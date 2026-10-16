/* AFTER v96, read-only. Chỉ chạy sau xác nhận đúng đích + backup + updater.
   Kết hợp manifest BEFORE 33 và AFTER 32 để đối chiếu tiền/tồn không đổi. */
SET NOCOUNT ON;
DECLARE @ExpectedServer sysname=N'REPLACE_WITH_APPROVED_SERVER';
DECLARE @ExpectedDatabase sysname=N'REPLACE_WITH_APPROVED_DATABASE';
IF CONVERT(sysname,SERVERPROPERTY('ServerName'))<>@ExpectedServer OR DB_NAME()<>@ExpectedDatabase
    THROW 59600,N'Sai đích hoặc chưa xác nhận server/database.',1;
SELECT SERVERPROPERTY('ServerName') AS server_name,DB_NAME() AS database_name;
IF COL_LENGTH(N'dbo.QL_Kho_Xuat',N'IDTaiKhoanXuat') IS NULL
 OR COL_LENGTH(N'dbo.QL_Kho_Xuat',N'TenNguoiXuatSnapshot') IS NULL
    THROW 59600,N'Thiếu schema audit v96.',1;
GO
IF NOT EXISTS(SELECT 1 FROM sys.parameters WHERE object_id=OBJECT_ID(N'dbo.STO_QL_Kho_Xuat_TheoToa') AND name=N'@IDTaiKhoanXuat')
    THROW 59600,N'Thiếu hợp đồng STO v96.',1;
IF EXISTS(SELECT 1 FROM dbo.QL_Kho_Xuat X LEFT JOIN dbo.HT_Tai_Khoan T ON T.ID=X.IDTaiKhoanXuat
          WHERE X.IDTaiKhoanXuat IS NOT NULL AND
            (T.ID IS NULL OR NULLIF(LTRIM(RTRIM(X.TenNguoiXuatSnapshot)),N'') IS NULL))
    THROW 59600,N'Phiếu cấp có audit tài khoản không hợp lệ.',1;
SELECT ID,IDCSKCB,SoPhieu,NgayXuat,IDNhanVienXuat,IDTaiKhoanXuat,TenNguoiXuatSnapshot,TongGiaVon
FROM dbo.QL_Kho_Xuat ORDER BY ID;
SELECT COUNT_BIG(*) AS so_phieu_legacy_chua_co_audit_tai_khoan
FROM dbo.QL_Kho_Xuat WHERE IDTaiKhoanXuat IS NULL;
SELECT VersionNo,TenMigration,AppliedAt FROM dbo.QLPM_SchemaVersion WHERE VersionNo IN(94,95,96);
PRINT N'Audit phiếu cấp v96: OK (chưa thay thế smoke test route/DB).';
