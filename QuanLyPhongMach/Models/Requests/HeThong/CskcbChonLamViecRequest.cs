using System.Text.Json.Serialization;

namespace QuanLyPhongMach.Models.Requests.HeThong;

public class CskcbChonLamViecRequest
{
    [JsonPropertyName("id_cskcb")]
    public long IdCskcb { get; set; }
}
