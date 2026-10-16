namespace QuanLyPhongMach.Entities;

public partial class DmLoaiToaThuoc
{
    public string MaLoaiToaThuoc { get; set; } = null!;

    public string TenLoaiToaThuoc { get; set; } = null!;

    public bool Active { get; set; }

    public virtual ICollection<DmNhomHang> DmNhomHang { get; set; } = new List<DmNhomHang>();

    public virtual ICollection<QlToaThuocCt> QlToaThuocCt { get; set; } = new List<QlToaThuocCt>();
}
