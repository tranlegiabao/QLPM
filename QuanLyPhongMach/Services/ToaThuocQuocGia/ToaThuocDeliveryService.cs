using System.Security.Cryptography;
using System.Text;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using QuanLyPhongMach.Data;
using QuanLyPhongMach.Models.Requests.KhamBenh;
using QuanLyPhongMach.Models.ToaThuocQuocGia;

namespace QuanLyPhongMach.Services.ToaThuocQuocGia;

public sealed class ToaThuocDeliveryService : IToaThuocDeliveryService
{
    private readonly QlpmDbContext _db;
    private readonly IToaThuocReadinessService _readiness;
    private readonly IToaThuocSigner _signer;
    private readonly IToaThuocQuocGiaClient _client;
    private readonly ILienThongCredentialProtector _credentialProtector;
    private readonly IKhamBenhPrintService _printService;
    private readonly ILogger<ToaThuocDeliveryService> _logger;

    public ToaThuocDeliveryService(
        QlpmDbContext db,
        IToaThuocReadinessService readiness,
        IToaThuocSigner signer,
        IToaThuocQuocGiaClient client,
        ILienThongCredentialProtector credentialProtector,
        IKhamBenhPrintService printService,
        ILogger<ToaThuocDeliveryService> logger)
    {
        _db = db;
        _readiness = readiness;
        _signer = signer;
        _client = client;
        _credentialProtector = credentialProtector;
        _printService = printService;
        _logger = logger;
    }

    public async Task<long> KySoAsync(
        long idToaThuoc,
        long idCskcb,
        long idNhanVien,
        long idTaiKhoan,
        CancellationToken cancellationToken = default)
    {
        var readiness = await _readiness.KiemTraAsync(idToaThuoc, idCskcb, idNhanVien, cancellationToken);
        if (!readiness.SanSangKy)
        {
            var status = readiness.TrangThai is "CHO_GUI" or "DANG_GUI" or "THANH_CONG" or "KHONG_RO_KET_QUA"
                ? 409
                : readiness.LoiKy.Any(x => x.Contains("cấu hình", StringComparison.OrdinalIgnoreCase)
                    || x.Contains("chưa được bật", StringComparison.OrdinalIgnoreCase)) ? 503 : 422;
            throw new ToaThuocInteroperabilityException(status, string.Join(" ", readiness.LoiKy));
        }

        var snapshot = await _readiness.TaoPayloadAsync(idToaThuoc, idCskcb, idNhanVien, cancellationToken);
        var prescriptionCode = snapshot.Payload.MaDonThuoc;
        var pdf = await _printService.InToaThuocAsync(new KhamBenhInRequest
        {
            nguon = "da_luu",
            id_vao_vien = snapshot.IdVaoVien,
            id_toa_thuoc = idToaThuoc
        }, idCskcb, idNhanVien);

        var signed = await _signer.SignAsync(new ToaThuocSignRequest(
            idToaThuoc,
            prescriptionCode,
            idNhanVien,
            snapshot.CanonicalJson,
            pdf.Content), cancellationToken);

        if (string.IsNullOrWhiteSpace(signed.Signature) || signed.SignedPdf.Length == 0)
            throw new ToaThuocInteroperabilityException(503, "Dịch vụ ký không trả đủ chữ ký dữ liệu và PDF đã ký.");
        if (signed.SignedPdf.Length > 10 * 1024 * 1024)
            throw new ToaThuocInteroperabilityException(422, "PDF đã ký vượt quá giới hạn 10 MB.");

        var saved = await CallBusinessStoAsync(() => _db.LayMotDongStoAsync("dbo.STO_QL_ToaThuoc_LuuPhienBanDaKy", new
        {
            IDCSKCB = idCskcb,
            IDToaThuoc = idToaThuoc,
            IDBacSi = idNhanVien,
            IDTaiKhoan = idTaiKhoan,
            PhienBanNguon = snapshot.PhienBanNguon,
            JsonChuaKy = snapshot.CanonicalJson,
            Sha256Json = Sha256(snapshot.CanonicalJson),
            ChuKyDuLieu = signed.Signature,
            JsonDaKy = signed.SignedJson,
            PdfDaKy = signed.SignedPdf,
            Sha256Pdf = Sha256(signed.SignedPdf),
            NhaCungCapKy = signed.Provider,
            SerialChungThu = signed.CertificateSerial
        }));
        var versionId = GetInt64(saved, "IDPhienBan");
        if (versionId <= 0)
            throw new ToaThuocInteroperabilityException(409, "Không lưu được phiên bản toa đã ký; dữ liệu khám có thể vừa thay đổi.");

        return versionId;
    }

    public async Task<long> XepHangLienThongAsync(
        long idToaThuoc,
        long idCskcb,
        long idNhanVien,
        long idTaiKhoan,
        CancellationToken cancellationToken = default)
    {
        var readiness = await _readiness.KiemTraAsync(idToaThuoc, idCskcb, idNhanVien, cancellationToken);
        if (!readiness.SanSangLienThong)
        {
            var status = readiness.TrangThai != "DA_KY"
                ? 409
                : readiness.LoiLienThong.Any(x => x.Contains("cấu hình", StringComparison.OrdinalIgnoreCase)
                    || x.Contains("chưa được bật", StringComparison.OrdinalIgnoreCase)) ? 503 : 422;
            throw new ToaThuocInteroperabilityException(status, string.Join(" ", readiness.LoiLienThong));
        }

        var versionId = await _db.QlToaThuoc.AsNoTracking()
            .Where(x => x.Id == idToaThuoc && x.Idcskcb == idCskcb)
            .Select(x => x.IdphienBanHienTai)
            .SingleAsync(cancellationToken);
        if (!versionId.HasValue)
            throw new ToaThuocInteroperabilityException(409, "Toa thuốc chưa có phiên bản ký số hợp lệ.");

        return await QueueVersionAsync(idCskcb, idToaThuoc, versionId.Value, idNhanVien, idTaiKhoan, false);
    }

    public async Task<long> XepHangGuiLaiAsync(
        long idToaThuoc,
        long idCskcb,
        long idNhanVien,
        long idTaiKhoan,
        CancellationToken cancellationToken = default)
    {
        var prescription = await _db.QlToaThuoc.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == idToaThuoc && x.Idcskcb == idCskcb, cancellationToken)
            ?? throw new ToaThuocInteroperabilityException(404, "Không tìm thấy toa thuốc.");
        if (prescription.IdbacSiKe != idNhanVien)
            throw new ToaThuocInteroperabilityException(403, "Chỉ bác sĩ kê đơn mới được gửi lại toa thuốc.");
        if (prescription.TrangThai is "THANH_CONG" or "DANG_GUI" or "KHONG_RO_KET_QUA")
            throw new ToaThuocInteroperabilityException(409, $"Không thể gửi lại toa ở trạng thái {prescription.TrangThai}.");
        if (!prescription.IdphienBanHienTai.HasValue)
            throw new ToaThuocInteroperabilityException(409, "Toa thuốc chưa có phiên bản đã ký hợp lệ.");

        var config = await _db.HtLienThongToaThuocCauHinh.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Idcskcb == idCskcb, cancellationToken);
        var selectedUrl = string.Equals(config?.MoiTruong, "PRODUCTION", StringComparison.OrdinalIgnoreCase)
            ? config?.ApiBaseUrlProduction
            : config?.ApiBaseUrlTest;
        if (config == null || !config.LienThongHieuLuc || string.IsNullOrWhiteSpace(selectedUrl)
            || string.IsNullOrWhiteSpace(config.MaLienThongCskcb)
            || string.IsNullOrWhiteSpace(config.MatKhauCskcbMaHoa))
            throw new ToaThuocInteroperabilityException(503,
                "API của môi trường đang chọn hoặc tài khoản cơ sở chưa được cấu hình; hệ thống không tự chuyển sang production.");

        var doctorConfig = await _db.HtLienThongToaThuocBacSi.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Idcskcb == idCskcb && x.IdnhanVien == idNhanVien && x.Active, cancellationToken);
        if (doctorConfig == null || string.IsNullOrWhiteSpace(doctorConfig.MaLienThong)
            || string.IsNullOrWhiteSpace(doctorConfig.MatKhauMaHoa))
            throw new ToaThuocInteroperabilityException(422, "Tài khoản liên thông của bác sĩ kê toa chưa đầy đủ.");

        return await QueueVersionAsync(idCskcb, idToaThuoc, prescription.IdphienBanHienTai.Value, idNhanVien, idTaiKhoan, true);
    }

    public async Task<int> XuLyHangDoiAsync(CancellationToken cancellationToken = default)
    {
        var queueItem = await _db.QlToaThuocLanGui.AsNoTracking()
            .Where(x => x.TrangThai == "CHO_GUI")
            .OrderBy(x => x.NgayTao)
            .Select(x => new { x.Id, x.Idcskcb })
            .FirstOrDefaultAsync(cancellationToken);
        if (queueItem == null) return 0;

        var started = await CallBusinessStoAsync(() => _db.LayMotDongStoAsync("dbo.STO_QL_ToaThuoc_BatDauGui", new
        {
            IDCSKCB = queueItem.Idcskcb,
            IDLanGui = queueItem.Id
        }));
        if (GetInt64(started, "IDLanGui") <= 0) return 0;

        var data = await (
            from attempt in _db.QlToaThuocLanGui.AsNoTracking()
            join version in _db.QlToaThuocPhienBan.AsNoTracking() on attempt.IdtoaThuocPhienBan equals version.Id
            join prescription in _db.QlToaThuoc.AsNoTracking() on version.IdtoaThuoc equals prescription.Id
            join doctor in _db.DmNhanVien.AsNoTracking() on prescription.IdbacSiKe equals doctor.Id
            join doctorConfig in _db.HtLienThongToaThuocBacSi.AsNoTracking()
                on new { prescription.Idcskcb, IdnhanVien = prescription.IdbacSiKe }
                equals new { doctorConfig.Idcskcb, doctorConfig.IdnhanVien }
            join config in _db.HtLienThongToaThuocCauHinh.AsNoTracking() on prescription.Idcskcb equals config.Idcskcb
            where attempt.Id == queueItem.Id && prescription.Idcskcb == queueItem.Idcskcb
            select new { attempt, version, prescription, doctor, doctorConfig, config }
        ).SingleAsync(cancellationToken);

        ToaThuocNationalSendResult result;
        try
        {
            if (!data.config.LienThongHieuLuc)
                throw new ToaThuocInteroperabilityException(503, "Liên thông toa thuốc đang tắt.");
            var baseUrl = string.Equals(data.config.MoiTruong, "PRODUCTION", StringComparison.OrdinalIgnoreCase)
                ? data.config.ApiBaseUrlProduction
                : data.config.ApiBaseUrlTest;
            if (string.IsNullOrWhiteSpace(baseUrl))
                throw new ToaThuocInteroperabilityException(503,
                    $"API {data.config.MoiTruong} đang để trống; không tự chuyển môi trường.");
            if (!Uri.TryCreate(baseUrl, UriKind.Absolute, out var baseAddress)
                || baseAddress.Scheme != Uri.UriSchemeHttps)
                throw new ToaThuocInteroperabilityException(503, "URL liên thông phải là HTTPS hợp lệ.");

            result = await _client.GuiAsync(new ToaThuocNationalRequest(
                baseAddress,
                new ToaThuocApiCredentials(
                    data.config.MaLienThongCskcb ?? string.Empty,
                    _credentialProtector.Unprotect(data.config.MatKhauCskcbMaHoa ?? string.Empty)),
                new ToaThuocApiCredentials(
                    data.doctorConfig.MaLienThong ?? string.Empty,
                    _credentialProtector.Unprotect(data.doctorConfig.MatKhauMaHoa ?? string.Empty)),
                data.doctor.HoTen,
                data.doctorConfig.SoChungChiHanhNghe ?? string.Empty,
                data.version.JsonDaKy,
                data.attempt.IdempotencyKey,
                data.doctorConfig.DaDangKy), cancellationToken);
            if (result.DoctorRegistered && !data.doctorConfig.DaDangKy)
            {
                await _db.HtLienThongToaThuocBacSi
                    .Where(x => x.Idcskcb == data.prescription.Idcskcb && x.IdnhanVien == data.prescription.IdbacSiKe)
                    .ExecuteUpdateAsync(setters => setters.SetProperty(x => x.DaDangKy, true), cancellationToken);
            }
        }
        catch (ToaThuocInteroperabilityException ex)
        {
            result = new(false, false, ex.StatusCode, "CONFIGURATION_ERROR", string.Empty, ex.Message);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi xử lý lần gửi toa {IDLanGui} tại CSKCB {IDCSKCB}.", queueItem.Id, queueItem.Idcskcb);
            result = new(false, true, null, "UNEXPECTED_ERROR", string.Empty, "Lỗi hệ thống khi gửi toa thuốc.");
        }

        await CallBusinessStoAsync(() => _db.LayMotDongStoAsync("dbo.STO_QL_ToaThuoc_GhiNhanKetQuaGui", new
        {
            IDCSKCB = queueItem.Idcskcb,
            IDLanGui = queueItem.Id,
            ThanhCong = result.Accepted,
            KhongRoKetQua = result.Unknown,
            HttpStatus = result.HttpStatus,
            MaKetQua = result.ResultCode,
            PhanHoiDaLoc = result.SanitizedResponse,
            LoiCuoi = result.Error
        }));
        return 1;
    }

    private async Task<long> QueueVersionAsync(long idCskcb, long idToaThuoc, long versionId, long idNhanVien, long idTaiKhoan, bool retry)
    {
        var queued = await CallBusinessStoAsync(() => _db.LayMotDongStoAsync("dbo.STO_QL_ToaThuoc_XepHangGui", new
        {
            IDCSKCB = idCskcb,
            IDToaThuoc = idToaThuoc,
            IDPhienBan = versionId,
            IDBacSi = idNhanVien,
            IDTaiKhoan = idTaiKhoan,
            GuiLai = retry
        }));
        var attemptId = GetInt64(queued, "IDLanGui");
        if (attemptId <= 0)
            throw new ToaThuocInteroperabilityException(409, "Không thể xếp hàng gửi toa thuốc ở trạng thái hiện tại.");
        return attemptId;
    }

    private static long GetInt64(object? row, string key)
    {
        if (row is not IDictionary<string, object?> values || !values.TryGetValue(key, out var value) || value == null)
            return 0;
        return Convert.ToInt64(value);
    }

    private static async Task<dynamic?> CallBusinessStoAsync(Func<Task<dynamic?>> action)
    {
        try
        {
            return await action();
        }
        catch (SqlException ex) when (ex.Number is 59121 or 59125 or 59131 or 59134)
        {
            throw new ToaThuocInteroperabilityException(403, "Tài khoản không được phép ký hoặc gửi toa thuốc này.");
        }
        catch (SqlException ex) when (ex.Number is >= 59120 and <= 59140)
        {
            throw new ToaThuocInteroperabilityException(409, "Dữ liệu hoặc trạng thái toa đã thay đổi. Vui lòng kiểm tra lại trước khi thao tác.");
        }
    }

    private static string Sha256(string value) => Sha256(Encoding.UTF8.GetBytes(value));
    private static string Sha256(byte[] value) => Convert.ToHexString(SHA256.HashData(value)).ToLowerInvariant();
}
