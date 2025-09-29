-- =============================================
-- Update Existing Procedures for Multi-Provider Support
-- =============================================
-- This script updates the RAG search and other existing procedures
-- to work with the new multi-provider AI system

USE [OSL_AI] -- Replace with your actual database name
GO

PRINT 'Updating existing procedures for multi-provider support...'
PRINT 'Database: ' + DB_NAME()
PRINT 'Update Date: ' + CONVERT(NVARCHAR, GETUTCDATE(), 120) + ' UTC'
PRINT '=============================================';

-- =============================================
-- Update SP_RAGSearch to use multi-provider embeddings
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_RAGSearch_MultiProvider]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_RAGSearch_MultiProvider]
GO

CREATE PROCEDURE [dbo].[SP_RAGSearch_MultiProvider]
    @QueryText NVARCHAR(MAX),
    @TopK INT = 10,
    @SimilarityThreshold FLOAT = 0.7,
    @AIProvider NVARCHAR(50) = 'OpenAI',
    @ApiKey NVARCHAR(255) = NULL,
    @BaseUrl NVARCHAR(500) = NULL,
    @Model NVARCHAR(100) = 'text-embedding-3-small',
    @DeploymentName NVARCHAR(100) = NULL,
    @ApiVersion NVARCHAR(50) = '2024-02-15-preview',
    @IncludeMetadata BIT = 1,
    @SearchNotes BIT = 1,
    @SearchDetails BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Generate query embedding
        DECLARE @QueryEmbedding VARBINARY(MAX);

        EXEC [dbo].[SP_GenerateEmbedding_MultiProvider]
            @Text = @QueryText,
            @Provider = @AIProvider,
            @ApiKey = @ApiKey,
            @BaseUrl = @BaseUrl,
            @Model = @Model,
            @DeploymentName = @DeploymentName,
            @ApiVersion = @ApiVersion,
            @Embedding = @QueryEmbedding OUTPUT;

        -- Create temporary table for results
        CREATE TABLE #SearchResults (
            DocumentId INT,
            DocumentChunkId INT,
            FileName NVARCHAR(255),
            Content NVARCHAR(MAX),
            HeaderContext NVARCHAR(MAX),
            Notes NVARCHAR(MAX),
            Details NVARCHAR(MAX),
            Similarity FLOAT,
            SearchType NVARCHAR(20),
            ChunkIndex INT,
            UploadedBy NVARCHAR(255),
            UploadedAt DATETIME2,
            ProcessedAt DATETIME2
        );

        -- Search content embeddings
        INSERT INTO #SearchResults
        SELECT TOP (@TopK)
            d.Id,
            dc.Id,
            d.FileName,
            dc.Content,
            dc.HeaderContext,
            dc.Notes,
            dc.Details,
            1.0 - (VECTOR_DISTANCE('cosine', @QueryEmbedding, ce.Embedding)) AS Similarity,
            'Content' AS SearchType,
            dc.ChunkIndex,
            d.UploadedBy,
            d.UploadedAt,
            d.ProcessedAt
        FROM Documents d
        INNER JOIN DocumentChunks dc ON d.Id = dc.DocumentId
        INNER JOIN DocumentChunkContentEmbeddings ce ON dc.Id = ce.DocumentChunkId
        WHERE (1.0 - (VECTOR_DISTANCE('cosine', @QueryEmbedding, ce.Embedding))) >= @SimilarityThreshold
        ORDER BY Similarity DESC;

        -- Search notes embeddings if enabled
        IF @SearchNotes = 1
        BEGIN
            INSERT INTO #SearchResults
            SELECT TOP (@TopK)
                d.Id,
                dc.Id,
                d.FileName,
                dc.Content,
                dc.HeaderContext,
                dc.Notes,
                dc.Details,
                1.0 - (VECTOR_DISTANCE('cosine', @QueryEmbedding, ne.Embedding)) AS Similarity,
                'Notes' AS SearchType,
                dc.ChunkIndex,
                d.UploadedBy,
                d.UploadedAt,
                d.ProcessedAt
            FROM Documents d
            INNER JOIN DocumentChunks dc ON d.Id = dc.DocumentId
            INNER JOIN DocumentChunkNotesEmbeddings ne ON dc.Id = ne.DocumentChunkId
            WHERE dc.Notes IS NOT NULL
              AND LEN(dc.Notes) > 0
              AND (1.0 - (VECTOR_DISTANCE('cosine', @QueryEmbedding, ne.Embedding))) >= @SimilarityThreshold
            ORDER BY Similarity DESC;
        END

        -- Search details embeddings if enabled
        IF @SearchDetails = 1
        BEGIN
            INSERT INTO #SearchResults
            SELECT TOP (@TopK)
                d.Id,
                dc.Id,
                d.FileName,
                dc.Content,
                dc.HeaderContext,
                dc.Notes,
                dc.Details,
                1.0 - (VECTOR_DISTANCE('cosine', @QueryEmbedding, de.Embedding)) AS Similarity,
                'Details' AS SearchType,
                dc.ChunkIndex,
                d.UploadedBy,
                d.UploadedAt,
                d.ProcessedAt
            FROM Documents d
            INNER JOIN DocumentChunks dc ON d.Id = dc.DocumentId
            INNER JOIN DocumentChunkDetailsEmbeddings de ON dc.Id = de.DocumentChunkId
            WHERE dc.Details IS NOT NULL
              AND LEN(dc.Details) > 0
              AND (1.0 - (VECTOR_DISTANCE('cosine', @QueryEmbedding, de.Embedding))) >= @SimilarityThreshold
            ORDER BY Similarity DESC;
        END

        -- Return top results with optional metadata
        IF @IncludeMetadata = 1
        BEGIN
            SELECT DISTINCT TOP (@TopK)
                DocumentId,
                DocumentChunkId,
                FileName,
                Content,
                HeaderContext,
                Notes,
                Details,
                MAX(Similarity) AS MaxSimilarity,
                STRING_AGG(SearchType, ', ') AS MatchedFields,
                ChunkIndex,
                UploadedBy,
                UploadedAt,
                ProcessedAt
            FROM #SearchResults
            GROUP BY DocumentId, DocumentChunkId, FileName, Content, HeaderContext, Notes, Details, ChunkIndex, UploadedBy, UploadedAt, ProcessedAt
            ORDER BY MaxSimilarity DESC;
        END
        ELSE
        BEGIN
            SELECT DISTINCT TOP (@TopK)
                DocumentId,
                DocumentChunkId,
                FileName,
                Content,
                MAX(Similarity) AS MaxSimilarity,
                ChunkIndex
            FROM #SearchResults
            GROUP BY DocumentId, DocumentChunkId, FileName, Content, ChunkIndex
            ORDER BY MaxSimilarity DESC;
        END

        DROP TABLE #SearchResults;

        PRINT 'RAG search completed using ' + @AIProvider + ' provider. Query: ' + LEFT(@QueryText, 50) + '...';

    END TRY
    BEGIN CATCH
        IF OBJECT_ID('tempdb..#SearchResults') IS NOT NULL
            DROP TABLE #SearchResults;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT 'Error in SP_RAGSearch_MultiProvider: ' + @ErrorMessage;
        RAISERROR (@ErrorMessage, 16, 1);
    END CATCH
END
GO

-- =============================================
-- Update SP_SemanticCacheCheck to use multi-provider
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_SemanticCacheCheck_MultiProvider]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_SemanticCacheCheck_MultiProvider]
GO

CREATE PROCEDURE [dbo].[SP_SemanticCacheCheck_MultiProvider]
    @QueryText NVARCHAR(MAX),
    @SimilarityThreshold FLOAT = 0.85,
    @AIProvider NVARCHAR(50) = 'OpenAI',
    @ApiKey NVARCHAR(255) = NULL,
    @BaseUrl NVARCHAR(500) = NULL,
    @Model NVARCHAR(100) = 'text-embedding-3-small',
    @DeploymentName NVARCHAR(100) = NULL,
    @ApiVersion NVARCHAR(50) = '2024-02-15-preview',
    @CachedResponse NVARCHAR(MAX) OUTPUT,
    @CacheHit BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET @CacheHit = 0;
        SET @CachedResponse = NULL;

        -- Generate query embedding
        DECLARE @QueryEmbedding VARBINARY(MAX);

        EXEC [dbo].[SP_GenerateEmbedding_MultiProvider]
            @Text = @QueryText,
            @Provider = @AIProvider,
            @ApiKey = @ApiKey,
            @BaseUrl = @BaseUrl,
            @Model = @Model,
            @DeploymentName = @DeploymentName,
            @ApiVersion = @ApiVersion,
            @Embedding = @QueryEmbedding OUTPUT;

        -- Check for similar queries in cache (not expired)
        SELECT TOP 1
            @CachedResponse = Response,
            @CacheHit = 1
        FROM SemanticCache sc
        WHERE (1.0 - (VECTOR_DISTANCE('cosine', @QueryEmbedding, sc.QueryEmbedding))) >= @SimilarityThreshold
          AND sc.ExpiresAt > GETUTCDATE()
        ORDER BY (1.0 - (VECTOR_DISTANCE('cosine', @QueryEmbedding, sc.QueryEmbedding))) DESC;

        -- Log the cache check
        IF @CacheHit = 1
        BEGIN
            PRINT 'Semantic cache HIT for query: ' + LEFT(@QueryText, 50) + '...';
        END
        ELSE
        BEGIN
            PRINT 'Semantic cache MISS for query: ' + LEFT(@QueryText, 50) + '...';
        END

    END TRY
    BEGIN CATCH
        SET @CacheHit = 0;
        SET @CachedResponse = NULL;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT 'Error in SP_SemanticCacheCheck_MultiProvider: ' + @ErrorMessage;
    END CATCH
END
GO

-- =============================================
-- Update SP_SemanticCacheStore to use multi-provider
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_SemanticCacheStore_MultiProvider]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_SemanticCacheStore_MultiProvider]
GO

CREATE PROCEDURE [dbo].[SP_SemanticCacheStore_MultiProvider]
    @QueryText NVARCHAR(MAX),
    @Response NVARCHAR(MAX),
    @TTLHours INT = 1,
    @AIProvider NVARCHAR(50) = 'OpenAI',
    @ApiKey NVARCHAR(255) = NULL,
    @BaseUrl NVARCHAR(500) = NULL,
    @Model NVARCHAR(100) = 'text-embedding-3-small',
    @DeploymentName NVARCHAR(100) = NULL,
    @ApiVersion NVARCHAR(50) = '2024-02-15-preview'
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Generate query embedding
        DECLARE @QueryEmbedding VARBINARY(MAX);

        EXEC [dbo].[SP_GenerateEmbedding_MultiProvider]
            @Text = @QueryText,
            @Provider = @AIProvider,
            @ApiKey = @ApiKey,
            @BaseUrl = @BaseUrl,
            @Model = @Model,
            @DeploymentName = @DeploymentName,
            @ApiVersion = @ApiVersion,
            @Embedding = @QueryEmbedding OUTPUT;

        -- Store in semantic cache
        INSERT INTO SemanticCache (QueryText, QueryEmbedding, Response, CreatedAt, ExpiresAt, Model, Provider)
        VALUES (
            @QueryText,
            @QueryEmbedding,
            @Response,
            GETUTCDATE(),
            DATEADD(HOUR, @TTLHours, GETUTCDATE()),
            @Model,
            @AIProvider
        );

        PRINT 'Response cached for ' + CAST(@TTLHours AS NVARCHAR) + ' hours using ' + @AIProvider + ' provider';

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT 'Error in SP_SemanticCacheStore_MultiProvider: ' + @ErrorMessage;
        RAISERROR (@ErrorMessage, 16, 1);
    END CATCH
END
GO

-- =============================================
-- Create helper procedure to get best available provider
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_GetBestAvailableProvider]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_GetBestAvailableProvider]
GO

CREATE PROCEDURE [dbo].[SP_GetBestAvailableProvider]
    @PreferredProvider NVARCHAR(50) = 'OpenAI',
    @OpenAIApiKey NVARCHAR(255) = NULL,
    @GeminiApiKey NVARCHAR(255) = NULL,
    @AzureOpenAIApiKey NVARCHAR(255) = NULL,
    @AzureOpenAIEndpoint NVARCHAR(500) = NULL,
    @SelectedProvider NVARCHAR(50) OUTPUT,
    @SelectedApiKey NVARCHAR(255) OUTPUT,
    @SelectedBaseUrl NVARCHAR(500) OUTPUT,
    @SelectedModel NVARCHAR(100) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Initialize output parameters
    SET @SelectedProvider = NULL;
    SET @SelectedApiKey = NULL;
    SET @SelectedBaseUrl = NULL;
    SET @SelectedModel = NULL;

    -- Try preferred provider first
    IF @PreferredProvider = 'OpenAI' AND @OpenAIApiKey IS NOT NULL
    BEGIN
        SET @SelectedProvider = 'OpenAI';
        SET @SelectedApiKey = @OpenAIApiKey;
        SET @SelectedBaseUrl = 'https://api.openai.com/v1';
        SET @SelectedModel = 'text-embedding-3-small';
    END
    ELSE IF @PreferredProvider = 'Gemini' AND @GeminiApiKey IS NOT NULL
    BEGIN
        SET @SelectedProvider = 'Gemini';
        SET @SelectedApiKey = @GeminiApiKey;
        SET @SelectedBaseUrl = 'https://generativelanguage.googleapis.com/v1beta';
        SET @SelectedModel = 'models/embedding-001';
    END
    ELSE IF @PreferredProvider = 'AzureOpenAI' AND @AzureOpenAIApiKey IS NOT NULL AND @AzureOpenAIEndpoint IS NOT NULL
    BEGIN
        SET @SelectedProvider = 'AzureOpenAI';
        SET @SelectedApiKey = @AzureOpenAIApiKey;
        SET @SelectedBaseUrl = @AzureOpenAIEndpoint;
        SET @SelectedModel = 'text-embedding-ada-002';
    END

    -- Fallback to any available provider
    IF @SelectedProvider IS NULL
    BEGIN
        IF @OpenAIApiKey IS NOT NULL
        BEGIN
            SET @SelectedProvider = 'OpenAI';
            SET @SelectedApiKey = @OpenAIApiKey;
            SET @SelectedBaseUrl = 'https://api.openai.com/v1';
            SET @SelectedModel = 'text-embedding-3-small';
        END
        ELSE IF @GeminiApiKey IS NOT NULL
        BEGIN
            SET @SelectedProvider = 'Gemini';
            SET @SelectedApiKey = @GeminiApiKey;
            SET @SelectedBaseUrl = 'https://generativelanguage.googleapis.com/v1beta';
            SET @SelectedModel = 'models/embedding-001';
        END
        ELSE IF @AzureOpenAIApiKey IS NOT NULL AND @AzureOpenAIEndpoint IS NOT NULL
        BEGIN
            SET @SelectedProvider = 'AzureOpenAI';
            SET @SelectedApiKey = @AzureOpenAIApiKey;
            SET @SelectedBaseUrl = @AzureOpenAIEndpoint;
            SET @SelectedModel = 'text-embedding-ada-002';
        END
    END

    -- Return result
    IF @SelectedProvider IS NOT NULL
    BEGIN
        SELECT
            @SelectedProvider AS Provider,
            @SelectedModel AS Model,
            'Available' AS Status;

        PRINT 'Selected provider: ' + @SelectedProvider;
    END
    ELSE
    BEGIN
        SELECT
            'None' AS Provider,
            'None' AS Model,
            'No providers available' AS Status;

        PRINT 'No AI providers available with the provided configuration';
    END
END
GO

-- =============================================
-- Create comprehensive test procedure
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_TestMultiProviderWorkflow]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_TestMultiProviderWorkflow]
GO

CREATE PROCEDURE [dbo].[SP_TestMultiProviderWorkflow]
    @TestDocument NVARCHAR(MAX) = 'This is a comprehensive test document for multi-provider AI integration. It contains information about various technologies including Azure SQL, OpenAI embeddings, and vector search capabilities.',
    @TestQuery NVARCHAR(MAX) = 'vector search capabilities',
    @OpenAIApiKey NVARCHAR(255) = NULL,
    @GeminiApiKey NVARCHAR(255) = NULL,
    @AzureOpenAIApiKey NVARCHAR(255) = NULL,
    @AzureOpenAIEndpoint NVARCHAR(500) = NULL,
    @AzureOpenAIDeployment NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '🧪 Starting Multi-Provider Workflow Test';
    PRINT '========================================';
    PRINT 'Test Document: ' + LEFT(@TestDocument, 100) + '...';
    PRINT 'Test Query: ' + @TestQuery;
    PRINT '';

    -- Test 1: Provider Selection
    PRINT '1. Testing Provider Selection...';
    DECLARE @SelectedProvider NVARCHAR(50);
    DECLARE @SelectedApiKey NVARCHAR(255);
    DECLARE @SelectedBaseUrl NVARCHAR(500);
    DECLARE @SelectedModel NVARCHAR(100);

    EXEC [dbo].[SP_GetBestAvailableProvider]
        @PreferredProvider = 'OpenAI',
        @OpenAIApiKey = @OpenAIApiKey,
        @GeminiApiKey = @GeminiApiKey,
        @AzureOpenAIApiKey = @AzureOpenAIApiKey,
        @AzureOpenAIEndpoint = @AzureOpenAIEndpoint,
        @SelectedProvider = @SelectedProvider OUTPUT,
        @SelectedApiKey = @SelectedApiKey OUTPUT,
        @SelectedBaseUrl = @SelectedBaseUrl OUTPUT,
        @SelectedModel = @SelectedModel OUTPUT;

    IF @SelectedProvider IS NULL
    BEGIN
        PRINT '❌ No providers available for testing. Please provide API keys.';
        RETURN;
    END

    -- Test 2: Document Insertion with Multi-Provider Embeddings
    PRINT '';
    PRINT '2. Testing Document Insertion with Multi-Provider Embeddings...';

    DECLARE @TestDocumentId INT;
    BEGIN TRY
        EXEC [dbo].[SP_InsertDocumentWithEmbeddings]
            @FileName = 'test_multiProvider.txt',
            @ContentType = 'text/plain',
            @FileSize = LEN(@TestDocument),
            @Content = @TestDocument,
            @UploadedBy = 'system_test',
            @Notes = 'Test document for multi-provider functionality',
            @Details = '{"test": true, "provider": "' + @SelectedProvider + '", "timestamp": "' + CONVERT(NVARCHAR, GETUTCDATE(), 127) + '"}',
            @AIProvider = @SelectedProvider,
            @ApiKey = @SelectedApiKey,
            @BaseUrl = @SelectedBaseUrl,
            @Model = @SelectedModel,
            @DeploymentName = @AzureOpenAIDeployment,
            @DocumentId = @TestDocumentId OUTPUT;

        PRINT '✅ Document inserted successfully. DocumentId: ' + CAST(@TestDocumentId AS NVARCHAR);
    END TRY
    BEGIN CATCH
        PRINT '❌ Document insertion failed: ' + ERROR_MESSAGE();
        RETURN;
    END CATCH

    -- Test 3: Semantic Cache Check
    PRINT '';
    PRINT '3. Testing Semantic Cache...';

    DECLARE @CachedResponse NVARCHAR(MAX);
    DECLARE @CacheHit BIT;

    BEGIN TRY
        EXEC [dbo].[SP_SemanticCacheCheck_MultiProvider]
            @QueryText = @TestQuery,
            @AIProvider = @SelectedProvider,
            @ApiKey = @SelectedApiKey,
            @BaseUrl = @SelectedBaseUrl,
            @Model = @SelectedModel,
            @DeploymentName = @AzureOpenAIDeployment,
            @CachedResponse = @CachedResponse OUTPUT,
            @CacheHit = @CacheHit OUTPUT;

        IF @CacheHit = 1
            PRINT '✅ Cache hit found';
        ELSE
            PRINT '✅ No cache hit (expected for first run)';
    END TRY
    BEGIN CATCH
        PRINT '❌ Semantic cache check failed: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 4: RAG Search
    PRINT '';
    PRINT '4. Testing Multi-Provider RAG Search...';

    BEGIN TRY
        EXEC [dbo].[SP_RAGSearch_MultiProvider]
            @QueryText = @TestQuery,
            @TopK = 5,
            @SimilarityThreshold = 0.1,
            @AIProvider = @SelectedProvider,
            @ApiKey = @SelectedApiKey,
            @BaseUrl = @SelectedBaseUrl,
            @Model = @SelectedModel,
            @DeploymentName = @AzureOpenAIDeployment,
            @IncludeMetadata = 1,
            @SearchNotes = 1,
            @SearchDetails = 1;

        PRINT '✅ RAG search completed successfully';
    END TRY
    BEGIN CATCH
        PRINT '❌ RAG search failed: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 5: Store Response in Cache
    PRINT '';
    PRINT '5. Testing Cache Storage...';

    DECLARE @TestResponse NVARCHAR(MAX) = 'This is a test response for the multi-provider workflow test. Generated at: ' + CONVERT(NVARCHAR, GETUTCDATE(), 127);

    BEGIN TRY
        EXEC [dbo].[SP_SemanticCacheStore_MultiProvider]
            @QueryText = @TestQuery,
            @Response = @TestResponse,
            @TTLHours = 1,
            @AIProvider = @SelectedProvider,
            @ApiKey = @SelectedApiKey,
            @BaseUrl = @SelectedBaseUrl,
            @Model = @SelectedModel,
            @DeploymentName = @AzureOpenAIDeployment;

        PRINT '✅ Response cached successfully';
    END TRY
    BEGIN CATCH
        PRINT '❌ Cache storage failed: ' + ERROR_MESSAGE();
    END CATCH

    -- Test Summary
    PRINT '';
    PRINT '========================================';
    PRINT '🎉 Multi-Provider Workflow Test Completed';
    PRINT 'Provider Used: ' + @SelectedProvider;
    PRINT 'Model Used: ' + @SelectedModel;
    PRINT 'Test Document ID: ' + CAST(ISNULL(@TestDocumentId, 0) AS NVARCHAR);
    PRINT '';
    PRINT 'Cleanup Note: Test document will remain in database for inspection.';
    PRINT 'To remove it manually, run: DELETE FROM Documents WHERE Id = ' + CAST(ISNULL(@TestDocumentId, 0) AS NVARCHAR) + ';';
    PRINT '========================================';
END
GO

PRINT '========================================';
PRINT 'Multi-Provider procedure updates completed successfully!';
PRINT '========================================';
PRINT '';
PRINT 'Updated/New Procedures:';
PRINT '• SP_RAGSearch_MultiProvider - Enhanced RAG search with multi-provider support';
PRINT '• SP_SemanticCacheCheck_MultiProvider - Multi-provider semantic cache checking';
PRINT '• SP_SemanticCacheStore_MultiProvider - Multi-provider semantic cache storage';
PRINT '• SP_GetBestAvailableProvider - Intelligent provider selection';
PRINT '• SP_TestMultiProviderWorkflow - Comprehensive workflow testing';
PRINT '';
PRINT 'Usage Example:';
PRINT '-- Test complete workflow:';
PRINT 'EXEC SP_TestMultiProviderWorkflow @OpenAIApiKey = ''your-key'', @GeminiApiKey = ''your-gemini-key'';';
PRINT '';