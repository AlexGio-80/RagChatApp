using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace RagChatApp_Server.Models;

/// <summary>
/// Represents a chunk of text from a document with its vector embedding
/// </summary>
public class DocumentChunk
{
    /// <summary>
    /// Unique identifier for the chunk
    /// </summary>
    [Key]
    public int Id { get; set; }

    /// <summary>
    /// Foreign key to the parent document
    /// </summary>
    [Required]
    public int DocumentId { get; set; }

    /// <summary>
    /// Order of this chunk within the document (0-based)
    /// </summary>
    [Required]
    public int ChunkIndex { get; set; }

    /// <summary>
    /// The text content of this chunk
    /// </summary>
    [Required]
    public string Content { get; set; } = string.Empty;

    /// <summary>
    /// Header context for this chunk (preserves document structure)
    /// </summary>
    public string? HeaderContext { get; set; }

    /// <summary>
    /// Vector embedding for this chunk stored as binary data (1536 dimensions for OpenAI embeddings)
    /// </summary>
    public byte[]? Embedding { get; set; }

    /// <summary>
    /// Date and time when this chunk was created
    /// </summary>
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Navigation property to the parent document
    /// </summary>
    [ForeignKey(nameof(DocumentId))]
    public virtual Document Document { get; set; } = null!;
}