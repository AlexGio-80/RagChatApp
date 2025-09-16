using Microsoft.EntityFrameworkCore;
using RagChatApp_Server.Data;
using RagChatApp_Server.DTOs;
using RagChatApp_Server.Models;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace RagChatApp_Server.Services;

/// <summary>
/// Service for Azure OpenAI integration with mock mode support
/// </summary>
public class AzureOpenAIService : IAzureOpenAIService
{
    private readonly ILogger<AzureOpenAIService> _logger;
    private readonly RagChatDbContext _context;
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _configuration;
    private readonly bool _isMockMode;

    public AzureOpenAIService(
        ILogger<AzureOpenAIService> logger,
        RagChatDbContext context,
        HttpClient httpClient,
        IConfiguration configuration)
    {
        _logger = logger;
        _context = context;
        _httpClient = httpClient;
        _configuration = configuration;

        // Check if mock mode is enabled
        _isMockMode = _configuration.GetValue<bool>("MockMode:Enabled", false);

        if (!_isMockMode)
        {
            // Configure HTTP client for Azure OpenAI
            var apiKey = _configuration["AzureOpenAI:ApiKey"];
            var endpoint = _configuration["AzureOpenAI:Endpoint"];

            if (!string.IsNullOrEmpty(apiKey))
            {
                _httpClient.DefaultRequestHeaders.Authorization =
                    new AuthenticationHeaderValue("Bearer", apiKey);
            }

            if (!string.IsNullOrEmpty(endpoint))
            {
                _httpClient.BaseAddress = new Uri(endpoint);
            }
        }

        _logger.LogInformation("AzureOpenAIService initialized in {Mode} mode",
            _isMockMode ? "Mock" : "Connected");
    }

    public bool IsMockMode => _isMockMode;

    /// <summary>
    /// Generates embeddings for text content
    /// </summary>
    public async Task<byte[]> GenerateEmbeddingsAsync(string text)
    {
        _logger.LogInformation("Generating embeddings for text of length: {Length}", text.Length);

        if (_isMockMode)
        {
            return GenerateMockEmbedding(text);
        }

        try
        {
            var requestBody = new
            {
                input = text,
                model = _configuration["AzureOpenAI:EmbeddingModel"] ?? "text-embedding-ada-002"
            };

            var jsonContent = JsonSerializer.Serialize(requestBody);
            var content = new StringContent(jsonContent, Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync("openai/deployments/text-embedding-ada-002/embeddings?api-version=2023-05-15", content);
            response.EnsureSuccessStatusCode();

            var responseJson = await response.Content.ReadAsStringAsync();
            var embeddingResponse = JsonSerializer.Deserialize<JsonElement>(responseJson);

            var embedding = embeddingResponse
                .GetProperty("data")[0]
                .GetProperty("embedding")
                .EnumerateArray()
                .Select(x => x.GetSingle())
                .ToArray();

            return ConvertFloatArrayToByteArray(embedding);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error generating embeddings");
            throw;
        }
    }

    /// <summary>
    /// Finds similar document chunks using vector similarity
    /// </summary>
    public async Task<List<ChatSource>> FindSimilarChunksAsync(string query, int maxResults = 5, double similarityThreshold = 0.7)
    {
        _logger.LogInformation("Finding similar chunks for query: {Query}", query);

        if (_isMockMode)
        {
            return await FindSimilarChunksMockAsync(query, maxResults);
        }

        // Generate embedding for the query
        var queryEmbedding = await GenerateEmbeddingsAsync(query);

        // In a real implementation, you would use vector similarity search
        // For now, we'll use a simple text-based search as fallback
        var chunks = await _context.DocumentChunks
            .Include(c => c.Document)
            .Where(c => c.Content.Contains(query) ||
                       (c.HeaderContext != null && c.HeaderContext.Contains(query)))
            .OrderBy(c => c.DocumentId)  // First order by document
            .ThenBy(c => c.ChunkIndex)   // Then by chunk order within document
            .Take(maxResults)
            .Select(c => new ChatSource
            {
                DocumentId = c.DocumentId,
                DocumentName = c.Document.FileName,
                Content = c.Content,
                HeaderContext = c.HeaderContext,
                SimilarityScore = 0.8 // Mock similarity score
            })
            .ToListAsync();

        return chunks;
    }

    /// <summary>
    /// Generates a chat response using RAG (Retrieval-Augmented Generation)
    /// </summary>
    public async Task<ChatResponse> GenerateChatResponseAsync(ChatRequest request)
    {
        _logger.LogInformation("Generating chat response for message: {Message}", request.Message);

        // Find relevant chunks
        var relevantChunks = await FindSimilarChunksAsync(
            request.Message,
            request.MaxChunks,
            request.SimilarityThreshold);

        if (_isMockMode)
        {
            return GenerateMockChatResponse(request, relevantChunks);
        }

        try
        {
            // Build context from relevant chunks
            var context = BuildContextFromChunks(relevantChunks);

            // Create chat completion request
            var systemMessage = "You are a helpful assistant that answers questions based on the provided context. " +
                               "If the context doesn't contain enough information to answer the question, say so clearly.";

            var userMessage = $"Context:\n{context}\n\nQuestion: {request.Message}";

            var requestBody = new
            {
                messages = new[]
                {
                    new { role = "system", content = systemMessage },
                    new { role = "user", content = userMessage }
                },
                model = _configuration["AzureOpenAI:ChatModel"] ?? "gpt-4",
                max_tokens = 1000,
                temperature = 0.7
            };

            var jsonContent = JsonSerializer.Serialize(requestBody);
            var content = new StringContent(jsonContent, Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync("openai/deployments/gpt-4/chat/completions?api-version=2023-05-15", content);
            response.EnsureSuccessStatusCode();

            var responseJson = await response.Content.ReadAsStringAsync();
            var chatResponse = JsonSerializer.Deserialize<JsonElement>(responseJson);

            var aiResponse = chatResponse
                .GetProperty("choices")[0]
                .GetProperty("message")
                .GetProperty("content")
                .GetString() ?? "I apologize, but I couldn't generate a response.";

            return new ChatResponse
            {
                Response = aiResponse,
                Sources = relevantChunks,
                IsMockResponse = false
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error generating chat response");
            throw;
        }
    }

    private byte[] GenerateMockEmbedding(string text)
    {
        // Generate a deterministic mock embedding based on text hash
        var hash = text.GetHashCode();
        var random = new Random(hash);
        var embedding = new float[1536]; // OpenAI embedding size

        for (int i = 0; i < embedding.Length; i++)
        {
            embedding[i] = (float)(random.NextDouble() * 2 - 1); // Values between -1 and 1
        }

        return ConvertFloatArrayToByteArray(embedding);
    }

    private async Task<List<ChatSource>> FindSimilarChunksMockAsync(string query, int maxResults)
    {
        // Simple text-based search for mock mode
        var chunks = await _context.DocumentChunks
            .Include(c => c.Document)
            .Where(c => c.Content.ToLower().Contains(query.ToLower()) ||
                       (c.HeaderContext != null && c.HeaderContext.ToLower().Contains(query.ToLower())))
            .OrderBy(c => c.DocumentId)  // First order by document
            .ThenBy(c => c.ChunkIndex)   // Then by chunk order within document
            .Take(maxResults)
            .Select(c => new ChatSource
            {
                DocumentId = c.DocumentId,
                DocumentName = c.Document.FileName,
                Content = c.Content,
                HeaderContext = c.HeaderContext,
                SimilarityScore = 0.85 // Mock similarity score
            })
            .ToListAsync();

        return chunks;
    }

    private ChatResponse GenerateMockChatResponse(ChatRequest request, List<ChatSource> sources)
    {
        var response = new StringBuilder();
        response.AppendLine($"Based on the available documents, here's what I found regarding '{request.Message}':");
        response.AppendLine();

        if (sources.Any())
        {
            foreach (var source in sources.Take(2)) // Limit to 2 sources for mock
            {
                if (!string.IsNullOrEmpty(source.HeaderContext))
                {
                    response.AppendLine($"**{source.HeaderContext}**");
                }
                response.AppendLine(source.Content.Length > 200
                    ? source.Content[..200] + "..."
                    : source.Content);
                response.AppendLine($"*(Source: {source.DocumentName})*");
                response.AppendLine();
            }
        }
        else
        {
            response.AppendLine("I couldn't find specific information about your question in the uploaded documents. Please try rephrasing your question or check if relevant documents have been uploaded.");
        }

        return new ChatResponse
        {
            Response = response.ToString(),
            Sources = sources,
            IsMockResponse = true
        };
    }

    private string BuildContextFromChunks(List<ChatSource> chunks)
    {
        var context = new StringBuilder();

        foreach (var chunk in chunks)
        {
            if (!string.IsNullOrEmpty(chunk.HeaderContext))
            {
                context.AppendLine($"Header: {chunk.HeaderContext}");
            }
            context.AppendLine($"Content: {chunk.Content}");
            context.AppendLine($"Source: {chunk.DocumentName}");
            context.AppendLine("---");
        }

        return context.ToString();
    }

    private byte[] ConvertFloatArrayToByteArray(float[] floats)
    {
        var bytes = new byte[floats.Length * 4];
        Buffer.BlockCopy(floats, 0, bytes, 0, bytes.Length);
        return bytes;
    }
}