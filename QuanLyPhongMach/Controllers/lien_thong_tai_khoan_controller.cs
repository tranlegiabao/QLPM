using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuanLyPhongMach.Data;
using QuanLyPhongMach.Entities;
using QuanLyPhongMach.Models.Requests.HeThong;
using QuanLyPhongMach.Services;
using QuanLyPhongMach.Services.ToaThuocQuocGia;

namespace QuanLyPhongMach.Controllers;

[Authorize]
public sealed class lien_thong_tai_khoan_controller : ControllerBase
{
    private readonly QlpmDbContext _db;
    private readonly ILienThongCredentialProtector _protector;
    public lien_thong_tai_khoan_controller(QlpmDbContext db, ILienThongCredentialProtector protector)
    { _db = db; _protector = protector; }

    [HttpGet("/api/he_thong/cskcb/{id:long}/lien-thong")]
    public async Task<IActionResult> Cskcb(long id, CancellationToken ct)
    {
        if (!User.IsInRole("quan_tri_he_thong")) return Forbid();
        if (!await _db.DmCskcb.AnyAsync(x => x.Id == id, ct)) return NotFound();
        var config = await _db.HtLienThongToaThuocCauHinh.AsNoTracking().SingleOrDefaultAsync(x => x.Idcskcb == id, ct);
        return Ok(new { status = 200, data = new { ma_lien_thong = config?.MaLienThongCskcb,
            da_cau_hinh_mat_khau = !string.IsNullOrEmpty(config?.MatKhauCskcbMaHoa), hieu_luc = config?.LienThongHieuLuc ?? false } });
    }

    [HttpPost("/api/he_thong/cskcb/{id:long}/lien-thong")]
    public async Task<IActionResult> LuuCskcb(long id, [FromBody] LienThongCskcbLuuRequest request, CancellationToken ct)
    {
        if (!User.IsInRole("quan_tri_he_thong")) return Forbid();
        // Admin may update the linked configuration while the CSKCB is inactive.
        if (!await _db.DmCskcb.AnyAsync(x => x.Id == id, ct)) return NotFound();
        if ((request.ma_lien_thong?.Length ?? 0) > 100 || (request.mat_khau?.Length ?? 0) > 500)
            return BadRequest(new { status = 400, message = "Mã hoặc mật khẩu liên thông quá dài." });
        var config = await _db.HtLienThongToaThuocCauHinh.SingleOrDefaultAsync(x => x.Idcskcb == id, ct);
        if (config == null) { config = new() { Idcskcb = id }; _db.HtLienThongToaThuocCauHinh.Add(config); }
        var password = string.IsNullOrWhiteSpace(request.mat_khau) ? config.MatKhauCskcbMaHoa : _protector.Protect(request.mat_khau);
        if (request.hieu_luc && (string.IsNullOrWhiteSpace(request.ma_lien_thong) || string.IsNullOrEmpty(password)))
            return BadRequest(new { status = 400, message = "Nhập mã và mật khẩu cơ sở trước khi bật liên thông." });
        config.MaLienThongCskcb = request.ma_lien_thong?.Trim(); config.MatKhauCskcbMaHoa = password;
        config.LienThongHieuLuc = request.hieu_luc; config.HieuLuc = config.KySoHieuLuc && request.hieu_luc;
        config.NgayCapNhat = DateTime.Now; config.IdtaiKhoanCapNhat = User.LayIdTaiKhoan();
        Audit(id, "LUU_TAI_KHOAN_LIEN_THONG_CSKCB");
        await _db.SaveChangesAsync(ct);
        return Ok(new { status = 200, message = "Đã lưu tài khoản liên thông của cơ sở." });
    }

    [yeu_cau_quyen_attribute("he_thong_nhan_vien", "Xem")]
    [HttpGet("/api/he_thong/nhan_vien/{id:long}/lien-thong")]
    public async Task<IActionResult> NhanVien(long id, [FromQuery] long? id_cskcb, CancellationToken ct)
    {
        var tenant = Tenant(id_cskcb);
        if (tenant <= 0) return Conflict(new { status = 409, message = "Chọn cơ sở KCB." });
        if (!await DoctorExists(id, tenant, ct)) return NotFound(new { status = 404, message = "Bác sĩ không thuộc cơ sở này." });
        var config = await _db.HtLienThongToaThuocBacSi.AsNoTracking().SingleOrDefaultAsync(x => x.Idcskcb == tenant && x.IdnhanVien == id, ct);
        return Ok(new { status = 200, data = new { ma_lien_thong = config?.MaLienThong,
            so_chung_chi_hanh_nghe = config?.SoChungChiHanhNghe,
            da_cau_hinh_mat_khau = !string.IsNullOrEmpty(config?.MatKhauMaHoa), active = config?.Active ?? true } });
    }

    [yeu_cau_quyen_attribute("he_thong_nhan_vien", "Sua")]
    [HttpPost("/api/he_thong/nhan_vien/{id:long}/lien-thong")]
    public async Task<IActionResult> LuuNhanVien(long id, [FromQuery] long? id_cskcb,
        [FromBody] LienThongNhanVienLuuRequest request, CancellationToken ct)
    {
        var tenant = Tenant(id_cskcb);
        if (tenant <= 0) return Conflict(new { status = 409, message = "Chọn cơ sở KCB." });
        if (!await DoctorExists(id, tenant, ct)) return NotFound(new { status = 404, message = "Bác sĩ không thuộc cơ sở này." });
        if ((request.ma_lien_thong?.Length ?? 0) > 100 || (request.mat_khau?.Length ?? 0) > 500 || (request.so_chung_chi_hanh_nghe?.Length ?? 0) > 100)
            return BadRequest(new { status = 400, message = "Thông tin tài khoản liên thông quá dài." });
        var config = await _db.HtLienThongToaThuocBacSi.SingleOrDefaultAsync(x => x.Idcskcb == tenant && x.IdnhanVien == id, ct);
        if (config == null) { config = new() { Idcskcb = tenant, IdnhanVien = id }; _db.HtLienThongToaThuocBacSi.Add(config); }
        var code = request.ma_lien_thong?.Trim();
        if (!string.Equals(config.MaLienThong, code, StringComparison.Ordinal)) config.DaDangKy = false;
        config.MaLienThong = code; config.SoChungChiHanhNghe = request.so_chung_chi_hanh_nghe?.Trim();
        if (!string.IsNullOrWhiteSpace(request.mat_khau)) config.MatKhauMaHoa = _protector.Protect(request.mat_khau);
        config.Active = request.active; config.NgayCapNhat = DateTime.Now; config.IdtaiKhoanCapNhat = User.LayIdTaiKhoan();
        Audit(tenant, "LUU_TAI_KHOAN_LIEN_THONG_BAC_SI");
        await _db.SaveChangesAsync(ct);
        return Ok(new { status = 200, message = "Đã lưu tài khoản liên thông của bác sĩ tại cơ sở." });
    }

    private long Tenant(long? requested) => User.IsInRole("quan_tri_he_thong") ? requested.GetValueOrDefault(User.LayIdCskcb()) : User.LayIdCskcb();
    private Task<bool> DoctorExists(long id, long tenant, CancellationToken ct) => _db.DmNhanVienCskcb.AnyAsync(x => x.Idcskcb == tenant
        && x.IdnhanVien == id && x.Active && x.IdnhanVienNavigation.Active && x.IdnhanVienNavigation.LaBacSi, ct);
    private void Audit(long tenant, string action) => _db.QlToaThuocAudit.Add(new QlToaThuocAudit {
        Idcskcb = tenant, HanhDong = action, IdtaiKhoan = User.LayIdTaiKhoan(),
        IdnhanVien = User.LayIdNhanVien() > 0 ? User.LayIdNhanVien() : null, NgayTao = DateTime.Now
    });
}
