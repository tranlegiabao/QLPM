namespace QuanLyPhongMach.Models.ToaThuocQuocGia;

public sealed record ToaThuocReadinessResult(
    string TrangThai,
    bool SanSangKy,
    IReadOnlyList<string> LoiKy,
    bool SanSangLienThong,
    IReadOnlyList<string> LoiLienThong);

public sealed record ToaThuocPayloadSnapshot(
    long IdToaThuoc,
    long IdVaoVien,
    long PhienBanNguon,
    ToaThuocQuocGiaPayload Payload,
    string CanonicalJson);

public sealed record ToaThuocSignRequest(
    long IdToaThuoc,
    string MaToaQuocGia,
    long IdBacSi,
    string CanonicalJson,
    byte[] Pdf);

public sealed record ToaThuocSignedArtifacts(
    string Signature,
    string SignedJson,
    byte[] SignedPdf,
    string Provider,
    string? CertificateSerial);

public sealed record ToaThuocNationalSendResult(
    bool Accepted,
    bool Unknown,
    int? HttpStatus,
    string? ResultCode,
    string SanitizedResponse,
    string? Error,
    bool DoctorRegistered = false);

public sealed record ToaThuocApiCredentials(string Username, string Password);

public sealed record ToaThuocNationalRequest(
    Uri BaseAddress,
    ToaThuocApiCredentials Facility,
    ToaThuocApiCredentials Doctor,
    string DoctorName,
    string DoctorLicense,
    string SignedJson,
    Guid IdempotencyKey,
    bool DoctorWasRegistered = false);

public sealed class LienThongToaThuocConfigRequest
{
    public string MoiTruong { get; set; } = "TEST";
    public string? ApiBaseUrlProduction { get; set; }
    public string? ApiBaseUrlTest { get; set; }
    public string? UrlKyDuLieu { get; set; }
    public string? UrlKyPdf { get; set; }
    public string? MaLienThongCskcb { get; set; }
    public string? MatKhauCskcb { get; set; }
    public bool KySoHieuLuc { get; set; }
    public bool LienThongHieuLuc { get; set; }
}

public sealed class LienThongToaThuocBacSiRequest
{
    public long IdNhanVien { get; set; }
    public string? MaLienThong { get; set; }
    public string? SoChungChiHanhNghe { get; set; }
    public string? MatKhau { get; set; }
    public bool Active { get; set; }
}
