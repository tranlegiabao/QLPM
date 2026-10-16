namespace QuanLyPhongMach.Models.Printing.KhamBenh;

public sealed class KhamBenhPrintChiDinhDong
{
    public DateTime NgayGioChiDinh { get; set; }
    public string MaDichVu { get; set; } = string.Empty;
    public string TenDichVu { get; set; } = string.Empty;
    public string DonViTinh { get; set; } = string.Empty;
    public decimal SoLuong { get; set; }
    public decimal DonGia { get; set; }
    public decimal ThanhTien { get; set; }
    public string NoiGuiNgoai { get; set; } = string.Empty;
    public string GhiChu { get; set; } = string.Empty;
}
