using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using QuanLyPhongMach.Models.ToaThuocQuocGia;

namespace QuanLyPhongMach.Services.ToaThuocQuocGia;

public sealed class ToaThuocQuocGiaClient : IToaThuocQuocGiaClient
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    private readonly HttpClient _httpClient;

    public ToaThuocQuocGiaClient(HttpClient httpClient)
    {
        _httpClient = httpClient;
    }

    public async Task<ToaThuocNationalSendResult> GuiAsync(ToaThuocNationalRequest request, CancellationToken cancellationToken = default)
    {
        var registeredNow = false;
        try
        {
            var token = await DangNhapBacSiAsync(request, cancellationToken);
            if (!string.IsNullOrWhiteSpace(token) && !request.DoctorWasRegistered)
                registeredNow = true;
            if (string.IsNullOrWhiteSpace(token))
            {
                if (request.DoctorWasRegistered)
                    return new(false, false, 401, "AUTH_DOCTOR_FAILED", string.Empty,
                        "Mã liên thông hoặc mật khẩu bác sĩ không hợp lệ.");
                var facilityToken = await DangNhapCskcbAsync(request, cancellationToken);
                if (string.IsNullOrWhiteSpace(facilityToken))
                    return new(false, false, 401, "AUTH_CSKCB_FAILED", string.Empty, "Đăng nhập cơ sở khám chữa bệnh thất bại.");

                await DangKyBacSiAsync(request, facilityToken, cancellationToken);
                registeredNow = true;
                token = await DangNhapBacSiAsync(request, cancellationToken);
            }

            if (string.IsNullOrWhiteSpace(token))
                return new(false, false, 401, "AUTH_DOCTOR_FAILED", string.Empty, "Đăng nhập bác sĩ thất bại.");

            using var message = new HttpRequestMessage(HttpMethod.Post, TaoUri(request.BaseAddress, "/api/v1/gui-don-thuoc"));
            message.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
            message.Headers.TryAddWithoutValidation("Idempotency-Key", request.IdempotencyKey.ToString("D"));
            message.Content = new StringContent(request.SignedJson, Encoding.UTF8, "application/json");

            using var response = await _httpClient.SendAsync(message, cancellationToken);
            var body = await response.Content.ReadAsStringAsync(cancellationToken);
            var sanitized = LienThongResponseSanitizer.Sanitize(body);
            var accepted = response.IsSuccessStatusCode && LaKetQuaThanhCong(body);
            return new(accepted, false, (int)response.StatusCode,
                accepted ? "ACCEPTED" : "REJECTED", sanitized,
                accepted ? null : "Hệ thống quốc gia chưa xác nhận tiếp nhận toa thuốc.", registeredNow);
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return new(false, true, null, "TIMEOUT", string.Empty,
                "Hết thời gian chờ; chưa xác định hệ thống quốc gia đã nhận toa hay chưa.", registeredNow);
        }
        catch (HttpRequestException)
        {
            return new(false, true, null, "NETWORK_ERROR", string.Empty, "Lỗi kết nối; chưa xác định hệ thống quốc gia đã nhận toa hay chưa.", registeredNow);
        }
    }

    private async Task<string?> DangNhapBacSiAsync(ToaThuocNationalRequest request, CancellationToken cancellationToken)
    {
        var payload = JsonSerializer.Serialize(new
        {
            ma_lien_thong_bac_si = request.Doctor.Username,
            ma_lien_thong_co_so_kham_chua_benh = request.Facility.Username,
            password = request.Doctor.Password
        }, JsonOptions);
        return await PostForTokenAsync(TaoUri(request.BaseAddress, "/api/auth/dang-nhap-bac-si"), payload, cancellationToken);
    }

    private async Task<string?> DangNhapCskcbAsync(ToaThuocNationalRequest request, CancellationToken cancellationToken)
    {
        var payload = JsonSerializer.Serialize(new
        {
            ma_lien_thong_co_so_kham_chua_benh = request.Facility.Username,
            password = request.Facility.Password
        }, JsonOptions);
        return await PostForTokenAsync(TaoUri(request.BaseAddress, "/api/auth/dang-nhap-co-so-kham-chua-benh"), payload, cancellationToken);
    }

    private async Task DangKyBacSiAsync(ToaThuocNationalRequest request, string facilityToken, CancellationToken cancellationToken)
    {
        using var message = new HttpRequestMessage(HttpMethod.Post, TaoUri(request.BaseAddress, "/api/v1/them-bac-si"));
        message.Headers.Authorization = new AuthenticationHeaderValue("Bearer", facilityToken);
        message.Content = JsonContent(new { ma_lien_thong_bac_si = request.Doctor.Username });
        using var response = await _httpClient.SendAsync(message, cancellationToken);
        if (!response.IsSuccessStatusCode)
            throw new HttpRequestException("Không đăng ký được bác sĩ với hệ thống toa thuốc quốc gia.", null, response.StatusCode);
    }

    private async Task<string?> PostForTokenAsync(Uri uri, string payload, CancellationToken cancellationToken)
    {
        using var message = new HttpRequestMessage(HttpMethod.Post, uri)
        {
            Content = new StringContent(payload, Encoding.UTF8, "application/json")
        };
        using var response = await _httpClient.SendAsync(message, cancellationToken);
        if (!response.IsSuccessStatusCode) return null;
        var body = await response.Content.ReadAsStringAsync(cancellationToken);
        try
        {
            using var doc = JsonDocument.Parse(body);
            return doc.RootElement.TryGetProperty("token", out var token) ? token.GetString() : null;
        }
        catch (JsonException)
        {
            return null;
        }
    }

    private static StringContent JsonContent(object value)
        => new(JsonSerializer.Serialize(value, JsonOptions), Encoding.UTF8, "application/json");

    private static Uri TaoUri(Uri baseAddress, string path) => new(baseAddress, path);

    private static bool LaKetQuaThanhCong(string body)
    {
        try
        {
            using var doc = JsonDocument.Parse(body);
            var root = doc.RootElement;
            if (root.TryGetProperty("success", out var success)
                && (success.ValueKind is JsonValueKind.True
                    || success.ValueKind == JsonValueKind.String && !string.IsNullOrWhiteSpace(success.GetString())))
                return true;
            foreach (var key in new[] { "status", "statusCode", "code" })
            {
                if (!root.TryGetProperty(key, out var value)) continue;
                if (value.ValueKind == JsonValueKind.Number && value.TryGetInt32(out var number) && number == 200) return true;
                if (value.ValueKind == JsonValueKind.String && value.GetString() is "200" or "SUCCESS" or "ACCEPTED") return true;
            }
            return false;
        }
        catch (JsonException)
        {
            return false;
        }
    }

}
