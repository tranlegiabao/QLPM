namespace QuanLyPhongMach.Models.Requests.HeThong;

public sealed class LienThongNhanVienLuuRequest
{
    public string? ma_lien_thong { get; set; }
    public string? mat_khau { get; set; }
    public string? so_chung_chi_hanh_nghe { get; set; }
    public bool active { get; set; } = true;
}
