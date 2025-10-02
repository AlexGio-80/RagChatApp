# Install RAG Chat App as Windows Service
# This script installs the application as a Windows Service with automatic startup

param(
    [Parameter(Mandatory=$false)]
    [string]$ServiceName = "RagChatAppService",

    [Parameter(Mandatory=$false)]
    [string]$DisplayName = "RAG Chat Application Service",

    [Parameter(Mandatory=$false)]
    [string]$Description = "RAG Chat Application - AI-powered document search and chat service",

    [Parameter(Mandatory=$false)]
    [string]$ApplicationPath = "C:\Program Files\RagChatApp",

    [Parameter(Mandatory=$false)]
    [string]$ServiceAccount = "NT AUTHORITY\NetworkService",

    [Parameter(Mandatory=$false)]
    [ValidateSet("Auto", "Manual", "Disabled")]
    [string]$StartupType = "Auto",

    [switch]$UseNSSM,
    [switch]$Uninstall
)

# Require Administrator privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: This script requires Administrator privileges" -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again" -ForegroundColor Yellow
    exit 1
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "RAG Chat App - Windows Service Installer" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Handle uninstall
if ($Uninstall) {
    Write-Host "Uninstalling service: $ServiceName" -ForegroundColor Yellow

    # Check if service exists
    $existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

    if ($existingService) {
        # Stop service if running
        if ($existingService.Status -eq 'Running') {
            Write-Host "Stopping service..." -ForegroundColor Yellow
            Stop-Service -Name $ServiceName -Force
            Start-Sleep -Seconds 2
        }

        # Remove service
        if ($UseNSSM -and (Test-Path ".\nssm.exe")) {
            Write-Host "Removing service using NSSM..." -ForegroundColor Yellow
            & .\nssm.exe remove $ServiceName confirm
        } else {
            Write-Host "Removing service using sc.exe..." -ForegroundColor Yellow
            sc.exe delete $ServiceName
        }

        Write-Host "Service uninstalled successfully!" -ForegroundColor Green
    } else {
        Write-Host "Service not found: $ServiceName" -ForegroundColor Yellow
    }

    exit 0
}

# Verify application path exists
$exePath = Join-Path $ApplicationPath "RagChatApp_Server.exe"
if (-not (Test-Path $exePath)) {
    Write-Host "ERROR: Application not found at: $exePath" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please ensure the application is deployed to: $ApplicationPath" -ForegroundColor Yellow
    Write-Host "Or specify the correct path using -ApplicationPath parameter" -ForegroundColor Yellow
    exit 1
}

Write-Host "Application found: $exePath" -ForegroundColor Green
Write-Host ""

# Check if service already exists
$existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existingService) {
    Write-Host "WARNING: Service already exists!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Current status:" -ForegroundColor Yellow
    Write-Host "  Name:        $($existingService.Name)" -ForegroundColor White
    Write-Host "  DisplayName: $($existingService.DisplayName)" -ForegroundColor White
    Write-Host "  Status:      $($existingService.Status)" -ForegroundColor White
    Write-Host "  StartType:   $($existingService.StartType)" -ForegroundColor White
    Write-Host ""

    $response = Read-Host "Do you want to remove and reinstall? (y/n)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "Installation cancelled" -ForegroundColor Yellow
        exit 0
    }

    # Stop and remove existing service
    if ($existingService.Status -eq 'Running') {
        Write-Host "Stopping existing service..." -ForegroundColor Yellow
        Stop-Service -Name $ServiceName -Force
        Start-Sleep -Seconds 2
    }

    Write-Host "Removing existing service..." -ForegroundColor Yellow
    sc.exe delete $ServiceName
    Start-Sleep -Seconds 2
}

# Install service based on method
if ($UseNSSM) {
    # Check if NSSM is available
    $nssmPath = ".\nssm.exe"
    if (-not (Test-Path $nssmPath)) {
        Write-Host "ERROR: NSSM not found at: $nssmPath" -ForegroundColor Red
        Write-Host ""
        Write-Host "Options:" -ForegroundColor Yellow
        Write-Host "  1. Download NSSM from https://nssm.cc/download" -ForegroundColor White
        Write-Host "  2. Extract nssm.exe to the same directory as this script" -ForegroundColor White
        Write-Host "  3. Or run without -UseNSSM to use sc.exe instead" -ForegroundColor White
        exit 1
    }

    Write-Host "Installing service using NSSM..." -ForegroundColor Cyan
    Write-Host ""

    # Install with NSSM
    & $nssmPath install $ServiceName $exePath
    & $nssmPath set $ServiceName AppDirectory $ApplicationPath
    & $nssmPath set $ServiceName DisplayName $DisplayName
    & $nssmPath set $ServiceName Description $Description
    & $nssmPath set $ServiceName Start SERVICE_AUTO_START
    & $nssmPath set $ServiceName AppExit Default Restart

    # Setup logging
    $logPath = Join-Path $ApplicationPath "logs"
    if (-not (Test-Path $logPath)) {
        New-Item -ItemType Directory -Path $logPath -Force | Out-Null
    }

    & $nssmPath set $ServiceName AppStdout (Join-Path $logPath "service-output.log")
    & $nssmPath set $ServiceName AppStderr (Join-Path $logPath "service-error.log")
    & $nssmPath set $ServiceName AppRotateFiles 1
    & $nssmPath set $ServiceName AppRotateOnline 1
    & $nssmPath set $ServiceName AppRotateBytes 1048576  # 1MB

    Write-Host "Service installed successfully using NSSM!" -ForegroundColor Green

} else {
    Write-Host "Installing service using sc.exe..." -ForegroundColor Cyan
    Write-Host ""

    # Map startup type for sc.exe
    $scStartType = switch ($StartupType) {
        "Auto" { "auto" }
        "Manual" { "demand" }
        "Disabled" { "disabled" }
    }

    # Install with sc.exe
    sc.exe create $ServiceName `
        binPath= "`"$exePath`"" `
        DisplayName= $DisplayName `
        start= $scStartType `
        obj= $ServiceAccount

    # Set description
    sc.exe description $ServiceName $Description

    # Set failure recovery (restart on failure)
    sc.exe failure $ServiceName reset= 86400 actions= restart/60000/restart/60000/restart/60000

    Write-Host "Service installed successfully using sc.exe!" -ForegroundColor Green
}

Write-Host ""

# Verify installation
$service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($service) {
    Write-Host "Service verification:" -ForegroundColor Green
    Write-Host "  Name:        $($service.Name)" -ForegroundColor White
    Write-Host "  DisplayName: $($service.DisplayName)" -ForegroundColor White
    Write-Host "  Status:      $($service.Status)" -ForegroundColor White
    Write-Host "  StartType:   $($service.StartType)" -ForegroundColor White
    Write-Host ""

    # Start service
    Write-Host "Starting service..." -ForegroundColor Cyan
    try {
        Start-Service -Name $ServiceName
        Start-Sleep -Seconds 3

        $service = Get-Service -Name $ServiceName
        if ($service.Status -eq 'Running') {
            Write-Host "SUCCESS: Service started successfully!" -ForegroundColor Green
        } else {
            Write-Host "WARNING: Service started but status is: $($service.Status)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "ERROR: Failed to start service" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "Check Event Viewer for details:" -ForegroundColor Yellow
        Write-Host "  eventvwr.msc -> Windows Logs -> Application" -ForegroundColor White
    }

} else {
    Write-Host "ERROR: Service installation verification failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Service Management Commands:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Start service:" -ForegroundColor Cyan
Write-Host "    Start-Service $ServiceName" -ForegroundColor White
Write-Host ""
Write-Host "  Stop service:" -ForegroundColor Cyan
Write-Host "    Stop-Service $ServiceName" -ForegroundColor White
Write-Host ""
Write-Host "  Restart service:" -ForegroundColor Cyan
Write-Host "    Restart-Service $ServiceName" -ForegroundColor White
Write-Host ""
Write-Host "  Check status:" -ForegroundColor Cyan
Write-Host "    Get-Service $ServiceName" -ForegroundColor White
Write-Host ""
Write-Host "  View logs (if using NSSM):" -ForegroundColor Cyan
Write-Host "    Get-Content '$ApplicationPath\logs\service-output.log' -Tail 50" -ForegroundColor White
Write-Host ""
Write-Host "  Uninstall service:" -ForegroundColor Cyan
Write-Host "    .\Install-WindowsService.ps1 -Uninstall" -ForegroundColor White
Write-Host ""

# Test endpoints
Write-Host "Testing API endpoints..." -ForegroundColor Cyan
Start-Sleep -Seconds 2

try {
    $healthResponse = Invoke-RestMethod -Uri "http://localhost:5000/health" -TimeoutSec 5 -ErrorAction Stop
    Write-Host "  Health endpoint: OK" -ForegroundColor Green

    $infoResponse = Invoke-RestMethod -Uri "http://localhost:5000/api/info" -TimeoutSec 5 -ErrorAction Stop
    Write-Host "  Info endpoint: OK (Version: $($infoResponse.version))" -ForegroundColor Green

} catch {
    Write-Host "  WARNING: Could not reach API endpoints" -ForegroundColor Yellow
    Write-Host "  This might be normal if the service is still starting..." -ForegroundColor Yellow
    Write-Host "  Wait 10-15 seconds and test manually:" -ForegroundColor Yellow
    Write-Host "    Invoke-RestMethod -Uri 'http://localhost:5000/health'" -ForegroundColor White
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Test API: http://localhost:5000/health" -ForegroundColor White
Write-Host "  2. Access Swagger: http://localhost:5000/swagger" -ForegroundColor White
Write-Host "  3. Configure firewall if remote access needed" -ForegroundColor White
Write-Host "  4. Setup SSL certificate for production" -ForegroundColor White
Write-Host ""
