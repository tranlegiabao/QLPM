namespace QuanLyPhongMach.Models.Requests.Kho;

public sealed class NhapKhoDongRequest
{
    public long id_thuoc { get; set; }
    public long id_don_vi_tinh { get; set; }
    public decimal so_luong { get; set; }
    public decimal gia_nhap { get; set; }
    public string? so_lo { get; set; }
    public DateTime? han_dung { get; set; }
}
