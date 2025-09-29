using Microsoft.Extensions.Options;
using RagChatApp_Server.Models;
using RagChatApp_Server.Services.Interfaces;
using System.Text;
using System.Text.Json;

namespace RagChatApp_Server.Services.AIProviders;

/// <summary>
/// Azure OpenAI provider service implementation
/// </summary>
public class AzureOpenAIProviderService : IAIProviderService
{
    private readonly AIProviderSettings _settings;
    private readonly HttpClient _httpClient;
    private readonly ILogger<AzureOpenAIProviderService> _logger;

    public AzureOpenAIProviderService(
        IOptions<AIProviderSettings> settings,
        HttpClient httpClient,
        ILogger<AzureOpenAIProviderService> logger)
    {
        _settings = settings.Value;
        _httpClient = httpClient;
        _logger = logger;

        ConfigureHttpClient();
    }

    private void ConfigureHttpClient()
    {
        var config = _settings.AzureOpenAI;
        _httpClient.BaseAddress = new Uri(config.Endpoint.TrimEnd('/') + "/");
        _httpClient.DefaultRequestHeaders.Add("api-key", config.ApiKey);
        _httpClient.Timeout = TimeSpan.FromSeconds(config.TimeoutSeconds);
    }

    public async Task<float[]> GenerateEmbeddingAsync(string text, AITaskType taskType = AITaskType.Embedding)
    {
        try
        {
            _logger.LogInformation("Generating embedding using Azure OpenAI for task: {TaskType}", taskType);

            var deploymentName = _settings.AzureOpenAI.EmbeddingDeploymentName;
            var url = $"openai/deployments/{deploymentName}/embeddings?api-version={_settings.AzureOpenAI.ApiVersion}";

            var requestBody = new
            {
                input = text
            };

            var json = JsonSerializer.Serialize(requestBody);
            var content = new StringContent(json, Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync(url, content);
            response.EnsureSuccessStatusCode();

            var responseContent = await response.Content.ReadAsStringAsync();
            using var document = JsonDocument.Parse(responseContent);

            var embedding = document.RootElement
                .GetProperty("data")[0]
                .GetProperty("embedding")
                .EnumerateArray()
                .Select(x => (float)x.GetDouble())
                .ToArray();

            _logger.LogInformation("Successfully generated embedding with {Dimensions} dimensions", embedding.Length);
            return embedding;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to generate embedding using Azure OpenAI");
            throw;
        }
    }

    public async Task<string> GenerateChatCompletionAsync(
        List<ChatMessage> messages,
        int? maxTokens = null,
        float temperature = 0.1f,
        AITaskType taskType = AITaskType.Chat)
    {
        try
        {
            _logger.LogInformation("Generating chat completion using Azure OpenAI for task: {TaskType}", taskType);

            var deploymentName = _settings.AzureOpenAI.ChatDeploymentName;
            var url = $"openai/deployments/{deploymentName}/chat/completions?api-version={_settings.AzureOpenAI.ApiVersion}";

            var requestBody = new
            {
                messages = messages.Select(m => new { role = m.Role, content = m.Content }),
                max_tokens = maxTokens ?? _settings.AzureOpenAI.MaxTokens,
                temperature = temperature
            };

            var json = JsonSerializer.Serialize(requestBody);
            var content = new StringContent(json, Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync(url, content);
            response.EnsureSuccessStatusCode();

            var responseContent = await response.Content.ReadAsStringAsync();
            using var document = JsonDocument.Parse(responseContent);

            var completion = document.RootElement
                .GetProperty("choices")[0]
                .GetProperty("message")
                .GetProperty("content")
                .GetString() ?? string.Empty;

            _logger.LogInformation("Successfully generated chat completion");
            return completion;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to generate chat completion using Azure OpenAI");
            throw;
        }
    }

    public string GetModelForTask(AITaskType taskType)
    {
        return taskType switch
        {
            AITaskType.Embedding => _settings.AzureOpenAI.EmbeddingDeploymentName,
            AITaskType.Chat => _settings.AzureOpenAI.ChatDeploymentName,
            AITaskType.OrderProcessing => _settings.AzureOpenAI.ChatDeploymentName,
            AITaskType.ArticleMatching => _settings.AzureOpenAI.ChatDeploymentName,
            _ => _settings.AzureOpenAI.ChatDeploymentName
        };
    }

    public AIProviderType GetCurrentProvider()
    {
        return AIProviderType.AzureOpenAI;
    }

    public object GetProviderConfiguration()
    {
        return new
        {
            Provider = "AzureOpenAI",
            ApiKey = _settings.AzureOpenAI.ApiKey,
            Endpoint = _settings.AzureOpenAI.Endpoint,
            ApiVersion = _settings.AzureOpenAI.ApiVersion,
            EmbeddingDeploymentName = _settings.AzureOpenAI.EmbeddingDeploymentName,
            ChatDeploymentName = _settings.AzureOpenAI.ChatDeploymentName,
            MaxTokens = _settings.AzureOpenAI.MaxTokens,
            TimeoutSeconds = _settings.AzureOpenAI.TimeoutSeconds
        };
    }
}