# Fix Port Conflict - Diagnose and resolve port binding issues
param(
    [int]$Port = 5000
)

Write-Host "=== Port Conflict Resolver ===" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "WARNING: Not running as Administrator" -ForegroundColor Yellow
    Write-Host "Some checks may require admin privileges" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "Checking port $Port..." -ForegroundColor Cyan
Write-Host ""

# Check 1: Is port in use?
Write-Host "1. Checking if port is in use..." -ForegroundColor Yellow
$connections = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue

if ($connections) {
    Write-Host "   Port $Port is IN USE!" -ForegroundColor Red
    Write-Host ""
    foreach ($conn in $connections) {
        $process = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
        Write-Host "   Process: $($process.ProcessName) (PID: $($conn.OwningProcess))" -ForegroundColor White
        Write-Host "   State: $($conn.State)" -ForegroundColor Gray
        Write-Host "   Path: $($process.Path)" -ForegroundColor Gray
        Write-Host ""
    }

    Write-Host "   Options:" -ForegroundColor Yellow
    Write-Host "   A) Stop the process using this port" -ForegroundColor White
    Write-Host "   B) Use a different port for RagChatApp" -ForegroundColor White
    Write-Host ""

} else {
    Write-Host "   Port $Port is FREE" -ForegroundColor Green
    Write-Host ""
}

# Check 2: Windows reserved ports
Write-Host "2. Checking Windows reserved ports..." -ForegroundColor Yellow
$reservedPorts = netsh interface ipv4 show excludedportrange protocol=tcp | Out-String

if ($reservedPorts -match "$Port\s+-") {
    Write-Host "   WARNING: Port $Port is in Windows reserved range!" -ForegroundColor Red
    Write-Host "   This happens with Hyper-V or Windows Containers" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   Solution: Use a different port" -ForegroundColor Cyan
    Write-Host ""
} else {
    Write-Host "   Port $Port is NOT reserved by Windows" -ForegroundColor Green
    Write-Host ""
}

# Check 3: Firewall
Write-Host "3. Checking Windows Firewall..." -ForegroundColor Yellow
$firewallRule = Get-NetFirewallRule | Where-Object {
    $_.DisplayName -like "*$Port*" -or $_.DisplayName -like "*RagChat*"
} -ErrorAction SilentlyContinue

if ($firewallRule) {
    Write-Host "   Found firewall rule(s) for port $Port or RagChatApp" -ForegroundColor Green
    $firewallRule | ForEach-Object {
        Write-Host "   - $($_.DisplayName): $($_.Enabled)" -ForegroundColor Gray
    }
} else {
    Write-Host "   No specific firewall rule found" -ForegroundColor Yellow
    Write-Host "   You may need to create one after choosing a port" -ForegroundColor Gray
}
Write-Host ""

# Suggest alternative ports
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Recommended Solutions" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Option 1: Use Alternative Port (Easiest)" -ForegroundColor Green
Write-Host ""
Write-Host "  Recommended ports: 8080, 8081, 8082, 9000, 9090" -ForegroundColor White
Write-Host ""
Write-Host "  To change port, edit appsettings.json:" -ForegroundColor Cyan
Write-Host '  "Kestrel": {' -ForegroundColor Gray
Write-Host '    "Endpoints": {' -ForegroundColor Gray
Write-Host '      "Http": {' -ForegroundColor Gray
Write-Host '        "Url": "http://0.0.0.0:8080"  <- Change 5000 to 8080' -ForegroundColor Yellow
Write-Host '      }' -ForegroundColor Gray
Write-Host '    }' -ForegroundColor Gray
Write-Host '  }' -ForegroundColor Gray
Write-Host ""

if ($connections) {
    Write-Host "Option 2: Stop Process Using Port $Port" -ForegroundColor Yellow
    Write-Host ""
    foreach ($conn in $connections) {
        $process = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
        Write-Host "  Stop-Process -Id $($conn.OwningProcess) -Force  # $($process.ProcessName)" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "  WARNING: Only stop processes you know are safe to stop!" -ForegroundColor Red
    Write-Host ""
}

Write-Host "Option 3: Check Available Ports" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Testing common alternative ports..." -ForegroundColor Cyan
$testPorts = @(8080, 8081, 8082, 9000, 9090, 7000, 7001)
$availablePorts = @()

foreach ($testPort in $testPorts) {
    $inUse = Get-NetTCPConnection -LocalPort $testPort -ErrorAction SilentlyContinue
    if (-not $inUse) {
        $availablePorts += $testPort
        Write-Host "  Port $testPort : AVAILABLE" -ForegroundColor Green
    } else {
        Write-Host "  Port $testPort : In use" -ForegroundColor Gray
    }
}

if ($availablePorts.Count -gt 0) {
    Write-Host ""
    Write-Host "  Suggested: Use port $($availablePorts[0])" -ForegroundColor Green
}

Write-Host ""
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""
