using System;
using System.Collections.Generic;

namespace QuanLyPhongMach.Entities;

public partial class DmPhacDo
{
    public long Id { get; set; }

    public long Idcskcb { get; set; }

    public string MaPhacDo { get; set; } = null!;

    public string TenPhacDo { get; set; } = null!;

    public bool Active { get; set; }

    public string? TrieuChung { get; set; }

    public virtual ICollection<DmPhacDoChiDinh> DmPhacDoChiDinh { get; set; } = new List<DmPhacDoChiDinh>();

    public virtual ICollection<DmPhacDoThuoc> DmPhacDoThuoc { get; set; } = new List<DmPhacDoThuoc>();

    public virtual DmCskcb IdcskcbNavigation { get; set; } = null!;

    public virtual ICollection<QlVaoVien> QlVaoVien { get; set; } = new List<QlVaoVien>();
}
