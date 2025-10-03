-- Performance Indices for Vector Search Optimization
-- Run this script to dramatically improve vector search performance

USE [RagChatAppDB];
GO

-- Add indices for foreign keys in embedding tables (if not exists)
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_DocumentChunkContentEmbeddings_DocumentChunkId' AND object_id = OBJECT_ID('DocumentChunkContentEmbeddings'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_DocumentChunkContentEmbeddings_DocumentChunkId
    ON DocumentChunkContentEmbeddings(DocumentChunkId);
    PRINT 'Created index: IX_DocumentChunkContentEmbeddings_DocumentChunkId';
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_DocumentChunkHeaderContextEmbeddings_DocumentChunkId' AND object_id = OBJECT_ID('DocumentChunkHeaderContextEmbeddings'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_DocumentChunkHeaderContextEmbeddings_DocumentChunkId
    ON DocumentChunkHeaderContextEmbeddings(DocumentChunkId);
    PRINT 'Created index: IX_DocumentChunkHeaderContextEmbeddings_DocumentChunkId';
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_DocumentChunkNotesEmbeddings_DocumentChunkId' AND object_id = OBJECT_ID('DocumentChunkNotesEmbeddings'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_DocumentChunkNotesEmbeddings_DocumentChunkId
    ON DocumentChunkNotesEmbeddings(DocumentChunkId);
    PRINT 'Created index: IX_DocumentChunkNotesEmbeddings_DocumentChunkId';
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_DocumentChunkDetailsEmbeddings_DocumentChunkId' AND object_id = OBJECT_ID('DocumentChunkDetailsEmbeddings'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_DocumentChunkDetailsEmbeddings_DocumentChunkId
    ON DocumentChunkDetailsEmbeddings(DocumentChunkId);
    PRINT 'Created index: IX_DocumentChunkDetailsEmbeddings_DocumentChunkId';
END

-- Add index on DocumentId for faster joins
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_DocumentChunks_DocumentId' AND object_id = OBJECT_ID('DocumentChunks'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_DocumentChunks_DocumentId
    ON DocumentChunks(DocumentId);
    PRINT 'Created index: IX_DocumentChunks_DocumentId';
END

-- Verify indices created
SELECT
    i.name AS IndexName,
    OBJECT_NAME(i.object_id) AS TableName,
    i.type_desc AS IndexType,
    STATS_DATE(i.object_id, i.index_id) AS LastUpdated
FROM sys.indexes i
WHERE OBJECT_NAME(i.object_id) = 'DocumentChunks'
    AND i.name LIKE 'IX_%'
ORDER BY i.name;

PRINT 'Performance indices installation complete!';
GO
