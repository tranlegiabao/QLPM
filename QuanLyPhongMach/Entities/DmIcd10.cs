using System;
using System.Collections.Generic;

namespace QuanLyPhongMach.Entities;

public partial class DmIcd10
{
    public long Id { get; set; }

    public long Idcskcb { get; set; }

    public string MaBenh { get; set; } = null!;

    public string TenBenh { get; set; } = null!;

    public bool Active { get; set; }

    public virtual DmCskcb IdcskcbNavigation { get; set; } = null!;

    public virtual ICollection<QlChanDoanCt> QlChanDoanCt { get; set; } = new List<QlChanDoanCt>();
}
