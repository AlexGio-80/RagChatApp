using Microsoft.EntityFrameworkCore;
using RagChatApp_Server.Data;
using RagChatApp_Server.DTOs;
using RagChatApp_Server.Models;
using RagChatApp_Server.Services.AIProviders;
using RagChatApp_Server.Services.Interfaces;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace RagChatApp_Server.Services;

/// <summary>
/// Service for AI integration with RAG support using multi-provider system
/// </summary>
public class AzureOpenAIService : IAzureOpenAIService
{
    private readonly ILogger<AzureOpenAIService> _logger;
    private readonly RagChatDbContext _context;
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _configuration;
    private readonly IServiceProvider _serviceProvider;
    private readonly IAIProviderService _aiProvider;
    private readonly bool _isMockMode;

    public AzureOpenAIService(
        ILogger<AzureOpenAIService> logger,
        RagChatDbContext context,
        HttpClient httpClient,
        IConfiguration configuration,
        IServiceProvider serviceProvider,
        AIProviderFactory providerFactory)
    {
        _logger = logger;
        _context = context;
        _httpClient = httpClient;
        _configuration = configuration;
        _serviceProvider = serviceProvider;
        _aiProvider = providerFactory.CreateProvider();

        // Check if mock mode is enabled
        _isMockMode = _configuration.GetValue<bool>("MockMode:Enabled", false);

        _logger.LogInformation("RAG Service initialized in {Mode} mode using provider: {Provider}",
            _isMockMode ? "Mock" : "Connected",
            _aiProvider.GetCurrentProvider());
    }

    public bool IsMockMode => _isMockMode;

    /// <summary>
    /// Generates embeddings for text content using configured AI provider
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
            // Use configured AI provider (OpenAI, Gemini, or Azure OpenAI)
            var embedding = await _aiProvider.GenerateEmbeddingAsync(text, AITaskType.Embedding);

            // Convert float array to byte array for database storage
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

        // Get configuration for max chunks
        var configuration = _serviceProvider.GetRequiredService<IConfiguration>();
        var ragSettings = configuration.GetSection("RagSettings").Get<RagSettings>() ?? new RagSettings();
        var effectiveMaxResults = Math.Min(maxResults, ragSettings.GetEffectiveMaxChunks());

        // Clean old cache entries (older than 1 hour)
        await CleanSemanticCacheAsync();

        // Check semantic cache first
        var cachedResult = await CheckSemanticCacheAsync(query);
        if (cachedResult != null)
        {
            _logger.LogInformation("Found cached result for query: {Query}", query);
            return new List<ChatSource> { cachedResult };
        }

        // Generate embedding for the query
        var queryEmbedding = await GenerateEmbeddingsAsync(query);

        // Perform multi-field vector search using SQL with LEAST function
        var results = await PerformMultiFieldVectorSearchAsync(queryEmbedding, effectiveMaxResults);

        // Cache the best result for future searches
        if (results.Any())
        {
            await CacheSemanticResultAsync(query, results.First());
        }

        _logger.LogInformation("Found {ResultCount} similar chunks for query: {Query}", results.Count, query);
        return results;
    }

    /// <summary>
    /// Generates a chat response using RAG (Retrieval-Augmented Generation)
    /// </summary>
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

            // Create chat completion request using configured AI provider
            var systemMessage = "You are a helpful assistant that answers questions based on the provided context. " +
                               "If the context doesn't contain enough information to answer the question, say so clearly.";

            var userMessage = $"Context:\n{context}\n\nQuestion: {request.Message}";

            var messages = new List<ChatMessage>
            {
                new ChatMessage { Role = "system", Content = systemMessage },
                new ChatMessage { Role = "user", Content = userMessage }
            };

            // Use configured AI provider for chat completion
            var aiResponse = await _aiProvider.GenerateChatCompletionAsync(
                messages,
                maxTokens: 1000,
                temperature: 0.7f,
                taskType: AITaskType.Chat);

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
        var embedding = new float[1536]; // text-embedding-3-small uses 1536 dimensions

        for (int i = 0; i < embedding.Length; i++)
        {
            embedding[i] = (float)(random.NextDouble() * 2 - 1); // Values between -1 and 1
        }

        return ConvertFloatArrayToByteArray(embedding);
    }

    private async Task<List<ChatSource>> FindSimilarChunksMockAsync(string query, int maxResults)
    {
        // Extract meaningful keywords from query
        var keywords = ExtractKeywords(query);
        
        // Improved text-based search for mock mode
        var chunks = await _context.DocumentChunks
            .Include(c => c.Document)
            .Where(c => 
                // Full phrase match (highest priority)
                c.Content.ToLower().Contains(query.ToLower()) ||
                (c.HeaderContext != null && c.HeaderContext.ToLower().Contains(query.ToLower())) ||
                // Keyword matching (fallback)
                keywords.Any(keyword => 
                    c.Content.ToLower().Contains(keyword.ToLower()) ||
                    (c.HeaderContext != null && c.HeaderContext.ToLower().Contains(keyword.ToLower()))
                )
            )
            .OrderBy(c => c.DocumentId)  // First order by document
            .ThenBy(c => c.ChunkIndex)   // Then by chunk order within document
            .Take(maxResults)
            .ToListAsync();

        // Calculate relevance scores after database query
        var result = chunks.Select(c => new ChatSource
        {
            DocumentId = c.DocumentId,
            DocumentName = c.Document.FileName,
            DocumentPath = c.Document.Path,
            Content = c.Content,
            HeaderContext = c.HeaderContext,
            Notes = c.Notes,
            Details = c.Details,
            SimilarityScore = CalculateRelevanceScore(c, query, keywords)
        }).ToList();

        return result;
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

    private float[] ConvertByteArrayToFloatArray(byte[] bytes)
    {
        var floats = new float[bytes.Length / 4];
        Buffer.BlockCopy(bytes, 0, floats, 0, bytes.Length);
        return floats;
    }

    private double CosineSimilarity(float[] vectorA, float[] vectorB)
    {
        if (vectorA.Length != vectorB.Length)
            throw new ArgumentException("Vectors must have the same length");

        double dotProduct = 0;
        double magnitudeA = 0;
        double magnitudeB = 0;

        for (int i = 0; i < vectorA.Length; i++)
        {
            dotProduct += vectorA[i] * vectorB[i];
            magnitudeA += vectorA[i] * vectorA[i];
            magnitudeB += vectorB[i] * vectorB[i];
        }

        if (magnitudeA == 0 || magnitudeB == 0)
            return 0;

        return dotProduct / (Math.Sqrt(magnitudeA) * Math.Sqrt(magnitudeB));
    }

    /// <summary>
    /// Extract meaningful keywords from search query
    /// </summary>
    private List<string> ExtractKeywords(string query)
    {
        if (string.IsNullOrWhiteSpace(query))
            return new List<string>();

        // Common stop words to filter out
        var stopWords = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "the", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by", "from",
            "as", "is", "was", "are", "were", "be", "been", "have", "has", "had", "do", "does",
            "did", "will", "would", "should", "could", "can", "may", "might", "a", "an", "that",
            "this", "these", "those", "what", "which", "who", "when", "where", "why", "how",
            "quali", "sono", "che", "cosa", "come", "dove", "quando", "perché", "per", "con",
            "di", "da", "su", "in", "il", "la", "lo", "le", "gli", "una", "un", "dei", "delle"
        };

        // Split query into words and filter
        var keywords = query
            .Split(new char[] { ' ', ',', '.', '!', '?', ';', ':', '\t', '\n' }, StringSplitOptions.RemoveEmptyEntries)
            .Where(word => word.Length > 2 && !stopWords.Contains(word))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();

        return keywords;
    }

    /// <summary>
    /// Calculate relevance score for a chunk based on query matching
    /// </summary>
    private async Task CleanSemanticCacheAsync()
    {
        var oneHourAgo = DateTime.UtcNow.AddHours(-1);
        var oldEntries = await _context.SemanticCache
            .Where(sc => sc.CreatedAt < oneHourAgo)
            .ToListAsync();

        if (oldEntries.Any())
        {
            _context.SemanticCache.RemoveRange(oldEntries);
            await _context.SaveChangesAsync();
            _logger.LogInformation("Cleaned {Count} old semantic cache entries", oldEntries.Count);
        }
    }

    private async Task<ChatSource?> CheckSemanticCacheAsync(string query)
    {
        var cacheEntry = await _context.SemanticCache
            .Where(sc => sc.SearchQuery == query)
            .OrderByDescending(sc => sc.CreatedAt)
            .FirstOrDefaultAsync();

        if (cacheEntry != null)
        {
            return new ChatSource
            {
                Content = cacheEntry.ResultContent,
                SimilarityScore = 1.0 // Cached results are considered perfect matches
            };
        }

        return null;
    }

    private async Task CacheSemanticResultAsync(string query, ChatSource bestResult)
    {
        try
        {
            var embedding = await GenerateEmbeddingsAsync(bestResult.Content);
            var cacheEntry = new SemanticCache
            {
                SearchQuery = query,
                ResultContent = bestResult.Content,
                ResultEmbedding = embedding,
                CreatedAt = DateTime.UtcNow
            };

            _context.SemanticCache.Add(cacheEntry);
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to cache semantic result for query: {Query}", query);
        }
    }

    private async Task<List<ChatSource>> PerformMultiFieldVectorSearchAsync(byte[] queryEmbedding, int maxResults)
    {
        try
        {
            // Convert byte[] to float[] for comparison
            var queryVector = ConvertByteArrayToFloatArray(queryEmbedding);

            // Get all chunks with their embeddings
            var chunks = await _context.DocumentChunks
                .Include(c => c.Document)
                .Include(c => c.ContentEmbedding)
                .Include(c => c.HeaderContextEmbedding)
                .Include(c => c.NotesEmbedding)
                .Include(c => c.DetailsEmbedding)
                .Where(c => c.ContentEmbedding != null ||
                           c.HeaderContextEmbedding != null ||
                           c.NotesEmbedding != null ||
                           c.DetailsEmbedding != null)
                .ToListAsync();

            // Calculate similarity scores in memory using cosine similarity
            var scoredChunks = new List<(DocumentChunk chunk, double score)>();

            foreach (var chunk in chunks)
            {
                var similarities = new List<double>();

                // Check Content embedding
                if (chunk.ContentEmbedding != null)
                {
                    var embVector = ConvertByteArrayToFloatArray(chunk.ContentEmbedding.Embedding);
                    similarities.Add(CosineSimilarity(queryVector, embVector));
                }

                // Check HeaderContext embedding
                if (chunk.HeaderContextEmbedding != null)
                {
                    var embVector = ConvertByteArrayToFloatArray(chunk.HeaderContextEmbedding.Embedding);
                    similarities.Add(CosineSimilarity(queryVector, embVector));
                }

                // Check Notes embedding
                if (chunk.NotesEmbedding != null)
                {
                    var embVector = ConvertByteArrayToFloatArray(chunk.NotesEmbedding.Embedding);
                    similarities.Add(CosineSimilarity(queryVector, embVector));
                }

                // Check Details embedding
                if (chunk.DetailsEmbedding != null)
                {
                    var embVector = ConvertByteArrayToFloatArray(chunk.DetailsEmbedding.Embedding);
                    similarities.Add(CosineSimilarity(queryVector, embVector));
                }

                // Use maximum similarity across all fields
                if (similarities.Any())
                {
                    scoredChunks.Add((chunk, similarities.Max()));
                }
            }

            // Sort by similarity (highest first) and take top results
            var topChunks = scoredChunks
                .OrderByDescending(x => x.score)
                .Take(maxResults)
                .ToList();

            _logger.LogInformation("Vector search found {Count} chunks, top score: {TopScore:F3}",
                topChunks.Count,
                topChunks.FirstOrDefault().score);

            return topChunks.Select(x => new ChatSource
            {
                DocumentId = x.chunk.DocumentId,
                DocumentName = x.chunk.Document.FileName,
                DocumentPath = x.chunk.Document.Path,
                Content = x.chunk.Content,
                HeaderContext = x.chunk.HeaderContext,
                Notes = x.chunk.Notes,
                Details = x.chunk.Details,
                SimilarityScore = x.score
            }).ToList();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error in vector search, falling back to text search");
            return await FallbackTextSearchAsync(maxResults);
        }
    }

    private async Task<List<ChatSource>> FallbackTextSearchAsync(int maxResults)
    {
        // Simplified fallback search using existing logic
        var chunks = await _context.DocumentChunks
            .Include(c => c.Document)
            .OrderBy(c => c.DocumentId)
            .ThenBy(c => c.ChunkIndex)
            .Take(maxResults)
            .ToListAsync();

        return chunks.Select(c => new ChatSource
        {
            DocumentId = c.DocumentId,
            DocumentName = c.Document.FileName,
            DocumentPath = c.Document.Path,
            Content = c.Content,
            HeaderContext = c.HeaderContext,
            Notes = c.Notes,
            Details = c.Details,
            SimilarityScore = 0.8 // Default similarity for fallback
        }).ToList();
    }

    private double CalculateRelevanceScore(DocumentChunk chunk, string originalQuery, List<string> keywords)
    {
        double score = 0.5; // Base score

        var content = (chunk.Content ?? "").ToLower();
        var header = (chunk.HeaderContext ?? "").ToLower();
        var query = originalQuery.ToLower();

        // Exact phrase match in header gets highest score
        if (header.Contains(query))
            score = 0.95;
        // Exact phrase match in content gets high score
        else if (content.Contains(query))
            score = 0.9;
        else
        {
            // Calculate score based on keyword matches
            int headerMatches = keywords.Count(k => header.Contains(k.ToLower()));
            int contentMatches = keywords.Count(k => content.Contains(k.ToLower()));
            
            // Header matches are weighted more heavily
            double keywordScore = (headerMatches * 0.3 + contentMatches * 0.1) / Math.Max(keywords.Count, 1);
            score = Math.Max(score, 0.6 + keywordScore);
        }

        return Math.Min(score, 0.99); // Cap at 0.99
    }
}