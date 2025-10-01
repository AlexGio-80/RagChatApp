# CLR Installation - Manual Steps

**Note**: If the PowerShell script has encoding issues, follow these manual steps instead.

## Step 1: Build CLR Assembly

```bash
cd C:\OSL\Claude\RagChatApp\RagChatApp_Server\Database\SqlClr
dotnet restore
dotnet build -c Release
```

Verify DLL exists: `bin\Release\SqlVectorFunctions.dll`

## Step 2: Configure SQL Server

```powershell
# Enable CLR
sqlcmd -S "DEV-ALEX\MSSQLSERVER01" -d "master" -E -Q "EXEC sp_configure 'clr enabled', 1; RECONFIGURE;"

# Disable CLR strict security
sqlcmd -S "DEV-ALEX\MSSQLSERVER01" -d "master" -E -Q "EXEC sp_configure 'show advanced options', 1; RECONFIGURE; EXEC sp_configure 'clr strict security', 0; RECONFIGURE;"

# Set database as TRUSTWORTHY
sqlcmd -S "DEV-ALEX\MSSQLSERVER01" -d "master" -E -Q "ALTER DATABASE [OSL_AI] SET TRUSTWORTHY ON;"
```

## Step 3: Deploy CLR Assembly

```powershell
# Clean up existing
sqlcmd -S "DEV-ALEX\MSSQLSERVER01" -d "OSL_AI" -E -Q "IF OBJECT_ID('dbo.fn_CosineSimilarity') IS NOT NULL DROP FUNCTION dbo.fn_CosineSimilarity; IF OBJECT_ID('dbo.fn_EmbeddingToString') IS NOT NULL DROP FUNCTION dbo.fn_EmbeddingToString; IF OBJECT_ID('dbo.fn_EmbeddingDimension') IS NOT NULL DROP FUNCTION dbo.fn_EmbeddingDimension; IF OBJECT_ID('dbo.fn_IsValidEmbedding') IS NOT NULL DROP FUNCTION dbo.fn_IsValidEmbedding; IF EXISTS (SELECT * FROM sys.assemblies WHERE name = 'SqlVectorFunctions') DROP ASSEMBLY SqlVectorFunctions;"

# Register assembly
sqlcmd -S "DEV-ALEX\MSSQLSERVER01" -d "OSL_AI" -E -Q "CREATE ASSEMBLY SqlVectorFunctions FROM 'C:\OSL\Claude\RagChatApp\RagChatApp_Server\Database\SqlClr\bin\Release\SqlVectorFunctions.dll' WITH PERMISSION_SET = SAFE;"

# Create functions
sqlcmd -S "DEV-ALEX\MSSQLSERVER01" -d "OSL_AI" -E -Q "CREATE FUNCTION dbo.fn_CosineSimilarity(@embedding1 VARBINARY(MAX), @embedding2 VARBINARY(MAX)) RETURNS FLOAT AS EXTERNAL NAME SqlVectorFunctions.SqlVectorFunctions.CosineSimilarity;"

sqlcmd -S "DEV-ALEX\MSSQLSERVER01" -d "OSL_AI" -E -Q "CREATE FUNCTION dbo.fn_EmbeddingToString(@embedding VARBINARY(MAX), @maxValues INT) RETURNS NVARCHAR(MAX) AS EXTERNAL NAME SqlVectorFunctions.SqlVectorFunctions.EmbeddingToString;"

sqlcmd -S "DEV-ALEX\MSSQLSERVER01" -d "OSL_AI" -E -Q "CREATE FUNCTION dbo.fn_EmbeddingDimension(@embedding VARBINARY(MAX)) RETURNS INT AS EXTERNAL NAME SqlVectorFunctions.SqlVectorFunctions.EmbeddingDimension;"

sqlcmd -S "DEV-ALEX\MSSQLSERVER01" -d "OSL_AI" -E -Q "CREATE FUNCTION dbo.fn_IsValidEmbedding(@embedding VARBINARY(MAX)) RETURNS BIT AS EXTERNAL NAME SqlVectorFunctions.SqlVectorFunctions.IsValidEmbedding;"
```

## Step 4: Install Stored Procedures

```bash
cd C:\OSL\Claude\RagChatApp\RagChatApp_Server\Database\StoredProcedures

sqlcmd -S "DEV-ALEX\MSSQLSERVER01" -d "OSL_AI" -E -i "01_MultiProviderSupport.sql"
sqlcmd -S "DEV-ALEX\MSSQLSERVER01" -d "OSL_AI" -E -i "01_DocumentsCRUD.sql"
sqlcmd -S "DEV-ALEX\MSSQLSERVER01" -d "OSL_AI" -E -i "02_DocumentChunksCRUD.sql"
sqlcmd -S "DEV-ALEX\MSSQLSERVER01" -d "OSL_AI" -E -i "04_SemanticCacheManagement.sql"

cd CLR
sqlcmd -S "DEV-ALEX\MSSQLSERVER01" -d "OSL_AI" -E -i "02_RAGSearch_CLR.sql"
```

## Step 5: Test Installation

```powershell
sqlcmd -S "DEV-ALEX\MSSQLSERVER01" -d "OSL_AI" -E -Q "DECLARE @TestEmb VARBINARY(MAX); SELECT TOP 1 @TestEmb = Embedding FROM DocumentChunkContentEmbeddings WHERE Embedding IS NOT NULL; SELECT dbo.fn_EmbeddingDimension(@TestEmb) AS Dimension, dbo.fn_IsValidEmbedding(@TestEmb) AS IsValid, dbo.fn_CosineSimilarity(@TestEmb, @TestEmb) AS SelfSimilarity;"
```

Expected output:
- Dimension: 768
- IsValid: 1
- SelfSimilarity: 1.0

## Done!

The CLR installation is complete. You can now use the RAG search with accurate cosine similarity.
