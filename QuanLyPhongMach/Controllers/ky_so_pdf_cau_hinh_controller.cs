using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuanLyPhongMach.Data;
using QuanLyPhongMach.Services;
using QuanLyPhongMach.Services.KySoPdf;
using QuanLyPhongMach.Services.ToaThuocQuocGia;

namespace QuanLyPhongMach.Controllers;

[Authorize(Roles="quan_tri_he_thong")]
public sealed class ky_so_pdf_cau_hinh_controller : ControllerBase
{
    private readonly QlpmDbContext _db;
    public ky_so_pdf_cau_hinh_controller(QlpmDbContext db)=>_db=db;
    [HttpGet("/api/he_thong/cskcb/{id:long}/ky-so-pdf")]
    public async Task<IActionResult> Lay(long id,CancellationToken ct)
    {
        var facility=await _db.DmCskcb.AsNoTracking().Where(x=>x.Id==id).Select(x=>new { x.MaCskcb }).SingleOrDefaultAsync(ct);
        if(facility==null)return NotFound();
        var config=await _db.HtLienThongToaThuocCauHinh.AsNoTracking().SingleOrDefaultAsync(x=>x.Idcskcb==id,ct);
        return Ok(new { status=200,data=new { ma_cskcb=facility.MaCskcb,hieu_luc=config?.KySoHieuLuc??false,url_ky_pdf=config?.UrlKyPdf } });
    }
    public sealed class ConfigRequest { public bool hieu_luc { get; set; } public string? url_ky_pdf { get; set; } }
    [HttpPost("/api/he_thong/cskcb/{id:long}/ky-so-pdf")]
    public async Task<IActionResult> Luu(long id,[FromBody] ConfigRequest? request)
    {
        var url=request?.url_ky_pdf?.Trim();
        if(request==null || (url?.Length??0)>500 || (!string.IsNullOrEmpty(url) &&
            (!Uri.TryCreate(url,UriKind.Absolute,out var uri) || uri.Scheme!=Uri.UriSchemeHttps || !string.IsNullOrEmpty(uri.UserInfo))))
            return BadRequest(new { status=400,message="URL ký PDF phải là HTTPS hợp lệ, không chứa tài khoản/mật khẩu." });
        try
        {
            await KySoPdfService.Business(()=>_db.ThucThiStoAsync("dbo.STO_QL_KySoPdf_CauHinh_Luu",new {
                IDCSKCB=id,IDTaiKhoan=User.LayIdTaiKhoan(),HieuLuc=request.hieu_luc,UrlKyPdf=url
            }));
            return Ok(new { status=200,message="Đã lưu cấu hình ký PDF của CSKCB." });
        }
        catch(ToaThuocInteroperabilityException ex){return StatusCode(ex.StatusCode,new { status=ex.StatusCode,message=ex.Message });}
    }
}
