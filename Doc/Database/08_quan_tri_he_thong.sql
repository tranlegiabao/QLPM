USE [QLPM];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* Vô hiệu cơ chế bắt buộc đổi mật khẩu: người dùng chỉ đổi khi chủ động yêu cầu. */
IF OBJECT_ID(N'dbo.HT_Tai_Khoan',N'U') IS NOT NULL
    UPDATE dbo.HT_Tai_Khoan
    SET Bat_Buoc_Doi_Mat_Khau=0
    WHERE Bat_Buoc_Doi_Mat_Khau<>0;
GO

/*
    21_bo_sung_quan_tri_cskcb.sql
    Quan ly tai khoan, vai tro, phan quyen va metadata chuc nang.
    Chay SAU 20_bo_sung_dang_nhap_phan_quyen.sql.
*/

/* Goi bo module Nhat ky he thong legacy khoi database main. */
IF OBJECT_ID(N'dbo.STO_HT_Nhat_Ky_Danh_Sach', N'P') IS NOT NULL
    DROP PROCEDURE dbo.STO_HT_Nhat_Ky_Danh_Sach;
IF OBJECT_ID(N'dbo.STO_HT_Nhat_Ky_Ghi', N'P') IS NOT NULL
    DROP PROCEDURE dbo.STO_HT_Nhat_Ky_Ghi;
GO

/* Xoa metadata chuc nang legacy khong con trong thiet ke hien tai. */
DELETE Q
FROM dbo.HT_Quyen_Vai_Tro Q
INNER JOIN dbo.HT_Chuc_Nang C
    ON C.IDCSKCB=Q.IDCSKCB AND C.ID=Q.ID_Chuc_Nang
WHERE C.Ma_Chuc_Nang IN (N'he_thong_nhat_ky', N'cls_cau_hinh');

DELETE FROM dbo.HT_Chuc_Nang
WHERE Ma_Chuc_Nang IN (N'he_thong_nhat_ky', N'cls_cau_hinh');

IF OBJECT_ID(N'dbo.HT_Nhat_Ky_He_Thong', N'U') IS NOT NULL
    DROP TABLE dbo.HT_Nhat_Ky_He_Thong;
GO

/* Metadata phan he/chuc nang. Day la system metadata, khong phai du lieu nghiep vu gia. */
DECLARE @Meta TABLE
(
    Ma_Phan_He NVARCHAR(100),
    Ten_Phan_He NVARCHAR(300),
    Thu_Tu_Phan_He INT,
    Ma_Chuc_Nang NVARCHAR(150),
    Ten_Chuc_Nang NVARCHAR(300),
    Duong_Dan NVARCHAR(500),
    Thu_Tu_Chuc_Nang INT
);

INSERT @Meta VALUES
(N'quan_ly', N'Quản lý', 1, N'tiep_nhan', N'Thông tin hành chính / Tiếp nhận', N'/tiep_nhan', 1),
(N'quan_ly', N'Quản lý', 1, N'kham_benh', N'Khám bệnh', N'/kham_benh', 2),
(N'quan_ly', N'Quản lý', 1, N'phac_do', N'Quản lý phác đồ', N'/phac_do', 3),
(N'quan_ly', N'Quản lý', 1, N'thu_ngan', N'Thu ngân', N'/thu_ngan', 5),
(N'quan_ly', N'Quản lý', 1, N'kho', N'Quản lý kho', N'/kho/quan-ly', 6),
(N'quan_ly', N'Quản lý', 1, N'kho_cap_phat', N'Cấp phát thuốc', N'/kho', 7),
(N'danh_muc', N'Danh mục', 2, N'danh_muc', N'Danh mục dùng chung', N'/he_thong?tab=danh_muc', 1),
(N'he_thong', N'Hệ thống', 3, N'he_thong_nhan_vien', N'Nhân viên', N'/he_thong?tab=nhan_vien', 1),
(N'he_thong', N'Hệ thống', 3, N'he_thong_tai_khoan', N'Tài khoản', N'/he_thong?tab=tai_khoan', 2),
(N'he_thong', N'Hệ thống', 3, N'he_thong_vai_tro', N'Vai trò', N'/he_thong?tab=vai_tro', 3),
(N'he_thong', N'Hệ thống', 3, N'he_thong_phan_quyen', N'Phân quyền', N'/he_thong?tab=phan_quyen', 4);

DECLARE @IDCSKCB BIGINT;
DECLARE cs CURSOR LOCAL FAST_FORWARD FOR SELECT ID FROM dbo.DM_CSKCB WHERE Active = 1;
OPEN cs;
FETCH NEXT FROM cs INTO @IDCSKCB;
WHILE @@FETCH_STATUS = 0
BEGIN
    INSERT dbo.HT_Phan_He(IDCSKCB, Ma_Phan_He, Ten_Phan_He, Thu_Tu, Active)
    SELECT DISTINCT @IDCSKCB, M.Ma_Phan_He, M.Ten_Phan_He, M.Thu_Tu_Phan_He, 1
    FROM @Meta M
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.HT_Phan_He X
        WHERE X.IDCSKCB = @IDCSKCB AND X.Ma_Phan_He = M.Ma_Phan_He
    );

    INSERT dbo.HT_Chuc_Nang(IDCSKCB, ID_Phan_He, Ma_Chuc_Nang, Ten_Chuc_Nang, Duong_Dan, Thu_Tu, Active)
    SELECT @IDCSKCB, P.ID, M.Ma_Chuc_Nang, M.Ten_Chuc_Nang, M.Duong_Dan, M.Thu_Tu_Chuc_Nang, 1
    FROM @Meta M
    INNER JOIN dbo.HT_Phan_He P
        ON P.IDCSKCB = @IDCSKCB AND P.Ma_Phan_He = M.Ma_Phan_He
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.HT_Chuc_Nang X
        WHERE X.IDCSKCB = @IDCSKCB AND X.Ma_Chuc_Nang = M.Ma_Chuc_Nang
    );

    /* Role quan_tri_cskcb la superuser trong CSKCB: bo sung va khoi phuc day du quyen. */
    INSERT dbo.HT_Quyen_Vai_Tro(IDCSKCB, ID_Vai_Tro, ID_Chuc_Nang, Xem, Them, Sua, Xoa, Xuat, Ca_Nhan)
    SELECT @IDCSKCB, VT.ID, CN.ID, 1,1,1,1,1,1
    FROM dbo.DM_Vai_Tro VT
    CROSS JOIN dbo.HT_Chuc_Nang CN
    WHERE VT.IDCSKCB = @IDCSKCB
      AND VT.Ma_Vai_Tro = N'quan_tri_cskcb'
      AND VT.Active = 1
      AND CN.IDCSKCB = @IDCSKCB
      AND CN.Active = 1
      AND NOT EXISTS
      (
          SELECT 1 FROM dbo.HT_Quyen_Vai_Tro Q
          WHERE Q.IDCSKCB = @IDCSKCB
            AND Q.ID_Vai_Tro = VT.ID
            AND Q.ID_Chuc_Nang = CN.ID
      );

    UPDATE Q
    SET Xem=1, Them=1, Sua=1, Xoa=1, Xuat=1, Ca_Nhan=1
    FROM dbo.HT_Quyen_Vai_Tro Q
    INNER JOIN dbo.DM_Vai_Tro VT
      ON VT.IDCSKCB=Q.IDCSKCB
     AND VT.ID=Q.ID_Vai_Tro
     AND VT.Ma_Vai_Tro=N'quan_tri_cskcb'
     AND VT.Active=1
    INNER JOIN dbo.HT_Chuc_Nang CN
      ON CN.IDCSKCB=Q.IDCSKCB
     AND CN.ID=Q.ID_Chuc_Nang
     AND CN.Active=1
    WHERE Q.IDCSKCB=@IDCSKCB;

    FETCH NEXT FROM cs INTO @IDCSKCB;
END;
CLOSE cs;
DEALLOCATE cs;
GO

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

CREATE OR ALTER PROCEDURE dbo.STO_HT_Tai_Khoan_Doi_Trang_Thai
    @IDCSKCB BIGINT,
    @ID_Tai_Khoan BIGINT,
    @Active BIT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.HT_Tai_Khoan
    SET Active=@Active,
        Khoa_Den_Luc=CASE WHEN @Active=1 THEN NULL ELSE Khoa_Den_Luc END,
        Ngay_Cap_Nhat=SYSDATETIME()
    WHERE IDCSKCB=@IDCSKCB AND ID=@ID_Tai_Khoan;

    IF @@ROWCOUNT=0 SELECT 404 AS Status, N'Không tìm thấy tài khoản.' AS Message;
    ELSE SELECT 200 AS Status, CASE WHEN @Active=1 THEN N'Đã mở tài khoản.' ELSE N'Đã khóa tài khoản.' END AS Message;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_Tai_Khoan_Lay_Theo_ID
    @IDCSKCB BIGINT,
    @ID_Tai_Khoan BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1 ID AS ID_Tai_Khoan,Ten_Dang_Nhap
    FROM dbo.HT_Tai_Khoan
    WHERE IDCSKCB=@IDCSKCB AND ID=@ID_Tai_Khoan;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_Tai_Khoan_Xoa
    @IDCSKCB BIGINT,
    @ID_Tai_Khoan BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS(SELECT 1 FROM dbo.HT_Tai_Khoan WHERE IDCSKCB=@IDCSKCB AND ID=@ID_Tai_Khoan)
    BEGIN
        SELECT 404 AS Status,N'Không tìm thấy tài khoản.' AS Message;
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRAN;
        DELETE dbo.HT_Tai_Khoan_Vai_Tro
        WHERE IDCSKCB=@IDCSKCB AND ID_Tai_Khoan=@ID_Tai_Khoan;

        DELETE dbo.HT_Tai_Khoan
        WHERE IDCSKCB=@IDCSKCB AND ID=@ID_Tai_Khoan;
        COMMIT;

        SELECT 200 AS Status,N'Xóa tài khoản thành công.' AS Message;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        IF ERROR_NUMBER()=547
            SELECT 409 AS Status,N'Tài khoản còn dữ liệu liên quan nên chưa thể xóa.' AS Message;
        ELSE
            SELECT 500 AS Status,ERROR_MESSAGE() AS Message;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_Tai_Khoan_Reset_Mat_Khau
    @IDCSKCB BIGINT,
    @ID_Tai_Khoan BIGINT,
    @Mat_Khau_Hash NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.HT_Tai_Khoan
    SET Mat_Khau_Hash=@Mat_Khau_Hash,
        Bat_Buoc_Doi_Mat_Khau=0,
        So_Lan_Dang_Nhap_Sai=0,
        Khoa_Den_Luc=NULL,
        Ngay_Cap_Nhat=SYSDATETIME()
    WHERE IDCSKCB=@IDCSKCB AND ID=@ID_Tai_Khoan;

    IF @@ROWCOUNT=0 SELECT 404 AS Status, N'Không tìm thấy tài khoản.' AS Message;
    ELSE SELECT 200 AS Status, N'Đã đặt lại mật khẩu về mặc định: a' AS Message;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_Doi_Mat_Khau
    @ID_Tai_Khoan BIGINT,
    @Mat_Khau_Hash NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.HT_Tai_Khoan
    SET Mat_Khau_Hash=@Mat_Khau_Hash,
        Bat_Buoc_Doi_Mat_Khau=0,
        Ngay_Cap_Nhat=SYSDATETIME()
    WHERE ID=@ID_Tai_Khoan AND Active=1;

    IF @@ROWCOUNT=0 SELECT 404 AS Status, N'Không tìm thấy tài khoản đang hoạt động.' AS Message;
    ELSE SELECT 200 AS Status, N'Đổi mật khẩu thành công.' AS Message;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_Vai_Tro_Danh_Sach
    @IDCSKCB BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ID AS ID_Vai_Tro,Ma_Vai_Tro,Ten_Vai_Tro,Mo_Ta,Active,Ngay_Tao,Ngay_Cap_Nhat
    FROM dbo.DM_Vai_Tro
    WHERE IDCSKCB=@IDCSKCB
    ORDER BY Active DESC,Ten_Vai_Tro;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_Vai_Tro_Luu
    @IDCSKCB BIGINT,
    @ID_Vai_Tro BIGINT = NULL,
    @Ma_Vai_Tro NVARCHAR(100),
    @Ten_Vai_Tro NVARCHAR(300),
    @Mo_Ta NVARCHAR(1000) = NULL,
    @Active BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @Ma_Vai_Tro=LTRIM(RTRIM(@Ma_Vai_Tro));
        SET @Ten_Vai_Tro=LTRIM(RTRIM(@Ten_Vai_Tro));
        IF @Ma_Vai_Tro=N'' OR @Ten_Vai_Tro=N'' THROW 51000,N'Mã và tên vai trò là bắt buộc.',1;

        IF EXISTS(SELECT 1 FROM dbo.DM_Vai_Tro WHERE IDCSKCB=@IDCSKCB AND Ma_Vai_Tro=@Ma_Vai_Tro AND (@ID_Vai_Tro IS NULL OR ID<>@ID_Vai_Tro))
            THROW 51000,N'Mã vai trò đã tồn tại.',1;

        IF @ID_Vai_Tro IS NULL OR @ID_Vai_Tro=0
        BEGIN
            INSERT dbo.DM_Vai_Tro(IDCSKCB,Ma_Vai_Tro,Ten_Vai_Tro,Mo_Ta,Active)
            VALUES(@IDCSKCB,@Ma_Vai_Tro,@Ten_Vai_Tro,@Mo_Ta,@Active);
            SET @ID_Vai_Tro=SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE dbo.DM_Vai_Tro
            SET Ma_Vai_Tro=@Ma_Vai_Tro,Ten_Vai_Tro=@Ten_Vai_Tro,Mo_Ta=@Mo_Ta,Active=@Active,Ngay_Cap_Nhat=SYSDATETIME()
            WHERE IDCSKCB=@IDCSKCB AND ID=@ID_Vai_Tro;
        END
        SELECT 200 AS Status,N'Lưu vai trò thành công.' AS Message,@ID_Vai_Tro AS ID_Vai_Tro;
    END TRY
    BEGIN CATCH
        SELECT 400 AS Status,ERROR_MESSAGE() AS Message,@ID_Vai_Tro AS ID_Vai_Tro;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_Vai_Tro_Xoa
    @IDCSKCB BIGINT,
    @ID_Vai_Tro BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @MaVaiTro NVARCHAR(100)=
    (
        SELECT Ma_Vai_Tro FROM dbo.DM_Vai_Tro
        WHERE IDCSKCB=@IDCSKCB AND ID=@ID_Vai_Tro
    );

    IF @MaVaiTro IS NULL
    BEGIN
        SELECT 404 AS Status,N'Không tìm thấy vai trò.' AS Message;
        RETURN;
    END;

    IF @MaVaiTro=N'quan_tri_cskcb'
    BEGIN
        SELECT 409 AS Status,N'Không được xóa vai trò quản trị cơ sở KCB.' AS Message;
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRAN;

        DELETE dbo.HT_Tai_Khoan_Vai_Tro
        WHERE IDCSKCB=@IDCSKCB AND ID_Vai_Tro=@ID_Vai_Tro;

        DELETE dbo.HT_Quyen_Vai_Tro
        WHERE IDCSKCB=@IDCSKCB AND ID_Vai_Tro=@ID_Vai_Tro;

        DELETE dbo.DM_Vai_Tro
        WHERE IDCSKCB=@IDCSKCB AND ID=@ID_Vai_Tro;

        COMMIT;
        SELECT 200 AS Status,N'Đã xóa hoàn toàn vai trò và gỡ khỏi mọi tài khoản.' AS Message;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 500 AS Status,ERROR_MESSAGE() AS Message;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_Quyen_Vai_Tro_Lay
    @IDCSKCB BIGINT,
    @ID_Vai_Tro BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        P.ID AS ID_Phan_He,P.Ma_Phan_He,P.Ten_Phan_He,P.Thu_Tu AS Thu_Tu_Phan_He,
        C.ID AS ID_Chuc_Nang,C.Ma_Chuc_Nang,C.Ten_Chuc_Nang,C.Duong_Dan,C.Thu_Tu AS Thu_Tu_Chuc_Nang,
        ISNULL(Q.Xem,0) AS Xem,ISNULL(Q.Them,0) AS Them,ISNULL(Q.Sua,0) AS Sua,
        ISNULL(Q.Xoa,0) AS Xoa,ISNULL(Q.Xuat,0) AS Xuat,ISNULL(Q.Ca_Nhan,0) AS Ca_Nhan
    FROM dbo.HT_Phan_He P
    INNER JOIN dbo.HT_Chuc_Nang C ON C.IDCSKCB=P.IDCSKCB AND C.ID_Phan_He=P.ID AND C.Active=1
    LEFT JOIN dbo.HT_Quyen_Vai_Tro Q ON Q.IDCSKCB=C.IDCSKCB AND Q.ID_Vai_Tro=@ID_Vai_Tro AND Q.ID_Chuc_Nang=C.ID
    WHERE P.IDCSKCB=@IDCSKCB AND P.Active=1
    ORDER BY P.Thu_Tu,P.ID,C.Thu_Tu,C.ID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_Quyen_Vai_Tro_Luu
    @IDCSKCB BIGINT,
    @ID_Vai_Tro BIGINT,
    @Quyen_Json NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS(SELECT 1 FROM dbo.DM_Vai_Tro WHERE IDCSKCB=@IDCSKCB AND ID=@ID_Vai_Tro AND Active=1)
            THROW 51000,N'Vai trò không tồn tại hoặc đã ngừng hoạt động.',1;

        DELETE dbo.HT_Quyen_Vai_Tro
        WHERE IDCSKCB=@IDCSKCB AND ID_Vai_Tro=@ID_Vai_Tro;

        INSERT dbo.HT_Quyen_Vai_Tro(IDCSKCB,ID_Vai_Tro,ID_Chuc_Nang,Xem,Them,Sua,Xoa,Xuat,Ca_Nhan)
        SELECT
            @IDCSKCB,@ID_Vai_Tro,J.ID_Chuc_Nang,J.Xem,J.Them,J.Sua,J.Xoa,J.Xuat,J.Ca_Nhan
        FROM OPENJSON(ISNULL(@Quyen_Json,N'[]'))
        WITH
        (
            ID_Chuc_Nang BIGINT '$.id_chuc_nang',
            Xem BIT '$.xem',Them BIT '$.them',Sua BIT '$.sua',Xoa BIT '$.xoa',Xuat BIT '$.xuat',Ca_Nhan BIT '$.ca_nhan'
        ) J
        INNER JOIN dbo.HT_Chuc_Nang C ON C.IDCSKCB=@IDCSKCB AND C.ID=J.ID_Chuc_Nang AND C.Active=1;

        COMMIT;
        SELECT 200 AS Status,N'Lưu phân quyền thành công.' AS Message;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SELECT 400 AS Status,ERROR_MESSAGE() AS Message;
    END CATCH
END;
GO

SELECT N'08_quan_tri_cskcb.sql hoàn tất.' AS Message;
GO
