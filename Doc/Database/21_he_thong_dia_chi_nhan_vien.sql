/*
21_he_thong_dia_chi_nhan_vien.sql
- Bo sung ma Tinh/Thanh, Phuong/Xa cho CSKCB va nhan vien.
- Luu ma danh muc de dung chung duoc giua cac tenant; ten hien thi lay tu DM_TinhThanh/DM_PhuongXa.
*/
USE [QLPM];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF COL_LENGTH(N'dbo.DM_CSKCB',N'SoNhaTenDuong') IS NULL
    ALTER TABLE dbo.DM_CSKCB ADD SoNhaTenDuong NVARCHAR(300) NULL;
GO
IF COL_LENGTH(N'dbo.DM_CSKCB',N'MaTinh') IS NULL
    ALTER TABLE dbo.DM_CSKCB ADD MaTinh NVARCHAR(20) NULL;
GO
IF COL_LENGTH(N'dbo.DM_CSKCB',N'MaPhuongXa') IS NULL
    ALTER TABLE dbo.DM_CSKCB ADD MaPhuongXa NVARCHAR(20) NULL;
GO

IF COL_LENGTH(N'dbo.DM_NhanVien',N'SoNhaTenDuong') IS NULL
    ALTER TABLE dbo.DM_NhanVien ADD SoNhaTenDuong NVARCHAR(300) NULL;
GO
IF COL_LENGTH(N'dbo.DM_NhanVien',N'DiaChi') IS NULL
    ALTER TABLE dbo.DM_NhanVien ADD DiaChi NVARCHAR(500) NULL;
GO
IF COL_LENGTH(N'dbo.DM_NhanVien',N'MaTinh') IS NULL
    ALTER TABLE dbo.DM_NhanVien ADD MaTinh NVARCHAR(20) NULL;
GO
IF COL_LENGTH(N'dbo.DM_NhanVien',N'MaPhuongXa') IS NULL
    ALTER TABLE dbo.DM_NhanVien ADD MaPhuongXa NVARCHAR(20) NULL;
GO

UPDATE dbo.DM_CSKCB
SET SoNhaTenDuong=DiaChi
WHERE SoNhaTenDuong IS NULL
  AND NULLIF(LTRIM(RTRIM(DiaChi)),N'') IS NOT NULL
  AND MaTinh IS NULL
  AND MaPhuongXa IS NULL;
GO

PRINT N'21_he_thong_dia_chi_nhan_vien.sql: OK';
GO
