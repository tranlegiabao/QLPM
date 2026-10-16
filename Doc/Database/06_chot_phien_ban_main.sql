/* Chi chot version sau khi 05_kiem_tra_main.sql da chay thanh cong. */
USE [QLPM];
GO
SET NOCOUNT ON;
GO

IF ISNULL(TRY_CONVERT(INT,SESSION_CONTEXT(N'QLPM_MAIN_VERIFIED')),0)<>114
    THROW 59099,N'Khong duoc chay file chot version rieng le. Hay chay 00_CapNhat_TatCa.sql de verifier trong cung session.',1;
GO

IF OBJECT_ID(N'dbo.QLPM_SchemaVersion',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.QLPM_SchemaVersion
    (
        VersionNo INT NOT NULL CONSTRAINT PK_QLPM_SchemaVersion PRIMARY KEY,
        TenMigration NVARCHAR(255) NOT NULL,
        BranchName NVARCHAR(50) NOT NULL,
        AppliedAt DATETIME2(0) NOT NULL
            CONSTRAINT DF_QLPM_SchemaVersion_AppliedAt DEFAULT(SYSDATETIME())
    );
END;
GO

IF NOT EXISTS(SELECT 1 FROM dbo.QLPM_SchemaVersion WHERE VersionNo=94)
    INSERT dbo.QLPM_SchemaVersion(VersionNo,TenMigration,BranchName)
    VALUES(94,N'main-cashier-inventory-documents-v94',N'main');
GO

IF NOT EXISTS(SELECT 1 FROM dbo.QLPM_SchemaVersion WHERE VersionNo=95)
    INSERT dbo.QLPM_SchemaVersion(VersionNo,TenMigration,BranchName)
    VALUES(95,N'main-cashier-inventory-his-safety-v95',N'main');
GO

IF NOT EXISTS(SELECT 1 FROM dbo.QLPM_SchemaVersion WHERE VersionNo=96)
    INSERT dbo.QLPM_SchemaVersion(VersionNo,TenMigration,BranchName)
    VALUES(96,N'main-inventory-dispense-account-audit-v96',N'main');
GO

IF NOT EXISTS(SELECT 1 FROM dbo.QLPM_SchemaVersion WHERE VersionNo=97)
    INSERT dbo.QLPM_SchemaVersion(VersionNo,TenMigration,BranchName)
    VALUES(97,N'main-cashier-internal-cls-during-exam-v97',N'main');
GO

IF NOT EXISTS(SELECT 1 FROM dbo.QLPM_SchemaVersion WHERE VersionNo=98)
    INSERT dbo.QLPM_SchemaVersion(VersionNo,TenMigration,BranchName)
    VALUES(98,N'main-cashier-cancel-auto-reverse-dispense-v98',N'main');
GO

IF NOT EXISTS(SELECT 1 FROM dbo.QLPM_SchemaVersion WHERE VersionNo=99)
    INSERT dbo.QLPM_SchemaVersion(VersionNo,TenMigration,BranchName)
    VALUES(99,N'main-cskcb-upfront-exam-fee-config-v99',N'main');
ELSE
    UPDATE dbo.QLPM_SchemaVersion
    SET TenMigration=N'main-cskcb-upfront-exam-fee-config-v99',
        BranchName=N'main'
    WHERE VersionNo=99;
GO

IF NOT EXISTS(SELECT 1 FROM dbo.QLPM_SchemaVersion WHERE VersionNo=100)
    INSERT dbo.QLPM_SchemaVersion(VersionNo,TenMigration,BranchName)
    VALUES(100,N'main-cskcb-upfront-cls-order-config-v100',N'main');
ELSE
    UPDATE dbo.QLPM_SchemaVersion
    SET TenMigration=N'main-cskcb-upfront-cls-order-config-v100',
        BranchName=N'main'
    WHERE VersionNo=100;
GO

IF NOT EXISTS(SELECT 1 FROM dbo.QLPM_SchemaVersion WHERE VersionNo=104)
    INSERT dbo.QLPM_SchemaVersion(VersionNo,TenMigration,BranchName)
    VALUES(104,N'main-national-prescription-signing-framework-v104',N'Hieu_05/10');
ELSE
    UPDATE dbo.QLPM_SchemaVersion
    SET TenMigration=N'main-national-prescription-signing-framework-v104',
        BranchName=N'Hieu_05/10'
    WHERE VersionNo=104;
GO

IF NOT EXISTS(SELECT 1 FROM dbo.QLPM_SchemaVersion WHERE VersionNo=105)
    INSERT dbo.QLPM_SchemaVersion(VersionNo,TenMigration,BranchName)
    VALUES(105,N'split-signing-and-national-prescription-delivery-v105',N'Hieu_12/10');
GO

IF NOT EXISTS(SELECT 1 FROM dbo.QLPM_SchemaVersion WHERE VersionNo=106)
    INSERT dbo.QLPM_SchemaVersion(VersionNo,TenMigration,BranchName)
    VALUES(106,N'inventory-supplier-directory-v106',N'Hieu_12/10');
GO

IF NOT EXISTS(SELECT 1 FROM dbo.QLPM_SchemaVersion WHERE VersionNo=107)
    INSERT dbo.QLPM_SchemaVersion(VersionNo,TenMigration,BranchName)
    VALUES(107,N'pdf-signing-template-and-document-framework-v107',N'Hieu_12/10_1');
GO

IF NOT EXISTS(SELECT 1 FROM dbo.QLPM_SchemaVersion WHERE VersionNo=108)
    INSERT dbo.QLPM_SchemaVersion(VersionNo,TenMigration,BranchName)
    VALUES(108,N'national-prescription-direct-delivery-v108',N'Hieu_12/10_1');
GO

IF NOT EXISTS(SELECT 1 FROM dbo.QLPM_SchemaVersion WHERE VersionNo=109)
    INSERT dbo.QLPM_SchemaVersion(VersionNo,TenMigration,BranchName)
    VALUES(109,N'pdf-signing-business-flow-v109',N'Hieu_12/10_1');
GO
IF NOT EXISTS(SELECT 1 FROM dbo.QLPM_SchemaVersion WHERE VersionNo=110)
    INSERT dbo.QLPM_SchemaVersion(VersionNo,TenMigration,BranchName)
    VALUES(110,N'pdf-signing-complete-documents-v110',N'Hieu_12/10_1');
GO
IF NOT EXISTS(SELECT 1 FROM dbo.QLPM_SchemaVersion WHERE VersionNo=111)
    INSERT dbo.QLPM_SchemaVersion(VersionNo,TenMigration,BranchName)
    VALUES(111,N'pdf-signing-dynamic-saved-documents-v111',N'Hieu_12/10_1');
GO
IF NOT EXISTS(SELECT 1 FROM dbo.QLPM_SchemaVersion WHERE VersionNo=112)
    INSERT dbo.QLPM_SchemaVersion(VersionNo,TenMigration,BranchName)
    VALUES(112,N'cls-image-dispensing-print-v112',N'Hieu_12/10_1');
GO
IF NOT EXISTS(SELECT 1 FROM dbo.QLPM_SchemaVersion WHERE VersionNo=113)
    INSERT dbo.QLPM_SchemaVersion(VersionNo,TenMigration,BranchName)
    VALUES(113,N'signed-pdf-print-and-active-dispensing-v113',N'Hieu_12/10_1');
GO
IF NOT EXISTS(SELECT 1 FROM dbo.QLPM_SchemaVersion WHERE VersionNo=114)
 INSERT dbo.QLPM_SchemaVersion(VersionNo,TenMigration,BranchName) VALUES(114,N'warehouse-canonical-documents-v114',N'Hieu_12/10_1');
GO
PRINT N'06_chot_phien_ban_main.sql: OK - schema main version 114.';
GO
