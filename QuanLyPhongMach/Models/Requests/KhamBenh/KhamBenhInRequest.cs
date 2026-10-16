namespace QuanLyPhongMach.Models.Requests.KhamBenh;

public sealed class KhamBenhInRequest
{
    public string? nguon { get; set; }
    public long id_vao_vien { get; set; }
    public long? id_toa_thuoc { get; set; }
    public bool gop_chi_dinh { get; set; }
    // Chi dung cho preview/ky so tung loai phieu chi dinh; null giu in day du.
    public bool? gui_ngoai_chi_dinh { get; set; }
    public bool ky_so { get; set; }
    public string? ho_ten { get; set; }
    public DateTime? ngay_sinh { get; set; }
    public byte? id_gioi_tinh { get; set; }
    public string? trieu_chung { get; set; }
    public DateTime? ngay_tai_kham { get; set; }
    public string? dan_do { get; set; }
    public List<KhamBenhInSinhHieuRequest> sinh_hieu { get; set; } = new();
    public List<KhamBenhInChanDoanRequest> chan_doan { get; set; } = new();
    public List<KhamBenhInChiDinhRequest> chi_dinh { get; set; } = new();
    public List<KhamBenhInToaThuocRequest> toa_thuoc { get; set; } = new();
}
