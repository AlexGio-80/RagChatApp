# RAG Chat Application - Database Schema v2.0

**Schema Version**: 2.0 (Enhanced Multi-Field Embeddings)
**Migration**: `ImplementMultipleEmbeddingTables`
**Implementation Date**: January 29, 2025

## 🏗️ Schema Overview

The enhanced database schema supports multi-field embeddings, semantic caching, and comprehensive metadata for advanced RAG functionality.

## 📊 Entity Relationship Diagram

```
┌─────────────────┐         ┌──────────────────┐
│    Documents    │ 1    M  │  DocumentChunks  │
│─────────────────│◄────────┤──────────────────│
│ Id (PK)         │         │ Id (PK)          │
│ FileName        │         │ DocumentId (FK)  │
│ ContentType     │         │ ChunkIndex       │
│ Size            │         │ Content          │
│ Content         │         │ HeaderContext    │
│ Path (NEW)      │         │ Notes (NEW)      │
│ UploadedAt      │         │ Details (NEW)    │
│ ProcessedAt     │         │ CreatedAt        │
│ Status          │         │ UpdatedAt (NEW)  │
└─────────────────┘         └──────────────────┘
                                      │
                                      ├─── 1:1 ────┐
                                      │             │
┌──────────────────┐                 │             │
│  SemanticCache   │                 │             │
│──────────────────│                 │             │
│ Id (PK)          │                 │             │
│ SearchQuery      │                 │             │
│ ResultContent    │                 │             │
│ ResultEmbedding  │                 │             │
│ CreatedAt        │                 │             │
└──────────────────┘                 │             │
                                      │             │
┌─────────────────────────────────────┼─────────────┼─────────────────┐
│                                     │             │                 │
│  ┌──────────────────────────────────▼─┐ ┌────────▼────────────────┐ │
│  │DocumentChunkContentEmbeddings    │ │DocumentChunkHeaderContext│ │
│  │──────────────────────────────────│ │Embeddings               │ │
│  │ Id (PK)                          │ │─────────────────────────│ │
│  │ DocumentChunkId (FK) UNIQUE      │ │ Id (PK)                 │ │
│  │ Embedding VARBINARY(MAX)         │ │ DocumentChunkId (FK)    │ │
│  │ CreatedAt                        │ │ Embedding VARBINARY(MAX)│ │
│  │ UpdatedAt                        │ │ CreatedAt               │ │
│  └──────────────────────────────────┘ │ UpdatedAt               │ │
│                                       └─────────────────────────┘ │
│  ┌──────────────────────────────────┐ ┌─────────────────────────┐ │
│  │DocumentChunkNotesEmbeddings      │ │DocumentChunkDetails     │ │
│  │──────────────────────────────────│ │Embeddings               │ │
│  │ Id (PK)                          │ │─────────────────────────│ │
│  │ DocumentChunkId (FK) UNIQUE      │ │ Id (PK)                 │ │
│  │ Embedding VARBINARY(MAX)         │ │ DocumentChunkId (FK)    │ │
│  │ CreatedAt                        │ │ Embedding VARBINARY(MAX)│ │
│  │ UpdatedAt                        │ │ CreatedAt               │ │
│  └──────────────────────────────────┘ │ UpdatedAt               │ │
│                                       └─────────────────────────┘ │
└───────────────────────────────────────────────────────────────────┘
                      4 Embedding Tables (1:1 relationships)
```

## 📋 Table Definitions

### Documents Table (Enhanced)

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| Id | INT | PRIMARY KEY, IDENTITY | Unique document identifier |
| FileName | NVARCHAR(255) | NOT NULL | Original filename |
| ContentType | NVARCHAR(100) | NOT NULL | MIME type (e.g., application/pdf) |
| Size | BIGINT | NOT NULL | File size in bytes |
| Content | NVARCHAR(MAX) | NOT NULL | Extracted text content |
| **Path** | NVARCHAR(500) | NULL | **NEW**: Document URL/path for linking |
| UploadedAt | DATETIME2 | NOT NULL | Upload timestamp (UTC) |
| ProcessedAt | DATETIME2 | NULL | Processing completion timestamp |
| Status | NVARCHAR(50) | NOT NULL | Processing status (Pending/Completed/Failed) |

**Indexes:**
- `IX_Documents_FileName` (FileName)
- `IX_Documents_Status` (Status)
- `IX_Documents_UploadedAt` (UploadedAt)

### DocumentChunks Table (Enhanced)

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| Id | INT | PRIMARY KEY, IDENTITY | Unique chunk identifier |
| DocumentId | INT | NOT NULL, FK → Documents.Id | Parent document reference |
| ChunkIndex | INT | NOT NULL | Chunk order within document (0-based) |
| Content | NVARCHAR(MAX) | NOT NULL | Chunk text content |
| HeaderContext | NVARCHAR(MAX) | NULL | Document structure header |
| **Notes** | NVARCHAR(MAX) | NULL | **NEW**: User-added notes |
| **Details** | NVARCHAR(MAX) | NULL | **NEW**: JSON metadata |
| CreatedAt | DATETIME2 | NOT NULL | Creation timestamp (UTC) |
| **UpdatedAt** | DATETIME2 | NOT NULL | **NEW**: Last modification timestamp |

**Relationships:**
- Foreign Key: `DocumentId` → `Documents.Id` (CASCADE DELETE)

**Indexes:**
- `IX_DocumentChunks_DocumentId` (DocumentId)
- `IX_DocumentChunks_DocumentId_ChunkIndex` (DocumentId, ChunkIndex) UNIQUE

### DocumentChunkContentEmbeddings Table (NEW)

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| Id | INT | PRIMARY KEY, IDENTITY | Unique embedding identifier |
| DocumentChunkId | INT | NOT NULL, UNIQUE, FK → DocumentChunks.Id | Chunk reference |
| Embedding | VARBINARY(MAX) | NOT NULL | Vector embedding (1536 dimensions) |
| CreatedAt | DATETIME2 | NOT NULL | Creation timestamp (UTC) |
| UpdatedAt | DATETIME2 | NOT NULL | Last update timestamp |

**Relationships:**
- Foreign Key: `DocumentChunkId` → `DocumentChunks.Id` (CASCADE DELETE)
- One-to-One: Each chunk has at most one content embedding

**Indexes:**
- `IX_DocumentChunkContentEmbeddings_DocumentChunkId` (DocumentChunkId) UNIQUE

### DocumentChunkHeaderContextEmbeddings Table (NEW)

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| Id | INT | PRIMARY KEY, IDENTITY | Unique embedding identifier |
| DocumentChunkId | INT | NOT NULL, UNIQUE, FK → DocumentChunks.Id | Chunk reference |
| Embedding | VARBINARY(MAX) | NOT NULL | Vector embedding for header context |
| CreatedAt | DATETIME2 | NOT NULL | Creation timestamp (UTC) |
| UpdatedAt | DATETIME2 | NOT NULL | Last update timestamp |

**Relationships:**
- Foreign Key: `DocumentChunkId` → `DocumentChunks.Id` (CASCADE DELETE)
- One-to-One: Each chunk has at most one header context embedding

**Indexes:**
- `IX_DocumentChunkHeaderContextEmbeddings_DocumentChunkId` (DocumentChunkId) UNIQUE

### DocumentChunkNotesEmbeddings Table (NEW)

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| Id | INT | PRIMARY KEY, IDENTITY | Unique embedding identifier |
| DocumentChunkId | INT | NOT NULL, UNIQUE, FK → DocumentChunks.Id | Chunk reference |
| Embedding | VARBINARY(MAX) | NOT NULL | Vector embedding for user notes |
| CreatedAt | DATETIME2 | NOT NULL | Creation timestamp (UTC) |
| UpdatedAt | DATETIME2 | NOT NULL | Last update timestamp |

**Relationships:**
- Foreign Key: `DocumentChunkId` → `DocumentChunks.Id` (CASCADE DELETE)
- One-to-One: Each chunk has at most one notes embedding

**Indexes:**
- `IX_DocumentChunkNotesEmbeddings_DocumentChunkId` (DocumentChunkId) UNIQUE

### DocumentChunkDetailsEmbeddings Table (NEW)

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| Id | INT | PRIMARY KEY, IDENTITY | Unique embedding identifier |
| DocumentChunkId | INT | NOT NULL, UNIQUE, FK → DocumentChunks.Id | Chunk reference |
| Embedding | VARBINARY(MAX) | NOT NULL | Vector embedding for JSON details |
| CreatedAt | DATETIME2 | NOT NULL | Creation timestamp (UTC) |
| UpdatedAt | DATETIME2 | Not NULL | Last update timestamp |

**Relationships:**
- Foreign Key: `DocumentChunkId` → `DocumentChunks.Id` (CASCADE DELETE)
- One-to-One: Each chunk has at most one details embedding

**Indexes:**
- `IX_DocumentChunkDetailsEmbeddings_DocumentChunkId` (DocumentChunkId) UNIQUE

### SemanticCache Table (NEW)

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| Id | INT | PRIMARY KEY, IDENTITY | Unique cache entry identifier |
| SearchQuery | NVARCHAR(1000) | NOT NULL | Original search query text |
| ResultContent | NVARCHAR(MAX) | NOT NULL | Best matching result content |
| ResultEmbedding | VARBINARY(MAX) | NOT NULL | Embedding of the best result |
| CreatedAt | DATETIME2 | NOT NULL | Cache entry timestamp (UTC) |

**Indexes:**
- `IX_SemanticCache_SearchQuery` (SearchQuery)
- `IX_SemanticCache_CreatedAt` (CreatedAt)

**Automatic Cleanup**: Entries older than 1 hour are automatically removed.

## 🔄 Migration Changes

### Added Tables
- ✅ `DocumentChunkContentEmbeddings`
- ✅ `DocumentChunkHeaderContextEmbeddings`
- ✅ `DocumentChunkNotesEmbeddings`
- ✅ `DocumentChunkDetailsEmbeddings`
- ✅ `SemanticCache`

### Modified Tables

#### Documents
- ✅ Added `Path` NVARCHAR(500) NULL

#### DocumentChunks
- ✅ Added `Notes` NVARCHAR(MAX) NULL
- ✅ Added `Details` NVARCHAR(MAX) NULL
- ✅ Added `UpdatedAt` DATETIME2 NOT NULL
- ✅ Removed `Embedding` VARBINARY(MAX) (migrated to ContentEmbeddings)

### Relationships Added
- ✅ 4 one-to-one relationships between DocumentChunks and embedding tables
- ✅ All relationships configured with CASCADE DELETE

## 📈 Performance Considerations

### Indexing Strategy
- **Primary Keys**: Clustered indexes on all Id columns
- **Foreign Keys**: Non-clustered indexes for join performance
- **Search Optimization**: Indexes on SearchQuery and CreatedAt for cache
- **Unique Constraints**: Prevent duplicate embeddings per chunk

### Storage Optimization
- **Embedding Storage**: VARBINARY(MAX) for 1536-dimension vectors (6KB each)
- **Text Storage**: NVARCHAR(MAX) for unlimited content length
- **Cascade Deletes**: Automatic cleanup prevents orphaned records

### Query Performance
- **Multi-Field Search**: Optimized with proper join indexes
- **Cache Lookup**: Fast exact match on SearchQuery
- **Pagination**: Efficient OFFSET/FETCH with proper ordering

## 🔍 Vector Search Logic

### Multi-Field Embedding Strategy
Each DocumentChunk can have up to 4 embeddings:

1. **Content Embedding**: Always present (from chunk content)
2. **HeaderContext Embedding**: Present if HeaderContext exists
3. **Notes Embedding**: Present if Notes exist
4. **Details Embedding**: Present if Details exist

### Search Algorithm (LEAST Function Logic)
```sql
SELECT TOP(@k)
    dc.Id,
    dc.Content,
    dc.HeaderContext,
    dc.Notes,
    dc.Details,
    -- Find minimum distance across all available embeddings
    LEAST(
        COALESCE(vector_distance('cosine', dcce.Embedding, @queryEmbedding), 1.0),
        COALESCE(vector_distance('cosine', dchce.Embedding, @queryEmbedding), 1.0),
        COALESCE(vector_distance('cosine', dcne.Embedding, @queryEmbedding), 1.0),
        COALESCE(vector_distance('cosine', dcde.Embedding, @queryEmbedding), 1.0)
    ) as cosine_distance
FROM DocumentChunks dc
LEFT JOIN DocumentChunkContentEmbeddings dcce ON dc.Id = dcce.DocumentChunkId
LEFT JOIN DocumentChunkHeaderContextEmbeddings dchce ON dc.Id = dchce.DocumentChunkId
LEFT JOIN DocumentChunkNotesEmbeddings dcne ON dc.Id = dcne.DocumentChunkId
LEFT JOIN DocumentChunkDetailsEmbeddings dcde ON dc.Id = dcde.DocumentChunkId
WHERE (dcce.Embedding IS NOT NULL OR dchce.Embedding IS NOT NULL OR
       dcne.Embedding IS NOT NULL OR dcde.Embedding IS NOT NULL)
ORDER BY cosine_distance ASC;
```

### Similarity Scoring
- **Cosine Distance**: 0.0 (identical) to 2.0 (completely different)
- **Similarity Score**: `(1.0 - cosine_distance) * 100` for percentage
- **LEAST Function**: Returns minimum distance (best match) across all fields

## 💾 Data Examples

### Sample Document Record
```sql
INSERT INTO Documents VALUES (
    'machine_learning_guide.pdf',
    'application/pdf',
    2048000,
    'Machine learning is a subset of artificial intelligence...',
    '/documents/guides/machine_learning_guide.pdf',
    GETUTCDATE(),
    GETUTCDATE(),
    'Completed'
);
```

### Sample DocumentChunk Record
```sql
INSERT INTO DocumentChunks VALUES (
    1,  -- DocumentId
    0,  -- ChunkIndex
    'Machine learning is a method of data analysis that automates analytical model building.',
    'Chapter 1: Introduction to Machine Learning',
    'Key concept: Foundation of AI',
    '{"author": "John Doe", "tags": ["AI", "ML"], "difficulty": "beginner"}',
    GETUTCDATE(),
    GETUTCDATE()
);
```

### Sample Embedding Records
```sql
-- Content embedding
INSERT INTO DocumentChunkContentEmbeddings VALUES (
    1,  -- DocumentChunkId
    0x123456...,  -- Embedding vector
    GETUTCDATE(),
    GETUTCDATE()
);

-- Header context embedding
INSERT INTO DocumentChunkHeaderContextEmbeddings VALUES (
    1,  -- DocumentChunkId
    0x789ABC...,  -- Embedding vector
    GETUTCDATE(),
    GETUTCDATE()
);
```

### Sample SemanticCache Record
```sql
INSERT INTO SemanticCache VALUES (
    'machine learning basics',
    'Machine learning is a method of data analysis...',
    0x123456...,
    GETUTCDATE()
);
```

## 🛠️ Maintenance Procedures

### Regular Maintenance
```sql
-- Clean expired cache entries (run hourly)
EXEC SP_CleanSemanticCache @MaxAgeHours = 1;

-- Check cache statistics
EXEC SP_GetSemanticCacheStats;

-- Analyze storage usage
SELECT
    t.name as TableName,
    SUM(p.rows) as RowCount,
    SUM(a.total_pages) * 8 / 1024 as SizeMB
FROM sys.tables t
JOIN sys.indexes i ON t.object_id = i.object_id
JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
JOIN sys.allocation_units a ON p.partition_id = a.container_id
WHERE t.name LIKE 'Document%' OR t.name = 'SemanticCache'
GROUP BY t.name
ORDER BY SizeMB DESC;
```

### Performance Monitoring
```sql
-- Monitor most expensive queries
SELECT TOP 10
    qs.total_elapsed_time / qs.execution_count as avg_elapsed_time,
    qs.execution_count,
    SUBSTRING(st.text, (qs.statement_start_offset/2)+1,
        ((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(st.text)
          ELSE qs.statement_end_offset END - qs.statement_start_offset)/2) + 1) as statement_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
WHERE st.text LIKE '%DocumentChunk%' OR st.text LIKE '%SemanticCache%'
ORDER BY avg_elapsed_time DESC;
```

## 🚀 Deployment Checklist

### Pre-Deployment Verification
- [ ] **Migration Applied**: `dotnet ef database update` successful
- [ ] **Indexes Created**: All performance indexes in place
- [ ] **Relationships Verified**: Foreign keys and cascade deletes working
- [ ] **Storage Capacity**: Sufficient space for embeddings (6KB per embedding)
- [ ] **Backup Strategy**: Regular backups including embedding tables

### Post-Deployment Validation
- [ ] **Data Integrity**: Verify existing data migrated correctly
- [ ] **Performance Tests**: Search response times under load
- [ ] **Cache Functionality**: Semantic cache working correctly
- [ ] **Stored Procedures**: All procedures installed and functional
- [ ] **Monitoring Setup**: Performance and storage monitoring active

### Rollback Plan
- [ ] **Database Backup**: Full backup before deployment
- [ ] **Migration Rollback**: `dotnet ef migrations remove` if needed
- [ ] **Data Recovery**: Restore procedures documented
- [ ] **Application Compatibility**: Previous version compatibility verified

---

## 📊 Schema Statistics

**Total Tables**: 6 (2 existing enhanced + 4 new embedding tables)
**Total Relationships**: 5 (1 one-to-many + 4 one-to-one)
**Total Indexes**: 12+ (performance optimized)
**Storage Multiplier**: ~4x (due to multiple embeddings per chunk)
**Search Capability**: Multi-field vector similarity with semantic caching

The enhanced schema provides comprehensive support for advanced RAG functionality while maintaining data integrity and query performance. 🎯