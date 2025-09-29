namespace RagChatApp_Server.Models;

/// <summary>
/// Configuration settings for RAG functionality
/// </summary>
public class RagSettings
{
    /// <summary>
    /// Maximum number of chunks to retrieve for LLM processing
    /// Default is 10, maximum allowed is 50
    /// </summary>
    public int MaxChunksForLLM { get; set; } = 10;

    /// <summary>
    /// Gets the effective max chunks value, ensuring it doesn't exceed 50
    /// </summary>
    public int GetEffectiveMaxChunks()
    {
        return Math.Min(MaxChunksForLLM <= 0 ? 10 : MaxChunksForLLM, 50);
    }
}