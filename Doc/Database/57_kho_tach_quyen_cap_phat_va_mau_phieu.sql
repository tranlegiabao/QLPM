USE [QLPM];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* Tách hai chức năng. Không đổi tài khoản, phân công nhân viên hay chứng từ.
   Kho chỉ quản lý kho; vai trò mới chỉ cấp phát/in/hủy cấp phát.
   Các vai trò tùy chỉnh khác giữ quyền cấp phát cũ trong lần chuyển đầu tiên. */
BEGIN TRAN;
DECLARE @Moi TABLE(IDCSKCB BIGINT PRIMARY KEY);
INSERT dbo.HT_Chuc_Nang(IDCSKCB,ID_Phan_He,Ma_Chuc_Nang,Ten_Chuc_Nang,Duong_Dan,Thu_Tu,Active)
OUTPUT inserted.IDCSKCB INTO @Moi
SELECT C.ID,P.ID,N'kho_cap_phat',N'Cấp phát thuốc',N'/kho',7,1
FROM dbo.DM_CSKCB C JOIN dbo.HT_Phan_He P ON P.IDCSKCB=C.ID AND P.Ma_Phan_He=N'quan_ly'
WHERE C.Active=1 AND NOT EXISTS
 (SELECT 1 FROM dbo.HT_Chuc_Nang F WHERE F.IDCSKCB=C.ID AND F.Ma_Chuc_Nang=N'kho_cap_phat');

UPDATE F SET Ten_Chuc_Nang=N'Quản lý kho',Duong_Dan=N'/kho/quan-ly'
FROM dbo.HT_Chuc_Nang F JOIN dbo.DM_CSKCB C ON C.ID=F.IDCSKCB AND C.Active=1
WHERE F.Ma_Chuc_Nang=N'kho';

UPDATE F SET Ten_Chuc_Nang=N'Cấp phát thuốc',Duong_Dan=N'/kho'
FROM dbo.HT_Chuc_Nang F JOIN dbo.DM_CSKCB C ON C.ID=F.IDCSKCB AND C.Active=1
WHERE F.Ma_Chuc_Nang=N'kho_cap_phat';

UPDATE V SET Ten_Vai_Tro=N'Quản lý kho',Mo_Ta=N'Quản lý tồn kho, nhập kho và phân nhóm thuốc.',Ngay_Cap_Nhat=SYSDATETIME()
FROM dbo.DM_Vai_Tro V JOIN dbo.DM_CSKCB C ON C.ID=V.IDCSKCB AND C.Active=1
WHERE V.Ma_Vai_Tro=N'kho';

-- Vai trò Kho được tách khỏi cấp phát; gán thêm Dược cấp phát nếu làm cả hai.
UPDATE Q SET Xem=0,Them=0,Sua=0,Xoa=0,Xuat=0,Ca_Nhan=0
FROM dbo.HT_Quyen_Vai_Tro Q JOIN dbo.DM_Vai_Tro V ON V.IDCSKCB=Q.IDCSKCB AND V.ID=Q.ID_Vai_Tro
JOIN dbo.HT_Chuc_Nang F ON F.IDCSKCB=Q.IDCSKCB AND F.ID=Q.ID_Chuc_Nang
JOIN dbo.DM_CSKCB C ON C.ID=Q.IDCSKCB AND C.Active=1
WHERE V.Ma_Vai_Tro=N'kho' AND F.Ma_Chuc_Nang=N'kho_cap_phat';

DECLARE @DuocMoi TABLE(IDCSKCB BIGINT PRIMARY KEY);
INSERT dbo.DM_Vai_Tro(IDCSKCB,Ma_Vai_Tro,Ten_Vai_Tro,Mo_Ta,Active)
OUTPUT inserted.IDCSKCB INTO @DuocMoi
SELECT C.ID,N'duoc_cap_phat',N'Dược cấp phát',N'Cấp phát thuốc, in phiếu và hủy cấp phát thuốc; không quản lý kho hoặc hủy chứng từ thu ngân.',1
FROM dbo.DM_CSKCB C WHERE C.Active=1 AND NOT EXISTS
 (SELECT 1 FROM dbo.DM_Vai_Tro V WHERE V.IDCSKCB=C.ID AND V.Ma_Vai_Tro=N'duoc_cap_phat');

-- Updater có thể đã thêm chức năng trước overlay này; chỉ chuyển quyền lần đầu.
INSERT @Moi SELECT D.IDCSKCB FROM @DuocMoi D WHERE NOT EXISTS(SELECT 1 FROM @Moi M WHERE M.IDCSKCB=D.IDCSKCB);

INSERT dbo.HT_Quyen_Vai_Tro(IDCSKCB,ID_Vai_Tro,ID_Chuc_Nang,Xem,Them,Sua,Xoa,Xuat,Ca_Nhan)
SELECT Q.IDCSKCB,Q.ID_Vai_Tro,F.ID,Q.Xem,0,Q.Sua,Q.Xoa,Q.Xuat,Q.Ca_Nhan
FROM @Moi M JOIN dbo.HT_Chuc_Nang K ON K.IDCSKCB=M.IDCSKCB AND K.Ma_Chuc_Nang=N'kho'
JOIN dbo.HT_Quyen_Vai_Tro Q ON Q.IDCSKCB=K.IDCSKCB AND Q.ID_Chuc_Nang=K.ID
JOIN dbo.DM_Vai_Tro V ON V.IDCSKCB=Q.IDCSKCB AND V.ID=Q.ID_Vai_Tro
JOIN dbo.HT_Chuc_Nang F ON F.IDCSKCB=M.IDCSKCB AND F.Ma_Chuc_Nang=N'kho_cap_phat'
WHERE V.Ma_Vai_Tro NOT IN(N'kho',N'duoc_cap_phat',N'quan_tri_cskcb')
 AND NOT EXISTS(SELECT 1 FROM dbo.HT_Quyen_Vai_Tro X WHERE X.IDCSKCB=Q.IDCSKCB AND X.ID_Vai_Tro=Q.ID_Vai_Tro AND X.ID_Chuc_Nang=F.ID);

INSERT dbo.HT_Quyen_Vai_Tro(IDCSKCB,ID_Vai_Tro,ID_Chuc_Nang,Xem,Them,Sua,Xoa,Xuat,Ca_Nhan)
SELECT V.IDCSKCB,V.ID,F.ID,1,CASE WHEN V.Ma_Vai_Tro=N'quan_tri_cskcb' THEN 1 ELSE 0 END,1,1,1,
 CASE WHEN V.Ma_Vai_Tro=N'quan_tri_cskcb' THEN 1 ELSE 0 END
FROM dbo.DM_Vai_Tro V JOIN dbo.DM_CSKCB C ON C.ID=V.IDCSKCB AND C.Active=1
JOIN dbo.HT_Chuc_Nang F ON F.IDCSKCB=V.IDCSKCB AND F.Ma_Chuc_Nang=N'kho_cap_phat'
WHERE V.Ma_Vai_Tro IN(N'duoc_cap_phat',N'quan_tri_cskcb')
 AND NOT EXISTS(SELECT 1 FROM dbo.HT_Quyen_Vai_Tro Q WHERE Q.IDCSKCB=V.IDCSKCB AND Q.ID_Vai_Tro=V.ID AND Q.ID_Chuc_Nang=F.ID);
COMMIT;
GO

/* Đầu phiếu bổ sung địa chỉ/điện thoại NCC cho mẫu Excel; đọc trong tenant.
   Giữ snapshot tên thuốc/ĐVT/NCC, người nhập và toàn bộ dòng lô hiện có. */
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_Nhap_ChiTiet @IDCSKCB BIGINT,@IDNhap BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT N.ID AS id,N.SoPhieu AS so_phieu,N.NgayNhap AS ngay_nhap,N.SoHoaDon AS so_hoa_don,N.NgayHoaDon AS ngay_hoa_don,
           COALESCE(N.TenNhaCungCapSnapshot,NCC.TenNhaCungCap) AS nha_cung_cap,
           NCC.DiaChi AS dia_chi_ncc,NCC.DienThoai AS dien_thoai_ncc,
           CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.QL_Kho_Nhap_CT D WHERE D.IDCSKCB=N.IDCSKCB AND D.IDNhap=N.ID AND D.TenThuocSnapshot IS NULL)
                     OR (N.IDNhaCungCap IS NOT NULL AND N.TenNhaCungCapSnapshot IS NULL) THEN 1 ELSE 0 END AS BIT) AS la_legacy,
           N.TongTien AS tong_tien,N.GhiChu AS ghi_chu,N.DaHuy AS da_huy,N.LyDoHuy AS ly_do_huy,
           N.NgayGioHuy AS ngay_gio_huy,COALESCE(NULLIF(N.TenNguoiNhapSnapshot,N''),NV.HoTen,TK.Ten_Dang_Nhap,N'') AS nguoi_nhap,COALESCE(NVH.HoTen,N'') AS nguoi_huy
    FROM dbo.QL_Kho_Nhap N LEFT JOIN dbo.DM_NhaCungCap NCC ON NCC.IDCSKCB=N.IDCSKCB AND NCC.ID=N.IDNhaCungCap
    LEFT JOIN dbo.DM_NhanVien NV ON NV.ID=N.IDNhanVienNhap LEFT JOIN dbo.DM_NhanVien NVH ON NVH.ID=N.IDNhanVienHuy
    LEFT JOIN dbo.HT_Tai_Khoan TK ON TK.ID=N.IDTaiKhoanNhap
    WHERE N.IDCSKCB=@IDCSKCB AND N.ID=@IDNhap;
    SELECT CT.ID AS id,CT.IDThuoc AS id_thuoc,COALESCE(CT.MaThuocSnapshot,T.MaThuoc) AS ma_thuoc,COALESCE(CT.TenThuocSnapshot,T.TenThuoc) AS ten_thuoc,COALESCE(CT.DonViTinhSnapshot,DVT.TenDVT) AS don_vi_tinh,
           CT.HeSoQuyDoi AS he_so_quy_doi,CT.SoLuongCoSo AS so_luong_co_so,CT.SoLuong AS so_luong,CT.GiaNhap AS gia_nhap,CT.ThanhTien AS thanh_tien,CT.SoLo AS so_lo,CT.HanDung AS han_dung,
           L.SoLuongNhap AS so_luong_nhap_co_so,L.SoLuongTon AS so_luong_ton_co_so
    FROM dbo.QL_Kho_Nhap_CT CT INNER JOIN dbo.DM_Thuoc T ON T.IDCSKCB=CT.IDCSKCB AND T.ID=CT.IDThuoc
    LEFT JOIN dbo.DM_DonViTinh DVT ON DVT.IDCSKCB=CT.IDCSKCB AND DVT.ID=CT.IDDonViTinh
    INNER JOIN dbo.QL_Kho_LoThuoc L ON L.ID=CT.IDLoThuoc
    WHERE CT.IDCSKCB=@IDCSKCB AND CT.IDNhap=@IDNhap ORDER BY CT.ID;
END;
GO
