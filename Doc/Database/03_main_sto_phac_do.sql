/* Canonical STO contract for phac do cua nhanh main. */

USE [QLPM];

GO

SET ANSI_NULLS ON;

SET QUOTED_IDENTIFIER ON;

GO

SET NOCOUNT ON;

SET XACT_ABORT ON;

GO

CREATE OR ALTER PROCEDURE dbo.STO_DM_PhacDo_DanhSach
    @IDCSKCB BIGINT,
    @TuKhoa NVARCHAR(200) = NULL,
    @Trang INT = 1,
    @KichThuocTrang INT = 25
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

    ;WITH D AS
    (
        SELECT
            P.ID,
            P.MaPhacDo,
            P.TenPhacDo,
            CD.IDICD10,
            CD.MaBenh AS MaICD10,
            CD.TenBenh AS TenICD10,
            P.TrieuChung,
            P.Active,
            (SELECT COUNT(*) FROM dbo.DM_PhacDo_ChiDinh X WHERE X.IDCSKCB=P.IDCSKCB AND X.IDPhacDo=P.ID AND X.Active=1) AS SoLuongChiDinh,
            (SELECT COUNT(*) FROM dbo.DM_PhacDo_Thuoc X WHERE X.IDCSKCB=P.IDCSKCB AND X.IDPhacDo=P.ID AND X.Active=1) AS SoLuongThuoc
        FROM dbo.DM_PhacDo P
        OUTER APPLY
        (
            SELECT TOP(1) C.IDICD10,I.MaBenh,I.TenBenh
            FROM dbo.DM_PhacDo_ChanDoan C
            INNER JOIN dbo.DM_ICD10 I
              ON I.IDCSKCB=C.IDCSKCB AND I.ID=C.IDICD10
            WHERE C.IDCSKCB=P.IDCSKCB AND C.IDPhacDo=P.ID AND C.Active=1
            ORDER BY
                CASE WHEN C.BenhChinh=1 THEN 0 WHEN C.BanDau=1 THEN 1 ELSE 2 END,
                ISNULL(C.ThuTu,2147483647),C.ID
        ) CD
        WHERE P.IDCSKCB=@IDCSKCB
          AND P.Active=1
          AND
          (
              @TuKhoa IS NULL
              OR P.MaPhacDo LIKE N'%' + @TuKhoa + N'%'
              OR P.TenPhacDo LIKE N'%' + @TuKhoa + N'%'
              OR CD.MaBenh LIKE N'%' + @TuKhoa + N'%'
              OR CD.TenBenh LIKE N'%' + @TuKhoa + N'%'
          )
    )
    SELECT D.*,COUNT(*) OVER() AS TongSoDong
    FROM D
    ORDER BY D.MaPhacDo,D.TenPhacDo,D.ID
    OFFSET (@Trang-1)*@KichThuocTrang ROWS
    FETCH NEXT @KichThuocTrang ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_DM_PhacDo_ChiTiet
    @IDCSKCB BIGINT,
    @ID BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    -- Result set 1: Thông tin phác đồ. Chẩn đoán nằm duy nhất ở result set 4.
    SELECT P.ID,
           P.MaPhacDo,
           P.TenPhacDo,
           P.TrieuChung,
           P.Active
    FROM dbo.DM_PhacDo P
    WHERE P.IDCSKCB = @IDCSKCB AND P.ID = @ID;

    -- Result set 2: Chi định CLS mẫu
    SELECT C.ID,
           C.IDDichVu,
           D.MaDichVu,
           D.TenDichVu,
           C.SoLuong,
           COALESCE(C.DonGia, D.DonGia) AS DonGia,
           C.GuiNgoai,
           C.NoiGuiNgoai,
           C.GhiChu
    FROM dbo.DM_PhacDo_ChiDinh C
    JOIN dbo.DM_DichVu D ON D.IDCSKCB = C.IDCSKCB AND D.ID = C.IDDichVu
    WHERE C.IDCSKCB = @IDCSKCB AND C.IDPhacDo = @ID AND C.Active = 1
    ORDER BY C.ThuTu, C.ID;

    -- Result set 3: Đơn thuốc mẫu
    SELECT T.ID,
           T.IDThuoc,
           D.MaThuoc,
           D.TenThuoc,
           D.HoatChat,
           G.MaLoaiToaThuoc,
           COALESCE(DVT.TenDVT,D.DonViTinh) AS DonViTinh,
           T.IDDonViTinhDung,
           COALESCE(DVTD.TenDVT,DVT.TenDVT,D.DonViTinh) AS DonViTinhDung,
           T.SoNgay,
           T.Sang,
           T.Trua,
           T.Chieu,
           T.Toi,
           T.LieuDung,
           T.DuongDung,
           T.CachDung,
           T.SoLuong,
           COALESCE(T.DonGia, D.GiaBan) AS DonGia,
           T.ThuTu
    FROM dbo.DM_PhacDo_Thuoc T
    JOIN dbo.DM_Thuoc D ON D.IDCSKCB = T.IDCSKCB AND D.ID = T.IDThuoc
    LEFT JOIN dbo.DM_NhomHang G ON G.IDCSKCB=D.IDCSKCB AND G.ID=D.IDNhomHang AND G.Active=1
    LEFT JOIN dbo.DM_DonViTinh DVT ON DVT.IDCSKCB=D.IDCSKCB AND DVT.ID=D.IDDonViTinh
    LEFT JOIN dbo.DM_DonViTinh DVTD ON DVTD.IDCSKCB=T.IDCSKCB AND DVTD.ID=T.IDDonViTinhDung
    WHERE T.IDCSKCB = @IDCSKCB AND T.IDPhacDo = @ID AND T.Active = 1
    ORDER BY T.ThuTu, T.ID;

    -- Result set 4: Danh sách chẩn đoán ICD-10 mẫu
    SELECT C.ID,
           C.IDICD10,
           I.MaBenh,
           I.TenBenh,
           C.BanDau,
           C.BenhChinh,
           C.BenhKhac,
           C.ThuTu
    FROM dbo.DM_PhacDo_ChanDoan C
    JOIN dbo.DM_ICD10 I ON I.IDCSKCB = C.IDCSKCB AND I.ID = C.IDICD10
    WHERE C.IDCSKCB = @IDCSKCB
      AND C.IDPhacDo = @ID
      AND C.Active = 1
    ORDER BY ISNULL(C.ThuTu, 2147483647), C.ID;
END;

GO

CREATE OR ALTER PROCEDURE dbo.STO_DM_PhacDo_Luu
    @IDCSKCB BIGINT,
    @ID BIGINT = NULL OUTPUT,
    @MaPhacDo NVARCHAR(30),
    @TenPhacDo NVARCHAR(300),
    @TrieuChung NVARCHAR(2000) = NULL,
    @ChanDoanJson NVARCHAR(MAX) = N'[]',
    @ChiDinhJson NVARCHAR(MAX) = N'[]',
    @ThuocJson NVARCHAR(MAX) = N'[]'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        SET @MaPhacDo = NULLIF(LTRIM(RTRIM(@MaPhacDo)), N'');
        SET @TenPhacDo = NULLIF(LTRIM(RTRIM(@TenPhacDo)), N'');

        DECLARE @CD TABLE
        (
            IDICD10 BIGINT NOT NULL PRIMARY KEY,
            BanDau BIT NOT NULL,
            BenhChinh BIT NOT NULL,
            BenhKhac BIT NOT NULL,
            ThuTu INT NULL
        );

        IF ISJSON(@ChanDoanJson) = 1
        BEGIN
            INSERT @CD(IDICD10, BanDau, BenhChinh, BenhKhac, ThuTu)
            SELECT IDICD10,
                   ISNULL(BanDau, 0),
                   ISNULL(BenhChinh, 0),
                   ISNULL(BenhKhac, 0),
                   ThuTu
            FROM OPENJSON(@ChanDoanJson) WITH
            (
                IDICD10 BIGINT '$.IDICD10',
                BanDau BIT '$.BanDau',
                BenhChinh BIT '$.BenhChinh',
                BenhKhac BIT '$.BenhKhac',
                ThuTu INT '$.ThuTu'
            )
            WHERE IDICD10 IS NOT NULL;
        END;

        IF (SELECT COUNT(*) FROM @CD) > 12
        BEGIN
            ROLLBACK;
            SELECT 400 AS Status, N'Mỗi phác đồ chỉ được tối đa 12 chẩn đoán ICD-10.' AS Message, @ID AS ID;
            RETURN;
        END;

        IF (SELECT COUNT(*) FROM @CD WHERE BenhChinh = 1) <> 1
        BEGIN
            ROLLBACK;
            SELECT 400 AS Status, N'Phác đồ bắt buộc phải có đúng 1 bệnh chính.' AS Message, @ID AS ID;
            RETURN;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM @CD C
            LEFT JOIN dbo.DM_ICD10 I
              ON I.IDCSKCB = @IDCSKCB
             AND I.ID = C.IDICD10
             AND I.Active = 1
            WHERE I.ID IS NULL
        )
        BEGIN
            ROLLBACK;
            SELECT 400 AS Status, N'Có mã ICD-10 không hợp lệ.' AS Message, @ID AS ID;
            RETURN;
        END;

        IF @MaPhacDo IS NULL OR @TenPhacDo IS NULL
        BEGIN
            ROLLBACK;
            SELECT 400 AS Status, N'Mã và tên phác đồ là bắt buộc.' AS Message, @ID AS ID;
            RETURN;
        END;

        IF @ID IS NULL OR @ID <= 0
        BEGIN
            DECLARE @IDPhacDoTrung BIGINT,@ActivePhacDoTrung BIT;

            SELECT TOP(1)
                   @IDPhacDoTrung=ID,
                   @ActivePhacDoTrung=Active
            FROM dbo.DM_PhacDo WITH(UPDLOCK,HOLDLOCK)
            WHERE IDCSKCB=@IDCSKCB AND MaPhacDo=@MaPhacDo;

            IF @IDPhacDoTrung IS NOT NULL AND ISNULL(@ActivePhacDoTrung,0)=1
            BEGIN
                ROLLBACK;
                SELECT 409 AS Status, N'Mã phác đồ đã tồn tại.' AS Message, @ID AS ID;
                RETURN;
            END;

            IF @IDPhacDoTrung IS NOT NULL
            BEGIN
                SET @ID=@IDPhacDoTrung;
                UPDATE dbo.DM_PhacDo
                SET TenPhacDo=@TenPhacDo,
                    TrieuChung=@TrieuChung,
                    Active=1
                WHERE IDCSKCB=@IDCSKCB AND ID=@ID;
            END
            ELSE
            BEGIN
                INSERT dbo.DM_PhacDo(IDCSKCB, MaPhacDo, TenPhacDo, TrieuChung, Active)
                VALUES(@IDCSKCB, @MaPhacDo, @TenPhacDo, @TrieuChung, 1);
                SET @ID = SCOPE_IDENTITY();
            END;
        END
        ELSE
        BEGIN
            IF EXISTS
            (
                SELECT 1
                FROM dbo.DM_PhacDo WITH(UPDLOCK,HOLDLOCK)
                WHERE IDCSKCB=@IDCSKCB
                  AND MaPhacDo=@MaPhacDo
                  AND ID<>@ID
            )
            BEGIN
                ROLLBACK;
                SELECT 409 AS Status, N'Mã phác đồ đã tồn tại ở một phác đồ khác.' AS Message, @ID AS ID;
                RETURN;
            END;

            UPDATE dbo.DM_PhacDo
            SET MaPhacDo = @MaPhacDo,
                TenPhacDo = @TenPhacDo,
                TrieuChung = @TrieuChung,
                Active = 1
            WHERE IDCSKCB = @IDCSKCB AND ID = @ID;
        END;

        -- Lưu danh sách chẩn đoán ICD-10 mẫu
        DELETE FROM dbo.DM_PhacDo_ChanDoan
        WHERE IDCSKCB = @IDCSKCB AND IDPhacDo = @ID;

        INSERT dbo.DM_PhacDo_ChanDoan
        (
            IDCSKCB, IDPhacDo, IDICD10,
            BanDau, BenhChinh, BenhKhac,
            ThuTu, Active
        )
        SELECT @IDCSKCB, @ID, C.IDICD10,
               C.BanDau, C.BenhChinh, C.BenhKhac,
               C.ThuTu, 1
        FROM @CD C;

        -- Lưu Chỉ định CLS mẫu
        DELETE FROM dbo.DM_PhacDo_ChiDinh WHERE IDCSKCB = @IDCSKCB AND IDPhacDo = @ID;

        IF ISJSON(@ChiDinhJson) = 1
        BEGIN
            INSERT dbo.DM_PhacDo_ChiDinh(IDCSKCB, IDPhacDo, IDDichVu, SoLuong, DonGia, GuiNgoai, NoiGuiNgoai, GhiChu, ThuTu, Active)
            SELECT @IDCSKCB, @ID, D.ID, ISNULL(NULLIF(J.SoLuong, 0), 1), COALESCE(J.DonGia, D.DonGia), ISNULL(J.GuiNgoai, 0), J.NoiGuiNgoai, J.GhiChu, J.ThuTu, 1
            FROM OPENJSON(@ChiDinhJson) WITH
            (
                IDDichVu BIGINT '$.IDDichVu',
                SoLuong DECIMAL(10,2) '$.SoLuong',
                DonGia DECIMAL(18,2) '$.DonGia',
                GuiNgoai BIT '$.GuiNgoai',
                NoiGuiNgoai NVARCHAR(300) '$.NoiGuiNgoai',
                GhiChu NVARCHAR(500) '$.GhiChu',
                ThuTu INT '$.ThuTu'
            ) J
            JOIN dbo.DM_DichVu D ON D.IDCSKCB = @IDCSKCB AND D.ID = J.IDDichVu AND D.Active = 1;
        END;

        -- Lưu Đơn thuốc mẫu
        DELETE FROM dbo.DM_PhacDo_Thuoc WHERE IDCSKCB = @IDCSKCB AND IDPhacDo = @ID;

        IF ISJSON(@ThuocJson) = 1
        BEGIN
            INSERT dbo.DM_PhacDo_Thuoc
            (
                IDCSKCB, IDPhacDo, IDThuoc, IDDonViTinhDung,
                SoNgay, Sang, Trua, Chieu, Toi, LieuDung, DuongDung, CachDung,
                SoLuong, DonGia, ThuTu, Active
            )
            SELECT @IDCSKCB, @ID, D.ID, COALESCE(DVTD.ID,D.IDDonViTinh),
                   ISNULL(NULLIF(J.SoNgay, 0), 3), J.Sang, J.Trua, J.Chieu, J.Toi, J.LieuDung, J.DuongDung, J.CachDung,
                   ISNULL(NULLIF(J.SoLuong, 0), 1), COALESCE(J.DonGia, D.GiaBan), J.ThuTu, 1
            FROM OPENJSON(@ThuocJson) WITH
            (
                IDThuoc BIGINT '$.IDThuoc',
                IDDonViTinhDung BIGINT '$.IDDonViTinhDung',
                SoNgay INT '$.SoNgay',
                Sang NVARCHAR(50) '$.Sang',
                Trua NVARCHAR(50) '$.Trua',
                Chieu NVARCHAR(50) '$.Chieu',
                Toi NVARCHAR(50) '$.Toi',
                LieuDung NVARCHAR(300) '$.LieuDung',
                DuongDung NVARCHAR(100) '$.DuongDung',
                CachDung NVARCHAR(500) '$.CachDung',
                SoLuong DECIMAL(10,2) '$.SoLuong',
                DonGia DECIMAL(18,2) '$.DonGia',
                ThuTu INT '$.ThuTu'
            ) J
            JOIN dbo.DM_Thuoc D ON D.IDCSKCB = @IDCSKCB AND D.ID = J.IDThuoc AND D.Active = 1
            LEFT JOIN dbo.DM_DonViTinh DVTD
              ON DVTD.IDCSKCB=@IDCSKCB
             AND DVTD.ID=J.IDDonViTinhDung
             AND DVTD.Active=1;
        END;

        COMMIT;
        SELECT 200 AS Status, N'Lưu phác đồ thành công.' AS Message, @ID AS ID;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        SELECT 500 AS Status, ERROR_MESSAGE() AS Message, @ID AS ID;
    END CATCH
END;

GO

CREATE OR ALTER PROCEDURE dbo.STO_DM_PhacDo_Xoa
    @IDCSKCB BIGINT,
    @ID BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.DM_PhacDo SET Active = 0 WHERE IDCSKCB = @IDCSKCB AND ID = @ID;
    SELECT CASE WHEN @@ROWCOUNT > 0 THEN 200 ELSE 404 END AS Status,
           CASE WHEN @@ROWCOUNT > 0 THEN N'Xóa phác đồ thành công.' ELSE N'Không tìm thấy phác đồ.' END AS Message;
END;

GO

PRINT N'03_main_sto_phac_do.sql: OK';

GO
