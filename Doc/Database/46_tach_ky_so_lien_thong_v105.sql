:ON ERROR EXIT
USE [QLPM];
GO
SET NOCOUNT ON;
GO

-- v105: tach cau hinh hai chuc nang; ke thua gia tri HieuLuc cu khi moi nang cap.
IF OBJECT_ID(N'dbo.HT_LienThongToaThuoc_CauHinh',N'U') IS NULL
    THROW 59151,N'Thieu bang cau hinh toa thuoc quoc gia v104.',1;
GO

IF COL_LENGTH(N'dbo.HT_LienThongToaThuoc_CauHinh',N'KySoHieuLuc') IS NULL
BEGIN
    ALTER TABLE dbo.HT_LienThongToaThuoc_CauHinh
        ADD KySoHieuLuc BIT NOT NULL CONSTRAINT DF_HT_LTTT_KySoHieuLuc DEFAULT(0);
    EXEC sys.sp_executesql N'UPDATE dbo.HT_LienThongToaThuoc_CauHinh SET KySoHieuLuc=HieuLuc;';
END;
GO

IF COL_LENGTH(N'dbo.HT_LienThongToaThuoc_CauHinh',N'LienThongHieuLuc') IS NULL
BEGIN
    ALTER TABLE dbo.HT_LienThongToaThuoc_CauHinh
        ADD LienThongHieuLuc BIT NOT NULL CONSTRAINT DF_HT_LTTT_LienThongHieuLuc DEFAULT(0);
    EXEC sys.sp_executesql N'UPDATE dbo.HT_LienThongToaThuoc_CauHinh SET LienThongHieuLuc=HieuLuc;';
END;
GO

PRINT N'46_tach_ky_so_lien_thong_v105.sql: cau hinh da tach.';
GO
