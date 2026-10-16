/* Read-only schema/data invariants. Does not create or cancel business documents. */
SET NOCOUNT ON;
IF DB_NAME()<>N'QLPM' THROW 59114,'Expected QLPM.',1;
DECLARE @Old TABLE(Name SYSNAME PRIMARY KEY);
INSERT @Old VALUES
('QL_Kho_Nhap'),('QL_Kho_Nhap_CT'),('QL_Kho_Xuat'),('QL_Kho_Xuat_CT'),
('QL_Kho_Hoan'),('QL_Kho_Hoan_CT'),('QL_Kho_DieuChinh'),('QL_Kho_DieuChinh_CT'),
('QL_Kho_KiemKe'),('QL_Kho_KiemKe_CT'),('QL_Kho_XuatKhac'),('QL_Kho_XuatKhac_CT'),
('QL_Kho_KhoaLo'),('QL_Kho_SoChungTu');
IF EXISTS(SELECT 1 FROM @Old WHERE OBJECT_ID(N'dbo.'+Name,N'U') IS NOT NULL
 OR OBJECT_ID(N'dbo.'+Name,N'V') IS NOT NULL)
 THROW 59114,'Legacy warehouse tables/views still exist.',1;
IF (SELECT COUNT(*) FROM sys.tables WHERE schema_id=SCHEMA_ID(N'dbo')
 AND (name='DM_Kho' OR name LIKE 'QL_Kho[_]%'))<>5
 THROW 59114,'Expected exactly five warehouse tables.',1;
IF OBJECT_ID(N'dbo.QL_Kho_ChungTu',N'U') IS NULL
 OR OBJECT_ID(N'dbo.QL_Kho_ChungTu_CT',N'U') IS NULL
 OR OBJECT_ID(N'dbo.QL_Kho_GiaoDich',N'U') IS NULL
 OR OBJECT_ID(N'dbo.QL_Kho_LoThuoc',N'U') IS NULL
 THROW 59114,'Canonical warehouse schema missing.',1;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id IN
 (OBJECT_ID(N'dbo.QL_Kho_ChungTu'),OBJECT_ID(N'dbo.QL_Kho_ChungTu_CT'))
 AND (is_disabled=1 OR is_not_trusted=1))
 OR EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id IN
 (OBJECT_ID(N'dbo.QL_Kho_ChungTu'),OBJECT_ID(N'dbo.QL_Kho_ChungTu_CT'))
 AND (is_disabled=1 OR is_not_trusted=1))
 THROW 59114,'Untrusted canonical constraint.',1;
IF EXISTS(SELECT 1 FROM dbo.QL_Kho_LoThuoc WHERE SoLuongTon<0)
 OR EXISTS(SELECT 1 FROM dbo.QL_Kho_ChungTu_CT WHERE LoaiChungTu='CAP_PHAT'
 AND (SoLuongDaHoan<0 OR SoLuongDaHoan>SoLuongCoSo))
 THROW 59114,'Invalid stock/returned quantity.',1;
IF EXISTS(SELECT 1 FROM dbo.QL_Kho_ChungTu_CT C
 LEFT JOIN dbo.QL_Kho_ChungTu H ON H.IDCSKCB=C.IDCSKCB AND H.LoaiChungTu=C.LoaiChungTu AND H.ID=C.IDChungTu
 WHERE H.ID IS NULL)
 OR EXISTS(SELECT 1 FROM dbo.QL_Kho_ChungTu_CT C
 LEFT JOIN dbo.QL_Kho_ChungTu_CT X ON X.IDCSKCB=C.IDCSKCB AND X.LoaiChungTu='CAP_PHAT' AND X.ID=C.IDChungTuCTGoc
 WHERE C.LoaiChungTu='HOAN' AND X.ID IS NULL)
 THROW 59114,'Broken typed document reference.',1;
IF EXISTS(SELECT 1 FROM sys.sql_expression_dependencies D JOIN @Old O ON O.Name=D.referenced_entity_name
 WHERE D.referencing_id IN(SELECT object_id FROM sys.sql_modules))
 THROW 59114,'SQL dependency on removed warehouse table.',1;
IF OBJECT_ID(N'dbo.TR_QL_Kho_ChungTu_CT_GiaoDich',N'TR') IS NULL
 OR OBJECT_ID(N'dbo.TR_QL_Kho_ChungTu_HuyNhap_GiaoDich',N'TR') IS NULL
 OR OBJECT_ID(N'dbo.TR_QL_Kho_GiaoDich_BatBien',N'TR') IS NULL
 OR EXISTS(SELECT 1 FROM sys.triggers WHERE name IN
 (N'TR_QL_Kho_ChungTu_CT_GiaoDich',N'TR_QL_Kho_ChungTu_HuyNhap_GiaoDich',N'TR_QL_Kho_GiaoDich_BatBien') AND is_disabled=1)
 THROW 59114,'Journal trigger missing/disabled.',1;
IF (SELECT COUNT(*) FROM sys.sequences WHERE name IN
 ('SEQ_Kho_NHAP','SEQ_Kho_NHAP_CT','SEQ_Kho_CAP_PHAT','SEQ_Kho_CAP_PHAT_CT',
 'SEQ_Kho_HOAN','SEQ_Kho_HOAN_CT','SEQ_Kho_DIEU_CHINH','SEQ_Kho_DIEU_CHINH_CT'))<>8
 THROW 59114,'Family ID sequence missing.',1;
PRINT N'KHO_V114_VERIFY_OK';
GO
