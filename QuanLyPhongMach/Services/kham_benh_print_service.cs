using System.Globalization;
using System.Security;
using System.Text;
using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using WkHtmlToPdfDotNet;
using WkHtmlToPdfDotNet.Contracts;
using QuanLyPhongMach.Data;
using QuanLyPhongMach.Models.Printing.KhamBenh;
using QuanLyPhongMach.Models.Requests.KhamBenh;
using QuanLyPhongMach.Services.Printing;

namespace QuanLyPhongMach.Services;

public sealed class KhamBenhPrintService : IKhamBenhPrintService
{
    private const string NguonBanNhap = "ban_nhap";
    private const string NguonDaLuu = "da_luu";
    private readonly QlpmDbContext _db;
    private readonly IRazorViewRenderer _renderer;
    private readonly IConverter _converter;
    private readonly IWebHostEnvironment _environment;
    private readonly QlpmDocumentStorage _storage;

    public KhamBenhPrintService(
        QlpmDbContext db,
        IRazorViewRenderer renderer,
        IConverter converter,
        IWebHostEnvironment environment,
        QlpmDocumentStorage storage)
    {
        _db = db;
        _renderer = renderer;
        _converter = converter;
        _environment = environment;
        _storage = storage;
    }

    public async Task<KhamBenhPdfResult> InChiDinhAsync(KhamBenhInRequest request, long idCskcb, long idNhanVien)
    {
        var source = ChuanHoaNguon(request);
        var model = await TaoThongTinChungAsync(request, idCskcb, idNhanVien, source);
        var diagnoses = await LayChanDoanAsync(request, idCskcb, source);
        if (diagnoses.Count == 0 && !request.ky_so)
            throw new KhamBenhPrintValidationException("Phải có ít nhất một chẩn đoán trước khi in phiếu chỉ định.");
        model.ChanDoan = string.Join("; ", diagnoses);

        var rows = source == NguonBanNhap
            ? await LayChiDinhBanNhapAsync(request, idCskcb)
            : await LayChiDinhDaLuuAsync(request.id_vao_vien, idCskcb);
        if (request.gui_ngoai_chi_dinh.HasValue)
            rows = rows.Where(x => x.GuiNgoai == request.gui_ngoai_chi_dinh.Value).ToList();
        if (rows.Count == 0)
            throw new KhamBenhPrintValidationException(request.gui_ngoai_chi_dinh.HasValue
                ? "Không có chỉ định " + (request.gui_ngoai_chi_dinh.Value ? "gửi ngoài" : "nội bộ") + " đã lưu để ký."
                : "Chưa có chỉ định để in.");

        if (request.gop_chi_dinh)
        {
            var list = rows.OrderBy(x => x.NgayLap).ToList();
            model.ChiDinhPages.Add(new KhamBenhPrintChiDinhPage
            {
                // Phiếu gộp dùng một bảng chung. Dòng gửi ngoài đã mang đúng snapshot đơn giá/thành tiền.
                GuiNgoai = false,
                NgayLap = source == NguonBanNhap ? DateTime.Now : list.Min(x => x.NgayLap),
                DichVu = list.Select(x => x.Dong).ToList(),
                TongTien = list.Sum(x => x.Dong.ThanhTien)
            });
        }
        else
        {
            foreach (var group in rows.GroupBy(x => x.GuiNgoai).OrderBy(x => x.Key))
            {
                var list = group.ToList();
                model.ChiDinhPages.Add(new KhamBenhPrintChiDinhPage
                {
                    GuiNgoai = group.Key,
                    NgayLap = source == NguonBanNhap ? DateTime.Now : list.Min(x => x.NgayLap),
                    DichVu = list.Select(x => x.Dong).ToList(),
                    TongTien = group.Key ? 0 : list.Sum(x => x.Dong.ThanhTien)
                });
            }
        }

        // In tách: nội bộ/gửi ngoài là các document độc lập. In gộp: chỉ có một document.
        var chiDinhPages = model.ChiDinhPages.ToList();
        var htmlDocuments = new List<string>(chiDinhPages.Count);
        foreach (var page in chiDinhPages)
        {
            model.ChiDinhPages = new List<KhamBenhPrintChiDinhPage> { page };
            htmlDocuments.Add(await _renderer.RenderAsync("~/Views/kham_benh/In/PhieuChiDinh.cshtml", model));
        }
        model.ChiDinhPages = chiDinhPages;

        return TaoPdf(htmlDocuments, tep_tin_dich_vu.TaoTenTaiXuong("pcd", model.MaVaoVien, "pdf"), resetPageNumberPerDocument: true);
    }

    public async Task<KhamBenhPdfResult> InToaThuocAsync(KhamBenhInRequest request, long idCskcb, long idNhanVien)
    {
        var source = ChuanHoaNguon(request);
        var model = await TaoThongTinChungAsync(request, idCskcb, idNhanVien, source, choToaThuoc: true);
        var diagnoses = await LayChanDoanAsync(request, idCskcb, source);
        if (diagnoses.Count == 0 && !request.ky_so)
            throw new KhamBenhPrintValidationException("Phải có ít nhất một chẩn đoán trước khi in toa thuốc.");
        model.ChanDoan = string.Join("; ", diagnoses);

        model.ToaPages = source == NguonBanNhap
            ? await LayToaBanNhapAsync(request, idCskcb, model.BacSi)
            : await LayToaDaLuuAsync(request.id_vao_vien, idCskcb, model.BacSi, request.id_toa_thuoc);
        if (model.ToaPages.Count == 0)
            throw new KhamBenhPrintValidationException("Chưa có thuốc để in toa.");
        if (request.id_toa_thuoc.HasValue)
        {
            var maToaQuocGia = await _db.QlToaThuoc.AsNoTracking()
                .Where(x => x.Idcskcb == idCskcb && x.Id == request.id_toa_thuoc.Value && x.IdvaoVien == request.id_vao_vien)
                .Select(x => x.MaToaQuocGia)
                .SingleOrDefaultAsync();
            if (string.IsNullOrWhiteSpace(maToaQuocGia))
                throw new KhamBenhPrintValidationException("Toa thuốc chưa có mã liên thông quốc gia.");
            foreach (var page in model.ToaPages)
                page.MaToaThuoc = maToaQuocGia;
        }
        else
        {
            var storedHeads = source == NguonDaLuu
                ? await _db.QlToaThuoc.AsNoTracking().Where(x => x.Idcskcb == idCskcb && x.IdvaoVien == request.id_vao_vien && x.ChiTiet.Any(d => d.Active))
                    .Select(x => new { Day = x.NgayKe.Date, Type = x.MaLoaiToaThuoc, Code = x.MaToaQuocGia }).ToListAsync()
                : null;
            foreach (var page in model.ToaPages)
            {
                var matches = storedHeads?.Where(x => x.Day == page.NgayKe.Date && x.Type == page.MaLoaiToaThuoc).ToList();
                page.MaToaThuoc = matches?.Count == 1 && !string.IsNullOrWhiteSpace(matches[0].Code)
                    ? matches[0].Code! : TaoMaToaThuoc(model.MaCskcb, model.MaVaoVien, page.MaLoaiToaThuoc);
            }
        }

        var html = await _renderer.RenderAsync("~/Views/kham_benh/In/ToaThuoc.cshtml", model);
        return TaoPdf(html, tep_tin_dich_vu.TaoTenTaiXuong("toa", model.MaVaoVien, "pdf"));
    }

    private async Task<KhamBenhPrintDocument> TaoThongTinChungAsync(
        KhamBenhInRequest request,
        long idCskcb,
        long idNhanVien,
        string source, bool choToaThuoc = false)
    {
        if (idCskcb <= 0)
            throw new KhamBenhPrintValidationException("Chọn cơ sở KCB trước khi in.");
        if (request.id_vao_vien <= 0)
            throw new KhamBenhPrintValidationException("Thiếu lượt khám cần in.");

        var visit = await _db.QlVaoVien.AsNoTracking()
            .Where(x => x.Id == request.id_vao_vien && x.Idcskcb == idCskcb && x.Active)
            .Select(x => new VisitData
            {
                Id = x.Id,
                MaVaoVien = x.MaVaoVien,
                IdBacSiKham = x.IdbacSiKham,
                TrieuChung = x.TrieuChung,
                NgayTaiKham = x.NgayTaiKham,
                DanDo = x.DanDo,
                MaBn = x.QlBenhNhan.MaBn,
                HoTen = x.QlBenhNhan.HoTen,
                NgaySinh = x.QlBenhNhan.NgaySinh,
                IdGioiTinh = x.QlBenhNhan.IdgioiTinh,
                GioiTinh = x.QlBenhNhan.DmGioiTinh.TenGioiTinh,
                SoCccd = x.QlBenhNhan.SoCccd,
                DiaChi = x.QlBenhNhan.DiaChi,
                DienThoai = x.QlBenhNhan.DienThoai,
                GiamHoMoiQuanHe = x.QlBenhNhan.GiamHoMoiQuanHe,
                GiamHoHoTen = x.QlBenhNhan.GiamHoHoTen,
                GiamHoDienThoai = x.QlBenhNhan.GiamHoDienThoai,
                GiamHoSoCccd = x.QlBenhNhan.GiamHoSoCccd,
                MaCskcb = x.IdcskcbNavigation.MaCskcb,
                TenCskcb = x.IdcskcbNavigation.TenCskcb,
                DiaChiCskcb = x.IdcskcbNavigation.DiaChi,
                DienThoaiCskcb = x.IdcskcbNavigation.Sdt,
                EmailCskcb = x.IdcskcbNavigation.Email,
                UrlLogo = x.IdcskcbNavigation.UrlLogo
            })
            .SingleOrDefaultAsync();
        if (visit == null)
            throw new KhamBenhPrintValidationException("Không tìm thấy lượt khám trong cơ sở đang làm việc.");

        var doctorId = visit.IdBacSiKham;
        if (source != NguonBanNhap && request.id_toa_thuoc.HasValue)
        {
            doctorId = await _db.QlToaThuoc.AsNoTracking()
                .Where(x => x.Idcskcb == idCskcb && x.IdvaoVien == visit.Id && x.Id == request.id_toa_thuoc.Value)
                .Select(x => (long?)x.IdbacSiKe).SingleOrDefaultAsync();
            if (!doctorId.HasValue)
                throw new KhamBenhPrintValidationException("Không tìm thấy bác sĩ kê toa thuốc đã chọn.");
        }
        else if (choToaThuoc && source == NguonDaLuu)
        {
            var prescribers = await _db.QlToaThuoc.AsNoTracking()
                .Where(x => x.Idcskcb == idCskcb && x.IdvaoVien == visit.Id && x.ChiTiet.Any(d => d.Active))
                .Select(x => x.IdbacSiKe).Distinct().Take(2).ToListAsync();
            if (prescribers.Count == 1) doctorId = prescribers[0];
        }
        if (source == NguonBanNhap && !doctorId.HasValue && idNhanVien > 0)
            doctorId = idNhanVien;
        var doctorInfo = doctorId.HasValue
            ? await (
                from nv in _db.DmNhanVien.AsNoTracking()
                join map in _db.DmNhanVienCskcb.AsNoTracking()
                    on nv.Id equals map.IdnhanVien
                join cd0 in _db.DmChucDanh.AsNoTracking()
                    on nv.IdchucDanh equals (long?)cd0.Id into cdJoin
                from cd in cdJoin.DefaultIfEmpty()
                where nv.Id == doctorId.Value
                      && nv.Active
                      && map.Idcskcb == idCskcb
                      && map.Active
                select new
                {
                    nv.HoTen,
                    TenChucDanh = cd != null ? cd.TenChucDanh : null,
                    VietTat = cd != null ? cd.VietTat : null
                }
            ).SingleOrDefaultAsync()
            : null;
        var doctorPrefix = doctorInfo == null
            ? null
            : !string.IsNullOrWhiteSpace(doctorInfo.VietTat)
                ? doctorInfo.VietTat
                : doctorInfo.TenChucDanh;
        var doctorName = doctorInfo == null
            ? null
            : string.IsNullOrWhiteSpace(doctorPrefix)
                ? doctorInfo.HoTen
                : $"{doctorPrefix!.Trim()} {doctorInfo.HoTen}".Trim();

        var genderName = visit.GioiTinh;
        if (source == NguonBanNhap && request.id_gioi_tinh.HasValue)
        {
            genderName = await _db.DmGioiTinh.AsNoTracking()
                .Where(x => x.Id == request.id_gioi_tinh.Value && x.Active)
                .Select(x => x.TenGioiTinh)
                .SingleOrDefaultAsync() ?? genderName;
        }

        var model = new KhamBenhPrintDocument
        {
            MaCskcb = TextOrEmpty(visit.MaCskcb),
            TenCskcb = TextOrEmpty(visit.TenCskcb),
            DiaChiCskcb = TextOrEmpty(visit.DiaChiCskcb),
            DienThoaiCskcb = TextOrEmpty(visit.DienThoaiCskcb),
            EmailCskcb = TextOrEmpty(visit.EmailCskcb),
            LogoDataUri = await _storage.LoadLogoDataUriAsync(visit.UrlLogo, CancellationToken.None),
            MaBn = TextOrEmpty(visit.MaBn),
            MaVaoVien = TextOrEmpty(visit.MaVaoVien),
            BarcodeSvg = TaoCode128Svg(visit.MaVaoVien),
            HoTen = TextOrEmpty(source == NguonBanNhap ? request.ho_ten ?? visit.HoTen : visit.HoTen),
            NgaySinh = source == NguonBanNhap ? request.ngay_sinh ?? visit.NgaySinh : visit.NgaySinh,
            GioiTinh = TextOrEmpty(genderName),
            SoCccd = TextOrEmpty(visit.SoCccd),
            DiaChi = TextOrEmpty(visit.DiaChi),
            DienThoai = TextOrEmpty(visit.DienThoai),
            GiamHoMoiQuanHe = TextOrEmpty(visit.GiamHoMoiQuanHe),
            GiamHoHoTen = TextOrEmpty(visit.GiamHoHoTen),
            GiamHoDienThoai = TextOrEmpty(visit.GiamHoDienThoai),
            GiamHoSoCccd = TextOrEmpty(visit.GiamHoSoCccd),
            TrieuChung = TextOrEmpty(source == NguonBanNhap ? request.trieu_chung : visit.TrieuChung),
            BacSi = TextOrEmpty(doctorName),
            LoiDan = TextOrEmpty(source == NguonBanNhap ? request.dan_do : visit.DanDo),
            NgayTaiKham = source == NguonBanNhap ? request.ngay_tai_kham : visit.NgayTaiKham
        };
        model.SinhHieu = await LaySinhHieuAsync(request, idCskcb, source);
        return model;
    }

    private async Task<List<string>> LayChanDoanAsync(KhamBenhInRequest request, long idCskcb, string source)
    {
        if (source == NguonDaLuu)
        {
            return await _db.QlChanDoanCt.AsNoTracking()
                .Where(x => x.Idcskcb == idCskcb && x.IdvaoVien == request.id_vao_vien)
                .OrderByDescending(x => x.BenhChinh).ThenBy(x => x.ThuTu).ThenBy(x => x.Id)
                .Select(x => $"({x.MaBenh}) {x.TenBenh}" + (x.GhiChu == null || x.GhiChu == "" ? "" : $" - {x.GhiChu}"))
                .ToListAsync();
        }

        var ids = request.chan_doan.Where(x => x.IDICD10 > 0).Select(x => x.IDICD10!.Value).Distinct().ToList();
        if (ids.Count != request.chan_doan.Count)
            throw new KhamBenhPrintValidationException("Chẩn đoán bản nháp không hợp lệ.");
        var masters = await _db.DmIcd10.AsNoTracking()
            .Where(x => x.Idcskcb == idCskcb && x.Active && ids.Contains(x.Id))
            .ToDictionaryAsync(x => x.Id);
        if (masters.Count != ids.Count)
            throw new KhamBenhPrintValidationException("Có chẩn đoán không thuộc cơ sở đang làm việc.");
        return request.chan_doan
            .OrderByDescending(x => x.BenhChinh)
            .Select(x =>
            {
                var item = masters[x.IDICD10!.Value];
                return $"({item.MaBenh}) {item.TenBenh}" + (string.IsNullOrWhiteSpace(x.GhiChu) ? "" : $" - {x.GhiChu.Trim()}");
            })
            .ToList();
    }

    private async Task<List<KhamBenhPrintSinhHieu>> LaySinhHieuAsync(KhamBenhInRequest request, long idCskcb, string source)
    {
        var masters = await _db.DmTriSoSinhHieu.AsNoTracking()
            .Where(x => x.Idcskcb == idCskcb && x.Active)
            .OrderBy(x => x.ThuTu).ThenBy(x => x.Id)
            .Select(x => new VitalMaster
            {
                Id = x.Id,
                Ma = x.MaTriSo,
                Ten = x.TenTriSo,
                DonViTinh = x.DonViTinh ?? string.Empty
            })
            .ToListAsync();

        if (source == NguonDaLuu)
        {
            var sheet = await _db.QlPhieuSinhHieu.AsNoTracking()
                .Where(x => x.Idcskcb == idCskcb && x.IdvaoVien == request.id_vao_vien)
                .OrderByDescending(x => x.NgayGioDo).ThenByDescending(x => x.Id)
                .Select(x => new { x.Id })
                .FirstOrDefaultAsync();
            var storedValues = sheet == null
                ? new List<VitalValue>()
                : await _db.QlPhieuSinhHieuCt.AsNoTracking()
                    .Where(x => x.Idcskcb == idCskcb && x.IdphieuSinhHieu == sheet.Id && x.GiaTri != null && x.GiaTri != "")
                    .OrderByDescending(x => x.Id)
                    .Select(x => new VitalValue { Id = x.IdtriSoSinhHieu, GiaTri = x.GiaTri! })
                    .ToListAsync();
            var savedValues = storedValues.GroupBy(x => x.Id).ToDictionary(x => x.Key, x => x.First().GiaTri);
            return TaoDanhSachSinhHieu(masters, savedValues);
        }

        var values = request.sinh_hieu
            .Where(x => x.IDTriSoSinhHieu > 0 && !string.IsNullOrWhiteSpace(x.GiaTri))
            .GroupBy(x => x.IDTriSoSinhHieu).ToDictionary(x => x.Key, x => x.Last().GiaTri!.Trim());
        return TaoDanhSachSinhHieu(masters, values);
    }

    private async Task<List<ChiDinhRow>> LayChiDinhBanNhapAsync(KhamBenhInRequest request, long idCskcb)
    {
        var valid = request.chi_dinh.Where(x => x.IDDichVu > 0).ToList();
        if (valid.Count != request.chi_dinh.Count || valid.Any(x => x.SoLuong <= 0))
            throw new KhamBenhPrintValidationException("Chỉ định bản nháp có dịch vụ hoặc số lượng không hợp lệ.");
        var ids = valid.Select(x => x.IDDichVu).Distinct().ToList();
        var masters = await _db.DmDichVu.AsNoTracking()
            .Where(x => x.Idcskcb == idCskcb && x.Active && ids.Contains(x.Id))
            .ToDictionaryAsync(x => x.Id);
        if (masters.Count != ids.Count)
            throw new KhamBenhPrintValidationException("Có dịch vụ không thuộc cơ sở đang làm việc.");
        var now = DateTime.Now;
        return valid.Select(x =>
        {
            var service = masters[x.IDDichVu];
            var price = x.GuiNgoai ? 0 : service.DonGia;
            var orderedAt = x.NgayGioChiDinh ?? now;
            return new ChiDinhRow
            {
                GuiNgoai = x.GuiNgoai,
                NgayLap = orderedAt,
                Dong = new KhamBenhPrintChiDinhDong
                {
                    NgayGioChiDinh = orderedAt,
                    MaDichVu = TextOrEmpty(service.MaDichVu),
                    TenDichVu = TextOrEmpty(service.TenDichVu),
                    DonViTinh = TextOrEmpty(service.DonViTinh),
                    SoLuong = x.SoLuong,
                    DonGia = price,
                    ThanhTien = price * x.SoLuong,
                    NoiGuiNgoai = TextOrEmpty(x.NoiGuiNgoai),
                    GhiChu = TextOrEmpty(x.GhiChu)
                }
            };
        }).ToList();
    }

    private async Task<List<ChiDinhRow>> LayChiDinhDaLuuAsync(long idVaoVien, long idCskcb)
    {
        return await _db.QlChiDinhCt.AsNoTracking()
            .Where(x => x.Idcskcb == idCskcb && x.IdvaoVien == idVaoVien && x.Active)
            .OrderBy(x => x.NgayGioChiDinh).ThenBy(x => x.Id)
            .Select(x => new ChiDinhRow
            {
                GuiNgoai = x.GuiNgoai,
                NgayLap = x.NgayGioChiDinh,
                Dong = new KhamBenhPrintChiDinhDong
                {
                    NgayGioChiDinh = x.NgayGioChiDinh,
                    MaDichVu = x.DmDichVu.MaDichVu,
                    TenDichVu = x.DmDichVu.TenDichVu,
                    DonViTinh = x.DmDichVu.DonViTinh ?? string.Empty,
                    SoLuong = x.SoLuong,
                    DonGia = x.GuiNgoai ? 0 : x.DonGia,
                    ThanhTien = x.GuiNgoai ? 0 : x.ThanhTien,
                    NoiGuiNgoai = x.NoiGuiNgoai ?? string.Empty,
                    GhiChu = x.GhiChu ?? string.Empty
                }
            }).ToListAsync();
    }

    private async Task<List<KhamBenhPrintToaPage>> LayToaBanNhapAsync(KhamBenhInRequest request, long idCskcb, string doctor)
    {
        var rows = request.toa_thuoc;
        if (rows.Count == 0) return new();
        if (rows.Any(x => x.IDThuoc <= 0 || x.SoLuong <= 0 || x.NgayKe == default || string.IsNullOrWhiteSpace(x.MaLoaiToaThuoc)))
            throw new KhamBenhPrintValidationException("Toa thuốc bản nháp có dòng thuốc không hợp lệ.");

        var types = rows
            .Select(x => x.MaLoaiToaThuoc!.Trim().ToLowerInvariant())
            .Distinct()
            .ToList();
        if (types.Any(x => x is not ("c" or "n" or "h")))
            throw new KhamBenhPrintValidationException("Loại toa thuốc không hợp lệ.");

        var typeTitles = await _db.DmLoaiToaThuoc.AsNoTracking()
            .Where(x => x.Active && types.Contains(x.MaLoaiToaThuoc))
            .ToDictionaryAsync(x => x.MaLoaiToaThuoc, x => x.TenLoaiToaThuoc);
        if (typeTitles.Count != types.Count)
            throw new KhamBenhPrintValidationException("Có loại toa thuốc không còn hiệu lực.");

        var medicineIds = rows.Select(x => x.IDThuoc).Distinct().ToList();
        var medicines = await _db.DmThuoc.AsNoTracking()
            .Where(x => x.Idcskcb == idCskcb && x.Active && medicineIds.Contains(x.Id))
            .ToDictionaryAsync(x => x.Id);
        if (medicines.Count != medicineIds.Count)
            throw new KhamBenhPrintValidationException("Có thuốc không thuộc cơ sở đang làm việc.");

        var unitIds = rows.Where(x => x.IDDonViTinhDung > 0).Select(x => x.IDDonViTinhDung!.Value).Distinct().ToList();
        var useUnits = await _db.DmDonViTinh.AsNoTracking()
            .Where(x => x.Idcskcb == idCskcb && x.Active && unitIds.Contains(x.Id))
            .ToDictionaryAsync(x => x.Id, x => x.TenDvt);
        if (useUnits.Count != unitIds.Count)
            throw new KhamBenhPrintValidationException("Đơn vị tính dùng của toa thuốc không hợp lệ.");

        // Một lượt khám có thể kê lẫn c/n/h. Khi in mới tách thành các đơn độc lập
        // theo ngày kê + loại toa, giống luồng in dữ liệu đã lưu.
        return rows
            .GroupBy(x => new
            {
                Day = x.NgayKe.Date,
                Type = x.MaLoaiToaThuoc!.Trim().ToLowerInvariant()
            })
            .OrderBy(x => x.Key.Day)
            .ThenBy(x => x.Key.Type)
            .Select(group => new KhamBenhPrintToaPage
            {
                MaLoaiToaThuoc = group.Key.Type,
                TieuDe = typeTitles[group.Key.Type].Trim().ToUpperInvariant(),
                NgayKe = group.Min(x => x.NgayKe),
                BacSi = doctor,
                Thuoc = group.Select(x => TaoDongThuoc(medicines[x.IDThuoc], x.SoLuong,
                    x.Sang, x.Trua, x.Chieu, x.Toi, x.LieuDung, x.CachDung,
                    x.IDDonViTinhDung.HasValue && useUnits.TryGetValue(x.IDDonViTinhDung.Value, out var unit)
                        ? unit
                        : medicines[x.IDThuoc].DonViTinh)).ToList()
            })
            .ToList();
    }

    private async Task<List<KhamBenhPrintToaPage>> LayToaDaLuuAsync(long idVaoVien, long idCskcb, string doctor, long? idToaThuoc = null)
    {
        var rows = await _db.QlToaThuocCt.AsNoTracking()
            .Where(x => x.Idcskcb == idCskcb && x.IdvaoVien == idVaoVien && x.Active
                && (!idToaThuoc.HasValue || x.IdtoaThuoc == idToaThuoc.Value))
            .OrderBy(x => x.NgayKe).ThenBy(x => x.ThuTu).ThenBy(x => x.Id)
            .Select(x => new SavedMedicineRow
            {
                IdThuoc = x.Idthuoc,
                NgayKe = x.NgayKe,
                MaLoai = x.MaLoaiToaThuoc,
                TenLoai = x.DmLoaiToaThuoc.TenLoaiToaThuoc,
                TenThuoc = x.DmThuoc.TenThuoc,
                HamLuong = x.DmThuoc.HamLuong,
                HoatChat = x.HoatChat != null && x.HoatChat != "" ? x.HoatChat : x.DmThuoc.HoatChat,
                DonViTinh = x.DmThuoc.DonViTinh,
                DuongDung = x.DmThuoc.DuongDung,
                SoLuong = x.SoLuong,
                Sang = x.Sang,
                Trua = x.Trua,
                Chieu = x.Chieu,
                Toi = x.Toi,
                LieuDung = x.LieuDung,
                CachDung = x.CachDung,
                IdDonViTinhDung = x.IddonViTinhDung
            }).ToListAsync();
        if (rows.Count == 0) return new();
        var unitIds = rows.Where(x => x.IdDonViTinhDung > 0).Select(x => x.IdDonViTinhDung!.Value).Distinct().ToList();
        var useUnits = await _db.DmDonViTinh.AsNoTracking()
            .Where(x => x.Idcskcb == idCskcb && unitIds.Contains(x.Id))
            .ToDictionaryAsync(x => x.Id, x => x.TenDvt);

        return rows.GroupBy(x => new { Day = x.NgayKe.Date, x.MaLoai })
            .OrderBy(x => x.Key.Day).ThenBy(x => x.Key.MaLoai)
            .Select(group => new KhamBenhPrintToaPage
            {
                MaLoaiToaThuoc = group.Key.MaLoai,
                TieuDe = TextOrEmpty(group.First().TenLoai).ToUpperInvariant(),
                NgayKe = group.Min(x => x.NgayKe),
                BacSi = doctor,
                Thuoc = group.Select(x => new KhamBenhPrintThuocDong
                {
                    TenThuoc = TextOrEmpty(x.TenThuoc),
                    HamLuong = TextOrEmpty(x.HamLuong),
                    HoatChat = TextOrEmpty(x.HoatChat),
                    SoLuong = x.SoLuong,
                    DonViTinh = TextOrEmpty(x.DonViTinh),
                    LieuDung = TaoLieuDung(x.DuongDung, x.Sang, x.Trua, x.Chieu, x.Toi,
                        x.IdDonViTinhDung.HasValue && useUnits.TryGetValue(x.IdDonViTinhDung.Value, out var unit) ? unit : x.DonViTinh,
                        x.CachDung, x.LieuDung)
                }).ToList()
            }).ToList();
    }

    private async Task<string> LayTenLoaiToaAsync(string code)
    {
        var title = await _db.DmLoaiToaThuoc.AsNoTracking()
            .Where(x => x.Active && x.MaLoaiToaThuoc == code)
            .Select(x => x.TenLoaiToaThuoc)
            .SingleOrDefaultAsync();
        if (string.IsNullOrWhiteSpace(title))
            throw new KhamBenhPrintValidationException("Loại toa thuốc không hợp lệ.");
        return title.Trim().ToUpperInvariant();
    }

    private static KhamBenhPrintThuocDong TaoDongThuoc(
        Entities.DmThuoc medicine,
        decimal quantity,
        string? morning,
        string? noon,
        string? afternoon,
        string? evening,
        string? storedDose,
        string? instructions,
        string? useUnit)
    {
        return new KhamBenhPrintThuocDong
        {
            TenThuoc = TextOrEmpty(medicine.TenThuoc),
            HamLuong = TextOrEmpty(medicine.HamLuong),
            HoatChat = TextOrEmpty(medicine.HoatChat),
            SoLuong = quantity,
            DonViTinh = TextOrEmpty(medicine.DonViTinh),
            LieuDung = TaoLieuDung(medicine.DuongDung, morning, noon, afternoon, evening, useUnit, instructions, storedDose)
        };
    }

    public static string TaoLieuDung(
        string? route,
        string? morning,
        string? noon,
        string? afternoon,
        string? evening,
        string? unit,
        string? instructions,
        string? storedDose)
    {
        var doseUnit = string.IsNullOrWhiteSpace(unit) ? "lần" : unit.Trim();
        var parts = new List<string>();
        AddDose(parts, "Sáng", morning, doseUnit);
        AddDose(parts, "Trưa", noon, doseUnit);
        AddDose(parts, "Chiều", afternoon, doseUnit);
        AddDose(parts, "Tối", evening, doseUnit);
        if (parts.Count == 0 && !string.IsNullOrWhiteSpace(storedDose))
            parts.Add(storedDose.Trim());

        var text = new StringBuilder();
        if (!string.IsNullOrWhiteSpace(route)) text.Append(route.Trim()).Append(" : ");
        text.Append(string.Join("; ", parts));
        if (!string.IsNullOrWhiteSpace(instructions))
        {
            if (text.Length > 0) text.Append("; ");
            text.Append(instructions.Trim());
        }
        var total = ParseDose(morning) + ParseDose(noon) + ParseDose(afternoon) + ParseDose(evening);
        if (total > 0)
            text.Append(" [").Append(FormatDecimal(total)).Append(' ').Append(doseUnit).Append("/ngày]");
        return TextOrEmpty(text.ToString());
    }

    private static void AddDose(List<string> parts, string label, string? value, string unit)
    {
        if (ParseDose(value) > 0) parts.Add($"{label} {value!.Trim()} {unit}");
    }

    private static decimal ParseDose(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return 0;
        var normalized = value.Trim().Replace(',', '.');
        return decimal.TryParse(normalized, NumberStyles.Number, CultureInfo.InvariantCulture, out var result) ? result : 0;
    }

    private static string ChuanHoaNguon(KhamBenhInRequest request)
    {
        var source = request.nguon?.Trim().ToLowerInvariant();
        if (source != NguonBanNhap && source != NguonDaLuu)
            throw new KhamBenhPrintValidationException("Nguồn dữ liệu in không hợp lệ.");
        return source;
    }

    private KhamBenhPdfResult TaoPdf(string html, string fileName)
        => TaoPdf(new[] { html }, fileName, resetPageNumberPerDocument: false);

    private KhamBenhPdfResult TaoPdf(
        IReadOnlyList<string> htmlDocuments,
        string fileName,
        bool resetPageNumberPerDocument)
    {
        var document = new HtmlToPdfDocument
        {
            GlobalSettings =
            {
                ColorMode = ColorMode.Color,
                Orientation = Orientation.Portrait,
                PaperSize = PaperKind.A5,
                Margins = new MarginSettings
                {
                    Top = 0.5,
                    Bottom = 0.5,
                    Left = 0.5,
                    Right = 0.5,
                    Unit = Unit.Centimeters
                }
            }
        };

        var pageToken = resetPageNumberPerDocument ? "[sitepage]" : "[page]";
        foreach (var html in htmlDocuments)
        {
            document.Objects.Add(new ObjectSettings
            {
                PagesCount = true,
                HtmlContent = html,
                WebSettings = { DefaultEncoding = "utf-8", LoadImages = true },
                LoadSettings = { BlockLocalFileAccess = false },
                FooterSettings =
                {
                    FontName = "Times New Roman",
                    FontSize = 8,
                    Right = pageToken,
                    Spacing = 0
                }
            });
        }

        return new KhamBenhPdfResult(_converter.Convert(document), fileName);
    }

    public static string TaoCode128Svg(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return string.Empty;
        var patterns = new[]
        {
            "212222","222122","222221","121223","121322","131222","122213","122312","132212","221213","221312","231212","112232","122132","122231","113222","123122","123221","223211","221132","221231","213212","223112","312131","311222","321122","321221","312212","322112","322211","212123","212321","232121","111323","131123","131321","112313","132113","132311","211313","231113","231311","112133","112331","132131","113123","113321","133121","313121","211331","231131","312113","312311","332111","314111","221411","431111","111224","112214","112412","122114","122411","142112","142211","241211","221114","411211","211141","114121","114211","411121","214111","211411","412111","111143","111341","131141","114113","114311","411113","411311","113141","114131","311141","411131","211412","211214","211232","211133","241112","134111","111242","121142","121241","114212","124112","124211","411212","421112","421211","212141","214121","412121","211412","211214","211232","2331112"
        };
        var encoded = patterns[104];
        var checksum = 104;
        var position = 1;
        foreach (var c in value)
        {
            var code = c - 32;
            if (code < 0 || code > 95) continue;
            checksum += code * position++;
            encoded += patterns[code];
        }
        encoded += patterns[checksum % 103] + patterns[106];
        var x = 0;
        var bars = new StringBuilder();
        for (var i = 0; i < encoded.Length; i++)
        {
            var width = encoded[i] - '0';
            if (i % 2 == 0) bars.Append($"<rect x=\"{x}\" y=\"0\" width=\"{width}\" height=\"38\" fill=\"#000\"/>");
            x += width;
        }
        var label = SecurityElement.Escape(value) ?? string.Empty;
        const int quietZone = 10;
        var totalWidth = x + quietZone * 2;
        return $"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 {totalWidth} 38\" preserveAspectRatio=\"none\" role=\"img\" aria-label=\"{label}\"><g transform=\"translate({quietZone},0)\">{bars}</g></svg><div class=\"barcode__label\">{label}</div>";
    }

    private static List<KhamBenhPrintSinhHieu> TaoDanhSachSinhHieu(
        IReadOnlyList<VitalMaster> masters,
        IReadOnlyDictionary<long, string> values)
    {
        var result = new List<KhamBenhPrintSinhHieu>();
        foreach (var master in masters)
        {
            if (string.Equals(master.Ma, "HA_TR", StringComparison.OrdinalIgnoreCase)) continue;
            if (string.Equals(master.Ma, "HA_TT", StringComparison.OrdinalIgnoreCase))
            {
                values.TryGetValue(master.Id, out var systolic);
                var diastolicMaster = masters.FirstOrDefault(x => string.Equals(x.Ma, "HA_TR", StringComparison.OrdinalIgnoreCase));
                var diastolic = diastolicMaster != null && values.TryGetValue(diastolicMaster.Id, out var storedDiastolic)
                    ? storedDiastolic
                    : string.Empty;
                var combined = (!string.IsNullOrWhiteSpace(systolic) || !string.IsNullOrWhiteSpace(diastolic))
                    ? $"{systolic}/{diastolic}".Trim('/')
                    : string.Empty;
                result.Add(new KhamBenhPrintSinhHieu { Ten = "Huyết áp", GiaTri = combined, DonViTinh = "mmHg" });
                continue;
            }

            result.Add(new KhamBenhPrintSinhHieu
            {
                Ten = master.Ten,
                GiaTri = values.TryGetValue(master.Id, out var value) ? TextOrEmpty(value) : string.Empty,
                DonViTinh = master.DonViTinh
            });
        }
        return result;
    }

    private static string TextOrEmpty(string? value) => string.IsNullOrWhiteSpace(value) ? string.Empty : value.Trim();
    private static string FormatDecimal(decimal value) => value % 1 == 0 ? value.ToString("0", CultureInfo.InvariantCulture) : value.ToString("0.##", CultureInfo.InvariantCulture);
    private static string TaoMaToaThuoc(string maCskcb, string maVaoVien, string maLoaiToaThuoc)
    {
        var facilityCode = maCskcb.Trim();
        if (facilityCode.Length != 5)
            throw new KhamBenhPrintValidationException("Mã cơ sở KCB phải có đúng 5 ký tự để tạo mã toa thuốc.");

        var visitCode = maVaoVien.Trim();
        if (!visitCode.StartsWith("VV", StringComparison.OrdinalIgnoreCase))
            throw new KhamBenhPrintValidationException("Mã vào viện không đúng định dạng để tạo mã toa thuốc.");

        var sequence = visitCode[2..];
        if (sequence.Length == 0 || sequence.Length > 7 || sequence.Any(x => !char.IsDigit(x)))
            throw new KhamBenhPrintValidationException("Mã vào viện không đúng định dạng để tạo mã toa thuốc.");

        var prescriptionType = maLoaiToaThuoc.Trim().ToLowerInvariant();
        if (prescriptionType.Length != 1 || !char.IsLetterOrDigit(prescriptionType[0]))
            throw new KhamBenhPrintValidationException("Loại toa thuốc không hợp lệ để tạo mã toa thuốc.");

        return $"{facilityCode}{sequence.PadLeft(7, '0')}-{prescriptionType}";
    }

    private static string SafeFilePart(string value)
    {
        var invalid = Path.GetInvalidFileNameChars();
        return new string(value.Select(c => invalid.Contains(c) ? '-' : c).ToArray());
    }

    private sealed class VisitData
    {
        public long Id { get; set; }
        public string MaVaoVien { get; set; } = string.Empty;
        public long? IdBacSiKham { get; set; }
        public string? TrieuChung { get; set; }
        public DateTime? NgayTaiKham { get; set; }
        public string? DanDo { get; set; }
        public string MaBn { get; set; } = string.Empty;
        public string HoTen { get; set; } = string.Empty;
        public DateTime? NgaySinh { get; set; }
        public byte IdGioiTinh { get; set; }
        public string GioiTinh { get; set; } = string.Empty;
        public string? SoCccd { get; set; }
        public string? DiaChi { get; set; }
        public string? DienThoai { get; set; }
        public string? GiamHoMoiQuanHe { get; set; }
        public string? GiamHoHoTen { get; set; }
        public string? GiamHoDienThoai { get; set; }
        public string? GiamHoSoCccd { get; set; }
        public string MaCskcb { get; set; } = string.Empty;
        public string TenCskcb { get; set; } = string.Empty;
        public string? DiaChiCskcb { get; set; }
        public string? DienThoaiCskcb { get; set; }
        public string? EmailCskcb { get; set; }
        public string? UrlLogo { get; set; }
    }

    private sealed class VitalMaster
    {
        public long Id { get; set; }
        public string Ma { get; set; } = string.Empty;
        public string Ten { get; set; } = string.Empty;
        public string DonViTinh { get; set; } = string.Empty;
    }

    private sealed class VitalValue
    {
        public long Id { get; set; }
        public string GiaTri { get; set; } = string.Empty;
    }

    private sealed class ChiDinhRow
    {
        public bool GuiNgoai { get; set; }
        public DateTime NgayLap { get; set; }
        public KhamBenhPrintChiDinhDong Dong { get; set; } = new();
    }

    private sealed class SavedMedicineRow
    {
        public long IdThuoc { get; set; }
        public DateTime NgayKe { get; set; }
        public string MaLoai { get; set; } = "c";
        public string TenLoai { get; set; } = "ĐƠN THUỐC";
        public string TenThuoc { get; set; } = string.Empty;
        public string? HamLuong { get; set; }
        public string? HoatChat { get; set; }
        public string? DonViTinh { get; set; }
        public string? DuongDung { get; set; }
        public decimal SoLuong { get; set; }
        public string? Sang { get; set; }
        public string? Trua { get; set; }
        public string? Chieu { get; set; }
        public string? Toi { get; set; }
        public string? LieuDung { get; set; }
        public string? CachDung { get; set; }
        public long? IdDonViTinhDung { get; set; }
    }
}
