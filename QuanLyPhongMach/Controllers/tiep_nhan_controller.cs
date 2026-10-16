using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuanLyPhongMach.Data;
using QuanLyPhongMach.Models.Requests.TiepNhan;
using QuanLyPhongMach.Services;

namespace QuanLyPhongMach.Controllers
{
    [yeu_cau_quyen_attribute("tiep_nhan", "Xem")]
    [Route("tiep_nhan")]
    public class tiep_nhan_controller : Controller
    {
        private readonly QlpmDbContext _db;

        public tiep_nhan_controller(QlpmDbContext db)
        {
            _db = db;
        }

        [HttpGet("")]
        public IActionResult Index()
        {
            ViewBag.ActiveTab = "tiep_nhan";
            ViewData["Title"] = "Thông tin hành chính / Tiếp nhận";
            return View("~/Views/tiep_nhan/Index.cshtml");
        }

        [HttpGet("/api/tiep_nhan/danh_sach")]
        public async Task<IActionResult> LayDanhSach(
            [FromQuery] DateTime? tu_ngay = null,
            [FromQuery] DateTime? den_ngay = null,
            [FromQuery] string? da_chuyen_kham = null,
            [FromQuery] string? tu_khoa = null,
            [FromQuery] int trang = 1,
            [FromQuery] int kich_thuoc_trang = 25)
        {
            var idCskcb = User.LayIdCskcb();
            if (idCskcb <= 0)
                return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước khi tiếp nhận." });

            bool? chuyenKhamBool = null;
            if (!string.IsNullOrEmpty(da_chuyen_kham))
            {
                if (da_chuyen_kham == "1" || da_chuyen_kham.Equals("true", StringComparison.OrdinalIgnoreCase))
                    chuyenKhamBool = true;
                else if (da_chuyen_kham == "0" || da_chuyen_kham.Equals("false", StringComparison.OrdinalIgnoreCase))
                    chuyenKhamBool = false;
            }

            var ds = await _db.LayDanhSachStoAsync("dbo.STO_QL_TiepNhan_DanhSach", new
            {
                IDCSKCB = idCskcb,
                TuNgay = tu_ngay?.Date ?? DateTime.Today,
                DenNgay = den_ngay?.Date ?? DateTime.Today,
                DaChuyenKham = chuyenKhamBool,
                TuKhoa = string.IsNullOrWhiteSpace(tu_khoa) ? null : tu_khoa.Trim(),
                Trang = Math.Max(1, trang),
                KichThuocTrang = Math.Min(100, Math.Max(10, kich_thuoc_trang))
            });

            return Ok(new { status = 200, message = "Thành công", data = ds });
        }

        // Nạp hồ sơ hiện có khi STO phát hiện CCCD trùng (mức CHAC).
        // Chỉ trả bệnh nhân đang hoạt động tại CSKCB của tài khoản đăng nhập.
        [HttpGet("/api/tiep_nhan/benh_nhan/{id:long}")]
        public async Task<IActionResult> LayBenhNhan(long id)
        {
            if (id <= 0)
                return BadRequest(new { status = 400, message = "Mã hồ sơ bệnh nhân không hợp lệ." });

            var idCskcb = User.LayIdCskcb();
            if (idCskcb <= 0)
                return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước khi tiếp nhận." });

            var benhNhan = await _db.QlBenhNhan.AsNoTracking()
                .Where(x => x.Id == id && x.Idcskcb == idCskcb && x.Active)
                .Select(x => new
                {
                    IDBenhNhan = x.Id,
                    MaBN = x.MaBn,
                    x.HoTen,
                    x.NgaySinh,
                    IDGioiTinh = x.IdgioiTinh,
                    SoCCCD = x.SoCccd,
                    x.DienThoai,
                    x.SoNhaTenDuong,
                    IDPhuongXa = x.IdphuongXa,
                    IDTinhThanh = x.IdtinhThanh,
                    x.DiaChi,
                    IDDanToc = x.IddanToc,
                    x.QuocTich,
                    x.NgheNghiep,
                    GhiChuBenhNhan = x.GhiChu,
                    GiamHo_MoiQuanHe = x.GiamHoMoiQuanHe,
                    GiamHo_HoTen = x.GiamHoHoTen,
                    GiamHo_DienThoai = x.GiamHoDienThoai,
                    GiamHo_SoCCCD = x.GiamHoSoCccd
                })
                .FirstOrDefaultAsync();

            if (benhNhan == null)
                return NotFound(new { status = 404, message = "Không tìm thấy hồ sơ bệnh nhân ở cơ sở hiện tại." });

            Response.Headers["Cache-Control"] = "no-store";
            return Ok(new { status = 200, data = benhNhan });
        }

        [HttpPost("/api/tiep_nhan/luu")]
        public async Task<IActionResult> LuuTiepNhan([FromBody] TiepNhanLuuRequest? request)
        {
            if (request == null)
                return Ok(new { status = 400, message = "Dữ liệu tiếp nhận không hợp lệ." });

            if (string.IsNullOrWhiteSpace(request.HoTen))
            {
                return Ok(new { status = 400, message = "Nhập họ tên bệnh nhân." });
            }

            string? congKhamJson = request.CongKham != null ? JsonSerializer.Serialize(request.CongKham) : "[]";

            DateTime? ngaySinhDt = null;
            if (!string.IsNullOrWhiteSpace(request.NgaySinh))
            {
                var rawNgaySinh = request.NgaySinh.Trim();
                var formats = new[] { "yyyy-MM-dd", "dd-MM-yyyy", "dd/MM/yyyy" };
                if (!DateTime.TryParseExact(rawNgaySinh, formats, CultureInfo.InvariantCulture, DateTimeStyles.None, out var parsedNs))
                    return Ok(new { status = 400, message = "Ngày sinh không đúng định dạng dd-MM-yyyy." });
                if (parsedNs.Year < 1800)
                    return Ok(new { status = 400, message = "Năm sinh phải từ 1800 trở lên." });
                ngaySinhDt = parsedNs.Date;
            }

            var idCskcb = User.LayIdCskcb();
            var idNhanVien = User.LayIdNhanVien();
            var laQuanTri = User.IsInRole("quan_tri_he_thong");
            if (idCskcb <= 0)
                return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước khi tiếp nhận." });
            if (!laQuanTri && idNhanVien <= 0)
                return Conflict(new { status = 409, message = "Tài khoản chưa có nhân viên tại cơ sở này." });

            long? idBenhNhanLuu = request.IdBenhNhan;
            long? idVaoVienLuu = request.IdVaoVien;
            int? soThuTuLuu = request.SoThuTu;
            bool taoVaoVienLuu = request.TaoVaoVien;

            // Sau khi đã chuyển khám, Tiếp nhận chỉ sửa hồ sơ hành chính/người giám hộ.
            // Để không đụng dữ liệu lượt khám, chế độ này gọi STO như thao tác cập nhật hồ sơ BN
            // (IDVaoVien=NULL, TaoVaoVien=0), sau đó trả lại IDVaoVien gốc cho UI.
            var chiSuaThongTinBenhNhan = request.ChiSuaThongTinBenhNhan;
            long? idVaoVienChiSua = null;

            if (idVaoVienLuu.GetValueOrDefault() > 0)
            {
                var luotHienTai = await _db.QlVaoVien
                    .AsNoTracking()
                    .Where(x => x.Idcskcb == idCskcb && x.Id == idVaoVienLuu!.Value && x.Active)
                    .Select(x => new { x.IdbenhNhan, x.TrangThaiKham, x.DaChuyenKham })
                    .FirstOrDefaultAsync();

                if (luotHienTai == null)
                    return Ok(new { status = 404, message = "Không tìm thấy lượt khám cần cập nhật." });

                idBenhNhanLuu ??= luotHienTai.IdbenhNhan;

                // Đang khám/đã chuyển khám: luôn khóa dữ liệu lượt, chỉ cho sửa hồ sơ BN.
                if (luotHienTai.DaChuyenKham && luotHienTai.TrangThaiKham < 2)
                    chiSuaThongTinBenhNhan = true;

                if (luotHienTai.TrangThaiKham == 2 && !chiSuaThongTinBenhNhan)
                {
                    // BN quay lại sau khi đã khám xong: tạo lượt mới, giữ nguyên lượt cũ.
                    idVaoVienLuu = null;
                    soThuTuLuu = null;
                    taoVaoVienLuu = true;
                }
                else if (chiSuaThongTinBenhNhan)
                {
                    idVaoVienChiSua = idVaoVienLuu;
                    idVaoVienLuu = null;
                    soThuTuLuu = null;
                    taoVaoVienLuu = false;
                    congKhamJson = null;
                }
            }

            // Trong cùng ngày, một bệnh nhân chỉ được có một lượt chưa hoàn tất (0/1).
            // Nếu đã có lượt đang mở thì không tạo lượt mới; trả IDVaoVien hiện tại để UI nạp lại.
            if (idBenhNhanLuu.GetValueOrDefault() > 0
                && idVaoVienLuu.GetValueOrDefault() <= 0
                && taoVaoVienLuu)
            {
                var ngayHomNay = DateTime.Today;
                var luotChuaXong = await _db.QlVaoVien
                    .AsNoTracking()
                    .Where(x => x.Idcskcb == idCskcb
                        && x.IdbenhNhan == idBenhNhanLuu!.Value
                        && x.Active
                        && x.Ngay == ngayHomNay
                        && x.TrangThaiKham < 2)
                    .OrderBy(x => x.NgayGioVaoVien)
                    .ThenBy(x => x.Id)
                    .Select(x => new { x.Id, x.SoThuTu, x.DaChuyenKham, x.TrangThaiKham })
                    .FirstOrDefaultAsync();

                if (luotChuaXong != null)
                {
                    return Ok(new
                    {
                        status = 409,
                        message = $"BN còn lượt khám chưa xong (STT {luotChuaXong.SoThuTu?.ToString() ?? "-"}). Hãy tiếp tục lượt đó.",
                        data = new
                        {
                            id_benh_nhan = idBenhNhanLuu,
                            id_vao_vien = luotChuaXong.Id,
                            da_chuyen_kham = luotChuaXong.DaChuyenKham,
                            trang_thai_kham = luotChuaXong.TrangThaiKham,
                            canh_bao_trung = false,
                            muc_do_trung = (string?)null
                        }
                    });
                }
            }

            var ketQua = await _db.LayMotDongStoAsync("dbo.STO_QL_TiepNhan_Luu", new
            {
                IDCSKCB = idCskcb,
                IDNguoiTiepNhan = idNhanVien > 0 ? (long?)idNhanVien : null,
                IDBenhNhan = idBenhNhanLuu,
                IDVaoVien = idVaoVienLuu,
                SoThuTu = soThuTuLuu,
                HoTen = request.HoTen.Trim(),
                NgaySinh = ngaySinhDt,
                GioiTinh = request.IdGioiTinh,
                SoCCCD = request.SoCccd?.Trim(),
                DienThoai = request.DienThoai?.Trim(),
                SoNhaTenDuong = request.SoNhaTenDuong?.Trim(),
                IDPhuongXa = request.IdPhuongXa,
                IDTinhThanh = request.IdTinhThanh,
                DiaChi = request.DiaChi?.Trim(),
                IDDanToc = request.IdDanToc,
                QuocTich = request.QuocTich?.Trim(),
                NgheNghiep = request.NgheNghiep?.Trim(),
                GhiChuBenhNhan = request.GhiChuBenhNhan?.Trim(),
                GhiChuLanKham = request.GhiChuLanKham?.Trim(),
                CongKhamJson = congKhamJson,
                TaoVaoVien = taoVaoVienLuu,
                ChuyenKham = request.ChuyenKham,
                BoQuaCanhBaoTrung = request.BoQuaCanhBaoTrung,
                GiamHo_MoiQuanHe = request.GiamHoMoiQuanHe?.Trim(),
                GiamHo_HoTen = request.GiamHoHoTen?.Trim(),
                GiamHo_DienThoai = request.GiamHoDienThoai?.Trim(),
                GiamHo_SoCCCD = request.GiamHoSoCccd?.Trim()
            });

            int status = 500;
            string message = "Không lưu được tiếp nhận.";
            object? idBenhNhan = null;
            object? idVaoVien = null;
            bool canhBaoTrung = false;
            string? mucDoTrung = null;

            if (ketQua != null)
            {
                var dict = (IDictionary<string, object?>)ketQua;
                if (dict.TryGetValue("Status", out var s) && s != null) status = Convert.ToInt32(s);
                var thongBaoSql = dict.TryGetValue("Message", out var msg) ? msg?.ToString() : null;
                dict.TryGetValue("IDBenhNhan", out idBenhNhan);
                dict.TryGetValue("IDVaoVien", out idVaoVien);
                if (dict.TryGetValue("CanhBaoTrung", out var cb) && cb != null) canhBaoTrung = Convert.ToBoolean(cb);
                if (dict.TryGetValue("MucDoTrung", out var md) && md != null) mucDoTrung = md.ToString();
                if (status == 200 && chiSuaThongTinBenhNhan && idVaoVienChiSua.GetValueOrDefault() > 0)
                {
                    idVaoVien = idVaoVienChiSua;
                    message = "Đã cập nhật thông tin hành chính bệnh nhân. Lượt khám và công khám được giữ nguyên.";
                }
                else
                {
                    message = status == 200
                        ? (string.IsNullOrWhiteSpace(thongBaoSql) ? "Đã lưu tiếp nhận." : thongBaoSql)
                        : status == 409 && mucDoTrung is not null
                            ? (string.IsNullOrWhiteSpace(thongBaoSql) ? "Đã có hồ sơ bệnh nhân trùng. Kiểm tra hồ sơ trước khi tiếp nhận." : thongBaoSql)
                            : canhBaoTrung ? "Có hồ sơ gần giống. Kiểm tra trước khi tiếp tục."
                            : "Không lưu được tiếp nhận.";
                }
            }

            return Ok(new
            {
                status,
                message,
                data = new
                {
                    id_benh_nhan = idBenhNhan,
                    id_vao_vien = idVaoVien,
                    canh_bao_trung = canhBaoTrung,
                    muc_do_trung = mucDoTrung
                }
            });
        }

        [HttpPost("/api/tiep_nhan/chuyen_kham")]
        public async Task<IActionResult> ChuyenKham([FromBody] IdVaoVienRequest? request)
        {
            if (request == null || request.IdVaoVien <= 0)
                return Ok(new { status = 400, message = "Thiếu lượt khám." });

            var idCskcb = User.LayIdCskcb();
            var luotCanChuyen = await _db.QlVaoVien
                .AsNoTracking()
                .Where(x => x.Idcskcb == idCskcb && x.Id == request.IdVaoVien && x.Active)
                .Select(x => new
                {
                    x.Id,
                    x.IdbenhNhan,
                    x.Ngay,
                    x.NgayGioVaoVien,
                    x.TrangThaiKham
                })
                .FirstOrDefaultAsync();

            if (luotCanChuyen != null)
            {
                if (luotCanChuyen.TrangThaiKham >= 2)
                    return Ok(new { status = 409, message = "Lượt khám đã xong hoặc đã hủy, không thể chuyển lại.", data = new { id_vao_vien = luotCanChuyen.Id } });

                // Bảo vệ dữ liệu cũ: nếu trước đây đã lỡ tạo 2 lượt chưa xong trong cùng ngày,
                // chỉ lượt đầu tiên được tiếp tục; lượt tạo sau không được chuyển khám.
                var luotTruocChuaXong = await _db.QlVaoVien
                    .AsNoTracking()
                    .Where(x => x.Idcskcb == idCskcb
                        && x.IdbenhNhan == luotCanChuyen.IdbenhNhan
                        && x.Ngay == luotCanChuyen.Ngay
                        && x.Active
                        && x.TrangThaiKham < 2
                        && x.Id != luotCanChuyen.Id
                        && (x.NgayGioVaoVien < luotCanChuyen.NgayGioVaoVien
                            || (x.NgayGioVaoVien == luotCanChuyen.NgayGioVaoVien && x.Id < luotCanChuyen.Id)))
                    .OrderBy(x => x.NgayGioVaoVien)
                    .ThenBy(x => x.Id)
                    .Select(x => x.Id)
                    .FirstOrDefaultAsync();

                if (luotTruocChuaXong > 0)
                {
                    return Ok(new
                    {
                        status = 409,
                        message = "BN còn lượt khám chưa xong. Hãy tiếp tục lượt đó.",
                        data = new { id_vao_vien = luotTruocChuaXong }
                    });
                }
            }

            var ketQua = await _db.LayMotDongStoAsync("dbo.STO_QL_TiepNhan_ChuyenKham", new
            {
                IDCSKCB = idCskcb,
                IDVaoVien = request.IdVaoVien
            });

            int status = 500;
            string message = "Không chuyển được lượt khám.";
            object? idVaoVienKetQua = request.IdVaoVien;
            if (ketQua != null)
            {
                var dict = (IDictionary<string, object?>)ketQua;
                if (dict.TryGetValue("Status", out var s) && s != null) status = Convert.ToInt32(s);
                message = status == 200 ? "Đã chuyển khám." : "Không chuyển được lượt khám.";
                if (dict.TryGetValue("IDVaoVien", out var idvv) && idvv != null) idVaoVienKetQua = idvv;
            }

            return Ok(new { status, message, data = new { id_vao_vien = idVaoVienKetQua, co_quyen_kham_benh = User.CoQuyen("kham_benh", "Xem") } });
        }

        [HttpGet("/api/tiep_nhan/danh_sach_cong_kham")]
        public async Task<IActionResult> LayDanhSachCongKham([FromQuery] long id_vao_vien)
        {
            var ds = await _db.LayDanhSachStoAsync("dbo.STO_QL_TiepNhan_LayCongKham", new
            {
                IDCSKCB = User.LayIdCskcb(),
                IDVaoVien = id_vao_vien
            });
            return Ok(new { status = 200, message = "Thành công", data = ds });
        }

        [HttpPost("/api/tiep_nhan/bo_cong_kham")]
        public async Task<IActionResult> BoCongKham([FromBody] BoCongKhamRequest? request)
        {
            if (request == null || request.IdVaoVien <= 0)
                return Ok(new { status = 400, message = "Dữ liệu bỏ công khám không hợp lệ." });

            string jsonIds = JsonSerializer.Serialize(request.IdCongKhamCtList ?? new List<long>());
            var ketQua = await _db.LayMotDongStoAsync("dbo.STO_QL_TiepNhan_BoCongKham", new
            {
                IDCSKCB = User.LayIdCskcb(),
                IDVaoVien = request.IdVaoVien,
                IDCongKhamCTJson = jsonIds
            });

            int status = 500;
            string message = "Không bỏ được công khám.";
            bool huyLuot = false;
            int conLai = 0;
            if (ketQua != null)
            {
                var dict = (IDictionary<string, object?>)ketQua;
                if (dict.TryGetValue("Status", out var s) && s != null) status = Convert.ToInt32(s);
                if (dict.TryGetValue("HuyLuotKham", out var h) && h != null) huyLuot = Convert.ToBoolean(h);
                if (dict.TryGetValue("SoLuongConLai", out var c) && c != null) conLai = Convert.ToInt32(c);
                message = status == 200
                    ? huyLuot ? "Đã bỏ công khám. Lượt khám về Chưa chuyển." : $"Đã bỏ công khám. Còn {conLai} công khám."
                    : "Không bỏ được công khám.";
            }

            return Ok(new { status, message, data = new { huy_luot_kham = huyLuot, so_luong_con_lai = conLai } });
        }

        [HttpPost("/api/tiep_nhan/bo_dang_ky")]
        public async Task<IActionResult> BoDangKy([FromBody] IdVaoVienRequest? request)
        {
            if (request == null || request.IdVaoVien <= 0)
                return Ok(new { status = 400, message = "Thiếu lượt khám." });

            var ketQua = await _db.LayMotDongStoAsync("dbo.STO_QL_TiepNhan_BoDangKy", new
            {
                IDCSKCB = User.LayIdCskcb(),
                IDVaoVien = request.IdVaoVien
            });

            int status = 500;
            string message = "Không bỏ được đăng ký.";
            if (ketQua != null)
            {
                var dict = (IDictionary<string, object?>)ketQua;
                if (dict.TryGetValue("Status", out var s) && s != null) status = Convert.ToInt32(s);
                message = status == 200 ? "Đã bỏ đăng ký." : "Không bỏ được đăng ký.";
            }

            return Ok(new { status, message });
        }

        [HttpPost("/api/tiep_nhan/xoa_benh_nhan")]
        public async Task<IActionResult> XoaBenhNhan([FromBody] XoaBenhNhanRequest? request)
        {
            if (request == null || request.IdBenhNhan <= 0)
                return Ok(new { status = 400, message = "Thiếu bệnh nhân." });

            var ketQua = await _db.LayMotDongStoAsync("dbo.STO_QL_BenhNhan_Xoa", new
            {
                IDCSKCB = User.LayIdCskcb(),
                IDBenhNhan = request.IdBenhNhan
            });

            int status = 500;
            string message = "Không xóa được bệnh nhân.";
            if (ketQua != null)
            {
                var dict = (IDictionary<string, object?>)ketQua;
                if (dict.TryGetValue("Status", out var s) && s != null) status = Convert.ToInt32(s);
                message = status == 200 ? "Đã xóa bệnh nhân." : "Không xóa được bệnh nhân.";
            }

            return Ok(new { status, message });
        }
    }
}
