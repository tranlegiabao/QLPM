:ON ERROR EXIT
USE [QLPM];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO
IF OBJECT_ID(N'dbo.QL_KySoPdf_TaiLieu',N'U') IS NULL
    THROW 59300,N'Can schema ky PDF v107 truoc khi nang cap v109.',1;
GO
IF OBJECT_ID(N'dbo.QL_KySoPdf_LanKy',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.QL_KySoPdf_LanKy(
        ID BIGINT IDENTITY PRIMARY KEY,IDCSKCB BIGINT NOT NULL,IDVaoVien BIGINT NOT NULL,
        IDToaThuoc BIGINT NULL,MaLoai NVARCHAR(30) NOT NULL,NhomChiDinh TINYINT NULL,
        PhienBanLamSang BIGINT NOT NULL,PdfNguon VARBINARY(MAX) NOT NULL,Sha256Nguon CHAR(64) NOT NULL,
        IDBacSiKy BIGINT NOT NULL,IDTaiKhoanKy BIGINT NOT NULL,TrangThai NVARCHAR(30) NOT NULL DEFAULT N'DANG_KY',
        IDTaiLieu BIGINT NULL,MaKetQua NVARCHAR(60) NULL,NgayTao DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),KetThucLuc DATETIME2(0) NULL,
        CONSTRAINT FK_QL_KSP_LK_Luot FOREIGN KEY(IDCSKCB,IDVaoVien) REFERENCES dbo.QL_VaoVien(IDCSKCB,ID),
        CONSTRAINT FK_QL_KSP_LK_Toa FOREIGN KEY(IDCSKCB,IDToaThuoc) REFERENCES dbo.QL_ToaThuoc(IDCSKCB,ID),
        CONSTRAINT FK_QL_KSP_LK_BS FOREIGN KEY(IDBacSiKy) REFERENCES dbo.DM_NhanVien(ID),
        CONSTRAINT FK_QL_KSP_LK_TK FOREIGN KEY(IDTaiKhoanKy) REFERENCES dbo.HT_Tai_Khoan(ID),
        CONSTRAINT FK_QL_KSP_LK_TL FOREIGN KEY(IDTaiLieu) REFERENCES dbo.QL_KySoPdf_TaiLieu(ID),
        CONSTRAINT CK_QL_KSP_LK_State CHECK(TrangThai IN(N'DANG_KY',N'THANH_CONG',N'LOI_KY',N'KHONG_RO_KET_QUA')),
        CONSTRAINT CK_QL_KSP_LK_Document CHECK((MaLoai=N'toa_thuoc' AND IDToaThuoc IS NOT NULL AND NhomChiDinh IS NULL)
            OR (MaLoai=N'chi_dinh' AND IDToaThuoc IS NULL AND NhomChiDinh IS NOT NULL AND NhomChiDinh IN(0,1))),
        CONSTRAINT CK_QL_KSP_LK_Source CHECK(DATALENGTH(PdfNguon) BETWEEN 8 AND 10485760)
    );
    CREATE INDEX IX_QL_KSP_LK_Luot ON dbo.QL_KySoPdf_LanKy(IDCSKCB,IDVaoVien,ID DESC);
END;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_KySoPdf_KiemTra
 @IDCSKCB BIGINT,@IDVaoVien BIGINT,@IDToaThuoc BIGINT=NULL,@MaLoai NVARCHAR(30),@NhomChiDinh TINYINT=NULL,
 @IDBacSi BIGINT,@IDTaiKhoan BIGINT
AS
BEGIN
 SET NOCOUNT ON;
 IF @MaLoai NOT IN(N'toa_thuoc',N'chi_dinh') OR @MaLoai IS NULL
    OR (@MaLoai=N'chi_dinh' AND (@NhomChiDinh IS NULL OR @NhomChiDinh NOT IN(0,1) OR @IDToaThuoc IS NOT NULL))
    OR (@MaLoai=N'toa_thuoc' AND (@IDToaThuoc IS NULL OR @NhomChiDinh IS NOT NULL))
    THROW 59303,N'Tai lieu ky khong hop le.',1;
 DECLARE @Function NVARCHAR(100)=CASE WHEN @MaLoai=N'toa_thuoc' THEN N'lien_thong_toa_thuoc' ELSE N'kham_benh' END;
 -- Global administrators may view/configure; they may never impersonate a doctor.
 IF NOT EXISTS(SELECT 1 FROM dbo.HT_Tai_Khoan T JOIN dbo.DM_NhanVien N ON N.ID=T.IDNhanVien
    JOIN dbo.DM_NhanVien_CSKCB M ON M.IDNhanVien=N.ID AND M.IDCSKCB=T.IDCSKCB AND M.Active=1
    WHERE T.ID=@IDTaiKhoan AND T.IDCSKCB=@IDCSKCB AND T.Active=1 AND T.LaQuanTriHeThong=0
      AND T.IDNhanVien=@IDBacSi AND N.Active=1 AND N.LaBacSi=1
      AND EXISTS(SELECT 1 FROM dbo.HT_Tai_Khoan_Vai_Tro TV
        JOIN dbo.DM_Vai_Tro V ON V.ID=TV.ID_Vai_Tro AND V.IDCSKCB=TV.IDCSKCB AND V.Active=1
        JOIN dbo.HT_Quyen_Vai_Tro Q ON Q.IDCSKCB=TV.IDCSKCB AND Q.ID_Vai_Tro=TV.ID_Vai_Tro AND Q.Sua=1
        JOIN dbo.HT_Chuc_Nang F ON F.IDCSKCB=Q.IDCSKCB AND F.ID=Q.ID_Chuc_Nang AND F.Active=1
        WHERE TV.IDCSKCB=@IDCSKCB AND TV.ID_Tai_Khoan=T.ID AND TV.Active=1 AND F.Ma_Chuc_Nang=@Function))
    THROW 59301,N'Chi tai khoan bac si co quyen Sua tai co so moi duoc ky.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.QL_VaoVien WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien AND Active=1)
    THROW 59302,N'Khong tim thay luot kham tai co so.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.QL_VaoVien WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien AND TrangThaiKham=2)
    THROW 59303,N'Phai Kham xong truoc khi ky PDF.',1;
 IF @MaLoai=N'toa_thuoc'
 BEGIN
    IF NOT EXISTS(SELECT 1 FROM dbo.QL_ToaThuoc WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND ID=@IDToaThuoc)
        THROW 59302,N'Toa thuoc khong thuoc luot kham/co so.',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.QL_ToaThuoc WHERE IDCSKCB=@IDCSKCB AND ID=@IDToaThuoc AND IDBacSiKe=@IDBacSi)
        THROW 59301,N'Khong duoc ky thay bac si ke toa.',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.QL_ToaThuoc_CT WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND IDToaThuoc=@IDToaThuoc AND Active=1)
        THROW 59303,N'Toa thuoc khong co dong thuoc.',1;
 END
 ELSE
 BEGIN
    IF NOT EXISTS(SELECT 1 FROM dbo.QL_VaoVien WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien AND IDBacSiKham=@IDBacSi)
        THROW 59301,N'Khong duoc ky thay bac si kham.',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.QL_ChiDinh_CT WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND Active=1 AND GuiNgoai=@NhomChiDinh)
        THROW 59303,N'Khong co chi dinh thuoc nhom da chon.',1;
    IF EXISTS(SELECT 1 FROM dbo.QL_ChiDinh_CT WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND Active=1 AND GuiNgoai=@NhomChiDinh AND ISNULL(IDBacSiChiDinh,0)<>@IDBacSi)
        THROW 59301,N'Phieu co chi dinh cua bac si khac; khong duoc ky thay.',1;
 END;
END;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_KySoPdf_BatDau
 @IDCSKCB BIGINT,@IDVaoVien BIGINT,@IDToaThuoc BIGINT=NULL,@MaLoai NVARCHAR(30),@NhomChiDinh TINYINT=NULL,
 @IDBacSi BIGINT,@IDTaiKhoan BIGINT,@PhienBanLamSang BIGINT,@PdfNguon VARBINARY(MAX),@Sha256Nguon CHAR(64)
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 BEGIN TRANSACTION;
 BEGIN TRY
    DECLARE @Revision BIGINT;
    SELECT @Revision=PhienBanLamSang FROM dbo.QL_VaoVien WITH(UPDLOCK,HOLDLOCK) WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien;
    EXEC dbo.STO_QL_KySoPdf_KiemTra @IDCSKCB,@IDVaoVien,@IDToaThuoc,@MaLoai,@NhomChiDinh,@IDBacSi,@IDTaiKhoan;
    IF @Revision IS NULL OR @PhienBanLamSang IS NULL OR @Revision<>@PhienBanLamSang
        THROW 59304,N'Ho so vua thay doi; xem lai PDF truoc khi ky.',1;
    IF @PdfNguon IS NULL OR DATALENGTH(@PdfNguon) NOT BETWEEN 8 AND 10485760
        OR @Sha256Nguon IS NULL OR LOWER(CONVERT(CHAR(64),HASHBYTES('SHA2_256',@PdfNguon),2))<>LOWER(@Sha256Nguon)
        THROW 59303,N'PDF nguon/hash khong hop le.',1;
    IF EXISTS(SELECT 1 FROM dbo.QL_KySoPdf_LanKy WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND MaLoai=@MaLoai
        AND ISNULL(IDToaThuoc,0)=ISNULL(@IDToaThuoc,0) AND ISNULL(NhomChiDinh,2)=ISNULL(@NhomChiDinh,2)
        AND TrangThai IN(N'DANG_KY',N'KHONG_RO_KET_QUA'))
        THROW 59304,N'Tai lieu dang ky hoac chua ro ket qua; khong gui ky trung.',1;
    IF EXISTS(SELECT 1 FROM dbo.QL_KySoPdf_TaiLieu WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND MaLoai=@MaLoai
        AND ISNULL(IDToaThuoc,0)=ISNULL(@IDToaThuoc,0) AND ISNULL(NhomChiDinh,2)=ISNULL(@NhomChiDinh,2)
        AND PhienBanLamSang=@Revision AND TrangThai=N'DA_KY')
        THROW 59304,N'Ban PDF nay da duoc ky; hay mo ban da ky.',1;
    INSERT dbo.QL_KySoPdf_LanKy(IDCSKCB,IDVaoVien,IDToaThuoc,MaLoai,NhomChiDinh,PhienBanLamSang,PdfNguon,Sha256Nguon,IDBacSiKy,IDTaiKhoanKy)
        VALUES(@IDCSKCB,@IDVaoVien,@IDToaThuoc,@MaLoai,@NhomChiDinh,@Revision,@PdfNguon,@Sha256Nguon,@IDBacSi,@IDTaiKhoan);
    DECLARE @ID BIGINT=SCOPE_IDENTITY();
    INSERT dbo.QL_KySoPdf_Audit(IDCSKCB,IDVaoVien,MaLoai,HanhDong,IDNhanVien,IDTaiKhoan,Sha256Pdf)
        VALUES(@IDCSKCB,@IDVaoVien,@MaLoai,N'BAT_DAU_KY',@IDBacSi,@IDTaiKhoan,@Sha256Nguon);
    COMMIT;SELECT @ID AS IDLanKy;
 END TRY
 BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK;THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_KySoPdf_KetQua
 @IDCSKCB BIGINT,@IDLanKy BIGINT,@TrangThai NVARCHAR(30),@MaKetQua NVARCHAR(60),
 @PdfDaKy VARBINARY(MAX)=NULL,@Sha256DaKy CHAR(64)=NULL,@NhaCungCap NVARCHAR(120)=NULL,@SerialChungThu NVARCHAR(200)=NULL,@MaHoSo NVARCHAR(200)=NULL
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @TrangThai IS NULL OR @TrangThai NOT IN(N'THANH_CONG',N'LOI_KY',N'KHONG_RO_KET_QUA') THROW 59303,N'Ket qua ky khong hop le.',1;
 DECLARE @Visit BIGINT;
 SELECT @Visit=IDVaoVien FROM dbo.QL_KySoPdf_LanKy WHERE IDCSKCB=@IDCSKCB AND ID=@IDLanKy;
 IF @Visit IS NULL THROW 59302,N'Khong tim thay lan ky.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
    DECLARE @Revision BIGINT,@SourceRevision BIGINT,@Loai NVARCHAR(30),@Toa BIGINT,@Nhom TINYINT,@BacSi BIGINT,@Account BIGINT,@State NVARCHAR(30),@Document BIGINT=NULL;
    SELECT @Revision=PhienBanLamSang FROM dbo.QL_VaoVien WITH(UPDLOCK,HOLDLOCK) WHERE IDCSKCB=@IDCSKCB AND ID=@Visit;
    SELECT @SourceRevision=PhienBanLamSang,@Loai=MaLoai,@Toa=IDToaThuoc,@Nhom=NhomChiDinh,@BacSi=IDBacSiKy,@Account=IDTaiKhoanKy,@State=TrangThai
        FROM dbo.QL_KySoPdf_LanKy WITH(UPDLOCK,HOLDLOCK) WHERE IDCSKCB=@IDCSKCB AND ID=@IDLanKy;
    IF @State<>N'DANG_KY' THROW 59304,N'Lan ky da duoc ghi ket qua.',1;
    IF @TrangThai=N'THANH_CONG'
    BEGIN
        IF @PdfDaKy IS NULL OR DATALENGTH(@PdfDaKy) NOT BETWEEN 8 AND 10485760 OR NULLIF(@SerialChungThu,N'') IS NULL
            OR @Sha256DaKy IS NULL OR LOWER(CONVERT(CHAR(64),HASHBYTES('SHA2_256',@PdfDaKy),2))<>LOWER(@Sha256DaKy)
            THROW 59303,N'Artifact ky PDF khong hop le.',1;
        DECLARE @Version INT=(SELECT ISNULL(MAX(SoPhienBan),0)+1 FROM dbo.QL_KySoPdf_TaiLieu
            WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@Visit AND MaLoai=@Loai AND ISNULL(IDToaThuoc,0)=ISNULL(@Toa,0) AND ISNULL(NhomChiDinh,2)=ISNULL(@Nhom,2));
        UPDATE dbo.QL_KySoPdf_TaiLieu SET TrangThai=N'HET_HIEU_LUC' WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@Visit AND MaLoai=@Loai
            AND ISNULL(IDToaThuoc,0)=ISNULL(@Toa,0) AND ISNULL(NhomChiDinh,2)=ISNULL(@Nhom,2) AND TrangThai=N'DA_KY';
        INSERT dbo.QL_KySoPdf_TaiLieu(IDCSKCB,IDVaoVien,IDToaThuoc,MaLoai,NhomChiDinh,SoPhienBan,PhienBanLamSang,TrangThai,
            PdfNguon,PdfDaKy,Sha256Nguon,Sha256DaKy,NhaCungCapKy,SerialChungThu,MaHoSoKy,NgayKy,IDBacSiKy,IDTaiKhoanKy)
        SELECT IDCSKCB,IDVaoVien,IDToaThuoc,MaLoai,NhomChiDinh,@Version,PhienBanLamSang,
            CASE WHEN @Revision=@SourceRevision THEN N'DA_KY' ELSE N'HET_HIEU_LUC' END,
            PdfNguon,@PdfDaKy,Sha256Nguon,@Sha256DaKy,@NhaCungCap,@SerialChungThu,@MaHoSo,SYSDATETIME(),IDBacSiKy,IDTaiKhoanKy
        FROM dbo.QL_KySoPdf_LanKy WHERE IDCSKCB=@IDCSKCB AND ID=@IDLanKy;
        SET @Document=SCOPE_IDENTITY();
    END;
    UPDATE dbo.QL_KySoPdf_LanKy SET TrangThai=@TrangThai,MaKetQua=@MaKetQua,IDTaiLieu=@Document,KetThucLuc=SYSDATETIME()
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDLanKy;
    INSERT dbo.QL_KySoPdf_Audit(IDCSKCB,IDVaoVien,MaLoai,HanhDong,IDTaiLieu,IDNhanVien,IDTaiKhoan,MaKetQua,Sha256Pdf)
        VALUES(@IDCSKCB,@Visit,@Loai,N'KET_QUA_KY',@Document,@BacSi,@Account,@MaKetQua,@Sha256DaKy);
    COMMIT;SELECT @Document AS IDTaiLieu,CASE WHEN @Revision=@SourceRevision THEN N'DA_KY' ELSE N'HET_HIEU_LUC' END AS TrangThaiTaiLieu;
 END TRY
 BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK;THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_KySoPdf_CauHinh_Luu
 @IDCSKCB BIGINT,@IDTaiKhoan BIGINT,@HieuLuc BIT,@UrlKyPdf NVARCHAR(500)
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF NOT EXISTS(SELECT 1 FROM dbo.HT_Tai_Khoan WHERE ID=@IDTaiKhoan AND Active=1 AND LaQuanTriHeThong=1)
    THROW 59301,N'Chi quan tri he thong duoc cau hinh dich vu ky.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.DM_CSKCB WHERE ID=@IDCSKCB AND Active=1) THROW 59302,N'Co so khong hop le.',1;
 IF @HieuLuc=1 AND (NULLIF(LTRIM(RTRIM(@UrlKyPdf)),N'') IS NULL OR @UrlKyPdf NOT LIKE N'https://%')
    THROW 59303,N'Can URL HTTPS dich vu ky PDF.',1;
 BEGIN TRANSACTION;
 IF NOT EXISTS(SELECT 1 FROM dbo.HT_LienThongToaThuoc_CauHinh WITH(UPDLOCK,HOLDLOCK) WHERE IDCSKCB=@IDCSKCB)
    INSERT dbo.HT_LienThongToaThuoc_CauHinh(IDCSKCB) VALUES(@IDCSKCB);
 UPDATE dbo.HT_LienThongToaThuoc_CauHinh SET KySoHieuLuc=@HieuLuc,UrlKyPdf=NULLIF(LTRIM(RTRIM(@UrlKyPdf)),N''),NgayCapNhat=SYSDATETIME(),IDTaiKhoanCapNhat=@IDTaiKhoan WHERE IDCSKCB=@IDCSKCB;
 INSERT dbo.QL_ToaThuoc_Audit(IDCSKCB,HanhDong,IDTaiKhoan) VALUES(@IDCSKCB,N'CAU_HINH_KY_PDF',@IDTaiKhoan);
 COMMIT;
END;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_KySoPdf_TaiLieu_DanhSach @IDCSKCB BIGINT,@IDVaoVien BIGINT
AS
BEGIN
 SET NOCOUNT ON;
 SELECT T.ID AS id,T.IDToaThuoc AS id_toa_thuoc,T.MaLoai AS ma_loai,T.NhomChiDinh AS nhom_chi_dinh,T.SoPhienBan AS so_phien_ban,
    CASE WHEN V.PhienBanLamSang=T.PhienBanLamSang THEN T.TrangThai ELSE N'HET_HIEU_LUC' END AS trang_thai,
    T.NgayKy AS ngay_ky,T.IDBacSiKy AS id_bac_si,T.SerialChungThu AS serial_chung_thu
 FROM dbo.QL_KySoPdf_TaiLieu T JOIN dbo.QL_VaoVien V ON V.IDCSKCB=T.IDCSKCB AND V.ID=T.IDVaoVien
 WHERE T.IDCSKCB=@IDCSKCB AND T.IDVaoVien=@IDVaoVien ORDER BY T.ID DESC;
END;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_KySoPdf_TaiLieu_Lay @IDCSKCB BIGINT,@ID BIGINT
AS
BEGIN
 SET NOCOUNT ON;
 SELECT T.PdfDaKy,CASE WHEN V.PhienBanLamSang=T.PhienBanLamSang THEN T.TrangThai ELSE N'HET_HIEU_LUC' END AS TrangThai
 FROM dbo.QL_KySoPdf_TaiLieu T JOIN dbo.QL_VaoVien V ON V.IDCSKCB=T.IDCSKCB AND V.ID=T.IDVaoVien
 WHERE T.IDCSKCB=@IDCSKCB AND T.ID=@ID;
END;
GO
PRINT N'50_ky_so_pdf_nghiep_vu_v109.sql: OK; no signing HTTP requests.';
GO
