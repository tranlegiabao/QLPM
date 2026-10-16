using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuanLyPhongMach.Data;
using QuanLyPhongMach.Models.Requests.PhacDo;
using QuanLyPhongMach.Services;

namespace QuanLyPhongMach.Controllers
{
    [yeu_cau_quyen_attribute("phac_do", "Xem")]
    [Route("phac_do")]
    public class phac_do_controller : Controller
    {
        private readonly QlpmDbContext _db;

        public phac_do_controller(QlpmDbContext db)
        {
            _db = db;
        }

        [HttpGet("")]
        public IActionResult Index()
        {
            ViewBag.ActiveTab = "phac_do";
            ViewBag.HienThiThanhPhanHe = false;
            ViewData["Title"] = "Quản lý phác đồ điều trị";
            return View("~/Views/phac_do/Index.cshtml");
        }

        [HttpGet("/api/phac_do/danh_sach")]
        public async Task<IActionResult> LayDanhSach(
            [FromQuery] string? tu_khoa = null,
            [FromQuery] string? q = null,
            [FromQuery] int trang = 1,
            [FromQuery] int kich_thuoc_trang = 25)
        {
            string? search = !string.IsNullOrEmpty(q) ? q : tu_khoa;

            var ds = await _db.LayDanhSachStoAsync("dbo.STO_DM_PhacDo_DanhSach", new
            {
                IDCSKCB = User.LayIdCskcb(),
                TuKhoa = search,
                Trang = Math.Max(1, trang),
                KichThuocTrang = Math.Min(1000, Math.Max(10, kich_thuoc_trang))
            });

            var mapped = ds.Select(x =>
            {
                var d = (IDictionary<string, object?>)x;
                d.TryGetValue("ID", out var id);
                d.TryGetValue("MaPhacDo", out var ma);
                d.TryGetValue("TenPhacDo", out var ten);
                d.TryGetValue("IDICD10", out var idIcd);
                d.TryGetValue("MaICD10", out var maIcd);
                d.TryGetValue("TenICD10", out var tenIcd);
                d.TryGetValue("TrieuChung", out var trieuChung);
                d.TryGetValue("SoLuongChiDinh", out var slcd);
                d.TryGetValue("SoLuongThuoc", out var slt);
                d.TryGetValue("TongSoDong", out var tongSoDong);

                return new
                {
                    id,
                    ma,
                    ten,
                    ma_phac_do = ma,
                    ten_phac_do = ten,
                    id_icd10 = idIcd,
                    ma_icd10 = maIcd,
                    ten_icd10 = tenIcd,
                    trieu_chung = trieuChung,
                    so_luong_chi_dinh = slcd,
                    so_luong_thuoc = slt,
                    tong_so_dong = tongSoDong
                };
            });

            return Ok(new { status = 200, message = "Thành công", data = mapped });
        }

        [HttpGet("/api/phac_do/chi_tiet")]
        public async Task<IActionResult> LayChiTiet([FromQuery] long id)
        {
            if (id <= 0)
                return Ok(new { status = 400, message = "Thiếu phác đồ." });
            await using var multi = await _db.QueryMultipleStoAsync("dbo.STO_DM_PhacDo_ChiTiet", new
            {
                IDCSKCB = User.LayIdCskcb(),
                ID = id
            });

            var thongTin = await multi.ReadFirstOrDefaultAsync();
            if (thongTin == null)
            {
                return Ok(new { status = 404, message = "Không tìm thấy phác đồ." });
            }

            var chiDinh = await multi.ReadAsync();
            var thuoc = await multi.ReadAsync();
            var chanDoan = await multi.ReadAsync();

            return Ok(new
            {
                status = 200,
                message = "Thành công",
                data = new
                {
                    thong_tin = thongTin,
                    chi_dinh = chiDinh,
                    thuoc = thuoc,
                    chan_doan = chanDoan
                }
            });
        }

        [HttpPost("/api/phac_do/luu")]
        [yeu_cau_quyen_attribute("phac_do", "Sua")]
        public async Task<IActionResult> LuuPhacDo([FromBody] PhacDoLuuRequest? request)
        {
            if (request == null)
                return Ok(new { status = 400, message = "Kiểm tra lại phác đồ." });

            if (string.IsNullOrWhiteSpace(request.ma_phac_do) || string.IsNullOrWhiteSpace(request.ten_phac_do))
            {
                return Ok(new { status = 400, message = "Nhập mã và tên phác đồ." });
            }

            string chanDoanJson = request.chan_doan is JsonElement cdnJe ? cdnJe.GetRawText() : (request.chan_doan != null ? JsonSerializer.Serialize(request.chan_doan) : "[]");
            if (DemBenhChinh(chanDoanJson) != 1)
            {
                return Ok(new { status = 400, message = "Chọn đúng 1 bệnh chính." });
            }

            var idCskcb = User.LayIdCskcb();
            var maPhacDo = request.ma_phac_do.Trim();
            long? idPhacDoLuu = request.id;

            // UQ_DM_PhacDo_CSKCB_Ma áp dụng cả dòng Active=0.
            // Nếu mã từng bị xóa mềm thì tái sử dụng chính ID cũ thay vì INSERT ID mới.
            var phacDoTrung = await _db.DmPhacDo
                .AsNoTracking()
                .Where(x => x.Idcskcb == idCskcb && x.MaPhacDo == maPhacDo)
                .Select(x => new { x.Id, x.Active })
                .FirstOrDefaultAsync();

            if (phacDoTrung != null && (!idPhacDoLuu.HasValue || idPhacDoLuu.Value <= 0))
            {
                if (phacDoTrung.Active)
                {
                    return Ok(new { status = 409, message = "Mã phác đồ đã tồn tại." });
                }

                idPhacDoLuu = phacDoTrung.Id;
            }
            else if (phacDoTrung != null && idPhacDoLuu.HasValue && phacDoTrung.Id != idPhacDoLuu.Value)
            {
                return Ok(new { status = 409, message = "Mã phác đồ đã có." });
            }
            string chiDinhJson = request.chi_dinh is JsonElement cdJe ? cdJe.GetRawText() : (request.chi_dinh != null ? JsonSerializer.Serialize(request.chi_dinh) : "[]");
            string thuocJson = request.thuoc is JsonElement tJe ? tJe.GetRawText() : (request.thuoc != null ? JsonSerializer.Serialize(request.thuoc) : "[]");

            var ketQua = await _db.LayMotDongStoAsync("dbo.STO_DM_PhacDo_Luu", new
            {
                IDCSKCB = idCskcb,
                ID = idPhacDoLuu,
                MaPhacDo = maPhacDo,
                TenPhacDo = request.ten_phac_do.Trim(),
                TrieuChung = request.trieu_chung?.Trim(),
                ChanDoanJson = chanDoanJson,
                ChiDinhJson = chiDinhJson,
                ThuocJson = thuocJson
            });

            int status = 500;
            string message = "Không lưu được phác đồ.";
            object? idMoi = null;

            if (ketQua != null)
            {
                var dict = (IDictionary<string, object?>)ketQua;
                if (dict.TryGetValue("Status", out var s) && s != null) status = Convert.ToInt32(s);
                message = status == 200 ? "Đã lưu phác đồ." : "Không lưu được phác đồ.";
                dict.TryGetValue("ID", out idMoi);
            }

            if (message.Contains("UQ_DM_PhacDo_CSKCB_Ma", StringComparison.OrdinalIgnoreCase)
                || message.Contains("duplicate key", StringComparison.OrdinalIgnoreCase))
            {
                status = 409;
                message = "Mã phác đồ đã tồn tại.";
            }

            return Ok(new
            {
                status,
                message,
                data = new { id = idMoi }
            });
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

        [HttpPost("/api/phac_do/xoa")]
        [yeu_cau_quyen_attribute("phac_do", "Xoa")]
        public async Task<IActionResult> XoaPhacDo([FromBody] PhacDoXoaRequest? request)
        {
            if (request == null || request.id <= 0)
                return Ok(new { status = 400, message = "Thiếu phác đồ." });

            var ketQua = await _db.LayMotDongStoAsync("dbo.STO_DM_PhacDo_Xoa", new
            {
                IDCSKCB = User.LayIdCskcb(),
                ID = request.id
            });

            int status = 500;
            string message = "Không xóa được phác đồ.";

            if (ketQua != null)
            {
                var dict = (IDictionary<string, object?>)ketQua;
                if (dict.TryGetValue("Status", out var s) && s != null) status = Convert.ToInt32(s);
                message = status == 200 ? "Đã xóa phác đồ." : "Không xóa được phác đồ.";
            }

            return Ok(new { status, message });
        }
    }
}
