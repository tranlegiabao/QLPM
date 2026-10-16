using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using QuanLyPhongMach.Data;
using QuanLyPhongMach.Entities;

namespace QuanLyPhongMach.Services
{
    public class danh_muc_json_dich_vu
    {
        private readonly string _jsonRootPath;
        private readonly IServiceScopeFactory? _scopeFactory;
        private readonly IConfiguration? _configuration;
        private static readonly ConcurrentDictionary<string, (DateTime LastModified, JsonDocument Doc)> Cache = new();
        private static readonly ConcurrentDictionary<long, System.Threading.SemaphoreSlim> SyncLocks = new();
        private static readonly System.Threading.SemaphoreSlim CommonJsonLock = new(1, 1);

        public danh_muc_json_dich_vu() : this(null, null)
        {
        }

        public danh_muc_json_dich_vu(IServiceScopeFactory? scopeFactory, IConfiguration? configuration)
        {
            _scopeFactory = scopeFactory;
            _configuration = configuration;
            var current = new DirectoryInfo(Directory.GetCurrentDirectory());
            while (current != null && !File.Exists(Path.Combine(current.FullName, "QuanLyPhongMach.sln")))
            {
                current = current.Parent;
            }
            string rootDir = current?.FullName ?? Directory.GetCurrentDirectory();
            string pathAtRoot = Path.Combine(rootDir, "Data", "Json");
            string pathAtProject = Path.Combine(Directory.GetCurrentDirectory(), "Data", "Json");

            _jsonRootPath = Directory.Exists(pathAtRoot) ? pathAtRoot : pathAtProject;
        }

        public string LayDuongDanRoot() => _jsonRootPath;

        public async Task<JsonDocument?> DocJsonAsync(string relativePath)
        {
            string fullPath = Path.Combine(_jsonRootPath, relativePath);
            if (!File.Exists(fullPath))
            {
                // Fallback check
                string altPath = Path.Combine(Directory.GetCurrentDirectory(), "Data", "Json", relativePath);
                if (File.Exists(altPath)) fullPath = altPath;
                else return null;
            }

            var lastModified = File.GetLastWriteTimeUtc(fullPath);
            if (Cache.TryGetValue(fullPath, out var cached) && cached.LastModified == lastModified)
            {
                return cached.Doc;
            }

            string content = await File.ReadAllTextAsync(fullPath);
            var doc = JsonDocument.Parse(content);
            Cache[fullPath] = (lastModified, doc);
            return doc;
        }

        public async Task<IEnumerable<dynamic>> LayDanhSachDropdownAsync(long idCskcb, string loaiDanhMuc, string? tuKhoa = null, int top = 20, long? idTinhFilter = null, string? maLoaiToaThuoc = null)
        {
            string cleanLoai = loaiDanhMuc.ToLowerInvariant();
            if (cleanLoai.StartsWith("dm_"))
            {
                cleanLoai = cleanLoai.Substring(3);
            }

            if ((cleanLoai == "dan_toc" || cleanLoai == "quoc_tich" || cleanLoai == "nghe_nghiep") && top <= 20)
            {
                top = 100;
            }
            else if (cleanLoai == "tinh_thanh")
            {
                // Toàn bộ 63 tỉnh thành Việt Nam cần được hiển thị đầy đủ
                if (top <= 20) top = 100;
            }
            else if (cleanLoai == "phuong_xa")
            {
                if (idTinhFilter.HasValue && idTinhFilter.Value > 0)
                {
                    if (top <= 20) top = 1000;
                }
                else if (top <= 20)
                {
                    top = 500;
                }
            }

            var maxTop = cleanLoai is "phuong_xa" or "icd10" or "dich_vu" or "thuoc" or "ma_giam_gia" ? 1000 : 100;
            top = Math.Min(maxTop, Math.Max(1, top));

            string fileName = cleanLoai switch
            {
                "ngan_hang" => "dung_chung/dm_ngan_hang.json",
                "gioi_tinh" => "dung_chung/dm_gioi_tinh.json",
                "chuc_danh" => "dung_chung/dm_chuc_danh.json",
                "dan_toc" => $"{idCskcb}/dm_dan_toc.json",
                "quoc_tich" => $"{idCskcb}/dm_quoc_tich.json",
                "nghe_nghiep" => $"{idCskcb}/dm_nghe_nghiep.json",
                "tinh_thanh" => $"{idCskcb}/dm_tinh_thanh.json",
                "phuong_xa" => $"{idCskcb}/dm_phuong_xa.json",
                "icd10" => $"{idCskcb}/dm_icd10.json",
                "dich_vu" => $"{idCskcb}/dm_dich_vu.json",
                "cong_kham" => $"{idCskcb}/dm_cong_kham.json",
                "thuoc" => $"{idCskcb}/dm_thuoc.json",
                "don_vi_tinh" => $"{idCskcb}/dm_don_vi_tinh.json",
                "tri_so_sinh_hieu" => $"{idCskcb}/dm_tri_so_sinh_hieu.json",
                "nhan_vien" => $"{idCskcb}/dm_nhan_vien.json",
                "bac_si" => $"{idCskcb}/dm_bac_si.json",
                "ma_giam_gia" => $"{idCskcb}/dm_ma_giam_gia.json",
                _ => $"{idCskcb}/dm_{cleanLoai}.json"
            };

            var doc = await DocJsonAsync(fileName);
            if (doc == null) return Enumerable.Empty<dynamic>();

            var allItems = new List<dynamic>();
            tuKhoa = tuKhoa?.Trim().ToLowerInvariant();
            string tuKhoaKhongDau = !string.IsNullOrEmpty(tuKhoa) ? LoaiBoDauTiengViet(tuKhoa) : "";

            foreach (var el in doc.RootElement.EnumerateArray())
            {
                long id = el.TryGetProperty("id", out var pId) ? pId.GetInt64() : 0;
                string ma = el.TryGetProperty("ma", out var pMa) ? pMa.GetString() ?? "" : "";
                string ten = el.TryGetProperty("ten", out var pTen) ? pTen.GetString() ?? "" : "";

                long? idTinh = el.TryGetProperty("id_tinh", out var pIt) ? pIt.GetInt64() : null;

                if (string.IsNullOrWhiteSpace(ten)) continue;

                // Lọc theo tỉnh thành nếu có chỉ định (dùng cho danh mục phường/xã)
                if (cleanLoai == "phuong_xa" && idTinhFilter.HasValue && idTinhFilter.Value > 0)
                {
                    if (!idTinh.HasValue || idTinh.Value != idTinhFilter.Value)
                    {
                        continue;
                    }
                }

                // Additional properties for specific dropdowns
                long? idDonViTinh = el.TryGetProperty("id_don_vi_tinh", out var pIdDvt)
                    && pIdDvt.ValueKind == JsonValueKind.Number
                    ? pIdDvt.GetInt64() : null;
                decimal? donGia = el.TryGetProperty("don_gia", out var pDg) ? pDg.GetDecimal() : null;
                decimal? giaBan = el.TryGetProperty("gia_ban", out var pGb) ? pGb.GetDecimal() : null;
                decimal? tiLe = el.TryGetProperty("ti_le", out var pTl) && pTl.ValueKind == JsonValueKind.Number ? pTl.GetDecimal() : null;
                string? donViTinh = el.TryGetProperty("don_vi_tinh", out var pDvt) ? pDvt.GetString() : null;
                string? duongDung = el.TryGetProperty("duong_dung", out var pDd) ? pDd.GetString() : null;
                string? hamLuong = el.TryGetProperty("ham_luong", out var pHl) ? pHl.GetString() : null;
                string? hoatChat = el.TryGetProperty("hoat_chat", out var pHc) ? pHc.GetString() : null;
                bool? guiNgoai = el.TryGetProperty("gui_ngoai", out var pGn) ? pGn.GetBoolean() : null;
                string? maLoaiToa = el.TryGetProperty("ma_loai_toa_thuoc", out var pLoaiToa) && pLoaiToa.ValueKind == JsonValueKind.String
                    ? pLoaiToa.GetString() : null;

                if (cleanLoai == "thuoc" && !string.IsNullOrWhiteSpace(maLoaiToaThuoc)
                    && !string.Equals(maLoaiToaThuoc, maLoaiToa, StringComparison.OrdinalIgnoreCase))
                    continue;
                string vietTatDanhMuc = el.TryGetProperty("viet_tat", out var pVt) && pVt.ValueKind == JsonValueKind.String
                    ? pVt.GetString() ?? "" : "";
                string vietTatTen = string.IsNullOrWhiteSpace(vietTatDanhMuc) ? TaoKyTuVietTat(ten) : LoaiBoDauTiengViet(vietTatDanhMuc).ToLowerInvariant();
                string vietTatHoatChat = !string.IsNullOrEmpty(hoatChat) ? TaoKyTuVietTat(hoatChat) : "";

                if (!string.IsNullOrEmpty(tuKhoa))
                {
                    string maLower = ma.ToLowerInvariant();
                    string tenLower = ten.ToLowerInvariant();
                    string tenKhongDau = LoaiBoDauTiengViet(tenLower);
                    string hcLower = (hoatChat ?? "").ToLowerInvariant();
                    string hcKhongDau = LoaiBoDauTiengViet(hcLower);

                    bool match = maLower.Contains(tuKhoa) ||
                                 tenLower.Contains(tuKhoa) ||
                                 tenKhongDau.Contains(tuKhoaKhongDau) ||
                                 hcLower.Contains(tuKhoa) ||
                                 hcKhongDau.Contains(tuKhoaKhongDau) ||
                                 vietTatTen.StartsWith(tuKhoaKhongDau) ||
                                 vietTatTen.Contains(tuKhoaKhongDau) ||
                                 vietTatHoatChat.StartsWith(tuKhoaKhongDau) ||
                                 vietTatHoatChat.Contains(tuKhoaKhongDau);
                    if (!match) continue;
                }

                allItems.Add(new
                {
                    id,
                    ma,
                    ten,
                    viet_tat = string.IsNullOrWhiteSpace(vietTatDanhMuc) ? vietTatTen : vietTatDanhMuc,
                    don_gia = donGia ?? giaBan,
                    ti_le = tiLe,
                    don_vi_tinh = donViTinh,
                    id_don_vi_tinh = idDonViTinh,
                    duong_dung = duongDung,
                    ham_luong = hamLuong,
                    hoat_chat = hoatChat,
                    id_tinh = idTinh,
                    gui_ngoai = guiNgoai,
                    ma_loai_toa_thuoc = maLoaiToa
                });
            }

            // Sắp xếp theo bảng chữ cái tiếng Anh / Tiếng Việt theo tên
            var sorted = allItems.OrderBy(x => (string)x.ten, StringComparer.CurrentCultureIgnoreCase);
            return sorted.Take(top);
        }

        private static string TaoKyTuVietTat(string str)
        {
            if (string.IsNullOrWhiteSpace(str)) return string.Empty;
            string strKhongDau = LoaiBoDauTiengViet(str);
            var words = strKhongDau.Split(new[] { ' ', '-', '_', '/', '.', ',' }, StringSplitOptions.RemoveEmptyEntries);
            var sb = new System.Text.StringBuilder();
            foreach (var w in words)
            {
                if (w.Length > 0)
                {
                    sb.Append(w[0]);
                }
            }
            return sb.ToString().ToLowerInvariant();
        }

        private static string LoaiBoDauTiengViet(string str)
        {
            if (string.IsNullOrEmpty(str)) return string.Empty;
            string normalized = str.Normalize(System.Text.NormalizationForm.FormD);
            var sb = new System.Text.StringBuilder();
            foreach (char c in normalized)
            {
                var unicodeCategory = System.Globalization.CharUnicodeInfo.GetUnicodeCategory(c);
                if (unicodeCategory != System.Globalization.UnicodeCategory.NonSpacingMark)
                {
                    sb.Append(c);
                }
            }
            return sb.ToString().Normalize(System.Text.NormalizationForm.FormC).Replace('đ', 'd').Replace('Đ', 'D');
        }

        #region Đồng bộ JSON danh mục từ DB (Đặc tả 6.2.2 & 6.2.3)

        /// <summary>
        /// Khi đăng nhập chỉ kiểm tra cache JSON bắt buộc; chỉ bootstrap full nếu đang thiếu file.
        /// Không dùng đăng nhập để refresh toàn bộ danh mục theo ngày.
        /// </summary>
        /// <summary>
        /// Login chỉ kiểm tra/đăng ký trạng thái cache; tuyệt đối không convert JSON đồng bộ.
        /// Nếu file bắt buộc thiếu thì đánh dấu CSKCB dirty để worker 00:00 xử lý.
        /// </summary>
        public async Task<bool> DangKyJsonCanKhoiTaoAsync(long idCskcb)
        {
            if (idCskcb <= 0) return false;

            await DamBaoCoDongVersionJsonAsync(idCskcb);

            string tenantDir = Path.Combine(_jsonRootPath, idCskcb.ToString());
            string[] requiredTenantFiles =
            {
                Path.Combine(tenantDir, "dm_dan_toc.json"),
                Path.Combine(tenantDir, "dm_tinh_thanh.json"),
                Path.Combine(tenantDir, "dm_phuong_xa.json"),
                Path.Combine(tenantDir, "dm_icd10.json"),
                Path.Combine(tenantDir, "dm_cong_kham.json"),
                Path.Combine(tenantDir, "dm_dich_vu.json"),
                Path.Combine(tenantDir, "dm_don_vi_tinh.json"),
                Path.Combine(tenantDir, "dm_thuoc.json"),
                Path.Combine(tenantDir, "dm_tri_so_sinh_hieu.json"),
                Path.Combine(tenantDir, "dm_nhan_vien.json"),
                Path.Combine(tenantDir, "dm_bac_si.json"),
                Path.Combine(tenantDir, "dm_ma_giam_gia.json"),
                Path.Combine(tenantDir, "dm_phac_do.json"),
                Path.Combine(tenantDir, "dm_quoc_tich.json"),
                Path.Combine(tenantDir, "dm_nghe_nghiep.json"),
                Path.Combine(tenantDir, "manifest.json")
            };

            bool commonMissing =
                !File.Exists(Path.Combine(_jsonRootPath, "dung_chung", "dm_ngan_hang.json")) ||
                !File.Exists(Path.Combine(_jsonRootPath, "dung_chung", "dm_gioi_tinh.json")) ||
                !File.Exists(Path.Combine(_jsonRootPath, "dung_chung", "dm_chuc_danh.json"));
            bool tenantMissing = requiredTenantFiles.Any(x => !File.Exists(x));

            if (!commonMissing && !tenantMissing)
                return false;

            using var scope = _scopeFactory?.CreateScope()
                ?? throw new InvalidOperationException("Chưa cấu hình IServiceScopeFactory để cập nhật trạng thái JSON.");
            var db = scope.ServiceProvider.GetRequiredService<QlpmDbContext>();

            await db.ThucThiStoAsync("dbo.STO_HT_JSON_DanhDauThieuFile", new { IDCSKCB = idCskcb, TatCa = commonMissing });

            return true;
        }

        /// <summary>
        /// Thực hiện đọc toàn bộ danh mục từ DB và convert ra các file JSON theo đặc tả
        /// </summary>
        public async Task<object> DongBoTatCaJsonTuDbAsync(long idCskcb)
        {
            var gate = SyncLocks.GetOrAdd(idCskcb, _ => new System.Threading.SemaphoreSlim(1, 1));
            await gate.WaitAsync();

            SqlConnection? tenantLock = null;
            try
            {
                // Semaphore là fast-path trong cùng process; SQL application lock bảo vệ
                // cùng CSKCB khi chạy nhiều instance/app server.
                tenantLock = await ThuLockCskcbAsync(idCskcb);
                await CapNhatTrangThaiJsonAsync(idCskcb, "DANG_DONG_BO");
                try
                {
                    return await DongBoTatCaJsonCoreAsync(idCskcb);
                }
                catch (Exception ex)
                {
                    await CapNhatLoiJsonAsync(idCskcb, ex.Message);
                    throw;
                }
            }
            finally
            {
                if (tenantLock != null)
                {
                    try
                    {
                        await NhaLockCskcbAsync(tenantLock, idCskcb);
                    }
                    finally
                    {
                        await tenantLock.DisposeAsync();
                    }
                }
                gate.Release();
            }
        }

        private async Task<object> DongBoTatCaJsonCoreAsync(long idCskcb)
        {
            if (_scopeFactory == null)
            {
                throw new InvalidOperationException("Chưa cấu hình IServiceScopeFactory để truy cập DbContext.");
            }

            using var scope = _scopeFactory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<QlpmDbContext>();

            await DamBaoCoDongVersionJsonAsync(db, idCskcb);
            long phienBanNguon = await LayVersionJsonAsync(db, idCskcb);

            var syncedFiles = new List<string>();
            string cskcbDir = Path.Combine(_jsonRootPath, idCskcb.ToString());
            string stagingRoot = Path.Combine(
                _jsonRootPath,
                ".staging",
                $"{idCskcb}_{Guid.NewGuid():N}");
            string stagingCskcbDir = Path.Combine(stagingRoot, idCskcb.ToString());
            string stagingDungChungDir = Path.Combine(stagingRoot, "dung_chung");

            Directory.CreateDirectory(stagingCskcbDir);
            Directory.CreateDirectory(stagingDungChungDir);

            try
            {
                // 1. dm_ngan_hang.json (dùng chung)
                var nganHangs = await db.DmNganHang
                    .AsNoTracking()
                    .OrderBy(x => x.TenNganHang)
                    .Select(x => new { id = x.Id, ma = x.MaNganHang, ten = x.TenNganHang })
                    .ToListAsync();
                await GhiFileJsonAtomicAsync(Path.Combine(stagingDungChungDir, "dm_ngan_hang.json"), nganHangs);
                syncedFiles.Add("dung_chung/dm_ngan_hang.json");

                // 2. dm_gioi_tinh.json (dùng chung, không phụ thuộc CSKCB)
                var gioiTinhs = await db.DmGioiTinh
                    .AsNoTracking()
                    .Where(x => x.Active)
                    .OrderBy(x => x.ThuTu)
                    .ThenBy(x => x.Id)
                    .Select(x => new { id = x.Id, ma = x.MaGioiTinh, ten = x.TenGioiTinh, thu_tu = x.ThuTu })
                    .ToListAsync();
                await GhiFileJsonAtomicAsync(Path.Combine(stagingDungChungDir, "dm_gioi_tinh.json"), gioiTinhs);
                syncedFiles.Add("dung_chung/dm_gioi_tinh.json");

                // 3. dm_chuc_danh.json (dùng chung)
                var chucDanhs = await db.DmChucDanh
                    .AsNoTracking()
                    .Where(x => x.Active)
                    .OrderBy(x => x.TenChucDanh)
                    .ThenBy(x => x.Id)
                    .Select(x => new { id = x.Id, ma = x.MaChucDanh, ten = x.TenChucDanh, viet_tat = x.VietTat })
                    .ToListAsync();
                await GhiFileJsonAtomicAsync(Path.Combine(stagingDungChungDir, "dm_chuc_danh.json"), chucDanhs);
                syncedFiles.Add("dung_chung/dm_chuc_danh.json");

            // 4. dm_dan_toc.json
            var danTocs = await db.DmDanToc
                .AsNoTracking()
                .Where(x => x.Idcskcb == idCskcb && x.Active)
                .OrderBy(x => x.MaDanToc)
                .Select(x => new { id = x.Id, ma = x.MaDanToc, ten = x.TenDanToc })
                .ToListAsync();
            await GhiFileJsonAtomicAsync(Path.Combine(stagingCskcbDir, "dm_dan_toc.json"), danTocs);
            syncedFiles.Add($"{idCskcb}/dm_dan_toc.json");

            // 4. dm_tinh_thanh.json
            var tinhThanhs = await db.DmTinhThanh
                .AsNoTracking()
                .Where(x => x.Idcskcb == idCskcb && x.Active)
                .OrderBy(x => x.TenTinh)
                .Select(x => new { id = x.Id, ma = x.MaTinh, ten = x.TenTinh })
                .ToListAsync();
            await GhiFileJsonAtomicAsync(Path.Combine(stagingCskcbDir, "dm_tinh_thanh.json"), tinhThanhs);
            syncedFiles.Add($"{idCskcb}/dm_tinh_thanh.json");

            // 5. dm_phuong_xa.json
            var phuongXas = await db.DmPhuongXa
                .AsNoTracking()
                .Where(x => x.Idcskcb == idCskcb && x.Active && !string.IsNullOrWhiteSpace(x.TenPhuongXa))
                .OrderBy(x => x.TenPhuongXa)
                .Select(x => new { id = x.Id, ma = x.MaPhuongXa, ten = x.TenPhuongXa, id_tinh = x.IdtinhThanh })
                .ToListAsync();
            await GhiFileJsonAtomicAsync(Path.Combine(stagingCskcbDir, "dm_phuong_xa.json"), phuongXas);
            syncedFiles.Add($"{idCskcb}/dm_phuong_xa.json");

            // 6. dm_icd10.json
            var icd10s = await db.DmIcd10
                .AsNoTracking()
                .Where(x => x.Idcskcb == idCskcb && x.Active)
                .OrderBy(x => x.MaBenh)
                .Select(x => new { id = x.Id, ma = x.MaBenh, ten = x.TenBenh })
                .ToListAsync();
            await GhiFileJsonAtomicAsync(Path.Combine(stagingCskcbDir, "dm_icd10.json"), icd10s);
            syncedFiles.Add($"{idCskcb}/dm_icd10.json");

            // 7. dm_cong_kham.json & dm_dich_vu.json
            var dichVus = await db.DmDichVu
                .AsNoTracking()
                .Where(x => x.Idcskcb == idCskcb && x.Active)
                .ToListAsync();

            var congKhams = dichVus
                .Where(x => x.LoaiDichVu == 1)
                .OrderBy(x => x.TenDichVu)
                .Select(x => new { id = x.Id, ma = x.MaDichVu, ten = x.TenDichVu, don_vi_tinh = x.DonViTinh, don_gia = x.DonGia })
                .ToList();
            await GhiFileJsonAtomicAsync(Path.Combine(stagingCskcbDir, "dm_cong_kham.json"), congKhams);
            syncedFiles.Add($"{idCskcb}/dm_cong_kham.json");

            var canLamSangs = dichVus
                .Where(x => x.LoaiDichVu != 1)
                .OrderBy(x => x.TenDichVu)
                .Select(x => new { id = x.Id, ma = x.MaDichVu, ten = x.TenDichVu, loai_dich_vu = (int)x.LoaiDichVu, don_vi_tinh = x.DonViTinh, don_gia = x.DonGia, gui_ngoai = x.ChoPhepGuiNgoai })
                .ToList();
            await GhiFileJsonAtomicAsync(Path.Combine(stagingCskcbDir, "dm_dich_vu.json"), canLamSangs);
            syncedFiles.Add($"{idCskcb}/dm_dich_vu.json");

            // 8. dm_don_vi_tinh.json - danh mục đơn vị tính dùng cho toa thuốc
            var donViTinhs = await db.DmDonViTinh
                .AsNoTracking()
                .Where(x => x.Idcskcb == idCskcb && x.Active)
                .OrderBy(x => x.TenDvt)
                .Select(x => new { id = x.Id, ma = x.MaDvt, ten = x.TenDvt })
                .ToListAsync();
            await GhiFileJsonAtomicAsync(Path.Combine(stagingCskcbDir, "dm_don_vi_tinh.json"), donViTinhs);
            syncedFiles.Add($"{idCskcb}/dm_don_vi_tinh.json");

            // 9. dm_thuoc.json
            var thuocs = await db.DmThuoc
                .AsNoTracking()
                .Where(x => x.Idcskcb == idCskcb && x.Active)
                .OrderBy(x => x.TenThuoc)
                .Select(x => new { id = x.Id, ma = x.MaThuoc, ten = x.TenThuoc, id_don_vi_tinh = x.IddonViTinh, don_vi_tinh = x.IddonViTinhNavigation != null ? x.IddonViTinhNavigation.TenDvt : x.DonViTinh, duong_dung = x.DuongDung, ham_luong = x.HamLuong, hoat_chat = x.HoatChat, gia_ban = x.GiaBan, ma_loai_toa_thuoc = x.DmNhomHang != null && x.DmNhomHang.Active ? x.DmNhomHang.MaLoaiToaThuoc : null })
                .ToListAsync();
            await GhiFileJsonAtomicAsync(Path.Combine(stagingCskcbDir, "dm_thuoc.json"), thuocs);
            syncedFiles.Add($"{idCskcb}/dm_thuoc.json");

            // 9. dm_tri_so_sinh_hieu.json
            var triSos = await db.DmTriSoSinhHieu
                .AsNoTracking()
                .Where(x => x.Idcskcb == idCskcb && x.Active)
                .OrderBy(x => x.ThuTu ?? 999)
                .Select(x => new { id = x.Id, ma = x.MaTriSo, ten = x.TenTriSo, don_vi_tinh = x.DonViTinh, thu_tu = x.ThuTu })
                .ToListAsync();
            await GhiFileJsonAtomicAsync(Path.Combine(stagingCskcbDir, "dm_tri_so_sinh_hieu.json"), triSos);
            syncedFiles.Add($"{idCskcb}/dm_tri_so_sinh_hieu.json");

            // 11. dm_nhan_vien.json & dm_bac_si.json
            var nhanViens = await (
                from map in db.DmNhanVienCskcb.AsNoTracking()
                join nv in db.DmNhanVien.AsNoTracking() on map.IdnhanVien equals nv.Id
                join cd0 in db.DmChucDanh.AsNoTracking() on nv.IdchucDanh equals (long?)cd0.Id into cdJoin
                from cd in cdJoin.DefaultIfEmpty()
                where map.Idcskcb == idCskcb && map.Active && nv.Active
                select new
                {
                    nv.Id,
                    nv.MaNhanVien,
                    nv.HoTen,
                    nv.LaBacSi,
                    nv.DienThoai,
                    IDChucDanh = nv.IdchucDanh,
                    TenChucDanh = cd != null ? cd.TenChucDanh : null,
                    VietTatChucDanh = cd != null ? cd.VietTat : null
                }
            ).ToListAsync();

            var nvList = nhanViens
                .OrderBy(x => x.HoTen)
                .Select(x => new { id = x.Id, ma = x.MaNhanVien, ten = x.HoTen, la_bac_si = x.LaBacSi, id_chuc_danh = x.IDChucDanh, chuc_danh = x.TenChucDanh, viet_tat_chuc_danh = x.VietTatChucDanh, sdt = x.DienThoai })
                .ToList();
            await GhiFileJsonAtomicAsync(Path.Combine(stagingCskcbDir, "dm_nhan_vien.json"), nvList);
            syncedFiles.Add($"{idCskcb}/dm_nhan_vien.json");

            var bacSis = nhanViens
                .Where(x => x.LaBacSi)
                .OrderBy(x => x.HoTen)
                .Select(x => new { id = x.Id, ma = x.MaNhanVien, ten = x.HoTen, id_chuc_danh = x.IDChucDanh, chuc_danh = x.TenChucDanh, viet_tat_chuc_danh = x.VietTatChucDanh })
                .ToList();
            await GhiFileJsonAtomicAsync(Path.Combine(stagingCskcbDir, "dm_bac_si.json"), bacSis);
            syncedFiles.Add($"{idCskcb}/dm_bac_si.json");

            // 11. dm_phac_do.json
            var phacDos = await db.DmPhacDo
                .AsNoTracking()
                .Where(x => x.Idcskcb == idCskcb && x.Active)
                .OrderBy(x => x.TenPhacDo)
                .Select(x => new { id = x.Id, ma = x.MaPhacDo, ten = x.TenPhacDo })
                .ToListAsync();
            await GhiFileJsonAtomicAsync(Path.Combine(stagingCskcbDir, "dm_phac_do.json"), phacDos);
            syncedFiles.Add($"{idCskcb}/dm_phac_do.json");

            // 12. dm_quoc_tich.json / dm_nghe_nghiep.json - canonical table, không còn giữ file mồ côi.
            var quocTichs = await LayDanhMucDonGianAsync(
                db,
                "quoc_tich",
                idCskcb);
            await GhiFileJsonAtomicAsync(Path.Combine(stagingCskcbDir, "dm_quoc_tich.json"), quocTichs);
            syncedFiles.Add($"{idCskcb}/dm_quoc_tich.json");

            var ngheNghieps = await LayDanhMucDonGianAsync(
                db,
                "nghe_nghiep",
                idCskcb);
            await GhiFileJsonAtomicAsync(Path.Combine(stagingCskcbDir, "dm_nghe_nghiep.json"), ngheNghieps);
            syncedFiles.Add($"{idCskcb}/dm_nghe_nghiep.json");

            // Mã giảm giá từng CSKCB: DB là nguồn, JSON phục vụ dropdown Thu ngân.
            var maGiamGias = await db.LayDanhSachStoAsync("dbo.STO_QL_ThuNgan_MaGiamGia_DanhSach", new
            {
                IDCSKCB = idCskcb,
                ChiHoatDong = true
            });
            var giamGias = maGiamGias.Select(row =>
            {
                var data = (IDictionary<string, object?>)row;
                return new
                {
                    id = Convert.ToInt64(data["ID"]),
                    ma = Convert.ToString(data["MaGiamGia"])?.Trim() ?? string.Empty,
                    ten = Convert.ToString(data["TenGiamGia"]) ?? string.Empty,
                    ti_le = Convert.ToDecimal(data["TiLe"])
                };
            }).ToArray();
            await GhiFileJsonAtomicAsync(Path.Combine(stagingCskcbDir, "dm_ma_giam_gia.json"), giamGias);
            syncedFiles.Add($"{idCskcb}/dm_ma_giam_gia.json");

            long phienBanSau = await LayVersionJsonAsync(db, idCskcb);
            bool daPhatHanh = phienBanSau == phienBanNguon;

            // 13. Ghi manifest.json
            var manifest = new
            {
                id_cskcb = idCskcb,
                phien_ban_nguon = phienBanNguon,
                phien_ban_hien_tai = phienBanSau,
                phien_ban_da_phat_hanh = daPhatHanh ? phienBanNguon : Math.Min(phienBanNguon, phienBanSau),
                ngay_dong_bo = DateTime.Now.ToString("yyyy-MM-dd"),
                thoi_gian_dong_bo = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"),
                danh_sach_file = syncedFiles,
                trang_thai = daPhatHanh ? "THANH_CONG" : "CO_THAY_DOI_TRONG_KHI_DONG_BO"
            };

            // Manifest tenant dùng để theo dõi đúng từng CSKCB; root manifest giữ tương thích endpoint cũ.
            await GhiFileJsonAtomicAsync(Path.Combine(stagingCskcbDir, "manifest.json"), manifest);
            await CommonJsonLock.WaitAsync();
            try
            {
                await GhiFileJsonAtomicAsync(Path.Combine(stagingRoot, "manifest.json"), manifest);
            }
            finally
            {
                CommonJsonLock.Release();
            }

            if (!daPhatHanh)
            {
                // Source đã đổi trong lúc convert: không publish staging, giữ nguyên cache hiện hành.
                await CapNhatDirtyJsonAsync(db, idCskcb);
                return manifest;
            }

            await PublishStagedJsonAsync(stagingRoot, cskcbDir, syncedFiles);

            // Chỉ publish version khi source VersionNo vẫn đúng version đã convert.
            await CapNhatDaPhatHanhJsonAsync(db, idCskcb, phienBanNguon);

            // Không Cache.Clear(): DocJsonAsync tự phát hiện file đổi bằng LastWriteTimeUtc.
            return manifest;
            }
            finally
            {
                XoaThuMucStaging(stagingRoot);
            }
        }

        public async Task<JsonDocument?> LayThongTinManifestAsync(long? idCskcb = null)
        {
            long selectedCskcb = idCskcb.GetValueOrDefault();
            string manifestPath = selectedCskcb > 0
                ? Path.Combine(_jsonRootPath, selectedCskcb.ToString(), "manifest.json")
                : Path.Combine(_jsonRootPath, "manifest.json");

            if (!File.Exists(manifestPath)) return null;
            string content = await File.ReadAllTextAsync(manifestPath);
            return JsonDocument.Parse(content);
        }

        private static string[] LayDuongDanJsonBatBuoc(string root, long idCskcb)
        {
            string tenantDir = Path.Combine(root, idCskcb.ToString());
            return new[]
            {
                Path.Combine(root, "dung_chung", "dm_ngan_hang.json"),
                Path.Combine(root, "dung_chung", "dm_gioi_tinh.json"),
                Path.Combine(root, "dung_chung", "dm_chuc_danh.json"),
                Path.Combine(tenantDir, "dm_dan_toc.json"),
                Path.Combine(tenantDir, "dm_tinh_thanh.json"),
                Path.Combine(tenantDir, "dm_phuong_xa.json"),
                Path.Combine(tenantDir, "dm_icd10.json"),
                Path.Combine(tenantDir, "dm_cong_kham.json"),
                Path.Combine(tenantDir, "dm_dich_vu.json"),
                Path.Combine(tenantDir, "dm_don_vi_tinh.json"),
                Path.Combine(tenantDir, "dm_thuoc.json"),
                Path.Combine(tenantDir, "dm_tri_so_sinh_hieu.json"),
                Path.Combine(tenantDir, "dm_nhan_vien.json"),
                Path.Combine(tenantDir, "dm_bac_si.json"),
                Path.Combine(tenantDir, "dm_ma_giam_gia.json"),
                Path.Combine(tenantDir, "dm_phac_do.json"),
                Path.Combine(tenantDir, "dm_quoc_tich.json"),
                Path.Combine(tenantDir, "dm_nghe_nghiep.json"),
                Path.Combine(tenantDir, "manifest.json")
            };
        }

        private async Task DamBaoCoDongVersionJsonAsync(long idCskcb)
        {
            if (_scopeFactory == null)
                throw new InvalidOperationException("Chưa cấu hình IServiceScopeFactory để truy cập DbContext.");

            using var scope = _scopeFactory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<QlpmDbContext>();
            await DamBaoCoDongVersionJsonAsync(db, idCskcb);
        }

        private static async Task DamBaoCoDongVersionJsonAsync(QlpmDbContext db, long idCskcb)
        {
            await db.ThucThiStoAsync("dbo.STO_HT_JSON_DamBaoDong", new { IDCSKCB = idCskcb });
        }

        public async Task DanhDauThayDoiDanhMucAsync(long idCskcb)
        {
            if (idCskcb <= 0) return;
            if (_scopeFactory == null)
                throw new InvalidOperationException("Chưa cấu hình IServiceScopeFactory để truy cập DbContext.");

            using var scope = _scopeFactory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<QlpmDbContext>();
            await DamBaoCoDongVersionJsonAsync(db, idCskcb);
            await db.ThucThiStoAsync("dbo.STO_HT_JSON_TangVersion", new { IDCSKCB = idCskcb });
        }

        public async Task<List<long>> LayDanhSachCskcbCanDongBoJsonAsync()
        {
            if (_scopeFactory == null) throw new InvalidOperationException("Chưa cấu hình IServiceScopeFactory để truy cập DbContext.");
            using var scope = _scopeFactory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<QlpmDbContext>();
            var rows = await db.LayDanhSachStoAsync("dbo.STO_HT_JSON_DanhSachCanDongBo");
            var ids = new List<long>(rows.Count);
            foreach (var row in rows)
                ids.Add(Convert.ToInt64(((IDictionary<string, object?>)row)["IDCSKCB"]));
            return ids;
        }

        public async Task<object?> LayTrangThaiJsonAsync(long idCskcb)
        {
            if (_scopeFactory == null) throw new InvalidOperationException("Chưa cấu hình IServiceScopeFactory để truy cập DbContext.");
            using var scope = _scopeFactory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<QlpmDbContext>();
            var row = await db.LayMotDongStoAsync("dbo.STO_HT_JSON_TrangThai", new { IDCSKCB = idCskcb });
            if (row is not IDictionary<string, object?> d) return null;
            return new JsonVersionStatus
            {
                IDCSKCB = Convert.ToInt64(d["IDCSKCB"]),
                VersionNo = Convert.ToInt64(d["VersionNo"]),
                PublishedVersionNo = Convert.ToInt64(d["PublishedVersionNo"]),
                TrangThai = Convert.ToString(d["TrangThai"]) ?? string.Empty,
                LastChangedAt = Convert.ToDateTime(d["LastChangedAt"]),
                LastGeneratedAt = d["LastGeneratedAt"] == null ? null : Convert.ToDateTime(d["LastGeneratedAt"]),
                LastError = Convert.ToString(d["LastError"]),
                UpdatedAt = Convert.ToDateTime(d["UpdatedAt"])
            };
        }

        private sealed class JsonVersionStatus
        {
            public long IDCSKCB { get; set; }
            public long VersionNo { get; set; }
            public long PublishedVersionNo { get; set; }
            public string TrangThai { get; set; } = string.Empty;
            public DateTime LastChangedAt { get; set; }
            public DateTime? LastGeneratedAt { get; set; }
            public string? LastError { get; set; }
            public DateTime UpdatedAt { get; set; }
        }

        private static async Task<long> LayVersionJsonAsync(QlpmDbContext db, long idCskcb)
        {
            var row = await db.LayMotDongStoAsync("dbo.STO_HT_JSON_LayVersion", new { IDCSKCB = idCskcb });
            return row is IDictionary<string, object?> d ? Convert.ToInt64(d["VersionNo"]) : 0;
        }

        private async Task<SqlConnection> ThuLockCskcbAsync(long idCskcb)
        {
            var connectionString = _configuration?.GetConnectionString("QLPM") ?? _configuration?["ConnectionStrings:QLPM"];
            if (string.IsNullOrWhiteSpace(connectionString)) throw new InvalidOperationException("Chưa cấu hình ConnectionStrings:QLPM.");
            var conn = new SqlConnection(connectionString);
            await conn.OpenAsync();
            try
            {
                await using var cmd = conn.CreateCommand();
                cmd.CommandType = System.Data.CommandType.StoredProcedure;
                cmd.CommandText = "dbo.STO_HT_JSON_ThuLock";
                cmd.Parameters.Add(new SqlParameter("@IDCSKCB", idCskcb));
                var result = await cmd.ExecuteScalarAsync();
                if (result == null || Convert.ToInt32(result) < 0)
                    throw new InvalidOperationException($"CSKCB {idCskcb} đang được đồng bộ JSON ở instance khác.");
                return conn;
            }
            catch { await conn.DisposeAsync(); throw; }
        }

        private static async Task NhaLockCskcbAsync(SqlConnection conn, long idCskcb)
        {
            await using var cmd = conn.CreateCommand();
            cmd.CommandType = System.Data.CommandType.StoredProcedure;
            cmd.CommandText = "dbo.STO_HT_JSON_NhaLock";
            cmd.Parameters.Add(new SqlParameter("@IDCSKCB", idCskcb));
            await cmd.ExecuteNonQueryAsync();
        }

        private async Task CapNhatTrangThaiJsonAsync(long idCskcb, string trangThai)
        {
            if (_scopeFactory == null) return;
            using var scope = _scopeFactory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<QlpmDbContext>();
            await db.ThucThiStoAsync("dbo.STO_HT_JSON_CapNhatTrangThai",
                new { IDCSKCB = idCskcb, TrangThai = trangThai });
        }

        private async Task CapNhatLoiJsonAsync(long idCskcb, string error)
        {
            if (_scopeFactory == null) return;
            using var scope = _scopeFactory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<QlpmDbContext>();
            await db.ThucThiStoAsync("dbo.STO_HT_JSON_CapNhatLoi", new
            {
                IDCSKCB = idCskcb,
                Loi = error.Length > 2000 ? error[..2000] : error
            });
        }

        private static async Task CapNhatDaPhatHanhJsonAsync(QlpmDbContext db, long idCskcb, long phienBan)
        {
            await db.ThucThiStoAsync("dbo.STO_HT_JSON_PhatHanh",
                new { IDCSKCB = idCskcb, VersionNo = phienBan });
        }

        private static async Task CapNhatDirtyJsonAsync(QlpmDbContext db, long idCskcb)
        {
            await db.ThucThiStoAsync("dbo.STO_HT_JSON_DanhDauDirty", new { IDCSKCB = idCskcb });
        }

        private static async Task<List<object>> LayDanhMucDonGianAsync(
            QlpmDbContext db, string loai, long idCskcb)
        {
            var rows = await db.LayDanhSachStoAsync("dbo.STO_HT_JSON_DanhMucDonGian",
                new { IDCSKCB = idCskcb, Loai = loai });
            var result = new List<object>(rows.Count);
            foreach (var row in rows)
            {
                var d = (IDictionary<string, object?>)row;
                result.Add(new
                {
                    id = Convert.ToInt64(d["ID"]),
                    ma = Convert.ToString(d["Ma"]) ?? string.Empty,
                    ten = Convert.ToString(d["Ten"]) ?? string.Empty
                });
            }
            return result;
        }

        private static async Task PublishStagedJsonAsync(
            string stagingRoot,
            string cskcbDir,
            IReadOnlyCollection<string> syncedFiles)
        {
            var jsonRoot = Directory.GetParent(cskcbDir)?.FullName
                ?? throw new InvalidOperationException("Không xác định được JSON root.");

            // Tenant files: caller đang giữ lock theo CSKCB.
            foreach (var relative in syncedFiles.Where(x => !x.StartsWith("dung_chung/", StringComparison.OrdinalIgnoreCase)))
            {
                var source = Path.Combine(stagingRoot, relative.Replace('/', Path.DirectorySeparatorChar));
                var target = Path.Combine(jsonRoot, relative.Replace('/', Path.DirectorySeparatorChar));
                await PublishStagedFileAtomicAsync(source, target);
            }

            // Shared JSON + root manifest dùng chung lock.
            await CommonJsonLock.WaitAsync();
            try
            {
                foreach (var relative in syncedFiles.Where(x => x.StartsWith("dung_chung/", StringComparison.OrdinalIgnoreCase)))
                {
                    var source = Path.Combine(stagingRoot, relative.Replace('/', Path.DirectorySeparatorChar));
                    var target = Path.Combine(jsonRoot, relative.Replace('/', Path.DirectorySeparatorChar));
                    await PublishStagedFileAtomicAsync(source, target);
                }

                var rootManifest = Path.Combine(stagingRoot, "manifest.json");
                await PublishStagedFileAtomicAsync(rootManifest, Path.Combine(jsonRoot, "manifest.json"));
            }
            finally
            {
                CommonJsonLock.Release();
            }

            // Tenant manifest publish cuối cùng trong lock của CSKCB.
            var tenantManifest = Path.Combine(
                stagingRoot,
                Path.GetFileName(cskcbDir),
                "manifest.json");
            await PublishStagedFileAtomicAsync(
                tenantManifest,
                Path.Combine(cskcbDir, "manifest.json"));
        }

        private static async Task PublishStagedFileAtomicAsync(string sourcePath, string targetPath)
        {
            if (!File.Exists(sourcePath))
                throw new FileNotFoundException("Thiếu file staging JSON.", sourcePath);

            var targetDir = Path.GetDirectoryName(targetPath);
            if (!string.IsNullOrWhiteSpace(targetDir))
                Directory.CreateDirectory(targetDir);

            var stagedBytes = await File.ReadAllBytesAsync(sourcePath);
            if (File.Exists(targetPath))
            {
                var currentBytes = await File.ReadAllBytesAsync(targetPath);
                if (stagedBytes.AsSpan().SequenceEqual(currentBytes))
                    return;
            }

            var tmpPath = targetPath + ".tmp";
            await File.WriteAllBytesAsync(tmpPath, stagedBytes);
            File.Move(tmpPath, targetPath, overwrite: true);
        }

        private static void XoaThuMucStaging(string stagingRoot)
        {
            try
            {
                if (Directory.Exists(stagingRoot))
                    Directory.Delete(stagingRoot, recursive: true);
            }
            catch
            {
                // Cleanup lỗi không được đụng vào published directories và không che lỗi chính.
            }
        }

        private static async Task<bool> GhiFileJsonAtomicAsync(string path, object data)
        {
            var dir = Path.GetDirectoryName(path);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
            {
                Directory.CreateDirectory(dir);
            }
            string tmpPath = path + ".tmp";
            var options = new JsonSerializerOptions
            {
                WriteIndented = true,
                Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping
            };
            string json = JsonSerializer.Serialize(data, options);

            if (File.Exists(path))
            {
                string current = await File.ReadAllTextAsync(path);
                if (string.Equals(current, json, StringComparison.Ordinal))
                    return false;
            }

            await File.WriteAllTextAsync(tmpPath, json, System.Text.Encoding.UTF8);
            File.Move(tmpPath, path, overwrite: true);
            return true;
        }

        #endregion
    }
}
