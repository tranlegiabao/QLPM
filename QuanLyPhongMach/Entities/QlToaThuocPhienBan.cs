namespace QuanLyPhongMach.Entities;

public sealed class QlToaThuocPhienBan
{
    public long Id { get; set; }
    public long Idcskcb { get; set; }
    public long IdtoaThuoc { get; set; }
    public int SoPhienBan { get; set; }
    public long PhienBanNguon { get; set; }
    public string TrangThai { get; set; } = "DA_KY";
    public string JsonChuaKy { get; set; } = string.Empty;
    public string Sha256Json { get; set; } = string.Empty;
    public string ChuKyDuLieu { get; set; } = string.Empty;
    public string JsonDaKy { get; set; } = string.Empty;
    public byte[] PdfDaKy { get; set; } = Array.Empty<byte>();
    public string Sha256Pdf { get; set; } = string.Empty;
    public string? NhaCungCapKy { get; set; }
    public string? SerialChungThu { get; set; }
    public long IdbacSiKy { get; set; }
    public long IdtaiKhoanKy { get; set; }
    public DateTime NgayGioKy { get; set; }
    public DateTime NgayTao { get; set; }

    public QlToaThuoc ToaThuoc { get; set; } = null!;
    public ICollection<QlToaThuocLanGui> LanGui { get; set; } = new List<QlToaThuocLanGui>();
}
