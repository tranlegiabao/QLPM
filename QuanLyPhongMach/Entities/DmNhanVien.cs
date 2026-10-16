using System;
using System.Collections.Generic;

namespace QuanLyPhongMach.Entities;

public partial class DmNhanVien
{
    public long Id { get; set; }

    public string MaNhanVien { get; set; } = null!;

    public string HoTen { get; set; } = null!;

    public bool LaBacSi { get; set; }

    public long? IdchucDanh { get; set; }

    public string? DienThoai { get; set; }

    public string? SoNhaTenDuong { get; set; }

    public string? DiaChi { get; set; }

    public string? MaTinh { get; set; }

    public string? MaPhuongXa { get; set; }

    public string? Email { get; set; }

    public bool Active { get; set; }

    public virtual DmChucDanh? IdchucDanhNavigation { get; set; }

    public virtual ICollection<DmNhanVienCskcb> DmNhanVienCskcb { get; set; } = new List<DmNhanVienCskcb>();

    public virtual ICollection<QlChanDoanCt> QlChanDoanCt { get; set; } = new List<QlChanDoanCt>();

    public virtual ICollection<QlChiDinhCt> QlChiDinhCt { get; set; } = new List<QlChiDinhCt>();

    public virtual ICollection<QlCongKham> QlCongKham { get; set; } = new List<QlCongKham>();

    public virtual ICollection<QlPhieuSinhHieu> QlPhieuSinhHieu { get; set; } = new List<QlPhieuSinhHieu>();

    public virtual ICollection<QlThuTien> QlThuTien { get; set; } = new List<QlThuTien>();

    public virtual ICollection<QlToaThuocCt> QlToaThuocCt { get; set; } = new List<QlToaThuocCt>();

    public virtual ICollection<QlVaoVien> QlVaoVienDmNhanVien { get; set; } = new List<QlVaoVien>();

    public virtual ICollection<QlVaoVien> QlVaoVienDmNhanVienNavigation { get; set; } = new List<QlVaoVien>();
}
