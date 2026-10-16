USE [QLPM];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.HT_Config',N'U') IS NULL
    THROW 59100,N'Thiếu bảng HT_Config v99. Hãy chạy updater đầy đủ từ 00_CapNhat_TatCa.sql.',1;
GO

/* Seed idempotent theo CSKCB; không ghi đè trạng thái quản trị đã chọn. */
INSERT dbo.HT_Config(IDCSKCB,MaChucNang,HieuLuc,Nhom,GhiChu)
SELECT C.ID,
       N'THUTIENCHIDINHTRUOC',
       1,
       N'3. Tài chính',
       N'Bắt buộc thanh toán chỉ định CLS trước khi nhập kết quả.'
FROM dbo.DM_CSKCB C
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.HT_Config H
    WHERE H.IDCSKCB=C.ID
      AND H.MaChucNang=N'THUTIENCHIDINHTRUOC'
);
GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_Cls_LuuDuongDanKetQua
    @IDCSKCB BIGINT,
    @IDChiDinhCT BIGINT,
    @DuongDanKetQua NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @DuongDanKetQua=NULLIF(LTRIM(RTRIM(@DuongDanKetQua)),N'');
    IF @IDCSKCB<=0 OR @IDChiDinhCT<=0 OR @DuongDanKetQua IS NULL
    BEGIN
        SELECT 400 AS Status,N'Dữ liệu file kết quả CLS không hợp lệ.' AS Message,
               CAST(NULL AS NVARCHAR(1000)) AS DuongDanKetQuaCu;
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @IDVaoVien BIGINT,@ThanhTien DECIMAL(18,2),@DuongDanKetQuaCu NVARCHAR(1000);
        SELECT @IDVaoVien=C.IDVaoVien,@ThanhTien=C.ThanhTien,@DuongDanKetQuaCu=C.DuongDanKetQua
        FROM dbo.QL_ChiDinh_CT C WITH(UPDLOCK,HOLDLOCK)
        WHERE C.IDCSKCB=@IDCSKCB AND C.ID=@IDChiDinhCT AND C.Active=1;

        IF @IDVaoVien IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT 404 AS Status,N'Không tìm thấy chỉ định CLS hợp lệ.' AS Message,
                   CAST(NULL AS NVARCHAR(1000)) AS DuongDanKetQuaCu;
            RETURN;
        END;

        /* Quy tắc chung: không sửa dữ liệu CLS sau khi lượt khám đã hoàn tất. */
        IF EXISTS (
            SELECT 1
            FROM dbo.QL_VaoVien V
            WHERE V.IDCSKCB=@IDCSKCB AND V.ID=@IDVaoVien AND V.TrangThaiKham=2
        )
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT 409 AS Status,N'Lượt khám đã hoàn tất; không thể thay đổi file kết quả CLS.' AS Message,
                   @DuongDanKetQuaCu AS DuongDanKetQuaCu;
            RETURN;
        END;

        IF ISNULL
           (
               (SELECT TOP(1) HieuLuc
                FROM dbo.HT_Config
                WHERE IDCSKCB=@IDCSKCB
                  AND MaChucNang=N'THUTIENCHIDINHTRUOC'),
               1
           )=1
           AND
           (
               EXISTS
               (
                   SELECT 1
                   FROM dbo.QL_ThuTien_CT T WITH(UPDLOCK,HOLDLOCK)
                   WHERE T.IDCSKCB=@IDCSKCB
                     AND T.IDChiDinhCT=@IDChiDinhCT
                     AND ISNULL(T.DaThu,0)=0
                     AND ROUND(ISNULL(T.ThucThu,T.ThanhTien),0)>0
               )
               OR
               (
                   ROUND(ISNULL(@ThanhTien,0),0)>0
                   AND NOT EXISTS
                   (
                       SELECT 1
                       FROM dbo.QL_ThuTien_CT T WITH(UPDLOCK,HOLDLOCK)
                       WHERE T.IDCSKCB=@IDCSKCB
                         AND T.IDChiDinhCT=@IDChiDinhCT
                   )
               )
           )
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT 409 AS Status,N'Chỉ định CLS chưa thanh toán. Thu tiền chỉ định trước khi nhập kết quả.' AS Message,
                   @DuongDanKetQuaCu AS DuongDanKetQuaCu;
            RETURN;
        END;

        UPDATE dbo.QL_ChiDinh_CT
        SET DuongDanKetQua=@DuongDanKetQua
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDChiDinhCT AND Active=1;

        COMMIT TRANSACTION;
        SELECT 200 AS Status,N'Đã lưu file kết quả CLS.' AS Message,
               @DuongDanKetQuaCu AS DuongDanKetQuaCu;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        SELECT 500 AS Status,N'Không thể lưu file kết quả CLS.' AS Message,
               CAST(NULL AS NVARCHAR(1000)) AS DuongDanKetQuaCu;
    END CATCH;
END;
GO

PRINT N'41_ht_config_thu_tien_chi_dinh_v100.sql: OK';
GO
