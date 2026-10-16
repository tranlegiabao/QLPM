namespace QuanLyPhongMach.Models.Requests.Kho;

public sealed class HoanThuocRequest
{
    public long id_vao_vien { get; set; }
    public bool hoan_toan_bo { get; set; }
    public string? ly_do { get; set; }
    public List<HoanThuocDongRequest> danh_sach { get; set; } = new();
}
