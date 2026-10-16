namespace QuanLyPhongMach.Entities;

public sealed class QlToaThuocLanGui
{
    public long Id { get; set; }
    public long Idcskcb { get; set; }
    public long IdtoaThuocPhienBan { get; set; }
    public Guid IdempotencyKey { get; set; }
    public int SoLan { get; set; }
    public string TrangThai { get; set; } = "CHO_GUI";
    public int? HttpStatus { get; set; }
    public string? MaKetQua { get; set; }
    public string? PhanHoiDaLoc { get; set; }
    public string? LoiCuoi { get; set; }
    public long IdbacSiYeuCau { get; set; }
    public long IdtaiKhoanYeuCau { get; set; }
    public DateTime NgayTao { get; set; }
    public DateTime? BatDauLuc { get; set; }
    public DateTime? KetThucLuc { get; set; }

    public QlToaThuocPhienBan PhienBan { get; set; } = null!;
}
