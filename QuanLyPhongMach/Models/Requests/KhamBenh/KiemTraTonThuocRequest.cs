namespace QuanLyPhongMach.Models.Requests.KhamBenh;

public sealed class KiemTraTonThuocRequest
{
    public List<KiemTraTonThuocDongRequest> danh_sach { get; set; } = new();
}
