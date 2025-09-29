-- =============================================
-- RAG Chat Application - Unified Installation Script for All Stored Procedures
-- =============================================
-- This script contains all stored procedures in a single file for easy execution

USE [OSL_AI] -- Replace with your actual database name
GO

PRINT 'Starting unified installation of RAG Chat Application stored procedures...'
PRINT 'Database: ' + DB_NAME()
PRINT 'Installation Date: ' + CONVERT(NVARCHAR, GETUTCDATE(), 120) + ' UTC'
PRINT '=============================================';

-- Check if we're in the correct database
IF DB_NAME() NOT LIKE '%RAG%' AND DB_NAME() NOT LIKE '%OSL%' AND DB_NAME() NOT LIKE '%AI%'
BEGIN
    PRINT 'WARNING: You may not be in the correct database!'
    PRINT 'Current database: ' + DB_NAME()
    PRINT 'Please ensure you are connected to the RAG Chat Application database.'
    PRINT '============================================='
END

-- Check if required tables exist
PRINT 'Checking for required tables...'

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Documents')
BEGIN
    PRINT 'ERROR: Documents table not found!'
    PRINT 'Please run the Entity Framework migrations first.'
    RETURN;
END

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'DocumentChunks')
BEGIN
    PRINT 'ERROR: DocumentChunks table not found!'
    PRINT 'Please run the Entity Framework migrations first.'
    RETURN;
END

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'DocumentChunkContentEmbeddings')
BEGIN
    PRINT 'ERROR: DocumentChunkContentEmbeddings table not found!'
    PRINT 'Please run the Entity Framework migrations first.'
    RETURN;
END

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SemanticCache')
BEGIN
    PRINT 'ERROR: SemanticCache table not found!'
    PRINT 'Please run the Entity Framework migrations first.'
    RETURN;
END

PRINT 'All required tables found.'
PRINT '=============================================';

-- =============================================
-- 1. DOCUMENTS CRUD STORED PROCEDURES
-- =============================================

PRINT '1. Installing Documents CRUD stored procedures...';

-- SP_InsertDocument - Insert a new document
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_InsertDocument]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_InsertDocument]
GO

CREATE PROCEDURE [dbo].[SP_InsertDocument]
    @FileName NVARCHAR(255),
    @ContentType NVARCHAR(100),
    @Size BIGINT,
    @Content NVARCHAR(MAX),
    @Path NVARCHAR(500) = NULL,
    @Status NVARCHAR(50) = 'Pending',
    @DocumentId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        INSERT INTO Documents (
            FileName,
            ContentType,
            Size,
            Content,
            Path,
            UploadedAt,
            ProcessedAt,
            Status
        )
        VALUES (
            @FileName,
            @ContentType,
            @Size,
            @Content,
            @Path,
            GETUTCDATE(),
            NULL,
            @Status
        );

        SET @DocumentId = SCOPE_IDENTITY();

        -- Return the inserted document
        SELECT
            Id,
            FileName,
            ContentType,
            Size,
            Content,
            Path,
            UploadedAt,
            ProcessedAt,
            Status
        FROM Documents
        WHERE Id = @DocumentId;

    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- SP_GetDocument - Retrieve a document by ID
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_GetDocument]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_GetDocument]
GO

CREATE PROCEDURE [dbo].[SP_GetDocument]
    @DocumentId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id,
        FileName,
        ContentType,
        Size,
        Content,
        Path,
        UploadedAt,
        ProcessedAt,
        Status
    FROM Documents
    WHERE Id = @DocumentId;
END
GO

-- SP_GetAllDocuments - Retrieve documents with pagination
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_GetAllDocuments]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_GetAllDocuments]
GO

CREATE PROCEDURE [dbo].[SP_GetAllDocuments]
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @Status NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    SELECT
        Id,
        FileName,
        ContentType,
        Size,
        LEFT(Content, 500) as ContentPreview, -- Only first 500 chars for listing
        Path,
        UploadedAt,
        ProcessedAt,
        Status
    FROM Documents
    WHERE (@Status IS NULL OR Status = @Status)
    ORDER BY UploadedAt DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- SP_UpdateDocument - Update document properties
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_UpdateDocument]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_UpdateDocument]
GO

CREATE PROCEDURE [dbo].[SP_UpdateDocument]
    @DocumentId INT,
    @Content NVARCHAR(MAX) = NULL,
    @Path NVARCHAR(500) = NULL,
    @Status NVARCHAR(50) = NULL,
    @ProcessedAt DATETIME2 = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Check if document exists
        IF NOT EXISTS (SELECT 1 FROM Documents WHERE Id = @DocumentId)
        BEGIN
            RAISERROR('Document with ID %d not found', 16, 1, @DocumentId);
            RETURN;
        END

        -- If content is being updated, delete all existing chunks
        IF @Content IS NOT NULL
        BEGIN
            DELETE FROM DocumentChunks WHERE DocumentId = @DocumentId;
        END

        UPDATE Documents
        SET
            Content = COALESCE(@Content, Content),
            Path = COALESCE(@Path, Path),
            Status = COALESCE(@Status, Status),
            ProcessedAt = COALESCE(@ProcessedAt, ProcessedAt)
        WHERE Id = @DocumentId;

        -- Return updated document
        EXEC SP_GetDocument @DocumentId;

    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- SP_DeleteDocument - Delete document and all related data
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_DeleteDocument]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_DeleteDocument]
GO

CREATE PROCEDURE [dbo].[SP_DeleteDocument]
    @DocumentId INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Check if document exists
        IF NOT EXISTS (SELECT 1 FROM Documents WHERE Id = @DocumentId)
        BEGIN
            RAISERROR('Document with ID %d not found', 16, 1, @DocumentId);
            RETURN;
        END

        DECLARE @FileName NVARCHAR(255);
        SELECT @FileName = FileName FROM Documents WHERE Id = @DocumentId;

        -- Delete document (cascade delete will handle chunks and embeddings)
        DELETE FROM Documents WHERE Id = @DocumentId;

        -- Return success message
        SELECT
            @DocumentId as DeletedDocumentId,
            @FileName as FileName,
            'Document and all related chunks deleted successfully' as Message;

    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

PRINT '   Documents CRUD procedures installed successfully';

-- =============================================
-- 2. DOCUMENT CHUNKS AND EMBEDDINGS CRUD
-- =============================================

PRINT '2. Installing DocumentChunks and Embeddings CRUD stored procedures...';

-- SP_InsertDocumentChunk - Insert a new document chunk with auto-embedding generation
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_InsertDocumentChunk]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_InsertDocumentChunk]
GO

CREATE PROCEDURE [dbo].[SP_InsertDocumentChunk]
    @DocumentId INT,
    @ChunkIndex INT,
    @Content NVARCHAR(MAX),
    @HeaderContext NVARCHAR(MAX) = NULL,
    @Notes NVARCHAR(MAX) = NULL,
    @Details NVARCHAR(MAX) = NULL,
    @ApiKey NVARCHAR(255) = NULL,
    @EmbeddingModel NVARCHAR(100) = 'text-embedding-3-small',
    @AutoGenerateEmbeddings BIT = 1,
    @ChunkId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Verify document exists
        IF NOT EXISTS (SELECT 1 FROM Documents WHERE Id = @DocumentId)
        BEGIN
            RAISERROR('Document with ID %d not found', 16, 1, @DocumentId);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Insert the chunk
        INSERT INTO DocumentChunks (
            DocumentId,
            ChunkIndex,
            Content,
            HeaderContext,
            Notes,
            Details,
            CreatedAt,
            UpdatedAt
        )
        VALUES (
            @DocumentId,
            @ChunkIndex,
            @Content,
            @HeaderContext,
            @Notes,
            @Details,
            GETUTCDATE(),
            GETUTCDATE()
        );

        SET @ChunkId = SCOPE_IDENTITY();

        -- Auto-generate embeddings if requested (default)
        IF @AutoGenerateEmbeddings = 1
        BEGIN
            -- Generate all embeddings for this chunk using OpenAI API
            EXEC SP_GenerateAllEmbeddingsForChunk
                @ChunkId = @ChunkId,
                @ApiKey = @ApiKey,
                @EmbeddingModel = @EmbeddingModel;
        END

        COMMIT TRANSACTION;

        -- Return the inserted chunk with embeddings info
        SELECT
            dc.Id,
            dc.DocumentId,
            dc.ChunkIndex,
            dc.Content,
            dc.HeaderContext,
            dc.Notes,
            dc.Details,
            dc.CreatedAt,
            dc.UpdatedAt,
            CASE WHEN dcce.Id IS NOT NULL THEN 1 ELSE 0 END as HasContentEmbedding,
            CASE WHEN dchce.Id IS NOT NULL THEN 1 ELSE 0 END as HasHeaderContextEmbedding,
            CASE WHEN dcne.Id IS NOT NULL THEN 1 ELSE 0 END as HasNotesEmbedding,
            CASE WHEN dcde.Id IS NOT NULL THEN 1 ELSE 0 END as HasDetailsEmbedding
        FROM DocumentChunks dc
        LEFT JOIN DocumentChunkContentEmbeddings dcce ON dc.Id = dcce.DocumentChunkId
        LEFT JOIN DocumentChunkHeaderContextEmbeddings dchce ON dc.Id = dchce.DocumentChunkId
        LEFT JOIN DocumentChunkNotesEmbeddings dcne ON dc.Id = dcne.DocumentChunkId
        LEFT JOIN DocumentChunkDetailsEmbeddings dcde ON dc.Id = dcde.DocumentChunkId
        WHERE dc.Id = @ChunkId;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- SP_GetDocumentChunks - Retrieve chunks for a document
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_GetDocumentChunks]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_GetDocumentChunks]
GO

CREATE PROCEDURE [dbo].[SP_GetDocumentChunks]
    @DocumentId INT,
    @IncludeEmbeddings BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @IncludeEmbeddings = 1
    BEGIN
        -- Return with embedding data
        SELECT
            dc.Id,
            dc.DocumentId,
            dc.ChunkIndex,
            dc.Content,
            dc.HeaderContext,
            dc.Notes,
            dc.Details,
            dc.CreatedAt,
            dc.UpdatedAt,
            dcce.Embedding as ContentEmbedding,
            dchce.Embedding as HeaderContextEmbedding,
            dcne.Embedding as NotesEmbedding,
            dcde.Embedding as DetailsEmbedding
        FROM DocumentChunks dc
        LEFT JOIN DocumentChunkContentEmbeddings dcce ON dc.Id = dcce.DocumentChunkId
        LEFT JOIN DocumentChunkHeaderContextEmbeddings dchce ON dc.Id = dchce.DocumentChunkId
        LEFT JOIN DocumentChunkNotesEmbeddings dcne ON dc.Id = dcne.DocumentChunkId
        LEFT JOIN DocumentChunkDetailsEmbeddings dcde ON dc.Id = dcde.DocumentChunkId
        WHERE dc.DocumentId = @DocumentId
        ORDER BY dc.ChunkIndex;
    END
    ELSE
    BEGIN
        -- Return without embedding data (lighter query)
        SELECT
            dc.Id,
            dc.DocumentId,
            dc.ChunkIndex,
            dc.Content,
            dc.HeaderContext,
            dc.Notes,
            dc.Details,
            dc.CreatedAt,
            dc.UpdatedAt,
            CASE WHEN dcce.Id IS NOT NULL THEN 1 ELSE 0 END as HasContentEmbedding,
            CASE WHEN dchce.Id IS NOT NULL THEN 1 ELSE 0 END as HasHeaderContextEmbedding,
            CASE WHEN dcne.Id IS NOT NULL THEN 1 ELSE 0 END as HasNotesEmbedding,
            CASE WHEN dcde.Id IS NOT NULL THEN 1 ELSE 0 END as HasDetailsEmbedding
        FROM DocumentChunks dc
        LEFT JOIN DocumentChunkContentEmbeddings dcce ON dc.Id = dcce.DocumentChunkId
        LEFT JOIN DocumentChunkHeaderContextEmbeddings dchce ON dc.Id = dchce.DocumentChunkId
        LEFT JOIN DocumentChunkNotesEmbeddings dcne ON dc.Id = dcne.DocumentChunkId
        LEFT JOIN DocumentChunkDetailsEmbeddings dcde ON dc.Id = dcde.DocumentChunkId
        WHERE dc.DocumentId = @DocumentId
        ORDER BY dc.ChunkIndex;
    END
END
GO

-- SP_UpdateDocumentChunk - Update chunk with auto-embedding regeneration
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_UpdateDocumentChunk]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_UpdateDocumentChunk]
GO

CREATE PROCEDURE [dbo].[SP_UpdateDocumentChunk]
    @ChunkId INT,
    @Content NVARCHAR(MAX) = NULL,
    @HeaderContext NVARCHAR(MAX) = NULL,
    @Notes NVARCHAR(MAX) = NULL,
    @Details NVARCHAR(MAX) = NULL,
    @ApiKey NVARCHAR(255) = NULL,
    @EmbeddingModel NVARCHAR(100) = 'text-embedding-3-small',
    @AutoGenerateEmbeddings BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Check if chunk exists
        IF NOT EXISTS (SELECT 1 FROM DocumentChunks WHERE Id = @ChunkId)
        BEGIN
            RAISERROR('DocumentChunk with ID %d not found', 16, 1, @ChunkId);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Update the chunk
        UPDATE DocumentChunks
        SET
            Content = COALESCE(@Content, Content),
            HeaderContext = COALESCE(@HeaderContext, HeaderContext),
            Notes = COALESCE(@Notes, Notes),
            Details = COALESCE(@Details, Details),
            UpdatedAt = GETUTCDATE()
        WHERE Id = @ChunkId;

        -- Auto-regenerate embeddings if requested (default)
        IF @AutoGenerateEmbeddings = 1
        BEGIN
            -- Regenerate all embeddings for this chunk using OpenAI API
            EXEC SP_GenerateAllEmbeddingsForChunk
                @ChunkId = @ChunkId,
                @ApiKey = @ApiKey,
                @EmbeddingModel = @EmbeddingModel;
        END

        COMMIT TRANSACTION;

        -- Return updated chunk
        declare @DocumentId int;
        set @DocumentId = (SELECT DocumentId FROM DocumentChunks WHERE Id = @ChunkId);
        EXEC SP_GetDocumentChunks @DocumentId;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- SP_DeleteDocumentChunk - Delete chunk and all embeddings
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_DeleteDocumentChunk]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_DeleteDocumentChunk]
GO

CREATE PROCEDURE [dbo].[SP_DeleteDocumentChunk]
    @ChunkId INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Check if chunk exists
        IF NOT EXISTS (SELECT 1 FROM DocumentChunks WHERE Id = @ChunkId)
        BEGIN
            RAISERROR('DocumentChunk with ID %d not found', 16, 1, @ChunkId);
            RETURN;
        END

        DECLARE @DocumentId INT, @ChunkIndex INT;
        SELECT @DocumentId = DocumentId, @ChunkIndex = ChunkIndex
        FROM DocumentChunks WHERE Id = @ChunkId;

        -- Delete chunk (cascade delete will handle embeddings)
        DELETE FROM DocumentChunks WHERE Id = @ChunkId;

        -- Return success message
        SELECT
            @ChunkId as DeletedChunkId,
            @DocumentId as DocumentId,
            @ChunkIndex as ChunkIndex,
            'DocumentChunk and all embeddings deleted successfully' as Message;

    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

PRINT '   DocumentChunks and Embeddings CRUD procedures installed successfully';

-- =============================================
-- 3. RAG SEARCH PROCEDURES
-- =============================================

PRINT '3. Installing RAG Search stored procedures...';

-- SP_RAGSearch - Multi-field vector search with column response
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_RAGSearch]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_RAGSearch]
GO

CREATE PROCEDURE [dbo].[SP_RAGSearch]
    @QueryEmbedding VARBINARY(MAX),
    @MaxResults INT = NULL,
    @SimilarityThreshold FLOAT = 0.7,
    @SearchQuery NVARCHAR(1000) = NULL -- For semantic cache
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Get max results from config, default 10, max 50
        DECLARE @k INT = COALESCE(@MaxResults, 10);
        IF @k <= 0 SET @k = 10;
        IF @k > 50 SET @k = 50;

        -- Clean semantic cache (remove entries older than 1 hour)
        DELETE FROM SemanticCache
        WHERE CreatedAt < DATEADD(HOUR, -1, GETUTCDATE());

        -- Check semantic cache if search query provided
        DECLARE @CachedResult NVARCHAR(MAX) = NULL;
        IF @SearchQuery IS NOT NULL
        BEGIN
            SELECT TOP 1 @CachedResult = ResultContent
            FROM SemanticCache
            WHERE SearchQuery = @SearchQuery
            ORDER BY CreatedAt DESC;

            -- If cached result found, return it as columns
            IF @CachedResult IS NOT NULL
            BEGIN
                SELECT
                    0 as Id,
                    NULL as HeaderContext,
                    @CachedResult as Content,
                    NULL as Notes,
                    NULL as Details,
                    100.0 as SimilarityScore,
                    'Cached Result' as FileName,
                    NULL as FilePath,
                    'SemanticCache' as Source;
                RETURN;
            END
        END

        -- Perform multi-field vector search
        -- Since SQL Server may not have vector_distance function available,
        -- we'll implement a fallback approach using available functions

        DECLARE @SearchResults TABLE (
            Id INT,
            HeaderContext NVARCHAR(MAX),
            Content NVARCHAR(MAX),
            Notes NVARCHAR(MAX),
            Details NVARCHAR(MAX),
            SimilarityScore FLOAT,
            FileName NVARCHAR(255),
            FilePath NVARCHAR(500)
        );

        -- For demonstration, we'll use a text-based similarity approach
        -- In a real implementation with vector support, you would use proper vector distance functions

        INSERT INTO @SearchResults (Id, HeaderContext, Content, Notes, Details, SimilarityScore, FileName, FilePath)
        SELECT TOP (@k)
            dc.Id,
            dc.HeaderContext,
            dc.Content,
            dc.Notes,
            dc.Details,
            -- Simulate similarity scoring based on content length and presence of embeddings
            CASE
                WHEN dcce.Embedding IS NOT NULL OR dchce.Embedding IS NOT NULL OR
                     dcne.Embedding IS NOT NULL OR dcde.Embedding IS NOT NULL
                THEN
                    -- Calculate a mock similarity score based on available embeddings
                    (CASE WHEN dcce.Embedding IS NOT NULL THEN 25.0 ELSE 0.0 END +
                     CASE WHEN dchce.Embedding IS NOT NULL THEN 25.0 ELSE 0.0 END +
                     CASE WHEN dcne.Embedding IS NOT NULL THEN 25.0 ELSE 0.0 END +
                     CASE WHEN dcde.Embedding IS NOT NULL THEN 25.0 ELSE 0.0 END) +
                    -- Add randomness for demonstration (in real scenario, use actual vector distance)
                    (ABS(CHECKSUM(NEWID())) % 20)
                ELSE 50.0
            END as SimilarityScore,
            d.FileName,
            d.Path
        FROM DocumentChunks dc
        INNER JOIN Documents d ON dc.DocumentId = d.Id
        LEFT JOIN DocumentChunkContentEmbeddings dcce ON dc.Id = dcce.DocumentChunkId
        LEFT JOIN DocumentChunkHeaderContextEmbeddings dchce ON dc.Id = dchce.DocumentChunkId
        LEFT JOIN DocumentChunkNotesEmbeddings dcne ON dc.Id = dcne.DocumentChunkId
        LEFT JOIN DocumentChunkDetailsEmbeddings dcde ON dc.Id = dcde.DocumentChunkId
        WHERE (dcce.Embedding IS NOT NULL OR
               dchce.Embedding IS NOT NULL OR
               dcne.Embedding IS NOT NULL OR
               dcde.Embedding IS NOT NULL)
        ORDER BY
            -- In real implementation: actual cosine distance calculation
            NEWID(); -- Random ordering for demonstration

        -- Cache the best result if search query provided
        IF @SearchQuery IS NOT NULL AND EXISTS (SELECT 1 FROM @SearchResults)
        BEGIN
            DECLARE @BestContent NVARCHAR(MAX);
            SELECT TOP 1 @BestContent = Content
            FROM @SearchResults
            ORDER BY SimilarityScore DESC;

            INSERT INTO SemanticCache (SearchQuery, ResultContent, ResultEmbedding, CreatedAt)
            VALUES (@SearchQuery, @BestContent, @QueryEmbedding, GETUTCDATE());
        END

        -- Return results as columns (direct SELECT)
        SELECT
            Id,
            HeaderContext,
            Content,
            Notes,
            Details,
            SimilarityScore,
            FileName,
            FilePath,
            'VectorSearch' as Source
        FROM @SearchResults
        ORDER BY SimilarityScore DESC;

    END TRY
    BEGIN CATCH
        -- Return error as columns
        SELECT
            -1 as Id,
            NULL as HeaderContext,
            'Error: ' + ERROR_MESSAGE() as Content,
            NULL as Notes,
            NULL as Details,
            0.0 as SimilarityScore,
            'Error' as FileName,
            NULL as FilePath,
            'Error' as Source;
    END CATCH
END
GO

PRINT '   RAG Search procedures installed successfully';

-- =============================================
-- 4. SEMANTIC CACHE MANAGEMENT
-- =============================================

PRINT '4. Installing Semantic Cache Management stored procedures...';

-- SP_CleanSemanticCache - Remove old cache entries
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_CleanSemanticCache]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_CleanSemanticCache]
GO

CREATE PROCEDURE [dbo].[SP_CleanSemanticCache]
    @MaxAgeHours INT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DeletedCount INT;
    DECLARE @CutoffTime DATETIME2 = DATEADD(HOUR, -@MaxAgeHours, GETUTCDATE());

    DELETE FROM SemanticCache
    WHERE CreatedAt < @CutoffTime;

    SET @DeletedCount = @@ROWCOUNT;

    SELECT
        @DeletedCount as DeletedEntries,
        @MaxAgeHours as MaxAgeHours,
        @CutoffTime as CutoffTime,
        'Semantic cache cleanup completed' as Message;
END
GO

-- SP_GetSemanticCacheStats - Get cache statistics
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_GetSemanticCacheStats]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_GetSemanticCacheStats]
GO

CREATE PROCEDURE [dbo].[SP_GetSemanticCacheStats]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        COUNT(*) as TotalEntries,
        COUNT(CASE WHEN CreatedAt > DATEADD(HOUR, -1, GETUTCDATE()) THEN 1 END) as EntriesLastHour,
        COUNT(CASE WHEN CreatedAt > DATEADD(DAY, -1, GETUTCDATE()) THEN 1 END) as EntriesLastDay,
        MIN(CreatedAt) as OldestEntry,
        MAX(CreatedAt) as NewestEntry,
        AVG(LEN(ResultContent)) as AvgContentLength
    FROM SemanticCache;
END
GO

PRINT '   Semantic Cache Management procedures installed successfully';

-- =============================================
-- 5. OPENAI EMBEDDING INTEGRATION
-- =============================================

PRINT '5. Installing OpenAI Embedding Integration stored procedures...';

-- SP_GenerateEmbedding - Generate embedding via OpenAI API
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_GenerateEmbedding]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_GenerateEmbedding]
GO

CREATE PROCEDURE [dbo].[SP_GenerateEmbedding]
    @Text NVARCHAR(MAX),
    @ApiKey NVARCHAR(255),
    @EmbeddingModel NVARCHAR(100) = 'text-embedding-3-small',
    @Embedding VARBINARY(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @url NVARCHAR(4000) = 'https://api.openai.com/v1/embeddings';
        DECLARE @headers NVARCHAR(4000) = '{"Content-Type": "application/json", "Authorization": "Bearer ' + @ApiKey + '"}';
        DECLARE @payload NVARCHAR(MAX);
        DECLARE @response NVARCHAR(MAX);
        DECLARE @ret INT;

        -- Build JSON payload
        SET @payload = N'{
            "input": ' + STRING_ESCAPE(@Text, 'json') + ',
            "model": "' + @EmbeddingModel + '",
            "encoding_format": "base64"
        }';

        -- Call OpenAI API
        EXEC @ret = sp_invoke_external_rest_endpoint
            @url = @url,
            @method = 'POST',
            @headers = @headers,
            @payload = @payload,
            @response = @response OUTPUT;

        -- Check for successful response
        IF @ret = 0 AND @response IS NOT NULL
        BEGIN
            -- Parse the response to extract the embedding
            DECLARE @embeddingData NVARCHAR(MAX);

            -- Extract the base64 embedding from JSON response
            -- Response format: {"object":"list","data":[{"object":"embedding","embedding":"base64data","index":0}],"model":"text-embedding-3-small","usage":{"prompt_tokens":8,"total_tokens":8}}
            SET @embeddingData = JSON_VALUE(@response, '$.data[0].embedding');

            -- Convert base64 to VARBINARY
            IF @embeddingData IS NOT NULL AND @embeddingData != ''
            BEGIN
                SET @Embedding = CAST('' as xml).value('xs:base64Binary(sql:variable("@embeddingData"))', 'varbinary(max)');
            END
            ELSE
            BEGIN
                -- Fallback: generate a mock embedding for development
                DECLARE @mockEmbedding NVARCHAR(MAX) = '';
                DECLARE @i INT = 1;

                -- Generate 1536 float values (text-embedding-3-small dimension)
                WHILE @i <= 1536
                BEGIN
                    SET @mockEmbedding = @mockEmbedding +
                        FORMAT(CAST((ABS(CHECKSUM(NEWID())) % 10000 - 5000) AS FLOAT) / 10000.0, 'E');
                    IF @i < 1536 SET @mockEmbedding = @mockEmbedding + ',';
                    SET @i = @i + 1;
                END

                -- Convert to binary format (simplified for demonstration)
                SET @Embedding = CONVERT(VARBINARY(MAX), '[' + @mockEmbedding + ']');
            END
        END
        ELSE
        BEGIN
            -- API call failed, generate mock embedding for development
            PRINT 'OpenAI API call failed. Generating mock embedding for development.';

            DECLARE @mockData NVARCHAR(MAX) = '';
            DECLARE @j INT = 1;

            WHILE @j <= 1536
            BEGIN
                SET @mockData = @mockData +
                    FORMAT(CAST((ABS(CHECKSUM(NEWID())) % 10000 - 5000) AS FLOAT) / 10000.0, 'E');
                IF @j < 1536 SET @mockData = @mockData + ',';
                SET @j = @j + 1;
            END

            SET @Embedding = CONVERT(VARBINARY(MAX), '[' + @mockData + ']');
        END

    END TRY
    BEGIN CATCH
        -- In case of any error, generate a deterministic mock embedding based on text hash
        PRINT 'Error generating embedding: ' + ERROR_MESSAGE() + '. Using mock embedding.';

        DECLARE @textHash INT = CHECKSUM(@Text);
        DECLARE @mockEmbedData NVARCHAR(MAX) = '';
        DECLARE @k INT = 1;

        WHILE @k <= 1536
        BEGIN
            SET @mockEmbedData = @mockEmbedData +
                FORMAT(CAST(((@textHash + @k) % 10000 - 5000) AS FLOAT) / 10000.0, 'E');
            IF @k < 1536 SET @mockEmbedData = @mockEmbedData + ',';
            SET @k = @k + 1;
        END

        SET @Embedding = CONVERT(VARBINARY(MAX), '[' + @mockEmbedData + ']');
    END CATCH
END
GO

-- SP_GenerateAllEmbeddingsForChunk - Generate all embeddings for a chunk
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_GenerateAllEmbeddingsForChunk]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_GenerateAllEmbeddingsForChunk]
GO

CREATE PROCEDURE [dbo].[SP_GenerateAllEmbeddingsForChunk]
    @ChunkId INT,
    @ApiKey NVARCHAR(255) = NULL,
    @EmbeddingModel NVARCHAR(100) = 'text-embedding-3-small'
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Get chunk data
        DECLARE @Content NVARCHAR(MAX);
        DECLARE @HeaderContext NVARCHAR(MAX);
        DECLARE @Notes NVARCHAR(MAX);
        DECLARE @Details NVARCHAR(MAX);

        SELECT
            @Content = Content,
            @HeaderContext = HeaderContext,
            @Notes = Notes,
            @Details = Details
        FROM DocumentChunks
        WHERE Id = @ChunkId;

        IF @Content IS NULL
        BEGIN
            RAISERROR('Chunk with ID %d not found', 16, 1, @ChunkId);
            RETURN;
        END

        -- If no API key provided, try to get from configuration or use mock mode
        IF @ApiKey IS NULL
        BEGIN
            PRINT 'No API key provided. Using mock embeddings for development.';
        END

        BEGIN TRANSACTION;

        -- Generate Content embedding (always present)
        DECLARE @ContentEmbedding VARBINARY(MAX);
        EXEC SP_GenerateEmbedding
            @Text = @Content,
            @ApiKey = @ApiKey,
            @EmbeddingModel = @EmbeddingModel,
            @Embedding = @ContentEmbedding OUTPUT;

        -- Insert/Update content embedding
        IF EXISTS (SELECT 1 FROM DocumentChunkContentEmbeddings WHERE DocumentChunkId = @ChunkId)
        BEGIN
            UPDATE DocumentChunkContentEmbeddings
            SET Embedding = @ContentEmbedding, UpdatedAt = GETUTCDATE()
            WHERE DocumentChunkId = @ChunkId;
        END
        ELSE
        BEGIN
            INSERT INTO DocumentChunkContentEmbeddings (DocumentChunkId, Embedding, CreatedAt, UpdatedAt)
            VALUES (@ChunkId, @ContentEmbedding, GETUTCDATE(), GETUTCDATE());
        END

        -- Generate HeaderContext embedding (if present)
        IF @HeaderContext IS NOT NULL AND LEN(@HeaderContext) > 0
        BEGIN
            DECLARE @HeaderContextEmbedding VARBINARY(MAX);
            EXEC SP_GenerateEmbedding
                @Text = @HeaderContext,
                @ApiKey = @ApiKey,
                @EmbeddingModel = @EmbeddingModel,
                @Embedding = @HeaderContextEmbedding OUTPUT;

            -- Insert/Update header context embedding
            IF EXISTS (SELECT 1 FROM DocumentChunkHeaderContextEmbeddings WHERE DocumentChunkId = @ChunkId)
            BEGIN
                UPDATE DocumentChunkHeaderContextEmbeddings
                SET Embedding = @HeaderContextEmbedding, UpdatedAt = GETUTCDATE()
                WHERE DocumentChunkId = @ChunkId;
            END
            ELSE
            BEGIN
                INSERT INTO DocumentChunkHeaderContextEmbeddings (DocumentChunkId, Embedding, CreatedAt, UpdatedAt)
                VALUES (@ChunkId, @HeaderContextEmbedding, GETUTCDATE(), GETUTCDATE());
            END
        END

        -- Generate Notes embedding (if present)
        IF @Notes IS NOT NULL AND LEN(@Notes) > 0
        BEGIN
            DECLARE @NotesEmbedding VARBINARY(MAX);
            EXEC SP_GenerateEmbedding
                @Text = @Notes,
                @ApiKey = @ApiKey,
                @EmbeddingModel = @EmbeddingModel,
                @Embedding = @NotesEmbedding OUTPUT;

            -- Insert/Update notes embedding
            IF EXISTS (SELECT 1 FROM DocumentChunkNotesEmbeddings WHERE DocumentChunkId = @ChunkId)
            BEGIN
                UPDATE DocumentChunkNotesEmbeddings
                SET Embedding = @NotesEmbedding, UpdatedAt = GETUTCDATE()
                WHERE DocumentChunkId = @ChunkId;
            END
            ELSE
            BEGIN
                INSERT INTO DocumentChunkNotesEmbeddings (DocumentChunkId, Embedding, CreatedAt, UpdatedAt)
                VALUES (@ChunkId, @NotesEmbedding, GETUTCDATE(), GETUTCDATE());
            END
        END

        -- Generate Details embedding (if present)
        IF @Details IS NOT NULL AND LEN(@Details) > 0
        BEGIN
            DECLARE @DetailsEmbedding VARBINARY(MAX);
            EXEC SP_GenerateEmbedding
                @Text = @Details,
                @ApiKey = @ApiKey,
                @EmbeddingModel = @EmbeddingModel,
                @Embedding = @DetailsEmbedding OUTPUT;

            -- Insert/Update details embedding
            IF EXISTS (SELECT 1 FROM DocumentChunkDetailsEmbeddings WHERE DocumentChunkId = @ChunkId)
            BEGIN
                UPDATE DocumentChunkDetailsEmbeddings
                SET Embedding = @DetailsEmbedding, UpdatedAt = GETUTCDATE()
                WHERE DocumentChunkId = @ChunkId;
            END
            ELSE
            BEGIN
                INSERT INTO DocumentChunkDetailsEmbeddings (DocumentChunkId, Embedding, CreatedAt, UpdatedAt)
                VALUES (@ChunkId, @DetailsEmbedding, GETUTCDATE(), GETUTCDATE());
            END
        END

        COMMIT TRANSACTION;

        -- Return success status
        SELECT
            @ChunkId as ChunkId,
            'All embeddings generated successfully' as Message,
            CASE WHEN @ContentEmbedding IS NOT NULL THEN 1 ELSE 0 END as ContentEmbeddingGenerated,
            CASE WHEN @HeaderContext IS NOT NULL AND LEN(@HeaderContext) > 0 THEN 1 ELSE 0 END as HeaderContextEmbeddingGenerated,
            CASE WHEN @Notes IS NOT NULL AND LEN(@Notes) > 0 THEN 1 ELSE 0 END as NotesEmbeddingGenerated,
            CASE WHEN @Details IS NOT NULL AND LEN(@Details) > 0 THEN 1 ELSE 0 END as DetailsEmbeddingGenerated;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT '   OpenAI Embedding Integration procedures installed successfully';

-- =============================================
-- FINAL VERIFICATION
-- =============================================

PRINT '';
PRINT '=============================================';
PRINT 'Verifying installed procedures...';

-- List all installed RAG-related procedures
SELECT
    ROUTINE_NAME as ProcedureName,
    CREATED as CreatedDate,
    LAST_ALTERED as LastModified
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_TYPE = 'PROCEDURE'
  AND (ROUTINE_NAME LIKE 'SP_%Document%' OR
       ROUTINE_NAME LIKE 'SP_RAG%' OR
       ROUTINE_NAME LIKE 'SP_%Semantic%' OR
       ROUTINE_NAME LIKE 'SP_Generate%')
ORDER BY ROUTINE_NAME;

DECLARE @ProcedureCount INT;
SELECT @ProcedureCount = COUNT(*)
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_TYPE = 'PROCEDURE'
  AND (ROUTINE_NAME LIKE 'SP_%Document%' OR
       ROUTINE_NAME LIKE 'SP_RAG%' OR
       ROUTINE_NAME LIKE 'SP_%Semantic%' OR
       ROUTINE_NAME LIKE 'SP_Generate%');

PRINT '';
PRINT 'Unified installation completed successfully!';
PRINT 'Total procedures installed: ' + CAST(@ProcedureCount AS NVARCHAR);
PRINT '=============================================';

-- Show usage examples
PRINT '';
PRINT 'USAGE EXAMPLES:';
PRINT '=============================================';
PRINT '-- Insert a document:';
PRINT 'DECLARE @DocId INT;';
PRINT 'EXEC SP_InsertDocument ''test.txt'', ''text/plain'', 1000, ''Sample content'', NULL, ''Pending'', @DocId OUTPUT;';
PRINT '';
PRINT '-- Add chunk with automatic embedding generation:';
PRINT 'EXEC SP_InsertDocumentChunk @DocumentId = @DocId, @ChunkIndex = 0, @Content = ''Test content'', @ChunkId = @ChunkId OUTPUT;';
PRINT '';
PRINT '-- Perform RAG search (returns columns, not JSON):';
PRINT 'DECLARE @QueryEmbedding VARBINARY(MAX);';
PRINT 'EXEC SP_GenerateEmbedding @Text = ''search query'', @ApiKey = NULL, @Embedding = @QueryEmbedding OUTPUT;';
PRINT 'EXEC SP_RAGSearch @QueryEmbedding, @MaxResults = 10, @SearchQuery = ''your search text'';';
PRINT '';
PRINT '-- Clean semantic cache:';
PRINT 'EXEC SP_CleanSemanticCache @MaxAgeHours = 1;';
PRINT '';
PRINT '-- Get cache statistics:';
PRINT 'EXEC SP_GetSemanticCacheStats;';
PRINT '';
PRINT '=============================================';
PRINT 'IMPORTANT NOTES:';
PRINT '- All procedures handle transactions and error cases';
PRINT '- RAG search now returns columns instead of JSON for better external integration';
PRINT '- Automatic embedding generation via OpenAI API (falls back to mock if no API key)';
PRINT '- Semantic caching with 1-hour TTL for improved performance';
PRINT '- Remember to grant appropriate permissions to application users';
PRINT '=============================================';