using System.Security.Cryptography;
using System.Text;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using QuanLyPhongMach.Data;
using QuanLyPhongMach.Entities;
using QuanLyPhongMach.Models.ToaThuocQuocGia;

namespace QuanLyPhongMach.Services.ToaThuocQuocGia;

public sealed class LienThongTrucTiepService : ILienThongTrucTiepService
{
    private readonly QlpmDbContext _db;
    private readonly IToaThuocReadinessService _readiness;
    private readonly IToaThuocQuocGiaClient _client;
    private readonly ILienThongCredentialProtector _protector;
    private readonly IConfiguration _configuration;
    private readonly ILogger<LienThongTrucTiepService> _logger;

    public LienThongTrucTiepService(QlpmDbContext db, IToaThuocReadinessService readiness,
        IToaThuocQuocGiaClient client, ILienThongCredentialProtector protector,
        IConfiguration configuration, ILogger<LienThongTrucTiepService> logger)
    {
        _db = db; _readiness = readiness; _client = client; _protector = protector;
        _configuration = configuration; _logger = logger;
    }

    public async Task KiemTraAsync(long idToa, long idCskcb, long idTaiKhoan, long idNhanVien, CancellationToken cancellationToken)
    {
        await BusinessStoAsync("dbo.STO_QL_ToaThuoc_LienThong_KiemTra", new {
            IDCSKCB = idCskcb, IDToaThuoc = idToa, IDTaiKhoan = idTaiKhoan, IDNhanVien = Actor(idNhanVien)
        });
        await _readiness.TaoPayloadLienThongAsync(idToa, idCskcb, cancellationToken);
        await TaoRequestAsync(idToa, idCskcb, string.Empty, Guid.Empty, cancellationToken);
    }

    public async Task<LienThongTrucTiepResult> GuiAsync(long idToa, long idCskcb, long idTaiKhoan, long idNhanVien, CancellationToken cancellationToken)
    {
        await KiemTraAsync(idToa, idCskcb, idTaiKhoan, idNhanVien, cancellationToken);
        var snapshot = await _readiness.TaoPayloadLienThongAsync(idToa, idCskcb, cancellationToken);
        var key = Guid.NewGuid();
        var request = await TaoRequestAsync(idToa, idCskcb, snapshot.CanonicalJson, key, cancellationToken);
        var started = await BusinessStoAsync("dbo.STO_QL_ToaThuoc_LienThong_BatDau", new {
            IDCSKCB = idCskcb, IDToaThuoc = idToa, IDTaiKhoan = idTaiKhoan, IDNhanVien = Actor(idNhanVien),
            snapshot.PhienBanNguon, JsonPayload = snapshot.CanonicalJson,
            Sha256Json = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(snapshot.CanonicalJson))).ToLowerInvariant(),
            IdempotencyKey = key
        });
        var idAttempt = Convert.ToInt64(((IDictionary<string, object?>)started!) ["IDLanGui"]);
        ToaThuocNationalSendResult result;
        try { result = await _client.GuiAsync(request, cancellationToken); }
        catch (OperationCanceledException) {
            result = new(false, true, null, "REQUEST_INTERRUPTED", "", "Kết nối bị ngắt; chưa rõ hệ thống quốc gia đã nhận toa hay chưa.");
        }
        catch (Exception ex) {
            _logger.LogError(ex, "Lỗi gửi trực tiếp lần {IDLanGui} của CSKCB {IDCSKCB}.", idAttempt, idCskcb);
            result = new(false, true, null, "UNEXPECTED_ERROR", "", "Chưa xác định kết quả gửi toa thuốc.");
        }
        var state = result.Accepted ? "THANH_CONG" : result.Unknown ? "KHONG_RO_KET_QUA"
            : result.ResultCode == "REJECTED" ? "TU_CHOI" : "LOI_GUI";
        // Persistence must finish even when the browser disconnected. No HTTP runs
        // inside this transaction, and the legacy worker cannot claim this attempt.
        await BusinessStoAsync("dbo.STO_QL_ToaThuoc_LienThong_KetQua", new {
            IDCSKCB = idCskcb, IDLanGui = idAttempt, TrangThai = state, result.HttpStatus,
            MaKetQua = result.ResultCode, PhanHoiDaLoc = result.SanitizedResponse, LoiCuoi = result.Error
        });
        if (result.DoctorRegistered) {
            var doctorId = await _db.QlToaThuoc.Where(x => x.Idcskcb == idCskcb && x.Id == idToa).Select(x => x.IdbacSiKe).SingleAsync();
            await _db.HtLienThongToaThuocBacSi.Where(x => x.Idcskcb == idCskcb && x.IdnhanVien == doctorId)
                .ExecuteUpdateAsync(setters => setters.SetProperty(x => x.DaDangKy, true));
        }
        return new(idAttempt, state, result);
    }

    private async Task<ToaThuocNationalRequest> TaoRequestAsync(long idToa, long idCskcb, string json, Guid key, CancellationToken ct)
    {
        var doctor = await (from p in _db.QlToaThuoc.AsNoTracking()
            join n in _db.DmNhanVien.AsNoTracking() on p.IdbacSiKe equals n.Id
            join m in _db.DmNhanVienCskcb.AsNoTracking() on new { p.Idcskcb, IdnhanVien = n.Id } equals new { m.Idcskcb, m.IdnhanVien }
            where p.Idcskcb == idCskcb && p.Id == idToa && n.Active && n.LaBacSi && m.Active
            select n).SingleOrDefaultAsync(ct)
            ?? throw new ToaThuocInteroperabilityException(422, "Bác sĩ kê toa không còn hoạt động tại cơ sở.");
        var config = await _db.HtLienThongToaThuocCauHinh.AsNoTracking().SingleOrDefaultAsync(x => x.Idcskcb == idCskcb, ct);
        var doctorConfig = await _db.HtLienThongToaThuocBacSi.AsNoTracking().SingleOrDefaultAsync(x => x.Idcskcb == idCskcb && x.IdnhanVien == doctor.Id && x.Active, ct);
        if (config == null || !config.LienThongHieuLuc)
            throw new ToaThuocInteroperabilityException(503, "Liên thông toa thuốc chưa được bật cho cơ sở.");
        // Deployment may override endpoints; absence preserves the existing DB
        // environment. There is deliberately no TEST-to-PRODUCTION fallback.
        var environment = _configuration["ToaThuocQuocGia:MoiTruong"] ?? config.MoiTruong;
        if (environment is not ("TEST" or "PRODUCTION"))
            throw new ToaThuocInteroperabilityException(503, "Môi trường liên thông không hợp lệ.");
        var url = _configuration[$"ToaThuocQuocGia:{(environment == "PRODUCTION" ? "ApiBaseUrlProduction" : "ApiBaseUrlTest")}"]
            ?? (environment == "PRODUCTION" ? config.ApiBaseUrlProduction : config.ApiBaseUrlTest);
        if (!Uri.TryCreate(url, UriKind.Absolute, out var baseAddress) || baseAddress.Scheme != Uri.UriSchemeHttps)
            throw new ToaThuocInteroperabilityException(503, $"Chưa cấu hình endpoint HTTPS cho môi trường {environment}.");
        if (string.IsNullOrWhiteSpace(config.MaLienThongCskcb) || string.IsNullOrWhiteSpace(config.MatKhauCskcbMaHoa)
            || doctorConfig == null || string.IsNullOrWhiteSpace(doctorConfig.MaLienThong) || string.IsNullOrWhiteSpace(doctorConfig.MatKhauMaHoa))
            throw new ToaThuocInteroperabilityException(422, "Thiếu mã hoặc mật khẩu liên thông của cơ sở/bác sĩ kê toa.");
        try {
            return new(baseAddress, new(config.MaLienThongCskcb, _protector.Unprotect(config.MatKhauCskcbMaHoa)),
                new(doctorConfig.MaLienThong, _protector.Unprotect(doctorConfig.MatKhauMaHoa)), doctor.HoTen,
                doctorConfig.SoChungChiHanhNghe ?? "", json, key, doctorConfig.DaDangKy);
        } catch (CryptographicException) {
            throw new ToaThuocInteroperabilityException(503, "Không đọc được mật khẩu đã mã hóa. Cần lưu lại tài khoản liên thông.");
        }
    }

    private async Task<dynamic?> BusinessStoAsync(string name, object args)
    {
        try { return await _db.LayMotDongStoAsync(name, args); }
        catch (SqlException ex) when (ex.Number is >= 59201 and <= 59205) {
            var status = ex.Number == 59201 ? 403 : ex.Number == 59202 ? 404 : ex.Number == 59203 ? 422 : 409;
            throw new ToaThuocInteroperabilityException(status, ex.Message);
        }
    }
    private static long? Actor(long id) => id > 0 ? id : null;
}
