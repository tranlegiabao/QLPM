:ON ERROR EXIT
USE [QLPM];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF DB_NAME()<>N'QLPM'
    THROW 59101,N'v104 chi duoc phep chay tren database QLPM.',1;
GO

IF OBJECT_ID(N'dbo.QLPM_SchemaVersion',N'U') IS NULL
 OR NOT EXISTS(SELECT 1 FROM dbo.QLPM_SchemaVersion WHERE VersionNo=103)
    THROW 59100,N'v104 yeu cau target da co warehouse schema v103. Khong duoc bo qua migration 101-103.',1;
GO

IF COL_LENGTH(N'dbo.DM_Thuoc',N'MaThuocQuocGia') IS NULL
    ALTER TABLE dbo.DM_Thuoc ADD MaThuocQuocGia NVARCHAR(20) NULL;
GO

IF COL_LENGTH(N'dbo.QL_VaoVien',N'PhienBanLamSang') IS NULL
    ALTER TABLE dbo.QL_VaoVien ADD PhienBanLamSang BIGINT NOT NULL
        CONSTRAINT DF_QL_VaoVien_PhienBanLamSang DEFAULT(0);
GO

IF OBJECT_ID(N'dbo.QL_ToaThuoc',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.QL_ToaThuoc
    (
        ID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_QL_ToaThuoc PRIMARY KEY,
        IDCSKCB BIGINT NOT NULL,
        IDVaoVien BIGINT NOT NULL,
        NgayKe DATE NOT NULL,
        MaLoaiToaThuoc NVARCHAR(1) NOT NULL,
        IDBacSiKe BIGINT NOT NULL,
        SoThuTuLienThong INT NULL,
        MaToaQuocGia NVARCHAR(14) NULL,
        TrangThai NVARCHAR(30) NOT NULL CONSTRAINT DF_QL_ToaThuoc_TrangThai DEFAULT(N'NHAP'),
        PhienBanNguon BIGINT NOT NULL CONSTRAINT DF_QL_ToaThuoc_PhienBanNguon DEFAULT(0),
        IDPhienBanHienTai BIGINT NULL,
        NgayTao DATETIME2(0) NOT NULL CONSTRAINT DF_QL_ToaThuoc_NgayTao DEFAULT(SYSDATETIME()),
        NgayCapNhat DATETIME2(0) NULL,
        CONSTRAINT CK_QL_ToaThuoc_Loai CHECK(MaLoaiToaThuoc IN(N'c',N'n',N'h')),
        CONSTRAINT CK_QL_ToaThuoc_TrangThai CHECK(TrangThai IN
            (N'NHAP',N'DA_KY',N'CHO_GUI',N'DANG_GUI',N'THANH_CONG',N'TU_CHOI',N'LOI_GUI',N'KHONG_RO_KET_QUA')),
        CONSTRAINT CK_QL_ToaThuoc_MaQuocGia CHECK(MaToaQuocGia IS NULL OR LEN(MaToaQuocGia)=14),
        CONSTRAINT UQ_QL_ToaThuoc_CSKCB_ID UNIQUE(IDCSKCB,ID),
        CONSTRAINT UQ_QL_ToaThuoc_Nhom UNIQUE(IDCSKCB,IDVaoVien,NgayKe,MaLoaiToaThuoc,IDBacSiKe),
        CONSTRAINT FK_QL_ToaThuoc_CSKCB FOREIGN KEY(IDCSKCB) REFERENCES dbo.DM_CSKCB(ID),
        CONSTRAINT FK_QL_ToaThuoc_VaoVien FOREIGN KEY(IDCSKCB,IDVaoVien) REFERENCES dbo.QL_VaoVien(IDCSKCB,ID),
        CONSTRAINT FK_QL_ToaThuoc_BacSi FOREIGN KEY(IDBacSiKe) REFERENCES dbo.DM_NhanVien(ID)
    );
    CREATE UNIQUE INDEX UQ_QL_ToaThuoc_MaQuocGia ON dbo.QL_ToaThuoc(MaToaQuocGia) WHERE MaToaQuocGia IS NOT NULL;
    CREATE INDEX IX_QL_ToaThuoc_DanhSach ON dbo.QL_ToaThuoc(IDCSKCB,NgayKe DESC,TrangThai);
END;
GO

IF OBJECT_ID(N'dbo.QL_ToaThuoc_So',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.QL_ToaThuoc_So
    (
        IDCSKCB BIGINT NOT NULL CONSTRAINT PK_QL_ToaThuoc_So PRIMARY KEY,
        GiaTri INT NOT NULL CONSTRAINT DF_QL_ToaThuoc_So_GiaTri DEFAULT(0),
        CONSTRAINT CK_QL_ToaThuoc_So_GiaTri CHECK(GiaTri BETWEEN 0 AND 9999999),
        CONSTRAINT FK_QL_ToaThuoc_So_CSKCB FOREIGN KEY(IDCSKCB) REFERENCES dbo.DM_CSKCB(ID)
    );
END;
GO

IF COL_LENGTH(N'dbo.QL_ToaThuoc_CT',N'IDToaThuoc') IS NULL
    ALTER TABLE dbo.QL_ToaThuoc_CT ADD IDToaThuoc BIGINT NULL;
GO

IF OBJECT_ID(N'dbo.QL_ToaThuoc_PhienBan',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.QL_ToaThuoc_PhienBan
    (
        ID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_QL_ToaThuoc_PhienBan PRIMARY KEY,
        IDCSKCB BIGINT NOT NULL,
        IDToaThuoc BIGINT NOT NULL,
        SoPhienBan INT NOT NULL,
        PhienBanNguon BIGINT NOT NULL,
        TrangThai NVARCHAR(30) NOT NULL CONSTRAINT DF_QL_ToaThuoc_PB_TrangThai DEFAULT(N'DA_KY'),
        JsonChuaKy NVARCHAR(MAX) NOT NULL,
        Sha256Json CHAR(64) NOT NULL,
        ChuKyDuLieu NVARCHAR(MAX) NOT NULL,
        JsonDaKy NVARCHAR(MAX) NOT NULL,
        PdfDaKy VARBINARY(MAX) NOT NULL,
        Sha256Pdf CHAR(64) NOT NULL,
        NhaCungCapKy NVARCHAR(100) NULL,
        SerialChungThu NVARCHAR(200) NULL,
        IDBacSiKy BIGINT NOT NULL,
        IDTaiKhoanKy BIGINT NOT NULL,
        NgayGioKy DATETIME2(0) NOT NULL CONSTRAINT DF_QL_ToaThuoc_PB_NgayGioKy DEFAULT(SYSDATETIME()),
        NgayTao DATETIME2(0) NOT NULL CONSTRAINT DF_QL_ToaThuoc_PB_NgayTao DEFAULT(SYSDATETIME()),
        CONSTRAINT CK_QL_ToaThuoc_PB_TrangThai CHECK(TrangThai IN(N'DA_KY',N'CHO_GUI',N'DANG_GUI',N'THANH_CONG',N'TU_CHOI',N'LOI_GUI',N'KHONG_RO_KET_QUA',N'HET_HIEU_LUC')),
        CONSTRAINT UQ_QL_ToaThuoc_PB UNIQUE(IDCSKCB,IDToaThuoc,SoPhienBan),
        CONSTRAINT UQ_QL_ToaThuoc_PB_CSKCB_ID UNIQUE(IDCSKCB,ID),
        CONSTRAINT FK_QL_ToaThuoc_PB_Toa FOREIGN KEY(IDCSKCB,IDToaThuoc) REFERENCES dbo.QL_ToaThuoc(IDCSKCB,ID),
        CONSTRAINT FK_QL_ToaThuoc_PB_BacSi FOREIGN KEY(IDBacSiKy) REFERENCES dbo.DM_NhanVien(ID),
        CONSTRAINT FK_QL_ToaThuoc_PB_TaiKhoan FOREIGN KEY(IDTaiKhoanKy) REFERENCES dbo.HT_Tai_Khoan(ID)
    );
END;
GO

IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name=N'FK_QL_ToaThuoc_PhienBanHienTai')
    ALTER TABLE dbo.QL_ToaThuoc ADD CONSTRAINT FK_QL_ToaThuoc_PhienBanHienTai
        FOREIGN KEY(IDCSKCB,IDPhienBanHienTai) REFERENCES dbo.QL_ToaThuoc_PhienBan(IDCSKCB,ID);
GO

IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name=N'FK_QL_ToaThuocCT_ToaThuoc')
    ALTER TABLE dbo.QL_ToaThuoc_CT ADD CONSTRAINT FK_QL_ToaThuocCT_ToaThuoc
        FOREIGN KEY(IDCSKCB,IDToaThuoc) REFERENCES dbo.QL_ToaThuoc(IDCSKCB,ID);
GO

IF OBJECT_ID(N'dbo.QL_ToaThuoc_LanGui',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.QL_ToaThuoc_LanGui
    (
        ID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_QL_ToaThuoc_LanGui PRIMARY KEY,
        IDCSKCB BIGINT NOT NULL,
        IDToaThuocPhienBan BIGINT NOT NULL,
        IdempotencyKey UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_QL_ToaThuoc_LG_Key DEFAULT(NEWID()),
        SoLan INT NOT NULL,
        TrangThai NVARCHAR(30) NOT NULL CONSTRAINT DF_QL_ToaThuoc_LG_TrangThai DEFAULT(N'CHO_GUI'),
        HttpStatus INT NULL,
        MaKetQua NVARCHAR(100) NULL,
        PhanHoiDaLoc NVARCHAR(4000) NULL,
        LoiCuoi NVARCHAR(2000) NULL,
        IDBacSiYeuCau BIGINT NOT NULL,
        IDTaiKhoanYeuCau BIGINT NOT NULL,
        NgayTao DATETIME2(0) NOT NULL CONSTRAINT DF_QL_ToaThuoc_LG_NgayTao DEFAULT(SYSDATETIME()),
        BatDauLuc DATETIME2(0) NULL,
        KetThucLuc DATETIME2(0) NULL,
        CONSTRAINT UQ_QL_ToaThuoc_LG_Key UNIQUE(IdempotencyKey),
        CONSTRAINT UQ_QL_ToaThuoc_LG_Lan UNIQUE(IDCSKCB,IDToaThuocPhienBan,SoLan),
        CONSTRAINT CK_QL_ToaThuoc_LG_TrangThai CHECK(TrangThai IN(N'CHO_GUI',N'DANG_GUI',N'THANH_CONG',N'TU_CHOI',N'LOI_GUI',N'KHONG_RO_KET_QUA')),
        CONSTRAINT FK_QL_ToaThuoc_LG_PB FOREIGN KEY(IDCSKCB,IDToaThuocPhienBan) REFERENCES dbo.QL_ToaThuoc_PhienBan(IDCSKCB,ID),
        CONSTRAINT FK_QL_ToaThuoc_LG_BacSi FOREIGN KEY(IDBacSiYeuCau) REFERENCES dbo.DM_NhanVien(ID),
        CONSTRAINT FK_QL_ToaThuoc_LG_TaiKhoan FOREIGN KEY(IDTaiKhoanYeuCau) REFERENCES dbo.HT_Tai_Khoan(ID)
    );
    CREATE INDEX IX_QL_ToaThuoc_LG_HangDoi ON dbo.QL_ToaThuoc_LanGui(TrangThai,NgayTao,ID);
END;
GO

IF OBJECT_ID(N'dbo.QL_ToaThuoc_Audit',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.QL_ToaThuoc_Audit
    (
        ID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_QL_ToaThuoc_Audit PRIMARY KEY,
        IDCSKCB BIGINT NOT NULL,
        IDToaThuoc BIGINT NULL,
        IDToaThuocPhienBan BIGINT NULL,
        HanhDong NVARCHAR(50) NOT NULL,
        TrangThaiTu NVARCHAR(30) NULL,
        TrangThaiDen NVARCHAR(30) NULL,
        LyDo NVARCHAR(1000) NULL,
        IDNhanVien BIGINT NULL,
        IDTaiKhoan BIGINT NOT NULL,
        NgayTao DATETIME2(0) NOT NULL CONSTRAINT DF_QL_ToaThuoc_Audit_NgayTao DEFAULT(SYSDATETIME()),
        CONSTRAINT FK_QL_ToaThuoc_Audit_CSKCB FOREIGN KEY(IDCSKCB) REFERENCES dbo.DM_CSKCB(ID),
        CONSTRAINT FK_QL_ToaThuoc_Audit_Toa FOREIGN KEY(IDCSKCB,IDToaThuoc) REFERENCES dbo.QL_ToaThuoc(IDCSKCB,ID),
        CONSTRAINT FK_QL_ToaThuoc_Audit_PB FOREIGN KEY(IDCSKCB,IDToaThuocPhienBan) REFERENCES dbo.QL_ToaThuoc_PhienBan(IDCSKCB,ID),
        CONSTRAINT FK_QL_ToaThuoc_Audit_NV FOREIGN KEY(IDNhanVien) REFERENCES dbo.DM_NhanVien(ID),
        CONSTRAINT FK_QL_ToaThuoc_Audit_TK FOREIGN KEY(IDTaiKhoan) REFERENCES dbo.HT_Tai_Khoan(ID)
    );
    CREATE INDEX IX_QL_ToaThuoc_Audit_Toa ON dbo.QL_ToaThuoc_Audit(IDCSKCB,IDToaThuoc,NgayTao DESC);
END;
GO

IF OBJECT_ID(N'dbo.HT_LienThongToaThuoc_CauHinh',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.HT_LienThongToaThuoc_CauHinh
    (
        IDCSKCB BIGINT NOT NULL CONSTRAINT PK_HT_LTTT_CauHinh PRIMARY KEY,
        MoiTruong NVARCHAR(10) NOT NULL CONSTRAINT DF_HT_LTTT_MoiTruong DEFAULT(N'TEST'),
        ApiBaseUrlProduction NVARCHAR(500) NOT NULL CONSTRAINT DF_HT_LTTT_ApiProd DEFAULT(N'https://api.donthuocquocgia.vn'),
        ApiBaseUrlTest NVARCHAR(500) NULL,
        UrlKyDuLieu NVARCHAR(500) NULL,
        UrlKyPdf NVARCHAR(500) NULL,
        MaLienThongCskcb NVARCHAR(100) NULL,
        MatKhauCskcbMaHoa NVARCHAR(MAX) NULL,
        HieuLuc BIT NOT NULL CONSTRAINT DF_HT_LTTT_HieuLuc DEFAULT(0),
        NgayCapNhat DATETIME2(0) NOT NULL CONSTRAINT DF_HT_LTTT_NgayCapNhat DEFAULT(SYSDATETIME()),
        IDTaiKhoanCapNhat BIGINT NULL,
        CONSTRAINT CK_HT_LTTT_MoiTruong CHECK(MoiTruong IN(N'TEST',N'PRODUCTION')),
        CONSTRAINT FK_HT_LTTT_CauHinh_CSKCB FOREIGN KEY(IDCSKCB) REFERENCES dbo.DM_CSKCB(ID),
        CONSTRAINT FK_HT_LTTT_CauHinh_TK FOREIGN KEY(IDTaiKhoanCapNhat) REFERENCES dbo.HT_Tai_Khoan(ID)
    );
END;
GO

INSERT dbo.HT_LienThongToaThuoc_CauHinh(IDCSKCB,MoiTruong,ApiBaseUrlProduction,ApiBaseUrlTest,HieuLuc)
SELECT C.ID,N'TEST',N'https://api.donthuocquocgia.vn',NULL,0
FROM dbo.DM_CSKCB C
WHERE NOT EXISTS(SELECT 1 FROM dbo.HT_LienThongToaThuoc_CauHinh H WHERE H.IDCSKCB=C.ID);
GO

IF OBJECT_ID(N'dbo.HT_LienThongToaThuoc_BacSi',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.HT_LienThongToaThuoc_BacSi
    (
        IDCSKCB BIGINT NOT NULL,
        IDNhanVien BIGINT NOT NULL,
        MaLienThong NVARCHAR(100) NULL,
        SoChungChiHanhNghe NVARCHAR(100) NULL,
        MatKhauMaHoa NVARCHAR(MAX) NULL,
        DaDangKy BIT NOT NULL CONSTRAINT DF_HT_LTTT_BS_DaDangKy DEFAULT(0),
        Active BIT NOT NULL CONSTRAINT DF_HT_LTTT_BS_Active DEFAULT(0),
        NgayCapNhat DATETIME2(0) NOT NULL CONSTRAINT DF_HT_LTTT_BS_NgayCapNhat DEFAULT(SYSDATETIME()),
        IDTaiKhoanCapNhat BIGINT NULL,
        CONSTRAINT PK_HT_LTTT_BacSi PRIMARY KEY(IDCSKCB,IDNhanVien),
        CONSTRAINT FK_HT_LTTT_BS_Map FOREIGN KEY(IDNhanVien,IDCSKCB) REFERENCES dbo.DM_NhanVien_CSKCB(IDNhanVien,IDCSKCB),
        CONSTRAINT FK_HT_LTTT_BS_TK FOREIGN KEY(IDTaiKhoanCapNhat) REFERENCES dbo.HT_Tai_Khoan(ID)
    );
END;
GO

/* Backfill one header per current print grouping without changing legacy line values. */
INSERT dbo.QL_ToaThuoc(IDCSKCB,IDVaoVien,NgayKe,MaLoaiToaThuoc,IDBacSiKe,PhienBanNguon)
SELECT D.IDCSKCB,D.IDVaoVien,CONVERT(DATE,D.NgayKe),D.MaLoaiToaThuoc,D.IDBacSiKe,MAX(V.PhienBanLamSang)
FROM dbo.QL_ToaThuoc_CT D
JOIN dbo.QL_VaoVien V ON V.IDCSKCB=D.IDCSKCB AND V.ID=D.IDVaoVien
WHERE D.Active=1 AND D.IDBacSiKe IS NOT NULL AND D.MaLoaiToaThuoc IN(N'c',N'n',N'h')
  AND NOT EXISTS
  (
      SELECT 1 FROM dbo.QL_ToaThuoc H
      WHERE H.IDCSKCB=D.IDCSKCB AND H.IDVaoVien=D.IDVaoVien
        AND H.NgayKe=CONVERT(DATE,D.NgayKe) AND H.MaLoaiToaThuoc=D.MaLoaiToaThuoc
        AND H.IDBacSiKe=D.IDBacSiKe
  )
GROUP BY D.IDCSKCB,D.IDVaoVien,CONVERT(DATE,D.NgayKe),D.MaLoaiToaThuoc,D.IDBacSiKe;
GO

UPDATE D
SET IDToaThuoc=H.ID
FROM dbo.QL_ToaThuoc_CT D
JOIN dbo.QL_ToaThuoc H
  ON H.IDCSKCB=D.IDCSKCB AND H.IDVaoVien=D.IDVaoVien
 AND H.NgayKe=CONVERT(DATE,D.NgayKe) AND H.MaLoaiToaThuoc=D.MaLoaiToaThuoc
 AND H.IDBacSiKe=D.IDBacSiKe
WHERE D.IDToaThuoc IS NULL AND D.MaLoaiToaThuoc IN(N'c',N'n',N'h');
GO

/* Allocate stable 7 digit counters only for facilities with a valid 5 character code. */
DECLARE @IDCSKCB BIGINT,@IDToa BIGINT,@Loai NVARCHAR(1),@MaCSKCB NVARCHAR(20),@So INT;
DECLARE c CURSOR LOCAL FAST_FORWARD FOR
    SELECT H.IDCSKCB,H.ID,H.MaLoaiToaThuoc,C.MaCSKCB
    FROM dbo.QL_ToaThuoc H JOIN dbo.DM_CSKCB C ON C.ID=H.IDCSKCB
    WHERE H.MaToaQuocGia IS NULL AND LEN(LTRIM(RTRIM(C.MaCSKCB)))=5
    ORDER BY H.IDCSKCB,H.ID;
OPEN c;
FETCH NEXT FROM c INTO @IDCSKCB,@IDToa,@Loai,@MaCSKCB;
WHILE @@FETCH_STATUS=0
BEGIN
    IF NOT EXISTS(SELECT 1 FROM dbo.QL_ToaThuoc_So WHERE IDCSKCB=@IDCSKCB)
        INSERT dbo.QL_ToaThuoc_So(IDCSKCB,GiaTri) VALUES(@IDCSKCB,0);
    UPDATE dbo.QL_ToaThuoc_So WITH(UPDLOCK,HOLDLOCK) SET @So=GiaTri=GiaTri+1 WHERE IDCSKCB=@IDCSKCB AND GiaTri<9999999;
    IF @So IS NULL THROW 59102,N'Da het day so toa thuoc 7 chu so.',1;
    UPDATE dbo.QL_ToaThuoc
    SET SoThuTuLienThong=@So,
        MaToaQuocGia=LTRIM(RTRIM(@MaCSKCB))+RIGHT(N'0000000'+CONVERT(NVARCHAR(7),@So),7)+N'-'+@Loai
    WHERE ID=@IDToa AND IDCSKCB=@IDCSKCB;
    SET @So=NULL;
    FETCH NEXT FROM c INTO @IDCSKCB,@IDToa,@Loai,@MaCSKCB;
END;
CLOSE c;
DEALLOCATE c;
GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_ToaThuoc_DongBoDauToa
    @IDCSKCB BIGINT,
    @IDVaoVien BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @OwnTran BIT=0;
    IF @@TRANCOUNT=0 BEGIN SET @OwnTran=1; BEGIN TRANSACTION; END;
    BEGIN TRY
        DECLARE @MaCSKCB NVARCHAR(20)=(SELECT LTRIM(RTRIM(MaCSKCB)) FROM dbo.DM_CSKCB WITH(UPDLOCK,HOLDLOCK) WHERE ID=@IDCSKCB);
        IF @MaCSKCB IS NULL THROW 59103,N'Khong tim thay CSKCB.',1;

        INSERT dbo.QL_ToaThuoc(IDCSKCB,IDVaoVien,NgayKe,MaLoaiToaThuoc,IDBacSiKe,PhienBanNguon)
        SELECT D.IDCSKCB,D.IDVaoVien,CONVERT(DATE,D.NgayKe),D.MaLoaiToaThuoc,D.IDBacSiKe,V.PhienBanLamSang
        FROM dbo.QL_ToaThuoc_CT D
        JOIN dbo.QL_VaoVien V ON V.IDCSKCB=D.IDCSKCB AND V.ID=D.IDVaoVien
        WHERE D.IDCSKCB=@IDCSKCB AND D.IDVaoVien=@IDVaoVien AND D.Active=1 AND D.IDBacSiKe IS NOT NULL
          AND D.MaLoaiToaThuoc IN(N'c',N'n',N'h')
          AND NOT EXISTS
          (
              SELECT 1 FROM dbo.QL_ToaThuoc H WITH(UPDLOCK,HOLDLOCK)
              WHERE H.IDCSKCB=D.IDCSKCB AND H.IDVaoVien=D.IDVaoVien
                AND H.NgayKe=CONVERT(DATE,D.NgayKe) AND H.MaLoaiToaThuoc=D.MaLoaiToaThuoc
                AND H.IDBacSiKe=D.IDBacSiKe
          )
        GROUP BY D.IDCSKCB,D.IDVaoVien,CONVERT(DATE,D.NgayKe),D.MaLoaiToaThuoc,D.IDBacSiKe,V.PhienBanLamSang;

        IF LEN(@MaCSKCB)=5
        BEGIN
            IF NOT EXISTS(SELECT 1 FROM dbo.QL_ToaThuoc_So WITH(UPDLOCK,HOLDLOCK) WHERE IDCSKCB=@IDCSKCB)
                INSERT dbo.QL_ToaThuoc_So(IDCSKCB,GiaTri) VALUES(@IDCSKCB,0);
            DECLARE @HeaderID BIGINT,@Type NVARCHAR(1),@Next INT;
            DECLARE h CURSOR LOCAL FAST_FORWARD FOR
                SELECT ID,MaLoaiToaThuoc FROM dbo.QL_ToaThuoc
                WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND MaToaQuocGia IS NULL ORDER BY ID;
            OPEN h; FETCH NEXT FROM h INTO @HeaderID,@Type;
            WHILE @@FETCH_STATUS=0
            BEGIN
                SET @Next=NULL;
                UPDATE dbo.QL_ToaThuoc_So WITH(UPDLOCK,HOLDLOCK) SET @Next=GiaTri=GiaTri+1 WHERE IDCSKCB=@IDCSKCB AND GiaTri<9999999;
                IF @Next IS NULL THROW 59102,N'Da het day so toa thuoc 7 chu so.',1;
                UPDATE dbo.QL_ToaThuoc SET SoThuTuLienThong=@Next,
                    MaToaQuocGia=@MaCSKCB+RIGHT(N'0000000'+CONVERT(NVARCHAR(7),@Next),7)+N'-'+@Type
                WHERE ID=@HeaderID AND IDCSKCB=@IDCSKCB;
                FETCH NEXT FROM h INTO @HeaderID,@Type;
            END;
            CLOSE h; DEALLOCATE h;
        END;

        UPDATE D SET IDToaThuoc=H.ID
        FROM dbo.QL_ToaThuoc_CT D
        JOIN dbo.QL_ToaThuoc H
          ON H.IDCSKCB=D.IDCSKCB AND H.IDVaoVien=D.IDVaoVien
         AND H.NgayKe=CONVERT(DATE,D.NgayKe) AND H.MaLoaiToaThuoc=D.MaLoaiToaThuoc
         AND H.IDBacSiKe=D.IDBacSiKe
        WHERE D.IDCSKCB=@IDCSKCB AND D.IDVaoVien=@IDVaoVien
          AND D.MaLoaiToaThuoc IN(N'c',N'n',N'h')
          AND (D.IDToaThuoc IS NULL OR D.IDToaThuoc<>H.ID);

        IF @OwnTran=1 COMMIT;
    END TRY
    BEGIN CATCH
        IF @OwnTran=1 AND @@TRANCOUNT>0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_QL_ToaThuoc_CT_LienThong
ON dbo.QL_ToaThuoc_CT
AFTER INSERT,UPDATE,DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRIGGER_NESTLEVEL()>1 RETURN;
    DECLARE @Visits TABLE(IDCSKCB BIGINT,IDVaoVien BIGINT,PRIMARY KEY(IDCSKCB,IDVaoVien));
    INSERT @Visits SELECT DISTINCT IDCSKCB,IDVaoVien FROM inserted
    UNION SELECT DISTINCT IDCSKCB,IDVaoVien FROM deleted;

    IF EXISTS
    (
        SELECT 1 FROM @Visits V JOIN dbo.QL_ToaThuoc H WITH(UPDLOCK,HOLDLOCK)
          ON H.IDCSKCB=V.IDCSKCB AND H.IDVaoVien=V.IDVaoVien
        WHERE H.TrangThai IN(N'CHO_GUI',N'DANG_GUI',N'THANH_CONG',N'KHONG_RO_KET_QUA')
    ) THROW 59110,N'Toa thuoc dang gui, khong ro ket qua hoac da lien thong thanh cong; khong duoc sua thuoc.',1;

    UPDATE V SET PhienBanLamSang=PhienBanLamSang+1,NgayCapNhatKham=SYSDATETIME()
    FROM dbo.QL_VaoVien V JOIN @Visits X ON X.IDCSKCB=V.IDCSKCB AND X.IDVaoVien=V.ID;

    UPDATE P SET TrangThai=N'HET_HIEU_LUC'
    FROM dbo.QL_ToaThuoc_PhienBan P
    JOIN dbo.QL_ToaThuoc H ON H.IDCSKCB=P.IDCSKCB AND H.ID=P.IDToaThuoc
    JOIN @Visits V ON V.IDCSKCB=H.IDCSKCB AND V.IDVaoVien=H.IDVaoVien
    WHERE P.TrangThai<>N'HET_HIEU_LUC';
    UPDATE H SET TrangThai=N'NHAP',IDPhienBanHienTai=NULL,NgayCapNhat=SYSDATETIME()
    FROM dbo.QL_ToaThuoc H JOIN @Visits V ON V.IDCSKCB=H.IDCSKCB AND V.IDVaoVien=H.IDVaoVien
    WHERE H.TrangThai IN(N'DA_KY',N'TU_CHOI',N'LOI_GUI');

    DECLARE @C BIGINT,@V BIGINT;
    DECLARE v CURSOR LOCAL FAST_FORWARD FOR SELECT IDCSKCB,IDVaoVien FROM @Visits;
    OPEN v; FETCH NEXT FROM v INTO @C,@V;
    WHILE @@FETCH_STATUS=0
    BEGIN
        EXEC dbo.STO_QL_ToaThuoc_DongBoDauToa @IDCSKCB=@C,@IDVaoVien=@V;
        FETCH NEXT FROM v INTO @C,@V;
    END;
    CLOSE v; DEALLOCATE v;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_QL_ChanDoan_CT_LienThong
ON dbo.QL_ChanDoan_CT
AFTER INSERT,UPDATE,DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Visits TABLE(IDCSKCB BIGINT,IDVaoVien BIGINT,PRIMARY KEY(IDCSKCB,IDVaoVien));
    INSERT @Visits SELECT DISTINCT IDCSKCB,IDVaoVien FROM inserted
    UNION SELECT DISTINCT IDCSKCB,IDVaoVien FROM deleted;
    IF EXISTS
    (
        SELECT 1 FROM @Visits V JOIN dbo.QL_ToaThuoc H WITH(UPDLOCK,HOLDLOCK)
          ON H.IDCSKCB=V.IDCSKCB AND H.IDVaoVien=V.IDVaoVien
        WHERE H.TrangThai IN(N'CHO_GUI',N'DANG_GUI',N'THANH_CONG',N'KHONG_RO_KET_QUA')
    ) THROW 59111,N'Toa thuoc dang gui, khong ro ket qua hoac da lien thong thanh cong; khong duoc sua chan doan.',1;
    UPDATE V SET PhienBanLamSang=PhienBanLamSang+1,NgayCapNhatKham=SYSDATETIME()
    FROM dbo.QL_VaoVien V JOIN @Visits X ON X.IDCSKCB=V.IDCSKCB AND X.IDVaoVien=V.ID;
    UPDATE P SET TrangThai=N'HET_HIEU_LUC'
    FROM dbo.QL_ToaThuoc_PhienBan P
    JOIN dbo.QL_ToaThuoc H ON H.IDCSKCB=P.IDCSKCB AND H.ID=P.IDToaThuoc
    JOIN @Visits V ON V.IDCSKCB=H.IDCSKCB AND V.IDVaoVien=H.IDVaoVien
    WHERE P.TrangThai<>N'HET_HIEU_LUC';
    UPDATE H SET TrangThai=N'NHAP',IDPhienBanHienTai=NULL,NgayCapNhat=SYSDATETIME()
    FROM dbo.QL_ToaThuoc H JOIN @Visits V ON V.IDCSKCB=H.IDCSKCB AND V.IDVaoVien=H.IDVaoVien
    WHERE H.TrangThai IN(N'DA_KY',N'TU_CHOI',N'LOI_GUI');
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_ToaThuoc_LuuPhienBanDaKy
    @IDCSKCB BIGINT,@IDToaThuoc BIGINT,@IDBacSi BIGINT,@IDTaiKhoan BIGINT,@PhienBanNguon BIGINT,
    @JsonChuaKy NVARCHAR(MAX),@Sha256Json CHAR(64),@ChuKyDuLieu NVARCHAR(MAX),@JsonDaKy NVARCHAR(MAX),
    @PdfDaKy VARBINARY(MAX),@Sha256Pdf CHAR(64),@NhaCungCapKy NVARCHAR(100)=NULL,@SerialChungThu NVARCHAR(200)=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @Visit BIGINT,@Doctor BIGINT,@State NVARCHAR(30),@CurrentRevision BIGINT,@VersionNo INT,@VersionID BIGINT;
        SELECT @Visit=H.IDVaoVien,@Doctor=H.IDBacSiKe,@State=H.TrangThai
        FROM dbo.QL_ToaThuoc H WITH(UPDLOCK,HOLDLOCK) WHERE H.IDCSKCB=@IDCSKCB AND H.ID=@IDToaThuoc;
        IF @Visit IS NULL THROW 59120,N'Khong tim thay toa thuoc.',1;
        IF @Doctor<>@IDBacSi THROW 59121,N'Chi bac si ke don moi duoc ky toa.',1;
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.HT_Tai_Khoan T
            JOIN dbo.DM_NhanVien N ON N.ID=T.IDNhanVien AND N.Active=1 AND N.LaBacSi=1
            JOIN dbo.DM_NhanVien_CSKCB M ON M.IDCSKCB=@IDCSKCB AND M.IDNhanVien=N.ID AND M.Active=1
            JOIN dbo.HT_Tai_Khoan_Vai_Tro TV ON TV.IDCSKCB=@IDCSKCB AND TV.ID_Tai_Khoan=T.ID AND TV.Active=1
            JOIN dbo.HT_Quyen_Vai_Tro Q ON Q.IDCSKCB=TV.IDCSKCB AND Q.ID_Vai_Tro=TV.ID_Vai_Tro AND Q.Sua=1
            JOIN dbo.HT_Chuc_Nang F ON F.IDCSKCB=Q.IDCSKCB AND F.ID=Q.ID_Chuc_Nang
                AND F.Ma_Chuc_Nang=N'lien_thong_toa_thuoc' AND F.Active=1
            WHERE T.ID=@IDTaiKhoan AND T.IDCSKCB=@IDCSKCB AND T.IDNhanVien=@IDBacSi
              AND T.Active=1 AND ISNULL(T.LaQuanTriHeThong,0)=0
        ) THROW 59125,N'Tai khoan bac si khong co quyen ky toa tai co so nay.',1;
        IF @State NOT IN(N'NHAP',N'TU_CHOI',N'LOI_GUI') THROW 59122,N'Trang thai toa khong cho phep ky.',1;
        SELECT @CurrentRevision=PhienBanLamSang FROM dbo.QL_VaoVien WITH(UPDLOCK,HOLDLOCK) WHERE IDCSKCB=@IDCSKCB AND ID=@Visit;
        IF @CurrentRevision<>@PhienBanNguon THROW 59123,N'Du lieu kham da thay doi; phai tao lai payload va ky lai.',1;
        IF DATALENGTH(@PdfDaKy)=0 OR NULLIF(@ChuKyDuLieu,N'') IS NULL THROW 59124,N'Thieu chu ky du lieu hoac PDF da ky.',1;
        SELECT @VersionNo=ISNULL(MAX(SoPhienBan),0)+1 FROM dbo.QL_ToaThuoc_PhienBan WITH(UPDLOCK,HOLDLOCK) WHERE IDCSKCB=@IDCSKCB AND IDToaThuoc=@IDToaThuoc;
        UPDATE dbo.QL_ToaThuoc_PhienBan SET TrangThai=N'HET_HIEU_LUC' WHERE IDCSKCB=@IDCSKCB AND IDToaThuoc=@IDToaThuoc AND TrangThai<>N'HET_HIEU_LUC';
        INSERT dbo.QL_ToaThuoc_PhienBan(IDCSKCB,IDToaThuoc,SoPhienBan,PhienBanNguon,TrangThai,JsonChuaKy,Sha256Json,ChuKyDuLieu,JsonDaKy,PdfDaKy,Sha256Pdf,NhaCungCapKy,SerialChungThu,IDBacSiKy,IDTaiKhoanKy)
        VALUES(@IDCSKCB,@IDToaThuoc,@VersionNo,@PhienBanNguon,N'DA_KY',@JsonChuaKy,@Sha256Json,@ChuKyDuLieu,@JsonDaKy,@PdfDaKy,@Sha256Pdf,@NhaCungCapKy,@SerialChungThu,@IDBacSi,@IDTaiKhoan);
        SET @VersionID=SCOPE_IDENTITY();
        UPDATE dbo.QL_ToaThuoc SET TrangThai=N'DA_KY',IDPhienBanHienTai=@VersionID,PhienBanNguon=@PhienBanNguon,NgayCapNhat=SYSDATETIME() WHERE IDCSKCB=@IDCSKCB AND ID=@IDToaThuoc;
        INSERT dbo.QL_ToaThuoc_Audit(IDCSKCB,IDToaThuoc,IDToaThuocPhienBan,HanhDong,TrangThaiTu,TrangThaiDen,IDNhanVien,IDTaiKhoan)
        VALUES(@IDCSKCB,@IDToaThuoc,@VersionID,N'KY_SO',@State,N'DA_KY',@IDBacSi,@IDTaiKhoan);
        COMMIT;
        SELECT @VersionID AS IDPhienBan;
    END TRY
    BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_ToaThuoc_XepHangGui
    @IDCSKCB BIGINT,@IDToaThuoc BIGINT,@IDPhienBan BIGINT,@IDBacSi BIGINT,@IDTaiKhoan BIGINT,@GuiLai BIT=0
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @State NVARCHAR(30),@Doctor BIGINT,@AttemptNo INT,@AttemptID BIGINT;
        SELECT @State=TrangThai,@Doctor=IDBacSiKe FROM dbo.QL_ToaThuoc WITH(UPDLOCK,HOLDLOCK)
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDToaThuoc AND IDPhienBanHienTai=@IDPhienBan;
        IF @Doctor IS NULL THROW 59130,N'Khong tim thay phien ban hien tai cua toa.',1;
        IF @Doctor<>@IDBacSi THROW 59131,N'Chi bac si ke don moi duoc gui toa.',1;
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.HT_Tai_Khoan T
            JOIN dbo.DM_NhanVien N ON N.ID=T.IDNhanVien AND N.Active=1 AND N.LaBacSi=1
            JOIN dbo.DM_NhanVien_CSKCB M ON M.IDCSKCB=@IDCSKCB AND M.IDNhanVien=N.ID AND M.Active=1
            JOIN dbo.HT_Tai_Khoan_Vai_Tro TV ON TV.IDCSKCB=@IDCSKCB AND TV.ID_Tai_Khoan=T.ID AND TV.Active=1
            JOIN dbo.HT_Quyen_Vai_Tro Q ON Q.IDCSKCB=TV.IDCSKCB AND Q.ID_Vai_Tro=TV.ID_Vai_Tro AND Q.Sua=1
            JOIN dbo.HT_Chuc_Nang F ON F.IDCSKCB=Q.IDCSKCB AND F.ID=Q.ID_Chuc_Nang
                AND F.Ma_Chuc_Nang=N'lien_thong_toa_thuoc' AND F.Active=1
            WHERE T.ID=@IDTaiKhoan AND T.IDCSKCB=@IDCSKCB AND T.IDNhanVien=@IDBacSi
              AND T.Active=1 AND ISNULL(T.LaQuanTriHeThong,0)=0
        ) THROW 59134,N'Tai khoan bac si khong co quyen gui toa tai co so nay.',1;
        IF (@GuiLai=0 AND @State<>N'DA_KY') OR (@GuiLai=1 AND @State NOT IN(N'TU_CHOI',N'LOI_GUI'))
            THROW 59132,N'Trang thai toa khong cho phep xep hang gui.',1;
        IF EXISTS(SELECT 1 FROM dbo.QL_ToaThuoc_LanGui G WITH(UPDLOCK,HOLDLOCK) WHERE G.IDCSKCB=@IDCSKCB AND G.IDToaThuocPhienBan=@IDPhienBan AND G.TrangThai IN(N'CHO_GUI',N'DANG_GUI'))
            THROW 59133,N'Toa da co yeu cau dang cho hoac dang gui.',1;
        SELECT @AttemptNo=ISNULL(MAX(SoLan),0)+1 FROM dbo.QL_ToaThuoc_LanGui WITH(UPDLOCK,HOLDLOCK) WHERE IDCSKCB=@IDCSKCB AND IDToaThuocPhienBan=@IDPhienBan;
        INSERT dbo.QL_ToaThuoc_LanGui(IDCSKCB,IDToaThuocPhienBan,SoLan,TrangThai,IDBacSiYeuCau,IDTaiKhoanYeuCau)
        VALUES(@IDCSKCB,@IDPhienBan,@AttemptNo,N'CHO_GUI',@IDBacSi,@IDTaiKhoan);
        SET @AttemptID=SCOPE_IDENTITY();
        UPDATE dbo.QL_ToaThuoc SET TrangThai=N'CHO_GUI',NgayCapNhat=SYSDATETIME() WHERE IDCSKCB=@IDCSKCB AND ID=@IDToaThuoc;
        UPDATE dbo.QL_ToaThuoc_PhienBan SET TrangThai=N'CHO_GUI' WHERE IDCSKCB=@IDCSKCB AND ID=@IDPhienBan;
        INSERT dbo.QL_ToaThuoc_Audit(IDCSKCB,IDToaThuoc,IDToaThuocPhienBan,HanhDong,TrangThaiTu,TrangThaiDen,IDNhanVien,IDTaiKhoan)
        VALUES(@IDCSKCB,@IDToaThuoc,@IDPhienBan,CASE WHEN @GuiLai=1 THEN N'GUI_LAI' ELSE N'XEP_HANG_GUI' END,@State,N'CHO_GUI',@IDBacSi,@IDTaiKhoan);
        COMMIT;
        SELECT @AttemptID AS IDLanGui;
    END TRY
    BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_ToaThuoc_BatDauGui @IDCSKCB BIGINT,@IDLanGui BIGINT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRANSACTION;
    DECLARE @PB BIGINT,@Toa BIGINT;
    SELECT @PB=IDToaThuocPhienBan FROM dbo.QL_ToaThuoc_LanGui WITH(UPDLOCK,HOLDLOCK)
    WHERE IDCSKCB=@IDCSKCB AND ID=@IDLanGui AND TrangThai=N'CHO_GUI';
    IF @PB IS NULL BEGIN ROLLBACK; SELECT CONVERT(BIGINT,0) AS IDLanGui; RETURN; END;
    SELECT @Toa=IDToaThuoc FROM dbo.QL_ToaThuoc_PhienBan WHERE IDCSKCB=@IDCSKCB AND ID=@PB;
    UPDATE dbo.QL_ToaThuoc_LanGui SET TrangThai=N'DANG_GUI',BatDauLuc=SYSDATETIME() WHERE ID=@IDLanGui AND IDCSKCB=@IDCSKCB;
    UPDATE dbo.QL_ToaThuoc_PhienBan SET TrangThai=N'DANG_GUI' WHERE ID=@PB AND IDCSKCB=@IDCSKCB;
    UPDATE dbo.QL_ToaThuoc SET TrangThai=N'DANG_GUI',NgayCapNhat=SYSDATETIME() WHERE ID=@Toa AND IDCSKCB=@IDCSKCB;
    COMMIT;
    SELECT @IDLanGui AS IDLanGui;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_ToaThuoc_GhiNhanKetQuaGui
    @IDCSKCB BIGINT,@IDLanGui BIGINT,@ThanhCong BIT,@KhongRoKetQua BIT,@HttpStatus INT=NULL,
    @MaKetQua NVARCHAR(100)=NULL,@PhanHoiDaLoc NVARCHAR(4000)=NULL,@LoiCuoi NVARCHAR(2000)=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @PB BIGINT,@Toa BIGINT,@Doctor BIGINT,@Account BIGINT,@Final NVARCHAR(30);
        SELECT @PB=IDToaThuocPhienBan,@Doctor=IDBacSiYeuCau,@Account=IDTaiKhoanYeuCau
        FROM dbo.QL_ToaThuoc_LanGui WITH(UPDLOCK,HOLDLOCK)
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDLanGui AND TrangThai=N'DANG_GUI';
        IF @PB IS NULL THROW 59140,N'Lan gui khong o trang thai DANG_GUI.',1;
        SELECT @Toa=IDToaThuoc FROM dbo.QL_ToaThuoc_PhienBan WHERE IDCSKCB=@IDCSKCB AND ID=@PB;
        SET @Final=CASE WHEN @ThanhCong=1 THEN N'THANH_CONG' WHEN @KhongRoKetQua=1 THEN N'KHONG_RO_KET_QUA'
            WHEN @HttpStatus BETWEEN 400 AND 499 THEN N'TU_CHOI' ELSE N'LOI_GUI' END;
        UPDATE dbo.QL_ToaThuoc_LanGui SET TrangThai=@Final,HttpStatus=@HttpStatus,MaKetQua=@MaKetQua,
            PhanHoiDaLoc=@PhanHoiDaLoc,LoiCuoi=@LoiCuoi,KetThucLuc=SYSDATETIME()
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDLanGui;
        UPDATE dbo.QL_ToaThuoc_PhienBan SET TrangThai=@Final WHERE IDCSKCB=@IDCSKCB AND ID=@PB;
        UPDATE dbo.QL_ToaThuoc SET TrangThai=@Final,NgayCapNhat=SYSDATETIME() WHERE IDCSKCB=@IDCSKCB AND ID=@Toa;
        INSERT dbo.QL_ToaThuoc_Audit(IDCSKCB,IDToaThuoc,IDToaThuocPhienBan,HanhDong,TrangThaiTu,TrangThaiDen,LyDo,IDNhanVien,IDTaiKhoan)
        VALUES(@IDCSKCB,@Toa,@PB,N'KET_QUA_GUI',N'DANG_GUI',@Final,@LoiCuoi,@Doctor,@Account);
        COMMIT;
        SELECT @IDLanGui AS IDLanGui,@Final AS TrangThai;
    END TRY
    BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

/* Permission metadata. Doctors receive operational access; tenant admins receive configuration access. */
DECLARE @Cskcb BIGINT,@QuanLy BIGINT,@HeThong BIGINT;
DECLARE p CURSOR LOCAL FAST_FORWARD FOR SELECT ID FROM dbo.DM_CSKCB;
OPEN p; FETCH NEXT FROM p INTO @Cskcb;
WHILE @@FETCH_STATUS=0
BEGIN
    SELECT @QuanLy=ID FROM dbo.HT_Phan_He WHERE IDCSKCB=@Cskcb AND Ma_Phan_He=N'quan_ly';
    SELECT @HeThong=ID FROM dbo.HT_Phan_He WHERE IDCSKCB=@Cskcb AND Ma_Phan_He=N'he_thong';
    IF @QuanLy IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.HT_Chuc_Nang WHERE IDCSKCB=@Cskcb AND Ma_Chuc_Nang=N'lien_thong_toa_thuoc')
        INSERT dbo.HT_Chuc_Nang(IDCSKCB,ID_Phan_He,Ma_Chuc_Nang,Ten_Chuc_Nang,Duong_Dan,Thu_Tu,Active)
        VALUES(@Cskcb,@QuanLy,N'lien_thong_toa_thuoc',N'Lien thong toa thuoc quoc gia',N'/lien_thong_toa_thuoc',30,1);
    IF @HeThong IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.HT_Chuc_Nang WHERE IDCSKCB=@Cskcb AND Ma_Chuc_Nang=N'he_thong_lien_thong_toa_thuoc')
        INSERT dbo.HT_Chuc_Nang(IDCSKCB,ID_Phan_He,Ma_Chuc_Nang,Ten_Chuc_Nang,Duong_Dan,Thu_Tu,Active)
        VALUES(@Cskcb,@HeThong,N'he_thong_lien_thong_toa_thuoc',N'Cau hinh lien thong toa thuoc',N'/he_thong/lien_thong_toa_thuoc',30,1);

    INSERT dbo.HT_Quyen_Vai_Tro(IDCSKCB,ID_Vai_Tro,ID_Chuc_Nang,Xem,Them,Sua,Xoa,Xuat,Ca_Nhan)
    SELECT @Cskcb,V.ID,F.ID,1,0,1,0,0,1 FROM dbo.DM_Vai_Tro V
    JOIN dbo.HT_Chuc_Nang F ON F.IDCSKCB=@Cskcb AND F.Ma_Chuc_Nang=N'lien_thong_toa_thuoc'
    WHERE V.IDCSKCB=@Cskcb AND V.Ma_Vai_Tro=N'bac_si' AND V.Active=1
      AND NOT EXISTS(SELECT 1 FROM dbo.HT_Quyen_Vai_Tro Q WHERE Q.IDCSKCB=@Cskcb AND Q.ID_Vai_Tro=V.ID AND Q.ID_Chuc_Nang=F.ID);
    INSERT dbo.HT_Quyen_Vai_Tro(IDCSKCB,ID_Vai_Tro,ID_Chuc_Nang,Xem,Them,Sua,Xoa,Xuat,Ca_Nhan)
    SELECT @Cskcb,V.ID,F.ID,1,1,1,1,1,1 FROM dbo.DM_Vai_Tro V
    JOIN dbo.HT_Chuc_Nang F ON F.IDCSKCB=@Cskcb AND F.Ma_Chuc_Nang IN(N'lien_thong_toa_thuoc',N'he_thong_lien_thong_toa_thuoc')
    WHERE V.IDCSKCB=@Cskcb AND V.Ma_Vai_Tro=N'quan_tri_cskcb' AND V.Active=1
      AND NOT EXISTS(SELECT 1 FROM dbo.HT_Quyen_Vai_Tro Q WHERE Q.IDCSKCB=@Cskcb AND Q.ID_Vai_Tro=V.ID AND Q.ID_Chuc_Nang=F.ID);
    FETCH NEXT FROM p INTO @Cskcb;
END;
CLOSE p; DEALLOCATE p;
GO

PRINT N'45_toa_thuoc_quoc_gia_v104.sql: source schema/STO prepared; TEST API and signing URLs remain blank.';
GO
