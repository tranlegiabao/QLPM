using System.Text.Json.Serialization;

namespace QuanLyPhongMach.Models.Requests.HeThong;

public class VaiTroXoaRequest
{
    [JsonPropertyName("id_vai_tro")]
    public long IdVaiTro { get; set; }
}
