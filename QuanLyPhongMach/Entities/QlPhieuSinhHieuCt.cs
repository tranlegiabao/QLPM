using System;
using System.Collections.Generic;

namespace QuanLyPhongMach.Entities;

public partial class QlPhieuSinhHieuCt
{
    public long Id { get; set; }

    public long Idcskcb { get; set; }

    public long IdphieuSinhHieu { get; set; }

    public long IdtriSoSinhHieu { get; set; }

    public string? GiaTri { get; set; }

    public virtual DmTriSoSinhHieu DmTriSoSinhHieu { get; set; } = null!;

    public virtual DmCskcb IdcskcbNavigation { get; set; } = null!;

    public virtual QlPhieuSinhHieu QlPhieuSinhHieu { get; set; } = null!;
}
