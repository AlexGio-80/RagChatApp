# Configuration Guide

## Development Settings Setup

### Quick Start

1. **Copy the template file**:
   ```bash
   cd RagChatApp_Server
   cp appsettings.Development.json.template appsettings.Development.json
   ```

2. **Update connection string**:
   - Replace `YOUR_SERVER\INSTANCE` with your SQL Server instance (e.g., `localhost\SQLEXPRESS`)
   - Replace `YOUR_DOMAIN\YOUR_USER` with your Windows user (e.g., `DOMAIN\username`)
   - Or use SQL authentication:
     ```json
     "DefaultConnection": "Data Source=localhost;Initial Catalog=OSL_AI;User ID=sa;Password=YourPassword;TrustServerCertificate=True"
     ```

3. **Configure AI Provider API Keys**:

   **Option A: Use appsettings.json (Quick Testing)**
   ```json
   {
     "AIProvider": {
       "DefaultProvider": "Gemini",
       "Gemini": {
         "ApiKey": "AIzaSy-your-actual-gemini-key"
       }
     }
   }
   ```

   **Option B: Use Encrypted Database Storage (Recommended for Production)**
   ```powershell
   # Install with encrypted storage
   cd Database/StoredProcedures
   .\Install-MultiProvider.ps1 `
       -GeminiApiKey "your-gemini-api-key" `
       -OpenAIApiKey "your-openai-api-key"
   ```

   Then leave API keys as placeholders in `appsettings.Development.json`.

## Configuration Options

### MockMode (Development)
For development without API keys:
```json
{
  "MockMode": {
    "Enabled": true
  }
}
```

### RAG Settings
```json
{
  "RagSettings": {
    "MaxChunksForLLM": 10  // Max chunks to return (1-50)
  }
}
```

### AI Provider Selection
```json
{
  "AIProvider": {
    "DefaultProvider": "Gemini",  // "OpenAI" | "Gemini" | "AzureOpenAI"
    "OrderProcessingModel": "gpt-4o",
    "ArticleMatchingModel": "gpt-4o",
    "EmbeddingModel": "text-embedding-3-small",
    "ChatModel": "gpt-4o-mini"
  }
}
```

## Security Best Practices

### ⚠️ NEVER Commit API Keys

- `appsettings.Development.json` is in `.gitignore`
- Always use the `.template` file as reference
- Store production keys in:
  - Azure Key Vault (recommended)
  - Encrypted database (using `Install-MultiProvider.ps1`)
  - Environment variables

### Getting API Keys

**OpenAI**: https://platform.openai.com/api-keys
**Google Gemini**: https://makersuite.google.com/app/apikey
**Azure OpenAI**: https://portal.azure.com

## Troubleshooting

### Connection Issues
```bash
# Test database connection
dotnet ef database update
```

### API Key Issues
```bash
# Enable mock mode for testing without API keys
# Set "MockMode": { "Enabled": true } in appsettings.Development.json
```

### Check Current Configuration
```bash
# View configuration (API keys will be masked)
curl https://localhost:7297/api/info
```

## Environment-Specific Files

- `appsettings.json` - Base configuration (tracked in git)
- `appsettings.Development.json` - Local development (NOT tracked in git)
- `appsettings.Production.json` - Production overrides (tracked in git, no secrets)
- `appsettings.Development.json.template` - Template for developers (tracked in git)

## First Time Setup Checklist

- [ ] Copy `appsettings.Development.json.template` to `appsettings.Development.json`
- [ ] Update database connection string
- [ ] Add at least one AI provider API key OR enable MockMode
- [ ] Run database migrations: `dotnet ef database update`
- [ ] (Optional) Install encrypted API key storage: `.\Install-MultiProvider.ps1`
- [ ] Start server: `dotnet run`
- [ ] Test: `curl https://localhost:7297/health`

## Additional Resources

- **Encrypted Storage Guide**: `Database/StoredProcedures/ENCRYPTION_UPGRADE_GUIDE.md`
- **Installation Guide**: `Database/StoredProcedures/README_Installation.md`
- **Main Documentation**: `../CLAUDE.md`
