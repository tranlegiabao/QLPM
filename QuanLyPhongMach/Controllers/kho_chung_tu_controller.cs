using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using WkHtmlToPdfDotNet;
using WkHtmlToPdfDotNet.Contracts;
using QuanLyPhongMach.Data;
using QuanLyPhongMach.Models.Printing.Kho;
using QuanLyPhongMach.Models.Printing.ThuNgan;
using QuanLyPhongMach.Services;

namespace QuanLyPhongMach.Controllers;

[Route("kho")]
public sealed class kho_chung_tu_controller : Controller
{
    private readonly QlpmDbContext _db;
    private readonly IRazorViewRenderer _renderer;
    private readonly IConverter _converter;
    private readonly IWebHostEnvironment _environment;
    private readonly QlpmDocumentStorage _storage;
    public kho_chung_tu_controller(QlpmDbContext db, IRazorViewRenderer renderer, IConverter converter,IWebHostEnvironment environment,QlpmDocumentStorage storage)
    { _db = db; _renderer = renderer; _converter = converter;_environment=environment;_storage=storage; }

    [yeu_cau_quyen_attribute("kho", "Xuat")]
    [HttpGet("phieu-nhap/pdf")]
    public async Task<IActionResult> PhieuNhapPdf([FromQuery] long id)
    {
        if (User.LayIdCskcb() <= 0 || id <= 0) return BadRequest("Thiếu cơ sở hoặc phiếu nhập.");
        var model = await LoadNhap(id);
        if (model == null) return NotFound("Không tìm thấy phiếu nhập tại cơ sở này.");
        var html = await _renderer.RenderAsync("~/Views/kho/PhieuNhap.cshtml", model);
        var doc = new HtmlToPdfDocument
        {
            GlobalSettings = { ColorMode = ColorMode.Color, Orientation = Orientation.Portrait,
                PaperSize = PaperKind.A4, Margins = new MarginSettings { Top = .5, Bottom = 1, Left = .5, Right = .5, Unit = Unit.Centimeters } }
        };
        doc.Objects.Add(new ObjectSettings { HtmlContent = html, PagesCount = true,
            WebSettings = { DefaultEncoding = "utf-8" },
            FooterSettings = { FontSize = 8, Left = "Trang [sitepage]" } });
        Response.Headers["Content-Disposition"] = $"inline; filename=\"{tep_tin_dich_vu.TaoTenTaiXuong("phieu-nhap", model.SoPhieu, "pdf")}\"";
        Response.Headers["X-Content-Type-Options"] = "nosniff";
        return File(_converter.Convert(doc), "application/pdf");
    }

    [yeu_cau_quyen_attribute("kho", "Xuat")]
    [HttpGet("phieu-nhap/excel")]
    public async Task<IActionResult> PhieuNhapExcel([FromQuery] long id)
    {
        if (User.LayIdCskcb() <= 0 || id <= 0) return BadRequest("Thiếu cơ sở hoặc phiếu nhập.");
        var model = await LoadNhap(id);
        if (model == null) return NotFound("Không tìm thấy phiếu nhập tại cơ sở này.");
        Response.Headers["X-Content-Type-Options"] = "nosniff";
        return File(kho_excel.PhieuNhap(model), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            tep_tin_dich_vu.TaoTenTaiXuong("phieu-nhap", model.SoPhieu, "xlsx"));
    }


    [yeu_cau_quyen_attribute("kho_cap_phat","Xuat")]
    [HttpGet("api/phieu-cap")]
    public async Task<IActionResult> PhieuCapDanhSach([FromQuery] long id_vao_vien)
    {
        var tenant=User.LayIdCskcb();
        if(tenant<=0 || id_vao_vien<=0)return BadRequest(new {status=400,message="Thiếu cơ sở hoặc lượt khám."});
        var rows=await _db.LayDanhSachStoAsync("dbo.STO_QL_Kho_PhieuCap_DanhSach",new {IDCSKCB=tenant,IDVaoVien=id_vao_vien});
        return Ok(new {status=200,data=rows});
    }

    [yeu_cau_quyen_attribute("kho_cap_phat","Xuat")]
    [HttpGet("phieu-cap/pdf")]
    public Task<IActionResult> PhieuCapPdf([FromQuery] long id = 0, [FromQuery] long id_vao_vien = 0)
        => PrintCap(id, false, id_vao_vien);

    [yeu_cau_quyen_attribute("kho_cap_phat","Xuat")]
    [HttpGet("don-cap-hai-lien/pdf")]
    public Task<IActionResult> DonCapHaiLienPdf([FromQuery] long id = 0, [FromQuery] long id_vao_vien = 0,
        [FromQuery] long[]? id_toa_thuoc_ct = null)
        => PrintCap(id, true, id_vao_vien, id_toa_thuoc_ct);

    private async Task<IActionResult> PrintCap(long id, bool twoCopies, long visit = 0, long[]? lineIds = null)
    {
        var tenant = User.LayIdCskcb();
        if (tenant <= 0 || (id > 0) == (visit > 0))
            return BadRequest(new {status=400,message="Chọn đúng phiếu cấp phát hoặc lượt khám cần in."});
        if (visit > 0 && twoCopies && (lineIds == null || lineIds.Length == 0 || lineIds.Any(x => x <= 0)))
            return BadRequest(new {status=400,message="Thiếu nhóm thuốc cần in đơn hai liên."});

        var documentIds = new List<long>();
        if (id > 0) documentIds.Add(id);
        else
        {
            // Lấy tất cả phiếu còn hiệu lực của đúng lượt/tenant, không chọn ngầm phiếu mới nhất.
            var rows = await _db.LayDanhSachStoAsync("dbo.STO_QL_Kho_PhieuCap_DanhSach", new { IDCSKCB = tenant, IDVaoVien = visit });
            foreach (var row in rows)
                documentIds.Add(Convert.ToInt64(Value((IDictionary<string,object?>)row, "id")));
        }
        var wantedLines = lineIds?.ToHashSet();
        var models = new List<KhoCapPhatPrintModel>();
        foreach (var documentId in documentIds.Distinct())
        {
            var model = await LoadCap(documentId);
            if (model == null) continue; // Có thể vừa bị hủy sau khi tải danh sách.
            if (model.DaHuy) return Conflict(new {status=409,message="Phiếu cấp phát đã hủy, không được in."});
            if (visit > 0 && twoCopies)
            {
                model.ChiTiet = model.ChiTiet.Where(x => wantedLines!.Contains(x.IdToaThuocCt)).ToList();
                if (model.ChiTiet.Count == 0) continue;
            }
            if (model.ChiTiet.Count == 0 || model.ChiTiet.Any(x => x.SoLuong <= 0))
                return UnprocessableEntity(new {status=422,message="Phiếu thiếu số lượng/quy đổi đã ghi nhận; cần đối chiếu trước khi in."});
            models.Add(model);
        }
        if (models.Count == 0) return NotFound(new {status=404,message="Không có phiếu cấp phát còn hiệu lực cho nhóm thuốc/lượt khám này."});
        var doc=new HtmlToPdfDocument {GlobalSettings={ColorMode=ColorMode.Color,PaperSize=PaperKind.A4,
            Orientation=twoCopies?Orientation.Landscape:Orientation.Portrait,
            Margins=new MarginSettings {Top=.5,Bottom=.5,Left=.5,Right=.5,Unit=Unit.Centimeters}}};
        foreach (var model in models)
        {
            if(twoCopies)
            {
                foreach(var group in model.ChiTiet.GroupBy(x=>new {x.MaToa,x.LoaiToa,Day=x.NgayKe.Date,x.BacSi}))
                {
                    var page=new KhoCapPhatPrintModel {ThongTin=model.ThongTin,SoPhieu=model.SoPhieu,NgayXuat=model.NgayXuat,
                        DaHuy=model.DaHuy,GhiChu=model.GhiChu,NguoiXuat=model.NguoiXuat,ChiTiet=group.ToList(),
                        MaToa=group.Key.MaToa,BacSi=group.Key.BacSi,NgayKe=group.Min(x=>x.NgayKe)};
                    doc.Objects.Add(new ObjectSettings {HtmlContent=await _renderer.RenderAsync("~/Views/kho/DonCapHaiLien.cshtml",page),
                        PagesCount=true,WebSettings={DefaultEncoding="utf-8"}});
                }
            }
            else doc.Objects.Add(new ObjectSettings {HtmlContent=await _renderer.RenderAsync("~/Views/kho/PhieuCapPhat.cshtml",model),
                PagesCount=true,WebSettings={DefaultEncoding="utf-8"},FooterSettings={FontSize=8,Right="[page]/[topage]"}});
        }
        var documentCode = models.Count == 1 ? models[0].SoPhieu : models[0].ThongTin.MaVaoVien;
        Response.Headers["Content-Disposition"]=$"inline; filename=\"{tep_tin_dich_vu.TaoTenTaiXuong(twoCopies?"don-2-lien":"phieu-cap",documentCode,"pdf")}\"";
        Response.Headers["X-Content-Type-Options"]="nosniff";Response.Headers["Cache-Control"]="no-store";
        return File(_converter.Convert(doc),"application/pdf");
    }

    private async Task<KhoCapPhatPrintModel?> LoadCap(long id)
    {
        var tenant=User.LayIdCskcb();
        await using var multi=await _db.QueryMultipleStoAsync("dbo.STO_QL_Kho_PhieuCap_In",new {IDCSKCB=tenant,IDXuat=id});
        var row=await multi.ReadFirstOrDefaultAsync();
        if(row==null)return null;
        var h=(IDictionary<string,object?>)row;
        var lines=await multi.ReadAsync();
        var model=new KhoCapPhatPrintModel {SoPhieu=Text(h,"so_phieu"),NgayXuat=Date(h,"ngay_xuat")!.Value,
            DaHuy=Number(h,"da_huy")==1,GhiChu=Text(h,"ghi_chu"),NguoiXuat=Text(h,"nguoi_xuat")};
        var p=model.ThongTin;
        p.TenCskcb=Text(h,"ten_cskcb");p.DiaChiCskcb=Text(h,"dia_chi_cskcb");p.DienThoaiCskcb=Text(h,"sdt_cskcb");p.EmailCskcb=Text(h,"email_cskcb");
        p.MaBn=Text(h,"ma_bn");p.MaVaoVien=Text(h,"ma_vao_vien");p.HoTen=Text(h,"ho_ten");p.NgaySinh=Date(h,"ngay_sinh");
        p.GioiTinh=Text(h,"gioi_tinh");p.DiaChi=Text(h,"dia_chi");p.DienThoai=Text(h,"dien_thoai");
        p.ChanDoan=Text(h,"chan_doan");p.LoiDan=Text(h,"dan_do");p.NgayTaiKham=Date(h,"ngay_tai_kham");
        p.GiamHoHoTen=Text(h,"giam_ho");p.GiamHoMoiQuanHe=Text(h,"quan_he");
        p.SinhHieu.Add(new() {Ten="Cân nặng",GiaTri=Text(h,"can_nang"),DonViTinh="Kg"});
        p.BarcodeSvg=KhamBenhPrintService.TaoCode128Svg(p.MaVaoVien);
        var logo=Text(h,"url_logo");
        if(!string.IsNullOrWhiteSpace(logo) && !Uri.IsWellFormedUriString(logo,UriKind.Absolute))
        {
            p.LogoDataUri=await _storage.LoadLogoDataUriAsync(logo,HttpContext.RequestAborted);
        }
        foreach(var line in lines)
        {
            var d=(IDictionary<string,object?>)line;
            var unit=Text(d,"don_vi_tinh");
            model.ChiTiet.Add(new() {IdToaThuocCt=Convert.ToInt64(Value(d,"id_toa_thuoc_ct") ?? 0),Ten=Text(d,"ten_thuoc"),HamLuong=Text(d,"ham_luong"),HoatChat=Text(d,"hoat_chat"),DonViTinh=unit,
                SoLuong=Number(d,"so_luong"),DonGia=Number(d,"don_gia"),ThanhTien=Number(d,"thanh_tien"),DaHoanCoSo=Number(d,"da_hoan_co_so"),
                GiaLegacy=Number(d,"gia_legacy")==1,MaToa=Text(d,"ma_toa"),LoaiToa=Text(d,"ma_loai_toa"),BacSi=Text(d,"bac_si"),NgayKe=Date(d,"ngay_ke")!.Value,
                LieuDung=KhamBenhPrintService.TaoLieuDung(Text(d,"duong_dung"),Text(d,"sang"),Text(d,"trua"),Text(d,"chieu"),Text(d,"toi"),unit,Text(d,"cach_dung"),Text(d,"lieu_dung"))});
        }
        return model;
    }

    private async Task<KhoNhapPrintModel?> LoadNhap(long id)
    {
        var tenant = User.LayIdCskcb();
        IDictionary<string, object?> info;
        List<dynamic> lines;
        await using (var multi = await _db.QueryMultipleStoAsync("dbo.STO_QL_Kho_Nhap_ChiTiet", new { IDCSKCB = tenant, IDNhap = id }))
        {
            var row = await multi.ReadFirstOrDefaultAsync();
            if (row == null) return null;
            info = (IDictionary<string, object?>)row;
            lines = (await multi.ReadAsync()).ToList();
        }
        var clinic = await _db.DmCskcb.AsNoTracking().Where(x => x.Id == tenant)
            .Select(x => new { x.TenCskcb, x.DiaChi, x.Sdt, x.Email, x.MaSt, x.SoTk, x.UrlLogo,
                NganHang = x.IdnganHangNavigation == null ? "" : x.IdnganHangNavigation.TenNganHang }).SingleOrDefaultAsync();
        var model = new KhoNhapPrintModel
        {
            CoSo = new ThuNganPrintModel { TenCskcb = clinic?.TenCskcb ?? "", DiaChiCskcb = clinic?.DiaChi ?? "", DienThoaiCskcb = clinic?.Sdt ?? "" },
            SoPhieu = Text(info, "so_phieu"), NgayNhap = Date(info, "ngay_nhap") ?? throw new InvalidOperationException("Phiếu nhập thiếu ngày ghi nhận."),
            SoHoaDon = Text(info, "so_hoa_don"), NgayHoaDon = Date(info, "ngay_hoa_don"),
            NhaCungCap = Text(info, "nha_cung_cap"), GhiChu = Text(info, "ghi_chu"), NguoiNhap = Text(info, "nguoi_nhap"),
            DiaChiNhaCungCap = Text(info, "dia_chi_ncc"), DienThoaiNhaCungCap = Text(info, "dien_thoai_ncc"),
            EmailCskcb = clinic?.Email ?? "", MaSoThueCskcb = clinic?.MaSt ?? "", SoTaiKhoanCskcb = clinic?.SoTk ?? "",
            NganHangCskcb = clinic?.NganHang ?? "",
            DaHuy = Number(info, "da_huy") == 1, LyDoHuy = Text(info, "ly_do_huy"),
            LaLegacy = Number(info, "la_legacy") == 1, TongTien = Number(info, "tong_tien")
        };
        if (!string.IsNullOrWhiteSpace(clinic?.UrlLogo))
            model.LogoDataUri = await _storage.LoadLogoDataUriAsync(clinic.UrlLogo, HttpContext.RequestAborted) ?? "";
        foreach (var row in lines)
        {
            var d = (IDictionary<string, object?>)row;
            model.ChiTiet.Add(new KhoNhapPrintDong
            {
                Ten = Text(d, "ten_thuoc"), Ma = Text(d, "ma_thuoc"), DonViTinh = Text(d, "don_vi_tinh"),
                SoLo = Text(d, "so_lo"), HanDung = Date(d, "han_dung"), SoLuong = Number(d, "so_luong"),
                HeSoQuyDoi = Number(d, "he_so_quy_doi"), SoLuongCoSo = Number(d, "so_luong_co_so"),
                SoLuongTonCoSo = Value(d, "so_luong_ton_co_so") is { } stock ? Convert.ToDecimal(stock) : null,
                GiaNhap = Number(d, "gia_nhap"), ThanhTien = Number(d, "thanh_tien")
            });
        }
        if (model.ChiTiet.Sum(x => x.ThanhTien) != model.TongTien)
            throw new InvalidOperationException("Tổng phiếu nhập không khớp chi tiết; cần đối chiếu trước khi in/xuất.");
        return model;
    }
    private static object? Value(IDictionary<string, object?> d, string key) => d.TryGetValue(key, out var v) && v != DBNull.Value ? v : null;
    private static string Text(IDictionary<string, object?> d, string key) => Convert.ToString(Value(d, key)) ?? "";
    private static decimal Number(IDictionary<string, object?> d, string key) => Convert.ToDecimal(Value(d, key) ?? 0);
    private static DateTime? Date(IDictionary<string, object?> d, string key) => Value(d, key) is { } v ? Convert.ToDateTime(v) : null;
}
