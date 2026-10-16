using System.Text.Json.Serialization;

namespace QuanLyPhongMach.Models.Requests.HeThong;

public class ChucDanhXoaRequest
{
    [JsonPropertyName("id_chuc_danh")]
    public long IdChucDanh { get; set; }
}
