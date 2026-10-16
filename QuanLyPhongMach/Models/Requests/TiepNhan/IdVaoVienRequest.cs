using System.Text.Json.Serialization;

namespace QuanLyPhongMach.Models.Requests.TiepNhan;

public class IdVaoVienRequest
{
    [JsonPropertyName("id_cskcb")]
    public long IdCskcb { get; set; }

    [JsonPropertyName("id_vao_vien")]
    public long IdVaoVien { get; set; }
}
