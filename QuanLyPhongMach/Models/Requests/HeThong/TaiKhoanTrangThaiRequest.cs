using System.Text.Json.Serialization;

namespace QuanLyPhongMach.Models.Requests.HeThong;

public class TaiKhoanTrangThaiRequest
{
    [JsonPropertyName("id_tai_khoan")]
    public long IdTaiKhoan { get; set; }

    [JsonPropertyName("active")]
    public bool Active { get; set; }
}
