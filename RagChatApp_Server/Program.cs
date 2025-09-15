using Microsoft.EntityFrameworkCore;
using RagChatApp_Server.Data;
using RagChatApp_Server.Services;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container
builder.Services.AddControllers();

// Configure Entity Framework
builder.Services.AddDbContext<RagChatDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

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
app.MapGet("/api/info", (IConfiguration config) => new
{
    ApplicationName = "RAG Chat API",
    Version = "1.0.0",
    Environment = app.Environment.EnvironmentName,
    MockMode = config.GetValue<bool>("MockMode:Enabled", false)
}).WithName("ApiInfo");

app.Run();
