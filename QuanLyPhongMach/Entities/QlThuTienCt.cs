using System;
using System.Collections.Generic;

namespace QuanLyPhongMach.Entities;

public partial class QlThuTienCt
{
    public long Id { get; set; }

    public long Idcskcb { get; set; }

    public long IdthuTien { get; set; }

    public long? IdcongKhamCt { get; set; }

    public long? IdchiDinhCt { get; set; }

    public long? IdtoaThuocCt { get; set; }

    public decimal SoLuong { get; set; }

    public decimal DonGia { get; set; }

    public decimal ThanhTien { get; set; }

    public decimal PhuThu { get; set; }

    public decimal GiamPhanTram { get; set; }

    public decimal TienGiam { get; set; }

    public decimal ThucThu { get; set; }

    public bool DaThu { get; set; }

    public bool DaHuy { get; set; }

    public DateTime? NgayGioHuy { get; set; }

    public long? IdnhanVienHuy { get; set; }

    public long? IdtaiKhoanHuy { get; set; }

    public virtual DmCskcb IdcskcbNavigation { get; set; } = null!;

    public virtual QlChiDinhCt? QlChiDinhCt { get; set; }

    public virtual QlCongKhamCt? QlCongKhamCt { get; set; }

    public virtual QlThuTien QlThuTien { get; set; } = null!;

    public virtual QlToaThuocCt? QlToaThuocCt { get; set; }
}
