namespace QuanLyPhongMach.Models.Requests.KhamBenh;

public sealed class KhamBenhInChiDinhRequest
{
    public long IDDichVu { get; set; }
    public DateTime? NgayGioChiDinh { get; set; }
    public decimal SoLuong { get; set; }
    public bool GuiNgoai { get; set; }
    public string? NoiGuiNgoai { get; set; }
    public string? GhiChu { get; set; }
}
