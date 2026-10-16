USE [QLPM];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/*
18_main_cleanup_legacy.sql
- Main chi giu schema runtime canonical.
- DSS/AHP se lam lai sau: xoa toan bo object DSS khoi DB main.
- Truoc khi DROP, migrate du lieu legacy con gia tri sang source-of-truth canonical.
*/

IF DB_NAME()<>N'QLPM'
    THROW 59070,N'Script cleanup chi duoc chay tren QLPM.',1;
GO

/* 1. Migrate mapping dich vu -> form cu. */
IF OBJECT_ID(N'dbo.QL_CLS_DichVu_FormKQ',N'U') IS NOT NULL
BEGIN
    UPDATE D
    SET D.LoaiKetQua=
            CASE
                WHEN M.LoaiKetQua IN(1,2) THEN M.LoaiKetQua
                WHEN M.LoaiKetQua=3 THEN 2
                ELSE 0
            END,
        D.IDFormKQ=CASE WHEN M.LoaiKetQua=1 THEN M.IDForm ELSE NULL END
    FROM dbo.DM_DichVu D
    INNER JOIN dbo.QL_CLS_DichVu_FormKQ M
      ON M.IDCSKCB=D.IDCSKCB AND M.IDDichVu=D.ID
    WHERE M.Active=1;
END;
GO

/* 2. Migrate ICD header cu cua phac do sang bang chi tiet. */
IF OBJECT_ID(N'dbo.DM_PhacDo_ChanDoan',N'U') IS NOT NULL
AND COL_LENGTH(N'dbo.DM_PhacDo',N'IDICD10') IS NOT NULL
BEGIN
    EXEC sys.sp_executesql N'
        INSERT dbo.DM_PhacDo_ChanDoan
        (IDCSKCB,IDPhacDo,IDICD10,BanDau,BenhChinh,BenhKhac,ThuTu,Active)
        SELECT P.IDCSKCB,P.ID,P.IDICD10,
               ISNULL(P.BanDau,0),ISNULL(P.BenhChinh,0),ISNULL(P.BenhKhac,0),1,1
        FROM dbo.DM_PhacDo P
        WHERE P.IDICD10 IS NOT NULL
          AND NOT EXISTS
          (
              SELECT 1
              FROM dbo.DM_PhacDo_ChanDoan C
              WHERE C.IDCSKCB=P.IDCSKCB
                AND C.IDPhacDo=P.ID
                AND C.IDICD10=P.IDICD10
          );';
END;
GO

/* 3. Migrate config tri so master cu sang form detail neu dong form chua co config. */
IF COL_LENGTH(N'dbo.QL_CLS_DM_TriSoXN',N'DonViTinh') IS NOT NULL
AND COL_LENGTH(N'dbo.QL_CLS_DM_TriSoXN',N'DinhLuong') IS NOT NULL
AND COL_LENGTH(N'dbo.QL_CLS_DM_TriSoXN',N'CongThucMoi') IS NOT NULL
BEGIN
    EXEC sys.sp_executesql N'
        UPDATE C
        SET C.TenHienThi=COALESCE(NULLIF(C.TenHienThi,N''''),T.TenTriSo),
            C.DonViTinh=T.DonViTinh,
            C.DinhLuong=T.DinhLuong,
            C.LuongDinhTinh=T.LuongDinhTinh,
            C.TuyetDoi=T.TuyetDoi,
            C.TriSoBinhThuong1=T.TriSoBinhThuong1,
            C.GHMin1=T.GHMin1,
            C.GHMax1=T.GHMax1,
            C.MacDinh1=T.MacDinh1,
            C.TriSoBinhThuong2=T.TriSoBinhThuong2,
            C.GHMin2=T.GHMin2,
            C.GHMax2=T.GHMax2,
            C.MacDinh2=T.MacDinh2,
            C.DonViTinh2=T.DonViTinh2,
            C.TiLeQuyDoi=T.TiLeQuyDoi,
            C.IDGioiTinh=T.IDGioiTinh,
            C.GHTuoi=T.GHTuoi,
            C.TuoiMin=T.TuoiMin,
            C.TuoiMax=T.TuoiMax,
            C.LamTron=T.LamTron,
            C.Nguong=T.Nguong,
            C.Tieude=T.Tieude,
            C.CongThuc=T.CongThuc,
            C.CongThucMoi=T.CongThucMoi
        FROM dbo.QL_CLS_FormKQXN_CT C
        INNER JOIN dbo.QL_CLS_DM_TriSoXN T
          ON T.IDCSKCB=C.IDCSKCB AND T.ID=C.IDTriSoXN
        WHERE C.TenHienThi IS NULL;';
END;
GO

/* LoaiDuLieu la metadata master; suy ra mot lan tu flags cu neu can. */
IF COL_LENGTH(N'dbo.QL_CLS_DM_TriSoXN',N'LoaiDuLieu') IS NOT NULL
AND COL_LENGTH(N'dbo.QL_CLS_DM_TriSoXN',N'DinhLuong') IS NOT NULL
BEGIN
    EXEC sys.sp_executesql N'
        UPDATE dbo.QL_CLS_DM_TriSoXN
        SET LoaiDuLieu=
            CASE
                WHEN ISNULL(DinhLuong,0)=1 OR ISNULL(TuyetDoi,0)=1 THEN N''NUMBER''
                WHEN ISNULL(LuongDinhTinh,0)=1 THEN N''TEXT''
                ELSE LoaiDuLieu
            END
        WHERE LoaiDuLieu IS NULL
           OR LTRIM(RTRIM(LoaiDuLieu))=N''''
           OR (UPPER(LTRIM(RTRIM(LoaiDuLieu)))=N''NUMBER''
               AND ISNULL(DinhLuong,0)=0
               AND ISNULL(TuyetDoi,0)=0
               AND ISNULL(LuongDinhTinh,0)=1);';
END;
GO

BEGIN TRY
    BEGIN TRAN;

    /* Xoa metadata quyen DSS neu tung ton tai. */
    IF OBJECT_ID(N'dbo.HT_Chuc_Nang',N'U') IS NOT NULL
       AND OBJECT_ID(N'dbo.HT_Quyen_Vai_Tro',N'U') IS NOT NULL
    BEGIN
        DELETE Q
        FROM dbo.HT_Quyen_Vai_Tro Q
        INNER JOIN dbo.HT_Chuc_Nang C
          ON C.IDCSKCB=Q.IDCSKCB AND C.ID=Q.ID_Chuc_Nang
        WHERE C.Ma_Chuc_Nang LIKE N'dss[_]%'
           OR C.Duong_Dan LIKE N'/dss%';

        DELETE FROM dbo.HT_Chuc_Nang
        WHERE Ma_Chuc_Nang LIKE N'dss[_]%'
           OR Duong_Dan LIKE N'/dss%';
    END;

    IF OBJECT_ID(N'dbo.HT_Phan_He',N'U') IS NOT NULL
    BEGIN
        DELETE P
        FROM dbo.HT_Phan_He P
        WHERE P.Ma_Phan_He=N'dss'
          AND NOT EXISTS
          (
              SELECT 1 FROM dbo.HT_Chuc_Nang C
              WHERE C.IDCSKCB=P.IDCSKCB AND C.ID_Phan_He=P.ID
          );
    END;

    /* Xoa stored module legacy/DSS. */
    DECLARE @Sql NVARCHAR(MAX)=N'';

    SELECT @Sql += N'DROP PROCEDURE '
        +QUOTENAME(SCHEMA_NAME(schema_id))+N'.'+QUOTENAME(name)+N';'+CHAR(13)+CHAR(10)
    FROM sys.procedures
    WHERE (name LIKE N'STO[_]DSS[_]%' OR name LIKE N'DSS[_]%'
        OR name LIKE N'STO[_]QL[_]KetQuaCLS%'
        OR name LIKE N'STO[_]QL[_]CLS[_]%[_]V2'
        OR name LIKE N'STO[_]QL[_]CLS[_]KetQua[_]Duyet%');

    IF NULLIF(@Sql,N'') IS NOT NULL EXEC sys.sp_executesql @Sql;

    SET @Sql=N'';
    SELECT @Sql += N'DROP VIEW '
        +QUOTENAME(SCHEMA_NAME(schema_id))+N'.'+QUOTENAME(name)+N';'+CHAR(13)+CHAR(10)
    FROM sys.views
    WHERE name LIKE N'DSS[_]%';
    IF NULLIF(@Sql,N'') IS NOT NULL EXEC sys.sp_executesql @Sql;

    SET @Sql=N'';
    SELECT @Sql += N'DROP FUNCTION '
        +QUOTENAME(SCHEMA_NAME(schema_id))+N'.'+QUOTENAME(name)+N';'+CHAR(13)+CHAR(10)
    FROM sys.objects
    WHERE type IN(N'FN',N'IF',N'TF')
      AND (name LIKE N'DSS[_]%' OR name LIKE N'FN[_]DSS[_]%');
    IF NULLIF(@Sql,N'') IS NOT NULL EXEC sys.sp_executesql @Sql;

    SET @Sql=N'';
    SELECT @Sql += N'DROP TRIGGER '
        +QUOTENAME(OBJECT_SCHEMA_NAME(object_id))+N'.'+QUOTENAME(name)+N';'+CHAR(13)+CHAR(10)
    FROM sys.triggers
    WHERE parent_class=1 AND name LIKE N'TR[_]DSS[_]%';
    IF NULLIF(@Sql,N'') IS NOT NULL EXEC sys.sp_executesql @Sql;

    SET @Sql=N'';
    SELECT @Sql += N'DROP SEQUENCE '
        +QUOTENAME(SCHEMA_NAME(schema_id))+N'.'+QUOTENAME(name)+N';'+CHAR(13)+CHAR(10)
    FROM sys.sequences
    WHERE name LIKE N'SEQ[_]DSS[_]%' OR name LIKE N'DSS[_]%';
    IF NULLIF(@Sql,N'') IS NOT NULL EXEC sys.sp_executesql @Sql;

    /* Danh sach bang legacy can xoa. */
    CREATE TABLE #DropTable
    (
        SchemaName SYSNAME NOT NULL,
        TableName SYSNAME NOT NULL,
        PRIMARY KEY(SchemaName,TableName)
    );

    INSERT #DropTable(SchemaName,TableName)
    SELECT SCHEMA_NAME(schema_id),name
    FROM sys.tables
    WHERE SCHEMA_NAME(schema_id)=N'dbo'
      AND name LIKE N'DSS[_]%';

    INSERT #DropTable(SchemaName,TableName)
    SELECT N'dbo',X.TableName
    FROM (VALUES
        /* CLS tables are intentionally kept until migration 26 has copied
           the newest valid PDF path to QL_ChiDinh_CT.DuongDanKetQua. */
        (N'QL_Thuoc_Di_Ung'),
        (N'sysdiagrams')
    ) X(TableName)
    WHERE OBJECT_ID(N'dbo.'+X.TableName,N'U') IS NOT NULL
      AND NOT EXISTS(SELECT 1 FROM #DropTable D WHERE D.SchemaName=N'dbo' AND D.TableName=X.TableName);

    /* Drop FK vao/ra bang se xoa. */
    SET @Sql=N'';
    SELECT @Sql += N'ALTER TABLE '
        +QUOTENAME(SCHEMA_NAME(T.schema_id))+N'.'+QUOTENAME(T.name)
        +N' DROP CONSTRAINT '+QUOTENAME(FK.name)+N';'+CHAR(13)+CHAR(10)
    FROM sys.foreign_keys FK
    INNER JOIN sys.tables T ON T.object_id=FK.parent_object_id
    WHERE EXISTS
    (
        SELECT 1 FROM #DropTable D
        WHERE OBJECT_ID(QUOTENAME(D.SchemaName)+N'.'+QUOTENAME(D.TableName)) IN(FK.parent_object_id,FK.referenced_object_id)
    );
    IF NULLIF(@Sql,N'') IS NOT NULL EXEC sys.sp_executesql @Sql;

    DECLARE @SchemaName SYSNAME,@TableName SYSNAME,@ColumnName SYSNAME;
    DECLARE CTable CURSOR LOCAL FAST_FORWARD FOR
        SELECT SchemaName,TableName FROM #DropTable;
    OPEN CTable;
    FETCH NEXT FROM CTable INTO @SchemaName,@TableName;
    WHILE @@FETCH_STATUS=0
    BEGIN
        IF OBJECT_ID(QUOTENAME(@SchemaName)+N'.'+QUOTENAME(@TableName),N'U') IS NOT NULL
        BEGIN
            SET @Sql=N'DROP TABLE '+QUOTENAME(@SchemaName)+N'.'+QUOTENAME(@TableName)+N';';
            EXEC sys.sp_executesql @Sql;
        END;
        FETCH NEXT FROM CTable INTO @SchemaName,@TableName;
    END;
    CLOSE CTable;
    DEALLOCATE CTable;

    /* Stored Database Diagram helper objects cung la legacy dev-tool. */
    DROP PROCEDURE IF EXISTS dbo.sp_alterdiagram;
    DROP PROCEDURE IF EXISTS dbo.sp_creatediagram;
    DROP PROCEDURE IF EXISTS dbo.sp_dropdiagram;
    DROP PROCEDURE IF EXISTS dbo.sp_helpdiagramdefinition;
    DROP PROCEDURE IF EXISTS dbo.sp_helpdiagrams;
    DROP PROCEDURE IF EXISTS dbo.sp_renamediagram;
    DROP FUNCTION IF EXISTS dbo.fn_diagramobjects;

    /* Danh sach cot legacy/trung source-of-truth. */
    CREATE TABLE #DropColumn
    (
        SchemaName SYSNAME NOT NULL,
        TableName SYSNAME NOT NULL,
        ColumnName SYSNAME NOT NULL,
        PRIMARY KEY(SchemaName,TableName,ColumnName)
    );

    INSERT #DropColumn VALUES
      (N'dbo',N'DM_NhanVien',N'UserId'),
      (N'dbo',N'DM_PhacDo',N'NoiDung'),
      (N'dbo',N'DM_PhacDo',N'IDICD10'),
      (N'dbo',N'DM_PhacDo',N'BanDau'),
      (N'dbo',N'DM_PhacDo',N'BenhChinh'),
      (N'dbo',N'DM_PhacDo',N'BenhKhac'),
      (N'dbo',N'QL_BenhNhan',N'Tuoi'),
      (N'dbo',N'QL_ChiDinh_CT',N'NgayGioThucHien'),
      (N'dbo',N'QL_ChiDinh_CT',N'NgayGioKetQua'),
      (N'dbo',N'QL_ChiDinh_CT',N'IDNhanVienThucHien'),
      (N'dbo',N'QL_ChiDinh_CT',N'IDBacSiThucHien'),
      (N'dbo',N'QL_ChiDinh_CT',N'IDPhieuKetQua'),
      (N'dbo',N'QL_CLS_FormKQXN',N'STT'),
      (N'dbo',N'QL_CLS_PhieuKetQua',N'Duyet'),
      (N'dbo',N'QL_CLS_PhieuKetQua',N'IDNhanVienDuyet'),
      (N'dbo',N'QL_CLS_PhieuKetQua',N'NgayGioDuyet'),
      (N'dbo',N'QL_CLS_PhieuKetQua',N'NgayGioHuyDuyet'),
      (N'dbo',N'QL_CLS_PhieuKetQua',N'IDNhanVienHuyDuyet'),
      (N'dbo',N'QL_CLS_PhieuKetQua',N'IDVaoVien'),
      (N'dbo',N'QL_CLS_PhieuKetQua',N'IDDichVu'),
      (N'dbo',N'QL_CLS_KetQuaXN_CT',N'Active'),
      (N'dbo',N'QL_CLS_KetQuaXN_CT',N'Duyet'),
      (N'dbo',N'QL_CLS_KetQuaXN_CT',N'IDNhanVienDuyet'),
      (N'dbo',N'QL_CLS_KetQuaXN_CT',N'NgayGioDuyet'),
      (N'dbo',N'QL_CLS_KetQuaXN_CT',N'HuyDuyet'),
      (N'dbo',N'QL_CLS_KetQuaXN_CT',N'IDNhanVienHuy'),
      (N'dbo',N'QL_CLS_KetQuaXN_CT',N'NgayGioHuyDuyet'),
      (N'dbo',N'QL_CLS_DM_TriSoXN',N'DonViTinh'),
      (N'dbo',N'QL_CLS_DM_TriSoXN',N'DinhLuong'),
      (N'dbo',N'QL_CLS_DM_TriSoXN',N'TriSoBinhThuong1'),
      (N'dbo',N'QL_CLS_DM_TriSoXN',N'GHMin1'),
      (N'dbo',N'QL_CLS_DM_TriSoXN',N'GHMax1'),
      (N'dbo',N'QL_CLS_DM_TriSoXN',N'MacDinh1'),
      (N'dbo',N'QL_CLS_DM_TriSoXN',N'TriSoBinhThuong2'),
      (N'dbo',N'QL_CLS_DM_TriSoXN',N'GHMin2'),
      (N'dbo',N'QL_CLS_DM_TriSoXN',N'GHMax2'),
      (N'dbo',N'QL_CLS_DM_TriSoXN',N'MacDinh2'),
      (N'dbo',N'QL_CLS_DM_TriSoXN',N'IDGioiTinh'),
      (N'dbo',N'QL_CLS_DM_TriSoXN',N'TuoiMin'),
      (N'dbo',N'QL_CLS_DM_TriSoXN',N'TuoiMax'),
      (N'dbo',N'QL_CLS_DM_TriSoXN',N'LamTron'),
      (N'dbo',N'QL_CLS_DM_TriSoXN',N'ThuTu'),
      (N'dbo',N'QL_CLS_DM_TriSoXN',N'LuongDinhTinh'),
      (N'dbo',N'QL_CLS_DM_TriSoXN',N'TuyetDoi'),
      (N'dbo',N'QL_CLS_DM_TriSoXN',N'DonViTinh2'),
      (N'dbo',N'QL_CLS_DM_TriSoXN',N'TiLeQuyDoi'),
      (N'dbo',N'QL_CLS_DM_TriSoXN',N'GHTuoi'),
      (N'dbo',N'QL_CLS_DM_TriSoXN',N'Nguong'),
      (N'dbo',N'QL_CLS_DM_TriSoXN',N'Tieude'),
      (N'dbo',N'QL_CLS_DM_TriSoXN',N'CongThuc'),
      (N'dbo',N'QL_CLS_DM_TriSoXN',N'CongThucMoi');

    DECLARE CCol CURSOR LOCAL FAST_FORWARD FOR
        SELECT SchemaName,TableName,ColumnName FROM #DropColumn;
    OPEN CCol;
    FETCH NEXT FROM CCol INTO @SchemaName,@TableName,@ColumnName;
    WHILE @@FETCH_STATUS=0
    BEGIN
        DECLARE @ObjectID INT=OBJECT_ID(QUOTENAME(@SchemaName)+N'.'+QUOTENAME(@TableName),N'U');
        DECLARE @ColumnID INT=NULL;
        IF @ObjectID IS NOT NULL
            SELECT @ColumnID=column_id FROM sys.columns WHERE object_id=@ObjectID AND name=@ColumnName;

        IF @ColumnID IS NOT NULL
        BEGIN
            /* FK */
            SET @Sql=N'';
            SELECT @Sql += N'ALTER TABLE '+QUOTENAME(SCHEMA_NAME(T.schema_id))+N'.'+QUOTENAME(T.name)
                +N' DROP CONSTRAINT '+QUOTENAME(FK.name)+N';'+CHAR(13)+CHAR(10)
            FROM sys.foreign_keys FK
            INNER JOIN sys.foreign_key_columns FKC ON FKC.constraint_object_id=FK.object_id
            INNER JOIN sys.tables T ON T.object_id=FK.parent_object_id
            WHERE (FKC.parent_object_id=@ObjectID AND FKC.parent_column_id=@ColumnID)
               OR (FKC.referenced_object_id=@ObjectID AND FKC.referenced_column_id=@ColumnID);
            IF NULLIF(@Sql,N'') IS NOT NULL EXEC sys.sp_executesql @Sql;

            /* DEFAULT */
            SET @Sql=N'';
            SELECT @Sql += N'ALTER TABLE '+QUOTENAME(@SchemaName)+N'.'+QUOTENAME(@TableName)
                +N' DROP CONSTRAINT '+QUOTENAME(name)+N';'
            FROM sys.default_constraints
            WHERE parent_object_id=@ObjectID AND parent_column_id=@ColumnID;
            IF NULLIF(@Sql,N'') IS NOT NULL EXEC sys.sp_executesql @Sql;

            /* CHECK constraint co dependency cot. */
            SET @Sql=N'';
            SELECT DISTINCT @Sql += N'ALTER TABLE '+QUOTENAME(@SchemaName)+N'.'+QUOTENAME(@TableName)
                +N' DROP CONSTRAINT '+QUOTENAME(CC.name)+N';'
            FROM sys.check_constraints CC
            LEFT JOIN sys.sql_expression_dependencies D ON D.referencing_id=CC.object_id
            WHERE CC.parent_object_id=@ObjectID
              AND (D.referenced_id=@ObjectID AND D.referenced_minor_id=@ColumnID
                   OR CC.definition LIKE N'%'+QUOTENAME(@ColumnName)+N'%');
            IF NULLIF(@Sql,N'') IS NOT NULL EXEC sys.sp_executesql @Sql;

            /* UNIQUE/key constraint neu co. */
            SET @Sql=N'';
            SELECT DISTINCT @Sql += N'ALTER TABLE '+QUOTENAME(@SchemaName)+N'.'+QUOTENAME(@TableName)
                +N' DROP CONSTRAINT '+QUOTENAME(KC.name)+N';'
            FROM sys.key_constraints KC
            INNER JOIN sys.index_columns IC
              ON IC.object_id=KC.parent_object_id AND IC.index_id=KC.unique_index_id
            WHERE KC.parent_object_id=@ObjectID AND IC.column_id=@ColumnID;
            IF NULLIF(@Sql,N'') IS NOT NULL EXEC sys.sp_executesql @Sql;

            /* Index con lai. */
            SET @Sql=N'';
            SELECT DISTINCT @Sql += N'DROP INDEX '+QUOTENAME(I.name)+N' ON '
                +QUOTENAME(@SchemaName)+N'.'+QUOTENAME(@TableName)+N';'
            FROM sys.indexes I
            INNER JOIN sys.index_columns IC
              ON IC.object_id=I.object_id AND IC.index_id=I.index_id
            WHERE I.object_id=@ObjectID AND IC.column_id=@ColumnID
              AND I.name IS NOT NULL AND I.is_primary_key=0 AND I.is_unique_constraint=0;
            IF NULLIF(@Sql,N'') IS NOT NULL EXEC sys.sp_executesql @Sql;

            /* Standalone statistics (manual/auto). Index-backed stats da duoc xu ly o tren. */
            SET @Sql=N'';
            SELECT DISTINCT @Sql += N'DROP STATISTICS '+QUOTENAME(@SchemaName)+N'.'+QUOTENAME(@TableName)+N'.'+QUOTENAME(S.name)+N';'
            FROM sys.stats S
            INNER JOIN sys.stats_columns SC
              ON SC.object_id=S.object_id AND SC.stats_id=S.stats_id
            LEFT JOIN sys.indexes I
              ON I.object_id=S.object_id AND I.index_id=S.stats_id
            WHERE S.object_id=@ObjectID
              AND SC.column_id=@ColumnID
              AND I.index_id IS NULL;
            IF NULLIF(@Sql,N'') IS NOT NULL EXEC sys.sp_executesql @Sql;

            SET @Sql=N'ALTER TABLE '+QUOTENAME(@SchemaName)+N'.'+QUOTENAME(@TableName)
                +N' DROP COLUMN '+QUOTENAME(@ColumnName)+N';';
            EXEC sys.sp_executesql @Sql;
        END;

        FETCH NEXT FROM CCol INTO @SchemaName,@TableName,@ColumnName;
    END;
    CLOSE CCol;
    DEALLOCATE CCol;

    COMMIT;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK;
    THROW;
END CATCH;
GO

PRINT N'18_main_cleanup_legacy.sql: OK - main chi con schema canonical.';
GO
