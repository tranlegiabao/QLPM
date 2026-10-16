/*
23_common_viet_tat.sql
Bảng danh mục cụm từ viết tắt cho triệu chứng / ghi chú khám bệnh
*/
USE [QLPM];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.DM_VietTat', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DM_VietTat
    (
        ID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DM_VietTat PRIMARY KEY,
        IDCSKCB BIGINT NOT NULL,
        IDNhanVien BIGINT NULL,
        Loai NVARCHAR(50) NOT NULL CONSTRAINT DF_DM_VietTat_Loai DEFAULT(N'TRIEU_CHUNG'),
        MaVietTat NVARCHAR(100) NOT NULL,
        CumTuDayDu NVARCHAR(MAX) NOT NULL,
        ThuTu INT NOT NULL CONSTRAINT DF_DM_VietTat_ThuTu DEFAULT(0),
        Active BIT NOT NULL CONSTRAINT DF_DM_VietTat_Active DEFAULT(1),
        NgayTao DATETIME2 NOT NULL CONSTRAINT DF_DM_VietTat_NgayTao DEFAULT(SYSDATETIME()),
        NgayCapNhat DATETIME2 NULL,
        CONSTRAINT FK_DM_VietTat_CSKCB FOREIGN KEY (IDCSKCB) REFERENCES dbo.DM_CSKCB(ID),
        CONSTRAINT FK_DM_VietTat_NhanVien FOREIGN KEY (IDNhanVien) REFERENCES dbo.DM_NhanVien(ID)
    );

    CREATE NONCLUSTERED INDEX IX_DM_VietTat_CSKCB_Loai 
        ON dbo.DM_VietTat(IDCSKCB, Loai, Active)
        INCLUDE (IDNhanVien, MaVietTat, ThuTu);
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_DM_VietTat_LayDanhSach
(
    @IDCSKCB BIGINT,
    @IDNhanVien BIGINT = NULL,
    @Loai NVARCHAR(50) = N'TRIEU_CHUNG'
)
AS
BEGIN
    SET NOCOUNT ON;
    SET @Loai = ISNULL(NULLIF(LTRIM(RTRIM(@Loai)), N''), N'TRIEU_CHUNG');

    IF @IDNhanVien IS NOT NULL AND @IDNhanVien > 0 AND EXISTS (
        SELECT 1 FROM dbo.DM_VietTat WHERE IDCSKCB = @IDCSKCB AND IDNhanVien = @IDNhanVien AND Loai = @Loai AND Active = 1
    )
    BEGIN
        SELECT 
            ID, IDCSKCB, IDNhanVien, Loai,
            MaVietTat AS ma, CumTuDayDu AS cum_tu, ThuTu AS thu_tu, Active AS active
        FROM dbo.DM_VietTat
        WHERE IDCSKCB = @IDCSKCB AND IDNhanVien = @IDNhanVien AND Loai = @Loai AND Active = 1
        ORDER BY ThuTu ASC, ID ASC;
    END
    ELSE
    BEGIN
        SELECT 
            ID, IDCSKCB, IDNhanVien, Loai,
            MaVietTat AS ma, CumTuDayDu AS cum_tu, ThuTu AS thu_tu, Active AS active
        FROM dbo.DM_VietTat
        WHERE IDCSKCB = @IDCSKCB AND IDNhanVien IS NULL AND Loai = @Loai AND Active = 1
        ORDER BY ThuTu ASC, ID ASC;
    END
END;
GO

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

        SET @Loai = ISNULL(NULLIF(LTRIM(RTRIM(@Loai)), N''), N'TRIEU_CHUNG');

        IF @IDNhanVien IS NOT NULL AND @IDNhanVien > 0
        BEGIN
            DELETE FROM dbo.DM_VietTat
            WHERE IDCSKCB = @IDCSKCB
              AND Loai = @Loai
              AND IDNhanVien = @IDNhanVien;
        END
        ELSE
        BEGIN
            DELETE FROM dbo.DM_VietTat
            WHERE IDCSKCB = @IDCSKCB
              AND Loai = @Loai
              AND IDNhanVien IS NULL;
        END

        IF @JsonDanhSach IS NOT NULL AND ISJSON(@JsonDanhSach) = 1
        BEGIN
            INSERT INTO dbo.DM_VietTat (IDCSKCB, IDNhanVien, Loai, MaVietTat, CumTuDayDu, ThuTu, Active, NgayTao)
            SELECT
                @IDCSKCB,
                @IDNhanVien,
                @Loai,
                LTRIM(RTRIM(JSON_VALUE(j.value, '$.ma'))),
                LTRIM(RTRIM(JSON_VALUE(j.value, '$.cum_tu'))),
                ISNULL(TRY_CAST(JSON_VALUE(j.value, '$.thu_tu') AS INT), ROW_NUMBER() OVER (ORDER BY (SELECT NULL))),
                1,
                SYSDATETIME()
            FROM OPENJSON(@JsonDanhSach) j
            WHERE NULLIF(LTRIM(RTRIM(JSON_VALUE(j.value, '$.ma'))), N'') IS NOT NULL
               OR NULLIF(LTRIM(RTRIM(JSON_VALUE(j.value, '$.cum_tu'))), N'') IS NOT NULL;
        END

        COMMIT TRANSACTION;

        SELECT 200 AS Status, N'Đã lưu danh sách cụm từ viết tắt thành công.' AS Message;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT 500 AS Status, ERROR_MESSAGE() AS Message;
    END CATCH
END;
GO
