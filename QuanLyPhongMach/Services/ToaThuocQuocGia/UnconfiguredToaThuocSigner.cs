using QuanLyPhongMach.Models.ToaThuocQuocGia;

namespace QuanLyPhongMach.Services.ToaThuocQuocGia;

public sealed class UnconfiguredToaThuocSigner : IToaThuocSigner
{
    public bool IsConfigured => false;

    public Task<ToaThuocSignedArtifacts> SignAsync(ToaThuocSignRequest request, CancellationToken cancellationToken = default)
        => throw new ToaThuocInteroperabilityException(503,
            "Chưa cấu hình dịch vụ ký số dữ liệu và PDF. Hệ thống không tạo chữ ký giả.");
}
