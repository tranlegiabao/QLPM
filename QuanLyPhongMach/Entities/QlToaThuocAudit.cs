namespace QuanLyPhongMach.Entities;

public sealed class QlToaThuocAudit
{
    public long Id { get; set; }
    public long Idcskcb { get; set; }
    public long? IdtoaThuoc { get; set; }
    public long? IdtoaThuocPhienBan { get; set; }
    public string HanhDong { get; set; } = string.Empty;
    public string? TrangThaiTu { get; set; }
    public string? TrangThaiDen { get; set; }
    public string? LyDo { get; set; }
    public long? IdnhanVien { get; set; }
    public long IdtaiKhoan { get; set; }
    public DateTime NgayTao { get; set; }
}
