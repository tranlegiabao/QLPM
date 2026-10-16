/*
99_TEST_seed_ton_kho_1000.sql

CHỈ DÙNG CHO DB TEST/DEV.

Mục tiêu:
- Mỗi thuốc Active của mỗi CSKCB có đúng 1.000 đơn vị TỒN VẬT LÝ
  trong kho mặc định KHO_THUOC sau khi chạy script.
- Dữ liệu được chia đều theo 5 trạng thái để test UI tồn kho:
  1. KHẢ DỤNG BÌNH THƯỜNG      : HSD > 30 ngày
  2. SẮP HẾT HẠN              : HSD <= 30 ngày
  3. HẾT HẠN                  : HSD < hôm nay
  4. INACTIVE                 : lô Active = 0
  5. KHÔNG HSD                : HanDung = NULL

LƯU Ý:
- Script này RESET SoLuongTon của toàn bộ lô hiện có trong KHO_THUOC về 0
  để bảo đảm mỗi thuốc hiển thị TonVatLy = 1000.
- Không đưa file này vào 00_CapNhat_TatCa.sql.
- Trạng thái CẤP PHÁT 0/1/2 (chưa cấp / cấp một phần / đã cấp) phụ thuộc
  toa + thu tiền + phiếu xuất, không phải trạng thái của tồn kho và không
  được giả lập trong script này.
*/

IF DB_NAME()<>N'QLPM'
    THROW 59000,N'Script test tồn kho chỉ được chạy trên database QLPM.',1;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.DM_Kho',N'U') IS NULL
   OR OBJECT_ID(N'dbo.QL_Kho_LoThuoc',N'U') IS NULL
   OR OBJECT_ID(N'dbo.DM_Thuoc',N'U') IS NULL
    THROW 59000,N'Chưa có schema kho. Chạy 29_kho_nghiep_vu.sql trước.',1;
GO

BEGIN TRY
    BEGIN TRAN;

    /* Bảo đảm mỗi CSKCB active có kho thuốc mặc định. */
    INSERT dbo.DM_Kho(IDCSKCB,MaKho,TenKho,Active)
    SELECT C.ID,N'KHO_THUOC',N'Kho thuốc',1
    FROM dbo.DM_CSKCB C
    WHERE C.Active=1
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.DM_Kho K
          WHERE K.IDCSKCB=C.ID
            AND K.MaKho=N'KHO_THUOC'
      );

    /* Bảo đảm quy đổi DVT cơ sở cho thuốc có IDDonViTinh. */
    INSERT dbo.DM_Thuoc_DonViQuyDoi
        (IDCSKCB,IDThuoc,IDDonViTinh,HeSoQuyDoi,LaDonViCoSo,Active)
    SELECT T.IDCSKCB,T.ID,T.IDDonViTinh,1,1,1
    FROM dbo.DM_Thuoc T
    WHERE T.Active=1
      AND T.IDDonViTinh IS NOT NULL
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.DM_Thuoc_DonViQuyDoi Q
          WHERE Q.IDCSKCB=T.IDCSKCB
            AND Q.IDThuoc=T.ID
            AND Q.IDDonViTinh=T.IDDonViTinh
      );

    /* TEST ONLY: reset tồn hiện tại để tổng vật lý sau seed đúng 1.000. */
    UPDATE L
    SET L.SoLuongTon=0
    FROM dbo.QL_Kho_LoThuoc L
    INNER JOIN dbo.DM_Kho K
      ON K.IDCSKCB=L.IDCSKCB
     AND K.ID=L.IDKho
    WHERE K.MaKho=N'KHO_THUOC';

    IF OBJECT_ID('tempdb..#SeedThuoc') IS NOT NULL DROP TABLE #SeedThuoc;

    ;WITH S AS
    (
        SELECT
            K.IDCSKCB,
            K.ID AS IDKho,
            T.ID AS IDThuoc,
            ROW_NUMBER() OVER(PARTITION BY K.IDCSKCB ORDER BY T.ID) AS RN,
            CASE
                WHEN ISNULL(T.GiaBan,0)>0 THEN CAST(ROUND(T.GiaBan*0.70,4) AS DECIMAL(18,4))
                ELSE CAST(1000 AS DECIMAL(18,4))
            END AS GiaNhap
        FROM dbo.DM_Kho K
        INNER JOIN dbo.DM_Thuoc T
          ON T.IDCSKCB=K.IDCSKCB
         AND T.Active=1
        WHERE K.Active=1
          AND K.MaKho=N'KHO_THUOC'
    )
    SELECT
        IDCSKCB,
        IDKho,
        IDThuoc,
        RN,
        CAST((RN-1)%5 AS INT) AS NhomTrangThai,
        GiaNhap
    INTO #SeedThuoc
    FROM S;

    /* Mỗi thuốc 1 lô test 1.000 đơn vị.
       Dùng SoLo có timestamp để không đụng FK/lịch sử của lần seed trước. */
    DECLARE @Batch NVARCHAR(20)=
        REPLACE(REPLACE(REPLACE(CONVERT(NVARCHAR(19),SYSDATETIME(),120),N'-',N''),N':',N''),N' ',N'');

    INSERT dbo.QL_Kho_LoThuoc
        (IDCSKCB,IDKho,IDThuoc,SoLo,HanDung,GiaNhap,SoLuongNhap,SoLuongTon,NgayNhap,Active)
    SELECT
        S.IDCSKCB,
        S.IDKho,
        S.IDThuoc,
        N'TEST1000-' + CONVERT(NVARCHAR(20),S.IDThuoc) + N'-' + @Batch,
        CASE S.NhomTrangThai
            WHEN 0 THEN DATEADD(DAY,365,CONVERT(DATE,SYSDATETIME()))  -- bình thường
            WHEN 1 THEN DATEADD(DAY,15,CONVERT(DATE,SYSDATETIME()))   -- sắp hết hạn
            WHEN 2 THEN DATEADD(DAY,-15,CONVERT(DATE,SYSDATETIME()))  -- hết hạn
            WHEN 3 THEN DATEADD(DAY,365,CONVERT(DATE,SYSDATETIME()))  -- inactive
            WHEN 4 THEN NULL                                          -- không HSD
        END,
        S.GiaNhap,
        1000,
        1000,
        SYSDATETIME(),
        CASE WHEN S.NhomTrangThai=3 THEN 0 ELSE 1 END
    FROM #SeedThuoc S;

    COMMIT;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK;
    THROW;
END CATCH;
GO

/* Kiểm tra tổng tồn và trạng thái sau seed. */
;WITH X AS
(
    SELECT
        T.IDCSKCB,
        T.ID AS IDThuoc,
        T.MaThuoc,
        T.TenThuoc,
        SUM(ISNULL(L.SoLuongTon,0)) AS TonVatLy,
        SUM
        (
            CASE
                WHEN L.SoLuongTon>0
                 AND (L.Active=0 OR L.HanDung<CONVERT(DATE,SYSDATETIME()))
                THEN L.SoLuongTon ELSE 0
            END
        ) AS TonHetHan,
        SUM
        (
            CASE
                WHEN L.Active=1
                 AND L.SoLuongTon>0
                 AND (L.HanDung IS NULL OR L.HanDung>=CONVERT(DATE,SYSDATETIME()))
                THEN L.SoLuongTon ELSE 0
            END
        ) AS TonKhaDung,
        MAX(CASE
            WHEN L.SoLo LIKE N'TEST1000-%' AND L.SoLuongTon>0 AND L.Active=0 THEN N'INACTIVE'
            WHEN L.SoLo LIKE N'TEST1000-%' AND L.SoLuongTon>0 AND L.HanDung<CONVERT(DATE,SYSDATETIME()) THEN N'HET_HAN'
            WHEN L.SoLo LIKE N'TEST1000-%' AND L.SoLuongTon>0 AND L.HanDung BETWEEN CONVERT(DATE,SYSDATETIME()) AND DATEADD(DAY,30,CONVERT(DATE,SYSDATETIME())) THEN N'SAP_HET_HAN'
            WHEN L.SoLo LIKE N'TEST1000-%' AND L.SoLuongTon>0 AND L.HanDung IS NULL THEN N'KHONG_HSD'
            WHEN L.SoLo LIKE N'TEST1000-%' AND L.SoLuongTon>0 THEN N'KHA_DUNG'
        END) AS TrangThaiTest
    FROM dbo.DM_Thuoc T
    INNER JOIN dbo.DM_Kho K
      ON K.IDCSKCB=T.IDCSKCB
     AND K.MaKho=N'KHO_THUOC'
     AND K.Active=1
    LEFT JOIN dbo.QL_Kho_LoThuoc L
      ON L.IDCSKCB=T.IDCSKCB
     AND L.IDKho=K.ID
     AND L.IDThuoc=T.ID
    WHERE T.Active=1
    GROUP BY T.IDCSKCB,T.ID,T.MaThuoc,T.TenThuoc
)
SELECT
    IDCSKCB,
    TrangThaiTest,
    COUNT(*) AS SoThuoc,
    MIN(TonVatLy) AS MinTonVatLy,
    MAX(TonVatLy) AS MaxTonVatLy,
    MIN(TonKhaDung) AS MinTonKhaDung,
    MAX(TonKhaDung) AS MaxTonKhaDung,
    MIN(TonHetHan) AS MinTonHetHan,
    MAX(TonHetHan) AS MaxTonHetHan
FROM X
GROUP BY IDCSKCB,TrangThaiTest
ORDER BY IDCSKCB,TrangThaiTest;

IF EXISTS
(
    SELECT 1
    FROM
    (
        SELECT
            T.IDCSKCB,
            T.ID,
            SUM(ISNULL(L.SoLuongTon,0)) AS TonVatLy
        FROM dbo.DM_Thuoc T
        INNER JOIN dbo.DM_Kho K
          ON K.IDCSKCB=T.IDCSKCB
         AND K.MaKho=N'KHO_THUOC'
         AND K.Active=1
        LEFT JOIN dbo.QL_Kho_LoThuoc L
          ON L.IDCSKCB=T.IDCSKCB
         AND L.IDKho=K.ID
         AND L.IDThuoc=T.ID
        WHERE T.Active=1
        GROUP BY T.IDCSKCB,T.ID
    ) A
    WHERE A.TonVatLy<>1000
)
    THROW 59000,N'Seed không đạt: có thuốc không có đúng 1.000 tồn vật lý.',1;

PRINT N'99_TEST_seed_ton_kho_1000.sql: OK - mỗi thuốc Active có đúng 1.000 tồn vật lý.';
GO
