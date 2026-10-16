/* Run 59 + 60 + 61 in one transaction, with a verified native backup.
   The dedicated Invoke-KhoV114.ps1 runner locks all source tables and compares every column. */
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; SET XACT_ABORT ON;
IF DB_NAME()<>N'QLPM' OR @@TRANCOUNT=0 THROW 59114,'QLPM transaction required; use Invoke-KhoV114.ps1.',1;
GO
IF OBJECT_ID(N'dbo.QL_Kho_ChungTu',N'U') IS NULL
BEGIN
CREATE TABLE dbo.QL_Kho_ChungTu(
 [ID] bigint NOT NULL,
 [IDCSKCB] bigint NOT NULL,
 [LoaiChungTu] varchar(20) NOT NULL,
 [IDKho] bigint NULL,
 [SoPhieu] nvarchar(30) NOT NULL,
 [SoHoaDon] nvarchar(100) NULL,
 [NgayGio] datetime2(0) NOT NULL CONSTRAINT DF_QL_Kho_ChungTu_NgayGio DEFAULT(SYSDATETIME()),
 [IDNhanVien] bigint NULL,
 [TongTien] decimal(18,2) NULL,
 [GhiChu] nvarchar(500) NULL,
 [DaHuy] bit NOT NULL CONSTRAINT DF_QL_Kho_ChungTu_DaHuy DEFAULT(0),
 [IDNhaCungCap] bigint NULL,
 [NgayHoaDon] date NULL,
 [NgayGioHuy] datetime2(0) NULL,
 [IDNhanVienHuy] bigint NULL,
 [LyDoHuy] nvarchar(500) NULL,
 [TenNhaCungCapSnapshot] nvarchar(500) NULL,
 [IDTaiKhoan] bigint NULL,
 [TenNguoiThucHienSnapshot] nvarchar(200) NULL,
 [IDTaiKhoanHuy] bigint NULL,
 [TenNguoiHuySnapshot] nvarchar(200) NULL,
 [IDVaoVien] bigint NULL,
 [TongGiaVon] decimal(18,2) NULL,
 [LyDo] nvarchar(500) NULL,
 [IDChungTuHuy] bigint NULL,
 [LoaiNghiepVu] varchar(20) NOT NULL,
 CONSTRAINT PK_QL_Kho_ChungTu PRIMARY KEY(IDCSKCB,LoaiChungTu,ID),
 CONSTRAINT CK_QL_Kho_ChungTu_Loai CHECK(LoaiChungTu IN('NHAP','CAP_PHAT','HOAN','DIEU_CHINH')),
 CONSTRAINT CK_QL_Kho_ChungTu_NHAP_Required CHECK(LoaiChungTu<>'NHAP' OR ([IDKho] IS NOT NULL AND [SoPhieu] IS NOT NULL AND [NgayGio] IS NOT NULL AND [TongTien] IS NOT NULL AND [DaHuy] IS NOT NULL)),
 CONSTRAINT CK_QL_Kho_ChungTu_CAP_PHAT_Required CHECK(LoaiChungTu<>'CAP_PHAT' OR ([IDKho] IS NOT NULL AND [IDVaoVien] IS NOT NULL AND [SoPhieu] IS NOT NULL AND [NgayGio] IS NOT NULL AND [TongGiaVon] IS NOT NULL AND [DaHuy] IS NOT NULL)),
 CONSTRAINT CK_V114_CK_QL_Kho_Xuat_ActorSnapshot CHECK(LoaiChungTu<>'CAP_PHAT' OR ([IDTaiKhoan] IS NULL AND [TenNguoiThucHienSnapshot] IS NULL OR [IDTaiKhoan] IS NOT NULL AND nullif(ltrim(rtrim([TenNguoiThucHienSnapshot])),N'') IS NOT NULL)),
 CONSTRAINT CK_QL_Kho_ChungTu_HOAN_Required CHECK(LoaiChungTu<>'HOAN' OR ([IDVaoVien] IS NOT NULL AND [SoPhieu] IS NOT NULL AND [NgayGio] IS NOT NULL AND [LyDo] IS NOT NULL AND [LoaiNghiepVu] IS NOT NULL)),
 CONSTRAINT CK_V114_CK_QL_Kho_Hoan_Loai CHECK(LoaiChungTu<>'HOAN' OR ([LoaiNghiepVu]='NHAN_TRA' AND [IDChungTuHuy] IS NULL AND [IDNhanVien] IS NOT NULL OR [LoaiNghiepVu]='DAO_CAP_HUY_THU' AND [IDChungTuHuy] IS NOT NULL AND [IDTaiKhoan] IS NOT NULL)),
 CONSTRAINT CK_QL_Kho_ChungTu_DIEU_CHINH_Required CHECK(LoaiChungTu<>'DIEU_CHINH' OR ([IDKho] IS NOT NULL AND [LoaiNghiepVu] IS NOT NULL AND [SoPhieu] IS NOT NULL AND [NgayGio] IS NOT NULL AND [IDNhanVien] IS NOT NULL AND [LyDo] IS NOT NULL)),
 CONSTRAINT CK_V114_CK_QL_Kho_DieuChinh_Loai CHECK(LoaiChungTu<>'DIEU_CHINH' OR ([LoaiNghiepVu]='HUY_THUOC' OR [LoaiNghiepVu]='DIEU_CHINH')),
 CONSTRAINT CK_QL_Kho_ChungTu_NghiepVu CHECK((LoaiChungTu='NHAP' AND LoaiNghiepVu='NHAP') OR (LoaiChungTu='CAP_PHAT' AND LoaiNghiepVu='CAP_PHAT') OR (LoaiChungTu='HOAN' AND LoaiNghiepVu IN('NHAN_TRA','DAO_CAP_HUY_THU')) OR (LoaiChungTu='DIEU_CHINH' AND LoaiNghiepVu IN('DIEU_CHINH','HUY_THUOC')))
);
CREATE UNIQUE INDEX UX_QL_Kho_ChungTu_FamilyID ON dbo.QL_Kho_ChungTu(LoaiChungTu,ID);
END;
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.QL_Kho_ChungTu') AND name='UX_QL_Kho_ChungTu_SoPhieu')
CREATE UNIQUE INDEX UX_QL_Kho_ChungTu_SoPhieu ON dbo.QL_Kho_ChungTu(IDCSKCB,LoaiChungTu,SoPhieu);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.QL_Kho_ChungTu') AND name='UX_QL_Kho_ChungTu_DaoThu')
CREATE UNIQUE INDEX UX_QL_Kho_ChungTu_DaoThu ON dbo.QL_Kho_ChungTu(IDCSKCB,IDChungTuHuy) WHERE IDChungTuHuy IS NOT NULL;
GO
IF OBJECT_ID(N'dbo.QL_Kho_ChungTu_CT',N'U') IS NULL
BEGIN
CREATE TABLE dbo.QL_Kho_ChungTu_CT(
 [ID] bigint NOT NULL,
 [IDCSKCB] bigint NOT NULL,
 [LoaiChungTu] varchar(20) NOT NULL,
 [IDChungTu] bigint NOT NULL,
 [IDThuoc] bigint NULL,
 [IDDonViTinh] bigint NULL,
 [HeSoQuyDoi] decimal(18,6) NULL,
 [SoLuong] decimal(18,4) NULL,
 [SoLuongCoSo] decimal(18,4) NULL,
 [GiaNhap] decimal(18,2) NULL,
 [ThanhTien] decimal(18,2) NULL,
 [SoLo] nvarchar(100) NULL,
 [HanDung] date NULL,
 [IDLoThuoc] bigint NULL,
 [TenThuocSnapshot] nvarchar(500) NULL,
 [MaThuocSnapshot] nvarchar(50) NULL,
 [DonViTinhSnapshot] nvarchar(100) NULL,
 [VAT] decimal(5,2) NULL CONSTRAINT DF_QL_Kho_ChungTu_CT_VAT DEFAULT(0),
 [TienVAT] decimal(18,2) NULL CONSTRAINT DF_QL_Kho_ChungTu_CT_TienVAT DEFAULT(0),
 [IDToaThuocCT] bigint NULL,
 [GiaVon] decimal(18,4) NULL,
 [SoLuongDaHoan] decimal(18,4) NULL CONSTRAINT DF_QL_Kho_ChungTu_CT_SoLuongDaHoan DEFAULT(0),
 [IDThuTienChungTuCT] bigint NULL,
 [IDChungTuCTGoc] bigint NULL,
 [SoLuongThayDoi] decimal(18,4) NULL,
 [SoLuongTruoc] decimal(18,4) NULL,
 [SoLuongSau] decimal(18,4) NULL,
 [LoaiChungTuGoc] varchar(20) NULL,
 CONSTRAINT PK_QL_Kho_ChungTu_CT PRIMARY KEY(IDCSKCB,LoaiChungTu,ID),
 CONSTRAINT CK_QL_Kho_ChungTu_CT_Loai CHECK(LoaiChungTu IN('NHAP','CAP_PHAT','HOAN','DIEU_CHINH')),
 CONSTRAINT CK_QL_Kho_ChungTu_CT_NHAP_Required CHECK(LoaiChungTu<>'NHAP' OR ([IDChungTu] IS NOT NULL AND [IDThuoc] IS NOT NULL AND [IDDonViTinh] IS NOT NULL AND [HeSoQuyDoi] IS NOT NULL AND [SoLuong] IS NOT NULL AND [SoLuongCoSo] IS NOT NULL AND [GiaNhap] IS NOT NULL AND [ThanhTien] IS NOT NULL AND [IDLoThuoc] IS NOT NULL AND [VAT] IS NOT NULL AND [TienVAT] IS NOT NULL)),
 CONSTRAINT CK_V114_CK_QL_Kho_NhapCT_SL CHECK(LoaiChungTu<>'NHAP' OR ([SoLuong]>(0) AND [SoLuongCoSo]>(0) AND [HeSoQuyDoi]>(0))),
 CONSTRAINT CK_QL_Kho_ChungTu_CT_CAP_PHAT_Required CHECK(LoaiChungTu<>'CAP_PHAT' OR ([IDChungTu] IS NOT NULL AND [IDToaThuocCT] IS NOT NULL AND [IDThuoc] IS NOT NULL AND [IDLoThuoc] IS NOT NULL AND [SoLuongCoSo] IS NOT NULL AND [GiaVon] IS NOT NULL AND [ThanhTien] IS NOT NULL AND [SoLuongDaHoan] IS NOT NULL)),
 CONSTRAINT CK_V114_CK_QL_Kho_Xuat_CT_DaHoan CHECK(LoaiChungTu<>'CAP_PHAT' OR ([SoLuongDaHoan]>=(0) AND [SoLuongDaHoan]<=[SoLuongCoSo])),
 CONSTRAINT CK_V114_CK_QL_Kho_XuatCT_SL CHECK(LoaiChungTu<>'CAP_PHAT' OR ([SoLuongCoSo]>(0))),
 CONSTRAINT CK_QL_Kho_ChungTu_CT_HOAN_Required CHECK(LoaiChungTu<>'HOAN' OR ([IDChungTu] IS NOT NULL AND [IDChungTuCTGoc] IS NOT NULL AND [SoLuongCoSo] IS NOT NULL)),
 CONSTRAINT CK_V114_CK_QL_Kho_Hoan_CT_SL CHECK(LoaiChungTu<>'HOAN' OR ([SoLuongCoSo]>(0))),
 CONSTRAINT CK_QL_Kho_ChungTu_CT_DIEU_CHINH_Required CHECK(LoaiChungTu<>'DIEU_CHINH' OR ([IDChungTu] IS NOT NULL AND [IDLoThuoc] IS NOT NULL AND [SoLuongThayDoi] IS NOT NULL AND [SoLuongTruoc] IS NOT NULL AND [SoLuongSau] IS NOT NULL)),
 CONSTRAINT CK_V114_CK_QL_Kho_DieuChinh_CT_SL CHECK(LoaiChungTu<>'DIEU_CHINH' OR ([SoLuongThayDoi]<>(0) AND [SoLuongTruoc]>=(0) AND [SoLuongSau]>=(0) AND [SoLuongSau]=([SoLuongTruoc]+[SoLuongThayDoi]))),
 CONSTRAINT CK_QL_Kho_ChungTu_CT_Goc CHECK((LoaiChungTu='HOAN' AND LoaiChungTuGoc IS NOT NULL AND LoaiChungTuGoc='CAP_PHAT' AND IDChungTuCTGoc IS NOT NULL) OR (LoaiChungTu<>'HOAN' AND LoaiChungTuGoc IS NULL AND IDChungTuCTGoc IS NULL))
);
CREATE UNIQUE INDEX UX_QL_Kho_ChungTu_CT_FamilyID ON dbo.QL_Kho_ChungTu_CT(LoaiChungTu,ID);
END;
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_ChungTu_CT_ChungTu')
ALTER TABLE dbo.QL_Kho_ChungTu_CT WITH CHECK ADD CONSTRAINT FK_QL_Kho_ChungTu_CT_ChungTu FOREIGN KEY(IDCSKCB,LoaiChungTu,IDChungTu) REFERENCES dbo.QL_Kho_ChungTu(IDCSKCB,LoaiChungTu,ID);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_ChungTu_CT_Goc')
ALTER TABLE dbo.QL_Kho_ChungTu_CT WITH CHECK ADD CONSTRAINT FK_QL_Kho_ChungTu_CT_Goc FOREIGN KEY(IDCSKCB,LoaiChungTuGoc,IDChungTuCTGoc) REFERENCES dbo.QL_Kho_ChungTu_CT(IDCSKCB,LoaiChungTu,ID);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_V114_FK_QL_Kho_DieuChinh_CT_Lo')
ALTER TABLE dbo.QL_Kho_ChungTu_CT WITH CHECK ADD CONSTRAINT FK_V114_FK_QL_Kho_DieuChinh_CT_Lo FOREIGN KEY(IDLoThuoc) REFERENCES dbo.QL_Kho_LoThuoc(ID);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_V114_FK_QL_Kho_DieuChinh_Kho')
ALTER TABLE dbo.QL_Kho_ChungTu WITH CHECK ADD CONSTRAINT FK_V114_FK_QL_Kho_DieuChinh_Kho FOREIGN KEY(IDCSKCB,IDKho) REFERENCES dbo.DM_Kho(IDCSKCB,ID);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_V114_FK_QL_Kho_DieuChinh_NV')
ALTER TABLE dbo.QL_Kho_ChungTu WITH CHECK ADD CONSTRAINT FK_V114_FK_QL_Kho_DieuChinh_NV FOREIGN KEY(IDNhanVien) REFERENCES dbo.DM_NhanVien(ID);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_V114_FK_QL_Kho_DieuChinh_TaiKhoan')
ALTER TABLE dbo.QL_Kho_ChungTu WITH CHECK ADD CONSTRAINT FK_V114_FK_QL_Kho_DieuChinh_TaiKhoan FOREIGN KEY(IDTaiKhoan) REFERENCES dbo.HT_Tai_Khoan(ID);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_V114_FK_QL_Kho_Hoan_ChungTuHuy')
ALTER TABLE dbo.QL_Kho_ChungTu WITH CHECK ADD CONSTRAINT FK_V114_FK_QL_Kho_Hoan_ChungTuHuy FOREIGN KEY(IDChungTuHuy) REFERENCES dbo.QL_ThuTien_ChungTu(ID);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_V114_FK_QL_Kho_Hoan_VV')
ALTER TABLE dbo.QL_Kho_ChungTu WITH CHECK ADD CONSTRAINT FK_V114_FK_QL_Kho_Hoan_VV FOREIGN KEY(IDCSKCB,IDVaoVien) REFERENCES dbo.QL_VaoVien(IDCSKCB,ID);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_V114_FK_QL_Kho_Nhap_NCC')
ALTER TABLE dbo.QL_Kho_ChungTu WITH CHECK ADD CONSTRAINT FK_V114_FK_QL_Kho_Nhap_NCC FOREIGN KEY(IDCSKCB,IDNhaCungCap) REFERENCES dbo.DM_NhaCungCap(IDCSKCB,ID);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_V114_FK_QL_Kho_Nhap_NVH')
ALTER TABLE dbo.QL_Kho_ChungTu WITH CHECK ADD CONSTRAINT FK_V114_FK_QL_Kho_Nhap_NVH FOREIGN KEY(IDNhanVienHuy) REFERENCES dbo.DM_NhanVien(ID);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_V114_FK_QL_Kho_Nhap_TaiKhoanHuy')
ALTER TABLE dbo.QL_Kho_ChungTu WITH CHECK ADD CONSTRAINT FK_V114_FK_QL_Kho_Nhap_TaiKhoanHuy FOREIGN KEY(IDTaiKhoanHuy) REFERENCES dbo.HT_Tai_Khoan(ID);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_V114_FK_QL_Kho_NhapCT_DVT')
ALTER TABLE dbo.QL_Kho_ChungTu_CT WITH CHECK ADD CONSTRAINT FK_V114_FK_QL_Kho_NhapCT_DVT FOREIGN KEY(IDCSKCB,IDDonViTinh) REFERENCES dbo.DM_DonViTinh(IDCSKCB,ID);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_V114_FK_QL_Kho_NhapCT_Thuoc')
ALTER TABLE dbo.QL_Kho_ChungTu_CT WITH CHECK ADD CONSTRAINT FK_V114_FK_QL_Kho_NhapCT_Thuoc FOREIGN KEY(IDCSKCB,IDThuoc) REFERENCES dbo.DM_Thuoc(IDCSKCB,ID);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_V114_FK_QL_Kho_Xuat_CT_ChungTuThu')
ALTER TABLE dbo.QL_Kho_ChungTu_CT WITH CHECK ADD CONSTRAINT FK_V114_FK_QL_Kho_Xuat_CT_ChungTuThu FOREIGN KEY(IDThuTienChungTuCT) REFERENCES dbo.QL_ThuTien_ChungTu_CT(ID);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_V114_FK_QL_Kho_XuatCT_Toa')
ALTER TABLE dbo.QL_Kho_ChungTu_CT WITH CHECK ADD CONSTRAINT FK_V114_FK_QL_Kho_XuatCT_Toa FOREIGN KEY(IDCSKCB,IDToaThuocCT) REFERENCES dbo.QL_ToaThuoc_CT(IDCSKCB,ID);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.QL_Kho_ChungTu') AND name='IX_QL_Kho_ChungTu_Visit') CREATE INDEX IX_QL_Kho_ChungTu_Visit ON dbo.QL_Kho_ChungTu(IDCSKCB,LoaiChungTu,IDVaoVien,DaHuy) INCLUDE(SoPhieu,NgayGio);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.QL_Kho_ChungTu_CT') AND name='IX_QL_Kho_ChungTu_CT_Header') CREATE INDEX IX_QL_Kho_ChungTu_CT_Header ON dbo.QL_Kho_ChungTu_CT(IDCSKCB,LoaiChungTu,IDChungTu);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.QL_Kho_ChungTu_CT') AND name='IX_QL_Kho_ChungTu_CT_Lot') CREATE INDEX IX_QL_Kho_ChungTu_CT_Lot ON dbo.QL_Kho_ChungTu_CT(IDCSKCB,LoaiChungTu,IDLoThuoc);
GO
IF OBJECT_ID(N'dbo.QL_Kho_Nhap',N'U') IS NOT NULL
BEGIN
IF EXISTS(SELECT 1 FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='NHAP') THROW 59114,'Canonical family is already populated while legacy tables remain.',1;
INSERT dbo.QL_Kho_ChungTu([ID],[IDCSKCB],[IDKho],[SoPhieu],[SoHoaDon],[NgayGio],[IDNhanVien],[TongTien],[GhiChu],[DaHuy],[IDNhaCungCap],[NgayHoaDon],[NgayGioHuy],[IDNhanVienHuy],[LyDoHuy],[TenNhaCungCapSnapshot],[IDTaiKhoan],[TenNguoiThucHienSnapshot],[IDTaiKhoanHuy],[TenNguoiHuySnapshot],[LoaiChungTu],[LoaiNghiepVu]) SELECT O.[ID],O.[IDCSKCB],O.[IDKho],O.[SoPhieu],O.[SoHoaDon],O.[NgayNhap],O.[IDNhanVienNhap],O.[TongTien],O.[GhiChu],O.[DaHuy],O.[IDNhaCungCap],O.[NgayHoaDon],O.[NgayGioHuy],O.[IDNhanVienHuy],O.[LyDoHuy],O.[TenNhaCungCapSnapshot],O.[IDTaiKhoanNhap],O.[TenNguoiNhapSnapshot],O.[IDTaiKhoanHuy],O.[TenNguoiHuySnapshot],'NHAP','NHAP' FROM dbo.QL_Kho_Nhap O;
IF EXISTS(SELECT [ID],[IDCSKCB],[IDKho],[SoPhieu],[SoHoaDon],[NgayNhap],[IDNhanVienNhap],[TongTien],[GhiChu],[DaHuy],[IDNhaCungCap],[NgayHoaDon],[NgayGioHuy],[IDNhanVienHuy],[LyDoHuy],[TenNhaCungCapSnapshot],[IDTaiKhoanNhap],[TenNguoiNhapSnapshot],[IDTaiKhoanHuy],[TenNguoiHuySnapshot] FROM dbo.QL_Kho_Nhap EXCEPT SELECT [ID],[IDCSKCB],[IDKho],[SoPhieu],[SoHoaDon],[NgayGio],[IDNhanVien],[TongTien],[GhiChu],[DaHuy],[IDNhaCungCap],[NgayHoaDon],[NgayGioHuy],[IDNhanVienHuy],[LyDoHuy],[TenNhaCungCapSnapshot],[IDTaiKhoan],[TenNguoiThucHienSnapshot],[IDTaiKhoanHuy],[TenNguoiHuySnapshot] FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='NHAP') OR EXISTS(SELECT [ID],[IDCSKCB],[IDKho],[SoPhieu],[SoHoaDon],[NgayGio],[IDNhanVien],[TongTien],[GhiChu],[DaHuy],[IDNhaCungCap],[NgayHoaDon],[NgayGioHuy],[IDNhanVienHuy],[LyDoHuy],[TenNhaCungCapSnapshot],[IDTaiKhoan],[TenNguoiThucHienSnapshot],[IDTaiKhoanHuy],[TenNguoiHuySnapshot] FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='NHAP' EXCEPT SELECT [ID],[IDCSKCB],[IDKho],[SoPhieu],[SoHoaDon],[NgayNhap],[IDNhanVienNhap],[TongTien],[GhiChu],[DaHuy],[IDNhaCungCap],[NgayHoaDon],[NgayGioHuy],[IDNhanVienHuy],[LyDoHuy],[TenNhaCungCapSnapshot],[IDTaiKhoanNhap],[TenNguoiNhapSnapshot],[IDTaiKhoanHuy],[TenNguoiHuySnapshot] FROM dbo.QL_Kho_Nhap) THROW 59114,'Lossless copy comparison failed: QL_Kho_Nhap',1;
END;
GO
IF OBJECT_ID(N'dbo.SEQ_Kho_NHAP',N'SO') IS NULL
BEGIN
DECLARE @Next BIGINT=ISNULL((SELECT MAX(ID) FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='NHAP'),0)+1;
IF OBJECT_ID(N'dbo.QL_Kho_Nhap',N'U') IS NOT NULL AND IDENT_CURRENT(N'dbo.QL_Kho_Nhap')>=@Next SET @Next=CONVERT(BIGINT,IDENT_CURRENT(N'dbo.QL_Kho_Nhap'))+1;
EXEC(N'CREATE SEQUENCE dbo.SEQ_Kho_NHAP AS BIGINT START WITH '+@Next+N' INCREMENT BY 1 NO CYCLE');
END;
GO
IF OBJECT_ID(N'dbo.QL_Kho_Nhap_CT',N'U') IS NOT NULL
BEGIN
IF EXISTS(SELECT 1 FROM dbo.QL_Kho_ChungTu_CT WHERE LoaiChungTu='NHAP') THROW 59114,'Canonical family is already populated while legacy tables remain.',1;
INSERT dbo.QL_Kho_ChungTu_CT([ID],[IDCSKCB],[IDChungTu],[IDThuoc],[IDDonViTinh],[HeSoQuyDoi],[SoLuong],[SoLuongCoSo],[GiaNhap],[ThanhTien],[SoLo],[HanDung],[IDLoThuoc],[TenThuocSnapshot],[MaThuocSnapshot],[DonViTinhSnapshot],[VAT],[TienVAT],[LoaiChungTu]) SELECT O.[ID],O.[IDCSKCB],O.[IDNhap],O.[IDThuoc],O.[IDDonViTinh],O.[HeSoQuyDoi],O.[SoLuong],O.[SoLuongCoSo],O.[GiaNhap],O.[ThanhTien],O.[SoLo],O.[HanDung],O.[IDLoThuoc],O.[TenThuocSnapshot],O.[MaThuocSnapshot],O.[DonViTinhSnapshot],O.[VAT],O.[TienVAT],'NHAP' FROM dbo.QL_Kho_Nhap_CT O;
IF EXISTS(SELECT [ID],[IDCSKCB],[IDNhap],[IDThuoc],[IDDonViTinh],[HeSoQuyDoi],[SoLuong],[SoLuongCoSo],[GiaNhap],[ThanhTien],[SoLo],[HanDung],[IDLoThuoc],[TenThuocSnapshot],[MaThuocSnapshot],[DonViTinhSnapshot],[VAT],[TienVAT] FROM dbo.QL_Kho_Nhap_CT EXCEPT SELECT [ID],[IDCSKCB],[IDChungTu],[IDThuoc],[IDDonViTinh],[HeSoQuyDoi],[SoLuong],[SoLuongCoSo],[GiaNhap],[ThanhTien],[SoLo],[HanDung],[IDLoThuoc],[TenThuocSnapshot],[MaThuocSnapshot],[DonViTinhSnapshot],[VAT],[TienVAT] FROM dbo.QL_Kho_ChungTu_CT WHERE LoaiChungTu='NHAP') OR EXISTS(SELECT [ID],[IDCSKCB],[IDChungTu],[IDThuoc],[IDDonViTinh],[HeSoQuyDoi],[SoLuong],[SoLuongCoSo],[GiaNhap],[ThanhTien],[SoLo],[HanDung],[IDLoThuoc],[TenThuocSnapshot],[MaThuocSnapshot],[DonViTinhSnapshot],[VAT],[TienVAT] FROM dbo.QL_Kho_ChungTu_CT WHERE LoaiChungTu='NHAP' EXCEPT SELECT [ID],[IDCSKCB],[IDNhap],[IDThuoc],[IDDonViTinh],[HeSoQuyDoi],[SoLuong],[SoLuongCoSo],[GiaNhap],[ThanhTien],[SoLo],[HanDung],[IDLoThuoc],[TenThuocSnapshot],[MaThuocSnapshot],[DonViTinhSnapshot],[VAT],[TienVAT] FROM dbo.QL_Kho_Nhap_CT) THROW 59114,'Lossless copy comparison failed: QL_Kho_Nhap_CT',1;
END;
GO
IF OBJECT_ID(N'dbo.SEQ_Kho_NHAP_CT',N'SO') IS NULL
BEGIN
DECLARE @Next BIGINT=ISNULL((SELECT MAX(ID) FROM dbo.QL_Kho_ChungTu_CT WHERE LoaiChungTu='NHAP'),0)+1;
IF OBJECT_ID(N'dbo.QL_Kho_Nhap_CT',N'U') IS NOT NULL AND IDENT_CURRENT(N'dbo.QL_Kho_Nhap_CT')>=@Next SET @Next=CONVERT(BIGINT,IDENT_CURRENT(N'dbo.QL_Kho_Nhap_CT'))+1;
EXEC(N'CREATE SEQUENCE dbo.SEQ_Kho_NHAP_CT AS BIGINT START WITH '+@Next+N' INCREMENT BY 1 NO CYCLE');
END;
GO
IF OBJECT_ID(N'dbo.QL_Kho_Xuat',N'U') IS NOT NULL
BEGIN
IF EXISTS(SELECT 1 FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='CAP_PHAT') THROW 59114,'Canonical family is already populated while legacy tables remain.',1;
INSERT dbo.QL_Kho_ChungTu([ID],[IDCSKCB],[IDKho],[IDVaoVien],[SoPhieu],[NgayGio],[IDNhanVien],[TongGiaVon],[GhiChu],[DaHuy],[IDTaiKhoan],[TenNguoiThucHienSnapshot],[LoaiChungTu],[LoaiNghiepVu]) SELECT O.[ID],O.[IDCSKCB],O.[IDKho],O.[IDVaoVien],O.[SoPhieu],O.[NgayXuat],O.[IDNhanVienXuat],O.[TongGiaVon],O.[GhiChu],O.[DaHuy],O.[IDTaiKhoanXuat],O.[TenNguoiXuatSnapshot],'CAP_PHAT','CAP_PHAT' FROM dbo.QL_Kho_Xuat O;
IF EXISTS(SELECT [ID],[IDCSKCB],[IDKho],[IDVaoVien],[SoPhieu],[NgayXuat],[IDNhanVienXuat],[TongGiaVon],[GhiChu],[DaHuy],[IDTaiKhoanXuat],[TenNguoiXuatSnapshot] FROM dbo.QL_Kho_Xuat EXCEPT SELECT [ID],[IDCSKCB],[IDKho],[IDVaoVien],[SoPhieu],[NgayGio],[IDNhanVien],[TongGiaVon],[GhiChu],[DaHuy],[IDTaiKhoan],[TenNguoiThucHienSnapshot] FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='CAP_PHAT') OR EXISTS(SELECT [ID],[IDCSKCB],[IDKho],[IDVaoVien],[SoPhieu],[NgayGio],[IDNhanVien],[TongGiaVon],[GhiChu],[DaHuy],[IDTaiKhoan],[TenNguoiThucHienSnapshot] FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='CAP_PHAT' EXCEPT SELECT [ID],[IDCSKCB],[IDKho],[IDVaoVien],[SoPhieu],[NgayXuat],[IDNhanVienXuat],[TongGiaVon],[GhiChu],[DaHuy],[IDTaiKhoanXuat],[TenNguoiXuatSnapshot] FROM dbo.QL_Kho_Xuat) THROW 59114,'Lossless copy comparison failed: QL_Kho_Xuat',1;
END;
GO
IF OBJECT_ID(N'dbo.SEQ_Kho_CAP_PHAT',N'SO') IS NULL
BEGIN
DECLARE @Next BIGINT=ISNULL((SELECT MAX(ID) FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='CAP_PHAT'),0)+1;
IF OBJECT_ID(N'dbo.QL_Kho_Xuat',N'U') IS NOT NULL AND IDENT_CURRENT(N'dbo.QL_Kho_Xuat')>=@Next SET @Next=CONVERT(BIGINT,IDENT_CURRENT(N'dbo.QL_Kho_Xuat'))+1;
EXEC(N'CREATE SEQUENCE dbo.SEQ_Kho_CAP_PHAT AS BIGINT START WITH '+@Next+N' INCREMENT BY 1 NO CYCLE');
END;
GO
IF OBJECT_ID(N'dbo.QL_Kho_Xuat_CT',N'U') IS NOT NULL
BEGIN
IF EXISTS(SELECT 1 FROM dbo.QL_Kho_ChungTu_CT WHERE LoaiChungTu='CAP_PHAT') THROW 59114,'Canonical family is already populated while legacy tables remain.',1;
INSERT dbo.QL_Kho_ChungTu_CT([ID],[IDCSKCB],[IDChungTu],[IDToaThuocCT],[IDThuoc],[IDLoThuoc],[SoLuongCoSo],[GiaVon],[ThanhTien],[SoLuongDaHoan],[IDThuTienChungTuCT],[HeSoQuyDoi],[LoaiChungTu]) SELECT O.[ID],O.[IDCSKCB],O.[IDXuat],O.[IDToaThuocCT],O.[IDThuoc],O.[IDLoThuoc],O.[SoLuongCoSo],O.[GiaVon],O.[ThanhTien],O.[SoLuongDaHoan],O.[IDThuTienChungTuCT],O.[HeSoQuyDoi],'CAP_PHAT' FROM dbo.QL_Kho_Xuat_CT O;
IF EXISTS(SELECT [ID],[IDCSKCB],[IDXuat],[IDToaThuocCT],[IDThuoc],[IDLoThuoc],[SoLuongCoSo],[GiaVon],[ThanhTien],[SoLuongDaHoan],[IDThuTienChungTuCT],[HeSoQuyDoi] FROM dbo.QL_Kho_Xuat_CT EXCEPT SELECT [ID],[IDCSKCB],[IDChungTu],[IDToaThuocCT],[IDThuoc],[IDLoThuoc],[SoLuongCoSo],[GiaVon],[ThanhTien],[SoLuongDaHoan],[IDThuTienChungTuCT],[HeSoQuyDoi] FROM dbo.QL_Kho_ChungTu_CT WHERE LoaiChungTu='CAP_PHAT') OR EXISTS(SELECT [ID],[IDCSKCB],[IDChungTu],[IDToaThuocCT],[IDThuoc],[IDLoThuoc],[SoLuongCoSo],[GiaVon],[ThanhTien],[SoLuongDaHoan],[IDThuTienChungTuCT],[HeSoQuyDoi] FROM dbo.QL_Kho_ChungTu_CT WHERE LoaiChungTu='CAP_PHAT' EXCEPT SELECT [ID],[IDCSKCB],[IDXuat],[IDToaThuocCT],[IDThuoc],[IDLoThuoc],[SoLuongCoSo],[GiaVon],[ThanhTien],[SoLuongDaHoan],[IDThuTienChungTuCT],[HeSoQuyDoi] FROM dbo.QL_Kho_Xuat_CT) THROW 59114,'Lossless copy comparison failed: QL_Kho_Xuat_CT',1;
END;
GO
IF OBJECT_ID(N'dbo.SEQ_Kho_CAP_PHAT_CT',N'SO') IS NULL
BEGIN
DECLARE @Next BIGINT=ISNULL((SELECT MAX(ID) FROM dbo.QL_Kho_ChungTu_CT WHERE LoaiChungTu='CAP_PHAT'),0)+1;
IF OBJECT_ID(N'dbo.QL_Kho_Xuat_CT',N'U') IS NOT NULL AND IDENT_CURRENT(N'dbo.QL_Kho_Xuat_CT')>=@Next SET @Next=CONVERT(BIGINT,IDENT_CURRENT(N'dbo.QL_Kho_Xuat_CT'))+1;
EXEC(N'CREATE SEQUENCE dbo.SEQ_Kho_CAP_PHAT_CT AS BIGINT START WITH '+@Next+N' INCREMENT BY 1 NO CYCLE');
END;
GO
IF OBJECT_ID(N'dbo.QL_Kho_Hoan',N'U') IS NOT NULL
BEGIN
IF EXISTS(SELECT 1 FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='HOAN') THROW 59114,'Canonical family is already populated while legacy tables remain.',1;
INSERT dbo.QL_Kho_ChungTu([ID],[IDCSKCB],[IDVaoVien],[SoPhieu],[NgayGio],[IDNhanVien],[LyDo],[IDTaiKhoan],[IDChungTuHuy],[LoaiNghiepVu],[TenNguoiThucHienSnapshot],[LoaiChungTu]) SELECT O.[ID],O.[IDCSKCB],O.[IDVaoVien],O.[SoPhieu],O.[NgayHoan],O.[IDNhanVienHoan],O.[LyDo],O.[IDTaiKhoanHoan],O.[IDChungTuHuy],O.[Loai],O.[TenNguoiHoanSnapshot],'HOAN' FROM dbo.QL_Kho_Hoan O;
IF EXISTS(SELECT [ID],[IDCSKCB],[IDVaoVien],[SoPhieu],[NgayHoan],[IDNhanVienHoan],[LyDo],[IDTaiKhoanHoan],[IDChungTuHuy],[Loai],[TenNguoiHoanSnapshot] FROM dbo.QL_Kho_Hoan EXCEPT SELECT [ID],[IDCSKCB],[IDVaoVien],[SoPhieu],[NgayGio],[IDNhanVien],[LyDo],[IDTaiKhoan],[IDChungTuHuy],[LoaiNghiepVu],[TenNguoiThucHienSnapshot] FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='HOAN') OR EXISTS(SELECT [ID],[IDCSKCB],[IDVaoVien],[SoPhieu],[NgayGio],[IDNhanVien],[LyDo],[IDTaiKhoan],[IDChungTuHuy],[LoaiNghiepVu],[TenNguoiThucHienSnapshot] FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='HOAN' EXCEPT SELECT [ID],[IDCSKCB],[IDVaoVien],[SoPhieu],[NgayHoan],[IDNhanVienHoan],[LyDo],[IDTaiKhoanHoan],[IDChungTuHuy],[Loai],[TenNguoiHoanSnapshot] FROM dbo.QL_Kho_Hoan) THROW 59114,'Lossless copy comparison failed: QL_Kho_Hoan',1;
END;
GO
IF OBJECT_ID(N'dbo.SEQ_Kho_HOAN',N'SO') IS NULL
BEGIN
DECLARE @Next BIGINT=ISNULL((SELECT MAX(ID) FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='HOAN'),0)+1;
IF OBJECT_ID(N'dbo.QL_Kho_Hoan',N'U') IS NOT NULL AND IDENT_CURRENT(N'dbo.QL_Kho_Hoan')>=@Next SET @Next=CONVERT(BIGINT,IDENT_CURRENT(N'dbo.QL_Kho_Hoan'))+1;
EXEC(N'CREATE SEQUENCE dbo.SEQ_Kho_HOAN AS BIGINT START WITH '+@Next+N' INCREMENT BY 1 NO CYCLE');
END;
GO
IF OBJECT_ID(N'dbo.QL_Kho_Hoan_CT',N'U') IS NOT NULL
BEGIN
IF EXISTS(SELECT 1 FROM dbo.QL_Kho_ChungTu_CT WHERE LoaiChungTu='HOAN') THROW 59114,'Canonical family is already populated while legacy tables remain.',1;
INSERT dbo.QL_Kho_ChungTu_CT([ID],[IDChungTu],[IDChungTuCTGoc],[SoLuongCoSo],[LoaiChungTu],[IDCSKCB],[LoaiChungTuGoc]) SELECT O.[ID],O.[IDHoan],O.[IDXuatCT],O.[SoLuongCoSo],'HOAN',H.IDCSKCB,'CAP_PHAT' FROM dbo.QL_Kho_Hoan_CT O JOIN dbo.QL_Kho_Hoan H ON H.ID=O.IDHoan;
IF EXISTS(SELECT [ID],[IDHoan],[IDXuatCT],[SoLuongCoSo] FROM dbo.QL_Kho_Hoan_CT EXCEPT SELECT [ID],[IDChungTu],[IDChungTuCTGoc],[SoLuongCoSo] FROM dbo.QL_Kho_ChungTu_CT WHERE LoaiChungTu='HOAN') OR EXISTS(SELECT [ID],[IDChungTu],[IDChungTuCTGoc],[SoLuongCoSo] FROM dbo.QL_Kho_ChungTu_CT WHERE LoaiChungTu='HOAN' EXCEPT SELECT [ID],[IDHoan],[IDXuatCT],[SoLuongCoSo] FROM dbo.QL_Kho_Hoan_CT) THROW 59114,'Lossless copy comparison failed: QL_Kho_Hoan_CT',1;
END;
GO
IF OBJECT_ID(N'dbo.SEQ_Kho_HOAN_CT',N'SO') IS NULL
BEGIN
DECLARE @Next BIGINT=ISNULL((SELECT MAX(ID) FROM dbo.QL_Kho_ChungTu_CT WHERE LoaiChungTu='HOAN'),0)+1;
IF OBJECT_ID(N'dbo.QL_Kho_Hoan_CT',N'U') IS NOT NULL AND IDENT_CURRENT(N'dbo.QL_Kho_Hoan_CT')>=@Next SET @Next=CONVERT(BIGINT,IDENT_CURRENT(N'dbo.QL_Kho_Hoan_CT'))+1;
EXEC(N'CREATE SEQUENCE dbo.SEQ_Kho_HOAN_CT AS BIGINT START WITH '+@Next+N' INCREMENT BY 1 NO CYCLE');
END;
GO
IF OBJECT_ID(N'dbo.QL_Kho_DieuChinh',N'U') IS NOT NULL
BEGIN
IF EXISTS(SELECT 1 FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='DIEU_CHINH') THROW 59114,'Canonical family is already populated while legacy tables remain.',1;
INSERT dbo.QL_Kho_ChungTu([ID],[IDCSKCB],[IDKho],[LoaiNghiepVu],[SoPhieu],[NgayGio],[IDNhanVien],[LyDo],[IDTaiKhoan],[TenNguoiThucHienSnapshot],[LoaiChungTu]) SELECT O.[ID],O.[IDCSKCB],O.[IDKho],O.[Loai],O.[SoPhieu],O.[NgayGio],O.[IDNhanVien],O.[LyDo],O.[IDTaiKhoan],O.[TenNguoiThucHienSnapshot],'DIEU_CHINH' FROM dbo.QL_Kho_DieuChinh O;
IF EXISTS(SELECT [ID],[IDCSKCB],[IDKho],[Loai],[SoPhieu],[NgayGio],[IDNhanVien],[LyDo],[IDTaiKhoan],[TenNguoiThucHienSnapshot] FROM dbo.QL_Kho_DieuChinh EXCEPT SELECT [ID],[IDCSKCB],[IDKho],[LoaiNghiepVu],[SoPhieu],[NgayGio],[IDNhanVien],[LyDo],[IDTaiKhoan],[TenNguoiThucHienSnapshot] FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='DIEU_CHINH') OR EXISTS(SELECT [ID],[IDCSKCB],[IDKho],[LoaiNghiepVu],[SoPhieu],[NgayGio],[IDNhanVien],[LyDo],[IDTaiKhoan],[TenNguoiThucHienSnapshot] FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='DIEU_CHINH' EXCEPT SELECT [ID],[IDCSKCB],[IDKho],[Loai],[SoPhieu],[NgayGio],[IDNhanVien],[LyDo],[IDTaiKhoan],[TenNguoiThucHienSnapshot] FROM dbo.QL_Kho_DieuChinh) THROW 59114,'Lossless copy comparison failed: QL_Kho_DieuChinh',1;
END;
GO
IF OBJECT_ID(N'dbo.SEQ_Kho_DIEU_CHINH',N'SO') IS NULL
BEGIN
DECLARE @Next BIGINT=ISNULL((SELECT MAX(ID) FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='DIEU_CHINH'),0)+1;
IF OBJECT_ID(N'dbo.QL_Kho_DieuChinh',N'U') IS NOT NULL AND IDENT_CURRENT(N'dbo.QL_Kho_DieuChinh')>=@Next SET @Next=CONVERT(BIGINT,IDENT_CURRENT(N'dbo.QL_Kho_DieuChinh'))+1;
EXEC(N'CREATE SEQUENCE dbo.SEQ_Kho_DIEU_CHINH AS BIGINT START WITH '+@Next+N' INCREMENT BY 1 NO CYCLE');
END;
GO
IF OBJECT_ID(N'dbo.QL_Kho_DieuChinh_CT',N'U') IS NOT NULL
BEGIN
IF EXISTS(SELECT 1 FROM dbo.QL_Kho_ChungTu_CT WHERE LoaiChungTu='DIEU_CHINH') THROW 59114,'Canonical family is already populated while legacy tables remain.',1;
INSERT dbo.QL_Kho_ChungTu_CT([ID],[IDCSKCB],[IDChungTu],[IDLoThuoc],[SoLuongThayDoi],[SoLuongTruoc],[SoLuongSau],[LoaiChungTu]) SELECT O.[ID],O.[IDCSKCB],O.[IDChungTu],O.[IDLoThuoc],O.[SoLuongThayDoi],O.[SoLuongTruoc],O.[SoLuongSau],'DIEU_CHINH' FROM dbo.QL_Kho_DieuChinh_CT O;
IF EXISTS(SELECT [ID],[IDCSKCB],[IDChungTu],[IDLoThuoc],[SoLuongThayDoi],[SoLuongTruoc],[SoLuongSau] FROM dbo.QL_Kho_DieuChinh_CT EXCEPT SELECT [ID],[IDCSKCB],[IDChungTu],[IDLoThuoc],[SoLuongThayDoi],[SoLuongTruoc],[SoLuongSau] FROM dbo.QL_Kho_ChungTu_CT WHERE LoaiChungTu='DIEU_CHINH') OR EXISTS(SELECT [ID],[IDCSKCB],[IDChungTu],[IDLoThuoc],[SoLuongThayDoi],[SoLuongTruoc],[SoLuongSau] FROM dbo.QL_Kho_ChungTu_CT WHERE LoaiChungTu='DIEU_CHINH' EXCEPT SELECT [ID],[IDCSKCB],[IDChungTu],[IDLoThuoc],[SoLuongThayDoi],[SoLuongTruoc],[SoLuongSau] FROM dbo.QL_Kho_DieuChinh_CT) THROW 59114,'Lossless copy comparison failed: QL_Kho_DieuChinh_CT',1;
END;
GO
IF OBJECT_ID(N'dbo.SEQ_Kho_DIEU_CHINH_CT',N'SO') IS NULL
BEGIN
DECLARE @Next BIGINT=ISNULL((SELECT MAX(ID) FROM dbo.QL_Kho_ChungTu_CT WHERE LoaiChungTu='DIEU_CHINH'),0)+1;
IF OBJECT_ID(N'dbo.QL_Kho_DieuChinh_CT',N'U') IS NOT NULL AND IDENT_CURRENT(N'dbo.QL_Kho_DieuChinh_CT')>=@Next SET @Next=CONVERT(BIGINT,IDENT_CURRENT(N'dbo.QL_Kho_DieuChinh_CT'))+1;
EXEC(N'CREATE SEQUENCE dbo.SEQ_Kho_DIEU_CHINH_CT AS BIGINT START WITH '+@Next+N' INCREMENT BY 1 NO CYCLE');
END;
GO
