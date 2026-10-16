using System.Collections.Generic;

namespace QuanLyPhongMach.Entities;

public partial class DmGioiTinh
{
    public byte Id { get; set; }

    public string MaGioiTinh { get; set; } = null!;

    public string TenGioiTinh { get; set; } = null!;

    public int ThuTu { get; set; }

    public bool Active { get; set; }

    public virtual ICollection<QlBenhNhan> QlBenhNhan { get; set; } = new List<QlBenhNhan>();
}
