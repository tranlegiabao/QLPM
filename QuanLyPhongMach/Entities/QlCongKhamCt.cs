using System;
using System.Collections.Generic;

namespace QuanLyPhongMach.Entities;

public partial class QlCongKhamCt
{
    public long Id { get; set; }

    public long Idcskcb { get; set; }

    public long IdcongKham { get; set; }

    public long IddichVu { get; set; }

    public decimal SoLuong { get; set; }

    public decimal DonGia { get; set; }

    public decimal ThanhTien { get; set; }

    public string? GhiChu { get; set; }

    public bool Active { get; set; }

    public virtual DmDichVu DmDichVu { get; set; } = null!;

    public virtual DmCskcb IdcskcbNavigation { get; set; } = null!;

    public virtual QlCongKham QlCongKham { get; set; } = null!;

    public virtual ICollection<QlThuTienCt> QlThuTienCt { get; set; } = new List<QlThuTienCt>();
}
