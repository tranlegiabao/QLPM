using System.Text.Json.Serialization;

namespace QuanLyPhongMach.Models.Requests.HeThong;

public class TaiKhoanLuuRequest
{
    [JsonPropertyName("id_tai_khoan")]
    public long? IdTaiKhoan { get; set; }

    [JsonPropertyName("id_nhan_vien")]
    public long IdNhanVien { get; set; }

    [JsonPropertyName("ten_dang_nhap")]
    public string? TenDangNhap { get; set; }


    [JsonPropertyName("vai_tro_ids")]
    public List<long> VaiTroIds { get; set; } = new();
}
