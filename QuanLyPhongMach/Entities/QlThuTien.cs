using System;
using System.Collections.Generic;

namespace QuanLyPhongMach.Entities;

public partial class QlThuTien
{
    public long Id { get; set; }

    public long Idcskcb { get; set; }

    public long IdvaoVien { get; set; }

    public string? SoPhieu { get; set; }

    public DateTime? NgayGioThu { get; set; }

    public long? IdnhanVienThu { get; set; }

    public long? IdtaiKhoanThu { get; set; }

    public decimal TongTien { get; set; }

    public decimal TienGiam { get; set; }

    public decimal ThucThu { get; set; }

    public decimal TienMat { get; set; }

    public decimal ChuyenKhoan { get; set; }

    public long? IdnganHang { get; set; }

    public bool DaThu { get; set; }

    public bool DaHuy { get; set; }

    public string? GhiChu { get; set; }

    public virtual DmNhanVien? DmNhanVien { get; set; }

    public virtual DmCskcb IdcskcbNavigation { get; set; } = null!;

    public virtual DmNganHang? IdnganHangNavigation { get; set; }

    public virtual ICollection<QlThuTienCt> QlThuTienCt { get; set; } = new List<QlThuTienCt>();

    public virtual QlVaoVien QlVaoVien { get; set; } = null!;
}
