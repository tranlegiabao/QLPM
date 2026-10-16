using System.Text.Json.Serialization;

namespace QuanLyPhongMach.Models.Requests.HeThong;

public class ChucDanhLuuRequest
{
    [JsonPropertyName("id_chuc_danh")]
    public long? IdChucDanh { get; set; }

    [JsonPropertyName("ma_chuc_danh")]
    public string? MaChucDanh { get; set; }

    [JsonPropertyName("ten_chuc_danh")]
    public string? TenChucDanh { get; set; }

    [JsonPropertyName("viet_tat")]
    public string? VietTat { get; set; }

    [JsonPropertyName("active")]
    public bool Active { get; set; } = true;
}
