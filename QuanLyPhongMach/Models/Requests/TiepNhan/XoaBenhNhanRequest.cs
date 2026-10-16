using System.Text.Json.Serialization;

namespace QuanLyPhongMach.Models.Requests.TiepNhan;

public class XoaBenhNhanRequest
{
    [JsonPropertyName("id_cskcb")]
    public long IdCskcb { get; set; }

    [JsonPropertyName("id_benh_nhan")]
    public long IdBenhNhan { get; set; }
}
