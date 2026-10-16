namespace QuanLyPhongMach.Entities;

public sealed class QlToaThuoc
{
    public long Id { get; set; }
    public long Idcskcb { get; set; }
    public long IdvaoVien { get; set; }
    public DateTime NgayKe { get; set; }
    public string MaLoaiToaThuoc { get; set; } = "c";
    public long IdbacSiKe { get; set; }
    public int? SoThuTuLienThong { get; set; }
    public string? MaToaQuocGia { get; set; }
    public string TrangThai { get; set; } = "NHAP";
    public long PhienBanNguon { get; set; }
    public long? IdphienBanHienTai { get; set; }
    public DateTime NgayTao { get; set; }
    public DateTime? NgayCapNhat { get; set; }

    public ICollection<QlToaThuocCt> ChiTiet { get; set; } = new List<QlToaThuocCt>();
    public ICollection<QlToaThuocPhienBan> PhienBan { get; set; } = new List<QlToaThuocPhienBan>();
}
