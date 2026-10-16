using QuanLyPhongMach.Models.ToaThuocQuocGia;

namespace QuanLyPhongMach.Services.ToaThuocQuocGia;

public interface ILienThongTrucTiepService
{
    Task KiemTraAsync(long idToa, long idCskcb, long idTaiKhoan, long idNhanVien, CancellationToken cancellationToken);
    Task<LienThongTrucTiepResult> GuiAsync(long idToa, long idCskcb, long idTaiKhoan, long idNhanVien, CancellationToken cancellationToken);
}
