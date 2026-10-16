/*
25a_common_nhan_vien_chuc_danh_schema.sql

Schema prelude cho v85.
Phai chay TRUOC cac script auth/quan tri tao STO co tham chieu:
- DM_NhanVien.IDChucDanh
- DM_NhanVien_CSKCB
- DM_ChucDanh

File 25_common_nhan_vien_nhieu_cskcb_chuc_danh.sql van duoc chay o cuoi
de cap nhat STO/trigger runtime. Prelude nay chi chuyen schema va du lieu cu.
*/
USE [QLPM];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* Prelude may run again after v84/v85 triggers already exist. Recreate the
   title trigger in script 25 after canonical seed/remap is complete. */
DROP TRIGGER IF EXISTS dbo.TR_DM_ChucDanh_JSON_VERSION;
GO

/* ==================== 1. DANH MUC CHUC DANH ==================== */
IF OBJECT_ID(N'dbo.DM_ChucDanh',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DM_ChucDanh
    (
        ID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DM_ChucDanh PRIMARY KEY,
        MaChucDanh NVARCHAR(60) NOT NULL,
        TenChucDanh NVARCHAR(200) NOT NULL,
        VietTat NVARCHAR(50) NULL,
        Active BIT NOT NULL CONSTRAINT DF_DM_ChucDanh_Active DEFAULT(1)
    );
    CREATE UNIQUE INDEX UQ_DM_ChucDanh_Ma ON dbo.DM_ChucDanh(MaChucDanh);
    CREATE UNIQUE INDEX UQ_DM_ChucDanh_Ten ON dbo.DM_ChucDanh(TenChucDanh);
END;
GO

IF COL_LENGTH(N'dbo.DM_NhanVien',N'IDChucDanh') IS NULL
    ALTER TABLE dbo.DM_NhanVien ADD IDChucDanh BIGINT NULL;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.foreign_keys
    WHERE parent_object_id=OBJECT_ID(N'dbo.DM_NhanVien')
      AND name=N'FK_DM_NhanVien_ChucDanh'
)
BEGIN
    ALTER TABLE dbo.DM_NhanVien WITH CHECK
    ADD CONSTRAINT FK_DM_NhanVien_ChucDanh
        FOREIGN KEY(IDChucDanh) REFERENCES dbo.DM_ChucDanh(ID);
END;
GO

/* Đảm bảo danh mục chức danh canonical 1..11 */
DECLARE @CanonTitlesPrelude TABLE (
    MaChucDanh NVARCHAR(60),
    TenChucDanh NVARCHAR(200),
    VietTat NVARCHAR(50),
    Active BIT
);
INSERT INTO @CanonTitlesPrelude VALUES
(N'1', N'Bác sĩ', N'BS', 1),
(N'2', N'Y sĩ', N'YS', 1),
(N'3', N'Điều dưỡng', N'ĐD', 1),
(N'4', N'Nữ hộ sinh', N'NHS', 1),
(N'5', N'Kỹ thuật viên', N'KTV', 1),
(N'6', N'Cử nhân CĐHA', N'CN CĐHA', 1),
(N'7', N'Dược sĩ đại học', N'DSĐH', 1),
(N'8', N'Dược sĩ trung cấp', N'DSTC', 1),
(N'9', N'Lương y', N'LY', 0),
(N'10', N'Cử nhân xét nghiệm', N'CN XN', 1),
(N'11', N'Dược sĩ cao đẳng', N'DSCĐ', 1);

INSERT INTO dbo.DM_ChucDanh (MaChucDanh, TenChucDanh, VietTat, Active)
SELECT S.MaChucDanh, S.TenChucDanh, S.VietTat, S.Active
FROM @CanonTitlesPrelude S
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.DM_ChucDanh C
    WHERE C.MaChucDanh = S.MaChucDanh OR LOWER(LTRIM(RTRIM(C.TenChucDanh))) = LOWER(LTRIM(RTRIM(S.TenChucDanh)))
);
GO

IF COL_LENGTH(N'dbo.DM_NhanVien', N'ChucDanh') IS NOT NULL
BEGIN
    EXEC(N'
        UPDATE N
        SET IDChucDanh=C.ID
        FROM dbo.DM_NhanVien N
        INNER JOIN dbo.DM_ChucDanh C
            ON LOWER(LTRIM(RTRIM(C.TenChucDanh)))=LOWER(LTRIM(RTRIM(N.ChucDanh)))
            OR LOWER(LTRIM(RTRIM(C.VietTat)))=LOWER(LTRIM(RTRIM(N.ChucDanh)))
        WHERE N.IDChucDanh IS NULL
          AND NULLIF(LTRIM(RTRIM(N.ChucDanh)),N'''') IS NOT NULL;');
END;
GO

/* ==================== 2. QUAN HE N-N NHAN VIEN - CSKCB ==================== */
IF OBJECT_ID(N'dbo.DM_NhanVien_CSKCB',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DM_NhanVien_CSKCB
    (
        IDNhanVien BIGINT NOT NULL,
        IDCSKCB BIGINT NOT NULL,
        Active BIT NOT NULL CONSTRAINT DF_DM_NhanVien_CSKCB_Active DEFAULT(1),
        CONSTRAINT PK_DM_NhanVien_CSKCB PRIMARY KEY(IDNhanVien,IDCSKCB),
        CONSTRAINT FK_DM_NhanVien_CSKCB_NhanVien FOREIGN KEY(IDNhanVien) REFERENCES dbo.DM_NhanVien(ID),
        CONSTRAINT FK_DM_NhanVien_CSKCB_CSKCB FOREIGN KEY(IDCSKCB) REFERENCES dbo.DM_CSKCB(ID)
    );
    CREATE INDEX IX_DM_NhanVien_CSKCB_CSKCB_Active
        ON dbo.DM_NhanVien_CSKCB(IDCSKCB,Active,IDNhanVien);
END;
GO

/* Backfill quan he cu truoc khi bo DM_NhanVien.IDCSKCB. */
IF COL_LENGTH(N'dbo.DM_NhanVien',N'IDCSKCB') IS NOT NULL
BEGIN
    EXEC(N'
        INSERT dbo.DM_NhanVien_CSKCB(IDNhanVien,IDCSKCB,Active)
        SELECT N.ID,N.IDCSKCB,N.Active
        FROM dbo.DM_NhanVien N
        WHERE N.IDCSKCB IS NOT NULL
          AND NOT EXISTS
          (
              SELECT 1 FROM dbo.DM_NhanVien_CSKCB X
              WHERE X.IDNhanVien=N.ID AND X.IDCSKCB=N.IDCSKCB
          );');
END;
GO

/*
Chuyen cac FK nghiep vu dang tham chieu (IDCSKCB, IDNhanVien) ve chi IDNhanVien.
IDNhanVien la dinh danh toan he thong; CSKCB cua nghiep vu duoc rang buoc bang DM_NhanVien_CSKCB.
*/
DECLARE @FkName SYSNAME,@ParentSchema SYSNAME,@ParentTable SYSNAME,@ParentColumn SYSNAME,@sql NVARCHAR(MAX);

DECLARE fk_nv CURSOR LOCAL FAST_FORWARD FOR
SELECT
    FK.name,
    PS.name,
    PT.name,
    PC.name
FROM sys.foreign_keys FK
INNER JOIN sys.tables PT ON PT.object_id=FK.parent_object_id
INNER JOIN sys.schemas PS ON PS.schema_id=PT.schema_id
INNER JOIN sys.foreign_key_columns FKC
    ON FKC.constraint_object_id=FK.object_id
INNER JOIN sys.columns PC
    ON PC.object_id=FK.parent_object_id AND PC.column_id=FKC.parent_column_id
INNER JOIN sys.columns RC
    ON RC.object_id=FK.referenced_object_id AND RC.column_id=FKC.referenced_column_id
WHERE FK.referenced_object_id=OBJECT_ID(N'dbo.DM_NhanVien')
  AND RC.name=N'ID'
  AND (SELECT COUNT(*) FROM sys.foreign_key_columns X WHERE X.constraint_object_id=FK.object_id)>1;

OPEN fk_nv;
FETCH NEXT FROM fk_nv INTO @FkName,@ParentSchema,@ParentTable,@ParentColumn;
WHILE @@FETCH_STATUS=0
BEGIN
    SET @sql=N'ALTER TABLE '+QUOTENAME(@ParentSchema)+N'.'+QUOTENAME(@ParentTable)
        +N' DROP CONSTRAINT '+QUOTENAME(@FkName)+N';'
        +N' ALTER TABLE '+QUOTENAME(@ParentSchema)+N'.'+QUOTENAME(@ParentTable)
        +N' WITH CHECK ADD CONSTRAINT '+QUOTENAME(@FkName)
        +N' FOREIGN KEY('+QUOTENAME(@ParentColumn)+N') REFERENCES dbo.DM_NhanVien(ID);';
    EXEC sys.sp_executesql @sql;
    FETCH NEXT FROM fk_nv INTO @FkName,@ParentSchema,@ParentTable,@ParentColumn;
END;
CLOSE fk_nv;
DEALLOCATE fk_nv;
GO

/* Trigger cu tham chieu IDCSKCB; bo truoc khi xoa cot va tao lai o cuoi file. */
IF OBJECT_ID(N'dbo.TR_DM_NhanVien_JSON_VERSION',N'TR') IS NOT NULL
    DROP TRIGGER dbo.TR_DM_NhanVien_JSON_VERSION;
GO

/* Bo quan he 1-N cu: DM_NhanVien.IDCSKCB. */
IF EXISTS
(
    SELECT 1 FROM sys.foreign_keys
    WHERE parent_object_id=OBJECT_ID(N'dbo.DM_NhanVien')
      AND name=N'FK_DM_NhanVien_CSKCB'
)
    ALTER TABLE dbo.DM_NhanVien DROP CONSTRAINT FK_DM_NhanVien_CSKCB;
GO

/* Hai UQ cu co the la UNIQUE CONSTRAINT (tao ra unique index noi bo),
   nen phai DROP CONSTRAINT truoc; chi DROP INDEX neu DB cu tao no nhu index thuong. */
IF EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id=OBJECT_ID(N'dbo.DM_NhanVien')
      AND name=N'UQ_DM_NhanVien_CSKCB_ID'
)
    ALTER TABLE dbo.DM_NhanVien DROP CONSTRAINT UQ_DM_NhanVien_CSKCB_ID;
ELSE IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'dbo.DM_NhanVien')
      AND name=N'UQ_DM_NhanVien_CSKCB_ID'
      AND is_unique_constraint=0
)
    DROP INDEX UQ_DM_NhanVien_CSKCB_ID ON dbo.DM_NhanVien;
GO

IF EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id=OBJECT_ID(N'dbo.DM_NhanVien')
      AND name=N'UQ_DM_NhanVien_CSKCB_Ma'
)
    ALTER TABLE dbo.DM_NhanVien DROP CONSTRAINT UQ_DM_NhanVien_CSKCB_Ma;
ELSE IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'dbo.DM_NhanVien')
      AND name=N'UQ_DM_NhanVien_CSKCB_Ma'
      AND is_unique_constraint=0
)
    DROP INDEX UQ_DM_NhanVien_CSKCB_Ma ON dbo.DM_NhanVien;
GO

IF COL_LENGTH(N'dbo.DM_NhanVien',N'IDCSKCB') IS NOT NULL
    ALTER TABLE dbo.DM_NhanVien DROP COLUMN IDCSKCB;
GO

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.DM_NhanVien') AND name=N'IX_DM_NhanVien_MaNhanVien')
    CREATE INDEX IX_DM_NhanVien_MaNhanVien ON dbo.DM_NhanVien(MaNhanVien);
GO

PRINT N'25a_common_nhan_vien_chuc_danh_schema.sql: OK';
GO
