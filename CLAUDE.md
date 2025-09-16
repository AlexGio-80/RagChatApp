# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RagChatApp - A RAG (Retrieval-Augmented Generation) chat application that allows users to upload documents and chat with AI using the content as context. The system uses Azure OpenAI for embeddings and chat completions, with SQL Server for vector storage.

## Architecture

- **RagChatApp_Server** (.NET 9.0): Backend API with document management and chat AI functionality
- **RagChatApp_UI** (HTML/CSS/JS): Frontend for document management and chat interface

### Key Technologies
- .NET 9.0 with Entity Framework Core
- SQL Server with vector support (VARBINARY for embeddings)
- Azure OpenAI integration
- Responsive frontend with glassmorphism design

### Core Features
- Document upload and processing (.txt, .pdf, .doc, .docx)
- Intelligent chunking based on markdown headers
- Vector similarity search
- RAG-based chat with source attribution
- Mock service mode for development

## Development Commands

### 🚀 Running the Application

**Backend Server (RagChatApp_Server)**:
```bash
cd RagChatApp_Server
dotnet restore              # Restore NuGet packages
dotnet build                # Build the project
dotnet run                  # Run the server (includes auto-database migration)
```
- **Default URL**: `https://localhost:7297`
- **Swagger UI**: `https://localhost:7297/swagger`
- **Health Check**: `https://localhost:7297/health`

**Frontend (RagChatApp_UI)**:
```bash
cd RagChatApp_UI

# Option 1: Using npm (recommended for development)
npm install      # Install development server dependencies
npm start        # Start development server on http://localhost:3000

# Option 2: Direct file access
# Open index.html directly in browser (limited functionality due to CORS)

# Option 3: Using live-server (if installed globally)
npx live-server --port=3000 --entry-file=index.html
```
- **Development URL**: `http://localhost:3000`
- **Static files**: HTML/CSS/JS (no build process required)

### 🗄️ Database Management

**Important**: Database migrations now run automatically on server startup!

**Manual Commands** (for development only):
```bash
# View migration status
dotnet ef migrations list

# Create new migration (when models change)
dotnet ef migrations add MigrationName

# Remove last migration (if not applied)
dotnet ef migrations remove

# Manual database update (not needed - auto-migrates on startup)
dotnet ef database update

# Reset database (development only)
dotnet ef database drop --force
dotnet run  # Will recreate with auto-migration
```

### 🧪 Testing Commands

```bash
# Build verification
dotnet build

# Unit tests (when implemented)
dotnet test

# API testing with curl
curl -X GET "https://localhost:7297/health"
curl -X GET "https://localhost:7297/api/info"
```

### 🔧 Development Tools

**Package Management**:
```bash
# Add new package
dotnet add package PackageName

# List installed packages
dotnet list package

# Update packages
dotnet restore
```

**Project Structure**:
```bash
# View project structure (Windows)
tree /F RagChatApp_Server
tree /F RagChatApp_UI

# Alternative with PowerShell
Get-ChildItem -Recurse -Name
```

### 📋 Pre-Deployment Checklist

Before deploying or committing:
```bash
# 1. Build check
dotnet build

# 2. Clean and rebuild
dotnet clean
dotnet build

# 3. Test auto-migration (reset database)
dotnet ef database drop --force
dotnet run  # Should auto-migrate

# 4. Verify endpoints
curl -X GET "https://localhost:7297/health"
curl -X GET "https://localhost:7297/api/info"
```

## 🚨 MANDATORY API DEVELOPMENT CHECKLIST

**Before deploying any new API endpoint, verify ALL items below:**

### ✅ Security Requirements (NON-NEGOTIABLE)

- [ ] **Rate Limiting Configured**: Every endpoint MUST have rate limiting policy configured
  - **MANDATORY**: If no specific policy is mentioned, automatically assign `GlobalLimiter` policy
  - Apply `[EnableRateLimiting("GlobalLimiter")]` to controllers without explicit rate limiting
  - Custom policies should only be used when specifically required (e.g., stricter limits for sensitive endpoints)
- [ ] **Authentication Considered**: Determine if endpoint needs `[Authorize]` attribute
- [ ] **Input Validation**: All inputs are validated with appropriate `[Required]`, `[EmailAddress]`, etc.
- [ ] **SQL Injection Protection**: Use parameterized queries (Dapper prevents this automatically)
- [ ] **Cross-Site Scripting (XSS)**: Sanitize any user input that could be rendered

### ✅ Multi-Tenant Requirements

- [ ] **TenantId Context**: All database operations include appropriate tenant isolation
- [ ] **Tenant Authorization**: Verify user has access to resources within their tenant
- [ ] **Data Leakage Prevention**: Ensure users cannot access other tenants' data

### ✅ Error Handling & Logging

- [ ] **Structured Logging**: Use `ILogger` with proper log levels and context
- [ ] **Exception Handling**: Wrap operations in try-catch with appropriate error responses
- [ ] **PII Protection**: Don't log sensitive information (passwords, tokens, personal data)

### ✅ Performance & Scalability

- [ ] **Async Operations**: Use `async/await` for all I/O operations
- [ ] **Database Efficiency**: Optimize queries, avoid N+1 problems
- [ ] **Memory Management**: Dispose resources properly, avoid memory leaks

### ✅ Testing Requirements

- [ ] **Rate Limiting Tested**: Verify endpoint respects configured limits
- [ ] **Authentication Tested**: Test both authenticated and unauthenticated scenarios
- [ ] **Tenant Isolation Tested**: Verify users cannot access other tenants' data
- [ ] **Error Scenarios Tested**: Test invalid inputs, missing data, etc.

### ✅ Documentation

- [ ] **XML Documentation**: Add `/// <summary>` comments to all public methods
- [ ] **Rate Limiting Documented**: Update rate limiting documentation if using new policy
- [ ] **API Changes Logged**: Update changelog for breaking changes

### 🔍 Quick Rate Limiting Test Commands

```bash
# Test GlobalLimiter (most endpoints) - should handle 100+ requests
for i in {1..5}; do curl -X GET "http://localhost:5000/api/your-new-endpoint" -w "%{http_code} "; done

# Test specific policy - should respect policy limits
for i in {1..20}; do curl -X POST "http://localhost:5000/api/your-secured-endpoint" \
  -H "Content-Type: application/json" -d '{"test":"data"}' -w "%{http_code} "; done

# Expected: First N requests return 200, then 429 after limit exceeded
```

**❌ DEPLOYMENT BLOCKED** if any checklist item is not verified.

## Development Principles

Follow these core software development principles when working on this codebase:

### KISS (Keep It Simple, Stupid)
- Write straightforward, uncomplicated solutions
- Avoid over-engineering and unnecessary complexity
- Prioritize readable and maintainable code
- Choose simple implementations over clever ones

### YAGNI (You Aren't Gonna Need It)
- Implement only what's currently needed
- Don't add speculative features or functionality
- Avoid code bloat and unnecessary abstractions
- Focus on present requirements, not hypothetical future needs

### SOLID Principles
- **Single Responsibility Principle**: Each class should have one reason to change
- **Open-Closed Principle**: Open for extension, closed for modification
- **Liskov Substitution Principle**: Subtypes must be substitutable for their base types
- **Interface Segregation Principle**: Prefer specific interfaces over general ones
- **Dependency Inversion Principle**: Depend on abstractions, not concretions

### Error Handling & Logging

- **Structured Logging**: Use `ILogger` with proper log levels and context
- **Exception Handling**: Wrap operations in try-catch with appropriate error responses
- **PII Protection**: Don't log sensitive information (passwords, tokens, personal data)
- **Dependency injection logging**: Log each in and out from every method, for better log analayse

### Performance & Scalability

- **Async Operations**: Use `async/await` for all I/O operations
- **Database Efficiency**: Optimize queries, avoid N+1 problems
- **Memory Management**: Dispose resources properly, avoid memory leaks

## Documentation Practice

### Feature Development Workflow
When implementing new features or making significant changes, maintain comprehensive documentation:

1. **Before Implementation**: Create or update `/Documentation/app_info/YYYY-MM-DD_desired_app_functionality.md`
	- Document the desired changes and requirements
	- Specify tier restrictions and business logic
	- Define success criteria

2. **After Implementation**: Create `/Documentation/app_info/YYYY-MM-DD_implementation_update.md`
	- List all files created/modified
	- Document technical implementation details
	- Include build status and test results
	- Note any pending items or known issues

3. **Current State Documentation**: Maintain `/Documentation/app_info\YYYY-MM-DD_app_functionality.md`
	- Keep an up-to-date snapshot of current functionality
	- Organize by features and tiers
	- Include both implemented and planned features
	- Mark items clearly as ✅ Completed or ⌛ Pending

## 📚 MODELLO DI DOCUMENTAZIONE CRITICA
**AGGIUNGI SEMPRE QUI I DOCUMENTI IMPORTANTI!** Quando crei o scopri:

### 🏗️ Architettura e Design
- **Sistema RAG - Architettura Completa** → `/Documentation/ArchitectureDiagram/system-architecture.md`
  - Pipeline RAG (Retrieval-Augmented Generation)
  - Architettura backend .NET 9.0
  - Struttura frontend HTML/CSS/JavaScript
  - Integrazione Azure OpenAI
  - Diagrammi di flusso per indicizzazione e chat

### 🗄️ Database e Schema
- **Schema Database RAG** → `/Documentation/DatabaseSchemas/rag-database-schema.md`
  - Schema SQL Server completo con VECTOR(1536)
  - Entity Framework Core configuration
  - Indici per performance vettoriale
  - Query di esempio e monitoring
  - Configurazione produzione e backup

### 🔧 Configurazione e Setup
- **Guida Setup Completa** → `/Documentation/ConfigurationGuides/setup-configuration-guide.md`
  - Configurazione Azure OpenAI Service
  - Database SQL Server (locale, remoto, Azure)
  - CORS e networking
  - Environment specifici (Dev/Prod)
  - Docker deployment
  - Troubleshooting comune

### 🛠️ Problem Solving
- **Fix Connettività Frontend-Backend** → `/Documentation/ProblemSolving/frontend-backend-connectivity-fix.md`
  - Risoluzione port mismatch
  - HTTPS redirection issues
  - Configurazione CORS
  - Metodologia debugging network
  - Test di verifica e monitoring

## Git Workflow e Versioning

### 🔄 Commit Guidelines
**OBBLIGATORIO**: Ogni modifica significativa deve essere committata su Git con messaggi descrittivi.

#### Regole per i Commit
- **Frequenza**: Commit dopo ogni feature completata o bug fix
- **Granularità**: Un commit per ogni logica unità di lavoro
- **Messaggi**: Utilizzare il formato convenzionale con descrizione chiara
- **Testing**: Assicurarsi che il codice compili prima del commit

#### Formato Messaggi Commit
```
<tipo>(<scope>): <descrizione>

[corpo opzionale]

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Tipi di commit:**
- `feat`: nuova funzionalità
- `fix`: correzione bug
- `docs`: solo documentazione
- `style`: formattazione, punto e virgola mancanti, ecc.
- `refactor`: refactoring del codice
- `test`: aggiunta di test
- `chore`: task di manutenzione

#### Esempi di Commit Messages
```bash
feat(api): add document upload endpoint with file validation
fix(ui): resolve CORS issue in production environment
docs(readme): update setup instructions for Azure OpenAI
refactor(services): improve error handling in DocumentProcessingService
```

### 📋 Pre-Commit Checklist
Prima di ogni commit, verificare:
- [ ] **Build Success**: `dotnet build` completa senza errori
- [ ] **Tests Pass**: Tutti i test unitari passano
- [ ] **Linting**: Codice formattato correttamente
- [ ] **Documentation**: Documentazione aggiornata se necessario
- [ ] **Security**: Nessun secret o credential nel codice
- [ ] **CLAUDE.md**: Aggiornato se cambiati workflow o architettura

### 🚀 Workflow Standard
```bash
# 1. Verifica stato repository
git status
git pull origin main

# 2. Sviluppo e testing
dotnet build
dotnet test # se applicabile

# 3. Staging delle modifiche
git add .
# OPPURE specifiche
git add RagChatApp_Server/Controllers/DocumentsController.cs

# 4. Commit con messaggio descrittivo
git commit -m "feat(api): implement document processing with chunking

- Add intelligent text chunking based on markdown headers
- Implement vector embedding generation
- Add background processing for large documents
- Include comprehensive error handling and logging

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# 5. Push al repository
git push origin main
```

### 🔧 Git Configuration Setup
```bash
# Configurazione iniziale (solo prima volta)
git config --global user.name "Your Name"
git config --global user.email "your.email@company.com"
git config --global init.defaultBranch main

# Configurazione per questo progetto
git config core.autocrlf true
git config core.filemode false
```

### 📊 Branching Strategy
- **main**: branch principale per produzione
- **develop**: branch di sviluppo per nuove feature
- **feature/***: branch per feature specifiche
- **hotfix/***: branch per correzioni urgenti

```bash
# Creare feature branch
git checkout -b feature/chat-interface
git commit -m "feat(ui): implement chat interface"
git push origin feature/chat-interface

# Merge dopo review
git checkout main
git merge feature/chat-interface
git push origin main
git branch -d feature/chat-interface
```

### 🏷️ Tagging delle Release
```bash
# Creare tag per release
git tag -a v1.0.0 -m "Release version 1.0.0 - Initial RAG Chat Application"
git push origin v1.0.0

# Listrare tag esistenti
git tag -l
```

### 📝 Commit automaton con script
Creare `commit-and-push.ps1`:
```powershell
param(
    [Parameter(Mandatory=$true)]
    [string]$Message,
    [string]$Type = "feat",
    [string]$Scope = ""
)

# Build check
Write-Host "🔨 Building project..."
dotnet build
if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed. Commit aborted."
    exit 1
}

# Git operations
git add .
$commitMessage = if ($Scope) { "$Type($Scope): $Message" } else { "$Type: $Message" }
$fullMessage = @"
$commitMessage

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
"@

git commit -m $fullMessage
git push origin main

Write-Host "✅ Committed and pushed: $commitMessage" -ForegroundColor Green
```

Uso: `.\commit-and-push.ps1 -Message "implement document upload" -Type "feat" -Scope "api"`

## Notes

- Project follows clean architecture principles
- All API endpoints must have rate limiting configured
- Database uses SQL Server with vector support for embeddings
- Support both connected AI mode and mock mode for development
- Emphasize code simplicity and maintainability
- Comprehensive logging and error handling required
- **MANDATORY**: Commit all changes to Git with descriptive messages
- Follow the Git workflow for all modifications and improvements