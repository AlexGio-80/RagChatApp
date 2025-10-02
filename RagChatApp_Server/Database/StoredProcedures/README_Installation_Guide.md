# RAG Chat App - Installation Reference Guide

> **📖 NOTE**: This is a **reference guide** for technical details about RAG installation options.
>
> **For production installation**, see: `../../00_PRODUCTION_SETUP_GUIDE.md` (Section 1.6)
>
> This file provides:
> - Comparison between CLR and VECTOR implementations
> - Technical details and performance characteristics
> - Troubleshooting and optimization tips

---

## 🎯 Choose Your Installation Path

This application offers **two installation methods** to accommodate different SQL Server versions and requirements:

| Installation Method | SQL Server Version | Status | Recommendation |
|---------------------|-------------------|--------|----------------|
| **CLR-based** | 2016, 2017, 2019, 2022, 2025 RC | ✅ Production Ready | **Recommended for most users** |
| **VECTOR-based** | 2025 RTM+ (when available) | ⏳ Future Ready | Use when VECTOR type is fully released |

---

## 📊 Comparison Matrix

### CLR Installation

**Pros:**
- ✅ Works with SQL Server 2016-2025 (including RC versions)
- ✅ Production-ready and battle-tested
- ✅ Accurate cosine similarity implementation
- ✅ No preview features or experimental APIs
- ✅ Available today

**Cons:**
- ⚠️ Requires CLR assembly deployment
- ⚠️ Requires database TRUSTWORTHY setting
- ⚠️ Slightly more complex initial setup

**Best for:**
- Production environments running SQL Server 2016-2022
- Organizations using SQL Server 2025 RC/Preview
- Teams that need a stable solution now
- Environments with existing CLR assemblies

### VECTOR Installation

**Pros:**
- ✅ Native SQL Server 2025 feature (when released)
- ✅ High-performance built-in functions
- ✅ Future-ready for vector indexing
- ✅ No CLR assembly management
- ✅ Simplified deployment

**Cons:**
- ⏳ Requires SQL Server 2025 RTM or later
- ⏳ VECTOR type not available in RC versions
- ⏳ Vector indexing features still in development

**Best for:**
- New deployments on SQL Server 2025 RTM+ (when available)
- Organizations planning to upgrade to SQL Server 2025
- Teams wanting to leverage future vector indexing
- Environments that prohibit CLR usage

---

## 🚀 Quick Start

### Step 1: Check Your SQL Server Version

```sql
SELECT
    CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)) AS Version,
    CAST(SERVERPROPERTY('ProductLevel') AS VARCHAR(50)) AS Level,
    CAST(SERVERPROPERTY('Edition') AS VARCHAR(50)) AS Edition;
```

**Version Guide:**
- `15.x` = SQL Server 2019
- `16.x` = SQL Server 2022
- `17.x` = SQL Server 2025

### Step 2: Choose Installation Method

#### Option A: CLR Installation (Recommended)

**For SQL Server 2016-2025 (all versions)**

```powershell
# Navigate to CLR installation folder
cd C:\OSL\Claude\RagChatApp\RagChatApp_Server\Database\StoredProcedures\CLR

# Run installation script
.\Install-RAG-CLR.ps1 `
    -ServerInstance "YOUR_SERVER\INSTANCE" `
    -DatabaseName "OSL_AI" `
    -DefaultProvider "OpenAI"
```

📖 **Full Documentation**: [CLR/README_CLR_Installation.md](CLR/README_CLR_Installation.md)

#### Option B: VECTOR Installation (SQL Server 2025 RTM+)

**For SQL Server 2025 RTM or later (when VECTOR type is available)**

```powershell
# Navigate to VECTOR installation folder
cd C:\OSL\Claude\RagChatApp\RagChatApp_Server\Database\StoredProcedures\VECTOR

# Run installation script
.\Install-RAG-VECTOR.ps1 `
    -ServerInstance "YOUR_SERVER\INSTANCE" `
    -DatabaseName "OSL_AI" `
    -DefaultProvider "OpenAI"
```

📖 **Full Documentation**: [VECTOR/README_VECTOR_Installation.md](VECTOR/README_VECTOR_Installation.md)

---

## 🎯 Decision Tree

```
Start
  │
  ├─ Are you using SQL Server 2025 RTM with full VECTOR support?
  │   ├─ YES → Use VECTOR Installation
  │   └─ NO ↓
  │
  ├─ Are you using SQL Server 2016-2024 or SQL Server 2025 RC?
  │   ├─ YES → Use CLR Installation ✅ (Recommended)
  │   └─ NO ↓
  │
  └─ Does your organization prohibit CLR assemblies?
      ├─ YES → Wait for SQL Server 2025 RTM or use alternative solutions
      └─ NO → Use CLR Installation ✅
```

---

## 📋 Prerequisites (Both Methods)

### Required
1. **SQL Server** with sysadmin permissions
2. **Windows Server** or Windows 10/11
3. **SQL Server Command Line Tools** (sqlcmd)
4. **.NET SDK** (for CLR method only)

### Recommended
- SQL Server Management Studio (SSMS)
- Visual Studio Code or Visual Studio 2019+
- Git (for version control)

---

## 📁 Repository Structure

```
Database/
├── StoredProcedures/
│   ├── CLR/                                    # CLR-based installation
│   │   ├── Install-RAG-CLR.ps1               # Automated installer
│   │   ├── README_CLR_Installation.md         # Full CLR guide
│   │   └── 02_RAGSearch_CLR.sql              # CLR stored procedures
│   │
│   ├── VECTOR/                                 # VECTOR-based installation
│   │   ├── Install-RAG-VECTOR.ps1            # Automated installer
│   │   ├── README_VECTOR_Installation.md      # Full VECTOR guide
│   │   └── 02_RAGSearch_VECTOR.sql           # VECTOR stored procedures
│   │
│   ├── 01_MultiProviderSupport.sql            # Common: AI provider support
│   ├── 01_DocumentsCRUD.sql                   # Common: Document operations
│   ├── 02_DocumentChunksCRUD.sql              # Common: Chunk operations
│   ├── 04_SemanticCacheManagement.sql         # Common: Cache management
│   └── 09_MigrateToVectorType.sql            # VECTOR: Migration script
│
└── SqlClr/                                     # CLR assembly project
    ├── SqlVectorFunctions.cs                  # C# implementation
    ├── SqlVectorFunctions.csproj              # Project file
    └── README.md                              # CLR assembly documentation
```

---

## ✅ Post-Installation Verification

### Test CLR Functions (CLR Installation Only)

```sql
USE [OSL_AI];

-- Test embedding dimension
DECLARE @TestEmb VARBINARY(MAX);
SELECT TOP 1 @TestEmb = Embedding FROM DocumentChunkContentEmbeddings;

SELECT
    dbo.fn_EmbeddingDimension(@TestEmb) AS Dimension,          -- Should be 768
    dbo.fn_IsValidEmbedding(@TestEmb) AS IsValid,              -- Should be 1
    dbo.fn_CosineSimilarity(@TestEmb, @TestEmb) AS Similarity; -- Should be 1.0
```

### Test VECTOR Functions (VECTOR Installation Only)

```sql
USE [OSL_AI];

-- Test vector distance
DECLARE @TestVec VECTOR(768);
SELECT TOP 1 @TestVec = EmbeddingVector FROM DocumentChunkContentEmbeddings;

SELECT
    VECTOR_DISTANCE('cosine', @TestVec, @TestVec) AS Distance; -- Should be 0.0
```

### Test RAG Search (Both Methods)

```sql
-- Test with existing embedding (mock query)
DECLARE @QueryEmb VARBINARY(MAX);
SELECT TOP 1 @QueryEmb = Embedding FROM DocumentChunkContentEmbeddings;

-- For CLR installation
SELECT TOP 5
    d.FileName,
    dc.Content,
    dbo.fn_CosineSimilarity(ce.Embedding, @QueryEmb) AS Similarity
FROM Documents d
INNER JOIN DocumentChunks dc ON d.Id = dc.DocumentId
INNER JOIN DocumentChunkContentEmbeddings ce ON dc.Id = ce.DocumentChunkId
WHERE dbo.fn_IsValidEmbedding(ce.Embedding) = 1
ORDER BY Similarity DESC;

-- For VECTOR installation
SELECT TOP 5
    d.FileName,
    dc.Content,
    1.0 - VECTOR_DISTANCE('cosine', ce.EmbeddingVector, CAST(@QueryEmb AS VECTOR(768))) AS Similarity
FROM Documents d
INNER JOIN DocumentChunks dc ON d.Id = dc.DocumentId
INNER JOIN DocumentChunkContentEmbeddings ce ON dc.Id = ce.DocumentChunkId
ORDER BY Similarity DESC;
```

---

## 🔧 Configuration

### AI Provider Setup

Both installation methods use the same AI provider configuration in `appsettings.json`:

```json
{
  "AIProvider": {
    "DefaultProvider": "OpenAI",
    "OpenAI": {
      "ApiKey": "sk-...",
      "BaseUrl": "https://api.openai.com/v1/",
      "EmbeddingModel": "text-embedding-3-small",
      "ChatModel": "gpt-4"
    },
    "Gemini": {
      "ApiKey": "AIza...",
      "BaseUrl": "https://generativelanguage.googleapis.com/v1beta/",
      "EmbeddingModel": "models/embedding-001",
      "ChatModel": "models/gemini-pro"
    },
    "AzureOpenAI": {
      "ApiKey": "...",
      "Endpoint": "https://your-resource.openai.azure.com/",
      "EmbeddingDeployment": "text-embedding-ada-002",
      "ChatDeployment": "gpt-4",
      "ApiVersion": "2024-02-15-preview"
    }
  }
}
```

---

## 🔄 Migration Between Methods

### From CLR to VECTOR (When Upgrading to SQL Server 2025 RTM)

```powershell
# 1. Backup your database
# 2. Run migration script
sqlcmd -S "SERVER" -d "OSL_AI" -E -i "09_MigrateToVectorType.sql"

# 3. Install VECTOR procedures
cd VECTOR
.\Install-RAG-VECTOR.ps1 -ServerInstance "SERVER" -DatabaseName "OSL_AI" -SkipMigration

# 4. Test thoroughly before removing CLR
# 5. Optionally remove CLR assembly
sqlcmd -S "SERVER" -d "OSL_AI" -E -Q "DROP ASSEMBLY SqlVectorFunctions"
```

### From VECTOR to CLR (Downgrade Scenario)

VARBINARY embeddings are preserved alongside VECTOR columns, so switching back is straightforward:

```powershell
cd CLR
.\Install-RAG-CLR.ps1 -ServerInstance "SERVER" -DatabaseName "OSL_AI"
```

---

## 🐛 Common Issues

### Issue: "Which installation should I choose?"

**For production today**: Use **CLR installation**
**For future SQL Server 2025 RTM**: Plan for **VECTOR installation**

### Issue: "CLR installation fails"

See [CLR/README_CLR_Installation.md](CLR/README_CLR_Installation.md) troubleshooting section

### Issue: "VECTOR type not supported"

Your SQL Server version doesn't support VECTOR type yet. Use CLR installation instead.

### Issue: "Can I use both methods?"

No. Choose one method and stick with it. Both methods provide the same functionality.

---

## 📚 Additional Resources

- **CLR Installation Guide**: [CLR/README_CLR_Installation.md](CLR/README_CLR_Installation.md)
- **VECTOR Installation Guide**: [VECTOR/README_VECTOR_Installation.md](VECTOR/README_VECTOR_Installation.md)
- **CLR Assembly Documentation**: [../SqlClr/README.md](../SqlClr/README.md)
- **API Documentation**: [README.md](README.md)
- **Database Schema**: [../DatabaseSchemas/rag-database-schema.md](../DatabaseSchemas/rag-database-schema.md)

---

## 🆘 Support

For issues or questions:
1. Check this installation guide
2. Review method-specific documentation (CLR or VECTOR)
3. Check troubleshooting sections
4. Review application and SQL Server logs
5. Create an issue on GitHub

---

## 📝 Version History

### Current Version (1.0.0)
- ✅ CLR installation (Production Ready)
- ⏳ VECTOR installation (Future Ready for SQL 2025 RTM)
- ✅ Dual installation path support
- ✅ Automated PowerShell installers
- ✅ Comprehensive documentation

---

**Recommendation**: Use **CLR installation** for production deployments today. Plan to migrate to **VECTOR installation** when SQL Server 2025 RTM is released with full VECTOR type support.

**Last Updated**: October 1, 2025
