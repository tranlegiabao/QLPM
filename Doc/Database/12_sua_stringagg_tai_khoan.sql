/*
=====================================================================
31. SUA LOI STO_HT_Tai_Khoan_Danh_Sach - SQL ERROR 8711
- SQL Server bao:
  Multiple ordered aggregate functions in the same scope have mutually
  incompatible orderings.
- Chi can sap xep chuoi ten vai tro; danh sach ID chi dung de set value
  tren UI nen khong can WITHIN GROUP.
=====================================================================
*/
USE [QLPM];
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

SELECT N'31_sua_loi_string_agg_tai_khoan.sql hoàn tất.' AS Message;
GO
