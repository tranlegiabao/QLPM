USE [QLPM];
GO
SET NOCOUNT ON;
GO

/*
    25_bo_sung_tai_lai_quyen_phien.sql
    Chay SAU 21_bo_sung_quan_tri_he_thong.sql.
    Dung de cookie auth tai lai quyen va khoa session ngay khi account/NV/CSKCB bi khoa.
*/

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

/*
    Bo sung dieu kien account active vao STO lay quyen.
    Account bi khoa se khong con role/quyen o request ke tiep.
*/
CREATE OR ALTER PROCEDURE dbo.STO_HT_Lay_Quyen_Tai_Khoan
    @ID_Tai_Khoan BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT
        VT.ID AS ID_Vai_Tro,
        VT.Ma_Vai_Tro,
        VT.Ten_Vai_Tro
    FROM dbo.HT_Tai_Khoan T
    INNER JOIN dbo.HT_Tai_Khoan_Vai_Tro TV
        ON TV.IDCSKCB = T.IDCSKCB
       AND TV.ID_Tai_Khoan = T.ID
       AND TV.Active = 1
    INNER JOIN dbo.DM_Vai_Tro VT
        ON VT.IDCSKCB = TV.IDCSKCB
       AND VT.ID = TV.ID_Vai_Tro
       AND VT.Active = 1
    WHERE T.ID = @ID_Tai_Khoan
      AND T.Active = 1;

    SELECT
        CN.Ma_Chuc_Nang,
        MAX(CONVERT(INT, Q.Xem)) AS Xem,
        MAX(CONVERT(INT, Q.Them)) AS Them,
        MAX(CONVERT(INT, Q.Sua)) AS Sua,
        MAX(CONVERT(INT, Q.Xoa)) AS Xoa,
        MAX(CONVERT(INT, Q.Xuat)) AS Xuat,
        MAX(CONVERT(INT, Q.Ca_Nhan)) AS CaNhan
    FROM dbo.HT_Tai_Khoan T
    INNER JOIN dbo.HT_Tai_Khoan_Vai_Tro TV
        ON TV.IDCSKCB = T.IDCSKCB
       AND TV.ID_Tai_Khoan = T.ID
       AND TV.Active = 1
    INNER JOIN dbo.HT_Quyen_Vai_Tro Q
        ON Q.IDCSKCB = TV.IDCSKCB
       AND Q.ID_Vai_Tro = TV.ID_Vai_Tro
    INNER JOIN dbo.HT_Chuc_Nang CN
        ON CN.IDCSKCB = Q.IDCSKCB
       AND CN.ID = Q.ID_Chuc_Nang
       AND CN.Active = 1
    WHERE T.ID = @ID_Tai_Khoan
      AND T.Active = 1
    GROUP BY CN.Ma_Chuc_Nang;
END;
GO

SELECT N'25_bo_sung_tai_lai_quyen_phien.sql hoàn tất.' AS Message;
GO
