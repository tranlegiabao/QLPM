/*
44_remove_nhan_vien_import.sql
Gỡ STO import Excel danh sách nhân viên đã ngừng hỗ trợ.
Không xóa bảng hoặc dữ liệu nhân viên.
*/
USE [QLPM];
GO

IF OBJECT_ID(N'dbo.STO_HT_Nhan_Vien_Import_Excel', N'P') IS NOT NULL
    DROP PROCEDURE dbo.STO_HT_Nhan_Vien_Import_Excel;
GO

PRINT N'44_remove_nhan_vien_import.sql: OK';
GO
