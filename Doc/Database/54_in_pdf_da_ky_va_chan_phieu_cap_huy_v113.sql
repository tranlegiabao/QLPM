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

CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_PhieuCap_DanhSach @IDCSKCB BIGINT,@IDVaoVien BIGINT
AS
BEGIN
 SET NOCOUNT ON;
 SELECT ID id,SoPhieu so_phieu,NgayXuat ngay_xuat,DaHuy da_huy
 FROM dbo.QL_Kho_Xuat WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND DaHuy=0
 ORDER BY NgayXuat DESC,ID DESC;
END;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_PhieuCap_In @IDCSKCB BIGINT,@IDXuat BIGINT
AS
BEGIN
 SET NOCOUNT ON;
 SELECT X.ID id,X.SoPhieu so_phieu,X.NgayXuat ngay_xuat,X.GhiChu ghi_chu,X.DaHuy da_huy,X.TenNguoiXuatSnapshot nguoi_xuat,
 V.MaVaoVien ma_vao_vien,V.DanDo dan_do,V.NgayTaiKham ngay_tai_kham,
 B.MaBN ma_bn,B.HoTen ho_ten,B.NgaySinh ngay_sinh,GT.TenGioiTinh gioi_tinh,B.DiaChi dia_chi,B.DienThoai dien_thoai,
 B.GiamHo_HoTen giam_ho,B.GiamHo_MoiQuanHe quan_he,
 C.TenCSKCB ten_cskcb,C.DiaChi dia_chi_cskcb,C.SDT sdt_cskcb,C.Email email_cskcb,C.UrlLogo url_logo,
 (SELECT TOP(1) D.GiaTri FROM dbo.QL_PhieuSinhHieu P JOIN dbo.QL_PhieuSinhHieu_CT D ON D.IDCSKCB=P.IDCSKCB AND D.IDPhieuSinhHieu=P.ID
  JOIN dbo.DM_TriSoSinhHieu S ON S.IDCSKCB=D.IDCSKCB AND S.ID=D.IDTriSoSinhHieu AND S.MaTriSo IN(N'CAN_NANG',N'CANNANG')
  WHERE P.IDCSKCB=X.IDCSKCB AND P.IDVaoVien=X.IDVaoVien ORDER BY P.NgayGioDo DESC,P.ID DESC,D.ID DESC) can_nang,
 (SELECT STRING_AGG(CONVERT(NVARCHAR(MAX),CONCAT(N'(',D.MaBenh,N') ',D.TenBenh)),N'; ')
  WITHIN GROUP(ORDER BY D.BenhChinh DESC,D.ThuTu,D.ID) FROM dbo.QL_ChanDoan_CT D WHERE D.IDCSKCB=X.IDCSKCB AND D.IDVaoVien=X.IDVaoVien) chan_doan
 FROM dbo.QL_Kho_Xuat X
 JOIN dbo.QL_VaoVien V ON V.IDCSKCB=X.IDCSKCB AND V.ID=X.IDVaoVien
 JOIN dbo.QL_BenhNhan B ON B.IDCSKCB=V.IDCSKCB AND B.ID=V.IDBenhNhan
 JOIN dbo.DM_CSKCB C ON C.ID=X.IDCSKCB
 LEFT JOIN dbo.DM_GioiTinh GT ON GT.ID=B.IDGioiTinh
 WHERE X.IDCSKCB=@IDCSKCB AND X.ID=@IDXuat AND X.DaHuy=0;

 -- Use the issued quantity and conversion at dispensing, and selling price
 -- from the linked receipt snapshot. Warehouse ThanhTien/GiaVon are cost.
 SELECT CT.IDToaThuocCT id_toa_thuoc_ct,
 COALESCE(D.Ten,M.TenThuoc) ten_thuoc,M.HamLuong ham_luong,COALESCE(NULLIF(T.HoatChat,N''),M.HoatChat) hoat_chat,
 COALESCE(D.DonViTinh,U.TenDVT,M.DonViTinh) don_vi_tinh,
 CAST(SUM(CT.SoLuongCoSo)/NULLIF(CT.HeSoQuyDoi,0) AS DECIMAL(18,4)) so_luong,
 COALESCE(D.DonGia,T.DonGia) don_gia,
 CAST(ROUND((SUM(CT.SoLuongCoSo)/NULLIF(CT.HeSoQuyDoi,0))*COALESCE(D.DonGia,T.DonGia),0) AS DECIMAL(18,2)) thanh_tien,
 SUM(CT.SoLuongDaHoan) da_hoan_co_so,
 CAST(CASE WHEN D.ID IS NULL THEN 1 ELSE 0 END AS BIT) gia_legacy,
 T.Sang sang,T.Trua trua,T.Chieu chieu,T.Toi toi,T.LieuDung lieu_dung,T.CachDung cach_dung,M.DuongDung duong_dung,
 T.MaLoaiToaThuoc ma_loai_toa,T.NgayKe ngay_ke,H.MaToaQuocGia ma_toa,
 LTRIM(RTRIM(CONCAT(CD.VietTat,N' ',NV.HoTen))) bac_si
 FROM dbo.QL_Kho_Xuat_CT CT
 JOIN dbo.QL_Kho_Xuat X ON X.IDCSKCB=CT.IDCSKCB AND X.ID=CT.IDXuat
 JOIN dbo.QL_ToaThuoc_CT T ON T.IDCSKCB=CT.IDCSKCB AND T.ID=CT.IDToaThuocCT AND T.IDVaoVien=X.IDVaoVien
 JOIN dbo.DM_Thuoc M ON M.IDCSKCB=CT.IDCSKCB AND M.ID=CT.IDThuoc
 LEFT JOIN dbo.DM_DonViTinh U ON U.IDCSKCB=T.IDCSKCB AND U.ID=T.IDDonViTinhDung
 LEFT JOIN dbo.QL_ThuTien_ChungTu_CT D ON D.ID=CT.IDThuTienChungTuCT AND D.Loai=N'THUOC'
  AND EXISTS(SELECT 1 FROM dbo.QL_ThuTien_ChungTu C0 WHERE C0.ID=D.IDChungTu AND C0.IDCSKCB=X.IDCSKCB AND C0.IDVaoVien=X.IDVaoVien)
 LEFT JOIN dbo.QL_ToaThuoc H ON H.IDCSKCB=T.IDCSKCB AND H.ID=T.IDToaThuoc
 LEFT JOIN dbo.DM_NhanVien NV ON NV.ID=T.IDBacSiKe
 LEFT JOIN dbo.DM_ChucDanh CD ON CD.ID=NV.IDChucDanh
 WHERE X.IDCSKCB=@IDCSKCB AND X.ID=@IDXuat AND X.DaHuy=0
 GROUP BY CT.IDToaThuocCT,CT.HeSoQuyDoi,D.ID,D.Ten,M.TenThuoc,M.HamLuong,T.HoatChat,M.HoatChat,D.DonViTinh,U.TenDVT,M.DonViTinh,
 D.DonGia,T.DonGia,T.Sang,T.Trua,T.Chieu,T.Toi,T.LieuDung,T.CachDung,M.DuongDung,T.MaLoaiToaThuoc,T.NgayKe,H.MaToaQuocGia,CD.VietTat,NV.HoTen
 ORDER BY T.NgayKe,CT.IDToaThuocCT;
END;
GO
PRINT N'54_in_pdf_da_ky_va_chan_phieu_cap_huy_v113.sql: OK; read-only printing.';
GO
