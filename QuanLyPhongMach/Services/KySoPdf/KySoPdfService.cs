using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using QuanLyPhongMach.Data;
using QuanLyPhongMach.Services.ToaThuocQuocGia;

namespace QuanLyPhongMach.Services.KySoPdf;

public sealed record PdfKySoPreview(long Tenant,long Visit,long? Prescription,string Type,byte? Group,
    long Revision,long Account,long Actor,byte[] Pdf,string Hash);
public sealed class PdfKySoPreviewStore : IDisposable
{
    private readonly MemoryCache _cache=new(new MemoryCacheOptions { SizeLimit=64*1024*1024 });
    public string Add(PdfKySoPreview preview)
    {
        var key=Guid.NewGuid().ToString("N");
        _cache.Set(key,preview,new MemoryCacheEntryOptions { AbsoluteExpirationRelativeToNow=TimeSpan.FromMinutes(10),Size=preview.Pdf.Length });
        return key;
    }
    public PdfKySoPreview Get(string key,long tenant,long account,long actor)
    {
        if(!_cache.TryGetValue<PdfKySoPreview>(key,out var preview) || preview==null || preview.Tenant!=tenant || preview.Account!=account || preview.Actor!=actor)
            throw new ToaThuocInteroperabilityException(409,"Bản xem trước đã hết hạn hoặc không thuộc phiên này. Mở lại PDF trước khi ký.");
        return preview;
    }
    public void Dispose()=>_cache.Dispose();
}
public sealed record PdfKySoResult(long IdTaiLieu,string TrangThai);

public sealed class KySoPdfService
{
    private readonly QlpmDbContext _db;
    private readonly IPdfSigningProvider _provider;
    private readonly PdfKySoPreviewStore _previews;
    private readonly IKhamBenhPrintService? _printing;
    private readonly QlpmDocumentStorage _storage;
    public KySoPdfService(QlpmDbContext db,IPdfSigningProvider provider,PdfKySoPreviewStore previews,QlpmDocumentStorage storage,IKhamBenhPrintService? printing=null)
    { _db=db;_provider=provider;_previews=previews;_storage=storage;_printing=printing; }
    public static string Hash(byte[] pdf)=>Convert.ToHexString(SHA256.HashData(pdf)).ToLowerInvariant();
    public async Task<PdfKySoResult> KyToanBoAsync(long visit,string type,long tenant,long account,long actor,CancellationToken ct)
    {
        if(visit<=0 || type is not ("toa_thuoc" or "chi_dinh"))
            throw new ToaThuocInteroperabilityException(400,"Thiếu lượt khám hoặc loại tài liệu ký.");
        IDictionary<string,object?> existing=Dict((object?)await Business(()=>_db.LayMotDongStoAsync("dbo.STO_QL_KySoPdf_ToanBo_HienTai",new {
            IDCSKCB=tenant,IDVaoVien=visit,MaLoai=type,IDBacSi=actor,IDTaiKhoan=account
        })));
        // A second click opens the already signed revision without another
        // provider request. The STO still verifies current actor and ownership.
        if(existing.TryGetValue("IDTaiLieu",out var id) && id!=null)
        {
            var stored=Dict((object?)await _db.LayMotDongStoAsync("dbo.STO_QL_KySoPdf_TaiLieu_Lay",new {IDCSKCB=tenant,ID=Convert.ToInt64(id)}));
            if(!stored.TryGetValue("PdfDaKy",out var value) || value is not byte[] signedPdf)
                throw new ToaThuocInteroperabilityException(404,"Không tìm thấy PDF đã ký để lưu FTP.");
            await LuuFileDaKyAsync(tenant,signedPdf,ct);
            return new(Convert.ToInt64(id),"DA_KY");
        }
        var revision=await _db.QlVaoVien.AsNoTracking().Where(x=>x.Idcskcb==tenant && x.Id==visit)
            .Select(x=>x.PhienBanLamSang).SingleAsync(ct);
        if(_printing==null)throw new ToaThuocInteroperabilityException(503,"Chưa có dịch vụ dựng PDF ký.");
        var request=new QuanLyPhongMach.Models.Requests.KhamBenh.KhamBenhInRequest {
            nguon="da_luu",id_vao_vien=visit,gop_chi_dinh=false,ky_so=true
        };
        var pdf=type=="toa_thuoc"?await _printing.InToaThuocAsync(request,tenant,actor):await _printing.InChiDinhAsync(request,tenant,actor);
        if(pdf.Content.Length<8 || pdf.Content.Length>10*1024*1024)throw new ToaThuocInteroperabilityException(422,"PDF nguồn không hợp lệ hoặc vượt 10 MB.");
        var ticket=_previews.Add(new(tenant,visit,null,type,type=="chi_dinh"?(byte)2:null,revision,account,actor,pdf.Content,Hash(pdf.Content)));
        return await KyAsync(ticket,tenant,account,actor,ct);
    }
    public async Task<PdfKySoResult> KyAsync(string ticket,long tenant,long account,long actor,CancellationToken ct)
    {
        var source=_previews.Get(ticket,tenant,account,actor);
        var args=new { IDCSKCB=tenant,IDVaoVien=source.Visit,IDToaThuoc=source.Prescription,MaLoai=source.Type,NhomChiDinh=source.Group,IDBacSi=actor,IDTaiKhoan=account };
        await Business(()=>_db.ThucThiStoAsync("dbo.STO_QL_KySoPdf_KiemTra",args));
        var config=await _db.HtLienThongToaThuocCauHinh.AsNoTracking().SingleOrDefaultAsync(x=>x.Idcskcb==tenant,ct);
        if(config?.KySoHieuLuc!=true || !Uri.TryCreate(config.UrlKyPdf,UriKind.Absolute,out var uri) || uri.Scheme!=Uri.UriSchemeHttps || !string.IsNullOrEmpty(uri.UserInfo))
            throw new ToaThuocInteroperabilityException(503,"Chưa bật hoặc chưa cấu hình URL HTTPS ký PDF tại CSKCB.");
        var codes=await (from nv in _db.DmNhanVien.AsNoTracking() from cs in _db.DmCskcb.AsNoTracking()
            where nv.Id==actor && cs.Id==tenant select new { nv.MaNhanVien,cs.MaCskcb }).SingleAsync(ct);
        // The HisSoft provider's SM appearance is 140 x 45 PDF points. Locate
        // each reserved doctor block in the rendered PDF, after pagination.
        var positions=PdfSigningPositionLocator.Locate(source.Pdf,source.Type,140,45);
        IDictionary<string,object?> started=Dict((object?)await Business(()=>_db.LayMotDongStoAsync("dbo.STO_QL_KySoPdf_BatDau",new {
            args.IDCSKCB,args.IDVaoVien,args.IDToaThuoc,args.MaLoai,args.NhomChiDinh,args.IDBacSi,args.IDTaiKhoan,
            PhienBanLamSang=source.Revision,PdfNguon=source.Pdf,Sha256Nguon=source.Hash,
            ViTriKyJson=JsonSerializer.Serialize(positions),PhienBanMauKy=2
        })));
        var attempt=Convert.ToInt64(started["IDLanKy"]);
        PdfSigningResult signed=null!;
        var currentPdf=source.Pdf;var completed=0;var validResponseReceived=false;
        try
        {
            foreach(var position in positions)
            {
                signed=await _provider.KyPdfAsync(uri,new(currentPdf,codes.MaCskcb,codes.MaNhanVien,
                    position.Page,position.X,position.Y),ct);
                if(signed.PdfDaKy.AsSpan().SequenceEqual(currentPdf))
                    throw new ToaThuocInteroperabilityException(502,"Dịch vụ chưa thêm chữ ký tại ô được yêu cầu.");
                if(completed>0 && (signed.PdfDaKy.Length<=currentPdf.Length ||
                    !signed.PdfDaKy.AsSpan(0,currentPdf.Length).SequenceEqual(currentPdf)))
                    throw new ToaThuocInteroperabilityException(502,"Dịch vụ không giữ nguyên chữ ký của các phiếu trước; chưa hoàn tất ký toàn bộ.");
                signed=signed with { SerialChungThu=PdfSignatureVerifier.Verify(signed.PdfDaKy) };
                validResponseReceived=true;
                currentPdf=signed.PdfDaKy;
                await Business(()=>_db.ThucThiStoAsync("dbo.STO_QL_KySoPdf_TienDo",new {
                    IDCSKCB=tenant,IDLanKy=attempt,SoViTriDaKy=++completed,
                    PdfDangKy=currentPdf,Sha256DangKy=Hash(currentPdf)
                }));
            }
        }
        catch(Exception ex)
        {
            // If a later block fails, retain the partial signed PDF and block
            // blind retries. Do not present it as a fully signed document.
            var unknown=validResponseReceived || ex is OperationCanceledException or HttpRequestException;
            await Business(()=>_db.LayMotDongStoAsync("dbo.STO_QL_KySoPdf_KetQua",new {
                IDCSKCB=tenant,IDLanKy=attempt,TrangThai=unknown?"KHONG_RO_KET_QUA":"LOI_KY",MaKetQua=unknown?"NETWORK_UNKNOWN":"PROVIDER_ERROR"
            }));
            if(unknown)throw new ToaThuocInteroperabilityException(504,"Lần ký chưa hoàn tất hoặc chưa rõ kết quả; có thể đã ký một phần. Không tự gửi lại, cần đối soát lần ký.");
            if(ex is ToaThuocInteroperabilityException)throw;
            throw new ToaThuocInteroperabilityException(502,"Dịch vụ ký không trả kết quả PDF hợp lệ.");
        }
        IDictionary<string,object?> saved=Dict((object?)await Business(()=>_db.LayMotDongStoAsync("dbo.STO_QL_KySoPdf_KetQua",new {
            IDCSKCB=tenant,IDLanKy=attempt,TrangThai="THANH_CONG",MaKetQua="SIGNED",PdfDaKy=signed.PdfDaKy,
            Sha256DaKy=Hash(signed.PdfDaKy),NhaCungCap=signed.NhaCungCap,SerialChungThu=signed.SerialChungThu,MaHoSo=signed.MaHoSo
        })));
        // Retain the verified artifact before FTP I/O so an FTP failure can be
        // retried by uploading these exact bytes, without signing again.
        // The signing API only returns success once the FTP file is uploaded.
        await LuuFileDaKyAsync(tenant,signed.PdfDaKy,ct);
        return new(Convert.ToInt64(saved["IDTaiLieu"]),Convert.ToString(saved["TrangThaiTaiLieu"])!);
    }
    private async Task LuuFileDaKyAsync(long tenant,byte[] pdf,CancellationToken ct)
    {
        try { await _storage.SaveSignedPdfAsync(tenant,pdf,ct); }
        catch(Exception ex) when(ex is IOException or System.Net.WebException)
        {
            throw new ToaThuocInteroperabilityException(503,"PDF đã ký được lưu nhưng chưa tải lên FTP. Kiểm tra FTP rồi bấm Ký số lại để tải file lên, không ký trùng.");
        }
    }
    private static IDictionary<string,object?> Dict(object? row)=>row as IDictionary<string,object?> ?? new Dictionary<string,object?>();
    public static async Task<T> Business<T>(Func<Task<T>> action)
    {
        try{return await action();}
        catch(SqlException ex) when(ex.Number is >=59300 and <=59304)
        {throw new ToaThuocInteroperabilityException(ex.Number switch {59301=>403,59302=>404,59303=>422,59304=>409,_=>503},ex.Message);}
    }
}
