using System;
using System.Collections.Generic;

namespace QuanLyPhongMach.Entities;

public partial class DmPhacDoThuoc
{
    public long Id { get; set; }

    public long Idcskcb { get; set; }

    public long IdphacDo { get; set; }

    public long Idthuoc { get; set; }

    public long? IddonViTinhDung { get; set; }

    public int SoNgay { get; set; }

    public string? Sang { get; set; }

    public string? Trua { get; set; }

    public string? Chieu { get; set; }

    public string? Toi { get; set; }

    public string? LieuDung { get; set; }

    public string? DuongDung { get; set; }

    public string? CachDung { get; set; }

    public decimal SoLuong { get; set; }

    public decimal? DonGia { get; set; }

    public int? ThuTu { get; set; }

    public bool Active { get; set; }

    public virtual DmPhacDo IdphacDoNavigation { get; set; } = null!;

    public virtual DmThuoc IdthuocNavigation { get; set; } = null!;
}
