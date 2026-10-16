using System.Text.Json.Serialization;

namespace QuanLyPhongMach.Models.Requests.HeThong;

public class CskcbXoaRequest
{
    [JsonPropertyName("id_cskcb")]
    public long IdCskcb { get; set; }
}
