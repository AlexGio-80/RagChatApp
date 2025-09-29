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
    public async Task<List<DocumentChunk>> CreateChunksAsync(string content, int maxChunkSize = 1000, string? notes = null, string? details = null, string fileName = "")
    {
        _logger.LogInformation("Creating chunks from content of length: {Length}", content.Length);

        var chunks = new List<DocumentChunk>();
        var chunkIndex = 0;
        var extension = Path.GetExtension(fileName).ToLowerInvariant();

        // For markdown and text files, try to use header-based chunking
        if (extension == ".md" || extension == ".txt")
        {
            var sections = SplitByHeaders(content);
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
                return chunks;
            }
        }

        // For PDF files, try to identify structure first
        if (extension == ".pdf")
        {
            var structuredChunks = TryExtractPdfStructure(content, notes, details, ref chunkIndex);
            if (structuredChunks.Any())
            {
                _logger.LogInformation("Created {ChunkCount} chunks using PDF structure", structuredChunks.Count);
                return structuredChunks;
            }
        }

        // Fallback to fixed-size chunking for files without clear structure
        var fixedChunks = SplitLongText(content, maxChunkSize - 100, 100);
        foreach (var chunk in fixedChunks)
        {
            chunks.Add(CreateDocumentChunk(chunkIndex++, chunk.Trim(), null, notes, details));
        }

        _logger.LogInformation("Created {ChunkCount} chunks using fixed-size splitting", chunks.Count);
        return chunks;
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

            foreach (var page in document.GetPages())
            {
                var pageText = page.Text;
                if (!string.IsNullOrWhiteSpace(pageText))
                {
                    // Normalize text: remove excessive whitespace and line breaks
                    pageText = NormalizeText(pageText);
                    content.AppendLine(pageText);
                }
            }

            return content.ToString();
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

        using var stream = file.OpenReadStream();
        using var document = WordprocessingDocument.Open(stream, false);

        if (document.MainDocumentPart?.Document.Body != null)
        {
            foreach (var element in document.MainDocumentPart.Document.Body.Elements())
            {
                if (element is Paragraph paragraph)
                {
                    content.AppendLine(paragraph.InnerText);
                }
                else if (element is Table table)
                {
                    foreach (var row in table.Elements<TableRow>())
                    {
                        var rowText = string.Join("\t", row.Elements<TableCell>().Select(cell => cell.InnerText));
                        content.AppendLine(rowText);
                    }
                }
            }
        }

        return content.ToString();
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
        var chunks = new List<DocumentChunk>();

        // Try to identify sections based on common PDF patterns
        var lines = text.Split('\n', StringSplitOptions.RemoveEmptyEntries);
        var currentSection = new StringBuilder();
        string? currentHeader = null;

        foreach (var line in lines)
        {
            var trimmedLine = line.Trim();

            // Simple heuristic for identifying headers in PDFs
            if (IsLikelyPdfHeader(trimmedLine))
            {
                // Save previous section
                if (currentSection.Length > 0)
                {
                    var content = currentSection.ToString().Trim();
                    if (!string.IsNullOrWhiteSpace(content))
                    {
                        chunks.Add(CreateDocumentChunk(chunkIndex++, content, currentHeader, notes, details));
                    }
                }

                // Start new section
                currentHeader = trimmedLine;
                currentSection.Clear();
            }
            else
            {
                currentSection.AppendLine(trimmedLine);
            }
        }

        // Add final section
        if (currentSection.Length > 0)
        {
            var content = currentSection.ToString().Trim();
            if (!string.IsNullOrWhiteSpace(content))
            {
                chunks.Add(CreateDocumentChunk(chunkIndex++, content, currentHeader, notes, details));
            }
        }

        // If we found meaningful structure, return it
        if (chunks.Count > 1 && chunks.Any(c => !string.IsNullOrEmpty(c.HeaderContext)))
        {
            return chunks;
        }

        return new List<DocumentChunk>();
    }

    private bool IsLikelyPdfHeader(string line)
    {
        if (string.IsNullOrWhiteSpace(line) || line.Length > 100)
            return false;

        // Common patterns for PDF headers
        return Regex.IsMatch(line, @"^(\d+\.?\s+|\w+\.?\s+)?[A-Z][^.!?]*$") ||
               Regex.IsMatch(line, @"^\d+\.\d+(\.\d+)?\s+[A-Z]") ||
               line.All(c => char.IsUpper(c) || char.IsWhiteSpace(c) || char.IsDigit(c) || c == '.');
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