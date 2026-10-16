namespace QuanLyPhongMach.Models.Requests.Kho;

public sealed class NhapKhoRequest
{
    public long id_kho { get; set; }
    public long? id_nha_cung_cap { get; set; }
    public string? so_hoa_don { get; set; }
    public DateTime? ngay_hoa_don { get; set; }
    public string? ghi_chu { get; set; }
    public List<NhapKhoDongRequest> danh_sach { get; set; } = new();
}
