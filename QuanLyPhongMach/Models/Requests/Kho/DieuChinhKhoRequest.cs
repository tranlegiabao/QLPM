namespace QuanLyPhongMach.Models.Requests.Kho;

public sealed class DieuChinhKhoRequest
{
    public string? loai { get; set; }
    public string? ly_do { get; set; }
    public List<DieuChinhKhoDongRequest> danh_sach { get; set; } = new();
}
