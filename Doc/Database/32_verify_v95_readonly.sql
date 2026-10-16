/* READ ONLY, AFTER v95. BEFORE dùng 33_before_v95_readonly.sql.
   Điền đúng server/DB đã duyệt. Không tự USE hoặc migrate database. */
SET NOCOUNT ON;
DECLARE @ExpectedServer sysname=N'REPLACE_WITH_APPROVED_SERVER';
DECLARE @ExpectedDatabase sysname=N'REPLACE_WITH_APPROVED_DATABASE';
IF CONVERT(sysname,SERVERPROPERTY('ServerName'))<>@ExpectedServer OR DB_NAME()<>@ExpectedDatabase
    THROW 59500,N'Sai đích hoặc chưa điền server/database đã duyệt. Dừng đối chiếu.',1;

SELECT SERVERPROPERTY('ServerName') AS server_name,DB_NAME() AS database_name,SYSDATETIME() AS verified_at;
SELECT VersionNo,TenMigration,AppliedAt FROM dbo.QLPM_SchemaVersion WHERE VersionNo IN(94,95);

/* Manifest tài chính. Lưu trước/sau cutover; không coi phiếu hủy là dòng chi tiền. */
SELECT IDCSKCB,Loai,TrangThai,COUNT_BIG(*) AS so_chung_tu,
       SUM(TongTien) AS tong_tien,SUM(TienGiam) AS tien_giam,SUM(ThucThu) AS thuc_thu,
       SUM(TienMat) AS tien_mat,SUM(ChuyenKhoan) AS chuyen_khoan
FROM dbo.QL_ThuTien_ChungTu GROUP BY IDCSKCB,Loai,TrangThai;
SELECT IDCSKCB,IDThuoc,IDKho,ID AS id_lo,SoLo,HanDung,SoLuongTon,GiaNhap,Active
FROM dbo.QL_Kho_LoThuoc ORDER BY IDCSKCB,IDKho,IDThuoc,ID;
SELECT X.IDCSKCB,H.IDVaoVien,X.ID,X.IDXuat,X.IDToaThuocCT,X.IDLoThuoc,
       X.SoLuongCoSo,X.SoLuongDaHoan,X.IDThuTienChungTuCT,X.HeSoQuyDoi
FROM dbo.QL_Kho_Xuat_CT X INNER JOIN dbo.QL_Kho_Xuat H ON H.IDCSKCB=X.IDCSKCB AND H.ID=X.IDXuat
ORDER BY X.IDCSKCB,H.IDVaoVien,X.ID;

/* Các dòng mơ hồ phải được đối chiếu thủ công, không tự chọn MIN/MAX để sửa. */
SELECT X.IDCSKCB,H.IDVaoVien,H.SoPhieu,X.ID AS id_xuat_ct,X.IDToaThuocCT,
       X.SoLuongCoSo-ISNULL(X.SoLuongDaHoan,0) AS dang_giao
FROM dbo.QL_Kho_Xuat_CT X INNER JOIN dbo.QL_Kho_Xuat H ON H.IDCSKCB=X.IDCSKCB AND H.ID=X.IDXuat
WHERE X.IDThuTienChungTuCT IS NULL;

IF EXISTS(SELECT 1 FROM dbo.QL_Kho_LoThuoc WHERE SoLuongTon<0)
    THROW 59501,N'Có tồn âm.',1;
IF EXISTS(SELECT 1 FROM dbo.QL_Kho_Xuat_CT WHERE ISNULL(SoLuongDaHoan,0)<0 OR SoLuongDaHoan>SoLuongCoSo)
    THROW 59502,N'Có dòng xuất hoàn vượt hoặc âm.',1;
IF EXISTS
(
    SELECT 1 FROM dbo.QL_Kho_Xuat_CT X
    INNER JOIN dbo.QL_Kho_Xuat H ON H.IDCSKCB=X.IDCSKCB AND H.ID=X.IDXuat
    INNER JOIN dbo.QL_ThuTien_ChungTu_CT D ON D.ID=X.IDThuTienChungTuCT
    INNER JOIN dbo.QL_ThuTien_ChungTu C ON C.ID=D.IDChungTu
    INNER JOIN dbo.QL_ThuTien_CT P ON P.ID=D.IDThuTienCT
    WHERE C.IDCSKCB<>X.IDCSKCB OR C.IDVaoVien<>H.IDVaoVien OR P.IDToaThuocCT<>X.IDToaThuocCT
       OR D.Loai<>N'THUOC' OR C.Loai<>'THU'
)
    THROW 59503,N'Liên kết cấp/thu sai nguồn hoặc sai cơ sở.',1;

PRINT N'Đối chiếu cấu trúc/manifest v95 hoàn tất. Không thay thế test nghiệp vụ/đồng thời/browser.';
