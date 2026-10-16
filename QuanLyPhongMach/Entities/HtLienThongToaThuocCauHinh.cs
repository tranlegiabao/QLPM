namespace QuanLyPhongMach.Entities;

public sealed class HtLienThongToaThuocCauHinh
{
    public long Idcskcb { get; set; }
    public string MoiTruong { get; set; } = "TEST";
    public string ApiBaseUrlProduction { get; set; } = "https://api.donthuocquocgia.vn";
    public string? ApiBaseUrlTest { get; set; }
    public string? UrlKyDuLieu { get; set; }
    public string? UrlKyPdf { get; set; }
    public string? MaLienThongCskcb { get; set; }
    public string? MatKhauCskcbMaHoa { get; set; }
    public bool HieuLuc { get; set; }
    public bool KySoHieuLuc { get; set; }
    public bool LienThongHieuLuc { get; set; }
    public DateTime NgayCapNhat { get; set; }
    public long? IdtaiKhoanCapNhat { get; set; }
}
