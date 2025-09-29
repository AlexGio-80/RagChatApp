-- =============================================
-- RAG Chat Application - Master Installation Script for All Stored Procedures
-- =============================================

USE [OSL_AI] -- Replace with your actual database name
GO

PRINT 'Starting installation of RAG Chat Application stored procedures...'
PRINT 'Database: ' + DB_NAME()
PRINT 'Installation Date: ' + CONVERT(NVARCHAR, GETUTCDATE(), 120) + ' UTC'
PRINT '============================================='

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
PRINT '============================================='

-- Install Documents CRUD procedures
PRINT '1. Installing Documents CRUD stored procedures...'
:r "01_DocumentsCRUD.sql"
PRINT ''

-- Install DocumentChunks CRUD procedures
PRINT '2. Installing DocumentChunks and Embeddings CRUD stored procedures...'
:r "02_DocumentChunksCRUD.sql"
PRINT ''

-- Install RAG Search procedures
PRINT '3. Installing RAG Search stored procedures...'
:r "03_RAGSearchProcedure.sql"
PRINT ''

-- Install Semantic Cache Management procedures
PRINT '4. Installing Semantic Cache Management stored procedures...'
:r "04_SemanticCacheManagement.sql"
PRINT ''

PRINT '============================================='
PRINT 'Verifying installed procedures...'

-- List all installed RAG-related procedures
SELECT
    ROUTINE_NAME as ProcedureName,
    CREATED as CreatedDate,
    LAST_ALTERED as LastModified
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_TYPE = 'PROCEDURE'
  AND (ROUTINE_NAME LIKE 'SP_%Document%' OR
       ROUTINE_NAME LIKE 'SP_RAG%' OR
       ROUTINE_NAME LIKE 'SP_%Semantic%')
ORDER BY ROUTINE_NAME;

DECLARE @ProcedureCount INT;
SELECT @ProcedureCount = COUNT(*)
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_TYPE = 'PROCEDURE'
  AND (ROUTINE_NAME LIKE 'SP_%Document%' OR
       ROUTINE_NAME LIKE 'SP_RAG%' OR
       ROUTINE_NAME LIKE 'SP_%Semantic%');

PRINT ''
PRINT 'Installation completed successfully!'
PRINT 'Total procedures installed: ' + CAST(@ProcedureCount AS NVARCHAR)
PRINT '============================================='

-- Show usage examples
PRINT ''
PRINT 'USAGE EXAMPLES:'
PRINT '============================================='
PRINT '-- Insert a document:'
PRINT 'DECLARE @DocId INT;'
PRINT 'EXEC SP_InsertDocument ''test.txt'', ''text/plain'', 1000, ''Sample content'', NULL, ''Pending'', @DocId OUTPUT;'
PRINT ''
PRINT '-- Get all documents:'
PRINT 'EXEC SP_GetAllDocuments @PageNumber = 1, @PageSize = 10;'
PRINT ''
PRINT '-- Perform RAG search (requires embeddings):'
PRINT 'DECLARE @QueryEmbedding VARBINARY(MAX) = 0x1234; -- Your query embedding'
PRINT 'EXEC SP_RAGSearch @QueryEmbedding, @MaxResults = 10, @SearchQuery = ''your search text'';'
PRINT ''
PRINT '-- Clean semantic cache:'
PRINT 'EXEC SP_CleanSemanticCache @MaxAgeHours = 1;'
PRINT ''
PRINT '-- Get cache statistics:'
PRINT 'EXEC SP_GetSemanticCacheStats;'
PRINT ''
PRINT '============================================='
PRINT 'IMPORTANT NOTES:'
PRINT '- All procedures handle transactions and error cases'
PRINT '- RAG search includes semantic caching (1-hour TTL)'
PRINT '- Vector distance functions may need adjustment based on your SQL Server version'
PRINT '- Remember to grant appropriate permissions to application users'
PRINT '============================================='