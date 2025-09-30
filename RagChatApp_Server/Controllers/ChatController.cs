using Microsoft.AspNetCore.Mvc;
using RagChatApp_Server.DTOs;
using RagChatApp_Server.Services;
using RagChatApp_Server.Services.AIProviders;
using RagChatApp_Server.Services.Interfaces;

namespace RagChatApp_Server.Controllers;

/// <summary>
/// Controller for chat interactions with AI using RAG
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class ChatController : ControllerBase
{
    private readonly ILogger<ChatController> _logger;
    private readonly IAzureOpenAIService _aiService;
    private readonly IAIProviderService _aiProvider;

    public ChatController(
        ILogger<ChatController> logger,
        IAzureOpenAIService aiService,
        AIProviderFactory providerFactory)
    {
        _logger = logger;
        _aiService = aiService;
        _aiProvider = providerFactory.CreateProvider();
    }

    /// <summary>
    /// Chat with AI using RAG (Retrieval-Augmented Generation)
    /// </summary>
    /// <param name="request">Chat request with user message and parameters</param>
    /// <returns>AI response with relevant sources</returns>
    [HttpPost]
    [ProducesResponseType(typeof(ChatResponse), 200)]
    [ProducesResponseType(typeof(OperationResponse), 400)]
    public async Task<IActionResult> Chat([FromBody] ChatRequest request)
    {
        _logger.LogInformation("Processing chat request: {Message}", request.Message);

        try
        {
            var response = await _aiService.GenerateChatResponseAsync(request);

            _logger.LogInformation("Chat response generated successfully. Sources: {SourceCount}, Mock: {IsMock}",
                response.Sources.Count, response.IsMockResponse);

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing chat request: {Message}", request.Message);
            return StatusCode(500, new OperationResponse
            {
                Success = false,
                Message = "An error occurred while processing your request"
            });
        }
    }

    /// <summary>
    /// Get information about the AI service configuration
    /// </summary>
    /// <returns>Service configuration information</returns>
    [HttpGet("info")]
    [ProducesResponseType(typeof(object), 200)]
    public IActionResult GetInfo()
    {
        _logger.LogInformation("Getting AI service info");

        var info = new
        {
            IsMockMode = _aiService.IsMockMode,
            ServiceType = _aiService.IsMockMode ? "Mock" : "Azure OpenAI",
            Version = "1.0.0"
        };

        return Ok(info);
    }
}