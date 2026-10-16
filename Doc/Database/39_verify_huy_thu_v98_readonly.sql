/* READ ONLY. Fill approved target; no USE, repair, backfill or cancellation. */
SET NOCOUNT ON;
DECLARE @ExpectedServer NVARCHAR(128)=N'<CONFIRMED_SERVER>';
DECLARE @ExpectedDatabase SYSNAME=N'<CONFIRMED_DATABASE>';
IF @ExpectedServer=N'<CONFIRMED_SERVER>' OR @ExpectedDatabase=N'<CONFIRMED_DATABASE>'
 OR CONVERT(NVARCHAR(128),SERVERPROPERTY(N'ServerName'))<>@ExpectedServer OR DB_NAME()<>@ExpectedDatabase
    THROW 59801,N'Chưa xác nhận đúng server/database cho verifier v98.',1;
IF COL_LENGTH(N'dbo.QL_Kho_Hoan',N'IDChungTuHuy') IS NULL
 OR COL_LENGTH(N'dbo.QL_Kho_Hoan',N'IDTaiKhoanHoan') IS NULL
 OR OBJECT_ID(N'dbo.STO_QL_ThuNgan_DaoCapChungTu',N'P') IS NULL
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_ThuNgan_HuyChungTu')),N'') NOT LIKE N'%EXEC dbo.STO_QL_ThuNgan_DaoCapChungTu%'
    THROW 59801,N'Thiếu contract hủy thu/đảo cấp v98.',1;
IF EXISTS
(
    SELECT 1 FROM dbo.QL_Kho_Hoan H
    LEFT JOIN dbo.QL_ThuTien_ChungTu C ON C.ID=H.IDChungTuHuy
    LEFT JOIN dbo.HT_Tai_Khoan T ON T.ID=H.IDTaiKhoanHoan
    WHERE H.Loai='DAO_CAP_HUY_THU'
      AND (C.ID IS NULL OR C.IDCSKCB<>H.IDCSKCB OR C.IDVaoVien<>H.IDVaoVien
           OR C.Loai<>'THU' OR C.TrangThai<>0 OR T.ID IS NULL
           OR C.IDTaiKhoanHuy IS NULL OR C.IDTaiKhoanHuy<>H.IDTaiKhoanHoan)
) THROW 59801,N'Bút toán đảo cấp không khớp chứng từ hủy/tài khoản.',1;
IF EXISTS
(
    SELECT 1 FROM dbo.QL_Kho_Hoan H
    INNER JOIN dbo.QL_Kho_Hoan_CT R ON R.IDHoan=H.ID
    INNER JOIN dbo.QL_Kho_Xuat_CT X ON X.ID=R.IDXuatCT
    INNER JOIN dbo.QL_Kho_Xuat P ON P.ID=X.IDXuat
    LEFT JOIN dbo.QL_Kho_LoThuoc L ON L.ID=X.IDLoThuoc
    LEFT JOIN dbo.QL_ThuTien_ChungTu_CT D ON D.ID=X.IDThuTienChungTuCT
    WHERE H.Loai='DAO_CAP_HUY_THU'
      AND (D.ID IS NULL OR D.IDChungTu<>H.IDChungTuHuy OR D.Loai<>N'THUOC'
           OR X.IDCSKCB<>H.IDCSKCB OR P.IDCSKCB<>H.IDCSKCB OR P.IDVaoVien<>H.IDVaoVien
           OR X.SoLuongDaHoan<>X.SoLuongCoSo OR L.ID IS NULL OR L.IDCSKCB<>H.IDCSKCB OR L.IDThuoc<>X.IDThuoc)
) THROW 59801,N'Đảo cấp sai dòng/tenant hoặc còn lượng đang giao sau hủy.',1;
IF EXISTS(SELECT 1 FROM dbo.QL_Kho_Hoan H WHERE H.Loai='DAO_CAP_HUY_THU'
          AND NOT EXISTS(SELECT 1 FROM dbo.QL_Kho_Hoan_CT R WHERE R.IDHoan=H.ID))
    THROW 59801,N'Bút toán đảo cấp không có chi tiết.',1;
IF EXISTS
(
    SELECT 1 FROM dbo.QL_Kho_Xuat_CT X
    OUTER APPLY(SELECT SUM(R.SoLuongCoSo) AS DaHoan FROM dbo.QL_Kho_Hoan_CT R WHERE R.IDXuatCT=X.ID) A
    WHERE X.SoLuongDaHoan<0 OR X.SoLuongDaHoan>X.SoLuongCoSo OR X.SoLuongDaHoan<>ISNULL(A.DaHoan,0)
) THROW 59801,N'Lượng hoàn/đảo không khớp sổ chi tiết; cần đối chiếu, không tự sửa.',1;
IF EXISTS(SELECT 1 FROM dbo.QL_Kho_LoThuoc WHERE SoLuongTon<0)
    THROW 59801,N'Tồn âm.',1;

SELECT CONVERT(NVARCHAR(128),SERVERPROPERTY(N'ServerName')) AS ServerName,DB_NAME() AS DatabaseName;
SELECT VersionNo,AppliedAt FROM dbo.QLPM_SchemaVersion WHERE VersionNo>=94 ORDER BY VersionNo;
SELECT H.IDCSKCB,H.ID,H.IDChungTuHuy,H.SoPhieu,H.NgayHoan,H.IDTaiKhoanHoan,H.IDNhanVienHoan,
       C.SoChungTu,C.NgayGioHuy,C.ThucThu,C.TienMat,C.ChuyenKhoan
FROM dbo.QL_Kho_Hoan H INNER JOIN dbo.QL_ThuTien_ChungTu C ON C.ID=H.IDChungTuHuy
WHERE H.Loai='DAO_CAP_HUY_THU' ORDER BY H.ID;
/* Manifest per lot/receipt, no sum of quantities across different medicine units. */
SELECT IDCSKCB,ID,IDThuoc,SoLuongTon FROM dbo.QL_Kho_LoThuoc ORDER BY IDCSKCB,ID;
SELECT IDCSKCB,Loai,TrangThai,COUNT_BIG(*) AS SoPhieu,SUM(ThucThu) AS ThucThu,
       SUM(TienMat) AS TienMat,SUM(ChuyenKhoan) AS ChuyenKhoan
FROM dbo.QL_ThuTien_ChungTu GROUP BY IDCSKCB,Loai,TrangThai ORDER BY IDCSKCB,Loai,TrangThai;
SELECT IDCSKCB,ID,IDVaoVien,TienMat,ChuyenKhoan,DaThu FROM dbo.QL_ThuTien ORDER BY IDCSKCB,ID;
SELECT C.IDCSKCB,C.ID,C.IDVaoVien,C.Loai,C.TrangThai,C.TongTien,C.TienGiam,C.ThucThu,C.TienMat,C.ChuyenKhoan,
       D.ID AS IDChungTuCT,D.IDThuTienCT,D.SoLuong,D.DonGia,D.ThanhToan
FROM dbo.QL_ThuTien_ChungTu C LEFT JOIN dbo.QL_ThuTien_ChungTu_CT D ON D.IDChungTu=C.ID
ORDER BY C.IDCSKCB,C.ID,D.ID;
SELECT X.IDCSKCB,X.ID,X.IDXuat,X.IDThuTienChungTuCT,X.IDLoThuoc,X.HeSoQuyDoi,
       X.SoLuongCoSo,X.SoLuongDaHoan,R.IDHoan,R.SoLuongCoSo AS SoLuongHoanDao
FROM dbo.QL_Kho_Xuat_CT X LEFT JOIN dbo.QL_Kho_Hoan_CT R ON R.IDXuatCT=X.ID
ORDER BY X.IDCSKCB,X.ID,R.ID;
/* Reconciliation queue: missing legacy link cannot be guessed from prescription ID. */
SELECT X.IDCSKCB,P.IDVaoVien,X.ID AS IDXuatCT,X.IDToaThuocCT,X.IDLoThuoc,
       X.SoLuongCoSo-X.SoLuongDaHoan AS ConDangGiao
FROM dbo.QL_Kho_Xuat_CT X INNER JOIN dbo.QL_Kho_Xuat P ON P.ID=X.IDXuat AND P.IDCSKCB=X.IDCSKCB
WHERE X.IDThuTienChungTuCT IS NULL AND X.SoLuongCoSo>X.SoLuongDaHoan;
PRINT N'v98 readonly inventory complete; NOT a runtime/concurrency test.';
