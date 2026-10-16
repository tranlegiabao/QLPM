using System;
using System.Collections.Generic;

namespace QuanLyPhongMach.Entities;

public partial class DmDichVu
{
    public long Id { get; set; }

    public long Idcskcb { get; set; }

    public string MaDichVu { get; set; } = null!;

    public string TenDichVu { get; set; } = null!;

    public byte LoaiDichVu { get; set; }

    public string? DonViTinh { get; set; }

    public decimal DonGia { get; set; }

    public bool ChoPhepGuiNgoai { get; set; }

    public bool Active { get; set; }

    public virtual ICollection<DmPhacDoChiDinh> DmPhacDoChiDinh { get; set; } = new List<DmPhacDoChiDinh>();

    public virtual DmCskcb IdcskcbNavigation { get; set; } = null!;

    public virtual ICollection<QlChiDinhCt> QlChiDinhCt { get; set; } = new List<QlChiDinhCt>();

    public virtual ICollection<QlCongKhamCt> QlCongKhamCt { get; set; } = new List<QlCongKhamCt>();
}
