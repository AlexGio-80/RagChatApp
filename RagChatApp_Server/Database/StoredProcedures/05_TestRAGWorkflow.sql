-- =============================================
-- Complete RAG Workflow Test Script
-- =============================================
-- This script demonstrates the complete RAG workflow:
-- 1. Generate embedding from query text
-- 2. Search for similar document chunks
-- 3. Return data ready for LLM consumption

USE [OSL_AI] -- Replace with your actual database name
GO

PRINT '=============================================';
PRINT 'Testing Complete RAG Workflow';
PRINT '=============================================';
PRINT '';

-- =============================================
-- Test 1: Basic RAG Search with Gemini (No API Key - Uses Mock)
-- =============================================
PRINT '--- Test 1: Basic RAG Search with Gemini (Mock Mode) ---';
PRINT '';

EXEC SP_GetDataForLLM_Gemini
    @SearchText = 'creazione prodotto in GP90',
    @TopK = 5,
    @IncludeMetadata = 1;

PRINT '';
PRINT '✓ Test 1 completed';
PRINT '';

-- =============================================
-- Test 2: RAG Search with OpenAI (No API Key - Uses Mock)
-- =============================================
PRINT '--- Test 2: RAG Search with OpenAI (Mock Mode) ---';
PRINT '';

EXEC SP_GetDataForLLM_OpenAI
    @SearchText = 'come creare un ordine di vendita',
    @TopK = 3,
    @IncludeMetadata = 0;

PRINT '';
PRINT '✓ Test 2 completed';
PRINT '';

-- =============================================
-- Test 3: RAG Search with Real API Key (Gemini Example)
-- =============================================
PRINT '--- Test 3: RAG Search with Real Gemini API Key ---';
PRINT 'NOTE: Update the @ApiKey parameter with your actual Gemini API key';
PRINT '';

-- Uncomment and add your real API key to test with real embeddings
/*
EXEC SP_GetDataForLLM_Gemini_WithKey
    @SearchText = 'gestione articoli e magazzino',
    @ApiKey = 'AIzaSy...-your-gemini-key-here',
    @TopK = 10,
    @IncludeMetadata = 1;
*/

PRINT 'Test 3 skipped (no API key provided)';
PRINT '';

-- =============================================
-- Test 4: Direct Embedding Generation Test
-- =============================================
PRINT '--- Test 4: Direct Embedding Generation with Gemini ---';
PRINT '';

DECLARE @QueryEmbedding VARBINARY(MAX);
DECLARE @TestQuery NVARCHAR(MAX) = 'test query for embedding generation';

EXEC SP_GenerateEmbedding_MultiProvider
    @Text = @TestQuery,
    @Provider = 'Gemini',
    @ApiKey = 'AIzaSyDUe74NImCUqMazYXgGdMA30e80QIvZENk',
    @BaseUrl = NULL,
    @Model = 'models/embedding-001',
    @DeploymentName = NULL,
    @ApiVersion = NULL,
    @Embedding = @QueryEmbedding OUTPUT;

IF @QueryEmbedding IS NOT NULL
BEGIN
    PRINT 'Embedding generated successfully!';
    PRINT 'Embedding length: ' + CAST(LEN(@QueryEmbedding) AS NVARCHAR) + ' bytes';
    PRINT 'First 100 bytes: ' + CAST(LEFT(@QueryEmbedding, 100) AS NVARCHAR(MAX));
END
ELSE
BEGIN
    PRINT 'WARNING: Embedding generation returned NULL';
END

PRINT '';
PRINT '✓ Test 4 completed';
PRINT '';

-- =============================================
-- Test 5: Compare Different Providers (Mock Mode)
-- =============================================
PRINT '--- Test 5: Compare Results from Different Providers ---';
PRINT '';

PRINT 'Results from OpenAI:';
EXEC SP_GetDataForLLM_OpenAI
    @SearchText = 'configurazione sistema',
    @TopK = 3,
    @IncludeMetadata = 0;

PRINT '';
PRINT 'Results from Gemini:';
EXEC SP_GetDataForLLM_Gemini
    @SearchText = 'configurazione sistema',
    @TopK = 3,
    @IncludeMetadata = 0;

PRINT '';
PRINT '✓ Test 5 completed';
PRINT '';

-- =============================================
-- Test 6: Advanced Search Options
-- =============================================
PRINT '--- Test 6: Advanced Search with Custom Options ---';
PRINT '';

EXEC SP_GetDataForLLM_Gemini
    @SearchText = 'processo di vendita',
    @TopK = 15,
    @IncludeMetadata = 1,
    @SearchNotes = 1,        -- Include search in notes
    @SearchDetails = 1,       -- Include search in details
    @SimilarityThreshold = 0.6; -- Lower threshold for more results

PRINT '';
PRINT '✓ Test 6 completed';
PRINT '';

-- =============================================
-- Test 7: Content-Only Search (No Notes/Details)
-- =============================================
PRINT '--- Test 7: Content-Only Search ---';
PRINT '';

EXEC SP_GetDataForLLM_Gemini
    @SearchText = 'importazione dati',
    @TopK = 5,
    @IncludeMetadata = 1,
    @SearchNotes = 0,         -- Exclude notes from search
    @SearchDetails = 0;       -- Exclude details from search

PRINT '';
PRINT '✓ Test 7 completed';
PRINT '';

-- =============================================
-- Summary
-- =============================================
PRINT '';
PRINT '=============================================';
PRINT 'All tests completed successfully!';
PRINT '=============================================';
PRINT '';
PRINT 'NEXT STEPS:';
PRINT '1. Review the results returned from each test';
PRINT '2. Add your real API keys to test with actual embeddings';
PRINT '3. Integrate these procedures into your LLM application';
PRINT '4. Adjust @TopK and @SimilarityThreshold based on your needs';
PRINT '';
PRINT 'INTEGRATION EXAMPLE (from your LLM application):';
PRINT '';
PRINT '-- C# Example:';
PRINT '-- using (var connection = new SqlConnection(connectionString))';
PRINT '-- {';
PRINT '--     var command = new SqlCommand("SP_GetDataForLLM_Gemini_WithKey", connection);';
PRINT '--     command.CommandType = CommandType.StoredProcedure;';
PRINT '--     command.Parameters.AddWithValue("@SearchText", userQuery);';
PRINT '--     command.Parameters.AddWithValue("@ApiKey", geminiApiKey);';
PRINT '--     command.Parameters.AddWithValue("@TopK", 10);';
PRINT '--     ';
PRINT '--     connection.Open();';
PRINT '--     var reader = await command.ExecuteReaderAsync();';
PRINT '--     ';
PRINT '--     var results = new List<RAGResult>();';
PRINT '--     while (await reader.ReadAsync())';
PRINT '--     {';
PRINT '--         results.Add(new RAGResult {';
PRINT '--             Content = reader["Content"].ToString(),';
PRINT '--             FileName = reader["FileName"].ToString(),';
PRINT '--             Similarity = (float)reader["MaxSimilarity"]';
PRINT '--         });';
PRINT '--     }';
PRINT '--     ';
PRINT '--     // Pass results to your LLM';
PRINT '--     var context = string.Join("\n\n", results.Select(r => r.Content));';
PRINT '--     var llmResponse = await CallLLMWithContext(userQuery, context);';
PRINT '-- }';
PRINT '';
PRINT '=============================================';
