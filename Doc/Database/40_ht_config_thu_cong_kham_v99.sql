USE [QLPM];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.HT_Config',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.HT_Config
    (
        ID BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_HT_Config PRIMARY KEY,
        IDCSKCB BIGINT NOT NULL,
        MaChucNang NVARCHAR(100) NOT NULL,
        HieuLuc BIT NOT NULL
            CONSTRAINT DF_HT_Config_HieuLuc DEFAULT(1),
        Nhom NVARCHAR(100) NULL,
        GhiChu NVARCHAR(500) NULL,
        CONSTRAINT UQ_HT_Config_IDCSKCB_MaChucNang UNIQUE(IDCSKCB,MaChucNang)
    );
END;
GO

/* Tach batch de SQL Server nhan cot moi truoc khi compile phan chuyen du lieu. */
IF COL_LENGTH(N'dbo.HT_Config',N'IDCSKCB') IS NULL
    ALTER TABLE dbo.HT_Config ADD IDCSKCB BIGINT NULL;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS(SELECT 1 FROM dbo.DM_CSKCB)
        THROW 59099,N'Không thể chuyển HT_Config theo cơ sở vì DM_CSKCB chưa có dữ liệu.',1;

    /* v99 global da tung duoc trien khai: giu nguyen trang thai da chon
       va nhan sang tung CSKCB truoc khi doi contract thanh tenant-scoped. */
    IF EXISTS
    (
        SELECT 1
        FROM sys.key_constraints
        WHERE parent_object_id=OBJECT_ID(N'dbo.HT_Config')
          AND name=N'UQ_HT_Config_MaChucNang'
          AND type=N'UQ'
    )
        ALTER TABLE dbo.HT_Config DROP CONSTRAINT UQ_HT_Config_MaChucNang;

    INSERT dbo.HT_Config(IDCSKCB,MaChucNang,HieuLuc,Nhom,GhiChu)
    SELECT C.ID,H.MaChucNang,H.HieuLuc,H.Nhom,H.GhiChu
    FROM dbo.HT_Config H
    CROSS JOIN dbo.DM_CSKCB C
    WHERE H.IDCSKCB IS NULL
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.HT_Config X
          WHERE X.IDCSKCB=C.ID
            AND X.MaChucNang=H.MaChucNang
      );

    DELETE dbo.HT_Config WHERE IDCSKCB IS NULL;

    IF EXISTS
    (
        SELECT 1
        FROM sys.columns
        WHERE object_id=OBJECT_ID(N'dbo.HT_Config')
          AND name=N'IDCSKCB'
          AND is_nullable=1
    )
        ALTER TABLE dbo.HT_Config ALTER COLUMN IDCSKCB BIGINT NOT NULL;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.key_constraints
        WHERE parent_object_id=OBJECT_ID(N'dbo.HT_Config')
          AND name=N'UQ_HT_Config_IDCSKCB_MaChucNang'
          AND type=N'UQ'
    )
        ALTER TABLE dbo.HT_Config
            ADD CONSTRAINT UQ_HT_Config_IDCSKCB_MaChucNang
            UNIQUE(IDCSKCB,MaChucNang);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

INSERT dbo.HT_Config(IDCSKCB,MaChucNang,HieuLuc,Nhom,GhiChu)
SELECT C.ID,
        N'THUCONGKHAMDVTRUOC',
        1,
        N'3. Tài chính',
        N'Bắt buộc thanh toán công khám trước khi bắt đầu khám.'
FROM dbo.DM_CSKCB C
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.HT_Config H
    WHERE H.IDCSKCB=C.ID
      AND H.MaChucNang=N'THUCONGKHAMDVTRUOC'
);
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_Config_DanhSach
    @IDCSKCB BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ID,MaChucNang,HieuLuc,Nhom,GhiChu
    FROM dbo.HT_Config
    WHERE IDCSKCB=@IDCSKCB
    ORDER BY ISNULL(Nhom,N''),MaChucNang;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_Config_CapNhatTrangThai
    @IDCSKCB BIGINT,
    @MaChucNang NVARCHAR(100),
    @HieuLuc BIT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @MaChucNang=UPPER(NULLIF(LTRIM(RTRIM(@MaChucNang)),N''));
    IF @IDCSKCB<=0 OR @MaChucNang IS NULL
    BEGIN
        SELECT 400 AS Status,N'Mã cấu hình không hợp lệ.' AS Message;
        RETURN;
    END;

    IF NOT EXISTS(SELECT 1 FROM dbo.DM_CSKCB WHERE ID=@IDCSKCB)
    BEGIN
        SELECT 404 AS Status,N'Không tìm thấy cơ sở KCB.' AS Message;
        RETURN;
    END;

    UPDATE dbo.HT_Config WITH(UPDLOCK,ROWLOCK)
    SET HieuLuc=@HieuLuc
    WHERE IDCSKCB=@IDCSKCB
      AND MaChucNang=@MaChucNang;

    IF @@ROWCOUNT=0
    BEGIN
        SELECT 404 AS Status,N'Không tìm thấy cấu hình.' AS Message;
        RETURN;
    END;

    SELECT 200 AS Status,N'Đã cập nhật cấu hình.' AS Message,
           IDCSKCB,MaChucNang,HieuLuc
    FROM dbo.HT_Config
    WHERE IDCSKCB=@IDCSKCB
      AND MaChucNang=@MaChucNang;
END;
GO

PRINT N'40_ht_config_thu_cong_kham_v99.sql: OK';
GO
