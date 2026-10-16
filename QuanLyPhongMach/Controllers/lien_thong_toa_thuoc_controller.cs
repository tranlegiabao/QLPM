using System.Text.Json.Nodes;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuanLyPhongMach.Data;
using QuanLyPhongMach.Services;
using QuanLyPhongMach.Services.ToaThuocQuocGia;

namespace QuanLyPhongMach.Controllers;

[yeu_cau_quyen_attribute("lien_thong_toa_thuoc", "Xem")]
[Route("lien_thong_toa_thuoc")]
public sealed class lien_thong_toa_thuoc_controller : Controller
{
    private readonly QlpmDbContext _db;
    private readonly IToaThuocReadinessService _readiness;
    private readonly IToaThuocDeliveryService _delivery;
    private readonly ILienThongTrucTiepService _direct;

    public lien_thong_toa_thuoc_controller(
        QlpmDbContext db,
        IToaThuocReadinessService readiness,
        IToaThuocDeliveryService delivery,
        ILienThongTrucTiepService direct)
    {
        _db = db;
        _readiness = readiness;
        _delivery = delivery;
        _direct = direct;
    }

    [HttpGet("")]
    public IActionResult Index()
    {
        ViewData["Title"] = "Liên thông toa thuốc quốc gia";
        ViewBag.CanSend = User.CoQuyen("lien_thong_toa_thuoc", "Sua");
        ViewBag.ActiveTab = "lien_thong_toa_thuoc";
        ViewBag.HienThiThanhPhanHe = false;
        return View("~/Views/lien_thong_toa_thuoc/Index.cshtml");
    }

    [HttpGet("/api/lien_thong_toa_thuoc/danh-sach")]
    public async Task<IActionResult> DanhSach([FromQuery] DateTime? tu_ngay, [FromQuery] DateTime? den_ngay,
        [FromQuery] string? trang_thai, [FromQuery] long? id_bac_si, [FromQuery] string? ma_toa,
        [FromQuery] string? ma_vao_vien, [FromQuery] long? id_vao_vien, [FromQuery] int trang = 1,
        [FromQuery] int kich_thuoc_trang = 25)
        => await ExecuteAsync(async () => {
            var from = (tu_ngay ?? DateTime.Today.AddDays(-7)).Date;
            var to = (den_ngay ?? DateTime.Today).Date;
            if (from > to) return BadRequest(new { status = 400, message = "Từ ngày phải trước hoặc bằng Đến ngày." });
            if (!string.IsNullOrWhiteSpace(trang_thai) && trang_thai is not ("DA_LIEN_THONG" or "CHUA_LIEN_THONG"))
                return BadRequest(new { status = 400, message = "Trạng thái lọc không hợp lệ." });
            var page = Math.Max(1, trang); var size = Math.Clamp(kich_thuoc_trang, 10, 100);
            await using var multi = await _db.QueryMultipleStoAsync("dbo.STO_QL_ToaThuoc_LienThong_DanhSach", new {
                IDCSKCB = User.LayIdCskcb(), TuNgay = from, DenNgay = to, TrangThai = trang_thai,
                IDBacSi = id_bac_si > 0 ? id_bac_si : null, MaToa = ma_toa?.Trim(), MaVaoVien = ma_vao_vien?.Trim(),
                IDVaoVien = id_vao_vien, Trang = page, KichThuocTrang = size
            });
            var total = (IDictionary<string, object?>?)await multi.ReadFirstOrDefaultAsync();
            var rows = await multi.ReadAsync();
            return Ok(new { status = 200, data = rows, tong_so = total?["tong_so"] ?? 0, trang = page, kich_thuoc_trang = size });
        }, requireDoctor: false);

    [HttpGet("/api/lien_thong_toa_thuoc/bac-si")]
    public async Task<IActionResult> BacSi(CancellationToken cancellationToken)
        => await ExecuteAsync(async () => {
            var rows = await (from m in _db.DmNhanVienCskcb.AsNoTracking()
                join n in _db.DmNhanVien.AsNoTracking() on m.IdnhanVien equals n.Id
                where m.Idcskcb == User.LayIdCskcb() && m.Active && n.Active && n.LaBacSi
                orderby n.HoTen select new { id = n.Id, ten = n.HoTen }).ToListAsync(cancellationToken);
            return Ok(new { status = 200, data = rows });
        }, requireDoctor: false);

    [HttpGet("/api/lien_thong_toa_thuoc/{id:long}/kiem-tra")]
    public async Task<IActionResult> KiemTra(long id, CancellationToken cancellationToken)
        => await ExecuteAsync(async () => {
            await _direct.KiemTraAsync(id, User.LayIdCskcb(), User.LayIdTaiKhoan(), User.LayIdNhanVien(), cancellationToken);
            return Ok(new { status = 200, data = new { sanSangLienThong = true, loiLienThong = Array.Empty<string>() } });
        }, requireDoctor: false);

    [HttpGet("/api/lien_thong_toa_thuoc/{id:long}/xem-payload")]
    public async Task<IActionResult> XemPayload(long id, CancellationToken cancellationToken)
        => await ExecuteAsync(async () => {
            var snapshot = await _readiness.TaoPayloadLienThongAsync(id, User.LayIdCskcb(), cancellationToken);
            var node = JsonNode.Parse(snapshot.CanonicalJson)!.AsObject();
            Mask(node, "ma_dinh_danh_y_te", 4);
            Mask(node, "ma_dinh_danh_cong_dan", 4);
            Mask(node, "so_dien_thoai_nguoi_kham_benh", 3);
            return Ok(new { status = 200, data = node, phien_ban_nguon = snapshot.PhienBanNguon });
        }, requireDoctor: false);

    [HttpGet("/api/lien_thong_toa_thuoc/{id:long}/phan-hoi")]
    public async Task<IActionResult> PhanHoi(long id)
        => await ExecuteAsync(async () => {
            if (!await _db.QlToaThuoc.AsNoTracking().AnyAsync(x => x.Id == id && x.Idcskcb == User.LayIdCskcb()))
                return NotFound(new { status = 404, message = "Không tìm thấy toa thuốc." });
            var rows = await _db.LayDanhSachStoAsync("dbo.STO_QL_ToaThuoc_LienThong_PhanHoi", new { IDCSKCB = User.LayIdCskcb(), IDToaThuoc = id });
            return Ok(new { status = 200, data = rows });
        }, requireDoctor: false);

    [yeu_cau_quyen_attribute("lien_thong_toa_thuoc", "Sua")]
    [HttpPost("/api/lien_thong_toa_thuoc/{id:long}/ky-so")]
    public async Task<IActionResult> KySo(long id, CancellationToken cancellationToken)
        => await ExecuteAsync(async () =>
        {
            if (LaQuanTri()) return StatusCode(403, new { status = 403, message = "Quản trị không được ký thay bác sĩ kê đơn." });
            var versionId = await _delivery.KySoAsync(id, User.LayIdCskcb(), User.LayIdNhanVien(), User.LayIdTaiKhoan(), cancellationToken);
            return Ok(new { status = 200, message = "Đã ký số toa thuốc. Toa chưa được liên thông.", data = new { id_phien_ban = versionId } });
        });

    [yeu_cau_quyen_attribute("lien_thong_toa_thuoc", "Sua")]
    [HttpPost("/api/lien_thong_toa_thuoc/{id:long}/lien-thong")]
    public async Task<IActionResult> LienThong(long id, CancellationToken cancellationToken)
        => await ExecuteAsync(async () =>
        {
            var result = await _direct.GuiAsync(id, User.LayIdCskcb(), User.LayIdTaiKhoan(), User.LayIdNhanVien(), cancellationToken);
            return Ok(new { status = 200, message = result.KetQua.Accepted ? "Đã liên thông toa thuốc." : result.KetQua.Error,
                data = new { id_lan_gui = result.IdLanGui, trang_thai = result.TrangThai,
                    http_status = result.KetQua.HttpStatus, phan_hoi = result.KetQua.SanitizedResponse } });
        }, requireDoctor: false);

    [yeu_cau_quyen_attribute("lien_thong_toa_thuoc", "Sua")]
    [HttpPost("/api/lien_thong_toa_thuoc/{id:long}/gui-lai")]
    public Task<IActionResult> GuiLai(long id, CancellationToken cancellationToken) => LienThong(id, cancellationToken);

    [HttpGet("/api/lien_thong_toa_thuoc/{id:long}/phien-ban/{versionId:long}/pdf")]
    public async Task<IActionResult> TaiPdf(long id, long versionId, CancellationToken cancellationToken)
    {
        var idCskcb = User.LayIdCskcb();
        var item = await (
            from version in _db.QlToaThuocPhienBan.AsNoTracking()
            join prescription in _db.QlToaThuoc.AsNoTracking() on version.IdtoaThuoc equals prescription.Id
            where prescription.Id == id && version.Id == versionId && prescription.Idcskcb == idCskcb
            select new { version.PdfDaKy, prescription.MaToaQuocGia }
        ).SingleOrDefaultAsync(cancellationToken);
        if (item == null) return NotFound(new { status = 404, message = "Không tìm thấy PDF đã ký." });
        return File(item.PdfDaKy, "application/pdf", $"toa-{item.MaToaQuocGia}.pdf");
    }

    private static void Mask(JsonObject node, string property, int visibleSuffix)
    {
        var value = node[property]?.GetValue<string>();
        if (string.IsNullOrWhiteSpace(value)) return;
        node[property] = new string('*', Math.Max(0, value.Length - visibleSuffix)) + value[^Math.Min(visibleSuffix, value.Length)..];
    }

    private async Task<IActionResult> ExecuteAsync(Func<Task<IActionResult>> action, bool requireDoctor = true)
    {
        try
        {
            if (User.LayIdCskcb() <= 0)
                return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước khi thao tác." });
            if (requireDoctor && User.LayIdNhanVien() <= 0)
                return StatusCode(403, new { status = 403, message = "Tài khoản không có bác sĩ tại cơ sở đang làm việc." });
            return await action();
        }
        catch (ToaThuocInteroperabilityException ex)
        {
            return StatusCode(ex.StatusCode, new { status = ex.StatusCode, message = ex.Message });
        }
    }

    private bool LaQuanTri()
        => User.IsInRole("quan_tri_he_thong") || User.IsInRole("quan_tri_cskcb");
}
