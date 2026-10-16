namespace QuanLyPhongMach.Models.Printing.KhamBenh;

public sealed class KhamBenhPrintToaPage
{
    public string MaToaThuoc { get; set; } = string.Empty;
    public string MaLoaiToaThuoc { get; set; } = "c";
    public string TieuDe { get; set; } = "ĐƠN THUỐC";
    public DateTime NgayKe { get; set; }
    public string BacSi { get; set; } = string.Empty;
    public List<KhamBenhPrintThuocDong> Thuoc { get; set; } = new();
}
