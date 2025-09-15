# 🗄️ Schema Database RAG - Documentazione Completa

## Panoramica Database

Il database del sistema RAG utilizza SQL Server con supporto per vector storage implementato tramite VARBINARY per ottimizzare le performance delle ricerche di similarità.

## Schema Completo SQL Server

### Tabella Documents

```sql
CREATE TABLE [Documents] (
    [Id] int IDENTITY(1,1) NOT NULL,
    [FileName] nvarchar(255) NOT NULL,
    [ContentType] nvarchar(100) NOT NULL,
    [Size] bigint NOT NULL,
    [Content] nvarchar(MAX) NOT NULL,
    [Status] nvarchar(50) NOT NULL DEFAULT 'Pending',
    [UploadedAt] datetime2 NOT NULL DEFAULT GETUTCDATE(),
    [ProcessedAt] datetime2 NULL,

    CONSTRAINT [PK_Documents] PRIMARY KEY CLUSTERED ([Id] ASC)
);

-- Indici per performance
CREATE NONCLUSTERED INDEX [IX_Documents_FileName]
ON [Documents]([FileName] ASC);

CREATE NONCLUSTERED INDEX [IX_Documents_Status]
ON [Documents]([Status] ASC);

CREATE NONCLUSTERED INDEX [IX_Documents_UploadedAt]
ON [Documents]([UploadedAt] DESC);

CREATE NONCLUSTERED INDEX [IX_Documents_Status_ProcessedAt]
ON [Documents]([Status] ASC, [ProcessedAt] DESC);
```

### Tabella DocumentChunks

```sql
CREATE TABLE [DocumentChunks] (
    [Id] int IDENTITY(1,1) NOT NULL,
    [DocumentId] int NOT NULL,
    [ChunkIndex] int NOT NULL,
    [Content] nvarchar(MAX) NOT NULL,
    [HeaderContext] nvarchar(500) NULL,
    [Embedding] varbinary(MAX) NULL,
    [CreatedAt] datetime2 NOT NULL DEFAULT GETUTCDATE(),

    CONSTRAINT [PK_DocumentChunks] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_DocumentChunks_Documents] FOREIGN KEY ([DocumentId])
        REFERENCES [Documents] ([Id]) ON DELETE CASCADE
);

-- Indici per performance vettoriale
CREATE NONCLUSTERED INDEX [IX_DocumentChunks_DocumentId]
ON [DocumentChunks]([DocumentId] ASC);

CREATE UNIQUE NONCLUSTERED INDEX [IX_DocumentChunks_DocumentId_ChunkIndex]
ON [DocumentChunks]([DocumentId] ASC, [ChunkIndex] ASC);

CREATE NONCLUSTERED INDEX [IX_DocumentChunks_CreatedAt]
ON [DocumentChunks]([CreatedAt] DESC);

-- Indice per ricerche full-text (opzionale)
CREATE FULLTEXT CATALOG [RAGFullTextCatalog];

CREATE FULLTEXT INDEX ON [DocumentChunks]([Content])
KEY INDEX [PK_DocumentChunks]
ON [RAGFullTextCatalog];
```

## Entity Framework Core Configuration

### DbContext Configuration

```csharp
public class RagChatDbContext : DbContext
{
    public DbSet<Document> Documents { get; set; }
    public DbSet<DocumentChunk> DocumentChunks { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Document Entity Configuration
        modelBuilder.Entity<Document>(entity =>
        {
            entity.HasKey(e => e.Id);

            entity.Property(e => e.FileName)
                .IsRequired()
                .HasMaxLength(255);

            entity.Property(e => e.ContentType)
                .IsRequired()
                .HasMaxLength(100);

            entity.Property(e => e.Content)
                .IsRequired();

            entity.Property(e => e.Status)
                .IsRequired()
                .HasMaxLength(50)
                .HasDefaultValue("Pending");

            entity.Property(e => e.UploadedAt)
                .IsRequired()
                .HasDefaultValueSql("GETUTCDATE()");

            // Indexes
            entity.HasIndex(e => e.FileName)
                .HasDatabaseName("IX_Documents_FileName");

            entity.HasIndex(e => e.Status)
                .HasDatabaseName("IX_Documents_Status");

            entity.HasIndex(e => e.UploadedAt)
                .HasDatabaseName("IX_Documents_UploadedAt");
        });

        // DocumentChunk Entity Configuration
        modelBuilder.Entity<DocumentChunk>(entity =>
        {
            entity.HasKey(e => e.Id);

            entity.Property(e => e.DocumentId)
                .IsRequired();

            entity.Property(e => e.ChunkIndex)
                .IsRequired();

            entity.Property(e => e.Content)
                .IsRequired();

            entity.Property(e => e.HeaderContext)
                .HasMaxLength(500);

            // Vector embedding storage
            entity.Property(e => e.Embedding)
                .HasColumnType("VARBINARY(MAX)");

            entity.Property(e => e.CreatedAt)
                .IsRequired()
                .HasDefaultValueSql("GETUTCDATE()");

            // Relationship configuration
            entity.HasOne(e => e.Document)
                .WithMany(d => d.Chunks)
                .HasForeignKey(e => e.DocumentId)
                .OnDelete(DeleteBehavior.Cascade);

            // Indexes
            entity.HasIndex(e => e.DocumentId)
                .HasDatabaseName("IX_DocumentChunks_DocumentId");

            entity.HasIndex(e => new { e.DocumentId, e.ChunkIndex })
                .IsUnique()
                .HasDatabaseName("IX_DocumentChunks_DocumentId_ChunkIndex");
        });
    }
}
```

## Indici per Performance Vettoriale

### Strategia di Indicizzazione

```sql
-- Indice composito per query comuni
CREATE NONCLUSTERED INDEX [IX_DocumentChunks_Search_Optimized]
ON [DocumentChunks]([DocumentId] ASC, [ChunkIndex] ASC)
INCLUDE ([Content], [HeaderContext], [Embedding]);

-- Indice per ricerche temporali
CREATE NONCLUSTERED INDEX [IX_Documents_ProcessingQueue]
ON [Documents]([Status] ASC, [UploadedAt] ASC)
WHERE [Status] IN ('Pending', 'Processing');

-- Indice per statistiche
CREATE NONCLUSTERED INDEX [IX_DocumentChunks_Stats]
ON [DocumentChunks]([DocumentId] ASC)
INCLUDE ([CreatedAt]);
```

### Ottimizzazioni per Vector Search

```sql
-- Stored Procedure per Vector Similarity Search
CREATE PROCEDURE [dbo].[SearchSimilarChunks]
    @QueryEmbedding VARBINARY(MAX),
    @MaxResults INT = 5,
    @SimilarityThreshold FLOAT = 0.7
AS
BEGIN
    SET NOCOUNT ON;

    -- Implementazione temporanea con ricerca full-text
    -- In produzione, considerare Azure SQL Database con vector support
    DECLARE @SearchResults TABLE (
        ChunkId INT,
        DocumentId INT,
        Content NVARCHAR(MAX),
        HeaderContext NVARCHAR(500),
        DocumentName NVARCHAR(255),
        SimilarityScore FLOAT
    );

    -- Placeholder per similarità basata su contenuto
    INSERT INTO @SearchResults
    SELECT TOP (@MaxResults)
        dc.Id,
        dc.DocumentId,
        dc.Content,
        dc.HeaderContext,
        d.FileName,
        0.8 as SimilarityScore -- Mock similarity score
    FROM DocumentChunks dc
    INNER JOIN Documents d ON dc.DocumentId = d.Id
    WHERE d.Status = 'Completed'
    ORDER BY dc.CreatedAt DESC;

    SELECT * FROM @SearchResults;
END;
```

## Query di Esempio e Monitoring

### Query Comuni per l'Applicazione

```sql
-- 1. Recuperare documenti con stato e conteggio chunk
SELECT
    d.Id,
    d.FileName,
    d.ContentType,
    d.Size,
    d.Status,
    d.UploadedAt,
    d.ProcessedAt,
    COUNT(dc.Id) as ChunkCount
FROM Documents d
LEFT JOIN DocumentChunks dc ON d.Id = dc.DocumentId
GROUP BY d.Id, d.FileName, d.ContentType, d.Size, d.Status, d.UploadedAt, d.ProcessedAt
ORDER BY d.UploadedAt DESC;

-- 2. Recuperare chunk per un documento specifico
SELECT
    dc.Id,
    dc.ChunkIndex,
    dc.Content,
    dc.HeaderContext,
    dc.CreatedAt
FROM DocumentChunks dc
WHERE dc.DocumentId = @DocumentId
ORDER BY dc.ChunkIndex;

-- 3. Ricerca full-text nei chunk
SELECT
    dc.Id,
    dc.DocumentId,
    d.FileName,
    dc.Content,
    dc.HeaderContext
FROM DocumentChunks dc
INNER JOIN Documents d ON dc.DocumentId = d.Id
WHERE CONTAINS(dc.Content, @SearchTerm)
ORDER BY dc.CreatedAt DESC;

-- 4. Statistiche sistema
SELECT
    COUNT(*) as TotalDocuments,
    SUM(CASE WHEN Status = 'Completed' THEN 1 ELSE 0 END) as CompletedDocuments,
    SUM(CASE WHEN Status = 'Processing' THEN 1 ELSE 0 END) as ProcessingDocuments,
    SUM(CASE WHEN Status = 'Failed' THEN 1 ELSE 0 END) as FailedDocuments,
    AVG(CAST(Size as FLOAT)) / 1024 / 1024 as AvgSizeMB
FROM Documents;

-- 5. Performance delle elaborazioni
SELECT
    d.Id,
    d.FileName,
    d.UploadedAt,
    d.ProcessedAt,
    DATEDIFF(SECOND, d.UploadedAt, d.ProcessedAt) as ProcessingTimeSeconds,
    COUNT(dc.Id) as ChunksCreated
FROM Documents d
LEFT JOIN DocumentChunks dc ON d.Id = dc.DocumentId
WHERE d.ProcessedAt IS NOT NULL
GROUP BY d.Id, d.FileName, d.UploadedAt, d.ProcessedAt
ORDER BY ProcessingTimeSeconds DESC;
```

### Query di Monitoraggio Performance

```sql
-- Monitoring query performance
SELECT
    t.text as QueryText,
    s.execution_count,
    s.total_elapsed_time / 1000000.0 as TotalElapsedTimeSeconds,
    s.avg_elapsed_time / 1000000.0 as AvgElapsedTimeSeconds,
    s.creation_time,
    s.last_execution_time
FROM sys.dm_exec_query_stats s
CROSS APPLY sys.dm_exec_sql_text(s.sql_handle) t
WHERE t.text LIKE '%Documents%' OR t.text LIKE '%DocumentChunks%'
ORDER BY s.avg_elapsed_time DESC;

-- Index usage statistics
SELECT
    i.name as IndexName,
    ius.user_seeks,
    ius.user_scans,
    ius.user_lookups,
    ius.user_updates
FROM sys.indexes i
INNER JOIN sys.dm_db_index_usage_stats ius ON i.object_id = ius.object_id AND i.index_id = ius.index_id
INNER JOIN sys.objects o ON i.object_id = o.object_id
WHERE o.name IN ('Documents', 'DocumentChunks')
ORDER BY ius.user_seeks + ius.user_scans + ius.user_lookups DESC;
```

## Configurazione Produzione e Backup

### Configurazione Database Produzione

```sql
-- Database configuration for production
ALTER DATABASE [OSL_AI] SET RECOVERY FULL;
ALTER DATABASE [OSL_AI] SET AUTO_UPDATE_STATISTICS ON;
ALTER DATABASE [OSL_AI] SET AUTO_CREATE_STATISTICS ON;

-- Memory optimization
ALTER DATABASE [OSL_AI] SET TARGET_RECOVERY_TIME = 60 SECONDS;

-- File growth configuration
ALTER DATABASE [OSL_AI]
MODIFY FILE (NAME = 'OSL_AI', FILEGROWTH = 256MB);

ALTER DATABASE [OSL_AI]
MODIFY FILE (NAME = 'OSL_AI_Log', FILEGROWTH = 64MB);
```

### Script di Backup

```sql
-- Full backup script
DECLARE @BackupPath NVARCHAR(500) = 'C:\Backups\OSL_AI_' + FORMAT(GETDATE(), 'yyyyMMdd_HHmmss') + '.bak';

BACKUP DATABASE [OSL_AI]
TO DISK = @BackupPath
WITH
    COMPRESSION,
    CHECKSUM,
    INIT,
    FORMAT;

-- Transaction log backup
DECLARE @LogBackupPath NVARCHAR(500) = 'C:\Backups\OSL_AI_Log_' + FORMAT(GETDATE(), 'yyyyMMdd_HHmmss') + '.trn';

BACKUP LOG [OSL_AI]
TO DISK = @LogBackupPath
WITH COMPRESSION, CHECKSUM;
```

### Manutenzione Database

```sql
-- Index maintenance script
DECLARE @TableName NVARCHAR(128), @IndexName NVARCHAR(128), @SQL NVARCHAR(MAX);

DECLARE maintenance_cursor CURSOR FOR
SELECT
    t.name as TableName,
    i.name as IndexName
FROM sys.tables t
INNER JOIN sys.indexes i ON t.object_id = i.object_id
WHERE t.name IN ('Documents', 'DocumentChunks')
AND i.name IS NOT NULL;

OPEN maintenance_cursor;

FETCH NEXT FROM maintenance_cursor INTO @TableName, @IndexName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = 'ALTER INDEX ' + @IndexName + ' ON ' + @TableName + ' REORGANIZE';
    EXEC sp_executesql @SQL;

    FETCH NEXT FROM maintenance_cursor INTO @TableName, @IndexName;
END;

CLOSE maintenance_cursor;
DEALLOCATE maintenance_cursor;

-- Update statistics
UPDATE STATISTICS Documents;
UPDATE STATISTICS DocumentChunks;
```

## Migration Scripts

### Initial Migration

```sql
-- Create Database
CREATE DATABASE [OSL_AI];
GO

USE [OSL_AI];
GO

-- Create Documents table
CREATE TABLE [Documents] (
    [Id] int IDENTITY(1,1) NOT NULL,
    [FileName] nvarchar(255) NOT NULL,
    [ContentType] nvarchar(100) NOT NULL,
    [Size] bigint NOT NULL,
    [Content] nvarchar(MAX) NOT NULL,
    [Status] nvarchar(50) NOT NULL DEFAULT 'Pending',
    [UploadedAt] datetime2 NOT NULL DEFAULT GETUTCDATE(),
    [ProcessedAt] datetime2 NULL,
    CONSTRAINT [PK_Documents] PRIMARY KEY CLUSTERED ([Id] ASC)
);

-- Create DocumentChunks table
CREATE TABLE [DocumentChunks] (
    [Id] int IDENTITY(1,1) NOT NULL,
    [DocumentId] int NOT NULL,
    [ChunkIndex] int NOT NULL,
    [Content] nvarchar(MAX) NOT NULL,
    [HeaderContext] nvarchar(500) NULL,
    [Embedding] varbinary(MAX) NULL,
    [CreatedAt] datetime2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT [PK_DocumentChunks] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_DocumentChunks_Documents] FOREIGN KEY ([DocumentId])
        REFERENCES [Documents] ([Id]) ON DELETE CASCADE
);

-- Create indexes
CREATE NONCLUSTERED INDEX [IX_Documents_FileName] ON [Documents]([FileName] ASC);
CREATE NONCLUSTERED INDEX [IX_Documents_Status] ON [Documents]([Status] ASC);
CREATE NONCLUSTERED INDEX [IX_Documents_UploadedAt] ON [Documents]([UploadedAt] DESC);
CREATE NONCLUSTERED INDEX [IX_DocumentChunks_DocumentId] ON [DocumentChunks]([DocumentId] ASC);
CREATE UNIQUE NONCLUSTERED INDEX [IX_DocumentChunks_DocumentId_ChunkIndex] ON [DocumentChunks]([DocumentId] ASC, [ChunkIndex] ASC);
```

### EF Core Migration Commands

```bash
# Create initial migration
dotnet ef migrations add InitialCreate

# Update database
dotnet ef database update

# Generate SQL script
dotnet ef migrations script

# Remove last migration (if needed)
dotnet ef migrations remove
```

## Considerazioni per Scalabilità

### Partitioning Strategy

```sql
-- Partitioning function by upload date
CREATE PARTITION FUNCTION DocumentPartitionFunction (datetime2)
AS RANGE RIGHT FOR VALUES (
    '2024-01-01', '2024-04-01', '2024-07-01', '2024-10-01', '2025-01-01'
);

-- Partition scheme
CREATE PARTITION SCHEME DocumentPartitionScheme
AS PARTITION DocumentPartitionFunction
ALL TO ([PRIMARY]);

-- Apply partitioning to Documents table (requires rebuild)
-- Note: Implement during low-usage periods
```

### Archive Strategy

```sql
-- Archive old documents (example: older than 2 years)
CREATE TABLE [DocumentsArchive] (
    -- Same structure as Documents table
    -- Plus archive metadata
);

-- Archive procedure
CREATE PROCEDURE [dbo].[ArchiveOldDocuments]
    @ArchiveBeforeDate DATETIME2
AS
BEGIN
    BEGIN TRANSACTION;

    -- Move to archive
    INSERT INTO [DocumentsArchive]
    SELECT * FROM [Documents]
    WHERE [UploadedAt] < @ArchiveBeforeDate;

    -- Delete from main table
    DELETE FROM [Documents]
    WHERE [UploadedAt] < @ArchiveBeforeDate;

    COMMIT TRANSACTION;
END;
```

Questo schema database fornisce una base solida per il sistema RAG con ottimizzazioni per performance, backup e manutenzione. La configurazione è scalabile e pronta per implementazioni enterprise.