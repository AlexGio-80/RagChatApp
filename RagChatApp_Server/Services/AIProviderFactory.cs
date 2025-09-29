using Microsoft.Extensions.Options;
using RagChatApp_Server.Models;
using RagChatApp_Server.Services.AIProviders;
using RagChatApp_Server.Services.Interfaces;

namespace RagChatApp_Server.Services;

/// <summary>
/// Factory for creating AI provider service instances
/// </summary>
public class AIProviderFactory
{
    private readonly AIProviderSettings _settings;
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<AIProviderFactory> _logger;

    public AIProviderFactory(
        IOptions<AIProviderSettings> settings,
        IServiceProvider serviceProvider,
        ILogger<AIProviderFactory> logger)
    {
        _settings = settings.Value;
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    /// <summary>
    /// Create an AI provider service based on configuration
    /// </summary>
    /// <param name="providerType">Optional provider type override</param>
    /// <returns>AI provider service instance</returns>
    public IAIProviderService CreateProvider(AIProviderType? providerType = null)
    {
        var targetProvider = providerType ?? GetDefaultProvider();

        _logger.LogInformation("Creating AI provider service: {Provider}", targetProvider);

        return targetProvider switch
        {
            AIProviderType.OpenAI => _serviceProvider.GetRequiredService<OpenAIProviderService>(),
            AIProviderType.Gemini => _serviceProvider.GetRequiredService<GeminiProviderService>(),
            AIProviderType.AzureOpenAI => _serviceProvider.GetRequiredService<AzureOpenAIProviderService>(),
            _ => throw new NotSupportedException($"AI provider {targetProvider} is not supported")
        };
    }

    /// <summary>
    /// Get the default provider from configuration
    /// </summary>
    /// <returns>Default AI provider type</returns>
    public AIProviderType GetDefaultProvider()
    {
        if (Enum.TryParse<AIProviderType>(_settings.DefaultProvider, true, out var provider))
        {
            return provider;
        }

        _logger.LogWarning("Invalid default provider '{Provider}', falling back to OpenAI", _settings.DefaultProvider);
        return AIProviderType.OpenAI;
    }

    /// <summary>
    /// Get all available providers
    /// </summary>
    /// <returns>List of available provider types</returns>
    public List<AIProviderType> GetAvailableProviders()
    {
        var providers = new List<AIProviderType>();

        if (!string.IsNullOrEmpty(_settings.OpenAI.ApiKey))
            providers.Add(AIProviderType.OpenAI);

        if (!string.IsNullOrEmpty(_settings.Gemini.ApiKey))
            providers.Add(AIProviderType.Gemini);

        if (!string.IsNullOrEmpty(_settings.AzureOpenAI.ApiKey) &&
            !string.IsNullOrEmpty(_settings.AzureOpenAI.Endpoint))
            providers.Add(AIProviderType.AzureOpenAI);

        return providers;
    }

    /// <summary>
    /// Check if a provider is properly configured
    /// </summary>
    /// <param name="providerType">Provider type to check</param>
    /// <returns>True if provider is configured</returns>
    public bool IsProviderConfigured(AIProviderType providerType)
    {
        return providerType switch
        {
            AIProviderType.OpenAI => !string.IsNullOrEmpty(_settings.OpenAI.ApiKey),
            AIProviderType.Gemini => !string.IsNullOrEmpty(_settings.Gemini.ApiKey),
            AIProviderType.AzureOpenAI => !string.IsNullOrEmpty(_settings.AzureOpenAI.ApiKey) &&
                                         !string.IsNullOrEmpty(_settings.AzureOpenAI.Endpoint),
            _ => false
        };
    }
}