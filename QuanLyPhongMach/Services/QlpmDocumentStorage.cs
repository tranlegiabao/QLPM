using System.Globalization;
using System.Net;
using System.Text.RegularExpressions;
using QuanLyPhongMach.Services.KySoPdf;

namespace QuanLyPhongMach.Services;

/// <summary>
/// File mới nằm trên FTP. Khóa CLS hiện có vẫn dùng cho STO và được ánh xạ
/// vào QLPM/KQCLS; PDF ký dùng tenant + SHA256 để không ghi đè bản ký khác.
/// Giữ khả năng đọc tài liệu cũ ở local/DB, không tự di chuyển lịch sử.
/// </summary>
public sealed class QlpmDocumentStorage
{
    private readonly IConfiguration _configuration;
    private readonly IWebHostEnvironment _environment;
    public QlpmDocumentStorage(IConfiguration configuration, IWebHostEnvironment environment)
    { _configuration = configuration; _environment = environment; }

    public const string LogoUrlPrefix = "/uploads/cskcb-logo/";

    public async Task UploadLogoAsync(string url, Stream content, CancellationToken ct)
        => await UploadAsync("QLPM/LogoCSKCB/" + LogoFileName(url), content, ct);

    public async Task<byte[]?> ReadLogoAsync(string url, CancellationToken ct)
    {
        var name = LogoFileName(url);
        var bytes = await DownloadAsync("QLPM/LogoCSKCB/" + name, 5 * 1024 * 1024, ct);
        if (bytes != null) return bytes;
        var local = Path.Combine(_environment.WebRootPath ?? Path.Combine(_environment.ContentRootPath, "wwwroot"), "uploads", "cskcb-logo", name);
        return File.Exists(local) ? await File.ReadAllBytesAsync(local, ct) : null;
    }

    public async Task DeleteLogoAsync(string? url, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(url) || !url.StartsWith(LogoUrlPrefix, StringComparison.OrdinalIgnoreCase)) return;
        var name = LogoFileName(url);
        await DeleteAsync("QLPM/LogoCSKCB/" + name, ct);
        var local = Path.Combine(_environment.WebRootPath ?? Path.Combine(_environment.ContentRootPath, "wwwroot"), "uploads", "cskcb-logo", name);
        if (File.Exists(local)) File.Delete(local);
    }

    public async Task<string?> LoadLogoDataUriAsync(string? url, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(url)) return null;
        if (Uri.TryCreate(url, UriKind.Absolute, out var absolute) && absolute.Scheme is "http" or "https") return url;
        byte[]? bytes;
        if (url.StartsWith(LogoUrlPrefix, StringComparison.OrdinalIgnoreCase))
            bytes = await ReadLogoAsync(url, ct);
        else
        {
            var root = Path.GetFullPath(_environment.WebRootPath ?? Path.Combine(_environment.ContentRootPath, "wwwroot"));
            var full = Path.GetFullPath(Path.Combine(root, url.Trim().TrimStart('/').Replace('/', Path.DirectorySeparatorChar)));
            if (!full.StartsWith(root + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase) || !File.Exists(full)) return null;
            bytes = await File.ReadAllBytesAsync(full, ct);
        }
        var mime = LogoContentType(url);
        return bytes == null || mime == null ? null : $"data:{mime};base64,{Convert.ToBase64String(bytes)}";
    }

    public static string? LogoContentType(string url) => Path.GetExtension(url).ToLowerInvariant() switch
    {
        ".jpg" or ".jpeg" => "image/jpeg", ".png" => "image/png",
        ".webp" => "image/webp", ".gif" => "image/gif", ".svg" => "image/svg+xml", _ => null
    };

    private static string LogoFileName(string url)
    {
        var match = Regex.Match(url, @"\A/uploads/cskcb-logo/(logo-[1-9][0-9]*-[A-Za-z0-9_-]+\.(?:jpg|jpeg|png|webp|gif))\z", RegexOptions.IgnoreCase);
        if (!match.Success) throw new IOException("Đường dẫn logo CSKCB không hợp lệ.");
        return match.Groups[1].Value;
    }

    public async Task UploadClsAsync(string key, long tenant, long order, Stream content, CancellationToken ct)
        => await UploadAsync(ClsRemotePath(key, tenant, order), content, ct);

    public async Task<byte[]?> ReadClsAsync(string key, long tenant, long order, CancellationToken ct)
    {
        var remote = ClsRemotePath(key, tenant, order);
        var bytes = await DownloadAsync(remote, 15 * 1024 * 1024, ct);
        if (bytes != null) return bytes;
        var local = LegacyClsPath(key);
        return File.Exists(local) ? await File.ReadAllBytesAsync(local, ct) : null;
    }

    public async Task DeleteClsAsync(string key, long tenant, long order, CancellationToken ct)
    {
        await DeleteAsync(ClsRemotePath(key, tenant, order), ct);
        var local = LegacyClsPath(key);
        if (File.Exists(local)) File.Delete(local);
    }

    public async Task SaveSignedPdfAsync(long tenant, byte[] pdf, CancellationToken ct)
    {
        await using var stream = new MemoryStream(pdf, writable: false);
        await UploadAsync(SignedRemotePath(tenant, KySoPdfService.Hash(pdf)), stream, ct);
    }

    public async Task<byte[]> ReadSignedPdfAsync(long tenant, string hash, byte[] legacyPdf, CancellationToken ct)
    {
        var pdf = await DownloadAsync(SignedRemotePath(tenant, hash), 10 * 1024 * 1024, ct) ?? legacyPdf;
        if (!string.Equals(KySoPdfService.Hash(pdf), hash, StringComparison.OrdinalIgnoreCase))
            throw new IOException("PDF đã ký không khớp hash lưu trữ.");
        return pdf;
    }

    private static string ClsRemotePath(string key, long tenant, long order)
    {
        var match = Regex.Match(key, @"^App_Data/cls(?:-v2)?/(\d+)/(\d+)/([A-Za-z0-9_-]+\.(?:pdf|jpg|jpeg|png|webp))$", RegexOptions.IgnoreCase);
        if (!match.Success || tenant <= 0 || order <= 0
            || match.Groups[1].Value != tenant.ToString(CultureInfo.InvariantCulture)
            || match.Groups[2].Value != order.ToString(CultureInfo.InvariantCulture))
            throw new IOException("Đường dẫn kết quả CLS không thuộc chỉ định tại cơ sở hiện tại.");
        return $"QLPM/KQCLS/{tenant}_{order}_{match.Groups[3].Value}";
    }

    private static string SignedRemotePath(long tenant, string hash)
    {
        if (tenant <= 0 || !Regex.IsMatch(hash, @"\A[0-9a-fA-F]{64}\z"))
            throw new IOException("Khóa PDF đã ký không hợp lệ.");
        return $"QLPM/KySoPDF/{tenant}_{hash.ToLowerInvariant()}.pdf";
    }

    private string LegacyClsPath(string key)
        => Path.Combine(_environment.ContentRootPath, key.Replace('/', Path.DirectorySeparatorChar));

    // FtpWebRequest is available in this net7 application; use the existing
    // FTP protocol/configuration without adding a package or changing HIS.
#pragma warning disable SYSLIB0014
    private FtpWebRequest Request(string path, string method)
    {
        var host = _configuration["FtpServer:ftpHost"]?.Trim();
        var username = _configuration["FtpServer:ftpUsername"];
        var password = _configuration["FtpServer:ftpPassword"];
        if (string.IsNullOrWhiteSpace(host) || string.IsNullOrWhiteSpace(username) || password == null
            || !Uri.TryCreate(host.Contains("://", StringComparison.Ordinal) ? host : "ftp://" + host, UriKind.Absolute, out var server)
            || server.Scheme != "ftp" || server.UserInfo.Length != 0 || server.Query.Length != 0
            || server.Fragment.Length != 0 || server.AbsolutePath != "/")
            throw new IOException("Cấu hình FTP lưu tài liệu QLPM không hợp lệ.");
        var request = (FtpWebRequest)WebRequest.Create(new Uri(server, path));
        request.Method = method;
        request.Credentials = new NetworkCredential(username, password);
        request.UseBinary = true;
        request.UsePassive = true;
        request.KeepAlive = false;
        request.Timeout = 60000;
        request.ReadWriteTimeout = 60000;
        return request;
    }
#pragma warning restore SYSLIB0014

    private static bool Missing(WebException ex)
    {
        var response = ex.Response as FtpWebResponse;
        var missing = response?.StatusCode == FtpStatusCode.ActionNotTakenFileUnavailable;
        response?.Dispose();
        return missing;
    }

    private static CancellationTokenSource Deadline(CancellationToken ct)
    {
        var deadline = CancellationTokenSource.CreateLinkedTokenSource(ct);
        deadline.CancelAfter(TimeSpan.FromSeconds(60));
        return deadline;
    }

    private async Task EnsureDirectoryAsync(string path, CancellationToken ct)
    {
        var request = Request(path, WebRequestMethods.Ftp.MakeDirectory);
        using var deadline = Deadline(ct);
        using var abort = deadline.Token.Register(request.Abort);
        try { using var response = (FtpWebResponse)await request.GetResponseAsync(); }
        catch (WebException ex) when (Missing(ex))
        {
            // MKD also returns 550 when a directory exists. Confirm the target
            // directory before continuing; do not hide access/create failures.
            var existing = Request(path + "/", WebRequestMethods.Ftp.ListDirectory);
            using var cancel = deadline.Token.Register(existing.Abort);
            using var response = (FtpWebResponse)await existing.GetResponseAsync();
        }
    }

    private async Task UploadAsync(string path, Stream content, CancellationToken ct)
    {
        await EnsureDirectoryAsync("QLPM", ct);
        await EnsureDirectoryAsync(path[..path.LastIndexOf('/')], ct);
        var request = Request(path, WebRequestMethods.Ftp.UploadFile);
        using var deadline = Deadline(ct);
        using var abort = deadline.Token.Register(request.Abort);
        await using (var target = await request.GetRequestStreamAsync())
            await content.CopyToAsync(target, deadline.Token);
        using var response = (FtpWebResponse)await request.GetResponseAsync();
    }

    private async Task<byte[]?> DownloadAsync(string path, int maxBytes, CancellationToken ct)
    {
        var request = Request(path, WebRequestMethods.Ftp.DownloadFile);
        using var deadline = Deadline(ct);
        using var abort = deadline.Token.Register(request.Abort);
        try
        {
            using var response = (FtpWebResponse)await request.GetResponseAsync();
            await using var source = response.GetResponseStream();
            await using var output = new MemoryStream();
            var buffer = new byte[81920];
            int count;
            while ((count = await source.ReadAsync(buffer, deadline.Token)) > 0)
            {
                if (output.Length + count > maxBytes) throw new IOException("File tài liệu trên FTP vượt kích thước cho phép.");
                await output.WriteAsync(buffer.AsMemory(0, count), deadline.Token);
            }
            return output.ToArray();
        }
        catch (WebException ex) when (Missing(ex)) { return null; }
    }

    private async Task DeleteAsync(string path, CancellationToken ct)
    {
        var request = Request(path, WebRequestMethods.Ftp.DeleteFile);
        using var deadline = Deadline(ct);
        using var abort = deadline.Token.Register(request.Abort);
        try { using var response = (FtpWebResponse)await request.GetResponseAsync(); }
        catch (WebException ex) when (Missing(ex)) { }
    }
}
