using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using RagChatApp_Server.Models;
using RagChatApp_Server.Services;
using RagChatApp_Server.Services.Interfaces;

namespace RagChatApp_Server.Controllers;

/// <summary>
/// Controller for AI provider management and testing
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class AIProviderController : ControllerBase
{
    private readonly AIProviderFactory _factory;
    private readonly AIProviderSettings _settings;
    private readonly ILogger<AIProviderController> _logger;

    public AIProviderController(
        AIProviderFactory factory,
        IOptions<AIProviderSettings> settings,
        ILogger<AIProviderController> logger)
    {
        _factory = factory;
        _settings = settings.Value;
        _logger = logger;
    }

    /// <summary>
    /// Get information about available AI providers
    /// </summary>
    [HttpGet("info")]
    public ActionResult<object> GetProvidersInfo()
    {
        try
        {
            _logger.LogInformation("Getting AI providers information");

            var availableProviders = _factory.GetAvailableProviders();
            var defaultProvider = _factory.GetDefaultProvider();

            return Ok(new
            {
                DefaultProvider = defaultProvider.ToString(),
                AvailableProviders = availableProviders.Select(p => new
                {
                    Name = p.ToString(),
                    IsConfigured = _factory.IsProviderConfigured(p),
                    IsDefault = p == defaultProvider
                }).ToArray(),
                Configuration = new
                {
                    OrderProcessingModel = _settings.OrderProcessingModel,
                    ArticleMatchingModel = _settings.ArticleMatchingModel,
                    EmbeddingModel = _settings.EmbeddingModel,
                    ChatModel = _settings.ChatModel
                }
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting AI providers information");
            return StatusCode(500, new { Error = "Failed to get providers information" });
        }
    }

    /// <summary>
    /// Test embedding generation with default provider
    /// </summary>
    [HttpPost("test/embedding")]
    public async Task<ActionResult<object>> TestEmbedding([FromBody] TestEmbeddingRequest request)
    {
        try
        {
            _logger.LogInformation("Testing embedding generation with text: {Text}", request.Text);

            var provider = _factory.CreateProvider(request.ProviderType);
            var embedding = await provider.GenerateEmbeddingAsync(request.Text, request.TaskType);

            return Ok(new
            {
                Provider = provider.GetCurrentProvider().ToString(),
                Model = provider.GetModelForTask(request.TaskType),
                EmbeddingDimensions = embedding.Length,
                Success = true,
                Embedding = request.IncludeEmbedding ? embedding : null
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error testing embedding generation");
            return StatusCode(500, new { Error = ex.Message, Success = false });
        }
    }

    /// <summary>
    /// Test chat completion with specified provider
    /// </summary>
    [HttpPost("test/chat")]
    public async Task<ActionResult<object>> TestChat([FromBody] TestChatRequest request)
    {
        try
        {
            _logger.LogInformation("Testing chat completion with provider: {Provider}", request.ProviderType);

            var provider = _factory.CreateProvider(request.ProviderType);
            var response = await provider.GenerateChatCompletionAsync(
                request.Messages,
                request.MaxTokens,
                request.Temperature,
                request.TaskType);

            return Ok(new
            {
                Provider = provider.GetCurrentProvider().ToString(),
                Model = provider.GetModelForTask(request.TaskType),
                Response = response,
                Success = true
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error testing chat completion");
            return StatusCode(500, new { Error = ex.Message, Success = false });
        }
    }

    /// <summary>
    /// Get provider configuration for stored procedures
    /// </summary>
    [HttpGet("configuration/{providerType}")]
    public ActionResult<object> GetProviderConfiguration(AIProviderType providerType)
    {
        try
        {
            _logger.LogInformation("Getting configuration for provider: {Provider}", providerType);

            if (!_factory.IsProviderConfigured(providerType))
            {
                return BadRequest(new { Error = $"Provider {providerType} is not configured" });
            }

            var provider = _factory.CreateProvider(providerType);
            var configuration = provider.GetProviderConfiguration();

            return Ok(configuration);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting provider configuration");
            return StatusCode(500, new { Error = ex.Message });
        }
    }

    /// <summary>
    /// Test all configured providers
    /// </summary>
    [HttpPost("test/all")]
    public async Task<ActionResult<object>> TestAllProviders([FromBody] string testText = "Hello, this is a test.")
    {
        try
        {
            _logger.LogInformation("Testing all configured providers");

            var availableProviders = _factory.GetAvailableProviders();
            var results = new List<object>();

            foreach (var providerType in availableProviders)
            {
                try
                {
                    var provider = _factory.CreateProvider(providerType);
                    var embedding = await provider.GenerateEmbeddingAsync(testText);

                    results.Add(new
                    {
                        Provider = providerType.ToString(),
                        Success = true,
                        EmbeddingDimensions = embedding.Length,
                        Model = provider.GetModelForTask(AITaskType.Embedding),
                        Error = (string?)null
                    });
                }
                catch (Exception ex)
                {
                    results.Add(new
                    {
                        Provider = providerType.ToString(),
                        Success = false,
                        EmbeddingDimensions = 0,
                        Model = (string?)null,
                        Error = ex.Message
                    });
                }
            }

            return Ok(new
            {
                TestText = testText,
                Results = results,
                TotalProviders = availableProviders.Count,
                SuccessfulProviders = results.Count(r => (bool)r.GetType().GetProperty("Success")!.GetValue(r)!)
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error testing all providers");
            return StatusCode(500, new { Error = ex.Message });
        }
    }
}

/// <summary>
/// Request model for testing embedding generation
/// </summary>
public class TestEmbeddingRequest
{
    public string Text { get; set; } = string.Empty;
    public AIProviderType? ProviderType { get; set; }
    public AITaskType TaskType { get; set; } = AITaskType.Embedding;
    public bool IncludeEmbedding { get; set; } = false;
}

/// <summary>
/// Request model for testing chat completion
/// </summary>
public class TestChatRequest
{
    public List<ChatMessage> Messages { get; set; } = new();
    public AIProviderType? ProviderType { get; set; }
    public AITaskType TaskType { get; set; } = AITaskType.Chat;
    public int? MaxTokens { get; set; }
    public float Temperature { get; set; } = 0.1f;
}