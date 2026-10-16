/* Manifest BEFORE v95, dùng được trên v94. READ ONLY, không phải lệnh BACKUP DB.
   Điền đích đã duyệt, lưu toàn bộ resultsets cùng bản sao lưu DB và app revision. */
SET NOCOUNT ON;
DECLARE @ExpectedServer sysname=N'REPLACE_WITH_APPROVED_SERVER';
DECLARE @ExpectedDatabase sysname=N'REPLACE_WITH_APPROVED_DATABASE';
IF CONVERT(sysname,SERVERPROPERTY('ServerName'))<>@ExpectedServer OR DB_NAME()<>@ExpectedDatabase
    THROW 59500,N'Sai đích hoặc chưa điền server/database đã duyệt.',1;
SELECT SERVERPROPERTY('ServerName') AS server_name,DB_NAME() AS database_name,SYSDATETIME() AS captured_at;
SELECT * FROM dbo.QLPM_SchemaVersion ORDER BY VersionNo;
SELECT IDCSKCB,Loai,TrangThai,COUNT_BIG(*) so_chung_tu,SUM(TongTien) tong_tien,SUM(TienGiam) tien_giam,
       SUM(ThucThu) thuc_thu,SUM(TienMat) tien_mat,SUM(ChuyenKhoan) chuyen_khoan
FROM dbo.QL_ThuTien_ChungTu GROUP BY IDCSKCB,Loai,TrangThai;
SELECT IDCSKCB,IDVaoVien,ID,SoPhieu,TongTien,TienGiam,ThucThu,TienMat,ChuyenKhoan,DaThu
FROM dbo.QL_ThuTien ORDER BY IDCSKCB,IDVaoVien;
SELECT IDCSKCB,IDThuoc,IDKho,ID AS id_lo,SoLo,HanDung,SoLuongTon,GiaNhap,Active
FROM dbo.QL_Kho_LoThuoc ORDER BY IDCSKCB,IDKho,IDThuoc,ID;
SELECT X.IDCSKCB,H.IDVaoVien,X.ID,X.IDXuat,X.IDToaThuocCT,X.IDLoThuoc,X.SoLuongCoSo,X.SoLuongDaHoan
FROM dbo.QL_Kho_Xuat_CT X INNER JOIN dbo.QL_Kho_Xuat H ON H.IDCSKCB=X.IDCSKCB AND H.ID=X.IDXuat
ORDER BY X.IDCSKCB,H.IDVaoVien,X.ID;
SELECT P.name,OBJECT_DEFINITION(P.object_id) AS procedure_definition
FROM sys.procedures P WHERE schema_id=SCHEMA_ID(N'dbo') AND
 (P.name LIKE N'STO_QL_Kho[_]%' OR P.name LIKE N'STO_QL_ThuNgan[_]%') ORDER BY P.name;
