param(
    [Parameter(Mandatory=$true)]
    [string]$Message,
    [string]$Type = "feat",
    [string]$Scope = ""
)

Write-Host "🚀 RAG Chat Application - Git Commit Automation" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan

# Build check
Write-Host "`n🔨 Building project..." -ForegroundColor Yellow
Set-Location "RagChatApp_Server"
dotnet build
$buildExitCode = $LASTEXITCODE
Set-Location ".."

if ($buildExitCode -ne 0) {
    Write-Error "❌ Build failed. Commit aborted."
    exit 1
}

Write-Host "✅ Build successful!" -ForegroundColor Green

# Git operations
Write-Host "`n📝 Preparing commit..." -ForegroundColor Yellow

# Check if there are changes to commit
$status = git status --porcelain
if (-not $status) {
    Write-Host "⚠️  No changes to commit." -ForegroundColor Yellow
    exit 0
}

git add .

# Build commit message
$commitMessage = if ($Scope) { "$Type($Scope): $Message" } else { "$Type: $Message" }
$fullMessage = @"
$commitMessage

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
"@

Write-Host "📋 Commit message:" -ForegroundColor Cyan
Write-Host $commitMessage -ForegroundColor White

# Commit
git commit -m $fullMessage

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Committed successfully: $commitMessage" -ForegroundColor Green

    # Show commit info
    $commitHash = git rev-parse --short HEAD
    Write-Host "📊 Commit: $commitHash" -ForegroundColor Gray

    # Push if remote exists
    $remotes = git remote
    if ($remotes) {
        Write-Host "`n🚀 Pushing to remote..." -ForegroundColor Yellow
        git push origin main

        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Pushed to remote successfully!" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Push failed. You may need to push manually." -ForegroundColor Yellow
        }
    } else {
        Write-Host "📝 No remote configured. Commit completed locally." -ForegroundColor Gray
    }
} else {
    Write-Error "❌ Commit failed."
    exit 1
}

Write-Host "`n🎉 Git workflow completed!" -ForegroundColor Green