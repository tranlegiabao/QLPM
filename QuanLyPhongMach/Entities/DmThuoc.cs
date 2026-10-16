using System;
using System.Collections.Generic;

namespace QuanLyPhongMach.Entities;

public partial class DmThuoc
{
    public long Id { get; set; }

    public long Idcskcb { get; set; }

    public string MaThuoc { get; set; } = null!;

    public string? MaThuocQuocGia { get; set; }

    public string TenThuoc { get; set; } = null!;

    public long? IddonViTinh { get; set; }

    public long? IdnhomHang { get; set; }

    public string? DonViTinh { get; set; }

    public string? DuongDung { get; set; }

    public string? HamLuong { get; set; }

    public string? HoatChat { get; set; }

    public decimal GiaBan { get; set; }

    public bool Active { get; set; }

    public virtual ICollection<DmPhacDoThuoc> DmPhacDoThuoc { get; set; } = new List<DmPhacDoThuoc>();

    public virtual DmCskcb IdcskcbNavigation { get; set; } = null!;

    public virtual DmNhomHang? DmNhomHang { get; set; }

    public virtual DmDonViTinh? IddonViTinhNavigation { get; set; }

    public virtual ICollection<QlToaThuocCt> QlToaThuocCt { get; set; } = new List<QlToaThuocCt>();
}
