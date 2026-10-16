:ON ERROR EXIT
/* 26_pdf_only_cls_va_cleanup_schema.sql - idempotent schema v85 cleanup. */
USE [QLPM];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF DB_NAME()<>N'QLPM'
    THROW 59085,N'Migration 26 chỉ được chạy trên database QLPM.',1;
GO

/* 1. One PDF path is the only CLS result contract. */
IF COL_LENGTH(N'dbo.QL_ChiDinh_CT',N'DuongDanKetQua') IS NULL
    ALTER TABLE dbo.QL_ChiDinh_CT ADD DuongDanKetQua NVARCHAR(1000) NULL;
GO
IF EXISTS
(
    SELECT 1 FROM sys.columns C
    INNER JOIN sys.types T ON T.user_type_id=C.user_type_id
    WHERE C.object_id=OBJECT_ID(N'dbo.QL_ChiDinh_CT') AND C.name=N'DuongDanKetQua'
      AND (T.name<>N'nvarchar' OR C.max_length<>2000 OR C.is_nullable<>1)
)
    ALTER TABLE dbo.QL_ChiDinh_CT ALTER COLUMN DuongDanKetQua NVARCHAR(1000) NULL;
GO

/* Migrate the newest active path that satisfies the new PDF contract. */
IF OBJECT_ID(N'dbo.QL_CLS_PhieuKetQua_File',N'U') IS NOT NULL
AND OBJECT_ID(N'dbo.QL_CLS_PhieuKetQua',N'U') IS NOT NULL
AND COL_LENGTH(N'dbo.QL_CLS_PhieuKetQua_File',N'DuongDanTuongDoi') IS NOT NULL
AND COL_LENGTH(N'dbo.QL_CLS_PhieuKetQua_File',N'NgayTaiLen') IS NOT NULL
AND COL_LENGTH(N'dbo.QL_CLS_PhieuKetQua',N'IDChiDinhCT') IS NOT NULL
BEGIN
    EXEC sys.sp_executesql N'
        ;WITH F AS
        (
            SELECT P.IDChiDinhCT,X.DuongDanTuongDoi,
                   ROW_NUMBER() OVER(PARTITION BY P.IDChiDinhCT ORDER BY X.NgayTaiLen DESC,X.ID DESC) AS RN
            FROM dbo.QL_CLS_PhieuKetQua_File X
            INNER JOIN dbo.QL_CLS_PhieuKetQua P ON P.IDCSKCB=X.IDCSKCB AND P.ID=X.IDPhieuKetQua
            WHERE X.Active=1 AND P.Active=1
              AND NULLIF(LTRIM(RTRIM(X.DuongDanTuongDoi)),N'''') IS NOT NULL
              AND LOWER(RIGHT(RTRIM(X.DuongDanTuongDoi),4))=N''.pdf''
        )
        UPDATE C SET DuongDanKetQua=F.DuongDanTuongDoi
        FROM dbo.QL_ChiDinh_CT C INNER JOIN F ON F.IDChiDinhCT=C.ID AND F.RN=1
        WHERE NULLIF(LTRIM(RTRIM(C.DuongDanKetQua)),N'''') IS NULL;';
END;
GO

IF OBJECT_ID(N'dbo.QL_KetQuaCLS_File',N'U') IS NOT NULL
AND OBJECT_ID(N'dbo.QL_KetQuaCLS',N'U') IS NOT NULL
AND COL_LENGTH(N'dbo.QL_KetQuaCLS_File',N'DuongDanTuongDoi') IS NOT NULL
AND COL_LENGTH(N'dbo.QL_KetQuaCLS_File',N'NgayTaiLen') IS NOT NULL
AND COL_LENGTH(N'dbo.QL_KetQuaCLS',N'IDChiDinhCT') IS NOT NULL
BEGIN
    EXEC sys.sp_executesql N'
        ;WITH F AS
        (
            SELECT P.IDChiDinhCT,X.DuongDanTuongDoi,
                   ROW_NUMBER() OVER(PARTITION BY P.IDChiDinhCT ORDER BY X.NgayTaiLen DESC,X.ID DESC) AS RN
            FROM dbo.QL_KetQuaCLS_File X
            INNER JOIN dbo.QL_KetQuaCLS P ON P.IDCSKCB=X.IDCSKCB AND P.ID=X.IDKetQuaCLS
            WHERE X.Active=1 AND P.Active=1
              AND NULLIF(LTRIM(RTRIM(X.DuongDanTuongDoi)),N'''') IS NOT NULL
              AND LOWER(RIGHT(RTRIM(X.DuongDanTuongDoi),4))=N''.pdf''
        )
        UPDATE C SET DuongDanKetQua=F.DuongDanTuongDoi
        FROM dbo.QL_ChiDinh_CT C INNER JOIN F ON F.IDChiDinhCT=C.ID AND F.RN=1
        WHERE NULLIF(LTRIM(RTRIM(C.DuongDanKetQua)),N'''') IS NULL;';
END;
GO

/* 2. Canonical professional titles. */
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
END;
GO
IF COL_LENGTH(N'dbo.DM_NhanVien',N'IDChucDanh') IS NULL
    ALTER TABLE dbo.DM_NhanVien ADD IDChucDanh BIGINT NULL;
GO

DECLARE @CanonicalTitle TABLE(Ma NVARCHAR(60) PRIMARY KEY,Ten NVARCHAR(200),VietTat NVARCHAR(50),Active BIT);
INSERT @CanonicalTitle VALUES
(N'1',N'Bác sĩ',N'BS',1),(N'2',N'Y sĩ',N'YS',1),(N'3',N'Điều dưỡng',N'ĐD',1),
(N'4',N'Nữ hộ sinh',N'NHS',1),(N'5',N'Kỹ thuật viên',N'KTV',1),
(N'6',N'Cử nhân CĐHA',N'CN CĐHA',1),(N'7',N'Dược sĩ đại học',N'DSĐH',1),
(N'8',N'Dược sĩ trung cấp',N'DSTC',1),(N'9',N'Lương y',N'LY',0),
(N'10',N'Cử nhân xét nghiệm',N'CN XN',1),(N'11',N'Dược sĩ cao đẳng',N'DSCĐ',1);

DECLARE @Ma NVARCHAR(60),@Ten NVARCHAR(200),@VietTat NVARCHAR(50),@Active BIT;
DECLARE CTitle CURSOR LOCAL FAST_FORWARD FOR
    SELECT Ma,Ten,VietTat,Active FROM @CanonicalTitle ORDER BY TRY_CONVERT(INT,Ma);
OPEN CTitle;
FETCH NEXT FROM CTitle INTO @Ma,@Ten,@VietTat,@Active;
WHILE @@FETCH_STATUS=0
BEGIN
    DECLARE @IDByCode BIGINT=(SELECT TOP(1) ID FROM dbo.DM_ChucDanh WHERE MaChucDanh=@Ma ORDER BY ID);
    DECLARE @IDByName BIGINT=(SELECT TOP(1) ID FROM dbo.DM_ChucDanh WHERE TenChucDanh=@Ten ORDER BY ID);
    IF @IDByCode IS NOT NULL AND @IDByName IS NOT NULL AND @IDByCode<>@IDByName
    BEGIN
        UPDATE dbo.DM_NhanVien SET IDChucDanh=@IDByCode WHERE IDChucDanh=@IDByName;
        DELETE dbo.DM_ChucDanh WHERE ID=@IDByName;
    END;
    IF @IDByCode IS NULL
    BEGIN
        SET @IDByName=(SELECT TOP(1) ID FROM dbo.DM_ChucDanh WHERE TenChucDanh=@Ten ORDER BY ID);
        IF @IDByName IS NOT NULL
        BEGIN
            UPDATE dbo.DM_ChucDanh SET MaChucDanh=@Ma,VietTat=@VietTat,Active=@Active WHERE ID=@IDByName;
            SET @IDByCode=@IDByName;
        END
        ELSE
        BEGIN
            INSERT dbo.DM_ChucDanh(MaChucDanh,TenChucDanh,VietTat,Active) VALUES(@Ma,@Ten,@VietTat,@Active);
            SET @IDByCode=SCOPE_IDENTITY();
        END;
    END;
    UPDATE dbo.DM_ChucDanh SET TenChucDanh=@Ten,VietTat=@VietTat,Active=@Active WHERE ID=@IDByCode;
    FETCH NEXT FROM CTitle INTO @Ma,@Ten,@VietTat,@Active;
END;
CLOSE CTitle;
DEALLOCATE CTitle;

/* Remap recognizable variants; organizational roles are not professional titles. */
UPDATE N SET IDChucDanh=C.ID
FROM dbo.DM_NhanVien N
INNER JOIN dbo.DM_ChucDanh O ON O.ID=N.IDChucDanh
CROSS APPLY
(
    SELECT CASE
        WHEN LOWER(LTRIM(RTRIM(O.TenChucDanh))) LIKE N'bác sĩ%' OR LOWER(LTRIM(RTRIM(O.TenChucDanh))) IN(N'bs',N'b.s') THEN N'1'
        WHEN LOWER(LTRIM(RTRIM(O.TenChucDanh))) LIKE N'y sĩ%' THEN N'2'
        WHEN LOWER(LTRIM(RTRIM(O.TenChucDanh))) LIKE N'điều dưỡng%' THEN N'3'
        WHEN LOWER(LTRIM(RTRIM(O.TenChucDanh))) LIKE N'nữ hộ sinh%' THEN N'4'
        WHEN LOWER(LTRIM(RTRIM(O.TenChucDanh))) LIKE N'kỹ thuật viên%' THEN N'5'
        WHEN LOWER(LTRIM(RTRIM(O.TenChucDanh))) LIKE N'cử nhân cđha%' THEN N'6'
        WHEN LOWER(LTRIM(RTRIM(O.TenChucDanh))) IN(N'dược sĩ',N'dược sĩ đại học') THEN N'7'
        WHEN LOWER(LTRIM(RTRIM(O.TenChucDanh))) LIKE N'dược sĩ trung cấp%' THEN N'8'
        WHEN LOWER(LTRIM(RTRIM(O.TenChucDanh))) LIKE N'lương y%' THEN N'9'
        WHEN LOWER(LTRIM(RTRIM(O.TenChucDanh))) LIKE N'cử nhân xét nghiệm%' THEN N'10'
        WHEN LOWER(LTRIM(RTRIM(O.TenChucDanh))) LIKE N'dược sĩ cao đẳng%' THEN N'11'
    END AS Ma
) M
INNER JOIN dbo.DM_ChucDanh C ON C.MaChucDanh=M.Ma
WHERE O.MaChucDanh NOT IN(N'1',N'2',N'3',N'4',N'5',N'6',N'7',N'8',N'9',N'10',N'11');

IF COL_LENGTH(N'dbo.DM_NhanVien',N'ChucDanh') IS NOT NULL
BEGIN
    EXEC sys.sp_executesql N'
        UPDATE N SET IDChucDanh=C.ID
        FROM dbo.DM_NhanVien N
        CROSS APPLY
        (
            SELECT CASE
                WHEN LOWER(LTRIM(RTRIM(ISNULL(N.ChucDanh,N'''')))) LIKE N''bác sĩ%'' OR LOWER(LTRIM(RTRIM(ISNULL(N.ChucDanh,N'''')))) IN(N''bs'',N''b.s'') THEN N''1''
                WHEN LOWER(LTRIM(RTRIM(ISNULL(N.ChucDanh,N'''')))) LIKE N''y sĩ%'' THEN N''2''
                WHEN LOWER(LTRIM(RTRIM(ISNULL(N.ChucDanh,N'''')))) LIKE N''điều dưỡng%'' THEN N''3''
                WHEN LOWER(LTRIM(RTRIM(ISNULL(N.ChucDanh,N'''')))) LIKE N''nữ hộ sinh%'' THEN N''4''
                WHEN LOWER(LTRIM(RTRIM(ISNULL(N.ChucDanh,N'''')))) LIKE N''kỹ thuật viên%'' THEN N''5''
                WHEN LOWER(LTRIM(RTRIM(ISNULL(N.ChucDanh,N'''')))) LIKE N''cử nhân cđha%'' THEN N''6''
                WHEN LOWER(LTRIM(RTRIM(ISNULL(N.ChucDanh,N'''')))) IN(N''dược sĩ'',N''dược sĩ đại học'') THEN N''7''
                WHEN LOWER(LTRIM(RTRIM(ISNULL(N.ChucDanh,N'''')))) LIKE N''dược sĩ trung cấp%'' THEN N''8''
                WHEN LOWER(LTRIM(RTRIM(ISNULL(N.ChucDanh,N'''')))) LIKE N''lương y%'' THEN N''9''
                WHEN LOWER(LTRIM(RTRIM(ISNULL(N.ChucDanh,N'''')))) LIKE N''cử nhân xét nghiệm%'' THEN N''10''
                WHEN LOWER(LTRIM(RTRIM(ISNULL(N.ChucDanh,N'''')))) LIKE N''dược sĩ cao đẳng%'' THEN N''11''
            END AS Ma
        ) M
        INNER JOIN dbo.DM_ChucDanh C ON C.MaChucDanh=M.Ma
        WHERE N.IDChucDanh IS NULL
           OR EXISTS(SELECT 1 FROM dbo.DM_ChucDanh O WHERE O.ID=N.IDChucDanh AND O.MaChucDanh NOT IN
             (N''1'',N''2'',N''3'',N''4'',N''5'',N''6'',N''7'',N''8'',N''9'',N''10'',N''11''));';
END;

UPDATE N SET IDChucDanh=NULL
FROM dbo.DM_NhanVien N INNER JOIN dbo.DM_ChucDanh C ON C.ID=N.IDChucDanh
WHERE C.MaChucDanh NOT IN(N'1',N'2',N'3',N'4',N'5',N'6',N'7',N'8',N'9',N'10',N'11');
DELETE dbo.DM_ChucDanh WHERE MaChucDanh NOT IN(N'1',N'2',N'3',N'4',N'5',N'6',N'7',N'8',N'9',N'10',N'11');
GO

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.DM_ChucDanh') AND name=N'UQ_DM_ChucDanh_Ma')
    CREATE UNIQUE INDEX UQ_DM_ChucDanh_Ma ON dbo.DM_ChucDanh(MaChucDanh);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.DM_ChucDanh') AND name=N'UQ_DM_ChucDanh_Ten')
    CREATE UNIQUE INDEX UQ_DM_ChucDanh_Ten ON dbo.DM_ChucDanh(TenChucDanh);
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'dbo.DM_NhanVien') AND referenced_object_id=OBJECT_ID(N'dbo.DM_ChucDanh'))
    ALTER TABLE dbo.DM_NhanVien WITH CHECK ADD CONSTRAINT FK_DM_NhanVien_ChucDanh FOREIGN KEY(IDChucDanh) REFERENCES dbo.DM_ChucDanh(ID);
GO

/* 3. One canonical prescription-type contract. */
IF OBJECT_ID(N'dbo.DM_LoaiToaThuoc',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DM_LoaiToaThuoc
    (
        MaLoaiToaThuoc NVARCHAR(1) NOT NULL CONSTRAINT PK_DM_LoaiToaThuoc PRIMARY KEY,
        TenLoaiToaThuoc NVARCHAR(500) NOT NULL,
        Active BIT NOT NULL CONSTRAINT DF_DM_LoaiToaThuoc_Active DEFAULT(1)
    );
END;
GO
IF COL_LENGTH(N'dbo.DM_LoaiToaThuoc',N'MaLoaiToaThuoc') IS NULL AND COL_LENGTH(N'dbo.DM_LoaiToaThuoc',N'MaLoaiDonThuoc') IS NOT NULL
    EXEC sys.sp_rename N'dbo.DM_LoaiToaThuoc.MaLoaiDonThuoc',N'MaLoaiToaThuoc',N'COLUMN';
IF COL_LENGTH(N'dbo.DM_LoaiToaThuoc',N'TenLoaiToaThuoc') IS NULL AND COL_LENGTH(N'dbo.DM_LoaiToaThuoc',N'TenLoaiDonThuoc') IS NOT NULL
    EXEC sys.sp_rename N'dbo.DM_LoaiToaThuoc.TenLoaiDonThuoc',N'TenLoaiToaThuoc',N'COLUMN';
GO

IF COL_LENGTH(N'dbo.DM_LoaiToaThuoc',N'TenLoaiToaThuoc') IS NOT NULL
BEGIN
    UPDATE dbo.DM_LoaiToaThuoc SET TenLoaiToaThuoc=N'' WHERE TenLoaiToaThuoc IS NULL;
    ALTER TABLE dbo.DM_LoaiToaThuoc ALTER COLUMN TenLoaiToaThuoc NVARCHAR(500) NOT NULL;
END;
GO

MERGE dbo.DM_LoaiToaThuoc AS T
USING (VALUES(N'c',N'Đơn thuốc cơ bản',CAST(1 AS BIT)),(N'n',N'Đơn thuốc gây nghiện',CAST(1 AS BIT)),(N'h',N'Đơn thuốc hướng tâm thần và thuốc tiền chất',CAST(1 AS BIT))) S(Ma,Ten,Active)
ON T.MaLoaiToaThuoc=S.Ma
WHEN MATCHED THEN UPDATE SET TenLoaiToaThuoc=S.Ten,Active=S.Active
WHEN NOT MATCHED THEN INSERT(MaLoaiToaThuoc,TenLoaiToaThuoc,Active) VALUES(S.Ma,S.Ten,S.Active);
GO

IF OBJECT_ID(N'dbo.QL_ToaThuoc_CT',N'U') IS NOT NULL AND COL_LENGTH(N'dbo.QL_ToaThuoc_CT',N'MaLoaiToaThuoc') IS NULL AND COL_LENGTH(N'dbo.QL_ToaThuoc_CT',N'MaLoaiDonThuoc') IS NOT NULL
    EXEC sys.sp_rename N'dbo.QL_ToaThuoc_CT.MaLoaiDonThuoc',N'MaLoaiToaThuoc',N'COLUMN';
IF OBJECT_ID(N'dbo.DM_NhomHang',N'U') IS NOT NULL AND COL_LENGTH(N'dbo.DM_NhomHang',N'MaLoaiToaThuoc') IS NULL AND COL_LENGTH(N'dbo.DM_NhomHang',N'MaLoaiDonThuoc') IS NOT NULL
    EXEC sys.sp_rename N'dbo.DM_NhomHang.MaLoaiDonThuoc',N'MaLoaiToaThuoc',N'COLUMN';
GO
IF OBJECT_ID(N'dbo.QL_ToaThuoc_CT',N'U') IS NOT NULL AND COL_LENGTH(N'dbo.QL_ToaThuoc_CT',N'MaLoaiToaThuoc') IS NULL
    ALTER TABLE dbo.QL_ToaThuoc_CT ADD MaLoaiToaThuoc NVARCHAR(1) NOT NULL CONSTRAINT DF_QL_ToaThuoc_CT_MaLoaiToaThuoc DEFAULT(N'c') WITH VALUES;
GO
IF COL_LENGTH(N'dbo.QL_ToaThuoc_CT',N'MaLoaiDonThuoc') IS NOT NULL AND COL_LENGTH(N'dbo.QL_ToaThuoc_CT',N'MaLoaiToaThuoc') IS NOT NULL
    EXEC sys.sp_executesql N'UPDATE dbo.QL_ToaThuoc_CT SET MaLoaiToaThuoc=MaLoaiDonThuoc WHERE MaLoaiToaThuoc IS NULL;';
IF COL_LENGTH(N'dbo.DM_NhomHang',N'MaLoaiDonThuoc') IS NOT NULL AND COL_LENGTH(N'dbo.DM_NhomHang',N'MaLoaiToaThuoc') IS NOT NULL
    EXEC sys.sp_executesql N'UPDATE dbo.DM_NhomHang SET MaLoaiToaThuoc=MaLoaiDonThuoc WHERE MaLoaiToaThuoc IS NULL;';
GO
IF COL_LENGTH(N'dbo.QL_ToaThuoc_CT',N'MaLoaiToaThuoc') IS NOT NULL
BEGIN
    EXEC sys.sp_executesql N'
        UPDATE dbo.QL_ToaThuoc_CT SET MaLoaiToaThuoc=N''c'' WHERE UPPER(MaLoaiToaThuoc) IN(N''CO_BAN'',N''COBAN'');
        UPDATE dbo.QL_ToaThuoc_CT SET MaLoaiToaThuoc=N''n'' WHERE UPPER(MaLoaiToaThuoc) IN(N''GAY_NGHIEN'',N''GAYNGHIEN'');
        UPDATE dbo.QL_ToaThuoc_CT SET MaLoaiToaThuoc=N''h'' WHERE UPPER(MaLoaiToaThuoc) IN(N''HUONG_TAM_THAN'',N''TIEN_CHAT'');
        IF EXISTS(SELECT 1 FROM dbo.QL_ToaThuoc_CT WHERE MaLoaiToaThuoc NOT IN(N''c'',N''n'',N''h''))
            THROW 59086,N''QL_ToaThuoc_CT có loại toa không thể migrate an toàn.'',1;';
END;
GO

/* 4. Drop dependencies and legacy columns. */
CREATE TABLE #LegacyColumn(SchemaName SYSNAME,TableName SYSNAME,ColumnName SYSNAME,PRIMARY KEY(SchemaName,TableName,ColumnName));
INSERT #LegacyColumn VALUES
(N'dbo',N'DM_NhanVien',N'UserId'),(N'dbo',N'DM_NhanVien',N'IDCSKCB'),(N'dbo',N'DM_NhanVien',N'ChucDanh'),
(N'dbo',N'DM_DichVu',N'LoaiKetQua'),(N'dbo',N'DM_DichVu',N'IDFormKQ'),
(N'dbo',N'QL_BenhNhan',N'GioiTinh'),(N'dbo',N'QL_BenhNhan',N'Tuoi'),
(N'dbo',N'DM_PhacDo',N'NoiDung'),(N'dbo',N'DM_PhacDo',N'IDICD10'),(N'dbo',N'DM_PhacDo',N'BanDau'),(N'dbo',N'DM_PhacDo',N'BenhChinh'),(N'dbo',N'DM_PhacDo',N'BenhKhac'),
(N'dbo',N'QL_ChiDinh_CT',N'NgayGioThucHien'),(N'dbo',N'QL_ChiDinh_CT',N'NgayGioKetQua'),(N'dbo',N'QL_ChiDinh_CT',N'IDNhanVienThucHien'),(N'dbo',N'QL_ChiDinh_CT',N'IDBacSiThucHien'),(N'dbo',N'QL_ChiDinh_CT',N'IDPhieuKetQua'),
(N'dbo',N'QL_VaoVien',N'MaLoaiDonThuoc'),(N'dbo',N'QL_VaoVien',N'MaLoaiToaThuoc'),
(N'dbo',N'QL_ToaThuoc_CT',N'MaLoaiDonThuoc'),(N'dbo',N'DM_NhomHang',N'MaLoaiDonThuoc'),
(N'dbo',N'DM_LoaiToaThuoc',N'MaLoaiDonThuoc'),(N'dbo',N'DM_LoaiToaThuoc',N'TenLoaiDonThuoc');

DECLARE @SchemaName SYSNAME,@TableName SYSNAME,@ColumnName SYSNAME,@ObjectID INT,@ColumnID INT,@Sql NVARCHAR(MAX);
DECLARE CColumn CURSOR LOCAL FAST_FORWARD FOR SELECT SchemaName,TableName,ColumnName FROM #LegacyColumn;
OPEN CColumn;
FETCH NEXT FROM CColumn INTO @SchemaName,@TableName,@ColumnName;
WHILE @@FETCH_STATUS=0
BEGIN
    SET @ObjectID=OBJECT_ID(QUOTENAME(@SchemaName)+N'.'+QUOTENAME(@TableName),N'U'); SET @ColumnID=NULL;
    IF @ObjectID IS NOT NULL SELECT @ColumnID=column_id FROM sys.columns WHERE object_id=@ObjectID AND name=@ColumnName;
    IF @ColumnID IS NOT NULL
    BEGIN
        SET @Sql=N'';
        SELECT DISTINCT @Sql+=N'ALTER TABLE '+QUOTENAME(OBJECT_SCHEMA_NAME(FK.parent_object_id))+N'.'+QUOTENAME(OBJECT_NAME(FK.parent_object_id))+N' DROP CONSTRAINT '+QUOTENAME(FK.name)+N';'
        FROM sys.foreign_keys FK INNER JOIN sys.foreign_key_columns FC ON FC.constraint_object_id=FK.object_id
        WHERE (FC.parent_object_id=@ObjectID AND FC.parent_column_id=@ColumnID) OR (FC.referenced_object_id=@ObjectID AND FC.referenced_column_id=@ColumnID);
        IF @Sql<>N'' EXEC sys.sp_executesql @Sql;
        SET @Sql=N'';
        SELECT @Sql+=N'ALTER TABLE '+QUOTENAME(@SchemaName)+N'.'+QUOTENAME(@TableName)+N' DROP CONSTRAINT '+QUOTENAME(name)+N';'
        FROM sys.default_constraints WHERE parent_object_id=@ObjectID AND parent_column_id=@ColumnID;
        IF @Sql<>N'' EXEC sys.sp_executesql @Sql;
        SET @Sql=N'';
        SELECT DISTINCT @Sql+=N'ALTER TABLE '+QUOTENAME(@SchemaName)+N'.'+QUOTENAME(@TableName)+N' DROP CONSTRAINT '+QUOTENAME(C.name)+N';'
        FROM sys.check_constraints C LEFT JOIN sys.sql_expression_dependencies D ON D.referencing_id=C.object_id
        WHERE C.parent_object_id=@ObjectID AND (C.parent_column_id=@ColumnID OR (D.referenced_id=@ObjectID AND D.referenced_minor_id=@ColumnID));
        IF @Sql<>N'' EXEC sys.sp_executesql @Sql;
        SET @Sql=N'';
        SELECT DISTINCT @Sql+=N'ALTER TABLE '+QUOTENAME(@SchemaName)+N'.'+QUOTENAME(@TableName)+N' DROP CONSTRAINT '+QUOTENAME(K.name)+N';'
        FROM sys.key_constraints K INNER JOIN sys.index_columns IC ON IC.object_id=K.parent_object_id AND IC.index_id=K.unique_index_id
        WHERE K.parent_object_id=@ObjectID AND IC.column_id=@ColumnID;
        IF @Sql<>N'' EXEC sys.sp_executesql @Sql;
        SET @Sql=N'';
        SELECT DISTINCT @Sql+=N'DROP INDEX '+QUOTENAME(I.name)+N' ON '+QUOTENAME(@SchemaName)+N'.'+QUOTENAME(@TableName)+N';'
        FROM sys.indexes I INNER JOIN sys.index_columns IC ON IC.object_id=I.object_id AND IC.index_id=I.index_id
        WHERE I.object_id=@ObjectID AND IC.column_id=@ColumnID AND I.name IS NOT NULL AND I.is_primary_key=0 AND I.is_unique_constraint=0;
        IF @Sql<>N'' EXEC sys.sp_executesql @Sql;
        SET @Sql=N'';
        SELECT DISTINCT @Sql+=N'DROP STATISTICS '+QUOTENAME(@SchemaName)+N'.'+QUOTENAME(@TableName)+N'.'+QUOTENAME(S.name)+N';'
        FROM sys.stats S INNER JOIN sys.stats_columns SC ON SC.object_id=S.object_id AND SC.stats_id=S.stats_id
        LEFT JOIN sys.indexes I ON I.object_id=S.object_id AND I.index_id=S.stats_id
        WHERE S.object_id=@ObjectID AND SC.column_id=@ColumnID AND I.index_id IS NULL;
        IF @Sql<>N'' EXEC sys.sp_executesql @Sql;
        SET @Sql=N'ALTER TABLE '+QUOTENAME(@SchemaName)+N'.'+QUOTENAME(@TableName)+N' DROP COLUMN '+QUOTENAME(@ColumnName)+N';';
        EXEC sys.sp_executesql @Sql;
    END;
    FETCH NEXT FROM CColumn INTO @SchemaName,@TableName,@ColumnName;
END;
CLOSE CColumn; DEALLOCATE CColumn; DROP TABLE #LegacyColumn;
GO

IF OBJECT_ID(N'dbo.DM_LoaiDonThuoc',N'U') IS NOT NULL
BEGIN
    DECLARE @DropLoaiFk NVARCHAR(MAX)=N'';
    SELECT @DropLoaiFk+=N'ALTER TABLE '+QUOTENAME(OBJECT_SCHEMA_NAME(parent_object_id))+N'.'+QUOTENAME(OBJECT_NAME(parent_object_id))+N' DROP CONSTRAINT '+QUOTENAME(name)+N';'
    FROM sys.foreign_keys WHERE referenced_object_id=OBJECT_ID(N'dbo.DM_LoaiDonThuoc');
    IF @DropLoaiFk<>N'' EXEC sys.sp_executesql @DropLoaiFk;
    DROP TABLE dbo.DM_LoaiDonThuoc;
END;
GO
IF OBJECT_ID(N'dbo.QL_ToaThuoc_CT',N'U') IS NOT NULL
AND NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'dbo.QL_ToaThuoc_CT') AND referenced_object_id=OBJECT_ID(N'dbo.DM_LoaiToaThuoc'))
    ALTER TABLE dbo.QL_ToaThuoc_CT WITH CHECK ADD CONSTRAINT FK_QL_ToaThuocCT_LoaiToaThuoc FOREIGN KEY(MaLoaiToaThuoc) REFERENCES dbo.DM_LoaiToaThuoc(MaLoaiToaThuoc);
GO

/* 5. Remove structured/legacy CLS modules and tables.
   STO_QL_Cls_LuuDuongDanKetQua la STO canonical PDF-only (v100):
   khong duoc xoa neu script nay duoc chay lai sau khi da upgrade. */
DECLARE @DropClsModule NVARCHAR(MAX)=N'';
SELECT @DropClsModule+=N'DROP PROCEDURE '+QUOTENAME(SCHEMA_NAME(schema_id))+N'.'+QUOTENAME(name)+N';'
FROM sys.procedures
WHERE name LIKE N'STO[_]QL[_]CLS[_]%'
  AND name<>N'STO_QL_Cls_LuuDuongDanKetQua';
IF @DropClsModule<>N'' EXEC sys.sp_executesql @DropClsModule;
DROP TRIGGER IF EXISTS dbo.TR_QL_ChiDinh_CT_BaoVeKetQuaCLS;
GO

CREATE TABLE #ClsTable(TableName SYSNAME PRIMARY KEY,DropOrder INT);
INSERT #ClsTable VALUES
(N'QL_CLS_KetQuaXN_CT',1),(N'QL_CLS_PhieuKetQua_File',2),(N'QL_CLS_KetQua_LichSu',3),
(N'QL_CLS_FormKQXN_CT',4),(N'QL_CLS_DichVu_FormKQ',5),(N'QL_KetQuaCLS_File',6),
(N'QL_CLS_PhieuKetQua',7),(N'QL_CLS_FormKQXN',8),(N'QL_CLS_DM_TriSoXN',9),(N'QL_KetQuaCLS',10);
DECLARE @DropClsFk NVARCHAR(MAX)=N'';
SELECT @DropClsFk+=N'ALTER TABLE '+QUOTENAME(OBJECT_SCHEMA_NAME(F.parent_object_id))+N'.'+QUOTENAME(OBJECT_NAME(F.parent_object_id))+N' DROP CONSTRAINT '+QUOTENAME(F.name)+N';'
FROM sys.foreign_keys F WHERE EXISTS(SELECT 1 FROM #ClsTable T WHERE OBJECT_ID(N'dbo.'+T.TableName) IN(F.parent_object_id,F.referenced_object_id));
IF @DropClsFk<>N'' EXEC sys.sp_executesql @DropClsFk;
DECLARE @DropClsTable NVARCHAR(MAX)=N'';
SELECT @DropClsTable+=N'DROP TABLE dbo.'+QUOTENAME(TableName)+N';' FROM #ClsTable
WHERE OBJECT_ID(N'dbo.'+TableName,N'U') IS NOT NULL ORDER BY DropOrder;
IF @DropClsTable<>N'' EXEC sys.sp_executesql @DropClsTable;
DROP TABLE #ClsTable;
GO

PRINT N'26_pdf_only_cls_va_cleanup_schema.sql: OK - schema PDF-only v85.';
GO
