using System;
using System.Collections.Generic;

namespace QuanLyPhongMach.Entities;

public partial class DmDonViTinh
{
    public long Id { get; set; }

    public long Idcskcb { get; set; }

    public string MaDvt { get; set; } = null!;

    public string TenDvt { get; set; } = null!;

    public bool Active { get; set; }

    public virtual ICollection<DmThuoc> DmThuoc { get; set; } = new List<DmThuoc>();

    public virtual DmCskcb IdcskcbNavigation { get; set; } = null!;
}
