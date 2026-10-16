using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuanLyPhongMach.Data;
using QuanLyPhongMach.Entities;
using QuanLyPhongMach.Models.ToaThuocQuocGia;
using QuanLyPhongMach.Services;
using QuanLyPhongMach.Services.ToaThuocQuocGia;

namespace QuanLyPhongMach.Controllers;

[yeu_cau_quyen_attribute("he_thong_lien_thong_toa_thuoc", "Xem")]
[Route("he_thong/lien_thong_toa_thuoc")]
public sealed class lien_thong_toa_thuoc_cau_hinh_controller : Controller
{
    private readonly QlpmDbContext _db;
    private readonly ILienThongCredentialProtector _protector;
    private readonly IToaThuocSigner _signer;

    public lien_thong_toa_thuoc_cau_hinh_controller(
        QlpmDbContext db,
        ILienThongCredentialProtector protector,
        IToaThuocSigner signer)
    {
        _db = db;
        _protector = protector;
        _signer = signer;
    }

    [HttpGet("/api/he_thong/lien_thong_toa_thuoc/cau-hinh")]
    public async Task<IActionResult> LayCauHinh(CancellationToken cancellationToken)
    {
        var idCskcb = User.LayIdCskcb();
        if (idCskcb <= 0) return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước khi cấu hình." });
        var config = await _db.HtLienThongToaThuocCauHinh.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Idcskcb == idCskcb, cancellationToken);
        var doctors = await (
            from map in _db.DmNhanVienCskcb.AsNoTracking()
            join doctor in _db.DmNhanVien.AsNoTracking() on map.IdnhanVien equals doctor.Id
            join configured in _db.HtLienThongToaThuocBacSi.AsNoTracking()
                on new { map.Idcskcb, map.IdnhanVien } equals new { configured.Idcskcb, configured.IdnhanVien } into configuredJoin
            from configured in configuredJoin.DefaultIfEmpty()
            where map.Idcskcb == idCskcb && map.Active && doctor.Active && doctor.LaBacSi
            orderby doctor.HoTen
            select new
            {
                id_nhan_vien = doctor.Id,
                ma_nhan_vien = doctor.MaNhanVien,
                ho_ten = doctor.HoTen,
                ma_lien_thong = configured != null ? configured.MaLienThong : null,
                so_chung_chi_hanh_nghe = configured != null ? configured.SoChungChiHanhNghe : null,
                active = configured != null && configured.Active,
                da_cau_hinh_mat_khau = configured != null && configured.MatKhauMaHoa != null
            }
        ).ToListAsync(cancellationToken);

        return Ok(new
        {
            status = 200,
            data = new
            {
                moi_truong = config?.MoiTruong ?? "TEST",
                che_do_tich_hop = "LIVE",
                cho_phep_goi_api_ngoai = true,
                api_base_url_production = config?.ApiBaseUrlProduction ?? "https://api.donthuocquocgia.vn",
                api_base_url_test = config?.ApiBaseUrlTest,
                url_ky_du_lieu = config?.UrlKyDuLieu,
                url_ky_pdf = config?.UrlKyPdf,
                ma_lien_thong_cskcb = config?.MaLienThongCskcb,
                da_cau_hinh_mat_khau_cskcb = !string.IsNullOrWhiteSpace(config?.MatKhauCskcbMaHoa),
                ky_so_hieu_luc = config?.KySoHieuLuc ?? false,
                lien_thong_hieu_luc = config?.LienThongHieuLuc ?? false,
                bac_si = doctors
            }
        });
    }

    [HttpGet("/api/he_thong/lien_thong_toa_thuoc/mau-ky")]
    public async Task<IActionResult> LayMauKyPdf()
    {
        var idCskcb = User.LayIdCskcb();
        if (idCskcb <= 0) return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước." });
        var data = await _db.LayDanhSachStoAsync("dbo.STO_QL_KySoPdf_Mau_DanhSach", new { IDCSKCB = idCskcb });
        return Ok(new { status = 200, data });
    }

    [yeu_cau_quyen_attribute("he_thong_lien_thong_toa_thuoc", "Sua")]
    [HttpPost("/api/he_thong/lien_thong_toa_thuoc/mau-ky")]
    public async Task<IActionResult> LuuMauKyPdf([FromBody] KySoPdfMauRequest? request)
    {
        var idCskcb = User.LayIdCskcb();
        if (idCskcb <= 0) return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước." });
        if (request == null || request.ma_loai is not ("toa_thuoc" or "chi_dinh")
            || request.trang_ky is < 1 or > 100
            || request.x1 < 0 || request.y1 < 0 || request.x2 <= request.x1
            || request.y2 <= request.y1 || request.x2 > 420 || request.y2 > 596)
            return UnprocessableEntity(new { status = 422, message = "Tọa độ PDF A5 phải thuộc phạm vi trang và X1 < X2, Y1 < Y2." });

        var row = await _db.LayMotDongStoAsync("dbo.STO_QL_KySoPdf_Mau_Luu", new
        {
            IDCSKCB = idCskcb,
            MaLoai = request.ma_loai,
            TrangKy = request.trang_ky,
            X1 = request.x1,
            Y1 = request.y1,
            X2 = request.x2,
            Y2 = request.y2
        });
        return Ok(new { status = 200, message = "Đã lưu khung ký PDF.", data = row });
    }

    [yeu_cau_quyen_attribute("he_thong_lien_thong_toa_thuoc", "Sua")]
    [HttpPost("/api/he_thong/lien_thong_toa_thuoc/cau-hinh")]
    public async Task<IActionResult> LuuCauHinh([FromBody] LienThongToaThuocConfigRequest request, CancellationToken cancellationToken)
    {
        var idCskcb = User.LayIdCskcb();
        if (idCskcb <= 0) return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước khi cấu hình." });
        var environment = request.MoiTruong?.Trim().ToUpperInvariant();
        if (environment is not ("TEST" or "PRODUCTION"))
            return UnprocessableEntity(new { status = 422, message = "Môi trường chỉ nhận TEST hoặc PRODUCTION." });
        if (!ValidHttps(request.ApiBaseUrlProduction, required: true) || !ValidHttps(request.ApiBaseUrlTest, required: false)
            || !ValidHttps(request.UrlKyDuLieu, required: false) || !ValidHttps(request.UrlKyPdf, required: false))
            return UnprocessableEntity(new { status = 422, message = "Các URL được cấu hình phải là HTTPS hợp lệ." });
        if (request.KySoHieuLuc)
        {
            if (!_signer.IsConfigured)
                return StatusCode(503, new { status = 503, message = "Chưa có adapter ký số thật; không thể bật ký số." });
            if (string.IsNullOrWhiteSpace(request.UrlKyDuLieu) || string.IsNullOrWhiteSpace(request.UrlKyPdf))
                return UnprocessableEntity(new { status = 422, message = "Phải cấu hình URL ký dữ liệu và URL ký PDF khi bật ký số." });
        }

        var entity = await _db.HtLienThongToaThuocCauHinh.SingleOrDefaultAsync(x => x.Idcskcb == idCskcb, cancellationToken);
        if (request.LienThongHieuLuc)
        {
            var selectedUrl = environment == "PRODUCTION" ? request.ApiBaseUrlProduction : request.ApiBaseUrlTest;
            if (string.IsNullOrWhiteSpace(selectedUrl) || string.IsNullOrWhiteSpace(request.MaLienThongCskcb)
                || (string.IsNullOrWhiteSpace(request.MatKhauCskcb) && string.IsNullOrWhiteSpace(entity?.MatKhauCskcbMaHoa)))
                return UnprocessableEntity(new { status = 422, message = "Phải cấu hình API môi trường, mã và mật khẩu liên thông CSKCB khi bật liên thông." });
        }
        if (entity == null)
        {
            entity = new HtLienThongToaThuocCauHinh { Idcskcb = idCskcb };
            _db.HtLienThongToaThuocCauHinh.Add(entity);
        }
        entity.MoiTruong = environment;
        entity.ApiBaseUrlProduction = request.ApiBaseUrlProduction!.Trim().TrimEnd('/');
        entity.ApiBaseUrlTest = TrimOrNull(request.ApiBaseUrlTest);
        entity.UrlKyDuLieu = TrimOrNull(request.UrlKyDuLieu);
        entity.UrlKyPdf = TrimOrNull(request.UrlKyPdf);
        entity.MaLienThongCskcb = TrimOrNull(request.MaLienThongCskcb);
        if (!string.IsNullOrWhiteSpace(request.MatKhauCskcb))
            entity.MatKhauCskcbMaHoa = _protector.Protect(request.MatKhauCskcb);
        entity.KySoHieuLuc = request.KySoHieuLuc;
        entity.LienThongHieuLuc = request.LienThongHieuLuc;
        entity.HieuLuc = request.KySoHieuLuc && request.LienThongHieuLuc;
        entity.NgayCapNhat = DateTime.Now;
        entity.IdtaiKhoanCapNhat = User.LayIdTaiKhoan();
        _db.QlToaThuocAudit.Add(Audit(idCskcb, "CAP_NHAT_CAU_HINH"));
        await _db.SaveChangesAsync(cancellationToken);
        return Ok(new { status = 200, message = "Đã lưu cấu hình. Mật khẩu không được trả lại qua API." });
    }

    [yeu_cau_quyen_attribute("he_thong_lien_thong_toa_thuoc", "Sua")]
    [HttpPost("/api/he_thong/lien_thong_toa_thuoc/bac-si")]
    public async Task<IActionResult> LuuBacSi([FromBody] LienThongToaThuocBacSiRequest request, CancellationToken cancellationToken)
    {
        var idCskcb = User.LayIdCskcb();
        if (idCskcb <= 0) return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước khi cấu hình." });
        var validDoctor = await _db.DmNhanVienCskcb.AsNoTracking().AnyAsync(x => x.Idcskcb == idCskcb
            && x.IdnhanVien == request.IdNhanVien && x.Active && x.IdnhanVienNavigation.Active
            && x.IdnhanVienNavigation.LaBacSi, cancellationToken);
        if (!validDoctor) return NotFound(new { status = 404, message = "Bác sĩ không thuộc cơ sở đang làm việc." });

        var entity = await _db.HtLienThongToaThuocBacSi.SingleOrDefaultAsync(
            x => x.Idcskcb == idCskcb && x.IdnhanVien == request.IdNhanVien, cancellationToken);
        if (entity == null)
        {
            entity = new HtLienThongToaThuocBacSi { Idcskcb = idCskcb, IdnhanVien = request.IdNhanVien };
            _db.HtLienThongToaThuocBacSi.Add(entity);
        }
        entity.MaLienThong = TrimOrNull(request.MaLienThong);
        entity.SoChungChiHanhNghe = TrimOrNull(request.SoChungChiHanhNghe);
        if (!string.IsNullOrWhiteSpace(request.MatKhau)) entity.MatKhauMaHoa = _protector.Protect(request.MatKhau);
        entity.Active = request.Active;
        entity.NgayCapNhat = DateTime.Now;
        entity.IdtaiKhoanCapNhat = User.LayIdTaiKhoan();
        _db.QlToaThuocAudit.Add(Audit(idCskcb, "CAP_NHAT_TAI_KHOAN_BAC_SI", request.IdNhanVien));
        await _db.SaveChangesAsync(cancellationToken);
        return Ok(new { status = 200, message = "Đã lưu cấu hình bác sĩ. Mật khẩu không được trả lại qua API." });
    }

    private QlToaThuocAudit Audit(long idCskcb, string action, long? idNhanVien = null)
    {
        var actor = idNhanVien ?? User.LayIdNhanVien();
        return new QlToaThuocAudit
        {
            Idcskcb = idCskcb,
            HanhDong = action,
            IdnhanVien = actor > 0 ? actor : null,
            IdtaiKhoan = User.LayIdTaiKhoan(),
            NgayTao = DateTime.Now
        };
    }

    private static bool ValidHttps(string? value, bool required)
    {
        if (string.IsNullOrWhiteSpace(value)) return !required;
        return Uri.TryCreate(value, UriKind.Absolute, out var uri) && uri.Scheme == Uri.UriSchemeHttps;
    }

    private static string? TrimOrNull(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim().TrimEnd('/');
}

public sealed class KySoPdfMauRequest
{
    public string? ma_loai { get; set; }
    public int trang_ky { get; set; }
    public decimal x1 { get; set; }
    public decimal y1 { get; set; }
    public decimal x2 { get; set; }
    public decimal y2 { get; set; }
}
