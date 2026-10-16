using System.Text.Json.Serialization;

namespace QuanLyPhongMach.Models.Requests.HeThong;

public class TaiKhoanXoaRequest
{
    [JsonPropertyName("id_tai_khoan")]
    public long IdTaiKhoan { get; set; }
}
