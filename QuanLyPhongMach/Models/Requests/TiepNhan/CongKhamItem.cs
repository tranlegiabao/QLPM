using System.Text.Json.Serialization;

namespace QuanLyPhongMach.Models.Requests.TiepNhan;

public class CongKhamItem
{
    [JsonPropertyName("IDDichVu")]
    public long IdDichVu { get; set; }

    [JsonPropertyName("TenDichVu")]
    public string? TenDichVu { get; set; }

    [JsonPropertyName("SoLuong")]
    public decimal SoLuong { get; set; } = 1;

    [JsonPropertyName("DonGia")]
    public decimal DonGia { get; set; }

    [JsonPropertyName("GhiChu")]
    public string? GhiChu { get; set; }
}
