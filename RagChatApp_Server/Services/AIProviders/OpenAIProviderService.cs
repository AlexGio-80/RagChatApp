using Microsoft.Extensions.Options;
using RagChatApp_Server.Models;
using RagChatApp_Server.Services.Interfaces;
using System.Text;
using System.Text.Json;

namespace RagChatApp_Server.Services.AIProviders;

/// <summary>
/// OpenAI provider service implementation
/// </summary>
public class OpenAIProviderService : IAIProviderService
{
    private readonly AIProviderSettings _settings;
    private readonly HttpClient _httpClient;
    private readonly ILogger<OpenAIProviderService> _logger;

    public OpenAIProviderService(
        IOptions<AIProviderSettings> settings,
        HttpClient httpClient,
        ILogger<OpenAIProviderService> logger)
    {
        _settings = settings.Value;
        _httpClient = httpClient;
        _logger = logger;

        ConfigureHttpClient();
    }

    private void ConfigureHttpClient()
    {
        var config = _settings.OpenAI;
        _httpClient.BaseAddress = new Uri(config.BaseUrl);
        _httpClient.DefaultRequestHeaders.Add("Authorization", $"Bearer {config.ApiKey}");

        if (!string.IsNullOrEmpty(config.OrganizationId))
        {
            _httpClient.DefaultRequestHeaders.Add("OpenAI-Organization", config.OrganizationId);
        }

        _httpClient.Timeout = TimeSpan.FromSeconds(config.TimeoutSeconds);
    }

    public async Task<float[]> GenerateEmbeddingAsync(string text, AITaskType taskType = AITaskType.Embedding)
    {
        try
        {
            _logger.LogInformation("Generating embedding using OpenAI for task: {TaskType}", taskType);

            var model = GetModelForTask(taskType);
            var requestBody = new
            {
                input = text,
                model = model
            };

            var json = JsonSerializer.Serialize(requestBody);
            var content = new StringContent(json, Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync("embeddings", content);
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
            _logger.LogError(ex, "Failed to generate embedding using OpenAI");
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
            _logger.LogInformation("Generating chat completion using OpenAI for task: {TaskType}", taskType);

            var model = GetModelForTask(taskType);
            var requestBody = new
            {
                model = model,
                messages = messages.Select(m => new { role = m.Role, content = m.Content }),
                max_tokens = maxTokens ?? _settings.OpenAI.MaxTokens,
                temperature = temperature
            };

            var json = JsonSerializer.Serialize(requestBody);
            var content = new StringContent(json, Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync("chat/completions", content);
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
            _logger.LogError(ex, "Failed to generate chat completion using OpenAI");
            throw;
        }
    }

    public string GetModelForTask(AITaskType taskType)
    {
        return taskType switch
        {
            AITaskType.Embedding => _settings.EmbeddingModel,
            AITaskType.Chat => _settings.ChatModel,
            AITaskType.OrderProcessing => _settings.OrderProcessingModel,
            AITaskType.ArticleMatching => _settings.ArticleMatchingModel,
            _ => _settings.OpenAI.DefaultChatModel
        };
    }

    public AIProviderType GetCurrentProvider()
    {
        return AIProviderType.OpenAI;
    }

    public object GetProviderConfiguration()
    {
        return new
        {
            Provider = "OpenAI",
            ApiKey = _settings.OpenAI.ApiKey,
            BaseUrl = _settings.OpenAI.BaseUrl,
            EmbeddingModel = _settings.EmbeddingModel,
            ChatModel = _settings.ChatModel,
            MaxTokens = _settings.OpenAI.MaxTokens,
            TimeoutSeconds = _settings.OpenAI.TimeoutSeconds
        };
    }
}