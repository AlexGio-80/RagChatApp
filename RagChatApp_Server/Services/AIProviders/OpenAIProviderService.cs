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

        // HttpClient is now configured in Program.cs via AddHttpClient
        // Add optional Organization header if configured
        if (!string.IsNullOrEmpty(_settings.OpenAI.OrganizationId))
        {
            _httpClient.DefaultRequestHeaders.Add("OpenAI-Organization", _settings.OpenAI.OrganizationId);
        }
    }

    public async Task<float[]> GenerateEmbeddingAsync(string text, AITaskType taskType = AITaskType.Embedding)
    {
        try
        {
            _logger.LogInformation("Generating embedding using OpenAI for task: {TaskType}", taskType);
            _logger.LogInformation("HttpClient BaseAddress: {BaseAddress}", _httpClient.BaseAddress?.ToString() ?? "NULL!");

            // If BaseAddress is null, configure it here as fallback
            if (_httpClient.BaseAddress == null)
            {
                _logger.LogWarning("HttpClient BaseAddress is NULL! Configuring manually...");
                var baseUrl = _settings.OpenAI.BaseUrl;
                if (!baseUrl.EndsWith("/"))
                {
                    baseUrl += "/";
                }
                _httpClient.BaseAddress = new Uri(baseUrl);
                if (!_httpClient.DefaultRequestHeaders.Contains("Authorization"))
                {
                    _httpClient.DefaultRequestHeaders.Add("Authorization", $"Bearer {_settings.OpenAI.ApiKey}");
                }
            }

            var model = GetModelForTask(taskType);
            _logger.LogInformation("Using model: {Model}, Full URL: {FullUrl}", model, new Uri(_httpClient.BaseAddress, "embeddings"));

            var requestBody = new
            {
                input = text,
                model = model
            };

            var json = JsonSerializer.Serialize(requestBody);
            var content = new StringContent(json, Encoding.UTF8, "application/json");

            var response = await SendWithRetryAsync("embeddings", content);
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

            var response = await SendWithRetryAsync("chat/completions", content);
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

    /// <summary>
    /// Send HTTP request with retry logic for transient failures (502, 503, 429)
    /// </summary>
    private async Task<HttpResponseMessage> SendWithRetryAsync(string endpoint, HttpContent content, int maxRetries = 3)
    {
        var retryDelays = new[] { 1000, 2000, 4000 }; // Exponential backoff: 1s, 2s, 4s

        for (int attempt = 0; attempt < maxRetries; attempt++)
        {
            try
            {
                var response = await _httpClient.PostAsync(endpoint, content);
                _logger.LogInformation("Response status: {StatusCode} (attempt {Attempt}/{Max})",
                    response.StatusCode, attempt + 1, maxRetries);

                // If success or non-retryable error, return immediately
                if (response.IsSuccessStatusCode ||
                    (response.StatusCode != System.Net.HttpStatusCode.BadGateway &&
                     response.StatusCode != System.Net.HttpStatusCode.ServiceUnavailable &&
                     response.StatusCode != System.Net.HttpStatusCode.TooManyRequests))
                {
                    if (!response.IsSuccessStatusCode)
                    {
                        var errorContent = await response.Content.ReadAsStringAsync();
                        _logger.LogError("OpenAI API Error: {StatusCode} - {Content}", response.StatusCode, errorContent);
                    }
                    return response;
                }

                // Log retryable error
                var retryableError = await response.Content.ReadAsStringAsync();
                _logger.LogWarning("Retryable error {StatusCode} on attempt {Attempt}/{Max}: {Error}",
                    response.StatusCode, attempt + 1, maxRetries, retryableError);

                // Wait before retry (except on last attempt)
                if (attempt < maxRetries - 1)
                {
                    var delay = retryDelays[attempt];
                    _logger.LogInformation("Waiting {Delay}ms before retry...", delay);
                    await Task.Delay(delay);
                }
                else
                {
                    // Last attempt failed, return the error response
                    return response;
                }
            }
            catch (HttpRequestException ex) when (attempt < maxRetries - 1)
            {
                _logger.LogWarning(ex, "Network error on attempt {Attempt}/{Max}, retrying...", attempt + 1, maxRetries);
                await Task.Delay(retryDelays[attempt]);
            }
        }

        // Should not reach here, but return a failed response as fallback
        throw new HttpRequestException("Max retry attempts exceeded");
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