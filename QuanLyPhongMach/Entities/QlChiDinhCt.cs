using System;
using System.Collections.Generic;

namespace QuanLyPhongMach.Entities;

public partial class QlChiDinhCt
{
    public long Id { get; set; }

    public long Idcskcb { get; set; }

    public long IdvaoVien { get; set; }

    public long IddichVu { get; set; }

    public decimal SoLuong { get; set; }

    public decimal DonGia { get; set; }

    public decimal ThanhTien { get; set; }

    public bool GuiNgoai { get; set; }

    public string? NoiGuiNgoai { get; set; }

    public DateTime NgayGioChiDinh { get; set; }

    public long? IdbacSiChiDinh { get; set; }

    public byte TrangThai { get; set; }

    public string? GhiChu { get; set; }

    public string? DuongDanKetQua { get; set; }

    public bool Active { get; set; }

    public virtual DmDichVu DmDichVu { get; set; } = null!;

    public virtual DmNhanVien? DmNhanVien { get; set; }

    public virtual DmCskcb IdcskcbNavigation { get; set; } = null!;

    public virtual ICollection<QlThuTienCt> QlThuTienCt { get; set; } = new List<QlThuTienCt>();

    public virtual QlVaoVien QlVaoVien { get; set; } = null!;
}
