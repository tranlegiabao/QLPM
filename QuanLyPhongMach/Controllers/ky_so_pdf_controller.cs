using System.Security.Cryptography;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuanLyPhongMach.Data;
using QuanLyPhongMach.Models.Requests.KhamBenh;
using QuanLyPhongMach.Services;
using QuanLyPhongMach.Services.Printing;
using QuanLyPhongMach.Services.KySoPdf;
using QuanLyPhongMach.Services.ToaThuocQuocGia;

namespace QuanLyPhongMach.Controllers;

public sealed class KySoPdfXemTruocRequest
{
    public long id_vao_vien { get; set; }
    public long? id_toa_thuoc { get; set; }
    public bool? gui_ngoai { get; set; }
    public string? loai_tai_lieu { get; set; }
}

/// <summary>
/// Xem nguồn và ký PDF từ hồ sơ đã lưu. Xem trước không gọi dịch vụ ký;
/// thao tác ký kiểm tra bác sĩ sở hữu và lưu artifact qua STO riêng.
/// </summary>
[yeu_cau_quyen_attribute("kham_benh", "Xem")]
[Route("api/ky_so_pdf")]
public sealed class ky_so_pdf_controller : Controller
{
    private readonly QlpmDbContext _db;
    private readonly IKhamBenhPrintService _printService;
    private readonly ILogger<ky_so_pdf_controller> _logger;
    private readonly PdfKySoPreviewStore _previews;
    private readonly KySoPdfService _signing;
    private readonly QlpmDocumentStorage _storage;

    public ky_so_pdf_controller(
        QlpmDbContext db, IKhamBenhPrintService printService, ILogger<ky_so_pdf_controller> logger,
        PdfKySoPreviewStore previews, KySoPdfService signing, QlpmDocumentStorage storage)
    {
        _db = db;
        _printService = printService;
        _logger = logger;
        _previews = previews;
        _signing = signing;
        _storage = storage;
    }

    [HttpPost("xem-truoc")]
    public async Task<IActionResult> XemTruoc([FromBody] KySoPdfXemTruocRequest? request)
    {
        if (request == null || request.id_vao_vien <= 0 ||
            request.loai_tai_lieu is not ("toa_thuoc" or "chi_dinh"))
            return BadRequest(new { status = 400, message = "Thiếu lượt khám hoặc loại tài liệu." });

        // Xem PDF khác với ký số: quyền xem hồ sơ chỉ giới hạn trong CSKCB.
        // Chỉ API ký số thật mới buộc đúng bác sĩ sở hữu tài liệu.
        if (!User.CoQuyen("kham_benh", "Xem"))
            return Forbid();

        var idCskcb = User.LayIdCskcb();
        var idNhanVien = User.LayIdNhanVien();
        if (idCskcb <= 0)
            return StatusCode(403, new { status = 403, message = "Phải chọn cơ sở KCB trước khi xem PDF." });

        var visit = await _db.QlVaoVien.AsNoTracking()
            .Where(x => x.Idcskcb == idCskcb && x.Id == request.id_vao_vien && x.Active)
            .Select(x => new { x.Id, x.PhienBanLamSang, x.IdbacSiKham })
            .SingleOrDefaultAsync();
        if (visit == null)
            return NotFound(new { status = 404, message = "Không tìm thấy lượt khám tại cơ sở hiện tại." });
        // Bản PDF nguồn xem trước được phép lấy từ hồ sơ đã lưu dù chưa kết thúc khám.
        // API ký số thật kiểm tra chủ sở hữu và các dòng đã lưu.
        if (request.loai_tai_lieu == "chi_dinh" && !request.gui_ngoai.HasValue)
            return BadRequest(new { status = 400, message = "Phải chọn phiếu chỉ định nội bộ hoặc gửi ngoài trước khi xem PDF." });

        if(request.loai_tai_lieu=="toa_thuoc" && !request.id_toa_thuoc.HasValue)
        {
            var heads=await _db.QlToaThuoc.AsNoTracking().Where(x=>x.Idcskcb==idCskcb && x.IdvaoVien==visit.Id
                && x.ChiTiet.Any(d=>d.Active)).Select(x=>x.Id).ToListAsync();
            if(heads.Count!=1)return BadRequest(new { status=400,message="Chọn một toa thuốc đã lưu để xem và ký PDF." });
            request.id_toa_thuoc=heads[0];
        }
        if (request.id_toa_thuoc.HasValue)
        {
            var isOwned = await _db.QlToaThuoc.AsNoTracking()
                .AnyAsync(x => x.Id == request.id_toa_thuoc.Value && x.IdvaoVien == request.id_vao_vien
                    && x.Idcskcb == idCskcb);
            if (!isOwned) return NotFound(new { status = 404, message = "Không tìm thấy toa thuốc trong lượt khám của cơ sở hiện tại." });
        }

        try
        {
            var source = new KhamBenhInRequest
            {
                nguon = "da_luu",
                ky_so = true,
                id_vao_vien = request.id_vao_vien,
                id_toa_thuoc = request.loai_tai_lieu == "toa_thuoc" ? request.id_toa_thuoc : null,
                gop_chi_dinh = false,
                gui_ngoai_chi_dinh = request.loai_tai_lieu == "chi_dinh"
                    ? request.gui_ngoai : null
            };
            var pdf = request.loai_tai_lieu == "toa_thuoc"
                ? await _printService.InToaThuocAsync(source, idCskcb, idNhanVien)
                : await _printService.InChiDinhAsync(source, idCskcb, idNhanVien);
            if (pdf.Content.Length == 0 || pdf.Content.Length > 10 * 1024 * 1024)
                return BadRequest(new { status = 400, message = "PDF nguồn không hợp lệ hoặc vượt 10 MB." });

            Response.Headers["X-QLPM-PDF-Da-Ky"] = "false";
            Response.Headers["X-QLPM-PDF-SHA256"] = Convert.ToHexString(SHA256.HashData(pdf.Content)).ToLowerInvariant();
            // Hệ tọa độ PDF: gốc ở góc trái dưới. Chỉ là vị trí mẫu, chưa ký.
            var mauKy = await _db.LayMotDongStoAsync("dbo.STO_QL_KySoPdf_Mau_Lay", new
            {
                IDCSKCB = idCskcb,
                MaLoai = request.loai_tai_lieu
            });
            var viTri = mauKy as IDictionary<string, object?>;
            if (viTri == null || !viTri.TryGetValue("rect", out var rect) || rect is not string rectText)
                return StatusCode(503, new { status = 503, message = "Thiếu mẫu ký PDF. Chạy migration v107 trước." });
            Response.Headers["X-QLPM-Khung-Ky"] = rectText;
            if (viTri.TryGetValue("trang_ky", out var trang) && trang != null)
                Response.Headers["X-QLPM-Trang-Ky"] = Convert.ToString(trang);
            Response.Headers["Cache-Control"] = "no-store";
            var revisionAfter=await _db.QlVaoVien.Where(x=>x.Idcskcb==idCskcb && x.Id==visit.Id).Select(x=>x.PhienBanLamSang).SingleAsync();
            if(revisionAfter!=visit.PhienBanLamSang)return Conflict(new { status=409,message="Hồ sơ vừa thay đổi; mở lại bản PDF." });
            var ticket=_previews.Add(new(idCskcb,visit.Id,request.loai_tai_lieu=="toa_thuoc"?request.id_toa_thuoc:null,
                request.loai_tai_lieu,request.loai_tai_lieu=="chi_dinh"?(byte)(request.gui_ngoai==true?1:0):null,
                visit.PhienBanLamSang,User.LayIdTaiKhoan(),idNhanVien,pdf.Content,KySoPdfService.Hash(pdf.Content)));
            Response.Headers["X-QLPM-Ban-Xem"] = ticket;
            var owner=request.loai_tai_lieu=="toa_thuoc"
                ? await _db.QlToaThuoc.Where(x=>x.Id==request.id_toa_thuoc && x.Idcskcb==idCskcb).Select(x=>x.IdbacSiKe).SingleAsync()
                : visit.IdbacSiKham;
            Response.Headers["X-QLPM-Co-The-Ky"] = !User.IsInRole("quan_tri_he_thong") && idNhanVien>0 && owner==idNhanVien
                && User.CoQuyen(request.loai_tai_lieu=="toa_thuoc"?"lien_thong_toa_thuoc":"kham_benh","Sua")?"true":"false";
            return File(pdf.Content, "application/pdf");
        }
        catch (KhamBenhPrintValidationException ex)
        {
            return BadRequest(new { status = 400, message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Không tạo được PDF nguồn để xem trước cho lượt khám {IdVaoVien}.", request.id_vao_vien);
            return StatusCode(500, new { status = 500, message = "Không thể xem trước PDF. Vui lòng thử lại." });
        }
    }

    [HttpGet("ho-so")]
    public async Task<IActionResult> HoSo(long id_vao_vien,CancellationToken ct)
    {
        var tenant=User.LayIdCskcb();
        if(!await _db.QlVaoVien.AnyAsync(x=>x.Idcskcb==tenant && x.Id==id_vao_vien && x.Active,ct))return NotFound();
        var heads=await _db.QlToaThuoc.AsNoTracking().Where(x=>x.Idcskcb==tenant && x.IdvaoVien==id_vao_vien && x.ChiTiet.Any(d=>d.Active))
            .OrderBy(x=>x.NgayKe).Select(x=>new { id=x.Id,ma=x.MaToaQuocGia,loai=x.MaLoaiToaThuoc,ngay=x.NgayKe }).ToListAsync(ct);
        var documents=await _db.LayDanhSachStoAsync("dbo.STO_QL_KySoPdf_TaiLieu_DanhSach",new { IDCSKCB=tenant,IDVaoVien=id_vao_vien });
        return Ok(new { status=200,data=new { toa_thuoc=heads,tai_lieu=documents } });
    }

    public sealed class KyRequest { public string? ma_ban_xem { get; set; } }
    public sealed class KyToanBoRequest { public long id_vao_vien { get; set; } public string? loai_tai_lieu { get; set; } }
    [HttpPost("ky-toan-bo")]
    public async Task<IActionResult> KyToanBo([FromBody] KyToanBoRequest? request,CancellationToken ct)
    {
        if(request==null || request.id_vao_vien<=0 || request.loai_tai_lieu is not ("toa_thuoc" or "chi_dinh"))
            return BadRequest(new { status=400,message="Thiếu lượt khám hoặc loại tài liệu ký." });
        if(User.IsInRole("quan_tri_he_thong"))return StatusCode(403,new { status=403,message="Quản trị không được ký thay bác sĩ." });
        try
        {
            var result=await _signing.KyToanBoAsync(request.id_vao_vien,request.loai_tai_lieu,User.LayIdCskcb(),User.LayIdTaiKhoan(),User.LayIdNhanVien(),ct);
            if(result.TrangThai!="DA_KY")return Conflict(new { status=409,message="Hồ sơ thay đổi trong lúc ký; bản ký đã hết hiệu lực. Kiểm tra và ký lại hồ sơ hiện tại." });
            Response.Headers["Cache-Control"]="no-store";
            return Ok(new { status=200,message="Đã có PDF ký số hợp lệ.",data=new { id_tai_lieu=result.IdTaiLieu,url_pdf=$"/api/ky_so_pdf/tai-lieu/{result.IdTaiLieu}" } });
        }
        catch(ToaThuocInteroperabilityException ex){return StatusCode(ex.StatusCode,new { status=ex.StatusCode,message=ex.Message });}
        catch(KhamBenhPrintValidationException ex){return UnprocessableEntity(new { status=422,message=ex.Message });}
        catch(Exception ex){_logger.LogError(ex,"Không hoàn tất ký toàn bộ PDF lượt {Visit}.",request.id_vao_vien);return StatusCode(500,new { status=500,message="Không hoàn tất ký PDF. Kiểm tra lịch sử trước khi thử lại." });}
    }
    [HttpPost("ky")]
    public async Task<IActionResult> Ky([FromBody] KyRequest? request,CancellationToken ct)
    {
        if(request?.ma_ban_xem is not { Length:32 })return BadRequest(new { status=400,message="Mở PDF nguồn trước khi ký." });
        if(User.IsInRole("quan_tri_he_thong"))return StatusCode(403,new { status=403,message="Quản trị không được ký thay bác sĩ." });
        try
        {
            var result=await _signing.KyAsync(request.ma_ban_xem,User.LayIdCskcb(),User.LayIdTaiKhoan(),User.LayIdNhanVien(),ct);
            return Ok(new { status=200,message=result.TrangThai=="DA_KY"?"Đã ký PDF và lưu tài liệu.":"Đã lưu PDF ký nhưng hồ sơ vừa thay đổi; bản ký đã hết hiệu lực.",
                data=new { id_tai_lieu=result.IdTaiLieu,trang_thai=result.TrangThai,url_pdf=$"/api/ky_so_pdf/tai-lieu/{result.IdTaiLieu}" } });
        }
        catch(ToaThuocInteroperabilityException ex){return StatusCode(ex.StatusCode,new { status=ex.StatusCode,message=ex.Message });}
        catch(Exception ex){_logger.LogError(ex,"Không hoàn tất ký PDF.");return StatusCode(500,new { status=500,message="Không hoàn tất ghi kết quả ký. Kiểm tra lịch sử trước khi thử lại." });}
    }
    [HttpGet("tai-lieu/{id:long}")]
    public async Task<IActionResult> TaiLieu(long id)
    {
        var row=await _db.LayMotDongStoAsync("dbo.STO_QL_KySoPdf_TaiLieu_Lay",new { IDCSKCB=User.LayIdCskcb(),ID=id });
        var data=row as IDictionary<string,object?>;
        if(data==null || !data.TryGetValue("PdfDaKy",out var value) || value is not byte[] pdf)return NotFound();
        pdf=await _storage.ReadSignedPdfAsync(User.LayIdCskcb(),KySoPdfService.Hash(pdf),pdf,HttpContext.RequestAborted);
        Response.Headers["Cache-Control"]="no-store";Response.Headers["X-QLPM-PDF-Da-Ky"]="true";
        Response.Headers["X-QLPM-PDF-Trang-Thai"]=Convert.ToString(data["TrangThai"]);
        return File(pdf,"application/pdf");
    }
}
