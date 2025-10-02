# RAG Search - Technical Reference Guide

> **📖 NOTE**: This is a **detailed technical reference** for RAG installation.
>
> **For production installation**, see: `00_PRODUCTION_SETUP_GUIDE.md` (Section 1.6)
>
> This file provides:
> - Detailed comparison of CLR vs VECTOR
> - Advanced installation options
> - Troubleshooting and migration guides
> - Performance tuning recommendations

---

## Overview

This guide explains how to choose and install the RAG (Retrieval-Augmented Generation) search functionality for your RagChatApp deployment.

The RAG search system allows you to retrieve relevant document chunks using vector similarity search and provides them to Large Language Models (LLMs) for accurate, context-aware responses.

## 🎯 Two Installation Options

### Option 1: CLR (SQL Server 2016-2025)
**Uses**: SQL CLR (Common Language Runtime) functions for vector similarity calculations

✅ **Choose CLR if**:
- You're running SQL Server 2016, 2017, 2019, or 2022
- You're running SQL Server 2025 RC/Preview (VECTOR type not yet available)
- You need a production-ready solution today
- Your organization allows CLR assemblies

**Benefits**:
- ✓ Broad compatibility (SQL Server 2016+)
- ✓ Proven, stable technology
- ✓ Accurate cosine similarity calculation
- ✓ Production tested with real workloads
- ✓ Available immediately

**Requirements**:
- SQL Server 2016 or later
- CLR enabled (`sp_configure 'clr enabled', 1`)
- Database set to TRUSTWORTHY
- .NET Framework 4.7.2+ (for CLR assembly)

### Option 2: VECTOR (SQL Server 2025 RTM+)
**Uses**: Native SQL Server 2025 VECTOR type for vector operations

✅ **Choose VECTOR if**:
- You're running SQL Server 2025 RTM (General Availability) or later
- VECTOR type is fully supported (not RC/Preview)
- You want native SQL Server performance
- You want to leverage future vector indexing features
- Your organization prohibits CLR usage

**Benefits**:
- ✓ Native SQL Server 2025 performance
- ✓ Future vector indexing support
- ✓ Optimized memory usage
- ✓ Better query optimization
- ✓ No CLR dependencies

**Requirements**:
- SQL Server 2025 RTM or later with full VECTOR type support
- ⚠️ **As of October 2025**: SQL Server 2025 is still in RC - use CLR instead

## 🚀 Quick Start: Interactive Installation

### Recommended: Use the Interactive Installer

The interactive installer automatically detects your SQL Server version and recommends the appropriate installation type.

```powershell
# Navigate to deployment package
cd DeploymentPackage

# Run interactive installer
.\Install-RAG-Interactive.ps1 `
    -ServerInstance "YOUR_SERVER\INSTANCE" `
    -DatabaseName "RagChatAppDB" `
    -DefaultProvider "Gemini"

# With API keys (optional, for testing)
.\Install-RAG-Interactive.ps1 `
    -ServerInstance "YOUR_SERVER\INSTANCE" `
    -DatabaseName "RagChatAppDB" `
    -GeminiApiKey "your-gemini-api-key" `
    -OpenAIApiKey "your-openai-api-key" `
    -DefaultProvider "Gemini"

# Non-interactive with auto-detection
.\Install-RAG-Interactive.ps1 `
    -ServerInstance "localhost" `
    -DatabaseName "RagChatAppDB" `
    -NonInteractive `
    -InstallationType Auto
```

**What the script does**:
1. Detects your SQL Server version
2. Tests for VECTOR type support
3. Recommends the best installation type for your setup
4. Installs the selected RAG implementation
5. Verifies the installation

### Manual Installation

If you prefer to install manually or need more control:

#### For CLR Installation:

```powershell
cd Database\StoredProcedures\CLR

.\Install-RAG-CLR.ps1 `
    -ServerInstance "YOUR_SERVER" `
    -DatabaseName "RagChatAppDB" `
    -DefaultProvider "Gemini"
```

**See**: `Database/StoredProcedures/CLR/README_CLR_Installation.md` for detailed instructions

#### For VECTOR Installation:

```powershell
cd Database\StoredProcedures\VECTOR

.\Install-RAG-VECTOR.ps1 `
    -ServerInstance "YOUR_SERVER" `
    -DatabaseName "RagChatAppDB" `
    -DefaultProvider "Gemini"
```

**See**: `Database/StoredProcedures/VECTOR/README_VECTOR_Installation.md` for detailed instructions

## 📋 Pre-Installation Checklist

Before installing RAG functionality:

### Database Prerequisites
- [ ] Database schema installed (`01_DatabaseSchema.sql` executed)
- [ ] Documents table exists with sample data (optional, for testing)
- [ ] DocumentChunks table exists with embeddings (optional, for testing)

### Base Stored Procedures (Required)
- [ ] Multi-provider support procedures installed (`01_MultiProviderSupport.sql`)
- [ ] Document CRUD procedures installed (optional, `01_DocumentsCRUD.sql`)
- [ ] Chunk CRUD procedures installed (optional, `02_DocumentChunksCRUD.sql`)

**Quick install base procedures**:
```bash
cd Database\StoredProcedures
sqlcmd -S "YOUR_SERVER" -d "RagChatAppDB" -E -i "01_MultiProviderSupport.sql"
```

### For CLR Installation Only
- [ ] SQL Server has CLR enabled
- [ ] Database set to TRUSTWORTHY (or using certificates)
- [ ] CLR strict security disabled (SQL Server 2017+) OR assemblies signed

**Enable CLR**:
```sql
USE master;
EXEC sp_configure 'clr enabled', 1;
RECONFIGURE;

-- For SQL Server 2017+
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'clr strict security', 0;
RECONFIGURE;

-- Set database as TRUSTWORTHY
ALTER DATABASE [RagChatAppDB] SET TRUSTWORTHY ON;
```

### For VECTOR Installation Only
- [ ] SQL Server 2025 RTM or later
- [ ] VECTOR type support verified

**Verify VECTOR support**:
```sql
USE [RagChatAppDB];
BEGIN TRY
    DECLARE @TestVector VECTOR(768);
    SELECT 'VECTOR type is supported' AS Status;
END TRY
BEGIN CATCH
    SELECT 'VECTOR type NOT supported - Use CLR installation' AS Status;
END CATCH
```

## ✅ Post-Installation Verification

### 1. Check Installation Status

```sql
USE [RagChatAppDB];

-- For CLR: Verify functions exist
SELECT name, type_desc
FROM sys.objects
WHERE name IN ('fn_CosineSimilarity', 'fn_EmbeddingDimension', 'fn_IsValidEmbedding')
ORDER BY name;

-- For VECTOR: Verify EmbeddingVector columns exist
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE COLUMN_NAME = 'EmbeddingVector'
ORDER BY TABLE_NAME;

-- Verify RAG procedures
SELECT ROUTINE_NAME
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_NAME LIKE '%RAG%'
ORDER BY ROUTINE_NAME;
```

### 2. Test Vector Similarity

**For CLR**:
```sql
-- Get a test embedding
DECLARE @TestEmb VARBINARY(MAX);
SELECT TOP 1 @TestEmb = Embedding
FROM DocumentChunkContentEmbeddings
WHERE Embedding IS NOT NULL;

-- Test self-similarity (should return 1.0)
SELECT dbo.fn_CosineSimilarity(@TestEmb, @TestEmb) AS SelfSimilarity;

-- Expected: 1.0 (perfect similarity)
```

**For VECTOR**:
```sql
-- Get a test vector
DECLARE @TestVector VECTOR(768);
SELECT TOP 1 @TestVector = EmbeddingVector
FROM DocumentChunkContentEmbeddings
WHERE EmbeddingVector IS NOT NULL;

-- Test distance (should return 0.0 for same vector)
SELECT VECTOR_DISTANCE('cosine', @TestVector, @TestVector) AS Distance;

-- Expected: 0.0 (zero distance = perfect similarity)
```

### 3. Test RAG Search

```sql
-- Test with existing embedding (mock query)
DECLARE @QueryEmb VARBINARY(MAX);
SELECT TOP 1 @QueryEmb = Embedding
FROM DocumentChunkContentEmbeddings;

-- For CLR
SELECT TOP 5
    d.FileName,
    dc.Content,
    dbo.fn_CosineSimilarity(ce.Embedding, @QueryEmb) AS Similarity
FROM Documents d
INNER JOIN DocumentChunks dc ON d.Id = dc.DocumentId
INNER JOIN DocumentChunkContentEmbeddings ce ON dc.Id = ce.DocumentChunkId
WHERE ce.Embedding IS NOT NULL
ORDER BY Similarity DESC;

-- For VECTOR
DECLARE @QueryVector VECTOR(768);
SELECT TOP 1 @QueryVector = EmbeddingVector
FROM DocumentChunkContentEmbeddings;

SELECT TOP 5
    d.FileName,
    dc.Content,
    1.0 - VECTOR_DISTANCE('cosine', ce.EmbeddingVector, @QueryVector) AS Similarity
FROM Documents d
INNER JOIN DocumentChunks dc ON d.Id = dc.DocumentId
INNER JOIN DocumentChunkContentEmbeddings ce ON dc.Id = ce.DocumentChunkId
WHERE ce.EmbeddingVector IS NOT NULL
ORDER BY Similarity DESC;
```

### 4. Test Full RAG Workflow

```sql
-- Test with AI provider (requires API key)
EXEC SP_RAGSearch_MultiProvider
    @QueryText = 'your test query',
    @TopK = 5,
    @SimilarityThreshold = 0.7,
    @AIProvider = 'Gemini',
    @ApiKey = 'your-api-key-here',
    @IncludeMetadata = 1;

-- Expected: JSON results with relevant chunks and similarity scores
```

## 🔧 Configuration

### AI Provider Configuration

RAG search requires AI providers for generating query embeddings. Configure in `appsettings.json`:

```json
{
  "AIProvider": {
    "DefaultProvider": "Gemini",
    "Gemini": {
      "ApiKey": "your-gemini-api-key",
      "BaseUrl": "https://generativelanguage.googleapis.com/v1beta",
      "DefaultEmbeddingModel": "models/embedding-001"
    },
    "OpenAI": {
      "ApiKey": "your-openai-api-key",
      "BaseUrl": "https://api.openai.com/v1",
      "DefaultEmbeddingModel": "text-embedding-3-small"
    }
  }
}
```

### Database-Level API Keys (Optional)

For SQL-only access, you can store encrypted API keys in the database:

```sql
-- Insert provider configuration with encrypted API key
EXEC SP_UpsertProviderConfiguration
    @ProviderName = 'Gemini',
    @ApiKey = 'your-actual-api-key',
    @BaseUrl = 'https://generativelanguage.googleapis.com/v1beta',
    @Model = 'models/embedding-001';

-- Keys are automatically encrypted with AES-256
```

**See**: `Database/StoredProcedures/ENCRYPTION_UPGRADE_GUIDE.md` for encryption setup

## 📊 Performance Considerations

### Expected Performance

**CLR Implementation**:
- Single similarity calculation: < 1ms
- 1,000 comparisons: ~100ms
- 10,000 comparisons: ~1 second

**VECTOR Implementation** (expected):
- Single comparison: < 1ms
- 1,000 comparisons: ~50-100ms (faster than CLR)
- 10,000 comparisons: ~500ms-1s (faster than CLR)

### Optimization Tips

1. **Limit result sets**: Use appropriate `@TopK` values (5-20 for most cases)
2. **Filter early**: Use WHERE clauses to reduce comparison count
3. **Index properly**: Ensure foreign keys are indexed
4. **Use semantic cache**: Enable caching for repeated queries
5. **Consider hybrid search**: Combine vector search with keyword filtering

### Scalability

- **Up to 100K chunks**: Excellent performance
- **100K - 1M chunks**: Good performance with proper indexing
- **1M+ chunks**: Consider partitioning or hybrid search strategies

## 🐛 Troubleshooting

### Installation Issues

**Problem**: "CLR type not supported" or "VECTOR type not supported"

**Solution**:
- For CLR: Check SQL Server version (2016+), enable CLR, set TRUSTWORTHY
- For VECTOR: Verify SQL Server 2025 RTM, fall back to CLR if needed

**Problem**: "Permission denied" during installation

**Solution**:
- Ensure you have sysadmin or db_owner permissions
- For CLR: May need server-level ALTER SETTINGS permission
- Check SQL Server error log for specific permission issues

### Runtime Issues

**Problem**: "Self-similarity is not 1.0" (CLR) or "Distance is not 0.0" (VECTOR)

**Cause**: Embedding data corruption or format mismatch

**Solution**:
```sql
-- Verify embedding format
SELECT
    COUNT(*) AS TotalEmbeddings,
    AVG(DATALENGTH(Embedding)) AS AvgByteLength,
    AVG(DATALENGTH(Embedding) / 4) AS AvgDimension
FROM DocumentChunkContentEmbeddings
WHERE Embedding IS NOT NULL;

-- Expected: AvgByteLength = 3072, AvgDimension = 768
```

**Problem**: RAG search returns no results

**Possible causes**:
1. No embeddings in database
2. Similarity threshold too high
3. API key not configured
4. Query embedding generation failed

**Solution**:
```sql
-- Check for embeddings
SELECT COUNT(*) FROM DocumentChunkContentEmbeddings WHERE Embedding IS NOT NULL;

-- Test with lower threshold
EXEC SP_RAGSearch_MultiProvider
    @QueryText = 'test',
    @TopK = 5,
    @SimilarityThreshold = 0.0,  -- Accept any similarity
    @AIProvider = 'Gemini',
    @ApiKey = 'your-key';
```

## 🔄 Migrating Between Implementations

### From CLR to VECTOR

When SQL Server 2025 RTM becomes available:

```powershell
# 1. Install VECTOR procedures (keeps CLR intact)
cd Database\StoredProcedures\VECTOR
.\Install-RAG-VECTOR.ps1 -ServerInstance "SERVER" -DatabaseName "RagChatAppDB" -SkipMigration:$false

# 2. Test VECTOR implementation thoroughly

# 3. Once verified, remove CLR (optional)
```

```sql
-- Remove CLR components (after verification)
DROP FUNCTION dbo.fn_CosineSimilarity;
DROP FUNCTION dbo.fn_EmbeddingDimension;
DROP FUNCTION dbo.fn_IsValidEmbedding;
DROP FUNCTION dbo.fn_EmbeddingToString;
DROP ASSEMBLY SqlVectorFunctions;

ALTER DATABASE [RagChatAppDB] SET TRUSTWORTHY OFF;
```

### From VECTOR to CLR

If you need to downgrade or move to older SQL Server:

```powershell
# Install CLR procedures (VARBINARY embeddings must exist)
cd Database\StoredProcedures\CLR
.\Install-RAG-CLR.ps1 -ServerInstance "SERVER" -DatabaseName "RagChatAppDB"

# VECTOR columns remain but are not used
```

## 📚 Additional Resources

### Documentation
- **CLR Installation**: `Database/StoredProcedures/CLR/README_CLR_Installation.md`
- **VECTOR Installation**: `Database/StoredProcedures/VECTOR/README_VECTOR_Installation.md`
- **CLR Manual Install**: `Database/StoredProcedures/CLR/INSTALL_MANUAL.md`
- **Database Schema**: `Documentation/rag-database-schema.md`
- **Encryption Guide**: `Database/StoredProcedures/ENCRYPTION_UPGRADE_GUIDE.md`

### Microsoft Documentation
- [SQL Server CLR Integration](https://learn.microsoft.com/en-us/sql/relational-databases/clr-integration/)
- [SQL Server VECTOR Type](https://learn.microsoft.com/en-us/sql/t-sql/data-types/vector) (when available)

## 🆘 Support

For issues or questions:

1. **Check this guide** and implementation-specific READMEs
2. **Review SQL Server error logs** (`EXEC xp_readerrorlog`)
3. **Verify prerequisites** (CLR enabled, VECTOR supported, etc.)
4. **Test with simplified queries** (see Troubleshooting section)
5. **Check GitHub issues** or create a new issue with details

## 📝 Summary

### Decision Tree

```
Do you have SQL Server 2025 RTM with VECTOR support?
├─ YES → Install VECTOR (recommended)
└─ NO → Do you have SQL Server 2016 or later?
    ├─ YES → Install CLR (recommended)
    └─ NO → Upgrade SQL Server to 2016 or later
```

### Quick Commands

```powershell
# Recommended: Interactive installer (auto-detects)
.\Install-RAG-Interactive.ps1 -ServerInstance "SERVER" -DatabaseName "RagChatAppDB"

# Manual CLR installation
.\Database\StoredProcedures\CLR\Install-RAG-CLR.ps1 -ServerInstance "SERVER" -DatabaseName "RagChatAppDB"

# Manual VECTOR installation
.\Database\StoredProcedures\VECTOR\Install-RAG-VECTOR.ps1 -ServerInstance "SERVER" -DatabaseName "RagChatAppDB"
```

---

**Last Updated**: October 2, 2025
**Version**: 1.0
**Compatibility**: SQL Server 2016+ (CLR), SQL Server 2025 RTM+ (VECTOR)
