using System.Diagnostics;
using Serilog;
using Serilog.Context;

namespace RagChatApp_Server.Middleware;

/// <summary>
/// Middleware for logging HTTP request and response details with timing
/// </summary>
public class RequestResponseLoggingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<RequestResponseLoggingMiddleware> _logger;

    public RequestResponseLoggingMiddleware(RequestDelegate next, ILogger<RequestResponseLoggingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var stopwatch = Stopwatch.StartNew();
        var requestId = Guid.NewGuid().ToString("N")[..8];

        // Add request ID to log context
        using (LogContext.PushProperty("RequestId", requestId))
        {
            try
            {
                // Log request entry
                LogRequest(context, requestId);

                // Call the next delegate/middleware in the pipeline
                await _next(context);

                // Log response
                stopwatch.Stop();
                LogResponse(context, stopwatch.ElapsedMilliseconds, requestId);
            }
            catch (Exception ex)
            {
                stopwatch.Stop();
                _logger.LogError(ex,
                    "❌ REQUEST FAILED [{RequestId}] {Method} {Path} | Duration: {Duration}ms",
                    requestId,
                    context.Request.Method,
                    context.Request.Path,
                    stopwatch.ElapsedMilliseconds);
                throw;
            }
        }
    }

    private void LogRequest(HttpContext context, string requestId)
    {
        var request = context.Request;

        _logger.LogInformation(
            "➡️  REQUEST [{RequestId}] {Method} {Scheme}://{Host}{Path}{QueryString} | ContentType: {ContentType} | ContentLength: {ContentLength}",
            requestId,
            request.Method,
            request.Scheme,
            request.Host,
            request.Path,
            request.QueryString,
            request.ContentType ?? "none",
            request.ContentLength?.ToString() ?? "unknown");

        // Log headers (only in Debug level)
        if (_logger.IsEnabled(LogLevel.Debug))
        {
            foreach (var header in request.Headers.Where(h => !IsSensitiveHeader(h.Key)))
            {
                _logger.LogDebug("  Header: {HeaderKey} = {HeaderValue}", header.Key, header.Value);
            }
        }
    }

    private void LogResponse(HttpContext context, long durationMs, string requestId)
    {
        var statusCode = context.Response.StatusCode;
        var logLevel = GetLogLevelForStatusCode(statusCode);

        var emoji = statusCode switch
        {
            < 300 => "✅",
            < 400 => "↩️ ",
            < 500 => "⚠️ ",
            _ => "❌"
        };

        _logger.Log(logLevel,
            "{Emoji} RESPONSE [{RequestId}] {Method} {Path} | Status: {StatusCode} | Duration: {Duration}ms",
            emoji,
            requestId,
            context.Request.Method,
            context.Request.Path,
            statusCode,
            durationMs);

        // Warning for slow requests
        if (durationMs > 3000)
        {
            _logger.LogWarning(
                "🐌 SLOW REQUEST [{RequestId}] {Method} {Path} took {Duration}ms",
                requestId,
                context.Request.Method,
                context.Request.Path,
                durationMs);
        }
    }

    private static LogLevel GetLogLevelForStatusCode(int statusCode)
    {
        return statusCode switch
        {
            < 300 => LogLevel.Information,
            < 400 => LogLevel.Information,
            < 500 => LogLevel.Warning,
            _ => LogLevel.Error
        };
    }

    private static bool IsSensitiveHeader(string headerName)
    {
        var sensitiveHeaders = new[]
        {
            "Authorization",
            "Cookie",
            "Set-Cookie",
            "X-API-Key",
            "X-Auth-Token"
        };

        return sensitiveHeaders.Contains(headerName, StringComparer.OrdinalIgnoreCase);
    }
}
