namespace QuanLyPhongMach.Models.Printing.Kho;

public sealed class KhoNhapPrintDong
{
    public string Ten { get; set; } = string.Empty;
    public string Ma { get; set; } = string.Empty;
    public string DonViTinh { get; set; } = string.Empty;
    public string SoLo { get; set; } = string.Empty;
    public DateTime? HanDung { get; set; }
    public decimal SoLuong { get; set; }
    public decimal HeSoQuyDoi { get; set; }
    public decimal SoLuongCoSo { get; set; }
    public decimal? SoLuongTonCoSo { get; set; }
    public decimal GiaNhap { get; set; }
    public decimal ThanhTien { get; set; }
}
