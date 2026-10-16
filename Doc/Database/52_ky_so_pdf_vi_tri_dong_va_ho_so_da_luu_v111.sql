:ON ERROR EXIT
USE [QLPM];
GO
SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;SET NOCOUNT ON;
GO
IF OBJECT_ID(N'dbo.QL_KySoPdf_LanKy',N'U') IS NULL THROW 59300,N'Can schema ky PDF v110.',1;
IF COL_LENGTH(N'dbo.QL_KySoPdf_LanKy',N'ViTriKyJson') IS NULL
 ALTER TABLE dbo.QL_KySoPdf_LanKy ADD ViTriKyJson NVARCHAR(MAX) NULL,PhienBanMauKy INT NOT NULL CONSTRAINT DF_KSP_LK_Mau DEFAULT 1,
 PdfDangKy VARBINARY(MAX) NULL,Sha256DangKy CHAR(64) NULL,SoViTriDaKy INT NOT NULL CONSTRAINT DF_KSP_LK_TienDo DEFAULT 0;
IF COL_LENGTH(N'dbo.QL_KySoPdf_TaiLieu',N'PhienBanMauKy') IS NULL
 ALTER TABLE dbo.QL_KySoPdf_TaiLieu ADD PhienBanMauKy INT NOT NULL CONSTRAINT DF_KSP_TL_Mau DEFAULT 1;
GO
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE name=N'CK_KSP_LK_TienDo')
 ALTER TABLE dbo.QL_KySoPdf_LanKy WITH CHECK ADD CONSTRAINT CK_KSP_LK_TienDo CHECK(SoViTriDaKy BETWEEN 0 AND 100
 AND (ViTriKyJson IS NULL OR ISJSON(ViTriKyJson)=1) AND PhienBanMauKy IN(1,2)
 AND (SoViTriDaKy=0 OR (PdfDangKy IS NOT NULL AND Sha256DangKy IS NOT NULL AND DATALENGTH(PdfDangKy) BETWEEN 8 AND 10485760)));
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
 -- Saved rows below are required; finishing the visit is not required.
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
 @IDBacSi BIGINT,@IDTaiKhoan BIGINT,@PhienBanLamSang BIGINT,@PdfNguon VARBINARY(MAX),@Sha256Nguon CHAR(64),
 @ViTriKyJson NVARCHAR(MAX)=NULL,@PhienBanMauKy INT=1
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
    IF @PhienBanMauKy<>2 OR ISJSON(@ViTriKyJson)<>1 OR @ViTriKyJson IS NULL
        THROW 59303,N'Can vi tri ky tu PDF da dung; khong dung toa do co dinh.',1;
    IF (SELECT COUNT(*) FROM OPENJSON(@ViTriKyJson)) NOT BETWEEN 1 AND 100
       OR EXISTS(SELECT 1 FROM OPENJSON(@ViTriKyJson) WITH(Page INT,X DECIMAL(18,2),Y DECIMAL(18,2),Width DECIMAL(18,2),Height DECIMAL(18,2))
          WHERE Page IS NULL OR Page<1 OR X IS NULL OR X<0 OR Y IS NULL OR Y<0 OR Width IS NULL OR Width<>140 OR Height IS NULL OR Height<>45)
        THROW 59303,N'Vi tri ky PDF khong hop le.',1;
    IF EXISTS(SELECT 1 FROM dbo.QL_KySoPdf_LanKy WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND MaLoai=@MaLoai
        AND ((@MaLoai=N'toa_thuoc' AND (@IDToaThuoc IS NULL OR IDToaThuoc IS NULL OR IDToaThuoc=@IDToaThuoc))
          OR (@MaLoai=N'chi_dinh' AND (@NhomChiDinh=2 OR NhomChiDinh=2 OR NhomChiDinh=@NhomChiDinh)))
        AND TrangThai IN(N'DANG_KY',N'KHONG_RO_KET_QUA'))
        THROW 59304,N'Tai lieu dang ky hoac chua ro ket qua; khong gui ky trung.',1;
    IF EXISTS(SELECT 1 FROM dbo.QL_KySoPdf_TaiLieu WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND MaLoai=@MaLoai
        AND ISNULL(IDToaThuoc,0)=ISNULL(@IDToaThuoc,0) AND ISNULL(NhomChiDinh,2)=ISNULL(@NhomChiDinh,2)
        AND PhienBanLamSang=@Revision AND TrangThai=N'DA_KY' AND PhienBanMauKy=@PhienBanMauKy)
        THROW 59304,N'Ban PDF nay da duoc ky; hay mo ban da ky.',1;
    INSERT dbo.QL_KySoPdf_LanKy(IDCSKCB,IDVaoVien,IDToaThuoc,MaLoai,NhomChiDinh,PhienBanLamSang,PdfNguon,Sha256Nguon,IDBacSiKy,IDTaiKhoanKy,ViTriKyJson,PhienBanMauKy)
        VALUES(@IDCSKCB,@IDVaoVien,@IDToaThuoc,@MaLoai,@NhomChiDinh,@Revision,@PdfNguon,@Sha256Nguon,@IDBacSi,@IDTaiKhoan,@ViTriKyJson,@PhienBanMauKy);
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
 AND ISNULL(T.NhomChiDinh,2)=ISNULL(@Nhom,2) AND T.TrangThai=N'DA_KY' AND T.PhienBanMauKy=2 AND T.PhienBanLamSang=V.PhienBanLamSang
 ORDER BY T.ID DESC;
END;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_KySoPdf_TienDo
 @IDCSKCB BIGINT,@IDLanKy BIGINT,@SoViTriDaKy INT,@PdfDangKy VARBINARY(MAX),@Sha256DangKy CHAR(64)
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @PdfDangKy IS NULL OR DATALENGTH(@PdfDangKy) NOT BETWEEN 8 AND 10485760 OR @Sha256DangKy IS NULL
 OR LOWER(CONVERT(CHAR(64),HASHBYTES('SHA2_256',@PdfDangKy),2))<>LOWER(@Sha256DangKy)
    THROW 59303,N'PDF tien do/hash khong hop le.',1;
 UPDATE dbo.QL_KySoPdf_LanKy SET PdfDangKy=@PdfDangKy,Sha256DangKy=@Sha256DangKy,SoViTriDaKy=@SoViTriDaKy
 WHERE IDCSKCB=@IDCSKCB AND ID=@IDLanKy AND TrangThai=N'DANG_KY' AND PhienBanMauKy=2
 AND SoViTriDaKy+1=@SoViTriDaKy AND @SoViTriDaKy<=(SELECT COUNT(*) FROM OPENJSON(ViTriKyJson));
 IF @@ROWCOUNT<>1 THROW 59304,N'Tien do ky khong hop le hoac lan ky da ket thuc.',1;
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
    IF @TrangThai=N'LOI_KY' AND EXISTS(SELECT 1 FROM dbo.QL_KySoPdf_LanKy WHERE ID=@IDLanKy AND IDCSKCB=@IDCSKCB AND SoViTriDaKy>0)
        THROW 59304,N'Lan ky da co PDF ky mot phan; phai doi soat, khong ky lai mu.',1;
    IF @TrangThai=N'THANH_CONG'
    BEGIN
        IF NOT EXISTS(SELECT 1 FROM dbo.QL_KySoPdf_LanKy WHERE IDCSKCB=@IDCSKCB AND ID=@IDLanKy AND PhienBanMauKy=2
            AND SoViTriDaKy=(SELECT COUNT(*) FROM OPENJSON(ViTriKyJson)) AND SoViTriDaKy>0
            AND Sha256DangKy=@Sha256DaKy AND PdfDangKy=@PdfDaKy)
            THROW 59303,N'Chua ky du cac o bac si hoac PDF khac ban da ghi tien do.',1;
        IF @PdfDaKy IS NULL OR DATALENGTH(@PdfDaKy) NOT BETWEEN 8 AND 10485760 OR NULLIF(@SerialChungThu,N'') IS NULL
            OR @Sha256DaKy IS NULL OR LOWER(CONVERT(CHAR(64),HASHBYTES('SHA2_256',@PdfDaKy),2))<>LOWER(@Sha256DaKy)
            THROW 59303,N'Artifact ky PDF khong hop le.',1;
        DECLARE @Version INT=(SELECT ISNULL(MAX(SoPhienBan),0)+1 FROM dbo.QL_KySoPdf_TaiLieu
            WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@Visit AND MaLoai=@Loai AND ISNULL(IDToaThuoc,0)=ISNULL(@Toa,0) AND ISNULL(NhomChiDinh,2)=ISNULL(@Nhom,2));
        UPDATE dbo.QL_KySoPdf_TaiLieu SET TrangThai=N'HET_HIEU_LUC' WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@Visit AND MaLoai=@Loai
            AND ISNULL(IDToaThuoc,0)=ISNULL(@Toa,0) AND ISNULL(NhomChiDinh,2)=ISNULL(@Nhom,2) AND TrangThai=N'DA_KY';
        INSERT dbo.QL_KySoPdf_TaiLieu(IDCSKCB,IDVaoVien,IDToaThuoc,MaLoai,NhomChiDinh,SoPhienBan,PhienBanLamSang,TrangThai,
            PdfNguon,PdfDaKy,Sha256Nguon,Sha256DaKy,NhaCungCapKy,SerialChungThu,MaHoSoKy,NgayKy,IDBacSiKy,IDTaiKhoanKy,PhienBanMauKy)
        SELECT IDCSKCB,IDVaoVien,IDToaThuoc,MaLoai,NhomChiDinh,@Version,PhienBanLamSang,
            CASE WHEN @Revision=@SourceRevision THEN N'DA_KY' ELSE N'HET_HIEU_LUC' END,
            PdfNguon,@PdfDaKy,Sha256Nguon,@Sha256DaKy,@NhaCungCap,@SerialChungThu,@MaHoSo,SYSDATETIME(),IDBacSiKy,IDTaiKhoanKy,PhienBanMauKy
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
CREATE OR ALTER TRIGGER dbo.TR_QL_ChiDinh_CT_KyPdf ON dbo.QL_ChiDinh_CT AFTER INSERT,UPDATE,DELETE
AS
BEGIN
 SET NOCOUNT ON;
 ;WITH Changed AS (SELECT COALESCE(i.IDCSKCB,d.IDCSKCB) IDCSKCB,COALESCE(i.IDVaoVien,d.IDVaoVien) IDVaoVien
 FROM inserted i FULL JOIN deleted d ON i.IDCSKCB=d.IDCSKCB AND i.ID=d.ID
 WHERE i.ID IS NULL OR d.ID IS NULL OR EXISTS(SELECT i.IDVaoVien, i.IDDichVu, i.SoLuong, i.DonGia, i.ThanhTien, i.GuiNgoai, i.NoiGuiNgoai, i.NgayGioChiDinh, i.IDBacSiChiDinh, i.GhiChu, i.Active EXCEPT SELECT d.IDVaoVien, d.IDDichVu, d.SoLuong, d.DonGia, d.ThanhTien, d.GuiNgoai, d.NoiGuiNgoai, d.NgayGioChiDinh, d.IDBacSiChiDinh, d.GhiChu, d.Active))
 UPDATE V SET PhienBanLamSang=V.PhienBanLamSang+1,NgayCapNhatKham=CASE WHEN V.NgayLuuKhamLanDau IS NULL THEN V.NgayCapNhatKham ELSE SYSDATETIME() END
 FROM dbo.QL_VaoVien V JOIN (SELECT DISTINCT IDCSKCB,IDVaoVien FROM Changed) C ON C.IDCSKCB=V.IDCSKCB AND C.IDVaoVien=V.ID;
END;
GO
CREATE OR ALTER TRIGGER dbo.TR_QL_VaoVien_KyPdf ON dbo.QL_VaoVien AFTER UPDATE
AS
BEGIN
 SET NOCOUNT ON;
 ;WITH Changed AS (SELECT COALESCE(i.IDCSKCB,d.IDCSKCB) IDCSKCB,COALESCE(i.ID,d.ID) IDVaoVien
 FROM inserted i FULL JOIN deleted d ON i.IDCSKCB=d.IDCSKCB AND i.ID=d.ID
 WHERE i.ID IS NULL OR d.ID IS NULL OR EXISTS(SELECT i.IDBenhNhan, i.MaVaoVien, i.IDBacSiKham, i.TrieuChung, i.DanDo, i.NgayTaiKham, i.Active EXCEPT SELECT d.IDBenhNhan, d.MaVaoVien, d.IDBacSiKham, d.TrieuChung, d.DanDo, d.NgayTaiKham, d.Active))
 UPDATE V SET PhienBanLamSang=V.PhienBanLamSang+1,NgayCapNhatKham=CASE WHEN V.NgayLuuKhamLanDau IS NULL THEN V.NgayCapNhatKham ELSE SYSDATETIME() END
 FROM dbo.QL_VaoVien V JOIN (SELECT DISTINCT IDCSKCB,IDVaoVien FROM Changed) C ON C.IDCSKCB=V.IDCSKCB AND C.IDVaoVien=V.ID;
END;
GO
CREATE OR ALTER TRIGGER dbo.TR_QL_PhieuSinhHieu_KyPdf ON dbo.QL_PhieuSinhHieu AFTER INSERT,UPDATE,DELETE
AS
BEGIN
 SET NOCOUNT ON;
 ;WITH Changed AS (SELECT COALESCE(i.IDCSKCB,d.IDCSKCB) IDCSKCB,COALESCE(i.IDVaoVien,d.IDVaoVien) IDVaoVien
 FROM inserted i FULL JOIN deleted d ON i.IDCSKCB=d.IDCSKCB AND i.ID=d.ID
 WHERE i.ID IS NULL OR d.ID IS NULL OR EXISTS(SELECT i.IDVaoVien, i.NgayGioDo EXCEPT SELECT d.IDVaoVien, d.NgayGioDo))
 UPDATE V SET PhienBanLamSang=V.PhienBanLamSang+1,NgayCapNhatKham=CASE WHEN V.NgayLuuKhamLanDau IS NULL THEN V.NgayCapNhatKham ELSE SYSDATETIME() END
 FROM dbo.QL_VaoVien V JOIN (SELECT DISTINCT IDCSKCB,IDVaoVien FROM Changed) C ON C.IDCSKCB=V.IDCSKCB AND C.IDVaoVien=V.ID;
END;
GO
CREATE OR ALTER TRIGGER dbo.TR_QL_PhieuSinhHieu_CT_KyPdf ON dbo.QL_PhieuSinhHieu_CT AFTER INSERT,UPDATE,DELETE
AS
BEGIN
 SET NOCOUNT ON;
 ;WITH Changed AS (
 SELECT COALESCE(i.IDCSKCB,d.IDCSKCB) IDCSKCB,COALESCE(i.IDPhieuSinhHieu,d.IDPhieuSinhHieu) IDPhieuSinhHieu
 FROM inserted i FULL JOIN deleted d ON i.IDCSKCB=d.IDCSKCB AND i.ID=d.ID
 WHERE i.ID IS NULL OR d.ID IS NULL OR EXISTS(SELECT i.IDPhieuSinhHieu,i.IDTriSoSinhHieu,i.GiaTri EXCEPT SELECT d.IDPhieuSinhHieu,d.IDTriSoSinhHieu,d.GiaTri))
 UPDATE V SET PhienBanLamSang=V.PhienBanLamSang+1,NgayCapNhatKham=CASE WHEN V.NgayLuuKhamLanDau IS NULL THEN V.NgayCapNhatKham ELSE SYSDATETIME() END
 FROM dbo.QL_VaoVien V JOIN (SELECT DISTINCT P.IDCSKCB,P.IDVaoVien FROM Changed C JOIN dbo.QL_PhieuSinhHieu P
 ON P.IDCSKCB=C.IDCSKCB AND P.ID=C.IDPhieuSinhHieu) X ON X.IDCSKCB=V.IDCSKCB AND X.IDVaoVien=V.ID;
END;
GO
CREATE OR ALTER TRIGGER dbo.TR_QL_BenhNhan_KyPdf ON dbo.QL_BenhNhan AFTER UPDATE
AS
BEGIN
 SET NOCOUNT ON;
 UPDATE V SET PhienBanLamSang=V.PhienBanLamSang+1,NgayCapNhatKham=CASE WHEN V.NgayLuuKhamLanDau IS NULL THEN V.NgayCapNhatKham ELSE SYSDATETIME() END
 FROM dbo.QL_VaoVien V JOIN inserted i ON i.IDCSKCB=V.IDCSKCB AND i.ID=V.IDBenhNhan
 JOIN deleted d ON d.IDCSKCB=i.IDCSKCB AND d.ID=i.ID
 WHERE EXISTS(SELECT i.MaBN,i.HoTen,i.NgaySinh,i.IDGioiTinh,i.SoCCCD,i.DiaChi,i.DienThoai,i.GiamHo_MoiQuanHe,i.GiamHo_HoTen,i.GiamHo_DienThoai,i.GiamHo_SoCCCD EXCEPT SELECT d.MaBN,d.HoTen,d.NgaySinh,d.IDGioiTinh,d.SoCCCD,d.DiaChi,d.DienThoai,d.GiamHo_MoiQuanHe,d.GiamHo_HoTen,d.GiamHo_DienThoai,d.GiamHo_SoCCCD);
END;
GO
PRINT N'52_ky_so_pdf_vi_tri_dong_va_ho_so_da_luu_v111.sql: OK; no signing HTTP.';
GO
