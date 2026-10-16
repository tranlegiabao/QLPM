using System;
using System.Collections.Generic;

namespace QuanLyPhongMach.Entities;

public partial class QlVaoVien
{
    public long Id { get; set; }

    public long Idcskcb { get; set; }

    public string MaVaoVien { get; set; } = null!;

    public long IdbenhNhan { get; set; }

    public DateTime Ngay { get; set; }

    public DateTime NgayGioVaoVien { get; set; }

    public int? SoThuTu { get; set; }

    public long? IdnguoiTiepNhan { get; set; }

    public long? IdbacSiKham { get; set; }

    public string? MaPdgoc { get; set; }

    public bool DaChuyenKham { get; set; }

    public DateTime? ThoiGianChuyenKham { get; set; }

    public byte TrangThaiKham { get; set; }

    public DateTime? BatDauKhamLuc { get; set; }

    public DateTime? KetThucKhamLuc { get; set; }

    public bool SinhHieu { get; set; }

    public bool Kham { get; set; }

    public bool KeToa { get; set; }

    public string? TrieuChung { get; set; }

    public long? IdphacDo { get; set; }

    public DateTime? NgayTaiKham { get; set; }

    public string? GhiChuTiepNhan { get; set; }

    public string? DanDo { get; set; }

    public bool Active { get; set; }

    public DateTime NgayTao { get; set; }

    public DateTime? NgayCapNhat { get; set; }

    public DateTime? NgayLuuKhamLanDau { get; set; }

    public DateTime? NgayCapNhatKham { get; set; }

    public long PhienBanLamSang { get; set; }

    public virtual DmNhanVien? DmNhanVien { get; set; }

    public virtual DmNhanVien? DmNhanVienNavigation { get; set; }

    public virtual DmPhacDo? DmPhacDo { get; set; }

    public virtual DmCskcb IdcskcbNavigation { get; set; } = null!;

    public virtual QlBenhNhan QlBenhNhan { get; set; } = null!;

    public virtual QlChanDoanCt? QlChanDoanCt { get; set; }

    public virtual ICollection<QlChiDinhCt> QlChiDinhCt { get; set; } = new List<QlChiDinhCt>();

    public virtual QlCongKham? QlCongKham { get; set; }

    public virtual ICollection<QlPhieuSinhHieu> QlPhieuSinhHieu { get; set; } = new List<QlPhieuSinhHieu>();

    public virtual QlThuTien? QlThuTien { get; set; }

    public virtual ICollection<QlToaThuocCt> QlToaThuocCt { get; set; } = new List<QlToaThuocCt>();
}
