using System;
using System.Collections.Generic;

namespace QuanLyPhongMach.Entities;

public partial class QlChanDoanCt
{
    public long Id { get; set; }

    public long Idcskcb { get; set; }

    public long IdvaoVien { get; set; }

    public long? Idicd10 { get; set; }

    public string MaBenh { get; set; } = null!;

    public string TenBenh { get; set; } = null!;

    public bool BanDau { get; set; }

    public bool BenhChinh { get; set; }

    public bool BenhKhac { get; set; }

    public int? ThuTu { get; set; }

    public DateTime NgayGioChanDoan { get; set; }

    public long? IdbacSi { get; set; }

    public string? GhiChu { get; set; }

    public virtual DmIcd10? DmIcd10 { get; set; }

    public virtual DmNhanVien? DmNhanVien { get; set; }

    public virtual DmCskcb IdcskcbNavigation { get; set; } = null!;

    public virtual QlVaoVien QlVaoVien { get; set; } = null!;
}
