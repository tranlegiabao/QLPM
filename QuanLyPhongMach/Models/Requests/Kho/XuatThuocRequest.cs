namespace QuanLyPhongMach.Models.Requests.Kho;

public sealed class XuatThuocRequest
{
    public long id_kho { get; set; }
    public long id_vao_vien { get; set; }
    public string? ghi_chu { get; set; }
    public List<XuatThuocDongRequest> danh_sach { get; set; } = new();
}
