using System;
using System.Collections.Generic;

namespace QuanLyPhongMach.Entities;

public partial class QlToaThuocCt
{
    public long Id { get; set; }

    public long Idcskcb { get; set; }

    public long IdvaoVien { get; set; }

    public long? IdtoaThuoc { get; set; }

    public long Idthuoc { get; set; }

    public DateTime NgayKe { get; set; }

    public long? IdbacSiKe { get; set; }

    public int? SoNgay { get; set; }

    public string? Sang { get; set; }

    public string? Trua { get; set; }

    public string? Chieu { get; set; }

    public string? Toi { get; set; }

    public string? LieuDung { get; set; }

    public string? CachDung { get; set; }

    public decimal SoLuong { get; set; }

    public decimal DonGia { get; set; }

    public decimal ThanhTien { get; set; }

    public int? ThuTu { get; set; }

    public long? IdtoaThuocCtgoc { get; set; }

    public long? IddonViTinhDung { get; set; }

    public string? HoatChat { get; set; }

    public string MaLoaiToaThuoc { get; set; } = "c";

    public bool Active { get; set; }

    public virtual DmNhanVien? DmNhanVien { get; set; }

    public virtual DmLoaiToaThuoc DmLoaiToaThuoc { get; set; } = null!;

    public virtual DmThuoc DmThuoc { get; set; } = null!;

    public virtual DmCskcb IdcskcbNavigation { get; set; } = null!;

    public virtual ICollection<QlToaThuocCt> InverseQlToaThuocCtNavigation { get; set; } = new List<QlToaThuocCt>();

    public virtual ICollection<QlThuTienCt> QlThuTienCt { get; set; } = new List<QlThuTienCt>();

    public virtual QlToaThuocCt? QlToaThuocCtNavigation { get; set; }

    public virtual QlVaoVien QlVaoVien { get; set; } = null!;

    public virtual QlToaThuoc? QlToaThuoc { get; set; }
}
