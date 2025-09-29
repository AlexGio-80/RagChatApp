-- =============================================
-- RAG Chat Application - DocumentChunks and Embeddings CRUD Stored Procedures
-- =============================================

-- =============================================
-- SP_InsertDocumentChunk - Insert a new document chunk with embeddings
-- =============================================
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
    @ContentEmbedding VARBINARY(MAX) = NULL,
    @HeaderContextEmbedding VARBINARY(MAX) = NULL,
    @NotesEmbedding VARBINARY(MAX) = NULL,
    @DetailsEmbedding VARBINARY(MAX) = NULL,
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

        -- Insert embeddings if provided
        IF @ContentEmbedding IS NOT NULL
        BEGIN
            INSERT INTO DocumentChunkContentEmbeddings (
                DocumentChunkId,
                Embedding,
                CreatedAt,
                UpdatedAt
            ) VALUES (
                @ChunkId,
                @ContentEmbedding,
                GETUTCDATE(),
                GETUTCDATE()
            );
        END

        IF @HeaderContextEmbedding IS NOT NULL AND @HeaderContext IS NOT NULL
        BEGIN
            INSERT INTO DocumentChunkHeaderContextEmbeddings (
                DocumentChunkId,
                Embedding,
                CreatedAt,
                UpdatedAt
            ) VALUES (
                @ChunkId,
                @HeaderContextEmbedding,
                GETUTCDATE(),
                GETUTCDATE()
            );
        END

        IF @NotesEmbedding IS NOT NULL AND @Notes IS NOT NULL
        BEGIN
            INSERT INTO DocumentChunkNotesEmbeddings (
                DocumentChunkId,
                Embedding,
                CreatedAt,
                UpdatedAt
            ) VALUES (
                @ChunkId,
                @NotesEmbedding,
                GETUTCDATE(),
                GETUTCDATE()
            );
        END

        IF @DetailsEmbedding IS NOT NULL AND @Details IS NOT NULL
        BEGIN
            INSERT INTO DocumentChunkDetailsEmbeddings (
                DocumentChunkId,
                Embedding,
                CreatedAt,
                UpdatedAt
            ) VALUES (
                @ChunkId,
                @DetailsEmbedding,
                GETUTCDATE(),
                GETUTCDATE()
            );
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

-- =============================================
-- SP_GetDocumentChunks - Retrieve chunks for a document
-- =============================================
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

-- =============================================
-- SP_UpdateDocumentChunk - Update existing chunk and embeddings
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_UpdateDocumentChunk]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_UpdateDocumentChunk]
GO

CREATE PROCEDURE [dbo].[SP_UpdateDocumentChunk]
    @ChunkId INT,
    @Content NVARCHAR(MAX) = NULL,
    @HeaderContext NVARCHAR(MAX) = NULL,
    @Notes NVARCHAR(MAX) = NULL,
    @Details NVARCHAR(MAX) = NULL,
    @ContentEmbedding VARBINARY(MAX) = NULL,
    @HeaderContextEmbedding VARBINARY(MAX) = NULL,
    @NotesEmbedding VARBINARY(MAX) = NULL,
    @DetailsEmbedding VARBINARY(MAX) = NULL,
    @UpdateEmbeddings BIT = 0
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

        -- Update embeddings if requested
        IF @UpdateEmbeddings = 1
        BEGIN
            -- Update or insert content embedding
            IF @ContentEmbedding IS NOT NULL
            BEGIN
                IF EXISTS (SELECT 1 FROM DocumentChunkContentEmbeddings WHERE DocumentChunkId = @ChunkId)
                    UPDATE DocumentChunkContentEmbeddings
                    SET Embedding = @ContentEmbedding, UpdatedAt = GETUTCDATE()
                    WHERE DocumentChunkId = @ChunkId;
                ELSE
                    INSERT INTO DocumentChunkContentEmbeddings (DocumentChunkId, Embedding, CreatedAt, UpdatedAt)
                    VALUES (@ChunkId, @ContentEmbedding, GETUTCDATE(), GETUTCDATE());
            END

            -- Update or insert header context embedding
            IF @HeaderContextEmbedding IS NOT NULL
            BEGIN
                IF EXISTS (SELECT 1 FROM DocumentChunkHeaderContextEmbeddings WHERE DocumentChunkId = @ChunkId)
                    UPDATE DocumentChunkHeaderContextEmbeddings
                    SET Embedding = @HeaderContextEmbedding, UpdatedAt = GETUTCDATE()
                    WHERE DocumentChunkId = @ChunkId;
                ELSE
                    INSERT INTO DocumentChunkHeaderContextEmbeddings (DocumentChunkId, Embedding, CreatedAt, UpdatedAt)
                    VALUES (@ChunkId, @HeaderContextEmbedding, GETUTCDATE(), GETUTCDATE());
            END

            -- Update or insert notes embedding
            IF @NotesEmbedding IS NOT NULL
            BEGIN
                IF EXISTS (SELECT 1 FROM DocumentChunkNotesEmbeddings WHERE DocumentChunkId = @ChunkId)
                    UPDATE DocumentChunkNotesEmbeddings
                    SET Embedding = @NotesEmbedding, UpdatedAt = GETUTCDATE()
                    WHERE DocumentChunkId = @ChunkId;
                ELSE
                    INSERT INTO DocumentChunkNotesEmbeddings (DocumentChunkId, Embedding, CreatedAt, UpdatedAt)
                    VALUES (@ChunkId, @NotesEmbedding, GETUTCDATE(), GETUTCDATE());
            END

            -- Update or insert details embedding
            IF @DetailsEmbedding IS NOT NULL
            BEGIN
                IF EXISTS (SELECT 1 FROM DocumentChunkDetailsEmbeddings WHERE DocumentChunkId = @ChunkId)
                    UPDATE DocumentChunkDetailsEmbeddings
                    SET Embedding = @DetailsEmbedding, UpdatedAt = GETUTCDATE()
                    WHERE DocumentChunkId = @ChunkId;
                ELSE
                    INSERT INTO DocumentChunkDetailsEmbeddings (DocumentChunkId, Embedding, CreatedAt, UpdatedAt)
                    VALUES (@ChunkId, @DetailsEmbedding, GETUTCDATE(), GETUTCDATE());
            END
        END

        COMMIT TRANSACTION;

        -- Return updated chunk
        EXEC SP_GetDocumentChunks @DocumentId = (SELECT DocumentId FROM DocumentChunks WHERE Id = @ChunkId);

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- =============================================
-- SP_DeleteDocumentChunk - Delete chunk and all embeddings
-- =============================================
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

PRINT 'DocumentChunks and Embeddings CRUD stored procedures created successfully'