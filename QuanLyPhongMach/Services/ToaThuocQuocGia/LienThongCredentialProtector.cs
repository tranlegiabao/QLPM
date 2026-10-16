using Microsoft.AspNetCore.DataProtection;

namespace QuanLyPhongMach.Services.ToaThuocQuocGia;

public sealed class LienThongCredentialProtector : ILienThongCredentialProtector
{
    private readonly IDataProtector _protector;

    public LienThongCredentialProtector(IDataProtectionProvider provider)
    {
        _protector = provider.CreateProtector("QLPM.LienThongToaThuoc.Credentials.v1");
    }

    public string Protect(string plaintext)
    {
        if (string.IsNullOrWhiteSpace(plaintext))
            throw new ArgumentException("Mật khẩu không được để trống.", nameof(plaintext));
        return _protector.Protect(plaintext);
    }

    public string Unprotect(string protectedValue)
    {
        if (string.IsNullOrWhiteSpace(protectedValue))
            throw new InvalidOperationException("Thông tin đăng nhập chưa được cấu hình.");
        return _protector.Unprotect(protectedValue);
    }
}
