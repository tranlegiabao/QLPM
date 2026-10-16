using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using QuanLyPhongMach.Data;
using QuanLyPhongMach.Models.Requests.XacThuc;
using QuanLyPhongMach.Services;

namespace QuanLyPhongMach.Controllers
{
    [Route("xac_thuc")]
    public class xac_thuc_controller : Controller
    {
        private readonly QlpmDbContext _db;
        private readonly danh_muc_json_dich_vu _danhMucJson;

        public xac_thuc_controller(
            QlpmDbContext db,
            danh_muc_json_dich_vu danhMucJson)
        {
            _db = db;
            _danhMucJson = danhMucJson;
        }

        [AllowAnonymous]
        [HttpGet("dang_nhap")]
        public IActionResult DangNhap([FromQuery] string? return_url = null)
        {
            if (User.Identity?.IsAuthenticated == true)
                return Redirect(LayReturnUrlAnToan(return_url));

            ViewData["Title"] = "Đăng nhập";
            ViewBag.ReturnUrl = LayReturnUrlAnToan(return_url);
            return View("~/Views/xac_thuc/dang_nhap.cshtml");
        }

        [AllowAnonymous]
        [HttpGet("cam_truy_cap")]
        public IActionResult CamTruyCap()
        {
            Response.StatusCode = 403;
            return View("~/Views/xac_thuc/cam_truy_cap.cshtml");
        }

        [AllowAnonymous]
        [HttpPost("/api/xac_thuc/dang_nhap")]
        public async Task<IActionResult> DangNhapApi([FromBody] DangNhapRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.TenDangNhap) || string.IsNullOrWhiteSpace(request.MatKhau))
                return Ok(new { status = 400, message = "Nhập tên đăng nhập và mật khẩu." });

            var tenDangNhapNhap = request.TenDangNhap.Trim();
            var row = await _db.LayMotDongStoAsync("dbo.STO_HT_Dang_Nhap_Lay_Tai_Khoan", new
            {
                Ten_Dang_Nhap = tenDangNhapNhap
            });

            if (row == null)
                return Ok(new { status = 401, message = "Tên đăng nhập hoặc mật khẩu không đúng." });

            var d = (IDictionary<string, object?>)row;
            long idTaiKhoan = LayLong(d, "ID_Tai_Khoan");
            long idCskcb = LayLong(d, "IDCSKCB");
            long idNhanVien = LayLong(d, "IDNhanVien");
            string tenDangNhap = LayString(d, "Ten_Dang_Nhap");
            if (!string.Equals(tenDangNhap, tenDangNhapNhap, StringComparison.Ordinal))
                return Ok(new { status = 401, message = "Tên đăng nhập hoặc mật khẩu không đúng." });
            string matKhauHash = LayString(d, "Mat_Khau_Hash");
            string hoTen = LayString(d, "HoTen");
            string maNhanVien = LayString(d, "MaNhanVien");

            if (!LayBool(d, "Tai_Khoan_Active") || !LayBool(d, "Nhan_Vien_Active") || !LayBool(d, "CSKCB_Active"))
                return Ok(new { status = 403, message = "Tài khoản chưa được phép đăng nhập." });

            // QLPM local dùng mật khẩu dạng text đơn giản; toàn bộ tài khoản mặc định là "a".
            // Không hash và không khóa tài khoản khi nhập sai.
            if (!string.Equals(matKhauHash, request.MatKhau, StringComparison.Ordinal))
                return Ok(new { status = 401, message = "Tên đăng nhập hoặc mật khẩu không đúng." });

            await _db.ThucThiStoAsync("dbo.STO_HT_Dang_Nhap_Ghi_Ket_Qua", new { ID_Tai_Khoan = idTaiKhoan, Thanh_Cong = true });

            var claims = new List<Claim>
            {
                new(ClaimTypes.NameIdentifier, idTaiKhoan.ToString()),
                new(ClaimTypes.Name, string.IsNullOrWhiteSpace(hoTen) ? tenDangNhap : hoTen),
                new(quyen_nguoi_dung.ClaimIdTaiKhoan, idTaiKhoan.ToString()),
                new(quyen_nguoi_dung.ClaimIdNhanVien, idNhanVien.ToString()),
                new(quyen_nguoi_dung.ClaimIdCskcb, idCskcb.ToString()),
                new(quyen_nguoi_dung.ClaimHoTen, string.IsNullOrWhiteSpace(hoTen) ? tenDangNhap : hoTen),
                new("qlpm_ten_dang_nhap", tenDangNhap),
                new("qlpm_ma_nhan_vien", maNhanVien)
            };

            await using (var multi = await _db.QueryMultipleStoAsync("dbo.STO_HT_Lay_Quyen_Tai_Khoan", new { ID_Tai_Khoan = idTaiKhoan }))
            {
                foreach (var item in await multi.ReadAsync())
                {
                    var dict = (IDictionary<string, object?>)item;
                    var maVaiTro = LayString(dict, "Ma_Vai_Tro");
                    var tenVaiTro = LayString(dict, "Ten_Vai_Tro");
                    if (!string.IsNullOrWhiteSpace(maVaiTro)) claims.Add(new Claim(ClaimTypes.Role, maVaiTro));
                    if (!string.IsNullOrWhiteSpace(tenVaiTro)) claims.Add(new Claim(quyen_nguoi_dung.ClaimTenVaiTro, tenVaiTro));
                }

                foreach (var item in await multi.ReadAsync())
                {
                    var dict = (IDictionary<string, object?>)item;
                    var maChucNang = LayString(dict, "Ma_Chuc_Nang");
                    if (string.IsNullOrWhiteSpace(maChucNang)) continue;
                    ThemQuyenNeuCo(claims, dict, maChucNang, "Xem");
                    ThemQuyenNeuCo(claims, dict, maChucNang, "Them");
                    ThemQuyenNeuCo(claims, dict, maChucNang, "Sua");
                    ThemQuyenNeuCo(claims, dict, maChucNang, "Xoa");
                    ThemQuyenNeuCo(claims, dict, maChucNang, "Xuat");
                    ThemQuyenNeuCo(claims, dict, maChucNang, "CaNhan");
                }
            }

            var principal = new ClaimsPrincipal(new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme));
            await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, principal, new AuthenticationProperties
            {
                IsPersistent = request.GhiNho,
                ExpiresUtc = request.GhiNho ? DateTimeOffset.Now.AddDays(7) : null,
                AllowRefresh = true
            });

            string? canhBao = null;
            if (idCskcb > 0)
            {
                try
                {
                    bool daXepLichDongBo = await _danhMucJson.DangKyJsonCanKhoiTaoAsync(idCskcb);
                    if (daXepLichDongBo)
                        canhBao = "Danh mục đang được đồng bộ nền.";
                }
                catch
                {
                    canhBao = "Đăng nhập được, nhưng danh mục chưa được cập nhật.";
                }
            }

            return Ok(new
            {
                status = 200,
                message = "Đăng nhập thành công.",
                canh_bao = canhBao,
                data = new
                {
                    id_tai_khoan = idTaiKhoan,
                    id_nhan_vien = idNhanVien,
                    id_cskcb = idCskcb,
                    ho_ten = hoTen,
                    bat_buoc_doi_mat_khau = false,
                    return_url = LayReturnUrlAnToan(request.ReturnUrl)
                }
            });
        }

        [HttpPost("/api/xac_thuc/dang_xuat")]
        public async Task<IActionResult> DangXuat()
        {
            await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
            return Ok(new { status = 200, message = "Đã đăng xuất." });
        }

        [HttpGet("/api/xac_thuc/phien_hien_tai")]
        public IActionResult PhienHienTai()
        {
            if (User.Identity?.IsAuthenticated != true)
                return Unauthorized(new { status = 401, message = "Chưa đăng nhập." });

            return Ok(new
            {
                status = 200,
                data = new
                {
                    id_tai_khoan = User.LayIdTaiKhoan(),
                    id_nhan_vien = User.LayIdNhanVien(),
                    id_cskcb = User.LayIdCskcb(),
                    ho_ten = User.LayHoTen(),
                    vai_tro = User.FindAll(ClaimTypes.Role).Select(x => x.Value).ToArray()
                }
            });
        }

        [AllowAnonymous]
        [HttpGet("/api/xac_thuc/khoi_tao_thong_tin")]
        public async Task<IActionResult> KhoiTaoThongTin(
            [FromQuery] long? id_cskcb = null,
            [FromQuery] string? q = null,
            [FromQuery] int top = 100)
        {
            await using var multi = await _db.QueryMultipleStoAsync("dbo.STO_HT_Khoi_Tao_Thong_Tin", new
            {
                IDCSKCB = id_cskcb,
                TuKhoa = string.IsNullOrWhiteSpace(q) ? null : q.Trim(),
                Top = Math.Min(100, Math.Max(1, top))
            });
            var cskcb = await multi.ReadAsync();
            var nhanVien = await multi.ReadAsync();
            return Ok(new { status = 200, message = "Thành công", data = new { cskcb, nhan_vien = nhanVien } });
        }

        private static void ThemQuyenNeuCo(List<Claim> claims, IDictionary<string, object?> dict, string maChucNang, string loaiQuyen)
        {
            if (dict.TryGetValue(loaiQuyen, out var raw) && raw != null && Convert.ToBoolean(raw))
                claims.Add(new Claim(quyen_nguoi_dung.ClaimQuyen, $"{maChucNang}:{loaiQuyen}"));
        }

        private static string LayReturnUrlAnToan(string? returnUrl)
        {
            if (!string.IsNullOrWhiteSpace(returnUrl) && returnUrl.StartsWith('/') && !returnUrl.StartsWith("//")) return returnUrl;
            return "/";
        }

        private static long LayLong(IDictionary<string, object?> d, string key)
            => d.TryGetValue(key, out var value) && value != null ? Convert.ToInt64(value) : 0;
        private static string LayString(IDictionary<string, object?> d, string key)
            => d.TryGetValue(key, out var value) && value != null ? value.ToString() ?? string.Empty : string.Empty;
        private static bool LayBool(IDictionary<string, object?> d, string key)
            => d.TryGetValue(key, out var value) && value != null && Convert.ToBoolean(value);
    }
}
