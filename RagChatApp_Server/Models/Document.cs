using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace RagChatApp_Server.Models;

/// <summary>
/// Represents a document uploaded to the system
/// </summary>
public class Document
{
    /// <summary>
    /// Unique identifier for the document
    /// </summary>
    [Key]
    public int Id { get; set; }

    /// <summary>
    /// Original filename of the uploaded document
    /// </summary>
    [Required]
    [MaxLength(255)]
    public string FileName { get; set; } = string.Empty;

    /// <summary>
    /// Content type of the document (e.g., text/plain, application/pdf)
    /// </summary>
    [Required]
    [MaxLength(100)]
    public string ContentType { get; set; } = string.Empty;

    /// <summary>
    /// Size of the document in bytes
    /// </summary>
    public long Size { get; set; }

    /// <summary>
    /// Size of the document in bytes (alias for FileSize used in SQL scripts)
    /// </summary>
    public long FileSize => Size;

    /// <summary>
    /// Full text content extracted from the document
    /// </summary>
    [Required]
    public string Content { get; set; } = string.Empty;

    /// <summary>
    /// Path or URL of the document for referencing in results
    /// </summary>
    [MaxLength(500)]
    public string? Path { get; set; }

    /// <summary>
    /// User who uploaded the document
    /// </summary>
    [MaxLength(255)]
    public string? UploadedBy { get; set; }

    /// <summary>
    /// Date and time when the document was uploaded
    /// </summary>
    public DateTime UploadedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Date and time when the document was last processed
    /// </summary>
    public DateTime? ProcessedAt { get; set; }

    /// <summary>
    /// Processing status of the document
    /// </summary>
    [Required]
    [MaxLength(50)]
    public string Status { get; set; } = "Pending";

    /// <summary>
    /// Processing status of the document (alias for ProcessingStatus used in SQL scripts)
    /// </summary>
    public string ProcessingStatus => Status;

    /// <summary>
    /// Optional notes about the document
    /// </summary>
    public string? Notes { get; set; }

    /// <summary>
    /// Collection of chunks created from this document
    /// </summary>
    public virtual ICollection<DocumentChunk> Chunks { get; set; } = new List<DocumentChunk>();
}