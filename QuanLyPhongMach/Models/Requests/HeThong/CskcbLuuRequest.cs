using System.Text.Json.Serialization;

namespace QuanLyPhongMach.Models.Requests.HeThong;

public class CskcbLuuRequest
{
    [JsonPropertyName("id_cskcb")]
    public long? IdCskcb { get; set; }

    [JsonPropertyName("ma_cskcb")]
    public string? MaCskcb { get; set; }

    [JsonPropertyName("ten_cskcb")]
    public string? TenCskcb { get; set; }

    [JsonPropertyName("so_nha_ten_duong")]
    public string? SoNhaTenDuong { get; set; }

    [JsonPropertyName("ma_tinh")]
    public string? MaTinh { get; set; }

    [JsonPropertyName("ma_phuong_xa")]
    public string? MaPhuongXa { get; set; }

    [JsonPropertyName("sdt")]
    public string? Sdt { get; set; }

    [JsonPropertyName("email")]
    public string? Email { get; set; }

    [JsonPropertyName("ma_st")]
    public string? MaSt { get; set; }

    [JsonPropertyName("so_tk")]
    public string? SoTk { get; set; }

    [JsonPropertyName("id_ngan_hang")]
    public long? IdNganHang { get; set; }

    [JsonPropertyName("url_logo")]
    public string? UrlLogo { get; set; }

    [JsonPropertyName("active")]
    public bool Active { get; set; } = true;
}
