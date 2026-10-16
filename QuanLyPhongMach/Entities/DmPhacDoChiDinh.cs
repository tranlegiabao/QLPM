using System;
using System.Collections.Generic;

namespace QuanLyPhongMach.Entities;

public partial class DmPhacDoChiDinh
{
    public long Id { get; set; }

    public long Idcskcb { get; set; }

    public long IdphacDo { get; set; }

    public long IddichVu { get; set; }

    public decimal SoLuong { get; set; }

    public decimal? DonGia { get; set; }

    public bool GuiNgoai { get; set; }

    public string? NoiGuiNgoai { get; set; }

    public string? GhiChu { get; set; }

    public int? ThuTu { get; set; }

    public bool Active { get; set; }

    public virtual DmDichVu IddichVuNavigation { get; set; } = null!;

    public virtual DmPhacDo IdphacDoNavigation { get; set; } = null!;
}
