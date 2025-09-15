using RagChatApp_Server.DTOs;
using RagChatApp_Server.Models;

namespace RagChatApp_Server.Services;

/// <summary>
/// Service for Azure OpenAI integration
/// </summary>
public interface IAzureOpenAIService
{
    /// <summary>
    /// Generates embeddings for text content
    /// </summary>
    /// <param name="text">Text to generate embeddings for</param>
    /// <returns>Vector embedding as byte array</returns>
    Task<byte[]> GenerateEmbeddingsAsync(string text);

    /// <summary>
    /// Finds similar document chunks using vector similarity
    /// </summary>
    /// <param name="query">The search query</param>
    /// <param name="maxResults">Maximum number of results to return</param>
    /// <param name="similarityThreshold">Minimum similarity threshold</param>
    /// <returns>List of relevant document chunks with similarity scores</returns>
    Task<List<ChatSource>> FindSimilarChunksAsync(string query, int maxResults = 5, double similarityThreshold = 0.7);

    /// <summary>
    /// Generates a chat response using RAG (Retrieval-Augmented Generation)
    /// </summary>
    /// <param name="request">Chat request with user message and parameters</param>
    /// <returns>AI-generated response with sources</returns>
    Task<ChatResponse> GenerateChatResponseAsync(ChatRequest request);

    /// <summary>
    /// Gets whether the service is running in mock mode
    /// </summary>
    bool IsMockMode { get; }
}