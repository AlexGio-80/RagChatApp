using RagChatApp_Server.Models;

namespace RagChatApp_Server.Services;

/// <summary>
/// Service for processing documents and extracting text content
/// </summary>
public interface IDocumentProcessingService
{
    /// <summary>
    /// Extracts text content from an uploaded file
    /// </summary>
    /// <param name="file">The uploaded file</param>
    /// <returns>Extracted text content</returns>
    Task<string> ExtractTextAsync(IFormFile file);

    /// <summary>
    /// Splits document content into chunks based on headers and size limits
    /// </summary>
    /// <param name="content">The document content to chunk</param>
    /// <param name="maxChunkSize">Maximum size per chunk (default: 1000 characters)</param>
    /// <returns>List of document chunks with preserved structure</returns>
    Task<List<DocumentChunk>> CreateChunksAsync(string content, int maxChunkSize = 1000);

    /// <summary>
    /// Validates if a file type is supported
    /// </summary>
    /// <param name="contentType">The MIME type of the file</param>
    /// <returns>True if supported, false otherwise</returns>
    bool IsSupportedFileType(string contentType);
}