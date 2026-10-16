USE [QLPM];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/*
27_post_sto_cleanup_orphan_exam_columns.sql
- Chi drop cot nghiep vu mo coi SAU KHI toan bo STO runtime da duoc CREATE/ALTER lai.
- HuongDieuTri: legacy khong con UI/runtime.
- GhiChu cua QL_VaoVien: schema cu dung chung cho ghi chu tiep nhan va dan do; da tach thanh
  GhiChuTiepNhan + DanDo trong 01_main_schema_contract.sql.
- DB cu co the co index paging/search INCLUDE cac cot legacy. Script se rebuild index,
  giu nguyen key/filter va chi bo cot legacy khoi INCLUDE truoc khi DROP COLUMN.
*/

IF DB_NAME()<>N'QLPM'
    THROW 59090,N'Script post-STO cleanup chi duoc chay tren QLPM.',1;
GO

DECLARE @TableId INT=OBJECT_ID(N'dbo.QL_VaoVien',N'U');
IF @TableId IS NULL
    THROW 59092,N'Khong tim thay dbo.QL_VaoVien.',1;

DECLARE @Legacy TABLE(ColumnName SYSNAME PRIMARY KEY);
INSERT @Legacy(ColumnName) VALUES(N'HuongDieuTri'),(N'GhiChu');

CREATE TABLE #IndexesToRebuild
(
    RowNo INT IDENTITY(1,1) PRIMARY KEY,
    IndexName SYSNAME NOT NULL,
    DropSql NVARCHAR(MAX) NOT NULL,
    CreateSql NVARCHAR(MAX) NOT NULL
);

DECLARE
    @ColumnName SYSNAME,
    @ColumnId INT,
    @ModuleConThamChieu NVARCHAR(MAX),
    @IndexKeyConThamChieu NVARCHAR(MAX),
    @Sql NVARCHAR(MAX),
    @Msg NVARCHAR(2048),
    @IdxRow INT,
    @IdxMax INT,
    @IdxDrop NVARCHAR(MAX),
    @IdxCreate NVARCHAR(MAX),
    @IdxName SYSNAME;

DECLARE C CURSOR LOCAL FAST_FORWARD FOR
    SELECT ColumnName FROM @Legacy ORDER BY ColumnName;
OPEN C;
FETCH NEXT FROM C INTO @ColumnName;

WHILE @@FETCH_STATUS=0
BEGIN
    SET @ColumnId=NULL;
    SELECT @ColumnId=column_id
    FROM sys.columns
    WHERE object_id=@TableId AND name=@ColumnName;

    IF @ColumnId IS NOT NULL
    BEGIN
        SET @ModuleConThamChieu=NULL;

        SELECT @ModuleConThamChieu=STRING_AGG(X.ModuleName,N', ')
        FROM
        (
            SELECT DISTINCT
                QUOTENAME(OBJECT_SCHEMA_NAME(D.referencing_id))
                +N'.'+QUOTENAME(OBJECT_NAME(D.referencing_id)) AS ModuleName
            FROM sys.sql_expression_dependencies D
            WHERE D.referenced_id=@TableId
              AND D.referenced_minor_id=@ColumnId
              AND OBJECTPROPERTY(D.referencing_id,N'IsMSShipped')=0
        ) X;

        IF NULLIF(@ModuleConThamChieu,N'') IS NOT NULL
        BEGIN
            SET @Msg=N'Khong the drop QL_VaoVien.'+@ColumnName
                +N' vi module runtime van con tham chieu: '
                +LEFT(@ModuleConThamChieu,1600)
                +N'. Hay cap nhat STO truoc khi cleanup.';
            CLOSE C;
            DEALLOCATE C;
            THROW 59091,@Msg,1;
        END;

        /*
          Neu cot legacy dang la KEY cua index thi dung lai, khong tu y thay doi
          y nghia/sap xep index. Truong hop INCLUDE thi co the rebuild an toan.
        */
        SET @IndexKeyConThamChieu=NULL;
        SELECT @IndexKeyConThamChieu=STRING_AGG(QUOTENAME(I.name),N', ')
        FROM sys.indexes I
        INNER JOIN sys.index_columns IC
          ON IC.object_id=I.object_id AND IC.index_id=I.index_id
        WHERE I.object_id=@TableId
          AND IC.column_id=@ColumnId
          AND IC.key_ordinal>0
          AND I.is_hypothetical=0;

        IF NULLIF(@IndexKeyConThamChieu,N'') IS NOT NULL
        BEGIN
            SET @Msg=N'Khong the tu dong drop QL_VaoVien.'+@ColumnName
                +N' vi cot dang la KEY cua index: '
                +LEFT(@IndexKeyConThamChieu,1600)
                +N'. Can xem lai index truoc khi cleanup.';
            CLOSE C;
            DEALLOCATE C;
            THROW 59093,@Msg,1;
        END;

        TRUNCATE TABLE #IndexesToRebuild;

        INSERT #IndexesToRebuild(IndexName,DropSql,CreateSql)
        SELECT
            I.name,
            N'DROP INDEX '+QUOTENAME(I.name)+N' ON dbo.QL_VaoVien;',
            N'CREATE '
            +CASE WHEN I.is_unique=1 THEN N'UNIQUE ' ELSE N'' END
            +CASE I.type WHEN 1 THEN N'CLUSTERED ' ELSE N'NONCLUSTERED ' END
            +N'INDEX '+QUOTENAME(I.name)+N' ON dbo.QL_VaoVien ('+K.KeyColumns+N')'
            +CASE WHEN NULLIF(Inc.IncludeColumns,N'') IS NOT NULL
                  THEN N' INCLUDE ('+Inc.IncludeColumns+N')' ELSE N'' END
            +CASE WHEN I.has_filter=1 AND NULLIF(I.filter_definition,N'') IS NOT NULL
                  THEN N' WHERE '+I.filter_definition ELSE N'' END
            +N';'
        FROM sys.indexes I
        CROSS APPLY
        (
            SELECT STRING_AGG(
                       CAST(QUOTENAME(CK.name)
                           +CASE WHEN ICK.is_descending_key=1 THEN N' DESC' ELSE N' ASC' END
                            AS NVARCHAR(MAX)),
                       N', '
                   ) WITHIN GROUP (ORDER BY ICK.key_ordinal) AS KeyColumns
            FROM sys.index_columns ICK
            INNER JOIN sys.columns CK
              ON CK.object_id=ICK.object_id AND CK.column_id=ICK.column_id
            WHERE ICK.object_id=I.object_id
              AND ICK.index_id=I.index_id
              AND ICK.key_ordinal>0
        ) K
        OUTER APPLY
        (
            SELECT STRING_AGG(
                       CAST(QUOTENAME(CI.name) AS NVARCHAR(MAX)),
                       N', '
                   ) WITHIN GROUP (ORDER BY ICI.index_column_id) AS IncludeColumns
            FROM sys.index_columns ICI
            INNER JOIN sys.columns CI
              ON CI.object_id=ICI.object_id AND CI.column_id=ICI.column_id
            WHERE ICI.object_id=I.object_id
              AND ICI.index_id=I.index_id
              AND ICI.is_included_column=1
              AND ICI.column_id<>@ColumnId
        ) Inc
        WHERE I.object_id=@TableId
          AND I.type IN(1,2)
          AND I.is_hypothetical=0
          AND I.is_primary_key=0
          AND I.is_unique_constraint=0
          AND EXISTS
          (
              SELECT 1
              FROM sys.index_columns IC
              WHERE IC.object_id=I.object_id
                AND IC.index_id=I.index_id
                AND IC.column_id=@ColumnId
                AND IC.is_included_column=1
          );

        SET @IdxRow=1;
        SELECT @IdxMax=COUNT(*) FROM #IndexesToRebuild;

        WHILE @IdxRow<=@IdxMax
        BEGIN
            SELECT @IdxName=IndexName,@IdxDrop=DropSql
            FROM #IndexesToRebuild
            WHERE RowNo=@IdxRow;

            PRINT N'Rebuild index '+QUOTENAME(@IdxName)+N': bo INCLUDE '+QUOTENAME(@ColumnName)+N'.';
            EXEC sys.sp_executesql @IdxDrop;
            SET @IdxRow+=1;
        END;

        SET @Sql=N'ALTER TABLE dbo.QL_VaoVien DROP COLUMN '+QUOTENAME(@ColumnName)+N';';
        EXEC sys.sp_executesql @Sql;

        SET @IdxRow=1;
        WHILE @IdxRow<=@IdxMax
        BEGIN
            SELECT @IdxName=IndexName,@IdxCreate=CreateSql
            FROM #IndexesToRebuild
            WHERE RowNo=@IdxRow;

            EXEC sys.sp_executesql @IdxCreate;
            SET @IdxRow+=1;
        END;
    END;

    FETCH NEXT FROM C INTO @ColumnName;
END;

CLOSE C;
DEALLOCATE C;
DROP TABLE #IndexesToRebuild;
GO

PRINT N'27_post_sto_cleanup_orphan_exam_columns.sql: OK';
GO
