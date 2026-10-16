namespace QuanLyPhongMach.Models.Requests.KhamBenh;

public class KhamLuuRequest
{
    public long id_vao_vien { get; set; }
    public string? trieu_chung { get; set; }
    public long? id_phac_do { get; set; }
    public string? ma_pd_goc { get; set; }
    public DateTime? ngay_tai_kham { get; set; }
    public string? dan_do { get; set; }
    public object? sinh_hieu { get; set; }
    public object? chan_doan { get; set; }
    public object? chi_dinh { get; set; }
    public object? toa_thuoc { get; set; }
    public bool? kham_xong { get; set; }
}
