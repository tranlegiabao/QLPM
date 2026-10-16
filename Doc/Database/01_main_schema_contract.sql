/*
01_main_schema_contract.sql
Chuan hoa schema canonical ma runtime main su dung.
Legacy migration/drop duoc thuc hien tap trung o 18_main_cleanup_legacy.sql.
*/
USE [QLPM];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* Tách ghi chú tiếp nhận và dặn dò bác sĩ.
   Schema cũ dùng chung QL_VaoVien.GhiChu cho hai nghiệp vụ nên có thể đã bị ghi đè.
   Dữ liệu cũ được phân loại theo bằng chứng đã phát sinh khám; trường hợp đang khám
   nhưng không đủ bằng chứng được giữ ở cả hai cột để tránh mất dữ liệu lịch sử. */
IF OBJECT_ID(N'dbo.QL_VaoVien',N'U') IS NULL
    THROW 59009,N'Thieu bang QL_VaoVien; khong the tach ghi chu tiep nhan va dan do.',1;
GO

/* QL_VaoVien là master duy nhất của lượt khám.
   Hai mốc riêng phân biệt mở màn hình khám với lần lưu chính thức đầu tiên. */
IF COL_LENGTH(N'dbo.QL_VaoVien',N'NgayLuuKhamLanDau') IS NULL
    ALTER TABLE dbo.QL_VaoVien ADD NgayLuuKhamLanDau DATETIME2(0) NULL;
GO

IF COL_LENGTH(N'dbo.QL_VaoVien',N'NgayCapNhatKham') IS NULL
    ALTER TABLE dbo.QL_VaoVien ADD NgayCapNhatKham DATETIME2(0) NULL;
GO

IF COL_LENGTH(N'dbo.QL_VaoVien',N'GhiChuTiepNhan') IS NULL
    ALTER TABLE dbo.QL_VaoVien ADD GhiChuTiepNhan NVARCHAR(1000) NULL;
GO

IF COL_LENGTH(N'dbo.QL_VaoVien',N'DanDo') IS NULL
    ALTER TABLE dbo.QL_VaoVien ADD DanDo NVARCHAR(1000) NULL;
GO

IF COL_LENGTH(N'dbo.QL_VaoVien',N'GhiChu') IS NOT NULL
BEGIN
    EXEC sys.sp_executesql N'
        ;WITH X AS
        (
            SELECT
                V.IDCSKCB,
                V.ID,
                NULLIF(LTRIM(RTRIM(V.GhiChu)),N'''') AS LegacyGhiChu,
                CASE
                    WHEN V.TrangThaiKham=2
                      OR ISNULL(V.Kham,0)=1
                      OR ISNULL(V.KeToa,0)=1
                      OR NULLIF(LTRIM(RTRIM(V.TrieuChung)),N'''') IS NOT NULL
                      OR V.IDPhacDo IS NOT NULL
                      OR V.NgayTaiKham IS NOT NULL
                      OR EXISTS(SELECT 1 FROM dbo.QL_PhieuSinhHieu P WHERE P.IDCSKCB=V.IDCSKCB AND P.IDVaoVien=V.ID)
                      OR EXISTS(SELECT 1 FROM dbo.QL_ChanDoan_CT C WHERE C.IDCSKCB=V.IDCSKCB AND C.IDVaoVien=V.ID)
                      OR EXISTS(SELECT 1 FROM dbo.QL_ChiDinh_CT C WHERE C.IDCSKCB=V.IDCSKCB AND C.IDVaoVien=V.ID AND C.Active=1)
                      OR EXISTS(SELECT 1 FROM dbo.QL_ToaThuoc_CT T WHERE T.IDCSKCB=V.IDCSKCB AND T.IDVaoVien=V.ID AND T.Active=1)
                    THEN 1 ELSE 0
                END AS CoBangChungDaLuuKham
            FROM dbo.QL_VaoVien V
            WHERE NULLIF(LTRIM(RTRIM(V.GhiChu)),N'''') IS NOT NULL
        )
        UPDATE V
        SET
            GhiChuTiepNhan =
                CASE
                    WHEN X.CoBangChungDaLuuKham=0
                      OR (V.TrangThaiKham=1 AND X.CoBangChungDaLuuKham=0)
                    THEN COALESCE(V.GhiChuTiepNhan,X.LegacyGhiChu)
                    ELSE V.GhiChuTiepNhan
                END,
            DanDo =
                CASE
                    WHEN X.CoBangChungDaLuuKham=1
                    THEN COALESCE(V.DanDo,X.LegacyGhiChu)
                    WHEN V.TrangThaiKham=1
                    THEN COALESCE(V.DanDo,X.LegacyGhiChu)
                    ELSE V.DanDo
                END
        FROM dbo.QL_VaoVien V
        INNER JOIN X ON X.IDCSKCB=V.IDCSKCB AND X.ID=V.ID;
    ';
END;
GO

/* Chuyển dấu mốc đã lưu từ master cũ sang QL_VaoVien rồi loại bỏ master trùng. */
IF OBJECT_ID(N'dbo.QL_PhieuKham',N'U') IS NOT NULL
BEGIN
    EXEC sys.sp_executesql N'
        UPDATE V
        SET NgayLuuKhamLanDau=COALESCE(V.NgayLuuKhamLanDau,P.NgayGioTao),
            NgayCapNhatKham=COALESCE(V.NgayCapNhatKham,P.NgayCapNhat),
            IDBacSiKham=COALESCE(V.IDBacSiKham,P.IDBacSi)
        FROM dbo.QL_VaoVien V
        INNER JOIN dbo.QL_PhieuKham P
            ON P.IDCSKCB=V.IDCSKCB AND P.IDVaoVien=V.ID
        WHERE P.Active=1;
    ';

    DROP TABLE dbo.QL_PhieuKham;
END;
GO

/* Hỗ trợ database cũ chưa từng có QL_PhieuKham nhưng đã phát sinh dữ liệu khám. */
UPDATE V
SET NgayLuuKhamLanDau=COALESCE(V.NgayLuuKhamLanDau,V.KetThucKhamLuc,V.NgayCapNhat,V.NgayGioVaoVien),
    NgayCapNhatKham=COALESCE(V.NgayCapNhatKham,V.KetThucKhamLuc,V.NgayCapNhat,V.NgayGioVaoVien)
FROM dbo.QL_VaoVien V
WHERE V.NgayLuuKhamLanDau IS NULL
  AND
  (
      V.TrangThaiKham=2
      OR ISNULL(V.Kham,0)=1
      OR NULLIF(LTRIM(RTRIM(V.TrieuChung)),N'') IS NOT NULL
      OR V.IDPhacDo IS NOT NULL
      OR V.NgayTaiKham IS NOT NULL
      OR NULLIF(LTRIM(RTRIM(V.DanDo)),N'') IS NOT NULL
      OR EXISTS(SELECT 1 FROM dbo.QL_PhieuSinhHieu P WHERE P.IDCSKCB=V.IDCSKCB AND P.IDVaoVien=V.ID)
      OR EXISTS(SELECT 1 FROM dbo.QL_ChanDoan_CT C WHERE C.IDCSKCB=V.IDCSKCB AND C.IDVaoVien=V.ID)
      OR EXISTS(SELECT 1 FROM dbo.QL_ChiDinh_CT C WHERE C.IDCSKCB=V.IDCSKCB AND C.IDVaoVien=V.ID AND C.Active=1)
      OR EXISTS(SELECT 1 FROM dbo.QL_ToaThuoc_CT T WHERE T.IDCSKCB=V.IDCSKCB AND T.IDVaoVien=V.ID AND T.Active=1)
  );
GO

/* Mỗi lượt khám chỉ giữ một phiếu sinh hiệu; giữ phiếu mới nhất nếu dữ liệu cũ bị lặp. */
IF OBJECT_ID(N'dbo.QL_PhieuSinhHieu',N'U') IS NULL
 OR OBJECT_ID(N'dbo.QL_PhieuSinhHieu_CT',N'U') IS NULL
    THROW 59010,N'Thieu bang sinh hieu; khong the ap dung contract mot phieu moi luot kham.',1;
GO

/* Huyet ap chi co mot nguon chuan: QL_PhieuSinhHieu_CT qua HA_TT/HA_TR.
   Neu schema cu con QL_PhieuSinhHieu.HuyetAp thi backfill an toan roi moi bo cot. */
IF COL_LENGTH(N'dbo.QL_PhieuSinhHieu',N'HuyetAp') IS NOT NULL
BEGIN
    EXEC sys.sp_executesql N'
        ;WITH Legacy AS
        (
            SELECT
                P.IDCSKCB,
                P.ID AS IDPhieuSinhHieu,
                NULLIF(LTRIM(RTRIM(REPLACE(P.HuyetAp,N''-'',N''/''))),N'''') AS HA
            FROM dbo.QL_PhieuSinhHieu P
            WHERE NULLIF(LTRIM(RTRIM(P.HuyetAp)),N'''') IS NOT NULL
        ),
        Parsed AS
        (
            SELECT
                IDCSKCB,
                IDPhieuSinhHieu,
                LTRIM(RTRIM(LEFT(HA,CHARINDEX(N''/'',HA)-1))) AS TamThu,
                LTRIM(RTRIM(SUBSTRING(HA,CHARINDEX(N''/'',HA)+1,100))) AS TamTruong
            FROM Legacy
            WHERE CHARINDEX(N''/'',HA)>1
        )
        INSERT dbo.QL_PhieuSinhHieu_CT(IDCSKCB,IDPhieuSinhHieu,IDTriSoSinhHieu,GiaTri)
        SELECT
            P.IDCSKCB,
            P.IDPhieuSinhHieu,
            D.ID,
            CASE WHEN UPPER(D.MaTriSo)=N''HA_TT'' THEN P.TamThu ELSE P.TamTruong END
        FROM Parsed P
        INNER JOIN dbo.DM_TriSoSinhHieu D
            ON D.IDCSKCB=P.IDCSKCB
           AND UPPER(D.MaTriSo) IN(N''HA_TT'',N''HA_TR'')
           AND D.Active=1
        WHERE NULLIF(CASE WHEN UPPER(D.MaTriSo)=N''HA_TT'' THEN P.TamThu ELSE P.TamTruong END,N'''') IS NOT NULL
          AND NOT EXISTS
          (
              SELECT 1
              FROM dbo.QL_PhieuSinhHieu_CT CT
              WHERE CT.IDCSKCB=P.IDCSKCB
                AND CT.IDPhieuSinhHieu=P.IDPhieuSinhHieu
                AND CT.IDTriSoSinhHieu=D.ID
          );

        IF EXISTS
        (
            SELECT 1
            FROM dbo.QL_PhieuSinhHieu P
            WHERE NULLIF(LTRIM(RTRIM(P.HuyetAp)),N'''') IS NOT NULL
              AND
              (
                  NOT EXISTS
                  (
                      SELECT 1
                      FROM dbo.QL_PhieuSinhHieu_CT CT
                      INNER JOIN dbo.DM_TriSoSinhHieu D
                          ON D.IDCSKCB=CT.IDCSKCB
                         AND D.ID=CT.IDTriSoSinhHieu
                      WHERE CT.IDCSKCB=P.IDCSKCB
                        AND CT.IDPhieuSinhHieu=P.ID
                        AND UPPER(D.MaTriSo)=N''HA_TT''
                        AND NULLIF(LTRIM(RTRIM(CT.GiaTri)),N'''') IS NOT NULL
                  )
                  OR NOT EXISTS
                  (
                      SELECT 1
                      FROM dbo.QL_PhieuSinhHieu_CT CT
                      INNER JOIN dbo.DM_TriSoSinhHieu D
                          ON D.IDCSKCB=CT.IDCSKCB
                         AND D.ID=CT.IDTriSoSinhHieu
                      WHERE CT.IDCSKCB=P.IDCSKCB
                        AND CT.IDPhieuSinhHieu=P.ID
                        AND UPPER(D.MaTriSo)=N''HA_TR''
                        AND NULLIF(LTRIM(RTRIM(CT.GiaTri)),N'''') IS NOT NULL
                  )
              )
        )
            THROW 59011,N''Khong the bo QL_PhieuSinhHieu.HuyetAp vi con du lieu cu chua map du HA_TT/HA_TR.'',1;
    ';

    ALTER TABLE dbo.QL_PhieuSinhHieu DROP COLUMN HuyetAp;
END;
GO

;WITH Ranked AS
(
    SELECT IDCSKCB,ID,ROW_NUMBER() OVER
        (PARTITION BY IDCSKCB,IDVaoVien ORDER BY NgayGioDo DESC,ID DESC) AS RN
    FROM dbo.QL_PhieuSinhHieu
)
DELETE CT
FROM dbo.QL_PhieuSinhHieu_CT CT
INNER JOIN Ranked R ON R.IDCSKCB=CT.IDCSKCB AND R.ID=CT.IDPhieuSinhHieu
WHERE R.RN>1;
GO

;WITH Ranked AS
(
    SELECT IDCSKCB,ID,ROW_NUMBER() OVER
        (PARTITION BY IDCSKCB,IDVaoVien ORDER BY NgayGioDo DESC,ID DESC) AS RN
    FROM dbo.QL_PhieuSinhHieu
)
DELETE P
FROM dbo.QL_PhieuSinhHieu P
INNER JOIN Ranked R ON R.IDCSKCB=P.IDCSKCB AND R.ID=P.ID
WHERE R.RN>1;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'dbo.QL_PhieuSinhHieu')
      AND name=N'UQ_QL_PhieuSinhHieu_CSKCB_VV'
)
    CREATE UNIQUE INDEX UQ_QL_PhieuSinhHieu_CSKCB_VV
        ON dbo.QL_PhieuSinhHieu(IDCSKCB,IDVaoVien);
GO

/* CLS PDF-only: khong con yeu cau QL_CLS_DM_TriSoXN / QL_CLS_KetQuaXN_CT */

/* COMMON DM_DonViTinh: tach danh muc don vi tinh thuoc theo HIS HH_DM_DonViTinh. */
IF OBJECT_ID(N'dbo.DM_DonViTinh',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DM_DonViTinh
    (
        ID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DM_DonViTinh PRIMARY KEY,
        IDCSKCB BIGINT NOT NULL,
        MaDVT NVARCHAR(100) NOT NULL,
        TenDVT NVARCHAR(1000) NOT NULL,
        Active BIT NOT NULL CONSTRAINT DF_DM_DonViTinh_Active DEFAULT(1),
        CONSTRAINT UQ_DM_DonViTinh_CSKCB_ID UNIQUE(IDCSKCB,ID),
        CONSTRAINT UQ_DM_DonViTinh_CSKCB_Ma UNIQUE(IDCSKCB,MaDVT),
        CONSTRAINT FK_DM_DonViTinh_CSKCB FOREIGN KEY(IDCSKCB) REFERENCES dbo.DM_CSKCB(ID)
    );
END;
GO

IF COL_LENGTH(N'dbo.DM_Thuoc',N'IDDonViTinh') IS NULL
    ALTER TABLE dbo.DM_Thuoc ADD IDDonViTinh BIGINT NULL;
GO

/* Giu tuong thich data cu: tao DVT legacy tu chuoi DonViTinh roi map FK. */
INSERT dbo.DM_DonViTinh(IDCSKCB,MaDVT,TenDVT,Active)
SELECT DISTINCT
       T.IDCSKCB,
       N'LEGACY_' + CONVERT(VARCHAR(64),HASHBYTES('SHA2_256',
           CONCAT(CONVERT(NVARCHAR(40),T.IDCSKCB),N'|',LOWER(LTRIM(RTRIM(T.DonViTinh))))),2),
       LTRIM(RTRIM(T.DonViTinh)),
       1
FROM dbo.DM_Thuoc T
WHERE NULLIF(LTRIM(RTRIM(T.DonViTinh)),N'') IS NOT NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM dbo.DM_DonViTinh D
      WHERE D.IDCSKCB=T.IDCSKCB
        AND LOWER(LTRIM(RTRIM(D.TenDVT)))=LOWER(LTRIM(RTRIM(T.DonViTinh)))
  );
GO

UPDATE T
SET T.IDDonViTinh=D.ID
FROM dbo.DM_Thuoc T
INNER JOIN dbo.DM_DonViTinh D
    ON D.IDCSKCB=T.IDCSKCB
   AND LOWER(LTRIM(RTRIM(D.TenDVT)))=LOWER(LTRIM(RTRIM(T.DonViTinh)))
WHERE T.IDDonViTinh IS NULL
  AND NULLIF(LTRIM(RTRIM(T.DonViTinh)),N'') IS NOT NULL;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.foreign_keys
    WHERE parent_object_id=OBJECT_ID(N'dbo.DM_Thuoc')
      AND name=N'FK_DM_Thuoc_DonViTinh'
)
    ALTER TABLE dbo.DM_Thuoc WITH CHECK
        ADD CONSTRAINT FK_DM_Thuoc_DonViTinh
        FOREIGN KEY(IDCSKCB,IDDonViTinh)
        REFERENCES dbo.DM_DonViTinh(IDCSKCB,ID);
GO

/* Snapshot hoạt chất trên từng dòng toa để lịch sử không đổi khi danh mục thuốc thay đổi. */
IF OBJECT_ID(N'dbo.QL_ToaThuoc_CT',N'U') IS NOT NULL
   AND COL_LENGTH(N'dbo.QL_ToaThuoc_CT',N'HoatChat') IS NULL
    ALTER TABLE dbo.QL_ToaThuoc_CT ADD HoatChat NVARCHAR(1000) NULL;
GO

UPDATE T
SET T.HoatChat=M.HoatChat
FROM dbo.QL_ToaThuoc_CT T
INNER JOIN dbo.DM_Thuoc M
    ON M.IDCSKCB=T.IDCSKCB
   AND M.ID=T.IDThuoc
WHERE NULLIF(LTRIM(RTRIM(T.HoatChat)),N'') IS NULL
  AND NULLIF(LTRIM(RTRIM(M.HoatChat)),N'') IS NOT NULL;
GO

/* ĐVT dùng trên từng dòng toa: tách khỏi ĐVT xuất mặc định của danh mục thuốc. */
IF OBJECT_ID(N'dbo.QL_ToaThuoc_CT',N'U') IS NOT NULL
   AND COL_LENGTH(N'dbo.QL_ToaThuoc_CT',N'IDDonViTinhDung') IS NULL
    ALTER TABLE dbo.QL_ToaThuoc_CT ADD IDDonViTinhDung BIGINT NULL;
GO

UPDATE T
SET T.IDDonViTinhDung=M.IDDonViTinh
FROM dbo.QL_ToaThuoc_CT T
INNER JOIN dbo.DM_Thuoc M
    ON M.IDCSKCB=T.IDCSKCB
   AND M.ID=T.IDThuoc
WHERE T.IDDonViTinhDung IS NULL
  AND M.IDDonViTinh IS NOT NULL;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.foreign_keys
    WHERE parent_object_id=OBJECT_ID(N'dbo.QL_ToaThuoc_CT')
      AND name=N'FK_QL_ToaThuocCT_DonViTinhDung'
)
    ALTER TABLE dbo.QL_ToaThuoc_CT WITH CHECK
        ADD CONSTRAINT FK_QL_ToaThuocCT_DonViTinhDung
        FOREIGN KEY(IDCSKCB,IDDonViTinhDung)
        REFERENCES dbo.DM_DonViTinh(IDCSKCB,ID);
GO

/* ĐVT dùng trên thuốc mẫu phác đồ: giống toa khám, nhưng phác đồ không lưu Ngày giờ. */
IF OBJECT_ID(N'dbo.DM_PhacDo_Thuoc',N'U') IS NOT NULL
   AND COL_LENGTH(N'dbo.DM_PhacDo_Thuoc',N'IDDonViTinhDung') IS NULL
    ALTER TABLE dbo.DM_PhacDo_Thuoc ADD IDDonViTinhDung BIGINT NULL;
GO

UPDATE T
SET T.IDDonViTinhDung=M.IDDonViTinh
FROM dbo.DM_PhacDo_Thuoc T
INNER JOIN dbo.DM_Thuoc M
    ON M.IDCSKCB=T.IDCSKCB
   AND M.ID=T.IDThuoc
WHERE T.IDDonViTinhDung IS NULL
  AND M.IDDonViTinh IS NOT NULL;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.foreign_keys
    WHERE parent_object_id=OBJECT_ID(N'dbo.DM_PhacDo_Thuoc')
      AND name=N'FK_DM_PhacDoThuoc_DonViTinhDung'
)
    ALTER TABLE dbo.DM_PhacDo_Thuoc WITH CHECK
        ADD CONSTRAINT FK_DM_PhacDoThuoc_DonViTinhDung
        FOREIGN KEY(IDCSKCB,IDDonViTinhDung)
        REFERENCES dbo.DM_DonViTinh(IDCSKCB,ID);
GO

/* CLS PDF-only: DM_DichVu khong can LoaiKetQua / IDFormKQ; cac bang va trigger CLS structured da bo khoi schema main. */
GO

PRINT N'01_main_schema_contract.sql: OK';
GO
