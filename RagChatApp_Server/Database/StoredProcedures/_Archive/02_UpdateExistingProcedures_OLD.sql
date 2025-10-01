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

        -- Search content embeddings using CLR cosine similarity
        INSERT INTO #SearchResults
        SELECT TOP (@TopK)
            d.Id,
            dc.Id,
            d.FileName,
            dc.Content,
            dc.HeaderContext,
            dc.Notes,
            dc.Details,
            -- Use CLR function for accurate cosine similarity
            dbo.fn_CosineSimilarity(ce.Embedding, @QueryEmbedding) AS Similarity,
            'Content' AS SearchType,
            dc.ChunkIndex,
            d.UploadedBy,
            d.UploadedAt,
            d.ProcessedAt
        FROM Documents d
        INNER JOIN DocumentChunks dc ON d.Id = dc.DocumentId
        INNER JOIN DocumentChunkContentEmbeddings ce ON dc.Id = ce.DocumentChunkId
        WHERE ce.Embedding IS NOT NULL
          AND d.Status = 'Completed'
          AND dbo.fn_IsValidEmbedding(ce.Embedding) = 1
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
                -- Use CLR function for accurate cosine similarity
                dbo.fn_CosineSimilarity(ne.Embedding, @QueryEmbedding) AS Similarity,
                'Notes' AS SearchType,
                dc.ChunkIndex,
                d.UploadedBy,
                d.UploadedAt,
                d.ProcessedAt
            FROM Documents d
            INNER JOIN DocumentChunks dc ON d.Id = dc.DocumentId
            INNER JOIN DocumentChunkNotesEmbeddings ne ON dc.Id = ne.DocumentChunkId
            WHERE dc.Notes IS NOT NULL
              AND LEN(LTRIM(RTRIM(dc.Notes))) > 0
              AND ne.Embedding IS NOT NULL
              AND d.Status = 'Completed'
              AND dbo.fn_IsValidEmbedding(ne.Embedding) = 1
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
                -- Use CLR function for accurate cosine similarity
                dbo.fn_CosineSimilarity(de.Embedding, @QueryEmbedding) AS Similarity,
                'Details' AS SearchType,
                dc.ChunkIndex,
                d.UploadedBy,
                d.UploadedAt,
                d.ProcessedAt
            FROM Documents d
            INNER JOIN DocumentChunks dc ON d.Id = dc.DocumentId
            INNER JOIN DocumentChunkDetailsEmbeddings de ON dc.Id = de.DocumentChunkId
            WHERE dc.Details IS NOT NULL
              AND LEN(LTRIM(RTRIM(dc.Details))) > 0
              AND de.Embedding IS NOT NULL
              AND d.Status = 'Completed'
              AND dbo.fn_IsValidEmbedding(de.Embedding) = 1
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
            @CachedResponse = ResultContent,
            @CacheHit = 1
        FROM SemanticCache sc
        WHERE sc.ResultEmbedding IS NOT NULL
          AND sc.CreatedAt > DATEADD(HOUR, -1, GETUTCDATE()) -- 1 hour TTL
        ORDER BY sc.CreatedAt DESC;

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
        INSERT INTO SemanticCache (SearchQuery, ResultContent, ResultEmbedding, CreatedAt)
        VALUES (
            @QueryText,
            'Multi-provider search results cached',
            @QueryEmbedding,
            GETUTCDATE()
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

PRINT 'Multi-Provider AI support installation completed successfully!';
PRINT 'Available procedures:';
PRINT '  - SP_GenerateEmbedding_MultiProvider';
PRINT '  - SP_RAGSearch_MultiProvider';
PRINT '  - SP_InsertDocumentWithEmbeddings';
PRINT '  - SP_CacheResponse';
PRINT '  - SP_TestAllProviders';
GO