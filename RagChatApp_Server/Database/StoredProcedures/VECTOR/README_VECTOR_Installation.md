# RAG Chat App - VECTOR Installation Reference

> **📖 NOTE**: This is a **technical reference** for VECTOR installation details.
>
> **For production installation**, see: `../../../00_PRODUCTION_SETUP_GUIDE.md` (Section 1.6)
>
> This file provides:
> - Detailed VECTOR type setup instructions
> - Migration from CLR to VECTOR
> - Troubleshooting and compatibility checks
> - Performance optimization tips

---

## Overview

This guide covers the installation of the RAG (Retrieval-Augmented Generation) Chat Application using **native SQL Server 2025 VECTOR type** for vector similarity calculations.

⚠️ **IMPORTANT**: This installation method requires SQL Server 2025 RTM or later with full VECTOR type support. As of October 2025, SQL Server 2025 is in RC (Release Candidate) and does not yet support the VECTOR type. **Use CLR installation instead for current deployments.**

## 🎯 When to Use VECTOR Installation

### Use VECTOR Installation When:
- ✅ You're running SQL Server 2025 RTM (GA release) or later
- ✅ VECTOR type is fully supported (not in RC/Preview)
- ✅ You want native SQL Server performance
- ✅ You're planning for future vector indexing features
- ✅ Your organization prohibits CLR assemblies

### Do NOT Use VECTOR Installation If:
- ❌ You're running SQL Server 2016-2024
- ❌ You're running SQL Server 2025 RC/Preview (VECTOR not available yet)
- ❌ You need a solution today → **Use CLR installation instead**

## 📋 Prerequisites

### Required
1. **SQL Server 2025 RTM** or later with VECTOR type support
2. **Windows Server** or Windows 10/11
3. **SQL Server Command Line Tools** (sqlcmd)
4. **Sysadmin permissions** on SQL Server

### Optional
- SQL Server Management Studio (SSMS)
- Visual Studio Code or Visual Studio
- Git (for version control)

## ✅ Pre-Installation Verification

### Check SQL Server Version

```sql
SELECT
    CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)) AS Version,
    CAST(SERVERPROPERTY('ProductLevel') AS VARCHAR(50)) AS Level,
    CAST(SERVERPROPERTY('Edition') AS VARCHAR(50)) AS Edition;
```

**Expected**: Version 17.x (SQL Server 2025) with Level = 'RTM' or higher

### Check VECTOR Type Support

```sql
USE [OSL_AI];
BEGIN TRY
    -- Test VECTOR type
    DECLARE @TestVector VECTOR(768);
    SET @TestVector = CAST(REPLICATE(0x00000000, 768) AS VECTOR(768));

    SELECT 'VECTOR type is supported' AS Status;
END TRY
BEGIN CATCH
    SELECT 'VECTOR type NOT supported: ' + ERROR_MESSAGE() AS Status;
END CATCH
```

**Expected**: `VECTOR type is supported`

**If you see errors**:
- VECTOR type is not yet available
- Use [CLR installation](../CLR/README_CLR_Installation.md) instead

## 🚀 Installation Methods

### Option 1: Automated Installation (Recommended)

```powershell
# Navigate to VECTOR installation folder
cd C:\OSL\Claude\RagChatApp\RagChatApp_Server\Database\StoredProcedures\VECTOR

# Run automated installer
.\Install-RAG-VECTOR.ps1 `
    -ServerInstance "YOUR_SERVER\INSTANCE" `
    -DatabaseName "OSL_AI" `
    -DefaultProvider "OpenAI"

# With API keys (optional)
.\Install-RAG-VECTOR.ps1 `
    -ServerInstance "YOUR_SERVER\INSTANCE" `
    -DatabaseName "OSL_AI" `
    -OpenAIApiKey "sk-..." `
    -GeminiApiKey "AIza..." `
    -DefaultProvider "OpenAI"

# Skip migration if already migrated
.\Install-RAG-VECTOR.ps1 `
    -ServerInstance "YOUR_SERVER\INSTANCE" `
    -DatabaseName "OSL_AI" `
    -SkipMigration
```

**Script Parameters:**
- `-ServerInstance`: SQL Server instance name
- `-DatabaseName`: Target database (default: "OSL_AI")
- `-OpenAIApiKey`: OpenAI API key (optional)
- `-GeminiApiKey`: Google Gemini API key (optional)
- `-AzureOpenAIApiKey`: Azure OpenAI key (optional)
- `-AzureOpenAIEndpoint`: Azure endpoint (optional)
- `-DefaultProvider`: Default AI provider
- `-SkipMigration`: Skip VARBINARY → VECTOR migration

### Option 2: Manual Installation

#### Step 1: Migrate Embeddings to VECTOR Type

```bash
# Run migration script
cd C:\OSL\Claude\RagChatApp\RagChatApp_Server\Database\StoredProcedures
sqlcmd -S "YOUR_SERVER" -d "OSL_AI" -E -i "09_MigrateToVectorType.sql"
```

This script:
1. Adds `EmbeddingVector VECTOR(768)` columns to all embedding tables
2. Converts VARBINARY embeddings to VECTOR type
3. Verifies migration success

**Expected output:**
```
✓ Added EmbeddingVector columns
✓ Content embeddings migrated: 426 rows
✓ Header embeddings migrated: 426 rows
Migration Successful!
```

#### Step 2: Install Base Stored Procedures

```bash
cd C:\OSL\Claude\RagChatApp\RagChatApp_Server\Database\StoredProcedures

# Install shared procedures
sqlcmd -S "YOUR_SERVER" -d "OSL_AI" -E -i "01_MultiProviderSupport.sql"
sqlcmd -S "YOUR_SERVER" -d "OSL_AI" -E -i "01_DocumentsCRUD.sql"
sqlcmd -S "YOUR_SERVER" -d "OSL_AI" -E -i "02_DocumentChunksCRUD.sql"
sqlcmd -S "YOUR_SERVER" -d "OSL_AI" -E -i "04_SemanticCacheManagement.sql"
```

#### Step 3: Install VECTOR RAG Procedures

```bash
cd VECTOR
sqlcmd -S "YOUR_SERVER" -d "OSL_AI" -E -i "02_RAGSearch_VECTOR.sql"
```

## ✅ Verification

### Test VECTOR Functions

```sql
USE [OSL_AI];

-- Get a test vector
DECLARE @TestVector VECTOR(768);
SELECT TOP 1 @TestVector = EmbeddingVector
FROM DocumentChunkContentEmbeddings
WHERE EmbeddingVector IS NOT NULL;

-- Test vector distance (should be 0.0 for same vector)
SELECT VECTOR_DISTANCE('cosine', @TestVector, @TestVector) AS Distance;

-- Test vector search
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

**Expected results:**
- Distance: 0.0 (for same vector)
- Similarity: 1.0 (for same vector)
- Results ordered correctly by similarity

### Test RAG Search Procedure

```sql
EXEC SP_RAGSearch_MultiProvider
    @QueryText = 'sistema operativo richiesto',
    @TopK = 5,
    @SimilarityThreshold = 0.7,
    @AIProvider = 'OpenAI',
    @ApiKey = 'your-api-key',
    @IncludeMetadata = 1;
```

## 🔧 Configuration

### AI Provider Setup

Configure in `appsettings.json`:

```json
{
  "AIProvider": {
    "DefaultProvider": "OpenAI",
    "OpenAI": {
      "ApiKey": "sk-...",
      "BaseUrl": "https://api.openai.com/v1/",
      "EmbeddingModel": "text-embedding-3-small"
    },
    "Gemini": {
      "ApiKey": "AIza...",
      "BaseUrl": "https://generativelanguage.googleapis.com/v1beta/",
      "EmbeddingModel": "models/embedding-001"
    }
  }
}
```

### Database Configuration

No additional configuration needed beyond the migration.

## 📊 Performance Considerations

### VECTOR Type Benefits
- **Native Performance**: Optimized by SQL Server engine
- **Future Indexing**: Support for vector indexes (when available)
- **Memory Efficient**: Optimized internal representation
- **Query Optimization**: Better execution plans

### Expected Performance
- **Single comparison**: < 1ms
- **1,000 comparisons**: ~50-100ms (expected faster than CLR)
- **10,000 comparisons**: ~500ms-1s (expected faster than CLR)

### Optimization Tips
1. **Use vector indexes** when available in future SQL Server releases
2. **Limit result sets** with appropriate `@TopK` values
3. **Filter early** with WHERE clauses
4. **Use semantic cache** for repeated queries

## 🔄 Migration from CLR to VECTOR

If you're currently using CLR installation:

### Step 1: Verify VARBINARY Embeddings Exist

```sql
-- Check that original embeddings are still present
SELECT COUNT(*) FROM DocumentChunkContentEmbeddings WHERE Embedding IS NOT NULL;
```

### Step 2: Run Migration

```bash
sqlcmd -S "SERVER" -d "OSL_AI" -E -i "09_MigrateToVectorType.sql"
```

### Step 3: Install VECTOR Procedures

```bash
cd VECTOR
.\Install-RAG-VECTOR.ps1 -ServerInstance "SERVER" -DatabaseName "OSL_AI" -SkipMigration
```

### Step 4: Test Thoroughly

Run verification tests before removing CLR.

### Step 5: Remove CLR (Optional)

Once verified, you can remove CLR components:

```sql
-- Drop CLR functions
DROP FUNCTION dbo.fn_CosineSimilarity;
DROP FUNCTION dbo.fn_EmbeddingToString;
DROP FUNCTION dbo.fn_EmbeddingDimension;
DROP FUNCTION dbo.fn_IsValidEmbedding;

-- Drop CLR assembly
DROP ASSEMBLY SqlVectorFunctions;

-- Remove TRUSTWORTHY (if desired)
ALTER DATABASE [OSL_AI] SET TRUSTWORTHY OFF;
```

## 🐛 Troubleshooting

### Issue: "VECTOR type not supported"

**Cause**: SQL Server version doesn't support VECTOR type

**Solution**:
1. Verify SQL Server 2025 RTM or later
2. Check SQL Server build number
3. If RC/Preview, use [CLR installation](../CLR/README_CLR_Installation.md) instead

### Issue: "Invalid cast from VARBINARY to VECTOR"

**Cause**: VARBINARY format incompatible with VECTOR type

**Solution**: Ensure embeddings are float32 arrays (768 values × 4 bytes = 3072 bytes)

### Issue: "Migration fails with error"

**Possible causes:**
1. VECTOR type not available
2. Embedding data corruption
3. Insufficient permissions

**Solution**: Check error message and verify VECTOR support:
```sql
SELECT @@VERSION;
```

### Issue: "Performance slower than expected"

**Possible causes:**
1. Missing indexes
2. Large dataset without optimization
3. Complex query plans

**Solution**:
1. Analyze query execution plans
2. Add appropriate indexes
3. Use result limiting with `@TopK`

## 📚 Additional Resources

- [Main Installation Guide](../README_Installation_Guide.md)
- [CLR Installation Alternative](../CLR/README_CLR_Installation.md)
- [Database Schema](../DatabaseSchemas/rag-database-schema.md)
- [API Documentation](../README.md)
- [SQL Server VECTOR Documentation](https://learn.microsoft.com/en-us/sql/t-sql/data-types/vector) (when available)

## 🆘 Support

For issues or questions:
1. Verify SQL Server 2025 RTM with VECTOR support
2. Check this documentation
3. Review SQL Server error logs
4. If VECTOR not supported, use CLR installation
5. Create issue on GitHub with details

## 📝 Changelog

### Version 1.0.0 (October 2025)
- ✅ Initial VECTOR implementation
- ✅ Migration script for VARBINARY → VECTOR
- ✅ SP_RAGSearch_MultiProvider with VECTOR_DISTANCE
- ✅ Automated installation script
- ⏳ Awaiting SQL Server 2025 RTM release

---

**Installation Type**: VECTOR (Native SQL Server 2025)
**Compatibility**: SQL Server 2025 RTM or later
**Status**: ⏳ **Awaiting SQL Server 2025 RTM**
**Alternative**: Use [CLR Installation](../CLR/README_CLR_Installation.md) for current deployments
**Last Updated**: October 1, 2025
