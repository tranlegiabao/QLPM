using System;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace QuanLyPhongMach.Services
{
    public static class quyen_nguoi_dung
    {
        public const string ClaimIdTaiKhoan = "qlpm_id_tai_khoan";
        public const string ClaimIdNhanVien = "qlpm_id_nhan_vien";
        public const string ClaimIdCskcb = "qlpm_id_cskcb";
        public const string ClaimIdCskcbLamViec = "qlpm_id_cskcb_lam_viec";
        public const string ClaimTenCskcbLamViec = "qlpm_ten_cskcb_lam_viec";
        public const string ClaimHoTen = "qlpm_ho_ten";
        public const string ClaimTenDangNhap = "qlpm_ten_dang_nhap";
        public const string ClaimTenVaiTro = "qlpm_ten_vai_tro";
        public const string ClaimQuyen = "qlpm_quyen";

        public static long LayIdTaiKhoan(this ClaimsPrincipal user) => LayLongClaim(user, ClaimIdTaiKhoan);
        public static long LayIdNhanVien(this ClaimsPrincipal user) => LayLongClaim(user, ClaimIdNhanVien);
        public static long LayIdCskcbLamViec(this ClaimsPrincipal user) => LayLongClaim(user, ClaimIdCskcbLamViec);
        public static string LayTenCskcbLamViec(this ClaimsPrincipal user) => user.FindFirstValue(ClaimTenCskcbLamViec) ?? string.Empty;
        public static long LayIdCskcb(this ClaimsPrincipal user)
        {
            if (user?.Identity?.IsAuthenticated != true) return 0;

            if (user.IsInRole("quan_tri_he_thong"))
            {
                var idLamViec = user.LayIdCskcbLamViec();
                if (idLamViec > 0) return idLamViec;
            }

            return LayLongClaim(user, ClaimIdCskcb);
        }
        public static string LayHoTen(this ClaimsPrincipal user) => user.FindFirstValue(ClaimHoTen) ?? user.Identity?.Name ?? string.Empty;
        public static string LayTenDangNhap(this ClaimsPrincipal user) => user.FindFirstValue(ClaimTenDangNhap) ?? string.Empty;
        public static string LayTenVaiTro(this ClaimsPrincipal user)
        {
            if (user?.Identity?.IsAuthenticated != true) return string.Empty;

            var names = user.FindAll(ClaimTenVaiTro)
                .Select(x => x.Value?.Trim())
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToArray();

            if (names.Length > 0) return string.Join(" / ", names!);
            if (user.IsInRole("quan_tri_he_thong")) return "Quản trị hệ thống";

            return user.FindAll(ClaimTypes.Role)
                .Select(x => x.Value?.Trim())
                .FirstOrDefault(x => !string.IsNullOrWhiteSpace(x))
                ?? string.Empty;
        }

        public static bool CoQuyen(this ClaimsPrincipal user, string ma_chuc_nang, string loai_quyen = "Xem")
        {
            if (user?.Identity?.IsAuthenticated != true) return false;

            // Global admin không thuộc tenant cố định.
            // Chưa chọn CSKCB: chỉ có quyền quản trị hệ thống/danh mục.
            // Đã chọn CSKCB làm việc: có toàn quyền nghiệp vụ trong đúng CSKCB đó.
            if (user.IsInRole("quan_tri_he_thong"))
            {
                if (ma_chuc_nang.StartsWith("he_thong_", StringComparison.OrdinalIgnoreCase)
                    || string.Equals(ma_chuc_nang, "danh_muc", StringComparison.OrdinalIgnoreCase))
                    return true;

                return user.LayIdCskcbLamViec() > 0;
            }

            var expected = $"{ma_chuc_nang}:{ChuanHoaQuyen(loai_quyen)}";
            return user.Claims.Any(c => c.Type == ClaimQuyen && string.Equals(c.Value, expected, StringComparison.OrdinalIgnoreCase));
        }

        private static long LayLongClaim(ClaimsPrincipal user, string claimType)
        {
            var raw = user.FindFirstValue(claimType);
            return long.TryParse(raw, out var value) ? value : 0;
        }

        public static string ChuanHoaQuyen(string value)
        {
            if (string.IsNullOrWhiteSpace(value)) return "Xem";
            return value.Trim().ToLowerInvariant() switch
            {
                "xem" => "Xem",
                "them" => "Them",
                "sua" => "Sua",
                "xoa" => "Xoa",
                "xuat" => "Xuat",
                "ca_nhan" => "CaNhan",
                "canhan" => "CaNhan",
                _ => value.Trim()
            };
        }
    }
}
