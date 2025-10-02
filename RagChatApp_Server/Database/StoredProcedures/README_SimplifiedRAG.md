# Simplified RAG Stored Procedures for LLM Integration

## Overview

This document describes the simplified stored procedures designed for easy integration with LLM applications. These procedures provide a simple interface to retrieve relevant document chunks using RAG (Retrieval-Augmented Generation) with multi-provider AI support.

## Installation

### Step 1: Install Core Multi-Provider Support
```sql
-- Run this first to install the multi-provider infrastructure
:r "01_MultiProviderSupport.sql"
```

### Step 2: Install RAG Search Procedures
```sql
-- Install the multi-provider RAG search procedure
:r "02_UpdateExistingProcedures.sql"
```

### Step 3: Install Simplified Procedures
```sql
-- Install simplified procedures (choose one or both)

-- Option A: Procedures without API key parameter (uses configuration or mock)
:r "04_SimplifiedRAGProcedures.sql"

-- Option B: Procedures with API key parameter (recommended for production)
:r "04b_SimplifiedRAGProcedures_WithApiKey.sql"
```

### Step 4: Test the Installation
```sql
-- Run the test script to verify everything works
:r "05_TestRAGWorkflow.sql"
```

## Available Procedures

### Without API Key Parameter (Uses Configuration or Mock)

#### `SP_GetDataForLLM_OpenAI`
Simple RAG search using OpenAI embeddings.

```sql
EXEC SP_GetDataForLLM_OpenAI
    @SearchText = 'your search query',
    @TopK = 10,
    @IncludeMetadata = 1,
    @SearchNotes = 1,
    @SearchDetails = 1,
    @SimilarityThreshold = 0.6;
```

**Parameters:**
- `@SearchText` (required) - The text to search for
- `@TopK` (default: 10) - Number of top results to return
- `@IncludeMetadata` (default: 1) - Include full metadata in results
- `@SearchNotes` (default: 1) - Include search in notes field
- `@SearchDetails` (default: 1) - Include search in details field
- `@SimilarityThreshold` (default 0.6) - Minimum similarity score

#### `SP_GetDataForLLM_Gemini`
Simple RAG search using Google Gemini embeddings.

```sql
EXEC SP_GetDataForLLM_Gemini
    @SearchText = 'your search query',
    @TopK = 10;
```

**Parameters:** Same as `SP_GetDataForLLM_OpenAI`

#### `SP_GetDataForLLM_AzureOpenAI`
Simple RAG search using Azure OpenAI embeddings.

```sql
EXEC SP_GetDataForLLM_AzureOpenAI
    @SearchText = 'your search query',
    @TopK = 10;
```

**Parameters:** Same as `SP_GetDataForLLM_OpenAI`

---

### With API Key Parameter (Recommended for Production)

#### `SP_GetDataForLLM_OpenAI_WithKey`
RAG search with OpenAI embeddings, API key as parameter.

```sql
EXEC SP_GetDataForLLM_OpenAI_WithKey
    @SearchText = 'your search query',
    @ApiKey = 'sk-your-openai-api-key',
    @TopK = 10,
    @BaseUrl = NULL,
    @Model = 'text-embedding-3-small';
```

**Parameters:**
- `@SearchText` (required) - The text to search for
- `@ApiKey` (required) - OpenAI API key
- `@TopK` (default: 10) - Number of top results to return
- `@BaseUrl` (optional) - Custom OpenAI endpoint
- `@Model` (default: 'text-embedding-3-small') - Embedding model
- `@IncludeMetadata` (default: 1) - Include full metadata
- `@SearchNotes` (default: 1) - Include search in notes
- `@SearchDetails` (default: 1) - Include search in details
- `@SimilarityThreshold` (default 0.6) - Minimum similarity score

#### `SP_GetDataForLLM_Gemini_WithKey`
RAG search with Gemini embeddings, API key as parameter.

```sql
EXEC SP_GetDataForLLM_Gemini_WithKey
    @SearchText = 'your search query',
    @ApiKey = 'AIzaSy...-your-gemini-api-key',
    @TopK = 10,
    @Model = 'models/embedding-001';
```

**Parameters:**
- `@SearchText` (required) - The text to search for
- `@ApiKey` (required) - Gemini API key
- `@TopK` (default: 10) - Number of top results
- `@BaseUrl` (optional) - Custom Gemini endpoint
- `@Model` (default: 'models/embedding-001') - Embedding model
- Plus all optional parameters from OpenAI version

#### `SP_GetDataForLLM_AzureOpenAI_WithKey`
RAG search with Azure OpenAI embeddings, full configuration.

```sql
EXEC SP_GetDataForLLM_AzureOpenAI_WithKey
    @SearchText = 'your search query',
    @ApiKey = 'your-azure-api-key',
    @Endpoint = 'https://your-resource.openai.azure.com',
    @DeploymentName = 'text-embedding-ada-002',
    @TopK = 10;
```

**Parameters:**
- `@SearchText` (required) - The text to search for
- `@ApiKey` (required) - Azure OpenAI API key
- `@Endpoint` (required) - Azure OpenAI endpoint URL
- `@DeploymentName` (required) - Deployment name
- `@TopK` (default: 10) - Number of top results
- `@ApiVersion` (default: '2024-02-15-preview') - API version
- Plus all optional parameters from OpenAI version

## Return Schema

### With Metadata (`@IncludeMetadata = 1`)

| Column | Type | Description |
|--------|------|-------------|
| `DocumentId` | INT | Unique document identifier |
| `DocumentChunkId` | INT | Unique chunk identifier |
| `FileName` | NVARCHAR(255) | Original document filename |
| `Content` | NVARCHAR(MAX) | Document chunk content |
| `HeaderContext` | NVARCHAR(MAX) | Document section/header context |
| `Notes` | NVARCHAR(MAX) | User notes associated with chunk |
| `Details` | NVARCHAR(MAX) | Additional metadata (JSON format) |
| `MaxSimilarity` | FLOAT | Highest similarity score (0-1) |
| `MatchedFields` | NVARCHAR(MAX) | Which fields matched (Content, Notes, Details) |
| `ChunkIndex` | INT | Position of chunk in document |
| `UploadedBy` | NVARCHAR(255) | User who uploaded the document |
| `UploadedAt` | DATETIME2 | Upload timestamp |
| `ProcessedAt` | DATETIME2 | Processing completion timestamp |

### Without Metadata (`@IncludeMetadata = 0`)

| Column | Type | Description |
|--------|------|-------------|
| `DocumentId` | INT | Unique document identifier |
| `DocumentChunkId` | INT | Unique chunk identifier |
| `FileName` | NVARCHAR(255) | Original document filename |
| `Content` | NVARCHAR(MAX) | Document chunk content |
| `MaxSimilarity` | FLOAT | Highest similarity score (0-1) |
| `ChunkIndex` | INT | Position of chunk in document |

## Usage Examples

### Example 1: Basic Search with Gemini
```sql
-- Simple search for top 5 results
EXEC SP_GetDataForLLM_Gemini_WithKey
    @SearchText = 'come creare un prodotto',
    @ApiKey = 'AIzaSy...',
    @TopK = 5;
```

### Example 2: Search with Custom Options
```sql
-- Search with lower threshold for more results
EXEC SP_GetDataForLLM_OpenAI_WithKey
    @SearchText = 'gestione ordini',
    @ApiKey = 'sk-...',
    @TopK = 15,
    @SimilarityThreshold = 0.6,
    @SearchNotes = 0,      -- Don't search in notes
    @SearchDetails = 0;    -- Don't search in details
```

### Example 3: Content-Only Search
```sql
-- Search only in document content, exclude notes and details
EXEC SP_GetDataForLLM_Gemini_WithKey
    @SearchText = 'configurazione sistema',
    @ApiKey = 'AIzaSy...',
    @TopK = 10,
    @IncludeMetadata = 0,  -- Return minimal columns
    @SearchNotes = 0,
    @SearchDetails = 0;
```

### Example 4: Azure OpenAI Search
```sql
-- Search using Azure OpenAI
EXEC SP_GetDataForLLM_AzureOpenAI_WithKey
    @SearchText = 'processo di vendita',
    @ApiKey = 'your-azure-key',
    @Endpoint = 'https://your-resource.openai.azure.com',
    @DeploymentName = 'text-embedding-ada-002',
    @TopK = 10;
```

## Integration with C# / .NET

```csharp
using System.Data;
using System.Data.SqlClient;

public class RAGService
{
    private readonly string _connectionString;
    private readonly string _geminiApiKey;

    public async Task<List<RAGResult>> SearchDocumentsAsync(string query, int topK = 10)
    {
        var results = new List<RAGResult>();

        using (var connection = new SqlConnection(_connectionString))
        {
            var command = new SqlCommand("SP_GetDataForLLM_Gemini_WithKey", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.AddWithValue("@SearchText", query);
            command.Parameters.AddWithValue("@ApiKey", _geminiApiKey);
            command.Parameters.AddWithValue("@TopK", topK);
            command.Parameters.AddWithValue("@IncludeMetadata", 1);

            await connection.OpenAsync();

            using (var reader = await command.ExecuteReaderAsync())
            {
                while (await reader.ReadAsync())
                {
                    results.Add(new RAGResult
                    {
                        DocumentId = reader.GetInt32(reader.GetOrdinal("DocumentId")),
                        ChunkId = reader.GetInt32(reader.GetOrdinal("DocumentChunkId")),
                        FileName = reader.GetString(reader.GetOrdinal("FileName")),
                        Content = reader.GetString(reader.GetOrdinal("Content")),
                        HeaderContext = reader.IsDBNull(reader.GetOrdinal("HeaderContext"))
                            ? null
                            : reader.GetString(reader.GetOrdinal("HeaderContext")),
                        Notes = reader.IsDBNull(reader.GetOrdinal("Notes"))
                            ? null
                            : reader.GetString(reader.GetOrdinal("Notes")),
                        Similarity = (float)reader.GetDouble(reader.GetOrdinal("MaxSimilarity")),
                        ChunkIndex = reader.GetInt32(reader.GetOrdinal("ChunkIndex"))
                    });
                }
            }
        }

        return results;
    }

    public async Task<string> GenerateLLMResponseAsync(string userQuery)
    {
        // 1. Get relevant document chunks using RAG
        var ragResults = await SearchDocumentsAsync(userQuery, topK: 10);

        // 2. Build context from results
        var context = string.Join("\n\n", ragResults.Select(r =>
            $"[From: {r.FileName}, Section: {r.HeaderContext}]\n{r.Content}"));

        // 3. Call your LLM with the context
        var prompt = $@"
Based on the following context, answer the user's question.

Context:
{context}

User Question: {userQuery}

Answer:";

        return await CallLLMAsync(prompt);
    }

    private async Task<string> CallLLMAsync(string prompt)
    {
        // Your LLM implementation here
        throw new NotImplementedException();
    }
}

public class RAGResult
{
    public int DocumentId { get; set; }
    public int ChunkId { get; set; }
    public string FileName { get; set; }
    public string Content { get; set; }
    public string HeaderContext { get; set; }
    public string Notes { get; set; }
    public float Similarity { get; set; }
    public int ChunkIndex { get; set; }
}
```

## Integration with Python

```python
import pyodbc

class RAGService:
    def __init__(self, connection_string, gemini_api_key):
        self.connection_string = connection_string
        self.gemini_api_key = gemini_api_key

    def search_documents(self, query, top_k=10):
        results = []

        with pyodbc.connect(self.connection_string) as conn:
            cursor = conn.cursor()
            cursor.execute(
                "{CALL SP_GetDataForLLM_Gemini_WithKey(?, ?, ?)}",
                query, self.gemini_api_key, top_k
            )

            columns = [column[0] for column in cursor.description]
            for row in cursor.fetchall():
                results.append(dict(zip(columns, row)))

        return results

    def generate_llm_response(self, user_query):
        # 1. Get relevant document chunks using RAG
        rag_results = self.search_documents(user_query, top_k=10)

        # 2. Build context from results
        context = "\n\n".join([
            f"[From: {r['FileName']}, Section: {r['HeaderContext']}]\n{r['Content']}"
            for r in rag_results
        ])

        # 3. Call your LLM with the context
        prompt = f"""
Based on the following context, answer the user's question.

Context:
{context}

User Question: {user_query}

Answer:"""

        return self.call_llm(prompt)

    def call_llm(self, prompt):
        # Your LLM implementation here
        raise NotImplementedError()
```

## Performance Tuning

### Adjust TopK Based on Use Case

```sql
-- For quick answers, use fewer results
EXEC SP_GetDataForLLM_Gemini_WithKey
    @SearchText = 'quick question',
    @ApiKey = 'AIzaSy...',
    @TopK = 3;

-- For comprehensive analysis, use more results
EXEC SP_GetDataForLLM_Gemini_WithKey
    @SearchText = 'detailed analysis needed',
    @ApiKey = 'AIzaSy...',
    @TopK = 20;
```

### Adjust Similarity Threshold

```sql
-- Strict matching (higher quality, fewer results)
EXEC SP_GetDataForLLM_Gemini_WithKey
    @SearchText = 'specific technical term',
    @ApiKey = 'AIzaSy...',
    @SimilarityThreshold = 0.8;

-- Broad matching (more results, may include less relevant)
EXEC SP_GetDataForLLM_Gemini_WithKey
    @SearchText = 'general topic',
    @ApiKey = 'AIzaSy...',
    @SimilarityThreshold = 0.5;
```

### Optimize for Response Time

```sql
-- Minimal columns for faster response
EXEC SP_GetDataForLLM_Gemini_WithKey
    @SearchText = 'query',
    @ApiKey = 'AIzaSy...',
    @TopK = 5,
    @IncludeMetadata = 0,    -- Skip metadata
    @SearchNotes = 0,         -- Skip notes search
    @SearchDetails = 0;       -- Skip details search
```

## Security Best Practices

1. **Never hardcode API keys** in stored procedures
2. **Store API keys encrypted** in a configuration table
3. **Use application-level security** to pass keys at runtime
4. **Consider Azure Key Vault** or similar for key management
5. **Implement proper access control** on stored procedures
6. **Log API usage** for monitoring and auditing
7. **Use different keys** for dev/test/production environments

## Troubleshooting

### Issue: No results returned
**Solution:** Check if documents are properly indexed with embeddings
```sql
-- Verify documents and embeddings exist
SELECT COUNT(*) FROM Documents;
SELECT COUNT(*) FROM DocumentChunks;
SELECT COUNT(*) FROM DocumentChunkContentEmbeddings;
```

### Issue: API key error
**Solution:** Verify API key is valid and has proper permissions
```sql
-- Test embedding generation directly
DECLARE @Embedding VARBINARY(MAX);
EXEC SP_GenerateEmbedding_MultiProvider
    @Text = 'test',
    @Provider = 'Gemini',
    @ApiKey = 'your-key',
    @Model = 'models/embedding-001',
    @Embedding = @Embedding OUTPUT;
SELECT @Embedding;
```

### Issue: Slow performance
**Solution:**
- Reduce `@TopK` parameter
- Set `@IncludeMetadata = 0`
- Disable notes/details search if not needed
- Ensure proper indexes on tables

## Support

For issues or questions:
- Check the main README in the StoredProcedures folder
- Review the test script: `05_TestRAGWorkflow.sql`
- Examine procedure code for detailed implementation
