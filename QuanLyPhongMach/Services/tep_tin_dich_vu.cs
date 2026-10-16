using System.Globalization;
using System.Text;

namespace QuanLyPhongMach.Services;

/// <summary>
/// Quy ước tên file ngắn, dễ đọc cho toàn hệ thống.
/// - File tải xuống: {loai}-{ma}.{ext}
/// - File lưu nội bộ: {loai}-{id}-{random8}.{ext}
/// Không dùng tên người bệnh / thông tin nhạy cảm trong tên file.
/// </summary>
public static class tep_tin_dich_vu
{
    public static string TaoTenTaiXuong(string loai, string? ma, string extension)
    {
        var loaiNgan = ChuanHoa(loai, "file", 12);
        var maNgan = ChuanHoa(ma, "data", 24);
        var ext = ChuanHoaExtension(extension);
        return $"{loaiNgan}-{maNgan}.{ext}";
    }

    public static string TaoTenLuuTru(string loai, long id, string extension)
    {
        var loaiNgan = ChuanHoa(loai, "file", 12);
        var ext = ChuanHoaExtension(extension);
        var random = Guid.NewGuid().ToString("N")[..8];
        return $"{loaiNgan}-{id}-{random}.{ext}";
    }

    private static string ChuanHoa(string? value, string fallback, int maxLength)
    {
        var source = string.IsNullOrWhiteSpace(value) ? fallback : value.Trim().ToLowerInvariant();
        var normalized = source.Normalize(NormalizationForm.FormD);
        var sb = new StringBuilder(maxLength);

        foreach (var ch in normalized)
        {
            if (CharUnicodeInfo.GetUnicodeCategory(ch) == UnicodeCategory.NonSpacingMark)
                continue;

            if (char.IsLetterOrDigit(ch))
            {
                sb.Append(ch);
            }
            else if ((ch == '-' || ch == '_' || char.IsWhiteSpace(ch)) && sb.Length > 0 && sb[^1] != '-')
            {
                sb.Append('-');
            }

            if (sb.Length >= maxLength) break;
        }

        var result = sb.ToString().Trim('-');
        return string.IsNullOrWhiteSpace(result) ? fallback : result;
    }

    private static string ChuanHoaExtension(string? extension)
    {
        var ext = (extension ?? string.Empty).Trim().TrimStart('.').ToLowerInvariant();
        if (string.IsNullOrWhiteSpace(ext)) return "bin";

        var safe = new string(ext.Where(char.IsLetterOrDigit).Take(10).ToArray());
        return string.IsNullOrWhiteSpace(safe) ? "bin" : safe;
    }
}
