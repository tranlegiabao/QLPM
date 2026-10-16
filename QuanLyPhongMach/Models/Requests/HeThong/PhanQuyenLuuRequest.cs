using System.Text.Json.Serialization;

namespace QuanLyPhongMach.Models.Requests.HeThong;

public class PhanQuyenLuuRequest
{
    [JsonPropertyName("id_vai_tro")]
    public long IdVaiTro { get; set; }

    [JsonPropertyName("quyen")]
    public object? Quyen { get; set; }
}
