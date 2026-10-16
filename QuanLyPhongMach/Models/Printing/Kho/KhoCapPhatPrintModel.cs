using QuanLyPhongMach.Models.Printing.KhamBenh;

namespace QuanLyPhongMach.Models.Printing.Kho;
public sealed class KhoCapPhatPrintModel
{
    public KhamBenhPrintDocument ThongTin { get; set; }=new();
    public string SoPhieu { get; set; }="";
    public DateTime NgayXuat { get; set; }
    public string GhiChu { get; set; }="";
    public string NguoiXuat { get; set; }="";
    public bool DaHuy { get; set; }
    public List<KhoCapPhatPrintDong> ChiTiet { get; set; }=new();
    public decimal TongTien=>ChiTiet.Sum(x=>x.ThanhTien);
    public bool GiaLegacy=>ChiTiet.Any(x=>x.GiaLegacy);
    public string MaToa { get; set; }="";
    public string BacSi { get; set; }="";
    public DateTime NgayKe { get; set; }
}
public sealed class KhoCapPhatPrintDong
{
    public long IdToaThuocCt {get;set;}
    public string Ten {get;set;}="";
    public string HamLuong {get;set;}="";
    public string HoatChat {get;set;}="";
    public string DonViTinh {get;set;}="";
    public decimal SoLuong {get;set;}
    public decimal DonGia {get;set;}
    public decimal ThanhTien {get;set;}
    public decimal DaHoanCoSo {get;set;}
    public bool GiaLegacy {get;set;}
    public string LieuDung {get;set;}="";
    public string MaToa {get;set;}="";
    public string BacSi {get;set;}="";
    public string LoaiToa {get;set;}="";
    public DateTime NgayKe {get;set;}
}

