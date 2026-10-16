:ON ERROR EXIT

/*
=====================================================================
QLPM MAIN - REBUILD TOAN BO STO
Tao: 2026-09-22

MUC DICH
- DROP toan bo stored procedure dbo.STO_% hien co trong database QLPM.
- Tao lai STO runtime cua nhanh main tu mot contract duy nhat.
- KHONG DROP TABLE, KHONG XOA DU LIEU, KHONG DROP TRIGGER/FUNCTION.
- Sinh hieu chi luu trong luong Kham.
- Trang thai Da kham: chi khi TrangThaiKham=2 do bac si bam Kham xong; co toa thuoc khong tu dong hoan tat.
- CLS PDF-only luu duong dan tai QL_ChiDinh_CT.DuongDanKetQua; khong co STO ket qua rieng.
- Gia dich vu/thuoc trong nghiep vu lay tu danh muc server, khong tin DonGia client.
- Chay script nay tren DB main da qua updater v94. Main khong con DSS/legacy schema.

LUU Y
- Day la file destructive doi voi STO, nen nen backup/script-out STO cu neu can doi chieu.
=====================================================================
*/
USE [QLPM];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF DB_NAME()<>N'QLPM'
    THROW 59000,N'Script chi duoc phep chay tren database QLPM.',1;
IF OBJECT_ID(N'dbo.QL_Kho_ChungTu',N'U') IS NULL
 OR NOT EXISTS(SELECT 1 FROM dbo.QLPM_SchemaVersion WHERE VersionNo=114)
    THROW 59114,N'Apply warehouse v114 using Invoke-KhoV114.ps1 before rebuilding STOs.',1;
GO

DECLARE @Thieu NVARCHAR(MAX)=N'';
IF OBJECT_ID(N'dbo.DM_CSKCB',N'U') IS NULL SET @Thieu+=N'DM_CSKCB; ';
IF OBJECT_ID(N'dbo.DM_NhanVien',N'U') IS NULL SET @Thieu+=N'DM_NhanVien; ';
IF COL_LENGTH(N'dbo.HT_Tai_Khoan',N'LaQuanTriHeThong') IS NULL SET @Thieu+=N'HT_Tai_Khoan.LaQuanTriHeThong (hay chay 00_CapNhat_TatCa.sql v76 truoc); ';
IF OBJECT_ID(N'dbo.QL_BenhNhan',N'U') IS NULL SET @Thieu+=N'QL_BenhNhan; ';
IF OBJECT_ID(N'dbo.QL_VaoVien',N'U') IS NULL SET @Thieu+=N'QL_VaoVien; ';
IF OBJECT_ID(N'dbo.QL_ChiDinh_CT',N'U') IS NULL SET @Thieu+=N'QL_ChiDinh_CT; ';
IF COL_LENGTH(N'dbo.QL_ThuTien_CT',N'PhuThu') IS NULL SET @Thieu+=N'QL_ThuTien_CT.PhuThu; ';
IF COL_LENGTH(N'dbo.QL_ThuTien_CT',N'GiamPhanTram') IS NULL SET @Thieu+=N'QL_ThuTien_CT.GiamPhanTram; ';
IF COL_LENGTH(N'dbo.QL_ThuTien_CT',N'DaHuy') IS NULL SET @Thieu+=N'QL_ThuTien_CT.DaHuy; ';
IF COL_LENGTH(N'dbo.QL_ThuTien_CT',N'NgayGioHuy') IS NULL SET @Thieu+=N'QL_ThuTien_CT.NgayGioHuy; ';
IF COL_LENGTH(N'dbo.QL_ThuTien_CT',N'IDNhanVienHuy') IS NULL SET @Thieu+=N'QL_ThuTien_CT.IDNhanVienHuy; ';
IF COL_LENGTH(N'dbo.QL_ThuTien_CT',N'IDTaiKhoanHuy') IS NULL SET @Thieu+=N'QL_ThuTien_CT.IDTaiKhoanHuy; ';
IF COL_LENGTH(N'dbo.QL_ThuTien',N'IDTaiKhoanThu') IS NULL SET @Thieu+=N'QL_ThuTien.IDTaiKhoanThu; ';
IF COL_LENGTH(N'dbo.QL_ThuTien_LichSu',N'IDTaiKhoan') IS NULL SET @Thieu+=N'QL_ThuTien_LichSu.IDTaiKhoan; ';
IF @Thieu<>N'' THROW 59001,N'Thieu schema bat buoc. Hay cap nhat schema truoc khi rebuild STO.',1;
GO

BEGIN TRANSACTION;
GO

PRINT N'===== DROP TOAN BO dbo.STO_% =====';
DECLARE @Drop NVARCHAR(MAX)=N'';
SELECT @Drop+=N'DROP PROCEDURE '+QUOTENAME(SCHEMA_NAME(P.schema_id))+N'.'+QUOTENAME(P.name)+N';'+CHAR(13)+CHAR(10)
FROM sys.procedures P
WHERE SCHEMA_NAME(P.schema_id)=N'dbo'
  AND P.name LIKE N'STO[_]%'
ORDER BY P.name;
IF NULLIF(@Drop,N'') IS NOT NULL EXEC sys.sp_executesql @Drop;
PRINT N'===== DROP STO HOAN TAT =====';
GO


/* ==================== STO_HT_CSKCB_Danh_Sach ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_HT_CSKCB_Danh_Sach
    @TuKhoa NVARCHAR(200)=NULL,
    @MaCSKCB NVARCHAR(20)=NULL,
    @TenCSKCB NVARCHAR(300)=NULL,
    @MaTinh NVARCHAR(20)=NULL,
    @MaPhuongXa NVARCHAR(20)=NULL,
    @Active BIT=NULL,
    @Trang INT=1,
    @KichThuocTrang INT=25
AS
BEGIN
    SET NOCOUNT ON;
    SET @TuKhoa=NULLIF(LTRIM(RTRIM(@TuKhoa)),N'');
    SET @MaCSKCB=NULLIF(LTRIM(RTRIM(@MaCSKCB)),N'');
    SET @TenCSKCB=NULLIF(LTRIM(RTRIM(@TenCSKCB)),N'');
    SET @MaTinh=NULLIF(LTRIM(RTRIM(@MaTinh)),N'');
    SET @MaPhuongXa=NULLIF(LTRIM(RTRIM(@MaPhuongXa)),N'');
    SET @Trang=CASE WHEN @Trang<1 THEN 1 ELSE @Trang END;
    SET @KichThuocTrang=CASE WHEN @KichThuocTrang<10 THEN 10 WHEN @KichThuocTrang>100 THEN 100 ELSE @KichThuocTrang END;

    ;WITH D AS
    (
        SELECT
            C.ID AS IDCSKCB,
            C.MaCSKCB,
            C.TenCSKCB,
            C.SoNhaTenDuong,
            C.DiaChi,
            C.MaTinh,
            C.MaPhuongXa,
            C.SDT,
            C.Email,
            C.MaST,
            C.SoTK,
            C.IDNganHang,
            NH.MaNganHang,
            NH.TenNganHang,
            C.UrlLogo,
            C.Active
        FROM dbo.DM_CSKCB C
        LEFT JOIN dbo.DM_NganHang NH ON NH.ID=C.IDNganHang
        WHERE (@Active IS NULL OR C.Active=@Active)
          AND (@MaCSKCB IS NULL OR C.MaCSKCB LIKE N'%'+@MaCSKCB+N'%')
          AND (@TenCSKCB IS NULL OR C.TenCSKCB LIKE N'%'+@TenCSKCB+N'%')
          AND (@MaTinh IS NULL OR C.MaTinh=@MaTinh)
          AND (@MaPhuongXa IS NULL OR C.MaPhuongXa=@MaPhuongXa)
          AND
          (
               @TuKhoa IS NULL
               OR C.MaCSKCB LIKE N'%'+@TuKhoa+N'%'
               OR C.TenCSKCB LIKE N'%'+@TuKhoa+N'%'
               OR C.SoNhaTenDuong LIKE N'%'+@TuKhoa+N'%'
               OR C.DiaChi LIKE N'%'+@TuKhoa+N'%'
               OR C.SDT LIKE N'%'+@TuKhoa+N'%'
               OR C.Email LIKE N'%'+@TuKhoa+N'%'
               OR C.MaST LIKE N'%'+@TuKhoa+N'%'
               OR C.SoTK LIKE N'%'+@TuKhoa+N'%'
               OR NH.MaNganHang LIKE N'%'+@TuKhoa+N'%'
               OR NH.TenNganHang LIKE N'%'+@TuKhoa+N'%'
          )
    )
    SELECT D.*,COUNT(*) OVER() AS TongSoDong
    FROM D
    ORDER BY D.Active DESC,D.TenCSKCB,D.IDCSKCB
    OFFSET (@Trang-1)*@KichThuocTrang ROWS
    FETCH NEXT @KichThuocTrang ROWS ONLY;
END;
GO

/* ==================== STO_HT_CSKCB_Luu ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_HT_CSKCB_Luu
    @IDCSKCB BIGINT=NULL,
    @MaCSKCB NVARCHAR(20),
    @TenCSKCB NVARCHAR(300),
    @SoNhaTenDuong NVARCHAR(300)=NULL,
    @MaTinh NVARCHAR(20)=NULL,
    @MaPhuongXa NVARCHAR(20)=NULL,
    @SDT NVARCHAR(100)=NULL,
    @Email NVARCHAR(200)=NULL,
    @MaST NVARCHAR(50)=NULL,
    @SoTK NVARCHAR(100)=NULL,
    @IDNganHang BIGINT=NULL,
    @UrlLogo NVARCHAR(1000)=NULL,
    @Active BIT=1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @MaCSKCB=NULLIF(LTRIM(RTRIM(@MaCSKCB)),N'');
    SET @TenCSKCB=NULLIF(LTRIM(RTRIM(@TenCSKCB)),N'');
    SET @SoNhaTenDuong=NULLIF(LTRIM(RTRIM(@SoNhaTenDuong)),N'');
    SET @MaTinh=NULLIF(LTRIM(RTRIM(@MaTinh)),N'');
    SET @MaPhuongXa=NULLIF(LTRIM(RTRIM(@MaPhuongXa)),N'');
    SET @SDT=NULLIF(LTRIM(RTRIM(@SDT)),N'');

    IF @SDT IS NOT NULL AND (LEN(@SDT)>10 OR @SDT LIKE N'%[^0-9]%')
    BEGIN
        SELECT 400 AS Status,N'Số điện thoại chỉ được nhập số và tối đa 10 ký tự.' AS Message,@IDCSKCB AS IDCSKCB;
        RETURN;
    END;

    SET @Email=NULLIF(LTRIM(RTRIM(@Email)),N'');
    SET @MaST=NULLIF(LTRIM(RTRIM(@MaST)),N'');
    SET @SoTK=NULLIF(LTRIM(RTRIM(@SoTK)),N'');
    SET @UrlLogo=NULLIF(LTRIM(RTRIM(@UrlLogo)),N'');

    IF @MaCSKCB IS NULL OR @TenCSKCB IS NULL
    BEGIN
        SELECT 400 AS Status,N'Mã CSKCB và tên CSKCB là bắt buộc.' AS Message,@IDCSKCB AS IDCSKCB;
        RETURN;
    END;

    IF @IDNganHang IS NOT NULL
       AND NOT EXISTS(SELECT 1 FROM dbo.DM_NganHang WHERE ID=@IDNganHang)
    BEGIN
        SELECT 400 AS Status,N'Ngân hàng không tồn tại.' AS Message,@IDCSKCB AS IDCSKCB;
        RETURN;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.DM_CSKCB
        WHERE MaCSKCB=@MaCSKCB
          AND (@IDCSKCB IS NULL OR ID<>@IDCSKCB)
    )
    BEGIN
        SELECT 409 AS Status,N'Mã CSKCB đã tồn tại.' AS Message,@IDCSKCB AS IDCSKCB;
        RETURN;
    END;

    DECLARE @TenTinh NVARCHAR(200)=NULL,
            @TenPhuongXa NVARCHAR(200)=NULL,
            @DiaChi NVARCHAR(500)=NULL;

    IF @MaTinh IS NOT NULL
        SELECT TOP(1) @TenTinh=T.TenTinh
        FROM dbo.DM_TinhThanh T
        WHERE T.Active=1 AND T.MaTinh=@MaTinh
        ORDER BY T.ID;

    IF @MaPhuongXa IS NOT NULL
        SELECT TOP(1) @TenPhuongXa=P.TenPhuongXa
        FROM dbo.DM_PhuongXa P
        LEFT JOIN dbo.DM_TinhThanh T
          ON T.IDCSKCB=P.IDCSKCB AND T.ID=P.IDTinhThanh
        WHERE P.Active=1
          AND P.MaPhuongXa=@MaPhuongXa
          AND (@MaTinh IS NULL OR T.MaTinh=@MaTinh)
        ORDER BY P.ID;

    SET @DiaChi=NULLIF(CONCAT_WS(N', ',@SoNhaTenDuong,@TenPhuongXa,@TenTinh),N'');

    BEGIN TRY
        BEGIN TRAN;

        IF ISNULL(@IDCSKCB,0)=0
        BEGIN
            INSERT dbo.DM_CSKCB
            (
                MaCSKCB,TenCSKCB,SoNhaTenDuong,DiaChi,MaTinh,MaPhuongXa,SDT,Email,MaST,SoTK,IDNganHang,UrlLogo,Active
            )
            VALUES
            (
                @MaCSKCB,@TenCSKCB,@SoNhaTenDuong,@DiaChi,@MaTinh,@MaPhuongXa,@SDT,@Email,@MaST,@SoTK,@IDNganHang,@UrlLogo,ISNULL(@Active,1)
            );

            SET @IDCSKCB=SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            IF NOT EXISTS(SELECT 1 FROM dbo.DM_CSKCB WHERE ID=@IDCSKCB)
            BEGIN
                ROLLBACK;
                SELECT 404 AS Status,N'Không tìm thấy CSKCB.' AS Message,@IDCSKCB AS IDCSKCB;
                RETURN;
            END;

            UPDATE dbo.DM_CSKCB
            SET MaCSKCB=@MaCSKCB,
                TenCSKCB=@TenCSKCB,
                SoNhaTenDuong=@SoNhaTenDuong,
                DiaChi=@DiaChi,
                MaTinh=@MaTinh,
                MaPhuongXa=@MaPhuongXa,
                SDT=@SDT,
                Email=@Email,
                MaST=@MaST,
                SoTK=@SoTK,
                IDNganHang=@IDNganHang,
                UrlLogo=@UrlLogo,
                Active=ISNULL(@Active,1)
            WHERE ID=@IDCSKCB;
        END;

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.HT_Config
            WHERE IDCSKCB=@IDCSKCB
              AND MaChucNang=N'THUCONGKHAMDVTRUOC'
        )
        BEGIN
            INSERT dbo.HT_Config(IDCSKCB,MaChucNang,HieuLuc,Nhom,GhiChu)
            VALUES
            (
                @IDCSKCB,N'THUCONGKHAMDVTRUOC',1,N'3. Tài chính',
                N'Bắt buộc thanh toán công khám trước khi bắt đầu khám.'
            );
        END;

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.HT_Config
            WHERE IDCSKCB=@IDCSKCB
              AND MaChucNang=N'THUTIENCHIDINHTRUOC'
        )
        BEGIN
            INSERT dbo.HT_Config(IDCSKCB,MaChucNang,HieuLuc,Nhom,GhiChu)
            VALUES
            (
                @IDCSKCB,N'THUTIENCHIDINHTRUOC',1,N'3. Tài chính',
                N'Bắt buộc thanh toán chỉ định CLS trước khi nhập kết quả.'
            );
        END;

        COMMIT;
        SELECT 200 AS Status,N'Lưu CSKCB thành công.' AS Message,@IDCSKCB AS IDCSKCB;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SELECT 500 AS Status,ERROR_MESSAGE() AS Message,@IDCSKCB AS IDCSKCB;
    END CATCH;
END;
GO

/* ==================== STO_HT_CSKCB_Xoa ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_HT_CSKCB_Xoa
    @IDCSKCB BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS(SELECT 1 FROM dbo.DM_CSKCB WHERE ID=@IDCSKCB)
    BEGIN
        SELECT 404 AS Status,N'Không tìm thấy CSKCB.' AS Message;
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @AppLockResult INT;
        DECLARE @AppLockResource NVARCHAR(255)=N'QLPM_HARD_DELETE_CSKCB_'+CONVERT(NVARCHAR(30),@IDCSKCB);
        EXEC @AppLockResult=sys.sp_getapplock
            @Resource=@AppLockResource,@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=10000;
        IF @AppLockResult<0 THROW 51000,N'Không lấy được khóa xóa CSKCB. Hãy thử lại.',1;

        DECLARE @AffectedEmployee TABLE(IDNhanVien BIGINT PRIMARY KEY);
        INSERT @AffectedEmployee(IDNhanVien)
        SELECT IDNhanVien FROM dbo.DM_NhanVien_CSKCB WHERE IDCSKCB=@IDCSKCB;

        CREATE TABLE #TenantTables(ObjectID INT NOT NULL PRIMARY KEY,SchemaName SYSNAME NOT NULL,TableName SYSNAME NOT NULL);
        INSERT #TenantTables(ObjectID,SchemaName,TableName)
        SELECT T.object_id,S.name,T.name
        FROM sys.tables T
        INNER JOIN sys.schemas S ON S.schema_id=T.schema_id
        WHERE T.is_ms_shipped=0
          AND EXISTS(SELECT 1 FROM sys.columns C WHERE C.object_id=T.object_id AND C.name=N'IDCSKCB');

        CREATE TABLE #FkTamTat
        (
            ParentObjectID INT NOT NULL,SchemaName SYSNAME NOT NULL,TableName SYSNAME NOT NULL,FKName SYSNAME NOT NULL,
            PRIMARY KEY(ParentObjectID,FKName)
        );
        INSERT #FkTamTat(ParentObjectID,SchemaName,TableName,FKName)
        SELECT DISTINCT FK.parent_object_id,S.name,T.name,FK.name
        FROM sys.foreign_keys FK
        INNER JOIN sys.tables T ON T.object_id=FK.parent_object_id
        INNER JOIN sys.schemas S ON S.schema_id=T.schema_id
        WHERE FK.is_disabled=0
          AND
          (
              EXISTS(SELECT 1 FROM #TenantTables X WHERE X.ObjectID=FK.parent_object_id)
              OR EXISTS(SELECT 1 FROM #TenantTables X WHERE X.ObjectID=FK.referenced_object_id)
              OR FK.referenced_object_id=OBJECT_ID(N'dbo.DM_CSKCB')
          );

        DECLARE @Schema SYSNAME,@Table SYSNAME,@FK SYSNAME,@Sql NVARCHAR(MAX);
        DECLARE fk_off CURSOR LOCAL FAST_FORWARD FOR
            SELECT SchemaName,TableName,FKName FROM #FkTamTat ORDER BY SchemaName,TableName,FKName;
        OPEN fk_off;
        FETCH NEXT FROM fk_off INTO @Schema,@Table,@FK;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SET @Sql=N'ALTER TABLE '+QUOTENAME(@Schema)+N'.'+QUOTENAME(@Table)+N' NOCHECK CONSTRAINT '+QUOTENAME(@FK)+N';';
            EXEC sys.sp_executesql @Sql;
            FETCH NEXT FROM fk_off INTO @Schema,@Table,@FK;
        END;
        CLOSE fk_off;
        DEALLOCATE fk_off;

        DECLARE table_delete CURSOR LOCAL FAST_FORWARD FOR
            SELECT SchemaName,TableName FROM #TenantTables ORDER BY SchemaName,TableName;
        OPEN table_delete;
        FETCH NEXT FROM table_delete INTO @Schema,@Table;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SET @Sql=N'DELETE FROM '+QUOTENAME(@Schema)+N'.'+QUOTENAME(@Table)+N' WHERE [IDCSKCB]=@IDCSKCB;';
            EXEC sys.sp_executesql @Sql,N'@IDCSKCB BIGINT',@IDCSKCB;
            FETCH NEXT FROM table_delete INTO @Schema,@Table;
        END;
        CLOSE table_delete;
        DEALLOCATE table_delete;

        UPDATE N
        SET Active=0
        FROM dbo.DM_NhanVien N
        INNER JOIN @AffectedEmployee A ON A.IDNhanVien=N.ID
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.DM_NhanVien_CSKCB M
            WHERE M.IDNhanVien=N.ID AND M.Active=1
        );

        DELETE dbo.DM_CSKCB WHERE ID=@IDCSKCB;

        DECLARE fk_on CURSOR LOCAL FAST_FORWARD FOR
            SELECT SchemaName,TableName,FKName FROM #FkTamTat ORDER BY SchemaName,TableName,FKName;
        OPEN fk_on;
        FETCH NEXT FROM fk_on INTO @Schema,@Table,@FK;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SET @Sql=N'ALTER TABLE '+QUOTENAME(@Schema)+N'.'+QUOTENAME(@Table)
                +N' WITH CHECK CHECK CONSTRAINT '+QUOTENAME(@FK)+N';';
            EXEC sys.sp_executesql @Sql;
            FETCH NEXT FROM fk_on INTO @Schema,@Table,@FK;
        END;
        CLOSE fk_on;
        DEALLOCATE fk_on;

        COMMIT;
        SELECT 200 AS Status,N'Đã xóa CSKCB; nhân viên dùng chung ở cơ sở khác được giữ nguyên.' AS Message;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 500 AS Status,ERROR_MESSAGE() AS Message;
    END CATCH
END;
GO

/* ==================== STO_HT_Dang_Nhap_Lay_Tai_Khoan ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_HT_Dang_Nhap_Lay_Tai_Khoan
    @Ten_Dang_Nhap NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP(1)
        T.ID AS ID_Tai_Khoan,
        T.IDCSKCB,
        T.IDNhanVien,
        T.Ten_Dang_Nhap,
        T.Mat_Khau_Hash,
        T.Bat_Buoc_Doi_Mat_Khau,
        T.So_Lan_Dang_Nhap_Sai,
        T.Khoa_Den_Luc,
        T.Lan_Dang_Nhap_Cuoi,
        T.Active AS Tai_Khoan_Active,
        T.LaQuanTriHeThong,
        CASE WHEN T.LaQuanTriHeThong=1 THEN T.Ten_Dang_Nhap ELSE N.HoTen END AS HoTen,
        CASE WHEN T.LaQuanTriHeThong=1 THEN N'ADMIN' ELSE N.MaNhanVien END AS MaNhanVien,
        CASE WHEN T.LaQuanTriHeThong=1 THEN CAST(0 AS BIT) ELSE ISNULL(N.LaBacSi,0) END AS LaBacSi,
        CASE WHEN T.LaQuanTriHeThong=1 THEN N'Quản trị hệ thống' ELSE CD.TenChucDanh END AS ChucDanh,
        CASE
            WHEN T.LaQuanTriHeThong=1 THEN CAST(1 AS BIT)
            WHEN ISNULL(N.Active,0)=1 AND ISNULL(M.Active,0)=1 THEN CAST(1 AS BIT)
            ELSE CAST(0 AS BIT)
        END AS Nhan_Vien_Active,
        CASE WHEN T.LaQuanTriHeThong=1 THEN NULL ELSE C.TenCSKCB END AS TenCSKCB,
        CASE WHEN T.LaQuanTriHeThong=1 THEN CAST(1 AS BIT) ELSE ISNULL(C.Active,0) END AS CSKCB_Active
    FROM dbo.HT_Tai_Khoan T
    LEFT JOIN dbo.DM_NhanVien N
      ON T.LaQuanTriHeThong=0 AND N.ID=T.IDNhanVien
    LEFT JOIN dbo.DM_NhanVien_CSKCB M
      ON T.LaQuanTriHeThong=0 AND M.IDNhanVien=T.IDNhanVien AND M.IDCSKCB=T.IDCSKCB
    LEFT JOIN dbo.DM_ChucDanh CD ON CD.ID=N.IDChucDanh
    LEFT JOIN dbo.DM_CSKCB C
      ON T.LaQuanTriHeThong=0 AND C.ID=T.IDCSKCB
    WHERE T.Ten_Dang_Nhap COLLATE Latin1_General_100_BIN2
        = LTRIM(RTRIM(@Ten_Dang_Nhap)) COLLATE Latin1_General_100_BIN2;
END;
GO

/* ==================== STO_HT_Dang_Nhap_Ghi_Ket_Qua ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_HT_Dang_Nhap_Ghi_Ket_Qua
    @ID_Tai_Khoan BIGINT,
    @Thanh_Cong BIT,
    @So_Lan_Sai_Toi_Da INT=5,
    @So_Phut_Khoa INT=15
AS
BEGIN
    SET NOCOUNT ON;
    IF @Thanh_Cong=1
    BEGIN
        UPDATE dbo.HT_Tai_Khoan
        SET So_Lan_Dang_Nhap_Sai=0,
            Khoa_Den_Luc=NULL,
            Lan_Dang_Nhap_Cuoi=SYSDATETIME(),
            Ngay_Cap_Nhat=SYSDATETIME()
        WHERE ID=@ID_Tai_Khoan;
        RETURN;
    END;

    UPDATE dbo.HT_Tai_Khoan
    SET So_Lan_Dang_Nhap_Sai=So_Lan_Dang_Nhap_Sai+1,
        Khoa_Den_Luc=CASE WHEN So_Lan_Dang_Nhap_Sai+1>=@So_Lan_Sai_Toi_Da
                          THEN DATEADD(MINUTE,@So_Phut_Khoa,SYSDATETIME()) ELSE Khoa_Den_Luc END,
        Ngay_Cap_Nhat=SYSDATETIME()
    WHERE ID=@ID_Tai_Khoan;
END;
GO

/* ==================== STO_HT_Doi_Mat_Khau ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_HT_Doi_Mat_Khau
    @ID_Tai_Khoan BIGINT,
    @Mat_Khau_Hash NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.HT_Tai_Khoan
    SET Mat_Khau_Hash=@Mat_Khau_Hash,
        Bat_Buoc_Doi_Mat_Khau=0,
        Ngay_Cap_Nhat=SYSDATETIME()
    WHERE ID=@ID_Tai_Khoan AND Active=1;

    IF @@ROWCOUNT=0 SELECT 404 AS Status, N'Không tìm thấy tài khoản đang hoạt động.' AS Message;
    ELSE SELECT 200 AS Status, N'Đổi mật khẩu thành công.' AS Message;
END;
GO

/* ==================== STO_HT_Khoi_Tao_Quan_Tri ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_HT_Khoi_Tao_Quan_Tri
    @Ten_Dang_Nhap NVARCHAR(150),
    @Mat_Khau_Hash NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        SET @Ten_Dang_Nhap=NULLIF(LTRIM(RTRIM(@Ten_Dang_Nhap)),N'');
        IF @Ten_Dang_Nhap IS NULL OR NULLIF(@Mat_Khau_Hash,N'') IS NULL
            THROW 56000,N'Tên đăng nhập và mật khẩu là bắt buộc.',1;

        IF EXISTS(SELECT 1 FROM dbo.HT_Tai_Khoan WHERE LaQuanTriHeThong=1)
        BEGIN
            ROLLBACK;
            SELECT 409 AS Status,N'Hệ thống đã có tài khoản quản trị global.' AS Message;
            RETURN;
        END;

        IF EXISTS(SELECT 1 FROM dbo.HT_Tai_Khoan WHERE LOWER(Ten_Dang_Nhap)=LOWER(@Ten_Dang_Nhap))
        BEGIN
            ROLLBACK;
            SELECT 409 AS Status,N'Tên đăng nhập đã tồn tại.' AS Message;
            RETURN;
        END;

        INSERT dbo.HT_Tai_Khoan
            (IDCSKCB,IDNhanVien,Ten_Dang_Nhap,Mat_Khau_Hash,Bat_Buoc_Doi_Mat_Khau,LaQuanTriHeThong,Active)
        VALUES
            (NULL,NULL,@Ten_Dang_Nhap,@Mat_Khau_Hash,0,1,1);

        COMMIT;
        SELECT 200 AS Status,N'Khởi tạo quản trị hệ thống global thành công.' AS Message;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 500 AS Status,ERROR_MESSAGE() AS Message;
    END CATCH
END;
GO

/* ==================== STO_HT_Khoi_Tao_Thong_Tin ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_HT_Khoi_Tao_Thong_Tin
    @IDCSKCB BIGINT=NULL,
    @TuKhoa NVARCHAR(200)=NULL,
    @Top INT=100
AS
BEGIN
    SET NOCOUNT ON;
    SET @TuKhoa=NULLIF(LTRIM(RTRIM(@TuKhoa)),N'');
    SET @Top=CASE WHEN @Top<1 THEN 1 WHEN @Top>100 THEN 100 ELSE @Top END;

    SELECT TOP (@Top)
        C.ID AS IDCSKCB,C.MaCSKCB,C.TenCSKCB,C.Active,
        CASE WHEN EXISTS(SELECT 1 FROM dbo.HT_Tai_Khoan T WHERE T.IDCSKCB=C.ID)
             THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS DaCoTaiKhoan
    FROM dbo.DM_CSKCB C
    WHERE C.Active=1
      AND (@IDCSKCB IS NULL OR C.ID=@IDCSKCB)
      AND (@TuKhoa IS NULL OR C.MaCSKCB LIKE N'%'+@TuKhoa+N'%' OR C.TenCSKCB LIKE N'%'+@TuKhoa+N'%')
    ORDER BY C.TenCSKCB,C.ID;

    SELECT TOP (@Top)
        N.ID AS IDNhanVien,
        @IDCSKCB AS IDCSKCB,
        N.MaNhanVien,
        N.HoTen,
        N.LaBacSi,
        N.IDChucDanh,
        CD.TenChucDanh AS ChucDanh
    FROM dbo.DM_NhanVien N
    INNER JOIN dbo.DM_NhanVien_CSKCB M
      ON M.IDNhanVien=N.ID AND M.IDCSKCB=@IDCSKCB AND M.Active=1
    LEFT JOIN dbo.DM_ChucDanh CD ON CD.ID=N.IDChucDanh
    WHERE @IDCSKCB IS NOT NULL
      AND N.Active=1
      AND (@TuKhoa IS NULL OR N.MaNhanVien LIKE N'%'+@TuKhoa+N'%' OR N.HoTen LIKE N'%'+@TuKhoa+N'%')
      AND NOT EXISTS
      (
          SELECT 1 FROM dbo.HT_Tai_Khoan T
          WHERE T.IDCSKCB=@IDCSKCB AND T.IDNhanVien=N.ID AND T.LaQuanTriHeThong=0
      )
    ORDER BY N.HoTen,N.ID;
END;
GO

/* ==================== STO_HT_Lay_Quyen_Tai_Khoan ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_HT_Lay_Quyen_Tai_Khoan
    @ID_Tai_Khoan BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.HT_Tai_Khoan
        WHERE ID=@ID_Tai_Khoan
          AND Active=1
          AND LaQuanTriHeThong=1
    )
    BEGIN
        SELECT
            CAST(0 AS BIGINT) AS ID_Vai_Tro,
            N'quan_tri_he_thong' AS Ma_Vai_Tro,
            N'Quản trị hệ thống' AS Ten_Vai_Tro;

        SELECT
            CAST(NULL AS NVARCHAR(150)) AS Ma_Chuc_Nang,
            CAST(0 AS INT) AS Xem,
            CAST(0 AS INT) AS Them,
            CAST(0 AS INT) AS Sua,
            CAST(0 AS INT) AS Xoa,
            CAST(0 AS INT) AS Xuat,
            CAST(0 AS INT) AS CaNhan
        WHERE 1=0;
        RETURN;
    END;

    SELECT DISTINCT
        VT.ID AS ID_Vai_Tro,
        CASE WHEN VT.Ma_Vai_Tro=N'quan_tri_he_thong' THEN N'quan_tri_cskcb' ELSE VT.Ma_Vai_Tro END AS Ma_Vai_Tro,
        CASE WHEN VT.Ma_Vai_Tro=N'quan_tri_he_thong' AND VT.Ten_Vai_Tro=N'Quản trị hệ thống'
             THEN N'Quản trị cơ sở KCB' ELSE VT.Ten_Vai_Tro END AS Ten_Vai_Tro
    FROM dbo.HT_Tai_Khoan T
    INNER JOIN dbo.HT_Tai_Khoan_Vai_Tro TV
        ON TV.IDCSKCB=T.IDCSKCB
       AND TV.ID_Tai_Khoan=T.ID
       AND TV.Active=1
    INNER JOIN dbo.DM_Vai_Tro VT
        ON VT.IDCSKCB=TV.IDCSKCB
       AND VT.ID=TV.ID_Vai_Tro
       AND VT.Active=1
    WHERE T.ID=@ID_Tai_Khoan
      AND T.Active=1
      AND T.LaQuanTriHeThong=0;

    SELECT
        CN.Ma_Chuc_Nang,
        MAX(CONVERT(INT,Q.Xem)) AS Xem,
        MAX(CONVERT(INT,Q.Them)) AS Them,
        MAX(CONVERT(INT,Q.Sua)) AS Sua,
        MAX(CONVERT(INT,Q.Xoa)) AS Xoa,
        MAX(CONVERT(INT,Q.Xuat)) AS Xuat,
        MAX(CONVERT(INT,Q.Ca_Nhan)) AS CaNhan
    FROM dbo.HT_Tai_Khoan T
    INNER JOIN dbo.HT_Tai_Khoan_Vai_Tro TV
        ON TV.IDCSKCB=T.IDCSKCB
       AND TV.ID_Tai_Khoan=T.ID
       AND TV.Active=1
    INNER JOIN dbo.HT_Quyen_Vai_Tro Q
        ON Q.IDCSKCB=TV.IDCSKCB
       AND Q.ID_Vai_Tro=TV.ID_Vai_Tro
    INNER JOIN dbo.HT_Chuc_Nang CN
        ON CN.IDCSKCB=Q.IDCSKCB
       AND CN.ID=Q.ID_Chuc_Nang
       AND CN.Active=1
    WHERE T.ID=@ID_Tai_Khoan
      AND T.Active=1
      AND T.LaQuanTriHeThong=0
    GROUP BY CN.Ma_Chuc_Nang;
END;
GO

/* ==================== STO_HT_Nhan_Vien_Danh_Sach ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_HT_Nhan_Vien_Danh_Sach
    @IDCSKCB BIGINT=NULL,
    @TuKhoa NVARCHAR(200)=NULL,
    @Trang INT=1,
    @KichThuocTrang INT=25
AS
BEGIN
    SET NOCOUNT ON;
    SET @TuKhoa=NULLIF(LTRIM(RTRIM(@TuKhoa)),N'');
    SET @Trang=CASE WHEN @Trang<1 THEN 1 ELSE @Trang END;
    SET @KichThuocTrang=CASE WHEN @KichThuocTrang<10 THEN 10 WHEN @KichThuocTrang>100 THEN 100 ELSE @KichThuocTrang END;

    ;WITH D AS
    (
        SELECT
            N.ID AS IDNhanVien,
            @IDCSKCB AS IDCSKCB,
            MAP.IDCSKCBs,
            MAP.TenCSKCB,
            N.MaNhanVien,
            N.HoTen,
            N.LaBacSi,
            N.IDChucDanh,
            CD.TenChucDanh AS ChucDanh,
            CD.VietTat AS VietTatChucDanh,
            N.DienThoai,
            N.SoNhaTenDuong,
            N.DiaChi,
            N.MaTinh,
            N.MaPhuongXa,
            N.Email,
            N.Active,
            CASE WHEN TK.ID IS NULL THEN CAST(0 AS BIT) ELSE CAST(1 AS BIT) END AS DaCoTaiKhoan,
            TK.Ten_Dang_Nhap
        FROM dbo.DM_NhanVien N
        LEFT JOIN dbo.DM_ChucDanh CD ON CD.ID=N.IDChucDanh
        CROSS APPLY
        (
            SELECT
                STRING_AGG(CONVERT(NVARCHAR(MAX),M.IDCSKCB),N',')
                    WITHIN GROUP (ORDER BY M.IDCSKCB) AS IDCSKCBs,
                STRING_AGG(CONVERT(NVARCHAR(MAX),C.TenCSKCB),N', ')
                    WITHIN GROUP (ORDER BY M.IDCSKCB) AS TenCSKCB
            FROM dbo.DM_NhanVien_CSKCB M
            INNER JOIN dbo.DM_CSKCB C ON C.ID=M.IDCSKCB
            WHERE M.IDNhanVien=N.ID AND M.Active=1
        ) MAP
        OUTER APPLY
        (
            SELECT TOP(1) T.ID,T.Ten_Dang_Nhap
            FROM dbo.HT_Tai_Khoan T
            WHERE T.IDNhanVien=N.ID
              AND T.LaQuanTriHeThong=0
              AND (@IDCSKCB IS NULL OR T.IDCSKCB=@IDCSKCB)
            ORDER BY CASE WHEN T.Active=1 THEN 0 ELSE 1 END,T.ID DESC
        ) TK
        WHERE
            (@IDCSKCB IS NULL OR EXISTS
            (
                SELECT 1 FROM dbo.DM_NhanVien_CSKCB M0
                WHERE M0.IDNhanVien=N.ID AND M0.IDCSKCB=@IDCSKCB AND M0.Active=1
            ))
            AND
            (
                @TuKhoa IS NULL
                OR N.MaNhanVien LIKE N'%'+@TuKhoa+N'%'
                OR N.HoTen LIKE N'%'+@TuKhoa+N'%'
                OR N.DienThoai LIKE N'%'+@TuKhoa+N'%'
                OR N.Email LIKE N'%'+@TuKhoa+N'%'
                OR ISNULL(CD.TenChucDanh,N'') LIKE N'%'+@TuKhoa+N'%'
                OR ISNULL(MAP.TenCSKCB,N'') LIKE N'%'+@TuKhoa+N'%'
            )
    )
    SELECT D.*,COUNT(*) OVER() AS TongSoDong
    FROM D
    ORDER BY D.IDNhanVien DESC
    OFFSET (@Trang-1)*@KichThuocTrang ROWS
    FETCH NEXT @KichThuocTrang ROWS ONLY;
END;
GO

/* ==================== STO_HT_Nhan_Vien_Luu ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_HT_Nhan_Vien_Luu
    @IDCSKCB BIGINT,
    @IDNhanVien BIGINT=NULL,
    @MaNhanVien NVARCHAR(30),
    @HoTen NVARCHAR(200),
    @LaBacSi BIT=0,
    @IDChucDanh BIGINT=NULL,
    @CSKCBJson NVARCHAR(MAX)=N'[]',
    @DienThoai NVARCHAR(20)=NULL,
    @SoNhaTenDuong NVARCHAR(300)=NULL,
    @MaTinh NVARCHAR(20)=NULL,
    @MaPhuongXa NVARCHAR(20)=NULL,
    @Email NVARCHAR(200)=NULL,
    @Active BIT=1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        SET @MaNhanVien=NULLIF(LTRIM(RTRIM(@MaNhanVien)),N'');
        SET @HoTen=NULLIF(LTRIM(RTRIM(@HoTen)),N'');
        SET @DienThoai=NULLIF(LTRIM(RTRIM(@DienThoai)),N'');
        SET @SoNhaTenDuong=NULLIF(LTRIM(RTRIM(@SoNhaTenDuong)),N'');
        SET @MaTinh=NULLIF(LTRIM(RTRIM(@MaTinh)),N'');
        SET @MaPhuongXa=NULLIF(LTRIM(RTRIM(@MaPhuongXa)),N'');
        SET @Email=NULLIF(LTRIM(RTRIM(@Email)),N'');

        IF @IDCSKCB<=0 OR NOT EXISTS(SELECT 1 FROM dbo.DM_CSKCB WHERE ID=@IDCSKCB AND Active=1)
            THROW 51000,N'Cơ sở đang làm việc không hợp lệ.',1;
        IF @MaNhanVien IS NULL OR @HoTen IS NULL
            THROW 51000,N'Mã nhân viên và họ tên là bắt buộc.',1;
        IF @DienThoai IS NOT NULL AND (LEN(@DienThoai)>10 OR @DienThoai LIKE N'%[^0-9]%')
            THROW 51000,N'Số điện thoại chỉ được nhập số và tối đa 10 ký tự.',1;
        IF @IDChucDanh IS NOT NULL
           AND NOT EXISTS(SELECT 1 FROM dbo.DM_ChucDanh WHERE ID=@IDChucDanh AND Active=1)
            THROW 51000,N'Chức danh không tồn tại hoặc đã ngừng hoạt động.',1;
        IF ISJSON(ISNULL(@CSKCBJson,N''))<>1
            THROW 51000,N'Danh sách cơ sở làm việc không hợp lệ.',1;

        DECLARE @CS TABLE(IDCSKCB BIGINT PRIMARY KEY);
        INSERT @CS(IDCSKCB)
        SELECT DISTINCT TRY_CONVERT(BIGINT,[value])
        FROM OPENJSON(@CSKCBJson)
        WHERE TRY_CONVERT(BIGINT,[value])>0;

        IF NOT EXISTS(SELECT 1 FROM @CS WHERE IDCSKCB=@IDCSKCB)
            INSERT @CS(IDCSKCB) VALUES(@IDCSKCB);

        IF EXISTS
        (
            SELECT 1 FROM @CS X
            LEFT JOIN dbo.DM_CSKCB C ON C.ID=X.IDCSKCB AND C.Active=1
            WHERE C.ID IS NULL
        )
            THROW 51000,N'Danh sách cơ sở làm việc có cơ sở không tồn tại hoặc đã ngừng.',1;

        IF EXISTS
        (
            SELECT 1 FROM dbo.DM_NhanVien N
            WHERE N.MaNhanVien=@MaNhanVien
              AND (@IDNhanVien IS NULL OR N.ID<>@IDNhanVien)
        )
            THROW 51000,N'Mã nhân viên đã tồn tại ở hồ sơ khác.',1;

        DECLARE @TenChucDanh NVARCHAR(200)=NULL,
                @TenTinh NVARCHAR(200)=NULL,
                @TenPhuongXa NVARCHAR(200)=NULL,
                @DiaChi NVARCHAR(500)=NULL;

        IF @IDChucDanh IS NOT NULL
            SELECT @TenChucDanh=TenChucDanh FROM dbo.DM_ChucDanh WHERE ID=@IDChucDanh;

        IF @MaTinh IS NOT NULL
            SELECT TOP(1) @TenTinh=T.TenTinh
            FROM dbo.DM_TinhThanh T
            WHERE T.Active=1 AND T.MaTinh=@MaTinh
            ORDER BY CASE WHEN T.IDCSKCB=@IDCSKCB THEN 0 ELSE 1 END,T.ID;

        IF @MaPhuongXa IS NOT NULL
            SELECT TOP(1) @TenPhuongXa=P.TenPhuongXa
            FROM dbo.DM_PhuongXa P
            LEFT JOIN dbo.DM_TinhThanh T ON T.IDCSKCB=P.IDCSKCB AND T.ID=P.IDTinhThanh
            WHERE P.Active=1
              AND P.MaPhuongXa=@MaPhuongXa
              AND (@MaTinh IS NULL OR T.MaTinh=@MaTinh)
            ORDER BY CASE WHEN P.IDCSKCB=@IDCSKCB THEN 0 ELSE 1 END,P.ID;

        SET @DiaChi=NULLIF(CONCAT_WS(N', ',@SoNhaTenDuong,@TenPhuongXa,@TenTinh),N'');

        BEGIN TRAN;

        IF @IDNhanVien IS NULL OR @IDNhanVien<=0
        BEGIN
            INSERT dbo.DM_NhanVien
            (
                MaNhanVien,HoTen,LaBacSi,IDChucDanh,DienThoai,
                SoNhaTenDuong,DiaChi,MaTinh,MaPhuongXa,Email,Active
            )
            VALUES
            (
                @MaNhanVien,@HoTen,@LaBacSi,@IDChucDanh,@DienThoai,
                @SoNhaTenDuong,@DiaChi,@MaTinh,@MaPhuongXa,@Email,@Active
            );
            SET @IDNhanVien=SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            IF NOT EXISTS
            (
                SELECT 1
                FROM dbo.DM_NhanVien_CSKCB M
                WHERE M.IDNhanVien=@IDNhanVien AND M.IDCSKCB=@IDCSKCB AND M.Active=1
            )
                THROW 51000,N'Nhân viên không thuộc cơ sở đang quản lý.',1;

            UPDATE dbo.DM_NhanVien
            SET MaNhanVien=@MaNhanVien,
                HoTen=@HoTen,
                LaBacSi=@LaBacSi,
                IDChucDanh=@IDChucDanh,
                DienThoai=@DienThoai,
                SoNhaTenDuong=@SoNhaTenDuong,
                DiaChi=@DiaChi,
                MaTinh=@MaTinh,
                MaPhuongXa=@MaPhuongXa,
                Email=@Email,
                Active=@Active
            WHERE ID=@IDNhanVien;

            IF @@ROWCOUNT=0 THROW 51000,N'Không tìm thấy nhân viên.',1;
        END;

        UPDATE M
        SET Active=CASE WHEN X.IDCSKCB IS NULL THEN 0 ELSE 1 END
        FROM dbo.DM_NhanVien_CSKCB M
        LEFT JOIN @CS X ON X.IDCSKCB=M.IDCSKCB
        WHERE M.IDNhanVien=@IDNhanVien;

        UPDATE M
        SET Active=1
        FROM dbo.DM_NhanVien_CSKCB M
        INNER JOIN @CS X ON X.IDCSKCB=M.IDCSKCB
        WHERE M.IDNhanVien=@IDNhanVien;

        INSERT dbo.DM_NhanVien_CSKCB(IDNhanVien,IDCSKCB,Active)
        SELECT @IDNhanVien,X.IDCSKCB,1
        FROM @CS X
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.DM_NhanVien_CSKCB M
            WHERE M.IDNhanVien=@IDNhanVien AND M.IDCSKCB=X.IDCSKCB
        );

        COMMIT;
        SELECT 200 AS Status,N'Lưu nhân viên và cơ sở làm việc thành công.' AS Message,@IDNhanVien AS IDNhanVien;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 400 AS Status,ERROR_MESSAGE() AS Message,@IDNhanVien AS IDNhanVien;
    END CATCH
END;
GO

/* ==================== STO_HT_Nhan_Vien_Xoa ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_HT_Nhan_Vien_Xoa
    @IDCSKCB BIGINT,
    @IDNhanVien BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.DM_NhanVien_CSKCB
        WHERE IDNhanVien=@IDNhanVien AND IDCSKCB=@IDCSKCB AND Active=1
    )
    BEGIN
        SELECT 404 AS Status,N'Nhân viên không thuộc cơ sở này.' AS Message;
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRAN;

        DELETE TV
        FROM dbo.HT_Tai_Khoan_Vai_Tro TV
        INNER JOIN dbo.HT_Tai_Khoan T
          ON T.IDCSKCB=TV.IDCSKCB AND T.ID=TV.ID_Tai_Khoan
        WHERE T.IDCSKCB=@IDCSKCB AND T.IDNhanVien=@IDNhanVien;

        DELETE dbo.HT_Tai_Khoan
        WHERE IDCSKCB=@IDCSKCB AND IDNhanVien=@IDNhanVien AND LaQuanTriHeThong=0;

        UPDATE dbo.DM_NhanVien_CSKCB
        SET Active=0
        WHERE IDNhanVien=@IDNhanVien AND IDCSKCB=@IDCSKCB;

        IF NOT EXISTS
        (
            SELECT 1 FROM dbo.DM_NhanVien_CSKCB
            WHERE IDNhanVien=@IDNhanVien AND Active=1
        )
            UPDATE dbo.DM_NhanVien SET Active=0 WHERE ID=@IDNhanVien;

        COMMIT;
        SELECT 200 AS Status,N'Đã gỡ nhân viên khỏi cơ sở. Dữ liệu khám lịch sử được giữ nguyên.' AS Message;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 500 AS Status,ERROR_MESSAGE() AS Message;
    END CATCH
END;
GO

/* ==================== STO_HT_Phien_Kiem_Tra ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_HT_Phien_Kiem_Tra
    @ID_Tai_Khoan BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP(1)
        T.ID AS ID_Tai_Khoan,
        T.IDCSKCB,
        T.IDNhanVien,
        T.Ten_Dang_Nhap,
        T.Bat_Buoc_Doi_Mat_Khau,
        T.Active AS Tai_Khoan_Active,
        T.LaQuanTriHeThong,
        CASE WHEN T.LaQuanTriHeThong=1 THEN N'ADMIN' ELSE N.MaNhanVien END AS MaNhanVien,
        CASE WHEN T.LaQuanTriHeThong=1 THEN T.Ten_Dang_Nhap ELSE N.HoTen END AS HoTen,
        CASE
            WHEN T.LaQuanTriHeThong=1 THEN CAST(1 AS BIT)
            WHEN ISNULL(N.Active,0)=1 AND ISNULL(M.Active,0)=1 THEN CAST(1 AS BIT)
            ELSE CAST(0 AS BIT)
        END AS Nhan_Vien_Active,
        CASE WHEN T.LaQuanTriHeThong=1 THEN NULL ELSE C.TenCSKCB END AS TenCSKCB,
        CASE WHEN T.LaQuanTriHeThong=1 THEN CAST(1 AS BIT) ELSE ISNULL(C.Active,0) END AS CSKCB_Active
    FROM dbo.HT_Tai_Khoan T
    LEFT JOIN dbo.DM_NhanVien N
      ON T.LaQuanTriHeThong=0 AND N.ID=T.IDNhanVien
    LEFT JOIN dbo.DM_NhanVien_CSKCB M
      ON T.LaQuanTriHeThong=0 AND M.IDNhanVien=T.IDNhanVien AND M.IDCSKCB=T.IDCSKCB
    LEFT JOIN dbo.DM_CSKCB C
      ON T.LaQuanTriHeThong=0 AND C.ID=T.IDCSKCB
    WHERE T.ID=@ID_Tai_Khoan;
END;
GO

/* ==================== STO_HT_Quyen_Vai_Tro_Lay ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_HT_Quyen_Vai_Tro_Lay
    @IDCSKCB BIGINT,
    @ID_Vai_Tro BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        P.ID AS ID_Phan_He,P.Ma_Phan_He,P.Ten_Phan_He,P.Thu_Tu AS Thu_Tu_Phan_He,
        C.ID AS ID_Chuc_Nang,C.Ma_Chuc_Nang,C.Ten_Chuc_Nang,C.Duong_Dan,C.Thu_Tu AS Thu_Tu_Chuc_Nang,
        ISNULL(Q.Xem,0) AS Xem,ISNULL(Q.Them,0) AS Them,ISNULL(Q.Sua,0) AS Sua,
        ISNULL(Q.Xoa,0) AS Xoa,ISNULL(Q.Xuat,0) AS Xuat,ISNULL(Q.Ca_Nhan,0) AS Ca_Nhan
    FROM dbo.HT_Phan_He P
    INNER JOIN dbo.HT_Chuc_Nang C ON C.IDCSKCB=P.IDCSKCB AND C.ID_Phan_He=P.ID AND C.Active=1
    LEFT JOIN dbo.HT_Quyen_Vai_Tro Q ON Q.IDCSKCB=C.IDCSKCB AND Q.ID_Vai_Tro=@ID_Vai_Tro AND Q.ID_Chuc_Nang=C.ID
    WHERE P.IDCSKCB=@IDCSKCB AND P.Active=1
    ORDER BY P.Thu_Tu,P.ID,C.Thu_Tu,C.ID;
END;
GO

/* ==================== STO_HT_Quyen_Vai_Tro_Luu ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_HT_Quyen_Vai_Tro_Luu
    @IDCSKCB BIGINT,
    @ID_Vai_Tro BIGINT,
    @Quyen_Json NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS(SELECT 1 FROM dbo.DM_Vai_Tro WHERE IDCSKCB=@IDCSKCB AND ID=@ID_Vai_Tro AND Active=1)
            THROW 51000,N'Vai trò không tồn tại hoặc đã ngừng hoạt động.',1;

        DELETE dbo.HT_Quyen_Vai_Tro
        WHERE IDCSKCB=@IDCSKCB AND ID_Vai_Tro=@ID_Vai_Tro;

        INSERT dbo.HT_Quyen_Vai_Tro(IDCSKCB,ID_Vai_Tro,ID_Chuc_Nang,Xem,Them,Sua,Xoa,Xuat,Ca_Nhan)
        SELECT
            @IDCSKCB,@ID_Vai_Tro,J.ID_Chuc_Nang,J.Xem,J.Them,J.Sua,J.Xoa,J.Xuat,J.Ca_Nhan
        FROM OPENJSON(ISNULL(@Quyen_Json,N'[]'))
        WITH
        (
            ID_Chuc_Nang BIGINT '$.id_chuc_nang',
            Xem BIT '$.xem',Them BIT '$.them',Sua BIT '$.sua',Xoa BIT '$.xoa',Xuat BIT '$.xuat',Ca_Nhan BIT '$.ca_nhan'
        ) J
        INNER JOIN dbo.HT_Chuc_Nang C ON C.IDCSKCB=@IDCSKCB AND C.ID=J.ID_Chuc_Nang AND C.Active=1;

        COMMIT;
        SELECT 200 AS Status,N'Lưu phân quyền thành công.' AS Message;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SELECT 400 AS Status,ERROR_MESSAGE() AS Message;
    END CATCH
END;
GO

/* ==================== STO_HT_Tai_Khoan_Danh_Sach ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_HT_Tai_Khoan_Danh_Sach
    @IDCSKCB BIGINT=NULL,
    @TuKhoa NVARCHAR(200)=NULL,
    @Trang INT=1,
    @KichThuocTrang INT=25
AS
BEGIN
    SET NOCOUNT ON;
    SET @TuKhoa=NULLIF(LTRIM(RTRIM(@TuKhoa)),N'');
    SET @Trang=CASE WHEN @Trang<1 THEN 1 ELSE @Trang END;
    SET @KichThuocTrang=CASE WHEN @KichThuocTrang<10 THEN 10 WHEN @KichThuocTrang>100 THEN 100 ELSE @KichThuocTrang END;

    ;WITH D AS
    (
        SELECT
            T.ID AS ID_Tai_Khoan,T.IDCSKCB,C.MaCSKCB,C.TenCSKCB,T.IDNhanVien,
            N.MaNhanVien,N.HoTen,N.IDChucDanh,CD.TenChucDanh AS ChucDanh,
            T.Ten_Dang_Nhap,T.Bat_Buoc_Doi_Mat_Khau,T.So_Lan_Dang_Nhap_Sai,T.Khoa_Den_Luc,T.Lan_Dang_Nhap_Cuoi,T.Active,
            STRING_AGG(V.Ten_Vai_Tro,N', ') WITHIN GROUP (ORDER BY V.Ten_Vai_Tro,V.ID) AS Vai_Tro,
            STRING_AGG(CONVERT(NVARCHAR(MAX),V.ID),N',') AS ID_Vai_Tro
        FROM dbo.HT_Tai_Khoan T
        INNER JOIN dbo.DM_CSKCB C ON C.ID=T.IDCSKCB
        INNER JOIN dbo.DM_NhanVien N ON N.ID=T.IDNhanVien
        INNER JOIN dbo.DM_NhanVien_CSKCB M
            ON M.IDNhanVien=N.ID AND M.IDCSKCB=T.IDCSKCB AND M.Active=1
        LEFT JOIN dbo.DM_ChucDanh CD ON CD.ID=N.IDChucDanh
        LEFT JOIN dbo.HT_Tai_Khoan_Vai_Tro TV
          ON TV.IDCSKCB=T.IDCSKCB AND TV.ID_Tai_Khoan=T.ID AND TV.Active=1
        LEFT JOIN dbo.DM_Vai_Tro V
          ON V.IDCSKCB=TV.IDCSKCB AND V.ID=TV.ID_Vai_Tro AND V.Active=1
        WHERE T.LaQuanTriHeThong=0
          AND (@IDCSKCB IS NULL OR T.IDCSKCB=@IDCSKCB)
          AND
          (
              @TuKhoa IS NULL
              OR T.Ten_Dang_Nhap LIKE N'%'+@TuKhoa+N'%'
              OR N.MaNhanVien LIKE N'%'+@TuKhoa+N'%'
              OR N.HoTen LIKE N'%'+@TuKhoa+N'%'
              OR C.MaCSKCB LIKE N'%'+@TuKhoa+N'%'
              OR C.TenCSKCB LIKE N'%'+@TuKhoa+N'%'
          )
        GROUP BY
            T.ID,T.IDCSKCB,C.MaCSKCB,C.TenCSKCB,T.IDNhanVien,
            N.MaNhanVien,N.HoTen,N.IDChucDanh,CD.TenChucDanh,
            T.Ten_Dang_Nhap,T.Bat_Buoc_Doi_Mat_Khau,T.So_Lan_Dang_Nhap_Sai,
            T.Khoa_Den_Luc,T.Lan_Dang_Nhap_Cuoi,T.Active
    )
    SELECT D.*,COUNT(*) OVER() AS TongSoDong
    FROM D
    ORDER BY D.ID_Tai_Khoan DESC
    OFFSET (@Trang-1)*@KichThuocTrang ROWS
    FETCH NEXT @KichThuocTrang ROWS ONLY;
END;
GO

/* ==================== STO_HT_Tai_Khoan_Doi_Trang_Thai ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_HT_Tai_Khoan_Doi_Trang_Thai
    @IDCSKCB BIGINT,
    @ID_Tai_Khoan BIGINT,
    @Active BIT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.HT_Tai_Khoan
    SET Active=@Active,
        Khoa_Den_Luc=CASE WHEN @Active=1 THEN NULL ELSE Khoa_Den_Luc END,
        Ngay_Cap_Nhat=SYSDATETIME()
    WHERE IDCSKCB=@IDCSKCB AND ID=@ID_Tai_Khoan;

    IF @@ROWCOUNT=0 SELECT 404 AS Status, N'Không tìm thấy tài khoản.' AS Message;
    ELSE SELECT 200 AS Status, CASE WHEN @Active=1 THEN N'Đã mở tài khoản.' ELSE N'Đã khóa tài khoản.' END AS Message;
END;
GO

/* ==================== STO_HT_Tai_Khoan_Luu ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_HT_Tai_Khoan_Luu
    @IDCSKCB BIGINT,
    @ID_Tai_Khoan BIGINT=NULL,
    @IDNhanVien BIGINT,
    @Ten_Dang_Nhap NVARCHAR(150),
    @Mat_Khau_Hash NVARCHAR(1000)=NULL,
    @Vai_Tro_Json NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        SET @Ten_Dang_Nhap=LTRIM(RTRIM(@Ten_Dang_Nhap));
        IF @Ten_Dang_Nhap=N'' THROW 51000,N'Tên đăng nhập là bắt buộc.',1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.DM_NhanVien N
            INNER JOIN dbo.DM_NhanVien_CSKCB M
              ON M.IDNhanVien=N.ID AND M.IDCSKCB=@IDCSKCB AND M.Active=1
            WHERE N.ID=@IDNhanVien AND N.Active=1
        )
            THROW 51000,N'Nhân viên không thuộc cơ sở hoặc đã ngừng hoạt động.',1;

        IF EXISTS
        (
            SELECT 1 FROM dbo.HT_Tai_Khoan
            WHERE LOWER(Ten_Dang_Nhap)=LOWER(@Ten_Dang_Nhap)
              AND (@ID_Tai_Khoan IS NULL OR ID<>@ID_Tai_Khoan)
        )
            THROW 51000,N'Tên đăng nhập đã tồn tại.',1;

        IF @ID_Tai_Khoan IS NULL OR @ID_Tai_Khoan=0
        BEGIN
            IF NULLIF(@Mat_Khau_Hash,N'') IS NULL
                THROW 51000,N'Mật khẩu là bắt buộc khi tạo tài khoản.',1;
            IF EXISTS
            (
                SELECT 1 FROM dbo.HT_Tai_Khoan
                WHERE IDCSKCB=@IDCSKCB AND IDNhanVien=@IDNhanVien AND LaQuanTriHeThong=0
            )
                THROW 51000,N'Nhân viên đã có tài khoản tại cơ sở này.',1;

            INSERT dbo.HT_Tai_Khoan
            (IDCSKCB,IDNhanVien,Ten_Dang_Nhap,Mat_Khau_Hash,Bat_Buoc_Doi_Mat_Khau,LaQuanTriHeThong)
            VALUES(@IDCSKCB,@IDNhanVien,@Ten_Dang_Nhap,@Mat_Khau_Hash,0,0);
            SET @ID_Tai_Khoan=SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            IF NOT EXISTS
            (
                SELECT 1 FROM dbo.HT_Tai_Khoan
                WHERE ID=@ID_Tai_Khoan AND IDCSKCB=@IDCSKCB AND LaQuanTriHeThong=0
            )
                THROW 51000,N'Không tìm thấy tài khoản.',1;

            UPDATE dbo.HT_Tai_Khoan
            SET IDNhanVien=@IDNhanVien,
                Ten_Dang_Nhap=@Ten_Dang_Nhap,
                Mat_Khau_Hash=COALESCE(NULLIF(@Mat_Khau_Hash,N''),Mat_Khau_Hash),
                Ngay_Cap_Nhat=SYSDATETIME()
            WHERE ID=@ID_Tai_Khoan AND IDCSKCB=@IDCSKCB;
        END;

        UPDATE dbo.HT_Tai_Khoan_Vai_Tro
        SET Active=0
        WHERE IDCSKCB=@IDCSKCB AND ID_Tai_Khoan=@ID_Tai_Khoan;

        ;WITH V AS
        (
            SELECT DISTINCT TRY_CONVERT(BIGINT,[value]) AS ID_Vai_Tro
            FROM OPENJSON(ISNULL(@Vai_Tro_Json,N'[]'))
            WHERE TRY_CONVERT(BIGINT,[value]) IS NOT NULL
        )
        UPDATE TV SET Active=1
        FROM dbo.HT_Tai_Khoan_Vai_Tro TV
        INNER JOIN V ON V.ID_Vai_Tro=TV.ID_Vai_Tro
        WHERE TV.IDCSKCB=@IDCSKCB AND TV.ID_Tai_Khoan=@ID_Tai_Khoan;

        ;WITH V AS
        (
            SELECT DISTINCT TRY_CONVERT(BIGINT,[value]) AS ID_Vai_Tro
            FROM OPENJSON(ISNULL(@Vai_Tro_Json,N'[]'))
            WHERE TRY_CONVERT(BIGINT,[value]) IS NOT NULL
        )
        INSERT dbo.HT_Tai_Khoan_Vai_Tro(IDCSKCB,ID_Tai_Khoan,ID_Vai_Tro,Active)
        SELECT @IDCSKCB,@ID_Tai_Khoan,V.ID_Vai_Tro,1
        FROM V
        INNER JOIN dbo.DM_Vai_Tro R
          ON R.IDCSKCB=@IDCSKCB AND R.ID=V.ID_Vai_Tro AND R.Active=1
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.HT_Tai_Khoan_Vai_Tro X
            WHERE X.IDCSKCB=@IDCSKCB AND X.ID_Tai_Khoan=@ID_Tai_Khoan AND X.ID_Vai_Tro=V.ID_Vai_Tro
        );

        COMMIT;
        SELECT 200 AS Status,N'Lưu tài khoản thành công.' AS Message,@ID_Tai_Khoan AS ID_Tai_Khoan;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 400 AS Status,ERROR_MESSAGE() AS Message,@ID_Tai_Khoan AS ID_Tai_Khoan;
    END CATCH
END;
GO

/* ==================== STO_HT_Tai_Khoan_Lay_Theo_ID ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_HT_Tai_Khoan_Lay_Theo_ID
    @IDCSKCB BIGINT,
    @ID_Tai_Khoan BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1 ID AS ID_Tai_Khoan,Ten_Dang_Nhap
    FROM dbo.HT_Tai_Khoan
    WHERE IDCSKCB=@IDCSKCB AND ID=@ID_Tai_Khoan;
END;
GO

/* ==================== STO_HT_Tai_Khoan_Xoa ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_HT_Tai_Khoan_Xoa
    @IDCSKCB BIGINT,
    @ID_Tai_Khoan BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS(SELECT 1 FROM dbo.HT_Tai_Khoan WHERE IDCSKCB=@IDCSKCB AND ID=@ID_Tai_Khoan)
    BEGIN
        SELECT 404 AS Status,N'Không tìm thấy tài khoản.' AS Message;
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRAN;
        DELETE dbo.HT_Tai_Khoan_Vai_Tro
        WHERE IDCSKCB=@IDCSKCB AND ID_Tai_Khoan=@ID_Tai_Khoan;

        DELETE dbo.HT_Tai_Khoan
        WHERE IDCSKCB=@IDCSKCB AND ID=@ID_Tai_Khoan;
        COMMIT;

        SELECT 200 AS Status,N'Xóa tài khoản thành công.' AS Message;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        IF ERROR_NUMBER()=547
            SELECT 409 AS Status,N'Tài khoản còn dữ liệu liên quan nên chưa thể xóa.' AS Message;
        ELSE
            SELECT 500 AS Status,ERROR_MESSAGE() AS Message;
    END CATCH
END;
GO

/* ==================== STO_HT_Tai_Khoan_Reset_Mat_Khau ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_HT_Tai_Khoan_Reset_Mat_Khau
    @IDCSKCB BIGINT,
    @ID_Tai_Khoan BIGINT,
    @Mat_Khau_Hash NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.HT_Tai_Khoan
    SET Mat_Khau_Hash=@Mat_Khau_Hash,
        Bat_Buoc_Doi_Mat_Khau=0,
        So_Lan_Dang_Nhap_Sai=0,
        Khoa_Den_Luc=NULL,
        Ngay_Cap_Nhat=SYSDATETIME()
    WHERE IDCSKCB=@IDCSKCB AND ID=@ID_Tai_Khoan;

    IF @@ROWCOUNT=0 SELECT 404 AS Status, N'Không tìm thấy tài khoản.' AS Message;
    ELSE SELECT 200 AS Status, N'Đã đặt lại mật khẩu về mặc định: a' AS Message;
END;
GO

/* ==================== STO_HT_Vai_Tro_Danh_Sach ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_HT_Vai_Tro_Danh_Sach
    @IDCSKCB BIGINT=NULL,
    @TuKhoa NVARCHAR(200)=NULL,
    @Trang INT=1,
    @KichThuocTrang INT=25
AS
BEGIN
    SET NOCOUNT ON;
    SET @TuKhoa=NULLIF(LTRIM(RTRIM(@TuKhoa)),N'');
    SET @Trang=CASE WHEN @Trang<1 THEN 1 ELSE @Trang END;
    SET @KichThuocTrang=CASE WHEN @KichThuocTrang<10 THEN 10 WHEN @KichThuocTrang>100 THEN 100 ELSE @KichThuocTrang END;

    ;WITH D AS
    (
        SELECT V.ID AS ID_Vai_Tro,V.IDCSKCB,C.MaCSKCB,C.TenCSKCB,V.Ma_Vai_Tro,V.Ten_Vai_Tro,V.Mo_Ta,V.Active,V.Ngay_Tao,V.Ngay_Cap_Nhat
        FROM dbo.DM_Vai_Tro V
        INNER JOIN dbo.DM_CSKCB C ON C.ID=V.IDCSKCB
        WHERE (@IDCSKCB IS NULL OR V.IDCSKCB=@IDCSKCB)
          AND
          (
              @TuKhoa IS NULL
              OR V.Ma_Vai_Tro LIKE N'%'+@TuKhoa+N'%'
              OR V.Ten_Vai_Tro LIKE N'%'+@TuKhoa+N'%'
              OR V.Mo_Ta LIKE N'%'+@TuKhoa+N'%'
              OR C.MaCSKCB LIKE N'%'+@TuKhoa+N'%'
              OR C.TenCSKCB LIKE N'%'+@TuKhoa+N'%'
          )
    )
    SELECT D.*,COUNT(*) OVER() AS TongSoDong
    FROM D
    ORDER BY D.Active DESC,D.Ten_Vai_Tro,D.ID_Vai_Tro
    OFFSET (@Trang-1)*@KichThuocTrang ROWS
    FETCH NEXT @KichThuocTrang ROWS ONLY;
END;
GO

/* ==================== STO_HT_Vai_Tro_Luu ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_HT_Vai_Tro_Luu
    @IDCSKCB BIGINT,
    @ID_Vai_Tro BIGINT = NULL,
    @Ma_Vai_Tro NVARCHAR(100),
    @Ten_Vai_Tro NVARCHAR(300),
    @Mo_Ta NVARCHAR(1000) = NULL,
    @Active BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @Ma_Vai_Tro=LTRIM(RTRIM(@Ma_Vai_Tro));
        SET @Ten_Vai_Tro=LTRIM(RTRIM(@Ten_Vai_Tro));
        IF @Ma_Vai_Tro=N'' OR @Ten_Vai_Tro=N'' THROW 51000,N'Mã và tên vai trò là bắt buộc.',1;

        IF EXISTS(SELECT 1 FROM dbo.DM_Vai_Tro WHERE IDCSKCB=@IDCSKCB AND Ma_Vai_Tro=@Ma_Vai_Tro AND (@ID_Vai_Tro IS NULL OR ID<>@ID_Vai_Tro))
            THROW 51000,N'Mã vai trò đã tồn tại.',1;

        IF @ID_Vai_Tro IS NULL OR @ID_Vai_Tro=0
        BEGIN
            INSERT dbo.DM_Vai_Tro(IDCSKCB,Ma_Vai_Tro,Ten_Vai_Tro,Mo_Ta,Active)
            VALUES(@IDCSKCB,@Ma_Vai_Tro,@Ten_Vai_Tro,@Mo_Ta,@Active);
            SET @ID_Vai_Tro=SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE dbo.DM_Vai_Tro
            SET Ma_Vai_Tro=@Ma_Vai_Tro,Ten_Vai_Tro=@Ten_Vai_Tro,Mo_Ta=@Mo_Ta,Active=@Active,Ngay_Cap_Nhat=SYSDATETIME()
            WHERE IDCSKCB=@IDCSKCB AND ID=@ID_Vai_Tro;
        END
        SELECT 200 AS Status,N'Lưu vai trò thành công.' AS Message,@ID_Vai_Tro AS ID_Vai_Tro;
    END TRY
    BEGIN CATCH
        SELECT 400 AS Status,ERROR_MESSAGE() AS Message,@ID_Vai_Tro AS ID_Vai_Tro;
    END CATCH
END;
GO

/* ==================== STO_HT_Vai_Tro_Xoa ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_HT_Vai_Tro_Xoa
    @IDCSKCB BIGINT,
    @ID_Vai_Tro BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @MaVaiTro NVARCHAR(100)=
    (
        SELECT Ma_Vai_Tro FROM dbo.DM_Vai_Tro
        WHERE IDCSKCB=@IDCSKCB AND ID=@ID_Vai_Tro
    );

    IF @MaVaiTro IS NULL
    BEGIN
        SELECT 404 AS Status,N'Không tìm thấy vai trò.' AS Message;
        RETURN;
    END;

    IF @MaVaiTro=N'quan_tri_he_thong'
    BEGIN
        SELECT 409 AS Status,N'Không được xóa vai trò quản trị hệ thống.' AS Message;
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRAN;

        DELETE dbo.HT_Tai_Khoan_Vai_Tro
        WHERE IDCSKCB=@IDCSKCB AND ID_Vai_Tro=@ID_Vai_Tro;

        DELETE dbo.HT_Quyen_Vai_Tro
        WHERE IDCSKCB=@IDCSKCB AND ID_Vai_Tro=@ID_Vai_Tro;

        DELETE dbo.DM_Vai_Tro
        WHERE IDCSKCB=@IDCSKCB AND ID=@ID_Vai_Tro;

        COMMIT;
        SELECT 200 AS Status,N'Đã xóa hoàn toàn vai trò và gỡ khỏi mọi tài khoản.' AS Message;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 500 AS Status,ERROR_MESSAGE() AS Message;
    END CATCH
END;
GO

/* ==================== STO_DM_PhacDo_ChiTiet ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_DM_PhacDo_ChiTiet
    @IDCSKCB BIGINT,
    @ID BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    -- Result set 1: Thông tin phác đồ. Chẩn đoán nằm duy nhất ở result set 4.
    SELECT P.ID,
           P.MaPhacDo,
           P.TenPhacDo,
           P.TrieuChung,
           P.Active
    FROM dbo.DM_PhacDo P
    WHERE P.IDCSKCB = @IDCSKCB AND P.ID = @ID;

    -- Result set 2: Chi định CLS mẫu
    SELECT C.ID,
           C.IDDichVu,
           D.MaDichVu,
           D.TenDichVu,
           C.SoLuong,
           COALESCE(C.DonGia, D.DonGia) AS DonGia,
           C.GuiNgoai,
           C.NoiGuiNgoai,
           C.GhiChu
    FROM dbo.DM_PhacDo_ChiDinh C
    JOIN dbo.DM_DichVu D ON D.IDCSKCB = C.IDCSKCB AND D.ID = C.IDDichVu
    WHERE C.IDCSKCB = @IDCSKCB AND C.IDPhacDo = @ID AND C.Active = 1
    ORDER BY C.ThuTu, C.ID;

    -- Result set 3: Đơn thuốc mẫu
    SELECT T.ID,
           T.IDThuoc,
           D.MaThuoc,
           D.TenThuoc,
           D.HoatChat,
           G.MaLoaiToaThuoc,
           COALESCE(DVT.TenDVT,D.DonViTinh) AS DonViTinh,
           T.IDDonViTinhDung,
           COALESCE(DVTD.TenDVT,DVT.TenDVT,D.DonViTinh) AS DonViTinhDung,
           T.SoNgay,
           T.Sang,
           T.Trua,
           T.Chieu,
           T.Toi,
           T.LieuDung,
           T.DuongDung,
           T.CachDung,
           T.SoLuong,
           COALESCE(T.DonGia, D.GiaBan) AS DonGia,
           T.ThuTu
    FROM dbo.DM_PhacDo_Thuoc T
    JOIN dbo.DM_Thuoc D ON D.IDCSKCB = T.IDCSKCB AND D.ID = T.IDThuoc
    LEFT JOIN dbo.DM_NhomHang G ON G.IDCSKCB=D.IDCSKCB AND G.ID=D.IDNhomHang AND G.Active=1
    LEFT JOIN dbo.DM_DonViTinh DVT ON DVT.IDCSKCB=D.IDCSKCB AND DVT.ID=D.IDDonViTinh
    LEFT JOIN dbo.DM_DonViTinh DVTD ON DVTD.IDCSKCB=T.IDCSKCB AND DVTD.ID=T.IDDonViTinhDung
    WHERE T.IDCSKCB = @IDCSKCB AND T.IDPhacDo = @ID AND T.Active = 1
    ORDER BY T.ThuTu, T.ID;

    -- Result set 4: Danh sách chẩn đoán ICD-10 mẫu
    SELECT C.ID,
           C.IDICD10,
           I.MaBenh,
           I.TenBenh,
           C.BanDau,
           C.BenhChinh,
           C.BenhKhac,
           C.ThuTu
    FROM dbo.DM_PhacDo_ChanDoan C
    JOIN dbo.DM_ICD10 I ON I.IDCSKCB = C.IDCSKCB AND I.ID = C.IDICD10
    WHERE C.IDCSKCB = @IDCSKCB
      AND C.IDPhacDo = @ID
      AND C.Active = 1
    ORDER BY ISNULL(C.ThuTu, 2147483647), C.ID;
END;

GO

/* ==================== STO_DM_PhacDo_DanhSach ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_DM_PhacDo_DanhSach
    @IDCSKCB BIGINT,
    @TuKhoa NVARCHAR(200) = NULL,
    @Trang INT = 1,
    @KichThuocTrang INT = 25
AS
BEGIN
    SET NOCOUNT ON;

    SET @TuKhoa = NULLIF(LTRIM(RTRIM(@TuKhoa)), N'');
    SET @Trang = CASE WHEN @Trang < 1 THEN 1 ELSE @Trang END;
    SET @KichThuocTrang = CASE
        WHEN @KichThuocTrang < 10 THEN 10
        WHEN @KichThuocTrang > 100 THEN 100
        ELSE @KichThuocTrang
    END;

    ;WITH D AS
    (
        SELECT
            P.ID,
            P.MaPhacDo,
            P.TenPhacDo,
            CD.IDICD10,
            CD.MaBenh AS MaICD10,
            CD.TenBenh AS TenICD10,
            P.TrieuChung,
            P.Active,
            (SELECT COUNT(*) FROM dbo.DM_PhacDo_ChiDinh X WHERE X.IDCSKCB=P.IDCSKCB AND X.IDPhacDo=P.ID AND X.Active=1) AS SoLuongChiDinh,
            (SELECT COUNT(*) FROM dbo.DM_PhacDo_Thuoc X WHERE X.IDCSKCB=P.IDCSKCB AND X.IDPhacDo=P.ID AND X.Active=1) AS SoLuongThuoc
        FROM dbo.DM_PhacDo P
        OUTER APPLY
        (
            SELECT TOP(1) C.IDICD10,I.MaBenh,I.TenBenh
            FROM dbo.DM_PhacDo_ChanDoan C
            INNER JOIN dbo.DM_ICD10 I
              ON I.IDCSKCB=C.IDCSKCB AND I.ID=C.IDICD10
            WHERE C.IDCSKCB=P.IDCSKCB AND C.IDPhacDo=P.ID AND C.Active=1
            ORDER BY
                CASE WHEN C.BenhChinh=1 THEN 0 WHEN C.BanDau=1 THEN 1 ELSE 2 END,
                ISNULL(C.ThuTu,2147483647),C.ID
        ) CD
        WHERE P.IDCSKCB=@IDCSKCB
          AND P.Active=1
          AND
          (
              @TuKhoa IS NULL
              OR P.MaPhacDo LIKE N'%' + @TuKhoa + N'%'
              OR P.TenPhacDo LIKE N'%' + @TuKhoa + N'%'
              OR CD.MaBenh LIKE N'%' + @TuKhoa + N'%'
              OR CD.TenBenh LIKE N'%' + @TuKhoa + N'%'
          )
    )
    SELECT D.*,COUNT(*) OVER() AS TongSoDong
    FROM D
    ORDER BY D.MaPhacDo,D.TenPhacDo,D.ID
    OFFSET (@Trang-1)*@KichThuocTrang ROWS
    FETCH NEXT @KichThuocTrang ROWS ONLY;
END;
GO

/* ==================== STO_DM_PhacDo_Luu ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_DM_PhacDo_Luu
    @IDCSKCB BIGINT,
    @ID BIGINT = NULL OUTPUT,
    @MaPhacDo NVARCHAR(30),
    @TenPhacDo NVARCHAR(300),
    @TrieuChung NVARCHAR(2000) = NULL,
    @ChanDoanJson NVARCHAR(MAX) = N'[]',
    @ChiDinhJson NVARCHAR(MAX) = N'[]',
    @ThuocJson NVARCHAR(MAX) = N'[]'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        SET @MaPhacDo = NULLIF(LTRIM(RTRIM(@MaPhacDo)), N'');
        SET @TenPhacDo = NULLIF(LTRIM(RTRIM(@TenPhacDo)), N'');

        DECLARE @CD TABLE
        (
            IDICD10 BIGINT NOT NULL PRIMARY KEY,
            BanDau BIT NOT NULL,
            BenhChinh BIT NOT NULL,
            BenhKhac BIT NOT NULL,
            ThuTu INT NULL
        );

        IF ISJSON(@ChanDoanJson) = 1
        BEGIN
            INSERT @CD(IDICD10, BanDau, BenhChinh, BenhKhac, ThuTu)
            SELECT IDICD10,
                   ISNULL(BanDau, 0),
                   ISNULL(BenhChinh, 0),
                   ISNULL(BenhKhac, 0),
                   ThuTu
            FROM OPENJSON(@ChanDoanJson) WITH
            (
                IDICD10 BIGINT '$.IDICD10',
                BanDau BIT '$.BanDau',
                BenhChinh BIT '$.BenhChinh',
                BenhKhac BIT '$.BenhKhac',
                ThuTu INT '$.ThuTu'
            )
            WHERE IDICD10 IS NOT NULL;
        END;

        IF (SELECT COUNT(*) FROM @CD) > 12
        BEGIN
            ROLLBACK;
            SELECT 400 AS Status, N'Mỗi phác đồ chỉ được tối đa 12 chẩn đoán ICD-10.' AS Message, @ID AS ID;
            RETURN;
        END;

        IF (SELECT COUNT(*) FROM @CD WHERE BenhChinh = 1) <> 1
        BEGIN
            ROLLBACK;
            SELECT 400 AS Status, N'Phác đồ bắt buộc phải có đúng 1 bệnh chính.' AS Message, @ID AS ID;
            RETURN;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM @CD C
            LEFT JOIN dbo.DM_ICD10 I
              ON I.IDCSKCB = @IDCSKCB
             AND I.ID = C.IDICD10
             AND I.Active = 1
            WHERE I.ID IS NULL
        )
        BEGIN
            ROLLBACK;
            SELECT 400 AS Status, N'Có mã ICD-10 không hợp lệ.' AS Message, @ID AS ID;
            RETURN;
        END;

        IF @MaPhacDo IS NULL OR @TenPhacDo IS NULL
        BEGIN
            ROLLBACK;
            SELECT 400 AS Status, N'Mã và tên phác đồ là bắt buộc.' AS Message, @ID AS ID;
            RETURN;
        END;

        IF @ID IS NULL OR @ID <= 0
        BEGIN
            DECLARE @IDPhacDoTrung BIGINT,@ActivePhacDoTrung BIT;

            SELECT TOP(1)
                   @IDPhacDoTrung=ID,
                   @ActivePhacDoTrung=Active
            FROM dbo.DM_PhacDo WITH(UPDLOCK,HOLDLOCK)
            WHERE IDCSKCB=@IDCSKCB AND MaPhacDo=@MaPhacDo;

            IF @IDPhacDoTrung IS NOT NULL AND ISNULL(@ActivePhacDoTrung,0)=1
            BEGIN
                ROLLBACK;
                SELECT 409 AS Status, N'Mã phác đồ đã tồn tại.' AS Message, @ID AS ID;
                RETURN;
            END;

            IF @IDPhacDoTrung IS NOT NULL
            BEGIN
                SET @ID=@IDPhacDoTrung;
                UPDATE dbo.DM_PhacDo
                SET TenPhacDo=@TenPhacDo,
                    TrieuChung=@TrieuChung,
                    Active=1
                WHERE IDCSKCB=@IDCSKCB AND ID=@ID;
            END
            ELSE
            BEGIN
                INSERT dbo.DM_PhacDo(IDCSKCB, MaPhacDo, TenPhacDo, TrieuChung, Active)
                VALUES(@IDCSKCB, @MaPhacDo, @TenPhacDo, @TrieuChung, 1);
                SET @ID = SCOPE_IDENTITY();
            END;
        END
        ELSE
        BEGIN
            IF EXISTS
            (
                SELECT 1
                FROM dbo.DM_PhacDo WITH(UPDLOCK,HOLDLOCK)
                WHERE IDCSKCB=@IDCSKCB
                  AND MaPhacDo=@MaPhacDo
                  AND ID<>@ID
            )
            BEGIN
                ROLLBACK;
                SELECT 409 AS Status, N'Mã phác đồ đã tồn tại ở một phác đồ khác.' AS Message, @ID AS ID;
                RETURN;
            END;

            UPDATE dbo.DM_PhacDo
            SET MaPhacDo = @MaPhacDo,
                TenPhacDo = @TenPhacDo,
                TrieuChung = @TrieuChung,
                Active = 1
            WHERE IDCSKCB = @IDCSKCB AND ID = @ID;
        END;

        -- Lưu danh sách chẩn đoán ICD-10 mẫu
        DELETE FROM dbo.DM_PhacDo_ChanDoan
        WHERE IDCSKCB = @IDCSKCB AND IDPhacDo = @ID;

        INSERT dbo.DM_PhacDo_ChanDoan
        (
            IDCSKCB, IDPhacDo, IDICD10,
            BanDau, BenhChinh, BenhKhac,
            ThuTu, Active
        )
        SELECT @IDCSKCB, @ID, C.IDICD10,
               C.BanDau, C.BenhChinh, C.BenhKhac,
               C.ThuTu, 1
        FROM @CD C;

        -- Lưu Chỉ định CLS mẫu
        DELETE FROM dbo.DM_PhacDo_ChiDinh WHERE IDCSKCB = @IDCSKCB AND IDPhacDo = @ID;

        IF ISJSON(@ChiDinhJson) = 1
        BEGIN
            INSERT dbo.DM_PhacDo_ChiDinh(IDCSKCB, IDPhacDo, IDDichVu, SoLuong, DonGia, GuiNgoai, NoiGuiNgoai, GhiChu, ThuTu, Active)
            SELECT @IDCSKCB, @ID, D.ID, ISNULL(NULLIF(J.SoLuong, 0), 1), COALESCE(J.DonGia, D.DonGia), ISNULL(J.GuiNgoai, 0), J.NoiGuiNgoai, J.GhiChu, J.ThuTu, 1
            FROM OPENJSON(@ChiDinhJson) WITH
            (
                IDDichVu BIGINT '$.IDDichVu',
                SoLuong DECIMAL(10,2) '$.SoLuong',
                DonGia DECIMAL(18,2) '$.DonGia',
                GuiNgoai BIT '$.GuiNgoai',
                NoiGuiNgoai NVARCHAR(300) '$.NoiGuiNgoai',
                GhiChu NVARCHAR(500) '$.GhiChu',
                ThuTu INT '$.ThuTu'
            ) J
            JOIN dbo.DM_DichVu D ON D.IDCSKCB = @IDCSKCB AND D.ID = J.IDDichVu AND D.Active = 1;
        END;

        -- Lưu Đơn thuốc mẫu
        DELETE FROM dbo.DM_PhacDo_Thuoc WHERE IDCSKCB = @IDCSKCB AND IDPhacDo = @ID;

        IF ISJSON(@ThuocJson) = 1
        BEGIN
            INSERT dbo.DM_PhacDo_Thuoc
            (
                IDCSKCB, IDPhacDo, IDThuoc, IDDonViTinhDung,
                SoNgay, Sang, Trua, Chieu, Toi, LieuDung, DuongDung, CachDung,
                SoLuong, DonGia, ThuTu, Active
            )
            SELECT @IDCSKCB, @ID, D.ID, COALESCE(DVTD.ID,D.IDDonViTinh),
                   ISNULL(NULLIF(J.SoNgay, 0), 3), J.Sang, J.Trua, J.Chieu, J.Toi, J.LieuDung, J.DuongDung, J.CachDung,
                   ISNULL(NULLIF(J.SoLuong, 0), 1), COALESCE(J.DonGia, D.GiaBan), J.ThuTu, 1
            FROM OPENJSON(@ThuocJson) WITH
            (
                IDThuoc BIGINT '$.IDThuoc',
                IDDonViTinhDung BIGINT '$.IDDonViTinhDung',
                SoNgay INT '$.SoNgay',
                Sang NVARCHAR(50) '$.Sang',
                Trua NVARCHAR(50) '$.Trua',
                Chieu NVARCHAR(50) '$.Chieu',
                Toi NVARCHAR(50) '$.Toi',
                LieuDung NVARCHAR(300) '$.LieuDung',
                DuongDung NVARCHAR(100) '$.DuongDung',
                CachDung NVARCHAR(500) '$.CachDung',
                SoLuong DECIMAL(10,2) '$.SoLuong',
                DonGia DECIMAL(18,2) '$.DonGia',
                ThuTu INT '$.ThuTu'
            ) J
            JOIN dbo.DM_Thuoc D ON D.IDCSKCB = @IDCSKCB AND D.ID = J.IDThuoc AND D.Active = 1
            LEFT JOIN dbo.DM_DonViTinh DVTD
              ON DVTD.IDCSKCB=@IDCSKCB
             AND DVTD.ID=J.IDDonViTinhDung
             AND DVTD.Active=1;
        END;

        COMMIT;
        SELECT 200 AS Status, N'Lưu phác đồ thành công.' AS Message, @ID AS ID;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        SELECT 500 AS Status, ERROR_MESSAGE() AS Message, @ID AS ID;
    END CATCH
END;

GO

/* ==================== STO_DM_PhacDo_Xoa ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_DM_PhacDo_Xoa
    @IDCSKCB BIGINT,
    @ID BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.DM_PhacDo SET Active = 0 WHERE IDCSKCB = @IDCSKCB AND ID = @ID;
    SELECT CASE WHEN @@ROWCOUNT > 0 THEN 200 ELSE 404 END AS Status,
           CASE WHEN @@ROWCOUNT > 0 THEN N'Xóa phác đồ thành công.' ELSE N'Không tìm thấy phác đồ.' END AS Message;
END;
GO

/* ==================== STO_QL_ThuTien_CapNhatTong ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_QL_ThuTien_CapNhatTong
    @IDCSKCB BIGINT,
    @IDVaoVien BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE CT
    SET PhuThu=ROUND(ISNULL(CT.PhuThu,0),0),
        GiamPhanTram=CASE
            WHEN ISNULL(CT.GiamPhanTram,0)<0 THEN 0
            WHEN ISNULL(CT.GiamPhanTram,0)>100 THEN 100
            ELSE ISNULL(CT.GiamPhanTram,0)
        END,
        TienGiam=ROUND(
            (ROUND(ISNULL(CT.ThanhTien,0),0)+ROUND(ISNULL(CT.PhuThu,0),0))
            * CASE
                WHEN ISNULL(CT.GiamPhanTram,0)<0 THEN 0
                WHEN ISNULL(CT.GiamPhanTram,0)>100 THEN 100
                ELSE ISNULL(CT.GiamPhanTram,0)
              END / 100.0,
            0
        ),
        ThucThu=
            (ROUND(ISNULL(CT.ThanhTien,0),0)+ROUND(ISNULL(CT.PhuThu,0),0))
            - ROUND(
                (ROUND(ISNULL(CT.ThanhTien,0),0)+ROUND(ISNULL(CT.PhuThu,0),0))
                * CASE
                    WHEN ISNULL(CT.GiamPhanTram,0)<0 THEN 0
                    WHEN ISNULL(CT.GiamPhanTram,0)>100 THEN 100
                    ELSE ISNULL(CT.GiamPhanTram,0)
                  END / 100.0,
                0
              )
    FROM dbo.QL_ThuTien_CT CT
    INNER JOIN dbo.QL_ThuTien T
      ON T.IDCSKCB=CT.IDCSKCB AND T.ID=CT.IDThuTien
    WHERE T.IDCSKCB=@IDCSKCB AND T.IDVaoVien=@IDVaoVien;

    UPDATE T
    SET TongTien=X.Tong,
        TienGiam=X.Giam,
        ThucThu=X.Thuc
    FROM dbo.QL_ThuTien T
    CROSS APPLY
    (
        SELECT
            ISNULL(SUM(ROUND(ThanhTien,0)+ROUND(ISNULL(PhuThu,0),0)),0) AS Tong,
            ISNULL(SUM(ROUND(ISNULL(TienGiam,0),0)),0) AS Giam,
            ISNULL(SUM(ROUND(ISNULL(ThucThu,0),0)),0) AS Thuc
        FROM dbo.QL_ThuTien_CT
        WHERE IDCSKCB=@IDCSKCB AND IDThuTien=T.ID
    ) X
    WHERE T.IDCSKCB=@IDCSKCB AND T.IDVaoVien=@IDVaoVien;
END;
GO

/* ==================== STO_QL_BenhNhan_Xoa ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_QL_BenhNhan_Xoa @IDCSKCB BIGINT,@IDBenhNhan BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS(SELECT 1 FROM dbo.QL_VaoVien WHERE IDCSKCB=@IDCSKCB AND IDBenhNhan=@IDBenhNhan)
    BEGIN SELECT 409 AS Status,N'Bệnh nhân đã có dữ liệu lượt khám, không được xóa hồ sơ.' AS Message; RETURN; END;
    UPDATE dbo.QL_BenhNhan SET Active=0,NgayCapNhat=SYSDATETIME() WHERE IDCSKCB=@IDCSKCB AND ID=@IDBenhNhan AND Active=1;
    SELECT CASE WHEN @@ROWCOUNT>0 THEN 200 ELSE 404 END AS Status,CASE WHEN @@ROWCOUNT>0 THEN N'Xóa bệnh nhân thành công.' ELSE N'Không tìm thấy bệnh nhân.' END AS Message;
END;
GO

/* ==================== STO_QL_TiepNhan_BoCongKham ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_QL_TiepNhan_BoCongKham
    @IDCSKCB BIGINT,
    @IDVaoVien BIGINT,
    @IDCongKhamCTJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @TrangThaiKham TINYINT, @Active BIT;
        SELECT @TrangThaiKham = TrangThaiKham,
               @Active = Active
        FROM dbo.QL_VaoVien WITH (UPDLOCK, HOLDLOCK)
        WHERE IDCSKCB = @IDCSKCB
          AND ID = @IDVaoVien;

        IF @TrangThaiKham IS NULL
        BEGIN
            COMMIT;
            SELECT 404 AS Status, N'Không tìm thấy lượt khám.' AS Message, 0 AS HuyLuotKham, 0 AS SoLuongConLai;
            RETURN;
        END;

        IF @TrangThaiKham <> 0
        BEGIN
            COMMIT;
            SELECT 409 AS Status, N'Chỉ được bỏ công khám khi bệnh nhân chưa khám.' AS Message, 0 AS HuyLuotKham, 0 AS SoLuongConLai;
            RETURN;
        END;

        IF ISNULL(@Active, 0) <> 1
        BEGIN
            COMMIT;
            SELECT 404 AS Status, N'Không tìm thấy lượt khám đang hoạt động.' AS Message, 0 AS HuyLuotKham, 0 AS SoLuongConLai;
            RETURN;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.QL_ThuTien T
            INNER JOIN dbo.QL_ThuTien_CT CT
              ON CT.IDCSKCB=T.IDCSKCB AND CT.IDThuTien=T.ID
            WHERE T.IDCSKCB=@IDCSKCB
              AND T.IDVaoVien=@IDVaoVien
              AND ISNULL(CT.DaThu,0)=1
        )
        BEGIN
            COMMIT;
            SELECT 409 AS Status, N'Lượt khám đã thu tiền, không thể bỏ đăng ký công khám.' AS Message, 0 AS HuyLuotKham, 0 AS SoLuongConLai;
            RETURN;
        END;

        DECLARE @IDs TABLE (ID BIGINT PRIMARY KEY);
        IF ISJSON(@IDCongKhamCTJson)=1
        BEGIN
            INSERT INTO @IDs (ID)
            SELECT DISTINCT TRY_CONVERT(BIGINT, value)
            FROM OPENJSON(@IDCongKhamCTJson)
            WHERE TRY_CONVERT(BIGINT, value) IS NOT NULL;
        END;

        IF NOT EXISTS (SELECT 1 FROM @IDs)
        BEGIN
            COMMIT;
            SELECT 400 AS Status, N'Chưa chọn công khám nào để bỏ đăng ký.' AS Message, 0 AS HuyLuotKham, 0 AS SoLuongConLai;
            RETURN;
        END;

        DECLARE @IDCongKham BIGINT =
        (
            SELECT ID FROM dbo.QL_CongKham
            WHERE IDCSKCB = @IDCSKCB AND IDVaoVien = @IDVaoVien
        );

        IF @IDCongKham IS NULL
        BEGIN
            COMMIT;
            SELECT 404 AS Status, N'Lượt khám không có phiếu công khám.' AS Message, 0 AS HuyLuotKham, 0 AS SoLuongConLai;
            RETURN;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM @IDs I
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM dbo.QL_CongKham_CT CT
                WHERE CT.IDCSKCB = @IDCSKCB
                  AND CT.IDCongKham = @IDCongKham
                  AND CT.ID = I.ID
                  AND CT.Active = 1
            )
        )
        BEGIN
            COMMIT;
            SELECT 400 AS Status, N'Có công khám không thuộc lượt khám hoặc đã được bỏ trước đó.' AS Message, 0 AS HuyLuotKham, 0 AS SoLuongConLai;
            RETURN;
        END;

        DECLARE @IDThuTien BIGINT =
        (
            SELECT ID FROM dbo.QL_ThuTien
            WHERE IDCSKCB = @IDCSKCB AND IDVaoVien = @IDVaoVien
        );

        IF @IDThuTien IS NOT NULL
        BEGIN
            DELETE T
            FROM dbo.QL_ThuTien_CT T
            JOIN dbo.QL_CongKham_CT C
              ON C.IDCSKCB = T.IDCSKCB AND C.ID = T.IDCongKhamCT
            JOIN @IDs I ON I.ID = C.ID
            WHERE T.IDCSKCB = @IDCSKCB
              AND T.IDThuTien = @IDThuTien
              AND C.IDCongKham = @IDCongKham;
        END;

        DELETE CT
        FROM dbo.QL_CongKham_CT CT
        JOIN @IDs I ON I.ID = CT.ID
        WHERE CT.IDCSKCB = @IDCSKCB
          AND CT.IDCongKham = @IDCongKham;

        DECLARE @SoLuongConLai INT = (
            SELECT COUNT(1) FROM dbo.QL_CongKham_CT 
            WHERE IDCSKCB = @IDCSKCB AND IDCongKham = @IDCongKham AND Active = 1
        );

        IF @SoLuongConLai = 0
        BEGIN
            UPDATE dbo.QL_VaoVien
            SET DaChuyenKham = 0,
                TrangThaiKham = 0,
                ThoiGianChuyenKham = NULL,
                IDBacSiKham = NULL,
                BatDauKhamLuc = NULL,
                NgayCapNhat = SYSDATETIME()
            WHERE IDCSKCB = @IDCSKCB AND ID = @IDVaoVien;
        END;

        IF @IDThuTien IS NOT NULL
            EXEC dbo.STO_QL_ThuTien_CapNhatTong @IDCSKCB, @IDVaoVien;

        COMMIT;
        SELECT 200 AS Status,
               CASE WHEN @SoLuongConLai = 0
                    THEN N'Đã bỏ toàn bộ công khám. Lượt tiếp nhận đã được đưa về Chưa chuyển.'
                    ELSE N'Bỏ đăng ký công khám thành công.'
               END AS Message,
               0 AS HuyLuotKham,
               @SoLuongConLai AS SoLuongConLai;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        SELECT 500 AS Status, ERROR_MESSAGE() AS Message, 0 AS HuyLuotKham, 0 AS SoLuongConLai;
    END CATCH
END;
GO

/* ==================== STO_QL_TiepNhan_BoDangKy ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_QL_TiepNhan_BoDangKy
    @IDCSKCB BIGINT,
    @IDVaoVien BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @TrangThai TINYINT,@Active BIT;
        SELECT @TrangThai=TrangThaiKham,@Active=Active
        FROM dbo.QL_VaoVien WITH(UPDLOCK,HOLDLOCK)
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien;

        IF @Active IS NULL OR @Active=0
        BEGIN
            ROLLBACK;
            SELECT 404 AS Status,N'Không tìm thấy lượt tiếp nhận đang hoạt động.' AS Message;
            RETURN;
        END;

        IF ISNULL(@TrangThai,0)<>0
           OR EXISTS(SELECT 1 FROM dbo.QL_PhieuSinhHieu WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien)
           OR EXISTS(SELECT 1 FROM dbo.QL_ChanDoan_CT WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien)
           OR EXISTS(SELECT 1 FROM dbo.QL_ChiDinh_CT WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND Active=1)
           OR EXISTS(SELECT 1 FROM dbo.QL_ToaThuoc_CT WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND Active=1)
        BEGIN
            ROLLBACK;
            SELECT 409 AS Status,N'Lượt khám đã phát sinh dữ liệu khám, không được xóa đăng ký tiếp nhận.' AS Message;
            RETURN;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.QL_ThuTien T
            INNER JOIN dbo.QL_ThuTien_CT CT
              ON CT.IDCSKCB=T.IDCSKCB AND CT.IDThuTien=T.ID
            WHERE T.IDCSKCB=@IDCSKCB
              AND T.IDVaoVien=@IDVaoVien
              AND ISNULL(CT.DaThu,0)=1
        )
        BEGIN
            ROLLBACK;
            SELECT 409 AS Status,N'Lượt khám đã thu tiền, không thể xóa.' AS Message;
            RETURN;
        END;

        DELETE CT
        FROM dbo.QL_ThuTien_CT CT
        INNER JOIN dbo.QL_ThuTien T ON T.IDCSKCB=CT.IDCSKCB AND T.ID=CT.IDThuTien
        WHERE T.IDCSKCB=@IDCSKCB AND T.IDVaoVien=@IDVaoVien;

        DELETE dbo.QL_ThuTien WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien;

        DELETE CT
        FROM dbo.QL_CongKham_CT CT
        INNER JOIN dbo.QL_CongKham C ON C.IDCSKCB=CT.IDCSKCB AND C.ID=CT.IDCongKham
        WHERE C.IDCSKCB=@IDCSKCB AND C.IDVaoVien=@IDVaoVien;

        DELETE dbo.QL_CongKham WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien;

        UPDATE dbo.QL_VaoVien
        SET TrangThaiKham=3,Active=0,NgayCapNhat=SYSDATETIME()
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien;

        COMMIT;
        SELECT 200 AS Status,N'Đã hủy lượt tiếp nhận chưa phát sinh dữ liệu khám.' AS Message;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 500 AS Status,ERROR_MESSAGE() AS Message;
    END CATCH
END;
GO

/* ==================== STO_QL_TiepNhan_ChuyenKham ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_QL_TiepNhan_ChuyenKham
    @IDCSKCB BIGINT,@IDVaoVien BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IDBenhNhan BIGINT,@Ngay DATE,@NgayGioVaoVien DATETIME2(0),@TrangThaiKham TINYINT,@DaChuyenKham BIT;
    SELECT @IDBenhNhan=V.IDBenhNhan,@Ngay=V.Ngay,@NgayGioVaoVien=V.NgayGioVaoVien,
           @TrangThaiKham=V.TrangThaiKham,@DaChuyenKham=V.DaChuyenKham
    FROM dbo.QL_VaoVien V
    WHERE V.IDCSKCB=@IDCSKCB AND V.ID=@IDVaoVien AND V.Active=1;

    IF @IDBenhNhan IS NULL
    BEGIN SELECT 404 AS Status,N'Không tìm thấy lượt khám.' AS Message,@IDVaoVien AS IDVaoVien; RETURN; END;

    IF @TrangThaiKham>=2
    BEGIN SELECT 409 AS Status,N'Lượt khám đã hoàn tất hoặc đã hủy, không thể chuyển khám lại.' AS Message,@IDVaoVien AS IDVaoVien; RETURN; END;

    DECLARE @IDVaoVienTruoc BIGINT;
    SELECT TOP(1) @IDVaoVienTruoc=V.ID
    FROM dbo.QL_VaoVien V
    WHERE V.IDCSKCB=@IDCSKCB
      AND V.IDBenhNhan=@IDBenhNhan
      AND V.Ngay=@Ngay
      AND V.Active=1
      AND V.TrangThaiKham IN(0,1)
      AND V.ID<>@IDVaoVien
      AND (V.NgayGioVaoVien<@NgayGioVaoVien OR (V.NgayGioVaoVien=@NgayGioVaoVien AND V.ID<@IDVaoVien))
    ORDER BY V.NgayGioVaoVien,V.ID;

    IF @IDVaoVienTruoc IS NOT NULL
    BEGIN
        SELECT 409 AS Status,
               N'Bệnh nhân đã có một lượt khám trước đó trong ngày chưa hoàn tất. Không thể chuyển lượt tiếp nhận trùng; hãy tiếp tục lượt trước.' AS Message,
               @IDVaoVienTruoc AS IDVaoVien;
        RETURN;
    END;

    IF ISNULL(@DaChuyenKham,0)=1
    BEGIN SELECT 200 AS Status,N'Lượt khám đã được chuyển trước đó.' AS Message,@IDVaoVien AS IDVaoVien; RETURN; END;

    IF NOT EXISTS(SELECT 1 FROM dbo.QL_CongKham C JOIN dbo.QL_CongKham_CT CT ON CT.IDCSKCB=C.IDCSKCB AND CT.IDCongKham=C.ID AND CT.Active=1 WHERE C.IDCSKCB=@IDCSKCB AND C.IDVaoVien=@IDVaoVien)
    BEGIN SELECT 400 AS Status,N'Chưa chọn công khám.' AS Message,@IDVaoVien AS IDVaoVien; RETURN; END;

    UPDATE dbo.QL_VaoVien
    SET DaChuyenKham=1,ThoiGianChuyenKham=ISNULL(ThoiGianChuyenKham,SYSDATETIME()),NgayCapNhat=SYSDATETIME()
    WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien AND Active=1 AND TrangThaiKham IN(0,1);

    SELECT 200 AS Status,N'Chuyển khám thành công.' AS Message,@IDVaoVien AS IDVaoVien;
END;
GO

/* ==================== STO_QL_TiepNhan_DanhSach ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_QL_TiepNhan_DanhSach
    @IDCSKCB BIGINT,
    @TuNgay DATE=NULL,
    @DenNgay DATE=NULL,
    @DaChuyenKham BIT=NULL,
    @TuKhoa NVARCHAR(200)=NULL,
    @Trang INT=1,
    @KichThuocTrang INT=25
AS
BEGIN
    SET NOCOUNT ON;
    SET @TuKhoa=NULLIF(LTRIM(RTRIM(@TuKhoa)),N'');
    IF @Trang IS NULL OR @Trang<1 SET @Trang=1;
    IF @KichThuocTrang IS NULL OR @KichThuocTrang<1 SET @KichThuocTrang=25;
    IF @KichThuocTrang>100 SET @KichThuocTrang=100;
    DECLARE @Offset BIGINT=(CONVERT(BIGINT,@Trang)-1)*@KichThuocTrang;

    IF @TuKhoa IS NOT NULL
    BEGIN
        ;WITH TimBN AS
        (
            SELECT TOP(500)
                B.*,
                CASE
                    WHEN B.MaBN=@TuKhoa OR B.SoCCCD=@TuKhoa OR B.DienThoai=@TuKhoa THEN 0
                    WHEN B.MaBN LIKE @TuKhoa+N'%' OR B.SoCCCD LIKE @TuKhoa+N'%' OR B.DienThoai LIKE @TuKhoa+N'%' THEN 1
                    WHEN B.HoTen LIKE @TuKhoa+N'%' THEN 2
                    ELSE 3
                END AS DiemTim
            FROM dbo.QL_BenhNhan B
            WHERE B.IDCSKCB=@IDCSKCB AND B.Active=1
              AND
              (
                  B.MaBN=@TuKhoa OR B.SoCCCD=@TuKhoa OR B.DienThoai=@TuKhoa
                  OR B.MaBN LIKE @TuKhoa+N'%'
                  OR B.SoCCCD LIKE @TuKhoa+N'%'
                  OR B.DienThoai LIKE @TuKhoa+N'%'
                  OR B.HoTen LIKE N'%'+@TuKhoa+N'%'
              )
            ORDER BY
                CASE
                    WHEN B.MaBN=@TuKhoa OR B.SoCCCD=@TuKhoa OR B.DienThoai=@TuKhoa THEN 0
                    WHEN B.MaBN LIKE @TuKhoa+N'%' OR B.SoCCCD LIKE @TuKhoa+N'%' OR B.DienThoai LIKE @TuKhoa+N'%' THEN 1
                    WHEN B.HoTen LIKE @TuKhoa+N'%' THEN 2
                    ELSE 3
                END,
                B.NgayTao DESC,B.ID DESC
        ),
        X AS
        (
            SELECT
                VV.ID AS IDVaoVien,VV.MaVaoVien,VV.NgayGioVaoVien,VV.Ngay,VV.SoThuTu,
                ISNULL(VV.DaChuyenKham,0) AS DaChuyenKham,ISNULL(VV.TrangThaiKham,0) AS TrangThaiKham,
                ISNULL(VV.SinhHieu,0) AS SinhHieu,ISNULL(VV.Kham,0) AS Kham,ISNULL(VV.KeToa,0) AS KeToa,
                VV.IDNguoiTiepNhan,
                B.ID AS IDBenhNhan,B.MaBN,B.HoTen,B.NgaySinh,B.IDGioiTinh,GT.TenGioiTinh,B.SoCCCD,B.DienThoai,B.DiaChi,
                B.IDDanToc,B.IDTinhThanh,B.IDPhuongXa,B.SoNhaTenDuong,B.QuocTich,B.NgheNghiep,
                B.GiamHo_MoiQuanHe,B.GiamHo_HoTen,B.GiamHo_DienThoai,B.GiamHo_SoCCCD,
                B.GhiChu AS GhiChuBenhNhan,VV.GhiChuTiepNhan AS GhiChuLanKham,
                CASE WHEN NULLIF(LTRIM(RTRIM(B.GhiChu)),N'') IS NULL THEN 0 ELSE 1 END AS CoGhiChu,
                B.DiemTim,
                COUNT(*) OVER() AS TongSoDong
            FROM TimBN B
            INNER JOIN dbo.DM_GioiTinh GT ON GT.ID=B.IDGioiTinh AND GT.Active=1
            OUTER APPLY
            (
                SELECT TOP(1)
                    V.ID,V.MaVaoVien,V.NgayGioVaoVien,V.Ngay,V.SoThuTu,V.DaChuyenKham,V.TrangThaiKham,
                    V.SinhHieu,V.Kham,V.KeToa,V.GhiChuTiepNhan,V.IDNguoiTiepNhan
                FROM dbo.QL_VaoVien V
                WHERE V.IDCSKCB=@IDCSKCB AND V.IDBenhNhan=B.ID AND V.Active=1
                ORDER BY V.NgayGioVaoVien DESC,V.ID DESC
            ) VV
        )
        SELECT *
        FROM X
        ORDER BY DiemTim,ISNULL(NgayGioVaoVien,CONVERT(DATETIME2(0),'19000101')) DESC,IDBenhNhan DESC
        OFFSET @Offset ROWS FETCH NEXT @KichThuocTrang ROWS ONLY
        OPTION(RECOMPILE);
        RETURN;
    END;

    SET @TuNgay=ISNULL(@TuNgay,CONVERT(DATE,SYSDATETIME()));
    SET @DenNgay=ISNULL(@DenNgay,@TuNgay);

    ;WITH X AS
    (
        SELECT
            VV.ID AS IDVaoVien,VV.MaVaoVien,VV.NgayGioVaoVien,VV.Ngay,VV.SoThuTu,
            VV.DaChuyenKham,VV.TrangThaiKham,VV.SinhHieu,VV.Kham,VV.KeToa,VV.IDNguoiTiepNhan,
            B.ID AS IDBenhNhan,B.MaBN,B.HoTen,B.NgaySinh,B.IDGioiTinh,GT.TenGioiTinh,B.SoCCCD,B.DienThoai,B.DiaChi,
            B.IDDanToc,B.IDTinhThanh,B.IDPhuongXa,B.SoNhaTenDuong,B.QuocTich,B.NgheNghiep,
            B.GiamHo_MoiQuanHe,B.GiamHo_HoTen,B.GiamHo_DienThoai,B.GiamHo_SoCCCD,
            B.GhiChu AS GhiChuBenhNhan,VV.GhiChuTiepNhan AS GhiChuLanKham,
            CASE WHEN NULLIF(LTRIM(RTRIM(B.GhiChu)),N'') IS NULL THEN 0 ELSE 1 END AS CoGhiChu,
            COUNT(*) OVER() AS TongSoDong
        FROM dbo.QL_VaoVien VV
        INNER JOIN dbo.QL_BenhNhan B ON B.IDCSKCB=VV.IDCSKCB AND B.ID=VV.IDBenhNhan
        INNER JOIN dbo.DM_GioiTinh GT ON GT.ID=B.IDGioiTinh AND GT.Active=1
        WHERE VV.IDCSKCB=@IDCSKCB
          AND VV.Active=1
          AND VV.Ngay BETWEEN @TuNgay AND @DenNgay
          AND (@DaChuyenKham IS NULL OR VV.DaChuyenKham=@DaChuyenKham)
    )
    SELECT *
    FROM X
    ORDER BY NgayGioVaoVien DESC,IDVaoVien DESC
    OFFSET @Offset ROWS FETCH NEXT @KichThuocTrang ROWS ONLY
    OPTION(RECOMPILE);
END;
GO

/* ==================== STO_QL_TiepNhan_LayCongKham ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_QL_TiepNhan_LayCongKham
    @IDCSKCB BIGINT,
    @IDVaoVien BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CKC.ID AS IDCongKhamCT,
           CKC.IDCongKham,
           CKC.IDDichVu,
           DV.MaDichVu,
           DV.TenDichVu,
           CKC.SoLuong,
           CKC.DonGia,
           CKC.ThanhTien,
           CKC.GhiChu,
           VV.DaChuyenKham,
           VV.TrangThaiKham,
           ISNULL(TT.DaThu, 0) AS DaThu
    FROM dbo.QL_CongKham_CT CKC
    JOIN dbo.QL_CongKham CK ON CK.IDCSKCB = CKC.IDCSKCB AND CK.ID = CKC.IDCongKham
    JOIN dbo.QL_VaoVien VV ON VV.IDCSKCB = CK.IDCSKCB AND VV.ID = CK.IDVaoVien
    JOIN dbo.DM_DichVu DV ON DV.IDCSKCB = CKC.IDCSKCB AND DV.ID = CKC.IDDichVu
    LEFT JOIN dbo.QL_ThuTien TT ON TT.IDCSKCB = VV.IDCSKCB AND TT.IDVaoVien = VV.ID
    WHERE CKC.IDCSKCB = @IDCSKCB AND CK.IDVaoVien = @IDVaoVien AND CKC.Active = 1
    ORDER BY CKC.ID;
END;
GO

/* ==================== STO_QL_BenhNhan_KiemTraTrung ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_QL_BenhNhan_KiemTraTrung
    @IDCSKCB BIGINT,
    @IDBenhNhan BIGINT=NULL,
    @HoTen NVARCHAR(150),
    @NgaySinh DATE=NULL,
    @GioiTinh TINYINT=NULL,
    @SoCCCD NVARCHAR(20)=NULL,
    @DienThoai NVARCHAR(20)=NULL,
    @DiaChi NVARCHAR(500)=NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @HoTen=NULLIF(LTRIM(RTRIM(@HoTen)),N'');
    SET @SoCCCD=NULLIF(REPLACE(REPLACE(LTRIM(RTRIM(@SoCCCD)),N' ',N''),N'.',N''),N'');
    SET @DienThoai=NULLIF(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(@DienThoai)),N' ',N''),N'.',N''),N'-',N''),N'');
    SET @DiaChi=NULLIF(LTRIM(RTRIM(@DiaChi)),N'');

    ;WITH X AS
    (
        SELECT
            B.ID AS IDBenhNhan,B.MaBN,B.HoTen,B.NgaySinh,B.IDGioiTinh,B.SoCCCD,B.DienThoai,B.DiaChi,
            CAST
            (
                CASE
                    WHEN @SoCCCD IS NOT NULL
                     AND NULLIF(REPLACE(REPLACE(LTRIM(RTRIM(B.SoCCCD)),N' ',N''),N'.',N''),N'')=@SoCCCD
                        THEN 3
                    WHEN @HoTen IS NOT NULL AND @NgaySinh IS NOT NULL
                     AND LTRIM(RTRIM(B.HoTen))=@HoTen AND B.NgaySinh=@NgaySinh
                     AND @DienThoai IS NOT NULL
                     AND NULLIF(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(B.DienThoai)),N' ',N''),N'.',N''),N'-',N''),N'')=@DienThoai
                        THEN 2
                    WHEN @HoTen IS NOT NULL AND @NgaySinh IS NOT NULL AND @GioiTinh IS NOT NULL
                     AND LTRIM(RTRIM(B.HoTen))=@HoTen AND B.NgaySinh=@NgaySinh AND B.IDGioiTinh=@GioiTinh
                     AND @DiaChi IS NOT NULL AND LTRIM(RTRIM(ISNULL(B.DiaChi,N'')))=@DiaChi
                        THEN 2
                    WHEN @HoTen IS NOT NULL AND @NgaySinh IS NOT NULL AND @GioiTinh IS NOT NULL
                     AND LTRIM(RTRIM(B.HoTen))=@HoTen AND B.NgaySinh=@NgaySinh AND B.IDGioiTinh=@GioiTinh
                        THEN 1
                    ELSE 0
                END AS TINYINT
            ) AS MucDo
        FROM dbo.QL_BenhNhan B
        WHERE B.IDCSKCB=@IDCSKCB
          AND B.Active=1
          AND (@IDBenhNhan IS NULL OR B.ID<>@IDBenhNhan)
    )
    SELECT TOP(20)
        IDBenhNhan,MaBN,HoTen,NgaySinh,IDGioiTinh,SoCCCD,DienThoai,DiaChi,
        MucDo,
        CASE MucDo WHEN 3 THEN N'CHAC' WHEN 2 THEN N'CAO' ELSE N'GOI_Y' END AS MaMucDo
    FROM X
    WHERE MucDo>0
    ORDER BY MucDo DESC,IDBenhNhan DESC;
END;
GO

/* ==================== STO_QL_TiepNhan_Luu ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_QL_TiepNhan_Luu
    @IDCSKCB            BIGINT,
    @IDBenhNhan         BIGINT = NULL,
    @IDVaoVien          BIGINT = NULL,
    @HoTen              NVARCHAR(150),
    @NgaySinh           DATE = NULL,
    @GioiTinh           TINYINT = 1,
    @SoCCCD             NVARCHAR(20) = NULL,
    @DienThoai          NVARCHAR(20) = NULL,
    @SoNhaTenDuong      NVARCHAR(255) = NULL,
    @IDPhuongXa         BIGINT = NULL,
    @IDTinhThanh        BIGINT = NULL,
    @DiaChi             NVARCHAR(500) = NULL,
    @IDDanToc            BIGINT = NULL,
    @QuocTich           NVARCHAR(50) = NULL,
    @NgheNghiep         NVARCHAR(100) = NULL,
    @GhiChuBenhNhan     NVARCHAR(500) = NULL,
    @GiamHo_MoiQuanHe   NVARCHAR(50) = NULL,
    @GiamHo_HoTen       NVARCHAR(150) = NULL,
    @GiamHo_DienThoai   NVARCHAR(20) = NULL,
    @GiamHo_SoCCCD      NVARCHAR(20) = NULL,
    @IDNguoiTiepNhan    BIGINT = NULL,
    @GhiChuLanKham      NVARCHAR(500) = NULL,
    @SoThuTu            INT = NULL,
    @ChuyenKham         BIT = 0,
    @CongKhamJson       NVARCHAR(MAX) = NULL,
    @TaoVaoVien         BIT = 1,
    @BoQuaCanhBaoTrung  BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        SET @HoTen=NULLIF(LTRIM(RTRIM(@HoTen)),N'');
        SET @SoCCCD=NULLIF(REPLACE(REPLACE(LTRIM(RTRIM(@SoCCCD)),N' ',N''),N'.',N''),N'');
        SET @DienThoai=NULLIF(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(@DienThoai)),N' ',N''),N'.',N''),N'-',N''),N'');
        SET @DiaChi=NULLIF(LTRIM(RTRIM(@DiaChi)),N'');

        IF @HoTen IS NULL THROW 56000,N'Họ tên bệnh nhân là bắt buộc.',1;
        SET @GioiTinh=ISNULL(@GioiTinh,1);
        IF NOT EXISTS(SELECT 1 FROM dbo.DM_GioiTinh WHERE ID=@GioiTinh AND Active=1)
            THROW 56000,N'Giới tính không hợp lệ.',1;

        IF @NgaySinh IS NOT NULL AND @NgaySinh>CONVERT(DATE,SYSDATETIME())
            THROW 56000,N'Ngày sinh không được lớn hơn ngày hiện tại.',1;

        IF @IDBenhNhan IS NULL OR @IDBenhNhan<=0
        BEGIN
            DECLARE @IDBenhNhanTrung BIGINT,@MucDoTrung TINYINT;

            ;WITH X AS
            (
                SELECT
                    B.ID,
                    CAST
                    (
                        CASE
                            WHEN @SoCCCD IS NOT NULL
                             AND NULLIF(REPLACE(REPLACE(LTRIM(RTRIM(B.SoCCCD)),N' ',N''),N'.',N''),N'')=@SoCCCD
                                THEN 3
                            WHEN @NgaySinh IS NOT NULL
                             AND LTRIM(RTRIM(B.HoTen))=@HoTen AND B.NgaySinh=@NgaySinh
                             AND @DienThoai IS NOT NULL
                             AND NULLIF(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(B.DienThoai)),N' ',N''),N'.',N''),N'-',N''),N'')=@DienThoai
                                THEN 2
                            WHEN @NgaySinh IS NOT NULL
                             AND LTRIM(RTRIM(B.HoTen))=@HoTen AND B.NgaySinh=@NgaySinh AND B.IDGioiTinh=@GioiTinh
                             AND @DiaChi IS NOT NULL AND LTRIM(RTRIM(ISNULL(B.DiaChi,N'')))=@DiaChi
                                THEN 2
                            WHEN @NgaySinh IS NOT NULL
                             AND LTRIM(RTRIM(B.HoTen))=@HoTen AND B.NgaySinh=@NgaySinh AND B.IDGioiTinh=@GioiTinh
                                THEN 1
                            ELSE 0
                        END AS TINYINT
                    ) AS MucDo
                FROM dbo.QL_BenhNhan B WITH(UPDLOCK,HOLDLOCK)
                WHERE B.IDCSKCB=@IDCSKCB AND B.Active=1
            )
            SELECT TOP(1) @IDBenhNhanTrung=ID,@MucDoTrung=MucDo
            FROM X WHERE MucDo>0
            ORDER BY MucDo DESC,ID DESC;

            IF @MucDoTrung=3
            BEGIN
                ROLLBACK;
                SELECT 409 AS Status,
                       N'CCCD đã tồn tại ở một hồ sơ bệnh nhân khác. Hãy chọn hồ sơ hiện có.' AS Message,
                       @IDBenhNhanTrung AS IDBenhNhan,
                       CAST(NULL AS BIGINT) AS IDVaoVien,
                       CAST(0 AS BIT) AS CanhBaoTrung,
                       N'CHAC' AS MucDoTrung;
                RETURN;
            END;

            IF @MucDoTrung=2 AND ISNULL(@BoQuaCanhBaoTrung,0)=0
            BEGIN
                ROLLBACK;
                SELECT 409 AS Status,
                       N'Có hồ sơ rất giống (họ tên + ngày sinh + SĐT hoặc địa chỉ). Hãy đối chiếu trước khi tạo hồ sơ mới.' AS Message,
                       @IDBenhNhanTrung AS IDBenhNhan,
                       CAST(NULL AS BIGINT) AS IDVaoVien,
                       CAST(1 AS BIT) AS CanhBaoTrung,
                       N'CAO' AS MucDoTrung;
                RETURN;
            END;

            DECLARE @SeqBN BIGINT=NEXT VALUE FOR dbo.SEQ_MaBN;
            DECLARE @MaBN NVARCHAR(30)=dbo.FN_QLPM_FormatMaBN(@SeqBN);

            INSERT dbo.QL_BenhNhan
            (
                IDCSKCB,MaBN,HoTen,NgaySinh,IDGioiTinh,SoCCCD,DienThoai,
                SoNhaTenDuong,IDPhuongXa,IDTinhThanh,DiaChi,IDDanToc,QuocTich,NgheNghiep,GhiChu,
                GiamHo_MoiQuanHe,GiamHo_HoTen,GiamHo_DienThoai,GiamHo_SoCCCD,Active
            )
            VALUES
            (
                @IDCSKCB,@MaBN,@HoTen,@NgaySinh,@GioiTinh,@SoCCCD,@DienThoai,
                @SoNhaTenDuong,@IDPhuongXa,@IDTinhThanh,@DiaChi,@IDDanToc,@QuocTich,@NgheNghiep,@GhiChuBenhNhan,
                @GiamHo_MoiQuanHe,@GiamHo_HoTen,@GiamHo_DienThoai,@GiamHo_SoCCCD,1
            );
            SET @IDBenhNhan=SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE dbo.QL_BenhNhan
            SET HoTen=@HoTen,NgaySinh=@NgaySinh,IDGioiTinh=@GioiTinh,
                SoCCCD=@SoCCCD,DienThoai=@DienThoai,
                SoNhaTenDuong=@SoNhaTenDuong,IDPhuongXa=@IDPhuongXa,IDTinhThanh=@IDTinhThanh,DiaChi=@DiaChi,
                IDDanToc=@IDDanToc,QuocTich=COALESCE(NULLIF(@QuocTich,N''),QuocTich),
                NgheNghiep=COALESCE(NULLIF(@NgheNghiep,N''),NgheNghiep),
                GhiChu=@GhiChuBenhNhan,GiamHo_MoiQuanHe=@GiamHo_MoiQuanHe,GiamHo_HoTen=@GiamHo_HoTen,
                GiamHo_DienThoai=@GiamHo_DienThoai,GiamHo_SoCCCD=@GiamHo_SoCCCD,NgayCapNhat=SYSDATETIME()
            WHERE IDCSKCB=@IDCSKCB AND ID=@IDBenhNhan AND Active=1;

            IF @@ROWCOUNT=0 THROW 56000,N'Không tìm thấy bệnh nhân.',1;
        END;

        IF (@IDVaoVien IS NULL OR @IDVaoVien<=0) AND @TaoVaoVien=0
        BEGIN
            COMMIT;
            SELECT 200 AS Status,N'Lưu thông tin bệnh nhân thành công.' AS Message,@IDBenhNhan AS IDBenhNhan,
                   CAST(NULL AS BIGINT) AS IDVaoVien,CAST(0 AS BIT) AS CanhBaoTrung,CAST(NULL AS NVARCHAR(20)) AS MucDoTrung;
            RETURN;
        END;

        DECLARE @NgayHienTai DATE=CONVERT(DATE,SYSDATETIME());

        IF @IDVaoVien IS NULL OR @IDVaoVien<=0
        BEGIN
            DECLARE @IDVaoVienDangMo BIGINT;
            SELECT TOP(1) @IDVaoVienDangMo=V.ID
            FROM dbo.QL_VaoVien V WITH(UPDLOCK,HOLDLOCK)
            WHERE V.IDCSKCB=@IDCSKCB
              AND V.IDBenhNhan=@IDBenhNhan
              AND V.Ngay=@NgayHienTai
              AND V.Active=1
              AND V.TrangThaiKham IN(0,1)
            ORDER BY V.NgayGioVaoVien,V.ID;

            IF @IDVaoVienDangMo IS NOT NULL
            BEGIN
                ROLLBACK;
                SELECT 409 AS Status,
                       N'Bệnh nhân đã có lượt khám chưa hoàn tất trong ngày. Không được tiếp nhận lại; hãy tiếp tục lượt hiện tại.' AS Message,
                       @IDBenhNhan AS IDBenhNhan,@IDVaoVienDangMo AS IDVaoVien,
                       CAST(0 AS BIT) AS CanhBaoTrung,CAST(NULL AS NVARCHAR(20)) AS MucDoTrung;
                RETURN;
            END;

            IF @SoThuTu IS NULL OR @SoThuTu<=0
            BEGIN
                DECLARE @LockResult INT;
                DECLARE @LockName NVARCHAR(255)=N'QLPM_STT_'+CONVERT(NVARCHAR(30),@IDCSKCB)+N'_'+CONVERT(NVARCHAR(8),@NgayHienTai,112);
                EXEC @LockResult=sys.sp_getapplock @Resource=@LockName,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=5000;
                IF @LockResult<0 THROW 56000,N'Không thể cấp số thứ tự tiếp nhận, vui lòng thử lại.',1;

                SELECT @SoThuTu=ISNULL(MAX(SoThuTu),0)+1
                FROM dbo.QL_VaoVien
                WHERE IDCSKCB=@IDCSKCB AND Ngay=@NgayHienTai;
            END;

            DECLARE @SeqVV BIGINT=NEXT VALUE FOR dbo.SEQ_MaVaoVien;
            DECLARE @MaVV NVARCHAR(30)=N'VV'+CASE
                WHEN @SeqVV<1000000 THEN RIGHT(N'000000'+CONVERT(NVARCHAR(20),@SeqVV),6)
                ELSE CONVERT(NVARCHAR(20),@SeqVV) END;

            INSERT dbo.QL_VaoVien
            (
                IDCSKCB,MaVaoVien,IDBenhNhan,Ngay,NgayGioVaoVien,SoThuTu,
                IDNguoiTiepNhan,GhiChuTiepNhan,DaChuyenKham,ThoiGianChuyenKham,TrangThaiKham,Active
            )
            VALUES
            (
                @IDCSKCB,@MaVV,@IDBenhNhan,@NgayHienTai,SYSDATETIME(),@SoThuTu,
                @IDNguoiTiepNhan,@GhiChuLanKham,0,NULL,0,1
            );
            SET @IDVaoVien=SCOPE_IDENTITY();

            INSERT dbo.QL_CongKham(IDCSKCB,IDVaoVien,IDNguoiTao) VALUES(@IDCSKCB,@IDVaoVien,@IDNguoiTiepNhan);
            INSERT dbo.QL_ThuTien(IDCSKCB,IDVaoVien) VALUES(@IDCSKCB,@IDVaoVien);
        END
        ELSE
        BEGIN
            DECLARE @DaChuyen BIT,@TrangThai TINYINT,@DaThu BIT;
            SELECT @DaChuyen=V.DaChuyenKham,@TrangThai=V.TrangThaiKham
            FROM dbo.QL_VaoVien V WITH(UPDLOCK,HOLDLOCK)
            WHERE V.IDCSKCB=@IDCSKCB AND V.ID=@IDVaoVien AND V.IDBenhNhan=@IDBenhNhan AND V.Active=1;

            IF @TrangThai IS NULL THROW 56000,N'Không tìm thấy lượt khám.',1;

            SELECT @DaThu=CASE WHEN EXISTS
            (
                SELECT 1
                FROM dbo.QL_ThuTien T
                INNER JOIN dbo.QL_ThuTien_CT CT
                  ON CT.IDCSKCB=T.IDCSKCB AND CT.IDThuTien=T.ID
                WHERE T.IDCSKCB=@IDCSKCB
                  AND T.IDVaoVien=@IDVaoVien
                  AND ISNULL(CT.DaThu,0)=1
            ) THEN 1 ELSE 0 END;

            IF ISNULL(@DaThu,0)=1 AND @CongKhamJson IS NOT NULL
                THROW 56000,N'Lượt khám đã thu tiền, không được thay đổi công khám.',1;

            IF ISNULL(@DaChuyen,0)=1 AND @CongKhamJson IS NOT NULL
                THROW 56000,N'Lượt khám đã chuyển khám, không được sửa công khám tại tiếp nhận.',1;

            UPDATE dbo.QL_VaoVien
            SET SoThuTu=COALESCE(@SoThuTu,SoThuTu),GhiChuTiepNhan=@GhiChuLanKham,NgayCapNhat=SYSDATETIME()
            WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien;
        END;

        DECLARE @IDCongKham BIGINT=(SELECT ID FROM dbo.QL_CongKham WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien);
        DECLARE @IDThuTien BIGINT=(SELECT ID FROM dbo.QL_ThuTien WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien);

        IF @CongKhamJson IS NOT NULL
        BEGIN
            IF ISJSON(@CongKhamJson)<>1 THROW 56000,N'Dữ liệu công khám không hợp lệ.',1;

            DECLARE @CK TABLE(IDDichVu BIGINT PRIMARY KEY,SoLuong DECIMAL(10,2),GhiChu NVARCHAR(500));
            INSERT @CK(IDDichVu,SoLuong,GhiChu)
            SELECT
                COALESCE(J.IDDichVu,J.id_dich_vu),
                COALESCE(J.SoLuong,J.so_luong,1),
                COALESCE(J.GhiChu,J.ghi_chu)
            FROM OPENJSON(@CongKhamJson)
            WITH
            (
                IDDichVu BIGINT '$.IDDichVu',id_dich_vu BIGINT '$.id_dich_vu',
                SoLuong DECIMAL(10,2) '$.SoLuong',so_luong DECIMAL(10,2) '$.so_luong',
                GhiChu NVARCHAR(500) '$.GhiChu',ghi_chu NVARCHAR(500) '$.ghi_chu'
            ) J
            WHERE COALESCE(J.IDDichVu,J.id_dich_vu) IS NOT NULL;

            IF EXISTS(SELECT 1 FROM @CK WHERE SoLuong<=0)
                THROW 56000,N'Số lượng công khám phải lớn hơn 0.',1;

            IF EXISTS
            (
                SELECT 1 FROM @CK X
                WHERE NOT EXISTS(SELECT 1 FROM dbo.DM_DichVu D WHERE D.IDCSKCB=@IDCSKCB AND D.ID=X.IDDichVu AND D.Active=1)
            )
                THROW 56000,N'Có công khám không tồn tại hoặc đã ngừng hoạt động.',1;

            DELETE T
            FROM dbo.QL_ThuTien_CT T
            INNER JOIN dbo.QL_CongKham_CT C ON C.IDCSKCB=T.IDCSKCB AND C.ID=T.IDCongKhamCT
            WHERE T.IDCSKCB=@IDCSKCB AND T.IDThuTien=@IDThuTien AND C.IDCongKham=@IDCongKham;

            DELETE dbo.QL_CongKham_CT WHERE IDCSKCB=@IDCSKCB AND IDCongKham=@IDCongKham;

            INSERT dbo.QL_CongKham_CT(IDCSKCB,IDCongKham,IDDichVu,SoLuong,DonGia,ThanhTien,GhiChu,Active)
            SELECT @IDCSKCB,@IDCongKham,D.ID,X.SoLuong,D.DonGia,X.SoLuong*D.DonGia,X.GhiChu,1
            FROM @CK X
            INNER JOIN dbo.DM_DichVu D ON D.IDCSKCB=@IDCSKCB AND D.ID=X.IDDichVu AND D.Active=1;

            INSERT dbo.QL_ThuTien_CT(IDCSKCB,IDThuTien,IDCongKhamCT,SoLuong,DonGia,ThanhTien,TienGiam,ThucThu,DaThu)
            SELECT @IDCSKCB,@IDThuTien,ID,SoLuong,DonGia,ThanhTien,0,ThanhTien,0
            FROM dbo.QL_CongKham_CT
            WHERE IDCSKCB=@IDCSKCB AND IDCongKham=@IDCongKham AND Active=1;

            EXEC dbo.STO_QL_ThuTien_CapNhatTong @IDCSKCB,@IDVaoVien;
        END;

        IF @ChuyenKham=1
        BEGIN
            IF NOT EXISTS
            (
                SELECT 1
                FROM dbo.QL_CongKham C
                INNER JOIN dbo.QL_CongKham_CT CT
                  ON CT.IDCSKCB=C.IDCSKCB AND CT.IDCongKham=C.ID AND CT.Active=1
                WHERE C.IDCSKCB=@IDCSKCB AND C.IDVaoVien=@IDVaoVien
            )
                THROW 56000,N'Phải chọn ít nhất một công khám trước khi chuyển khám.',1;

            UPDATE dbo.QL_VaoVien
            SET DaChuyenKham=1,
                ThoiGianChuyenKham=COALESCE(ThoiGianChuyenKham,SYSDATETIME()),
                NgayCapNhat=SYSDATETIME()
            WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien;
        END;

        COMMIT;
        SELECT 200 AS Status,
               CASE WHEN @ChuyenKham=1 THEN N'Tiếp nhận và chuyển khám thành công.' ELSE N'Lưu tiếp nhận thành công.' END AS Message,
               @IDBenhNhan AS IDBenhNhan,@IDVaoVien AS IDVaoVien,
               CAST(0 AS BIT) AS CanhBaoTrung,CAST(NULL AS NVARCHAR(20)) AS MucDoTrung;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 400 AS Status,ERROR_MESSAGE() AS Message,
               @IDBenhNhan AS IDBenhNhan,@IDVaoVien AS IDVaoVien,
               CAST(0 AS BIT) AS CanhBaoTrung,CAST(NULL AS NVARCHAR(20)) AS MucDoTrung;
    END CATCH
END;

GO

/* ==================== STO_QL_Kham_CapNhatDangKham ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kham_CapNhatDangKham
    @IDCSKCB BIGINT,
    @IDVaoVien BIGINT,
    @IDBacSi BIGINT,
    @LaQuanTri BIT=0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @TrangThai TINYINT,@Active BIT,@DaChuyen BIT,@BSDangKham BIGINT;
        SELECT @TrangThai=TrangThaiKham,@Active=Active,@DaChuyen=DaChuyenKham,@BSDangKham=IDBacSiKham
        FROM dbo.QL_VaoVien WITH(UPDLOCK,HOLDLOCK)
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien;

        IF @Active IS NULL OR @Active=0
        BEGIN ROLLBACK; SELECT 404 AS Status,N'Không tìm thấy lượt khám.' AS Message; RETURN; END;
        IF ISNULL(@DaChuyen,0)<>1
        BEGIN ROLLBACK; SELECT 409 AS Status,N'Lượt khám chưa được chuyển khám.' AS Message; RETURN; END;
        IF @TrangThai IN(2,3)
        BEGIN ROLLBACK; SELECT 409 AS Status,N'Lượt khám đã kết thúc hoặc đã hủy.' AS Message; RETURN; END;
        IF ISNULL(@LaQuanTri,0)=0
           AND @TrangThai IN(0,1)
           AND @BSDangKham IS NOT NULL
           AND @BSDangKham<>@IDBacSi
        BEGIN ROLLBACK; SELECT 409 AS Status,N'Bệnh nhân đang được bác sĩ khác khám.' AS Message; RETURN; END;

        IF @TrangThai=0
           AND ISNULL
           (
               (SELECT TOP(1) HieuLuc
                FROM dbo.HT_Config
                WHERE IDCSKCB=@IDCSKCB
                  AND MaChucNang=N'THUCONGKHAMDVTRUOC'),
               1
           )=1
           AND EXISTS
           (
               SELECT 1
               FROM dbo.QL_ThuTien T
               INNER JOIN dbo.QL_ThuTien_CT CT
                 ON CT.IDCSKCB=T.IDCSKCB AND CT.IDThuTien=T.ID
               INNER JOIN dbo.QL_CongKham_CT CK
                 ON CK.IDCSKCB=CT.IDCSKCB AND CK.ID=CT.IDCongKhamCT AND CK.Active=1
               WHERE T.IDCSKCB=@IDCSKCB
                 AND T.IDVaoVien=@IDVaoVien
                 AND ISNULL(CT.DaThu,0)=0
                 AND ROUND(ISNULL(CT.ThucThu,CT.ThanhTien),0)>0
           )
        BEGIN
            ROLLBACK;
            SELECT 409 AS Status,N'Bệnh nhân chưa thanh toán công khám. Thu công khám trước khi bắt đầu khám.' AS Message;
            RETURN;
        END;

        UPDATE dbo.QL_VaoVien
        SET TrangThaiKham=1,
            IDBacSiKham=CASE
                WHEN ISNULL(@LaQuanTri,0)=1 AND @IDBacSi<=0 THEN IDBacSiKham
                WHEN ISNULL(@LaQuanTri,0)=1 AND @BSDangKham IS NOT NULL THEN @BSDangKham
                ELSE COALESCE(IDBacSiKham,@IDBacSi)
            END,
            BatDauKhamLuc=COALESCE(BatDauKhamLuc,SYSDATETIME()),
            NgayCapNhat=SYSDATETIME()
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien;

        COMMIT;
        SELECT 200 AS Status,N'Đã cập nhật trạng thái đang khám.' AS Message;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 409 AS Status,ERROR_MESSAGE() AS Message;
    END CATCH
END;

GO

/* ==================== STO_QL_Kham_ChiTietLanKhamCu ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kham_ChiTietLanKhamCu
    @IDCSKCB BIGINT,
    @IDVaoVienCu BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ID, MaVaoVien, TrieuChung, DanDo, NgayTaiKham, IDPhacDo, MaPDGoc
    FROM dbo.QL_VaoVien
    WHERE IDCSKCB = @IDCSKCB AND ID = @IDVaoVienCu;

    DECLARE @IDPhieu BIGINT =
    (
        SELECT TOP 1 ID
        FROM dbo.QL_PhieuSinhHieu
        WHERE IDCSKCB = @IDCSKCB AND IDVaoVien = @IDVaoVienCu
        ORDER BY NgayGioDo DESC, ID DESC
    );

    SELECT CT.IDTriSoSinhHieu, DM.MaTriSo, DM.TenTriSo, DM.DonViTinh, CT.GiaTri
    FROM dbo.QL_PhieuSinhHieu_CT CT
    JOIN dbo.DM_TriSoSinhHieu DM ON DM.IDCSKCB = CT.IDCSKCB AND DM.ID = CT.IDTriSoSinhHieu
    WHERE CT.IDCSKCB = @IDCSKCB AND CT.IDPhieuSinhHieu = @IDPhieu
    ORDER BY ISNULL(DM.ThuTu, 999), DM.ID;

    SELECT CD.IDICD10, CD.MaBenh, CD.TenBenh, CD.BanDau, CD.BenhChinh, CD.BenhKhac, CD.GhiChu
    FROM dbo.QL_ChanDoan_CT CD
    WHERE CD.IDCSKCB = @IDCSKCB AND CD.IDVaoVien = @IDVaoVienCu
    ORDER BY ISNULL(CD.ThuTu, 999), CD.ID;

    SELECT
        C.ID AS IDChiDinhCT,C.IDDichVu,D.MaDichVu,D.TenDichVu,C.SoLuong,C.DonGia,D.DonGia AS DonGiaDanhMuc,
        C.GuiNgoai,C.NoiGuiNgoai,C.GhiChu,
        CASE
            WHEN NULLIF(LTRIM(RTRIM(C.DuongDanKetQua)),N'') IS NULL THEN 0
            ELSE 2
        END AS TrangThaiKetQua,
        CAST(
            CASE
                WHEN NULLIF(LTRIM(RTRIM(C.DuongDanKetQua)),N'') IS NULL THEN 0
                ELSE 1
            END AS BIT
        ) AS CoFileKetQua,
        C.DuongDanKetQua
    FROM dbo.QL_ChiDinh_CT C
    JOIN dbo.DM_DichVu D ON D.IDCSKCB = C.IDCSKCB AND D.ID = C.IDDichVu
    WHERE C.IDCSKCB = @IDCSKCB AND C.IDVaoVien = @IDVaoVienCu AND C.Active = 1
    ORDER BY C.ID;

    SELECT
        T.IDThuoc, T.MaLoaiToaThuoc, M.MaThuoc, M.TenThuoc, COALESCE(DVTD.TenDVT,DVT.TenDVT,M.DonViTinh) AS DonViTinh, T.IDDonViTinhDung, M.HamLuong, COALESCE(NULLIF(T.HoatChat,N''),M.HoatChat) AS HoatChat,
        T.SoNgay, T.Sang, T.Trua, T.Chieu, T.Toi, T.LieuDung, T.CachDung,
        T.SoLuong, T.DonGia, T.ThanhTien, T.ID AS IDToaThuocCTGoc
    FROM dbo.QL_ToaThuoc_CT T
    JOIN dbo.DM_Thuoc M ON M.IDCSKCB = T.IDCSKCB AND M.ID = T.IDThuoc
    LEFT JOIN dbo.DM_DonViTinh DVT ON DVT.IDCSKCB=M.IDCSKCB AND DVT.ID=M.IDDonViTinh
    LEFT JOIN dbo.DM_DonViTinh DVTD ON DVTD.IDCSKCB=T.IDCSKCB AND DVTD.ID=T.IDDonViTinhDung
    WHERE T.IDCSKCB = @IDCSKCB AND T.IDVaoVien = @IDVaoVienCu AND T.Active = 1
    ORDER BY ISNULL(T.ThuTu, 999), T.ID;
END;
GO

/* ==================== STO_QL_Kham_ChonBenhNhan ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kham_ChonBenhNhan
    @IDCSKCB BIGINT,
    @IDVaoVien BIGINT,
    @IDBacSi BIGINT,
    @LaQuanTri BIT=0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @TrangThai TINYINT,@DaChuyen BIT,@BSDangKham BIGINT;
        SELECT @TrangThai=TrangThaiKham,@DaChuyen=DaChuyenKham,@BSDangKham=IDBacSiKham
        FROM dbo.QL_VaoVien
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien AND Active=1;

        IF @TrangThai IS NULL
        BEGIN ROLLBACK; SELECT 404 AS Status,N'Không tìm thấy lượt khám.' AS Message; RETURN; END;
        IF ISNULL(@DaChuyen,0)=0
        BEGIN ROLLBACK; SELECT 409 AS Status,N'Bệnh nhân chưa được chuyển khám.' AS Message; RETURN; END;
        IF @TrangThai=3
        BEGIN ROLLBACK; SELECT 409 AS Status,N'Lượt khám đã bị hủy.' AS Message; RETURN; END;

        IF ISNULL(@LaQuanTri,0)=0
           AND @TrangThai IN(0,1)
           AND @BSDangKham IS NOT NULL
           AND @BSDangKham<>@IDBacSi
        BEGIN ROLLBACK; SELECT 409 AS Status,N'Bệnh nhân đang được bác sĩ khác khám.' AS Message; RETURN; END;

        COMMIT;

        SELECT 200 AS Status,N'Tải bệnh nhân thành công.' AS Message;

        SELECT VV.*,BN.MaBN,BN.HoTen,BN.NgaySinh,BN.IDGioiTinh,GT.TenGioiTinh,BN.SoCCCD,BN.DienThoai,BN.DiaChi,BN.GhiChu AS GhiChuBenhNhan
        FROM dbo.QL_VaoVien VV
        INNER JOIN dbo.QL_BenhNhan BN ON BN.IDCSKCB=VV.IDCSKCB AND BN.ID=VV.IDBenhNhan
        INNER JOIN dbo.DM_GioiTinh GT ON GT.ID=BN.IDGioiTinh AND GT.Active=1
        WHERE VV.IDCSKCB=@IDCSKCB AND VV.ID=@IDVaoVien;

        DECLARE @IDPhieu BIGINT=
        (
            SELECT TOP(1) ID
            FROM dbo.QL_PhieuSinhHieu
            WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien
            ORDER BY NgayGioDo DESC,ID DESC
        );

        SELECT P.ID AS IDPhieuSinhHieu,P.NgayGioDo,CT.IDTriSoSinhHieu,DM.MaTriSo,DM.TenTriSo,DM.DonViTinh,CT.GiaTri
        FROM dbo.QL_PhieuSinhHieu P
        INNER JOIN dbo.QL_PhieuSinhHieu_CT CT ON CT.IDCSKCB=P.IDCSKCB AND CT.IDPhieuSinhHieu=P.ID
        INNER JOIN dbo.DM_TriSoSinhHieu DM ON DM.IDCSKCB=CT.IDCSKCB AND DM.ID=CT.IDTriSoSinhHieu
        WHERE P.IDCSKCB=@IDCSKCB AND P.ID=@IDPhieu
        ORDER BY ISNULL(DM.ThuTu,999),DM.ID;

        SELECT * FROM dbo.QL_ChanDoan_CT
        WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien
        ORDER BY ISNULL(ThuTu,999),ID;

        SELECT
            C.*,D.MaDichVu,D.TenDichVu,D.DonViTinh,D.DonGia AS DonGiaDanhMuc,
            CASE
                WHEN NULLIF(LTRIM(RTRIM(C.DuongDanKetQua)),N'') IS NULL THEN 0
                ELSE 2
            END AS TrangThaiKetQua,
            CAST(
                CASE
                    WHEN NULLIF(LTRIM(RTRIM(C.DuongDanKetQua)),N'') IS NULL THEN 0
                    ELSE 1
                END AS BIT
            ) AS CoFileKetQua,
            C.DuongDanKetQua
        FROM dbo.QL_ChiDinh_CT C
        INNER JOIN dbo.DM_DichVu D ON D.IDCSKCB=C.IDCSKCB AND D.ID=C.IDDichVu
        WHERE C.IDCSKCB=@IDCSKCB AND C.IDVaoVien=@IDVaoVien AND C.Active=1
        ORDER BY C.ID;

        SELECT T.*,DM.MaThuoc,DM.TenThuoc,COALESCE(DVTD.TenDVT,DVT.TenDVT,DM.DonViTinh) AS DonViTinh,DM.HamLuong,COALESCE(NULLIF(T.HoatChat,N''),DM.HoatChat) AS HoatChat
        FROM dbo.QL_ToaThuoc_CT T
        INNER JOIN dbo.DM_Thuoc DM ON DM.IDCSKCB=T.IDCSKCB AND DM.ID=T.IDThuoc
        LEFT JOIN dbo.DM_DonViTinh DVT ON DVT.IDCSKCB=DM.IDCSKCB AND DVT.ID=DM.IDDonViTinh
        LEFT JOIN dbo.DM_DonViTinh DVTD ON DVTD.IDCSKCB=T.IDCSKCB AND DVTD.ID=T.IDDonViTinhDung
        WHERE T.IDCSKCB=@IDCSKCB AND T.IDVaoVien=@IDVaoVien AND T.Active=1
        ORDER BY ISNULL(T.ThuTu,999),T.ID;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 409 AS Status,ERROR_MESSAGE() AS Message;
    END CATCH
END;

GO

/* ==================== STO_QL_Kham_DanhSach ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kham_DanhSach
    @IDCSKCB BIGINT,
    @Ngay DATE=NULL,
    @TrangThaiKham TINYINT=NULL,
    @TuKhoa NVARCHAR(200)=NULL,
    @Trang INT=1,
    @KichThuocTrang INT=25
AS
BEGIN
    SET NOCOUNT ON;
    SET @Ngay=ISNULL(@Ngay,CONVERT(DATE,SYSDATETIME()));
    SET @TuKhoa=NULLIF(LTRIM(RTRIM(@TuKhoa)),N'');
    IF @Trang IS NULL OR @Trang<1 SET @Trang=1;
    IF @KichThuocTrang IS NULL OR @KichThuocTrang<1 SET @KichThuocTrang=25;
    IF @KichThuocTrang>100 SET @KichThuocTrang=100;
    DECLARE @Offset BIGINT=(CONVERT(BIGINT,@Trang)-1)*@KichThuocTrang;

    ;WITH X AS
    (
        SELECT
            VV.ID AS IDVaoVien,VV.SoThuTu,VV.MaVaoVien,VV.NgayGioVaoVien,VV.ThoiGianChuyenKham,
            VV.TrangThaiKham,VV.SinhHieu,VV.Kham,VV.KeToa,VV.IDBacSiKham,
            B.ID AS IDBenhNhan,B.MaBN,B.HoTen,B.NgaySinh,B.IDGioiTinh,GT.TenGioiTinh,B.SoCCCD,B.DienThoai,
            B.GhiChu AS GhiChuBenhNhan,VV.GhiChuTiepNhan AS GhiChuLanKham,
            CASE WHEN NULLIF(LTRIM(RTRIM(B.GhiChu)),N'') IS NULL THEN 0 ELSE 1 END AS CoGhiChu,
            CASE VV.TrangThaiKham WHEN 0 THEN N'CHUA_KHAM' WHEN 1 THEN N'DANG_KHAM' WHEN 2 THEN N'DA_KHAM' ELSE N'KHAC' END AS MaTrangThaiMau,
            CASE VV.TrangThaiKham WHEN 0 THEN N'#DDF4FF' WHEN 1 THEN N'#FFF3BF' WHEN 2 THEN N'#111827' ELSE N'#F3F4F6' END AS MauNen,
            CASE VV.TrangThaiKham WHEN 2 THEN N'#FFFFFF' ELSE N'#111827' END AS MauChu,
            COUNT(*) OVER() AS TongSoDong
        FROM dbo.QL_VaoVien VV
        INNER JOIN dbo.QL_BenhNhan B ON B.IDCSKCB=VV.IDCSKCB AND B.ID=VV.IDBenhNhan
        INNER JOIN dbo.DM_GioiTinh GT ON GT.ID=B.IDGioiTinh AND GT.Active=1
        WHERE VV.IDCSKCB=@IDCSKCB
          AND VV.Ngay=@Ngay
          AND VV.DaChuyenKham=1
          AND VV.Active=1
          AND VV.TrangThaiKham IN(0,1,2)
          /* Worklist khám chỉ trả lượt đủ điều kiện vào bàn khám.
             Khi bật THUCONGKHAMDVTRUOC, lượt CHƯA khám còn công khám
             dương chưa thu sẽ nằm ở Thu ngân, không xuất hiện ở DS bác sĩ. */
          AND
          (
              VV.TrangThaiKham<>0
              OR ISNULL
                 (
                     (SELECT TOP(1) HieuLuc
                      FROM dbo.HT_Config
                      WHERE IDCSKCB=@IDCSKCB
                        AND MaChucNang=N'THUCONGKHAMDVTRUOC'),
                     1
                 )=0
              OR NOT EXISTS
                 (
                     SELECT 1
                     FROM dbo.QL_ThuTien T0
                     INNER JOIN dbo.QL_ThuTien_CT P0
                       ON P0.IDCSKCB=T0.IDCSKCB AND P0.IDThuTien=T0.ID
                     INNER JOIN dbo.QL_CongKham_CT CK0
                       ON CK0.IDCSKCB=P0.IDCSKCB AND CK0.ID=P0.IDCongKhamCT AND CK0.Active=1
                     WHERE T0.IDCSKCB=VV.IDCSKCB
                       AND T0.IDVaoVien=VV.ID
                       AND ISNULL(P0.DaThu,0)=0
                       AND ROUND(ISNULL(P0.ThucThu,P0.ThanhTien),0)>0
                 )
          )
          AND (@TrangThaiKham IS NULL OR VV.TrangThaiKham=@TrangThaiKham)
          AND
          (
              @TuKhoa IS NULL
              OR B.MaBN=@TuKhoa OR B.SoCCCD=@TuKhoa OR B.DienThoai=@TuKhoa
              OR B.MaBN LIKE @TuKhoa+N'%' OR B.SoCCCD LIKE @TuKhoa+N'%' OR B.DienThoai LIKE @TuKhoa+N'%'
              OR B.HoTen LIKE N'%'+@TuKhoa+N'%'
          )
    )
    SELECT *
    FROM X
    ORDER BY ISNULL(ThoiGianChuyenKham,NgayGioVaoVien) ASC,IDVaoVien ASC
    OFFSET @Offset ROWS FETCH NEXT @KichThuocTrang ROWS ONLY
    OPTION(RECOMPILE);
END;
GO

/* ==================== STO_QL_Kham_HuyDangKham ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kham_HuyDangKham
    @IDCSKCB BIGINT,
    @IDVaoVien BIGINT,
    @IDBacSi BIGINT,
    @LaQuanTri BIT=0
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.QL_VaoVien V
        WHERE V.IDCSKCB=@IDCSKCB AND V.ID=@IDVaoVien
          AND V.Active=1 AND V.TrangThaiKham=1
          AND V.NgayLuuKhamLanDau IS NULL
          AND ISNULL(@LaQuanTri,0)=0
          AND V.IDBacSiKham IS NOT NULL AND V.IDBacSiKham<>@IDBacSi
    )
    BEGIN
        SELECT 409 AS Status,N'Bệnh nhân đang được bác sĩ khác khám.' AS Message;
        RETURN;
    END;

    IF EXISTS(SELECT 1 FROM dbo.QL_VaoVien WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien AND NgayLuuKhamLanDau IS NOT NULL)
       OR EXISTS(SELECT 1 FROM dbo.QL_PhieuSinhHieu WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien)
       OR EXISTS(SELECT 1 FROM dbo.QL_ChanDoan_CT WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien)
       OR EXISTS(SELECT 1 FROM dbo.QL_ChiDinh_CT WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND Active=1)
       OR EXISTS(SELECT 1 FROM dbo.QL_ToaThuoc_CT WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND Active=1)
    BEGIN
        SELECT 409 AS Status,N'Lượt khám đã có dữ liệu được lưu, không thể trả về Chưa khám.' AS Message;
        RETURN;
    END;

    UPDATE dbo.QL_VaoVien
    SET TrangThaiKham=0,
        IDBacSiKham=NULL,
        BatDauKhamLuc=NULL,
        NgayCapNhat=SYSDATETIME()
    WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien
      AND TrangThaiKham=1 AND Active=1
      AND NgayLuuKhamLanDau IS NULL
      AND (ISNULL(@LaQuanTri,0)=1 OR IDBacSiKham IS NULL OR IDBacSiKham=@IDBacSi);

    SELECT CASE WHEN @@ROWCOUNT>0 THEN 200 ELSE 409 END AS Status,
           CASE WHEN @@ROWCOUNT>0 THEN N'Đã trả lượt khám về trạng thái Chưa khám.'
                ELSE N'Không thể hủy trạng thái đang khám.' END AS Message;
END;

GO

/* ==================== STO_QL_Kham_LayToaCu ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kham_LayToaCu
    @IDCSKCB BIGINT,
    @IDVaoVienCu BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT T.ID AS IDToaThuocCTGoc, T.IDThuoc, T.MaLoaiToaThuoc, DM.MaThuoc, DM.TenThuoc, COALESCE(DVTD.TenDVT,DVT.TenDVT,DM.DonViTinh) AS DonViTinh, T.IDDonViTinhDung, DM.HamLuong, COALESCE(NULLIF(T.HoatChat,N''),DM.HoatChat) AS HoatChat,
           T.SoNgay, T.Sang, T.Trua, T.Chieu, T.Toi, T.LieuDung, T.CachDung, T.SoLuong, T.DonGia, T.ThanhTien, T.ThuTu
    FROM dbo.QL_ToaThuoc_CT T
    JOIN dbo.DM_Thuoc DM ON DM.IDCSKCB = T.IDCSKCB AND DM.ID = T.IDThuoc
    LEFT JOIN dbo.DM_DonViTinh DVT ON DVT.IDCSKCB=DM.IDCSKCB AND DVT.ID=DM.IDDonViTinh
        LEFT JOIN dbo.DM_DonViTinh DVTD ON DVTD.IDCSKCB=T.IDCSKCB AND DVTD.ID=T.IDDonViTinhDung
    WHERE T.IDCSKCB = @IDCSKCB AND T.IDVaoVien = @IDVaoVienCu AND T.Active = 1
    ORDER BY ISNULL(T.ThuTu, 999), T.ID;
END;
GO

/* ==================== STO_QL_Kham_LichSu ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kham_LichSu
    @IDCSKCB BIGINT,
    @IDBenhNhan BIGINT,
    @IDVaoVienHienTai BIGINT = NULL,
    @TuKhoa NVARCHAR(200) = NULL,
    @Trang INT = 1,
    @KichThuocTrang INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    SET @TuKhoa = NULLIF(LTRIM(RTRIM(@TuKhoa)), N'');
    SET @Trang = CASE WHEN @Trang < 1 THEN 1 ELSE @Trang END;
    SET @KichThuocTrang = CASE
        WHEN @KichThuocTrang < 10 THEN 10
        WHEN @KichThuocTrang > 100 THEN 100
        ELSE @KichThuocTrang
    END;

    SELECT
        VV.ID AS IDVaoVien,
        VV.MaVaoVien,
        VV.NgayGioVaoVien,
        VV.BatDauKhamLuc,
        VV.KetThucKhamLuc,
        VV.TrieuChung,
        VV.NgayTaiKham,
        VV.DanDo,
        NV.HoTen AS BacSiKham,
        STRING_AGG(
            (CASE WHEN CD.BanDau = 1 THEN N'[BĐ] ' ELSE N'' END) +
            (CASE WHEN CD.BenhChinh = 1 THEN N'[Chính] ' ELSE N'' END) +
            (CASE WHEN CD.BenhKhac = 1 THEN N'[#] ' ELSE N'' END) +
            CD.MaBenh + N' - ' + CD.TenBenh,
            N'; '
        ) AS ChanDoan,
        (SELECT COUNT(1)
         FROM dbo.QL_ToaThuoc_CT T
         WHERE T.IDCSKCB = VV.IDCSKCB
           AND T.IDVaoVien = VV.ID
           AND T.Active = 1) AS SoLuongThuoc,
        (SELECT COUNT(1)
         FROM dbo.QL_ChiDinh_CT C
         WHERE C.IDCSKCB = VV.IDCSKCB
           AND C.IDVaoVien = VV.ID
           AND C.Active = 1) AS SoLuongChiDinh,
        COUNT(*) OVER() AS TongSoDong
    FROM dbo.QL_VaoVien VV
    LEFT JOIN dbo.DM_NhanVien NV
      ON NV.ID = VV.IDBacSiKham
    LEFT JOIN dbo.QL_ChanDoan_CT CD
      ON CD.IDCSKCB = VV.IDCSKCB
     AND CD.IDVaoVien = VV.ID
    WHERE VV.IDCSKCB = @IDCSKCB
      AND VV.IDBenhNhan = @IDBenhNhan
      /* Lịch sử chỉ nhận lượt đã Khám xong.
         Kham/KeToa là cờ legacy, có dữ liệu toa không đồng nghĩa đã hoàn tất. */
      AND VV.TrangThaiKham = 2
      /* Lượt hiện tại đã Khám xong cũng là một hồ sơ lịch sử hợp lệ. */
      AND (@IDVaoVienHienTai IS NULL OR VV.ID <> @IDVaoVienHienTai OR VV.TrangThaiKham = 2)
      AND VV.Active = 1
      AND
      (
          @TuKhoa IS NULL
          OR NV.HoTen LIKE N'%' + @TuKhoa + N'%'
          OR VV.TrieuChung LIKE N'%' + @TuKhoa + N'%'
          OR CONVERT(NVARCHAR(10), VV.NgayGioVaoVien, 103) LIKE N'%' + @TuKhoa + N'%'
          OR EXISTS
          (
              SELECT 1
              FROM dbo.QL_ChanDoan_CT X
              WHERE X.IDCSKCB = VV.IDCSKCB
                AND X.IDVaoVien = VV.ID
                AND
                (
                    X.MaBenh LIKE N'%' + @TuKhoa + N'%'
                    OR X.TenBenh LIKE N'%' + @TuKhoa + N'%'
                )
          )
      )
    GROUP BY
        VV.ID, VV.MaVaoVien, VV.NgayGioVaoVien, VV.BatDauKhamLuc, VV.KetThucKhamLuc,
        VV.TrieuChung, VV.NgayTaiKham, VV.DanDo, NV.HoTen, VV.IDCSKCB
    ORDER BY VV.NgayGioVaoVien DESC, VV.ID DESC
    OFFSET (@Trang - 1) * @KichThuocTrang ROWS
    FETCH NEXT @KichThuocTrang ROWS ONLY;
END;
GO

/* ==================== STO_QL_Kham_Luu ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kham_Luu
    @IDCSKCB BIGINT,
    @IDVaoVien BIGINT,
    @IDBacSi BIGINT,
    @TrieuChung NVARCHAR(2000)=NULL,
    @IDPhacDo BIGINT=NULL,
    @MaPDGoc NVARCHAR(50)=NULL,
    @NgayTaiKham DATE=NULL,
    @DanDo NVARCHAR(1000)=NULL,
    @SinhHieuJson NVARCHAR(MAX)=NULL,
    @ChanDoanJson NVARCHAR(MAX)=NULL,
    @ChiDinhJson NVARCHAR(MAX)=NULL,
    @ToaThuocJson NVARCHAR(MAX)=NULL,
    @KhamXong BIT=0,
    @LaQuanTri BIT=0,
    @CoQuyenSua BIT=0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @TrangThaiHienTai TINYINT,@IDThuTien BIGINT,@BSDangKham BIGINT,@IDBacSiNghiepVu BIGINT;
        DECLARE @FilesToDelete TABLE(ID BIGINT PRIMARY KEY,DuongDanTuongDoi NVARCHAR(1000) NOT NULL);
        DECLARE @CIXoa TABLE(ID BIGINT PRIMARY KEY);
        SELECT @TrangThaiHienTai=V.TrangThaiKham,@BSDangKham=V.IDBacSiKham
        FROM dbo.QL_VaoVien V WITH(UPDLOCK,HOLDLOCK)
        WHERE V.IDCSKCB=@IDCSKCB AND V.ID=@IDVaoVien AND V.Active=1 AND V.DaChuyenKham=1;

        IF @TrangThaiHienTai IS NULL THROW 57000,N'Không tìm thấy lượt khám hoặc chưa chuyển khám.',1;
        IF @TrangThaiHienTai=3 THROW 57000,N'Lượt khám đã bị hủy.',1;
        IF @TrangThaiHienTai=2
            THROW 57000,N'Lượt khám đã hoàn tất; không được phép chỉnh sửa.',1;
        IF ISNULL(@LaQuanTri,0)=0
           AND @BSDangKham IS NOT NULL
           AND @BSDangKham<>@IDBacSi
            THROW 57000,N'Bệnh nhân đang thuộc phiên khám của bác sĩ khác.',1;

        SET @IDBacSiNghiepVu=CASE
            WHEN ISNULL(@LaQuanTri,0)=1 THEN @BSDangKham
            ELSE @IDBacSi
        END;

        SELECT @IDThuTien=ID FROM dbo.QL_ThuTien WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien;
        IF EXISTS
        (
            SELECT 1
            FROM dbo.QL_ThuTien_CT CT
            WHERE CT.IDCSKCB=@IDCSKCB
              AND CT.IDThuTien=@IDThuTien
              AND ISNULL(CT.DaThu,0)=1
        )
            THROW 57000,N'Lượt khám đã phát sinh khoản thu, không thể thay đổi dữ liệu.',1;

        IF @IDPhacDo IS NOT NULL
           AND NOT EXISTS(SELECT 1 FROM dbo.DM_PhacDo WHERE IDCSKCB=@IDCSKCB AND ID=@IDPhacDo AND Active=1)
            THROW 57000,N'Phác đồ không hợp lệ.',1;

        UPDATE dbo.QL_VaoVien
        SET IDBacSiKham=@IDBacSiNghiepVu,
            TrieuChung=@TrieuChung,IDPhacDo=@IDPhacDo,
            MaPDGoc=NULLIF(LTRIM(RTRIM(@MaPDGoc)),N''),
            NgayTaiKham=@NgayTaiKham,DanDo=@DanDo,
            BatDauKhamLuc=COALESCE(BatDauKhamLuc,SYSDATETIME()),
            NgayLuuKhamLanDau=COALESCE(NgayLuuKhamLanDau,SYSDATETIME()),
            NgayCapNhatKham=SYSDATETIME(),NgayCapNhat=SYSDATETIME()
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien;

        /* NULL/[] = khong sua sinh hieu; moi IDVaoVien chi co mot phieu sinh hieu. */
        IF @SinhHieuJson IS NOT NULL
        BEGIN
            IF ISJSON(@SinhHieuJson)<>1 THROW 57000,N'Dữ liệu sinh hiệu không hợp lệ.',1;
            IF EXISTS
            (
                SELECT 1 FROM OPENJSON(@SinhHieuJson)
                WITH(GiaTri NVARCHAR(100) '$.GiaTri')
                WHERE NULLIF(LTRIM(RTRIM(GiaTri)),N'') IS NOT NULL
            )
            BEGIN
                DECLARE @IDPhieuSH BIGINT;
                SELECT TOP (1) @IDPhieuSH=P.ID
                FROM dbo.QL_PhieuSinhHieu P WITH(UPDLOCK,HOLDLOCK)
                WHERE P.IDCSKCB=@IDCSKCB AND P.IDVaoVien=@IDVaoVien
                ORDER BY P.NgayGioDo DESC,P.ID DESC;

                IF @IDPhieuSH IS NULL
                BEGIN
                    INSERT dbo.QL_PhieuSinhHieu(IDCSKCB,IDVaoVien,IDNhanVien,NgayGioDo)
                    VALUES(@IDCSKCB,@IDVaoVien,@IDBacSiNghiepVu,SYSDATETIME());
                    SET @IDPhieuSH=SCOPE_IDENTITY();
                END
                ELSE
                BEGIN
                    UPDATE dbo.QL_PhieuSinhHieu
                    SET IDNhanVien=@IDBacSiNghiepVu,
                        NgayGioDo=SYSDATETIME()
                    WHERE IDCSKCB=@IDCSKCB AND ID=@IDPhieuSH;
                    DELETE dbo.QL_PhieuSinhHieu_CT
                    WHERE IDCSKCB=@IDCSKCB AND IDPhieuSinhHieu=@IDPhieuSH;
                END;

                INSERT dbo.QL_PhieuSinhHieu_CT(IDCSKCB,IDPhieuSinhHieu,IDTriSoSinhHieu,GiaTri)
                SELECT @IDCSKCB,@IDPhieuSH,J.IDTriSoSinhHieu,J.GiaTri
                FROM OPENJSON(@SinhHieuJson)
                WITH(IDTriSoSinhHieu BIGINT '$.IDTriSoSinhHieu',GiaTri NVARCHAR(100) '$.GiaTri') J
                INNER JOIN dbo.DM_TriSoSinhHieu D ON D.IDCSKCB=@IDCSKCB AND D.ID=J.IDTriSoSinhHieu AND D.Active=1
                WHERE NULLIF(LTRIM(RTRIM(J.GiaTri)),N'') IS NOT NULL;

                IF EXISTS(SELECT 1 FROM dbo.QL_PhieuSinhHieu_CT WHERE IDCSKCB=@IDCSKCB AND IDPhieuSinhHieu=@IDPhieuSH)
                    UPDATE dbo.QL_VaoVien SET SinhHieu=1 WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien;
            END;
        END;

        /* Chan doan: NULL = giu nguyen; [] = xoa het. */
        IF @ChanDoanJson IS NOT NULL
        BEGIN
            IF ISJSON(@ChanDoanJson)<>1 THROW 57000,N'Dữ liệu chẩn đoán không hợp lệ.',1;
            DECLARE @CD TABLE(IDICD10 BIGINT PRIMARY KEY,BanDau BIT,BenhChinh BIT,BenhKhac BIT,ThuTu INT,GhiChu NVARCHAR(500));
            INSERT @CD
            SELECT IDICD10,ISNULL(BanDau,0),ISNULL(BenhChinh,0),ISNULL(BenhKhac,0),ThuTu,GhiChu
            FROM OPENJSON(@ChanDoanJson)
            WITH(IDICD10 BIGINT '$.IDICD10',BanDau BIT '$.BanDau',BenhChinh BIT '$.BenhChinh',BenhKhac BIT '$.BenhKhac',ThuTu INT '$.ThuTu',GhiChu NVARCHAR(500) '$.GhiChu')
            WHERE IDICD10 IS NOT NULL;

            IF (@KhamXong=1 AND (SELECT COUNT(*) FROM @CD WHERE BenhChinh=1)<>1)
               OR (ISNULL(@KhamXong,0)=0 AND (SELECT COUNT(*) FROM @CD WHERE BenhChinh=1)>1)
            BEGIN
                ROLLBACK;
                SELECT 400 AS Status,N'Chẩn đoán bắt buộc phải có đúng 1 bệnh chính.' AS Message;
                RETURN;
            END;
            IF EXISTS
            (
                SELECT 1 FROM @CD C
                WHERE NOT EXISTS(SELECT 1 FROM dbo.DM_ICD10 I WHERE I.IDCSKCB=@IDCSKCB AND I.ID=C.IDICD10)
            )
                THROW 57000,N'Có mã ICD-10 không hợp lệ.',1;

            DELETE dbo.QL_ChanDoan_CT WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien;
            INSERT dbo.QL_ChanDoan_CT(IDCSKCB,IDVaoVien,IDICD10,MaBenh,TenBenh,BanDau,BenhChinh,BenhKhac,ThuTu,IDBacSi,GhiChu)
            SELECT @IDCSKCB,@IDVaoVien,I.ID,I.MaBenh,I.TenBenh,C.BanDau,C.BenhChinh,C.BenhKhac,C.ThuTu,@IDBacSiNghiepVu,C.GhiChu
            FROM @CD C INNER JOIN dbo.DM_ICD10 I ON I.IDCSKCB=@IDCSKCB AND I.ID=C.IDICD10;
        END
        ELSE IF (@KhamXong=1 AND
                 (SELECT COUNT(*) FROM dbo.QL_ChanDoan_CT WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND BenhChinh=1)<>1)
             OR (ISNULL(@KhamXong,0)=0 AND
                 (SELECT COUNT(*) FROM dbo.QL_ChanDoan_CT WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND BenhChinh=1)>1)
        BEGIN
            ROLLBACK;
            SELECT 400 AS Status,N'Chẩn đoán bắt buộc phải có đúng 1 bệnh chính.' AS Message;
            RETURN;
        END;

        /* Chi dinh: giu ID de ket qua/file CLS khong bi dut lien ket. */
        IF @ChiDinhJson IS NOT NULL
        BEGIN
            IF ISJSON(@ChiDinhJson)<>1 THROW 57000,N'Dữ liệu chỉ định không hợp lệ.',1;

            DECLARE @CI TABLE
            (
                ID BIGINT NULL,IDDichVu BIGINT NOT NULL,NgayGioChiDinh DATETIME2(0) NULL,SoLuong DECIMAL(10,2) NOT NULL,
                DonGia DECIMAL(18,2) NULL,GuiNgoai BIT NOT NULL,NoiGuiNgoai NVARCHAR(300) NULL,GhiChu NVARCHAR(500) NULL
            );

            INSERT @CI(ID,IDDichVu,NgayGioChiDinh,SoLuong,DonGia,GuiNgoai,NoiGuiNgoai,GhiChu)
            SELECT NULL,J.IDDichVu,J.NgayGioChiDinh,COALESCE(J.SoLuong,1),NULL,ISNULL(J.GuiNgoai,0),J.NoiGuiNgoai,J.GhiChu
            FROM OPENJSON(@ChiDinhJson)
            WITH
            (
                IDDichVu BIGINT '$.IDDichVu',NgayGioChiDinh DATETIME2(0) '$.NgayGioChiDinh',
                SoLuong DECIMAL(10,2) '$.SoLuong',DonGia DECIMAL(18,2) '$.DonGia',
                GuiNgoai BIT '$.GuiNgoai',NoiGuiNgoai NVARCHAR(300) '$.NoiGuiNgoai',GhiChu NVARCHAR(500) '$.GhiChu'
            ) J
            WHERE J.IDDichVu IS NOT NULL;

            IF EXISTS(SELECT 1 FROM @CI WHERE SoLuong<=0)
                THROW 57000,N'Số lượng chỉ định CLS phải lớn hơn 0.',1;

            /* Khong nhan ID dong chi tiet tu client.
               Trong mot luot kham UI khong cho chon trung dich vu, nen tim dong
               hien co bang IDCSKCB + IDVaoVien + IDDichVu. */
            UPDATE X
            SET ID=M.ID
            FROM @CI X
            OUTER APPLY
            (
                SELECT TOP(1) C.ID
                FROM dbo.QL_ChiDinh_CT C WITH(UPDLOCK,HOLDLOCK)
                WHERE C.IDCSKCB=@IDCSKCB
                  AND C.IDVaoVien=@IDVaoVien
                  AND C.IDDichVu=X.IDDichVu
                  AND C.Active=1
                ORDER BY C.ID
            ) M
            WHERE M.ID IS NOT NULL;

            IF EXISTS
            (
                SELECT 1 FROM @CI X
                WHERE NOT EXISTS(SELECT 1 FROM dbo.DM_DichVu D WHERE D.IDCSKCB=@IDCSKCB AND D.ID=X.IDDichVu AND D.Active=1 AND D.LoaiDichVu<>1)
            )
                THROW 57000,N'Có dịch vụ CLS không hợp lệ.',1;

            INSERT @CIXoa(ID)
            SELECT C.ID
            FROM dbo.QL_ChiDinh_CT C WITH(UPDLOCK,HOLDLOCK)
            WHERE C.IDCSKCB=@IDCSKCB AND C.IDVaoVien=@IDVaoVien AND C.Active=1
              AND NOT EXISTS(SELECT 1 FROM @CI X WHERE X.ID=C.ID);

            INSERT @FilesToDelete(ID,DuongDanTuongDoi)
            SELECT C.ID,C.DuongDanKetQua
            FROM @CIXoa X
            INNER JOIN dbo.QL_ChiDinh_CT C ON C.ID=X.ID AND C.IDCSKCB=@IDCSKCB
            WHERE C.IDVaoVien=@IDVaoVien AND NULLIF(LTRIM(RTRIM(C.DuongDanKetQua)),N'') IS NOT NULL;

            DELETE T
            FROM dbo.QL_ThuTien_CT T
            INNER JOIN dbo.QL_ChiDinh_CT C ON C.IDCSKCB=T.IDCSKCB AND C.ID=T.IDChiDinhCT
            WHERE T.IDCSKCB=@IDCSKCB AND T.IDThuTien=@IDThuTien AND C.IDVaoVien=@IDVaoVien;

            UPDATE C
            SET Active=0
            FROM dbo.QL_ChiDinh_CT C
            WHERE C.IDCSKCB=@IDCSKCB AND C.IDVaoVien=@IDVaoVien AND C.Active=1
              AND NOT EXISTS(SELECT 1 FROM @CI X WHERE X.ID=C.ID);

            UPDATE C
            SET IDDichVu=X.IDDichVu,NgayGioChiDinh=COALESCE(X.NgayGioChiDinh,C.NgayGioChiDinh),SoLuong=X.SoLuong,
                DonGia=CASE WHEN X.GuiNgoai=1 THEN 0 ELSE D.DonGia END,
                ThanhTien=CASE WHEN X.GuiNgoai=1 THEN 0 ELSE X.SoLuong*D.DonGia END,
                GuiNgoai=X.GuiNgoai,
                NoiGuiNgoai=CASE WHEN X.GuiNgoai=1 THEN X.NoiGuiNgoai END,GhiChu=X.GhiChu
            FROM dbo.QL_ChiDinh_CT C
            INNER JOIN @CI X ON X.ID=C.ID
            INNER JOIN dbo.DM_DichVu D ON D.IDCSKCB=@IDCSKCB AND D.ID=X.IDDichVu
            WHERE C.IDCSKCB=@IDCSKCB AND C.IDVaoVien=@IDVaoVien AND C.Active=1;

            INSERT dbo.QL_ChiDinh_CT
            (
                IDCSKCB,IDVaoVien,IDDichVu,NgayGioChiDinh,SoLuong,DonGia,ThanhTien,GuiNgoai,NoiGuiNgoai,IDBacSiChiDinh,TrangThai,GhiChu,Active
            )
            SELECT @IDCSKCB,@IDVaoVien,D.ID,COALESCE(X.NgayGioChiDinh,SYSDATETIME()),X.SoLuong,
                   CASE WHEN X.GuiNgoai=1 THEN 0 ELSE D.DonGia END,
                   CASE WHEN X.GuiNgoai=1 THEN 0 ELSE X.SoLuong*D.DonGia END,
                   X.GuiNgoai,
                   CASE WHEN X.GuiNgoai=1 THEN X.NoiGuiNgoai END,@IDBacSiNghiepVu,0,X.GhiChu,1
            FROM @CI X
            INNER JOIN dbo.DM_DichVu D ON D.IDCSKCB=@IDCSKCB AND D.ID=X.IDDichVu
            WHERE ISNULL(X.ID,0)<=0;

            IF @IDThuTien IS NOT NULL
                INSERT dbo.QL_ThuTien_CT(IDCSKCB,IDThuTien,IDChiDinhCT,SoLuong,DonGia,ThanhTien,TienGiam,ThucThu,DaThu)
                SELECT @IDCSKCB,@IDThuTien,C.ID,C.SoLuong,C.DonGia,C.ThanhTien,0,C.ThanhTien,0
                FROM dbo.QL_ChiDinh_CT C
                WHERE C.IDCSKCB=@IDCSKCB AND C.IDVaoVien=@IDVaoVien AND C.Active=1;
        END;

        /* Toa: diff/upsert de giu ID, NULL = giu nguyen. */
        IF @ToaThuocJson IS NOT NULL
        BEGIN
            IF ISJSON(@ToaThuocJson)<>1 THROW 57000,N'Dữ liệu toa thuốc không hợp lệ.',1;

            DECLARE @TT TABLE
            (
                ID BIGINT NULL,IDThuoc BIGINT NOT NULL,MaLoaiToaThuoc NVARCHAR(1) NOT NULL,SoNgay INT NULL,Sang NVARCHAR(50) NULL,Trua NVARCHAR(50) NULL,
                Chieu NVARCHAR(50) NULL,Toi NVARCHAR(50) NULL,LieuDung NVARCHAR(300) NULL,CachDung NVARCHAR(500) NULL,
                NgayKe DATETIME2(0) NULL,SoLuong DECIMAL(10,2) NOT NULL,DonGia DECIMAL(18,2) NULL,ThuTu INT NULL,IDToaThuocCTGoc BIGINT NULL,
                IDDonViTinhDung BIGINT NULL
            );

            IF EXISTS
            (
                SELECT 1
                FROM OPENJSON(@ToaThuocJson)
                WITH(IDThuoc BIGINT '$.IDThuoc',SoLuong DECIMAL(10,2) '$.SoLuong')
                WHERE IDThuoc IS NOT NULL AND ISNULL(SoLuong,0)<=0
            )
                THROW 57000,N'Số lượng thuốc phải lớn hơn 0.',1;

            INSERT @TT
            SELECT NULL,J.IDThuoc,COALESCE(NULLIF(LOWER(LTRIM(RTRIM(J.MaLoaiToaThuoc))),N''),N'c'),J.SoNgay,J.Sang,J.Trua,J.Chieu,J.Toi,J.LieuDung,J.CachDung,
                   J.NgayKe,J.SoLuong,NULL,J.ThuTu,J.IDToaThuocCTGoc,J.IDDonViTinhDung
            FROM OPENJSON(@ToaThuocJson)
            WITH
            (
                IDThuoc BIGINT '$.IDThuoc',MaLoaiToaThuoc NVARCHAR(1) '$.MaLoaiToaThuoc',SoNgay INT '$.SoNgay',
                Sang NVARCHAR(50) '$.Sang',Trua NVARCHAR(50) '$.Trua',Chieu NVARCHAR(50) '$.Chieu',Toi NVARCHAR(50) '$.Toi',
                LieuDung NVARCHAR(300) '$.LieuDung',CachDung NVARCHAR(500) '$.CachDung',NgayKe DATETIME2(0) '$.NgayKe',SoLuong DECIMAL(10,2) '$.SoLuong',
                DonGia DECIMAL(18,2) '$.DonGia',ThuTu INT '$.ThuTu',IDToaThuocCTGoc BIGINT '$.IDToaThuocCTGoc',
                IDDonViTinhDung BIGINT '$.IDDonViTinhDung'
            ) J
            WHERE J.IDThuoc IS NOT NULL AND J.SoLuong>0;

            IF EXISTS(SELECT 1 FROM @TT WHERE ISNULL(ThuTu,0)<=0)
                THROW 57000,N'Thứ tự dòng toa thuốc không hợp lệ.',1;
            IF EXISTS(SELECT ThuTu FROM @TT GROUP BY ThuTu HAVING COUNT(*)>1)
                THROW 57000,N'Thứ tự dòng toa thuốc bị lặp.',1;

            /* Khong nhan ID dong toa tu client.
               Tim dong hien co bang IDCSKCB + IDVaoVien + ThuTu. */
            UPDATE X
            SET ID=M.ID
            FROM @TT X
            OUTER APPLY
            (
                SELECT TOP(1) T.ID
                FROM dbo.QL_ToaThuoc_CT T WITH(UPDLOCK,HOLDLOCK)
                WHERE T.IDCSKCB=@IDCSKCB
                  AND T.IDVaoVien=@IDVaoVien
                  AND T.ThuTu=X.ThuTu
                  AND T.Active=1
                ORDER BY T.ID
            ) M
            WHERE M.ID IS NOT NULL;
            IF EXISTS(SELECT 1 FROM @TT WHERE MaLoaiToaThuoc NOT IN(N'c',N'n',N'h'))
                THROW 57000,N'Loại toa thuốc không hợp lệ.',1;
            /* Một lượt khám được kê đồng thời nhiều loại toa c/n/h.
               MaLoaiToaThuoc được lưu riêng trên từng dòng và chỉ tách khi in. */
            IF EXISTS
            (
                SELECT 1 FROM @TT X
                WHERE NOT EXISTS(SELECT 1 FROM dbo.DM_Thuoc D WHERE D.IDCSKCB=@IDCSKCB AND D.ID=X.IDThuoc AND D.Active=1)
            )
                THROW 57000,N'Có thuốc không hợp lệ.',1;
            IF EXISTS
            (
                SELECT 1 FROM @TT X
                WHERE X.IDDonViTinhDung IS NOT NULL
                  AND NOT EXISTS
                  (
                      SELECT 1
                      FROM dbo.DM_DonViTinh DVT
                      WHERE DVT.IDCSKCB=@IDCSKCB
                        AND DVT.ID=X.IDDonViTinhDung
                        AND DVT.Active=1
                  )
            )
                THROW 57000,N'Đơn vị tính dùng không hợp lệ.',1;
            DELETE X
            FROM dbo.QL_ThuTien_CT X
            INNER JOIN dbo.QL_ToaThuoc_CT T ON T.IDCSKCB=X.IDCSKCB AND T.ID=X.IDToaThuocCT
            WHERE X.IDCSKCB=@IDCSKCB AND X.IDThuTien=@IDThuTien AND T.IDVaoVien=@IDVaoVien;

            UPDATE T
            SET Active=0
            FROM dbo.QL_ToaThuoc_CT T
            WHERE T.IDCSKCB=@IDCSKCB AND T.IDVaoVien=@IDVaoVien AND T.Active=1
              AND NOT EXISTS(SELECT 1 FROM @TT X WHERE X.ID=T.ID);

            UPDATE T
            SET IDThuoc=X.IDThuoc,MaLoaiToaThuoc=X.MaLoaiToaThuoc,IDBacSiKe=@IDBacSiNghiepVu,NgayKe=COALESCE(X.NgayKe,T.NgayKe),SoNgay=X.SoNgay,Sang=X.Sang,Trua=X.Trua,
                Chieu=X.Chieu,Toi=X.Toi,LieuDung=X.LieuDung,CachDung=X.CachDung,SoLuong=X.SoLuong,
                DonGia=D.GiaBan,ThanhTien=X.SoLuong*D.GiaBan,
                ThuTu=X.ThuTu,IDToaThuocCTGoc=X.IDToaThuocCTGoc,
                IDDonViTinhDung=COALESCE(X.IDDonViTinhDung,D.IDDonViTinh),
                HoatChat=CASE
                    WHEN T.IDThuoc=X.IDThuoc AND NULLIF(LTRIM(RTRIM(T.HoatChat)),N'') IS NOT NULL THEN T.HoatChat
                    ELSE D.HoatChat
                END
            FROM dbo.QL_ToaThuoc_CT T
            INNER JOIN @TT X ON X.ID=T.ID
            INNER JOIN dbo.DM_Thuoc D ON D.IDCSKCB=@IDCSKCB AND D.ID=X.IDThuoc
            WHERE T.IDCSKCB=@IDCSKCB AND T.IDVaoVien=@IDVaoVien AND T.Active=1;

            INSERT dbo.QL_ToaThuoc_CT
            (
                IDCSKCB,IDVaoVien,IDThuoc,MaLoaiToaThuoc,NgayKe,IDBacSiKe,SoNgay,Sang,Trua,Chieu,Toi,LieuDung,CachDung,
                SoLuong,DonGia,ThanhTien,ThuTu,IDToaThuocCTGoc,IDDonViTinhDung,HoatChat,Active
            )
            SELECT @IDCSKCB,@IDVaoVien,D.ID,X.MaLoaiToaThuoc,COALESCE(X.NgayKe,SYSDATETIME()),@IDBacSiNghiepVu,X.SoNgay,X.Sang,X.Trua,X.Chieu,X.Toi,X.LieuDung,X.CachDung,
                   X.SoLuong,D.GiaBan,X.SoLuong*D.GiaBan,X.ThuTu,X.IDToaThuocCTGoc,COALESCE(X.IDDonViTinhDung,D.IDDonViTinh),D.HoatChat,1
            FROM @TT X
            INNER JOIN dbo.DM_Thuoc D ON D.IDCSKCB=@IDCSKCB AND D.ID=X.IDThuoc
            WHERE ISNULL(X.ID,0)<=0;

            IF @IDThuTien IS NOT NULL
                INSERT dbo.QL_ThuTien_CT(IDCSKCB,IDThuTien,IDToaThuocCT,SoLuong,DonGia,ThanhTien,TienGiam,ThucThu,DaThu)
                SELECT @IDCSKCB,@IDThuTien,T.ID,T.SoLuong,T.DonGia,T.ThanhTien,0,T.ThanhTien,0
                FROM dbo.QL_ToaThuoc_CT T
                WHERE T.IDCSKCB=@IDCSKCB AND T.IDVaoVien=@IDVaoVien AND T.Active=1;

            UPDATE dbo.QL_VaoVien
            SET KeToa=CASE WHEN EXISTS(SELECT 1 FROM dbo.QL_ToaThuoc_CT WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND Active=1) THEN 1 ELSE 0 END
            WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien;
        END;

        IF @IDThuTien IS NOT NULL EXEC dbo.STO_QL_ThuTien_CapNhatTong @IDCSKCB,@IDVaoVien;

        DECLARE @TrangThaiMoi TINYINT=CASE
            WHEN @TrangThaiHienTai=2 OR @KhamXong=1 THEN 2
            WHEN @TrangThaiHienTai=0 THEN 1
            ELSE @TrangThaiHienTai
        END;

        UPDATE dbo.QL_VaoVien
        SET TrangThaiKham=@TrangThaiMoi,
            Kham=CASE WHEN @KhamXong=1 THEN 1 ELSE Kham END,
            KetThucKhamLuc=CASE WHEN @KhamXong=1 THEN COALESCE(KetThucKhamLuc,SYSDATETIME()) ELSE KetThucKhamLuc END,
            NgayCapNhat=SYSDATETIME()
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien;

        COMMIT;
        /* Chỉ yêu cầu xóa file vật lý sau khi giao dịch SQL đã commit.
           Không trả danh sách nếu lưu không thành công. */
        SELECT 200 AS Status,
               CASE WHEN @TrangThaiMoi=2 THEN N'Khám bệnh hoàn tất thành công.' ELSE N'Lưu dữ liệu khám thành công.' END AS Message,
               ISNULL((SELECT F.DuongDanTuongDoi
                       FROM @FilesToDelete AS F
                       FOR JSON PATH),N'[]') AS FilesToDeleteJson;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 400 AS Status,N'Không thể lưu khám bệnh do dữ liệu không hợp lệ hoặc đã thay đổi.' AS Message;
    END CATCH
END;

GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_Kham_HoanTat
    @IDCSKCB BIGINT,
    @IDVaoVien BIGINT,
    @IDBacSi BIGINT,
    @LaQuanTri BIT=0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @TrangThai TINYINT,@DaChuyen BIT,@BSDangKham BIGINT,@NgayLuuKhamLanDau DATETIME2(0);
        SELECT @TrangThai=V.TrangThaiKham,@DaChuyen=V.DaChuyenKham,@BSDangKham=V.IDBacSiKham,
               @NgayLuuKhamLanDau=V.NgayLuuKhamLanDau
        FROM dbo.QL_VaoVien V WITH(UPDLOCK,HOLDLOCK)
        WHERE V.IDCSKCB=@IDCSKCB AND V.ID=@IDVaoVien AND V.Active=1;

        IF @TrangThai IS NULL THROW 57000,N'Không tìm thấy lượt khám.',1;
        IF ISNULL(@DaChuyen,0)<>1 THROW 57000,N'Lượt khám chưa được chuyển khám.',1;
        IF @TrangThai=3 THROW 57000,N'Lượt khám đã bị hủy.',1;

        IF @NgayLuuKhamLanDau IS NULL
            THROW 57000,N'Lượt khám chưa được lưu.',1;

        IF @TrangThai=2
        BEGIN
            COMMIT;
            SELECT 200 AS Status,N'Lượt khám đã hoàn tất.' AS Message,
                   @IDVaoVien AS IDVaoVien,CAST(2 AS TINYINT) AS TrangThaiKham;
            RETURN;
        END;

        IF ISNULL(@LaQuanTri,0)=0
           AND @BSDangKham IS NOT NULL
           AND @BSDangKham<>@IDBacSi
            THROW 57000,N'Bệnh nhân đang thuộc phiên khám của bác sĩ khác.',1;

        IF (SELECT COUNT(*) FROM dbo.QL_ChanDoan_CT
            WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND BenhChinh=1)<>1
            THROW 57000,N'Chẩn đoán bắt buộc phải có đúng 1 bệnh chính.',1;

        UPDATE dbo.QL_VaoVien
        SET TrangThaiKham=2,
            Kham=1,
            KetThucKhamLuc=COALESCE(KetThucKhamLuc,SYSDATETIME()),
            NgayCapNhatKham=SYSDATETIME(),
            NgayCapNhat=SYSDATETIME()
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien;

        COMMIT;
        SELECT 200 AS Status,N'Khám bệnh hoàn tất thành công.' AS Message,
               @IDVaoVien AS IDVaoVien,CAST(2 AS TINYINT) AS TrangThaiKham;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 400 AS Status,ERROR_MESSAGE() AS Message,
               @IDVaoVien AS IDVaoVien,CAST(NULL AS TINYINT) AS TrangThaiKham;
    END CATCH
END;

GO

/* ==================== STO_DM_VietTat_LayDanhSach ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_DM_VietTat_LayDanhSach
(
    @IDCSKCB BIGINT,
    @IDNhanVien BIGINT = NULL,
    @Loai NVARCHAR(50) = N'TRIEU_CHUNG'
)
AS
BEGIN
    SET NOCOUNT ON;
    SET @Loai=ISNULL(NULLIF(LTRIM(RTRIM(@Loai)),N''),N'TRIEU_CHUNG');

    IF @IDNhanVien IS NOT NULL AND @IDNhanVien>0
       AND EXISTS
       (
           SELECT 1 FROM dbo.DM_VietTat
           WHERE IDCSKCB=@IDCSKCB AND IDNhanVien=@IDNhanVien AND Loai=@Loai AND Active=1
       )
    BEGIN
        SELECT ID,IDCSKCB,IDNhanVien,Loai,
               MaVietTat AS ma,CumTuDayDu AS cum_tu,ThuTu AS thu_tu,Active AS active
        FROM dbo.DM_VietTat
        WHERE IDCSKCB=@IDCSKCB AND IDNhanVien=@IDNhanVien AND Loai=@Loai AND Active=1
        ORDER BY ThuTu,ID;
    END
    ELSE
    BEGIN
        SELECT ID,IDCSKCB,IDNhanVien,Loai,
               MaVietTat AS ma,CumTuDayDu AS cum_tu,ThuTu AS thu_tu,Active AS active
        FROM dbo.DM_VietTat
        WHERE IDCSKCB=@IDCSKCB AND IDNhanVien IS NULL AND Loai=@Loai AND Active=1
        ORDER BY ThuTu,ID;
    END;
END;
GO

/* ==================== STO_DM_VietTat_LuuDanhSach ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_DM_VietTat_LuuDanhSach
(
    @IDCSKCB BIGINT,
    @IDNhanVien BIGINT = NULL,
    @Loai NVARCHAR(50) = N'TRIEU_CHUNG',
    @JsonDanhSach NVARCHAR(MAX) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;
        SET @Loai=ISNULL(NULLIF(LTRIM(RTRIM(@Loai)),N''),N'TRIEU_CHUNG');

        IF @IDNhanVien IS NOT NULL AND @IDNhanVien>0
            DELETE dbo.DM_VietTat
            WHERE IDCSKCB=@IDCSKCB AND Loai=@Loai AND IDNhanVien=@IDNhanVien;
        ELSE
            DELETE dbo.DM_VietTat
            WHERE IDCSKCB=@IDCSKCB AND Loai=@Loai AND IDNhanVien IS NULL;

        IF @JsonDanhSach IS NOT NULL AND ISJSON(@JsonDanhSach)=1
        BEGIN
            INSERT dbo.DM_VietTat
                (IDCSKCB,IDNhanVien,Loai,MaVietTat,CumTuDayDu,ThuTu,Active,NgayTao)
            SELECT
                @IDCSKCB,@IDNhanVien,@Loai,
                LTRIM(RTRIM(JSON_VALUE(J.value,'$.ma'))),
                LTRIM(RTRIM(JSON_VALUE(J.value,'$.cum_tu'))),
                ISNULL(TRY_CAST(JSON_VALUE(J.value,'$.thu_tu') AS INT),
                       ROW_NUMBER() OVER(ORDER BY (SELECT NULL))),
                1,SYSDATETIME()
            FROM OPENJSON(@JsonDanhSach) J
            WHERE NULLIF(LTRIM(RTRIM(JSON_VALUE(J.value,'$.ma'))),N'') IS NOT NULL
               OR NULLIF(LTRIM(RTRIM(JSON_VALUE(J.value,'$.cum_tu'))),N'') IS NOT NULL;
        END;

        COMMIT TRANSACTION;
        SELECT 200 AS Status,N'Đã lưu danh sách cụm từ viết tắt thành công.' AS Message;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        SELECT 500 AS Status,ERROR_MESSAGE() AS Message;
    END CATCH;
END;
GO



:r "D:\project\QLPM\Doc\Database\V114\28_thu_ngan.sql"
:r "D:\project\QLPM\Doc\Database\40_ht_config_thu_cong_kham_v99.sql"
:r "D:\project\QLPM\Doc\Database\41_ht_config_thu_tien_chi_dinh_v100.sql"

:r ".\Doc\Database\60_kho_sto_v114.sql"
PRINT N'===== KIEM TRA SAU REBUILD =====';
DECLARE @Required TABLE(Name SYSNAME PRIMARY KEY);
INSERT @Required(Name) VALUES
(N'STO_QL_TiepNhan_DanhSach'),
(N'STO_QL_TiepNhan_Luu'),
(N'STO_QL_TiepNhan_ChuyenKham'),
(N'STO_QL_Kham_DanhSach'),
(N'STO_QL_Kham_ChonBenhNhan'),
(N'STO_QL_Kham_Luu'),
(N'STO_QL_Kham_HoanTat'),
(N'STO_DM_PhacDo_DanhSach'),
(N'STO_DM_PhacDo_ChiTiet'),
(N'STO_DM_PhacDo_Luu'),
(N'STO_DM_PhacDo_Xoa'),
(N'STO_HT_Dang_Nhap_Lay_Tai_Khoan'),
(N'STO_HT_Dang_Nhap_Ghi_Ket_Qua'),
(N'STO_HT_Lay_Quyen_Tai_Khoan'),
(N'STO_HT_Phien_Kiem_Tra'),
(N'STO_HT_Nhan_Vien_Danh_Sach'),
(N'STO_HT_Nhan_Vien_Luu'),
(N'STO_HT_Nhan_Vien_Xoa'),

(N'STO_HT_Tai_Khoan_Danh_Sach'),
(N'STO_HT_Tai_Khoan_Luu'),
(N'STO_HT_Tai_Khoan_Doi_Trang_Thai'),
(N'STO_HT_Tai_Khoan_Reset_Mat_Khau'),
(N'STO_HT_Tai_Khoan_Lay_Theo_ID'),
(N'STO_HT_Tai_Khoan_Xoa'),
(N'STO_HT_Vai_Tro_Danh_Sach'),
(N'STO_HT_Vai_Tro_Luu'),
(N'STO_HT_Vai_Tro_Xoa'),
(N'STO_HT_Quyen_Vai_Tro_Lay'),
(N'STO_HT_Quyen_Vai_Tro_Luu'),
(N'STO_HT_CSKCB_Danh_Sach'),
(N'STO_HT_CSKCB_Luu'),
(N'STO_HT_CSKCB_Xoa'),
(N'STO_HT_Config_DanhSach'),
(N'STO_HT_Config_CapNhatTrangThai'),
(N'STO_QL_Cls_LuuDuongDanKetQua'),
(N'STO_QL_BenhNhan_KiemTraTrung'),
(N'STO_QL_Kham_CapNhatDangKham'),
(N'STO_QL_Kham_HuyDangKham'),
(N'STO_QL_Kham_ChiTietLanKhamCu'),
(N'STO_QL_Kham_LayToaCu'),
(N'STO_QL_Kham_LichSu'),
(N'STO_DM_VietTat_LayDanhSach'),
(N'STO_DM_VietTat_LuuDanhSach'),
(N'STO_QL_ThuNgan_DanhSach'),
(N'STO_QL_ThuNgan_ChiTiet'),
(N'STO_QL_ThuNgan_ThuTien'),
(N'STO_QL_ThuNgan_HuyNhom'),
(N'STO_QL_ThuNgan_HuyThu'),
(N'STO_QL_Kho_DanhSachKho'),
(N'STO_QL_Kho_TonKho_DanhSach'),
(N'STO_QL_Kho_Nhap'),
(N'STO_QL_Kho_Xuat_DanhSach'),
(N'STO_QL_Kho_Xuat_ChiTiet'),
(N'STO_QL_Kho_Xuat_TheoToa'),
(N'STO_QL_Kho_Xuat_Hoan');

DECLARE @Loi NVARCHAR(MAX)=N'';
SELECT @Loi+=N'- Thieu dbo.'+R.Name+CHAR(13)+CHAR(10)
FROM @Required R
WHERE OBJECT_ID(N'dbo.'+R.Name,N'P') IS NULL;

IF @Loi<>N''
BEGIN
    PRINT @Loi;
    IF @@TRANCOUNT>0 ROLLBACK;
    THROW 59002,N'Rebuild STO chua day du.',1;
END;

COMMIT TRANSACTION;

/* Thu ngân v94 có lớp chứng từ riêng; chạy lại script canonical sau bundle legacy
   để phục hồi đầy đủ STO chứng từ và phiên bản STO_QL_ThuNgan_ThuTien mới nhất. */
:r "D:\project\QLPM\Doc\Database\V114\28_thu_ngan.sql"

:r "D:\project\QLPM\Doc\Database\V114\31_thu_ngan_kho_v95.sql"

:r "D:\project\QLPM\Doc\Database\V114\36_thu_cls_dang_kham_v97.sql"
:r "D:\project\QLPM\Doc\Database\V114\38_huy_thu_dao_cap_v98.sql"
:r "D:\project\QLPM\Doc\Database\45_toa_thuoc_quoc_gia_v104.sql"
:r "D:\project\QLPM\Doc\Database\49_lien_thong_toa_thuoc_truc_tiep_v108.sql"
:r "D:\project\QLPM\Doc\Database\50_ky_so_pdf_nghiep_vu_v109.sql"
:r "D:\project\QLPM\Doc\Database\51_ky_so_pdf_toan_bo_v110.sql"
:r "D:\project\QLPM\Doc\Database\52_ky_so_pdf_vi_tri_dong_va_ho_so_da_luu_v111.sql"
:r "D:\project\QLPM\Doc\Database\V114\53_cls_anh_va_in_cap_phat_v112.sql"
:r "D:\project\QLPM\Doc\Database\V114\54_in_pdf_da_ky_va_chan_phieu_cap_huy_v113.sql"
:r "D:\project\QLPM\Doc\Database\55_kho_loc_trang_thai_ton.sql"

:r "D:\project\QLPM\Doc\Database\V114\57_kho_tach_quyen_cap_phat_va_mau_phieu.sql"
:r "D:\project\QLPM\Doc\Database\V114\58_thao_tac_khong_bat_buoc_ly_do.sql"

:r ".\Doc\Database\60_kho_sto_v114.sql"
:r ".\Doc\Database\62_kho_kiem_tra_v114.sql"

SELECT COUNT(*) AS TongSTO
FROM sys.procedures
WHERE schema_id=SCHEMA_ID(N'dbo') AND name LIKE N'STO[_]%';

PRINT N'QLPM MAIN: REBUILD TOAN BO STO HOAN TAT.';
GO
