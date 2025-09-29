using RagChatApp_Server.Models;

namespace RagChatApp_Server.Services.Interfaces;

/// <summary>
/// Interface for AI provider services
/// </summary>
public interface IAIProviderService
{
    /// <summary>
    /// Generate embeddings for the given text
    /// </summary>
    /// <param name="text">Text to embed</param>
    /// <param name="taskType">Type of AI task for provider selection</param>
    /// <returns>Embedding vector as float array</returns>
    Task<float[]> GenerateEmbeddingAsync(string text, AITaskType taskType = AITaskType.Embedding);

    /// <summary>
    /// Generate chat completion
    /// </summary>
    /// <param name="messages">Chat messages</param>
    /// <param name="maxTokens">Maximum tokens for response</param>
    /// <param name="temperature">Temperature for response randomness</param>
    /// <param name="taskType">Type of AI task for provider selection</param>
    /// <returns>Chat completion response</returns>
    Task<string> GenerateChatCompletionAsync(
        List<ChatMessage> messages,
        int? maxTokens = null,
        float temperature = 0.1f,
        AITaskType taskType = AITaskType.Chat);

    /// <summary>
    /// Get the model name for a specific task type
    /// </summary>
    /// <param name="taskType">AI task type</param>
    /// <returns>Model name to use</returns>
    string GetModelForTask(AITaskType taskType);

    /// <summary>
    /// Get the current provider type
    /// </summary>
    /// <returns>Current AI provider type</returns>
    AIProviderType GetCurrentProvider();

    /// <summary>
    /// Get provider-specific configuration for stored procedures
    /// </summary>
    /// <returns>Configuration object for stored procedure calls</returns>
    object GetProviderConfiguration();
}

/// <summary>
/// Chat message for AI conversations
/// </summary>
public class ChatMessage
{
    public string Role { get; set; } = string.Empty;
    public string Content { get; set; } = string.Empty;
}