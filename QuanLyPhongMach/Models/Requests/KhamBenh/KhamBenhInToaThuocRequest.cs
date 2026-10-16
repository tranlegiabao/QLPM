namespace QuanLyPhongMach.Models.Requests.KhamBenh;

public sealed class KhamBenhInToaThuocRequest
{
    public long IDThuoc { get; set; }
    public DateTime NgayKe { get; set; }
    public int? SoNgay { get; set; }
    public string? Sang { get; set; }
    public string? Trua { get; set; }
    public string? Chieu { get; set; }
    public string? Toi { get; set; }
    public string? LieuDung { get; set; }
    public string? CachDung { get; set; }
    public decimal SoLuong { get; set; }
    public long? IDDonViTinhDung { get; set; }
    public string? MaLoaiToaThuoc { get; set; }
}
