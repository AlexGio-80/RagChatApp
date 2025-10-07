# Verify ZIP package contents
Write-Host "=== Verifying ZIP Package ===" -ForegroundColor Cyan
Write-Host ""

$zip = Get-ChildItem -Filter "RagChatApp_DeploymentPackage_*.zip" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $zip) {
    Write-Host "ERROR: No ZIP found!" -ForegroundColor Red
    exit 1
}

Write-Host "ZIP file: $($zip.Name)" -ForegroundColor Yellow
Write-Host "ZIP size: $([math]::Round($zip.Length/1MB, 2)) MB (compressed)" -ForegroundColor Yellow
Write-Host ""

# Extract
Write-Host "Extracting ZIP..." -ForegroundColor Cyan
$extractPath = ".\VerifyExtract"
if (Test-Path $extractPath) {
    Remove-Item $extractPath -Recurse -Force
}
Expand-Archive -Path $zip.FullName -DestinationPath $extractPath -Force

# Check Application folder
$appPath = Join-Path $extractPath "Application"
if (-not (Test-Path $appPath)) {
    Write-Host "ERROR: Application folder not found in ZIP!" -ForegroundColor Red
    exit 1
}

Write-Host "Analyzing extracted Application folder..." -ForegroundColor Cyan
Write-Host ""

$files = Get-ChildItem $appPath -Recurse -File
$dlls = Get-ChildItem $appPath -Filter "*.dll" -Recurse
$totalSize = [math]::Round(($files | Measure-Object -Property Length -Sum).Sum/1MB, 2)
$systemDlls = $dlls | Where-Object { $_.Name -like "System.*.dll" }

Write-Host "Files: $($files.Count)"
Write-Host "DLLs: $($dlls.Count)"
Write-Host "Size: $totalSize MB (uncompressed)"
Write-Host "System DLLs: $($systemDlls.Count)" -ForegroundColor $(if ($systemDlls.Count -gt 50) { "Green" } else { "Red" })
Write-Host ""

# Final verdict
if ($systemDlls.Count -gt 50) {
    Write-Host "==================================" -ForegroundColor Green
    Write-Host "RESULT: SELF-CONTAINED!" -ForegroundColor Green
    Write-Host "==================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "The ZIP is correct! It's compressed from $totalSize MB to $([math]::Round($zip.Length/1MB, 2)) MB"
    Write-Host "When extracted on the server, it will be $totalSize MB and include .NET Runtime"
} else {
    Write-Host "==================================" -ForegroundColor Red
    Write-Host "RESULT: FRAMEWORK-DEPENDENT!" -ForegroundColor Red
    Write-Host "==================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "The package does NOT include .NET Runtime!"
}

Write-Host ""
Write-Host "Sample System DLLs found:"
$systemDlls | Select-Object -First 10 Name | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Gray }
