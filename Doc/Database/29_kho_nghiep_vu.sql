/*
29_kho_nghiep_vu.sql
Kho thuốc tối thiểu:
- DM_Kho
- DM_Thuoc_DonViQuyDoi
- QL_Kho_LoThuoc
- QL_Kho_Nhap / CT
- QL_Kho_Xuat / CT
- Nhập kho theo lô/HSD
- Xuất thuốc theo toa đã thanh toán, FEFO
*/

IF DB_NAME()<>N'QLPM'
    THROW 59000,N'Script kho chỉ được chạy trên database QLPM.',1;
GO

IF OBJECT_ID(N'dbo.DM_Kho',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DM_Kho
    (
        ID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DM_Kho PRIMARY KEY,
        IDCSKCB BIGINT NOT NULL,
        MaKho NVARCHAR(50) NOT NULL,
        TenKho NVARCHAR(200) NOT NULL,
        Active BIT NOT NULL CONSTRAINT DF_DM_Kho_Active DEFAULT(1),
        CONSTRAINT FK_DM_Kho_CSKCB FOREIGN KEY(IDCSKCB) REFERENCES dbo.DM_CSKCB(ID)
    );
    CREATE UNIQUE INDEX UQ_DM_Kho_CSKCB_Ma ON dbo.DM_Kho(IDCSKCB,MaKho);
    CREATE UNIQUE INDEX UQ_DM_Kho_CSKCB_ID ON dbo.DM_Kho(IDCSKCB,ID);
END;
GO

IF OBJECT_ID(N'dbo.DM_Thuoc_DonViQuyDoi',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DM_Thuoc_DonViQuyDoi
    (
        ID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DM_Thuoc_DonViQuyDoi PRIMARY KEY,
        IDCSKCB BIGINT NOT NULL,
        IDThuoc BIGINT NOT NULL,
        IDDonViTinh BIGINT NOT NULL,
        HeSoQuyDoi DECIMAL(18,6) NOT NULL,
        LaDonViCoSo BIT NOT NULL CONSTRAINT DF_DM_Thuoc_DVQD_Base DEFAULT(0),
        Active BIT NOT NULL CONSTRAINT DF_DM_Thuoc_DVQD_Active DEFAULT(1),
        CONSTRAINT CK_DM_Thuoc_DVQD_HeSo CHECK(HeSoQuyDoi>0),
        CONSTRAINT FK_DM_Thuoc_DVQD_Thuoc FOREIGN KEY(IDCSKCB,IDThuoc) REFERENCES dbo.DM_Thuoc(IDCSKCB,ID),
        CONSTRAINT FK_DM_Thuoc_DVQD_DVT FOREIGN KEY(IDCSKCB,IDDonViTinh) REFERENCES dbo.DM_DonViTinh(IDCSKCB,ID)
    );
    CREATE UNIQUE INDEX UQ_DM_Thuoc_DVQD ON dbo.DM_Thuoc_DonViQuyDoi(IDCSKCB,IDThuoc,IDDonViTinh);
END;
GO

IF OBJECT_ID(N'dbo.QL_Kho_LoThuoc',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.QL_Kho_LoThuoc
    (
        ID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_QL_Kho_LoThuoc PRIMARY KEY,
        IDCSKCB BIGINT NOT NULL,
        IDKho BIGINT NOT NULL,
        IDThuoc BIGINT NOT NULL,
        SoLo NVARCHAR(100) NULL,
        HanDung DATE NULL,
        GiaNhap DECIMAL(18,4) NOT NULL CONSTRAINT DF_QL_Kho_Lo_GiaNhap DEFAULT(0),
        SoLuongNhap DECIMAL(18,4) NOT NULL CONSTRAINT DF_QL_Kho_Lo_SLNhap DEFAULT(0),
        SoLuongTon DECIMAL(18,4) NOT NULL CONSTRAINT DF_QL_Kho_Lo_SLTon DEFAULT(0),
        NgayNhap DATETIME2(0) NOT NULL CONSTRAINT DF_QL_Kho_Lo_NgayNhap DEFAULT(SYSDATETIME()),
        Active BIT NOT NULL CONSTRAINT DF_QL_Kho_Lo_Active DEFAULT(1),
        CONSTRAINT CK_QL_Kho_Lo_Ton CHECK(SoLuongNhap>=0 AND SoLuongTon>=0),
        CONSTRAINT FK_QL_Kho_Lo_Kho FOREIGN KEY(IDCSKCB,IDKho) REFERENCES dbo.DM_Kho(IDCSKCB,ID),
        CONSTRAINT FK_QL_Kho_Lo_Thuoc FOREIGN KEY(IDCSKCB,IDThuoc) REFERENCES dbo.DM_Thuoc(IDCSKCB,ID)
    );
    CREATE INDEX IX_QL_Kho_Lo_FEFO ON dbo.QL_Kho_LoThuoc(IDCSKCB,IDKho,IDThuoc,Active,HanDung,NgayNhap,ID)
        INCLUDE(SoLuongTon,GiaNhap,SoLo);
END;
GO

IF OBJECT_ID(N'dbo.QL_Kho_Nhap',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.QL_Kho_Nhap
    (
        ID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_QL_Kho_Nhap PRIMARY KEY,
        IDCSKCB BIGINT NOT NULL,
        IDKho BIGINT NOT NULL,
        SoPhieu NVARCHAR(30) NOT NULL,
        SoHoaDon NVARCHAR(100) NULL,
        NgayNhap DATETIME2(0) NOT NULL,
        IDNhanVienNhap BIGINT NULL,
        TongTien DECIMAL(18,2) NOT NULL CONSTRAINT DF_QL_Kho_Nhap_Tong DEFAULT(0),
        GhiChu NVARCHAR(500) NULL,
        DaHuy BIT NOT NULL CONSTRAINT DF_QL_Kho_Nhap_DaHuy DEFAULT(0),
        CONSTRAINT FK_QL_Kho_Nhap_Kho FOREIGN KEY(IDCSKCB,IDKho) REFERENCES dbo.DM_Kho(IDCSKCB,ID),
        CONSTRAINT FK_QL_Kho_Nhap_NV FOREIGN KEY(IDNhanVienNhap) REFERENCES dbo.DM_NhanVien(ID)
    );
    CREATE UNIQUE INDEX UQ_QL_Kho_Nhap_SoPhieu ON dbo.QL_Kho_Nhap(IDCSKCB,SoPhieu);
    CREATE UNIQUE INDEX UQ_QL_Kho_Nhap_CSKCB_ID ON dbo.QL_Kho_Nhap(IDCSKCB,ID);
END;
GO

IF OBJECT_ID(N'dbo.QL_Kho_Nhap_CT',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.QL_Kho_Nhap_CT
    (
        ID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_QL_Kho_Nhap_CT PRIMARY KEY,
        IDCSKCB BIGINT NOT NULL,
        IDNhap BIGINT NOT NULL,
        IDThuoc BIGINT NOT NULL,
        IDDonViTinh BIGINT NOT NULL,
        HeSoQuyDoi DECIMAL(18,6) NOT NULL,
        SoLuong DECIMAL(18,4) NOT NULL,
        SoLuongCoSo DECIMAL(18,4) NOT NULL,
        GiaNhap DECIMAL(18,2) NOT NULL,
        ThanhTien DECIMAL(18,2) NOT NULL,
        SoLo NVARCHAR(100) NULL,
        HanDung DATE NULL,
        IDLoThuoc BIGINT NOT NULL,
        CONSTRAINT CK_QL_Kho_NhapCT_SL CHECK(SoLuong>0 AND SoLuongCoSo>0 AND HeSoQuyDoi>0),
        CONSTRAINT FK_QL_Kho_NhapCT_Nhap FOREIGN KEY(IDCSKCB,IDNhap) REFERENCES dbo.QL_Kho_Nhap(IDCSKCB,ID),
        CONSTRAINT FK_QL_Kho_NhapCT_Thuoc FOREIGN KEY(IDCSKCB,IDThuoc) REFERENCES dbo.DM_Thuoc(IDCSKCB,ID),
        CONSTRAINT FK_QL_Kho_NhapCT_DVT FOREIGN KEY(IDCSKCB,IDDonViTinh) REFERENCES dbo.DM_DonViTinh(IDCSKCB,ID),
        CONSTRAINT FK_QL_Kho_NhapCT_Lo FOREIGN KEY(IDLoThuoc) REFERENCES dbo.QL_Kho_LoThuoc(ID)
    );
END;
GO

IF OBJECT_ID(N'dbo.QL_Kho_Xuat',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.QL_Kho_Xuat
    (
        ID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_QL_Kho_Xuat PRIMARY KEY,
        IDCSKCB BIGINT NOT NULL,
        IDKho BIGINT NOT NULL,
        IDVaoVien BIGINT NOT NULL,
        SoPhieu NVARCHAR(30) NOT NULL,
        NgayXuat DATETIME2(0) NOT NULL,
        IDNhanVienXuat BIGINT NULL,
        TongGiaVon DECIMAL(18,2) NOT NULL CONSTRAINT DF_QL_Kho_Xuat_Tong DEFAULT(0),
        GhiChu NVARCHAR(500) NULL,
        DaHuy BIT NOT NULL CONSTRAINT DF_QL_Kho_Xuat_DaHuy DEFAULT(0),
        CONSTRAINT FK_QL_Kho_Xuat_Kho FOREIGN KEY(IDCSKCB,IDKho) REFERENCES dbo.DM_Kho(IDCSKCB,ID),
        CONSTRAINT FK_QL_Kho_Xuat_VV FOREIGN KEY(IDCSKCB,IDVaoVien) REFERENCES dbo.QL_VaoVien(IDCSKCB,ID),
        CONSTRAINT FK_QL_Kho_Xuat_NV FOREIGN KEY(IDNhanVienXuat) REFERENCES dbo.DM_NhanVien(ID)
    );
    CREATE UNIQUE INDEX UQ_QL_Kho_Xuat_SoPhieu ON dbo.QL_Kho_Xuat(IDCSKCB,SoPhieu);
    CREATE UNIQUE INDEX UQ_QL_Kho_Xuat_CSKCB_ID ON dbo.QL_Kho_Xuat(IDCSKCB,ID);
    CREATE INDEX IX_QL_Kho_Xuat_VV ON dbo.QL_Kho_Xuat(IDCSKCB,IDVaoVien,DaHuy,NgayXuat);
END;
GO

IF OBJECT_ID(N'dbo.QL_Kho_Xuat_CT',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.QL_Kho_Xuat_CT
    (
        ID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_QL_Kho_Xuat_CT PRIMARY KEY,
        IDCSKCB BIGINT NOT NULL,
        IDXuat BIGINT NOT NULL,
        IDToaThuocCT BIGINT NOT NULL,
        IDThuoc BIGINT NOT NULL,
        IDLoThuoc BIGINT NOT NULL,
        SoLuongCoSo DECIMAL(18,4) NOT NULL,
        GiaVon DECIMAL(18,4) NOT NULL,
        ThanhTien DECIMAL(18,2) NOT NULL,
        CONSTRAINT CK_QL_Kho_XuatCT_SL CHECK(SoLuongCoSo>0),
        CONSTRAINT FK_QL_Kho_XuatCT_Xuat FOREIGN KEY(IDCSKCB,IDXuat) REFERENCES dbo.QL_Kho_Xuat(IDCSKCB,ID),
        CONSTRAINT FK_QL_Kho_XuatCT_Toa FOREIGN KEY(IDCSKCB,IDToaThuocCT) REFERENCES dbo.QL_ToaThuoc_CT(IDCSKCB,ID),
        CONSTRAINT FK_QL_Kho_XuatCT_Thuoc FOREIGN KEY(IDCSKCB,IDThuoc) REFERENCES dbo.DM_Thuoc(IDCSKCB,ID),
        CONSTRAINT FK_QL_Kho_XuatCT_Lo FOREIGN KEY(IDLoThuoc) REFERENCES dbo.QL_Kho_LoThuoc(ID)
    );
    CREATE INDEX IX_QL_Kho_XuatCT_Toa ON dbo.QL_Kho_Xuat_CT(IDCSKCB,IDToaThuocCT);
END;
GO

IF OBJECT_ID(N'dbo.DM_NhaCungCap',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DM_NhaCungCap
    (
        ID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DM_NhaCungCap PRIMARY KEY,
        IDCSKCB BIGINT NOT NULL, MaNhaCungCap NVARCHAR(50) NOT NULL, TenNhaCungCap NVARCHAR(300) NOT NULL,
        MaSoThue NVARCHAR(50) NULL, DienThoai NVARCHAR(30) NULL, DiaChi NVARCHAR(500) NULL,
        Active BIT NOT NULL CONSTRAINT DF_DM_NhaCungCap_Active DEFAULT(1),
        CONSTRAINT UQ_DM_NhaCungCap_CSKCB_ID UNIQUE(IDCSKCB,ID),
        CONSTRAINT UQ_DM_NhaCungCap_Ma UNIQUE(IDCSKCB,MaNhaCungCap),
        CONSTRAINT FK_DM_NhaCungCap_CSKCB FOREIGN KEY(IDCSKCB) REFERENCES dbo.DM_CSKCB(ID)
    );
END;
GO

IF COL_LENGTH(N'dbo.QL_Kho_Nhap',N'IDNhaCungCap') IS NULL
    ALTER TABLE dbo.QL_Kho_Nhap ADD IDNhaCungCap BIGINT NULL;
IF COL_LENGTH(N'dbo.QL_Kho_Nhap',N'NgayHoaDon') IS NULL
    ALTER TABLE dbo.QL_Kho_Nhap ADD NgayHoaDon DATE NULL;
IF COL_LENGTH(N'dbo.QL_Kho_Nhap',N'NgayGioHuy') IS NULL
    ALTER TABLE dbo.QL_Kho_Nhap ADD NgayGioHuy DATETIME2(0) NULL;
IF COL_LENGTH(N'dbo.QL_Kho_Nhap',N'IDNhanVienHuy') IS NULL
    ALTER TABLE dbo.QL_Kho_Nhap ADD IDNhanVienHuy BIGINT NULL;
IF COL_LENGTH(N'dbo.QL_Kho_Nhap',N'LyDoHuy') IS NULL
    ALTER TABLE dbo.QL_Kho_Nhap ADD LyDoHuy NVARCHAR(500) NULL;
GO

IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'dbo.QL_Kho_Nhap') AND name=N'FK_QL_Kho_Nhap_NCC')
    ALTER TABLE dbo.QL_Kho_Nhap WITH CHECK ADD CONSTRAINT FK_QL_Kho_Nhap_NCC
        FOREIGN KEY(IDCSKCB,IDNhaCungCap) REFERENCES dbo.DM_NhaCungCap(IDCSKCB,ID);
GO

IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'dbo.QL_Kho_Nhap') AND name=N'FK_QL_Kho_Nhap_NVH')
    ALTER TABLE dbo.QL_Kho_Nhap WITH CHECK ADD CONSTRAINT FK_QL_Kho_Nhap_NVH FOREIGN KEY(IDNhanVienHuy) REFERENCES dbo.DM_NhanVien(ID);
GO

CREATE OR ALTER PROCEDURE dbo.STO_DM_NhaCungCap_DanhSach @IDCSKCB BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ID AS id,MaNhaCungCap AS ma,TenNhaCungCap AS ten,MaSoThue AS ma_so_thue,DienThoai AS dien_thoai,DiaChi AS dia_chi
    FROM dbo.DM_NhaCungCap WHERE IDCSKCB=@IDCSKCB AND Active=1 ORDER BY TenNhaCungCap,ID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_DM_NhaCungCap_ThemNhanh
    @IDCSKCB BIGINT,@Ten NVARCHAR(300),@MaSoThue NVARCHAR(50)=NULL,@DienThoai NVARCHAR(30)=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON; SET @Ten=NULLIF(LTRIM(RTRIM(@Ten)),N'');
    BEGIN TRY
        IF @Ten IS NULL THROW 58100,N'Phải nhập tên nhà cung cấp.',1;
        DECLARE @ID BIGINT=(SELECT TOP(1) ID FROM dbo.DM_NhaCungCap WHERE IDCSKCB=@IDCSKCB AND TenNhaCungCap=@Ten AND Active=1 ORDER BY ID);
        IF @ID IS NULL BEGIN
            DECLARE @Ma NVARCHAR(50)=N'NCC-'+LEFT(REPLACE(CONVERT(NVARCHAR(36),NEWID()),N'-',N''),12);
            INSERT dbo.DM_NhaCungCap(IDCSKCB,MaNhaCungCap,TenNhaCungCap,MaSoThue,DienThoai)
            VALUES(@IDCSKCB,@Ma,@Ten,NULLIF(LTRIM(RTRIM(@MaSoThue)),N''),NULLIF(LTRIM(RTRIM(@DienThoai)),N''));
            SET @ID=SCOPE_IDENTITY();
        END;
        SELECT 200 AS Status,N'Đã lưu nhà cung cấp.' AS Message,@ID AS ID;
    END TRY BEGIN CATCH SELECT 400 AS Status,ERROR_MESSAGE() AS Message; END CATCH;
END;
GO

IF COL_LENGTH(N'dbo.QL_Kho_Xuat_CT',N'SoLuongDaHoan') IS NULL
    ALTER TABLE dbo.QL_Kho_Xuat_CT ADD SoLuongDaHoan DECIMAL(18,4) NOT NULL
        CONSTRAINT DF_QL_Kho_Xuat_CT_SoLuongDaHoan DEFAULT(0);
GO

IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.QL_Kho_Xuat_CT') AND name=N'CK_QL_Kho_Xuat_CT_DaHoan')
    ALTER TABLE dbo.QL_Kho_Xuat_CT WITH CHECK ADD CONSTRAINT CK_QL_Kho_Xuat_CT_DaHoan
        CHECK(SoLuongDaHoan>=0 AND SoLuongDaHoan<=SoLuongCoSo);
GO

IF OBJECT_ID(N'dbo.QL_Kho_Hoan',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.QL_Kho_Hoan
    (
        ID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_QL_Kho_Hoan PRIMARY KEY,
        IDCSKCB BIGINT NOT NULL, IDVaoVien BIGINT NOT NULL, SoPhieu NVARCHAR(30) NOT NULL,
        NgayHoan DATETIME2(0) NOT NULL CONSTRAINT DF_QL_Kho_Hoan_Ngay DEFAULT(SYSDATETIME()),
        IDNhanVienHoan BIGINT NOT NULL, LyDo NVARCHAR(500) NOT NULL,
        CONSTRAINT UQ_QL_Kho_Hoan_So UNIQUE(IDCSKCB,SoPhieu),
        CONSTRAINT FK_QL_Kho_Hoan_VV FOREIGN KEY(IDCSKCB,IDVaoVien) REFERENCES dbo.QL_VaoVien(IDCSKCB,ID),
        CONSTRAINT FK_QL_Kho_Hoan_NV FOREIGN KEY(IDNhanVienHoan) REFERENCES dbo.DM_NhanVien(ID)
    );
    CREATE INDEX IX_QL_Kho_Hoan_VV ON dbo.QL_Kho_Hoan(IDCSKCB,IDVaoVien,NgayHoan DESC);
END;
GO

IF OBJECT_ID(N'dbo.QL_Kho_Hoan_CT',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.QL_Kho_Hoan_CT
    (
        ID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_QL_Kho_Hoan_CT PRIMARY KEY,
        IDHoan BIGINT NOT NULL, IDXuatCT BIGINT NOT NULL, SoLuongCoSo DECIMAL(18,4) NOT NULL,
        CONSTRAINT CK_QL_Kho_Hoan_CT_SL CHECK(SoLuongCoSo>0),
        CONSTRAINT FK_QL_Kho_Hoan_CT_Hoan FOREIGN KEY(IDHoan) REFERENCES dbo.QL_Kho_Hoan(ID),
        CONSTRAINT FK_QL_Kho_Hoan_CT_XuatCT FOREIGN KEY(IDXuatCT) REFERENCES dbo.QL_Kho_Xuat_CT(ID)
    );
    CREATE INDEX IX_QL_Kho_Hoan_CT_Hoan ON dbo.QL_Kho_Hoan_CT(IDHoan,ID);
END;
GO

IF NOT EXISTS(SELECT 1 FROM sys.sequences WHERE schema_id=SCHEMA_ID(N'dbo') AND name=N'SEQ_SoPhieuNhapKho')
    EXEC(N'CREATE SEQUENCE dbo.SEQ_SoPhieuNhapKho AS BIGINT START WITH 1 INCREMENT BY 1;');
IF NOT EXISTS(SELECT 1 FROM sys.sequences WHERE schema_id=SCHEMA_ID(N'dbo') AND name=N'SEQ_SoPhieuXuatKho')
    EXEC(N'CREATE SEQUENCE dbo.SEQ_SoPhieuXuatKho AS BIGINT START WITH 1 INCREMENT BY 1;');
IF NOT EXISTS(SELECT 1 FROM sys.sequences WHERE schema_id=SCHEMA_ID(N'dbo') AND name=N'SEQ_SoPhieuHoanKho')
    EXEC(N'CREATE SEQUENCE dbo.SEQ_SoPhieuHoanKho AS BIGINT START WITH 1 INCREMENT BY 1;');
GO

/* Mỗi CSKCB có một kho thuốc mặc định. */
INSERT dbo.DM_Kho(IDCSKCB,MaKho,TenKho,Active)
SELECT C.ID,N'KHO_THUOC',N'Kho thuốc',1
FROM dbo.DM_CSKCB C
WHERE C.Active=1
  AND NOT EXISTS
  (
      SELECT 1 FROM dbo.DM_Kho K
      WHERE K.IDCSKCB=C.ID AND K.MaKho=N'KHO_THUOC'
  );
GO

/* DVT mặc định của thuốc là đơn vị cơ sở với hệ số 1. */
INSERT dbo.DM_Thuoc_DonViQuyDoi(IDCSKCB,IDThuoc,IDDonViTinh,HeSoQuyDoi,LaDonViCoSo,Active)
SELECT T.IDCSKCB,T.ID,T.IDDonViTinh,1,1,1
FROM dbo.DM_Thuoc T
WHERE T.IDDonViTinh IS NOT NULL
  AND NOT EXISTS
  (
      SELECT 1 FROM dbo.DM_Thuoc_DonViQuyDoi Q
      WHERE Q.IDCSKCB=T.IDCSKCB AND Q.IDThuoc=T.ID AND Q.IDDonViTinh=T.IDDonViTinh
  );
GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_DanhSachKho
    @IDCSKCB BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ID AS id,MaKho AS ma,TenKho AS ten
    FROM dbo.DM_Kho
    WHERE IDCSKCB=@IDCSKCB AND Active=1
    ORDER BY TenKho,ID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_TonKho_DanhSach
    @IDCSKCB BIGINT,
    @IDKho BIGINT=NULL,
    @TuKhoa NVARCHAR(300)=NULL,
    @Trang INT=1,
    @KichThuocTrang INT=25,
    @TrangThai NVARCHAR(30)=N'tat_ca'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Ngay DATE=CONVERT(DATE,SYSDATETIME());
    SET @TrangThai=COALESCE(NULLIF(LOWER(LTRIM(RTRIM(@TrangThai))),N''),N'tat_ca');
    IF @TrangThai NOT IN(N'tat_ca',N'con_thuoc',N'het_thuoc',N'sap_het_han',N'het_han_khoa')
        THROW 51000,N'Trang thai loc ton kho khong hop le.',1;
    SET @TuKhoa=NULLIF(LTRIM(RTRIM(@TuKhoa)),N'');
    SET @Trang=CASE WHEN @Trang<1 THEN 1 ELSE @Trang END;
    SET @KichThuocTrang=CASE WHEN @KichThuocTrang<10 THEN 10 WHEN @KichThuocTrang>100 THEN 100 ELSE @KichThuocTrang END;

    IF @IDKho IS NULL
        SELECT TOP(1) @IDKho=ID FROM dbo.DM_Kho WHERE IDCSKCB=@IDCSKCB AND Active=1 ORDER BY ID;

    DECLARE @TonKho TABLE
    (
        id_thuoc BIGINT NOT NULL,
        ma_thuoc NVARCHAR(100) NULL,
        ten_thuoc NVARCHAR(500) NULL,
        don_vi_tinh NVARCHAR(200) NULL,
        ton_vat_ly DECIMAL(38,6) NOT NULL,
        ton_het_han DECIMAL(38,6) NOT NULL,
        ton_kha_dung DECIMAL(38,6) NOT NULL,
        han_gan_nhat DATE NULL,
        so_lo BIGINT NOT NULL,
        gia_ban DECIMAL(38,6) NULL,
        sap_het_han BIT NOT NULL
    );

    INSERT @TonKho
        (id_thuoc,ma_thuoc,ten_thuoc,don_vi_tinh,ton_vat_ly,ton_het_han,ton_kha_dung,han_gan_nhat,so_lo,gia_ban,sap_het_han)
    SELECT
        T.ID,
        T.MaThuoc,
        T.TenThuoc,
        DVT.TenDVT,
        ISNULL(X.ton_vat_ly,0),
        ISNULL(X.ton_het_han,0),
        ISNULL(X.ton_kha_dung,0),
        X.han_gan_nhat,
        ISNULL(X.so_lo,0),
        T.GiaBan,
        CAST(CASE WHEN X.han_gan_nhat BETWEEN @Ngay AND DATEADD(DAY,30,@Ngay) THEN 1 ELSE 0 END AS BIT)
    FROM dbo.DM_Thuoc T
    LEFT JOIN dbo.DM_DonViTinh DVT
      ON DVT.IDCSKCB=T.IDCSKCB AND DVT.ID=T.IDDonViTinh
    OUTER APPLY
    (
        SELECT
            SUM(L.SoLuongTon) AS ton_vat_ly,
            SUM(CASE WHEN L.SoLuongTon>0 AND (L.Active=0 OR L.HanDung<@Ngay) THEN L.SoLuongTon ELSE 0 END) AS ton_het_han,
            SUM(CASE WHEN L.Active=1 AND L.SoLuongTon>0 AND (L.HanDung IS NULL OR L.HanDung>=@Ngay) THEN L.SoLuongTon ELSE 0 END) AS ton_kha_dung,
            MIN(CASE WHEN L.Active=1 AND L.SoLuongTon>0 AND (L.HanDung IS NULL OR L.HanDung>=@Ngay) THEN L.HanDung END) AS han_gan_nhat,
            SUM(CASE WHEN L.SoLuongTon>0 THEN CAST(1 AS BIGINT) ELSE CAST(0 AS BIGINT) END) AS so_lo
        FROM dbo.QL_Kho_LoThuoc L
        WHERE L.IDCSKCB=@IDCSKCB AND L.IDKho=@IDKho AND L.IDThuoc=T.ID
    ) X
    WHERE T.IDCSKCB=@IDCSKCB
      AND T.Active=1
      AND
      (
          @TuKhoa IS NULL
          OR T.MaThuoc LIKE N'%'+@TuKhoa+N'%'
          OR T.TenThuoc LIKE N'%'+@TuKhoa+N'%'
      );

    -- Filtering applies to the complete result before count and pagination.
    DELETE FROM @TonKho WHERE NOT
    (
        @TrangThai=N'tat_ca'
        OR (@TrangThai=N'con_thuoc' AND ton_kha_dung>0)
        OR (@TrangThai=N'het_thuoc' AND ton_vat_ly=0)
        OR (@TrangThai=N'sap_het_han' AND sap_het_han=1)
        OR (@TrangThai=N'het_han_khoa' AND ton_het_han>0)
    );

    SELECT COUNT_BIG(*) AS tong_so FROM @TonKho;

    SELECT *
    FROM @TonKho
    ORDER BY CASE WHEN ton_kha_dung<=0 THEN 0 ELSE 1 END,ten_thuoc,id_thuoc
    OFFSET (@Trang-1)*@KichThuocTrang ROWS
    FETCH NEXT @KichThuocTrang ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_Nhap
    @IDCSKCB BIGINT,
    @IDKho BIGINT,
    @IDNhanVienNhap BIGINT,
    @IDNhaCungCap BIGINT=NULL,
    @SoHoaDon NVARCHAR(100)=NULL,
    @NgayHoaDon DATE=NULL,
    @GhiChu NVARCHAR(500)=NULL,
    @DanhSachJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS(SELECT 1 FROM dbo.DM_Kho WHERE IDCSKCB=@IDCSKCB AND ID=@IDKho AND Active=1)
            THROW 58100,N'Kho không hợp lệ.',1;
        IF @IDNhanVienNhap<=0
            THROW 58100,N'Không xác định được nhân viên nhập kho.',1;
        IF @IDNhaCungCap IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.DM_NhaCungCap WHERE IDCSKCB=@IDCSKCB AND ID=@IDNhaCungCap AND Active=1)
            THROW 58100,N'Nhà cung cấp không hợp lệ.',1;
        IF ISJSON(@DanhSachJson)<>1
            THROW 58100,N'Danh sách nhập kho không hợp lệ.',1;

        DECLARE @CT TABLE
        (
            STT INT IDENTITY(1,1) PRIMARY KEY,
            IDThuoc BIGINT NOT NULL,
            IDDonViTinh BIGINT NOT NULL,
            SoLuong DECIMAL(18,4) NOT NULL,
            GiaNhap DECIMAL(18,2) NOT NULL,
            SoLo NVARCHAR(100) NULL,
            HanDung DATE NULL,
            HeSo DECIMAL(18,6) NULL
        );

        INSERT @CT(IDThuoc,IDDonViTinh,SoLuong,GiaNhap,SoLo,HanDung)
        SELECT
            J.IDThuoc,J.IDDonViTinh,J.SoLuong,J.GiaNhap,
            NULLIF(LTRIM(RTRIM(J.SoLo)),N''),J.HanDung
        FROM OPENJSON(@DanhSachJson)
        WITH
        (
            IDThuoc BIGINT '$.id_thuoc',
            IDDonViTinh BIGINT '$.id_don_vi_tinh',
            SoLuong DECIMAL(18,4) '$.so_luong',
            GiaNhap DECIMAL(18,2) '$.gia_nhap',
            SoLo NVARCHAR(100) '$.so_lo',
            HanDung DATE '$.han_dung'
        ) J
        WHERE J.IDThuoc IS NOT NULL;

        IF NOT EXISTS(SELECT 1 FROM @CT)
            THROW 58100,N'Chưa có thuốc nhập kho.',1;
        IF EXISTS(SELECT 1 FROM @CT WHERE SoLuong<=0 OR GiaNhap<0)
            THROW 58100,N'Số lượng hoặc giá nhập không hợp lệ.',1;
        IF EXISTS(SELECT 1 FROM @CT WHERE HanDung IS NOT NULL AND HanDung<CONVERT(DATE,SYSDATETIME()))
            THROW 58100,N'Không được nhập lô thuốc đã hết hạn.',1;
        IF EXISTS
        (
            SELECT 1 FROM @CT C
            WHERE NOT EXISTS
            (
                SELECT 1 FROM dbo.DM_Thuoc T
                WHERE T.IDCSKCB=@IDCSKCB AND T.ID=C.IDThuoc AND T.Active=1
            )
        )
            THROW 58100,N'Có thuốc không thuộc cơ sở hoặc đã ngừng hoạt động.',1;

        UPDATE C
        SET HeSo=Q.HeSoQuyDoi
        FROM @CT C
        INNER JOIN dbo.DM_Thuoc_DonViQuyDoi Q
          ON Q.IDCSKCB=@IDCSKCB
         AND Q.IDThuoc=C.IDThuoc
         AND Q.IDDonViTinh=C.IDDonViTinh
         AND Q.Active=1;

        IF EXISTS(SELECT 1 FROM @CT WHERE HeSo IS NULL OR HeSo<=0)
            THROW 58100,N'Có thuốc chưa cấu hình quy đổi đơn vị tính.',1;

        DECLARE @Seq BIGINT=NEXT VALUE FOR dbo.SEQ_SoPhieuNhapKho;
        DECLARE @SoPhieu NVARCHAR(30)=N'NK'+CONVERT(CHAR(8),SYSDATETIME(),112)+RIGHT(N'00000000'+CONVERT(NVARCHAR(20),@Seq),8);

        INSERT dbo.QL_Kho_Nhap(IDCSKCB,IDKho,SoPhieu,SoHoaDon,NgayHoaDon,IDNhaCungCap,NgayNhap,IDNhanVienNhap,TongTien,GhiChu,DaHuy)
        SELECT @IDCSKCB,@IDKho,@SoPhieu,NULLIF(LTRIM(RTRIM(@SoHoaDon)),N''),@NgayHoaDon,@IDNhaCungCap,SYSDATETIME(),@IDNhanVienNhap,
               SUM(SoLuong*GiaNhap),NULLIF(LTRIM(RTRIM(@GhiChu)),N''),0
        FROM @CT;

        DECLARE @IDNhap BIGINT=SCOPE_IDENTITY();
        DECLARE @STT INT,@IDThuoc BIGINT,@IDDVT BIGINT,@SL DECIMAL(18,4),@Gia DECIMAL(18,2),@SoLo NVARCHAR(100),@HanDung DATE,@HeSo DECIMAL(18,6);
        DECLARE c CURSOR LOCAL FAST_FORWARD FOR
            SELECT STT,IDThuoc,IDDonViTinh,SoLuong,GiaNhap,SoLo,HanDung,HeSo FROM @CT ORDER BY STT;

        OPEN c;
        FETCH NEXT FROM c INTO @STT,@IDThuoc,@IDDVT,@SL,@Gia,@SoLo,@HanDung,@HeSo;
        WHILE @@FETCH_STATUS=0
        BEGIN
            DECLARE @SLCoSo DECIMAL(18,4)=@SL*@HeSo;
            DECLARE @GiaCoSo DECIMAL(18,4)=CASE WHEN @HeSo>0 THEN @Gia/@HeSo ELSE 0 END;
            DECLARE @IDLo BIGINT;
            SET @IDLo=NULL;

            /* Mỗi phiếu nhập giữ lô tồn riêng, kể cả cùng số lô/HSD, để có thể
               chứng minh chính xác lô của phiếu đã phát sinh xuất hay chưa. */
            INSERT dbo.QL_Kho_LoThuoc(IDCSKCB,IDKho,IDThuoc,SoLo,HanDung,GiaNhap,SoLuongNhap,SoLuongTon,NgayNhap,Active)
            VALUES(@IDCSKCB,@IDKho,@IDThuoc,@SoLo,@HanDung,@GiaCoSo,@SLCoSo,@SLCoSo,SYSDATETIME(),1);
            SET @IDLo=SCOPE_IDENTITY();

            INSERT dbo.QL_Kho_Nhap_CT
                (IDCSKCB,IDNhap,IDThuoc,IDDonViTinh,HeSoQuyDoi,SoLuong,SoLuongCoSo,GiaNhap,ThanhTien,SoLo,HanDung,IDLoThuoc)
            VALUES
                (@IDCSKCB,@IDNhap,@IDThuoc,@IDDVT,@HeSo,@SL,@SLCoSo,@Gia,@SL*@Gia,@SoLo,@HanDung,@IDLo);

            FETCH NEXT FROM c INTO @STT,@IDThuoc,@IDDVT,@SL,@Gia,@SoLo,@HanDung,@HeSo;
        END;
        CLOSE c;
        DEALLOCATE c;

        COMMIT;
        SELECT 200 AS Status,N'Nhập kho thành công.' AS Message,@IDNhap AS IDNhap,@SoPhieu AS SoPhieu;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local','c')>=-1
        BEGIN
            IF CURSOR_STATUS('local','c')> -1 CLOSE c;
            DEALLOCATE c;
        END;
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 400 AS Status,ERROR_MESSAGE() AS Message,CAST(NULL AS BIGINT) AS IDNhap,CAST(NULL AS NVARCHAR(30)) AS SoPhieu;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_Xuat_DanhSach
    @IDCSKCB BIGINT,
    @TuKhoa NVARCHAR(200)=NULL,
    @TrangThai TINYINT=NULL,
    @TrangThaiCsv NVARCHAR(20)=NULL,
    @TuNgay DATE=NULL,
    @DenNgay DATE=NULL,
    @LoaiToa NVARCHAR(20)=NULL,
    @Trang INT=1,
    @KichThuocTrang INT=25
AS
BEGIN
    SET NOCOUNT ON;
    SET @TuKhoa=NULLIF(LTRIM(RTRIM(@TuKhoa)),N'');
    SET @TrangThaiCsv=NULLIF(REPLACE(LTRIM(RTRIM(@TrangThaiCsv)),N' ',N''),N'');
    SET @LoaiToa=LOWER(NULLIF(LTRIM(RTRIM(@LoaiToa)),N''));
    IF @LoaiToa NOT IN(N'c',N'n',N'h') SET @LoaiToa=NULL;
    IF @TrangThai NOT IN(0,1,2) SET @TrangThai=NULL;
    SET @Trang=CASE WHEN @Trang<1 THEN 1 ELSE @Trang END;
    SET @KichThuocTrang=CASE WHEN @KichThuocTrang<10 THEN 10 WHEN @KichThuocTrang>100 THEN 100 ELSE @KichThuocTrang END;
    IF @TuNgay IS NOT NULL AND @DenNgay IS NOT NULL AND @TuNgay>@DenNgay
    BEGIN
        DECLARE @D DATE=@TuNgay;
        SET @TuNgay=@DenNgay;
        SET @DenNgay=@D;
    END;

    ;WITH D AS
    (
        SELECT
            V.ID AS id_vao_vien,V.MaVaoVien AS ma_vao_vien,
            B.MaBN AS ma_bn,B.HoTen AS ho_ten,B.NgaySinh AS ngay_sinh,
            GT.TenGioiTinh AS gioi_tinh,
            T.SoPhieu AS so_phieu_thu,T.NgayGioThu AS ngay_gio_thu,
            X.tong_dong,X.tong_co_so,X.da_cap_co_so,X.thieu_quy_doi,
            CASE
                WHEN ISNULL(X.thieu_quy_doi,0)>0 AND ISNULL(X.da_cap_co_so,0)>0 THEN CAST(1 AS TINYINT)
                WHEN ISNULL(X.thieu_quy_doi,0)>0 THEN CAST(0 AS TINYINT)
                WHEN ISNULL(X.da_cap_co_so,0)<=0 THEN CAST(0 AS TINYINT)
                WHEN ISNULL(X.da_cap_co_so,0)<ISNULL(X.tong_co_so,0) THEN CAST(1 AS TINYINT)
                ELSE CAST(2 AS TINYINT)
            END AS trang_thai_cap
        FROM dbo.QL_VaoVien V
        INNER JOIN dbo.QL_BenhNhan B
          ON B.IDCSKCB=V.IDCSKCB AND B.ID=V.IDBenhNhan
        LEFT JOIN dbo.DM_GioiTinh GT ON GT.ID=B.IDGioiTinh
        INNER JOIN dbo.QL_ThuTien T
          ON T.IDCSKCB=V.IDCSKCB AND T.IDVaoVien=V.ID
        CROSS APPLY
        (
            SELECT
                COUNT_BIG(*) AS tong_dong,
                SUM(CASE WHEN Q.HeSoQuyDoi IS NOT NULL THEN TT.SoLuong*Q.HeSoQuyDoi ELSE 0 END) AS tong_co_so,
                SUM(ISNULL(CAP.da_cap,0)) AS da_cap_co_so,
                SUM(CASE WHEN Q.HeSoQuyDoi IS NULL THEN 1 ELSE 0 END) AS thieu_quy_doi
            FROM dbo.QL_ToaThuoc_CT TT
            INNER JOIN dbo.QL_ThuTien_CT PAY
              ON PAY.IDCSKCB=TT.IDCSKCB
             AND PAY.IDThuTien=T.ID
             AND PAY.IDToaThuocCT=TT.ID
             AND ISNULL(PAY.DaThu,0)=1
            INNER JOIN dbo.DM_Thuoc M
              ON M.IDCSKCB=TT.IDCSKCB AND M.ID=TT.IDThuoc
            LEFT JOIN dbo.DM_Thuoc_DonViQuyDoi Q
              ON Q.IDCSKCB=TT.IDCSKCB
             AND Q.IDThuoc=TT.IDThuoc
             AND Q.IDDonViTinh=COALESCE(TT.IDDonViTinhDung,M.IDDonViTinh)
             AND Q.Active=1
            OUTER APPLY
            (
                SELECT SUM(XCT.SoLuongCoSo-ISNULL(XCT.SoLuongDaHoan,0)) AS da_cap
                FROM dbo.QL_Kho_Xuat_CT XCT
                INNER JOIN dbo.QL_Kho_Xuat XH
                  ON XH.IDCSKCB=XCT.IDCSKCB AND XH.ID=XCT.IDXuat AND XH.DaHuy=0
                WHERE XCT.IDCSKCB=TT.IDCSKCB AND XCT.IDToaThuocCT=TT.ID
            ) CAP
            WHERE TT.IDCSKCB=V.IDCSKCB
              AND TT.IDVaoVien=V.ID
              AND TT.Active=1
              AND (@LoaiToa IS NULL OR LOWER(TT.MaLoaiToaThuoc)=@LoaiToa)
        ) X
        WHERE V.IDCSKCB=@IDCSKCB
          AND V.Active=1
          /* Cấp phát chỉ nhận lượt đã Khám xong; STO xuất cũng chặn cùng điều kiện. */
          AND V.TrangThaiKham=2
          AND X.tong_dong>0
          AND (@TuNgay IS NULL OR CONVERT(DATE,COALESCE(T.NgayGioThu,V.NgayGioVaoVien))>=@TuNgay)
          AND (@DenNgay IS NULL OR CONVERT(DATE,COALESCE(T.NgayGioThu,V.NgayGioVaoVien))<=@DenNgay)
          AND
          (
              @TuKhoa IS NULL
              OR B.MaBN LIKE N'%'+@TuKhoa+N'%'
              OR B.HoTen LIKE N'%'+@TuKhoa+N'%'
              OR V.MaVaoVien LIKE N'%'+@TuKhoa+N'%'
              OR ISNULL(T.SoPhieu,N'') LIKE N'%'+@TuKhoa+N'%'
          )
    ),
    F AS
    (
        SELECT *
        FROM D
        WHERE
            (
                @TrangThaiCsv IS NOT NULL
                AND CHARINDEX(
                    N',' + CONVERT(NVARCHAR(3),trang_thai_cap) + N',',
                    N',' + @TrangThaiCsv + N','
                ) > 0
            )
            OR
            (
                @TrangThaiCsv IS NULL
                AND (@TrangThai IS NULL OR trang_thai_cap=@TrangThai)
            )
    )
    SELECT F.*,COUNT(*) OVER() AS tong_so
    FROM F
    ORDER BY CASE trang_thai_cap WHEN 0 THEN 0 WHEN 1 THEN 1 ELSE 2 END,ngay_gio_thu DESC,id_vao_vien DESC
    OFFSET (@Trang-1)*@KichThuocTrang ROWS
    FETCH NEXT @KichThuocTrang ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_Xuat_ChiTiet
    @IDCSKCB BIGINT,
    @IDKho BIGINT,
    @IDVaoVien BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        V.ID AS id_vao_vien,V.MaVaoVien AS ma_vao_vien,
        B.MaBN AS ma_bn,B.HoTen AS ho_ten,B.NgaySinh AS ngay_sinh,
        GT.TenGioiTinh AS gioi_tinh,B.DiaChi AS dia_chi,
        T.SoPhieu AS so_phieu_thu,T.NgayGioThu AS ngay_gio_thu
    FROM dbo.QL_VaoVien V
    INNER JOIN dbo.QL_BenhNhan B ON B.IDCSKCB=V.IDCSKCB AND B.ID=V.IDBenhNhan
    LEFT JOIN dbo.DM_GioiTinh GT ON GT.ID=B.IDGioiTinh
    INNER JOIN dbo.QL_ThuTien T ON T.IDCSKCB=V.IDCSKCB AND T.IDVaoVien=V.ID
    WHERE V.IDCSKCB=@IDCSKCB
      AND V.ID=@IDVaoVien
      AND V.Active=1
      AND V.TrangThaiKham=2
      AND EXISTS
      (
          SELECT 1
          FROM dbo.QL_ThuTien_CT PAY
          WHERE PAY.IDCSKCB=T.IDCSKCB
            AND PAY.IDThuTien=T.ID
            AND PAY.IDToaThuocCT IS NOT NULL
            AND ISNULL(PAY.DaThu,0)=1
      );

    SELECT
        TT.ID AS id_toa_thuoc_ct,
        TT.IDThuoc AS id_thuoc,
        TT.MaLoaiToaThuoc AS ma_loai_toa_thuoc,
        TT.NgayKe AS ngay_ke,
        M.MaThuoc AS ma_thuoc,
        M.TenThuoc AS ten_thuoc,
        M.HamLuong AS ham_luong,
        COALESCE(DVTD.TenDVT,DVT.TenDVT,M.DonViTinh) AS don_vi_tinh,
        COALESCE(TT.IDDonViTinhDung,M.IDDonViTinh) AS id_don_vi_tinh,
        TT.SoLuong AS so_luong_ke,
        TT.DonGia AS don_gia,
        TT.SoNgay AS so_ngay,
        TT.Sang AS sang,
        TT.Trua AS trua,
        TT.Chieu AS chieu,
        TT.Toi AS toi,
        TT.LieuDung AS lieu_dung,
        TT.CachDung AS cach_dung,
        COALESCE(NULLIF(TT.HoatChat,N''),M.HoatChat) AS hoat_chat,
        G.TenNhomHang AS nhom_hang,
        NV.HoTen AS bac_si_ke,
        K.TenKho AS kho_xuat,
        Q.HeSoQuyDoi AS he_so_quy_doi,
        CAST(CASE WHEN Q.HeSoQuyDoi IS NULL THEN 0 ELSE 1 END AS BIT) AS co_quy_doi,
        CASE WHEN Q.HeSoQuyDoi IS NULL THEN NULL ELSE TT.SoLuong*Q.HeSoQuyDoi END AS so_luong_ke_co_so,
        ISNULL(CAP.da_cap,0) AS da_cap_co_so,
        CASE
            WHEN Q.HeSoQuyDoi IS NULL THEN NULL
            WHEN TT.SoLuong*Q.HeSoQuyDoi-ISNULL(CAP.da_cap,0)<0 THEN 0
            ELSE TT.SoLuong*Q.HeSoQuyDoi-ISNULL(CAP.da_cap,0)
        END AS con_lai_co_so,
        CASE WHEN Q.HeSoQuyDoi>0 THEN
            (CASE WHEN TT.SoLuong*Q.HeSoQuyDoi-ISNULL(CAP.da_cap,0)<0 THEN 0 ELSE TT.SoLuong*Q.HeSoQuyDoi-ISNULL(CAP.da_cap,0) END)/Q.HeSoQuyDoi
            ELSE NULL END AS con_lai,
        ISNULL(TON.ton,0) AS ton_co_so,
        CASE WHEN Q.HeSoQuyDoi>0 THEN ISNULL(TON.ton,0)/Q.HeSoQuyDoi ELSE NULL END AS ton_theo_dvt,
        TON.han_gan_nhat
    FROM dbo.QL_ToaThuoc_CT TT
    INNER JOIN dbo.QL_ThuTien T
      ON T.IDCSKCB=TT.IDCSKCB AND T.IDVaoVien=TT.IDVaoVien
    INNER JOIN dbo.QL_ThuTien_CT PAY
      ON PAY.IDCSKCB=TT.IDCSKCB
     AND PAY.IDThuTien=T.ID
     AND PAY.IDToaThuocCT=TT.ID
     AND ISNULL(PAY.DaThu,0)=1
    INNER JOIN dbo.DM_Thuoc M ON M.IDCSKCB=TT.IDCSKCB AND M.ID=TT.IDThuoc
    LEFT JOIN dbo.DM_DonViTinh DVT ON DVT.IDCSKCB=M.IDCSKCB AND DVT.ID=M.IDDonViTinh
    LEFT JOIN dbo.DM_DonViTinh DVTD ON DVTD.IDCSKCB=TT.IDCSKCB AND DVTD.ID=TT.IDDonViTinhDung
    LEFT JOIN dbo.DM_NhomHang G ON G.IDCSKCB=M.IDCSKCB AND G.ID=M.IDNhomHang AND G.Active=1
    LEFT JOIN dbo.DM_NhanVien NV ON NV.ID=TT.IDBacSiKe
    LEFT JOIN dbo.DM_Kho K ON K.IDCSKCB=@IDCSKCB AND K.ID=@IDKho AND K.Active=1
    LEFT JOIN dbo.DM_Thuoc_DonViQuyDoi Q
      ON Q.IDCSKCB=TT.IDCSKCB
     AND Q.IDThuoc=TT.IDThuoc
     AND Q.IDDonViTinh=COALESCE(TT.IDDonViTinhDung,M.IDDonViTinh)
     AND Q.Active=1
    OUTER APPLY
    (
        SELECT SUM(XCT.SoLuongCoSo-ISNULL(XCT.SoLuongDaHoan,0)) AS da_cap
        FROM dbo.QL_Kho_Xuat_CT XCT
        INNER JOIN dbo.QL_Kho_Xuat XH
          ON XH.IDCSKCB=XCT.IDCSKCB AND XH.ID=XCT.IDXuat AND XH.DaHuy=0
        WHERE XCT.IDCSKCB=TT.IDCSKCB AND XCT.IDToaThuocCT=TT.ID
    ) CAP
    OUTER APPLY
    (
        SELECT SUM(L.SoLuongTon) AS ton,MIN(CASE WHEN L.SoLuongTon>0 THEN L.HanDung END) AS han_gan_nhat
        FROM dbo.QL_Kho_LoThuoc L
        WHERE L.IDCSKCB=@IDCSKCB
          AND L.IDKho=@IDKho
          AND L.IDThuoc=TT.IDThuoc
          AND L.Active=1
          AND (L.HanDung IS NULL OR L.HanDung>=CONVERT(DATE,SYSDATETIME()))
    ) TON
    WHERE TT.IDCSKCB=@IDCSKCB AND TT.IDVaoVien=@IDVaoVien AND TT.Active=1
    ORDER BY LOWER(TT.MaLoaiToaThuoc),ISNULL(TT.ThuTu,999),TT.ID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_Xuat_TheoToa
    @IDCSKCB BIGINT,
    @IDKho BIGINT,
    @IDVaoVien BIGINT,
    @IDNhanVienXuat BIGINT,
    @DanhSachJson NVARCHAR(MAX),
    @GhiChu NVARCHAR(500)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS(SELECT 1 FROM dbo.DM_Kho WHERE IDCSKCB=@IDCSKCB AND ID=@IDKho AND Active=1)
            THROW 58200,N'Kho không hợp lệ.',1;
        IF @IDNhanVienXuat<=0
            THROW 58200,N'Không xác định được nhân viên xuất kho.',1;
        /* Khóa master lượt khám để không race với hủy thu / chỉnh khám / hoàn kho. */
        DECLARE @VisitState TINYINT;
        SELECT @VisitState=V.TrangThaiKham
        FROM dbo.QL_VaoVien V WITH(UPDLOCK,HOLDLOCK)
        WHERE V.IDCSKCB=@IDCSKCB AND V.ID=@IDVaoVien AND V.Active=1;

        IF @VisitState<>2
            THROW 58200,N'Lượt khám chưa ở trạng thái Khám xong.',1;

        DECLARE @IDThuTien BIGINT;
        SELECT @IDThuTien=T.ID
        FROM dbo.QL_ThuTien T WITH(UPDLOCK,HOLDLOCK)
        WHERE T.IDCSKCB=@IDCSKCB AND T.IDVaoVien=@IDVaoVien;

        IF @IDThuTien IS NULL
            THROW 58200,N'Lượt khám chưa phát sinh thanh toán toa thuốc.',1;

        IF ISJSON(@DanhSachJson)<>1
            THROW 58200,N'Danh sách cấp thuốc không hợp lệ.',1;

        DECLARE @YeuCau TABLE
        (
            STT INT IDENTITY(1,1) PRIMARY KEY,
            IDToaThuocCT BIGINT NOT NULL,
            SoLuongCap DECIMAL(18,4) NOT NULL,
            IDThuoc BIGINT NULL,
            HeSo DECIMAL(18,6) NULL,
            SoLuongCoSo DECIMAL(18,4) NULL,
            ConLaiCoSo DECIMAL(18,4) NULL
        );

        INSERT @YeuCau(IDToaThuocCT,SoLuongCap)
        SELECT J.IDToaThuocCT,SUM(J.SoLuongCap)
        FROM OPENJSON(@DanhSachJson)
        WITH
        (
            IDToaThuocCT BIGINT '$.id_toa_thuoc_ct',
            SoLuongCap DECIMAL(18,4) '$.so_luong_cap'
        ) J
        WHERE J.IDToaThuocCT IS NOT NULL AND ISNULL(J.SoLuongCap,0)>0
        GROUP BY J.IDToaThuocCT;

        IF NOT EXISTS(SELECT 1 FROM @YeuCau)
            THROW 58200,N'Chưa chọn số lượng thuốc cần cấp.',1;

        IF EXISTS
        (
            SELECT 1
            FROM @YeuCau Y
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM dbo.QL_ThuTien_CT PAY WITH(UPDLOCK,HOLDLOCK)
                WHERE PAY.IDCSKCB=@IDCSKCB
                  AND PAY.IDThuTien=@IDThuTien
                  AND PAY.IDToaThuocCT=Y.IDToaThuocCT
                  AND ISNULL(PAY.DaThu,0)=1
            )
        )
            THROW 58200,N'Chỉ được cấp các dòng thuốc đã thu tiền.',1;

        UPDATE Y
        SET IDThuoc=TT.IDThuoc,
            HeSo=Q.HeSoQuyDoi,
            SoLuongCoSo=Y.SoLuongCap*Q.HeSoQuyDoi,
            ConLaiCoSo=TT.SoLuong*Q.HeSoQuyDoi-ISNULL(CAP.da_cap,0)
        FROM @YeuCau Y
        INNER JOIN dbo.QL_ToaThuoc_CT TT
          ON TT.IDCSKCB=@IDCSKCB AND TT.ID=Y.IDToaThuocCT AND TT.IDVaoVien=@IDVaoVien AND TT.Active=1
        INNER JOIN dbo.DM_Thuoc M
          ON M.IDCSKCB=TT.IDCSKCB AND M.ID=TT.IDThuoc
        INNER JOIN dbo.DM_Thuoc_DonViQuyDoi Q
          ON Q.IDCSKCB=TT.IDCSKCB
         AND Q.IDThuoc=TT.IDThuoc
         AND Q.IDDonViTinh=COALESCE(TT.IDDonViTinhDung,M.IDDonViTinh)
         AND Q.Active=1
        OUTER APPLY
        (
            SELECT SUM(XCT.SoLuongCoSo-ISNULL(XCT.SoLuongDaHoan,0)) AS da_cap
            FROM dbo.QL_Kho_Xuat_CT XCT
            INNER JOIN dbo.QL_Kho_Xuat XH
              ON XH.IDCSKCB=XCT.IDCSKCB AND XH.ID=XCT.IDXuat AND XH.DaHuy=0
            WHERE XCT.IDCSKCB=TT.IDCSKCB AND XCT.IDToaThuocCT=TT.ID
        ) CAP;

        IF EXISTS(SELECT 1 FROM @YeuCau WHERE IDThuoc IS NULL OR HeSo IS NULL OR SoLuongCoSo IS NULL)
            THROW 58200,N'Có dòng toa không hợp lệ hoặc chưa cấu hình quy đổi đơn vị.',1;
        IF EXISTS(SELECT 1 FROM @YeuCau WHERE SoLuongCoSo>ConLaiCoSo+0.0001)
            THROW 58200,N'Số lượng cấp vượt quá số lượng còn lại của toa.',1;

        IF EXISTS
        (
            SELECT 1
            FROM @YeuCau Y
            OUTER APPLY
            (
                SELECT SUM(L.SoLuongTon) AS ton
                FROM dbo.QL_Kho_LoThuoc L WITH(UPDLOCK,HOLDLOCK)
                WHERE L.IDCSKCB=@IDCSKCB
                  AND L.IDKho=@IDKho
                  AND L.IDThuoc=Y.IDThuoc
                  AND L.Active=1
                  AND (L.HanDung IS NULL OR L.HanDung>=CONVERT(DATE,SYSDATETIME()))
            ) T
            WHERE ISNULL(T.ton,0)<Y.SoLuongCoSo
        )
            THROW 58200,N'Tồn kho không đủ để cấp số lượng đã chọn.',1;

        DECLARE @Seq BIGINT=NEXT VALUE FOR dbo.SEQ_SoPhieuXuatKho;
        DECLARE @SoPhieu NVARCHAR(30)=N'XK'+CONVERT(CHAR(8),SYSDATETIME(),112)+RIGHT(N'00000000'+CONVERT(NVARCHAR(20),@Seq),8);

        INSERT dbo.QL_Kho_Xuat(IDCSKCB,IDKho,IDVaoVien,SoPhieu,NgayXuat,IDNhanVienXuat,TongGiaVon,GhiChu,DaHuy)
        VALUES(@IDCSKCB,@IDKho,@IDVaoVien,@SoPhieu,SYSDATETIME(),@IDNhanVienXuat,0,NULLIF(LTRIM(RTRIM(@GhiChu)),N''),0);

        DECLARE @IDXuat BIGINT=SCOPE_IDENTITY();
        DECLARE @STT INT,@IDToa BIGINT,@IDThuoc BIGINT,@CanCap DECIMAL(18,4);
        DECLARE yc CURSOR LOCAL FAST_FORWARD FOR
            SELECT STT,IDToaThuocCT,IDThuoc,SoLuongCoSo FROM @YeuCau ORDER BY STT;

        OPEN yc;
        FETCH NEXT FROM yc INTO @STT,@IDToa,@IDThuoc,@CanCap;
        WHILE @@FETCH_STATUS=0
        BEGIN
            WHILE @CanCap>0.0001
            BEGIN
                DECLARE @IDLo BIGINT,@TonLo DECIMAL(18,4),@GiaVon DECIMAL(18,4);
                SET @IDLo=NULL;
                SET @TonLo=NULL;
                SET @GiaVon=NULL;
                SELECT TOP(1)
                    @IDLo=L.ID,@TonLo=L.SoLuongTon,@GiaVon=L.GiaNhap
                FROM dbo.QL_Kho_LoThuoc L WITH(UPDLOCK,HOLDLOCK)
                WHERE L.IDCSKCB=@IDCSKCB
                  AND L.IDKho=@IDKho
                  AND L.IDThuoc=@IDThuoc
                  AND L.Active=1
                  AND L.SoLuongTon>0
                  AND (L.HanDung IS NULL OR L.HanDung>=CONVERT(DATE,SYSDATETIME()))
                ORDER BY CASE WHEN L.HanDung IS NULL THEN 1 ELSE 0 END,L.HanDung,L.NgayNhap,L.ID;

                IF @IDLo IS NULL
                    THROW 58200,N'Không còn lô thuốc hợp lệ để xuất.',1;

                DECLARE @Lay DECIMAL(18,4)=CASE WHEN @TonLo>=@CanCap THEN @CanCap ELSE @TonLo END;

                UPDATE dbo.QL_Kho_LoThuoc
                SET SoLuongTon=SoLuongTon-@Lay
                WHERE ID=@IDLo;

                INSERT dbo.QL_Kho_Xuat_CT(IDCSKCB,IDXuat,IDToaThuocCT,IDThuoc,IDLoThuoc,SoLuongCoSo,GiaVon,ThanhTien)
                VALUES(@IDCSKCB,@IDXuat,@IDToa,@IDThuoc,@IDLo,@Lay,@GiaVon,ROUND(@Lay*@GiaVon,2));

                SET @CanCap=@CanCap-@Lay;
            END;

            FETCH NEXT FROM yc INTO @STT,@IDToa,@IDThuoc,@CanCap;
        END;
        CLOSE yc;
        DEALLOCATE yc;

        UPDATE H
        SET TongGiaVon=X.Tong
        FROM dbo.QL_Kho_Xuat H
        CROSS APPLY
        (
            SELECT ISNULL(SUM(ThanhTien),0) AS Tong
            FROM dbo.QL_Kho_Xuat_CT C
            WHERE C.IDCSKCB=@IDCSKCB AND C.IDXuat=H.ID
        ) X
        WHERE H.IDCSKCB=@IDCSKCB AND H.ID=@IDXuat;

        COMMIT;
        SELECT 200 AS Status,N'Xuất thuốc thành công.' AS Message,@IDXuat AS IDXuat,@SoPhieu AS SoPhieu;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local','yc')>=-1
        BEGIN
            IF CURSOR_STATUS('local','yc')> -1 CLOSE yc;
            DEALLOCATE yc;
        END;
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 400 AS Status,ERROR_MESSAGE() AS Message,CAST(NULL AS BIGINT) AS IDXuat,CAST(NULL AS NVARCHAR(30)) AS SoPhieu;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_Xuat_Hoan
    @IDCSKCB BIGINT,
    @IDVaoVien BIGINT,
    @IDNhanVienHoan BIGINT,
    @LyDo NVARCHAR(500)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @LyDo=COALESCE(NULLIF(LTRIM(RTRIM(@LyDo)),N''),N'Hoàn thuốc về kho');

    BEGIN TRY
        BEGIN TRAN;

        IF @IDNhanVienHoan<=0
            THROW 58200,N'Không xác định được nhân viên hoàn kho.',1;

        /* Cùng khóa master với Thu ngân và Xuất thuốc. */
        DECLARE @VisitLock BIGINT;
        SELECT @VisitLock=ID
        FROM dbo.QL_VaoVien WITH(UPDLOCK,HOLDLOCK)
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien AND Active=1;
        IF @VisitLock IS NULL
            THROW 58200,N'Không tìm thấy lượt khám.',1;

        DECLARE @Xuat TABLE(ID BIGINT PRIMARY KEY);
        INSERT @Xuat(ID)
        SELECT X.ID
        FROM dbo.QL_Kho_Xuat X WITH(UPDLOCK,HOLDLOCK)
        WHERE X.IDCSKCB=@IDCSKCB
          AND X.IDVaoVien=@IDVaoVien
          AND X.DaHuy=0;

        IF NOT EXISTS(SELECT 1 FROM @Xuat)
            THROW 58200,N'Lượt khám chưa có thuốc đã cấp để hoàn kho.',1;

        /* Khóa các lô trước khi cộng trả để tránh va chạm với một lượt xuất đồng thời.
           Ghi ID vào table variable để không phát sinh result-set phụ cho controller. */
        DECLARE @LoBiKhoa TABLE(ID BIGINT PRIMARY KEY);
        INSERT @LoBiKhoa(ID)
        SELECT L.ID
        FROM dbo.QL_Kho_LoThuoc L WITH(UPDLOCK,HOLDLOCK)
        WHERE EXISTS
        (
            SELECT 1
            FROM dbo.QL_Kho_Xuat_CT CT
            INNER JOIN @Xuat X ON X.ID=CT.IDXuat
            WHERE CT.IDCSKCB=@IDCSKCB AND CT.IDLoThuoc=L.ID
        );

        ;WITH R AS
        (
            SELECT CT.IDLoThuoc,SUM(CT.SoLuongCoSo) AS SoLuongHoan
            FROM dbo.QL_Kho_Xuat_CT CT
            INNER JOIN @Xuat X ON X.ID=CT.IDXuat
            WHERE CT.IDCSKCB=@IDCSKCB
            GROUP BY CT.IDLoThuoc
        )
        UPDATE L
        SET L.SoLuongTon=L.SoLuongTon+R.SoLuongHoan
        FROM dbo.QL_Kho_LoThuoc L
        INNER JOIN R ON R.IDLoThuoc=L.ID;

        DECLARE @DongHoan NVARCHAR(500)=LEFT(
            N'[Hoàn kho '+CONVERT(NVARCHAR(19),SYSDATETIME(),120)+
            N' - NV '+CONVERT(NVARCHAR(30),@IDNhanVienHoan)+N'] '+@LyDo,
            500
        );

        UPDATE H
        SET DaHuy=1,
            GhiChu=LEFT(CASE
                WHEN NULLIF(LTRIM(RTRIM(H.GhiChu)),N'') IS NULL THEN @DongHoan
                ELSE H.GhiChu+N' | '+@DongHoan
            END,500)
        FROM dbo.QL_Kho_Xuat H
        INNER JOIN @Xuat X ON X.ID=H.ID
        WHERE H.IDCSKCB=@IDCSKCB;

        COMMIT;
        SELECT 200 AS Status,N'Đã hoàn toàn bộ thuốc đã cấp về đúng lô.' AS Message,
               (SELECT COUNT(*) FROM @Xuat) AS SoPhieuHoan;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 400 AS Status,ERROR_MESSAGE() AS Message,0 AS SoPhieuHoan;
    END CATCH;
END;
GO


/* =========================================================
   KIỂM TRA TỒN KHO KHI BÁC SĨ KÊ TOA
   - Dùng kho hoạt động duy nhất/đầu tiên của CSKCB.
   - Chỉ tính lô còn hạn sử dụng.
   - Quy đổi tồn kho về đúng ĐVT bác sĩ đang kê.
   - Nếu cùng thuốc xuất hiện nhiều dòng thì cộng tổng nhu cầu
     trước khi kết luận đủ/thiếu.
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kham_KiemTraTonThuoc
    @IDCSKCB BIGINT,
    @DanhSachJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    IF ISJSON(@DanhSachJson)<>1
        THROW 58200,N'Danh sách thuốc kiểm tra tồn kho không hợp lệ.',1;

    DECLARE @IDKho BIGINT;
    SELECT TOP(1) @IDKho=ID
    FROM dbo.DM_Kho
    WHERE IDCSKCB=@IDCSKCB AND Active=1
    ORDER BY ID;

    DECLARE @YeuCau TABLE
    (
        RowIndex INT NOT NULL,
        IDThuoc BIGINT NOT NULL,
        IDDonViTinh BIGINT NULL,
        SoLuong DECIMAL(18,4) NOT NULL,
        HeSo DECIMAL(18,6) NULL
    );

    INSERT @YeuCau(RowIndex,IDThuoc,IDDonViTinh,SoLuong)
    SELECT
        J.RowIndex,
        J.IDThuoc,
        J.IDDonViTinh,
        CASE WHEN ISNULL(J.SoLuong,0)<0 THEN 0 ELSE ISNULL(J.SoLuong,0) END
    FROM OPENJSON(@DanhSachJson)
    WITH
    (
        RowIndex INT '$.row_index',
        IDThuoc BIGINT '$.id_thuoc',
        IDDonViTinh BIGINT '$.id_don_vi_tinh',
        SoLuong DECIMAL(18,4) '$.so_luong'
    ) J
    WHERE J.IDThuoc IS NOT NULL;

    UPDATE Y
    SET
        IDDonViTinh=COALESCE(Y.IDDonViTinh,M.IDDonViTinh),
        HeSo=CASE
            WHEN COALESCE(Y.IDDonViTinh,M.IDDonViTinh)=M.IDDonViTinh
                THEN COALESCE(Q.HeSoQuyDoi,CAST(1 AS DECIMAL(18,6)))
            ELSE Q.HeSoQuyDoi
        END
    FROM @YeuCau Y
    INNER JOIN dbo.DM_Thuoc M
      ON M.IDCSKCB=@IDCSKCB AND M.ID=Y.IDThuoc AND M.Active=1
    LEFT JOIN dbo.DM_Thuoc_DonViQuyDoi Q
      ON Q.IDCSKCB=@IDCSKCB
     AND Q.IDThuoc=Y.IDThuoc
     AND Q.IDDonViTinh=COALESCE(Y.IDDonViTinh,M.IDDonViTinh)
     AND Q.Active=1;

    ;WITH B AS
    (
        SELECT
            Y.RowIndex AS row_index,
            Y.IDThuoc AS id_thuoc,
            M.MaThuoc AS ma_thuoc,
            M.TenThuoc AS ten_thuoc,
            Y.IDDonViTinh AS id_don_vi_tinh,
            COALESCE(DVTD.TenDVT,DVT.TenDVT,M.DonViTinh) AS don_vi_tinh,
            Y.SoLuong AS so_luong_ke,
            Y.HeSo AS he_so_quy_doi,
            CASE WHEN Y.HeSo IS NULL OR Y.HeSo<=0 THEN NULL ELSE Y.SoLuong*Y.HeSo END AS can_co_so,
            CAST(CASE WHEN @IDKho IS NULL THEN 0 ELSE 1 END AS BIT) AS co_kho,
            CAST(CASE WHEN Y.HeSo IS NULL OR Y.HeSo<=0 THEN 0 ELSE 1 END AS BIT) AS co_quy_doi,
            ISNULL(TON.ton_co_so,0) AS ton_co_so
        FROM @YeuCau Y
        INNER JOIN dbo.DM_Thuoc M
          ON M.IDCSKCB=@IDCSKCB AND M.ID=Y.IDThuoc AND M.Active=1
        LEFT JOIN dbo.DM_DonViTinh DVT
          ON DVT.IDCSKCB=M.IDCSKCB AND DVT.ID=M.IDDonViTinh
        LEFT JOIN dbo.DM_DonViTinh DVTD
          ON DVTD.IDCSKCB=M.IDCSKCB AND DVTD.ID=Y.IDDonViTinh
        OUTER APPLY
        (
            SELECT SUM(L.SoLuongTon) AS ton_co_so
            FROM dbo.QL_Kho_LoThuoc L
            WHERE @IDKho IS NOT NULL
              AND L.IDCSKCB=@IDCSKCB
              AND L.IDKho=@IDKho
              AND L.IDThuoc=Y.IDThuoc
              AND L.Active=1
              AND L.SoLuongTon>0
              AND (L.HanDung IS NULL OR L.HanDung>=CONVERT(DATE,SYSDATETIME()))
        ) TON
    ),
    C AS
    (
        SELECT
            B.*,
            SUM(ISNULL(B.can_co_so,0)) OVER(PARTITION BY B.id_thuoc) AS tong_can_co_so
        FROM B
    )
    SELECT
        row_index,
        id_thuoc,
        ma_thuoc,
        ten_thuoc,
        id_don_vi_tinh,
        don_vi_tinh,
        so_luong_ke,
        he_so_quy_doi,
        co_kho,
        co_quy_doi,
        ton_co_so,
        CASE
            WHEN he_so_quy_doi IS NULL OR he_so_quy_doi<=0 THEN NULL
            ELSE ROUND(ton_co_so/he_so_quy_doi,3)
        END AS ton_theo_dvt,
        tong_can_co_so,
        CAST(CASE
            WHEN co_kho=0 OR co_quy_doi=0 THEN 0
            WHEN ton_co_so+0.0001>=tong_can_co_so THEN 1
            ELSE 0
        END AS BIT) AS du_ton
    FROM C
    ORDER BY row_index;
END;
GO

/* v94: hoàn theo từng dòng/số lượng; JSON rỗng là lối tắt hoàn toàn bộ. */
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_Xuat_Hoan
    @IDCSKCB BIGINT,
    @IDVaoVien BIGINT,
    @IDNhanVienHoan BIGINT,
    @LyDo NVARCHAR(500)=NULL,
    @DanhSachJson NVARCHAR(MAX)=N'[]'
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    SET @LyDo=COALESCE(NULLIF(LTRIM(RTRIM(@LyDo)),N''),N'Hoàn thuốc về kho');
    BEGIN TRY
        BEGIN TRAN;
        IF @IDNhanVienHoan<=0 THROW 58200,N'Không xác định được nhân viên hoàn kho.',1;
        IF ISJSON(@DanhSachJson)<>1 THROW 58200,N'Danh sách hoàn kho không hợp lệ.',1;

        DECLARE @VisitLock BIGINT;
        SELECT @VisitLock=ID FROM dbo.QL_VaoVien WITH(UPDLOCK,HOLDLOCK)
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien AND Active=1;
        IF @VisitLock IS NULL THROW 58200,N'Không tìm thấy lượt khám.',1;

        DECLARE @Y TABLE(STT INT IDENTITY PRIMARY KEY,IDToaThuocCT BIGINT NOT NULL,CanHoanCoSo DECIMAL(18,4) NULL);
        INSERT @Y(IDToaThuocCT,CanHoanCoSo)
        SELECT J.IDToaThuocCT,SUM(J.SoLuongHoan*Q.HeSoQuyDoi)
        FROM OPENJSON(@DanhSachJson) WITH(IDToaThuocCT BIGINT '$.id_toa_thuoc_ct',SoLuongHoan DECIMAL(18,4) '$.so_luong_hoan') J
        INNER JOIN dbo.QL_ToaThuoc_CT TT ON TT.IDCSKCB=@IDCSKCB AND TT.ID=J.IDToaThuocCT AND TT.IDVaoVien=@IDVaoVien
        INNER JOIN dbo.DM_Thuoc M ON M.IDCSKCB=TT.IDCSKCB AND M.ID=TT.IDThuoc
        INNER JOIN dbo.DM_Thuoc_DonViQuyDoi Q ON Q.IDCSKCB=TT.IDCSKCB AND Q.IDThuoc=TT.IDThuoc
          AND Q.IDDonViTinh=COALESCE(TT.IDDonViTinhDung,M.IDDonViTinh) AND Q.Active=1
        WHERE ISNULL(J.SoLuongHoan,0)>0
        GROUP BY J.IDToaThuocCT;

        IF NOT EXISTS(SELECT 1 FROM @Y)
            INSERT @Y(IDToaThuocCT,CanHoanCoSo)
            SELECT CT.IDToaThuocCT,SUM(CT.SoLuongCoSo-ISNULL(CT.SoLuongDaHoan,0))
            FROM dbo.QL_Kho_Xuat_CT CT
            INNER JOIN dbo.QL_Kho_Xuat X ON X.IDCSKCB=CT.IDCSKCB AND X.ID=CT.IDXuat AND X.DaHuy=0
            WHERE X.IDCSKCB=@IDCSKCB AND X.IDVaoVien=@IDVaoVien
            GROUP BY CT.IDToaThuocCT
            HAVING SUM(CT.SoLuongCoSo-ISNULL(CT.SoLuongDaHoan,0))>0;

        IF NOT EXISTS(SELECT 1 FROM @Y) THROW 58200,N'Lượt khám chưa có thuốc đã cấp để hoàn kho.',1;
        IF EXISTS
        (
            SELECT 1 FROM @Y Y OUTER APPLY
            (SELECT SUM(CT.SoLuongCoSo-ISNULL(CT.SoLuongDaHoan,0)) ConLai
             FROM dbo.QL_Kho_Xuat_CT CT INNER JOIN dbo.QL_Kho_Xuat X ON X.IDCSKCB=CT.IDCSKCB AND X.ID=CT.IDXuat AND X.DaHuy=0
             WHERE X.IDCSKCB=@IDCSKCB AND X.IDVaoVien=@IDVaoVien AND CT.IDToaThuocCT=Y.IDToaThuocCT) R
            WHERE Y.CanHoanCoSo IS NULL OR Y.CanHoanCoSo<=0 OR Y.CanHoanCoSo>ISNULL(R.ConLai,0)+0.0001
        ) THROW 58200,N'Số lượng hoàn vượt số lượng đã cấp còn có thể hoàn.',1;

        DECLARE @Seq BIGINT=NEXT VALUE FOR dbo.SEQ_SoPhieuHoanKho;
        DECLARE @SoPhieu NVARCHAR(30)=N'HK'+CONVERT(CHAR(8),SYSDATETIME(),112)+RIGHT(N'00000000'+CONVERT(NVARCHAR(20),@Seq),8);
        INSERT dbo.QL_Kho_Hoan(IDCSKCB,IDVaoVien,SoPhieu,NgayHoan,IDNhanVienHoan,LyDo)
        VALUES(@IDCSKCB,@IDVaoVien,@SoPhieu,SYSDATETIME(),@IDNhanVienHoan,@LyDo);
        DECLARE @IDHoan BIGINT=SCOPE_IDENTITY(),@STT INT,@IDToa BIGINT,@CanHoan DECIMAL(18,4);
        DECLARE hc CURSOR LOCAL FAST_FORWARD FOR SELECT STT,IDToaThuocCT,CanHoanCoSo FROM @Y ORDER BY STT;
        OPEN hc; FETCH NEXT FROM hc INTO @STT,@IDToa,@CanHoan;
        WHILE @@FETCH_STATUS=0
        BEGIN
            WHILE @CanHoan>0.0001
            BEGIN
                DECLARE @IDXuatCT BIGINT,@IDLo BIGINT,@ConLai DECIMAL(18,4);
                SET @IDXuatCT=NULL;
                SELECT TOP(1) @IDXuatCT=CT.ID,@IDLo=CT.IDLoThuoc,@ConLai=CT.SoLuongCoSo-ISNULL(CT.SoLuongDaHoan,0)
                FROM dbo.QL_Kho_Xuat_CT CT WITH(UPDLOCK,HOLDLOCK)
                INNER JOIN dbo.QL_Kho_Xuat X ON X.IDCSKCB=CT.IDCSKCB AND X.ID=CT.IDXuat AND X.DaHuy=0
                WHERE X.IDCSKCB=@IDCSKCB AND X.IDVaoVien=@IDVaoVien AND CT.IDToaThuocCT=@IDToa
                  AND CT.SoLuongCoSo-ISNULL(CT.SoLuongDaHoan,0)>0
                ORDER BY X.NgayXuat DESC,CT.ID DESC;
                IF @IDXuatCT IS NULL THROW 58200,N'Không còn dòng xuất phù hợp để hoàn.',1;
                DECLARE @Tra DECIMAL(18,4)=CASE WHEN @ConLai>=@CanHoan THEN @CanHoan ELSE @ConLai END;
                UPDATE dbo.QL_Kho_Xuat_CT SET SoLuongDaHoan=SoLuongDaHoan+@Tra WHERE ID=@IDXuatCT;
                UPDATE dbo.QL_Kho_LoThuoc SET SoLuongTon=SoLuongTon+@Tra WHERE ID=@IDLo;
                INSERT dbo.QL_Kho_Hoan_CT(IDHoan,IDXuatCT,SoLuongCoSo) VALUES(@IDHoan,@IDXuatCT,@Tra);
                SET @CanHoan=@CanHoan-@Tra;
            END;
            FETCH NEXT FROM hc INTO @STT,@IDToa,@CanHoan;
        END;
        CLOSE hc; DEALLOCATE hc;

        UPDATE X SET DaHuy=1,GhiChu=LEFT(CASE WHEN NULLIF(LTRIM(RTRIM(X.GhiChu)),N'') IS NULL THEN N'' ELSE X.GhiChu+N' | ' END+
            N'[Đã hoàn đủ '+CONVERT(NVARCHAR(19),SYSDATETIME(),120)+N'] '+@LyDo,500)
        FROM dbo.QL_Kho_Xuat X
        WHERE X.IDCSKCB=@IDCSKCB AND X.IDVaoVien=@IDVaoVien AND X.DaHuy=0
          AND NOT EXISTS(SELECT 1 FROM dbo.QL_Kho_Xuat_CT CT WHERE CT.IDCSKCB=X.IDCSKCB AND CT.IDXuat=X.ID AND CT.SoLuongCoSo-ISNULL(CT.SoLuongDaHoan,0)>0.0001);

        COMMIT;
        SELECT 200 AS Status,N'Hoàn kho thành công.' AS Message,@IDHoan AS IDHoan,@SoPhieu AS SoPhieu;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local','hc')>=-1 BEGIN IF CURSOR_STATUS('local','hc')>-1 CLOSE hc; DEALLOCATE hc; END;
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 400 AS Status,ERROR_MESSAGE() AS Message,CAST(NULL AS BIGINT) AS IDHoan,CAST(NULL AS NVARCHAR(30)) AS SoPhieu;
    END CATCH;
END;
GO

IF OBJECT_ID(N'dbo.QL_Kho_DieuChinh',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.QL_Kho_DieuChinh
    (
        ID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_QL_Kho_DieuChinh PRIMARY KEY,
        IDCSKCB BIGINT NOT NULL, IDKho BIGINT NOT NULL, Loai VARCHAR(20) NOT NULL,
        SoPhieu NVARCHAR(30) NOT NULL, NgayGio DATETIME2(0) NOT NULL CONSTRAINT DF_QL_Kho_DieuChinh_Ngay DEFAULT(SYSDATETIME()),
        IDNhanVien BIGINT NOT NULL, LyDo NVARCHAR(500) NOT NULL,
        CONSTRAINT UQ_QL_Kho_DieuChinh_So UNIQUE(IDCSKCB,SoPhieu),
        CONSTRAINT UQ_QL_Kho_DieuChinh_CSKCB_ID UNIQUE(IDCSKCB,ID),
        CONSTRAINT CK_QL_Kho_DieuChinh_Loai CHECK(Loai IN('DIEU_CHINH','HUY_THUOC')),
        CONSTRAINT FK_QL_Kho_DieuChinh_Kho FOREIGN KEY(IDCSKCB,IDKho) REFERENCES dbo.DM_Kho(IDCSKCB,ID),
        CONSTRAINT FK_QL_Kho_DieuChinh_NV FOREIGN KEY(IDNhanVien) REFERENCES dbo.DM_NhanVien(ID)
    );
    CREATE INDEX IX_QL_Kho_DieuChinh_Ngay ON dbo.QL_Kho_DieuChinh(IDCSKCB,NgayGio DESC,ID DESC);
END;
GO

IF OBJECT_ID(N'dbo.QL_Kho_DieuChinh_CT',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.QL_Kho_DieuChinh_CT
    (
        ID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_QL_Kho_DieuChinh_CT PRIMARY KEY,
        IDCSKCB BIGINT NOT NULL, IDChungTu BIGINT NOT NULL, IDLoThuoc BIGINT NOT NULL,
        SoLuongThayDoi DECIMAL(18,4) NOT NULL, SoLuongTruoc DECIMAL(18,4) NOT NULL, SoLuongSau DECIMAL(18,4) NOT NULL,
        CONSTRAINT CK_QL_Kho_DieuChinh_CT_SL CHECK(SoLuongThayDoi<>0 AND SoLuongTruoc>=0 AND SoLuongSau>=0 AND SoLuongSau=SoLuongTruoc+SoLuongThayDoi),
        CONSTRAINT FK_QL_Kho_DieuChinh_CT_ChungTu FOREIGN KEY(IDCSKCB,IDChungTu) REFERENCES dbo.QL_Kho_DieuChinh(IDCSKCB,ID),
        CONSTRAINT FK_QL_Kho_DieuChinh_CT_Lo FOREIGN KEY(IDLoThuoc) REFERENCES dbo.QL_Kho_LoThuoc(ID)
    );
    CREATE INDEX IX_QL_Kho_DieuChinh_CT_Lo ON dbo.QL_Kho_DieuChinh_CT(IDLoThuoc,IDChungTu);
END;
GO

IF NOT EXISTS(SELECT 1 FROM sys.sequences WHERE schema_id=SCHEMA_ID(N'dbo') AND name=N'SEQ_SoPhieuDieuChinhKho')
    EXEC(N'CREATE SEQUENCE dbo.SEQ_SoPhieuDieuChinhKho AS BIGINT START WITH 1 INCREMENT BY 1;');
GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_LoThuoc_DanhSach
    @IDCSKCB BIGINT,@IDKho BIGINT=NULL,@IDThuoc BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    IF @IDKho IS NULL
        SELECT TOP(1) @IDKho=ID FROM dbo.DM_Kho WHERE IDCSKCB=@IDCSKCB AND Active=1 ORDER BY ID;
    SELECT L.ID AS id_lo_thuoc,L.SoLo AS so_lo,L.HanDung AS han_dung,L.SoLuongTon AS ton_vat_ly,
           CASE WHEN L.Active=1 AND (L.HanDung IS NULL OR L.HanDung>=CONVERT(DATE,SYSDATETIME())) THEN L.SoLuongTon ELSE 0 END AS ton_kha_dung,
           L.GiaNhap AS gia_nhap,L.NgayNhap AS ngay_nhap,L.Active AS active,
           CASE WHEN L.HanDung IS NOT NULL AND L.HanDung<CONVERT(DATE,SYSDATETIME()) THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS het_han
    FROM dbo.QL_Kho_LoThuoc L
    WHERE L.IDCSKCB=@IDCSKCB AND L.IDKho=@IDKho AND L.IDThuoc=@IDThuoc
      AND (L.Active=1 OR L.SoLuongTon>0)
    ORDER BY CASE WHEN L.HanDung IS NULL THEN 1 ELSE 0 END,L.HanDung,L.NgayNhap,L.ID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_DieuChinh_Luu
    @IDCSKCB BIGINT,@IDKho BIGINT=NULL,@Loai VARCHAR(20),@IDNhanVien BIGINT,
    @LyDo NVARCHAR(500)=NULL,@DanhSachJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    SET @Loai=UPPER(LTRIM(RTRIM(ISNULL(@Loai,'')))); SET @LyDo=COALESCE(NULLIF(LTRIM(RTRIM(@LyDo)),N''),CASE WHEN @Loai='HUY_THUOC' THEN N'Hủy thuốc' ELSE N'Điều chỉnh tồn kho' END);
    IF @IDKho IS NULL
        SELECT TOP(1) @IDKho=ID FROM dbo.DM_Kho WHERE IDCSKCB=@IDCSKCB AND Active=1 ORDER BY ID;
    BEGIN TRY
        BEGIN TRAN;
        IF @Loai NOT IN('DIEU_CHINH','HUY_THUOC') THROW 58200,N'Loại chứng từ kho không hợp lệ.',1;
        IF @IDNhanVien<=0 THROW 58200,N'Không xác định được nhân viên thực hiện.',1;
        IF NOT EXISTS(SELECT 1 FROM dbo.DM_Kho WHERE IDCSKCB=@IDCSKCB AND ID=@IDKho AND Active=1) THROW 58200,N'Kho không hợp lệ.',1;
        IF ISJSON(@DanhSachJson)<>1 THROW 58200,N'Danh sách lô thuốc không hợp lệ.',1;
        DECLARE @D TABLE(IDLo BIGINT PRIMARY KEY,ThayDoi DECIMAL(18,4) NOT NULL,Truoc DECIMAL(18,4) NULL,Sau DECIMAL(18,4) NULL);
        INSERT @D(IDLo,ThayDoi)
        SELECT J.IDLo,CASE WHEN @Loai='HUY_THUOC' THEN -ABS(SUM(J.SoLuong)) ELSE SUM(J.SoLuong) END
        FROM OPENJSON(@DanhSachJson) WITH(IDLo BIGINT '$.id_lo_thuoc',SoLuong DECIMAL(18,4) '$.so_luong') J
        WHERE J.IDLo IS NOT NULL AND ISNULL(J.SoLuong,0)<>0 GROUP BY J.IDLo;
        IF NOT EXISTS(SELECT 1 FROM @D) THROW 58200,N'Chưa nhập số lượng cần xử lý.',1;
        UPDATE D SET Truoc=L.SoLuongTon,Sau=L.SoLuongTon+D.ThayDoi
        FROM @D D INNER JOIN dbo.QL_Kho_LoThuoc L WITH(UPDLOCK,HOLDLOCK) ON L.ID=D.IDLo
        WHERE L.IDCSKCB=@IDCSKCB AND L.IDKho=@IDKho;
        IF EXISTS(SELECT 1 FROM @D WHERE Truoc IS NULL) THROW 58200,N'Có lô thuốc không thuộc kho hiện tại.',1;
        IF EXISTS(SELECT 1 FROM @D WHERE Sau<0) THROW 58200,N'Số lượng giảm vượt tồn vật lý của lô.',1;

        DECLARE @Seq BIGINT=NEXT VALUE FOR dbo.SEQ_SoPhieuDieuChinhKho;
        DECLARE @So NVARCHAR(30)=CASE WHEN @Loai='HUY_THUOC' THEN N'HT-' ELSE N'DC-' END+CONVERT(CHAR(8),SYSDATETIME(),112)+RIGHT(N'00000000'+CONVERT(NVARCHAR(20),@Seq),8);
        INSERT dbo.QL_Kho_DieuChinh(IDCSKCB,IDKho,Loai,SoPhieu,NgayGio,IDNhanVien,LyDo)
        VALUES(@IDCSKCB,@IDKho,@Loai,@So,SYSDATETIME(),@IDNhanVien,@LyDo);
        DECLARE @ID BIGINT=SCOPE_IDENTITY();
        INSERT dbo.QL_Kho_DieuChinh_CT(IDCSKCB,IDChungTu,IDLoThuoc,SoLuongThayDoi,SoLuongTruoc,SoLuongSau)
        SELECT @IDCSKCB,@ID,IDLo,ThayDoi,Truoc,Sau FROM @D;
        UPDATE L SET SoLuongTon=D.Sau FROM dbo.QL_Kho_LoThuoc L INNER JOIN @D D ON D.IDLo=L.ID;
        COMMIT;
        SELECT 200 AS Status,N'Đã ghi chứng từ kho.' AS Message,@ID AS IDChungTu,@So AS SoPhieu;
    END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; SELECT 400 AS Status,ERROR_MESSAGE() AS Message; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_DieuChinh_DanhSach
    @IDCSKCB BIGINT,@TuNgay DATE=NULL,@DenNgay DATE=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT H.ID AS id,H.SoPhieu AS so_phieu,H.Loai AS loai,H.NgayGio AS ngay_gio,NV.HoTen AS nguoi_lap,H.LyDo AS ly_do,
           COUNT(CT.ID) AS so_dong,SUM(CT.SoLuongThayDoi) AS tong_thay_doi
    FROM dbo.QL_Kho_DieuChinh H INNER JOIN dbo.DM_NhanVien NV ON NV.ID=H.IDNhanVien
    INNER JOIN dbo.QL_Kho_DieuChinh_CT CT ON CT.IDCSKCB=H.IDCSKCB AND CT.IDChungTu=H.ID
    WHERE H.IDCSKCB=@IDCSKCB AND (@TuNgay IS NULL OR H.NgayGio>=@TuNgay) AND (@DenNgay IS NULL OR H.NgayGio<DATEADD(DAY,1,@DenNgay))
    GROUP BY H.ID,H.SoPhieu,H.Loai,H.NgayGio,NV.HoTen,H.LyDo ORDER BY H.NgayGio DESC,H.ID DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_Nhap_DanhSach
    @IDCSKCB BIGINT,@TuNgay DATE=NULL,@DenNgay DATE=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT N.ID AS id,N.SoPhieu AS so_phieu,N.NgayNhap AS ngay_nhap,N.SoHoaDon AS so_hoa_don,N.NgayHoaDon AS ngay_hoa_don,
           NCC.TenNhaCungCap AS nha_cung_cap,N.TongTien AS tong_tien,N.DaHuy AS da_huy,N.LyDoHuy AS ly_do_huy,
           COALESCE(NV.HoTen,N'') AS nguoi_nhap,COUNT(CT.ID) AS so_dong
    FROM dbo.QL_Kho_Nhap N
    LEFT JOIN dbo.DM_NhaCungCap NCC ON NCC.IDCSKCB=N.IDCSKCB AND NCC.ID=N.IDNhaCungCap
    LEFT JOIN dbo.DM_NhanVien NV ON NV.ID=N.IDNhanVienNhap
    LEFT JOIN dbo.QL_Kho_Nhap_CT CT ON CT.IDCSKCB=N.IDCSKCB AND CT.IDNhap=N.ID
    WHERE N.IDCSKCB=@IDCSKCB AND (@TuNgay IS NULL OR N.NgayNhap>=@TuNgay) AND (@DenNgay IS NULL OR N.NgayNhap<DATEADD(DAY,1,@DenNgay))
    GROUP BY N.ID,N.SoPhieu,N.NgayNhap,N.SoHoaDon,N.NgayHoaDon,NCC.TenNhaCungCap,N.TongTien,N.DaHuy,N.LyDoHuy,NV.HoTen
    ORDER BY N.NgayNhap DESC,N.ID DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_Nhap_ChiTiet @IDCSKCB BIGINT,@IDNhap BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT N.ID AS id,N.SoPhieu AS so_phieu,N.NgayNhap AS ngay_nhap,N.SoHoaDon AS so_hoa_don,N.NgayHoaDon AS ngay_hoa_don,
           NCC.TenNhaCungCap AS nha_cung_cap,N.TongTien AS tong_tien,N.GhiChu AS ghi_chu,N.DaHuy AS da_huy,N.LyDoHuy AS ly_do_huy,
           N.NgayGioHuy AS ngay_gio_huy,COALESCE(NV.HoTen,N'') AS nguoi_nhap,COALESCE(NVH.HoTen,N'') AS nguoi_huy
    FROM dbo.QL_Kho_Nhap N LEFT JOIN dbo.DM_NhaCungCap NCC ON NCC.IDCSKCB=N.IDCSKCB AND NCC.ID=N.IDNhaCungCap
    LEFT JOIN dbo.DM_NhanVien NV ON NV.ID=N.IDNhanVienNhap LEFT JOIN dbo.DM_NhanVien NVH ON NVH.ID=N.IDNhanVienHuy
    WHERE N.IDCSKCB=@IDCSKCB AND N.ID=@IDNhap;
    SELECT CT.ID AS id,CT.IDThuoc AS id_thuoc,T.MaThuoc AS ma_thuoc,T.TenThuoc AS ten_thuoc,DVT.TenDVT AS don_vi_tinh,
           CT.SoLuong AS so_luong,CT.GiaNhap AS gia_nhap,CT.ThanhTien AS thanh_tien,CT.SoLo AS so_lo,CT.HanDung AS han_dung,
           L.SoLuongNhap AS so_luong_nhap_co_so,L.SoLuongTon AS so_luong_ton_co_so
    FROM dbo.QL_Kho_Nhap_CT CT INNER JOIN dbo.DM_Thuoc T ON T.IDCSKCB=CT.IDCSKCB AND T.ID=CT.IDThuoc
    LEFT JOIN dbo.DM_DonViTinh DVT ON DVT.IDCSKCB=CT.IDCSKCB AND DVT.ID=CT.IDDonViTinh
    INNER JOIN dbo.QL_Kho_LoThuoc L ON L.ID=CT.IDLoThuoc
    WHERE CT.IDCSKCB=@IDCSKCB AND CT.IDNhap=@IDNhap ORDER BY CT.ID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_Nhap_Huy
    @IDCSKCB BIGINT,@IDNhap BIGINT,@IDNhanVienHuy BIGINT,@LyDo NVARCHAR(500)=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON; SET @LyDo=COALESCE(NULLIF(LTRIM(RTRIM(@LyDo)),N''),N'Hủy phiếu nhập kho');
    BEGIN TRY
        BEGIN TRAN;
        IF @IDNhanVienHuy<=0 THROW 58100,N'Không xác định được nhân viên hủy.',1;
        IF NOT EXISTS(SELECT 1 FROM dbo.QL_Kho_Nhap WITH(UPDLOCK,HOLDLOCK) WHERE IDCSKCB=@IDCSKCB AND ID=@IDNhap AND DaHuy=0)
            THROW 58100,N'Phiếu nhập không tồn tại hoặc đã hủy.',1;
        IF EXISTS(SELECT 1 FROM dbo.QL_Kho_Nhap_CT CT INNER JOIN dbo.QL_Kho_LoThuoc L WITH(UPDLOCK,HOLDLOCK) ON L.ID=CT.IDLoThuoc
                  WHERE CT.IDCSKCB=@IDCSKCB AND CT.IDNhap=@IDNhap AND L.SoLuongTon<L.SoLuongNhap-0.0001)
            THROW 58100,N'Không thể hủy vì đã có thuốc của phiếu nhập được cấp hoặc điều chỉnh.',1;
        IF EXISTS(SELECT 1 FROM dbo.QL_Kho_Nhap_CT CT
                  WHERE CT.IDCSKCB=@IDCSKCB AND CT.IDNhap=@IDNhap
                    AND EXISTS(SELECT 1 FROM dbo.QL_Kho_Nhap_CT K INNER JOIN dbo.QL_Kho_Nhap N ON N.IDCSKCB=K.IDCSKCB AND N.ID=K.IDNhap AND N.DaHuy=0
                               WHERE K.IDLoThuoc=CT.IDLoThuoc AND K.IDNhap<>@IDNhap))
            THROW 58100,N'Phiếu legacy dùng chung lô với phiếu khác nên chỉ được xem, không thể hủy tự động.',1;
        UPDATE L SET SoLuongTon=0,Active=0 FROM dbo.QL_Kho_LoThuoc L INNER JOIN dbo.QL_Kho_Nhap_CT CT ON CT.IDLoThuoc=L.ID
        WHERE CT.IDCSKCB=@IDCSKCB AND CT.IDNhap=@IDNhap;
        UPDATE dbo.QL_Kho_Nhap SET DaHuy=1,NgayGioHuy=SYSDATETIME(),IDNhanVienHuy=@IDNhanVienHuy,LyDoHuy=@LyDo
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDNhap;
        COMMIT;
        SELECT 200 AS Status,N'Đã hủy phiếu nhập.' AS Message,@IDNhap AS IDNhap;
    END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; SELECT 400 AS Status,ERROR_MESSAGE() AS Message; END CATCH;
END;
GO

PRINT N'29_kho_nghiep_vu.sql: OK';
GO
