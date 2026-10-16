/* Finalize only after column-for-column copy verification. No stock/ledger writes. */
IF DB_NAME()<>N'QLPM' OR @@TRANCOUNT=0 THROW 59114,'QLPM transaction required.',1;
GO
IF OBJECT_ID(N'dbo.QL_Kho_KiemKe_CT',N'U') IS NOT NULL AND EXISTS(SELECT 1 FROM dbo.QL_Kho_KiemKe_CT) THROW 59114,'Refuse removal of nonempty unused table: QL_Kho_KiemKe_CT',1;
GO
IF OBJECT_ID(N'dbo.QL_Kho_KiemKe',N'U') IS NOT NULL AND EXISTS(SELECT 1 FROM dbo.QL_Kho_KiemKe) THROW 59114,'Refuse removal of nonempty unused table: QL_Kho_KiemKe',1;
GO
IF OBJECT_ID(N'dbo.QL_Kho_XuatKhac_CT',N'U') IS NOT NULL AND EXISTS(SELECT 1 FROM dbo.QL_Kho_XuatKhac_CT) THROW 59114,'Refuse removal of nonempty unused table: QL_Kho_XuatKhac_CT',1;
GO
IF OBJECT_ID(N'dbo.QL_Kho_XuatKhac',N'U') IS NOT NULL AND EXISTS(SELECT 1 FROM dbo.QL_Kho_XuatKhac) THROW 59114,'Refuse removal of nonempty unused table: QL_Kho_XuatKhac',1;
GO
IF OBJECT_ID(N'dbo.QL_Kho_KhoaLo',N'U') IS NOT NULL AND EXISTS(SELECT 1 FROM dbo.QL_Kho_KhoaLo) THROW 59114,'Refuse removal of nonempty unused table: QL_Kho_KhoaLo',1;
GO
IF OBJECT_ID(N'dbo.QL_Kho_SoChungTu',N'U') IS NOT NULL AND EXISTS(SELECT 1 FROM dbo.QL_Kho_SoChungTu) THROW 59114,'Refuse removal of nonempty unused table: QL_Kho_SoChungTu',1;
GO
DROP PROCEDURE IF EXISTS dbo.STO_QL_Kho_XuatKhac_Luu;
DROP PROCEDURE IF EXISTS dbo.STO_QL_Kho_XuatKhac_Huy;
DROP PROCEDURE IF EXISTS dbo.STO_QL_Kho_XuatKhac_DanhSach;
DROP PROCEDURE IF EXISTS dbo.STO_QL_Kho_KhoaLo_Luu;
DROP PROCEDURE IF EXISTS dbo.STO_QL_Kho_KhoaLo_LichSu;
DROP PROCEDURE IF EXISTS dbo.STO_QL_Kho_KiemKe_LuuNhap;
DROP PROCEDURE IF EXISTS dbo.STO_QL_Kho_KiemKe_Chot;
DROP PROCEDURE IF EXISTS dbo.STO_QL_Kho_KiemKe_HuyNhap;
DROP PROCEDURE IF EXISTS dbo.STO_QL_Kho_KiemKe_DanhSach;
DROP PROCEDURE IF EXISTS dbo.STO_QL_Kho_KiemKe_ChiTiet;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_DieuChinh_CT_ChungTu') ALTER TABLE dbo.QL_Kho_DieuChinh_CT DROP CONSTRAINT FK_QL_Kho_DieuChinh_CT_ChungTu;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_DieuChinh_CT_Lo') ALTER TABLE dbo.QL_Kho_DieuChinh_CT DROP CONSTRAINT FK_QL_Kho_DieuChinh_CT_Lo;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_DieuChinh_Kho') ALTER TABLE dbo.QL_Kho_DieuChinh DROP CONSTRAINT FK_QL_Kho_DieuChinh_Kho;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_DieuChinh_NV') ALTER TABLE dbo.QL_Kho_DieuChinh DROP CONSTRAINT FK_QL_Kho_DieuChinh_NV;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_DieuChinh_TaiKhoan') ALTER TABLE dbo.QL_Kho_DieuChinh DROP CONSTRAINT FK_QL_Kho_DieuChinh_TaiKhoan;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_Hoan_ChungTuHuy') ALTER TABLE dbo.QL_Kho_Hoan DROP CONSTRAINT FK_QL_Kho_Hoan_ChungTuHuy;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_Hoan_CT_Hoan') ALTER TABLE dbo.QL_Kho_Hoan_CT DROP CONSTRAINT FK_QL_Kho_Hoan_CT_Hoan;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_Hoan_CT_XuatCT') ALTER TABLE dbo.QL_Kho_Hoan_CT DROP CONSTRAINT FK_QL_Kho_Hoan_CT_XuatCT;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_Hoan_NV') ALTER TABLE dbo.QL_Kho_Hoan DROP CONSTRAINT FK_QL_Kho_Hoan_NV;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_Hoan_TaiKhoan') ALTER TABLE dbo.QL_Kho_Hoan DROP CONSTRAINT FK_QL_Kho_Hoan_TaiKhoan;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_Hoan_VV') ALTER TABLE dbo.QL_Kho_Hoan DROP CONSTRAINT FK_QL_Kho_Hoan_VV;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_KhoaLo_Lo') ALTER TABLE dbo.QL_Kho_KhoaLo DROP CONSTRAINT FK_QL_Kho_KhoaLo_Lo;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_KhoaLo_TK') ALTER TABLE dbo.QL_Kho_KhoaLo DROP CONSTRAINT FK_QL_Kho_KhoaLo_TK;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_KiemKe_CT_H') ALTER TABLE dbo.QL_Kho_KiemKe_CT DROP CONSTRAINT FK_QL_Kho_KiemKe_CT_H;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_KiemKe_CT_Lo') ALTER TABLE dbo.QL_Kho_KiemKe_CT DROP CONSTRAINT FK_QL_Kho_KiemKe_CT_Lo;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_KiemKe_CT_Thuoc') ALTER TABLE dbo.QL_Kho_KiemKe_CT DROP CONSTRAINT FK_QL_Kho_KiemKe_CT_Thuoc;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_KiemKe_DC') ALTER TABLE dbo.QL_Kho_KiemKe DROP CONSTRAINT FK_QL_Kho_KiemKe_DC;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_KiemKe_Kho') ALTER TABLE dbo.QL_Kho_KiemKe DROP CONSTRAINT FK_QL_Kho_KiemKe_Kho;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_KiemKe_NVH') ALTER TABLE dbo.QL_Kho_KiemKe DROP CONSTRAINT FK_QL_Kho_KiemKe_NVH;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_KiemKe_TK') ALTER TABLE dbo.QL_Kho_KiemKe DROP CONSTRAINT FK_QL_Kho_KiemKe_TK;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_KiemKe_TKH') ALTER TABLE dbo.QL_Kho_KiemKe DROP CONSTRAINT FK_QL_Kho_KiemKe_TKH;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_Nhap_Kho') ALTER TABLE dbo.QL_Kho_Nhap DROP CONSTRAINT FK_QL_Kho_Nhap_Kho;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_Nhap_NCC') ALTER TABLE dbo.QL_Kho_Nhap DROP CONSTRAINT FK_QL_Kho_Nhap_NCC;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_Nhap_NV') ALTER TABLE dbo.QL_Kho_Nhap DROP CONSTRAINT FK_QL_Kho_Nhap_NV;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_Nhap_NVH') ALTER TABLE dbo.QL_Kho_Nhap DROP CONSTRAINT FK_QL_Kho_Nhap_NVH;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_Nhap_TaiKhoanHuy') ALTER TABLE dbo.QL_Kho_Nhap DROP CONSTRAINT FK_QL_Kho_Nhap_TaiKhoanHuy;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_Nhap_TaiKhoanNhap') ALTER TABLE dbo.QL_Kho_Nhap DROP CONSTRAINT FK_QL_Kho_Nhap_TaiKhoanNhap;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_NhapCT_DVT') ALTER TABLE dbo.QL_Kho_Nhap_CT DROP CONSTRAINT FK_QL_Kho_NhapCT_DVT;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_NhapCT_Lo') ALTER TABLE dbo.QL_Kho_Nhap_CT DROP CONSTRAINT FK_QL_Kho_NhapCT_Lo;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_NhapCT_Nhap') ALTER TABLE dbo.QL_Kho_Nhap_CT DROP CONSTRAINT FK_QL_Kho_NhapCT_Nhap;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_NhapCT_Thuoc') ALTER TABLE dbo.QL_Kho_Nhap_CT DROP CONSTRAINT FK_QL_Kho_NhapCT_Thuoc;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_SoChungTu_CSKCB') ALTER TABLE dbo.QL_Kho_SoChungTu DROP CONSTRAINT FK_QL_Kho_SoChungTu_CSKCB;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_Xuat_CT_ChungTuThu') ALTER TABLE dbo.QL_Kho_Xuat_CT DROP CONSTRAINT FK_QL_Kho_Xuat_CT_ChungTuThu;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_Xuat_Kho') ALTER TABLE dbo.QL_Kho_Xuat DROP CONSTRAINT FK_QL_Kho_Xuat_Kho;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_Xuat_NV') ALTER TABLE dbo.QL_Kho_Xuat DROP CONSTRAINT FK_QL_Kho_Xuat_NV;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_Xuat_TaiKhoan') ALTER TABLE dbo.QL_Kho_Xuat DROP CONSTRAINT FK_QL_Kho_Xuat_TaiKhoan;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_Xuat_VV') ALTER TABLE dbo.QL_Kho_Xuat DROP CONSTRAINT FK_QL_Kho_Xuat_VV;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_XuatCT_Lo') ALTER TABLE dbo.QL_Kho_Xuat_CT DROP CONSTRAINT FK_QL_Kho_XuatCT_Lo;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_XuatCT_Thuoc') ALTER TABLE dbo.QL_Kho_Xuat_CT DROP CONSTRAINT FK_QL_Kho_XuatCT_Thuoc;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_XuatCT_Toa') ALTER TABLE dbo.QL_Kho_Xuat_CT DROP CONSTRAINT FK_QL_Kho_XuatCT_Toa;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_XuatCT_Xuat') ALTER TABLE dbo.QL_Kho_Xuat_CT DROP CONSTRAINT FK_QL_Kho_XuatCT_Xuat;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_XuatKhac_CT_H') ALTER TABLE dbo.QL_Kho_XuatKhac_CT DROP CONSTRAINT FK_QL_Kho_XuatKhac_CT_H;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_XuatKhac_CT_Lo') ALTER TABLE dbo.QL_Kho_XuatKhac_CT DROP CONSTRAINT FK_QL_Kho_XuatKhac_CT_Lo;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_XuatKhac_CT_Thuoc') ALTER TABLE dbo.QL_Kho_XuatKhac_CT DROP CONSTRAINT FK_QL_Kho_XuatKhac_CT_Thuoc;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_XuatKhac_Kho') ALTER TABLE dbo.QL_Kho_XuatKhac DROP CONSTRAINT FK_QL_Kho_XuatKhac_Kho;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_XuatKhac_NCC') ALTER TABLE dbo.QL_Kho_XuatKhac DROP CONSTRAINT FK_QL_Kho_XuatKhac_NCC;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_XuatKhac_TK') ALTER TABLE dbo.QL_Kho_XuatKhac DROP CONSTRAINT FK_QL_Kho_XuatKhac_TK;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_QL_Kho_XuatKhac_TKH') ALTER TABLE dbo.QL_Kho_XuatKhac DROP CONSTRAINT FK_QL_Kho_XuatKhac_TKH;
GO
DROP TABLE IF EXISTS dbo.QL_Kho_KiemKe_CT;
DROP TABLE IF EXISTS dbo.QL_Kho_KiemKe;
DROP TABLE IF EXISTS dbo.QL_Kho_XuatKhac_CT;
DROP TABLE IF EXISTS dbo.QL_Kho_XuatKhac;
DROP TABLE IF EXISTS dbo.QL_Kho_KhoaLo;
DROP TABLE IF EXISTS dbo.QL_Kho_SoChungTu;
DROP TABLE IF EXISTS dbo.QL_Kho_Hoan_CT;
DROP TABLE IF EXISTS dbo.QL_Kho_Hoan;
DROP TABLE IF EXISTS dbo.QL_Kho_Xuat_CT;
DROP TABLE IF EXISTS dbo.QL_Kho_Xuat;
DROP TABLE IF EXISTS dbo.QL_Kho_Nhap_CT;
DROP TABLE IF EXISTS dbo.QL_Kho_Nhap;
DROP TABLE IF EXISTS dbo.QL_Kho_DieuChinh_CT;
DROP TABLE IF EXISTS dbo.QL_Kho_DieuChinh;
GO
CREATE OR ALTER TRIGGER dbo.TR_QL_Kho_ChungTu_CT_GiaoDich
ON dbo.QL_Kho_ChungTu_CT AFTER INSERT AS
BEGIN
SET NOCOUNT ON;
INSERT dbo.QL_Kho_GiaoDich
(IDCSKCB,IDKho,IDThuoc,IDLoThuoc,LoaiGiaoDich,SoLuong,GiaVon,NgayGiaoDich,LoaiChungTu,IDChungTu,IDChungTuCT,IDTaiKhoan,IDNhanVien,TenNguoiThucHienSnapshot,GhiChu)
SELECT I.IDCSKCB,H.IDKho,I.IDThuoc,I.IDLoThuoc,'NHAP',I.SoLuongCoSo,L.GiaNhap,H.NgayNhap,'NHAP',H.ID,I.ID,
           H.IDTaiKhoanNhap,H.IDNhanVienNhap,COALESCE(NULLIF(H.TenNguoiNhapSnapshot,N''),N'Legacy/SQL caller'),H.GhiChu
    FROM (SELECT [ID], [IDCSKCB], [IDChungTu] AS [IDNhap], [IDThuoc], [IDDonViTinh], [HeSoQuyDoi], [SoLuong], [SoLuongCoSo], [GiaNhap], [ThanhTien], [SoLo], [HanDung], [IDLoThuoc], [TenThuocSnapshot], [MaThuocSnapshot], [DonViTinhSnapshot], [VAT], [TienVAT] FROM inserted WHERE LoaiChungTu='NHAP') I INNER JOIN (SELECT [ID], [IDCSKCB], [IDKho], [SoPhieu], [SoHoaDon], [NgayGio] AS [NgayNhap], [IDNhanVien] AS [IDNhanVienNhap], [TongTien], [GhiChu], [DaHuy], [IDNhaCungCap], [NgayHoaDon], [NgayGioHuy], [IDNhanVienHuy], [LyDoHuy], [TenNhaCungCapSnapshot], [IDTaiKhoan] AS [IDTaiKhoanNhap], [TenNguoiThucHienSnapshot] AS [TenNguoiNhapSnapshot], [IDTaiKhoanHuy], [TenNguoiHuySnapshot] FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='NHAP') H ON H.IDCSKCB=I.IDCSKCB AND H.ID=I.IDNhap
    INNER JOIN dbo.QL_Kho_LoThuoc L ON L.ID=I.IDLoThuoc
UNION ALL
SELECT I.IDCSKCB,H.IDKho,I.IDThuoc,I.IDLoThuoc,'CAP_PHAT',-I.SoLuongCoSo,I.GiaVon,H.NgayXuat,'CAP_PHAT',H.ID,I.ID,
           H.IDTaiKhoanXuat,H.IDNhanVienXuat,COALESCE(NULLIF(H.TenNguoiXuatSnapshot,N''),N'Legacy/SQL caller'),H.GhiChu
    FROM (SELECT [ID], [IDCSKCB], [IDChungTu] AS [IDXuat], [IDToaThuocCT], [IDThuoc], [IDLoThuoc], [SoLuongCoSo], [GiaVon], [ThanhTien], [SoLuongDaHoan], [IDThuTienChungTuCT], [HeSoQuyDoi] FROM inserted WHERE LoaiChungTu='CAP_PHAT') I INNER JOIN (SELECT [ID], [IDCSKCB], [IDKho], [IDVaoVien], [SoPhieu], [NgayGio] AS [NgayXuat], [IDNhanVien] AS [IDNhanVienXuat], [TongGiaVon], [GhiChu], [DaHuy], [IDTaiKhoan] AS [IDTaiKhoanXuat], [TenNguoiThucHienSnapshot] AS [TenNguoiXuatSnapshot] FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='CAP_PHAT') H ON H.IDCSKCB=I.IDCSKCB AND H.ID=I.IDXuat
UNION ALL
SELECT H.IDCSKCB,X.IDKho,XC.IDThuoc,XC.IDLoThuoc,
           CASE WHEN H.Loai='DAO_CAP_HUY_THU' THEN 'DAO_CAP_HUY_THU' ELSE 'HOAN' END,
           I.SoLuongCoSo,XC.GiaVon,H.NgayHoan,CASE WHEN H.Loai='DAO_CAP_HUY_THU' THEN 'DAO_CAP_HUY_THU' ELSE 'HOAN' END,H.ID,I.ID,
           H.IDTaiKhoanHoan,H.IDNhanVienHoan,COALESCE(NULLIF(H.TenNguoiHoanSnapshot,N''),N'Legacy/SQL caller'),H.LyDo
    FROM (SELECT [ID], [IDChungTu] AS [IDHoan], [IDChungTuCTGoc] AS [IDXuatCT], [SoLuongCoSo] FROM inserted WHERE LoaiChungTu='HOAN') I INNER JOIN (SELECT [ID], [IDCSKCB], [IDVaoVien], [SoPhieu], [NgayGio] AS [NgayHoan], [IDNhanVien] AS [IDNhanVienHoan], [LyDo], [IDTaiKhoan] AS [IDTaiKhoanHoan], [IDChungTuHuy], [LoaiNghiepVu] AS [Loai], [TenNguoiThucHienSnapshot] AS [TenNguoiHoanSnapshot] FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='HOAN') H ON H.ID=I.IDHoan
    INNER JOIN (SELECT [ID], [IDCSKCB], [IDChungTu] AS [IDXuat], [IDToaThuocCT], [IDThuoc], [IDLoThuoc], [SoLuongCoSo], [GiaVon], [ThanhTien], [SoLuongDaHoan], [IDThuTienChungTuCT], [HeSoQuyDoi] FROM dbo.QL_Kho_ChungTu_CT WHERE LoaiChungTu='CAP_PHAT') XC ON XC.ID=I.IDXuatCT
    INNER JOIN (SELECT [ID], [IDCSKCB], [IDKho], [IDVaoVien], [SoPhieu], [NgayGio] AS [NgayXuat], [IDNhanVien] AS [IDNhanVienXuat], [TongGiaVon], [GhiChu], [DaHuy], [IDTaiKhoan] AS [IDTaiKhoanXuat], [TenNguoiThucHienSnapshot] AS [TenNguoiXuatSnapshot] FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='CAP_PHAT') X ON X.IDCSKCB=XC.IDCSKCB AND X.ID=XC.IDXuat
UNION ALL
SELECT I.IDCSKCB,H.IDKho,L.IDThuoc,I.IDLoThuoc,CASE WHEN H.Loai='HUY_THUOC' THEN 'HUY_THUOC' ELSE 'DIEU_CHINH' END,
           I.SoLuongThayDoi,L.GiaNhap,H.NgayGio,H.Loai,H.ID,I.ID,H.IDTaiKhoan,H.IDNhanVien,
           COALESCE(NULLIF(H.TenNguoiThucHienSnapshot,N''),N'Legacy/SQL caller'),H.LyDo
    FROM (SELECT [ID], [IDCSKCB], [IDChungTu], [IDLoThuoc], [SoLuongThayDoi], [SoLuongTruoc], [SoLuongSau] FROM inserted WHERE LoaiChungTu='DIEU_CHINH') I INNER JOIN (SELECT [ID], [IDCSKCB], [IDKho], [LoaiNghiepVu] AS [Loai], [SoPhieu], [NgayGio], [IDNhanVien], [LyDo], [IDTaiKhoan], [TenNguoiThucHienSnapshot] FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='DIEU_CHINH') H ON H.IDCSKCB=I.IDCSKCB AND H.ID=I.IDChungTu
    INNER JOIN dbo.QL_Kho_LoThuoc L ON L.ID=I.IDLoThuoc;
END;
GO
CREATE OR ALTER TRIGGER dbo.TR_QL_Kho_ChungTu_HuyNhap_GiaoDich
ON dbo.QL_Kho_ChungTu AFTER UPDATE AS
BEGIN
 SET NOCOUNT ON;
 INSERT dbo.QL_Kho_GiaoDich
 (IDCSKCB,IDKho,IDThuoc,IDLoThuoc,LoaiGiaoDich,SoLuong,GiaVon,NgayGiaoDich,LoaiChungTu,IDChungTu,IDChungTuCT,IDTaiKhoan,IDNhanVien,TenNguoiThucHienSnapshot,GhiChu)
 SELECT N.IDCSKCB,N.IDKho,C.IDThuoc,C.IDLoThuoc,'DAO_NHAP',-C.SoLuongCoSo,L.GiaNhap,ISNULL(N.NgayGioHuy,SYSDATETIME()),'HUY_NHAP',N.ID,C.ID,N.IDTaiKhoanHuy,N.IDNhanVienHuy,COALESCE(NULLIF(N.TenNguoiHuySnapshot,N''),N'Legacy/SQL caller'),N.LyDoHuy
 FROM inserted N JOIN deleted O ON O.IDCSKCB=N.IDCSKCB AND O.LoaiChungTu=N.LoaiChungTu AND O.ID=N.ID
 JOIN dbo.QL_Kho_ChungTu_CT C ON C.IDCSKCB=N.IDCSKCB AND C.LoaiChungTu=N.LoaiChungTu AND C.IDChungTu=N.ID
 JOIN dbo.QL_Kho_LoThuoc L ON L.ID=C.IDLoThuoc
 WHERE N.LoaiChungTu='NHAP' AND O.DaHuy=0 AND N.DaHuy=1;
END;
GO
IF EXISTS(SELECT 1 FROM sys.sql_modules WHERE definition LIKE N'%dbo.QL_Kho_KiemKe_CT %' OR definition LIKE N'%dbo.QL_Kho_KiemKe_CT(%' OR definition LIKE N'%dbo.QL_Kho_KiemKe_CT'+CHAR(13)+'%' OR definition LIKE N'%dbo.QL_Kho_KiemKe_CT'+CHAR(10)+'%') THROW 59114,'SQL module still references QL_Kho_KiemKe_CT',1;
IF EXISTS(SELECT 1 FROM sys.sql_modules WHERE definition LIKE N'%dbo.QL_Kho_KiemKe %' OR definition LIKE N'%dbo.QL_Kho_KiemKe(%' OR definition LIKE N'%dbo.QL_Kho_KiemKe'+CHAR(13)+'%' OR definition LIKE N'%dbo.QL_Kho_KiemKe'+CHAR(10)+'%') THROW 59114,'SQL module still references QL_Kho_KiemKe',1;
IF EXISTS(SELECT 1 FROM sys.sql_modules WHERE definition LIKE N'%dbo.QL_Kho_XuatKhac_CT %' OR definition LIKE N'%dbo.QL_Kho_XuatKhac_CT(%' OR definition LIKE N'%dbo.QL_Kho_XuatKhac_CT'+CHAR(13)+'%' OR definition LIKE N'%dbo.QL_Kho_XuatKhac_CT'+CHAR(10)+'%') THROW 59114,'SQL module still references QL_Kho_XuatKhac_CT',1;
IF EXISTS(SELECT 1 FROM sys.sql_modules WHERE definition LIKE N'%dbo.QL_Kho_XuatKhac %' OR definition LIKE N'%dbo.QL_Kho_XuatKhac(%' OR definition LIKE N'%dbo.QL_Kho_XuatKhac'+CHAR(13)+'%' OR definition LIKE N'%dbo.QL_Kho_XuatKhac'+CHAR(10)+'%') THROW 59114,'SQL module still references QL_Kho_XuatKhac',1;
IF EXISTS(SELECT 1 FROM sys.sql_modules WHERE definition LIKE N'%dbo.QL_Kho_KhoaLo %' OR definition LIKE N'%dbo.QL_Kho_KhoaLo(%' OR definition LIKE N'%dbo.QL_Kho_KhoaLo'+CHAR(13)+'%' OR definition LIKE N'%dbo.QL_Kho_KhoaLo'+CHAR(10)+'%') THROW 59114,'SQL module still references QL_Kho_KhoaLo',1;
IF EXISTS(SELECT 1 FROM sys.sql_modules WHERE definition LIKE N'%dbo.QL_Kho_SoChungTu %' OR definition LIKE N'%dbo.QL_Kho_SoChungTu(%' OR definition LIKE N'%dbo.QL_Kho_SoChungTu'+CHAR(13)+'%' OR definition LIKE N'%dbo.QL_Kho_SoChungTu'+CHAR(10)+'%') THROW 59114,'SQL module still references QL_Kho_SoChungTu',1;
IF EXISTS(SELECT 1 FROM sys.sql_modules WHERE definition LIKE N'%dbo.QL_Kho_Hoan_CT %' OR definition LIKE N'%dbo.QL_Kho_Hoan_CT(%' OR definition LIKE N'%dbo.QL_Kho_Hoan_CT'+CHAR(13)+'%' OR definition LIKE N'%dbo.QL_Kho_Hoan_CT'+CHAR(10)+'%') THROW 59114,'SQL module still references QL_Kho_Hoan_CT',1;
IF EXISTS(SELECT 1 FROM sys.sql_modules WHERE definition LIKE N'%dbo.QL_Kho_Hoan %' OR definition LIKE N'%dbo.QL_Kho_Hoan(%' OR definition LIKE N'%dbo.QL_Kho_Hoan'+CHAR(13)+'%' OR definition LIKE N'%dbo.QL_Kho_Hoan'+CHAR(10)+'%') THROW 59114,'SQL module still references QL_Kho_Hoan',1;
IF EXISTS(SELECT 1 FROM sys.sql_modules WHERE definition LIKE N'%dbo.QL_Kho_Xuat_CT %' OR definition LIKE N'%dbo.QL_Kho_Xuat_CT(%' OR definition LIKE N'%dbo.QL_Kho_Xuat_CT'+CHAR(13)+'%' OR definition LIKE N'%dbo.QL_Kho_Xuat_CT'+CHAR(10)+'%') THROW 59114,'SQL module still references QL_Kho_Xuat_CT',1;
IF EXISTS(SELECT 1 FROM sys.sql_modules WHERE definition LIKE N'%dbo.QL_Kho_Xuat %' OR definition LIKE N'%dbo.QL_Kho_Xuat(%' OR definition LIKE N'%dbo.QL_Kho_Xuat'+CHAR(13)+'%' OR definition LIKE N'%dbo.QL_Kho_Xuat'+CHAR(10)+'%') THROW 59114,'SQL module still references QL_Kho_Xuat',1;
IF EXISTS(SELECT 1 FROM sys.sql_modules WHERE definition LIKE N'%dbo.QL_Kho_Nhap_CT %' OR definition LIKE N'%dbo.QL_Kho_Nhap_CT(%' OR definition LIKE N'%dbo.QL_Kho_Nhap_CT'+CHAR(13)+'%' OR definition LIKE N'%dbo.QL_Kho_Nhap_CT'+CHAR(10)+'%') THROW 59114,'SQL module still references QL_Kho_Nhap_CT',1;
IF EXISTS(SELECT 1 FROM sys.sql_modules WHERE definition LIKE N'%dbo.QL_Kho_Nhap %' OR definition LIKE N'%dbo.QL_Kho_Nhap(%' OR definition LIKE N'%dbo.QL_Kho_Nhap'+CHAR(13)+'%' OR definition LIKE N'%dbo.QL_Kho_Nhap'+CHAR(10)+'%') THROW 59114,'SQL module still references QL_Kho_Nhap',1;
IF EXISTS(SELECT 1 FROM sys.sql_modules WHERE definition LIKE N'%dbo.QL_Kho_DieuChinh_CT %' OR definition LIKE N'%dbo.QL_Kho_DieuChinh_CT(%' OR definition LIKE N'%dbo.QL_Kho_DieuChinh_CT'+CHAR(13)+'%' OR definition LIKE N'%dbo.QL_Kho_DieuChinh_CT'+CHAR(10)+'%') THROW 59114,'SQL module still references QL_Kho_DieuChinh_CT',1;
IF EXISTS(SELECT 1 FROM sys.sql_modules WHERE definition LIKE N'%dbo.QL_Kho_DieuChinh %' OR definition LIKE N'%dbo.QL_Kho_DieuChinh(%' OR definition LIKE N'%dbo.QL_Kho_DieuChinh'+CHAR(13)+'%' OR definition LIKE N'%dbo.QL_Kho_DieuChinh'+CHAR(10)+'%') THROW 59114,'SQL module still references QL_Kho_DieuChinh',1;
GO
