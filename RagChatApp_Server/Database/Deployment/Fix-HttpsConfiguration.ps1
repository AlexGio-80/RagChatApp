# Fix HTTPS Configuration
# This script helps configure or disable HTTPS for production deployment

param(
    [Parameter(Mandatory=$true)]
    [string]$AppSettingsPath,

    [ValidateSet("DisableHttps", "GenerateDevCert", "ShowInfo")]
    [string]$Action = "ShowInfo"
)

Write-Host "=== HTTPS Configuration Helper ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $AppSettingsPath)) {
    Write-Host "ERROR: File not found: $AppSettingsPath" -ForegroundColor Red
    exit 1
}

Write-Host "File: $AppSettingsPath" -ForegroundColor Yellow
Write-Host ""

switch ($Action) {
    "DisableHttps" {
        Write-Host "Disabling HTTPS endpoint..." -ForegroundColor Cyan
        Write-Host ""

        # Read current config
        $content = Get-Content $AppSettingsPath -Raw
        $json = $content | ConvertFrom-Json

        # Remove HTTPS endpoint
        if ($json.Kestrel -and $json.Kestrel.Endpoints -and $json.Kestrel.Endpoints.Https) {
            $json.Kestrel.Endpoints.PSObject.Properties.Remove('Https')

            # Save
            $backup = $AppSettingsPath + ".backup." + (Get-Date -Format "yyyyMMdd_HHmmss")
            Copy-Item $AppSettingsPath $backup
            Write-Host "Backup created: $backup" -ForegroundColor Green

            $json | ConvertTo-Json -Depth 10 | Set-Content $AppSettingsPath

            Write-Host "SUCCESS: HTTPS endpoint disabled!" -ForegroundColor Green
            Write-Host ""
            Write-Host "Application will now listen only on HTTP:" -ForegroundColor Yellow
            Write-Host "  - http://localhost:5000" -ForegroundColor White
            Write-Host ""
            Write-Host "Try starting the application again:" -ForegroundColor Cyan
            Write-Host "  cd `"$(Split-Path $AppSettingsPath)`"" -ForegroundColor Gray
            Write-Host "  .\RagChatApp_Server.exe" -ForegroundColor Gray
        } else {
            Write-Host "HTTPS endpoint is already disabled or not configured" -ForegroundColor Yellow
        }
    }

    "GenerateDevCert" {
        Write-Host "Generating development HTTPS certificate..." -ForegroundColor Cyan
        Write-Host ""
        Write-Host "WARNING: This requires .NET SDK (not just runtime)" -ForegroundColor Yellow
        Write-Host "If you're on a production server without SDK, use -Action DisableHttps instead" -ForegroundColor Yellow
        Write-Host ""

        $response = Read-Host "Continue? (Y/N)"
        if ($response -ne 'Y' -and $response -ne 'y') {
            Write-Host "Cancelled" -ForegroundColor Yellow
            exit 0
        }

        # Check if dotnet is available
        $dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
        if (-not $dotnet) {
            Write-Host "ERROR: dotnet command not found" -ForegroundColor Red
            Write-Host "Install .NET SDK or use -Action DisableHttps" -ForegroundColor Yellow
            exit 1
        }

        Write-Host "Generating certificate..." -ForegroundColor Cyan
        & dotnet dev-certs https --clean
        & dotnet dev-certs https --trust

        if ($LASTEXITCODE -eq 0) {
            Write-Host "SUCCESS: Certificate generated and trusted!" -ForegroundColor Green
            Write-Host ""
            Write-Host "Try starting the application again" -ForegroundColor Cyan
        } else {
            Write-Host "ERROR: Certificate generation failed" -ForegroundColor Red
            Write-Host "Consider using -Action DisableHttps instead" -ForegroundColor Yellow
        }
    }

    "ShowInfo" {
        Write-Host "Current HTTPS Configuration:" -ForegroundColor Cyan
        Write-Host ""

        $content = Get-Content $AppSettingsPath -Raw
        $json = $content | ConvertFrom-Json

        if ($json.Kestrel -and $json.Kestrel.Endpoints) {
            if ($json.Kestrel.Endpoints.Http) {
                Write-Host "  HTTP:  $($json.Kestrel.Endpoints.Http.Url)" -ForegroundColor Green
            }
            if ($json.Kestrel.Endpoints.Https) {
                Write-Host "  HTTPS: $($json.Kestrel.Endpoints.Https.Url)" -ForegroundColor Yellow
                Write-Host "         (Certificate required!)" -ForegroundColor Yellow
            } else {
                Write-Host "  HTTPS: Not configured" -ForegroundColor Gray
            }
        } else {
            Write-Host "  No Kestrel configuration found" -ForegroundColor Red
        }

        Write-Host ""
        Write-Host "Available Actions:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "1. Disable HTTPS (Recommended for internal networks):" -ForegroundColor Yellow
        Write-Host "   .\Fix-HttpsConfiguration.ps1 -AppSettingsPath `"$AppSettingsPath`" -Action DisableHttps" -ForegroundColor White
        Write-Host ""
        Write-Host "2. Generate Development Certificate (Requires .NET SDK):" -ForegroundColor Yellow
        Write-Host "   .\Fix-HttpsConfiguration.ps1 -AppSettingsPath `"$AppSettingsPath`" -Action GenerateDevCert" -ForegroundColor White
        Write-Host ""
        Write-Host "3. Use Production SSL Certificate:" -ForegroundColor Yellow
        Write-Host "   See documentation for configuring production certificates" -ForegroundColor Gray
        Write-Host ""
    }
}
