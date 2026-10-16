using QuanLyPhongMach.Models.ToaThuocQuocGia;

namespace QuanLyPhongMach.Services.ToaThuocQuocGia;

public interface IToaThuocReadinessService
{
    Task<ToaThuocReadinessResult> KiemTraAsync(long idToaThuoc, long idCskcb, long idNhanVien, CancellationToken cancellationToken = default);
    Task<ToaThuocPayloadSnapshot> TaoPayloadAsync(long idToaThuoc, long idCskcb, long idNhanVien, CancellationToken cancellationToken = default);
    Task<ToaThuocPayloadSnapshot> TaoPayloadLienThongAsync(long idToaThuoc, long idCskcb, CancellationToken cancellationToken = default);
}

public interface IToaThuocSigner
{
    bool IsConfigured { get; }
    Task<ToaThuocSignedArtifacts> SignAsync(ToaThuocSignRequest request, CancellationToken cancellationToken = default);
}

public interface IToaThuocQuocGiaClient
{
    Task<ToaThuocNationalSendResult> GuiAsync(ToaThuocNationalRequest request, CancellationToken cancellationToken = default);
}

public interface IToaThuocDeliveryService
{
    Task<long> KySoAsync(long idToaThuoc, long idCskcb, long idNhanVien, long idTaiKhoan, CancellationToken cancellationToken = default);
    Task<long> XepHangLienThongAsync(long idToaThuoc, long idCskcb, long idNhanVien, long idTaiKhoan, CancellationToken cancellationToken = default);
    Task<long> XepHangGuiLaiAsync(long idToaThuoc, long idCskcb, long idNhanVien, long idTaiKhoan, CancellationToken cancellationToken = default);
    Task<int> XuLyHangDoiAsync(CancellationToken cancellationToken = default);
}

public interface ILienThongCredentialProtector
{
    string Protect(string plaintext);
    string Unprotect(string protectedValue);
}

public sealed class ToaThuocInteroperabilityException : Exception
{
    public ToaThuocInteroperabilityException(int statusCode, string message) : base(message)
    {
        StatusCode = statusCode;
    }

    public int StatusCode { get; }
}
