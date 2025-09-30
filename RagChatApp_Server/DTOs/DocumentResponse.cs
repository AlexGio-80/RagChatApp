namespace RagChatApp_Server.DTOs;

/// <summary>
/// Response model for document operations
/// </summary>
public class DocumentResponse
{
    /// <summary>
    /// Document ID
    /// </summary>
    public int Id { get; set; }

    /// <summary>
    /// Original filename
    /// </summary>
    public string FileName { get; set; } = string.Empty;

    /// <summary>
    /// Content type
    /// </summary>
    public string ContentType { get; set; } = string.Empty;

    /// <summary>
    /// File size in bytes
    /// </summary>
    public long Size { get; set; }

    /// <summary>
    /// Processing status
    /// </summary>
    public string Status { get; set; } = string.Empty;

    /// <summary>
    /// Document path or URL for referencing
    /// </summary>
    public string? Path { get; set; }

    /// <summary>
    /// Upload timestamp
    /// </summary>
    public DateTime UploadedAt { get; set; }

    /// <summary>
    /// Processing timestamp
    /// </summary>
    public DateTime? ProcessedAt { get; set; }

    /// <summary>
    /// Number of chunks created from this document
    /// </summary>
    public int ChunkCount { get; set; }
}

/// <summary>
/// Response model for successful operations
/// </summary>
public class OperationResponse
{
    /// <summary>
    /// Whether the operation was successful
    /// </summary>
    public bool Success { get; set; }

    /// <summary>
    /// Result message
    /// </summary>
    public string Message { get; set; } = string.Empty;

    /// <summary>
    /// Additional data if applicable
    /// </summary>
    public object? Data { get; set; }
}