using ClosedXML.Excel;
using QuanLyPhongMach.Models.Reports.ThuNgan;

namespace QuanLyPhongMach.Services;

public static class thu_ngan_excel
{
    /*
     * Bám mẫu HIS đã commit tại:
     * Doc/UI/pdf-mẫu/EXCELLichSuHuyChungTu.xlsx
     * Sheet: LichSuHuyChungTu, header A1:N1.
     */
    public static byte[] LichSuHuyChungTu(ThuNganLichSuHuyExcelModel model)
    {
        using var book = new XLWorkbook();
        var sheet = book.Worksheets.Add("LichSuHuyChungTu");
        sheet.ShowGridLines = true;
        sheet.Style.Font.FontName = "Calibri";
        sheet.Style.Font.FontSize = 11;

        string[] headers =
        {
            "STT",
            "NgayThu",
            "NguonThu",
            "SoChungTu",
            "TrangThaiXoa",
            "NgayGioHuy",
            "TenNguoiDangNhapHuy",
            "NgayGioXoa",
            "TenNguoiDangNhapXoa",
            "TenNguoiXoa",
            "LyDoXoa",
            "SoDienThoaiBenhNhan",
            "ThongTinHanhChinh",
            "NoiDungHuy"
        };

        for (var c = 0; c < headers.Length; c++)
            sheet.Cell(1, c + 1).Value = headers[c];

        var header = sheet.Range(1, 1, 1, 14);
        header.Style.Font.Bold = true;
        header.Style.Fill.BackgroundColor = XLColor.FromHtml("#ADD8E6");

        double[] widths =
        {
            9.140625,
            16.209102630615234,
            13.341453552246094,
            17.103261947631836,
            13.015096664428711,
            16.209102630615234,
            22.254396438598633,
            11.708641052246094,
            22.126514434814453,
            12.717384338378906,
            9.140625,
            21.409345626831055,
            116.30070495605469,
            104.67356872558594
        };
        for (var c = 0; c < widths.Length; c++)
            sheet.Column(c + 1).Width = widths[c];

        var row = 2;
        var stt = 1;
        foreach (var item in model.LichSu.OrderByDescending(x => x.NgayGioHuy ?? x.NgayThu))
        {
            sheet.Cell(row, 1).Value = stt++;
            SetDateTime(sheet.Cell(row, 2), item.NgayThu);
            sheet.Cell(row, 3).Value = item.NguonThu;
            sheet.Cell(row, 4).Value = item.SoChungTu;
            sheet.Cell(row, 5).Value = item.TrangThaiXoa;
            SetDateTime(sheet.Cell(row, 6), item.NgayGioHuy);
            sheet.Cell(row, 7).Value = item.TenNguoiDangNhapHuy;
            SetDateTime(sheet.Cell(row, 8), item.NgayGioXoa);
            sheet.Cell(row, 9).Value = item.TenNguoiDangNhapXoa;
            sheet.Cell(row, 10).Value = item.TenNguoiXoa;
            sheet.Cell(row, 11).Value = item.LyDoXoa;
            sheet.Cell(row, 12).Value = item.SoDienThoaiBenhNhan;
            sheet.Cell(row, 13).Value = item.ThongTinHanhChinh;
            sheet.Cell(row, 14).Value = item.NoiDungHuy;
            row++;
        }

        sheet.SheetView.FreezeRows(1);

        using var stream = new MemoryStream();
        book.SaveAs(stream);
        return stream.ToArray();
    }

    private static void SetDateTime(IXLCell cell, DateTime? value)
    {
        if (!value.HasValue) return;
        cell.Value = value.Value;
        cell.Style.DateFormat.Format = "dd-MM-yyyy HH:mm";
    }
}
