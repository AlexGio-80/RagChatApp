# RAG Chat Application - Stored Procedures Documentation

This directory contains SQL Server stored procedures that provide a complete SQL interface for the RAG Chat Application, allowing all operations to be performed directly from SQL without using the REST API.

## 🗂️ Files Overview

| File | Description |
|------|-------------|
| `00_InstallAllStoredProcedures.sql` | Master installation script |
| `01_DocumentsCRUD.sql` | Documents CRUD operations |
| `02_DocumentChunksCRUD.sql` | DocumentChunks and Embeddings CRUD with auto-generation |
| `03_RAGSearchProcedure.sql` | RAG search with column response |
| `04_SemanticCacheManagement.sql` | Semantic cache management |
| `05_OpenAIEmbeddingIntegration.sql` | OpenAI API embedding generation via REST |

## 🚀 Installation

1. **Prerequisites**: Ensure Entity Framework migrations are applied first
2. **Run Installation**: Execute the master script in SQL Server Management Studio:
   ```sql
   -- Update the USE statement with your database name
   USE [YourDatabaseName]
   GO
   :r "00_InstallAllStoredProcedures.sql"
   ```

## 📋 Available Stored Procedures

### Documents CRUD Operations

#### `SP_InsertDocument`
Insert a new document with automatic timestamp.
```sql
DECLARE @DocumentId INT;
EXEC SP_InsertDocument
    @FileName = 'example.pdf',
    @ContentType = 'application/pdf',
    @Size = 1024000,
    @Content = 'Extracted document content...',
    @Path = '/documents/example.pdf',
    @Status = 'Pending',
    @DocumentId = @DocumentId OUTPUT;

SELECT @DocumentId as NewDocumentId;
```

#### `SP_GetDocument`
Retrieve a document by ID.
```sql
EXEC SP_GetDocument @DocumentId = 1;
```

#### `SP_GetAllDocuments`
Retrieve documents with pagination and filtering.
```sql
-- Get first page of completed documents
EXEC SP_GetAllDocuments
    @PageNumber = 1,
    @PageSize = 10,
    @Status = 'Completed';
```

#### `SP_UpdateDocument`
Update document properties. **Note**: Updating content deletes all chunks and resets to 'Pending'.
```sql
EXEC SP_UpdateDocument
    @DocumentId = 1,
    @Status = 'Completed',
    @ProcessedAt = GETUTCDATE();
```

#### `SP_DeleteDocument`
Delete document and all related chunks/embeddings (cascade delete).
```sql
EXEC SP_DeleteDocument @DocumentId = 1;
```

### DocumentChunks and Embeddings CRUD

#### `SP_InsertDocumentChunk` (ENHANCED)
Create a document chunk with automatic embedding generation via OpenAI API.
```sql
DECLARE @ChunkId INT;
-- Auto-generate embeddings (default behavior)
EXEC SP_InsertDocumentChunk
    @DocumentId = 1,
    @ChunkIndex = 0,
    @Content = 'This is the first chunk of content...',
    @HeaderContext = 'Introduction',
    @Notes = 'Important section',
    @Details = '{"author": "John Doe", "tags": ["AI", "ML"]}',
    @ApiKey = 'your-openai-api-key', -- Optional, will use mock if not provided
    @EmbeddingModel = 'text-embedding-3-small', -- Optional, default model
    @AutoGenerateEmbeddings = 1, -- Optional, default is 1 (true)
    @ChunkId = @ChunkId OUTPUT;

-- Skip embedding generation for manual control
EXEC SP_InsertDocumentChunk
    @DocumentId = 1,
    @ChunkIndex = 0,
    @Content = 'Content without embeddings...',
    @AutoGenerateEmbeddings = 0, -- Skip automatic embedding generation
    @ChunkId = @ChunkId OUTPUT;
```

#### `SP_GetDocumentChunks`
Retrieve all chunks for a document.
```sql
-- Get chunks without embedding data (lighter)
EXEC SP_GetDocumentChunks @DocumentId = 1, @IncludeEmbeddings = 0;

-- Get chunks with embedding data
EXEC SP_GetDocumentChunks @DocumentId = 1, @IncludeEmbeddings = 1;
```

#### `SP_UpdateDocumentChunk` (ENHANCED)
Update chunk content with automatic embedding regeneration.
```sql
-- Auto-regenerate embeddings after content update (default)
EXEC SP_UpdateDocumentChunk
    @ChunkId = 1,
    @Content = 'Updated chunk content',
    @Notes = 'Updated notes',
    @ApiKey = 'your-openai-api-key', -- Optional
    @AutoGenerateEmbeddings = 1; -- Default behavior

-- Update content without regenerating embeddings
EXEC SP_UpdateDocumentChunk
    @ChunkId = 1,
    @Content = 'Updated content',
    @AutoGenerateEmbeddings = 0; -- Skip embedding regeneration
```

#### `SP_DeleteDocumentChunk`
Delete a chunk and all its embeddings.
```sql
EXEC SP_DeleteDocumentChunk @ChunkId = 1;
```

### RAG Search Operations

#### `SP_RAGSearch` (ENHANCED)
Perform multi-field vector search with column-based results.
```sql
-- Search with query embedding
DECLARE @QueryEmbedding VARBINARY(MAX) = 0x1234....; -- Your query embedding
EXEC SP_RAGSearch
    @QueryEmbedding = @QueryEmbedding,
    @MaxResults = 10,
    @SimilarityThreshold = 0.7,
    @SearchQuery = 'machine learning algorithms';
```

**Column Response Format** (instead of JSON):
```
Id | HeaderContext | Content | Notes | Details | SimilarityScore | FileName | FilePath | Source
1  | Machine Learning Basics | Machine learning is... | Key concepts | {"topic":"AI"} | 85.5 | ml_guide.pdf | /docs/ml_guide.pdf | VectorSearch
0  | NULL | Cached result... | NULL | NULL | 100.0 | Cached Result | NULL | SemanticCache
```

This change makes it easier to consume results from external applications and provides better performance.

#### `SP_RAGSearchWithVectorDistance`
Advanced search using actual vector distance functions (if supported by SQL Server).
```sql
EXEC SP_RAGSearchWithVectorDistance
    @QueryEmbedding = @QueryEmbedding,
    @MaxResults = 5,
    @SearchQuery = 'neural networks';
```

### Semantic Cache Management

#### `SP_CleanSemanticCache`
Remove old cache entries.
```sql
-- Clean entries older than 1 hour (default)
EXEC SP_CleanSemanticCache;

-- Clean entries older than 2 hours
EXEC SP_CleanSemanticCache @MaxAgeHours = 2;
```

#### `SP_GetSemanticCacheStats`
Get cache statistics and analysis.
```sql
EXEC SP_GetSemanticCacheStats;
```

#### `SP_SearchSemanticCache`
Search in semantic cache.
```sql
-- Exact match
EXEC SP_SearchSemanticCache
    @SearchQuery = 'machine learning',
    @ExactMatch = 1;

-- Fuzzy match
EXEC SP_SearchSemanticCache
    @SearchQuery = 'learning',
    @ExactMatch = 0;
```

#### `SP_AddToSemanticCache`
Manually add cache entry.
```sql
EXEC SP_AddToSemanticCache
    @SearchQuery = 'deep learning',
    @ResultContent = 'Deep learning is a subset of machine learning...',
    @ResultEmbedding = 0x1234....,
    @OverwriteExisting = 1;
```

#### `SP_DeleteFromSemanticCache`
Delete cache entries.
```sql
-- Delete specific query
EXEC SP_DeleteFromSemanticCache @SearchQuery = 'old query';

-- Delete by ID
EXEC SP_DeleteFromSemanticCache @CacheId = 5;

-- Delete all cache
EXEC SP_DeleteFromSemanticCache @DeleteAll = 1;
```

### OpenAI Embedding Integration (NEW)

#### `SP_GenerateEmbedding`
Generate a single embedding via OpenAI API using `sp_invoke_external_rest_endpoint`.
```sql
DECLARE @EmbeddingResult VARBINARY(MAX);
EXEC SP_GenerateEmbedding
    @Text = 'Text to generate embedding for',
    @ApiKey = 'your-openai-api-key',
    @EmbeddingModel = 'text-embedding-3-small', -- Optional, default model
    @Embedding = @EmbeddingResult OUTPUT;

SELECT @EmbeddingResult as GeneratedEmbedding;
```

#### `SP_GenerateAllEmbeddingsForChunk`
Generate all embeddings for a document chunk (Content, HeaderContext, Notes, Details).
```sql
-- Generate embeddings for all available fields in chunk
EXEC SP_GenerateAllEmbeddingsForChunk
    @ChunkId = 1,
    @ApiKey = 'your-openai-api-key', -- Optional, uses mock if not provided
    @EmbeddingModel = 'text-embedding-3-small'; -- Optional

-- For development/testing without API key (uses deterministic mock embeddings)
EXEC SP_GenerateAllEmbeddingsForChunk @ChunkId = 1;
```

**Features:**
- **Automatic API Integration**: Calls OpenAI API directly from SQL using `sp_invoke_external_rest_endpoint`
- **Fallback to Mock**: If API call fails or no API key provided, generates deterministic mock embeddings
- **Multi-Field Support**: Generates embeddings for all available text fields
- **Error Handling**: Comprehensive error management with fallback strategies
- **Base64 Decoding**: Handles OpenAI's base64-encoded embedding responses

## 🔧 Configuration and Features

### Configurable Parameters
- **MaxResults**: Default 10, maximum 50 (as per specification)
- **Similarity Threshold**: Default 0.7 for relevance filtering
- **Cache TTL**: 1 hour automatic cleanup
- **Pagination**: Standard page/size parameters

### Key Features Implemented
✅ **Multi-field embedding search** using LEAST function logic
✅ **Semantic caching** with 1-hour TTL
✅ **Column-based response format** for RAG search results (enhanced from JSON)
✅ **Automatic embedding generation** via OpenAI API integration
✅ **Cascade deletion** for data integrity
✅ **Error handling** with transaction rollback and fallback strategies
✅ **Performance optimization** with proper indexing support
✅ **Mock mode support** for development without API keys

### Vector Distance Support
The procedures are designed to work with SQL Server's vector functions when available:
- `vector_distance('cosine', embedding1, embedding2)`
- Fallback to text-based similarity when vector functions unavailable
- Ready for SQL Server 2025+ vector support

## 🛡️ Security Considerations

1. **Grant minimal permissions** to application users
2. **Use parameterized calls** to prevent SQL injection
3. **Validate inputs** before calling procedures
4. **Monitor cache size** to prevent excessive memory usage
5. **Regular cleanup** of old cache entries

## 📊 Performance Tips

1. **Use pagination** for large result sets
2. **Include embedding data only when needed** (`@IncludeEmbeddings = 0`)
3. **Regular cache cleanup** to maintain performance
4. **Monitor procedure execution** for optimization opportunities
5. **Index optimization** on frequently queried columns

## 🔄 Integration with API

These stored procedures complement the REST API and can be used:
- **Directly from SQL clients** for bulk operations
- **From other applications** requiring SQL-only access
- **For reporting and analytics** without API overhead
- **For batch processing** scenarios
- **For administrative tasks** and maintenance

## 📝 Error Handling

All procedures include comprehensive error handling:
- **Transaction rollback** on failures
- **Descriptive error messages** with error codes
- **Graceful degradation** for missing features
- **Input validation** with appropriate responses
- **Logging-friendly** error formats

## 🧪 Testing Examples

```sql
-- Complete workflow test with automatic embedding generation
DECLARE @DocId INT, @ChunkId INT;

-- 1. Insert document
EXEC SP_InsertDocument 'test.txt', 'text/plain', 100, 'Test content', NULL, 'Pending', @DocId OUTPUT;

-- 2. Add chunk with automatic embedding generation
EXEC SP_InsertDocumentChunk
    @DocumentId = @DocId,
    @ChunkIndex = 0,
    @Content = 'Test chunk content',
    @HeaderContext = 'Test Header',
    @Notes = 'Test notes',
    @ApiKey = 'your-api-key-or-null-for-mock', -- NULL will use mock embeddings
    @ChunkId = @ChunkId OUTPUT;

-- 3. Update document status
EXEC SP_UpdateDocument @DocId, @Status = 'Completed', @ProcessedAt = GETUTCDATE();

-- 4. Generate query embedding and search
DECLARE @QueryEmbedding VARBINARY(MAX);
EXEC SP_GenerateEmbedding
    @Text = 'test query',
    @ApiKey = 'your-api-key-or-null',
    @Embedding = @QueryEmbedding OUTPUT;

-- 5. Search for content (now returns columns, not JSON)
EXEC SP_RAGSearch @QueryEmbedding, 5, 0.7, 'test query';

-- 6. Check cache statistics
EXEC SP_GetSemanticCacheStats;

-- 7. Cleanup
EXEC SP_DeleteDocument @DocId;
```

This completes the full SQL interface implementation as specified in the requirements! 🎉