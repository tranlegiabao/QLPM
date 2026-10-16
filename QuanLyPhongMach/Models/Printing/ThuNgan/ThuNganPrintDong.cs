namespace QuanLyPhongMach.Models.Printing.ThuNgan;

public sealed class ThuNganPrintDong
{
    public string Loai { get; set; } = string.Empty;
    public string Ten { get; set; } = string.Empty;
    public string DonViTinh { get; set; } = string.Empty;
    public decimal SoLuong { get; set; }
    public decimal DonGia { get; set; }
    public decimal ThanhTien { get; set; }
    public decimal PhuThu { get; set; }
    public decimal GiamPhanTram { get; set; }
    public decimal TienGiam { get; set; }
    public decimal ThanhToan { get; set; }
}
