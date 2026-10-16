using QuanLyPhongMach.Models.Printing.ThuNgan;

namespace QuanLyPhongMach.Models.Printing.Kho;

public sealed class KhoNhapPrintModel
{
    public ThuNganPrintModel CoSo { get; set; } = new();
    public string SoPhieu { get; set; } = string.Empty;
    public DateTime NgayNhap { get; set; }
    public string SoHoaDon { get; set; } = string.Empty;
    public DateTime? NgayHoaDon { get; set; }
    public string NhaCungCap { get; set; } = string.Empty;
    public string DiaChiNhaCungCap { get; set; } = string.Empty;
    public string DienThoaiNhaCungCap { get; set; } = string.Empty;
    public string EmailCskcb { get; set; } = string.Empty;
    public string MaSoThueCskcb { get; set; } = string.Empty;
    public string SoTaiKhoanCskcb { get; set; } = string.Empty;
    public string NganHangCskcb { get; set; } = string.Empty;
    public string LogoDataUri { get; set; } = string.Empty;
    public string GhiChu { get; set; } = string.Empty;
    public string NguoiNhap { get; set; } = string.Empty;
    public bool DaHuy { get; set; }
    public string LyDoHuy { get; set; } = string.Empty;
    public bool LaLegacy { get; set; }
    public decimal TongTien { get; set; }
    public List<KhoNhapPrintDong> ChiTiet { get; set; } = new();
}
