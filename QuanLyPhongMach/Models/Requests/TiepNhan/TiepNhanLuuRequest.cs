using System.Text.Json.Serialization;

namespace QuanLyPhongMach.Models.Requests.TiepNhan;

/// <summary>
/// Request body cho API lưu tiếp nhận bệnh nhân (gộp cả tạo mới và cập nhật).
/// </summary>
public class TiepNhanLuuRequest
{
    [JsonPropertyName("id_cskcb")]
    public long IdCskcb { get; set; }

    [JsonPropertyName("id_nguoi_tiep_nhan")]
    public long? IdNguoiTiepNhan { get; set; }

    [JsonPropertyName("id_benh_nhan")]
    public long? IdBenhNhan { get; set; }

    [JsonPropertyName("id_vao_vien")]
    public long? IdVaoVien { get; set; }

    [JsonPropertyName("so_thu_tu")]
    public int? SoThuTu { get; set; }

    [JsonPropertyName("ho_ten")]
    public string? HoTen { get; set; }

    [JsonPropertyName("ngay_sinh")]
    public string? NgaySinh { get; set; }

    [JsonPropertyName("id_gioi_tinh")]
    public byte? IdGioiTinh { get; set; }

    [JsonPropertyName("so_cccd")]
    public string? SoCccd { get; set; }

    [JsonPropertyName("dien_thoai")]
    public string? DienThoai { get; set; }

    [JsonPropertyName("so_nha_ten_duong")]
    public string? SoNhaTenDuong { get; set; }

    [JsonPropertyName("id_phuong_xa")]
    public long? IdPhuongXa { get; set; }

    [JsonPropertyName("id_tinh_thanh")]
    public long? IdTinhThanh { get; set; }

    [JsonPropertyName("dia_chi")]
    public string? DiaChi { get; set; }

    [JsonPropertyName("id_dan_toc")]
    public long? IdDanToc { get; set; }

    [JsonPropertyName("quoc_tich")]
    public string? QuocTich { get; set; }

    [JsonPropertyName("nghe_nghiep")]
    public string? NgheNghiep { get; set; }

    [JsonPropertyName("ghi_chu_benh_nhan")]
    public string? GhiChuBenhNhan { get; set; }

    [JsonPropertyName("ghi_chu_lan_kham")]
    public string? GhiChuLanKham { get; set; }

    [JsonPropertyName("cong_kham")]
    public List<CongKhamItem>? CongKham { get; set; }

    [JsonPropertyName("tao_vao_vien")]
    public bool TaoVaoVien { get; set; }

    [JsonPropertyName("chuyen_kham")]
    public bool ChuyenKham { get; set; }

    [JsonPropertyName("bo_qua_canh_bao_trung")]
    public bool BoQuaCanhBaoTrung { get; set; }

    [JsonPropertyName("chi_sua_thong_tin_benh_nhan")]
    public bool ChiSuaThongTinBenhNhan { get; set; }

    // --- Thông tin người giám hộ (bắt buộc khi BN dưới 18 tuổi) ---
    [JsonPropertyName("giam_ho_moi_quan_he")]
    public string? GiamHoMoiQuanHe { get; set; }

    [JsonPropertyName("giam_ho_ho_ten")]
    public string? GiamHoHoTen { get; set; }

    [JsonPropertyName("giam_ho_dien_thoai")]
    public string? GiamHoDienThoai { get; set; }

    [JsonPropertyName("giam_ho_so_cccd")]
    public string? GiamHoSoCccd { get; set; }
}
