/*
24_json_danh_muc_phien_ban.sql
- JSON la read-model/cache, DB la source of truth.
- Moi CSKCB co 1 dong version JSON dung chung cho tat ca danh muc tenant.
- Version tang khi source table thay doi; PublishedVersionNo chi tang sau khi JSON publish thanh cong.
- Khong tao file v1/v2; chi giu file JSON hien tai + metadata version trong DB.
- Worker se chay theo gio server luc 00:00, chi convert CSKCB dang dirty.
*/

USE [QLPM];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.HT_JSON_CSKCB',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.HT_JSON_CSKCB
    (
        IDCSKCB BIGINT NOT NULL
            CONSTRAINT PK_HT_JSON_CSKCB PRIMARY KEY,
        VersionNo BIGINT NOT NULL
            CONSTRAINT DF_HT_JSON_CSKCB_VersionNo DEFAULT(1),
        PublishedVersionNo BIGINT NOT NULL
            CONSTRAINT DF_HT_JSON_CSKCB_PublishedVersionNo DEFAULT(0),
        TrangThai NVARCHAR(20) NOT NULL
            CONSTRAINT DF_HT_JSON_CSKCB_TrangThai DEFAULT(N'CHO_DONG_BO'),
        LastChangedAt DATETIME2(0) NOT NULL
            CONSTRAINT DF_HT_JSON_CSKCB_LastChangedAt DEFAULT(SYSDATETIME()),
        LastGeneratedAt DATETIME2(0) NULL,
        LastError NVARCHAR(2000) NULL,
        UpdatedAt DATETIME2(0) NOT NULL
            CONSTRAINT DF_HT_JSON_CSKCB_UpdatedAt DEFAULT(SYSDATETIME()),
        CONSTRAINT FK_HT_JSON_CSKCB_CSKCB
            FOREIGN KEY(IDCSKCB) REFERENCES dbo.DM_CSKCB(ID)
            ON DELETE CASCADE,
        CONSTRAINT CK_HT_JSON_CSKCB_Version
            CHECK(PublishedVersionNo>=0 AND PublishedVersionNo<=VersionNo),
        CONSTRAINT CK_HT_JSON_CSKCB_TrangThai
            CHECK(TrangThai IN(N'CHO_DONG_BO',N'DANG_DONG_BO',N'SAN_SANG',N'LOI'))
    );
END;
GO

IF OBJECT_ID(N'dbo.HT_JSON_DongBo_Lich',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.HT_JSON_DongBo_Lich
    (
        ID TINYINT NOT NULL
            CONSTRAINT PK_HT_JSON_DongBo_Lich PRIMARY KEY,
        NgayChayCuoi DATE NULL,
        LanChayCuoi DATETIME2(0) NULL,
        TrangThai NVARCHAR(20) NOT NULL
            CONSTRAINT DF_HT_JSON_DongBo_Lich_TrangThai DEFAULT(N'CHUA_CHAY'),
        LastError NVARCHAR(2000) NULL,
        UpdatedAt DATETIME2(0) NOT NULL
            CONSTRAINT DF_HT_JSON_DongBo_Lich_UpdatedAt DEFAULT(SYSDATETIME()),
        CONSTRAINT CK_HT_JSON_DongBo_Lich_ID CHECK(ID=1)
    );
END;
GO

IF NOT EXISTS(SELECT 1 FROM dbo.HT_JSON_DongBo_Lich WHERE ID=1)
    INSERT dbo.HT_JSON_DongBo_Lich(ID,NgayChayCuoi,TrangThai)
    VALUES(1,CONVERT(DATE,SYSDATETIME()),N'CHUA_CHAY');
GO

/* Canonical source cho hai JSON truoc day chi ton tai dang file. */
IF OBJECT_ID(N'dbo.DM_QuocTich',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DM_QuocTich
    (
        IDCSKCB BIGINT NOT NULL,
        ID BIGINT NOT NULL,
        MaQuocTich NVARCHAR(20) NOT NULL,
        TenQuocTich NVARCHAR(200) NOT NULL,
        Active BIT NOT NULL
            CONSTRAINT DF_DM_QuocTich_Active DEFAULT(1),
        CONSTRAINT PK_DM_QuocTich PRIMARY KEY(IDCSKCB,ID),
        CONSTRAINT UQ_DM_QuocTich_CSKCB_Ma UNIQUE(IDCSKCB,MaQuocTich),
        CONSTRAINT FK_DM_QuocTich_CSKCB FOREIGN KEY(IDCSKCB)
            REFERENCES dbo.DM_CSKCB(ID) ON DELETE CASCADE
    );
END;
GO

IF OBJECT_ID(N'dbo.DM_NgheNghiep',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DM_NgheNghiep
    (
        IDCSKCB BIGINT NOT NULL,
        ID BIGINT NOT NULL,
        MaNgheNghiep NVARCHAR(20) NOT NULL,
        TenNgheNghiep NVARCHAR(200) NOT NULL,
        Active BIT NOT NULL
            CONSTRAINT DF_DM_NgheNghiep_Active DEFAULT(1),
        CONSTRAINT PK_DM_NgheNghiep PRIMARY KEY(IDCSKCB,ID),
        CONSTRAINT UQ_DM_NgheNghiep_CSKCB_Ma UNIQUE(IDCSKCB,MaNgheNghiep),
        CONSTRAINT FK_DM_NgheNghiep_CSKCB FOREIGN KEY(IDCSKCB)
            REFERENCES dbo.DM_CSKCB(ID) ON DELETE CASCADE
    );
END;
GO

/* Backfill bo danh muc chuan hien dang dung trong JSON runtime. */
;WITH S AS
(
    SELECT *
    FROM (VALUES
        (CAST(1 AS BIGINT),N'VN',N'Việt Nam'),
        (CAST(2 AS BIGINT),N'LA',N'Lào'),
        (CAST(3 AS BIGINT),N'KH',N'Campuchia'),
        (CAST(4 AS BIGINT),N'TH',N'Thái Lan'),
        (CAST(5 AS BIGINT),N'SG',N'Singapore'),
        (CAST(6 AS BIGINT),N'MY',N'Malaysia'),
        (CAST(7 AS BIGINT),N'ID',N'Indonesia'),
        (CAST(8 AS BIGINT),N'PH',N'Philippines'),
        (CAST(9 AS BIGINT),N'CN',N'Trung Quốc'),
        (CAST(10 AS BIGINT),N'KR',N'Hàn Quốc'),
        (CAST(11 AS BIGINT),N'JP',N'Nhật Bản'),
        (CAST(12 AS BIGINT),N'TW',N'Đài Loan'),
        (CAST(13 AS BIGINT),N'US',N'Hoa Kỳ'),
        (CAST(14 AS BIGINT),N'GB',N'Vương Quốc Anh'),
        (CAST(15 AS BIGINT),N'FR',N'Pháp'),
        (CAST(16 AS BIGINT),N'DE',N'Đức'),
        (CAST(17 AS BIGINT),N'RU',N'Nga'),
        (CAST(18 AS BIGINT),N'AU',N'Úc'),
        (CAST(19 AS BIGINT),N'CA',N'Canada'),
        (CAST(99 AS BIGINT),N'XX',N'Quốc tịch khác')
    ) V(ID,MaQuocTich,TenQuocTich)
)
INSERT dbo.DM_QuocTich(IDCSKCB,ID,MaQuocTich,TenQuocTich,Active)
SELECT C.ID,S.ID,S.MaQuocTich,S.TenQuocTich,1
FROM dbo.DM_CSKCB C
CROSS JOIN S
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.DM_QuocTich T
    WHERE T.IDCSKCB=C.ID AND T.ID=S.ID
);
GO

;WITH S AS
(
    SELECT *
    FROM (VALUES
        (CAST(1 AS BIGINT),N'01',N'Cán bộ, công chức, viên chức'),
        (CAST(2 AS BIGINT),N'02',N'Công nhân'),
        (CAST(3 AS BIGINT),N'03',N'Nông dân'),
        (CAST(4 AS BIGINT),N'04',N'Kinh doanh, buôn bán'),
        (CAST(5 AS BIGINT),N'05',N'Nhân viên văn phòng, dịch vụ'),
        (CAST(6 AS BIGINT),N'06',N'Lực lượng vũ trang'),
        (CAST(7 AS BIGINT),N'07',N'Học sinh, sinh viên'),
        (CAST(8 AS BIGINT),N'08',N'Trẻ em dưới 6 tuổi'),
        (CAST(9 AS BIGINT),N'09',N'Hưu trí, người cao tuổi'),
        (CAST(10 AS BIGINT),N'10',N'Nội trợ'),
        (CAST(11 AS BIGINT),N'11',N'Lao động tự do'),
        (CAST(99 AS BIGINT),N'99',N'Khác')
    ) V(ID,MaNgheNghiep,TenNgheNghiep)
)
INSERT dbo.DM_NgheNghiep(IDCSKCB,ID,MaNgheNghiep,TenNgheNghiep,Active)
SELECT C.ID,S.ID,S.MaNgheNghiep,S.TenNgheNghiep,1
FROM dbo.DM_CSKCB C
CROSS JOIN S
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.DM_NgheNghiep T
    WHERE T.IDCSKCB=C.ID AND T.ID=S.ID
);
GO

/* Seed existing tenants as already published to avoid a one-time full rebuild.
   Login will mark a tenant dirty if its required JSON is actually missing. */
INSERT dbo.HT_JSON_CSKCB(IDCSKCB,VersionNo,PublishedVersionNo,TrangThai)
SELECT C.ID,1,1,N'SAN_SANG'
FROM dbo.DM_CSKCB C
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.HT_JSON_CSKCB V WHERE V.IDCSKCB=C.ID
);
GO

/* New CSKCB starts dirty. Existing CSKCB updates bump the source version. */
CREATE OR ALTER TRIGGER dbo.TR_DM_CSKCB_JSON_VERSION
ON dbo.DM_CSKCB
AFTER INSERT,UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT dbo.HT_JSON_CSKCB(IDCSKCB,VersionNo,PublishedVersionNo,TrangThai)
    SELECT I.ID,1,0,N'CHO_DONG_BO'
    FROM inserted I
    LEFT JOIN dbo.HT_JSON_CSKCB V ON V.IDCSKCB=I.ID
    WHERE V.IDCSKCB IS NULL;


    /* CSKCB mới phải có ngay bộ lookup canonical để JSON không rỗng. */
    ;WITH S AS
    (
        SELECT *
        FROM (VALUES
            (CAST(1 AS BIGINT),N'VN',N'Việt Nam'),
            (CAST(2 AS BIGINT),N'LA',N'Lào'),
            (CAST(3 AS BIGINT),N'KH',N'Campuchia'),
            (CAST(4 AS BIGINT),N'TH',N'Thái Lan'),
            (CAST(5 AS BIGINT),N'SG',N'Singapore'),
            (CAST(6 AS BIGINT),N'MY',N'Malaysia'),
            (CAST(7 AS BIGINT),N'ID',N'Indonesia'),
            (CAST(8 AS BIGINT),N'PH',N'Philippines'),
            (CAST(9 AS BIGINT),N'CN',N'Trung Quốc'),
            (CAST(10 AS BIGINT),N'KR',N'Hàn Quốc'),
            (CAST(11 AS BIGINT),N'JP',N'Nhật Bản'),
            (CAST(12 AS BIGINT),N'TW',N'Đài Loan'),
            (CAST(13 AS BIGINT),N'US',N'Hoa Kỳ'),
            (CAST(14 AS BIGINT),N'GB',N'Vương Quốc Anh'),
            (CAST(15 AS BIGINT),N'FR',N'Pháp'),
            (CAST(16 AS BIGINT),N'DE',N'Đức'),
            (CAST(17 AS BIGINT),N'RU',N'Nga'),
            (CAST(18 AS BIGINT),N'AU',N'Úc'),
            (CAST(19 AS BIGINT),N'CA',N'Canada'),
            (CAST(99 AS BIGINT),N'XX',N'Quốc tịch khác')
        ) V(ID,MaQuocTich,TenQuocTich)
    )
    INSERT dbo.DM_QuocTich(IDCSKCB,ID,MaQuocTich,TenQuocTich,Active)
    SELECT I.ID,S.ID,S.MaQuocTich,S.TenQuocTich,1
    FROM inserted I
    CROSS JOIN S
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.DM_QuocTich T
        WHERE T.IDCSKCB=I.ID AND T.ID=S.ID
    );

    ;WITH S AS
    (
        SELECT *
        FROM (VALUES
            (CAST(1 AS BIGINT),N'01',N'Cán bộ, công chức, viên chức'),
            (CAST(2 AS BIGINT),N'02',N'Công nhân'),
            (CAST(3 AS BIGINT),N'03',N'Nông dân'),
            (CAST(4 AS BIGINT),N'04',N'Kinh doanh, buôn bán'),
            (CAST(5 AS BIGINT),N'05',N'Nhân viên văn phòng, dịch vụ'),
            (CAST(6 AS BIGINT),N'06',N'Lực lượng vũ trang'),
            (CAST(7 AS BIGINT),N'07',N'Học sinh, sinh viên'),
            (CAST(8 AS BIGINT),N'08',N'Trẻ em dưới 6 tuổi'),
            (CAST(9 AS BIGINT),N'09',N'Hưu trí, người cao tuổi'),
            (CAST(10 AS BIGINT),N'10',N'Nội trợ'),
            (CAST(11 AS BIGINT),N'11',N'Lao động tự do'),
            (CAST(99 AS BIGINT),N'99',N'Khác')
        ) V(ID,MaNgheNghiep,TenNgheNghiep)
    )
    INSERT dbo.DM_NgheNghiep(IDCSKCB,ID,MaNgheNghiep,TenNgheNghiep,Active)
    SELECT I.ID,S.ID,S.MaNgheNghiep,S.TenNgheNghiep,1
    FROM inserted I
    CROSS JOIN S
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.DM_NgheNghiep T
        WHERE T.IDCSKCB=I.ID AND T.ID=S.ID
    );

    ;WITH Changed AS
    (
        SELECT I.ID
        FROM inserted I
        INNER JOIN deleted D ON D.ID=I.ID
    )
    UPDATE V
    SET VersionNo=V.VersionNo+1,
        TrangThai=N'CHO_DONG_BO',
        LastChangedAt=SYSDATETIME(),
        LastError=NULL,
        UpdatedAt=SYSDATETIME()
    FROM dbo.HT_JSON_CSKCB V
    INNER JOIN Changed C ON C.ID=V.IDCSKCB;
END;
GO

/* Tenant-specific source tables. */
CREATE OR ALTER TRIGGER dbo.TR_DM_DanToc_JSON_VERSION
ON dbo.DM_DanToc
AFTER INSERT,UPDATE,DELETE
AS
BEGIN
    SET NOCOUNT ON;
    ;WITH Changed AS
    (
        SELECT IDCSKCB FROM inserted WHERE IDCSKCB IS NOT NULL
        UNION
        SELECT IDCSKCB FROM deleted WHERE IDCSKCB IS NOT NULL
    )
    INSERT dbo.HT_JSON_CSKCB(IDCSKCB,VersionNo,PublishedVersionNo,TrangThai)
    SELECT C.IDCSKCB,1,0,N'CHO_DONG_BO'
    FROM Changed C
    LEFT JOIN dbo.HT_JSON_CSKCB V ON V.IDCSKCB=C.IDCSKCB
    WHERE V.IDCSKCB IS NULL;

    ;WITH Changed AS
    (
        SELECT IDCSKCB FROM inserted WHERE IDCSKCB IS NOT NULL
        UNION
        SELECT IDCSKCB FROM deleted WHERE IDCSKCB IS NOT NULL
    )
    UPDATE V
    SET VersionNo=V.VersionNo+1,TrangThai=N'CHO_DONG_BO',
        LastChangedAt=SYSDATETIME(),LastError=NULL,UpdatedAt=SYSDATETIME()
    FROM dbo.HT_JSON_CSKCB V
    INNER JOIN Changed C ON C.IDCSKCB=V.IDCSKCB;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_DM_TinhThanh_JSON_VERSION
ON dbo.DM_TinhThanh
AFTER INSERT,UPDATE,DELETE
AS
BEGIN
    SET NOCOUNT ON;
    ;WITH Changed AS
    (
        SELECT IDCSKCB FROM inserted WHERE IDCSKCB IS NOT NULL
        UNION SELECT IDCSKCB FROM deleted WHERE IDCSKCB IS NOT NULL
    )
    INSERT dbo.HT_JSON_CSKCB(IDCSKCB,VersionNo,PublishedVersionNo,TrangThai)
    SELECT C.IDCSKCB,1,0,N'CHO_DONG_BO'
    FROM Changed C LEFT JOIN dbo.HT_JSON_CSKCB V ON V.IDCSKCB=C.IDCSKCB
    WHERE V.IDCSKCB IS NULL;

    ;WITH Changed AS
    (
        SELECT IDCSKCB FROM inserted WHERE IDCSKCB IS NOT NULL
        UNION SELECT IDCSKCB FROM deleted WHERE IDCSKCB IS NOT NULL
    )
    UPDATE V SET VersionNo=V.VersionNo+1,TrangThai=N'CHO_DONG_BO',
        LastChangedAt=SYSDATETIME(),LastError=NULL,UpdatedAt=SYSDATETIME()
    FROM dbo.HT_JSON_CSKCB V INNER JOIN Changed C ON C.IDCSKCB=V.IDCSKCB;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_DM_PhuongXa_JSON_VERSION
ON dbo.DM_PhuongXa
AFTER INSERT,UPDATE,DELETE
AS
BEGIN
    SET NOCOUNT ON;
    ;WITH Changed AS
    (
        SELECT IDCSKCB FROM inserted WHERE IDCSKCB IS NOT NULL
        UNION SELECT IDCSKCB FROM deleted WHERE IDCSKCB IS NOT NULL
    )
    INSERT dbo.HT_JSON_CSKCB(IDCSKCB,VersionNo,PublishedVersionNo,TrangThai)
    SELECT C.IDCSKCB,1,0,N'CHO_DONG_BO'
    FROM Changed C LEFT JOIN dbo.HT_JSON_CSKCB V ON V.IDCSKCB=C.IDCSKCB
    WHERE V.IDCSKCB IS NULL;

    ;WITH Changed AS
    (
        SELECT IDCSKCB FROM inserted WHERE IDCSKCB IS NOT NULL
        UNION SELECT IDCSKCB FROM deleted WHERE IDCSKCB IS NOT NULL
    )
    UPDATE V SET VersionNo=V.VersionNo+1,TrangThai=N'CHO_DONG_BO',
        LastChangedAt=SYSDATETIME(),LastError=NULL,UpdatedAt=SYSDATETIME()
    FROM dbo.HT_JSON_CSKCB V INNER JOIN Changed C ON C.IDCSKCB=V.IDCSKCB;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_DM_ICD10_JSON_VERSION
ON dbo.DM_ICD10
AFTER INSERT,UPDATE,DELETE
AS
BEGIN
    SET NOCOUNT ON;
    ;WITH Changed AS
    (
        SELECT IDCSKCB FROM inserted WHERE IDCSKCB IS NOT NULL
        UNION SELECT IDCSKCB FROM deleted WHERE IDCSKCB IS NOT NULL
    )
    INSERT dbo.HT_JSON_CSKCB(IDCSKCB,VersionNo,PublishedVersionNo,TrangThai)
    SELECT C.IDCSKCB,1,0,N'CHO_DONG_BO'
    FROM Changed C LEFT JOIN dbo.HT_JSON_CSKCB V ON V.IDCSKCB=C.IDCSKCB
    WHERE V.IDCSKCB IS NULL;

    ;WITH Changed AS
    (
        SELECT IDCSKCB FROM inserted WHERE IDCSKCB IS NOT NULL
        UNION SELECT IDCSKCB FROM deleted WHERE IDCSKCB IS NOT NULL
    )
    UPDATE V SET VersionNo=V.VersionNo+1,TrangThai=N'CHO_DONG_BO',
        LastChangedAt=SYSDATETIME(),LastError=NULL,UpdatedAt=SYSDATETIME()
    FROM dbo.HT_JSON_CSKCB V INNER JOIN Changed C ON C.IDCSKCB=V.IDCSKCB;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_DM_DichVu_JSON_VERSION
ON dbo.DM_DichVu
AFTER INSERT,UPDATE,DELETE
AS
BEGIN
    SET NOCOUNT ON;
    ;WITH Changed AS
    (
        SELECT IDCSKCB FROM inserted WHERE IDCSKCB IS NOT NULL
        UNION SELECT IDCSKCB FROM deleted WHERE IDCSKCB IS NOT NULL
    )
    INSERT dbo.HT_JSON_CSKCB(IDCSKCB,VersionNo,PublishedVersionNo,TrangThai)
    SELECT C.IDCSKCB,1,0,N'CHO_DONG_BO'
    FROM Changed C LEFT JOIN dbo.HT_JSON_CSKCB V ON V.IDCSKCB=C.IDCSKCB
    WHERE V.IDCSKCB IS NULL;

    ;WITH Changed AS
    (
        SELECT IDCSKCB FROM inserted WHERE IDCSKCB IS NOT NULL
        UNION SELECT IDCSKCB FROM deleted WHERE IDCSKCB IS NOT NULL
    )
    UPDATE V SET VersionNo=V.VersionNo+1,TrangThai=N'CHO_DONG_BO',
        LastChangedAt=SYSDATETIME(),LastError=NULL,UpdatedAt=SYSDATETIME()
    FROM dbo.HT_JSON_CSKCB V INNER JOIN Changed C ON C.IDCSKCB=V.IDCSKCB;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_DM_DonViTinh_JSON_VERSION
ON dbo.DM_DonViTinh
AFTER INSERT,UPDATE,DELETE
AS
BEGIN
    SET NOCOUNT ON;
    ;WITH Changed AS
    (
        SELECT IDCSKCB FROM inserted WHERE IDCSKCB IS NOT NULL
        UNION SELECT IDCSKCB FROM deleted WHERE IDCSKCB IS NOT NULL
    )
    INSERT dbo.HT_JSON_CSKCB(IDCSKCB,VersionNo,PublishedVersionNo,TrangThai)
    SELECT C.IDCSKCB,1,0,N'CHO_DONG_BO'
    FROM Changed C LEFT JOIN dbo.HT_JSON_CSKCB V ON V.IDCSKCB=C.IDCSKCB
    WHERE V.IDCSKCB IS NULL;

    ;WITH Changed AS
    (
        SELECT IDCSKCB FROM inserted WHERE IDCSKCB IS NOT NULL
        UNION SELECT IDCSKCB FROM deleted WHERE IDCSKCB IS NOT NULL
    )
    UPDATE V SET VersionNo=V.VersionNo+1,TrangThai=N'CHO_DONG_BO',
        LastChangedAt=SYSDATETIME(),LastError=NULL,UpdatedAt=SYSDATETIME()
    FROM dbo.HT_JSON_CSKCB V INNER JOIN Changed C ON C.IDCSKCB=V.IDCSKCB;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_DM_Thuoc_JSON_VERSION
ON dbo.DM_Thuoc
AFTER INSERT,UPDATE,DELETE
AS
BEGIN
    SET NOCOUNT ON;
    ;WITH Changed AS
    (
        SELECT IDCSKCB FROM inserted WHERE IDCSKCB IS NOT NULL
        UNION SELECT IDCSKCB FROM deleted WHERE IDCSKCB IS NOT NULL
    )
    INSERT dbo.HT_JSON_CSKCB(IDCSKCB,VersionNo,PublishedVersionNo,TrangThai)
    SELECT C.IDCSKCB,1,0,N'CHO_DONG_BO'
    FROM Changed C LEFT JOIN dbo.HT_JSON_CSKCB V ON V.IDCSKCB=C.IDCSKCB
    WHERE V.IDCSKCB IS NULL;

    ;WITH Changed AS
    (
        SELECT IDCSKCB FROM inserted WHERE IDCSKCB IS NOT NULL
        UNION SELECT IDCSKCB FROM deleted WHERE IDCSKCB IS NOT NULL
    )
    UPDATE V SET VersionNo=V.VersionNo+1,TrangThai=N'CHO_DONG_BO',
        LastChangedAt=SYSDATETIME(),LastError=NULL,UpdatedAt=SYSDATETIME()
    FROM dbo.HT_JSON_CSKCB V INNER JOIN Changed C ON C.IDCSKCB=V.IDCSKCB;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_DM_TriSoSinhHieu_JSON_VERSION
ON dbo.DM_TriSoSinhHieu
AFTER INSERT,UPDATE,DELETE
AS
BEGIN
    SET NOCOUNT ON;
    ;WITH Changed AS
    (
        SELECT IDCSKCB FROM inserted WHERE IDCSKCB IS NOT NULL
        UNION SELECT IDCSKCB FROM deleted WHERE IDCSKCB IS NOT NULL
    )
    INSERT dbo.HT_JSON_CSKCB(IDCSKCB,VersionNo,PublishedVersionNo,TrangThai)
    SELECT C.IDCSKCB,1,0,N'CHO_DONG_BO'
    FROM Changed C LEFT JOIN dbo.HT_JSON_CSKCB V ON V.IDCSKCB=C.IDCSKCB
    WHERE V.IDCSKCB IS NULL;

    ;WITH Changed AS
    (
        SELECT IDCSKCB FROM inserted WHERE IDCSKCB IS NOT NULL
        UNION SELECT IDCSKCB FROM deleted WHERE IDCSKCB IS NOT NULL
    )
    UPDATE V SET VersionNo=V.VersionNo+1,TrangThai=N'CHO_DONG_BO',
        LastChangedAt=SYSDATETIME(),LastError=NULL,UpdatedAt=SYSDATETIME()
    FROM dbo.HT_JSON_CSKCB V INNER JOIN Changed C ON C.IDCSKCB=V.IDCSKCB;
END;
GO

IF COL_LENGTH(N'dbo.DM_NhanVien',N'IDCSKCB') IS NOT NULL
BEGIN
    EXEC(N'
CREATE OR ALTER TRIGGER dbo.TR_DM_NhanVien_JSON_VERSION
ON dbo.DM_NhanVien
AFTER INSERT,UPDATE,DELETE
AS
BEGIN
    SET NOCOUNT ON;
    ;WITH Changed AS
    (
        SELECT IDCSKCB FROM inserted WHERE IDCSKCB IS NOT NULL
        UNION SELECT IDCSKCB FROM deleted WHERE IDCSKCB IS NOT NULL
    )
    INSERT dbo.HT_JSON_CSKCB(IDCSKCB,VersionNo,PublishedVersionNo,TrangThai)
    SELECT C.IDCSKCB,1,0,N''CHO_DONG_BO''
    FROM Changed C LEFT JOIN dbo.HT_JSON_CSKCB V ON V.IDCSKCB=C.IDCSKCB
    WHERE V.IDCSKCB IS NULL;

    ;WITH Changed AS
    (
        SELECT IDCSKCB FROM inserted WHERE IDCSKCB IS NOT NULL
        UNION SELECT IDCSKCB FROM deleted WHERE IDCSKCB IS NOT NULL
    )
    UPDATE V SET VersionNo=V.VersionNo+1,TrangThai=N''CHO_DONG_BO'',
        LastChangedAt=SYSDATETIME(),LastError=NULL,UpdatedAt=SYSDATETIME()
    FROM dbo.HT_JSON_CSKCB V INNER JOIN Changed C ON C.IDCSKCB=V.IDCSKCB;
END;');
END
ELSE
BEGIN
    /* Schema v84+: nhan vien la ho so dung chung. Trigger bang noi se danh dau dung CSKCB;
       trigger nay danh dau cac CSKCB hien dang gan nhan vien khi thong tin ho so thay doi. */
    EXEC(N'
CREATE OR ALTER TRIGGER dbo.TR_DM_NhanVien_JSON_VERSION
ON dbo.DM_NhanVien
AFTER INSERT,UPDATE,DELETE
AS
BEGIN
    SET NOCOUNT ON;
    ;WITH NhanVienDoi AS
    (
        SELECT ID FROM inserted
        UNION
        SELECT ID FROM deleted
    ),
    Changed AS
    (
        SELECT DISTINCT M.IDCSKCB
        FROM dbo.DM_NhanVien_CSKCB M
        INNER JOIN NhanVienDoi N ON N.ID=M.IDNhanVien
    )
    INSERT dbo.HT_JSON_CSKCB(IDCSKCB,VersionNo,PublishedVersionNo,TrangThai)
    SELECT C.IDCSKCB,1,0,N''CHO_DONG_BO''
    FROM Changed C
    LEFT JOIN dbo.HT_JSON_CSKCB V ON V.IDCSKCB=C.IDCSKCB
    WHERE V.IDCSKCB IS NULL;

    ;WITH NhanVienDoi AS
    (
        SELECT ID FROM inserted
        UNION
        SELECT ID FROM deleted
    ),
    Changed AS
    (
        SELECT DISTINCT M.IDCSKCB
        FROM dbo.DM_NhanVien_CSKCB M
        INNER JOIN NhanVienDoi N ON N.ID=M.IDNhanVien
    )
    UPDATE V SET VersionNo=V.VersionNo+1,TrangThai=N''CHO_DONG_BO'',
        LastChangedAt=SYSDATETIME(),LastError=NULL,UpdatedAt=SYSDATETIME()
    FROM dbo.HT_JSON_CSKCB V INNER JOIN Changed C ON C.IDCSKCB=V.IDCSKCB;
END;');
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_DM_PhacDo_JSON_VERSION
ON dbo.DM_PhacDo
AFTER INSERT,UPDATE,DELETE
AS
BEGIN
    SET NOCOUNT ON;
    ;WITH Changed AS
    (
        SELECT IDCSKCB FROM inserted WHERE IDCSKCB IS NOT NULL
        UNION SELECT IDCSKCB FROM deleted WHERE IDCSKCB IS NOT NULL
    )
    INSERT dbo.HT_JSON_CSKCB(IDCSKCB,VersionNo,PublishedVersionNo,TrangThai)
    SELECT C.IDCSKCB,1,0,N'CHO_DONG_BO'
    FROM Changed C LEFT JOIN dbo.HT_JSON_CSKCB V ON V.IDCSKCB=C.IDCSKCB
    WHERE V.IDCSKCB IS NULL;

    ;WITH Changed AS
    (
        SELECT IDCSKCB FROM inserted WHERE IDCSKCB IS NOT NULL
        UNION SELECT IDCSKCB FROM deleted WHERE IDCSKCB IS NOT NULL
    )
    UPDATE V SET VersionNo=V.VersionNo+1,TrangThai=N'CHO_DONG_BO',
        LastChangedAt=SYSDATETIME(),LastError=NULL,UpdatedAt=SYSDATETIME()
    FROM dbo.HT_JSON_CSKCB V INNER JOIN Changed C ON C.IDCSKCB=V.IDCSKCB;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_DM_QuocTich_JSON_VERSION
ON dbo.DM_QuocTich
AFTER INSERT,UPDATE,DELETE
AS
BEGIN
    SET NOCOUNT ON;
    ;WITH Changed AS
    (
        SELECT IDCSKCB FROM inserted WHERE IDCSKCB IS NOT NULL
        UNION SELECT IDCSKCB FROM deleted WHERE IDCSKCB IS NOT NULL
    )
    INSERT dbo.HT_JSON_CSKCB(IDCSKCB,VersionNo,PublishedVersionNo,TrangThai)
    SELECT C.IDCSKCB,1,0,N'CHO_DONG_BO'
    FROM Changed C LEFT JOIN dbo.HT_JSON_CSKCB V ON V.IDCSKCB=C.IDCSKCB
    WHERE V.IDCSKCB IS NULL;

    ;WITH Changed AS
    (
        SELECT IDCSKCB FROM inserted WHERE IDCSKCB IS NOT NULL
        UNION SELECT IDCSKCB FROM deleted WHERE IDCSKCB IS NOT NULL
    )
    UPDATE V SET VersionNo=V.VersionNo+1,TrangThai=N'CHO_DONG_BO',
        LastChangedAt=SYSDATETIME(),LastError=NULL,UpdatedAt=SYSDATETIME()
    FROM dbo.HT_JSON_CSKCB V INNER JOIN Changed C ON C.IDCSKCB=V.IDCSKCB;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_DM_NgheNghiep_JSON_VERSION
ON dbo.DM_NgheNghiep
AFTER INSERT,UPDATE,DELETE
AS
BEGIN
    SET NOCOUNT ON;
    ;WITH Changed AS
    (
        SELECT IDCSKCB FROM inserted WHERE IDCSKCB IS NOT NULL
        UNION SELECT IDCSKCB FROM deleted WHERE IDCSKCB IS NOT NULL
    )
    INSERT dbo.HT_JSON_CSKCB(IDCSKCB,VersionNo,PublishedVersionNo,TrangThai)
    SELECT C.IDCSKCB,1,0,N'CHO_DONG_BO'
    FROM Changed C LEFT JOIN dbo.HT_JSON_CSKCB V ON V.IDCSKCB=C.IDCSKCB
    WHERE V.IDCSKCB IS NULL;

    ;WITH Changed AS
    (
        SELECT IDCSKCB FROM inserted WHERE IDCSKCB IS NOT NULL
        UNION SELECT IDCSKCB FROM deleted WHERE IDCSKCB IS NOT NULL
    )
    UPDATE V SET VersionNo=V.VersionNo+1,TrangThai=N'CHO_DONG_BO',
        LastChangedAt=SYSDATETIME(),LastError=NULL,UpdatedAt=SYSDATETIME()
    FROM dbo.HT_JSON_CSKCB V INNER JOIN Changed C ON C.IDCSKCB=V.IDCSKCB;
END;
GO

/* Danh muc dung chung: mot thay doi lam dirty tat ca tenant. */
CREATE OR ALTER TRIGGER dbo.TR_DM_GioiTinh_JSON_VERSION
ON dbo.DM_GioiTinh
AFTER INSERT,UPDATE,DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS(SELECT 1 FROM inserted) OR EXISTS(SELECT 1 FROM deleted)
        UPDATE dbo.HT_JSON_CSKCB
        SET VersionNo=VersionNo+1,TrangThai=N'CHO_DONG_BO',
            LastChangedAt=SYSDATETIME(),LastError=NULL,UpdatedAt=SYSDATETIME();
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_DM_NganHang_JSON_VERSION
ON dbo.DM_NganHang
AFTER INSERT,UPDATE,DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS(SELECT 1 FROM inserted) OR EXISTS(SELECT 1 FROM deleted)
        UPDATE dbo.HT_JSON_CSKCB
        SET VersionNo=VersionNo+1,TrangThai=N'CHO_DONG_BO',
            LastChangedAt=SYSDATETIME(),LastError=NULL,UpdatedAt=SYSDATETIME();
END;
GO


/* Runtime JSON 2017: mọi truy vấn/cập nhật DB từ service và worker đi qua STO.
   Ứng dụng không được gửi câu SELECT/UPDATE trực tiếp. */
CREATE OR ALTER PROCEDURE dbo.STO_HT_JSON_DamBaoDong
    @IDCSKCB BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    IF @IDCSKCB<=0 RETURN;
    IF NOT EXISTS(SELECT 1 FROM dbo.HT_JSON_CSKCB WITH(UPDLOCK,HOLDLOCK) WHERE IDCSKCB=@IDCSKCB)
        INSERT dbo.HT_JSON_CSKCB(IDCSKCB,VersionNo,PublishedVersionNo,TrangThai)
        VALUES(@IDCSKCB,1,0,N'CHO_DONG_BO');
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_JSON_DanhDauThieuFile
    @IDCSKCB BIGINT,
    @TatCa BIT=0
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE V
    SET TrangThai=N'CHO_DONG_BO',LastError=NULL,UpdatedAt=SYSDATETIME()
    FROM dbo.HT_JSON_CSKCB V
    WHERE (@TatCa=1 AND EXISTS (SELECT 1 FROM dbo.DM_CSKCB C WHERE C.ID=V.IDCSKCB AND C.Active=1))
       OR (@TatCa=0 AND V.IDCSKCB=@IDCSKCB);
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_JSON_TangVersion
    @IDCSKCB BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.HT_JSON_CSKCB
    SET VersionNo=VersionNo+1,TrangThai=N'CHO_DONG_BO',LastError=NULL,
        LastChangedAt=SYSDATETIME(),UpdatedAt=SYSDATETIME()
    WHERE IDCSKCB=@IDCSKCB;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_JSON_DanhSachCanDongBo
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IDCSKCB
    FROM dbo.HT_JSON_CSKCB
    WHERE VersionNo>PublishedVersionNo
       OR TrangThai IN(N'CHO_DONG_BO',N'LOI')
    ORDER BY IDCSKCB;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_JSON_TrangThai
    @IDCSKCB BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IDCSKCB,VersionNo,PublishedVersionNo,TrangThai,
           LastChangedAt,LastGeneratedAt,LastError,UpdatedAt
    FROM dbo.HT_JSON_CSKCB
    WHERE IDCSKCB=@IDCSKCB;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_JSON_LayVersion
    @IDCSKCB BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT VersionNo
    FROM dbo.HT_JSON_CSKCB
    WHERE IDCSKCB=@IDCSKCB;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_JSON_CapNhatTrangThai
    @IDCSKCB BIGINT,
    @TrangThai NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.HT_JSON_CSKCB
    SET TrangThai=@TrangThai,LastError=NULL,UpdatedAt=SYSDATETIME()
    WHERE IDCSKCB=@IDCSKCB;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_JSON_CapNhatLoi
    @IDCSKCB BIGINT,
    @Loi NVARCHAR(2000)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.HT_JSON_CSKCB
    SET TrangThai=N'LOI',LastError=@Loi,UpdatedAt=SYSDATETIME()
    WHERE IDCSKCB=@IDCSKCB;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_JSON_PhatHanh
    @IDCSKCB BIGINT,
    @VersionNo BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.HT_JSON_CSKCB
    SET PublishedVersionNo=@VersionNo,TrangThai=N'SAN_SANG',
        LastGeneratedAt=SYSDATETIME(),LastError=NULL,UpdatedAt=SYSDATETIME()
    WHERE IDCSKCB=@IDCSKCB AND VersionNo=@VersionNo;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_JSON_DanhDauDirty
    @IDCSKCB BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.HT_JSON_CSKCB
    SET TrangThai=N'CHO_DONG_BO',LastError=NULL,UpdatedAt=SYSDATETIME()
    WHERE IDCSKCB=@IDCSKCB;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_JSON_DanhMucDonGian
    @IDCSKCB BIGINT,
    @Loai NVARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    IF @Loai=N'quoc_tich'
        SELECT ID,MaQuocTich AS Ma,TenQuocTich AS Ten
        FROM dbo.DM_QuocTich
        WHERE IDCSKCB=@IDCSKCB AND Active=1
        ORDER BY ID;
    ELSE IF @Loai=N'nghe_nghiep'
        SELECT ID,MaNgheNghiep AS Ma,TenNgheNghiep AS Ten
        FROM dbo.DM_NgheNghiep
        WHERE IDCSKCB=@IDCSKCB AND Active=1
        ORDER BY ID;
    ELSE
        THROW 59010,N'Loại danh mục JSON không hợp lệ.',1;
END;
GO

/* Lock được giữ trên cùng SqlConnection suốt phiên đồng bộ. */
CREATE OR ALTER PROCEDURE dbo.STO_HT_JSON_ThuLock
    @IDCSKCB BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Result INT;
    DECLARE @LockName NVARCHAR(255)=CONCAT(N'QLPM_JSON_CSKCB_',@IDCSKCB);
    EXEC @Result=sys.sp_getapplock
         @Resource=@LockName,
         @LockMode='Exclusive',@LockOwner='Session',@LockTimeout=5000;
    SELECT @Result AS KetQua;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_JSON_NhaLock
    @IDCSKCB BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LockName NVARCHAR(255)=CONCAT(N'QLPM_JSON_CSKCB_',@IDCSKCB);
    EXEC sys.sp_releaseapplock
         @Resource=@LockName,
         @LockOwner='Session';
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_JSON_LayThoiGian
AS
BEGIN
    SET NOCOUNT ON;
    SELECT SYSDATETIME() AS ThoiGian;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_JSON_LayLich
AS
BEGIN
    SET NOCOUNT ON;
    SELECT NgayChayCuoi,LanChayCuoi,TrangThai
    FROM dbo.HT_JSON_DongBo_Lich
    WHERE ID=1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_JSON_BatDauLich
    @LanChayCuoi DATETIME2(0)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.HT_JSON_DongBo_Lich
    SET TrangThai=N'DANG_CHAY',LanChayCuoi=@LanChayCuoi,
        LastError=NULL,UpdatedAt=SYSDATETIME()
    WHERE ID=1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_JSON_KetThucLich
    @NgayChayCuoi DATE,
    @LanChayCuoi DATETIME2(0),
    @TrangThai NVARCHAR(20),
    @LastError NVARCHAR(2000)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.HT_JSON_DongBo_Lich
    SET NgayChayCuoi=@NgayChayCuoi,LanChayCuoi=@LanChayCuoi,
        TrangThai=@TrangThai,LastError=@LastError,
        UpdatedAt=SYSDATETIME()
    WHERE ID=1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_JSON_ThuLockDem
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Result INT;
    EXEC @Result=sys.sp_getapplock
         @Resource=N'QLPM_JSON_DANH_MUC_00H',
         @LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0;
    SELECT @Result AS KetQua;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_JSON_NhaLockDem
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sys.sp_releaseapplock
         @Resource=N'QLPM_JSON_DANH_MUC_00H',
         @LockOwner='Session';
END;
GO

PRINT N'24_json_danh_muc_phien_ban.sql: OK';
GO
