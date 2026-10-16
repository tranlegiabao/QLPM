/* Danh mục mã giảm giá QLPM - tương ứng DaoTaoHIS.dbo.DM_MaGiamGia.
   Mỗi CSKCB có danh mục riêng; tỷ lệ DECIMAL giữ 5,5%. SQL Server 2017. */
USE [QLPM];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO
/* Tenant-owned discount catalog. Legacy shared rows are copied to each
   existing CSKCB on first upgrade, without discarding any configured codes. */
IF OBJECT_ID(N'dbo.DM_MaGiamGia',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DM_MaGiamGia
    (
        ID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DM_MaGiamGia PRIMARY KEY,
        IDCSKCB BIGINT NOT NULL,
        MaGiamGia NVARCHAR(30) NOT NULL,
        TenGiamGia NVARCHAR(150) NOT NULL,
        TiLe DECIMAL(6,2) NOT NULL,
        Active BIT NOT NULL CONSTRAINT DF_DM_MaGiamGia_Active DEFAULT(1),
        CONSTRAINT FK_DM_MaGiamGia_CSKCB FOREIGN KEY(IDCSKCB) REFERENCES dbo.DM_CSKCB(ID),
        CONSTRAINT UQ_DM_MaGiamGia_CSKCB_Ma UNIQUE(IDCSKCB,MaGiamGia),
        CONSTRAINT CK_DM_MaGiamGia_TiLe CHECK(TiLe>=0 AND TiLe<=100)
    );
END;
GO

IF COL_LENGTH(N'dbo.DM_MaGiamGia',N'IDCSKCB') IS NULL
BEGIN
    ALTER TABLE dbo.DM_MaGiamGia ADD IDCSKCB BIGINT NULL;
END;
GO

/* Upgrade global codes -> tenant-specific codes exactly once. */
IF EXISTS(SELECT 1 FROM dbo.DM_MaGiamGia WHERE IDCSKCB IS NULL)
BEGIN
    DECLARE @DefaultCSKCB BIGINT=(SELECT MIN(ID) FROM dbo.DM_CSKCB);
    IF @DefaultCSKCB IS NULL
        THROW 59120,N'Không có CSKCB để chuyển danh mục mã giảm giá.',1;

    IF EXISTS(SELECT 1 FROM sys.key_constraints
              WHERE parent_object_id=OBJECT_ID(N'dbo.DM_MaGiamGia')
                AND name=N'UQ_DM_MaGiamGia_MaGiamGia')
        ALTER TABLE dbo.DM_MaGiamGia DROP CONSTRAINT UQ_DM_MaGiamGia_MaGiamGia;

    /* Global rows become the default tenant's data; clone to other tenants. */
    INSERT dbo.DM_MaGiamGia(IDCSKCB,MaGiamGia,TenGiamGia,TiLe,Active)
    SELECT C.ID, D.MaGiamGia, D.TenGiamGia, D.TiLe, D.Active
    FROM dbo.DM_MaGiamGia D
    CROSS JOIN dbo.DM_CSKCB C
    WHERE D.IDCSKCB IS NULL AND C.ID<>@DefaultCSKCB
      AND NOT EXISTS(
        SELECT 1 FROM dbo.DM_MaGiamGia E
        WHERE E.IDCSKCB=C.ID AND E.MaGiamGia=D.MaGiamGia);

    UPDATE dbo.DM_MaGiamGia SET IDCSKCB=@DefaultCSKCB WHERE IDCSKCB IS NULL;
END;
GO

/* Empty legacy catalog may still have the old global unique constraint. */
IF EXISTS(SELECT 1 FROM sys.key_constraints
          WHERE parent_object_id=OBJECT_ID(N'dbo.DM_MaGiamGia')
            AND name=N'UQ_DM_MaGiamGia_MaGiamGia')
    ALTER TABLE dbo.DM_MaGiamGia DROP CONSTRAINT UQ_DM_MaGiamGia_MaGiamGia;
GO

IF EXISTS(SELECT 1 FROM sys.columns
          WHERE object_id=OBJECT_ID(N'dbo.DM_MaGiamGia')
            AND name=N'IDCSKCB' AND is_nullable=1)
    ALTER TABLE dbo.DM_MaGiamGia ALTER COLUMN IDCSKCB BIGINT NOT NULL;
GO

IF NOT EXISTS(SELECT 1 FROM sys.key_constraints
              WHERE parent_object_id=OBJECT_ID(N'dbo.DM_MaGiamGia')
                AND name=N'UQ_DM_MaGiamGia_CSKCB_Ma')
    ALTER TABLE dbo.DM_MaGiamGia
    ADD CONSTRAINT UQ_DM_MaGiamGia_CSKCB_Ma UNIQUE(IDCSKCB,MaGiamGia);
GO

IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys
              WHERE parent_object_id=OBJECT_ID(N'dbo.DM_MaGiamGia')
                AND name=N'FK_DM_MaGiamGia_CSKCB')
    ALTER TABLE dbo.DM_MaGiamGia
    ADD CONSTRAINT FK_DM_MaGiamGia_CSKCB FOREIGN KEY(IDCSKCB) REFERENCES dbo.DM_CSKCB(ID);
GO

/* Dọn phần thử nghiệm CLS nhiều-file v101 nếu từng triển khai.
   Không xóa bất kỳ tệp đính kèm thực tế nào và không mất dữ liệu. */
DROP PROCEDURE IF EXISTS dbo.STO_QL_Cls_FileKetQua_DanhSach;
DROP PROCEDURE IF EXISTS dbo.STO_QL_Cls_FileKetQua_Lay;
DROP PROCEDURE IF EXISTS dbo.STO_QL_Cls_FileKetQua_Them;
DROP PROCEDURE IF EXISTS dbo.STO_QL_Cls_FileKetQua_Xoa;
GO
IF OBJECT_ID(N'dbo.QL_ChiDinh_FileKetQua',N'U') IS NOT NULL
BEGIN
    EXEC sys.sp_executesql N'
        IF NOT EXISTS(SELECT 1 FROM dbo.QL_ChiDinh_FileKetQua)
        BEGIN
            DROP TABLE dbo.QL_ChiDinh_FileKetQua;
            PRINT N''Đã dọn bảng CLS nhiều-file rỗng.'';
        END
        ELSE
            PRINT N''CẢNH BÁO: Bảng CLS nhiều-file còn dữ liệu; giữ nguyên để đối chiếu, không xóa tự động.'';
    ';
END;
GO

/* Default HIS codes are independently seeded for every CSKCB. */
INSERT dbo.DM_MaGiamGia(IDCSKCB,MaGiamGia,TenGiamGia,TiLe,Active)
SELECT C.ID,S.Ma,S.Ten,S.TiLe,1
FROM dbo.DM_CSKCB C
CROSS JOIN (VALUES
    (N'20',N'Giảm 20',CAST(20.00 AS DECIMAL(6,2))),
    (N'30',N'Giảm 30',CAST(30.00 AS DECIMAL(6,2))),
    (N'5.5',N'5.5',CAST(5.50 AS DECIMAL(6,2))),
    (N'10',N'Giảm 10',CAST(10.00 AS DECIMAL(6,2))),
    (N'100',N'Giảm 100',CAST(100.00 AS DECIMAL(6,2)))
) S(Ma,Ten,TiLe)
WHERE NOT EXISTS(SELECT 1 FROM dbo.DM_MaGiamGia D
                 WHERE D.IDCSKCB=C.ID AND D.MaGiamGia=S.Ma);
GO

/* Existing JSON caches must be regenerated once to include this catalog. */
IF NOT EXISTS(SELECT 1 FROM sys.triggers
              WHERE name=N'TR_DM_MaGiamGia_JSON_VERSION'
                AND parent_id=OBJECT_ID(N'dbo.DM_MaGiamGia'))
BEGIN
    UPDATE V SET VersionNo=VersionNo+1,
        TrangThai=N'CHO_DONG_BO',LastChangedAt=SYSDATETIME(),
        LastError=NULL,UpdatedAt=SYSDATETIME()
    FROM dbo.HT_JSON_CSKCB V;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_DM_MaGiamGia_JSON_VERSION
ON dbo.DM_MaGiamGia
AFTER INSERT,UPDATE,DELETE
AS
BEGIN
    SET NOCOUNT ON;
    ;WITH Changed AS
    (
        SELECT IDCSKCB FROM inserted
        UNION
        SELECT IDCSKCB FROM deleted
    )
    UPDATE V SET VersionNo=V.VersionNo+1,TrangThai=N'CHO_DONG_BO',
        LastChangedAt=SYSDATETIME(),LastError=NULL,UpdatedAt=SYSDATETIME()
    FROM dbo.HT_JSON_CSKCB V
    INNER JOIN Changed C ON C.IDCSKCB=V.IDCSKCB;
END;
GO

/* New CSKCB gets an independent copy of HIS defaults automatically. */
CREATE OR ALTER TRIGGER dbo.TR_DM_CSKCB_MaGiamGia_Default
ON dbo.DM_CSKCB
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT dbo.DM_MaGiamGia(IDCSKCB,MaGiamGia,TenGiamGia,TiLe,Active)
    SELECT I.ID,S.Ma,S.Ten,S.TiLe,1
    FROM inserted I
    CROSS JOIN (VALUES
        (N'20',N'Giảm 20',CAST(20.00 AS DECIMAL(6,2))),
        (N'30',N'Giảm 30',CAST(30.00 AS DECIMAL(6,2))),
        (N'5.5',N'5.5',CAST(5.50 AS DECIMAL(6,2))),
        (N'10',N'Giảm 10',CAST(10.00 AS DECIMAL(6,2))),
        (N'100',N'Giảm 100',CAST(100.00 AS DECIMAL(6,2)))
    ) S(Ma,Ten,TiLe)
    WHERE NOT EXISTS(SELECT 1 FROM dbo.DM_MaGiamGia D
                     WHERE D.IDCSKCB=I.ID AND D.MaGiamGia=S.Ma);
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_ThuNgan_MaGiamGia_DanhSach
    @IDCSKCB BIGINT,
    @ChiHoatDong BIT=1
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ID,MaGiamGia,TenGiamGia,TiLe,Active
    FROM dbo.DM_MaGiamGia
    WHERE IDCSKCB=@IDCSKCB AND (@ChiHoatDong=0 OR Active=1)
    ORDER BY TiLe,MaGiamGia,ID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_ThuNgan_MaGiamGia_Luu
    @IDCSKCB BIGINT,
    @ID BIGINT=0,
    @MaGiamGia NVARCHAR(30),
    @TenGiamGia NVARCHAR(150),
    @TiLe DECIMAL(6,2),
    @Active BIT=1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @MaGiamGia=NULLIF(LTRIM(RTRIM(@MaGiamGia)),N'');
    SET @TenGiamGia=NULLIF(LTRIM(RTRIM(@TenGiamGia)),N'');

    IF @IDCSKCB<=0 OR NOT EXISTS(SELECT 1 FROM dbo.DM_CSKCB WHERE ID=@IDCSKCB)
        OR @MaGiamGia IS NULL OR @TenGiamGia IS NULL OR @TiLe IS NULL
        OR @TiLe<0 OR @TiLe>100 OR @ID<0
    BEGIN
        SELECT 400 AS Status,N'Mã, tên, CSKCB và tỉ lệ giảm giá phải hợp lệ.' AS Message;
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        IF EXISTS(SELECT 1 FROM dbo.DM_MaGiamGia WITH(UPDLOCK,HOLDLOCK)
                  WHERE IDCSKCB=@IDCSKCB AND MaGiamGia=@MaGiamGia AND ID<>@ID)
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT 409 AS Status,N'Mã giảm giá đã tồn tại trong CSKCB.' AS Message;
            RETURN;
        END;
        IF @ID=0
        BEGIN
            INSERT dbo.DM_MaGiamGia(IDCSKCB,MaGiamGia,TenGiamGia,TiLe,Active)
            VALUES(@IDCSKCB,@MaGiamGia,@TenGiamGia,@TiLe,@Active);
            SET @ID=SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE dbo.DM_MaGiamGia
            SET MaGiamGia=@MaGiamGia,TenGiamGia=@TenGiamGia,TiLe=@TiLe,Active=@Active
            WHERE ID=@ID AND IDCSKCB=@IDCSKCB;
            IF @@ROWCOUNT=0
            BEGIN
                ROLLBACK TRANSACTION;
                SELECT 404 AS Status,N'Không tìm thấy mã giảm giá của CSKCB.' AS Message;
                RETURN;
            END;
        END;
        COMMIT TRANSACTION;
        SELECT 200 AS Status,N'Đã lưu mã giảm giá.' AS Message,@ID AS ID;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        SELECT 500 AS Status,N'Không thể lưu mã giảm giá.' AS Message;
    END CATCH;
END;
GO

PRINT N'42_dm_ma_giam_gia.sql: OK';
GO
