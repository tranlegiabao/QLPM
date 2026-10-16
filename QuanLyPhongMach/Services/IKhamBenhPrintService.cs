using QuanLyPhongMach.Models.Printing.KhamBenh;
using QuanLyPhongMach.Models.Requests.KhamBenh;

namespace QuanLyPhongMach.Services;

public interface IKhamBenhPrintService
{
    Task<KhamBenhPdfResult> InChiDinhAsync(KhamBenhInRequest request, long idCskcb, long idNhanVien);
    Task<KhamBenhPdfResult> InToaThuocAsync(KhamBenhInRequest request, long idCskcb, long idNhanVien);
}
