namespace QuanLyPhongMach.Services;

/// <summary>Đọc số tiền VND nguyên đã làm tròn; không dùng double hoặc parse theo culture.</summary>
public static class so_tien_bang_chu
{
    private static readonly string[] ChuSo = { "không", "một", "hai", "ba", "bốn", "năm", "sáu", "bảy", "tám", "chín" };
    private static readonly string[] Bac = { "", "nghìn", "triệu", "tỷ", "nghìn tỷ", "triệu tỷ" };

    public static string Doc(decimal soTien)
    {
        if (soTien < 0 || soTien > 999999999999999999m)
            throw new ArgumentOutOfRangeException(nameof(soTien));
        var so = decimal.Round(soTien, 0, MidpointRounding.AwayFromZero);
        if (so == 0) return "Không đồng";
        var nhom = new List<int>();
        while (so > 0) { nhom.Add((int)(so % 1000)); so = decimal.Truncate(so / 1000); }
        var ketQua = new List<string>();
        for (var i = nhom.Count - 1; i >= 0; i--)
        {
            if (nhom[i] == 0) continue;
            ketQua.Add(DocNhom(nhom[i], i < nhom.Count - 1));
            if (Bac[i].Length > 0) ketQua.Add(Bac[i]);
        }
        var chu = string.Join(" ", ketQua) + " đồng";
        return char.ToUpperInvariant(chu[0]) + chu[1..];
    }

    private static string DocNhom(int n, bool docTram)
    {
        var tram = n / 100; var chuc = n / 10 % 10; var donVi = n % 10;
        var chu = new List<string>();
        if (tram > 0 || docTram) { chu.Add(ChuSo[tram]); chu.Add("trăm"); }
        if (chuc == 0 && donVi > 0 && (tram > 0 || docTram)) chu.Add("lẻ");
        else if (chuc == 1) chu.Add("mười");
        else if (chuc > 1) { chu.Add(ChuSo[chuc]); chu.Add("mươi"); }
        if (donVi > 0) chu.Add(donVi == 1 && chuc > 1 ? "mốt" : donVi == 5 && chuc > 0 ? "lăm" : ChuSo[donVi]);
        return string.Join(" ", chu);
    }
}
