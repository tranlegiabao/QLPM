/*
25_common_nhan_vien_nhieu_cskcb_chuc_danh.sql

Muc tieu:
- DM_NhanVien la ho so nhan vien dung chung, KHONG thuoc truc tiep mot CSKCB.
- DM_NhanVien_CSKCB la bang noi N-N: 1 nhan vien <-> nhieu CSKCB.
- DM_ChucDanh la danh muc dung chung, co VietTat de in/phuc vu UI.
- Vai tro/phan quyen hoan toan tach khoi chuc danh nghe nghiep.
- Nguon chuan chuc danh la DM_NhanVien.IDChucDanh; khong giu cot snapshot/fallback.
*/
USE [QLPM];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
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

/* Dong bo 11 chuc danh canonical */
DECLARE @SeedCD TABLE (MaChucDanh NVARCHAR(60), TenChucDanh NVARCHAR(200), VietTat NVARCHAR(50), Active BIT);
INSERT INTO @SeedCD (MaChucDanh, TenChucDanh, VietTat, Active) VALUES
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

INSERT dbo.DM_ChucDanh(MaChucDanh, TenChucDanh, VietTat, Active)
SELECT S.MaChucDanh, S.TenChucDanh, S.VietTat, S.Active
FROM @SeedCD S
WHERE NOT EXISTS (SELECT 1 FROM dbo.DM_ChucDanh C WHERE C.MaChucDanh = S.MaChucDanh OR C.TenChucDanh = S.TenChucDanh);

IF COL_LENGTH(N'dbo.DM_NhanVien', N'ChucDanh') IS NOT NULL
BEGIN
    EXEC(N'
        UPDATE N
        SET IDChucDanh = C.ID
        FROM dbo.DM_NhanVien N
        INNER JOIN dbo.DM_ChucDanh C
            ON LOWER(LTRIM(RTRIM(C.TenChucDanh))) = LOWER(LTRIM(RTRIM(N.ChucDanh)))
               OR (C.VietTat IS NOT NULL AND LOWER(LTRIM(RTRIM(C.VietTat))) = LOWER(LTRIM(RTRIM(N.ChucDanh))))
        WHERE N.IDChucDanh IS NULL
          AND NULLIF(LTRIM(RTRIM(N.ChucDanh)), N'''') IS NOT NULL;
    ');
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

/* ==================== 3. DANH SACH NHAN VIEN ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_HT_Nhan_Vien_Danh_Sach
    @IDCSKCB BIGINT=NULL,
    @TuKhoa NVARCHAR(200)=NULL,
    @Trang INT=1,
    @KichThuocTrang INT=25
AS
BEGIN
    SET NOCOUNT ON;
    SET @TuKhoa=NULLIF(LTRIM(RTRIM(@TuKhoa)),N'');
    SET @Trang=CASE WHEN @Trang<1 THEN 1 ELSE @Trang END;
    SET @KichThuocTrang=CASE WHEN @KichThuocTrang<10 THEN 10 WHEN @KichThuocTrang>100 THEN 100 ELSE @KichThuocTrang END;

    ;WITH D AS
    (
        SELECT
            N.ID AS IDNhanVien,
            @IDCSKCB AS IDCSKCB,
            MAP.IDCSKCBs,
            MAP.TenCSKCB,
            N.MaNhanVien,
            N.HoTen,
            N.LaBacSi,
            N.IDChucDanh,
            CD.TenChucDanh AS ChucDanh,
            CD.VietTat AS VietTatChucDanh,
            N.DienThoai,
            N.SoNhaTenDuong,
            N.DiaChi,
            N.MaTinh,
            N.MaPhuongXa,
            N.Email,
            N.Active,
            CASE WHEN TK.ID IS NULL THEN CAST(0 AS BIT) ELSE CAST(1 AS BIT) END AS DaCoTaiKhoan,
            TK.Ten_Dang_Nhap
        FROM dbo.DM_NhanVien N
        LEFT JOIN dbo.DM_ChucDanh CD ON CD.ID=N.IDChucDanh
        CROSS APPLY
        (
            SELECT
                STRING_AGG(CONVERT(NVARCHAR(MAX),M.IDCSKCB),N',')
                    WITHIN GROUP (ORDER BY M.IDCSKCB) AS IDCSKCBs,
                STRING_AGG(CONVERT(NVARCHAR(MAX),C.TenCSKCB),N', ')
                    WITHIN GROUP (ORDER BY M.IDCSKCB) AS TenCSKCB
            FROM dbo.DM_NhanVien_CSKCB M
            INNER JOIN dbo.DM_CSKCB C ON C.ID=M.IDCSKCB
            WHERE M.IDNhanVien=N.ID AND M.Active=1
        ) MAP
        OUTER APPLY
        (
            SELECT TOP(1) T.ID,T.Ten_Dang_Nhap
            FROM dbo.HT_Tai_Khoan T
            WHERE T.IDNhanVien=N.ID
              AND T.LaQuanTriHeThong=0
              AND (@IDCSKCB IS NULL OR T.IDCSKCB=@IDCSKCB)
            ORDER BY CASE WHEN T.Active=1 THEN 0 ELSE 1 END,T.ID DESC
        ) TK
        WHERE
            (@IDCSKCB IS NULL OR EXISTS
            (
                SELECT 1 FROM dbo.DM_NhanVien_CSKCB M0
                WHERE M0.IDNhanVien=N.ID AND M0.IDCSKCB=@IDCSKCB AND M0.Active=1
            ))
            AND
            (
                @TuKhoa IS NULL
                OR N.MaNhanVien LIKE N'%'+@TuKhoa+N'%'
                OR N.HoTen LIKE N'%'+@TuKhoa+N'%'
                OR N.DienThoai LIKE N'%'+@TuKhoa+N'%'
                OR N.Email LIKE N'%'+@TuKhoa+N'%'
                OR ISNULL(CD.TenChucDanh,N'') LIKE N'%'+@TuKhoa+N'%'
                OR ISNULL(MAP.TenCSKCB,N'') LIKE N'%'+@TuKhoa+N'%'
            )
    )
    SELECT D.*,COUNT(*) OVER() AS TongSoDong
    FROM D
    ORDER BY D.IDNhanVien DESC
    OFFSET (@Trang-1)*@KichThuocTrang ROWS
    FETCH NEXT @KichThuocTrang ROWS ONLY;
END;
GO

/* ==================== 4. LUU NHAN VIEN + GAN NHIEU CSKCB ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_HT_Nhan_Vien_Luu
    @IDCSKCB BIGINT,
    @IDNhanVien BIGINT=NULL,
    @MaNhanVien NVARCHAR(30),
    @HoTen NVARCHAR(200),
    @LaBacSi BIT=0,
    @IDChucDanh BIGINT=NULL,
    @CSKCBJson NVARCHAR(MAX)=N'[]',
    @DienThoai NVARCHAR(20)=NULL,
    @SoNhaTenDuong NVARCHAR(300)=NULL,
    @MaTinh NVARCHAR(20)=NULL,
    @MaPhuongXa NVARCHAR(20)=NULL,
    @Email NVARCHAR(200)=NULL,
    @Active BIT=1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        SET @MaNhanVien=NULLIF(LTRIM(RTRIM(@MaNhanVien)),N'');
        SET @HoTen=NULLIF(LTRIM(RTRIM(@HoTen)),N'');
        SET @DienThoai=NULLIF(LTRIM(RTRIM(@DienThoai)),N'');
        SET @SoNhaTenDuong=NULLIF(LTRIM(RTRIM(@SoNhaTenDuong)),N'');
        SET @MaTinh=NULLIF(LTRIM(RTRIM(@MaTinh)),N'');
        SET @MaPhuongXa=NULLIF(LTRIM(RTRIM(@MaPhuongXa)),N'');
        SET @Email=NULLIF(LTRIM(RTRIM(@Email)),N'');

        IF @IDCSKCB<=0 OR NOT EXISTS(SELECT 1 FROM dbo.DM_CSKCB WHERE ID=@IDCSKCB AND Active=1)
            THROW 51000,N'Cơ sở đang làm việc không hợp lệ.',1;
        IF @MaNhanVien IS NULL OR @HoTen IS NULL
            THROW 51000,N'Mã nhân viên và họ tên là bắt buộc.',1;
        IF @DienThoai IS NOT NULL AND (LEN(@DienThoai)>10 OR @DienThoai LIKE N'%[^0-9]%')
            THROW 51000,N'Số điện thoại chỉ được nhập số và tối đa 10 ký tự.',1;
        IF @IDChucDanh IS NOT NULL
           AND NOT EXISTS(SELECT 1 FROM dbo.DM_ChucDanh WHERE ID=@IDChucDanh AND Active=1)
            THROW 51000,N'Chức danh không tồn tại hoặc đã ngừng hoạt động.',1;
        IF ISJSON(ISNULL(@CSKCBJson,N''))<>1
            THROW 51000,N'Danh sách cơ sở làm việc không hợp lệ.',1;

        DECLARE @CS TABLE(IDCSKCB BIGINT PRIMARY KEY);
        INSERT @CS(IDCSKCB)
        SELECT DISTINCT TRY_CONVERT(BIGINT,[value])
        FROM OPENJSON(@CSKCBJson)
        WHERE TRY_CONVERT(BIGINT,[value])>0;

        IF NOT EXISTS(SELECT 1 FROM @CS WHERE IDCSKCB=@IDCSKCB)
            INSERT @CS(IDCSKCB) VALUES(@IDCSKCB);

        IF EXISTS
        (
            SELECT 1 FROM @CS X
            LEFT JOIN dbo.DM_CSKCB C ON C.ID=X.IDCSKCB AND C.Active=1
            WHERE C.ID IS NULL
        )
            THROW 51000,N'Danh sách cơ sở làm việc có cơ sở không tồn tại hoặc đã ngừng.',1;

        IF EXISTS
        (
            SELECT 1 FROM dbo.DM_NhanVien N
            WHERE N.MaNhanVien=@MaNhanVien
              AND (@IDNhanVien IS NULL OR N.ID<>@IDNhanVien)
        )
            THROW 51000,N'Mã nhân viên đã tồn tại ở hồ sơ khác.',1;

        DECLARE @TenChucDanh NVARCHAR(200)=NULL,
                @TenTinh NVARCHAR(200)=NULL,
                @TenPhuongXa NVARCHAR(200)=NULL,
                @DiaChi NVARCHAR(500)=NULL;

        IF @IDChucDanh IS NOT NULL
            SELECT @TenChucDanh=TenChucDanh FROM dbo.DM_ChucDanh WHERE ID=@IDChucDanh;

        IF @MaTinh IS NOT NULL
            SELECT TOP(1) @TenTinh=T.TenTinh
            FROM dbo.DM_TinhThanh T
            WHERE T.Active=1 AND T.MaTinh=@MaTinh
            ORDER BY CASE WHEN T.IDCSKCB=@IDCSKCB THEN 0 ELSE 1 END,T.ID;

        IF @MaPhuongXa IS NOT NULL
            SELECT TOP(1) @TenPhuongXa=P.TenPhuongXa
            FROM dbo.DM_PhuongXa P
            LEFT JOIN dbo.DM_TinhThanh T ON T.IDCSKCB=P.IDCSKCB AND T.ID=P.IDTinhThanh
            WHERE P.Active=1
              AND P.MaPhuongXa=@MaPhuongXa
              AND (@MaTinh IS NULL OR T.MaTinh=@MaTinh)
            ORDER BY CASE WHEN P.IDCSKCB=@IDCSKCB THEN 0 ELSE 1 END,P.ID;

        SET @DiaChi=NULLIF(CONCAT_WS(N', ',@SoNhaTenDuong,@TenPhuongXa,@TenTinh),N'');

        BEGIN TRAN;

        IF @IDNhanVien IS NULL OR @IDNhanVien<=0
        BEGIN
            INSERT dbo.DM_NhanVien
            (
                MaNhanVien,HoTen,LaBacSi,IDChucDanh,DienThoai,
                SoNhaTenDuong,DiaChi,MaTinh,MaPhuongXa,Email,Active
            )
            VALUES
            (
                @MaNhanVien,@HoTen,@LaBacSi,@IDChucDanh,@DienThoai,
                @SoNhaTenDuong,@DiaChi,@MaTinh,@MaPhuongXa,@Email,@Active
            );
            SET @IDNhanVien=SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            IF NOT EXISTS
            (
                SELECT 1
                FROM dbo.DM_NhanVien_CSKCB M
                WHERE M.IDNhanVien=@IDNhanVien AND M.IDCSKCB=@IDCSKCB AND M.Active=1
            )
                THROW 51000,N'Nhân viên không thuộc cơ sở đang quản lý.',1;

            UPDATE dbo.DM_NhanVien
            SET MaNhanVien=@MaNhanVien,
                HoTen=@HoTen,
                LaBacSi=@LaBacSi,
                IDChucDanh=@IDChucDanh,
                DienThoai=@DienThoai,
                SoNhaTenDuong=@SoNhaTenDuong,
                DiaChi=@DiaChi,
                MaTinh=@MaTinh,
                MaPhuongXa=@MaPhuongXa,
                Email=@Email,
                Active=@Active
            WHERE ID=@IDNhanVien;

            IF @@ROWCOUNT=0 THROW 51000,N'Không tìm thấy nhân viên.',1;
        END;

        UPDATE M
        SET Active=CASE WHEN X.IDCSKCB IS NULL THEN 0 ELSE 1 END
        FROM dbo.DM_NhanVien_CSKCB M
        LEFT JOIN @CS X ON X.IDCSKCB=M.IDCSKCB
        WHERE M.IDNhanVien=@IDNhanVien;

        UPDATE M
        SET Active=1
        FROM dbo.DM_NhanVien_CSKCB M
        INNER JOIN @CS X ON X.IDCSKCB=M.IDCSKCB
        WHERE M.IDNhanVien=@IDNhanVien;

        INSERT dbo.DM_NhanVien_CSKCB(IDNhanVien,IDCSKCB,Active)
        SELECT @IDNhanVien,X.IDCSKCB,1
        FROM @CS X
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.DM_NhanVien_CSKCB M
            WHERE M.IDNhanVien=@IDNhanVien AND M.IDCSKCB=X.IDCSKCB
        );

        COMMIT;
        SELECT 200 AS Status,N'Lưu nhân viên và cơ sở làm việc thành công.' AS Message,@IDNhanVien AS IDNhanVien;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 400 AS Status,ERROR_MESSAGE() AS Message,@IDNhanVien AS IDNhanVien;
    END CATCH
END;
GO

/* ==================== 5. GO NHAN VIEN KHOI MOT CSKCB ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_HT_Nhan_Vien_Xoa
    @IDCSKCB BIGINT,
    @IDNhanVien BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.DM_NhanVien_CSKCB
        WHERE IDNhanVien=@IDNhanVien AND IDCSKCB=@IDCSKCB AND Active=1
    )
    BEGIN
        SELECT 404 AS Status,N'Nhân viên không thuộc cơ sở này.' AS Message;
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRAN;

        DELETE TV
        FROM dbo.HT_Tai_Khoan_Vai_Tro TV
        INNER JOIN dbo.HT_Tai_Khoan T
          ON T.IDCSKCB=TV.IDCSKCB AND T.ID=TV.ID_Tai_Khoan
        WHERE T.IDCSKCB=@IDCSKCB AND T.IDNhanVien=@IDNhanVien;

        DELETE dbo.HT_Tai_Khoan
        WHERE IDCSKCB=@IDCSKCB AND IDNhanVien=@IDNhanVien AND LaQuanTriHeThong=0;

        UPDATE dbo.DM_NhanVien_CSKCB
        SET Active=0
        WHERE IDNhanVien=@IDNhanVien AND IDCSKCB=@IDCSKCB;

        IF NOT EXISTS
        (
            SELECT 1 FROM dbo.DM_NhanVien_CSKCB
            WHERE IDNhanVien=@IDNhanVien AND Active=1
        )
            UPDATE dbo.DM_NhanVien SET Active=0 WHERE ID=@IDNhanVien;

        COMMIT;
        SELECT 200 AS Status,N'Đã gỡ nhân viên khỏi cơ sở. Dữ liệu khám lịch sử được giữ nguyên.' AS Message;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 500 AS Status,ERROR_MESSAGE() AS Message;
    END CATCH
END;
GO

/* ==================== 6. TAI KHOAN THEO QUAN HE NHAN VIEN-CSKCB ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_HT_Tai_Khoan_Danh_Sach
    @IDCSKCB BIGINT=NULL,
    @TuKhoa NVARCHAR(200)=NULL,
    @Trang INT=1,
    @KichThuocTrang INT=25
AS
BEGIN
    SET NOCOUNT ON;
    SET @TuKhoa=NULLIF(LTRIM(RTRIM(@TuKhoa)),N'');
    SET @Trang=CASE WHEN @Trang<1 THEN 1 ELSE @Trang END;
    SET @KichThuocTrang=CASE WHEN @KichThuocTrang<10 THEN 10 WHEN @KichThuocTrang>100 THEN 100 ELSE @KichThuocTrang END;

    ;WITH D AS
    (
        SELECT
            T.ID AS ID_Tai_Khoan,T.IDCSKCB,C.MaCSKCB,C.TenCSKCB,T.IDNhanVien,
            N.MaNhanVien,N.HoTen,N.IDChucDanh,CD.TenChucDanh AS ChucDanh,
            T.Ten_Dang_Nhap,T.Bat_Buoc_Doi_Mat_Khau,T.So_Lan_Dang_Nhap_Sai,T.Khoa_Den_Luc,T.Lan_Dang_Nhap_Cuoi,T.Active,
            STRING_AGG(V.Ten_Vai_Tro,N', ') WITHIN GROUP (ORDER BY V.Ten_Vai_Tro,V.ID) AS Vai_Tro,
            STRING_AGG(CONVERT(NVARCHAR(MAX),V.ID),N',') AS ID_Vai_Tro
        FROM dbo.HT_Tai_Khoan T
        INNER JOIN dbo.DM_CSKCB C ON C.ID=T.IDCSKCB
        INNER JOIN dbo.DM_NhanVien N ON N.ID=T.IDNhanVien
        INNER JOIN dbo.DM_NhanVien_CSKCB M
            ON M.IDNhanVien=N.ID AND M.IDCSKCB=T.IDCSKCB AND M.Active=1
        LEFT JOIN dbo.DM_ChucDanh CD ON CD.ID=N.IDChucDanh
        LEFT JOIN dbo.HT_Tai_Khoan_Vai_Tro TV
          ON TV.IDCSKCB=T.IDCSKCB AND TV.ID_Tai_Khoan=T.ID AND TV.Active=1
        LEFT JOIN dbo.DM_Vai_Tro V
          ON V.IDCSKCB=TV.IDCSKCB AND V.ID=TV.ID_Vai_Tro AND V.Active=1
        WHERE T.LaQuanTriHeThong=0
          AND (@IDCSKCB IS NULL OR T.IDCSKCB=@IDCSKCB)
          AND
          (
              @TuKhoa IS NULL
              OR T.Ten_Dang_Nhap LIKE N'%'+@TuKhoa+N'%'
              OR N.MaNhanVien LIKE N'%'+@TuKhoa+N'%'
              OR N.HoTen LIKE N'%'+@TuKhoa+N'%'
              OR C.MaCSKCB LIKE N'%'+@TuKhoa+N'%'
              OR C.TenCSKCB LIKE N'%'+@TuKhoa+N'%'
          )
        GROUP BY
            T.ID,T.IDCSKCB,C.MaCSKCB,C.TenCSKCB,T.IDNhanVien,
            N.MaNhanVien,N.HoTen,N.IDChucDanh,CD.TenChucDanh,
            T.Ten_Dang_Nhap,T.Bat_Buoc_Doi_Mat_Khau,T.So_Lan_Dang_Nhap_Sai,
            T.Khoa_Den_Luc,T.Lan_Dang_Nhap_Cuoi,T.Active
    )
    SELECT D.*,COUNT(*) OVER() AS TongSoDong
    FROM D
    ORDER BY D.ID_Tai_Khoan DESC
    OFFSET (@Trang-1)*@KichThuocTrang ROWS
    FETCH NEXT @KichThuocTrang ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_Tai_Khoan_Luu
    @IDCSKCB BIGINT,
    @ID_Tai_Khoan BIGINT=NULL,
    @IDNhanVien BIGINT,
    @Ten_Dang_Nhap NVARCHAR(150),
    @Mat_Khau_Hash NVARCHAR(1000)=NULL,
    @Vai_Tro_Json NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        SET @Ten_Dang_Nhap=LTRIM(RTRIM(@Ten_Dang_Nhap));
        IF @Ten_Dang_Nhap=N'' THROW 51000,N'Tên đăng nhập là bắt buộc.',1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.DM_NhanVien N
            INNER JOIN dbo.DM_NhanVien_CSKCB M
              ON M.IDNhanVien=N.ID AND M.IDCSKCB=@IDCSKCB AND M.Active=1
            WHERE N.ID=@IDNhanVien AND N.Active=1
        )
            THROW 51000,N'Nhân viên không thuộc cơ sở hoặc đã ngừng hoạt động.',1;

        IF EXISTS
        (
            SELECT 1 FROM dbo.HT_Tai_Khoan
            WHERE LOWER(Ten_Dang_Nhap)=LOWER(@Ten_Dang_Nhap)
              AND (@ID_Tai_Khoan IS NULL OR ID<>@ID_Tai_Khoan)
        )
            THROW 51000,N'Tên đăng nhập đã tồn tại.',1;

        IF @ID_Tai_Khoan IS NULL OR @ID_Tai_Khoan=0
        BEGIN
            IF NULLIF(@Mat_Khau_Hash,N'') IS NULL
                THROW 51000,N'Mật khẩu là bắt buộc khi tạo tài khoản.',1;
            IF EXISTS
            (
                SELECT 1 FROM dbo.HT_Tai_Khoan
                WHERE IDCSKCB=@IDCSKCB AND IDNhanVien=@IDNhanVien AND LaQuanTriHeThong=0
            )
                THROW 51000,N'Nhân viên đã có tài khoản tại cơ sở này.',1;

            INSERT dbo.HT_Tai_Khoan
            (IDCSKCB,IDNhanVien,Ten_Dang_Nhap,Mat_Khau_Hash,Bat_Buoc_Doi_Mat_Khau,LaQuanTriHeThong)
            VALUES(@IDCSKCB,@IDNhanVien,@Ten_Dang_Nhap,@Mat_Khau_Hash,0,0);
            SET @ID_Tai_Khoan=SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            IF NOT EXISTS
            (
                SELECT 1 FROM dbo.HT_Tai_Khoan
                WHERE ID=@ID_Tai_Khoan AND IDCSKCB=@IDCSKCB AND LaQuanTriHeThong=0
            )
                THROW 51000,N'Không tìm thấy tài khoản.',1;

            UPDATE dbo.HT_Tai_Khoan
            SET IDNhanVien=@IDNhanVien,
                Ten_Dang_Nhap=@Ten_Dang_Nhap,
                Mat_Khau_Hash=COALESCE(NULLIF(@Mat_Khau_Hash,N''),Mat_Khau_Hash),
                Ngay_Cap_Nhat=SYSDATETIME()
            WHERE ID=@ID_Tai_Khoan AND IDCSKCB=@IDCSKCB;
        END;

        UPDATE dbo.HT_Tai_Khoan_Vai_Tro
        SET Active=0
        WHERE IDCSKCB=@IDCSKCB AND ID_Tai_Khoan=@ID_Tai_Khoan;

        ;WITH V AS
        (
            SELECT DISTINCT TRY_CONVERT(BIGINT,[value]) AS ID_Vai_Tro
            FROM OPENJSON(ISNULL(@Vai_Tro_Json,N'[]'))
            WHERE TRY_CONVERT(BIGINT,[value]) IS NOT NULL
        )
        UPDATE TV SET Active=1
        FROM dbo.HT_Tai_Khoan_Vai_Tro TV
        INNER JOIN V ON V.ID_Vai_Tro=TV.ID_Vai_Tro
        WHERE TV.IDCSKCB=@IDCSKCB AND TV.ID_Tai_Khoan=@ID_Tai_Khoan;

        ;WITH V AS
        (
            SELECT DISTINCT TRY_CONVERT(BIGINT,[value]) AS ID_Vai_Tro
            FROM OPENJSON(ISNULL(@Vai_Tro_Json,N'[]'))
            WHERE TRY_CONVERT(BIGINT,[value]) IS NOT NULL
        )
        INSERT dbo.HT_Tai_Khoan_Vai_Tro(IDCSKCB,ID_Tai_Khoan,ID_Vai_Tro,Active)
        SELECT @IDCSKCB,@ID_Tai_Khoan,V.ID_Vai_Tro,1
        FROM V
        INNER JOIN dbo.DM_Vai_Tro R
          ON R.IDCSKCB=@IDCSKCB AND R.ID=V.ID_Vai_Tro AND R.Active=1
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.HT_Tai_Khoan_Vai_Tro X
            WHERE X.IDCSKCB=@IDCSKCB AND X.ID_Tai_Khoan=@ID_Tai_Khoan AND X.ID_Vai_Tro=V.ID_Vai_Tro
        );

        COMMIT;
        SELECT 200 AS Status,N'Lưu tài khoản thành công.' AS Message,@ID_Tai_Khoan AS ID_Tai_Khoan;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 400 AS Status,ERROR_MESSAGE() AS Message,@ID_Tai_Khoan AS ID_Tai_Khoan;
    END CATCH
END;
GO

/* ==================== 7. DANG NHAP / PHIEN ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_HT_Dang_Nhap_Lay_Tai_Khoan
    @Ten_Dang_Nhap NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP(1)
        T.ID AS ID_Tai_Khoan,
        T.IDCSKCB,
        T.IDNhanVien,
        T.Ten_Dang_Nhap,
        T.Mat_Khau_Hash,
        T.Bat_Buoc_Doi_Mat_Khau,
        T.So_Lan_Dang_Nhap_Sai,
        T.Khoa_Den_Luc,
        T.Lan_Dang_Nhap_Cuoi,
        T.Active AS Tai_Khoan_Active,
        T.LaQuanTriHeThong,
        CASE WHEN T.LaQuanTriHeThong=1 THEN T.Ten_Dang_Nhap ELSE N.HoTen END AS HoTen,
        CASE WHEN T.LaQuanTriHeThong=1 THEN N'ADMIN' ELSE N.MaNhanVien END AS MaNhanVien,
        CASE WHEN T.LaQuanTriHeThong=1 THEN CAST(0 AS BIT) ELSE ISNULL(N.LaBacSi,0) END AS LaBacSi,
        CASE WHEN T.LaQuanTriHeThong=1 THEN N'Quản trị hệ thống' ELSE CD.TenChucDanh END AS ChucDanh,
        CASE
            WHEN T.LaQuanTriHeThong=1 THEN CAST(1 AS BIT)
            WHEN ISNULL(N.Active,0)=1 AND ISNULL(M.Active,0)=1 THEN CAST(1 AS BIT)
            ELSE CAST(0 AS BIT)
        END AS Nhan_Vien_Active,
        CASE WHEN T.LaQuanTriHeThong=1 THEN NULL ELSE C.TenCSKCB END AS TenCSKCB,
        CASE WHEN T.LaQuanTriHeThong=1 THEN CAST(1 AS BIT) ELSE ISNULL(C.Active,0) END AS CSKCB_Active
    FROM dbo.HT_Tai_Khoan T
    LEFT JOIN dbo.DM_NhanVien N
      ON T.LaQuanTriHeThong=0 AND N.ID=T.IDNhanVien
    LEFT JOIN dbo.DM_NhanVien_CSKCB M
      ON T.LaQuanTriHeThong=0 AND M.IDNhanVien=T.IDNhanVien AND M.IDCSKCB=T.IDCSKCB
    LEFT JOIN dbo.DM_ChucDanh CD ON CD.ID=N.IDChucDanh
    LEFT JOIN dbo.DM_CSKCB C
      ON T.LaQuanTriHeThong=0 AND C.ID=T.IDCSKCB
    WHERE T.Ten_Dang_Nhap COLLATE Latin1_General_100_BIN2
        = LTRIM(RTRIM(@Ten_Dang_Nhap)) COLLATE Latin1_General_100_BIN2;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_Phien_Kiem_Tra
    @ID_Tai_Khoan BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP(1)
        T.ID AS ID_Tai_Khoan,
        T.IDCSKCB,
        T.IDNhanVien,
        T.Ten_Dang_Nhap,
        T.Bat_Buoc_Doi_Mat_Khau,
        T.Active AS Tai_Khoan_Active,
        T.LaQuanTriHeThong,
        CASE WHEN T.LaQuanTriHeThong=1 THEN N'ADMIN' ELSE N.MaNhanVien END AS MaNhanVien,
        CASE WHEN T.LaQuanTriHeThong=1 THEN T.Ten_Dang_Nhap ELSE N.HoTen END AS HoTen,
        CASE
            WHEN T.LaQuanTriHeThong=1 THEN CAST(1 AS BIT)
            WHEN ISNULL(N.Active,0)=1 AND ISNULL(M.Active,0)=1 THEN CAST(1 AS BIT)
            ELSE CAST(0 AS BIT)
        END AS Nhan_Vien_Active,
        CASE WHEN T.LaQuanTriHeThong=1 THEN NULL ELSE C.TenCSKCB END AS TenCSKCB,
        CASE WHEN T.LaQuanTriHeThong=1 THEN CAST(1 AS BIT) ELSE ISNULL(C.Active,0) END AS CSKCB_Active
    FROM dbo.HT_Tai_Khoan T
    LEFT JOIN dbo.DM_NhanVien N
      ON T.LaQuanTriHeThong=0 AND N.ID=T.IDNhanVien
    LEFT JOIN dbo.DM_NhanVien_CSKCB M
      ON T.LaQuanTriHeThong=0 AND M.IDNhanVien=T.IDNhanVien AND M.IDCSKCB=T.IDCSKCB
    LEFT JOIN dbo.DM_CSKCB C
      ON T.LaQuanTriHeThong=0 AND C.ID=T.IDCSKCB
    WHERE T.ID=@ID_Tai_Khoan;
END;
GO

/* ==================== 8. BOOTSTRAP ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_HT_Khoi_Tao_Thong_Tin
    @IDCSKCB BIGINT=NULL,
    @TuKhoa NVARCHAR(200)=NULL,
    @Top INT=100
AS
BEGIN
    SET NOCOUNT ON;
    SET @TuKhoa=NULLIF(LTRIM(RTRIM(@TuKhoa)),N'');
    SET @Top=CASE WHEN @Top<1 THEN 1 WHEN @Top>100 THEN 100 ELSE @Top END;

    SELECT TOP (@Top)
        C.ID AS IDCSKCB,C.MaCSKCB,C.TenCSKCB,C.Active,
        CASE WHEN EXISTS(SELECT 1 FROM dbo.HT_Tai_Khoan T WHERE T.IDCSKCB=C.ID)
             THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS DaCoTaiKhoan
    FROM dbo.DM_CSKCB C
    WHERE C.Active=1
      AND (@IDCSKCB IS NULL OR C.ID=@IDCSKCB)
      AND (@TuKhoa IS NULL OR C.MaCSKCB LIKE N'%'+@TuKhoa+N'%' OR C.TenCSKCB LIKE N'%'+@TuKhoa+N'%')
    ORDER BY C.TenCSKCB,C.ID;

    SELECT TOP (@Top)
        N.ID AS IDNhanVien,
        @IDCSKCB AS IDCSKCB,
        N.MaNhanVien,
        N.HoTen,
        N.LaBacSi,
        N.IDChucDanh,
        CD.TenChucDanh AS ChucDanh
    FROM dbo.DM_NhanVien N
    INNER JOIN dbo.DM_NhanVien_CSKCB M
      ON M.IDNhanVien=N.ID AND M.IDCSKCB=@IDCSKCB AND M.Active=1
    LEFT JOIN dbo.DM_ChucDanh CD ON CD.ID=N.IDChucDanh
    WHERE @IDCSKCB IS NOT NULL
      AND N.Active=1
      AND (@TuKhoa IS NULL OR N.MaNhanVien LIKE N'%'+@TuKhoa+N'%' OR N.HoTen LIKE N'%'+@TuKhoa+N'%')
      AND NOT EXISTS
      (
          SELECT 1 FROM dbo.HT_Tai_Khoan T
          WHERE T.IDCSKCB=@IDCSKCB AND T.IDNhanVien=N.ID AND T.LaQuanTriHeThong=0
      )
    ORDER BY N.HoTen,N.ID;
END;
GO

/* ==================== 9. IMPORT NHAN VIEN ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_HT_Nhan_Vien_Import_Excel
    @IDCSKCB BIGINT,
    @DuLieuJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @IDCSKCB<=0 OR NOT EXISTS(SELECT 1 FROM dbo.DM_CSKCB WHERE ID=@IDCSKCB AND Active=1)
    BEGIN
        SELECT 400 Status,N'Thiếu cơ sở khám chữa bệnh.' Message,0 SoDong,0 SoThem,0 SoCapNhat;
        SELECT TOP(0) CAST(NULL AS INT) DongExcel,CAST(NULL AS NVARCHAR(30)) MaNhanVien,CAST(NULL AS NVARCHAR(2000)) Loi;
        RETURN;
    END;

    IF ISJSON(ISNULL(@DuLieuJson,N''))<>1
    BEGIN
        SELECT 400 Status,N'Dữ liệu import không hợp lệ.' Message,0 SoDong,0 SoThem,0 SoCapNhat;
        SELECT TOP(0) CAST(NULL AS INT) DongExcel,CAST(NULL AS NVARCHAR(30)) MaNhanVien,CAST(NULL AS NVARCHAR(2000)) Loi;
        RETURN;
    END;

    DECLARE @D TABLE
    (
        DongExcel INT NOT NULL,
        MaNhanVien NVARCHAR(30) NULL,
        HoTen NVARCHAR(200) NULL,
        LaBacSi BIT NOT NULL,
        ChucDanh NVARCHAR(100) NULL,
        IDChucDanh BIGINT NULL,
        DienThoai NVARCHAR(20) NULL,
        SoNhaTenDuong NVARCHAR(300) NULL,
        MaTinh NVARCHAR(20) NULL,
        MaPhuongXa NVARCHAR(20) NULL,
        DiaChi NVARCHAR(500) NULL,
        Email NVARCHAR(200) NULL,
        Active BIT NOT NULL,
        LaMoi BIT NULL,
        Loi NVARCHAR(2000) NULL
    );

    INSERT @D(DongExcel,MaNhanVien,HoTen,LaBacSi,ChucDanh,DienThoai,SoNhaTenDuong,MaTinh,MaPhuongXa,Email,Active)
    SELECT
        ISNULL(J.DongExcel,0),NULLIF(LTRIM(RTRIM(J.MaNhanVien)),N''),NULLIF(LTRIM(RTRIM(J.HoTen)),N''),
        ISNULL(J.LaBacSi,0),NULLIF(LTRIM(RTRIM(J.ChucDanh)),N''),NULLIF(LTRIM(RTRIM(J.DienThoai)),N''),
        NULLIF(LTRIM(RTRIM(J.SoNhaTenDuong)),N''),NULLIF(LTRIM(RTRIM(J.MaTinh)),N''),
        NULLIF(LTRIM(RTRIM(J.MaPhuongXa)),N''),NULLIF(LTRIM(RTRIM(J.Email)),N''),ISNULL(J.Active,1)
    FROM OPENJSON(@DuLieuJson)
    WITH
    (
        DongExcel INT '$.dong_excel',
        MaNhanVien NVARCHAR(30) '$.ma_nhan_vien',
        HoTen NVARCHAR(200) '$.ho_ten',
        LaBacSi BIT '$.la_bac_si',
        ChucDanh NVARCHAR(100) '$.chuc_danh',
        DienThoai NVARCHAR(20) '$.dien_thoai',
        SoNhaTenDuong NVARCHAR(300) '$.so_nha_ten_duong',
        MaTinh NVARCHAR(20) '$.ma_tinh',
        MaPhuongXa NVARCHAR(20) '$.ma_phuong_xa',
        Email NVARCHAR(200) '$.email',
        Active BIT '$.active'
    ) J;

    UPDATE D
    SET IDChucDanh=CD.ID
    FROM @D D
    OUTER APPLY
    (
        SELECT TOP(1) C.ID
        FROM dbo.DM_ChucDanh C
        WHERE C.Active=1
          AND D.ChucDanh IS NOT NULL
          AND
          (
              LOWER(C.MaChucDanh)=LOWER(D.ChucDanh)
              OR LOWER(C.TenChucDanh)=LOWER(D.ChucDanh)
              OR LOWER(ISNULL(C.VietTat,N''))=LOWER(D.ChucDanh)
          )
        ORDER BY C.ID
    ) CD;

    UPDATE D
    SET Loi=NULLIF(CONCAT_WS(N'; ',
        CASE WHEN DongExcel<=1 THEN N'Số dòng Excel không hợp lệ' END,
        CASE WHEN MaNhanVien IS NULL THEN N'Thiếu Mã nhân viên' END,
        CASE WHEN HoTen IS NULL THEN N'Thiếu Họ tên' END,
        CASE WHEN ChucDanh IS NOT NULL AND IDChucDanh IS NULL THEN N'Chức danh không có trong danh mục chức danh' END,
        CASE WHEN DienThoai IS NOT NULL AND (LEN(DienThoai)>10 OR DienThoai LIKE N'%[^0-9]%') THEN N'SĐT chỉ được nhập số và tối đa 10 ký tự' END,
        CASE WHEN (SELECT COUNT(*) FROM dbo.DM_NhanVien N WHERE N.MaNhanVien=D.MaNhanVien)>1 THEN N'Mã nhân viên đang trùng ở nhiều hồ sơ; cần gộp thủ công' END
    ),N'')
    FROM @D D;

    ;WITH Dup AS
    (
        SELECT MaNhanVien FROM @D WHERE MaNhanVien IS NOT NULL
        GROUP BY MaNhanVien HAVING COUNT(*)>1
    )
    UPDATE D
    SET Loi=CONCAT_WS(N'; ',NULLIF(D.Loi,N''),N'Trùng Mã nhân viên trong file Excel')
    FROM @D D INNER JOIN Dup X ON X.MaNhanVien=D.MaNhanVien;

    UPDATE D
    SET DiaChi=NULLIF(CONCAT_WS(N', ',D.SoNhaTenDuong,PX.TenPhuongXa,TT.TenTinh),N'')
    FROM @D D
    OUTER APPLY
    (
        SELECT TOP(1) T.TenTinh FROM dbo.DM_TinhThanh T
        WHERE T.Active=1 AND T.MaTinh=D.MaTinh
        ORDER BY CASE WHEN T.IDCSKCB=@IDCSKCB THEN 0 ELSE 1 END,T.ID
    ) TT
    OUTER APPLY
    (
        SELECT TOP(1) P.TenPhuongXa
        FROM dbo.DM_PhuongXa P
        LEFT JOIN dbo.DM_TinhThanh T ON T.IDCSKCB=P.IDCSKCB AND T.ID=P.IDTinhThanh
        WHERE P.Active=1 AND P.MaPhuongXa=D.MaPhuongXa
          AND (D.MaTinh IS NULL OR T.MaTinh=D.MaTinh)
        ORDER BY CASE WHEN P.IDCSKCB=@IDCSKCB THEN 0 ELSE 1 END,P.ID
    ) PX;

    UPDATE D
    SET LaMoi=CASE WHEN EXISTS(SELECT 1 FROM dbo.DM_NhanVien N WHERE N.MaNhanVien=D.MaNhanVien) THEN 0 ELSE 1 END
    FROM @D D WHERE D.MaNhanVien IS NOT NULL;

    DECLARE @SoDong INT=(SELECT COUNT(*) FROM @D),
            @SoThem INT=(SELECT COUNT(*) FROM @D WHERE LaMoi=1),
            @SoCapNhat INT=(SELECT COUNT(*) FROM @D WHERE LaMoi=0);

    IF EXISTS(SELECT 1 FROM @D WHERE Loi IS NOT NULL)
    BEGIN
        SELECT 400 Status,N'File có dữ liệu không hợp lệ. Chưa import dòng nào.' Message,@SoDong SoDong,0 SoThem,0 SoCapNhat;
        SELECT DongExcel,MaNhanVien,Loi FROM @D WHERE Loi IS NOT NULL ORDER BY DongExcel;
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRAN;

        UPDATE N
        SET N.HoTen=D.HoTen,N.LaBacSi=D.LaBacSi,N.IDChucDanh=D.IDChucDanh,
            N.DienThoai=D.DienThoai,N.SoNhaTenDuong=D.SoNhaTenDuong,
            N.DiaChi=D.DiaChi,N.MaTinh=D.MaTinh,N.MaPhuongXa=D.MaPhuongXa,N.Email=D.Email,N.Active=D.Active
        FROM dbo.DM_NhanVien N
        INNER JOIN @D D ON D.MaNhanVien=N.MaNhanVien AND D.LaMoi=0
        LEFT JOIN dbo.DM_ChucDanh CD ON CD.ID=D.IDChucDanh;

        INSERT dbo.DM_NhanVien
        (MaNhanVien,HoTen,LaBacSi,IDChucDanh,DienThoai,SoNhaTenDuong,DiaChi,MaTinh,MaPhuongXa,Email,Active)
        SELECT D.MaNhanVien,D.HoTen,D.LaBacSi,D.IDChucDanh,D.DienThoai,
               D.SoNhaTenDuong,D.DiaChi,D.MaTinh,D.MaPhuongXa,D.Email,D.Active
        FROM @D D
        LEFT JOIN dbo.DM_ChucDanh CD ON CD.ID=D.IDChucDanh
        WHERE D.LaMoi=1;

        UPDATE M SET Active=1
        FROM dbo.DM_NhanVien_CSKCB M
        INNER JOIN dbo.DM_NhanVien N ON N.ID=M.IDNhanVien
        INNER JOIN @D D ON D.MaNhanVien=N.MaNhanVien
        WHERE M.IDCSKCB=@IDCSKCB;

        INSERT dbo.DM_NhanVien_CSKCB(IDNhanVien,IDCSKCB,Active)
        SELECT N.ID,@IDCSKCB,1
        FROM @D D
        INNER JOIN dbo.DM_NhanVien N ON N.MaNhanVien=D.MaNhanVien
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.DM_NhanVien_CSKCB M
            WHERE M.IDNhanVien=N.ID AND M.IDCSKCB=@IDCSKCB
        );

        COMMIT;
        SELECT 200 Status,N'Import nhân viên thành công.' Message,@SoDong SoDong,@SoThem SoThem,@SoCapNhat SoCapNhat;
        SELECT TOP(0) CAST(NULL AS INT) DongExcel,CAST(NULL AS NVARCHAR(30)) MaNhanVien,CAST(NULL AS NVARCHAR(2000)) Loi;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 500 Status,ERROR_MESSAGE() Message,@SoDong SoDong,0 SoThem,0 SoCapNhat;
        SELECT TOP(0) CAST(NULL AS INT) DongExcel,CAST(NULL AS NVARCHAR(30)) MaNhanVien,CAST(NULL AS NVARCHAR(2000)) Loi;
    END CATCH
END;
GO

/* ==================== 10. JSON VERSION ==================== */
CREATE OR ALTER TRIGGER dbo.TR_DM_ChucDanh_JSON_VERSION
ON dbo.DM_ChucDanh
AFTER INSERT,UPDATE,DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS(SELECT 1 FROM inserted) OR EXISTS(SELECT 1 FROM deleted)
        UPDATE dbo.HT_JSON_CSKCB
        SET VersionNo=VersionNo+1,
            TrangThai=N'CHO_DONG_BO',
            LastChangedAt=SYSDATETIME(),
            LastError=NULL,
            UpdatedAt=SYSDATETIME();
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_DM_NhanVien_CSKCB_JSON_VERSION
ON dbo.DM_NhanVien_CSKCB
AFTER INSERT,UPDATE,DELETE
AS
BEGIN
    SET NOCOUNT ON;
    ;WITH C AS
    (
        SELECT IDCSKCB FROM inserted
        UNION
        SELECT IDCSKCB FROM deleted
    )
    UPDATE V
    SET VersionNo=V.VersionNo+1,
        TrangThai=N'CHO_DONG_BO',
        LastChangedAt=SYSDATETIME(),
        LastError=NULL,
        UpdatedAt=SYSDATETIME()
    FROM dbo.HT_JSON_CSKCB V
    INNER JOIN C ON C.IDCSKCB=V.IDCSKCB;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_DM_NhanVien_JSON_VERSION
ON dbo.DM_NhanVien
AFTER INSERT,UPDATE,DELETE
AS
BEGIN
    SET NOCOUNT ON;
    ;WITH N AS
    (
        SELECT ID FROM inserted
        UNION
        SELECT ID FROM deleted
    ),
    C AS
    (
        SELECT DISTINCT M.IDCSKCB
        FROM dbo.DM_NhanVien_CSKCB M
        INNER JOIN N ON N.ID=M.IDNhanVien
    )
    UPDATE V
    SET VersionNo=V.VersionNo+1,
        TrangThai=N'CHO_DONG_BO',
        LastChangedAt=SYSDATETIME(),
        LastError=NULL,
        UpdatedAt=SYSDATETIME()
    FROM dbo.HT_JSON_CSKCB V
    INNER JOIN C ON C.IDCSKCB=V.IDCSKCB;
END;
GO

/* ==================== 11. HARD DELETE CSKCB KHONG XOA NHAN VIEN DUNG CHUNG ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_HT_CSKCB_Xoa
    @IDCSKCB BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS(SELECT 1 FROM dbo.DM_CSKCB WHERE ID=@IDCSKCB)
    BEGIN
        SELECT 404 AS Status,N'Không tìm thấy CSKCB.' AS Message;
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @AppLockResult INT;
        DECLARE @AppLockResource NVARCHAR(255)=N'QLPM_HARD_DELETE_CSKCB_'+CONVERT(NVARCHAR(30),@IDCSKCB);
        EXEC @AppLockResult=sys.sp_getapplock
            @Resource=@AppLockResource,@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=10000;
        IF @AppLockResult<0 THROW 51000,N'Không lấy được khóa xóa CSKCB. Hãy thử lại.',1;

        DECLARE @AffectedEmployee TABLE(IDNhanVien BIGINT PRIMARY KEY);
        INSERT @AffectedEmployee(IDNhanVien)
        SELECT IDNhanVien FROM dbo.DM_NhanVien_CSKCB WHERE IDCSKCB=@IDCSKCB;

        CREATE TABLE #TenantTables(ObjectID INT NOT NULL PRIMARY KEY,SchemaName SYSNAME NOT NULL,TableName SYSNAME NOT NULL);
        INSERT #TenantTables(ObjectID,SchemaName,TableName)
        SELECT T.object_id,S.name,T.name
        FROM sys.tables T
        INNER JOIN sys.schemas S ON S.schema_id=T.schema_id
        WHERE T.is_ms_shipped=0
          AND EXISTS(SELECT 1 FROM sys.columns C WHERE C.object_id=T.object_id AND C.name=N'IDCSKCB');

        CREATE TABLE #FkTamTat
        (
            ParentObjectID INT NOT NULL,SchemaName SYSNAME NOT NULL,TableName SYSNAME NOT NULL,FKName SYSNAME NOT NULL,
            PRIMARY KEY(ParentObjectID,FKName)
        );
        INSERT #FkTamTat(ParentObjectID,SchemaName,TableName,FKName)
        SELECT DISTINCT FK.parent_object_id,S.name,T.name,FK.name
        FROM sys.foreign_keys FK
        INNER JOIN sys.tables T ON T.object_id=FK.parent_object_id
        INNER JOIN sys.schemas S ON S.schema_id=T.schema_id
        WHERE FK.is_disabled=0
          AND
          (
              EXISTS(SELECT 1 FROM #TenantTables X WHERE X.ObjectID=FK.parent_object_id)
              OR EXISTS(SELECT 1 FROM #TenantTables X WHERE X.ObjectID=FK.referenced_object_id)
              OR FK.referenced_object_id=OBJECT_ID(N'dbo.DM_CSKCB')
          );

        DECLARE @Schema SYSNAME,@Table SYSNAME,@FK SYSNAME,@Sql NVARCHAR(MAX);
        DECLARE fk_off CURSOR LOCAL FAST_FORWARD FOR
            SELECT SchemaName,TableName,FKName FROM #FkTamTat ORDER BY SchemaName,TableName,FKName;
        OPEN fk_off;
        FETCH NEXT FROM fk_off INTO @Schema,@Table,@FK;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SET @Sql=N'ALTER TABLE '+QUOTENAME(@Schema)+N'.'+QUOTENAME(@Table)+N' NOCHECK CONSTRAINT '+QUOTENAME(@FK)+N';';
            EXEC sys.sp_executesql @Sql;
            FETCH NEXT FROM fk_off INTO @Schema,@Table,@FK;
        END;
        CLOSE fk_off;
        DEALLOCATE fk_off;

        DECLARE table_delete CURSOR LOCAL FAST_FORWARD FOR
            SELECT SchemaName,TableName FROM #TenantTables ORDER BY SchemaName,TableName;
        OPEN table_delete;
        FETCH NEXT FROM table_delete INTO @Schema,@Table;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SET @Sql=N'DELETE FROM '+QUOTENAME(@Schema)+N'.'+QUOTENAME(@Table)+N' WHERE [IDCSKCB]=@IDCSKCB;';
            EXEC sys.sp_executesql @Sql,N'@IDCSKCB BIGINT',@IDCSKCB;
            FETCH NEXT FROM table_delete INTO @Schema,@Table;
        END;
        CLOSE table_delete;
        DEALLOCATE table_delete;

        UPDATE N
        SET Active=0
        FROM dbo.DM_NhanVien N
        INNER JOIN @AffectedEmployee A ON A.IDNhanVien=N.ID
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.DM_NhanVien_CSKCB M
            WHERE M.IDNhanVien=N.ID AND M.Active=1
        );

        DELETE dbo.DM_CSKCB WHERE ID=@IDCSKCB;

        DECLARE fk_on CURSOR LOCAL FAST_FORWARD FOR
            SELECT SchemaName,TableName,FKName FROM #FkTamTat ORDER BY SchemaName,TableName,FKName;
        OPEN fk_on;
        FETCH NEXT FROM fk_on INTO @Schema,@Table,@FK;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SET @Sql=N'ALTER TABLE '+QUOTENAME(@Schema)+N'.'+QUOTENAME(@Table)
                +N' WITH CHECK CHECK CONSTRAINT '+QUOTENAME(@FK)+N';';
            EXEC sys.sp_executesql @Sql;
            FETCH NEXT FROM fk_on INTO @Schema,@Table,@FK;
        END;
        CLOSE fk_on;
        DEALLOCATE fk_on;

        COMMIT;
        SELECT 200 AS Status,N'Đã xóa CSKCB; nhân viên dùng chung ở cơ sở khác được giữ nguyên.' AS Message;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 500 AS Status,ERROR_MESSAGE() AS Message;
    END CATCH
END;
GO

/* ==================== 12. CAC STO NGHIEP VU DOC TEN NHAN VIEN THEO ID TOAN HE THONG ==================== */
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kham_LichSu
    @IDCSKCB BIGINT,
    @IDBenhNhan BIGINT,
    @IDVaoVienHienTai BIGINT = NULL,
    @TuKhoa NVARCHAR(200) = NULL,
    @Trang INT = 1,
    @KichThuocTrang INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    SET @TuKhoa = NULLIF(LTRIM(RTRIM(@TuKhoa)), N'');
    SET @Trang = CASE WHEN @Trang < 1 THEN 1 ELSE @Trang END;
    SET @KichThuocTrang = CASE
        WHEN @KichThuocTrang < 10 THEN 10
        WHEN @KichThuocTrang > 100 THEN 100
        ELSE @KichThuocTrang
    END;

    SELECT
        VV.ID AS IDVaoVien,
        VV.MaVaoVien,
        VV.NgayGioVaoVien,
        VV.BatDauKhamLuc,
        VV.KetThucKhamLuc,
        VV.TrieuChung,
        VV.NgayTaiKham,
        VV.DanDo,
        NV.HoTen AS BacSiKham,
        STRING_AGG(
            (CASE WHEN CD.BanDau = 1 THEN N'[BĐ] ' ELSE N'' END) +
            (CASE WHEN CD.BenhChinh = 1 THEN N'[Chính] ' ELSE N'' END) +
            (CASE WHEN CD.BenhKhac = 1 THEN N'[#] ' ELSE N'' END) +
            CD.MaBenh + N' - ' + CD.TenBenh,
            N'; '
        ) AS ChanDoan,
        (SELECT COUNT(1)
         FROM dbo.QL_ToaThuoc_CT T
         WHERE T.IDCSKCB = VV.IDCSKCB
           AND T.IDVaoVien = VV.ID
           AND T.Active = 1) AS SoLuongThuoc,
        (SELECT COUNT(1)
         FROM dbo.QL_ChiDinh_CT C
         WHERE C.IDCSKCB = VV.IDCSKCB
           AND C.IDVaoVien = VV.ID
           AND C.Active = 1) AS SoLuongChiDinh,
        COUNT(*) OVER() AS TongSoDong
    FROM dbo.QL_VaoVien VV
    LEFT JOIN dbo.DM_NhanVien NV
      ON NV.ID = VV.IDBacSiKham
    LEFT JOIN dbo.QL_ChanDoan_CT CD
      ON CD.IDCSKCB = VV.IDCSKCB
     AND CD.IDVaoVien = VV.ID
    WHERE VV.IDCSKCB = @IDCSKCB
      AND VV.IDBenhNhan = @IDBenhNhan
      AND (VV.TrangThaiKham = 2 OR VV.Kham = 1 OR VV.KeToa = 1)
      /* Lượt hiện tại chỉ bị loại khỏi lịch sử khi nó chưa hoàn tất.
         Nếu đã Khám xong (TrangThaiKham=2), chính lượt đó cũng là một lần khám
         đã hình thành và phải xuất hiện trong lịch sử. */
      AND (@IDVaoVienHienTai IS NULL OR VV.ID <> @IDVaoVienHienTai OR VV.TrangThaiKham = 2)
      AND VV.Active = 1
      AND
      (
          @TuKhoa IS NULL
          OR NV.HoTen LIKE N'%' + @TuKhoa + N'%'
          OR VV.TrieuChung LIKE N'%' + @TuKhoa + N'%'
          OR CONVERT(NVARCHAR(10), VV.NgayGioVaoVien, 103) LIKE N'%' + @TuKhoa + N'%'
          OR EXISTS
          (
              SELECT 1
              FROM dbo.QL_ChanDoan_CT X
              WHERE X.IDCSKCB = VV.IDCSKCB
                AND X.IDVaoVien = VV.ID
                AND
                (
                    X.MaBenh LIKE N'%' + @TuKhoa + N'%'
                    OR X.TenBenh LIKE N'%' + @TuKhoa + N'%'
                )
          )
      )
    GROUP BY
        VV.ID, VV.MaVaoVien, VV.NgayGioVaoVien, VV.BatDauKhamLuc, VV.KetThucKhamLuc,
        VV.TrieuChung, VV.NgayTaiKham, VV.DanDo, NV.HoTen, VV.IDCSKCB
    ORDER BY VV.NgayGioVaoVien DESC, VV.ID DESC
    OFFSET (@Trang - 1) * @KichThuocTrang ROWS
    FETCH NEXT @KichThuocTrang ROWS ONLY;
END;
GO

DROP PROCEDURE IF EXISTS dbo.STO_QL_CLS_KetQua_ChiTiet;
GO
DROP PROCEDURE IF EXISTS dbo.STO_QL_CLS_KetQua_Luot;
GO

PRINT N'25_common_nhan_vien_nhieu_cskcb_chuc_danh.sql: OK';
GO
