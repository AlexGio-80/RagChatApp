-- =============================================
-- RAG Search Procedures - CLR Version
-- =============================================
-- This file contains RAG search procedures using CLR functions for cosine similarity
-- Compatible with SQL Server 2016-2022 and SQL Server 2025
-- Requires: SqlVectorFunctions CLR assembly deployed

USE [OSL_AI]
GO

PRINT '============================================='
PRINT 'Installing RAG Search Procedures (CLR Version)'
PRINT '============================================='
PRINT 'Database: ' + DB_NAME()
PRINT 'Install Date: ' + CONVERT(NVARCHAR, GETUTCDATE(), 120) + ' UTC'
PRINT ''

-- =============================================
-- Drop existing procedures
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_RAGSearch_MultiProvider]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_RAGSearch_MultiProvider]
GO

PRINT '✓ Dropped existing SP_RAGSearch_MultiProvider'
GO

-- =============================================
-- SP_RAGSearch_MultiProvider (CLR Version)
-- =============================================
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
        PRINT 'SP_RAGSearch_MultiProvider (CLR): Generating query embedding...';

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

        IF @QueryEmbedding IS NULL
        BEGIN
            RAISERROR('Failed to generate query embedding', 16, 1);
            RETURN;
        END

        PRINT 'SP_RAGSearch_MultiProvider (CLR): Query embedding generated successfully';
        PRINT 'SP_RAGSearch_MultiProvider (CLR): Searching with CLR cosine similarity...';

        -- Create temporary table for results with proper similarity scoring
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

        -- Search header context embeddings
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
            dbo.fn_CosineSimilarity(he.Embedding, @QueryEmbedding) AS Similarity,
            'HeaderContext' AS SearchType,
            dc.ChunkIndex,
            d.UploadedBy,
            d.UploadedAt,
            d.ProcessedAt
        FROM Documents d
        INNER JOIN DocumentChunks dc ON d.Id = dc.DocumentId
        INNER JOIN DocumentChunkHeaderContextEmbeddings he ON dc.Id = he.DocumentChunkId
        WHERE he.Embedding IS NOT NULL
          AND dc.HeaderContext IS NOT NULL
          AND LEN(LTRIM(RTRIM(dc.HeaderContext))) > 0
          AND d.Status = 'Completed'
          AND dbo.fn_IsValidEmbedding(he.Embedding) = 1
        ORDER BY Similarity DESC;

        PRINT 'SP_RAGSearch_MultiProvider (CLR): Search completed, aggregating results...';

        -- Aggregate results by chunk (take max similarity across all fields)
        IF @IncludeMetadata = 1
        BEGIN
            -- Full metadata version
            SELECT TOP (@TopK)
                sr.DocumentId,
                sr.DocumentChunkId,
                sr.FileName,
                sr.Content,
                sr.HeaderContext,
                sr.Notes,
                sr.Details,
                MAX(sr.Similarity) AS MaxSimilarity,
                STRING_AGG(sr.SearchType, ', ') WITHIN GROUP (ORDER BY sr.Similarity DESC) AS MatchedFields,
                sr.ChunkIndex,
                sr.UploadedBy,
                sr.UploadedAt,
                sr.ProcessedAt
            FROM #SearchResults sr
            WHERE sr.Similarity >= @SimilarityThreshold
            GROUP BY
                sr.DocumentId,
                sr.DocumentChunkId,
                sr.FileName,
                sr.Content,
                sr.HeaderContext,
                sr.Notes,
                sr.Details,
                sr.ChunkIndex,
                sr.UploadedBy,
                sr.UploadedAt,
                sr.ProcessedAt
            ORDER BY MaxSimilarity DESC;
        END
        ELSE
        BEGIN
            -- Minimal version
            SELECT TOP (@TopK)
                sr.DocumentId,
                sr.DocumentChunkId,
                sr.FileName,
                sr.Content,
                MAX(sr.Similarity) AS MaxSimilarity,
                sr.ChunkIndex
            FROM #SearchResults sr
            WHERE sr.Similarity >= @SimilarityThreshold
            GROUP BY
                sr.DocumentId,
                sr.DocumentChunkId,
                sr.FileName,
                sr.Content,
                sr.ChunkIndex
            ORDER BY MaxSimilarity DESC;
        END

        PRINT 'SP_RAGSearch_MultiProvider (CLR): Results returned successfully';

        -- Cleanup
        DROP TABLE #SearchResults;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorLine INT = ERROR_LINE();
        PRINT 'SP_RAGSearch_MultiProvider (CLR) ERROR at line ' + CAST(@ErrorLine AS NVARCHAR) + ': ' + @ErrorMessage;

        -- Cleanup on error
        IF OBJECT_ID('tempdb..#SearchResults') IS NOT NULL
            DROP TABLE #SearchResults;

        RAISERROR (@ErrorMessage, 16, 1);
    END CATCH
END
GO

PRINT '✓ SP_RAGSearch_MultiProvider (CLR) created successfully';
PRINT '';

-- =============================================
-- Summary
-- =============================================
PRINT '============================================='
PRINT 'RAG Search Procedures (CLR Version) Installed!'
PRINT '============================================='
PRINT '';
PRINT 'Available Procedures:'
PRINT '  • SP_RAGSearch_MultiProvider - Multi-provider RAG search with CLR cosine similarity'
PRINT '';
PRINT 'Features:'
PRINT '  • Accurate cosine similarity using CLR functions'
PRINT '  • Multi-field search (Content, Notes, Details, HeaderContext)'
PRINT '  • Configurable similarity threshold'
PRINT '  • Compatible with SQL Server 2016-2025'
PRINT '';
PRINT 'Requirements:'
PRINT '  • SqlVectorFunctions CLR assembly must be deployed'
PRINT '  • Functions: dbo.fn_CosineSimilarity, dbo.fn_IsValidEmbedding'
PRINT '';
PRINT '============================================='
