using System.Diagnostics;

namespace QuanLyPhongMach.Services;

// Do not log query strings, request bodies, cookies, tokens or PDF/image bytes.
public sealed class RequestErrorLoggingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<RequestErrorLoggingMiddleware> _logger;
    public RequestErrorLoggingMiddleware(RequestDelegate next,ILogger<RequestErrorLoggingMiddleware> logger)
    { _next=next;_logger=logger; }
    public async Task InvokeAsync(HttpContext context)
    {
        var started=Stopwatch.GetTimestamp();var exceptionLogged=false;
        context.Response.OnStarting(()=>{
            context.Response.Headers["X-QLPM-Trace-Id"]=context.TraceIdentifier;
            return Task.CompletedTask;
        });
        try { await _next(context); }
        catch(Exception ex) when(ex is not OperationCanceledException || !context.RequestAborted.IsCancellationRequested)
        {
            exceptionLogged=true;
            _logger.LogError(ex,"[QLPM] Unhandled {Method} {Path}; endpoint={Endpoint}; tenant={Tenant}; account={Account}; trace={TraceId}",
                context.Request.Method,context.Request.Path,context.GetEndpoint()?.DisplayName??"(no route)",
                context.User.LayIdCskcb(),context.User.LayIdTaiKhoan(),context.TraceIdentifier);
            throw;
        }
        finally
        {
            if(!exceptionLogged && context.Response.StatusCode>=400)
                _logger.LogError("[QLPM] HTTP {Status} {Method} {Path}; endpoint={Endpoint}; tenant={Tenant}; account={Account}; trace={TraceId}; elapsed={ElapsedMs}ms",
                    context.Response.StatusCode,context.Request.Method,context.Request.Path,
                    context.GetEndpoint()?.DisplayName??"(no route)",context.User.LayIdCskcb(),context.User.LayIdTaiKhoan(),
                    context.TraceIdentifier,Stopwatch.GetElapsedTime(started).TotalMilliseconds);
        }
    }
}

