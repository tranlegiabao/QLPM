namespace QuanLyPhongMach.Entities;

public sealed class HtLienThongToaThuocBacSi
{
    public long Idcskcb { get; set; }
    public long IdnhanVien { get; set; }
    public string? MaLienThong { get; set; }
    public string? SoChungChiHanhNghe { get; set; }
    public string? MatKhauMaHoa { get; set; }
    public bool DaDangKy { get; set; }
    public bool Active { get; set; }
    public DateTime NgayCapNhat { get; set; }
    public long? IdtaiKhoanCapNhat { get; set; }
}
