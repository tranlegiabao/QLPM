using System.Globalization;
using System.Text;
using System.Text.Json;
using QuanLyPhongMach.Services.ToaThuocQuocGia;

namespace QuanLyPhongMach.Services.KySoPdf;

/// <summary>
/// Contract ký PDF dùng chung: phiếu chỉ định, toa thuốc và tài liệu y tế sau này.
/// Khác hoàn toàn việc ký trường 'signature' của JSON quốc gia.
/// </summary>
public sealed record PdfSigningRequest(
    byte[] PdfNguon,
    string MaCskcb,
    string MaNguoiKy,
    int TrangKy,
    decimal ToaDoX,
    decimal ToaDoY,
    string KichThuoc = "SM");

public sealed record PdfSigningResult(
    byte[] PdfDaKy,
    string? MaHoSo,
    string NhaCungCap,
    string? SerialChungThu = null);

public interface IPdfSigningProvider
{
    Task<PdfSigningResult> KyPdfAsync(
        Uri urlDichVu, PdfSigningRequest request, CancellationToken cancellationToken = default);
}

/// <summary>
/// Adapter theo JSON request/response HISoft CaServices. URL phải do đơn vị ký cấp thực tế.
/// Không mặc định tự nhận URL UAT của nhà cung cấp khác làm URL ký HISoft.
/// </summary>
public sealed class HisSoftPdfSigningProvider : IPdfSigningProvider
{
    private readonly HttpClient _http;
    public HisSoftPdfSigningProvider(HttpClient http) => _http = http;

    public async Task<PdfSigningResult> KyPdfAsync(
        Uri urlDichVu, PdfSigningRequest request, CancellationToken cancellationToken = default)
    {
        if (urlDichVu.Scheme != Uri.UriSchemeHttps)
            throw new ToaThuocInteroperabilityException(422, "Dịch vụ ký PDF phải dùng HTTPS.");
        if (request.PdfNguon.Length == 0 || request.PdfNguon.Length > 10 * 1024 * 1024 ||
            request.TrangKy < 1 || request.ToaDoX < 0 || request.ToaDoY < 0 ||
            string.IsNullOrWhiteSpace(request.MaCskcb) ||
            string.IsNullOrWhiteSpace(request.MaNguoiKy))
            throw new ToaThuocInteroperabilityException(422, "Dữ liệu, trang hoặc vị trí ký PDF không hợp lệ.");

        // JSON phù hợp contract payload HISoft CaServices trong báo cáo kỹ thuật.
        var payload = JsonSerializer.Serialize(new
        {
            base64 = Convert.ToBase64String(request.PdfNguon),
            maCSKCB = request.MaCskcb,
            page = request.TrangKy,
            toaDoX = request.ToaDoX.ToString(CultureInfo.InvariantCulture),
            toaDoY = request.ToaDoY.ToString(CultureInfo.InvariantCulture),
            maNguoiKy = request.MaNguoiKy,
            kichThuoc = request.KichThuoc
        });
        using var message = new HttpRequestMessage(HttpMethod.Post, urlDichVu)
        {
            Content = new StringContent(payload, Encoding.UTF8, "application/json")
        };
        using var response = await _http.SendAsync(message, cancellationToken);
        if (!response.IsSuccessStatusCode)
            throw new ToaThuocInteroperabilityException(502, "Dịch vụ ký PDF trả lỗi HTTP.");
        var text = await response.Content.ReadAsStringAsync(cancellationToken);
        using var json = JsonDocument.Parse(text);
        var root = json.RootElement;
        if (!root.TryGetProperty("statusCode", out var status) ||
            !(status.ValueKind == JsonValueKind.Number && status.TryGetInt32(out var code) && code == 200
              || status.ValueKind == JsonValueKind.String && status.GetString() == "200") ||
            !root.TryGetProperty("dataSign", out var dataSign) ||
            dataSign.ValueKind != JsonValueKind.String ||
            string.IsNullOrWhiteSpace(dataSign.GetString()))
            throw new ToaThuocInteroperabilityException(502, "Dịch vụ ký PDF không trả dữ liệu ký hợp lệ.");

        byte[] signedPdf;
        try { signedPdf = Convert.FromBase64String(dataSign.GetString()!); }
        catch (FormatException)
        {
            throw new ToaThuocInteroperabilityException(502, "Dịch vụ ký PDF trả dữ liệu Base64 không hợp lệ.");
        }
        if (signedPdf.Length < 8 || signedPdf.Length > 10 * 1024 * 1024 ||
            Encoding.ASCII.GetString(signedPdf, 0, 5) != "%PDF-")
            throw new ToaThuocInteroperabilityException(502, "Dịch vụ ký PDF không trả file PDF hợp lệ.");

        var serial = PdfSignatureVerifier.Verify(signedPdf);

        var maHoSo = root.TryGetProperty("maHoSo", out var ma)
            && ma.ValueKind == JsonValueKind.String ? ma.GetString() : null;
        return new PdfSigningResult(signedPdf, maHoSo, "HISSOFT_EXTERNAL", serial);
    }
}
