namespace QuanLyPhongMach.Models.Printing.KhamBenh;

public sealed class KhamBenhPrintChiDinhPage
{
    public bool GuiNgoai { get; set; }
    public DateTime NgayLap { get; set; }
    public List<KhamBenhPrintChiDinhDong> DichVu { get; set; } = new();
    public decimal TongTien { get; set; }
}
