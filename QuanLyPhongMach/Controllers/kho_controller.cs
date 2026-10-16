using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using QuanLyPhongMach.Data;
using QuanLyPhongMach.Models.Requests.Kho;
using QuanLyPhongMach.Services;

namespace QuanLyPhongMach.Controllers
{
    [Route("kho")]
    public class kho_controller : Controller
    {
        private readonly QlpmDbContext _db;
        private readonly danh_muc_json_dich_vu _danhMucJson;

        public kho_controller(QlpmDbContext db, danh_muc_json_dich_vu danhMucJson)
        {
            _db = db;
            _danhMucJson = danhMucJson;
        }

        // Cấp phát thuộc luồng Khám bệnh; QL kho là màn độc lập, không hiện thanh phân hệ lâm sàng.
        [HttpGet("")]
        public IActionResult Index([FromQuery] string? tab = null)
        {
            if (tab is "ton-kho" or "nhap-kho" or "dieu-chinh" or "phan-nhom")
                return Redirect("/kho/quan-ly?tab=" + tab); // Giữ tương thích các URL cũ.
            return HienThiKho(laQuanLyKho: false);
        }

        [HttpGet("quan-ly")]
        public IActionResult QuanLy()
            => HienThiKho(laQuanLyKho: true);

        private IActionResult HienThiKho(bool laQuanLyKho)
        {
            ViewBag.ActiveTab = "kho";
            ViewBag.HienThiThanhPhanHe = !laQuanLyKho;
            ViewBag.KhoChiQuanLy = laQuanLyKho;
            ViewBag.CoQuyenNhap = User.CoQuyen("kho", "Them");
            var chucNang = laQuanLyKho ? "kho" : "kho_cap_phat";
            ViewBag.CoQuyenCap = !laQuanLyKho && User.CoQuyen(chucNang, "Sua");
            ViewBag.CoQuyenHoan = User.CoQuyen(chucNang, "Xoa");
            ViewBag.CoQuyenXuat = User.CoQuyen(chucNang, "Xuat");
            ViewData["Title"] = laQuanLyKho ? "Quản lý kho" : "Cấp phát thuốc";
            return View("~/Views/kho/Index.cshtml");
        }

        [HttpGet("api/danh-sach-kho")]
        public async Task<IActionResult> DanhSachKho()
        {
            var idCskcb = User.LayIdCskcb();
            if (idCskcb <= 0)
                return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước." });

            var rows = await _db.LayDanhSachStoAsync("dbo.STO_QL_Kho_DanhSachKho", new
            {
                IDCSKCB = idCskcb
            });
            return Ok(new { status = 200, data = rows });
        }

        [HttpGet("api/ton-kho")]
        public async Task<IActionResult> TonKho(
            [FromQuery] long? id_kho = null,
            [FromQuery] string? q = null,
            [FromQuery] int trang = 1,
            [FromQuery] int kich_thuoc_trang = 25,
            [FromQuery] string? trang_thai = null)
        {
            var idCskcb = User.LayIdCskcb();
            if (idCskcb <= 0)
                return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước." });

            var page = Math.Max(1, trang);
            var pageSize = Math.Clamp(kich_thuoc_trang, 10, 100);
            var status = string.IsNullOrWhiteSpace(trang_thai) ? "tat_ca" : trang_thai.Trim().ToLowerInvariant();
            if (status is not ("tat_ca" or "con_thuoc" or "het_thuoc" or "sap_het_han" or "het_han_khoa"))
                return BadRequest(new { status = 400, message = "Trạng thái lọc tồn kho không hợp lệ." });

            await using var multi = await _db.QueryMultipleStoAsync("dbo.STO_QL_Kho_TonKho_DanhSach", new
            {
                IDCSKCB = idCskcb,
                IDKho = id_kho,
                TuKhoa = string.IsNullOrWhiteSpace(q) ? null : q.Trim(),
                Trang = page,
                KichThuocTrang = pageSize,
                TrangThai = status
            });

            var totalRow = await multi.ReadFirstOrDefaultAsync();
            var rows = await multi.ReadAsync();
            var total = totalRow == null ? 0L : Convert.ToInt64(totalRow.tong_so);

            return Ok(new
            {
                status = 200,
                data = new
                {
                    danh_sach = rows,
                    tong_so = total,
                    trang = page,
                    kich_thuoc_trang = pageSize,
                    so_trang = Math.Max(1, (int)Math.Ceiling(total / (double)pageSize))
                }
            });
        }

        [yeu_cau_quyen_attribute("kho", "Them")]
        [HttpPost("api/nhap-kho")]
        public async Task<IActionResult> NhapKho([FromBody] NhapKhoRequest? request)
        {
            var idCskcb = User.LayIdCskcb();
            var idNhanVien = User.LayIdNhanVien();
            var idTaiKhoan = User.LayIdTaiKhoan();
            var laAdmin = User.IsInRole("quan_tri_he_thong");
            if (idCskcb <= 0)
                return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước." });
            if (laAdmin && User.LayIdCskcbLamViec() <= 0)
                return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước." });
            if (idTaiKhoan <= 0)
                return Conflict(new { status = 409, message = "Không xác định được tài khoản thực hiện." });
            if (!laAdmin && idNhanVien <= 0)
                return Conflict(new { status = 409, message = "Tài khoản kho chưa gắn với nhân viên tại cơ sở này." });
            if (request == null || request.id_kho <= 0 || request.danh_sach == null || request.danh_sach.Count == 0)
                return BadRequest(new { status = 400, message = "Kiểm tra lại phiếu nhập kho." });

            var row = await _db.LayMotDongStoAsync("dbo.STO_QL_Kho_Nhap", new
            {
                IDCSKCB = idCskcb,
                IDKho = request.id_kho,
                IDNhanVienNhap = laAdmin ? (long?)null : idNhanVien,
                IDTaiKhoanNhap = idTaiKhoan,
                IDNhaCungCap = request.id_nha_cung_cap,
                SoHoaDon = string.IsNullOrWhiteSpace(request.so_hoa_don) ? null : request.so_hoa_don.Trim(),
                NgayHoaDon = request.ngay_hoa_don?.Date,
                GhiChu = string.IsNullOrWhiteSpace(request.ghi_chu) ? null : request.ghi_chu.Trim(),
                DanhSachJson = JsonSerializer.Serialize(request.danh_sach)
            });
            return TraKetQua(row, "Nhập kho thành công.");
        }

        [HttpGet("api/nha-cung-cap")]
        public async Task<IActionResult> NhaCungCapDanhSach()
        {
            var idCskcb = User.LayIdCskcb();
            if (idCskcb <= 0) return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước." });
            var rows = await _db.LayDanhSachStoAsync("dbo.STO_DM_NhaCungCap_DanhSach", new { IDCSKCB = idCskcb });
            return Ok(new { status = 200, data = rows });
        }

        [HttpGet("api/nha-cung-cap/danh-sach")]
        public async Task<IActionResult> NhaCungCapQuanLyDanhSach(
            [FromQuery] string? q = null,
            [FromQuery] string? trang_thai = null)
        {
            var idCskcb = User.LayIdCskcb();
            if (idCskcb <= 0) return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước." });

            byte? active = trang_thai?.Trim().ToLowerInvariant() switch
            {
                "hoat_dong" => 1,
                "ngung" => 0,
                _ => null
            };
            var rows = await _db.LayDanhSachStoAsync("dbo.STO_DM_NhaCungCap_QuanLy_DanhSach", new
            {
                IDCSKCB = idCskcb,
                TuKhoa = string.IsNullOrWhiteSpace(q) ? null : q.Trim(),
                TrangThai = active
            });
            return Ok(new { status = 200, data = rows });
        }

        [HttpPost("api/nha-cung-cap/luu")]
        public async Task<IActionResult> NhaCungCapLuu([FromBody] NhaCungCapLuuRequest? request)
        {
            var idCskcb = User.LayIdCskcb();
            if (idCskcb <= 0) return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước." });
            if (request == null || request.id < 0 || string.IsNullOrWhiteSpace(request.ten))
                return BadRequest(new { status = 400, message = "Phải nhập tên nhà cung cấp." });

            // Thêm và sửa là hai quyền độc lập, không dùng quyền Xem để ghi.
            if (!User.CoQuyen("kho", request.id > 0 ? "Sua" : "Them"))
                return Forbid();
            if (request.ten.Trim().Length > 300
                || (request.ma?.Trim().Length ?? 0) > 50
                || (request.ma_so_thue?.Trim().Length ?? 0) > 50
                || (request.dia_chi?.Trim().Length ?? 0) > 500)
                return BadRequest(new { status = 400, message = "Thông tin nhà cung cấp vượt quá độ dài cho phép." });
            var phone = request.dien_thoai?.Trim();
            if (!string.IsNullOrEmpty(phone) && (phone.Length > 10 || phone.Any(c => c < '0' || c > '9')))
                return BadRequest(new { status = 400, message = "Số điện thoại chỉ được nhập tối đa 10 chữ số." });

            var row = await _db.LayMotDongStoAsync("dbo.STO_DM_NhaCungCap_Luu", new
            {
                IDCSKCB = idCskcb,
                ID = request.id,
                Ma = string.IsNullOrWhiteSpace(request.ma) ? null : request.ma.Trim(),
                Ten = request.ten.Trim(),
                MaSoThue = string.IsNullOrWhiteSpace(request.ma_so_thue) ? null : request.ma_so_thue.Trim(),
                DienThoai = phone,
                DiaChi = string.IsNullOrWhiteSpace(request.dia_chi) ? null : request.dia_chi.Trim(),
                Active = request.active,
                CanDeactivate = User.CoQuyen("kho", "Xoa")
            });
            return TraKetQua(row, "Đã lưu nhà cung cấp.");
        }

        [yeu_cau_quyen_attribute("kho", "Xoa")]
        [HttpPost("api/nha-cung-cap/xoa")]
        public async Task<IActionResult> NhaCungCapXoa([FromBody] NhaCungCapXoaRequest? request)
        {
            var idCskcb = User.LayIdCskcb();
            if (idCskcb <= 0) return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước." });
            if (request == null || request.id <= 0)
                return BadRequest(new { status = 400, message = "Chưa chọn nhà cung cấp cần ngừng sử dụng." });

            // Xóa mềm để giữ nguyên FK và lịch sử các phiếu nhập đã phát sinh.
            var row = await _db.LayMotDongStoAsync("dbo.STO_DM_NhaCungCap_Xoa", new
            {
                IDCSKCB = idCskcb,
                ID = request.id
            });
            return TraKetQua(row, "Đã ngừng sử dụng nhà cung cấp.");
        }

        [HttpGet("api/phieu-nhap")]
        public async Task<IActionResult> PhieuNhapDanhSach([FromQuery] DateTime? tu_ngay = null, [FromQuery] DateTime? den_ngay = null)
        {
            var idCskcb = User.LayIdCskcb();
            if (idCskcb <= 0) return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước." });
            var rows = await _db.LayDanhSachStoAsync("dbo.STO_QL_Kho_Nhap_DanhSach", new
            {
                IDCSKCB = idCskcb, TuNgay = tu_ngay?.Date, DenNgay = den_ngay?.Date
            });
            return Ok(new { status = 200, data = rows });
        }

        [HttpGet("api/phieu-nhap/chi-tiet")]
        public async Task<IActionResult> PhieuNhapChiTiet([FromQuery] long id)
        {
            var idCskcb = User.LayIdCskcb();
            if (idCskcb <= 0 || id <= 0) return BadRequest(new { status = 400, message = "Thiếu phiếu nhập." });
            await using var multi = await _db.QueryMultipleStoAsync("dbo.STO_QL_Kho_Nhap_ChiTiet", new { IDCSKCB = idCskcb, IDNhap = id });
            var info = await multi.ReadFirstOrDefaultAsync();
            if (info == null) return NotFound(new { status = 404, message = "Không tìm thấy phiếu nhập." });
            var rows = await multi.ReadAsync();
            return Ok(new { status = 200, data = new { thong_tin = info, chi_tiet = rows } });
        }

        [yeu_cau_quyen_attribute("kho", "Xoa")]
        [HttpPost("api/phieu-nhap/huy")]
        public async Task<IActionResult> PhieuNhapHuy([FromBody] HuyPhieuNhapRequest? request)
        {
            var idCskcb = User.LayIdCskcb(); var idNhanVien = User.LayIdNhanVien();
            if (idCskcb <= 0 || idNhanVien <= 0) return Conflict(new { status = 409, message = "Không xác định được cơ sở hoặc nhân viên." });
            if (request == null || request.id <= 0)
                return BadRequest(new { status = 400, message = "Thiếu phiếu nhập cần hủy." });
            var row = await _db.LayMotDongStoAsync("dbo.STO_QL_Kho_Nhap_Huy", new
            {
                IDCSKCB = idCskcb, IDNhap = request.id, IDNhanVienHuy = idNhanVien,
                LyDo = string.IsNullOrWhiteSpace(request.ly_do) ? null : request.ly_do.Trim()
            });
            return TraKetQua(row, "Đã hủy phiếu nhập.");
        }

        [HttpGet("api/lo-thuoc")]
        public async Task<IActionResult> LoThuoc([FromQuery] long id_thuoc)
        {
            var idCskcb = User.LayIdCskcb();
            if (idCskcb <= 0 || id_thuoc <= 0) return BadRequest(new { status = 400, message = "Thiếu thuốc hoặc cơ sở." });
            var rows = await _db.LayDanhSachStoAsync("dbo.STO_QL_Kho_LoThuoc_DanhSach", new
            {
                IDCSKCB = idCskcb, IDKho = (long?)null, IDThuoc = id_thuoc
            });
            return Ok(new { status = 200, data = rows });
        }

        [yeu_cau_quyen_attribute("kho", "Xoa")]
        [HttpPost("api/dieu-chinh-ton")]
        public async Task<IActionResult> DieuChinhTon([FromBody] DieuChinhKhoRequest? request)
        {
            var idCskcb = User.LayIdCskcb(); var idNhanVien = User.LayIdNhanVien();
            if (idCskcb <= 0 || idNhanVien <= 0) return Conflict(new { status = 409, message = "Không xác định được cơ sở hoặc nhân viên." });
            if (request == null || request.danh_sach == null || request.danh_sach.Count == 0)
                return BadRequest(new { status = 400, message = "Thiếu lô hoặc số lượng cần xử lý." });
            var loai = (request.loai ?? string.Empty).Trim().ToUpperInvariant();
            if (loai is not ("DIEU_CHINH" or "HUY_THUOC")) return BadRequest(new { status = 400, message = "Loại chứng từ không hợp lệ." });
            var row = await _db.LayMotDongStoAsync("dbo.STO_QL_Kho_DieuChinh_Luu", new
            {
                IDCSKCB = idCskcb, IDKho = (long?)null, Loai = loai, IDNhanVien = idNhanVien,
                LyDo = string.IsNullOrWhiteSpace(request.ly_do) ? null : request.ly_do.Trim(),
                DanhSachJson = JsonSerializer.Serialize(request.danh_sach)
            });
            return TraKetQua(row, "Đã ghi chứng từ kho.");
        }

        [HttpGet("api/dieu-chinh-ton/lich-su")]
        public async Task<IActionResult> DieuChinhTonLichSu([FromQuery] DateTime? tu_ngay = null, [FromQuery] DateTime? den_ngay = null)
        {
            var idCskcb = User.LayIdCskcb();
            if (idCskcb <= 0) return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước." });
            var rows = await _db.LayDanhSachStoAsync("dbo.STO_QL_Kho_DieuChinh_DanhSach", new
            { IDCSKCB = idCskcb, TuNgay = tu_ngay?.Date, DenNgay = den_ngay?.Date });
            return Ok(new { status = 200, data = rows });
        }

        [HttpGet("api/cho-cap")]
        public async Task<IActionResult> ChoCap(
            [FromQuery] string? q = null,
            [FromQuery] string? trang_thai = null,
            [FromQuery] DateTime? tu_ngay = null,
            [FromQuery] DateTime? den_ngay = null,
            [FromQuery] string? loai_toa = null,
            [FromQuery] int trang = 1,
            [FromQuery] int kich_thuoc_trang = 25)
        {
            var idCskcb = User.LayIdCskcb();
            if (idCskcb <= 0)
                return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước." });

            var boLocTrangThai = (trang_thai ?? "chua_cap").Trim().ToLowerInvariant();
            byte? trangThai = null;
            string? trangThaiCsv = null;

            switch (boLocTrangThai)
            {
                case "chua_cap":
                case "cho_cap":
                    // "Chưa cấp" gồm cả chưa cấp lần nào (0) và đã cấp nhưng còn thiếu (1).
                    trangThaiCsv = "0,1";
                    break;
                case "da_cap":
                    trangThai = 2;
                    break;
                case "tat_ca":
                case "all":
                case "":
                    break;
                default:
                    trangThaiCsv = "0,1";
                    break;
            }

            var page = Math.Max(1, trang);
            var pageSize = Math.Clamp(kich_thuoc_trang, 10, 100);
            var rows = (await _db.LayDanhSachStoAsync("dbo.STO_QL_Kho_Xuat_DanhSach", new
            {
                IDCSKCB = idCskcb,
                TuKhoa = string.IsNullOrWhiteSpace(q) ? null : q.Trim(),
                TrangThai = trangThai,
                TrangThaiCsv = trangThaiCsv,
                TuNgay = tu_ngay?.Date,
                DenNgay = den_ngay?.Date,
                LoaiToa = string.IsNullOrWhiteSpace(loai_toa) || string.Equals(loai_toa, "tat_ca", StringComparison.OrdinalIgnoreCase)
                    ? null
                    : loai_toa.Trim().ToLowerInvariant(),
                Trang = page,
                KichThuocTrang = pageSize
            })).ToList();

            long total = 0;
            if (rows.Count > 0 && rows[0] is IDictionary<string, object?> first
                && first.TryGetValue("tong_so", out var totalValue) && totalValue != null)
                total = Convert.ToInt64(totalValue);

            return Ok(new
            {
                status = 200,
                data = new
                {
                    danh_sach = rows,
                    tong_so = total,
                    trang = page,
                    kich_thuoc_trang = pageSize,
                    so_trang = Math.Max(1, (int)Math.Ceiling(total / (double)pageSize))
                }
            });
        }

        [HttpGet("api/chi-tiet-cap")]
        public async Task<IActionResult> ChiTietCap([FromQuery] long id_kho, [FromQuery] long id_vao_vien)
        {
            var idCskcb = User.LayIdCskcb();
            if (idCskcb <= 0)
                return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước." });
            if (id_kho <= 0 || id_vao_vien <= 0)
                return BadRequest(new { status = 400, message = "Thiếu kho hoặc lượt khám." });

            await using var multi = await _db.QueryMultipleStoAsync("dbo.STO_QL_Kho_Xuat_ChiTiet", new
            {
                IDCSKCB = idCskcb,
                IDKho = id_kho,
                IDVaoVien = id_vao_vien
            });
            var info = await multi.ReadFirstOrDefaultAsync();
            if (info == null)
                return NotFound(new { status = 404, message = "Không tìm thấy toa đã thanh toán." });
            var rows = await multi.ReadAsync();

            return Ok(new { status = 200, data = new { thong_tin = info, toa_thuoc = rows } });
        }

        [yeu_cau_quyen_attribute("kho_cap_phat", "Sua")]
        [HttpPost("api/xuat-thuoc")]
        public async Task<IActionResult> XuatThuoc([FromBody] XuatThuocRequest? request)
        {
            var idCskcb = User.LayIdCskcb();
            var idNhanVien = User.LayIdNhanVien();
            var idTaiKhoan = User.LayIdTaiKhoan();
            var laAdmin = User.IsInRole("quan_tri_he_thong");
            if (idCskcb <= 0)
                return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước." });
            if (laAdmin && User.LayIdCskcbLamViec() <= 0)
                return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước." });
            if (idTaiKhoan <= 0)
                return Conflict(new { status = 409, message = "Không xác định được tài khoản thực hiện." });
            if (!laAdmin && idNhanVien <= 0)
                return Conflict(new { status = 409, message = "Tài khoản kho chưa gắn với nhân viên tại cơ sở này." });
            if (request == null || request.id_kho <= 0 || request.id_vao_vien <= 0 || request.danh_sach == null
                || request.danh_sach.Count == 0 || request.danh_sach.Any(x => x == null || x.id_toa_thuoc_ct <= 0 || x.so_luong_cap <= 0))
                return BadRequest(new { status = 400, message = "Kiểm tra lại phiếu xuất thuốc." });

            var row = await _db.LayMotDongStoAsync("dbo.STO_QL_Kho_Xuat_TheoToa", new
            {
                IDCSKCB = idCskcb,
                IDKho = request.id_kho,
                IDVaoVien = request.id_vao_vien,
                IDNhanVienXuat = laAdmin ? (long?)null : idNhanVien,
                IDTaiKhoanXuat = idTaiKhoan,
                DanhSachJson = JsonSerializer.Serialize(request.danh_sach),
                GhiChu = string.IsNullOrWhiteSpace(request.ghi_chu) ? null : request.ghi_chu.Trim()
            });
            return TraKetQua(row, "Xuất thuốc thành công.");
        }

        [HttpGet("api/dong-da-cap")]
        public async Task<IActionResult> DongDaCap([FromQuery] long id_vao_vien)
        {
            var idCskcb = User.LayIdCskcb();
            if (idCskcb <= 0 || id_vao_vien <= 0)
                return BadRequest(new { status = 400, message = "Thiếu cơ sở hoặc lượt khám." });
            var rows = await _db.LayDanhSachStoAsync("dbo.STO_QL_Kho_DongDaCap", new
            { IDCSKCB = idCskcb, IDVaoVien = id_vao_vien });
            return Ok(new { status = 200, data = rows });
        }

        [yeu_cau_quyen_attribute("kho_cap_phat", "Xoa")]
        [HttpPost("api/hoan-thuoc")]
        public async Task<IActionResult> HoanThuoc([FromBody] HoanThuocRequest? request)
        {
            var idCskcb = User.LayIdCskcb();
            var idNhanVien = User.LayIdNhanVien();
            if (idCskcb <= 0)
                return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước." });
            if (idNhanVien <= 0)
                return Conflict(new { status = 409, message = "Tài khoản kho chưa gắn với nhân viên tại cơ sở này." });
            if (request == null || request.id_vao_vien <= 0)
                return BadRequest(new { status = 400, message = "Thiếu lượt khám cần hoàn kho." });
            if (request.danh_sach == null ||
                (request.hoan_toan_bo && request.danh_sach.Count != 0) ||
                (!request.hoan_toan_bo && (request.danh_sach.Count == 0 ||
                    request.danh_sach.Any(x => x.id_xuat_ct <= 0 || x.so_luong_hoan_co_so <= 0) ||
                    request.danh_sach.Select(x => x.id_xuat_ct).Distinct().Count() != request.danh_sach.Count)))
                return BadRequest(new { status = 400, message = "Chọn đúng dòng cấp và lượng hoàn; hoàn toàn bộ phải được chọn rõ ràng." });

            var row = await _db.LayMotDongStoAsync("dbo.STO_QL_Kho_Xuat_Hoan", new
            {
                IDCSKCB = idCskcb,
                IDVaoVien = request.id_vao_vien,
                IDNhanVienHoan = idNhanVien,
                LyDo = string.IsNullOrWhiteSpace(request.ly_do) ? null : request.ly_do.Trim(),
                HoanToanBo = request.hoan_toan_bo,
                DanhSachJson = JsonSerializer.Serialize(request.danh_sach)
            });
            return TraKetQua(row, "Hoàn kho thành công.");
        }

        /* ==================== Phân nhóm thuốc c/n/h hiện hữu ==================== */

        [HttpGet("api/danh-sach")]
        public async Task<IActionResult> DanhSach(
            [FromQuery] string? q = null,
            [FromQuery] int trang = 1,
            [FromQuery] int kich_thuoc_trang = 25,
            [FromQuery] string[]? loai_toa = null)
        {
            var idCskcb = User.LayIdCskcb();
            if (idCskcb <= 0) return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước." });

            var pageSize = Math.Clamp(kich_thuoc_trang, 10, 100);
            var page = Math.Max(1, trang);
            var loaiToaJson = loai_toa is { Length: > 0 }
                ? JsonSerializer.Serialize(loai_toa.Where(x => !string.IsNullOrWhiteSpace(x)).Select(x => x.Trim()))
                : null;

            await using var multi = await _db.QueryMultipleStoAsync("dbo.STO_QL_Kho_Thuoc_Danh_Sach", new
            {
                IDCSKCB = idCskcb,
                TuKhoa = string.IsNullOrWhiteSpace(q) ? null : q.Trim(),
                Trang = page,
                KichThuocTrang = pageSize,
                LoaiToaJson = loaiToaJson
            });
            var groups = await multi.ReadAsync();
            var totalRow = await multi.ReadFirstOrDefaultAsync();
            var medicines = await multi.ReadAsync();
            var total = totalRow == null ? 0L : Convert.ToInt64(totalRow.TongSo);

            return Ok(new { status = 200, data = new { nhom_hang = groups, thuoc = medicines, tong_so = total, trang = page, kich_thuoc_trang = pageSize, so_trang = Math.Max(1, (int)Math.Ceiling(total / (double)pageSize)) } });
        }

        [yeu_cau_quyen_attribute("kho", "Sua")]
        [HttpPost("api/gan-nhom")]
        public async Task<IActionResult> GanNhom([FromBody] GanNhomRequest? request)
        {
            var idCskcb = User.LayIdCskcb();
            if (idCskcb <= 0 || request == null || request.id_thuoc <= 0)
                return BadRequest(new { status = 400, message = "Thiếu thuốc hoặc cơ sở KCB." });

            var ketQua = await _db.LayMotDongStoAsync("dbo.STO_QL_Kho_Thuoc_GanNhom", new
            {
                IDCSKCB = idCskcb,
                IDThuoc = request.id_thuoc,
                IDNhomHang = request.id_nhom_hang
            });
            if (ketQua == null) return StatusCode(500, new { status = 500, message = "STO không trả kết quả cập nhật." });

            var maLoi = Convert.ToInt32(ketQua.MaLoi);
            var thongBao = Convert.ToString(ketQua.ThongBao) ?? "Không cập nhật được nhóm thuốc.";
            if (maLoi == 404) return NotFound(new { status = maLoi, message = thongBao });
            if (maLoi == 400) return BadRequest(new { status = maLoi, message = thongBao });
            if (maLoi != 200) return StatusCode(500, new { status = 500, message = thongBao });

            await _danhMucJson.DanhDauThayDoiDanhMucAsync(idCskcb);
            return Ok(new { status = 200, message = thongBao });
        }

        private static IActionResult TraKetQua(dynamic? row, string successMessage)
        {
            if (row == null)
                return new ObjectResult(new { status = 500, message = "Stored procedure không trả kết quả." }) { StatusCode = 500 };

            var data = (IDictionary<string, object?>)row;
            var status = data.TryGetValue("Status", out var s) && s != null ? Convert.ToInt32(s) : 500;
            var message = data.TryGetValue("Message", out var m) && m != null
                ? m.ToString() ?? successMessage
                : (status == 200 ? successMessage : "Không thực hiện được thao tác.");

            return new OkObjectResult(new { status, message, data = row });
        }
    }
}
