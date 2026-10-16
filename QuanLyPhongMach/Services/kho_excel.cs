using ClosedXML.Excel;
using QuanLyPhongMach.Models.Printing.Kho;

namespace QuanLyPhongMach.Services;

public static class kho_excel
{
    // Port worksheet từ HisSoft/Controllers/HH_NhapKhoController.cs: ExportExcelPhieuNhapKho.
    // Giữ vùng header, hàng tiêu đề 12, data từ 14, 14 cột và widths HIS.
    public static byte[] PhieuNhap(KhoNhapPrintModel model)
    {
        using var book = new XLWorkbook();
        var sheet = book.Worksheets.Add("Phiếu nhập kho");
        sheet.ShowGridLines = false;
        sheet.Style.Font.FontName = "Calibri";
        sheet.Style.Font.FontSize = 11;
        sheet.Style.Alignment.Vertical = XLAlignmentVerticalValues.Center;
        void Merge(string range, string value) { var r = sheet.Range(range); r.Merge(); r.FirstCell().Value = value; }
        Merge("A1:D1", model.CoSo.TenCskcb);
        Merge("A2:D2", "Địa chỉ: " + model.CoSo.DiaChiCskcb);
        Merge("A3:B3", "SĐT: " + model.CoSo.DienThoaiCskcb);
        Merge("C3:D3", "Email: " + model.EmailCskcb);
        Merge("A4:B4", "MST: " + model.MaSoThueCskcb); Merge("C4:D4", "Số TK: " + model.SoTaiKhoanCskcb);
        Merge("A5:B5", "Ngân hàng: " + model.NganHangCskcb); Merge("C5:D5", "Chủ TK: ");
        sheet.Range("A1:D5").Style.Font.Bold = true;
        sheet.Range("A1:D5").Style.Font.FontSize = 12;
        double[] widths = { 10, 60, 20, 20, 20, 10, 20, 30, 20, 20, 40, 20, 20, 20 };
        for (var c = 0; c < widths.Length; c++) sheet.Column(c + 1).Width = widths[c];
        Merge("A7:L7", "PHIẾU NHẬP KHO" + (model.DaHuy ? " - ĐÃ HỦY" : ""));
        sheet.Range("A7:L7").Style.Font.Bold = true;
        sheet.Range("A7:L7").Style.Font.FontSize = 18;
        sheet.Range("A7:L7").Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center;
        Merge("A8:D8", "Nhà cung cấp: " + model.NhaCungCap);
        Merge("A9:D9", "Địa chỉ: " + model.DiaChiNhaCungCap);
        Merge("A10:B10", "Điện thoại: " + model.DienThoaiNhaCungCap);
        Merge("C10:D10", "Email: "); // QLPM chưa lưu email nhà cung cấp.
        sheet.Range("A8:D10").Style.Font.Bold = true;
        sheet.Range("A8:D10").Style.Font.FontSize = 14;
        string[] headers = { "STT", "Tên hàng hóa", "Mã hàng hóa", "Hạn dùng", "ĐVT nhập", "SL Nhập", "SLQĐ", "Giá nhập", "Chiết khấu", "Thuế VAT", "Thành tiền", "Số lượng tồn", "Số lô", "Tỷ lệ hao hụt" };
        for (var c = 0; c < headers.Length; c++) sheet.Cell(12, c + 1).Value = headers[c];
        var header = sheet.Range(12, 1, 12, 14);
        header.Style.Font.Bold = true;
        header.Style.Fill.BackgroundColor = XLColor.LightGray;
        header.Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center;
        header.Style.Border.OutsideBorder = XLBorderStyleValues.Thin;
        header.Style.Border.InsideBorder = XLBorderStyleValues.Thin;
        var row = 14;
        foreach (var line in model.ChiTiet)
        {
            sheet.Cell(row, 1).Value = row - 13;
            sheet.Cell(row, 2).Value = line.Ten; sheet.Cell(row, 3).Value = line.Ma;
            if (line.HanDung.HasValue) { sheet.Cell(row, 4).Value = line.HanDung.Value; sheet.Cell(row, 4).Style.DateFormat.Format = "dd-MM-yyyy"; }
            sheet.Cell(row, 5).Value = line.DonViTinh;
            sheet.Cell(row, 6).Value = line.SoLuong; sheet.Cell(row, 7).Value = line.HeSoQuyDoi;
            sheet.Cell(row, 8).Value = line.GiaNhap; sheet.Cell(row, 9).Value = 0;
            sheet.Cell(row, 10).Value = 0; sheet.Cell(row, 11).Value = line.ThanhTien;
            if (line.SoLuongTonCoSo.HasValue) sheet.Cell(row, 12).Value = line.SoLuongTonCoSo.Value;
            sheet.Cell(row, 13).Value = line.SoLo;
            sheet.Range(row, 6, row, 12).Style.NumberFormat.Format = "#,##0.##";
            sheet.Range(row, 6, row, 14).Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Right;
            sheet.Cell(row, 13).Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Left;
            sheet.Range(row, 1, row, 4).Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center;
            sheet.Cell(row, 5).Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Left;
            sheet.Range(row, 1, row, 14).Style.Fill.BackgroundColor = XLColor.White;
            sheet.Range(row, 1, row, 14).Style.Border.OutsideBorder = XLBorderStyleValues.Thin;
            sheet.Range(row, 1, row, 14).Style.Border.InsideBorder = XLBorderStyleValues.Thin;
            row++;
        }
        row++;
        sheet.Cell(row, 1).Value = "Tổng tiền hàng:"; sheet.Cell(row, 2).Value = model.TongTien;
        sheet.Cell(row + 1, 1).Value = "Tổng tiền chiết khấu:"; sheet.Cell(row + 1, 2).Value = 0;
        sheet.Cell(row + 2, 1).Value = "Tổng tiền thuế:"; sheet.Cell(row + 2, 2).Value = 0;
        sheet.Cell(row + 3, 1).Value = "Tổng trả:"; sheet.Cell(row + 3, 2).Value = model.TongTien;
        sheet.Range(row, 1, row + 3, 2).Style.Font.Bold = true;
        sheet.Range(row, 2, row + 3, 2).Style.NumberFormat.Format = "#,##0";
        sheet.Range(row, 2, row + 3, 2).Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Right;
        if (model.DaHuy) Merge($"A{row + 5}:N{row + 5}", "Lý do hủy: " + model.LyDoHuy);
        sheet.PageSetup.PageOrientation = XLPageOrientation.Landscape;
        sheet.PageSetup.PaperSize = XLPaperSize.A4Paper;
        sheet.PageSetup.FitToPages(1, 0);
        sheet.PageSetup.SetRowsToRepeatAtTop(12, 12);
        sheet.PageSetup.PrintAreas.Add(1, 1, row + 5, 14);
        sheet.SheetView.FreezeRows(12);
        using var stream = new MemoryStream();
        book.SaveAs(stream);
        return stream.ToArray();
    }
}
