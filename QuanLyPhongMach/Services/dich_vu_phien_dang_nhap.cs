using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using QuanLyPhongMach.Data;

namespace QuanLyPhongMach.Services
{
    public sealed class dich_vu_phien_dang_nhap
    {
        private readonly QlpmDbContext _db;

        public dich_vu_phien_dang_nhap(QlpmDbContext db)
        {
            _db = db;
        }

        public async Task<ClaimsPrincipal?> TaiLaiAsync(ClaimsPrincipal current)
        {
            if (current?.Identity?.IsAuthenticated != true) return null;

            var idTaiKhoan = current.LayIdTaiKhoan();
            if (idTaiKhoan <= 0) return null;

            var row = await _db.LayMotDongStoAsync("dbo.STO_HT_Phien_Kiem_Tra", new
            {
                ID_Tai_Khoan = idTaiKhoan
            });

            if (row == null) return null;
            var d = (IDictionary<string, object?>)row;

            if (!LayBool(d, "Tai_Khoan_Active") || !LayBool(d, "Nhan_Vien_Active") || !LayBool(d, "CSKCB_Active"))
                return null;

            var idCskcb = LayLong(d, "IDCSKCB");
            var idNhanVien = LayLong(d, "IDNhanVien");
            var tenDangNhap = LayString(d, "Ten_Dang_Nhap");
            var hoTen = LayString(d, "HoTen");
            var maNhanVien = LayString(d, "MaNhanVien");
            var laQuanTriHeThong = LayBool(d, "LaQuanTriHeThong");

            long idCskcbLamViec = 0;
            string tenCskcbLamViec = string.Empty;
            if (laQuanTriHeThong)
            {
                var idDaChon = current.LayIdCskcbLamViec();
                if (idDaChon > 0)
                {
                    var cs = await _db.DmCskcb.AsNoTracking()
                        .Where(x => x.Id == idDaChon && x.Active)
                        .Select(x => new { x.Id, x.TenCskcb })
                        .FirstOrDefaultAsync();

                    if (cs != null)
                    {
                        idCskcbLamViec = cs.Id;
                        tenCskcbLamViec = cs.TenCskcb;
                    }
                }
            }

            var claims = current.Claims
                .Where(c => c.Type != ClaimTypes.Role
                            && c.Type != quyen_nguoi_dung.ClaimQuyen
                            && c.Type != quyen_nguoi_dung.ClaimIdTaiKhoan
                            && c.Type != quyen_nguoi_dung.ClaimIdNhanVien
                            && c.Type != quyen_nguoi_dung.ClaimIdCskcb
                            && c.Type != quyen_nguoi_dung.ClaimIdCskcbLamViec
                            && c.Type != quyen_nguoi_dung.ClaimTenCskcbLamViec
                            && c.Type != quyen_nguoi_dung.ClaimHoTen
                            && c.Type != quyen_nguoi_dung.ClaimTenVaiTro
                            && c.Type != "qlpm_ten_dang_nhap"
                            && c.Type != "qlpm_ma_nhan_vien"
                            && c.Type != ClaimTypes.NameIdentifier
                            && c.Type != ClaimTypes.Name)
                .ToList();

            claims.Add(new Claim(ClaimTypes.NameIdentifier, idTaiKhoan.ToString()));
            claims.Add(new Claim(ClaimTypes.Name, string.IsNullOrWhiteSpace(hoTen) ? tenDangNhap : hoTen));
            claims.Add(new Claim(quyen_nguoi_dung.ClaimIdTaiKhoan, idTaiKhoan.ToString()));
            claims.Add(new Claim(quyen_nguoi_dung.ClaimIdNhanVien, idNhanVien.ToString()));
            claims.Add(new Claim(quyen_nguoi_dung.ClaimIdCskcb, idCskcb.ToString()));
            claims.Add(new Claim(quyen_nguoi_dung.ClaimHoTen, string.IsNullOrWhiteSpace(hoTen) ? tenDangNhap : hoTen));
            claims.Add(new Claim("qlpm_ten_dang_nhap", tenDangNhap));
            claims.Add(new Claim("qlpm_ma_nhan_vien", maNhanVien));
            if (idCskcbLamViec > 0)
            {
                claims.Add(new Claim(quyen_nguoi_dung.ClaimIdCskcbLamViec, idCskcbLamViec.ToString()));
                claims.Add(new Claim(quyen_nguoi_dung.ClaimTenCskcbLamViec, tenCskcbLamViec));
            }

            await using var multi = await _db.QueryMultipleStoAsync("dbo.STO_HT_Lay_Quyen_Tai_Khoan", new
            {
                ID_Tai_Khoan = idTaiKhoan
            });

            foreach (var item in await multi.ReadAsync())
            {
                var role = (IDictionary<string, object?>)item;
                var maVaiTro = LayString(role, "Ma_Vai_Tro");
                var tenVaiTro = LayString(role, "Ten_Vai_Tro");
                if (!string.IsNullOrWhiteSpace(maVaiTro))
                    claims.Add(new Claim(ClaimTypes.Role, maVaiTro));
                if (!string.IsNullOrWhiteSpace(tenVaiTro))
                    claims.Add(new Claim(quyen_nguoi_dung.ClaimTenVaiTro, tenVaiTro));
            }

            foreach (var item in await multi.ReadAsync())
            {
                var quyen = (IDictionary<string, object?>)item;
                var maChucNang = LayString(quyen, "Ma_Chuc_Nang");
                if (string.IsNullOrWhiteSpace(maChucNang)) continue;

                ThemQuyenNeuCo(claims, quyen, maChucNang, "Xem");
                ThemQuyenNeuCo(claims, quyen, maChucNang, "Them");
                ThemQuyenNeuCo(claims, quyen, maChucNang, "Sua");
                ThemQuyenNeuCo(claims, quyen, maChucNang, "Xoa");
                ThemQuyenNeuCo(claims, quyen, maChucNang, "Xuat");
                ThemQuyenNeuCo(claims, quyen, maChucNang, "CaNhan");
            }

            var identity = new ClaimsIdentity(claims, current.Identity?.AuthenticationType ?? "Cookies");
            return new ClaimsPrincipal(identity);
        }

        private static void ThemQuyenNeuCo(List<Claim> claims, IDictionary<string, object?> d, string maChucNang, string loaiQuyen)
        {
            if (d.TryGetValue(loaiQuyen, out var raw) && raw != null && Convert.ToBoolean(raw))
                claims.Add(new Claim(quyen_nguoi_dung.ClaimQuyen, $"{maChucNang}:{loaiQuyen}"));
        }

        private static long LayLong(IDictionary<string, object?> d, string key)
            => d.TryGetValue(key, out var value) && value != null ? Convert.ToInt64(value) : 0;

        private static string LayString(IDictionary<string, object?> d, string key)
            => d.TryGetValue(key, out var value) && value != null ? value.ToString() ?? string.Empty : string.Empty;

        private static bool LayBool(IDictionary<string, object?> d, string key)
            => d.TryGetValue(key, out var value) && value != null && Convert.ToBoolean(value);
    }
}
