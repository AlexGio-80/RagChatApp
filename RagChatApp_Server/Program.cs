using Microsoft.EntityFrameworkCore;
using RagChatApp_Server.Data;
using RagChatApp_Server.Models;
using RagChatApp_Server.Services;
using RagChatApp_Server.Services.AIProviders;
using RagChatApp_Server.Services.Interfaces;

var builder = WebApplication.CreateBuilder(args);

// Configure application to run as Windows Service
builder.Host.UseWindowsService();

// Add services to the container
builder.Services.AddControllers();

// Configure Entity Framework
builder.Services.AddDbContext<RagChatDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

// Configure AI Provider settings
builder.Services.Configure<AIProviderSettings>(
    builder.Configuration.GetSection("AIProvider"));

// Rate limiting will be configured later with AspNetCoreRateLimit package

// Configure CORS
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

// Register custom services
builder.Services.AddScoped<IDocumentProcessingService, DocumentProcessingService>();

// Register AI provider services with HttpClient
// Configure HttpClient for each provider with proper BaseAddress
builder.Services.AddHttpClient<OpenAIProviderService>((serviceProvider, client) =>
{
    var config = serviceProvider.GetRequiredService<IConfiguration>();
    var baseUrl = config["AIProvider:OpenAI:BaseUrl"] ?? "https://api.openai.com/v1";
    var apiKey = config["AIProvider:OpenAI:ApiKey"] ?? "";

    // Ensure BaseUrl ends with / for proper relative path concatenation
    if (!baseUrl.EndsWith("/"))
    {
        baseUrl += "/";
    }

    client.BaseAddress = new Uri(baseUrl);
    client.DefaultRequestHeaders.Add("Authorization", $"Bearer {apiKey}");
    client.Timeout = TimeSpan.FromSeconds(30);
});

builder.Services.AddHttpClient<GeminiProviderService>((serviceProvider, client) =>
{
    var config = serviceProvider.GetRequiredService<IConfiguration>();
    var baseUrl = config["AIProvider:Gemini:BaseUrl"] ?? "https://generativelanguage.googleapis.com/v1beta";

    // Ensure BaseUrl ends with / for proper relative path concatenation
    if (!baseUrl.EndsWith("/"))
    {
        baseUrl += "/";
    }

    client.BaseAddress = new Uri(baseUrl);
    client.Timeout = TimeSpan.FromSeconds(30);
});

builder.Services.AddHttpClient<AzureOpenAIProviderService>();

builder.Services.AddScoped<AIProviderFactory>();

// Register the default AI provider service based on configuration
builder.Services.AddScoped<IAIProviderService>(provider =>
{
    var factory = provider.GetRequiredService<AIProviderFactory>();
    return factory.CreateProvider();
});

// Keep existing AzureOpenAI service for backward compatibility
builder.Services.AddScoped<IAzureOpenAIService, AzureOpenAIService>();
builder.Services.AddHttpClient<IAzureOpenAIService, AzureOpenAIService>();

// Configure Swagger/OpenAPI
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new() { Title = "RAG Chat API", Version = "v1" });

    // Include XML comments
    var xmlFile = $"{System.Reflection.Assembly.GetExecutingAssembly().GetName().Name}.xml";
    var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
    if (File.Exists(xmlPath))
    {
        c.IncludeXmlComments(xmlPath);
    }
});

var app = builder.Build();

// Auto-migrate database on startup
using (var scope = app.Services.CreateScope())
{
    var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();
    var context = scope.ServiceProvider.GetRequiredService<RagChatDbContext>();

    try
    {
        logger.LogInformation("Starting database migration...");
        await context.Database.MigrateAsync();
        logger.LogInformation("Database migration completed successfully.");
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "An error occurred during database migration.");
        throw; // Re-throw to prevent startup if database migration fails
    }
}

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c => c.SwaggerEndpoint("/swagger/v1/swagger.json", "RAG Chat API v1"));
}

// Enable CORS
app.UseCors("AllowAll");

// Rate limiting will be added later

app.UseHttpsRedirection();

// Map controllers
app.MapControllers();

// Health check endpoint
app.MapGet("/health", () => new { Status = "Healthy", Timestamp = DateTime.UtcNow })
    .WithName("HealthCheck");

// API info endpoint
app.MapGet("/api/info", (IConfiguration config, AIProviderFactory factory) => new
{
    ApplicationName = "RAG Chat API",
    Version = "1.0.0",
    Environment = app.Environment.EnvironmentName,
    MockMode = config.GetValue<bool>("MockMode:Enabled", false),
    DefaultAIProvider = factory.GetDefaultProvider().ToString(),
    AvailableProviders = factory.GetAvailableProviders().Select(p => p.ToString()).ToArray()
}).WithName("ApiInfo");

app.Run();
