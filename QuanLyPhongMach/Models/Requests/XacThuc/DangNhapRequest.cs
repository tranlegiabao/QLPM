using System.Text.Json.Serialization;
using System.ComponentModel.DataAnnotations;

namespace QuanLyPhongMach.Models.Requests.XacThuc;

public class DangNhapRequest
{
    [JsonPropertyName("ten_dang_nhap")]
    [Required]
    public string TenDangNhap { get; set; } = string.Empty;

    [JsonPropertyName("mat_khau")]
    [Required]
    public string MatKhau { get; set; } = string.Empty;

    [JsonPropertyName("ghi_nho")]
    public bool GhiNho { get; set; }

    [JsonPropertyName("return_url")]
    public string? ReturnUrl { get; set; }
}
