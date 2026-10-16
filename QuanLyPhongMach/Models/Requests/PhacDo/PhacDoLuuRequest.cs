namespace QuanLyPhongMach.Models.Requests.PhacDo;

public class PhacDoLuuRequest
{
    public long? id { get; set; }
    public string ma_phac_do { get; set; } = "";
    public string ten_phac_do { get; set; } = "";
    public string? trieu_chung { get; set; }
    public object? chan_doan { get; set; }
    public object? chi_dinh { get; set; }
    public object? thuoc { get; set; }
}
