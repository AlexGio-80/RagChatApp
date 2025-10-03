using System.ComponentModel.DataAnnotations;

namespace RagChatApp_Server.DTOs;

/// <summary>
/// Request model for chat interactions
/// </summary>
public class ChatRequest
{
    /// <summary>
    /// The user's question or message
    /// </summary>
    [Required]
    [MaxLength(2000)]
    public string Message { get; set; } = string.Empty;

    /// <summary>
    /// Maximum number of relevant chunks to include in context
    /// </summary>
    public int MaxChunks { get; set; } = 5;

    /// <summary>
    /// Similarity threshold for chunk relevance (0.0 to 1.0)
    /// Default: 0.5 (recommended for balanced precision/recall)
    /// </summary>
    public double SimilarityThreshold { get; set; } = 0.5;
}

/// <summary>
/// Response model for chat interactions
/// </summary>
public class ChatResponse
{
    /// <summary>
    /// The AI's response message
    /// </summary>
    public string Response { get; set; } = string.Empty;

    /// <summary>
    /// Sources used to generate the response
    /// </summary>
    public List<ChatSource> Sources { get; set; } = new();

    /// <summary>
    /// Whether the response was generated using mock mode
    /// </summary>
    public bool IsMockResponse { get; set; }
}

/// <summary>
/// Information about a source chunk used in the chat response
/// </summary>
public class ChatSource
{
    /// <summary>
    /// ID of the source document
    /// </summary>
    public int DocumentId { get; set; }

    /// <summary>
    /// Name of the source document
    /// </summary>
    public string DocumentName { get; set; } = string.Empty;

    /// <summary>
    /// Path or URL of the source document
    /// </summary>
    public string? DocumentPath { get; set; }

    /// <summary>
    /// The relevant chunk content
    /// </summary>
    public string Content { get; set; } = string.Empty;

    /// <summary>
    /// Header context for the chunk
    /// </summary>
    public string? HeaderContext { get; set; }

    /// <summary>
    /// Notes associated with the chunk
    /// </summary>
    public string? Notes { get; set; }

    /// <summary>
    /// Additional details as JSON for the chunk
    /// </summary>
    public string? Details { get; set; }

    /// <summary>
    /// Similarity score for this chunk
    /// </summary>
    public double SimilarityScore { get; set; }
}