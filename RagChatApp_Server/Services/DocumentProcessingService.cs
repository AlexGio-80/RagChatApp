using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;
using iText.Kernel.Pdf;
using iText.Kernel.Pdf.Canvas.Parser;
using iText.Kernel.Pdf.Canvas.Parser.Listener;
using RagChatApp_Server.Models;
using System.Text;
using System.Text.RegularExpressions;

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
    public async Task<List<DocumentChunk>> CreateChunksAsync(string content, int maxChunkSize = 1000)
    {
        _logger.LogInformation("Creating chunks from content of length: {Length}", content.Length);

        var chunks = new List<DocumentChunk>();
        var chunkIndex = 0;

        // Split by markdown headers first
        var sections = SplitByHeaders(content);

        foreach (var section in sections)
        {
            var headerContext = ExtractHeaderContext(section);
            var sectionContent = ExtractSectionContent(section);

            if (sectionContent.Length <= maxChunkSize)
            {
                // Section fits in one chunk
                chunks.Add(new DocumentChunk
                {
                    ChunkIndex = chunkIndex++,
                    Content = sectionContent.Trim(),
                    HeaderContext = headerContext
                });
            }
            else
            {
                // Split large section into smaller chunks
                var subChunks = SplitLongText(sectionContent, maxChunkSize);
                foreach (var subChunk in subChunks)
                {
                    chunks.Add(new DocumentChunk
                    {
                        ChunkIndex = chunkIndex++,
                        Content = subChunk.Trim(),
                        HeaderContext = headerContext
                    });
                }
            }
        }

        _logger.LogInformation("Created {ChunkCount} chunks", chunks.Count);
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
        var content = new StringBuilder();

        using var stream = file.OpenReadStream();
        using var reader = new PdfReader(stream);
        using var document = new PdfDocument(reader);

        for (int i = 1; i <= document.GetNumberOfPages(); i++)
        {
            var page = document.GetPage(i);
            var strategy = new SimpleTextExtractionStrategy();
            var pageText = PdfTextExtractor.GetTextFromPage(page, strategy);
            content.AppendLine(pageText);
        }

        return content.ToString();
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
}