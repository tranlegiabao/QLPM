namespace QuanLyPhongMach.Models.Reports.ThuNgan;

public sealed class ThuNganLichSuHuyExcelDong
{
    public DateTime? NgayThu { get; set; }
    public string NguonThu { get; set; } = string.Empty;
    public string SoChungTu { get; set; } = string.Empty;
    public string TrangThaiXoa { get; set; } = string.Empty;
    public DateTime? NgayGioHuy { get; set; }
    public string TenNguoiDangNhapHuy { get; set; } = string.Empty;
    public DateTime? NgayGioXoa { get; set; }
    public string TenNguoiDangNhapXoa { get; set; } = string.Empty;
    public string TenNguoiXoa { get; set; } = string.Empty;
    public string LyDoXoa { get; set; } = string.Empty;
    public string SoDienThoaiBenhNhan { get; set; } = string.Empty;
    public string ThongTinHanhChinh { get; set; } = string.Empty;
    public string NoiDungHuy { get; set; } = string.Empty;
}
