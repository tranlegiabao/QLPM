using System;
using System.Collections.Generic;

namespace QuanLyPhongMach.Entities;

public partial class QlBenhNhan
{
    public long Id { get; set; }

    public long Idcskcb { get; set; }

    public string MaBn { get; set; } = null!;

    public string HoTen { get; set; } = null!;

    public DateTime? NgaySinh { get; set; }

    public byte IdgioiTinh { get; set; }

    public string? SoCccd { get; set; }

    public string? DienThoai { get; set; }

    public string? SoNhaTenDuong { get; set; }

    public long? IdphuongXa { get; set; }

    public long? IdtinhThanh { get; set; }

    public string? DiaChi { get; set; }

    public long? IddanToc { get; set; }

    public string? GhiChu { get; set; }

    public bool Active { get; set; }

    public DateTime NgayTao { get; set; }

    public DateTime? NgayCapNhat { get; set; }

    public string? QuocTich { get; set; }

    public string? NgheNghiep { get; set; }

    public string? GiamHoMoiQuanHe { get; set; }

    public string? GiamHoHoTen { get; set; }

    public string? GiamHoDienThoai { get; set; }

    public string? GiamHoSoCccd { get; set; }

    public virtual DmDanToc? DmDanToc { get; set; }

    public virtual DmGioiTinh DmGioiTinh { get; set; } = null!;

    public virtual DmPhuongXa? DmPhuongXa { get; set; }

    public virtual DmTinhThanh? DmTinhThanh { get; set; }

    public virtual DmCskcb IdcskcbNavigation { get; set; } = null!;

    public virtual ICollection<QlVaoVien> QlVaoVien { get; set; } = new List<QlVaoVien>();
}
