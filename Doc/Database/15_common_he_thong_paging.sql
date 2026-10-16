/*
15_common_he_thong_paging.sql

Server-side paging cho cac bang danh sach quan tri common.
Lookup/dropdown nho goi cung STO voi page size gioi han, khong dung load-all.
*/
USE [QLPM];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

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

CREATE OR ALTER PROCEDURE dbo.STO_HT_Vai_Tro_Danh_Sach
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
        SELECT V.ID AS ID_Vai_Tro,V.IDCSKCB,C.MaCSKCB,C.TenCSKCB,V.Ma_Vai_Tro,V.Ten_Vai_Tro,V.Mo_Ta,V.Active,V.Ngay_Tao,V.Ngay_Cap_Nhat
        FROM dbo.DM_Vai_Tro V
        INNER JOIN dbo.DM_CSKCB C ON C.ID=V.IDCSKCB
        WHERE (@IDCSKCB IS NULL OR V.IDCSKCB=@IDCSKCB)
          AND
          (
              @TuKhoa IS NULL
              OR V.Ma_Vai_Tro LIKE N'%'+@TuKhoa+N'%'
              OR V.Ten_Vai_Tro LIKE N'%'+@TuKhoa+N'%'
              OR V.Mo_Ta LIKE N'%'+@TuKhoa+N'%'
              OR C.MaCSKCB LIKE N'%'+@TuKhoa+N'%'
              OR C.TenCSKCB LIKE N'%'+@TuKhoa+N'%'
          )
    )
    SELECT D.*,COUNT(*) OVER() AS TongSoDong
    FROM D
    ORDER BY D.Active DESC,D.Ten_Vai_Tro,D.ID_Vai_Tro
    OFFSET (@Trang-1)*@KichThuocTrang ROWS
    FETCH NEXT @KichThuocTrang ROWS ONLY;
END;
GO

PRINT N'15_common_he_thong_paging.sql: OK';
GO
