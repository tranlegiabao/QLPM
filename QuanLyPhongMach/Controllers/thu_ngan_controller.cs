using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using WkHtmlToPdfDotNet;
using WkHtmlToPdfDotNet.Contracts;
using QuanLyPhongMach.Data;
using QuanLyPhongMach.Models.Printing.ThuNgan;
using QuanLyPhongMach.Models.Reports.ThuNgan;
using QuanLyPhongMach.Models.Requests.ThuNgan;
using QuanLyPhongMach.Services;

namespace QuanLyPhongMach.Controllers
{
    [yeu_cau_quyen_attribute("thu_ngan", "Xem")]
    [Route("thu_ngan")]
    public class thu_ngan_controller : Controller
    {
        private readonly QlpmDbContext _db;
        private readonly IRazorViewRenderer _renderer;
        private readonly IConverter _converter;

        public thu_ngan_controller(
            QlpmDbContext db,
            IRazorViewRenderer renderer,
            IConverter converter)
        {
            _db = db;
            _renderer = renderer;
            _converter = converter;
        }

        [HttpGet("")]
        public IActionResult Index()
        {
            ViewBag.ActiveTab = "thu_ngan";
            ViewBag.CoQuyenThu = User.CoQuyen("thu_ngan", "Them");
            ViewBag.CoQuyenHoan = User.CoQuyen("thu_ngan", "Sua");
            ViewBag.CoQuyenHuy = User.CoQuyen("thu_ngan", "Xoa");
            ViewBag.CoQuyenXuat = User.CoQuyen("thu_ngan", "Xuat");
            ViewData["Title"] = "Thu ngân";
            return View("~/Views/thu_ngan/Index.cshtml");
        }

        [HttpGet("api/chung-tu")]
        public async Task<IActionResult> DanhSachChungTu([FromQuery] long id_vao_vien)
        {
            var idCskcb = User.LayIdCskcb();
            if (idCskcb <= 0) return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước khi xem chứng từ." });
            if (id_vao_vien <= 0) return BadRequest(new { status = 400, message = "Thiếu lượt khám." });

            await using var multi = await _db.QueryMultipleStoAsync("dbo.STO_QL_ThuNgan_DanhSachChungTu", new
            {
                IDCSKCB = idCskcb,
                IDVaoVien = id_vao_vien
            });

            var chungTu = await multi.ReadAsync();
            var chiTiet = await multi.ReadAsync();
            var lichSu = await multi.ReadAsync();

            return Ok(new
            {
                status = 200,
                data = new
                {
                    chung_tu = chungTu,
                    chi_tiet = chiTiet,
                    lich_su = lichSu
                }
            });
        }

        [yeu_cau_quyen_attribute("thu_ngan", "Xuat")]
        [HttpGet("lich-su-chung-tu/excel")]
        public async Task<IActionResult> XuatExcelLichSuChungTu([FromQuery] long id_vao_vien)
        {
            var idCskcb = User.LayIdCskcb();
            if (idCskcb <= 0)
                return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước khi xuất lịch sử chứng từ." });
            if (id_vao_vien <= 0)
                return BadRequest(new { status = 400, message = "Thiếu lượt khám." });

            dynamic? thongTin;
            List<dynamic> rows;
            await using (var multi = await _db.QueryMultipleStoAsync("dbo.STO_QL_ThuNgan_LichSuHuyChungTu", new
            {
                IDCSKCB = idCskcb,
                IDVaoVien = id_vao_vien
            }))
            {
                thongTin = await multi.ReadFirstOrDefaultAsync();
                if (thongTin == null)
                    return NotFound(new { status = 404, message = "Không tìm thấy lượt khám." });
                rows = (await multi.ReadAsync()).ToList();
            }

            var model = new ThuNganLichSuHuyExcelModel();
            foreach (var row in rows)
            {
                var x = (IDictionary<string, object?>)row;
                model.LichSu.Add(new ThuNganLichSuHuyExcelDong
                {
                    NgayThu = DocDateNullable(x, "ngay_thu"),
                    NguonThu = DocString(x, "nguon_thu"),
                    SoChungTu = DocString(x, "so_chung_tu"),
                    TrangThaiXoa = DocString(x, "trang_thai_xoa"),
                    NgayGioHuy = DocDateNullable(x, "ngay_gio_huy"),
                    TenNguoiDangNhapHuy = DocString(x, "ten_nguoi_dang_nhap_huy"),
                    NgayGioXoa = DocDateNullable(x, "ngay_gio_xoa"),
                    TenNguoiDangNhapXoa = DocString(x, "ten_nguoi_dang_nhap_xoa"),
                    TenNguoiXoa = DocString(x, "ten_nguoi_xoa"),
                    LyDoXoa = DocString(x, "ly_do_xoa"),
                    SoDienThoaiBenhNhan = DocString(x, "so_dien_thoai_benh_nhan"),
                    ThongTinHanhChinh = DocString(x, "thong_tin_hanh_chinh"),
                    NoiDungHuy = DocString(x, "noi_dung_huy")
                });
            }

            var info = (IDictionary<string, object?>)thongTin;
            var ma = DocString(info, "ma_vao_vien");
            if (string.IsNullOrWhiteSpace(ma)) ma = DocString(info, "ma_bn");
            if (string.IsNullOrWhiteSpace(ma)) ma = id_vao_vien.ToString();

            var bytes = thu_ngan_excel.LichSuHuyChungTu(model);
            var fileName = tep_tin_dich_vu.TaoTenTaiXuong("lich_su_huy_chung_tu", ma, "xlsx");
            return File(
                bytes,
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                fileName);
        }

        [HttpGet("api/danh-sach-chung-tu")]
        public async Task<IActionResult> DanhSachBenhNhanChungTu(
            [FromQuery] DateTime? tu_ngay = null,
            [FromQuery] DateTime? den_ngay = null,
            [FromQuery] string? q = null,
            [FromQuery] int trang = 1,
            [FromQuery] int kich_thuoc_trang = 25)
        {
            var idCskcb = User.LayIdCskcb();
            if (idCskcb <= 0)
                return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước khi quản lý chứng từ." });

            var page = Math.Max(1, trang);
            var pageSize = Math.Clamp(kich_thuoc_trang, 10, 100);
            var denNgay = (den_ngay ?? DateTime.Today).Date;
            var tuNgay = (tu_ngay ?? denNgay).Date;
            if (denNgay < tuNgay) (tuNgay, denNgay) = (denNgay, tuNgay);

            var rows = (await _db.LayDanhSachStoAsync("dbo.STO_QL_ThuNgan_DanhSachBenhNhanChungTu", new
            {
                IDCSKCB = idCskcb,
                TuNgay = tuNgay,
                DenNgay = denNgay,
                TuKhoa = string.IsNullOrWhiteSpace(q) ? null : q.Trim(),
                Trang = page,
                KichThuocTrang = pageSize
            })).ToList();

            long total = 0;
            if (rows.Count > 0 && rows[0] is IDictionary<string, object?> first
                && first.TryGetValue("tong_so", out var totalValue) && totalValue != null)
            {
                total = Convert.ToInt64(totalValue);
            }

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

        [HttpGet("api/danh-sach")]
        public async Task<IActionResult> DanhSach(
            [FromQuery] DateTime? ngay = null,
            [FromQuery] string? trang_thai = null,
            [FromQuery] string? q = null,
            [FromQuery] int trang = 1,
            [FromQuery] int kich_thuoc_trang = 25)
        {
            var idCskcb = User.LayIdCskcb();
            if (idCskcb <= 0)
                return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước khi thu ngân." });

            byte? trangThai = (trang_thai ?? string.Empty).Trim().ToLowerInvariant() switch
            {
                "" or "tat_ca" or "all" => null,
                "cho_thu" => 0,
                "da_thu" => 1,
                _ when byte.TryParse(trang_thai, out var value) && value <= 1 => value,
                _ => null
            };

            var page = Math.Max(1, trang);
            var pageSize = Math.Clamp(kich_thuoc_trang, 10, 100);
            var ngayLoc = (ngay ?? DateTime.Today).Date;
            var rows = (await _db.LayDanhSachStoAsync("dbo.STO_QL_ThuNgan_DanhSach", new
            {
                IDCSKCB = idCskcb,
                TuNgay = ngayLoc,
                DenNgay = ngayLoc,
                TrangThai = trangThai,
                TuKhoa = string.IsNullOrWhiteSpace(q) ? null : q.Trim(),
                Trang = page,
                KichThuocTrang = pageSize
            })).ToList();

            long total = 0;
            if (rows.Count > 0 && rows[0] is IDictionary<string, object?> first
                && first.TryGetValue("tong_so", out var totalValue) && totalValue != null)
            {
                total = Convert.ToInt64(totalValue);
            }

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

        [HttpGet("api/chi-tiet")]
        public async Task<IActionResult> ChiTiet([FromQuery] long id_vao_vien)
        {
            var idCskcb = User.LayIdCskcb();
            if (idCskcb <= 0)
                return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước khi thu ngân." });
            if (id_vao_vien <= 0)
                return BadRequest(new { status = 400, message = "Thiếu lượt khám." });

            await using var multi = await _db.QueryMultipleStoAsync("dbo.STO_QL_ThuNgan_ChiTiet", new
            {
                IDCSKCB = idCskcb,
                IDVaoVien = id_vao_vien
            });

            var thongTin = await multi.ReadFirstOrDefaultAsync();
            if (thongTin == null)
                return NotFound(new { status = 404, message = "Không tìm thấy lượt khám đang khám hoặc đã hoàn tất." });

            var chiTiet = await multi.ReadAsync();
            return Ok(new
            {
                status = 200,
                data = new
                {
                    thong_tin = thongTin,
                    chi_tiet = chiTiet
                }
            });
        }

        [yeu_cau_quyen_attribute("thu_ngan", "Xuat")]
        [HttpGet("in-phieu")]
        public async Task<IActionResult> InPhieu([FromQuery] long? id_chung_tu = null, [FromQuery] long? id_vao_vien = null)
        {
            var idCskcb = User.LayIdCskcb();
            if (idCskcb <= 0)
                return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước khi in phiếu thu." });
            if (id_chung_tu.GetValueOrDefault() <= 0 && id_vao_vien.GetValueOrDefault() <= 0)
                return BadRequest(new { status = 400, message = "Thiếu chứng từ cần in." });

            dynamic? info;
            List<dynamic> lines;

            /*
             * QueryMultiple giữ DbDataReader mở cho tới khi DisposeAsync.
             * Phải đóng reader trước khi chạy EF query trên cùng DbContext/connection,
             * nếu không SqlClient sẽ báo "already an open DataReader".
             */
            var sto = id_chung_tu.GetValueOrDefault() > 0
                ? "dbo.STO_QL_ThuNgan_ChiTietChungTu"
                : "dbo.STO_QL_ThuNgan_ChiTiet";
            var parameters = id_chung_tu.GetValueOrDefault() > 0
                ? new { IDCSKCB = idCskcb, IDChungTu = id_chung_tu!.Value }
                : (object)new { IDCSKCB = idCskcb, IDVaoVien = id_vao_vien!.Value };
            await using (var multi = await _db.QueryMultipleStoAsync(sto, parameters))
            {
                info = await multi.ReadFirstOrDefaultAsync();
                if (info == null)
                    return NotFound("Không tìm thấy lượt khám.");

                lines = (await multi.ReadAsync()).ToList();
            }

            var d = (IDictionary<string, object?>)info;
            if (id_chung_tu.GetValueOrDefault() <= 0 && !lines.Any(row => DocInt((IDictionary<string, object?>)row, "da_thu") == 1))
                return BadRequest("Lượt khám chưa có khoản nào đã thu.");

            var cskcb = await _db.DmCskcb.AsNoTracking()
                .Where(x => x.Id == idCskcb)
                .Select(x => new { x.TenCskcb, x.DiaChi, x.Sdt })
                .SingleOrDefaultAsync();

            var model = new ThuNganPrintModel
            {
                TenCskcb = cskcb?.TenCskcb ?? string.Empty,
                DiaChiCskcb = cskcb?.DiaChi ?? string.Empty,
                DienThoaiCskcb = cskcb?.Sdt ?? string.Empty,
                MaBenhNhan = DocString(d, "ma_bn"),
                HoTen = DocString(d, "ho_ten"),
                DiaChiBenhNhan = DocString(d, "dia_chi"),
                DienThoaiBenhNhan = DocString(d, "dien_thoai"),
                NgaySinh = DocDateNullable(d, "ngay_sinh"),
                GioiTinh = DocString(d, "gioi_tinh"),
                MaVaoVien = DocString(d, "ma_vao_vien"),
                SoPhieu = DocString(d, "so_phieu"),
                LoaiChungTu = string.IsNullOrWhiteSpace(DocString(d, "loai")) ? "THU" : DocString(d, "loai"),
                TrangThai = d.ContainsKey("trang_thai") ? DocInt(d, "trang_thai") : 1,
                LyDoHuy = DocString(d, "ly_do_huy"),
                SoChungTuGoc = DocString(d, "so_chung_tu_goc"),
                NgayGioThu = DocDateNullable(d, "ngay_gio_thu")
                    ?? throw new InvalidOperationException("Chứng từ thiếu ngày ghi nhận; cần đối chiếu trước khi in."),
                NhanVienThu = DocString(d, "nhan_vien_thu"),
                TongTien = DocDecimal(d, "tong_tien"),
                TienGiam = DocDecimal(d, "tien_giam"),
                ThucThu = DocDecimal(d, "da_thu"),
                TienMat = DocDecimal(d, "tien_mat"),
                ChuyenKhoan = DocDecimal(d, "chuyen_khoan"),
                NganHang = DocString(d, "ten_ngan_hang"),
                GhiChu = DocString(d, "ghi_chu")
            };

            foreach (var row in lines)
            {
                var x = (IDictionary<string, object?>)row;
                if (id_chung_tu.GetValueOrDefault() <= 0 && DocInt(x, "da_thu") != 1) continue;

                model.ChiTiet.Add(new ThuNganPrintDong
                {
                    Loai = DocString(x, "loai"),
                    Ten = DocString(x, "ten"),
                    DonViTinh = DocString(x, "don_vi_tinh"),
                    SoLuong = DocDecimal(x, "so_luong"),
                    DonGia = DocDecimal(x, "don_gia"),
                    ThanhTien = DocDecimal(x, "thanh_tien"),
                    PhuThu = DocDecimal(x, "phu_thu"),
                    GiamPhanTram = DocDecimal(x, "giam_phan_tram"),
                    TienGiam = DocDecimal(x, "tien_giam"),
                    ThanhToan = DocDecimal(x, "thanh_toan")
                });
            }

            var html = await _renderer.RenderAsync(id_chung_tu.GetValueOrDefault() > 0 && model.LoaiChungTu == "THU"
                ? "~/Views/thu_ngan/PhieuThuA4.cshtml"
                : "~/Views/thu_ngan/InPhieu.cshtml", model);
            var document = new HtmlToPdfDocument
            {
                GlobalSettings =
                {
                    ColorMode = ColorMode.Color,
                    Orientation = Orientation.Portrait,
                    PaperSize = PaperKind.A4,
                    Margins = new MarginSettings
                    {
                        Top = 1.0,
                        Bottom = 1.0,
                        Left = 1.0,
                        Right = 1.0,
                        Unit = Unit.Centimeters
                    }
                }
            };

            document.Objects.Add(new ObjectSettings
            {
                PagesCount = true,
                HtmlContent = html,
                WebSettings =
                {
                    DefaultEncoding = "utf-8",
                    LoadImages = true
                },
                LoadSettings =
                {
                    BlockLocalFileAccess = false
                },
                FooterSettings = { FontSize = 8, Right = "Trang [sitepage]/[sitepages]", Spacing = 2.812 }
            });

            var pdf = _converter.Convert(document);
            var fileName = tep_tin_dich_vu.TaoTenTaiXuong(
                "pt",
                string.IsNullOrWhiteSpace(model.MaVaoVien) ? model.SoPhieu : model.MaVaoVien,
                "pdf");

            Response.Headers["Content-Disposition"] = $"inline; filename=\"{fileName}\"";
            Response.Headers["X-Content-Type-Options"] = "nosniff";
            return File(pdf, "application/pdf");
        }

        [yeu_cau_quyen_attribute("thu_ngan", "Them")]
        [HttpPost("api/thu-tien")]
        public async Task<IActionResult> ThuTien([FromBody] ThuTienRequest? request)
        {
            var idCskcb = User.LayIdCskcb();
            var idNhanVien = User.LayIdNhanVien();
            var idTaiKhoan = User.LayIdTaiKhoan();
            var laQuanTri = User.IsInRole("quan_tri_he_thong");
            if (idCskcb <= 0)
                return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước khi thu ngân." });
            if (idTaiKhoan <= 0)
                return Conflict(new { status = 409, message = "Phiên đăng nhập không xác định được tài khoản thực hiện." });
            if (!laQuanTri && idNhanVien <= 0)
                return Conflict(new { status = 409, message = "Tài khoản thu ngân chưa gắn với nhân viên tại cơ sở này." });
            if (request == null || request.id_vao_vien <= 0)
                return BadRequest(new { status = 400, message = "Thiếu lượt khám cần thu tiền." });

            var row = await _db.LayMotDongStoAsync("dbo.STO_QL_ThuNgan_ThuTien", new
            {
                IDCSKCB = idCskcb,
                IDVaoVien = request.id_vao_vien,
                IDNhanVienThu = idNhanVien > 0 ? (long?)idNhanVien : null,
                IDTaiKhoanThu = idTaiKhoan,
                ChuyenKhoan = request.chuyen_khoan,
                IDNganHang = request.id_ngan_hang,
                GhiChu = string.IsNullOrWhiteSpace(request.ghi_chu) ? null : request.ghi_chu.Trim(),
                DanhSachJson = JsonSerializer.Serialize(request.danh_sach)
            });

            return TraKetQua(row, "Thu tiền thành công.");
        }

        [yeu_cau_quyen_attribute("thu_ngan", "Xoa")]
        [HttpPost("api/huy-chung-tu")]
        public async Task<IActionResult> HuyChungTu([FromBody] XuLyChungTuRequest? request)
        {
            var validation = ValidateActor(request?.id_chung_tu ?? 0);
            if (validation != null) return validation;
            var row = await _db.LayMotDongStoAsync("dbo.STO_QL_ThuNgan_HuyChungTu", new
            {
                IDCSKCB = User.LayIdCskcb(),
                IDChungTu = request!.id_chung_tu,
                LyDo = string.IsNullOrWhiteSpace(request.ly_do) ? null : request.ly_do.Trim(),
                IDNhanVien = User.LayIdNhanVien() > 0 ? (long?)User.LayIdNhanVien() : null,
                IDTaiKhoan = User.LayIdTaiKhoan()
            });
            return TraKetQua(row, "Đã hủy chứng từ thu.");
        }

        [yeu_cau_quyen_attribute("thu_ngan", "Sua")]
        [HttpPost("api/hoan-tien")]
        public async Task<IActionResult> HoanTien([FromBody] XuLyChungTuRequest? request)
        {
            var validation = ValidateActor(request?.id_chung_tu ?? 0);
            if (validation != null) return validation;
            var row = await _db.LayMotDongStoAsync("dbo.STO_QL_ThuNgan_HoanTien", new
            {
                IDCSKCB = User.LayIdCskcb(),
                IDChungTuGoc = request!.id_chung_tu,
                LyDo = string.IsNullOrWhiteSpace(request.ly_do) ? null : request.ly_do.Trim(),
                IDNhanVien = User.LayIdNhanVien() > 0 ? (long?)User.LayIdNhanVien() : null,
                IDTaiKhoan = User.LayIdTaiKhoan()
            });
            return TraKetQua(row, "Hoàn tiền thành công.");
        }

        [yeu_cau_quyen_attribute("thu_ngan", "Sua")]
        [HttpPost("api/legacy-huy-nhom-disabled")]
        public IActionResult HuyNhom([FromBody] HuyNhomRequest? request)
            => StatusCode(410, new { status = 410, message = "API legacy chỉ đọc. Hãy xử lý theo chứng từ thu cụ thể." });

        [yeu_cau_quyen_attribute("thu_ngan", "Sua")]
        [HttpPost("api/legacy-huy-thu-disabled")]
        public IActionResult HuyThu([FromBody] HuyThuRequest? request)
            => StatusCode(410, new { status = 410, message = "API legacy chỉ đọc. Hãy xử lý theo chứng từ thu cụ thể." });

        private IActionResult? ValidateActor(long idChungTu)
        {
            if (User.LayIdCskcb() <= 0)
                return Conflict(new { status = 409, message = "Chọn cơ sở KCB trước khi xử lý chứng từ." });
            if (User.LayIdTaiKhoan() <= 0)
                return Conflict(new { status = 409, message = "Phiên đăng nhập không xác định được tài khoản thực hiện." });
            if (!User.IsInRole("quan_tri_he_thong") && User.LayIdNhanVien() <= 0)
                return Conflict(new { status = 409, message = "Tài khoản thu ngân chưa gắn với nhân viên tại cơ sở này." });
            if (idChungTu <= 0)
                return BadRequest(new { status = 400, message = "Thiếu chứng từ cần xử lý." });
            return null;
        }

        private static string DocString(IDictionary<string, object?> data, string key)
            => data.TryGetValue(key, out var value) && value != null && value != DBNull.Value
                ? Convert.ToString(value) ?? string.Empty
                : string.Empty;

        private static decimal DocDecimal(IDictionary<string, object?> data, string key)
            => data.TryGetValue(key, out var value) && value != null && value != DBNull.Value
                ? Convert.ToDecimal(value)
                : 0m;

        private static int DocInt(IDictionary<string, object?> data, string key)
            => data.TryGetValue(key, out var value) && value != null && value != DBNull.Value
                ? Convert.ToInt32(value)
                : 0;

        private static DateTime? DocDateNullable(IDictionary<string, object?> data, string key)
            => data.TryGetValue(key, out var value) && value != null && value != DBNull.Value
                ? Convert.ToDateTime(value)
                : null;

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
