using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RagChatApp_Server.Data;
using RagChatApp_Server.DTOs;
using RagChatApp_Server.Models;
using RagChatApp_Server.Services;

namespace RagChatApp_Server.Controllers;

/// <summary>
/// Controller for document management operations
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class DocumentsController : ControllerBase
{
    private readonly ILogger<DocumentsController> _logger;
    private readonly RagChatDbContext _context;
    private readonly IDocumentProcessingService _documentService;
    private readonly IAzureOpenAIService _aiService;

    public DocumentsController(
        ILogger<DocumentsController> logger,
        RagChatDbContext context,
        IDocumentProcessingService documentService,
        IAzureOpenAIService aiService)
    {
        _logger = logger;
        _context = context;
        _documentService = documentService;
        _aiService = aiService;
    }

    /// <summary>
    /// Upload and process a document file
    /// </summary>
    /// <param name="request">Document upload request containing the file</param>
    /// <returns>Document processing result</returns>
    [HttpPost("upload")]
    [ProducesResponseType(typeof(DocumentResponse), 200)]
    [ProducesResponseType(typeof(OperationResponse), 400)]
    public async Task<IActionResult> UploadDocument([FromForm] DocumentUploadRequest request)
    {
        _logger.LogInformation("Uploading document: {FileName}", request.File.FileName);

        try
        {
            // Validate file type
            if (!_documentService.IsSupportedFileType(request.File.ContentType))
            {
                return BadRequest(new OperationResponse
                {
                    Success = false,
                    Message = $"File type {request.File.ContentType} is not supported"
                });
            }

            // Extract text content
            var content = await _documentService.ExtractTextAsync(request.File);

            // Create document record
            var document = new Document
            {
                FileName = request.File.FileName,
                ContentType = request.File.ContentType,
                Size = request.File.Length,
                Content = content,
                Status = "Processing"
            };

            _context.Documents.Add(document);
            await _context.SaveChangesAsync();

            // Process document in background
            _ = Task.Run(async () => await ProcessDocumentAsync(document.Id));

            var response = new DocumentResponse
            {
                Id = document.Id,
                FileName = document.FileName,
                ContentType = document.ContentType,
                Size = document.Size,
                Status = document.Status,
                UploadedAt = document.UploadedAt,
                ChunkCount = 0
            };

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error uploading document: {FileName}", request.File.FileName);
            return StatusCode(500, new OperationResponse
            {
                Success = false,
                Message = "An error occurred while processing the document"
            });
        }
    }

    /// <summary>
    /// Index text content directly without file upload
    /// </summary>
    /// <param name="request">Text indexing request</param>
    /// <returns>Document processing result</returns>
    [HttpPost("index-text")]
    [ProducesResponseType(typeof(DocumentResponse), 200)]
    [ProducesResponseType(typeof(OperationResponse), 400)]
    public async Task<IActionResult> IndexText([FromBody] IndexTextRequest request)
    {
        _logger.LogInformation("Indexing text: {Title}", request.Title);

        try
        {
            // Create document record
            var document = new Document
            {
                FileName = $"{request.Title}.txt",
                ContentType = "text/plain",
                Size = request.Content.Length,
                Content = request.Content,
                Status = "Processing"
            };

            _context.Documents.Add(document);
            await _context.SaveChangesAsync();

            // Process document in background
            _ = Task.Run(async () => await ProcessDocumentAsync(document.Id));

            var response = new DocumentResponse
            {
                Id = document.Id,
                FileName = document.FileName,
                ContentType = document.ContentType,
                Size = document.Size,
                Status = document.Status,
                UploadedAt = document.UploadedAt,
                ChunkCount = 0
            };

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error indexing text: {Title}", request.Title);
            return StatusCode(500, new OperationResponse
            {
                Success = false,
                Message = "An error occurred while processing the text"
            });
        }
    }

    /// <summary>
    /// Get list of all documents
    /// </summary>
    /// <returns>List of documents with metadata</returns>
    [HttpGet]
    [ProducesResponseType(typeof(List<DocumentResponse>), 200)]
    public async Task<IActionResult> GetDocuments()
    {
        _logger.LogInformation("Retrieving all documents");

        try
        {
            var documents = await _context.Documents
                .Include(d => d.Chunks)
                .Select(d => new DocumentResponse
                {
                    Id = d.Id,
                    FileName = d.FileName,
                    ContentType = d.ContentType,
                    Size = d.Size,
                    Status = d.Status,
                    UploadedAt = d.UploadedAt,
                    ProcessedAt = d.ProcessedAt,
                    ChunkCount = d.Chunks.Count
                })
                .OrderByDescending(d => d.UploadedAt)
                .ToListAsync();

            return Ok(documents);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving documents");
            return StatusCode(500, new OperationResponse
            {
                Success = false,
                Message = "An error occurred while retrieving documents"
            });
        }
    }

    /// <summary>
    /// Update an existing document
    /// </summary>
    /// <param name="id">Document ID</param>
    /// <param name="request">Updated document content</param>
    /// <returns>Updated document information</returns>
    [HttpPut("{id}")]
    [ProducesResponseType(typeof(DocumentResponse), 200)]
    [ProducesResponseType(typeof(OperationResponse), 404)]
    public async Task<IActionResult> UpdateDocument(int id, [FromBody] IndexTextRequest request)
    {
        _logger.LogInformation("Updating document: {Id}", id);

        try
        {
            var document = await _context.Documents.FindAsync(id);
            if (document == null)
            {
                return NotFound(new OperationResponse
                {
                    Success = false,
                    Message = "Document not found"
                });
            }

            // Update document content
            document.Content = request.Content;
            document.Status = "Processing";
            document.ProcessedAt = null;

            // Remove existing chunks
            var existingChunks = await _context.DocumentChunks
                .Where(c => c.DocumentId == id)
                .ToListAsync();
            _context.DocumentChunks.RemoveRange(existingChunks);

            await _context.SaveChangesAsync();

            // Process document in background
            _ = Task.Run(async () => await ProcessDocumentAsync(document.Id));

            var response = new DocumentResponse
            {
                Id = document.Id,
                FileName = document.FileName,
                ContentType = document.ContentType,
                Size = document.Size,
                Status = document.Status,
                UploadedAt = document.UploadedAt,
                ProcessedAt = document.ProcessedAt,
                ChunkCount = 0
            };

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating document: {Id}", id);
            return StatusCode(500, new OperationResponse
            {
                Success = false,
                Message = "An error occurred while updating the document"
            });
        }
    }

    /// <summary>
    /// Delete a document and all its chunks
    /// </summary>
    /// <param name="id">Document ID</param>
    /// <returns>Operation result</returns>
    [HttpDelete("{id}")]
    [ProducesResponseType(typeof(OperationResponse), 200)]
    [ProducesResponseType(typeof(OperationResponse), 404)]
    public async Task<IActionResult> DeleteDocument(int id)
    {
        _logger.LogInformation("Deleting document: {Id}", id);

        try
        {
            var document = await _context.Documents.FindAsync(id);
            if (document == null)
            {
                return NotFound(new OperationResponse
                {
                    Success = false,
                    Message = "Document not found"
                });
            }

            _context.Documents.Remove(document);
            await _context.SaveChangesAsync();

            return Ok(new OperationResponse
            {
                Success = true,
                Message = "Document deleted successfully"
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting document: {Id}", id);
            return StatusCode(500, new OperationResponse
            {
                Success = false,
                Message = "An error occurred while deleting the document"
            });
        }
    }

    /// <summary>
    /// Background processing of document chunks and embeddings
    /// </summary>
    private async Task ProcessDocumentAsync(int documentId)
    {
        try
        {
            _logger.LogInformation("Starting background processing for document: {DocumentId}", documentId);

            var document = await _context.Documents.FindAsync(documentId);
            if (document == null)
            {
                _logger.LogWarning("Document not found for processing: {DocumentId}", documentId);
                return;
            }

            // Create chunks
            var chunks = await _documentService.CreateChunksAsync(document.Content);

            // Generate embeddings for each chunk
            foreach (var chunk in chunks)
            {
                chunk.DocumentId = documentId;
                chunk.Embedding = await _aiService.GenerateEmbeddingsAsync(chunk.Content);
            }

            // Save chunks to database
            _context.DocumentChunks.AddRange(chunks);

            // Update document status
            document.Status = "Completed";
            document.ProcessedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            _logger.LogInformation("Completed processing for document: {DocumentId}, Chunks: {ChunkCount}",
                documentId, chunks.Count);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing document: {DocumentId}", documentId);

            // Update document status to failed
            var document = await _context.Documents.FindAsync(documentId);
            if (document != null)
            {
                document.Status = "Failed";
                await _context.SaveChangesAsync();
            }
        }
    }
}