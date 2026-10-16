namespace QuanLyPhongMach.Models.Printing.ThuNgan;

public sealed class ThuNganPrintModel
{
    public string TenCskcb { get; set; } = string.Empty;
    public string DiaChiCskcb { get; set; } = string.Empty;
    public string DienThoaiCskcb { get; set; } = string.Empty;
    public string MaBenhNhan { get; set; } = string.Empty;
    public string HoTen { get; set; } = string.Empty;
    public string DiaChiBenhNhan { get; set; } = string.Empty;
    public string DienThoaiBenhNhan { get; set; } = string.Empty;
    public DateTime? NgaySinh { get; set; }
    public string GioiTinh { get; set; } = string.Empty;
    public string MaVaoVien { get; set; } = string.Empty;
    public string SoPhieu { get; set; } = string.Empty;
    public string LoaiChungTu { get; set; } = "THU";
    public int TrangThai { get; set; } = 1;
    public string LyDoHuy { get; set; } = string.Empty;
    public string SoChungTuGoc { get; set; } = string.Empty;
    public DateTime NgayGioThu { get; set; }
    public string NhanVienThu { get; set; } = string.Empty;
    public decimal TongTien { get; set; }
    public decimal TienGiam { get; set; }
    public decimal ThucThu { get; set; }
    public decimal TienMat { get; set; }
    public decimal ChuyenKhoan { get; set; }
    public string NganHang { get; set; } = string.Empty;
    public string GhiChu { get; set; } = string.Empty;
    public List<ThuNganPrintDong> ChiTiet { get; set; } = new();
}
