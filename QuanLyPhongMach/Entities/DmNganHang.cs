using System;
using System.Collections.Generic;

namespace QuanLyPhongMach.Entities;

public partial class DmNganHang
{
    public long Id { get; set; }

    public string MaNganHang { get; set; } = null!;

    public string TenNganHang { get; set; } = null!;

    public bool Active { get; set; }

    public virtual ICollection<DmCskcb> DmCskcb { get; set; } = new List<DmCskcb>();

    public virtual ICollection<QlThuTien> QlThuTien { get; set; } = new List<QlThuTien>();
}
