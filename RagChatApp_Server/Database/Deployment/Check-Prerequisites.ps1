# Prerequisites Checker for RagChatApp Deployment
# Run this script on the target server BEFORE deploying

param(
    [switch]$Detailed = $false
)

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "RagChatApp - Prerequisites Checker" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$allChecksPassed = $true

# Function to check prerequisite
function Test-Prerequisite {
    param(
        [string]$Name,
        [scriptblock]$Check,
        [string]$SuccessMessage,
        [string]$FailureMessage,
        [string]$Recommendation,
        [bool]$Required = $true
    )

    Write-Host "Checking: $Name..." -ForegroundColor Yellow -NoNewline

    try {
        $result = & $Check
        if ($result) {
            Write-Host " ✅ OK" -ForegroundColor Green
            if ($Detailed -and $SuccessMessage) {
                Write-Host "  $SuccessMessage" -ForegroundColor Gray
            }
            return $true
        } else {
            if ($Required) {
                Write-Host " ❌ FAILED" -ForegroundColor Red
                Write-Host "  $FailureMessage" -ForegroundColor Red
                if ($Recommendation) {
                    Write-Host "  → $Recommendation" -ForegroundColor Yellow
                }
            } else {
                Write-Host " ⚠️  WARNING" -ForegroundColor Yellow
                Write-Host "  $FailureMessage" -ForegroundColor Yellow
                if ($Recommendation) {
                    Write-Host "  → $Recommendation" -ForegroundColor Gray
                }
            }
            return -not $Required
        }
    }
    catch {
        Write-Host " ❌ ERROR" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

Write-Host "SERVER PREREQUISITES" -ForegroundColor Cyan
Write-Host "-------------------" -ForegroundColor Cyan
Write-Host ""

# Check 1: Windows Server
$check1 = Test-Prerequisite `
    -Name "Windows Operating System" `
    -Check {
        $os = Get-CimInstance Win32_OperatingSystem
        return $os.Caption -match "Windows"
    } `
    -SuccessMessage "OS: $($(Get-CimInstance Win32_OperatingSystem).Caption)" `
    -FailureMessage "Non-Windows OS detected" `
    -Recommendation "RagChatApp requires Windows Server 2016+ or Windows 10+"

$allChecksPassed = $allChecksPassed -and $check1

# Check 2: Administrator Rights
$check2 = Test-Prerequisite `
    -Name "Administrator Privileges" `
    -Check {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } `
    -SuccessMessage "Running as Administrator" `
    -FailureMessage "Not running as Administrator" `
    -Recommendation "Right-click PowerShell and select 'Run as Administrator'"

$allChecksPassed = $allChecksPassed -and $check2

# Check 3: .NET 9.0 Runtime
Write-Host ""
Write-Host ".NET RUNTIME CHECKS" -ForegroundColor Cyan
Write-Host "------------------" -ForegroundColor Cyan
Write-Host ""

$check3 = Test-Prerequisite `
    -Name ".NET 9.0 Runtime (Microsoft.AspNetCore.App)" `
    -Check {
        try {
            $dotnetInfo = & dotnet --list-runtimes 2>&1 | Out-String
            return $dotnetInfo -match "Microsoft\.AspNetCore\.App 9\."
        } catch {
            return $false
        }
    } `
    -SuccessMessage ".NET 9.0 ASP.NET Core Runtime found" `
    -FailureMessage ".NET 9.0 Runtime NOT found (required for framework-dependent deployment)" `
    -Recommendation "Download: https://dotnet.microsoft.com/download/dotnet/9.0 OR use Self-Contained deployment package" `
    -Required $false

if (-not $check3) {
    Write-Host ""
    Write-Host "  IMPORTANT: You have 2 options:" -ForegroundColor Yellow
    Write-Host "    1. Install .NET 9.0 Runtime (recommended)" -ForegroundColor White
    Write-Host "       Download: https://dotnet.microsoft.com/download/dotnet/9.0" -ForegroundColor Gray
    Write-Host "       Select: 'ASP.NET Core Runtime 9.0.x - Windows x64 Installer'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "    2. Use Self-Contained deployment package (includes runtime)" -ForegroundColor White
    Write-Host "       Create with: .\Create-DeploymentPackage.ps1 -SelfContained" -ForegroundColor Gray
    Write-Host ""
}

# Check 4: SQL Server
Write-Host ""
Write-Host "DATABASE PREREQUISITES" -ForegroundColor Cyan
Write-Host "---------------------" -ForegroundColor Cyan
Write-Host ""

$check4 = Test-Prerequisite `
    -Name "SQL Server Availability" `
    -Check {
        try {
            $sqlServices = Get-Service | Where-Object {$_.Name -like "MSSQL*" -and $_.Status -eq "Running"}
            return $null -ne $sqlServices
        } catch {
            return $false
        }
    } `
    -SuccessMessage "SQL Server service(s) running" `
    -FailureMessage "SQL Server not found or not running" `
    -Recommendation "Install SQL Server 2019+ or SQL Server Express"

$allChecksPassed = $allChecksPassed -and $check4

if ($check4) {
    # Try to get SQL Server version
    try {
        $sqlcmdPath = (Get-Command sqlcmd -ErrorAction SilentlyContinue).Source
        if ($sqlcmdPath) {
            Write-Host "  Testing SQL Server connection..." -ForegroundColor Gray
            $version = sqlcmd -S "localhost" -Q "SELECT @@VERSION" -h -1 2>&1 | Out-String
            if ($version -match "Microsoft SQL Server (\d+)") {
                $majorVersion = [int]$Matches[1]
                if ($majorVersion -ge 15) {
                    Write-Host "  ✅ SQL Server $majorVersion (compatible)" -ForegroundColor Green
                } else {
                    Write-Host "  ⚠️  SQL Server $majorVersion (minimum 2019/version 15 recommended)" -ForegroundColor Yellow
                }
            }
        }
    } catch {
        Write-Host "  ⚠️  Could not determine SQL Server version" -ForegroundColor Yellow
    }
}

# Check 5: Disk Space
Write-Host ""
Write-Host "SYSTEM RESOURCES" -ForegroundColor Cyan
Write-Host "----------------" -ForegroundColor Cyan
Write-Host ""

$check5 = Test-Prerequisite `
    -Name "Disk Space (C: drive)" `
    -Check {
        $drive = Get-PSDrive C
        $freeSpaceGB = [math]::Round($drive.Free / 1GB, 2)
        if ($Detailed) {
            Write-Host "  Free space: $freeSpaceGB GB" -ForegroundColor Gray
        }
        return $freeSpaceGB -gt 2
    } `
    -SuccessMessage "Sufficient disk space available" `
    -FailureMessage "Less than 2GB free space on C: drive" `
    -Recommendation "Free up disk space (minimum 2GB recommended)"

$allChecksPassed = $allChecksPassed -and $check5

# Check 6: RAM
$check6 = Test-Prerequisite `
    -Name "Available Memory" `
    -Check {
        $totalRAM = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
        if ($Detailed) {
            Write-Host "  Total RAM: $totalRAM GB" -ForegroundColor Gray
        }
        return $totalRAM -gt 2
    } `
    -SuccessMessage "Sufficient memory available" `
    -FailureMessage "Less than 2GB RAM" `
    -Recommendation "Minimum 4GB RAM recommended for production" `
    -Required $false

# Check 7: PowerShell Version
Write-Host ""
Write-Host "TOOLS & UTILITIES" -ForegroundColor Cyan
Write-Host "-----------------" -ForegroundColor Cyan
Write-Host ""

$check7 = Test-Prerequisite `
    -Name "PowerShell Version" `
    -Check {
        $version = $PSVersionTable.PSVersion.Major
        if ($Detailed) {
            Write-Host "  Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
        }
        return $version -ge 5
    } `
    -SuccessMessage "PowerShell 5.0+ found" `
    -FailureMessage "PowerShell version too old" `
    -Recommendation "Update to PowerShell 5.1 or PowerShell 7+"

$allChecksPassed = $allChecksPassed -and $check7

# Check 8: SqlCmd
$check8 = Test-Prerequisite `
    -Name "SQL Command Line Tools (sqlcmd)" `
    -Check {
        return $null -ne (Get-Command sqlcmd -ErrorAction SilentlyContinue)
    } `
    -SuccessMessage "sqlcmd available" `
    -FailureMessage "sqlcmd not found" `
    -Recommendation "Usually installed with SQL Server, or install SQL Server Command Line Utilities" `
    -Required $false

# Check 9: Firewall (optional)
$check9 = Test-Prerequisite `
    -Name "Windows Firewall Status" `
    -Check {
        try {
            $firewallProfile = Get-NetFirewallProfile -Profile Domain,Public,Private -ErrorAction Stop
            $enabled = $firewallProfile | Where-Object {$_.Enabled -eq $true}
            if ($enabled) {
                Write-Host "  Note: Firewall is enabled, you may need to open ports 5000/5001" -ForegroundColor Gray
            }
            return $true
        } catch {
            return $true  # If we can't check, assume it's fine
        }
    } `
    -SuccessMessage "Firewall configuration noted" `
    -FailureMessage "" `
    -Recommendation "" `
    -Required $false

# Summary
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

if ($allChecksPassed) {
    Write-Host "✅ All required prerequisites met!" -ForegroundColor Green
    Write-Host ""
    Write-Host "You are ready to deploy RagChatApp." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Extract deployment package" -ForegroundColor White
    Write-Host "  2. Read QUICK_START_DEPLOYMENT.md" -ForegroundColor White
    Write-Host "  3. Follow installation steps" -ForegroundColor White
} else {
    Write-Host "❌ Some prerequisites are missing!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please address the issues above before deploying." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "For detailed help, run:" -ForegroundColor Yellow
    Write-Host "  .\Check-Prerequisites.ps1 -Detailed" -ForegroundColor White
}

Write-Host ""

# Return exit code
if ($allChecksPassed) {
    exit 0
} else {
    exit 1
}
