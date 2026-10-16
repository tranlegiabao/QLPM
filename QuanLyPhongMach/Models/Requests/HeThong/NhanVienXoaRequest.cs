using System.Text.Json.Serialization;

namespace QuanLyPhongMach.Models.Requests.HeThong;

public class NhanVienXoaRequest
{
    [JsonPropertyName("id_nhan_vien")]
    public long IdNhanVien { get; set; }
}
