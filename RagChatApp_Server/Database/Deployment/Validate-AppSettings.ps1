# Script to validate and fix appsettings.json
param(
    [Parameter(Mandatory=$false)]
    [string]$FilePath = "C:\OSLAI-2025\OSL_RagChatApp\Application\appsettings.json"
)

Write-Host "=== AppSettings.json Validator ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $FilePath)) {
    Write-Host "ERROR: File not found: $FilePath" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please specify the correct path:" -ForegroundColor Yellow
    Write-Host "  .\Validate-AppSettings.ps1 -FilePath 'C:\Path\To\appsettings.json'" -ForegroundColor White
    exit 1
}

Write-Host "File: $FilePath" -ForegroundColor Yellow
Write-Host ""

# Read file
$content = Get-Content $FilePath -Raw

# Try to parse JSON
Write-Host "Validating JSON syntax..." -ForegroundColor Cyan
try {
    $json = $content | ConvertFrom-Json -ErrorAction Stop
    Write-Host "SUCCESS: JSON is valid!" -ForegroundColor Green
    Write-Host ""

    # Show structure
    Write-Host "Configuration structure:" -ForegroundColor Yellow
    Write-Host "  - ConnectionStrings: $(if ($json.ConnectionStrings) { 'Present' } else { 'MISSING' })" -ForegroundColor $(if ($json.ConnectionStrings) { 'Green' } else { 'Red' })
    Write-Host "  - AIProvider: $(if ($json.AIProvider) { 'Present' } else { 'MISSING' })" -ForegroundColor $(if ($json.AIProvider) { 'Green' } else { 'Red' })
    Write-Host "  - Logging: $(if ($json.Logging) { 'Present' } else { 'MISSING' })" -ForegroundColor $(if ($json.Logging) { 'Green' } else { 'Red' })

    if ($json.AIProvider) {
        Write-Host ""
        Write-Host "  AI Provider details:" -ForegroundColor Yellow
        Write-Host "    - DefaultProvider: $($json.AIProvider.DefaultProvider)"
        if ($json.AIProvider.Gemini -and $json.AIProvider.Gemini.ApiKey) {
            $keyPreview = $json.AIProvider.Gemini.ApiKey.Substring(0, [Math]::Min(10, $json.AIProvider.Gemini.ApiKey.Length)) + "..."
            Write-Host "    - Gemini ApiKey: $keyPreview" -ForegroundColor Gray
        }
        if ($json.AIProvider.OpenAI -and $json.AIProvider.OpenAI.ApiKey) {
            $keyPreview = $json.AIProvider.OpenAI.ApiKey.Substring(0, [Math]::Min(10, $json.AIProvider.OpenAI.ApiKey.Length)) + "..."
            Write-Host "    - OpenAI ApiKey: $keyPreview" -ForegroundColor Gray
        }
    }

} catch {
    Write-Host "ERROR: Invalid JSON!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Error details:" -ForegroundColor Yellow
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""

    # Try to identify the line
    if ($_.Exception.Message -match "line (\d+)") {
        $errorLine = [int]$Matches[1]
        Write-Host "Problem around line: $errorLine" -ForegroundColor Yellow
        Write-Host ""

        # Show context
        $lines = $content -split "`n"
        $start = [Math]::Max(0, $errorLine - 3)
        $end = [Math]::Min($lines.Count - 1, $errorLine + 2)

        Write-Host "Context:" -ForegroundColor Cyan
        for ($i = $start; $i -le $end; $i++) {
            $lineNum = $i + 1
            $prefix = if ($lineNum -eq $errorLine) { ">>> " } else { "    " }
            $color = if ($lineNum -eq $errorLine) { "Red" } else { "Gray" }
            Write-Host "$prefix$($lineNum): $($lines[$i])" -ForegroundColor $color
        }
    }

    Write-Host ""
    Write-Host "Common JSON errors:" -ForegroundColor Yellow
    Write-Host "  1. Missing comma between properties" -ForegroundColor White
    Write-Host "  2. Extra comma after last property" -ForegroundColor White
    Write-Host "  3. Unescaped backslashes in strings (use \\)" -ForegroundColor White
    Write-Host "  4. Single quotes instead of double quotes" -ForegroundColor White
    Write-Host "  5. Comments (not allowed in JSON)" -ForegroundColor White

    Write-Host ""
    Write-Host "Would you like to create a backup and use a template? (Y/N)" -ForegroundColor Yellow
    $response = Read-Host

    if ($response -eq 'Y' -or $response -eq 'y') {
        # Backup
        $backup = $FilePath + ".backup." + (Get-Date -Format "yyyyMMdd_HHmmss")
        Copy-Item $FilePath $backup
        Write-Host "Backup created: $backup" -ForegroundColor Green

        Write-Host ""
        Write-Host "You can now edit the file manually or copy a correct template." -ForegroundColor Yellow
        Write-Host "See: OFFLINE_DEPLOYMENT_GUIDE.md for correct appsettings.json example" -ForegroundColor Cyan
    }

    exit 1
}
