using System.Text.Json.Serialization;

namespace QuanLyPhongMach.Models.Requests.TiepNhan;

public class BoCongKhamRequest
{
    [JsonPropertyName("id_cskcb")]
    public long IdCskcb { get; set; }

    [JsonPropertyName("id_vao_vien")]
    public long IdVaoVien { get; set; }

    [JsonPropertyName("id_cong_kham_ct_list")]
    public List<long> IdCongKhamCtList { get; set; } = new();
}
