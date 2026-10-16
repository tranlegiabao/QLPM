namespace QuanLyPhongMach.Models.Requests.Kho;

public sealed class NhaCungCapLuuRequest
{
    public long id { get; set; }
    public string? ma { get; set; }
    public string? ten { get; set; }
    public string? ma_so_thue { get; set; }
    public string? dien_thoai { get; set; }
    public string? dia_chi { get; set; }
    public bool active { get; set; } = true;
}
