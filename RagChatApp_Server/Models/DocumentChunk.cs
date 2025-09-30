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
    /// Notes that can be added when loading or modifying the document
    /// </summary>
    public string? Notes { get; set; }

    /// <summary>
    /// Additional details as JSON for search enhancement
    /// </summary>
    public string? Details { get; set; }

    /// <summary>
    /// Date and time when this chunk was created
    /// </summary>
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Date and time when this chunk was last updated
    /// </summary>
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Navigation property to the parent document
    /// </summary>
    [ForeignKey(nameof(DocumentId))]
    public virtual Document Document { get; set; } = null!;

    /// <summary>
    /// Navigation property to content embedding
    /// </summary>
    public virtual DocumentChunkContentEmbedding? ContentEmbedding { get; set; }

    /// <summary>
    /// Navigation property to header context embedding
    /// </summary>
    public virtual DocumentChunkHeaderContextEmbedding? HeaderContextEmbedding { get; set; }

    /// <summary>
    /// Navigation property to notes embedding
    /// </summary>
    public virtual DocumentChunkNotesEmbedding? NotesEmbedding { get; set; }

    /// <summary>
    /// Navigation property to details embedding
    /// </summary>
    public virtual DocumentChunkDetailsEmbedding? DetailsEmbedding { get; set; }
}

/// <summary>
/// Embedding for document chunk content
/// </summary>
public class DocumentChunkContentEmbedding
{
    /// <summary>
    /// Unique identifier for the embedding
    /// </summary>
    [Key]
    public int Id { get; set; }

    /// <summary>
    /// Foreign key to the document chunk
    /// </summary>
    [Required]
    public int DocumentChunkId { get; set; }

    /// <summary>
    /// Vector embedding for the content stored as binary data (1536 dimensions for OpenAI embeddings)
    /// </summary>
    [Required]
    public byte[] Embedding { get; set; } = Array.Empty<byte>();

    /// <summary>
    /// AI model used to generate this embedding
    /// </summary>
    [MaxLength(100)]
    public string? Model { get; set; }

    /// <summary>
    /// Date and time when this embedding was created
    /// </summary>
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Date and time when this embedding was last updated
    /// </summary>
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Navigation property to the document chunk
    /// </summary>
    [ForeignKey(nameof(DocumentChunkId))]
    public virtual DocumentChunk DocumentChunk { get; set; } = null!;
}

/// <summary>
/// Embedding for document chunk header context
/// </summary>
public class DocumentChunkHeaderContextEmbedding
{
    /// <summary>
    /// Unique identifier for the embedding
    /// </summary>
    [Key]
    public int Id { get; set; }

    /// <summary>
    /// Foreign key to the document chunk
    /// </summary>
    [Required]
    public int DocumentChunkId { get; set; }

    /// <summary>
    /// Vector embedding for the header context stored as binary data (1536 dimensions for OpenAI embeddings)
    /// </summary>
    [Required]
    public byte[] Embedding { get; set; } = Array.Empty<byte>();

    /// <summary>
    /// AI model used to generate this embedding
    /// </summary>
    [MaxLength(100)]
    public string? Model { get; set; }

    /// <summary>
    /// Date and time when this embedding was created
    /// </summary>
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Date and time when this embedding was last updated
    /// </summary>
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Navigation property to the document chunk
    /// </summary>
    [ForeignKey(nameof(DocumentChunkId))]
    public virtual DocumentChunk DocumentChunk { get; set; } = null!;
}

/// <summary>
/// Embedding for document chunk notes
/// </summary>
public class DocumentChunkNotesEmbedding
{
    /// <summary>
    /// Unique identifier for the embedding
    /// </summary>
    [Key]
    public int Id { get; set; }

    /// <summary>
    /// Foreign key to the document chunk
    /// </summary>
    [Required]
    public int DocumentChunkId { get; set; }

    /// <summary>
    /// Vector embedding for the notes stored as binary data (1536 dimensions for OpenAI embeddings)
    /// </summary>
    [Required]
    public byte[] Embedding { get; set; } = Array.Empty<byte>();

    /// <summary>
    /// AI model used to generate this embedding
    /// </summary>
    [MaxLength(100)]
    public string? Model { get; set; }

    /// <summary>
    /// Date and time when this embedding was created
    /// </summary>
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Date and time when this embedding was last updated
    /// </summary>
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Navigation property to the document chunk
    /// </summary>
    [ForeignKey(nameof(DocumentChunkId))]
    public virtual DocumentChunk DocumentChunk { get; set; } = null!;
}

/// <summary>
/// Embedding for document chunk details
/// </summary>
public class DocumentChunkDetailsEmbedding
{
    /// <summary>
    /// Unique identifier for the embedding
    /// </summary>
    [Key]
    public int Id { get; set; }

    /// <summary>
    /// Foreign key to the document chunk
    /// </summary>
    [Required]
    public int DocumentChunkId { get; set; }

    /// <summary>
    /// Vector embedding for the details stored as binary data (1536 dimensions for OpenAI embeddings)
    /// </summary>
    [Required]
    public byte[] Embedding { get; set; } = Array.Empty<byte>();

    /// <summary>
    /// AI model used to generate this embedding
    /// </summary>
    [MaxLength(100)]
    public string? Model { get; set; }

    /// <summary>
    /// Date and time when this embedding was created
    /// </summary>
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Date and time when this embedding was last updated
    /// </summary>
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Navigation property to the document chunk
    /// </summary>
    [ForeignKey(nameof(DocumentChunkId))]
    public virtual DocumentChunk DocumentChunk { get; set; } = null!;
}

/// <summary>
/// Semantic cache to store recent search results
/// </summary>
public class SemanticCache
{
    /// <summary>
    /// Unique identifier for the cache entry
    /// </summary>
    [Key]
    public int Id { get; set; }

    /// <summary>
    /// The search query string
    /// </summary>
    [Required]
    [MaxLength(1000)]
    public string SearchQuery { get; set; } = string.Empty;

    /// <summary>
    /// Content of the result with the highest similarity percentage
    /// </summary>
    [Required]
    public string ResultContent { get; set; } = string.Empty;

    /// <summary>
    /// Embedding of the result content with the highest similarity percentage
    /// </summary>
    [Required]
    public byte[] ResultEmbedding { get; set; } = Array.Empty<byte>();

    /// <summary>
    /// Date and time when this cache entry was created
    /// </summary>
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
