using System.Collections.Generic;

namespace QuanLyPhongMach.Entities;

public partial class DmChucDanh
{
    public long Id { get; set; }
    public string MaChucDanh { get; set; } = null!;
    public string TenChucDanh { get; set; } = null!;
    public string? VietTat { get; set; }
    public bool Active { get; set; }

    public virtual ICollection<DmNhanVien> DmNhanVien { get; set; } = new List<DmNhanVien>();
}
