using System;
using System.Text.RegularExpressions;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Builder;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using WkHtmlToPdfDotNet;
using WkHtmlToPdfDotNet.Contracts;
using QuanLyPhongMach.Data;
using QuanLyPhongMach.Services;
using QuanLyPhongMach.Services.ToaThuocQuocGia;
using QuanLyPhongMach.Services.KySoPdf;

var builder = WebApplication.CreateBuilder(args);

const long maxRequestBodyBytes = 20L * 1024 * 1024;
builder.WebHost.ConfigureKestrel(options =>
{
    options.Limits.MaxRequestBodySize = maxRequestBodyBytes;
});
builder.Services.Configure<FormOptions>(options =>
{
    options.MultipartBodyLengthLimit = maxRequestBodyBytes;
});

builder.Configuration.AddJsonFile("appsettings.local.json", optional: true, reloadOnChange: true);
// Console for the Project profile; Debug provider for Visual Studio Output.
builder.Logging.AddConsole();
builder.Logging.AddDebug();

var configuredKeyRingPath = builder.Configuration["DataProtection:KeyRingPath"];
var keyRingPath = string.IsNullOrWhiteSpace(configuredKeyRingPath)
    ? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "QLPM", "DataProtectionKeys")
    : Path.GetFullPath(configuredKeyRingPath);
Directory.CreateDirectory(keyRingPath);
builder.Services.AddDataProtection()
    .SetApplicationName("QLPM")
    .PersistKeysToFileSystem(new DirectoryInfo(keyRingPath));

var configuredConnectionString = builder.Configuration.GetConnectionString("QLPM")
    ?? throw new InvalidOperationException("Chua cau hinh ConnectionStrings:QLPM.");
var connectionStringWithoutCommandTimeout = Regex.Replace(
    configuredConnectionString,
    @"(?i)(^|;)\s*Command Timeout\s*=\s*[^;]*(;|$)",
    "$1").Trim().TrimEnd(';');
var qlpmConnectionStringBuilder = new SqlConnectionStringBuilder(connectionStringWithoutCommandTimeout)
{
    Pooling = true,
    MinPoolSize = 10,
    MaxPoolSize = 200
};
if (qlpmConnectionStringBuilder.DataSource is "." or "(local)" or "localhost")
{
    qlpmConnectionStringBuilder.Encrypt = false;
}
builder.Configuration["ConnectionStrings:QLPM"] = qlpmConnectionStringBuilder.ConnectionString;

builder.Services.AddScoped<ngu_canh_nguoi_dung_filter>();
builder.Services.AddScoped<phan_quyen_nghiep_vu_filter>();
builder.Services.AddScoped<dich_vu_phien_dang_nhap>();
builder.Services.AddScoped<IRazorViewRenderer, RazorViewRenderer>();
builder.Services.AddScoped<IKhamBenhPrintService, KhamBenhPrintService>();
builder.Services.AddScoped<QlpmDocumentStorage>();
builder.Services.AddScoped<IToaThuocReadinessService, ToaThuocReadinessService>();
builder.Services.AddScoped<IToaThuocDeliveryService, ToaThuocDeliveryService>();
builder.Services.AddScoped<ILienThongTrucTiepService, LienThongTrucTiepService>();
builder.Services.AddScoped<ILienThongCredentialProtector, LienThongCredentialProtector>();
// Legacy combined JSON/PDF contract is retained for old records. Real PDF
// signing uses KySoPdfService; no national JSON signature is fabricated.
builder.Services.AddSingleton<IToaThuocSigner, UnconfiguredToaThuocSigner>();
builder.Services.AddSingleton<PdfKySoPreviewStore>();
builder.Services.AddScoped<KySoPdfService>();
builder.Services.AddHttpClient<IPdfSigningProvider, HisSoftPdfSigningProvider>(client =>
{
    client.Timeout = TimeSpan.FromSeconds(30);
    client.DefaultRequestHeaders.UserAgent.ParseAdd("QLPM-PDF-Signing/1.0");
});
builder.Services.AddHttpClient<IToaThuocQuocGiaClient, ToaThuocQuocGiaClient>(client =>
{
    client.Timeout = TimeSpan.FromSeconds(30);
    client.DefaultRequestHeaders.UserAgent.ParseAdd("QLPM-ToaThuocQuocGia/1.0");
});
builder.Services.AddSingleton(typeof(IConverter), new SynchronizedConverter(new PdfTools()));

builder.Services.AddControllersWithViews(options =>
    {
        options.Filters.Add<ngu_canh_nguoi_dung_filter>();
        options.Filters.Add<phan_quyen_nghiep_vu_filter>();
        options.Filters.Add<ApiResultErrorLoggingFilter>();
    })
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.PropertyNamingPolicy = null;
    });

builder.Services.AddDbContext<QlpmDbContext>(options =>
    options.UseSqlServer(
        builder.Configuration.GetConnectionString("QLPM"),
        sqlServerOptions => sqlServerOptions.CommandTimeout(30)));

builder.Services.AddSingleton<danh_muc_json_dich_vu>();
builder.Services.AddHostedService<danh_muc_json_worker>();
builder.Services.AddHostedService<ToaThuocDeliveryWorker>();

builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.LoginPath = "/xac_thuc/dang_nhap";
        options.LogoutPath = "/api/xac_thuc/dang_xuat";
        options.AccessDeniedPath = "/xac_thuc/cam_truy_cap";
        options.Cookie.Name = "qlpm_auth";
        options.Cookie.HttpOnly = true;
        options.Cookie.SameSite = Microsoft.AspNetCore.Http.SameSiteMode.Lax;
        options.Cookie.SecurePolicy = Microsoft.AspNetCore.Http.CookieSecurePolicy.SameAsRequest;
        options.SlidingExpiration = true;
        options.ExpireTimeSpan = TimeSpan.FromHours(8);

        options.Events.OnRedirectToLogin = async context =>
        {
            if (context.Request.Path.StartsWithSegments("/api"))
            {
                context.Response.StatusCode = StatusCodes.Status401Unauthorized;
                await context.Response.WriteAsJsonAsync(new
                {
                    status = StatusCodes.Status401Unauthorized,
                    message = "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại."
                });
                return;
            }

            context.Response.Redirect(context.RedirectUri);
        };
        options.Events.OnRedirectToAccessDenied = async context =>
        {
            if (context.Request.Path.StartsWithSegments("/api"))
            {
                context.Response.StatusCode = StatusCodes.Status403Forbidden;
                await context.Response.WriteAsJsonAsync(new
                {
                    status = StatusCodes.Status403Forbidden,
                    message = "Bạn chưa có quyền thực hiện thao tác này."
                });
                return;
            }

            context.Response.Redirect(context.RedirectUri);
        };

        options.Events.OnValidatePrincipal = async context =>
        {
            try
            {
                var dichVuPhien = context.HttpContext.RequestServices.GetRequiredService<dich_vu_phien_dang_nhap>();
                var principalMoi = await dichVuPhien.TaiLaiAsync(context.Principal!);
                if (principalMoi == null)
                {
                    context.RejectPrincipal();
                    context.HttpContext.Response.Cookies.Delete("qlpm_auth");
                    return;
                }

                context.ReplacePrincipal(principalMoi);
                context.ShouldRenew = true;
            }
            catch (Exception ex)
            {
                // Vẫn fail-closed với request hiện tại khi không xác minh được từ DB.
                // Không xóa cookie vì lỗi SQL/kết nối tạm thời: lần truy cập sau
                // có thể xác minh lại khi DB hoạt động, kể cả phiên "Ghi nhớ đăng nhập".
                var logger = context.HttpContext.RequestServices
                    .GetRequiredService<ILoggerFactory>()
                    .CreateLogger("QLPM.Authentication");
                logger.LogWarning(ex, "Không thể xác minh lại phiên đăng nhập do lỗi hệ thống.");
                context.RejectPrincipal();
            }
        };
    });

builder.Services.AddAuthorization(options =>
{
    options.FallbackPolicy = new AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        .Build();
});

builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
    {
        if (!context.Request.Path.StartsWithSegments("/api"))
            return RateLimitPartition.GetNoLimiter("non-api");

        var authenticated = context.User.Identity?.IsAuthenticated == true;
        var accountId = authenticated ? context.User.LayIdTaiKhoan() : 0;
        var remoteIp = context.Connection.RemoteIpAddress?.ToString() ?? "unknown";
        var key = accountId > 0
            ? $"account:{accountId}"
            : $"ip:{remoteIp}";
        var permitLimit = authenticated ? 180 : 60;

        return RateLimitPartition.GetFixedWindowLimiter(key, _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = permitLimit,
            Window = TimeSpan.FromMinutes(1),
            QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
            QueueLimit = 0,
            AutoReplenishment = true
        });
    });
    options.OnRejected = async (context, cancellationToken) =>
    {
        context.HttpContext.Response.Headers["Retry-After"] = "60";
        context.HttpContext.Response.ContentType = "application/json; charset=utf-8";
        await context.HttpContext.Response.WriteAsync(
            "{\"status\":429,\"message\":\"Quá nhiều yêu cầu. Vui lòng thử lại sau.\"}",
            cancellationToken);
    };
});

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseMiddleware<RequestErrorLoggingMiddleware>();
app.UseStaticFiles();
app.UseRouting();
app.UseAuthentication();
app.UseRateLimiter();
app.UseAuthorization();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();
