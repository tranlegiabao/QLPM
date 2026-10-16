using System;
using System.Collections.Generic;

namespace QuanLyPhongMach.Entities;

public partial class DmCskcb
{
    public long Id { get; set; }

    public string MaCskcb { get; set; } = null!;

    public string TenCskcb { get; set; } = null!;

    public string? DiaChi { get; set; }

    public string? SoNhaTenDuong { get; set; }

    public string? MaTinh { get; set; }

    public string? MaPhuongXa { get; set; }

    public string? Sdt { get; set; }

    public string? Email { get; set; }

    public string? MaSt { get; set; }

    public string? SoTk { get; set; }

    public long? IdnganHang { get; set; }

    public string? UrlLogo { get; set; }

    public bool Active { get; set; }

    public virtual ICollection<DmDanToc> DmDanToc { get; set; } = new List<DmDanToc>();

    public virtual ICollection<DmDichVu> DmDichVu { get; set; } = new List<DmDichVu>();

    public virtual ICollection<DmDonViTinh> DmDonViTinh { get; set; } = new List<DmDonViTinh>();

    public virtual ICollection<DmIcd10> DmIcd10 { get; set; } = new List<DmIcd10>();

    public virtual ICollection<DmNhanVienCskcb> DmNhanVienCskcb { get; set; } = new List<DmNhanVienCskcb>();

    public virtual ICollection<DmPhacDo> DmPhacDo { get; set; } = new List<DmPhacDo>();

    public virtual ICollection<DmPhuongXa> DmPhuongXa { get; set; } = new List<DmPhuongXa>();

    public virtual ICollection<DmThuoc> DmThuoc { get; set; } = new List<DmThuoc>();

    public virtual ICollection<DmTinhThanh> DmTinhThanh { get; set; } = new List<DmTinhThanh>();

    public virtual ICollection<DmTriSoSinhHieu> DmTriSoSinhHieu { get; set; } = new List<DmTriSoSinhHieu>();

    public virtual DmNganHang? IdnganHangNavigation { get; set; }

    public virtual ICollection<QlBenhNhan> QlBenhNhan { get; set; } = new List<QlBenhNhan>();

    public virtual ICollection<QlChanDoanCt> QlChanDoanCt { get; set; } = new List<QlChanDoanCt>();

    public virtual ICollection<QlChiDinhCt> QlChiDinhCt { get; set; } = new List<QlChiDinhCt>();

    public virtual ICollection<QlCongKham> QlCongKham { get; set; } = new List<QlCongKham>();

    public virtual ICollection<QlCongKhamCt> QlCongKhamCt { get; set; } = new List<QlCongKhamCt>();

    public virtual ICollection<QlPhieuSinhHieu> QlPhieuSinhHieu { get; set; } = new List<QlPhieuSinhHieu>();

    public virtual ICollection<QlPhieuSinhHieuCt> QlPhieuSinhHieuCt { get; set; } = new List<QlPhieuSinhHieuCt>();

    public virtual ICollection<QlThuTien> QlThuTien { get; set; } = new List<QlThuTien>();

    public virtual ICollection<QlThuTienCt> QlThuTienCt { get; set; } = new List<QlThuTienCt>();

    public virtual ICollection<QlToaThuocCt> QlToaThuocCt { get; set; } = new List<QlToaThuocCt>();

    public virtual ICollection<QlVaoVien> QlVaoVien { get; set; } = new List<QlVaoVien>();
}
