using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using QuanLyPhongMach.Services;

namespace QuanLyPhongMach.Controllers
{
    [ApiController]
    [Route("api/danh_muc")]
    public class danh_muc_controller : ControllerBase
    {
        private readonly danh_muc_json_dich_vu _danhMucService;

        public danh_muc_controller(danh_muc_json_dich_vu danhMucService)
        {
            _danhMucService = danhMucService;
        }

        [HttpGet("trang_thai_dong_bo")]
        public async Task<IActionResult> TrangThaiDongBo([FromQuery] long? id_cskcb = null)
        {
            var cskcb = LayIdCskcbDanhMuc(id_cskcb);
            var manifest = await _danhMucService.LayThongTinManifestAsync(cskcb > 0 ? cskcb : null);
            var jsonVersion = cskcb > 0
                ? await _danhMucService.LayTrangThaiJsonAsync(cskcb)
                : null;

            if (manifest == null && jsonVersion == null)
            {
                return Ok(new
                {
                    status = 404,
                    message = "Chưa có thông tin manifest/version JSON"
                });
            }

            return Ok(new
            {
                status = 200,
                message = "Thành công",
                data = manifest?.RootElement,
                json_version = jsonVersion
            });
        }

        [HttpPost("dong_bo")]
        public async Task<IActionResult> DongBo([FromQuery] long? id_cskcb = null)
        {
            var cskcb = LayIdCskcbDanhMuc(id_cskcb);
            if (cskcb <= 0)
                return BadRequest(new { status = 400, message = "Chọn cơ sở KCB." });

            var manifest = await _danhMucService.DongBoTatCaJsonTuDbAsync(cskcb);
            return Ok(new
            {
                status = 200,
                message = "Đã đồng bộ danh mục.",
                data = manifest
            });
        }

        [HttpGet("{loai}")]
        public async Task<IActionResult> LayDanhMuc(
            string loai,
            [FromQuery] string? q = null,
            [FromQuery] string? tu_khoa = null,
            [FromQuery] long? id_cskcb = null,
            [FromQuery] int top = 20,
            [FromQuery] long? id_tinh = null,
            [FromQuery] string? ma_loai_toa_thuoc = null)
        {
            var cskcb = LayIdCskcbDanhMuc(id_cskcb);
            var loaiDungChung = string.Equals(loai, "ngan_hang", System.StringComparison.OrdinalIgnoreCase)
                || string.Equals(loai, "dm_ngan_hang", System.StringComparison.OrdinalIgnoreCase)
                || string.Equals(loai, "gioi_tinh", System.StringComparison.OrdinalIgnoreCase)
                || string.Equals(loai, "dm_gioi_tinh", System.StringComparison.OrdinalIgnoreCase)
                || string.Equals(loai, "chuc_danh", System.StringComparison.OrdinalIgnoreCase)
                || string.Equals(loai, "dm_chuc_danh", System.StringComparison.OrdinalIgnoreCase);
            if (cskcb <= 0 && !loaiDungChung)
                return BadRequest(new { status = 400, message = "Chọn cơ sở KCB." });

            string? searchTerm = !string.IsNullOrEmpty(q) ? q : tu_khoa;
            top = Math.Min(1000, Math.Max(1, top));
            var ketQua = await _danhMucService.LayDanhSachDropdownAsync(cskcb, loai, searchTerm, top, id_tinh, ma_loai_toa_thuoc);
            return Ok(new
            {
                status = 200,
                message = "Thành công",
                data = ketQua
            });
        }
        private long LayIdCskcbDanhMuc(long? idCskcbYeuCau)
        {
            if (!User.IsInRole("quan_tri_he_thong"))
                return User.LayIdCskcb();

            // Global admin: nếu API truyền CSKCB đích thì dùng CSKCB đó;
            // nếu không truyền (các màn nghiệp vụ như Tiếp nhận), dùng working-CSKCB
            // đã chọn trong cookie/claim.
            var idTheoQuery = idCskcbYeuCau.GetValueOrDefault();
            return idTheoQuery > 0 ? idTheoQuery : User.LayIdCskcb();
        }

    }
}
