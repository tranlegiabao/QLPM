:ON ERROR EXIT
USE [QLPM];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.DM_NhaCungCap', N'U') IS NULL
    THROW 58190, N'Thieu DM_NhaCungCap. Chay schema Kho v94 truoc.', 1;
GO

/* Danh muc bao gom ca dong ngung hoat dong de co the sua/kich hoat lai. */
CREATE OR ALTER PROCEDURE dbo.STO_DM_NhaCungCap_QuanLy_DanhSach
    @IDCSKCB BIGINT,
    @TuKhoa NVARCHAR(300)=NULL,
    @TrangThai TINYINT=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @TuKhoa=NULLIF(LTRIM(RTRIM(@TuKhoa)),N'');

    SELECT ID AS id,MaNhaCungCap AS ma,TenNhaCungCap AS ten,
           MaSoThue AS ma_so_thue,DienThoai AS dien_thoai,DiaChi AS dia_chi,
           Active AS active
    FROM dbo.DM_NhaCungCap
    WHERE IDCSKCB=@IDCSKCB
      AND (@TrangThai IS NULL OR Active=@TrangThai)
      AND (@TuKhoa IS NULL
           OR MaNhaCungCap LIKE N'%'+@TuKhoa+N'%'
           OR TenNhaCungCap LIKE N'%'+@TuKhoa+N'%'
           OR MaSoThue LIKE N'%'+@TuKhoa+N'%'
           OR DienThoai LIKE N'%'+@TuKhoa+N'%')
    ORDER BY Active DESC,TenNhaCungCap,ID;
END;
GO

/* Luu theo tenant va khoa tren bo du lieu nha cung cap de tranh tao trung khi goi dong thoi. */
CREATE OR ALTER PROCEDURE dbo.STO_DM_NhaCungCap_Luu
    @IDCSKCB BIGINT,
    @ID BIGINT=0,
    @Ma NVARCHAR(50)=NULL,
    @Ten NVARCHAR(300),
    @MaSoThue NVARCHAR(50)=NULL,
    @DienThoai NVARCHAR(30)=NULL,
    @DiaChi NVARCHAR(500)=NULL,
    @Active BIT=1,
    @CanDeactivate BIT=0
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    SET @Ma=NULLIF(LTRIM(RTRIM(@Ma)),N'');
    SET @Ten=NULLIF(LTRIM(RTRIM(@Ten)),N'');
    SET @MaSoThue=NULLIF(LTRIM(RTRIM(@MaSoThue)),N'');
    SET @DienThoai=NULLIF(LTRIM(RTRIM(@DienThoai)),N'');
    SET @DiaChi=NULLIF(LTRIM(RTRIM(@DiaChi)),N'');

    BEGIN TRY
        IF @ID<0 OR @Ten IS NULL THROW 58191,N'Phai nhap ten nha cung cap.',1;
        IF @DienThoai IS NOT NULL AND (LEN(@DienThoai)>10 OR @DienThoai LIKE N'%[^0-9]%')
            THROW 58192,N'So dien thoai chi duoc toi da 10 chu so.',1;
        IF NOT EXISTS(SELECT 1 FROM dbo.DM_CSKCB WHERE ID=@IDCSKCB)
            THROW 58193,N'Co so kham chua benh khong hop le.',1;

        BEGIN TRANSACTION;
        IF @ID>0 AND NOT EXISTS
            (SELECT 1 FROM dbo.DM_NhaCungCap WITH(UPDLOCK,HOLDLOCK) WHERE IDCSKCB=@IDCSKCB AND ID=@ID)
            THROW 58194,N'Khong tim thay nha cung cap can sua.',1;

        /* Ma tu sinh khi tao moi va khong nhap ma, cho phep nhap ma thu cong. */
        IF @ID=0 AND @Ma IS NULL
            SET @Ma=N'NCC-'+LEFT(REPLACE(CONVERT(NVARCHAR(36),NEWID()),N'-',N''),12);
        IF @ID>0 AND @Ma IS NULL
            SELECT @Ma=MaNhaCungCap FROM dbo.DM_NhaCungCap WHERE IDCSKCB=@IDCSKCB AND ID=@ID;
        IF @ID>0 AND @Active=0 AND @CanDeactivate=0
           AND EXISTS(SELECT 1 FROM dbo.DM_NhaCungCap WHERE IDCSKCB=@IDCSKCB AND ID=@ID AND Active=1)
            THROW 58197,N'Khong co quyen ngung su dung nha cung cap.',1;

        IF EXISTS(SELECT 1 FROM dbo.DM_NhaCungCap WITH(UPDLOCK,HOLDLOCK)
                  WHERE IDCSKCB=@IDCSKCB AND MaNhaCungCap=@Ma AND ID<>@ID)
            THROW 58195,N'Ma nha cung cap da ton tai tai co so.',1;
        IF EXISTS(SELECT 1 FROM dbo.DM_NhaCungCap WITH(UPDLOCK,HOLDLOCK)
                  WHERE IDCSKCB=@IDCSKCB AND TenNhaCungCap=@Ten AND ID<>@ID)
            THROW 58196,N'Ten nha cung cap da ton tai tai co so.',1;

        IF @ID=0
        BEGIN
            INSERT dbo.DM_NhaCungCap(IDCSKCB,MaNhaCungCap,TenNhaCungCap,MaSoThue,DienThoai,DiaChi,Active)
            VALUES(@IDCSKCB,@Ma,@Ten,@MaSoThue,@DienThoai,@DiaChi,@Active);
            SET @ID=SCOPE_IDENTITY();
        END
        ELSE
            UPDATE dbo.DM_NhaCungCap
            SET MaNhaCungCap=@Ma,TenNhaCungCap=@Ten,MaSoThue=@MaSoThue,
                DienThoai=@DienThoai,DiaChi=@DiaChi,Active=@Active
            WHERE IDCSKCB=@IDCSKCB AND ID=@ID;

        COMMIT;
        SELECT 200 AS Status,N'Da luu nha cung cap.' AS Message,@ID AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SELECT CASE WHEN ERROR_NUMBER()=58194 THEN 404 ELSE 400 END AS Status,
               ERROR_MESSAGE() AS Message;
    END CATCH;
END;
GO

/* Chi ngung su dung, khong xoa ban ghi/FK phieu nhap trong qua khu. */
CREATE OR ALTER PROCEDURE dbo.STO_DM_NhaCungCap_Xoa
    @IDCSKCB BIGINT,
    @ID BIGINT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    UPDATE dbo.DM_NhaCungCap SET Active=0
    WHERE IDCSKCB=@IDCSKCB AND ID=@ID;
    IF @@ROWCOUNT=0
        SELECT 404 AS Status,N'Khong tim thay nha cung cap.' AS Message;
    ELSE
        SELECT 200 AS Status,N'Da ngung su dung nha cung cap.' AS Message,@ID AS ID;
END;
GO

/* Endpoint them-nhanh da go; STO cu khong duoc goi lai. */
DROP PROCEDURE IF EXISTS dbo.STO_DM_NhaCungCap_ThemNhanh;
GO
PRINT N'47_danh_muc_nha_cung_cap_v106.sql: OK';
GO
