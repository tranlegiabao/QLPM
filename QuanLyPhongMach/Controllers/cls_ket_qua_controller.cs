using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuanLyPhongMach.Data;
using QuanLyPhongMach.Entities;
using QuanLyPhongMach.Models.Requests.Cls;
using QuanLyPhongMach.Services;

namespace QuanLyPhongMach.Controllers
{
    [Route("cls_ket_qua")]
    public class cls_ket_qua_controller : Controller
    {
        private readonly QlpmDbContext _db;
        private readonly QlpmDocumentStorage _storage;

        public cls_ket_qua_controller(QlpmDbContext db, QlpmDocumentStorage storage)
        {
            _db = db;
            _storage = storage;
        }

        [HttpGet("/api/cls/danh_sach")]
        [yeu_cau_quyen_attribute("kham_benh", "Xem")]
        public async Task<IActionResult> DanhSach(
            [FromQuery] string? q = null,
            [FromQuery] int trang = 1,
            [FromQuery] int kich_thuoc_trang = 25)
        {
            if (!CoCoSo(out var idCskcb)) return Unauthorized();

            var query = from cd in _db.QlChiDinhCt.AsNoTracking()
                        join dv in _db.DmDichVu.AsNoTracking()
                            on new { cd.Idcskcb, Id = cd.IddichVu } equals new { dv.Idcskcb, dv.Id }
                        join vv in _db.QlVaoVien.AsNoTracking()
                            on new { cd.Idcskcb, Id = cd.IdvaoVien } equals new { vv.Idcskcb, vv.Id }
                        join bn in _db.QlBenhNhan.AsNoTracking()
                            on new { vv.Idcskcb, Id = vv.IdbenhNhan } equals new { bn.Idcskcb, bn.Id }
                        where cd.Idcskcb == idCskcb && cd.Active
                        select new
                        {
                            IDChiDinhCT = cd.Id,
                            cd.IdvaoVien,
                            vv.MaVaoVien,
                            bn.MaBn,
                            bn.HoTen,
                            bn.NgaySinh,
                            cd.IddichVu,
                            dv.MaDichVu,
                            dv.TenDichVu,
                            cd.NgayGioChiDinh,
                            cd.DuongDanKetQua,
                            CoFileKetQua = !string.IsNullOrWhiteSpace(cd.DuongDanKetQua)
                        };

            if (!string.IsNullOrWhiteSpace(q))
            {
                var term = q.Trim().ToLower();
                query = query.Where(x =>
                    x.MaVaoVien.ToLower().Contains(term) ||
                    x.MaBn.ToLower().Contains(term) ||
                    x.HoTen.ToLower().Contains(term) ||
                    x.MaDichVu.ToLower().Contains(term) ||
                    x.TenDichVu.ToLower().Contains(term));
            }

            var total = await query.CountAsync();
            var page = Math.Max(1, trang);
            var pageSize = Math.Clamp(kich_thuoc_trang, 10, 100);

            var rows = await query
                .OrderByDescending(x => x.NgayGioChiDinh)
                .ThenByDescending(x => x.IDChiDinhCT)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync();

            return Ok(new
            {
                status = 200,
                message = "Thành công",
                data = rows,
                total,
                page,
                pageSize
            });
        }

        [HttpGet("/api/cls/ket_qua")]
        [yeu_cau_quyen_attribute("kham_benh", "Xem")]
        public async Task<IActionResult> KetQuaChiTiet([FromQuery] long id_chi_dinh_ct)
        {
            if (!CoCoSo(out var idCskcb)) return Unauthorized();
            if (id_chi_dinh_ct <= 0)
                return Ok(new { status = 400, message = "Thiếu chỉ định CLS." });

            var info = await (
                from cd in _db.QlChiDinhCt.AsNoTracking()
                join dv in _db.DmDichVu.AsNoTracking()
                    on new { cd.Idcskcb, Id = cd.IddichVu } equals new { dv.Idcskcb, dv.Id }
                join vv in _db.QlVaoVien.AsNoTracking()
                    on new { cd.Idcskcb, Id = cd.IdvaoVien } equals new { vv.Idcskcb, vv.Id }
                join bn in _db.QlBenhNhan.AsNoTracking()
                    on new { vv.Idcskcb, Id = vv.IdbenhNhan } equals new { bn.Idcskcb, bn.Id }
                where cd.Id == id_chi_dinh_ct && cd.Idcskcb == idCskcb && cd.Active
                select new
                {
                    ID = cd.Id,
                    IDChiDinhCT = cd.Id,
                    IDVaoVien = cd.IdvaoVien,
                    IDDichVu = cd.IddichVu,
                    dv.MaDichVu,
                    dv.TenDichVu,
                    bn.MaBn,
                    bn.HoTen,
                    bn.NgaySinh,
                    cd.DuongDanKetQua,
                    CoFileKetQua = !string.IsNullOrWhiteSpace(cd.DuongDanKetQua),
                    TrangThai = string.IsNullOrWhiteSpace(cd.DuongDanKetQua) ? 0 : 2
                }
            ).FirstOrDefaultAsync();

            if (info == null)
                return Ok(new { status = 404, message = "Không tìm thấy chỉ định CLS." });

            return Ok(new
            {
                status = 200,
                message = "Đã tải kết quả CLS.",
                data = info
            });
        }

        [HttpPost("/api/cls/chi_dinh/dam_bao")]
        [yeu_cau_quyen_attribute("kham_benh", "Sua")]
        public async Task<IActionResult> DamBaoChiDinh([FromBody] DamBaoChiDinhRequest? request)
        {
            var contextError = ValidateClsOperator(out var idCskcb, out var idNhanVien);
            if (contextError != null) return contextError;
            if (request == null || request.id_vao_vien <= 0 || request.id_dich_vu <= 0)
                return Ok(new { status = 400, message = "Thiếu lượt khám hoặc dịch vụ CLS." });

            if (request.so_luong <= 0 || request.so_luong > 99999999.99m
                || decimal.Round(request.so_luong, 2) != request.so_luong)
                return Ok(new { status = 400, message = "Số lượng CLS phải lớn hơn 0, tối đa 2 chữ số thập phân." });

            var row = await _db.LayMotDongStoAsync("dbo.STO_QL_Cls_DamBaoChiDinh", new
            {
                IDCSKCB = idCskcb,
                IDVaoVien = request.id_vao_vien,
                IDDichVu = request.id_dich_vu,
                IDBacSi = User.IsInRole("quan_tri_he_thong") ? null : idNhanVien,
                LaQuanTri = User.IsInRole("quan_tri_he_thong"),
                CoQuyenSua = User.CoQuyen("kham_benh", "Sua"),
                SoLuong = request.so_luong,
                GuiNgoai = request.gui_ngoai,
                NoiGuiNgoai = request.noi_gui_ngoai?.Trim(),
                GhiChu = request.ghi_chu?.Trim()
            });

            if (row is not IDictionary<string, object?> result)
                return Ok(new { status = 500, message = "Không nhận được kết quả lưu chỉ định CLS." });
            var status = Convert.ToInt32(result["Status"]);
            return Ok(new
            {
                status,
                message = Convert.ToString(result["Message"]),
                data = status == 200 ? new { id_chi_dinh_ct = Convert.ToInt64(result["IDChiDinhCT"]) } : null
            });
        }

        [HttpPost("/api/cls/file/upload")]
        [yeu_cau_quyen_attribute("kham_benh", "Sua")]
        [RequestSizeLimit(16 * 1024 * 1024)]
        public async Task<IActionResult> Upload([FromForm] long id_chi_dinh_ct, [FromForm] IFormFile? file)
        {
            const long maxFileBytes = 15L * 1024 * 1024;

            var contextError = ValidateClsOperator(out var idCskcb, out _);
            if (contextError != null) return contextError;

            if (id_chi_dinh_ct <= 0 || file == null || file.Length <= 0)
                return Ok(new { status = 400, message = "Thiếu file hoặc chỉ định CLS." });
            if (file.Length > maxFileBytes)
                return Ok(new { status = 413, message = "File kết quả tối đa 15 MB." });

            var format = ClsFileFormat.FromPath(file.FileName ?? string.Empty);
            if (format == null)
                return Ok(new { status = 400, message = "Chỉ nhận PDF hoặc ảnh JPG, JPEG, PNG, WEBP." });

            // Check actual file bytes, not the filename or client MIME alone.
            var header = new byte[12];
            await using (var readStream = file.OpenReadStream())
            {
                var readCount = 0;
                while (readCount < header.Length)
                {
                    var count = await readStream.ReadAsync(header.AsMemory(readCount), HttpContext.RequestAborted);
                    if (count == 0) break;
                    readCount += count;
                }
                if (!ClsFileFormat.Matches(format, header.AsSpan(0, readCount)))
                {
                    return Ok(new { status = 400, message = "Nội dung file không khớp định dạng PDF/ảnh đã chọn." });
                }
            }

            var chiDinh = await _db.QlChiDinhCt.AsNoTracking()
                .FirstOrDefaultAsync(x => x.Id == id_chi_dinh_ct && x.Idcskcb == idCskcb && x.Active);
            if (chiDinh == null)
                return Ok(new { status = 404, message = "Không tìm thấy chỉ định CLS hợp lệ." });

            if (await _db.QlVaoVien.AsNoTracking().AnyAsync(x =>
                    x.Idcskcb == idCskcb && x.Id == chiDinh.IdvaoVien && x.TrangThaiKham == 2))
                return Conflict(new { status = 409, message = "Lượt khám đã hoàn tất, không thể thay đổi file kết quả CLS." });

            // Keep the STO's existing logical key. Storage maps it to FTP,
            // so no local directory/file is created for new results.
            var relativeDir = Path.Combine("App_Data", "cls", idCskcb.ToString(), id_chi_dinh_ct.ToString());
            var storedName = tep_tin_dich_vu.TaoTenLuuTru("kqcls", id_chi_dinh_ct, format.Extension);
            var relativePath = Path.Combine(relativeDir, storedName).Replace('\\', '/');

            string? oldRelativePath;
            try
            {
                await using (var stream = file.OpenReadStream())
                    await _storage.UploadClsAsync(relativePath, idCskcb, id_chi_dinh_ct, stream, HttpContext.RequestAborted);
                var row = await _db.LayMotDongStoAsync("dbo.STO_QL_Cls_LuuDuongDanKetQua", new
                {
                    IDCSKCB = idCskcb,
                    IDChiDinhCT = id_chi_dinh_ct,
                    DuongDanKetQua = relativePath
                });

                if (row is not IDictionary<string, object?> result)
                {
                    await DeleteStoredClsBestEffort(relativePath, idCskcb, id_chi_dinh_ct);
                    return Ok(new { status = 500, message = "Không nhận được kết quả lưu file CLS." });
                }

                var status = Convert.ToInt32(result["Status"]);
                if (status != 200)
                {
                    await DeleteStoredClsBestEffort(relativePath, idCskcb, id_chi_dinh_ct);
                    return Ok(new
                    {
                        status,
                        message = Convert.ToString(result["Message"])
                    });
                }

                oldRelativePath = Convert.ToString(result["DuongDanKetQuaCu"]);
            }
            catch
            {
                await DeleteStoredClsBestEffort(relativePath, idCskcb, id_chi_dinh_ct);
                throw;
            }

            // Xóa file cũ (best-effort) sau khi update DB thành công
            if (!string.IsNullOrWhiteSpace(oldRelativePath))
            {
                await DeleteStoredClsBestEffort(oldRelativePath, idCskcb, id_chi_dinh_ct);
            }

            return Ok(new
            {
                status = 200,
                message = "Đã tải file kết quả lên.",
                data = new
                {
                    id_chi_dinh_ct,
                    duong_dan = relativePath,
                    co_file = true
                }
            });
        }

        [HttpGet("/api/cls/file/{id:long}")]
        [yeu_cau_quyen_attribute("kham_benh", "Xem")]
        public async Task<IActionResult> FileKetQua(long id, [FromQuery] bool inline = true)
        {
            if (!CoCoSo(out var idCskcb)) return Unauthorized();

            var chiDinh = await _db.QlChiDinhCt.AsNoTracking()
                .FirstOrDefaultAsync(x => x.Id == id && x.Idcskcb == idCskcb && x.Active);
            if (chiDinh == null || string.IsNullOrWhiteSpace(chiDinh.DuongDanKetQua))
                return NotFound();

            var format = ClsFileFormat.FromPath(chiDinh.DuongDanKetQua);
            if (format == null) return NotFound();
            var bytes = await _storage.ReadClsAsync(chiDinh.DuongDanKetQua, idCskcb, id, HttpContext.RequestAborted);
            if (bytes == null) return NotFound();
            Response.Headers["X-Content-Type-Options"] = "nosniff";
            Response.Headers["Cache-Control"] = "no-store";
            return inline
                ? File(bytes, format.ContentType, enableRangeProcessing: true)
                : File(bytes, format.ContentType, tep_tin_dich_vu.TaoTenTaiXuong("kqcls", id.ToString(), format.Extension), enableRangeProcessing: true);
        }

        [HttpPost("/api/cls/file/xoa")]
        [yeu_cau_quyen_attribute("kham_benh", "Sua")]
        public async Task<IActionResult> XoaFile([FromBody] XoaClsFileRequest? request)
        {
            var contextError = ValidateClsOperator(out var idCskcb, out _);
            if (contextError != null) return contextError;

            var targetId = request?.id_chi_dinh_ct ?? 0;

            if (targetId <= 0)
                return Ok(new { status = 400, message = "Dữ liệu xóa file không hợp lệ." });

            var chiDinh = await _db.QlChiDinhCt
                .FirstOrDefaultAsync(x => x.Id == targetId && x.Idcskcb == idCskcb && x.Active);
            if (chiDinh == null)
                return Ok(new { status = 404, message = "Không tìm thấy chỉ định CLS." });

            if (await _db.QlVaoVien.AsNoTracking().AnyAsync(x =>
                    x.Idcskcb == idCskcb && x.Id == chiDinh.IdvaoVien && x.TrangThaiKham == 2))
                return Conflict(new { status = 409, message = "Lượt khám đã hoàn tất, không thể thay đổi file kết quả CLS." });

            var oldRelativePath = chiDinh.DuongDanKetQua;
            chiDinh.DuongDanKetQua = null;
            await _db.SaveChangesAsync();

            if (!string.IsNullOrWhiteSpace(oldRelativePath))
            {
                await DeleteStoredClsBestEffort(oldRelativePath, idCskcb, targetId);
            }

            return Ok(new { status = 200, message = "Đã xóa file kết quả." });
        }

        private bool CoCoSo(out long idCskcb)
        {
            idCskcb = User.LayIdCskcb();
            return User.Identity?.IsAuthenticated == true && idCskcb > 0;
        }

        private IActionResult? ValidateClsOperator(out long idCskcb, out long? idNhanVien)
        {
            idNhanVien = null;
            if (User.Identity?.IsAuthenticated != true)
            {
                idCskcb = 0;
                return Unauthorized(new
                {
                    status = StatusCodes.Status401Unauthorized,
                    message = "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại."
                });
            }

            idCskcb = User.LayIdCskcb();
            if (idCskcb <= 0)
                return StatusCode(StatusCodes.Status403Forbidden, new
                {
                    status = StatusCodes.Status403Forbidden,
                    message = "Chọn cơ sở làm việc trước khi tải file."
                });

            var idNhanVienDangNhap = User.LayIdNhanVien();
            if (idNhanVienDangNhap > 0)
            {
                idNhanVien = idNhanVienDangNhap;
                return null;
            }

            if (User.IsInRole("quan_tri_he_thong")) return null;

            return StatusCode(StatusCodes.Status403Forbidden, new
            {
                status = StatusCodes.Status403Forbidden,
                message = "Tài khoản chưa được gắn với nhân viên."
            });
        }

        private async Task DeleteStoredClsBestEffort(string key, long tenant, long order)
        {
            try
            {
                await _storage.DeleteClsAsync(key, tenant, order, CancellationToken.None);
            }
            catch
            {
                // Keep the existing best-effort cleanup semantics after DB save.
            }
        }
    }
}
