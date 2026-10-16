/*
14_common_cls_tri_so_import.sql
(DEPRECATED / BỎ TRONG v85)
CLS đã chuyển sang mô hình PDF-only.
Không còn sử dụng bảng QL_CLS_DM_TriSoXN, QL_CLS_FormKQXN_CT hoặc import trị số.
*/
USE [QLPM];
GO
SET NOCOUNT ON;
GO

DROP PROCEDURE IF EXISTS dbo.STO_QL_CLS_DM_TriSo_DanhSach;
DROP PROCEDURE IF EXISTS dbo.STO_QL_CLS_DM_TriSo_Import;
GO

PRINT N'14_common_cls_tri_so_import.sql: OK - Deprecated (CLS PDF-only).';
GO
