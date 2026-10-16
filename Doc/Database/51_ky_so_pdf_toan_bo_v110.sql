:ON ERROR EXIT
USE [QLPM];
GO
SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;SET NOCOUNT ON;
GO
IF OBJECT_ID(N'dbo.QL_KySoPdf_LanKy',N'U') IS NULL THROW 59300,N'Can schema ky PDF v109.',1;
GO
-- NULL prescription means the complete saved prescription PDF for the visit.
-- Group 2 means both internal and external orders, still rendered separately.
IF EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.QL_KySoPdf_LanKy') AND name=N'CK_QL_KSP_LK_Document')
 ALTER TABLE dbo.QL_KySoPdf_LanKy DROP CONSTRAINT CK_QL_KSP_LK_Document;
ALTER TABLE dbo.QL_KySoPdf_LanKy WITH CHECK ADD CONSTRAINT CK_QL_KSP_LK_Document
 CHECK((MaLoai=N'toa_thuoc' AND NhomChiDinh IS NULL)
 OR (MaLoai=N'chi_dinh' AND IDToaThuoc IS NULL AND NhomChiDinh IS NOT NULL AND NhomChiDinh IN(0,1,2)));
GO
IF EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.QL_KySoPdf_TaiLieu') AND name=N'CK_QL_KySoPdf_TL_Nhom')
 ALTER TABLE dbo.QL_KySoPdf_TaiLieu DROP CONSTRAINT CK_QL_KySoPdf_TL_Nhom;
ALTER TABLE dbo.QL_KySoPdf_TaiLieu WITH CHECK ADD CONSTRAINT CK_QL_KySoPdf_TL_Nhom
 CHECK((MaLoai=N'toa_thuoc' AND NhomChiDinh IS NULL)
 OR (MaLoai=N'chi_dinh' AND IDToaThuoc IS NULL AND NhomChiDinh IS NOT NULL AND NhomChiDinh IN(0,1,2)));
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_KySoPdf_KiemTra
 @IDCSKCB BIGINT,@IDVaoVien BIGINT,@IDToaThuoc BIGINT=NULL,@MaLoai NVARCHAR(30),@NhomChiDinh TINYINT=NULL,
 @IDBacSi BIGINT,@IDTaiKhoan BIGINT
AS
BEGIN
 SET NOCOUNT ON;
 IF @MaLoai NOT IN(N'toa_thuoc',N'chi_dinh') OR @MaLoai IS NULL
    OR (@MaLoai=N'chi_dinh' AND (@NhomChiDinh IS NULL OR @NhomChiDinh NOT IN(0,1,2) OR @IDToaThuoc IS NOT NULL))
    OR (@MaLoai=N'toa_thuoc' AND @NhomChiDinh IS NOT NULL)
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
 IF @MaLoai=N'toa_thuoc' AND @IDToaThuoc IS NOT NULL
 BEGIN
    IF NOT EXISTS(SELECT 1 FROM dbo.QL_ToaThuoc WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND ID=@IDToaThuoc)
        THROW 59302,N'Toa thuoc khong thuoc luot kham/co so.',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.QL_ToaThuoc WHERE IDCSKCB=@IDCSKCB AND ID=@IDToaThuoc AND IDBacSiKe=@IDBacSi)
        THROW 59301,N'Khong duoc ky thay bac si ke toa.',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.QL_ToaThuoc_CT WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND IDToaThuoc=@IDToaThuoc AND Active=1)
        THROW 59303,N'Toa thuoc khong co dong thuoc.',1;
 END
 ELSE IF @MaLoai=N'toa_thuoc'
 BEGIN
    IF NOT EXISTS(SELECT 1 FROM dbo.QL_ToaThuoc_CT WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND Active=1)
        THROW 59303,N'Khong co thuoc da luu de ky.',1;
    IF EXISTS(SELECT 1 FROM dbo.QL_ToaThuoc_CT D LEFT JOIN dbo.QL_ToaThuoc H ON H.IDCSKCB=D.IDCSKCB AND H.ID=D.IDToaThuoc
        WHERE D.IDCSKCB=@IDCSKCB AND D.IDVaoVien=@IDVaoVien AND D.Active=1
        AND (H.ID IS NULL OR H.IDVaoVien<>@IDVaoVien OR H.IDBacSiKe<>@IDBacSi OR ISNULL(D.IDBacSiKe,0)<>@IDBacSi))
        THROW 59301,N'Luot co toa cua bac si khac; khong duoc ky thay.',1;
 END
 ELSE
 BEGIN
    IF NOT EXISTS(SELECT 1 FROM dbo.QL_VaoVien WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien AND IDBacSiKham=@IDBacSi)
        THROW 59301,N'Khong duoc ky thay bac si kham.',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.QL_ChiDinh_CT WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND Active=1 AND (@NhomChiDinh=2 OR GuiNgoai=@NhomChiDinh))
        THROW 59303,N'Khong co chi dinh thuoc nhom da chon.',1;
    IF EXISTS(SELECT 1 FROM dbo.QL_ChiDinh_CT WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND Active=1 AND (@NhomChiDinh=2 OR GuiNgoai=@NhomChiDinh) AND ISNULL(IDBacSiChiDinh,0)<>@IDBacSi)
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
        AND ((@MaLoai=N'toa_thuoc' AND (@IDToaThuoc IS NULL OR IDToaThuoc IS NULL OR IDToaThuoc=@IDToaThuoc))
          OR (@MaLoai=N'chi_dinh' AND (@NhomChiDinh=2 OR NhomChiDinh=2 OR NhomChiDinh=@NhomChiDinh)))
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
CREATE OR ALTER PROCEDURE dbo.STO_QL_KySoPdf_ToanBo_HienTai
 @IDCSKCB BIGINT,@IDVaoVien BIGINT,@MaLoai NVARCHAR(30),@IDBacSi BIGINT,@IDTaiKhoan BIGINT
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @Nhom TINYINT=CASE WHEN @MaLoai=N'chi_dinh' THEN 2 ELSE NULL END;
 EXEC dbo.STO_QL_KySoPdf_KiemTra @IDCSKCB,@IDVaoVien,NULL,@MaLoai,@Nhom,@IDBacSi,@IDTaiKhoan;
 SELECT TOP(1) T.ID AS IDTaiLieu,T.TrangThai AS TrangThaiTaiLieu
 FROM dbo.QL_KySoPdf_TaiLieu T JOIN dbo.QL_VaoVien V ON V.IDCSKCB=T.IDCSKCB AND V.ID=T.IDVaoVien
 WHERE T.IDCSKCB=@IDCSKCB AND T.IDVaoVien=@IDVaoVien AND T.MaLoai=@MaLoai AND T.IDToaThuoc IS NULL
 AND ISNULL(T.NhomChiDinh,2)=ISNULL(@Nhom,2) AND T.TrangThai=N'DA_KY' AND T.PhienBanLamSang=V.PhienBanLamSang
 ORDER BY T.ID DESC;
END;
GO
PRINT N'51_ky_so_pdf_toan_bo_v110.sql: OK; no signing HTTP requests.';
GO
