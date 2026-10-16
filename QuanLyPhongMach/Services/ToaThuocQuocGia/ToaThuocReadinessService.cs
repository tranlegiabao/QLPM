using System.Globalization;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using QuanLyPhongMach.Data;
using QuanLyPhongMach.Models.ToaThuocQuocGia;

namespace QuanLyPhongMach.Services.ToaThuocQuocGia;

public sealed class ToaThuocReadinessService : IToaThuocReadinessService
{
    private static readonly JsonSerializerOptions CanonicalJsonOptions = new()
    {
        PropertyNamingPolicy = null,
        WriteIndented = false,
        DefaultIgnoreCondition = System.Text.Json.Serialization.JsonIgnoreCondition.WhenWritingNull
    };

    private readonly QlpmDbContext _db;
    private readonly IToaThuocSigner _signer;

    public ToaThuocReadinessService(QlpmDbContext db, IToaThuocSigner signer)
    {
        _db = db;
        _signer = signer;
    }

    public async Task<ToaThuocReadinessResult> KiemTraAsync(
        long idToaThuoc,
        long idCskcb,
        long idNhanVien,
        CancellationToken cancellationToken = default)
    {
        var dataErrors = new List<string>();
        var prescription = await _db.QlToaThuoc.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == idToaThuoc && x.Idcskcb == idCskcb, cancellationToken);
        if (prescription == null)
            throw new ToaThuocInteroperabilityException(404, "Không tìm thấy toa thuốc trong cơ sở đang làm việc.");

        await KiemTraDuLieuAsync(prescription, idNhanVien, dataErrors, cancellationToken);

        var config = await _db.HtLienThongToaThuocCauHinh.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Idcskcb == idCskcb, cancellationToken);

        var signErrors = new List<string>(dataErrors);
        if (prescription.TrangThai is not ("NHAP" or "TU_CHOI" or "LOI_GUI"))
            signErrors.Add($"Trạng thái {prescription.TrangThai} không cho phép ký số.");
        if (config == null || !config.KySoHieuLuc)
            signErrors.Add("Chức năng ký số chưa được bật cho cơ sở.");
        else if (string.IsNullOrWhiteSpace(config.UrlKyDuLieu)
            || string.IsNullOrWhiteSpace(config.UrlKyPdf)
            || !_signer.IsConfigured)
            signErrors.Add("Chưa cấu hình đầy đủ dịch vụ ký dữ liệu và ký PDF.");

        var deliveryErrors = new List<string>(dataErrors);
        if (prescription.TrangThai != "DA_KY" || !prescription.IdphienBanHienTai.HasValue)
            deliveryErrors.Add("Toa thuốc phải có phiên bản ký số hợp lệ trước khi liên thông.");
        if (config == null || !config.LienThongHieuLuc)
            deliveryErrors.Add("Chức năng liên thông toa thuốc chưa được bật cho cơ sở.");
        else
        {
            var selectedUrl = string.Equals(config.MoiTruong, "PRODUCTION", StringComparison.OrdinalIgnoreCase)
                ? config.ApiBaseUrlProduction
                : config.ApiBaseUrlTest;
            if (string.IsNullOrWhiteSpace(selectedUrl))
                deliveryErrors.Add($"Chưa cấu hình API {config.MoiTruong}; hệ thống không tự chuyển sang production.");
            if (string.IsNullOrWhiteSpace(config.MaLienThongCskcb) || string.IsNullOrWhiteSpace(config.MatKhauCskcbMaHoa))
                deliveryErrors.Add("Chưa cấu hình tài khoản liên thông của cơ sở.");
        }

        var doctorConfig = await _db.HtLienThongToaThuocBacSi.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Idcskcb == idCskcb && x.IdnhanVien == prescription.IdbacSiKe && x.Active, cancellationToken);
        if (doctorConfig == null || string.IsNullOrWhiteSpace(doctorConfig.MaLienThong)
            || string.IsNullOrWhiteSpace(doctorConfig.MatKhauMaHoa)
            || string.IsNullOrWhiteSpace(doctorConfig.SoChungChiHanhNghe))
            deliveryErrors.Add("Bác sĩ kê đơn chưa có mã liên thông, chứng chỉ hành nghề hoặc mật khẩu API.");

        return new(
            prescription.TrangThai,
            signErrors.Count == 0,
            signErrors,
            deliveryErrors.Count == 0,
            deliveryErrors);
    }

    public async Task<ToaThuocPayloadSnapshot> TaoPayloadAsync(
        long idToaThuoc,
        long idCskcb,
        long idNhanVien,
        CancellationToken cancellationToken = default)
        => await TaoPayloadCoreAsync(idToaThuoc, idCskcb, idNhanVien, true, cancellationToken);

    public Task<ToaThuocPayloadSnapshot> TaoPayloadLienThongAsync(
        long idToaThuoc, long idCskcb, CancellationToken cancellationToken = default)
        => TaoPayloadCoreAsync(idToaThuoc, idCskcb, 0, false, cancellationToken);

    private async Task<ToaThuocPayloadSnapshot> TaoPayloadCoreAsync(
        long idToaThuoc, long idCskcb, long idNhanVien, bool requirePrescriber, CancellationToken cancellationToken)
    {
        var prescription = await _db.QlToaThuoc.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == idToaThuoc && x.Idcskcb == idCskcb, cancellationToken)
            ?? throw new ToaThuocInteroperabilityException(404, "Không tìm thấy toa thuốc trong cơ sở đang làm việc.");
        var errors = new List<string>();
        await KiemTraDuLieuAsync(prescription, idNhanVien, errors, cancellationToken, requirePrescriber);
        if (errors.Count > 0)
            throw new ToaThuocInteroperabilityException(422, string.Join(" ", errors));

        var visit = await _db.QlVaoVien.AsNoTracking()
            .Where(x => x.Idcskcb == idCskcb && x.Id == prescription.IdvaoVien)
            .Select(x => new
            {
                x.Id,
                x.PhienBanLamSang,
                x.NgayTaiKham,
                x.DanDo,
                Patient = x.QlBenhNhan
            })
            .SingleAsync(cancellationToken);

        var diagnoses = await _db.QlChanDoanCt.AsNoTracking()
            .Where(x => x.Idcskcb == idCskcb && x.IdvaoVien == prescription.IdvaoVien)
            .OrderByDescending(x => x.BenhChinh).ThenBy(x => x.ThuTu).ThenBy(x => x.Id)
            .Select(x => new ToaThuocQuocGiaChanDoan
            {
                MaChanDoan = x.MaBenh,
                TenChanDoan = x.TenBenh,
                KetLuan = x.GhiChu
            })
            .ToListAsync(cancellationToken);

        var medicines = await _db.QlToaThuocCt.AsNoTracking()
            .Where(x => x.Idcskcb == idCskcb && x.IdtoaThuoc == idToaThuoc && x.Active)
            .OrderBy(x => x.ThuTu).ThenBy(x => x.Id)
            .Select(x => new
            {
                x.SoNgay,
                x.SoLuong,
                x.Sang,
                x.Trua,
                x.Chieu,
                x.Toi,
                x.CachDung,
                x.LieuDung,
                HoatChatDong = x.HoatChat,
                x.DmThuoc.MaThuocQuocGia,
                x.DmThuoc.TenThuoc,
                HoatChatDanhMuc = x.DmThuoc.HoatChat,
                x.DmThuoc.DonViTinh
            })
            .ToListAsync(cancellationToken);

        var maxDays = Math.Max(1, medicines.Max(x => x.SoNgay ?? 1));
        var guardian = string.Join("; ", new[]
        {
            visit.Patient.GiamHoHoTen,
            visit.Patient.GiamHoMoiQuanHe,
            visit.Patient.GiamHoDienThoai,
            visit.Patient.GiamHoSoCccd
        }.Where(x => !string.IsNullOrWhiteSpace(x)).Select(x => x!.Trim()));

        var payload = new ToaThuocQuocGiaPayload
        {
            LoaiDonThuoc = prescription.MaLoaiToaThuoc,
            MaDonThuoc = prescription.MaToaQuocGia!,
            HoTenBenhNhan = visit.Patient.HoTen.Trim(),
            MaDinhDanhYTe = visit.Patient.MaBn.Trim(),
            MaDinhDanhCongDan = NullIfWhiteSpace(visit.Patient.SoCccd),
            NgaySinhBenhNhan = visit.Patient.NgaySinh!.Value.ToString("dd/MM/yyyy", CultureInfo.InvariantCulture),
            GioiTinh = visit.Patient.IdgioiTinh switch { 1 => 2, 2 => 3, _ => 1 },
            ThongTinNguoiGiamHo = NullIfWhiteSpace(guardian),
            DiaChi = visit.Patient.DiaChi?.Trim() ?? string.Empty,
            ChanDoan = diagnoses,
            DotDungThuoc = prescription.MaLoaiToaThuoc is "h" or "n"
                ? new[] { new ToaThuocQuocGiaDotDung
                {
                    So = "1",
                    TuNgay = prescription.NgayKe.ToString("dd/MM/yyyy", CultureInfo.InvariantCulture),
                    DenNgay = prescription.NgayKe.AddDays(maxDays - 1).ToString("dd/MM/yyyy", CultureInfo.InvariantCulture),
                    SoThang = "0"
                } }
                : Array.Empty<ToaThuocQuocGiaDotDung>(),
            ThongTinDonThuoc = medicines.Select(x => new ToaThuocQuocGiaDongThuoc
            {
                MaThuoc = x.MaThuocQuocGia!,
                TenThuoc = x.TenThuoc.Trim(),
                BietDuoc = NullIfWhiteSpace(x.HoatChatDong ?? x.HoatChatDanhMuc),
                DonViTinh = x.DonViTinh?.Trim() ?? string.Empty,
                SoLuong = x.SoLuong,
                CachDung = TaoCachDung(x.Sang, x.Trua, x.Chieu, x.Toi, x.LieuDung, x.CachDung)
            }).ToList(),
            LoiDan = NullIfWhiteSpace(visit.DanDo),
            SoDienThoaiNguoiKhamBenh = NullIfWhiteSpace(visit.Patient.DienThoai),
            NgayTaiKham = visit.NgayTaiKham.HasValue
                ? Math.Max(0, (visit.NgayTaiKham.Value.Date - prescription.NgayKe.Date).Days)
                : null,
            NgayGioKeDon = prescription.NgayKe.ToString("yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture),
            Signature = string.Empty
        };
        var json = JsonSerializer.Serialize(payload, CanonicalJsonOptions);
        return new(idToaThuoc, visit.Id, visit.PhienBanLamSang, payload, json);
    }

    private async Task KiemTraDuLieuAsync(
        Entities.QlToaThuoc prescription,
        long idNhanVien,
        List<string> errors,
        CancellationToken cancellationToken,
        bool requirePrescriber = true)
    {
        if (requirePrescriber && prescription.IdbacSiKe != idNhanVien)
            throw new ToaThuocInteroperabilityException(403, "Chỉ bác sĩ kê đơn mới được ký và liên thông toa thuốc này.");
        if (!ToaThuocQuocGiaCode.IsValid(prescription.MaToaQuocGia, prescriptionType: prescription.MaLoaiToaThuoc))
            errors.Add("Toa thuốc chưa có mã quốc gia hợp lệ 14 ký tự.");
        if (prescription.MaLoaiToaThuoc is not ("c" or "n" or "h"))
            errors.Add("Loại toa thuốc không thuộc phạm vi c/n/h.");

        var visit = await _db.QlVaoVien.AsNoTracking()
            .Where(x => x.Idcskcb == prescription.Idcskcb && x.Id == prescription.IdvaoVien && x.Active)
            .Select(x => new
            {
                x.TrangThaiKham,
                PatientName = x.QlBenhNhan.HoTen,
                PatientCode = x.QlBenhNhan.MaBn,
                PatientAddress = x.QlBenhNhan.DiaChi,
                x.QlBenhNhan.NgaySinh,
                x.QlBenhNhan.IdgioiTinh,
                FacilityCode = x.IdcskcbNavigation.MaCskcb
            })
            .SingleOrDefaultAsync(cancellationToken);
        if (visit == null) errors.Add("Không tìm thấy lượt khám của toa thuốc.");
        else
        {
            if (visit.TrangThaiKham != 2) errors.Add("Phải hoàn tất khám trước khi ký hoặc liên thông toa thuốc.");
            if (string.IsNullOrWhiteSpace(visit.PatientName) || visit.NgaySinh == null || visit.IdgioiTinh <= 0)
                errors.Add("Thiếu họ tên, ngày sinh hoặc giới tính bệnh nhân.");
            if (string.IsNullOrWhiteSpace(visit.PatientAddress))
                errors.Add("Thiếu địa chỉ bệnh nhân.");
            if (!string.IsNullOrWhiteSpace(visit.PatientCode) && visit.PatientCode.Trim().Length > 10)
                errors.Add("Mã định danh y tế của bệnh nhân vượt quá 10 ký tự theo đặc tả quốc gia.");
            if (visit.FacilityCode?.Trim().Length != 5)
                errors.Add("Mã cơ sở khám chữa bệnh phải có đúng 5 ký tự.");
            else if (!ToaThuocQuocGiaCode.IsValid(prescription.MaToaQuocGia, visit.FacilityCode, prescription.MaLoaiToaThuoc))
                errors.Add("Mã toa quốc gia không khớp mã cơ sở hoặc loại toa.");
        }

        var diagnosisCount = await _db.QlChanDoanCt.AsNoTracking()
            .CountAsync(x => x.Idcskcb == prescription.Idcskcb && x.IdvaoVien == prescription.IdvaoVien, cancellationToken);
        var mainDiagnosisCount = await _db.QlChanDoanCt.AsNoTracking()
            .CountAsync(x => x.Idcskcb == prescription.Idcskcb && x.IdvaoVien == prescription.IdvaoVien && x.BenhChinh, cancellationToken);
        if (diagnosisCount == 0 || mainDiagnosisCount != 1)
            errors.Add("Toa thuốc phải có đúng một chẩn đoán chính.");

        var medicineRows = await _db.QlToaThuocCt.AsNoTracking()
            .Where(x => x.Idcskcb == prescription.Idcskcb && x.IdtoaThuoc == prescription.Id && x.Active)
            .Select(x => new
            {
                x.Id,
                x.DmThuoc.TenThuoc,
                x.DmThuoc.MaThuocQuocGia,
                BietDuoc = x.HoatChat ?? x.DmThuoc.HoatChat,
                x.DmThuoc.DonViTinh
            })
            .ToListAsync(cancellationToken);
        if (medicineRows.Count == 0) errors.Add("Toa thuốc không có dòng thuốc đang hiệu lực.");
        var unmapped = medicineRows.Where(x => string.IsNullOrWhiteSpace(x.MaThuocQuocGia)).Select(x => x.TenThuoc).ToList();
        if (unmapped.Count > 0)
            errors.Add($"Thuốc chưa có mã quốc gia: {string.Join(", ", unmapped.Take(5))}{(unmapped.Count > 5 ? "..." : string.Empty)}.");
        if (medicineRows.Any(x => string.IsNullOrWhiteSpace(x.BietDuoc) || string.IsNullOrWhiteSpace(x.DonViTinh)))
            errors.Add("Mọi dòng thuốc phải có biệt dược/hoạt chất và đơn vị tính theo đặc tả quốc gia.");
    }

    private static string TaoCachDung(string? morning, string? noon, string? afternoon, string? evening, string? dose, string? instruction)
    {
        var parts = new[]
        {
            Pair("Sáng", morning), Pair("Trưa", noon), Pair("Chiều", afternoon), Pair("Tối", evening),
            NullIfWhiteSpace(dose), NullIfWhiteSpace(instruction)
        }.Where(x => !string.IsNullOrWhiteSpace(x));
        return string.Join("; ", parts!);
    }

    private static string? Pair(string label, string? value)
        => string.IsNullOrWhiteSpace(value) ? null : $"{label} {value.Trim()}";

    private static string? NullIfWhiteSpace(string? value)
        => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
