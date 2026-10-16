namespace QuanLyPhongMach.Entities;

public partial class DmNhomHang
{
    public long Id { get; set; }

    public long Idcskcb { get; set; }

    public string MaNhomHang { get; set; } = null!;

    public string TenNhomHang { get; set; } = null!;

    public string MaLoaiToaThuoc { get; set; } = null!;

    public bool Active { get; set; }

    public virtual DmLoaiToaThuoc DmLoaiToaThuoc { get; set; } = null!;

    public virtual ICollection<DmThuoc> DmThuoc { get; set; } = new List<DmThuoc>();
}
