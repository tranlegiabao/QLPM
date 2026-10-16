using System;
using System.Collections.Generic;

namespace QuanLyPhongMach.Entities;

public partial class QlPhieuSinhHieu
{
    public long Id { get; set; }

    public long Idcskcb { get; set; }

    public long IdvaoVien { get; set; }

    public DateTime NgayGioDo { get; set; }

    public long? IdnhanVien { get; set; }

    public string? GhiChu { get; set; }

    public virtual DmNhanVien? DmNhanVien { get; set; }

    public virtual DmCskcb IdcskcbNavigation { get; set; } = null!;

    public virtual ICollection<QlPhieuSinhHieuCt> QlPhieuSinhHieuCt { get; set; } = new List<QlPhieuSinhHieuCt>();

    public virtual QlVaoVien QlVaoVien { get; set; } = null!;
}
