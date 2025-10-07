# Debug script to check package creation
Write-Host "=== Package Debug Info ===" -ForegroundColor Cyan
Write-Host ""

# Check latest ZIP
Write-Host "1. Latest deployment package:" -ForegroundColor Yellow
$latestZip = Get-ChildItem -Filter "RagChatApp_DeploymentPackage_*.zip" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($latestZip) {
    Write-Host "   Name: $($latestZip.Name)"
    Write-Host "   Size: $([math]::Round($latestZip.Length/1MB, 2)) MB"
    Write-Host "   Date: $($latestZip.LastWriteTime)"
} else {
    Write-Host "   NO ZIP FOUND" -ForegroundColor Red
}
Write-Host ""

# Check publish folder
Write-Host "2. Current publish folder:" -ForegroundColor Yellow
$publishPath = "..\..\bin\Release\net9.0\publish"
if (Test-Path $publishPath) {
    $files = Get-ChildItem $publishPath -Recurse -File
    $dlls = Get-ChildItem $publishPath -Filter "*.dll" -Recurse
    $totalSize = [math]::Round(($files | Measure-Object -Property Length -Sum).Sum/1MB, 2)

    Write-Host "   Path exists: YES"
    Write-Host "   Total files: $($files.Count)"
    Write-Host "   DLL files: $($dlls.Count)"
    Write-Host "   Total size: $totalSize MB"

    # Check for System.*.dll (indicates runtime)
    $systemDlls = $dlls | Where-Object { $_.Name -like "System.*.dll" }
    Write-Host "   System DLLs: $($systemDlls.Count)" -ForegroundColor $(if ($systemDlls.Count -gt 50) { "Green" } else { "Red" })

    if ($systemDlls.Count -gt 50) {
        Write-Host "   [OK] Looks like SELF-CONTAINED" -ForegroundColor Green
    } else {
        Write-Host "   [WARNING] Looks like FRAMEWORK-DEPENDENT" -ForegroundColor Red
    }
} else {
    Write-Host "   Path exists: NO" -ForegroundColor Red
}
Write-Host ""

# Check last package folder
Write-Host "3. Latest deployment folder:" -ForegroundColor Yellow
$latestFolder = Get-ChildItem -Directory | Where-Object { $_.Name -like "*DeploymentPackage*" -or $_.Name -like "Test*" } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($latestFolder) {
    Write-Host "   Name: $($latestFolder.Name)"
    $appPath = Join-Path $latestFolder.FullName "Application"
    if (Test-Path $appPath) {
        $appFiles = Get-ChildItem $appPath -Recurse -File
        $appDlls = Get-ChildItem $appPath -Filter "*.dll" -Recurse
        $appSize = [math]::Round(($appFiles | Measure-Object -Property Length -Sum).Sum/1MB, 2)

        Write-Host "   Application files: $($appFiles.Count)"
        Write-Host "   Application DLLs: $($appDlls.Count)"
        Write-Host "   Application size: $appSize MB"

        $systemDlls = $appDlls | Where-Object { $_.Name -like "System.*.dll" }
        Write-Host "   System DLLs: $($systemDlls.Count)" -ForegroundColor $(if ($systemDlls.Count -gt 50) { "Green" } else { "Red" })

        if ($systemDlls.Count -gt 50) {
            Write-Host "   [OK] Package is SELF-CONTAINED" -ForegroundColor Green
        } else {
            Write-Host "   [WARNING] Package is FRAMEWORK-DEPENDENT" -ForegroundColor Red
        }
    }
}
Write-Host ""
