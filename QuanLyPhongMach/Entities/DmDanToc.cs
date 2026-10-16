using System;
using System.Collections.Generic;

namespace QuanLyPhongMach.Entities;

public partial class DmDanToc
{
    public long Id { get; set; }

    public long Idcskcb { get; set; }

    public string MaDanToc { get; set; } = null!;

    public string TenDanToc { get; set; } = null!;

    public bool Active { get; set; }

    public virtual DmCskcb IdcskcbNavigation { get; set; } = null!;

    public virtual ICollection<QlBenhNhan> QlBenhNhan { get; set; } = new List<QlBenhNhan>();
}
