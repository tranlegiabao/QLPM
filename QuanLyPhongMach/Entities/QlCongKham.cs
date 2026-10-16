using System;
using System.Collections.Generic;

namespace QuanLyPhongMach.Entities;

public partial class QlCongKham
{
    public long Id { get; set; }

    public long Idcskcb { get; set; }

    public long IdvaoVien { get; set; }

    public long? IdnguoiTao { get; set; }

    public DateTime NgayTao { get; set; }

    public string? GhiChu { get; set; }

    public virtual DmNhanVien? DmNhanVien { get; set; }

    public virtual DmCskcb IdcskcbNavigation { get; set; } = null!;

    public virtual ICollection<QlCongKhamCt> QlCongKhamCt { get; set; } = new List<QlCongKhamCt>();

    public virtual QlVaoVien QlVaoVien { get; set; } = null!;
}
