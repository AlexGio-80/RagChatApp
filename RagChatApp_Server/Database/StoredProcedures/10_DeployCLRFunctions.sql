-- =============================================
-- Deploy SQL CLR Vector Functions
-- =============================================
-- This script registers the CLR assembly for vector operations
-- Compatible with SQL Server 2016+ (2017, 2019, 2022, 2025)

USE [OSL_AI]
GO

PRINT '=============================================';
PRINT 'Deploying SQL CLR Vector Functions';
PRINT '=============================================';
PRINT 'Database: ' + DB_NAME();
PRINT 'Deploy Date: ' + CONVERT(NVARCHAR, GETUTCDATE(), 120) + ' UTC';
PRINT '';

-- =============================================
-- Step 1: Enable CLR Integration
-- =============================================
PRINT 'Step 1: Enabling CLR integration...';

-- Check if CLR is enabled
DECLARE @ClrEnabled INT;
SELECT @ClrEnabled = CAST(value_in_use AS INT)
FROM sys.configurations
WHERE name = 'clr enabled';

IF @ClrEnabled = 0
BEGIN
    PRINT '  Enabling CLR integration (requires RECONFIGURE)...';
    EXEC sp_configure 'clr enabled', 1;
    RECONFIGURE;
    PRINT '  ✓ CLR integration enabled';
END
ELSE
BEGIN
    PRINT '  ✓ CLR integration already enabled';
END

PRINT '';

-- =============================================
-- Step 2: Set Database Trustworthy (if needed)
-- =============================================
PRINT 'Step 2: Checking database trustworthiness...';

DECLARE @IsTrustworthy BIT;
SELECT @IsTrustworthy = is_trustworthy_on
FROM sys.databases
WHERE name = DB_NAME();

IF @IsTrustworthy = 0
BEGIN
    PRINT '  Setting database as TRUSTWORTHY...';
    PRINT '  Note: This is required for CLR SAFE assemblies in some configurations';

    DECLARE @SetTrustworthySQL NVARCHAR(MAX);
    SET @SetTrustworthySQL = 'ALTER DATABASE ' + QUOTENAME(DB_NAME()) + ' SET TRUSTWORTHY ON';
    EXEC sp_executesql @SetTrustworthySQL;

    PRINT '  ✓ Database set as TRUSTWORTHY';
END
ELSE
BEGIN
    PRINT '  ✓ Database already TRUSTWORTHY';
END

PRINT '';

-- =============================================
-- Step 3: Drop existing functions and assembly
-- =============================================
PRINT 'Step 3: Cleaning up existing CLR objects...';

IF OBJECT_ID('dbo.fn_CosineSimilarity') IS NOT NULL
BEGIN
    DROP FUNCTION dbo.fn_CosineSimilarity;
    PRINT '  ✓ Dropped existing fn_CosineSimilarity';
END

IF OBJECT_ID('dbo.fn_EmbeddingToString') IS NOT NULL
BEGIN
    DROP FUNCTION dbo.fn_EmbeddingToString;
    PRINT '  ✓ Dropped existing fn_EmbeddingToString';
END

IF OBJECT_ID('dbo.fn_EmbeddingDimension') IS NOT NULL
BEGIN
    DROP FUNCTION dbo.fn_EmbeddingDimension;
    PRINT '  ✓ Dropped existing fn_EmbeddingDimension';
END

IF OBJECT_ID('dbo.fn_IsValidEmbedding') IS NOT NULL
BEGIN
    DROP FUNCTION dbo.fn_IsValidEmbedding;
    PRINT '  ✓ Dropped existing fn_IsValidEmbedding';
END

IF EXISTS (SELECT * FROM sys.assemblies WHERE name = 'SqlVectorFunctions')
BEGIN
    DROP ASSEMBLY SqlVectorFunctions;
    PRINT '  ✓ Dropped existing SqlVectorFunctions assembly';
END

PRINT '';

-- =============================================
-- Step 4: Create Assembly from DLL
-- =============================================
PRINT 'Step 4: Registering CLR assembly...';
PRINT '  Assembly path: C:\OSL\Claude\RagChatApp\RagChatApp_Server\Database\SqlClr\bin\Release\SqlVectorFunctions.dll';
PRINT '  Note: Using TRUSTWORTHY database to allow SAFE assembly';
PRINT '';

-- Load assembly from file
-- Using SAFE permission set with TRUSTWORTHY database
CREATE ASSEMBLY SqlVectorFunctions
FROM 'C:\OSL\Claude\RagChatApp\RagChatApp_Server\Database\SqlClr\bin\Release\SqlVectorFunctions.dll'
WITH PERMISSION_SET = SAFE;

-- Alternative: If SAFE fails, uncomment below for EXTERNAL_ACCESS
-- This requires the assembly to be signed or database to be TRUSTWORTHY
-- CREATE ASSEMBLY SqlVectorFunctions
-- FROM 'C:\OSL\Claude\RagChatApp\RagChatApp_Server\Database\SqlClr\bin\Release\SqlVectorFunctions.dll'
-- WITH PERMISSION_SET = EXTERNAL_ACCESS;

PRINT '  ✓ SqlVectorFunctions assembly registered';
PRINT '';

-- =============================================
-- Step 5: Create SQL Functions
-- =============================================
PRINT 'Step 5: Creating SQL CLR functions...';
PRINT '';
GO

-- Cosine Similarity Function
CREATE FUNCTION dbo.fn_CosineSimilarity(
    @embedding1 VARBINARY(MAX),
    @embedding2 VARBINARY(MAX)
)
RETURNS FLOAT
AS EXTERNAL NAME SqlVectorFunctions.SqlVectorFunctions.CosineSimilarity;
GO

-- Embedding to String (for debugging)
CREATE FUNCTION dbo.fn_EmbeddingToString(
    @embedding VARBINARY(MAX),
    @maxValues INT
)
RETURNS NVARCHAR(MAX)
AS EXTERNAL NAME SqlVectorFunctions.SqlVectorFunctions.EmbeddingToString;
GO

-- Embedding Dimension
CREATE FUNCTION dbo.fn_EmbeddingDimension(
    @embedding VARBINARY(MAX)
)
RETURNS INT
AS EXTERNAL NAME SqlVectorFunctions.SqlVectorFunctions.EmbeddingDimension;
GO

-- Validate Embedding
CREATE FUNCTION dbo.fn_IsValidEmbedding(
    @embedding VARBINARY(MAX)
)
RETURNS BIT
AS EXTERNAL NAME SqlVectorFunctions.SqlVectorFunctions.IsValidEmbedding;
GO

PRINT '  ✓ fn_CosineSimilarity created';
PRINT '  ✓ fn_EmbeddingToString created';
PRINT '  ✓ fn_EmbeddingDimension created';
PRINT '  ✓ fn_IsValidEmbedding created';
GO

PRINT '';

-- =============================================
-- Step 6: Test Functions
-- =============================================
PRINT 'Step 6: Testing CLR functions...';

-- Get test embeddings
DECLARE @TestEmb1 VARBINARY(MAX), @TestEmb2 VARBINARY(MAX);

SELECT TOP 1 @TestEmb1 = Embedding
FROM DocumentChunkContentEmbeddings
WHERE Embedding IS NOT NULL
ORDER BY DocumentChunkId;

SELECT TOP 1 @TestEmb2 = Embedding
FROM DocumentChunkContentEmbeddings
WHERE Embedding IS NOT NULL
ORDER BY DocumentChunkId DESC;

IF @TestEmb1 IS NOT NULL AND @TestEmb2 IS NOT NULL
BEGIN
    -- Test dimension
    DECLARE @Dimension INT = dbo.fn_EmbeddingDimension(@TestEmb1);
    PRINT '  Test embedding dimension: ' + CAST(@Dimension AS NVARCHAR);

    -- Test validation
    DECLARE @IsValid BIT = dbo.fn_IsValidEmbedding(@TestEmb1);
    PRINT '  Test embedding is valid: ' + CAST(@IsValid AS NVARCHAR);

    -- Test cosine similarity
    DECLARE @Similarity FLOAT = dbo.fn_CosineSimilarity(@TestEmb1, @TestEmb2);
    PRINT '  Test similarity (different vectors): ' + CAST(@Similarity AS NVARCHAR(20));

    -- Test same vector (should be 1.0)
    DECLARE @SelfSimilarity FLOAT = dbo.fn_CosineSimilarity(@TestEmb1, @TestEmb1);
    PRINT '  Test similarity (same vector): ' + CAST(@SelfSimilarity AS NVARCHAR(20));

    IF ABS(@SelfSimilarity - 1.0) < 0.001
        PRINT '  ✓ Cosine similarity function working correctly!';
    ELSE
        PRINT '  ⚠ Warning: Self-similarity should be 1.0, got ' + CAST(@SelfSimilarity AS NVARCHAR(20));

    -- Test string conversion (first 5 values)
    DECLARE @EmbString NVARCHAR(MAX) = dbo.fn_EmbeddingToString(@TestEmb1, 5);
    PRINT '  Sample embedding values: ' + LEFT(@EmbString, 100) + '...';
END
ELSE
BEGIN
    PRINT '  ⚠ No test embeddings available';
END

PRINT '';

-- =============================================
-- Summary
-- =============================================
PRINT '=============================================';
PRINT 'SQL CLR Vector Functions Deployed Successfully!';
PRINT '=============================================';
PRINT '';
PRINT 'Available Functions:';
PRINT '  • dbo.fn_CosineSimilarity(embedding1, embedding2) → FLOAT';
PRINT '    Calculates cosine similarity between two embeddings';
PRINT '    Returns: -1.0 to 1.0 (higher = more similar)';
PRINT '';
PRINT '  • dbo.fn_EmbeddingDimension(embedding) → INT';
PRINT '    Returns the dimension of an embedding vector';
PRINT '';
PRINT '  • dbo.fn_IsValidEmbedding(embedding) → BIT';
PRINT '    Validates if a VARBINARY is a valid embedding';
PRINT '';
PRINT '  • dbo.fn_EmbeddingToString(embedding, maxValues) → NVARCHAR';
PRINT '    Converts embedding to readable string (for debugging)';
PRINT '';
PRINT 'Usage Example:';
PRINT '  SELECT TOP 10';
PRINT '      dc.Content,';
PRINT '      dbo.fn_CosineSimilarity(ce.Embedding, @QueryEmbedding) AS Similarity';
PRINT '  FROM DocumentChunks dc';
PRINT '  INNER JOIN DocumentChunkContentEmbeddings ce ON dc.Id = ce.DocumentChunkId';
PRINT '  WHERE dbo.fn_IsValidEmbedding(ce.Embedding) = 1';
PRINT '  ORDER BY Similarity DESC;';
PRINT '';
PRINT 'Next Step: Update SP_RAGSearch_MultiProvider to use fn_CosineSimilarity';
PRINT '=============================================';
