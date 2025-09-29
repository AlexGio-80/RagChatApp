using System.ComponentModel.DataAnnotations;

namespace RagChatApp_Server.DTOs;

/// <summary>
/// Request model for document upload
/// </summary>
public class DocumentUploadRequest
{
    /// <summary>
    /// The file to upload
    /// </summary>
    [Required]
    public IFormFile File { get; set; } = null!;

    /// <summary>
    /// Optional notes about the document
    /// </summary>
    public string? Notes { get; set; }

    /// <summary>
    /// Optional structured metadata as JSON string
    /// Examples: {"author": "John Doe", "tags": ["AI", "ML"], "license": "MIT"}
    /// </summary>
    public string? Details { get; set; }
}

/// <summary>
/// Request model for indexing text directly
/// </summary>
public class IndexTextRequest
{
    /// <summary>
    /// The title/name for this text content
    /// </summary>
    [Required]
    [MaxLength(255)]
    public string Title { get; set; } = string.Empty;

    /// <summary>
    /// The text content to index
    /// </summary>
    [Required]
    public string Content { get; set; } = string.Empty;

    /// <summary>
    /// Optional notes about the text content
    /// </summary>
    public string? Notes { get; set; }

    /// <summary>
    /// Optional structured metadata as JSON string
    /// Examples: {"author": "John Doe", "type": "documentation", "tags": ["tutorial"]}
    /// </summary>
    public string? Details { get; set; }
}