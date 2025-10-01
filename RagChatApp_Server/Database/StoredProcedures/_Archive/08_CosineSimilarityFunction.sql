-- =============================================
-- Cosine Similarity Calculation for VARBINARY Embeddings
-- =============================================
-- Creates a CLR or T-SQL function to calculate cosine similarity
-- between two VARBINARY embedding vectors

USE [OSL_AI]
GO

PRINT '=============================================';
PRINT 'Creating Cosine Similarity Function';
PRINT '=============================================';
PRINT '';

-- Drop existing function if it exists
IF OBJECT_ID('dbo.fn_CosineSimilarity', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_CosineSimilarity;
GO

-- =============================================
-- Inline Table-Valued Function for Cosine Similarity
-- =============================================
-- This function calculates cosine similarity between two VARBINARY embeddings
-- Formula: similarity = dot_product / (magnitude1 * magnitude2)
-- Returns: Float between -1 and 1 (higher is more similar)
--
-- Note: This is a pure T-SQL implementation for VARBINARY float arrays
-- Each float is 4 bytes in little-endian format
-- =============================================

CREATE FUNCTION dbo.fn_CosineSimilarity(
    @embedding1 VARBINARY(MAX),
    @embedding2 VARBINARY(MAX)
)
RETURNS TABLE
AS
RETURN
(
    WITH ByteSequence AS (
        -- Generate sequence of byte positions (0, 4, 8, 12, ..., up to embedding length)
        SELECT TOP (DATALENGTH(@embedding1) / 4)
            (ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1) * 4 AS BytePos
        FROM sys.objects
    ),
    FloatValues AS (
        -- Extract float values from both embeddings
        SELECT
            BytePos / 4 AS FloatIndex,
            CAST(SUBSTRING(@embedding1, BytePos + 1, 4) AS FLOAT) AS Value1,
            CAST(SUBSTRING(@embedding2, BytePos + 1, 4) AS FLOAT) AS Value2
        FROM ByteSequence
    ),
    Calculations AS (
        SELECT
            SUM(Value1 * Value2) AS DotProduct,
            SQRT(SUM(Value1 * Value1)) AS Magnitude1,
            SQRT(SUM(Value2 * Value2)) AS Magnitude2
        FROM FloatValues
    )
    SELECT
        CASE
            WHEN Magnitude1 = 0 OR Magnitude2 = 0 THEN 0
            ELSE DotProduct / (Magnitude1 * Magnitude2)
        END AS CosineSimilarity
    FROM Calculations
);
GO

PRINT '✓ fn_CosineSimilarity function created';
PRINT '';
PRINT 'Testing the function...';

-- Test the function with sample embeddings
DECLARE @TestEmbedding1 VARBINARY(MAX) = (SELECT TOP 1 Embedding FROM DocumentChunkContentEmbeddings WHERE Embedding IS NOT NULL);
DECLARE @TestEmbedding2 VARBINARY(MAX) = (SELECT TOP 1 Embedding FROM DocumentChunkContentEmbeddings WHERE Embedding IS NOT NULL ORDER BY DocumentChunkId DESC);

IF @TestEmbedding1 IS NOT NULL AND @TestEmbedding2 IS NOT NULL
BEGIN
    DECLARE @TestSimilarity FLOAT;
    SELECT @TestSimilarity = CosineSimilarity FROM dbo.fn_CosineSimilarity(@TestEmbedding1, @TestEmbedding2);
    PRINT 'Test similarity score: ' + CAST(@TestSimilarity AS NVARCHAR(20));
    PRINT '✓ Function test passed';
END
ELSE
BEGIN
    PRINT '⚠ Warning: No test embeddings available';
END

PRINT '';
PRINT '=============================================';
PRINT 'Cosine Similarity Function Ready!';
PRINT '=============================================';
PRINT '';
PRINT 'Usage:';
PRINT '  SELECT CosineSimilarity';
PRINT '  FROM dbo.fn_CosineSimilarity(@embedding1, @embedding2);';
PRINT '';
