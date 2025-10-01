# Generate SQL script with assembly as hexadecimal
$dllPath = "C:\OSL\Claude\RagChatApp\RagChatApp_Server\Database\SqlClr\bin\Release\SqlVectorFunctions.dll"
$outputPath = "C:\OSL\Claude\RagChatApp\RagChatApp_Server\Database\StoredProcedures\11_DeployCLRFromHex.sql"

Write-Host "Reading DLL file..."
$bytes = [System.IO.File]::ReadAllBytes($dllPath)
$dllSize = $bytes.Length
Write-Host "DLL size: $dllSize bytes"

Write-Host "Converting to hexadecimal..."
$hex = "0x" + (($bytes | ForEach-Object { $_.ToString("X2") }) -join "")

Write-Host "Generating SQL script..."
$sqlScript = @"
-- =============================================
-- Deploy SQL CLR Vector Functions (From Hex)
-- =============================================
USE [OSL_AI]
GO

PRINT 'Deploying SqlVectorFunctions assembly from hexadecimal...';
PRINT 'Assembly size: $dllSize bytes';
GO

-- Drop existing if present
IF EXISTS (SELECT * FROM sys.assemblies WHERE name = 'SqlVectorFunctions')
BEGIN
    DROP ASSEMBLY SqlVectorFunctions;
    PRINT 'Dropped existing assembly';
END
GO

-- Create assembly from hexadecimal
CREATE ASSEMBLY SqlVectorFunctions
FROM $hex
WITH PERMISSION_SET = SAFE;
GO

PRINT 'Assembly registered successfully!';
GO

-- Create functions
CREATE FUNCTION dbo.fn_CosineSimilarity(
    @embedding1 VARBINARY(MAX),
    @embedding2 VARBINARY(MAX)
)
RETURNS FLOAT
AS EXTERNAL NAME SqlVectorFunctions.SqlVectorFunctions.CosineSimilarity;
GO

CREATE FUNCTION dbo.fn_EmbeddingToString(
    @embedding VARBINARY(MAX),
    @maxValues INT
)
RETURNS NVARCHAR(MAX)
AS EXTERNAL NAME SqlVectorFunctions.SqlVectorFunctions.EmbeddingToString;
GO

CREATE FUNCTION dbo.fn_EmbeddingDimension(
    @embedding VARBINARY(MAX)
)
RETURNS INT
AS EXTERNAL NAME SqlVectorFunctions.SqlVectorFunctions.EmbeddingDimension;
GO

CREATE FUNCTION dbo.fn_IsValidEmbedding(
    @embedding VARBINARY(MAX)
)
RETURNS BIT
AS EXTERNAL NAME SqlVectorFunctions.SqlVectorFunctions.IsValidEmbedding;
GO

PRINT 'All CLR functions created successfully!';
GO
"@

[System.IO.File]::WriteAllText($outputPath, $sqlScript)
Write-Host "SQL script generated: $outputPath"
Write-Host "Script size: $($sqlScript.Length) characters"
