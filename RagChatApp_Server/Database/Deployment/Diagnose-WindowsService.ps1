# Windows Service Diagnostic Tool
param(
    [string]$ServiceName = "RagChatAppService",
    [string]$ApplicationPath = "C:\OSLAI-2025\OSL_RagChatApp\Application"
)

Write-Host "=== Windows Service Diagnostic ===" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: This script must run as Administrator" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

Write-Host "Service Name: $ServiceName" -ForegroundColor Yellow
Write-Host "Application Path: $ApplicationPath" -ForegroundColor Yellow
Write-Host ""

# Check 1: Service exists?
Write-Host "1. Checking if service exists..." -ForegroundColor Cyan
$service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

if ($service) {
    Write-Host "   Service found!" -ForegroundColor Green
    Write-Host "   Status: $($service.Status)" -ForegroundColor White
    Write-Host "   StartType: $($service.StartType)" -ForegroundColor White
    Write-Host "   DisplayName: $($service.DisplayName)" -ForegroundColor White
} else {
    Write-Host "   Service NOT found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "   Create service with:" -ForegroundColor Yellow
    Write-Host "   .\Install-WindowsService.ps1 -ApplicationPath `"$ApplicationPath`"" -ForegroundColor Gray
    exit 1
}
Write-Host ""

# Check 2: Application exists?
Write-Host "2. Checking application files..." -ForegroundColor Cyan
$exePath = Join-Path $ApplicationPath "RagChatApp_Server.exe"
$dllPath = Join-Path $ApplicationPath "RagChatApp_Server.dll"

if (Test-Path $exePath) {
    Write-Host "   EXE found: $exePath" -ForegroundColor Green
} else {
    Write-Host "   ERROR: EXE not found: $exePath" -ForegroundColor Red
}

if (Test-Path $dllPath) {
    Write-Host "   DLL found: $dllPath" -ForegroundColor Green
} else {
    Write-Host "   ERROR: DLL not found: $dllPath" -ForegroundColor Red
}

$appSettingsPath = Join-Path $ApplicationPath "appsettings.json"
if (Test-Path $appSettingsPath) {
    Write-Host "   Config found: appsettings.json" -ForegroundColor Green
} else {
    Write-Host "   WARNING: appsettings.json not found!" -ForegroundColor Yellow
}
Write-Host ""

# Check 3: Recent Event Log errors
Write-Host "3. Checking recent Event Log errors..." -ForegroundColor Cyan
try {
    $events = Get-EventLog -LogName Application -Source $ServiceName -Newest 5 -ErrorAction SilentlyContinue
    if ($events) {
        Write-Host "   Found recent events:" -ForegroundColor Yellow
        foreach ($event in $events) {
            $color = switch ($event.EntryType) {
                "Error" { "Red" }
                "Warning" { "Yellow" }
                default { "Gray" }
            }
            Write-Host "   [$($event.TimeGenerated)] $($event.EntryType): $($event.Message.Substring(0, [Math]::Min(100, $event.Message.Length)))..." -ForegroundColor $color
        }
    } else {
        Write-Host "   No recent events found" -ForegroundColor Gray
    }
} catch {
    Write-Host "   Could not read Event Log (service may not have started yet)" -ForegroundColor Gray
}
Write-Host ""

# Check 4: Service timeout configuration
Write-Host "4. Checking service timeout..." -ForegroundColor Cyan
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Control"
$timeout = Get-ItemProperty -Path $regPath -Name "ServicesPipeTimeout" -ErrorAction SilentlyContinue

if ($timeout) {
    $timeoutMs = $timeout.ServicesPipeTimeout
    $timeoutSec = $timeoutMs / 1000
    Write-Host "   Current timeout: $timeoutSec seconds" -ForegroundColor White
} else {
    Write-Host "   Using default timeout: 30 seconds" -ForegroundColor White
}
Write-Host ""

# Check 5: Can app start manually?
Write-Host "5. Testing manual start..." -ForegroundColor Cyan
Write-Host "   Attempting to start application manually (will timeout after 5 seconds)..." -ForegroundColor Gray

$testJob = Start-Job -ScriptBlock {
    param($exePath)
    Set-Location (Split-Path $exePath)
    & $exePath 2>&1
} -ArgumentList $exePath

$completed = Wait-Job $testJob -Timeout 5
if ($completed) {
    $output = Receive-Job $testJob
    Write-Host "   App output:" -ForegroundColor Yellow
    $output | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
} else {
    Write-Host "   App started (still running after 5 seconds - GOOD sign)" -ForegroundColor Green
    Write-Host "   Stopping test..." -ForegroundColor Gray
}

Stop-Job $testJob -ErrorAction SilentlyContinue
Remove-Job $testJob -ErrorAction SilentlyContinue

# Try to stop any lingering processes
Get-Process -Name "RagChatApp_Server" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Host ""

# Recommendations
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Diagnostic Summary & Solutions" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

if ($service.Status -eq "Running") {
    Write-Host "SUCCESS: Service is running!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Test endpoints:" -ForegroundColor Cyan
    Write-Host "  Invoke-RestMethod http://localhost:5000/health" -ForegroundColor Gray
    Write-Host "  Invoke-RestMethod http://localhost:8080/health" -ForegroundColor Gray

} else {
    Write-Host "Service is not running. Common causes:" -ForegroundColor Yellow
    Write-Host ""

    Write-Host "1. Missing Windows Service configuration in code" -ForegroundColor Cyan
    Write-Host "   Solution: Rebuild app with .UseWindowsService()" -ForegroundColor White
    Write-Host "   The app needs to be recompiled with Windows Service support" -ForegroundColor Gray
    Write-Host ""

    Write-Host "2. Database connection timeout" -ForegroundColor Cyan
    Write-Host "   Solution: Check connection string in appsettings.json" -ForegroundColor White
    Write-Host "   Test: sqlcmd -S YourServer -d RagChatAppDB -Q `"SELECT 1`"" -ForegroundColor Gray
    Write-Host ""

    Write-Host "3. Service timeout too short" -ForegroundColor Cyan
    Write-Host "   Solution: Increase service timeout to 120 seconds" -ForegroundColor White
    Write-Host "   Run: reg add HKLM\SYSTEM\CurrentControlSet\Control /v ServicesPipeTimeout /t REG_DWORD /d 120000 /f" -ForegroundColor Gray
    Write-Host "   Then restart computer" -ForegroundColor Gray
    Write-Host ""

    Write-Host "4. Configuration errors (JSON, ports, etc)" -ForegroundColor Cyan
    Write-Host "   Solution: Validate appsettings.json" -ForegroundColor White
    Write-Host "   Run: .\Validate-AppSettings.ps1 -FilePath `"$appSettingsPath`"" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "For detailed service errors, check Event Viewer:" -ForegroundColor Yellow
Write-Host "  eventvwr.msc -> Windows Logs -> Application" -ForegroundColor Gray
Write-Host "  Filter by Source: $ServiceName" -ForegroundColor Gray
Write-Host ""
