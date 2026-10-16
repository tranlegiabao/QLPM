using System.Text.Json.Serialization;

namespace QuanLyPhongMach.Models.Requests.HeThong;

public class NhanVienLuuRequest
{
    [JsonPropertyName("id_nhan_vien")]
    public long? IdNhanVien { get; set; }

    [JsonPropertyName("ma_nhan_vien")]
    public string? MaNhanVien { get; set; }

    [JsonPropertyName("ho_ten")]
    public string? HoTen { get; set; }

    [JsonPropertyName("la_bac_si")]
    public bool LaBacSi { get; set; }

    [JsonPropertyName("chuc_danh")]
    public string? ChucDanh { get; set; }

    [JsonPropertyName("id_chuc_danh")]
    public long? IdChucDanh { get; set; }

    [JsonPropertyName("cskcb_ids")]
    public List<long> CskcbIds { get; set; } = new();

    [JsonPropertyName("dien_thoai")]
    public string? DienThoai { get; set; }

    [JsonPropertyName("so_nha_ten_duong")]
    public string? SoNhaTenDuong { get; set; }

    [JsonPropertyName("ma_tinh")]
    public string? MaTinh { get; set; }

    [JsonPropertyName("ma_phuong_xa")]
    public string? MaPhuongXa { get; set; }

    [JsonPropertyName("email")]
    public string? Email { get; set; }

    [JsonPropertyName("active")]
    public bool Active { get; set; } = true;
}
