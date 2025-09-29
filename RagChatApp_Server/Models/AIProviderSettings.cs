using System.ComponentModel.DataAnnotations;

namespace RagChatApp_Server.Models;

/// <summary>
/// Configuration for AI providers (OpenAI, Gemini, etc.)
/// </summary>
public class AIProviderSettings
{
    /// <summary>
    /// Default AI provider to use (OpenAI, Gemini, etc.)
    /// </summary>
    [Required]
    public string DefaultProvider { get; set; } = "OpenAI";

    /// <summary>
    /// Model to use for order processing tasks
    /// </summary>
    public string OrderProcessingModel { get; set; } = "gpt-4o";

    /// <summary>
    /// Model to use for article matching tasks
    /// </summary>
    public string ArticleMatchingModel { get; set; } = "gpt-4o";

    /// <summary>
    /// Model to use for embedding generation
    /// </summary>
    public string EmbeddingModel { get; set; } = "text-embedding-3-small";

    /// <summary>
    /// Model to use for chat completions
    /// </summary>
    public string ChatModel { get; set; } = "gpt-4o-mini";

    /// <summary>
    /// OpenAI configuration
    /// </summary>
    public OpenAIProviderConfig OpenAI { get; set; } = new();

    /// <summary>
    /// Google Gemini configuration
    /// </summary>
    public GeminiProviderConfig Gemini { get; set; } = new();

    /// <summary>
    /// Azure OpenAI configuration (for enterprise deployments)
    /// </summary>
    public AzureOpenAIProviderConfig AzureOpenAI { get; set; } = new();
}

/// <summary>
/// OpenAI provider configuration
/// </summary>
public class OpenAIProviderConfig
{
    /// <summary>
    /// OpenAI API Key
    /// </summary>
    [Required]
    public string ApiKey { get; set; } = string.Empty;

    /// <summary>
    /// OpenAI API Base URL
    /// </summary>
    public string BaseUrl { get; set; } = "https://api.openai.com/v1";

    /// <summary>
    /// Organization ID (optional)
    /// </summary>
    public string? OrganizationId { get; set; }

    /// <summary>
    /// Default embedding model for OpenAI
    /// </summary>
    public string DefaultEmbeddingModel { get; set; } = "text-embedding-3-small";

    /// <summary>
    /// Default chat model for OpenAI
    /// </summary>
    public string DefaultChatModel { get; set; } = "gpt-4o-mini";

    /// <summary>
    /// Maximum tokens per request
    /// </summary>
    public int MaxTokens { get; set; } = 4096;

    /// <summary>
    /// Request timeout in seconds
    /// </summary>
    public int TimeoutSeconds { get; set; } = 30;
}

/// <summary>
/// Google Gemini provider configuration
/// </summary>
public class GeminiProviderConfig
{
    /// <summary>
    /// Google API Key
    /// </summary>
    [Required]
    public string ApiKey { get; set; } = string.Empty;

    /// <summary>
    /// Google AI API Base URL
    /// </summary>
    public string BaseUrl { get; set; } = "https://generativelanguage.googleapis.com/v1beta";

    /// <summary>
    /// Default embedding model for Gemini
    /// </summary>
    public string DefaultEmbeddingModel { get; set; } = "models/embedding-001";

    /// <summary>
    /// Default chat model for Gemini
    /// </summary>
    public string DefaultChatModel { get; set; } = "models/gemini-1.5-pro-latest";

    /// <summary>
    /// Maximum tokens per request
    /// </summary>
    public int MaxTokens { get; set; } = 8192;

    /// <summary>
    /// Request timeout in seconds
    /// </summary>
    public int TimeoutSeconds { get; set; } = 30;

    /// <summary>
    /// Generation configuration
    /// </summary>
    public GeminiGenerationConfig GenerationConfig { get; set; } = new();
}

/// <summary>
/// Gemini generation configuration
/// </summary>
public class GeminiGenerationConfig
{
    /// <summary>
    /// Temperature for randomness (0.0 to 1.0)
    /// </summary>
    public float Temperature { get; set; } = 0.1f;

    /// <summary>
    /// Top-p for nucleus sampling
    /// </summary>
    public float TopP { get; set; } = 0.95f;

    /// <summary>
    /// Top-k for top-k sampling
    /// </summary>
    public int TopK { get; set; } = 40;
}

/// <summary>
/// Azure OpenAI provider configuration
/// </summary>
public class AzureOpenAIProviderConfig
{
    /// <summary>
    /// Azure OpenAI API Key
    /// </summary>
    [Required]
    public string ApiKey { get; set; } = string.Empty;

    /// <summary>
    /// Azure OpenAI endpoint
    /// </summary>
    [Required]
    public string Endpoint { get; set; } = string.Empty;

    /// <summary>
    /// Azure OpenAI API Version
    /// </summary>
    public string ApiVersion { get; set; } = "2024-02-15-preview";

    /// <summary>
    /// Deployment name for embedding model
    /// </summary>
    public string EmbeddingDeploymentName { get; set; } = "text-embedding-ada-002";

    /// <summary>
    /// Deployment name for chat model
    /// </summary>
    public string ChatDeploymentName { get; set; } = "gpt-4";

    /// <summary>
    /// Maximum tokens per request
    /// </summary>
    public int MaxTokens { get; set; } = 4096;

    /// <summary>
    /// Request timeout in seconds
    /// </summary>
    public int TimeoutSeconds { get; set; } = 30;
}

/// <summary>
/// Supported AI provider types
/// </summary>
public enum AIProviderType
{
    OpenAI,
    Gemini,
    AzureOpenAI
}

/// <summary>
/// AI task types for provider selection
/// </summary>
public enum AITaskType
{
    Embedding,
    Chat,
    OrderProcessing,
    ArticleMatching
}