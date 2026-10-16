using System;
using System.Collections.Generic;

namespace QuanLyPhongMach.Entities;

public partial class DmTinhThanh
{
    public long Id { get; set; }

    public long Idcskcb { get; set; }

    public string MaTinh { get; set; } = null!;

    public string TenTinh { get; set; } = null!;

    public bool Active { get; set; }

    public virtual ICollection<DmPhuongXa> DmPhuongXa { get; set; } = new List<DmPhuongXa>();

    public virtual DmCskcb IdcskcbNavigation { get; set; } = null!;

    public virtual ICollection<QlBenhNhan> QlBenhNhan { get; set; } = new List<QlBenhNhan>();
}
