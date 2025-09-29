-- =============================================
-- RAG Chat Application - Semantic Cache Management Stored Procedures
-- =============================================

-- =============================================
-- SP_CleanSemanticCache - Clean old cache entries
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_CleanSemanticCache]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_CleanSemanticCache]
GO

CREATE PROCEDURE [dbo].[SP_CleanSemanticCache]
    @MaxAgeHours INT = 1
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @CutoffTime DATETIME2 = DATEADD(HOUR, -@MaxAgeHours, GETUTCDATE());

        DECLARE @DeletedCount INT;

        DELETE FROM SemanticCache
        WHERE CreatedAt < @CutoffTime;

        SET @DeletedCount = @@ROWCOUNT;

        SELECT
            @DeletedCount as DeletedEntries,
            @CutoffTime as CutoffTime,
            GETUTCDATE() as CleanedAt,
            'Semantic cache cleaned successfully' as Message;

    END TRY
    BEGIN CATCH
        SELECT
            ERROR_MESSAGE() as ErrorMessage,
            ERROR_NUMBER() as ErrorNumber,
            'Error cleaning semantic cache' as Message;
    END CATCH
END
GO

-- =============================================
-- SP_GetSemanticCacheStats - Get cache statistics
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_GetSemanticCacheStats]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_GetSemanticCacheStats]
GO

CREATE PROCEDURE [dbo].[SP_GetSemanticCacheStats]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        COUNT(*) as TotalCacheEntries,
        COUNT(CASE WHEN CreatedAt >= DATEADD(HOUR, -1, GETUTCDATE()) THEN 1 END) as EntriesLastHour,
        COUNT(CASE WHEN CreatedAt >= DATEADD(HOUR, -24, GETUTCDATE()) THEN 1 END) as EntriesLast24Hours,
        MIN(CreatedAt) as OldestEntry,
        MAX(CreatedAt) as NewestEntry,
        AVG(DATALENGTH(ResultContent)) as AvgContentSize,
        AVG(DATALENGTH(ResultEmbedding)) as AvgEmbeddingSize
    FROM SemanticCache;

    -- Top 10 most recent searches
    SELECT TOP 10
        SearchQuery,
        LEN(ResultContent) as ContentLength,
        CreatedAt,
        DATEDIFF(MINUTE, CreatedAt, GETUTCDATE()) as MinutesAgo
    FROM SemanticCache
    ORDER BY CreatedAt DESC;

    -- Cache hit rate analysis (queries that appear multiple times)
    SELECT
        SearchQuery,
        COUNT(*) as HitCount,
        MIN(CreatedAt) as FirstHit,
        MAX(CreatedAt) as LastHit
    FROM SemanticCache
    GROUP BY SearchQuery
    HAVING COUNT(*) > 1
    ORDER BY COUNT(*) DESC;
END
GO

-- =============================================
-- SP_SearchSemanticCache - Search in semantic cache
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_SearchSemanticCache]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_SearchSemanticCache]
GO

CREATE PROCEDURE [dbo].[SP_SearchSemanticCache]
    @SearchQuery NVARCHAR(1000),
    @ExactMatch BIT = 1,
    @MaxAgeHours INT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CutoffTime DATETIME2 = DATEADD(HOUR, -@MaxAgeHours, GETUTCDATE());

    IF @ExactMatch = 1
    BEGIN
        -- Exact match search
        SELECT TOP 1
            Id,
            SearchQuery,
            ResultContent,
            CreatedAt,
            DATEDIFF(MINUTE, CreatedAt, GETUTCDATE()) as MinutesAgo,
            'ExactMatch' as MatchType
        FROM SemanticCache
        WHERE SearchQuery = @SearchQuery
          AND CreatedAt >= @CutoffTime
        ORDER BY CreatedAt DESC;
    END
    ELSE
    BEGIN
        -- Fuzzy match search (contains)
        SELECT TOP 5
            Id,
            SearchQuery,
            ResultContent,
            CreatedAt,
            DATEDIFF(MINUTE, CreatedAt, GETUTCDATE()) as MinutesAgo,
            'FuzzyMatch' as MatchType
        FROM SemanticCache
        WHERE (SearchQuery LIKE '%' + @SearchQuery + '%' OR @SearchQuery LIKE '%' + SearchQuery + '%')
          AND CreatedAt >= @CutoffTime
        ORDER BY
            CASE WHEN SearchQuery = @SearchQuery THEN 1 ELSE 2 END, -- Exact matches first
            CreatedAt DESC;
    END
END
GO

-- =============================================
-- SP_AddToSemanticCache - Manually add entry to cache
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_AddToSemanticCache]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_AddToSemanticCache]
GO

CREATE PROCEDURE [dbo].[SP_AddToSemanticCache]
    @SearchQuery NVARCHAR(1000),
    @ResultContent NVARCHAR(MAX),
    @ResultEmbedding VARBINARY(MAX),
    @OverwriteExisting BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Check if entry already exists
        IF EXISTS (SELECT 1 FROM SemanticCache WHERE SearchQuery = @SearchQuery)
        BEGIN
            IF @OverwriteExisting = 1
            BEGIN
                UPDATE SemanticCache
                SET
                    ResultContent = @ResultContent,
                    ResultEmbedding = @ResultEmbedding,
                    CreatedAt = GETUTCDATE()
                WHERE SearchQuery = @SearchQuery;

                SELECT
                    'Updated' as Action,
                    @SearchQuery as SearchQuery,
                    GETUTCDATE() as UpdatedAt,
                    'Existing cache entry updated' as Message;
            END
            ELSE
            BEGIN
                SELECT
                    'Skipped' as Action,
                    @SearchQuery as SearchQuery,
                    (SELECT CreatedAt FROM SemanticCache WHERE SearchQuery = @SearchQuery) as ExistingEntryDate,
                    'Cache entry already exists, use @OverwriteExisting = 1 to update' as Message;
            END
        END
        ELSE
        BEGIN
            INSERT INTO SemanticCache (SearchQuery, ResultContent, ResultEmbedding, CreatedAt)
            VALUES (@SearchQuery, @ResultContent, @ResultEmbedding, GETUTCDATE());

            SELECT
                'Added' as Action,
                @SearchQuery as SearchQuery,
                GETUTCDATE() as CreatedAt,
                'New cache entry added successfully' as Message;
        END

    END TRY
    BEGIN CATCH
        SELECT
            'Error' as Action,
            @SearchQuery as SearchQuery,
            ERROR_MESSAGE() as ErrorMessage,
            ERROR_NUMBER() as ErrorNumber;
    END CATCH
END
GO

-- =============================================
-- SP_DeleteFromSemanticCache - Delete specific cache entries
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_DeleteFromSemanticCache]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_DeleteFromSemanticCache]
GO

CREATE PROCEDURE [dbo].[SP_DeleteFromSemanticCache]
    @SearchQuery NVARCHAR(1000) = NULL,
    @CacheId INT = NULL,
    @DeleteAll BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @DeletedCount INT = 0;

        IF @DeleteAll = 1
        BEGIN
            DELETE FROM SemanticCache;
            SET @DeletedCount = @@ROWCOUNT;

            SELECT
                @DeletedCount as DeletedEntries,
                'All cache entries deleted' as Message;
        END
        ELSE IF @CacheId IS NOT NULL
        BEGIN
            DELETE FROM SemanticCache WHERE Id = @CacheId;
            SET @DeletedCount = @@ROWCOUNT;

            SELECT
                @DeletedCount as DeletedEntries,
                @CacheId as CacheId,
                'Cache entry deleted by ID' as Message;
        END
        ELSE IF @SearchQuery IS NOT NULL
        BEGIN
            DELETE FROM SemanticCache WHERE SearchQuery = @SearchQuery;
            SET @DeletedCount = @@ROWCOUNT;

            SELECT
                @DeletedCount as DeletedEntries,
                @SearchQuery as SearchQuery,
                'Cache entries deleted by search query' as Message;
        END
        ELSE
        BEGIN
            SELECT
                0 as DeletedEntries,
                'No deletion criteria provided' as Message;
        END

    END TRY
    BEGIN CATCH
        SELECT
            ERROR_MESSAGE() as ErrorMessage,
            ERROR_NUMBER() as ErrorNumber,
            'Error deleting from semantic cache' as Message;
    END CATCH
END
GO

PRINT 'Semantic Cache Management stored procedures created successfully'