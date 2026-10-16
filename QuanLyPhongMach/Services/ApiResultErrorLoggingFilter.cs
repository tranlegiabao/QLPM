using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace QuanLyPhongMach.Services;

// Several older APIs return HTTP 200 with { status: 4xx/5xx }.
public sealed class ApiResultErrorLoggingFilter : IAsyncResultFilter
{
    private readonly ILogger<ApiResultErrorLoggingFilter> _logger;
    public ApiResultErrorLoggingFilter(ILogger<ApiResultErrorLoggingFilter> logger)=>_logger=logger;
    public async Task OnResultExecutionAsync(ResultExecutingContext context,ResultExecutionDelegate next)
    {
        if(context.Result is ObjectResult result && (result.StatusCode??200)<400 && result.Value is {} value)
        {
            var status=value.GetType().GetProperty("status")?.GetValue(value);
            if(status is int code && code>=400)
                _logger.LogError("[QLPM] API result {Status} {Method} {Path}; tenant={Tenant}; account={Account}; trace={TraceId}",
                    code,context.HttpContext.Request.Method,context.HttpContext.Request.Path,
                    context.HttpContext.User.LayIdCskcb(),context.HttpContext.User.LayIdTaiKhoan(),context.HttpContext.TraceIdentifier);
        }
        await next();
    }
}

