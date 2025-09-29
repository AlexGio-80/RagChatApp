using Microsoft.Extensions.Options;
using RagChatApp_Server.Models;
using RagChatApp_Server.Services.Interfaces;
using System.Text;
using System.Text.Json;

namespace RagChatApp_Server.Services.AIProviders;

/// <summary>
/// Google Gemini provider service implementation
/// </summary>
public class GeminiProviderService : IAIProviderService
{
    private readonly AIProviderSettings _settings;
    private readonly HttpClient _httpClient;
    private readonly ILogger<GeminiProviderService> _logger;

    public GeminiProviderService(
        IOptions<AIProviderSettings> settings,
        HttpClient httpClient,
        ILogger<GeminiProviderService> logger)
    {
        _settings = settings.Value;
        _httpClient = httpClient;
        _logger = logger;

        ConfigureHttpClient();
    }

    private void ConfigureHttpClient()
    {
        var config = _settings.Gemini;
        _httpClient.BaseAddress = new Uri(config.BaseUrl.TrimEnd('/') + '/');
        _httpClient.Timeout = TimeSpan.FromSeconds(config.TimeoutSeconds);
    }

    public async Task<float[]> GenerateEmbeddingAsync(string text, AITaskType taskType = AITaskType.Embedding)
    {
        try
        {
            _logger.LogInformation("Generating embedding using Gemini for task: {TaskType}", taskType);

            var model = GetModelForTask(taskType);
            var url = $"{model}:embedContent?key={_settings.Gemini.ApiKey}";

            var requestBody = new
            {
                content = new
                {
                    parts = new[]
                    {
                        new { text = text }
                    }
                }
            };

            var json = JsonSerializer.Serialize(requestBody);
            var content = new StringContent(json, Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync(url, content);
            response.EnsureSuccessStatusCode();

            var responseContent = await response.Content.ReadAsStringAsync();
            using var document = JsonDocument.Parse(responseContent);

            var embedding = document.RootElement
                .GetProperty("embedding")
                .GetProperty("values")
                .EnumerateArray()
                .Select(x => (float)x.GetDouble())
                .ToArray();

            _logger.LogInformation("Successfully generated embedding with {Dimensions} dimensions", embedding.Length);
            return embedding;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to generate embedding using Gemini");
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
            _logger.LogInformation("Generating chat completion using Gemini for task: {TaskType}", taskType);

            var model = GetModelForTask(taskType);
            var url = $"{model}:generateContent?key={_settings.Gemini.ApiKey}";

            var requestBody = new
            {
                contents = messages.Select(m => new
                {
                    role = m.Role == "assistant" ? "model" : m.Role,
                    parts = new[] { new { text = m.Content } }
                }).ToArray(),
                generationConfig = new
                {
                    temperature = temperature,
                    topP = _settings.Gemini.GenerationConfig.TopP,
                    topK = _settings.Gemini.GenerationConfig.TopK,
                    maxOutputTokens = maxTokens ?? _settings.Gemini.MaxTokens
                }
            };

            var json = JsonSerializer.Serialize(requestBody);
            var content = new StringContent(json, Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync(url, content);
            response.EnsureSuccessStatusCode();

            var responseContent = await response.Content.ReadAsStringAsync();
            using var document = JsonDocument.Parse(responseContent);

            var completion = document.RootElement
                .GetProperty("candidates")[0]
                .GetProperty("content")
                .GetProperty("parts")[0]
                .GetProperty("text")
                .GetString() ?? string.Empty;

            _logger.LogInformation("Successfully generated chat completion");
            return completion;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to generate chat completion using Gemini");
            throw;
        }
    }

    public string GetModelForTask(AITaskType taskType)
    {
        return taskType switch
        {
            AITaskType.Embedding => _settings.Gemini.DefaultEmbeddingModel,
            AITaskType.Chat => _settings.Gemini.DefaultChatModel,
            AITaskType.OrderProcessing => _settings.Gemini.DefaultChatModel,
            AITaskType.ArticleMatching => _settings.Gemini.DefaultChatModel,
            _ => _settings.Gemini.DefaultChatModel
        };
    }

    public AIProviderType GetCurrentProvider()
    {
        return AIProviderType.Gemini;
    }

    public object GetProviderConfiguration()
    {
        return new
        {
            Provider = "Gemini",
            ApiKey = _settings.Gemini.ApiKey,
            BaseUrl = _settings.Gemini.BaseUrl,
            EmbeddingModel = _settings.Gemini.DefaultEmbeddingModel,
            ChatModel = _settings.Gemini.DefaultChatModel,
            MaxTokens = _settings.Gemini.MaxTokens,
            TimeoutSeconds = _settings.Gemini.TimeoutSeconds,
            GenerationConfig = _settings.Gemini.GenerationConfig
        };
    }
}