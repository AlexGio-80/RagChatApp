-- =============================================
-- Migrate VARBINARY Embeddings to VECTOR Type
-- =============================================
-- This script converts VARBINARY(MAX) embedding columns to native VECTOR(768) type
-- Required for using SQL Server 2025's VECTOR_DISTANCE function

USE [OSL_AI]
GO

PRINT '=============================================';
PRINT 'Migrating Embeddings to VECTOR Type';
PRINT '=============================================';
PRINT 'Database: ' + DB_NAME();
PRINT 'Migration Date: ' + CONVERT(NVARCHAR, GETUTCDATE(), 120) + ' UTC';
PRINT '';
PRINT 'WARNING: This operation will';
PRINT '  - Convert VARBINARY(MAX) to VECTOR(768)';
PRINT '  - Require reading/writing all embedding data';
PRINT '  - Take several minutes depending on data size';
PRINT '';

-- Check current embedding count
DECLARE @EmbeddingCount INT;
SELECT @EmbeddingCount = COUNT(*) FROM DocumentChunkContentEmbeddings WHERE Embedding IS NOT NULL;
PRINT 'Total embeddings to migrate: ' + CAST(@EmbeddingCount AS NVARCHAR);
PRINT '';

-- =============================================
-- Step 1: Add new VECTOR columns
-- =============================================
PRINT 'Step 1: Adding new VECTOR columns...';

-- Content Embeddings
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentChunkContentEmbeddings' AND COLUMN_NAME = 'EmbeddingVector')
BEGIN
    ALTER TABLE DocumentChunkContentEmbeddings ADD EmbeddingVector VECTOR(768) NULL;
    PRINT '  ✓ Added EmbeddingVector to DocumentChunkContentEmbeddings';
END
ELSE
    PRINT '  ⚠ EmbeddingVector already exists in DocumentChunkContentEmbeddings';

-- Header Context Embeddings
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentChunkHeaderContextEmbeddings' AND COLUMN_NAME = 'EmbeddingVector')
BEGIN
    ALTER TABLE DocumentChunkHeaderContextEmbeddings ADD EmbeddingVector VECTOR(768) NULL;
    PRINT '  ✓ Added EmbeddingVector to DocumentChunkHeaderContextEmbeddings';
END
ELSE
    PRINT '  ⚠ EmbeddingVector already exists in DocumentChunkHeaderContextEmbeddings';

-- Notes Embeddings
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentChunkNotesEmbeddings' AND COLUMN_NAME = 'EmbeddingVector')
BEGIN
    ALTER TABLE DocumentChunkNotesEmbeddings ADD EmbeddingVector VECTOR(768) NULL;
    PRINT '  ✓ Added EmbeddingVector to DocumentChunkNotesEmbeddings';
END
ELSE
    PRINT '  ⚠ EmbeddingVector already exists in DocumentChunkNotesEmbeddings';

-- Details Embeddings
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentChunkDetailsEmbeddings' AND COLUMN_NAME = 'EmbeddingVector')
BEGIN
    ALTER TABLE DocumentChunkDetailsEmbeddings ADD EmbeddingVector VECTOR(768) NULL;
    PRINT '  ✓ Added EmbeddingVector to DocumentChunkDetailsEmbeddings';
END
ELSE
    PRINT '  ⚠ EmbeddingVector already exists in DocumentChunkDetailsEmbeddings';

PRINT '';

-- =============================================
-- Step 2: Migrate data using CAST/CONVERT
-- =============================================
PRINT 'Step 2: Migrating embedding data to VECTOR type...';
PRINT '  Note: SQL Server 2025 should support automatic conversion';
PRINT '';

-- Try direct CAST conversion (SQL Server 2025 RC feature)
BEGIN TRY
    PRINT '  Attempting Content embeddings migration...';
    UPDATE DocumentChunkContentEmbeddings
    SET EmbeddingVector = CAST(Embedding AS VECTOR(768))
    WHERE Embedding IS NOT NULL AND EmbeddingVector IS NULL;
    PRINT '  ✓ Content embeddings migrated: ' + CAST(@@ROWCOUNT AS NVARCHAR) + ' rows';
END TRY
BEGIN CATCH
    PRINT '  ✗ Direct CAST not supported. Error: ' + ERROR_MESSAGE();
    PRINT '  Alternative: Use application-level migration or wait for SQL Server 2025 RTM';
END CATCH

BEGIN TRY
    PRINT '  Attempting Header Context embeddings migration...';
    UPDATE DocumentChunkHeaderContextEmbeddings
    SET EmbeddingVector = CAST(Embedding AS VECTOR(768))
    WHERE Embedding IS NOT NULL AND EmbeddingVector IS NULL;
    PRINT '  ✓ Header Context embeddings migrated: ' + CAST(@@ROWCOUNT AS NVARCHAR) + ' rows';
END TRY
BEGIN CATCH
    PRINT '  ✗ Header Context migration failed: ' + ERROR_MESSAGE();
END CATCH

BEGIN TRY
    PRINT '  Attempting Notes embeddings migration...';
    UPDATE DocumentChunkNotesEmbeddings
    SET EmbeddingVector = CAST(Embedding AS VECTOR(768))
    WHERE Embedding IS NOT NULL AND EmbeddingVector IS NULL;
    PRINT '  ✓ Notes embeddings migrated: ' + CAST(@@ROWCOUNT AS NVARCHAR) + ' rows';
END TRY
BEGIN CATCH
    PRINT '  ✗ Notes migration failed: ' + ERROR_MESSAGE();
END CATCH

BEGIN TRY
    PRINT '  Attempting Details embeddings migration...';
    UPDATE DocumentChunkDetailsEmbeddings
    SET EmbeddingVector = CAST(Embedding AS VECTOR(768))
    WHERE Embedding IS NOT NULL AND EmbeddingVector IS NULL;
    PRINT '  ✓ Details embeddings migrated: ' + CAST(@@ROWCOUNT AS NVARCHAR) + ' rows';
END TRY
BEGIN CATCH
    PRINT '  ✗ Details migration failed: ' + ERROR_MESSAGE();
END CATCH

PRINT '';

-- =============================================
-- Step 3: Verification
-- =============================================
PRINT 'Step 3: Verifying migration...';

DECLARE @MigratedContent INT, @MigratedHeader INT, @MigratedNotes INT, @MigratedDetails INT;

SELECT @MigratedContent = COUNT(*) FROM DocumentChunkContentEmbeddings WHERE EmbeddingVector IS NOT NULL;
SELECT @MigratedHeader = COUNT(*) FROM DocumentChunkHeaderContextEmbeddings WHERE EmbeddingVector IS NOT NULL;
SELECT @MigratedNotes = COUNT(*) FROM DocumentChunkNotesEmbeddings WHERE EmbeddingVector IS NOT NULL;
SELECT @MigratedDetails = COUNT(*) FROM DocumentChunkDetailsEmbeddings WHERE EmbeddingVector IS NOT NULL;

PRINT '  Content embeddings migrated: ' + CAST(@MigratedContent AS NVARCHAR);
PRINT '  Header embeddings migrated: ' + CAST(@MigratedHeader AS NVARCHAR);
PRINT '  Notes embeddings migrated: ' + CAST(@MigratedNotes AS NVARCHAR);
PRINT '  Details embeddings migrated: ' + CAST(@MigratedDetails AS NVARCHAR);

PRINT '';
PRINT '=============================================';

IF @MigratedContent > 0
BEGIN
    PRINT 'Migration Successful!';
    PRINT '';
    PRINT 'Next Steps:';
    PRINT '  1. Test VECTOR_DISTANCE function';
    PRINT '  2. Update stored procedures to use EmbeddingVector';
    PRINT '  3. Drop old Embedding columns (after backup)';
    PRINT '  4. Rename EmbeddingVector to Embedding';
END
ELSE
BEGIN
    PRINT 'Migration Not Completed';
    PRINT '';
    PRINT 'Possible reasons:';
    PRINT '  - SQL Server 2025 RC does not support VARBINARY to VECTOR cast';
    PRINT '  - Requires application-level migration using JSON_ARRAY format';
    PRINT '  - Need to wait for SQL Server 2025 RTM with full VECTOR support';
    PRINT '';
    PRINT 'Alternative Solution:';
    PRINT '  Use C# API for vector search (already implemented)';
    PRINT '  SQL procedures can call C# API via HTTP or use simplified search';
END

PRINT '=============================================';
