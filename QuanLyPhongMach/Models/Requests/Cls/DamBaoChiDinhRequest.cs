namespace QuanLyPhongMach.Models.Requests.Cls;

public sealed class DamBaoChiDinhRequest
{
    public long id_vao_vien { get; set; }
    public long id_dich_vu { get; set; }
    public decimal so_luong { get; set; } = 1m;
    public bool gui_ngoai { get; set; }
    public string? noi_gui_ngoai { get; set; }
    public string? ghi_chu { get; set; }
}
