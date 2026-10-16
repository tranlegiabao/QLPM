/*
19_common_global_admin.sql

Tach tai khoan quan_tri_he_thong ra khoi tenant:
- Global admin khong thuoc CSKCB, khong gan DM_NhanVien.
- Tenant account van bat buoc co IDCSKCB + IDNhanVien.
- Global admin chi nhan role synthetic quan_tri_he_thong.
- Neu DB cu co role quan_tri_he_thong, tai khoan active dau tien duoc promote thanh global admin.
  Cac role tenant con lai duoc xem nhu quan_tri_cskcb de khong cap quyen global.
*/
USE [QLPM];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF COL_LENGTH(N'dbo.HT_Tai_Khoan',N'LaQuanTriHeThong') IS NULL
BEGIN
    ALTER TABLE dbo.HT_Tai_Khoan
        ADD LaQuanTriHeThong BIT NOT NULL
            CONSTRAINT DF_HT_Tai_Khoan_LaQuanTriHeThong DEFAULT(0);
END;
GO

/* Cho phep duy nhat global admin khong co tenant/nhan vien. */
IF EXISTS
(
    SELECT 1
    FROM sys.columns
    WHERE object_id=OBJECT_ID(N'dbo.HT_Tai_Khoan')
      AND name IN (N'IDCSKCB',N'IDNhanVien')
      AND is_nullable=0
)
BEGIN
    IF OBJECT_ID(N'dbo.FK_HT_TKVT_TaiKhoan',N'F') IS NOT NULL
        ALTER TABLE dbo.HT_Tai_Khoan_Vai_Tro DROP CONSTRAINT FK_HT_TKVT_TaiKhoan;

    IF OBJECT_ID(N'dbo.FK_HT_Tai_Khoan_NhanVien',N'F') IS NOT NULL
        ALTER TABLE dbo.HT_Tai_Khoan DROP CONSTRAINT FK_HT_Tai_Khoan_NhanVien;

    IF OBJECT_ID(N'dbo.FK_HT_Tai_Khoan_CSKCB',N'F') IS NOT NULL
        ALTER TABLE dbo.HT_Tai_Khoan DROP CONSTRAINT FK_HT_Tai_Khoan_CSKCB;

    IF OBJECT_ID(N'dbo.UQ_HT_Tai_Khoan_NhanVien',N'UQ') IS NOT NULL
        ALTER TABLE dbo.HT_Tai_Khoan DROP CONSTRAINT UQ_HT_Tai_Khoan_NhanVien;

    IF OBJECT_ID(N'dbo.UQ_HT_Tai_Khoan_CSKCB_ID',N'UQ') IS NOT NULL
        ALTER TABLE dbo.HT_Tai_Khoan DROP CONSTRAINT UQ_HT_Tai_Khoan_CSKCB_ID;

    ALTER TABLE dbo.HT_Tai_Khoan ALTER COLUMN IDCSKCB BIGINT NULL;
    ALTER TABLE dbo.HT_Tai_Khoan ALTER COLUMN IDNhanVien BIGINT NULL;

    ALTER TABLE dbo.HT_Tai_Khoan WITH CHECK
        ADD CONSTRAINT FK_HT_Tai_Khoan_CSKCB
            FOREIGN KEY(IDCSKCB) REFERENCES dbo.DM_CSKCB(ID);

    ALTER TABLE dbo.HT_Tai_Khoan WITH CHECK
        ADD CONSTRAINT FK_HT_Tai_Khoan_NhanVien
            FOREIGN KEY(IDNhanVien) REFERENCES dbo.DM_NhanVien(ID);

    ALTER TABLE dbo.HT_Tai_Khoan
        ADD CONSTRAINT UQ_HT_Tai_Khoan_CSKCB_ID UNIQUE(IDCSKCB,ID);

    ALTER TABLE dbo.HT_Tai_Khoan_Vai_Tro WITH CHECK
        ADD CONSTRAINT FK_HT_TKVT_TaiKhoan
            FOREIGN KEY(IDCSKCB,ID_Tai_Khoan) REFERENCES dbo.HT_Tai_Khoan(IDCSKCB,ID);
END;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'dbo.HT_Tai_Khoan')
      AND name=N'UX_HT_Tai_Khoan_NhanVien'
)
BEGIN
    CREATE UNIQUE INDEX UX_HT_Tai_Khoan_NhanVien
        ON dbo.HT_Tai_Khoan(IDCSKCB,IDNhanVien)
        WHERE IDCSKCB IS NOT NULL AND IDNhanVien IS NOT NULL;
END;
GO

/* Promote mot admin legacy de deployment hien tai khong bi mat quyen. */
IF NOT EXISTS(SELECT 1 FROM dbo.HT_Tai_Khoan WHERE LaQuanTriHeThong=1)
BEGIN
    DECLARE @IDAdmin BIGINT;

    SELECT TOP(1) @IDAdmin=T.ID
    FROM dbo.HT_Tai_Khoan T
    INNER JOIN dbo.HT_Tai_Khoan_Vai_Tro TV
        ON TV.IDCSKCB=T.IDCSKCB AND TV.ID_Tai_Khoan=T.ID AND TV.Active=1
    INNER JOIN dbo.DM_Vai_Tro V
        ON V.IDCSKCB=TV.IDCSKCB AND V.ID=TV.ID_Vai_Tro AND V.Active=1
    WHERE T.Active=1
      AND V.Ma_Vai_Tro=N'quan_tri_he_thong'
    ORDER BY T.ID;

    IF @IDAdmin IS NOT NULL
    BEGIN
        DELETE TV
        FROM dbo.HT_Tai_Khoan_Vai_Tro TV
        INNER JOIN dbo.HT_Tai_Khoan T
            ON T.ID=TV.ID_Tai_Khoan AND T.IDCSKCB=TV.IDCSKCB
        WHERE T.ID=@IDAdmin;

        UPDATE dbo.HT_Tai_Khoan
        SET LaQuanTriHeThong=1,
            IDCSKCB=NULL,
            IDNhanVien=NULL,
            Ngay_Cap_Nhat=SYSDATETIME()
        WHERE ID=@IDAdmin;
    END;
END;
GO

/* Role cu o tenant khong con duoc hieu la global admin.
   Neu da co quan_tri_cskcb thi gop mapping/quyen vao role do truoc khi xoa role cu. */
INSERT dbo.HT_Tai_Khoan_Vai_Tro(IDCSKCB,ID_Tai_Khoan,ID_Vai_Tro,Active)
SELECT O.IDCSKCB,TV.ID_Tai_Khoan,N.ID,TV.Active
FROM dbo.DM_Vai_Tro O
INNER JOIN dbo.DM_Vai_Tro N
    ON N.IDCSKCB=O.IDCSKCB
   AND N.Ma_Vai_Tro=N'quan_tri_cskcb'
   AND N.ID<>O.ID
INNER JOIN dbo.HT_Tai_Khoan_Vai_Tro TV
    ON TV.IDCSKCB=O.IDCSKCB
   AND TV.ID_Vai_Tro=O.ID
WHERE O.Ma_Vai_Tro=N'quan_tri_he_thong'
  AND NOT EXISTS
  (
      SELECT 1
      FROM dbo.HT_Tai_Khoan_Vai_Tro X
      WHERE X.IDCSKCB=O.IDCSKCB
        AND X.ID_Tai_Khoan=TV.ID_Tai_Khoan
        AND X.ID_Vai_Tro=N.ID
  );

INSERT dbo.HT_Quyen_Vai_Tro
    (IDCSKCB,ID_Vai_Tro,ID_Chuc_Nang,Xem,Them,Sua,Xoa,Xuat,Ca_Nhan)
SELECT
    O.IDCSKCB,N.ID,Q.ID_Chuc_Nang,Q.Xem,Q.Them,Q.Sua,Q.Xoa,Q.Xuat,Q.Ca_Nhan
FROM dbo.DM_Vai_Tro O
INNER JOIN dbo.DM_Vai_Tro N
    ON N.IDCSKCB=O.IDCSKCB
   AND N.Ma_Vai_Tro=N'quan_tri_cskcb'
   AND N.ID<>O.ID
INNER JOIN dbo.HT_Quyen_Vai_Tro Q
    ON Q.IDCSKCB=O.IDCSKCB
   AND Q.ID_Vai_Tro=O.ID
WHERE O.Ma_Vai_Tro=N'quan_tri_he_thong'
  AND NOT EXISTS
  (
      SELECT 1
      FROM dbo.HT_Quyen_Vai_Tro X
      WHERE X.IDCSKCB=O.IDCSKCB
        AND X.ID_Vai_Tro=N.ID
        AND X.ID_Chuc_Nang=Q.ID_Chuc_Nang
  );

UPDATE T
SET Xem=CASE WHEN T.Xem=1 OR Q.Xem=1 THEN 1 ELSE 0 END,
    Them=CASE WHEN T.Them=1 OR Q.Them=1 THEN 1 ELSE 0 END,
    Sua=CASE WHEN T.Sua=1 OR Q.Sua=1 THEN 1 ELSE 0 END,
    Xoa=CASE WHEN T.Xoa=1 OR Q.Xoa=1 THEN 1 ELSE 0 END,
    Xuat=CASE WHEN T.Xuat=1 OR Q.Xuat=1 THEN 1 ELSE 0 END,
    Ca_Nhan=CASE WHEN T.Ca_Nhan=1 OR Q.Ca_Nhan=1 THEN 1 ELSE 0 END
FROM dbo.HT_Quyen_Vai_Tro T
INNER JOIN dbo.DM_Vai_Tro N
    ON N.IDCSKCB=T.IDCSKCB
   AND N.ID=T.ID_Vai_Tro
   AND N.Ma_Vai_Tro=N'quan_tri_cskcb'
INNER JOIN dbo.DM_Vai_Tro O
    ON O.IDCSKCB=N.IDCSKCB
   AND O.Ma_Vai_Tro=N'quan_tri_he_thong'
   AND O.ID<>N.ID
INNER JOIN dbo.HT_Quyen_Vai_Tro Q
    ON Q.IDCSKCB=O.IDCSKCB
   AND Q.ID_Vai_Tro=O.ID
   AND Q.ID_Chuc_Nang=T.ID_Chuc_Nang;

DELETE TV
FROM dbo.HT_Tai_Khoan_Vai_Tro TV
INNER JOIN dbo.DM_Vai_Tro O
    ON O.IDCSKCB=TV.IDCSKCB
   AND O.ID=TV.ID_Vai_Tro
   AND O.Ma_Vai_Tro=N'quan_tri_he_thong'
WHERE EXISTS
(
    SELECT 1 FROM dbo.DM_Vai_Tro N
    WHERE N.IDCSKCB=O.IDCSKCB
      AND N.Ma_Vai_Tro=N'quan_tri_cskcb'
      AND N.ID<>O.ID
);

DELETE Q
FROM dbo.HT_Quyen_Vai_Tro Q
INNER JOIN dbo.DM_Vai_Tro O
    ON O.IDCSKCB=Q.IDCSKCB
   AND O.ID=Q.ID_Vai_Tro
   AND O.Ma_Vai_Tro=N'quan_tri_he_thong'
WHERE EXISTS
(
    SELECT 1 FROM dbo.DM_Vai_Tro N
    WHERE N.IDCSKCB=O.IDCSKCB
      AND N.Ma_Vai_Tro=N'quan_tri_cskcb'
      AND N.ID<>O.ID
);

DELETE O
FROM dbo.DM_Vai_Tro O
WHERE O.Ma_Vai_Tro=N'quan_tri_he_thong'
  AND EXISTS
  (
      SELECT 1 FROM dbo.DM_Vai_Tro N
      WHERE N.IDCSKCB=O.IDCSKCB
        AND N.Ma_Vai_Tro=N'quan_tri_cskcb'
        AND N.ID<>O.ID
  );

UPDATE V
SET Ma_Vai_Tro=N'quan_tri_cskcb',
    Ten_Vai_Tro=CASE WHEN V.Ten_Vai_Tro=N'Quản trị hệ thống' THEN N'Quản trị cơ sở KCB' ELSE V.Ten_Vai_Tro END,
    Mo_Ta=COALESCE(NULLIF(V.Mo_Ta,N''),N'Quản trị trong phạm vi một cơ sở KCB.'),
    Ngay_Cap_Nhat=SYSDATETIME()
FROM dbo.DM_Vai_Tro V
WHERE V.Ma_Vai_Tro=N'quan_tri_he_thong';
GO

IF OBJECT_ID(N'dbo.CK_HT_Tai_Khoan_PhamVi',N'C') IS NULL
BEGIN
    ALTER TABLE dbo.HT_Tai_Khoan WITH CHECK
        ADD CONSTRAINT CK_HT_Tai_Khoan_PhamVi CHECK
        (
            (LaQuanTriHeThong=1 AND IDCSKCB IS NULL AND IDNhanVien IS NULL)
            OR
            (LaQuanTriHeThong=0 AND IDCSKCB IS NOT NULL AND IDNhanVien IS NOT NULL)
        );
END;
GO

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

PRINT N'19_common_global_admin.sql: OK';
GO
