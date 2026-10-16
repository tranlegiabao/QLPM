using System;
using System.Collections.Generic;

namespace QuanLyPhongMach.Entities;

public partial class DmPhuongXa
{
    public long Id { get; set; }

    public long Idcskcb { get; set; }

    public long IdtinhThanh { get; set; }

    public string MaPhuongXa { get; set; } = null!;

    public string TenPhuongXa { get; set; } = null!;

    public bool Active { get; set; }

    public virtual DmTinhThanh DmTinhThanh { get; set; } = null!;

    public virtual DmCskcb IdcskcbNavigation { get; set; } = null!;

    public virtual ICollection<QlBenhNhan> QlBenhNhan { get; set; } = new List<QlBenhNhan>();
}
