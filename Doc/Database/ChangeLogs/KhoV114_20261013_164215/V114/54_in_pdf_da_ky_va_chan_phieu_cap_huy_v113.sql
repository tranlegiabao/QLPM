/* v114 non-warehouse portion. Warehouse definitions are centralized in 60_kho_sto_v114.sql. */
:ON ERROR EXIT
USE [QLPM];
GO
SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;SET NOCOUNT ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_KySoPdf_In_HienTai
 @IDCSKCB BIGINT,@IDVaoVien BIGINT,@MaLoai NVARCHAR(30),@IDToaThuoc BIGINT=NULL,@NhomChiDinh TINYINT=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SELECT TOP(1) T.ID IDTaiLieu,T.PdfDaKy,T.Sha256DaKy
 FROM dbo.QL_KySoPdf_TaiLieu T JOIN dbo.QL_VaoVien V ON V.IDCSKCB=T.IDCSKCB AND V.ID=T.IDVaoVien AND V.Active=1
 WHERE T.IDCSKCB=@IDCSKCB AND T.IDVaoVien=@IDVaoVien AND T.MaLoai=@MaLoai AND T.TrangThai=N'DA_KY'
 AND T.PhienBanLamSang=V.PhienBanLamSang
 AND ((@MaLoai=N'toa_thuoc' AND ((@IDToaThuoc IS NULL AND T.IDToaThuoc IS NULL) OR T.IDToaThuoc=@IDToaThuoc))
   OR (@MaLoai=N'chi_dinh' AND ((@NhomChiDinh IS NULL AND T.NhomChiDinh=2) OR T.NhomChiDinh=@NhomChiDinh)))
 ORDER BY T.ID DESC;
END;
GO
PRINT N'54_in_pdf_da_ky_va_chan_phieu_cap_huy_v113.sql: OK; read-only printing.';
GO
