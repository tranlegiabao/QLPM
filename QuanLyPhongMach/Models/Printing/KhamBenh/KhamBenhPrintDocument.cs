namespace QuanLyPhongMach.Models.Printing.KhamBenh;

public sealed class KhamBenhPrintDocument
{
    public string MaCskcb { get; set; } = string.Empty;
    public string TenCskcb { get; set; } = string.Empty;
    public string DiaChiCskcb { get; set; } = string.Empty;
    public string DienThoaiCskcb { get; set; } = string.Empty;
    public string EmailCskcb { get; set; } = string.Empty;
    public string? LogoDataUri { get; set; }
    public string MaBn { get; set; } = string.Empty;
    public string MaVaoVien { get; set; } = string.Empty;
    public string BarcodeSvg { get; set; } = string.Empty;
    public string HoTen { get; set; } = string.Empty;
    public DateTime? NgaySinh { get; set; }
    public string GioiTinh { get; set; } = string.Empty;
    public string SoCccd { get; set; } = string.Empty;
    public string DiaChi { get; set; } = string.Empty;
    public string DienThoai { get; set; } = string.Empty;
    public string GiamHoMoiQuanHe { get; set; } = string.Empty;
    public string GiamHoHoTen { get; set; } = string.Empty;
    public string GiamHoDienThoai { get; set; } = string.Empty;
    public string GiamHoSoCccd { get; set; } = string.Empty;
    public string TrieuChung { get; set; } = string.Empty;
    public string ChanDoan { get; set; } = string.Empty;
    public string BacSi { get; set; } = string.Empty;
    public string LoiDan { get; set; } = string.Empty;
    public DateTime? NgayTaiKham { get; set; }
    public List<KhamBenhPrintSinhHieu> SinhHieu { get; set; } = new();
    public List<KhamBenhPrintChiDinhPage> ChiDinhPages { get; set; } = new();
    public List<KhamBenhPrintToaPage> ToaPages { get; set; } = new();
}
