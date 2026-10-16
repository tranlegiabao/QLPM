using System.Text.Json.Serialization;

namespace QuanLyPhongMach.Models.Requests.HeThong;

public sealed class CauHinhTrangThaiRequest
{
    [JsonPropertyName("ma_chuc_nang")]
    public string? MaChucNang { get; set; }

    [JsonPropertyName("hieu_luc")]
    public bool? HieuLuc { get; set; }
}
