using System;
using System.Collections.Generic;

namespace QuanLyPhongMach.Entities;

public partial class DmTriSoSinhHieu
{
    public long Id { get; set; }

    public long Idcskcb { get; set; }

    public string MaTriSo { get; set; } = null!;

    public string TenTriSo { get; set; } = null!;

    public string? DonViTinh { get; set; }

    public int? ThuTu { get; set; }

    public bool Active { get; set; }

    public virtual DmCskcb IdcskcbNavigation { get; set; } = null!;

    public virtual ICollection<QlPhieuSinhHieuCt> QlPhieuSinhHieuCt { get; set; } = new List<QlPhieuSinhHieuCt>();
}
