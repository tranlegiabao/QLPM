namespace QuanLyPhongMach.Entities;

public partial class DmNhanVienCskcb
{
    public long IdnhanVien { get; set; }
    public long Idcskcb { get; set; }
    public bool Active { get; set; }

    public virtual DmNhanVien IdnhanVienNavigation { get; set; } = null!;
    public virtual DmCskcb IdcskcbNavigation { get; set; } = null!;
}
