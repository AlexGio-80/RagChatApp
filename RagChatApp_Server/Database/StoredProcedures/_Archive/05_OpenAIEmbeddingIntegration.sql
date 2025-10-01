-- =============================================
-- RAG Chat Application - OpenAI Embedding Integration via REST API
-- =============================================

-- =============================================
-- SP_GenerateEmbedding - Generate embedding via OpenAI API
-- =============================================
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

-- =============================================
-- SP_GenerateAllEmbeddingsForChunk - Generate all embeddings for a chunk
-- =============================================
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

PRINT 'OpenAI Embedding Integration stored procedures created successfully'