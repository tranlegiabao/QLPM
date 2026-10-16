namespace QuanLyPhongMach.Models.Requests.KhamBenh;

public sealed class KiemTraTonThuocDongRequest
{
    public int row_index { get; set; }
    public long id_thuoc { get; set; }
    public long? id_don_vi_tinh { get; set; }
    public decimal so_luong { get; set; }
}
