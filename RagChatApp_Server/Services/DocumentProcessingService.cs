using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;
using RagChatApp_Server.Models;
using System.Text;
using System.Text.RegularExpressions;
using UglyToad.PdfPig;

namespace RagChatApp_Server.Services;

/// <summary>
/// Service for processing documents and extracting text content
/// </summary>
public class DocumentProcessingService : IDocumentProcessingService
{
    private readonly ILogger<DocumentProcessingService> _logger;
    private readonly HashSet<string> _supportedTypes = new()
    {
        "text/plain",
        "application/pdf",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "application/msword"
    };

    public DocumentProcessingService(ILogger<DocumentProcessingService> logger)
    {
        _logger = logger;
    }

    /// <summary>
    /// Extracts text content from an uploaded file
    /// </summary>
    public async Task<string> ExtractTextAsync(IFormFile file)
    {
        _logger.LogInformation("Extracting text from file: {FileName}, Type: {ContentType}",
            file.FileName, file.ContentType);

        try
        {
            return file.ContentType.ToLower() switch
            {
                "text/plain" => await ExtractFromTextFileAsync(file),
                "application/pdf" => await ExtractFromPdfAsync(file),
                "application/vnd.openxmlformats-officedocument.wordprocessingml.document" => await ExtractFromDocxAsync(file),
                "application/msword" => await ExtractFromDocAsync(file), // Legacy Word format (.doc)
                _ => throw new NotSupportedException($"File type {file.ContentType} is not supported")
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error extracting text from file: {FileName}", file.FileName);
            throw;
        }
    }

    /// <summary>
    /// Splits document content into chunks based on headers and size limits
    /// </summary>
    public Task<List<DocumentChunk>> CreateChunksAsync(string content, int maxChunkSize = 1000, string? notes = null, string? details = null, string fileName = "")
    {
        _logger.LogInformation("Creating chunks from content of length: {Length}, fileName: {FileName}", content.Length, fileName);

        var chunks = new List<DocumentChunk>();
        var chunkIndex = 0;
        var extension = Path.GetExtension(fileName).ToLowerInvariant();

        _logger.LogInformation("File extension detected: {Extension}", extension);

        // For markdown and text files, try to use header-based chunking
        if (extension == ".md" || extension == ".txt")
        {
            var sections = SplitByHeaders(content);
            _logger.LogInformation("Split into {SectionCount} sections for header-based chunking", sections.Count);
            
            if (sections.Count > 1)
            {
                foreach (var section in sections)
                {
                    var headerContext = ExtractHeaderContext(section);
                    var sectionContent = ExtractSectionContent(section);

                    if (!string.IsNullOrWhiteSpace(sectionContent))
                    {
                        if (sectionContent.Length <= maxChunkSize)
                        {
                            chunks.Add(CreateDocumentChunk(chunkIndex++, sectionContent.Trim(), headerContext, notes, details));
                        }
                        else
                        {
                            var subChunks = SplitLongText(sectionContent, maxChunkSize - 100, 100);
                            foreach (var subChunk in subChunks)
                            {
                                chunks.Add(CreateDocumentChunk(chunkIndex++, subChunk.Trim(), headerContext, notes, details));
                            }
                        }
                    }
                }
                _logger.LogInformation("Created {ChunkCount} chunks using header-based splitting", chunks.Count);
                return Task.FromResult(chunks);
            }
        }

        // For PDF and Word files, try to identify structure first
        if (extension == ".pdf" || extension == ".docx" || extension == ".doc")
        {
            var structuredChunks = TryExtractPdfStructure(content, notes, details, ref chunkIndex);
            if (structuredChunks.Any())
            {
                _logger.LogInformation("Created {ChunkCount} chunks using document structure for {Extension}", structuredChunks.Count, extension);
                return Task.FromResult(structuredChunks);
            }
        }

        // Fallback to fixed-size chunking for files without clear structure
        _logger.LogInformation("Using fixed-size chunking as fallback");
        var fixedChunks = SplitLongText(content, maxChunkSize - 100, 100);
        foreach (var chunk in fixedChunks)
        {
            chunks.Add(CreateDocumentChunk(chunkIndex++, chunk.Trim(), null, notes, details));
        }

        _logger.LogInformation("Created {ChunkCount} chunks using fixed-size splitting", chunks.Count);
        return Task.FromResult(chunks);
    }

    /// <summary>
    /// Validates if a file type is supported
    /// </summary>
    public bool IsSupportedFileType(string contentType)
    {
        return _supportedTypes.Contains(contentType.ToLower());
    }

    private async Task<string> ExtractFromTextFileAsync(IFormFile file)
    {
        using var reader = new StreamReader(file.OpenReadStream(), Encoding.UTF8);
        return await reader.ReadToEndAsync();
    }

    private async Task<string> ExtractFromPdfAsync(IFormFile file)
    {
        try
        {
            using var stream = file.OpenReadStream();
            using var document = PdfDocument.Open(stream);
            var content = new StringBuilder();

            _logger.LogInformation("Extracting PDF with {PageCount} pages", document.NumberOfPages);

            foreach (var page in document.GetPages())
            {
                try
                {
                    var pageText = page.Text;
                    if (string.IsNullOrWhiteSpace(pageText))
                    {
                        _logger.LogDebug("Page {PageNum} has no text content", page.Number);
                        continue;
                    }

                    // Get words for analysis
                    var words = page.GetWords().ToList();
                    _logger.LogDebug("Page {PageNum} has {WordCount} words", page.Number, words.Count);

                    // Try to detect headers by font size if words available
                    if (words.Any())
                    {
                        // Group words into lines based on Y position (with tolerance for slight variations)
                        var wordsByLine = words
                            .GroupBy(w => Math.Round(w.BoundingBox.Bottom, 0))
                            .OrderByDescending(g => g.Key)
                            .ToList();

                        _logger.LogDebug("Page {PageNum} has {LineCount} lines", page.Number, wordsByLine.Count);

                        var lines = new List<string>();
                        foreach (var lineGroup in wordsByLine)
                        {
                            var lineWords = lineGroup.OrderBy(w => w.BoundingBox.Left).ToList();
                            var lineText = string.Join(" ", lineWords.Select(w => w.Text)).Trim();
                            
                            if (string.IsNullOrWhiteSpace(lineText)) continue;

                            // Calculate average font size for this line
                            var avgFontSize = lineWords
                                .SelectMany(w => w.Letters)
                                .Where(l => l != null)
                                .Select(l => l.PointSize)
                                .DefaultIfEmpty(0)
                                .Average();

                            // Check if any word in line is bold
                            var hasBoldText = lineWords
                                .SelectMany(w => w.Letters)
                                .Any(l => l?.FontName?.ToLower().Contains("bold") == true);

                            // Mark potential headers (larger font or bold, and not too long)
                            if ((avgFontSize > 12 || hasBoldText) && lineText.Length < 150)
                            {
                                _logger.LogInformation("Potential header on page {Page}: '{Text}' (size: {Size:F1}pt, bold: {Bold})", 
                                    page.Number, lineText.Substring(0, Math.Min(60, lineText.Length)), avgFontSize, hasBoldText);
                                
                                // Add markers to help header detection
                                lines.Add($"[HEADER_CANDIDATE] {lineText}");
                            }
                            else
                            {
                                lines.Add(lineText);
                            }
                        }

                        content.AppendLine(string.Join("\n", lines));
                    }
                    else
                    {
                        // Fallback to simple text extraction
                        _logger.LogDebug("Using fallback text extraction for page {PageNum}", page.Number);
                        content.AppendLine(NormalizeText(pageText));
                    }

                    content.AppendLine(); // Blank line between pages
                }
                catch (Exception pageEx)
                {
                    _logger.LogWarning(pageEx, "Error processing page {PageNum}, using fallback extraction", page.Number);
                    // Fallback to simple text
                    var pageText = page.Text;
                    if (!string.IsNullOrWhiteSpace(pageText))
                    {
                        content.AppendLine(NormalizeText(pageText));
                    }
                }
            }

            var extractedText = content.ToString();
            _logger.LogInformation("Extracted {Length} characters from PDF with {Pages} pages", 
                extractedText.Length, document.NumberOfPages);
            
            return extractedText;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error extracting text from PDF file {FileName}", file.FileName);
            throw new InvalidOperationException($"Failed to extract text from PDF: {ex.Message}", ex);
        }
    }

    private async Task<string> ExtractFromDocxAsync(IFormFile file)
    {
        var content = new StringBuilder();

        try
        {
            using var stream = file.OpenReadStream();
            using var document = WordprocessingDocument.Open(stream, false);

            if (document.MainDocumentPart?.Document.Body == null)
            {
                _logger.LogWarning("Word document {FileName} has no body content", file.FileName);
                return string.Empty;
            }

            _logger.LogInformation("Extracting Word document with style analysis: {FileName}", file.FileName);
            int headersFound = 0;

            foreach (var element in document.MainDocumentPart.Document.Body.Elements())
            {
                if (element is Paragraph paragraph)
                {
                    var text = paragraph.InnerText?.Trim();
                    if (string.IsNullOrWhiteSpace(text))
                        continue;

                    // Check paragraph style to detect headers
                    var styleId = paragraph.ParagraphProperties?.ParagraphStyleId?.Val?.Value;
                    bool isHeader = false;
                    
                    // Common Word heading styles
                    if (!string.IsNullOrEmpty(styleId))
                    {
                        var styleLower = styleId.ToLower();
                        isHeader = styleLower.Contains("heading") || 
                                   styleLower.Contains("title") ||
                                   styleLower.StartsWith("h1") ||
                                   styleLower.StartsWith("h2") ||
                                   styleLower.StartsWith("h3") ||
                                   styleLower.StartsWith("h4") ||
                                   styleLower.StartsWith("h5") ||
                                   styleLower.StartsWith("h6");
                    }

                    // Also check for bold and large font as header indicators
                    if (!isHeader && text.Length < 150)
                    {
                        var runs = paragraph.Elements<Run>().ToList();
                        if (runs.Any())
                        {
                            // Check if text is bold
                            bool isBold = runs.Any(r => 
                                r.RunProperties?.Bold?.Val?.Value == true ||
                                r.RunProperties?.Bold != null);

                            // Check font size (if larger than typical body text)
                            var fontSize = runs
                                .Select(r => r.RunProperties?.FontSize?.Val?.Value)
                                .Where(fs => fs != null)
                                .Select(fs => int.TryParse(fs, out int size) ? size : 0)
                                .FirstOrDefault();

                            // Font size in Word is in half-points (e.g., "24" = 12pt)
                            // Body text is typically 22 (11pt), headers are 24+ (12pt+)
                            if (isBold || fontSize > 22)
                            {
                                isHeader = true;
                            }
                        }
                    }

                    if (isHeader)
                    {
                        headersFound++;
                        _logger.LogInformation("Word header detected (style: '{Style}'): '{Text}'", 
                            styleId ?? "formatting-based", 
                            text.Substring(0, Math.Min(60, text.Length)));
                        content.AppendLine($"[HEADER_CANDIDATE] {text}");
                    }
                    else
                    {
                        content.AppendLine(text);
                    }
                }
                else if (element is Table table)
                {
                    _logger.LogDebug("Processing table with {RowCount} rows", table.Elements<TableRow>().Count());
                    foreach (var row in table.Elements<TableRow>())
                    {
                        var rowText = string.Join("\t", row.Elements<TableCell>().Select(cell => cell.InnerText?.Trim()));
                        if (!string.IsNullOrWhiteSpace(rowText))
                        {
                            content.AppendLine(rowText);
                        }
                    }
                }
            }

            var extractedText = content.ToString();
            _logger.LogInformation("Extracted {Length} characters from Word document with {HeaderCount} headers detected", 
                extractedText.Length, headersFound);

            return extractedText;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error extracting text from Word document {FileName}", file.FileName);
            throw new InvalidOperationException($"Failed to extract text from Word document: {ex.Message}", ex);
        }
    }

    /// <summary>
    /// Extract text from legacy Word document (.doc format)
    /// </summary>
    private async Task<string> ExtractFromDocAsync(IFormFile file)
    {
        _logger.LogInformation("Attempting to extract text from legacy Word document: {FileName}", file.FileName);
        
        try
        {
            // Try to read as if it's actually a newer format (some .doc files are actually .docx)
            return await ExtractFromDocxAsync(file);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Could not read {FileName} as modern Word format, attempting alternative extraction", file.FileName);
            
            // For now, return a message indicating the limitation
            // In a production environment, you might want to:
            // 1. Use a library like Aspose.Words
            // 2. Convert using LibreOffice/OpenOffice headless
            // 3. Use a cloud service for conversion
            
            var content = new StringBuilder();
            content.AppendLine($"# Document: {file.FileName}");
            content.AppendLine();
            content.AppendLine("**Note**: This is a legacy Word document (.doc format).");
            content.AppendLine("The system currently supports modern Word documents (.docx), PDF files, and plain text files.");
            content.AppendLine();
            content.AppendLine("To process this document, please:");
            content.AppendLine("1. Open the document in Microsoft Word");
            content.AppendLine("2. Save it as a .docx file (Word Document format)");
            content.AppendLine("3. Upload the converted .docx file");
            content.AppendLine();
            content.AppendLine("Alternative: Save the document as a .txt file to preserve the text content.");
            
            return content.ToString();
        }
    }

    private List<string> SplitByHeaders(string content)
    {
        // Split by markdown headers (# ## ### etc.)
        var headerPattern = @"(?=^#{1,6}\s+.+$)";
        var sections = Regex.Split(content, headerPattern, RegexOptions.Multiline)
            .Where(s => !string.IsNullOrWhiteSpace(s))
            .ToList();

        // If no headers found, treat entire content as one section
        return sections.Any() ? sections : new List<string> { content };
    }

    private string? ExtractHeaderContext(string section)
    {
        var lines = section.Split('\n', StringSplitOptions.RemoveEmptyEntries);
        var firstLine = lines.FirstOrDefault()?.Trim();

        // Check if first line is a markdown header
        if (firstLine != null && Regex.IsMatch(firstLine, @"^#{1,6}\s+.+"))
        {
            return firstLine;
        }

        return null;
    }

    private string ExtractSectionContent(string section)
    {
        var lines = section.Split('\n');
        var firstLine = lines.FirstOrDefault()?.Trim();

        // If first line is a header, skip it for content
        if (firstLine != null && Regex.IsMatch(firstLine, @"^#{1,6}\s+.+"))
        {
            return string.Join('\n', lines.Skip(1));
        }

        return section;
    }

    private List<string> SplitLongText(string text, int maxSize)
    {
        var chunks = new List<string>();
        var sentences = SplitIntoSentences(text);
        var currentChunk = new StringBuilder();

        foreach (var sentence in sentences)
        {
            if (currentChunk.Length + sentence.Length > maxSize && currentChunk.Length > 0)
            {
                chunks.Add(currentChunk.ToString());
                currentChunk.Clear();
            }

            currentChunk.Append(sentence);

            // Add space if not ending with punctuation or whitespace
            if (!sentence.EndsWith(' ') && !string.IsNullOrEmpty(sentence))
            {
                currentChunk.Append(' ');
            }
        }

        if (currentChunk.Length > 0)
        {
            chunks.Add(currentChunk.ToString());
        }

        return chunks;
    }

    private List<string> SplitIntoSentences(string text)
    {
        // Simple sentence splitting - can be improved with more sophisticated NLP
        var sentences = Regex.Split(text, @"(?<=[.!?])\s+")
            .Where(s => !string.IsNullOrWhiteSpace(s))
            .ToList();

        return sentences.Any() ? sentences : new List<string> { text };
    }

    private DocumentChunk CreateDocumentChunk(int chunkIndex, string content, string? headerContext, string? notes, string? details)
    {
        return new DocumentChunk
        {
            ChunkIndex = chunkIndex,
            Content = content,
            HeaderContext = headerContext,
            Notes = notes,
            Details = details
        };
    }

    private List<DocumentChunk> TryExtractPdfStructure(string text, string? notes, string? details, ref int chunkIndex)
    {
        _logger.LogInformation("Attempting to extract PDF structure from text of length: {Length}", text.Length);
        var chunks = new List<DocumentChunk>();

        // Try to identify sections based on common PDF patterns
        var lines = text.Split('\n', StringSplitOptions.RemoveEmptyEntries);
        _logger.LogInformation("Split text into {LineCount} lines", lines.Length);
        
        var currentSection = new StringBuilder();
        string? currentHeader = null;
        int headersFound = 0;

        foreach (var line in lines)
        {
            var trimmedLine = line.Trim();
            
            if (string.IsNullOrWhiteSpace(trimmedLine))
                continue;

            // Simple heuristic for identifying headers in PDFs
            if (IsLikelyPdfHeader(trimmedLine))
            {
                headersFound++;
                
                // Save previous section
                if (currentSection.Length > 0)
                {
                    var content = currentSection.ToString().Trim();
                    if (!string.IsNullOrWhiteSpace(content))
                    {
                        _logger.LogDebug("Creating chunk {Index} with header: '{Header}', content length: {ContentLength}", 
                            chunkIndex, currentHeader ?? "(none)", content.Length);
                        chunks.Add(CreateDocumentChunk(chunkIndex++, content, currentHeader, notes, details));
                    }
                }

                // Start new section - remove marker if present
                currentHeader = trimmedLine.Replace("[HEADER_CANDIDATE]", "").Trim();
                currentSection.Clear();
                _logger.LogDebug("Starting new section with header: {Header}", currentHeader);
            }
            else
            {
                // Also remove marker from content lines (shouldn't happen but just in case)
                var cleanLine = trimmedLine.Replace("[HEADER_CANDIDATE]", "").Trim();
                if (!string.IsNullOrWhiteSpace(cleanLine))
                {
                    currentSection.AppendLine(cleanLine);
                }
            }
        }

        // Add final section
        if (currentSection.Length > 0)
        {
            var content = currentSection.ToString().Trim();
            if (!string.IsNullOrWhiteSpace(content))
            {
                _logger.LogDebug("Creating final chunk {Index} with header: '{Header}', content length: {ContentLength}", 
                    chunkIndex, currentHeader ?? "(none)", content.Length);
                chunks.Add(CreateDocumentChunk(chunkIndex++, content, currentHeader, notes, details));
            }
        }

        _logger.LogInformation("Found {HeaderCount} headers, created {ChunkCount} chunks", headersFound, chunks.Count);
        
        // If we found meaningful structure, return it
        if (chunks.Count > 1 && chunks.Any(c => !string.IsNullOrEmpty(c.HeaderContext)))
        {
            _logger.LogInformation("Successfully extracted PDF structure with {ChunkCount} chunks and {HeaderCount} headers", 
                chunks.Count, headersFound);
            return chunks;
        }

        _logger.LogInformation("No meaningful PDF structure found (chunks: {ChunkCount}, headers: {HeaderCount})", 
            chunks.Count, headersFound);
        return new List<DocumentChunk>();
    }

    private bool IsLikelyPdfHeader(string line)
    {
        if (string.IsNullOrWhiteSpace(line))
            return false;

        var trimmedLine = line.Trim();

        // Check for our marker from PDF extraction
        if (trimmedLine.StartsWith("[HEADER_CANDIDATE]"))
        {
            _logger.LogDebug("Header detected by PDF font analysis: {Line}", trimmedLine.Replace("[HEADER_CANDIDATE]", "").Trim());
            return true;
        }

        // Skip lines that are too long to be headers
        if (trimmedLine.Length > 200)
        {
            _logger.LogTrace("Line too long ({Length}) to be header: {Line}", trimmedLine.Length, trimmedLine.Substring(0, Math.Min(50, trimmedLine.Length)));
            return false;
        }

        // Skip lines with excessive dots (table of contents formatting)
        if (trimmedLine.Count(c => c == '.') > 5)
        {
            _logger.LogTrace("Too many dots in line, likely TOC: {Line}", trimmedLine.Substring(0, Math.Min(50, trimmedLine.Length)));
            return false;
        }

        // Pattern 1: Numbered headers: "1. Title", "1.2 Title", "1.2.3 Title"
        if (Regex.IsMatch(trimmedLine, @"^\d+(\.\d+)*\.?\s+\w+"))
        {
            _logger.LogDebug("Detected numbered header: {Line}", trimmedLine);
            return true;
        }

        // Pattern 2: All caps headers: "INTRODUCTION", "CHAPTER 1"
        if (trimmedLine.Length >= 3 && trimmedLine.All(c => char.IsUpper(c) || char.IsWhiteSpace(c) || char.IsDigit(c) || c == '.' || c == ':' || c == '-' || c == '\'' || c == '(' || c == ')'))
        {
            _logger.LogDebug("Detected all-caps header: {Line}", trimmedLine);
            return true;
        }

        // Pattern 3: Title case - starts with capital, relatively short
        if (trimmedLine.Length <= 100 && trimmedLine.Length > 0 && char.IsUpper(trimmedLine[0]))
        {
            // Check if it looks like a sentence (ends with period, exclamation, question mark)
            if (trimmedLine.TrimEnd().EndsWith(".") || trimmedLine.TrimEnd().EndsWith("!") || trimmedLine.TrimEnd().EndsWith("?"))
            {
                _logger.LogTrace("Looks like a sentence (ends with punctuation): {Line}", trimmedLine);
                return false;
            }

            // Split into words
            var words = trimmedLine.Split(new[] { ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries);
            
            // Headers are usually short (2-10 words)
            if (words.Length >= 2 && words.Length <= 10)
            {
                int capitalizedWords = words.Count(w => w.Length > 0 && char.IsUpper(w[0]));
                
                // More lenient: at least 30% capitalized (good for Italian)
                if (capitalizedWords >= Math.Max(1, words.Length * 0.3))
                {
                    _logger.LogDebug("Detected title-case header ({CapWords}/{TotalWords} capitalized): {Line}", 
                        capitalizedWords, words.Length, trimmedLine);
                    return true;
                }
                else
                {
                    _logger.LogTrace("Not enough capitalized words ({CapWords}/{TotalWords}): {Line}", 
                        capitalizedWords, words.Length, trimmedLine);
                }
            }
            else if (words.Length == 1 && trimmedLine.Length >= 3)
            {
                // Single word starting with capital, likely a header
                _logger.LogDebug("Detected single-word header: {Line}", trimmedLine);
                return true;
            }
        }

        return false;
    }

    private List<string> SplitLongText(string text, int maxChunkSize = 750, int overlap = 100)
    {
        if (string.IsNullOrWhiteSpace(text))
            return new List<string>();

        var chunks = new List<string>();

        // First try to split by sentences
        var sentences = SplitIntoSentences(text);
        var currentChunk = new StringBuilder();

        foreach (var sentence in sentences)
        {
            if (currentChunk.Length + sentence.Length <= maxChunkSize)
            {
                currentChunk.Append(sentence);
            }
            else
            {
                if (currentChunk.Length > 0)
                {
                    chunks.Add(currentChunk.ToString().Trim());

                    // Add overlap from the end of current chunk
                    var overlapText = GetOverlapText(currentChunk.ToString(), overlap);
                    currentChunk.Clear();
                    currentChunk.Append(overlapText);
                }
                currentChunk.Append(sentence);
            }
        }

        if (currentChunk.Length > 0)
        {
            chunks.Add(currentChunk.ToString().Trim());
        }

        return chunks.Where(c => !string.IsNullOrWhiteSpace(c)).ToList();
    }

    private string GetOverlapText(string text, int maxOverlapLength)
    {
        if (text.Length <= maxOverlapLength)
            return text;

        // Try to find a good breaking point (end of sentence)
        var overlapStart = text.Length - maxOverlapLength;
        var lastSentenceEnd = text.LastIndexOf('.', text.Length - 1, maxOverlapLength);

        if (lastSentenceEnd > overlapStart)
        {
            return text.Substring(lastSentenceEnd + 1).Trim();
        }

        return text.Substring(overlapStart).Trim();
    }

    private string NormalizeText(string text)
    {
        if (string.IsNullOrWhiteSpace(text))
            return string.Empty;

        // Remove excessive whitespace
        text = Regex.Replace(text, @"\s+", " ");

        // Remove unnecessary line breaks but preserve paragraph structure
        text = Regex.Replace(text, @"(\r\n|\r|\n)+", "\n");

        return text.Trim();
    }
}