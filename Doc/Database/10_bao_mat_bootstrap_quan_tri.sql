USE [QLPM];
GO
SET NOCOUNT ON;
GO

/*
    26_bao_mat_bootstrap_quan_tri.sql
    Khong cho API khoi_tao_quan_tri vo danh sach nhan vien cua CSKCB da co tai khoan.
*/

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

SELECT N'26_bao_mat_bootstrap_quan_tri.sql hoàn tất.' AS Message;
GO
