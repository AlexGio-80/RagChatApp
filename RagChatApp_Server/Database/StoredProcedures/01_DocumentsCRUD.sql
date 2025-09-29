-- =============================================
-- RAG Chat Application - Documents CRUD Stored Procedures
-- =============================================

-- =============================================
-- SP_InsertDocument - Insert a new document
-- =============================================
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
            Status
        )
        VALUES (
            @FileName,
            @ContentType,
            @Size,
            @Content,
            @Path,
            GETUTCDATE(),
            @Status
        );

        SET @DocumentId = SCOPE_IDENTITY();

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

-- =============================================
-- SP_GetDocument - Retrieve document by ID
-- =============================================
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

-- =============================================
-- SP_GetAllDocuments - Retrieve all documents with pagination
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_GetAllDocuments]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_GetAllDocuments]
GO

CREATE PROCEDURE [dbo].[SP_GetAllDocuments]
    @PageNumber INT = 1,
    @PageSize INT = 50,
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
        LEN(Content) as ContentLength, -- Don't return full content for list view
        Path,
        UploadedAt,
        ProcessedAt,
        Status,
        COUNT(*) OVER() as TotalCount
    FROM Documents
    WHERE (@Status IS NULL OR Status = @Status)
    ORDER BY UploadedAt DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- =============================================
-- SP_UpdateDocument - Update existing document
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_UpdateDocument]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_UpdateDocument]
GO

CREATE PROCEDURE [dbo].[SP_UpdateDocument]
    @DocumentId INT,
    @FileName NVARCHAR(255) = NULL,
    @ContentType NVARCHAR(100) = NULL,
    @Size BIGINT = NULL,
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

        -- If content is being updated, delete all existing chunks and embeddings
        IF @Content IS NOT NULL
        BEGIN
            DELETE FROM DocumentChunks WHERE DocumentId = @DocumentId;

            -- Update status to Pending for reprocessing
            SET @Status = COALESCE(@Status, 'Pending');
            SET @ProcessedAt = NULL;
        END

        UPDATE Documents
        SET
            FileName = COALESCE(@FileName, FileName),
            ContentType = COALESCE(@ContentType, ContentType),
            Size = COALESCE(@Size, Size),
            Content = COALESCE(@Content, Content),
            Path = COALESCE(@Path, Path),
            Status = COALESCE(@Status, Status),
            ProcessedAt = COALESCE(@ProcessedAt, ProcessedAt)
        WHERE Id = @DocumentId;

        -- Return updated document
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

-- =============================================
-- SP_DeleteDocument - Delete document and all related data
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_DeleteDocument]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_DeleteDocument]
GO

CREATE PROCEDURE [dbo].[SP_DeleteDocument]
    @DocumentId INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Check if document exists
        IF NOT EXISTS (SELECT 1 FROM Documents WHERE Id = @DocumentId)
        BEGIN
            RAISERROR('Document with ID %d not found', 16, 1, @DocumentId);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Get document info before deletion
        DECLARE @FileName NVARCHAR(255);
        SELECT @FileName = FileName FROM Documents WHERE Id = @DocumentId;

        -- Delete document (cascade delete will handle chunks and embeddings)
        DELETE FROM Documents WHERE Id = @DocumentId;

        COMMIT TRANSACTION;

        -- Return success message
        SELECT
            @DocumentId as DeletedDocumentId,
            @FileName as DeletedFileName,
            'Document and all related data deleted successfully' as Message;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT 'Documents CRUD stored procedures created successfully'