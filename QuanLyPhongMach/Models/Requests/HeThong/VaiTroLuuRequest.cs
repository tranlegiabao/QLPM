using System.Text.Json.Serialization;

namespace QuanLyPhongMach.Models.Requests.HeThong;

public class VaiTroLuuRequest
{
    [JsonPropertyName("id_vai_tro")]
    public long? IdVaiTro { get; set; }

    [JsonPropertyName("ma_vai_tro")]
    public string? MaVaiTro { get; set; }

    [JsonPropertyName("ten_vai_tro")]
    public string? TenVaiTro { get; set; }

    [JsonPropertyName("mo_ta")]
    public string? MoTa { get; set; }

    [JsonPropertyName("active")]
    public bool Active { get; set; } = true;
}
