using System.Text.RegularExpressions;

namespace QuanLyPhongMach.Services.ToaThuocQuocGia;

public static partial class ToaThuocQuocGiaCode
{
    [GeneratedRegex("^[A-Za-z0-9]{5}[0-9]{7}-[cnh]$", RegexOptions.CultureInvariant)]
    private static partial Regex Pattern();

    public static bool IsValid(string? value, string? facilityCode = null, string? prescriptionType = null)
    {
        if (string.IsNullOrWhiteSpace(value) || !Pattern().IsMatch(value)) return false;
        if (!string.IsNullOrWhiteSpace(facilityCode)
            && !value.StartsWith(facilityCode.Trim(), StringComparison.OrdinalIgnoreCase)) return false;
        return string.IsNullOrWhiteSpace(prescriptionType)
            || value.EndsWith($"-{prescriptionType.Trim().ToLowerInvariant()}", StringComparison.Ordinal);
    }
}
