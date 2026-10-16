using System.Text.Json.Serialization;

namespace QuanLyPhongMach.Models.ToaThuocQuocGia;

public sealed class ToaThuocQuocGiaPayload
{
    [JsonPropertyName("loai_don_thuoc")]
    public string LoaiDonThuoc { get; init; } = string.Empty;

    [JsonPropertyName("ma_don_thuoc")]
    public string MaDonThuoc { get; init; } = string.Empty;

    [JsonPropertyName("ho_ten_benh_nhan")]
    public string HoTenBenhNhan { get; init; } = string.Empty;

    [JsonPropertyName("ma_dinh_danh_y_te")]
    public string MaDinhDanhYTe { get; init; } = string.Empty;

    [JsonPropertyName("ma_dinh_danh_cong_dan")]
    public string? MaDinhDanhCongDan { get; init; }

    [JsonPropertyName("ngay_sinh_benh_nhan")]
    public string NgaySinhBenhNhan { get; init; } = string.Empty;

    [JsonPropertyName("can_nang")]
    public decimal? CanNang { get; init; }

    [JsonPropertyName("gioi_tinh")]
    public int GioiTinh { get; init; }

    [JsonPropertyName("ma_so_the_bao_hiem_y_te")]
    public string? MaSoTheBaoHiemYTe { get; init; }

    [JsonPropertyName("thong_tin_nguoi_giam_ho")]
    public string? ThongTinNguoiGiamHo { get; init; }

    [JsonPropertyName("dia_chi")]
    public string DiaChi { get; init; } = string.Empty;

    [JsonPropertyName("chan_doan")]
    public IReadOnlyList<ToaThuocQuocGiaChanDoan> ChanDoan { get; init; } = Array.Empty<ToaThuocQuocGiaChanDoan>();

    [JsonPropertyName("dot_dung_thuoc")]
    public IReadOnlyList<ToaThuocQuocGiaDotDung> DotDungThuoc { get; init; } = Array.Empty<ToaThuocQuocGiaDotDung>();

    [JsonPropertyName("thong_tin_don_thuoc")]
    public IReadOnlyList<ToaThuocQuocGiaDongThuoc> ThongTinDonThuoc { get; init; } = Array.Empty<ToaThuocQuocGiaDongThuoc>();

    [JsonPropertyName("luu_y")]
    public string? LuuY { get; init; }

    [JsonPropertyName("hinh_thuc_dieu_tri")]
    public int HinhThucDieuTri { get; init; } = 1;

    [JsonPropertyName("loi_dan")]
    public string? LoiDan { get; init; }

    [JsonPropertyName("so_dien_thoai_nguoi_kham_benh")]
    public string? SoDienThoaiNguoiKhamBenh { get; init; }

    [JsonPropertyName("ngay_tai_kham")]
    public int? NgayTaiKham { get; init; }

    [JsonPropertyName("ngay_gio_ke_don")]
    public string NgayGioKeDon { get; init; } = string.Empty;

    [JsonPropertyName("signature")]
    public string Signature { get; init; } = string.Empty;
}

public sealed class ToaThuocQuocGiaChanDoan
{
    [JsonPropertyName("ma_chan_doan")]
    public string MaChanDoan { get; init; } = string.Empty;

    [JsonPropertyName("ten_chan_doan")]
    public string TenChanDoan { get; init; } = string.Empty;

    [JsonPropertyName("ket_luan")]
    public string? KetLuan { get; init; }
}

public sealed class ToaThuocQuocGiaDotDung
{
    [JsonPropertyName("SO")]
    public string So { get; init; } = "1";

    [JsonPropertyName("Tungay")]
    public string TuNgay { get; init; } = string.Empty;

    [JsonPropertyName("Denngay")]
    public string DenNgay { get; init; } = string.Empty;

    [JsonPropertyName("Sothang")]
    public string SoThang { get; init; } = "0";
}

public sealed class ToaThuocQuocGiaDongThuoc
{
    [JsonPropertyName("ma_thuoc")]
    public string MaThuoc { get; init; } = string.Empty;

    [JsonPropertyName("ten_thuoc")]
    public string TenThuoc { get; init; } = string.Empty;

    [JsonPropertyName("biet_duoc")]
    public string? BietDuoc { get; init; }

    [JsonPropertyName("don_vi_tinh")]
    public string DonViTinh { get; init; } = string.Empty;

    [JsonPropertyName("so_luong")]
    public decimal SoLuong { get; init; }

    [JsonPropertyName("cach_dung")]
    public string CachDung { get; init; } = string.Empty;
}
