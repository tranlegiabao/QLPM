using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Claims;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuanLyPhongMach.Data;
using QuanLyPhongMach.Entities;
using QuanLyPhongMach.Models.Requests.HeThong;
using QuanLyPhongMach.Models.ViewModels;
using QuanLyPhongMach.Services;

namespace QuanLyPhongMach.Controllers
{
    [Authorize]
    [Route("he_thong")]
    public class he_thong_controller : Controller
    {
        private readonly QlpmDbContext _db;
        private readonly danh_muc_json_dich_vu _danhMucJson;
        private readonly IWebHostEnvironment _env;
        private readonly QlpmDocumentStorage _storage;

        public he_thong_controller(
            QlpmDbContext db,
            danh_muc_json_dich_vu danhMucJson,
            IWebHostEnvironment env,
            QlpmDocumentStorage storage)
        {
            _db = db;
            _danhMucJson = danhMucJson;
            _env = env;
            _storage = storage;
        }

        [HttpGet("")]
        public async Task<IActionResult> Index([FromQuery] bool doi_co_so = false)
        {
            var coQuyenHeThong =
                User.IsInRole("quan_tri_he_thong")
                || User.CoQuyen("he_thong_nhan_vien", "Xem")
                || User.CoQuyen("he_thong_tai_khoan", "Xem")
                || User.CoQuyen("he_thong_vai_tro", "Xem")
                || User.CoQuyen("he_thong_phan_quyen", "Xem");

            if (!coQuyenHeThong) return NotFound();

            ViewBag.HienThiThanhPhanHe = false;
            ViewData["Title"] = "Quản trị hệ thống";

            if (User.IsInRole("quan_tri_he_thong"))
            {
                if (doi_co_so)
                    await CapNhatNguCanhCskcbAsync(null, null);

                return View("~/Views/he_thong/TongQuan.cshtml");
            }

            var idCskcb = User.LayIdCskcb();
            return idCskcb > 0
                ? Redirect($"/he_thong/cskcb/{idCskcb}")
                : NotFound();
        }

        [HttpGet("cskcb/{id:long?}")]
        public async Task<IActionResult> ChiTiet(long? id = null)
        {
            var laQuanTriHeThong = User.IsInRole("quan_tri_he_thong");
            var idTheoTaiKhoan = User.LayIdCskcb();

            if (!laQuanTriHeThong)
            {
                var coQuyenHeThong =
                    User.CoQuyen("he_thong_nhan_vien", "Xem")
                    || User.CoQuyen("he_thong_tai_khoan", "Xem")
                    || User.CoQuyen("he_thong_vai_tro", "Xem")
                    || User.CoQuyen("he_thong_phan_quyen", "Xem");
                if (!coQuyenHeThong || idTheoTaiKhoan <= 0) return NotFound();
                id = idTheoTaiKhoan;
            }

            var idCskcb = id.GetValueOrDefault();
            string tenCskcb = "Cơ sở KCB mới";

            if (idCskcb > 0)
            {
                if (!laQuanTriHeThong && idCskcb != idTheoTaiKhoan) return NotFound();

                var cs = await _db.DmCskcb.AsNoTracking()
                    .Where(x => x.Id == idCskcb)
                    .Select(x => new { x.Id, x.MaCskcb, x.TenCskcb, x.Active })
                    .FirstOrDefaultAsync();

                if (cs == null) return NotFound();
                tenCskcb = cs.TenCskcb;

                if (laQuanTriHeThong)
                {
                    if (cs.Active)
                        await CapNhatNguCanhCskcbAsync(cs.Id, cs.TenCskcb);
                    else
                        await CapNhatNguCanhCskcbAsync(null, null);
                }
            }
            else if (!laQuanTriHeThong)
            {
                return NotFound();
            }
            else
            {
                // Màn thêm CSKCB không phải ngữ cảnh nghiệp vụ.
                await CapNhatNguCanhCskcbAsync(null, null);
            }

            ViewBag.HienThiThanhPhanHe = false;
            ViewBag.IdCskcb = idCskcb;
            ViewBag.TenCskcb = tenCskcb;
            ViewBag.LaMoi = idCskcb <= 0;
            if (laQuanTriHeThong && idCskcb > 0)
                ViewBag.CauHinhCskcb = await TaiCauHinhHeThongAsync(idCskcb, tenCskcb);
            ViewData["Title"] = idCskcb > 0 ? $"Quản trị - {tenCskcb}" : "Thêm cơ sở KCB";
            return View("~/Views/he_thong/ChiTiet.cshtml");
        }

        private async Task<CauHinhHeThongViewModel> TaiCauHinhHeThongAsync(long idCskcb, string tenCskcb)
        {
            var rows = await _db.LayDanhSachStoAsync("dbo.STO_HT_Config_DanhSach", new
            {
                IDCSKCB = idCskcb
            });
            var danhSach = new List<CauHinhHeThongItemViewModel>();
            foreach (var row in rows)
            {
                var data = (IDictionary<string, object?>)row;
                danhSach.Add(new CauHinhHeThongItemViewModel
                {
                    MaChucNang = Convert.ToString(data["MaChucNang"]) ?? string.Empty,
                    HieuLuc = data["HieuLuc"] != null && Convert.ToBoolean(data["HieuLuc"]),
                    Nhom = Convert.ToString(data["Nhom"]) ?? string.Empty,
                    GhiChu = Convert.ToString(data["GhiChu"]) ?? string.Empty
                });
            }

            return new CauHinhHeThongViewModel
            {
                IdCskcb = idCskcb,
                TenCskcb = tenCskcb,
                DanhSach = danhSach
            };
        }

        [HttpGet("cau_hinh")]
        public async Task<IActionResult> CauHinh([FromQuery] long? id_cskcb = null)
        {
            if (!User.IsInRole("quan_tri_he_thong")) return NotFound();

            var idCskcb = LayIdCskcbQuanTri(id_cskcb);
            if (idCskcb <= 0) return NotFound();

            var cskcb = await _db.DmCskcb.AsNoTracking()
                .Where(x => x.Id == idCskcb)
                .Select(x => new { x.Id, x.TenCskcb })
                .FirstOrDefaultAsync();
            if (cskcb == null) return NotFound();

            ViewBag.HienThiThanhPhanHe = false;
            ViewData["Title"] = $"Cấu hình - {cskcb.TenCskcb}";
            var model = await TaiCauHinhHeThongAsync(cskcb.Id, cskcb.TenCskcb);
            return View("~/Views/he_thong/CauHinh.cshtml", model);
        }

        [HttpPost("/api/he_thong/cau_hinh/trang_thai")]
        [Authorize(Roles = "quan_tri_he_thong")]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> CauHinhTrangThai(
            [FromBody] CauHinhTrangThaiRequest? request,
            [FromQuery] long? id_cskcb = null)
        {
            if (!User.IsInRole("quan_tri_he_thong")) return Forbid();

            var idCskcb = LayIdCskcbQuanTri(id_cskcb);
            var maChucNang = request?.MaChucNang?.Trim().ToUpperInvariant();
            if (idCskcb <= 0 || string.IsNullOrWhiteSpace(maChucNang) || maChucNang.Length > 100 || request?.HieuLuc is null)
                return Ok(new { status = 400, message = "Dữ liệu cấu hình không hợp lệ." });
            var hieuLuc = request.HieuLuc.Value;

            var ketQua = await _db.LayMotDongStoAsync("dbo.STO_HT_Config_CapNhatTrangThai", new
            {
                IDCSKCB = idCskcb,
                MaChucNang = maChucNang,
                HieuLuc = hieuLuc
            });

            if (ketQua is not IDictionary<string, object?> data)
                return Ok(new { status = 500, message = "Không cập nhật được cấu hình." });

            var status = data.TryGetValue("Status", out var statusValue) && statusValue != null
                ? Convert.ToInt32(statusValue)
                : 500;
            var message = data.TryGetValue("Message", out var messageValue)
                ? Convert.ToString(messageValue)
                : null;

            return Ok(new
            {
                status,
                message = string.IsNullOrWhiteSpace(message)
                    ? (status == 200 ? "Đã cập nhật cấu hình." : "Không cập nhật được cấu hình.")
                    : message,
                data = status == 200
                    ? new { id_cskcb = idCskcb, ma_chuc_nang = maChucNang, hieu_luc = hieuLuc }
                    : null
            });
        }

        [HttpPost("/api/he_thong/cskcb/chon_lam_viec")]
        public async Task<IActionResult> CskcbChonLamViec([FromBody] CskcbChonLamViecRequest request)
        {
            if (!User.IsInRole("quan_tri_he_thong")) return Forbid();

            if (request.IdCskcb <= 0)
            {
                await CapNhatNguCanhCskcbAsync(null, null);
                return Ok(new { status = 200, message = "Đã bỏ chọn cơ sở KCB.", data = new { id_cskcb = 0L, ten_cskcb = "" } });
            }

            var cs = await _db.DmCskcb.AsNoTracking()
                .Where(x => x.Id == request.IdCskcb && x.Active)
                .Select(x => new { x.Id, x.TenCskcb })
                .FirstOrDefaultAsync();

            if (cs == null)
                return Ok(new { status = 404, message = "Cơ sở KCB không tồn tại hoặc đã ngừng hoạt động." });

            await CapNhatNguCanhCskcbAsync(cs.Id, cs.TenCskcb);
            return Ok(new
            {
                status = 200,
                message = $"Đã chọn cơ sở: {cs.TenCskcb}.",
                data = new { id_cskcb = cs.Id, ten_cskcb = cs.TenCskcb }
            });
        }

        [HttpGet("/api/he_thong/cskcb")]
        public async Task<IActionResult> CskcbDanhSach(
            [FromQuery] string? q = null,
            [FromQuery] string? ma_cskcb = null,
            [FromQuery] string? ten_cskcb = null,
            [FromQuery] string? ma_tinh = null,
            [FromQuery] string? ma_phuong_xa = null,
            [FromQuery] bool? active = null,
            [FromQuery] int trang = 1,
            [FromQuery] int kich_thuoc_trang = 25)
        {
            if (!User.IsInRole("quan_tri_he_thong")) return Forbid();

            var ds = await _db.LayDanhSachStoAsync("dbo.STO_HT_CSKCB_Danh_Sach", new
            {
                TuKhoa = string.IsNullOrWhiteSpace(q) ? null : q.Trim(),
                MaCSKCB = string.IsNullOrWhiteSpace(ma_cskcb) ? null : ma_cskcb.Trim(),
                TenCSKCB = string.IsNullOrWhiteSpace(ten_cskcb) ? null : ten_cskcb.Trim(),
                MaTinh = string.IsNullOrWhiteSpace(ma_tinh) ? null : ma_tinh.Trim(),
                MaPhuongXa = string.IsNullOrWhiteSpace(ma_phuong_xa) ? null : ma_phuong_xa.Trim(),
                Active = active,
                Trang = Math.Max(1, trang),
                KichThuocTrang = Math.Min(100, Math.Max(10, kich_thuoc_trang))
            });
            return Ok(new { status = 200, message = "Thành công", data = ds });
        }

        [HttpGet("/api/he_thong/dia_chi/tinh_thanh")]
        public async Task<IActionResult> DiaChiTinhThanh()
        {
            var ds = await _db.DmTinhThanh.AsNoTracking()
                .Where(x => x.Active)
                .GroupBy(x => new { x.MaTinh, x.TenTinh })
                .Select(g => new { ma = g.Key.MaTinh, ten = g.Key.TenTinh })
                .OrderBy(x => x.ten)
                .ToListAsync();

            return Ok(new { status = 200, data = ds });
        }

        [HttpGet("/api/he_thong/dia_chi/phuong_xa")]
        public async Task<IActionResult> DiaChiPhuongXa([FromQuery] string? ma_tinh = null)
        {
            ma_tinh = string.IsNullOrWhiteSpace(ma_tinh) ? null : ma_tinh.Trim();
            if (ma_tinh == null)
                return Ok(new { status = 200, data = Array.Empty<object>() });

            var ds = await (
                from p in _db.DmPhuongXa.AsNoTracking()
                join t in _db.DmTinhThanh.AsNoTracking()
                    on new { p.Idcskcb, Id = p.IdtinhThanh } equals new { t.Idcskcb, Id = t.Id }
                where p.Active && t.Active && t.MaTinh == ma_tinh
                group p by new { p.MaPhuongXa, p.TenPhuongXa } into g
                orderby g.Key.TenPhuongXa
                select new { ma = g.Key.MaPhuongXa, ten = g.Key.TenPhuongXa }
            ).ToListAsync();

            return Ok(new { status = 200, data = ds });
        }

        [HttpGet("/api/he_thong/cskcb/{id:long}")]
        public async Task<IActionResult> CskcbChiTiet(long id)
        {
            var laQuanTriHeThong = User.IsInRole("quan_tri_he_thong");
            var idTheoTaiKhoan = User.LayIdCskcb();
            if (id <= 0 || (!laQuanTriHeThong && id != idTheoTaiKhoan)) return NotFound();

            var x = await _db.DmCskcb.AsNoTracking()
                .Where(c => c.Id == id)
                .Select(c => new
                {
                    IDCSKCB = c.Id,
                    MaCSKCB = c.MaCskcb,
                    TenCSKCB = c.TenCskcb,
                    c.DiaChi,
                    c.SoNhaTenDuong,
                    SDT = c.Sdt,
                    c.MaTinh,
                    c.MaPhuongXa,
                    c.Email,
                    MaST = c.MaSt,
                    SoTK = c.SoTk,
                    IDNganHang = c.IdnganHang,
                    c.UrlLogo,
                    c.Active
                })
                .FirstOrDefaultAsync();

            return x == null
                ? NotFound()
                : Ok(new { status = 200, message = "Thành công", data = x });
        }

        [HttpGet("/api/he_thong/cskcb/hien_tai")]
        public async Task<IActionResult> CskcbHienTai()
        {
            var idCskcb = User.LayIdCskcb();
            if (idCskcb <= 0)
                return Ok(new { status = 200, message = "Không có cơ sở KCB hiện tại", data = (object?)null });

            var x = await _db.DmCskcb.AsNoTracking()
                .Where(c => c.Id == idCskcb)
                .Select(c => new
                {
                    id = c.Id,
                    ten_cskcb = c.TenCskcb,
                    dia_chi = c.DiaChi ?? string.Empty,
                    so_nha_ten_duong = c.SoNhaTenDuong ?? string.Empty,
                    sdt = c.Sdt ?? string.Empty,
                    email = c.Email ?? string.Empty,
                    url_logo = c.UrlLogo ?? string.Empty
                })
                .FirstOrDefaultAsync();

            return x == null
                ? Ok(new { status = 200, message = "Không tìm thấy cơ sở KCB", data = (object?)null })
                : Ok(new { status = 200, message = "Thành công", data = x });
        }

        [HttpPost("/api/he_thong/cskcb/luu")]
        public async Task<IActionResult> CskcbLuu([FromBody] CskcbLuuRequest request)
        {
            if (!User.IsInRole("quan_tri_he_thong")) return Forbid();

            if (string.IsNullOrWhiteSpace(request.MaCskcb) || string.IsNullOrWhiteSpace(request.TenCskcb))
                return Ok(new { status = 400, message = "Nhập mã và tên cơ sở KCB." });

            var sdt = request.Sdt?.Trim();
            if (!string.IsNullOrWhiteSpace(sdt) && !Regex.IsMatch(sdt, @"^\d{1,10}$"))
                return Ok(new { status = 400, message = "Số điện thoại chỉ nhập tối đa 10 chữ số." });

            var logoCu = request.IdCskcb.GetValueOrDefault() > 0
                ? await _db.DmCskcb.AsNoTracking()
                    .Where(x => x.Id == request.IdCskcb.Value)
                    .Select(x => x.UrlLogo)
                    .FirstOrDefaultAsync()
                : null;

            var ketQua = await _db.LayMotDongStoAsync("dbo.STO_HT_CSKCB_Luu", new
            {
                IDCSKCB = request.IdCskcb,
                MaCSKCB = request.MaCskcb.Trim(),
                TenCSKCB = request.TenCskcb.Trim(),
                SoNhaTenDuong = request.SoNhaTenDuong?.Trim(),
                MaTinh = request.MaTinh?.Trim(),
                MaPhuongXa = request.MaPhuongXa?.Trim(),
                SDT = sdt,
                Email = request.Email?.Trim(),
                MaST = request.MaSt?.Trim(),
                SoTK = request.SoTk?.Trim(),
                IDNganHang = request.IdNganHang,
                UrlLogo = request.UrlLogo?.Trim(),
                Active = request.Active
            });

            if (ketQua is IDictionary<string, object?> kq
                && kq.TryGetValue("Status", out var statusObj)
                && statusObj != null
                && Convert.ToInt32(statusObj) == 200)
            {
                var logoMoi = request.UrlLogo?.Trim();
                if (!string.Equals(logoCu, logoMoi, StringComparison.OrdinalIgnoreCase))
                    await XoaLogoNoiBoAsync(logoCu);
            }

            return TraKetQua(ketQua, "Đã lưu cơ sở KCB.", "Không lưu được cơ sở KCB.");
        }

        [HttpPost("/api/he_thong/cskcb/logo")]
        [RequestSizeLimit(6 * 1024 * 1024)]
        public async Task<IActionResult> CskcbLogo([FromForm] long id_cskcb, [FromForm] IFormFile? file)
        {
            if (!User.IsInRole("quan_tri_he_thong")) return Forbid();
            if (id_cskcb <= 0)
                return Ok(new { status = 400, message = "Lưu cơ sở KCB trước khi tải ảnh." });
            if (file == null || file.Length == 0)
                return Ok(new { status = 400, message = "Chưa chọn hình ảnh." });
            if (file.Length > 5 * 1024 * 1024)
                return Ok(new { status = 400, message = "Hình ảnh tối đa 5 MB." });

            var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
            if (ext is not ".jpg" and not ".jpeg" and not ".png" and not ".webp" and not ".gif")
                return Ok(new { status = 400, message = "Chỉ hỗ trợ JPG, PNG, WEBP hoặc GIF." });

            await using (var input = file.OpenReadStream())
            {
                var header = new byte[12];
                var read = await input.ReadAsync(header.AsMemory(0, header.Length));
                if (!LaChuKyAnhHopLe(header, read, ext))
                    return Ok(new { status = 400, message = "File ảnh không hợp lệ." });
            }

            var cskcb = await _db.DmCskcb.FirstOrDefaultAsync(x => x.Id == id_cskcb);
            if (cskcb == null)
                return Ok(new { status = 404, message = "Không tìm thấy cơ sở KCB." });

            var fileName = tep_tin_dich_vu.TaoTenLuuTru("logo", id_cskcb, ext);
            var logoUrl = QlpmDocumentStorage.LogoUrlPrefix + fileName;

            try
            {
                await using (var input = file.OpenReadStream())
                    await _storage.UploadLogoAsync(logoUrl, input, HttpContext.RequestAborted);

                var logoCu = cskcb.UrlLogo;
                cskcb.UrlLogo = logoUrl;
                await _db.SaveChangesAsync(HttpContext.RequestAborted);

                if (!string.Equals(logoCu, cskcb.UrlLogo, StringComparison.OrdinalIgnoreCase))
                    await XoaLogoNoiBoAsync(logoCu);

                return Ok(new
                {
                    status = 200,
                    message = "Đã lưu hình ảnh.",
                    data = new { url = cskcb.UrlLogo, ten_file = fileName }
                });
            }
            catch
            {
                await XoaLogoNoiBoAsync(logoUrl);
                throw;
            }
        }

        [HttpGet("/uploads/cskcb-logo/{fileName}")]
        public async Task<IActionResult> DocLogoCskcb(string fileName)
        {
            var url = QlpmDocumentStorage.LogoUrlPrefix + fileName;
            var laQuanTri = User.IsInRole("quan_tri_he_thong");
            var tenant = User.LayIdCskcb();
            if (!await _db.DmCskcb.AsNoTracking().AnyAsync(x => x.UrlLogo == url
                && (laQuanTri || x.Id == tenant), HttpContext.RequestAborted)) return NotFound();
            var mime = QlpmDocumentStorage.LogoContentType(url);
            if (mime == null) return NotFound();
            var bytes = await _storage.ReadLogoAsync(url, HttpContext.RequestAborted);
            if (bytes == null) return NotFound();
            Response.Headers["X-Content-Type-Options"] = "nosniff";
            Response.Headers["Cache-Control"] = "no-store";
            return File(bytes, mime);
        }

        [HttpPost("/api/he_thong/cskcb/xoa")]
        public async Task<IActionResult> CskcbXoa([FromBody] CskcbXoaRequest request)
        {
            if (!User.IsInRole("quan_tri_he_thong")) return Forbid();
            if (request.IdCskcb <= 0)
                return Ok(new { status = 400, message = "Thiếu cơ sở KCB cần xóa." });

            var xoaCskcbDangDung = request.IdCskcb == User.LayIdCskcb();
            var logoCu = await _db.DmCskcb.AsNoTracking()
                .Where(x => x.Id == request.IdCskcb)
                .Select(x => x.UrlLogo)
                .FirstOrDefaultAsync();
            var ketQua = await _db.LayMotDongStoAsync("dbo.STO_HT_CSKCB_Xoa", new { IDCSKCB = request.IdCskcb });

            if (ketQua is not IDictionary<string, object?> d)
                return Ok(new { status = 500, message = "Không xóa được cơ sở KCB." });

            var status = d.TryGetValue("Status", out var s) && s != null ? Convert.ToInt32(s) : 500;
            if (status != 200) return Ok(new { status, message = "Không xóa được cơ sở KCB." });

            await XoaLogoNoiBoAsync(logoCu);
            var canhBaoFile = XoaDuLieuVatLyCskcb(request.IdCskcb);
            if (xoaCskcbDangDung)
                await CapNhatNguCanhCskcbAsync(null, null);

            return Ok(new
            {
                status = canhBaoFile.Count == 0 ? 200 : 207,
                message = canhBaoFile.Count == 0
                    ? "Đã xóa cơ sở KCB và dữ liệu liên quan."
                    : "Đã xóa dữ liệu, nhưng còn file chưa xóa được.",
                data = new { dang_xuat = false, bo_ngu_canh = xoaCskcbDangDung, canh_bao_file = canhBaoFile }
            });
        }

        [HttpGet("/api/he_thong/chuc_danh")]
        public async Task<IActionResult> ChucDanhDanhSach(
            [FromQuery] string? q = null,
            [FromQuery] int trang = 1,
            [FromQuery] int kich_thuoc_trang = 25)
        {
            if (!User.IsInRole("quan_tri_he_thong")) return Forbid();

            q = string.IsNullOrWhiteSpace(q) ? null : q.Trim();
            trang = Math.Max(1, trang);
            kich_thuoc_trang = Math.Min(100, Math.Max(10, kich_thuoc_trang));

            var query = _db.DmChucDanh.AsNoTracking().AsQueryable();
            if (q != null)
            {
                query = query.Where(x =>
                    x.MaChucDanh.Contains(q) ||
                    x.TenChucDanh.Contains(q) ||
                    (x.VietTat != null && x.VietTat.Contains(q)));
            }

            var tong = await query.CountAsync();
            var ds = await query
                .OrderByDescending(x => x.Active)
                .ThenBy(x => x.TenChucDanh)
                .ThenBy(x => x.Id)
                .Skip((trang - 1) * kich_thuoc_trang)
                .Take(kich_thuoc_trang)
                .Select(x => new
                {
                    IDChucDanh = x.Id,
                    x.MaChucDanh,
                    x.TenChucDanh,
                    x.VietTat,
                    x.Active
                })
                .ToListAsync();

            var data = ds.Select(x => new
            {
                x.IDChucDanh,
                x.MaChucDanh,
                x.TenChucDanh,
                x.VietTat,
                x.Active,
                TongSoDong = tong
            });
            return Ok(new { status = 200, message = "Thành công", data });
        }

        [HttpPost("/api/he_thong/chuc_danh/luu")]
        public async Task<IActionResult> ChucDanhLuu([FromBody] ChucDanhLuuRequest request)
        {
            if (!User.IsInRole("quan_tri_he_thong")) return Forbid();

            var ma = request.MaChucDanh?.Trim();
            var ten = request.TenChucDanh?.Trim();
            var vietTat = request.VietTat?.Trim();
            if (string.IsNullOrWhiteSpace(ma) || string.IsNullOrWhiteSpace(ten))
                return Ok(new { status = 400, message = "Nhập mã và tên chức danh." });
            if (ma.Length > 60 || ten.Length > 200 || (vietTat?.Length ?? 0) > 50)
                return Ok(new { status = 400, message = "Mã, tên hoặc viết tắt chức danh vượt độ dài cho phép." });

            var trung = await _db.DmChucDanh.AsNoTracking().AnyAsync(x =>
                (x.MaChucDanh.ToLower() == ma.ToLower()
                 || x.TenChucDanh.ToLower() == ten.ToLower())
                && (!request.IdChucDanh.HasValue || x.Id != request.IdChucDanh.Value));
            if (trung)
                return Ok(new { status = 409, message = "Mã hoặc tên chức danh đã tồn tại." });

            DmChucDanh entity;
            if (request.IdChucDanh.GetValueOrDefault() > 0)
            {
                entity = await _db.DmChucDanh.FirstOrDefaultAsync(x => x.Id == request.IdChucDanh!.Value);
                if (entity == null)
                    return Ok(new { status = 404, message = "Không tìm thấy chức danh." });
            }
            else
            {
                entity = new DmChucDanh();
                _db.DmChucDanh.Add(entity);
            }

            entity.MaChucDanh = ma;
            entity.TenChucDanh = ten;
            entity.VietTat = string.IsNullOrWhiteSpace(vietTat) ? null : vietTat;
            entity.Active = request.Active;
            await _db.SaveChangesAsync();

            var cskcbIds = await _db.DmCskcb.AsNoTracking()
                .Where(x => x.Active)
                .Select(x => x.Id)
                .ToListAsync();
            foreach (var id in cskcbIds)
                await _danhMucJson.DanhDauThayDoiDanhMucAsync(id);

            return Ok(new
            {
                status = 200,
                message = "Đã lưu chức danh. Danh mục JSON đã được đánh dấu chờ đồng bộ.",
                data = new { id_chuc_danh = entity.Id }
            });
        }

        [HttpPost("/api/he_thong/chuc_danh/xoa")]
        public async Task<IActionResult> ChucDanhXoa([FromBody] ChucDanhXoaRequest request)
        {
            if (!User.IsInRole("quan_tri_he_thong")) return Forbid();
            if (request.IdChucDanh <= 0)
                return Ok(new { status = 400, message = "Thiếu chức danh cần xóa." });

            var entity = await _db.DmChucDanh.FirstOrDefaultAsync(x => x.Id == request.IdChucDanh);
            if (entity == null)
                return Ok(new { status = 404, message = "Không tìm thấy chức danh." });

            if (await _db.DmNhanVien.AsNoTracking().AnyAsync(x => x.IdchucDanh == request.IdChucDanh))
                return Ok(new { status = 409, message = "Chức danh đang được nhân viên sử dụng. Hãy đổi chức danh nhân viên trước khi xóa." });

            _db.DmChucDanh.Remove(entity);
            await _db.SaveChangesAsync();

            var cskcbIds = await _db.DmCskcb.AsNoTracking()
                .Where(x => x.Active)
                .Select(x => x.Id)
                .ToListAsync();
            foreach (var id in cskcbIds)
                await _danhMucJson.DanhDauThayDoiDanhMucAsync(id);

            return Ok(new { status = 200, message = "Đã xóa chức danh." });
        }


        [HttpGet("/api/he_thong/nhan_vien")]
        [yeu_cau_quyen_attribute("he_thong_nhan_vien", "Xem")]
        public async Task<IActionResult> NhanVienDanhSach(
            [FromQuery] long? id_cskcb = null,
            [FromQuery] string? q = null,
            [FromQuery] int trang = 1,
            [FromQuery] int kich_thuoc_trang = 25)
        {
            var ds = await _db.LayDanhSachStoAsync("dbo.STO_HT_Nhan_Vien_Danh_Sach", new
            {
                IDCSKCB = LayIdCskcbLoc(id_cskcb),
                TuKhoa = q,
                Trang = Math.Max(1, trang),
                KichThuocTrang = Math.Min(100, Math.Max(10, kich_thuoc_trang))
            });
            return Ok(new { status = 200, message = "Thành công", data = ds });
        }

        [HttpGet("/api/he_thong/nhan_vien_lookup")]
        [yeu_cau_quyen_attribute("he_thong_tai_khoan", "Xem")]
        public async Task<IActionResult> NhanVienLookup([FromQuery] long? id_cskcb = null, [FromQuery] string? q = null, [FromQuery] int top = 30)
        {
            var ds = await _db.LayDanhSachStoAsync("dbo.STO_HT_Nhan_Vien_Danh_Sach", new
            {
                IDCSKCB = LayIdCskcbQuanTri(id_cskcb),
                TuKhoa = q,
                Trang = 1,
                KichThuocTrang = Math.Min(100, Math.Max(10, top))
            });
            return Ok(new { status = 200, data = ds });
        }

        [HttpPost("/api/he_thong/nhan_vien/luu")]
        public async Task<IActionResult> NhanVienLuu([FromBody] NhanVienLuuRequest request, [FromQuery] long? id_cskcb = null)
        {
            var quyenCan = request.IdNhanVien.GetValueOrDefault() > 0 ? "Sua" : "Them";
            if (!User.CoQuyen("he_thong_nhan_vien", quyenCan)) return Forbid();

            if (string.IsNullOrWhiteSpace(request.MaNhanVien) || string.IsNullOrWhiteSpace(request.HoTen))
                return Ok(new { status = 400, message = "Nhập mã nhân viên và họ tên." });

            var dienThoai = request.DienThoai?.Trim();
            if (!string.IsNullOrWhiteSpace(dienThoai) && !Regex.IsMatch(dienThoai, @"^\d{1,10}$"))
                return Ok(new { status = 400, message = "Số điện thoại chỉ nhập tối đa 10 chữ số." });

            var idCskcbDangLam = LayIdCskcbQuanTri(id_cskcb);
            if (idCskcbDangLam <= 0)
                return Ok(new { status = 400, message = "Chọn cơ sở KCB." });

            // Lưu tại cơ sở đang quản lý, không nhận danh sách phân công từ form.
            // STO đồng bộ toàn bộ danh sách nên giữ các phân công hiện có khi sửa.
            var cskcbIds = new List<long>();
            if (request.IdNhanVien.GetValueOrDefault() > 0)
            {
                cskcbIds = await _db.DmNhanVienCskcb.AsNoTracking()
                    .Where(x => x.IdnhanVien == request.IdNhanVien!.Value && x.Active)
                    .Select(x => x.Idcskcb)
                    .ToListAsync();
            }
            if (!cskcbIds.Contains(idCskcbDangLam))
                cskcbIds.Add(idCskcbDangLam);

            var ketQua = await _db.LayMotDongStoAsync("dbo.STO_HT_Nhan_Vien_Luu", new
            {
                IDCSKCB = idCskcbDangLam,
                IDNhanVien = request.IdNhanVien,
                MaNhanVien = request.MaNhanVien.Trim(),
                HoTen = request.HoTen.Trim(),
                LaBacSi = request.LaBacSi,
                IDChucDanh = request.IdChucDanh,
                CSKCBJson = JsonSerializer.Serialize(cskcbIds),
                DienThoai = dienThoai,
                SoNhaTenDuong = request.SoNhaTenDuong?.Trim(),
                MaTinh = request.MaTinh?.Trim(),
                MaPhuongXa = request.MaPhuongXa?.Trim(),
                Email = request.Email?.Trim(),
                Active = request.Active
            });

            if (ketQua != null && Convert.ToInt32(ketQua.Status) == 200)
            {
                foreach (var id in cskcbIds)
                    await _danhMucJson.DanhDauThayDoiDanhMucAsync(id);
            }

            return TraKetQua(ketQua, "Đã lưu nhân viên.", "Không lưu được nhân viên.");
        }


        [HttpPost("/api/he_thong/nhan_vien/xoa")]
        [yeu_cau_quyen_attribute("he_thong_nhan_vien", "Xoa")]
        public async Task<IActionResult> NhanVienXoa([FromBody] NhanVienXoaRequest request, [FromQuery] long? id_cskcb = null)
        {
            if (request.IdNhanVien <= 0)
                return Ok(new { status = 400, message = "Thiếu nhân viên cần xóa." });
            if (request.IdNhanVien == User.LayIdNhanVien())
                return Ok(new { status = 400, message = "Không thể xóa nhân viên đang đăng nhập." });

            var targetCskcb = LayIdCskcbQuanTri(id_cskcb);
            var ketQua = await _db.LayMotDongStoAsync("dbo.STO_HT_Nhan_Vien_Xoa", new
            {
                IDCSKCB = targetCskcb,
                IDNhanVien = request.IdNhanVien
            });
            if (ketQua != null && Convert.ToInt32(ketQua.Status) == 200)
            {
                await _danhMucJson.DanhDauThayDoiDanhMucAsync(targetCskcb);
            }
            return TraKetQua(ketQua, "Đã xóa nhân viên.", "Không xóa được nhân viên.");
        }

        [HttpGet("/api/he_thong/tai_khoan")]
        [yeu_cau_quyen_attribute("he_thong_tai_khoan", "Xem")]
        public async Task<IActionResult> TaiKhoanDanhSach(
            [FromQuery] long? id_cskcb = null,
            [FromQuery] string? q = null,
            [FromQuery] int trang = 1,
            [FromQuery] int kich_thuoc_trang = 25)
        {
            var ds = await _db.LayDanhSachStoAsync("dbo.STO_HT_Tai_Khoan_Danh_Sach", new
            {
                IDCSKCB = LayIdCskcbLoc(id_cskcb),
                TuKhoa = q,
                Trang = Math.Max(1, trang),
                KichThuocTrang = Math.Min(100, Math.Max(10, kich_thuoc_trang))
            });
            return Ok(new { status = 200, message = "Thành công", data = ds });
        }

        [HttpPost("/api/he_thong/tai_khoan/luu")]
        public async Task<IActionResult> TaiKhoanLuu([FromBody] TaiKhoanLuuRequest request, [FromQuery] long? id_cskcb = null)
        {
            var quyenCan = request.IdTaiKhoan.GetValueOrDefault() > 0 ? "Sua" : "Them";
            if (!User.CoQuyen("he_thong_tai_khoan", quyenCan)) return Forbid();

            if (request.IdNhanVien <= 0 || string.IsNullOrWhiteSpace(request.TenDangNhap))
                return Ok(new { status = 400, message = "Chọn nhân viên và nhập tên đăng nhập." });

            var tenDangNhap = request.TenDangNhap.Trim();
            var matKhau = request.IdTaiKhoan.GetValueOrDefault() <= 0 ? "a" : null;

            var ketQua = await _db.LayMotDongStoAsync("dbo.STO_HT_Tai_Khoan_Luu", new
            {
                IDCSKCB = LayIdCskcbQuanTri(id_cskcb),
                ID_Tai_Khoan = request.IdTaiKhoan,
                IDNhanVien = request.IdNhanVien,
                Ten_Dang_Nhap = tenDangNhap,
                Mat_Khau_Hash = matKhau,
                Vai_Tro_Json = JsonSerializer.Serialize(request.VaiTroIds ?? new List<long>())
            });

            return TraKetQua(ketQua, "Đã lưu tài khoản.", "Không lưu được tài khoản.");
        }

        [HttpPost("/api/he_thong/tai_khoan/trang_thai")]
        [yeu_cau_quyen_attribute("he_thong_tai_khoan", "Sua")]
        public async Task<IActionResult> TaiKhoanTrangThai([FromBody] TaiKhoanTrangThaiRequest request, [FromQuery] long? id_cskcb = null)
        {
            if (request.IdTaiKhoan == User.LayIdTaiKhoan() && !request.Active)
                return Ok(new { status = 400, message = "Không thể tự khóa tài khoản." });

            var ketQua = await _db.LayMotDongStoAsync("dbo.STO_HT_Tai_Khoan_Doi_Trang_Thai", new
            {
                IDCSKCB = LayIdCskcbQuanTri(id_cskcb),
                ID_Tai_Khoan = request.IdTaiKhoan,
                Active = request.Active
            });
            return TraKetQua(ketQua, "Đã cập nhật tài khoản.", "Không cập nhật được tài khoản.");
        }

        [HttpPost("/api/he_thong/tai_khoan/xoa")]
        [yeu_cau_quyen_attribute("he_thong_tai_khoan", "Xoa")]
        public async Task<IActionResult> TaiKhoanXoa([FromBody] TaiKhoanXoaRequest request, [FromQuery] long? id_cskcb = null)
        {
            if (request.IdTaiKhoan <= 0)
                return Ok(new { status = 400, message = "Thiếu tài khoản cần xóa." });
            if (request.IdTaiKhoan == User.LayIdTaiKhoan())
                return Ok(new { status = 400, message = "Không thể tự xóa tài khoản." });

            var ketQua = await _db.LayMotDongStoAsync("dbo.STO_HT_Tai_Khoan_Xoa", new
            {
                IDCSKCB = LayIdCskcbQuanTri(id_cskcb),
                ID_Tai_Khoan = request.IdTaiKhoan
            });
            return TraKetQua(ketQua, "Đã xóa tài khoản.", "Không xóa được tài khoản.");
        }

        [HttpGet("/api/he_thong/vai_tro")]
        [yeu_cau_quyen_attribute("he_thong_vai_tro", "Xem")]
        public async Task<IActionResult> VaiTroDanhSach(
            [FromQuery] long? id_cskcb = null,
            [FromQuery] string? q = null,
            [FromQuery] int trang = 1,
            [FromQuery] int kich_thuoc_trang = 25)
        {
            var ds = await _db.LayDanhSachStoAsync("dbo.STO_HT_Vai_Tro_Danh_Sach", new
            {
                IDCSKCB = LayIdCskcbLoc(id_cskcb),
                TuKhoa = q,
                Trang = Math.Max(1, trang),
                KichThuocTrang = Math.Min(100, Math.Max(10, kich_thuoc_trang))
            });
            return Ok(new { status = 200, message = "Thành công", data = ds });
        }

        [HttpGet("/api/he_thong/vai_tro_lookup")]
        [yeu_cau_quyen_attribute("he_thong_vai_tro", "Xem")]
        public async Task<IActionResult> VaiTroLookup([FromQuery] long? id_cskcb = null, [FromQuery] string? q = null, [FromQuery] int top = 100)
        {
            var ds = await _db.LayDanhSachStoAsync("dbo.STO_HT_Vai_Tro_Danh_Sach", new
            {
                IDCSKCB = LayIdCskcbQuanTri(id_cskcb),
                TuKhoa = q,
                Trang = 1,
                KichThuocTrang = Math.Min(100, Math.Max(10, top))
            });
            return Ok(new { status = 200, data = ds });
        }

        [HttpPost("/api/he_thong/vai_tro/luu")]
        public async Task<IActionResult> VaiTroLuu([FromBody] VaiTroLuuRequest request, [FromQuery] long? id_cskcb = null)
        {
            var quyenCan = request.IdVaiTro.GetValueOrDefault() > 0 ? "Sua" : "Them";
            if (!User.CoQuyen("he_thong_vai_tro", quyenCan)) return Forbid();

            var ketQua = await _db.LayMotDongStoAsync("dbo.STO_HT_Vai_Tro_Luu", new
            {
                IDCSKCB = LayIdCskcbQuanTri(id_cskcb),
                ID_Vai_Tro = request.IdVaiTro,
                Ma_Vai_Tro = request.MaVaiTro,
                Ten_Vai_Tro = request.TenVaiTro,
                Mo_Ta = request.MoTa,
                Active = request.Active
            });
            return TraKetQua(ketQua, "Đã lưu vai trò.", "Không lưu được vai trò.");
        }


        [HttpPost("/api/he_thong/vai_tro/xoa")]
        [yeu_cau_quyen_attribute("he_thong_vai_tro", "Xoa")]
        public async Task<IActionResult> VaiTroXoa([FromBody] VaiTroXoaRequest request, [FromQuery] long? id_cskcb = null)
        {
            if (request.IdVaiTro <= 0)
                return Ok(new { status = 400, message = "Thiếu vai trò cần xóa." });

            var ketQua = await _db.LayMotDongStoAsync("dbo.STO_HT_Vai_Tro_Xoa", new
            {
                IDCSKCB = LayIdCskcbQuanTri(id_cskcb),
                ID_Vai_Tro = request.IdVaiTro
            });
            return TraKetQua(ketQua, "Đã xóa vai trò.", "Không xóa được vai trò.");
        }

        [HttpGet("/api/he_thong/phan_quyen")]
        [yeu_cau_quyen_attribute("he_thong_phan_quyen", "Xem")]
        public async Task<IActionResult> PhanQuyenLay([FromQuery] long id_vai_tro, [FromQuery] long? id_cskcb = null)
        {
            var ds = await _db.LayDanhSachStoAsync("dbo.STO_HT_Quyen_Vai_Tro_Lay", new
            {
                IDCSKCB = LayIdCskcbQuanTri(id_cskcb),
                ID_Vai_Tro = id_vai_tro
            });
            return Ok(new { status = 200, message = "Thành công", data = ds });
        }

        [HttpPost("/api/he_thong/phan_quyen/luu")]
        [yeu_cau_quyen_attribute("he_thong_phan_quyen", "Sua")]
        public async Task<IActionResult> PhanQuyenLuu([FromBody] PhanQuyenLuuRequest request, [FromQuery] long? id_cskcb = null)
        {
            var quyenJson = request.Quyen is JsonElement je ? je.GetRawText() : JsonSerializer.Serialize(request.Quyen ?? Array.Empty<object>());
            var ketQua = await _db.LayMotDongStoAsync("dbo.STO_HT_Quyen_Vai_Tro_Luu", new
            {
                IDCSKCB = LayIdCskcbQuanTri(id_cskcb),
                ID_Vai_Tro = request.IdVaiTro,
                Quyen_Json = quyenJson
            });
            return TraKetQua(ketQua, "Đã lưu phân quyền.", "Không lưu được phân quyền.");
        }

        [HttpPost("/api/he_thong/danh_muc/dong_bo")]
        [yeu_cau_quyen_attribute("danh_muc", "Sua")]
        public async Task<IActionResult> DongBoDanhMuc([FromQuery] long? id_cskcb = null)
        {
            var cskcb = LayIdCskcbQuanTri(id_cskcb);
            if (cskcb <= 0) return Ok(new { status = 400, message = "Chọn cơ sở KCB cần đồng bộ." });
            var ketQua = await _danhMucJson.DongBoTatCaJsonTuDbAsync(cskcb);
            return Ok(new { status = 200, message = "Đã đồng bộ danh mục.", data = ketQua });
        }

        private long? LayIdCskcbLoc(long? idCskcb)
        {
            if (User.IsInRole("quan_tri_he_thong"))
            {
                var id = idCskcb.GetValueOrDefault() > 0
                    ? idCskcb.GetValueOrDefault()
                    : User.LayIdCskcb();
                return id > 0 ? id : null;
            }
            return User.LayIdCskcb();
        }

        private long LayIdCskcbQuanTri(long? idCskcb)
        {
            if (User.IsInRole("quan_tri_he_thong"))
                return idCskcb.GetValueOrDefault() > 0
                    ? idCskcb.GetValueOrDefault()
                    : User.LayIdCskcb();
            return User.LayIdCskcb();
        }

        private async Task CapNhatNguCanhCskcbAsync(long? idCskcb, string? tenCskcb)
        {
            if (!User.IsInRole("quan_tri_he_thong")) return;

            var claims = User.Claims
                .Where(x => x.Type != quyen_nguoi_dung.ClaimIdCskcbLamViec
                            && x.Type != quyen_nguoi_dung.ClaimTenCskcbLamViec)
                .ToList();

            if (idCskcb.GetValueOrDefault() > 0)
            {
                claims.Add(new Claim(quyen_nguoi_dung.ClaimIdCskcbLamViec, idCskcb.Value.ToString()));
                claims.Add(new Claim(quyen_nguoi_dung.ClaimTenCskcbLamViec, tenCskcb?.Trim() ?? string.Empty));
            }

            var principal = new ClaimsPrincipal(
                new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme));

            var auth = await HttpContext.AuthenticateAsync(CookieAuthenticationDefaults.AuthenticationScheme);
            await HttpContext.SignInAsync(
                CookieAuthenticationDefaults.AuthenticationScheme,
                principal,
                auth.Properties ?? new AuthenticationProperties());

            HttpContext.User = principal;
        }

        private async Task XoaLogoNoiBoAsync(string? url)
        {
            if (string.IsNullOrWhiteSpace(url)
                || !url.StartsWith("/uploads/cskcb-logo/", StringComparison.OrdinalIgnoreCase))
                return;

            try
            {
                await _storage.DeleteLogoAsync(url, CancellationToken.None);
            }
            catch
            {
                // Dọn file là best-effort; không làm hỏng giao dịch dữ liệu chính.
            }
        }

        private static bool LaChuKyAnhHopLe(byte[] h, int n, string ext)
        {
            if (ext is ".jpg" or ".jpeg")
                return n >= 3 && h[0] == 0xFF && h[1] == 0xD8 && h[2] == 0xFF;
            if (ext == ".png")
                return n >= 8 && h[0] == 0x89 && h[1] == 0x50 && h[2] == 0x4E && h[3] == 0x47
                    && h[4] == 0x0D && h[5] == 0x0A && h[6] == 0x1A && h[7] == 0x0A;
            if (ext == ".gif")
                return n >= 6 && h[0] == 0x47 && h[1] == 0x49 && h[2] == 0x46
                    && h[3] == 0x38 && (h[4] == 0x37 || h[4] == 0x39) && h[5] == 0x61;
            if (ext == ".webp")
                return n >= 12 && h[0] == 0x52 && h[1] == 0x49 && h[2] == 0x46 && h[3] == 0x46
                    && h[8] == 0x57 && h[9] == 0x45 && h[10] == 0x42 && h[11] == 0x50;
            return false;
        }

        private List<string> XoaDuLieuVatLyCskcb(long idCskcb)
        {
            var canhBao = new List<string>();
            var thuMuc = new[]
            {
                Path.Combine(_env.ContentRootPath, "App_Data", "cls", idCskcb.ToString()),
                Path.Combine(_env.ContentRootPath, "App_Data", "cls-v2", idCskcb.ToString()),
                Path.Combine(_danhMucJson.LayDuongDanRoot(), idCskcb.ToString())
            };

            foreach (var path in thuMuc)
            {
                try
                {
                    if (Directory.Exists(path)) Directory.Delete(path, true);
                }
                catch (Exception ex)
                {
                    canhBao.Add($"{path}: {ex.Message}");
                }
            }
            return canhBao;
        }

        private IActionResult TraKetQua(dynamic? ketQua, string successMessage, string errorMessage)
        {
            if (ketQua == null) return Ok(new { status = 500, message = errorMessage });
            var d = (IDictionary<string, object?>)ketQua;
            var status = d.TryGetValue("Status", out var s) && s != null ? Convert.ToInt32(s) : 500;
            var message = status == 200 ? successMessage : errorMessage;
            var data = new Dictionary<string, object?>(d, StringComparer.OrdinalIgnoreCase)
            {
                ["Message"] = message
            };
            return Ok(new { status, message, data });
        }
    }
}
