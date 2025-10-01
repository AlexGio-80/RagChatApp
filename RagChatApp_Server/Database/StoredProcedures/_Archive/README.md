# Archived Files

This folder contains experimental and obsolete scripts that were created during development but are not part of the final solution.

## Files

### 07_FixVectorSearch.sql
**Status**: ❌ Failed Experiment
**Reason**: Attempted to use native `VECTOR_DISTANCE` function with VARBINARY embeddings
**Error**: SQL Server 2025 RC requires VECTOR type, not VARBINARY
**Lesson Learned**: Native VECTOR support requires actual VECTOR(768) columns, not VARBINARY(MAX)
**Superseded By**: CLR/02_RAGSearch_CLR.sql (CLR approach) or VECTOR/02_RAGSearch_VECTOR.sql (for SQL 2025 RTM+)

### 08_CosineSimilarityFunction.sql
**Status**: ❌ Failed Experiment
**Reason**: Attempted to create T-SQL inline function for cosine similarity
**Error**: Cannot cast VARBINARY to FLOAT directly in T-SQL
**Lesson Learned**: T-SQL cannot perform byte-level operations needed for vector calculations
**Superseded By**: CLR functions (SqlVectorFunctions.cs)

### 11_DeployCLRFromHex.sql
**Status**: ⚠️ Partially Successful
**Reason**: Alternative CLR deployment method using hexadecimal DLL representation
**Issue**: SQL Server has strict security checks that prevent assembly loading even with hex format
**Lesson Learned**: Must disable "CLR strict security" or use TRUSTWORTHY database
**Superseded By**: 10_DeployCLRFunctions.sql (direct file path approach)

### Install-MultiProvider.ps1 / Install-MultiProvider-Fixed.ps1
**Status**: ⚠️ Obsolete
**Reason**: Early installation scripts before CLR/VECTOR split
**Issue**: Mixed concerns, no clear separation between deployment methods
**Superseded By**: CLR/Install-RAG-CLR.ps1 and VECTOR/Install-RAG-VECTOR.ps1

### Install-StoredProcedures.ps1
**Status**: ⚠️ Obsolete
**Reason**: Generic installation script without vector search implementation
**Superseded By**: Method-specific installers in CLR/ and VECTOR/ folders

### 02_UpdateExistingProcedures_OLD.sql
**Status**: ⚠️ Obsolete
**Reason**: Mixed random similarity + early CLR integration attempts
**Superseded By**: CLR/02_RAGSearch_CLR.sql (clean CLR implementation)

### 00_InstallAllStoredProcedures.sql
**Status**: ⚠️ Obsolete
**Archived**: October 1, 2025
**Reason**: Early unified installation script without encryption or multi-provider support
**Issue**: No API key encryption, manual configuration required
**Superseded By**: Install-MultiProvider-Fixed.ps1 (automated, encrypted configuration)

### 00_InstallAllStoredProcedures_Unified.sql
**Status**: ⚠️ Obsolete
**Archived**: October 1, 2025
**Reason**: Duplicate of 00_InstallAllStoredProcedures.sql with minor variations
**Superseded By**: Install-MultiProvider-Fixed.ps1

### 03_RAGSearchProcedure.sql
**Status**: ⚠️ Obsolete
**Archived**: October 1, 2025
**Reason**: Generic RAG search without vector search implementation (random similarity)
**Issue**: Did not use proper cosine similarity calculation
**Superseded By**: CLR/02_RAGSearch_CLR.sql (CLR with fn_CosineSimilarity) or VECTOR/02_RAGSearch_VECTOR.sql (native VECTOR_DISTANCE)

### 05_OpenAIEmbeddingIntegration.sql
**Status**: ⚠️ Obsolete
**Archived**: October 1, 2025
**Reason**: OpenAI-only embedding generation
**Issue**: Single provider support, no encryption
**Superseded By**: 01_MultiProviderSupport.sql (multi-provider with OpenAI, Gemini, Azure) + 06_EncryptedConfiguration.sql (encrypted API keys)

### README_Installation_OLD.md
**Status**: ⚠️ Obsolete
**Archived**: October 1, 2025
**Reason**: Installation guide before CLR/VECTOR split and encryption system
**Superseded By**: 00_SETUP_GUIDE.md (complete setup from zero) + README_Installation_Guide.md (CLR vs VECTOR choice)

## Why Keep These Files?

These files are preserved as:
1. **Historical reference** for understanding the development process
2. **Learning material** for troubleshooting similar issues
3. **Documentation** of what doesn't work and why

## Do Not Use

⚠️ **Do not use these files in production or development.**

Use the official installation methods instead:
- **Complete Setup Guide**: `00_SETUP_GUIDE.md` (start here for new installations)
- **Multi-Provider Installer**: `Install-MultiProvider-Fixed.ps1` (base system + encryption)
- **CLR Installation**: `CLR/Install-RAG-CLR.ps1` (vector search via CLR)
- **VECTOR Installation**: `VECTOR/Install-RAG-VECTOR.ps1` (vector search via SQL 2025)

## Related Documentation

- [Complete Setup Guide](../00_SETUP_GUIDE.md) - **START HERE**
- [Installation Guide (CLR vs VECTOR)](../README_Installation_Guide.md)
- [CLR Installation Guide](../CLR/README_CLR_Installation.md)
- [VECTOR Installation Guide](../VECTOR/README_VECTOR_Installation.md)
- [Simplified RAG API](../README_SimplifiedRAG.md)

---

**Archive Date**: October 1, 2025
**Reason**: Development experiments superseded by working solutions
