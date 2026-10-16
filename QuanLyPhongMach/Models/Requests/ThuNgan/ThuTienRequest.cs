namespace QuanLyPhongMach.Models.Requests.ThuNgan;

public sealed class ThuTienRequest
{
    public long id_vao_vien { get; set; }
    public decimal chuyen_khoan { get; set; }
    public long? id_ngan_hang { get; set; }
    public string? ghi_chu { get; set; }
    public List<ThuTienDongRequest> danh_sach { get; set; } = new();
}
