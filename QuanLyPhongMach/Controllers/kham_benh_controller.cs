using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using QuanLyPhongMach.Data;
using QuanLyPhongMach.Models.Requests.KhamBenh;
using QuanLyPhongMach.Services;
using QuanLyPhongMach.Services.Printing;

namespace QuanLyPhongMach.Controllers
{
    [yeu_cau_quyen_attribute("kham_benh", "Xem")]
    [Route("kham_benh")]
    public class kham_benh_controller : Controller
    {
        private readonly QlpmDbContext _db;
        private readonly IWebHostEnvironment _env;
        private readonly IKhamBenhPrintService _printService;
        private readonly ILogger<kham_benh_controller> _logger;
        private readonly QlpmDocumentStorage _storage;

        public kham_benh_controller(
            QlpmDbContext db,
            IWebHostEnvironment env,
            IKhamBenhPrintService printService,
            ILogger<kham_benh_controller> logger,
            QlpmDocumentStorage storage)
        {
            _db = db;
            _env = env;
            _printService = printService;
            _logger = logger;
            _storage = storage;
        }

        // Không cho phép mở lại hoặc ghi đè hồ sơ có TrangThaiKham = 2, kể cả quản trị.
        private Task<bool> LaLuotKhamDaXongAsync(long idCskcb, long idVaoVien)
        {
            return _db.QlVaoVien.AsNoTracking()
                .AnyAsync(v => v.Idcskcb == idCskcb && v.Id == idVaoVien
                    && v.Active && v.TrangThaiKham == 2);
        }

        [HttpGet("")]
        public IActionResult Index([FromQuery] long? id_vao_vien = null)
        {
            ViewBag.ActiveTab = "kham_benh";
            ViewBag.TargetIdVaoVien = id_vao_vien;
            ViewBag.CanSuaKham = User.CoQuyen("kham_benh", "Sua");
            ViewBag.CanLienThongToaThuoc = User.CoQuyen("lien_thong_toa_thuoc", "Sua");
            ViewData["Title"] = "Khám bệnh";
            return View("~/Views/kham_benh/Index.cshtml");
        }

        [HttpGet("/api/kham_benh/loai_toa")]
        public async Task<IActionResult> LayLoaiToaThuoc()
        {
            var source = await _db.DmLoaiToaThuoc.AsNoTracking()
                .Where(x => x.Active && (x.MaLoaiToaThuoc == "c" || x.MaLoaiToaThuoc == "n" || x.MaLoaiToaThuoc == "h"))
                .ToListAsync();

            // Giữ đúng contract JSON của HIS:
            // id/ma là c|n|h; viettat chỉ là mã hiển thị DTCB|DTGN|DTHTTVTTC.
            var ds = source
                .OrderBy(x => x.MaLoaiToaThuoc == "c" ? 0 : x.MaLoaiToaThuoc == "n" ? 1 : 2)
                .Select(x => new
                {
                    id = x.MaLoaiToaThuoc,
                    ma = x.MaLoaiToaThuoc,
                    ten = x.TenLoaiToaThuoc,
                    viettat = x.MaLoaiToaThuoc == "c"
                        ? "DTCB"
                        : x.MaLoaiToaThuoc == "n"
                            ? "DTGN"
                            : "DTHTTVTTC",
                    active = x.Active
                })
                .ToList();

            return Ok(new { status = 200, data = ds });
        }

        [HttpPost("/api/kham_benh/kiem_tra_ton_thuoc")]
        public async Task<IActionResult> KiemTraTonThuoc([FromBody] KiemTraTonThuocRequest? request)
        {
            var idCskcb = User.LayIdCskcb();
            if (idCskcb <= 0)
                return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước khi kiểm tra tồn thuốc." });

            var source = request?.danh_sach ?? new List<KiemTraTonThuocDongRequest>();
            var danhSach = source
                .Where(x => x.id_thuoc > 0 && x.so_luong >= 0)
                .Select(x => new
                {
                    row_index = x.row_index,
                    id_thuoc = x.id_thuoc,
                    id_don_vi_tinh = x.id_don_vi_tinh,
                    so_luong = x.so_luong
                })
                .ToList();

            if (danhSach.Count == 0)
                return Ok(new { status = 200, data = Array.Empty<object>() });

            var rows = await _db.LayDanhSachStoAsync("dbo.STO_QL_Kham_KiemTraTonThuoc", new
            {
                IDCSKCB = idCskcb,
                DanhSachJson = JsonSerializer.Serialize(danhSach)
            });

            return Ok(new { status = 200, data = rows });
        }

        [HttpPost("/api/kham_benh/in/chi_dinh")]
        public async Task<IActionResult> InChiDinh([FromBody] KhamBenhInRequest? request)
        {
            return await TaoPdfAsync(request, inToaThuoc: false);
        }

        [HttpPost("/api/kham_benh/in/toa_thuoc")]
        public async Task<IActionResult> InToaThuoc([FromBody] KhamBenhInRequest? request)
        {
            return await TaoPdfAsync(request, inToaThuoc: true);
        }

        private async Task<IActionResult> TaoPdfAsync(KhamBenhInRequest? request, bool inToaThuoc)
        {
            if (request == null)
                return BadRequest(new { status = 400, message = "Dữ liệu in không hợp lệ." });
            if (string.Equals(request.nguon, "ban_nhap", StringComparison.OrdinalIgnoreCase)
                && !User.CoQuyen("kham_benh", "Sua"))
                return Forbid();

            try
            {
                // Printing consumes the immutable signed file when one covers
                // the current saved revision. It never calls the signing provider.
                var signedRow = await _db.LayMotDongStoAsync("dbo.STO_QL_KySoPdf_In_HienTai", new
                {
                    IDCSKCB = User.LayIdCskcb(), IDVaoVien = request.id_vao_vien,
                    MaLoai = inToaThuoc ? "toa_thuoc" : "chi_dinh",
                    IDToaThuoc = inToaThuoc ? request.id_toa_thuoc : null,
                    NhomChiDinh = !inToaThuoc && request.gui_ngoai_chi_dinh.HasValue
                        ? (byte?)(request.gui_ngoai_chi_dinh.Value ? 1 : 0) : null
                });
                if (signedRow is IDictionary<string, object?> signed
                    && signed.TryGetValue("PdfDaKy", out var bytes) && bytes is byte[] pdf)
                {
                    if (!string.Equals(Services.KySoPdf.KySoPdfService.Hash(pdf), Convert.ToString(signed["Sha256DaKy"]), StringComparison.OrdinalIgnoreCase))
                        return Conflict(new { status = 409, message = "PDF đã ký không khớp hash lưu trữ; cần kiểm tra tài liệu." });
                    pdf = await _storage.ReadSignedPdfAsync(User.LayIdCskcb(), Convert.ToString(signed["Sha256DaKy"])!, pdf, HttpContext.RequestAborted);
                    Response.Headers["Cache-Control"] = "no-store";
                    Response.Headers["X-QLPM-PDF-Da-Ky"] = "true";
                    Response.Headers["X-QLPM-PDF-Trang-Thai"] = "DA_KY";
                    return File(pdf, "application/pdf", tep_tin_dich_vu.TaoTenTaiXuong("pdf-da-ky", Convert.ToString(signed["IDTaiLieu"]), "pdf"));
                }
                request.ky_so = false;
                var result = inToaThuoc
                    ? await _printService.InToaThuocAsync(request, User.LayIdCskcb(), User.LayIdNhanVien())
                    : await _printService.InChiDinhAsync(request, User.LayIdCskcb(), User.LayIdNhanVien());
                return File(result.Content, "application/pdf", result.FileName);
            }
            catch (KhamBenhPrintValidationException ex)
            {
                return BadRequest(new { status = 400, message = ex.Message });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Không tạo được PDF {LoaiPhieu} cho lượt khám {IDVaoVien}.",
                    inToaThuoc ? "toa thuốc" : "chỉ định", request.id_vao_vien);
                return StatusCode(500, new { status = 500, message = "Không tạo được file PDF. Vui lòng thử lại." });
            }
        }

        [HttpGet("/api/kham_benh/danh_sach")]
        public async Task<IActionResult> LayDanhSach(
            [FromQuery] DateTime? ngay = null,
            [FromQuery] byte? trang_thai_kham = null,
            [FromQuery] string? tu_khoa = null,
            [FromQuery] int trang = 1,
            [FromQuery] int kich_thuoc_trang = 20)
        {
            var idCskcb = User.LayIdCskcb();
            if (idCskcb <= 0) return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước khi khám." });

            var ds = await _db.LayDanhSachStoAsync("dbo.STO_QL_Kham_DanhSach", new
            {
                IDCSKCB = idCskcb,
                Ngay = ngay?.Date ?? DateTime.Today,
                TrangThaiKham = trang_thai_kham,
                TuKhoa = string.IsNullOrWhiteSpace(tu_khoa) ? null : tu_khoa.Trim(),
                Trang = Math.Max(1, trang),
                KichThuocTrang = Math.Min(100, Math.Max(10, kich_thuoc_trang))
            });

            return Ok(new { status = 200, message = "Thành công", data = ds });
        }

        [HttpPost("/api/kham_benh/chon_benh_nhan")]
        public async Task<IActionResult> ChonBenhNhan([FromBody] ChonBenhNhanRequest? request)
        {
            if (request == null || request.id_vao_vien <= 0)
                return Ok(new { status = 400, message = "Thiếu lượt khám." });

            var idCskcb = User.LayIdCskcb();
            var idBacSi = User.LayIdNhanVien();
            var laQuanTri = User.IsInRole("quan_tri_he_thong");
            if (idCskcb <= 0) return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước khi khám." });
            if (!laQuanTri && idBacSi <= 0) return Conflict(new { status = 409, message = "Tài khoản chưa có bác sĩ tại cơ sở này." });

            await using var multi = await _db.QueryMultipleStoAsync("dbo.STO_QL_Kham_ChonBenhNhan", new
            {
                IDCSKCB = idCskcb,
                IDVaoVien = request.id_vao_vien,
                IDBacSi = idBacSi,
                LaQuanTri = laQuanTri
            });

            var resStatus = await multi.ReadFirstOrDefaultAsync();
            int status = 500;
            string message = "Không tải được lượt khám.";
            if (resStatus != null)
            {
                var d = (IDictionary<string, object?>)resStatus;
                if (d.TryGetValue("Status", out var s) && s != null) status = Convert.ToInt32(s);
                if (d.TryGetValue("Message", out var m) && m != null && !string.IsNullOrWhiteSpace(Convert.ToString(m)))
                    message = Convert.ToString(m)!;
                else
                    message = status == 200 ? "Đã tải lượt khám." : "Không tải được lượt khám.";
            }

            if (status != 200)
            {
                return Ok(new { status, message });
            }

            var info = await multi.ReadFirstOrDefaultAsync();
            var vitals = await multi.ReadAsync();
            var diagnoses = await multi.ReadAsync();
            var orders = await multi.ReadAsync();
            var prescriptions = await multi.ReadAsync();

            return Ok(new
            {
                status = 200,
                message = "Thành công",
                data = new
                {
                    thong_tin = info,
                    sinh_hieu = vitals,
                    chan_doan = diagnoses,
                    chi_dinh = orders,
                    toa_thuoc = prescriptions
                }
            });
        }

        [HttpPost("/api/kham_benh/cap_nhat_dang_kham")]
        public async Task<IActionResult> CapNhatDangKham([FromBody] CapNhatDangKhamRequest? request)
        {
            if (request == null || request.id_vao_vien <= 0)
            {
                return Ok(new { status = 400, message = "Thiếu lượt khám." });
            }

            var idCskcb = User.LayIdCskcb();
            var idBacSi = User.LayIdNhanVien();
            var laQuanTri = User.IsInRole("quan_tri_he_thong");
            if (idCskcb <= 0) return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước khi khám." });
            if (!laQuanTri && idBacSi <= 0) return Conflict(new { status = 409, message = "Tài khoản chưa có bác sĩ tại cơ sở này." });
            if (await LaLuotKhamDaXongAsync(idCskcb, request.id_vao_vien))
                return Conflict(new { status = 409, message = "Lượt khám đã hoàn tất, không được thêm, sửa, xóa hoặc lưu dữ liệu khám." });

            var row = await _db.LayMotDongStoAsync("dbo.STO_QL_Kham_CapNhatDangKham", new
            {
                IDCSKCB = idCskcb,
                IDVaoVien = request.id_vao_vien,
                IDBacSi = idBacSi,
                LaQuanTri = laQuanTri
            });

            var status = 500;
            var message = "Không cập nhật được trạng thái khám.";
            if (row is IDictionary<string, object?> d)
            {
                if (d.TryGetValue("Status", out var s) && s != null) status = Convert.ToInt32(s);
                if (d.TryGetValue("Message", out var m) && m != null && !string.IsNullOrWhiteSpace(Convert.ToString(m)))
                    message = Convert.ToString(m)!;
                else
                    message = status == 200 ? "Đã cập nhật trạng thái khám." : "Không cập nhật được trạng thái khám.";
            }

            return Ok(new { status, message });
        }

        [HttpPost("/api/kham_benh/huy_dang_kham")]
        public async Task<IActionResult> HuyDangKham([FromBody] CapNhatDangKhamRequest? request)
        {
            if (request == null || request.id_vao_vien <= 0)
                return Ok(new { status = 400, message = "Thiếu id_vao_vien" });

            var idCskcb = User.LayIdCskcb();
            var idBacSi = User.LayIdNhanVien();
            var laQuanTri = User.IsInRole("quan_tri_he_thong");
            if (idCskcb <= 0) return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước khi khám." });
            if (!laQuanTri && idBacSi <= 0) return Conflict(new { status = 409, message = "Tài khoản chưa có bác sĩ tại cơ sở này." });

            var row = await _db.LayMotDongStoAsync("dbo.STO_QL_Kham_HuyDangKham", new
            {
                IDCSKCB = idCskcb,
                IDVaoVien = request.id_vao_vien,
                IDBacSi = idBacSi,
                LaQuanTri = laQuanTri
            });

            if (row is not IDictionary<string, object?> d)
                return Ok(new { status = 500, message = "Không hủy được trạng thái đang khám." });

            var status = d.TryGetValue("Status", out var s) && s != null ? Convert.ToInt32(s) : 500;
            var message = status == 200 ? "Đã hủy trạng thái đang khám." : "Không hủy được trạng thái đang khám.";
            return Ok(new { status, message });
        }

        [yeu_cau_quyen_attribute("kham_benh", "Sua")]
        [HttpPost("/api/kham_benh/luu")]
        public async Task<IActionResult> LuuKham([FromBody] KhamLuuRequest? request)
        {
            if (request == null || request.id_vao_vien <= 0)
                return Ok(new { status = 400, message = "Kiểm tra lại hồ sơ khám." });

            var idCskcb = User.LayIdCskcb();
            var idBacSi = User.LayIdNhanVien();
            var laQuanTri = User.IsInRole("quan_tri_he_thong");
            if (idCskcb <= 0) return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước khi khám." });
            if (!laQuanTri && idBacSi <= 0) return Conflict(new { status = 409, message = "Tài khoản chưa có bác sĩ tại cơ sở này." });
            if (await LaLuotKhamDaXongAsync(idCskcb, request.id_vao_vien))
                return Conflict(new { status = 409, message = "Lượt khám đã hoàn tất, không được thêm, sửa, xóa hoặc lưu dữ liệu khám." });
            string? sinhHieuJson = request.sinh_hieu is JsonElement jeSh ? jeSh.GetRawText() : (request.sinh_hieu != null ? JsonSerializer.Serialize(request.sinh_hieu) : null);
            string? chanDoanJson = request.chan_doan is JsonElement jeCd ? jeCd.GetRawText() : (request.chan_doan != null ? JsonSerializer.Serialize(request.chan_doan) : null);
            var soBenhChinh = string.IsNullOrWhiteSpace(chanDoanJson) ? 0 : DemBenhChinh(chanDoanJson);
            if ((request.kham_xong == true && soBenhChinh != 1) || (request.kham_xong != true && soBenhChinh > 1))
            {
                return Ok(new { status = 400, message = "Hoan tat can dung 1 ICD chinh; luu thuong cho phep toi da 1 ICD chinh." });
            }

            string? chiDinhJson = request.chi_dinh is JsonElement jeCi ? jeCi.GetRawText() : (request.chi_dinh != null ? JsonSerializer.Serialize(request.chi_dinh) : null);
            string? toaThuocJson = request.toa_thuoc is JsonElement jeTt ? jeTt.GetRawText() : (request.toa_thuoc != null ? JsonSerializer.Serialize(request.toa_thuoc) : null);

            var ketQua = await _db.LayMotDongStoAsync("dbo.STO_QL_Kham_Luu", new
            {
                IDCSKCB = idCskcb,
                IDVaoVien = request.id_vao_vien,
                IDBacSi = idBacSi,
                TrieuChung = request.trieu_chung,
                IDPhacDo = request.id_phac_do,
                MaPDGoc = request.ma_pd_goc,
                NgayTaiKham = request.ngay_tai_kham?.Date,
                DanDo = request.dan_do,
                SinhHieuJson = sinhHieuJson,
                ChanDoanJson = chanDoanJson,
                ChiDinhJson = chiDinhJson,
                ToaThuocJson = toaThuocJson,
                KhamXong = request.kham_xong == true,
                LaQuanTri = laQuanTri,
                CoQuyenSua = User.CoQuyen("kham_benh", "Sua")
            });

            int status = 500;
            string message = "Không lưu được hồ sơ khám.";

            if (ketQua is IDictionary<string, object?> dict)
            {
                if (dict.TryGetValue("Status", out var s) && s != null)
                    status = Convert.ToInt32(s);
                if (dict.TryGetValue("Message", out var stoMessage) && stoMessage != null)
                    message = stoMessage.ToString() ?? message;

                // Chỉ dọn file kết quả của chỉ định đã xóa sau khi STO commit thành công.
                // Đường dẫn được kiểm tra thuộc App_Data/cls hoặc cls-v2 trước khi xóa.
                if (status == 200
                    && dict.TryGetValue("FilesToDeleteJson", out var files)
                    && files != null)
                    XoaFileClsSauKhiLuu(files.ToString());
            }

            return Ok(new { status, message });
        }

        [yeu_cau_quyen_attribute("kham_benh", "Sua")]
        [HttpPost("/api/kham_benh/hoan_tat")]
        public async Task<IActionResult> HoanTatKham([FromBody] KhamHoanTatRequest? request)
        {
            if (request == null || request.id_vao_vien <= 0)
                return Ok(new { status = 400, message = "Kiểm tra lại lượt khám." });

            var idCskcb = User.LayIdCskcb();
            var idBacSi = User.LayIdNhanVien();
            var laQuanTri = User.IsInRole("quan_tri_he_thong");
            if (idCskcb <= 0) return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước khi khám." });
            if (!laQuanTri && idBacSi <= 0) return Conflict(new { status = 409, message = "Tài khoản chưa có bác sĩ tại cơ sở này." });
            if (await LaLuotKhamDaXongAsync(idCskcb, request.id_vao_vien))
                return Conflict(new { status = 409, message = "Lượt khám đã hoàn tất, không được thêm, sửa, xóa hoặc lưu dữ liệu khám." });

            var row = await _db.LayMotDongStoAsync("dbo.STO_QL_Kham_HoanTat", new
            {
                IDCSKCB = idCskcb,
                IDVaoVien = request.id_vao_vien,
                IDBacSi = idBacSi,
                LaQuanTri = laQuanTri
            });

            if (row is not IDictionary<string, object?> d)
                return Ok(new { status = 500, message = "Không hoàn tất được lượt khám." });

            var status = d.TryGetValue("Status", out var s) && s != null ? Convert.ToInt32(s) : 500;
            var message = d.TryGetValue("Message", out var m) && m != null
                ? m.ToString() ?? "Không hoàn tất được lượt khám."
                : "Không hoàn tất được lượt khám.";
            d.TryGetValue("TrangThaiKham", out var trangThaiKham);

            return Ok(new
            {
                status,
                message,
                data = new
                {
                    id_vao_vien = request.id_vao_vien,
                    da_luu_kham = status == 200,
                    trang_thai_kham = trangThaiKham
                }
            });
        }

        private void XoaFileClsSauKhiLuu(string? filesJson)
        {
            if (string.IsNullOrWhiteSpace(filesJson)) return;

            try
            {
                using var doc = JsonDocument.Parse(filesJson);
                if (doc.RootElement.ValueKind != JsonValueKind.Array) return;

                foreach (var item in doc.RootElement.EnumerateArray())
                {
                    if (!item.TryGetProperty("DuongDanTuongDoi", out var pathValue)
                        || pathValue.ValueKind != JsonValueKind.String)
                        continue;

                    try
                    {
                        var fullPath = ResolveClsFilePath(pathValue.GetString());
                        if (fullPath != null && System.IO.File.Exists(fullPath))
                            System.IO.File.Delete(fullPath);
                    }
                    catch (Exception ex)
                    {
                        Console.Error.WriteLine($"[kham_benh] Không xóa được file CLS '{pathValue.GetString()}': {ex}");
                    }
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"[kham_benh] Không đọc được danh sách file CLS cần xóa sau khi lưu: {ex}");
            }
        }

        private string? ResolveClsFilePath(string? relative)
        {
            if (string.IsNullOrWhiteSpace(relative)) return null;

            try
            {
                var full = Path.GetFullPath(Path.Combine(
                    _env.ContentRootPath,
                    relative.Replace('/', Path.DirectorySeparatorChar)));
                var allowedRoots = new[]
                {
                    Path.Combine(_env.ContentRootPath, "App_Data", "cls"),
                    Path.Combine(_env.ContentRootPath, "App_Data", "cls-v2")
                };

                foreach (var root in allowedRoots)
                {
                    var prefix = Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)
                        + Path.DirectorySeparatorChar;
                    if (full.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) return full;
                }
            }
            catch
            {
                return null;
            }

            return null;
        }

        private static int DemBenhChinh(string json)
        {
            try
            {
                using var doc = JsonDocument.Parse(json);
                if (doc.RootElement.ValueKind != JsonValueKind.Array) return 0;

                var count = 0;
                foreach (var item in doc.RootElement.EnumerateArray())
                {
                    JsonElement value;
                    if (!item.TryGetProperty("BenhChinh", out value)
                        && !item.TryGetProperty("benh_chinh", out value))
                        continue;

                    var isMain = value.ValueKind switch
                    {
                        JsonValueKind.True => true,
                        JsonValueKind.Number => value.TryGetInt32(out var n) && n == 1,
                        JsonValueKind.String => bool.TryParse(value.GetString(), out var b) && b,
                        _ => false
                    };

                    if (isMain) count++;
                }

                return count;
            }
            catch
            {
                return 0;
            }
        }

        [HttpGet("/api/kham_benh/lich_su")]
        public async Task<IActionResult> LayLichSu(
            [FromQuery] long? id_benh_nhan = null,
            [FromQuery] long? id_vao_vien_hien_tai = null,
            [FromQuery] string? tu_khoa = null,
            [FromQuery] int trang = 1,
            [FromQuery] int kich_thuoc_trang = 10)
        {
            var idCskcb = User.LayIdCskcb();
            if (idCskcb <= 0) return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước khi khám." });

            if (id_benh_nhan == null || id_benh_nhan <= 0)
            {
                return Ok(new { status = 200, message = "Chưa có bệnh nhân", data = Array.Empty<dynamic>() });
            }

            var ds = await _db.LayDanhSachStoAsync("dbo.STO_QL_Kham_LichSu", new
            {
                IDCSKCB = idCskcb,
                IDBenhNhan = id_benh_nhan.Value,
                IDVaoVienHienTai = id_vao_vien_hien_tai,
                TuKhoa = string.IsNullOrWhiteSpace(tu_khoa) ? null : tu_khoa.Trim(),
                Trang = Math.Max(1, trang),
                KichThuocTrang = Math.Min(100, Math.Max(10, kich_thuoc_trang))
            });

            return Ok(new { status = 200, message = "Thành công", data = ds });
        }

        [HttpGet("/api/kham_benh/lay_toa_cu")]
        public async Task<IActionResult> LayToaCu([FromQuery] long id_vao_vien_cu)
        {
            var idCskcb = User.LayIdCskcb();
            if (idCskcb <= 0) return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước khi khám." });

            var ds = await _db.LayDanhSachStoAsync("dbo.STO_QL_Kham_LayToaCu", new
            {
                IDCSKCB = idCskcb,
                IDVaoVienCu = id_vao_vien_cu
            });

            return Ok(new { status = 200, message = "Thành công", data = ds });
        }

        [HttpGet("/api/kham_benh/chi_tiet_lan_kham_cu")]
        public async Task<IActionResult> LayChiTietLanKhamCu([FromQuery] long id_vao_vien_cu)
        {
            var idCskcb = User.LayIdCskcb();
            if (idCskcb <= 0) return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước khi khám." });

            dynamic? info;
            IEnumerable<dynamic> sinhHieu;
            IEnumerable<dynamic> chanDoan;
            IEnumerable<dynamic> chiDinh;
            IEnumerable<dynamic> toaThuoc;

            await using (var multi = await _db.QueryMultipleStoAsync("dbo.STO_QL_Kham_ChiTietLanKhamCu", new
            {
                IDCSKCB = idCskcb,
                IDVaoVienCu = id_vao_vien_cu
            }))
            {
                info = await multi.ReadFirstOrDefaultAsync();
                if (info == null)
                {
                    return Ok(new { status = 404, message = "Không tìm thấy lần khám cũ." });
                }

                sinhHieu = await multi.ReadAsync();
                chanDoan = await multi.ReadAsync();
                chiDinh = await multi.ReadAsync();
                toaThuoc = await multi.ReadAsync();
            }

            return Ok(new
            {
                status = 200,
                message = "Thành công",
                data = new
                {
                    thong_tin = info,
                    sinh_hieu = sinhHieu,
                    chan_doan = chanDoan,
                    chi_dinh = chiDinh,
                    toa_thuoc = toaThuoc
                }
            });
        }

        [HttpGet("/api/kham_benh/viet_tat")]
        public async Task<IActionResult> LayDanhSachVietTat([FromQuery] string loai = "TRIEU_CHUNG")
        {
            var idCskcb = User.LayIdCskcb();
            if (idCskcb <= 0) return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước khi khám." });
            var idNhanVien = User.LayIdNhanVien();

            var ds = await _db.LayDanhSachStoAsync("dbo.STO_DM_VietTat_LayDanhSach", new
            {
                IDCSKCB = idCskcb,
                IDNhanVien = idNhanVien > 0 ? (long?)idNhanVien : null,
                Loai = string.IsNullOrWhiteSpace(loai) ? "TRIEU_CHUNG" : loai.Trim()
            });

            return Ok(new { status = 200, message = "Thành công", data = ds });
        }

        [HttpPost("/api/kham_benh/viet_tat")]
        public async Task<IActionResult> LuuDanhSachVietTat([FromBody] VietTatLuuRequest? request)
        {
            var idCskcb = User.LayIdCskcb();
            if (idCskcb <= 0) return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước khi khám." });
            var idNhanVien = User.LayIdNhanVien();

            string? jsonDanhSach = request?.danh_sach is JsonElement je
                ? je.GetRawText()
                : (request?.danh_sach != null ? JsonSerializer.Serialize(request.danh_sach) : null);

            var ketQua = await _db.LayMotDongStoAsync("dbo.STO_DM_VietTat_LuuDanhSach", new
            {
                IDCSKCB = idCskcb,
                IDNhanVien = idNhanVien > 0 ? (long?)idNhanVien : null,
                Loai = string.IsNullOrWhiteSpace(request?.loai) ? "TRIEU_CHUNG" : request.loai.Trim(),
                JsonDanhSach = jsonDanhSach
            });

            int status = 200;
            string message = "Đã lưu danh sách cụm từ viết tắt.";
            if (ketQua != null)
            {
                var dict = (IDictionary<string, object?>)ketQua;
                if (dict.TryGetValue("Status", out var s) && s != null) status = Convert.ToInt32(s);
                message = status == 200 ? "Đã lưu cụm từ viết tắt." : "Không lưu được cụm từ viết tắt.";
            }

            return Ok(new { status, message });
        }

    }
}
