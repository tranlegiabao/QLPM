/*
16_common_cskcb_admin.sql

Quan ly DM_CSKCB cho quan tri he thong.
- Nut Xoa la hard-delete: xoa toan bo du lieu tenant trong DB theo IDCSKCB.
- File/cache tenant duoc controller don sau khi DB commit.
*/
USE [QLPM];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

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

PRINT N'16_common_cskcb_admin.sql: OK';
GO
