/*
QLPM - XOA DU LIEU THUOC TESTAHP KHOI PRODUCTION
- Chi nhan dien thuoc test theo MaThuoc TESTAHP* hoac TenThuoc co marker [TEST-AHP].
- Xoa cac dong con dang FK truc tiep toi DM_Thuoc truoc khi xoa master.
- Xu ly QL_ThuTien_CT va self-reference cua QL_ToaThuoc_CT truoc de khong vo FK.
- Script idempotent: chay lai khong loi neu da sach.
*/

USE [QLPM];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.DM_Thuoc',N'U') IS NULL
BEGIN
    PRINT N'Cleanup TESTAHP: khong co dbo.DM_Thuoc, bo qua.';
    RETURN;
END;
GO

BEGIN TRY
    BEGIN TRAN;

    IF OBJECT_ID('tempdb..#TestThuoc') IS NOT NULL DROP TABLE #TestThuoc;
    CREATE TABLE #TestThuoc
    (
        IDCSKCB BIGINT NOT NULL,
        ID BIGINT NOT NULL,
        MaThuoc NVARCHAR(150) NULL,
        TenThuoc NVARCHAR(500) NULL,
        CONSTRAINT PK_Temp_TestThuoc PRIMARY KEY(IDCSKCB,ID)
    );

    INSERT #TestThuoc(IDCSKCB,ID,MaThuoc,TenThuoc)
    SELECT IDCSKCB,ID,MaThuoc,TenThuoc
    FROM dbo.DM_Thuoc
    WHERE UPPER(LTRIM(RTRIM(ISNULL(MaThuoc,N'')))) LIKE N'TESTAHP%'
       OR CHARINDEX(N'[TEST-AHP]',UPPER(ISNULL(TenThuoc,N'')))>0;

    DECLARE @SoThuoc INT=(SELECT COUNT(*) FROM #TestThuoc);

    IF @SoThuoc=0
    BEGIN
        COMMIT;
        PRINT N'Cleanup TESTAHP: DM_Thuoc da sach.';
        RETURN;
    END;

    /* Ghi lai cac luot bi anh huong de cap nhat tong tien sau khi xoa toa test. */
    IF OBJECT_ID('tempdb..#AffectedVisit') IS NOT NULL DROP TABLE #AffectedVisit;
    CREATE TABLE #AffectedVisit
    (
        IDCSKCB BIGINT NOT NULL,
        IDVaoVien BIGINT NOT NULL,
        CONSTRAINT PK_Temp_AffectedVisit PRIMARY KEY(IDCSKCB,IDVaoVien)
    );

    IF OBJECT_ID(N'dbo.QL_ToaThuoc_CT',N'U') IS NOT NULL
    BEGIN
        INSERT #AffectedVisit(IDCSKCB,IDVaoVien)
        SELECT DISTINCT T.IDCSKCB,T.IDVaoVien
        FROM dbo.QL_ToaThuoc_CT T
        INNER JOIN #TestThuoc X
            ON X.IDCSKCB=T.IDCSKCB AND X.ID=T.IDThuoc;

        IF OBJECT_ID('tempdb..#TestToa') IS NOT NULL DROP TABLE #TestToa;
        CREATE TABLE #TestToa
        (
            IDCSKCB BIGINT NOT NULL,
            ID BIGINT NOT NULL,
            CONSTRAINT PK_Temp_TestToa PRIMARY KEY(IDCSKCB,ID)
        );

        INSERT #TestToa(IDCSKCB,ID)
        SELECT T.IDCSKCB,T.ID
        FROM dbo.QL_ToaThuoc_CT T
        INNER JOIN #TestThuoc X
            ON X.IDCSKCB=T.IDCSKCB AND X.ID=T.IDThuoc;

        IF OBJECT_ID(N'dbo.QL_ThuTien_CT',N'U') IS NOT NULL
           AND COL_LENGTH(N'dbo.QL_ThuTien_CT',N'IDToaThuocCT') IS NOT NULL
        BEGIN
            DELETE C
            FROM dbo.QL_ThuTien_CT C
            INNER JOIN #TestToa T
                ON T.IDCSKCB=C.IDCSKCB AND T.ID=C.IDToaThuocCT;
        END;

        IF COL_LENGTH(N'dbo.QL_ToaThuoc_CT',N'IDToaThuocCTGoc') IS NOT NULL
        BEGIN
            UPDATE C
            SET IDToaThuocCTGoc=NULL
            FROM dbo.QL_ToaThuoc_CT C
            INNER JOIN #TestToa T
                ON T.IDCSKCB=C.IDCSKCB AND T.ID=C.IDToaThuocCTGoc
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM #TestThuoc X
                WHERE X.IDCSKCB=C.IDCSKCB AND X.ID=C.IDThuoc
            );
        END;
    END;

    /*
      Xoa tat ca bang con FK truc tiep toi DM_Thuoc.
      Cach nay bao phu ca bang common va cac bang DSS chi co o Hieu_QLPM.
    */
    DECLARE
        @FKName SYSNAME,
        @ChildSchema SYSNAME,
        @ChildTable SYSNAME,
        @Join NVARCHAR(MAX),
        @Sql NVARCHAR(MAX);

    DECLARE fk_cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT FK.name,SC.name,TB.name
    FROM sys.foreign_keys FK
    INNER JOIN sys.tables TB ON TB.object_id=FK.parent_object_id
    INNER JOIN sys.schemas SC ON SC.schema_id=TB.schema_id
    WHERE FK.referenced_object_id=OBJECT_ID(N'dbo.DM_Thuoc')
    ORDER BY SC.name,TB.name,FK.name;

    OPEN fk_cur;
    FETCH NEXT FROM fk_cur INTO @FKName,@ChildSchema,@ChildTable;

    WHILE @@FETCH_STATUS=0
    BEGIN
        SELECT @Join=STRING_AGG
        (
            N'C.'+QUOTENAME(COL_NAME(FKC.parent_object_id,FKC.parent_column_id))
            +N'=T.'+QUOTENAME(COL_NAME(FKC.referenced_object_id,FKC.referenced_column_id)),
            N' AND '
        ) WITHIN GROUP (ORDER BY FKC.constraint_column_id)
        FROM sys.foreign_key_columns FKC
        WHERE FKC.constraint_object_id=OBJECT_ID(QUOTENAME(@ChildSchema)+N'.'+QUOTENAME(@FKName));

        IF NULLIF(@Join,N'') IS NULL
            THROW 58001,N'Khong doc duoc mapping FK toi DM_Thuoc.',1;

        IF EXISTS
        (
            SELECT 1
            FROM sys.foreign_key_columns FKC
            WHERE FKC.constraint_object_id=OBJECT_ID(QUOTENAME(@ChildSchema)+N'.'+QUOTENAME(@FKName))
              AND COL_NAME(FKC.referenced_object_id,FKC.referenced_column_id) NOT IN(N'ID',N'IDCSKCB')
        )
            THROW 58002,N'Phat hien FK DM_Thuoc tham chieu cot ngoai ID/IDCSKCB; dung cleanup de kiem tra thu cong.',1;

        SET @Sql=
            N'DELETE C FROM '+QUOTENAME(@ChildSchema)+N'.'+QUOTENAME(@ChildTable)
            +N' C INNER JOIN #TestThuoc T ON '+@Join+N';';

        EXEC sys.sp_executesql @Sql;

        FETCH NEXT FROM fk_cur INTO @FKName,@ChildSchema,@ChildTable;
    END;

    CLOSE fk_cur;
    DEALLOCATE fk_cur;

    /* Xoa master TESTAHP sau khi tat ca FK truc tiep da sach. */
    DELETE D
    FROM dbo.DM_Thuoc D
    INNER JOIN #TestThuoc T
        ON T.IDCSKCB=D.IDCSKCB AND T.ID=D.ID;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.DM_Thuoc
        WHERE UPPER(LTRIM(RTRIM(ISNULL(MaThuoc,N'')))) LIKE N'TESTAHP%'
           OR CHARINDEX(N'[TEST-AHP]',UPPER(ISNULL(TenThuoc,N'')))>0
    )
        THROW 58003,N'Cleanup TESTAHP chua xoa het DM_Thuoc.',1;

    /* Dong bo lai tong thu neu cac dong toa test tung nam trong luot kham. */
    IF OBJECT_ID(N'dbo.STO_QL_ThuTien_CapNhatTong',N'P') IS NOT NULL
    BEGIN
        DECLARE @IDCSKCB BIGINT,@IDVaoVien BIGINT;
        DECLARE vv_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT IDCSKCB,IDVaoVien FROM #AffectedVisit;

        OPEN vv_cur;
        FETCH NEXT FROM vv_cur INTO @IDCSKCB,@IDVaoVien;

        WHILE @@FETCH_STATUS=0
        BEGIN
            EXEC dbo.STO_QL_ThuTien_CapNhatTong
                @IDCSKCB=@IDCSKCB,
                @IDVaoVien=@IDVaoVien;

            FETCH NEXT FROM vv_cur INTO @IDCSKCB,@IDVaoVien;
        END;

        CLOSE vv_cur;
        DEALLOCATE vv_cur;
    END;

    COMMIT;
    PRINT CONCAT(N'Cleanup TESTAHP: da xoa ',@SoThuoc,N' thuoc test va cac tham chieu lien quan.');
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local','fk_cur')>=0 CLOSE fk_cur;
    IF CURSOR_STATUS('local','fk_cur')>-3 DEALLOCATE fk_cur;

    IF CURSOR_STATUS('local','vv_cur')>=0 CLOSE vv_cur;
    IF CURSOR_STATUS('local','vv_cur')>-3 DEALLOCATE vv_cur;

    IF XACT_STATE()<>0 ROLLBACK;
    THROW;
END CATCH;
GO
