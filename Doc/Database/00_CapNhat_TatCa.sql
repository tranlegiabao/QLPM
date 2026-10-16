/*
=====================================================================
QLPM MAIN - CAP NHAT DATABASE HIEN TAI

Nguon contract:
- QuanLyPhongMach/Data/QlpmDbContext.cs
- QuanLyPhongMach/Entities
- Cac loi goi STO trong Controllers cua nhanh main

Pham vi:
- Chi cap nhat database QLPM dang ton tai.
- Khong tao database moi.
- Main dung schema canonical rieng; DSS/AHP legacy bi xoa khoi DB main va se lam lai sau.
- Co the chay lai; version 114 chi duoc ghi sau khi verifier dat.

Chay TU DUNG THU MUC GOC cua checkout dang can deploy.
PowerShell:
    Set-Location "D:\project\QLPM"
    chcp 65001 > $null
    [Console]::InputEncoding  = [System.Text.UTF8Encoding]::new()
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
    sqlcmd -S <server> -d master -E -C -b -f i:65001,o:65001 -i ".\Doc\Database\00_CapNhat_TatCa.sql"

Tat ca :r ben duoi dung duong dan tuong doi de khong vo tinh doc file
tu mot checkout D:\project\QLPM khac/stale.
=====================================================================
*/

:ON ERROR EXIT

USE [master];
GO

/* Fail-fast neu sqlcmd doc file UTF-8 sai. Message loi co y dung ASCII
   de van doc duoc ngay ca khi terminal dang sai code page. */
IF UNICODE(N'ế')<>7871 OR UNICODE(N'đ')<>273 OR UNICODE(N'ữ')<>7919
    THROW 59000,'UTF8 DECODE FAILED. Run sqlcmd with -f i:65001,o:65001 from the repository root.',1;
GO

IF DB_ID(N'QLPM') IS NULL
    THROW 59000,N'Khong tim thay database QLPM. Bo script main nay khong ho tro tao database moi.',1;
GO

USE [QLPM];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

EXEC sys.sp_set_session_context @key=N'QLPM_MAIN_VERIFIED',@value=NULL;
GO

DECLARE @Loi NVARCHAR(MAX)=N'';

IF DB_NAME()<>N'QLPM'
    SET @Loi+=N'- Sai database dich; bat buoc la QLPM.'+CHAR(13)+CHAR(10);

IF OBJECT_ID(N'dbo.DM_CSKCB',N'U') IS NULL
    SET @Loi+=N'- Thieu bang loi DM_CSKCB.'+CHAR(13)+CHAR(10);
IF OBJECT_ID(N'dbo.DM_NhanVien',N'U') IS NULL
    SET @Loi+=N'- Thieu bang loi DM_NhanVien.'+CHAR(13)+CHAR(10);
IF OBJECT_ID(N'dbo.QL_BenhNhan',N'U') IS NULL
    SET @Loi+=N'- Thieu bang loi QL_BenhNhan.'+CHAR(13)+CHAR(10);
IF OBJECT_ID(N'dbo.QL_VaoVien',N'U') IS NULL
    SET @Loi+=N'- Thieu bang loi QL_VaoVien.'+CHAR(13)+CHAR(10);
IF OBJECT_ID(N'dbo.QL_ChiDinh_CT',N'U') IS NULL
    SET @Loi+=N'- Thieu bang loi QL_ChiDinh_CT.'+CHAR(13)+CHAR(10);
IF COL_LENGTH(N'dbo.QL_BenhNhan',N'IDGioiTinh') IS NULL
 OR COL_LENGTH(N'dbo.QL_BenhNhan',N'GioiTinh') IS NOT NULL
    SET @Loi+=N'- QL_BenhNhan chua o contract IDGioiTinh cua main.'+CHAR(13)+CHAR(10);

IF @Loi<>N''
BEGIN
    RAISERROR(N'PRECHECK QLPM MAIN KHONG DAT:%sUpdater dung lai truoc khi thay doi schema.',16,1,@Loi);
    RETURN;
END;
GO

/* v114 consolidation must already have been applied by the guarded runner.
   The full updater is not atomic and therefore must not perform the destructive cutover. */
IF OBJECT_ID(N'dbo.QL_Kho_ChungTu',N'U') IS NULL
 OR NOT EXISTS(SELECT 1 FROM dbo.QLPM_SchemaVersion WHERE VersionNo=114)
 THROW 59114,N'Run Invoke-KhoV114.ps1 -Apply with a verified backup before the full updater.',1;
GO

:r ".\Doc\Database\01_main_schema_contract.sql"
:r ".\Doc\Database\40_ht_config_thu_cong_kham_v99.sql"

/* Refresh STO tiep nhan/kham truoc cleanup pha huy schema.
   Ly do: DB cu co the con STO tham chieu cot legacy (vd HuongDieuTri).
   Neu DROP cot truoc CREATE OR ALTER STO thi SQL Server co the compile module cu
   va dung updater giua chung. */
:r ".\Doc\Database\02_main_sto_tiep_nhan_kham.sql"

/* Hieu_05/10 runtime /kho còn dùng 2 STO phân nhóm thuốc; phải tạo cùng updater
   để checkout branch + chạy 00 không bị lỗi "Could not find stored procedure". */

:r ".\Doc\Database\V114\28_thu_ngan.sql"
:r ".\Doc\Database\V114\31_thu_ngan_kho_v95.sql"

:r ".\Doc\Database\21_he_thong_dia_chi_nhan_vien.sql"
:r ".\Doc\Database\25a_common_nhan_vien_chuc_danh_schema.sql"
:r ".\Doc\Database\24_json_danh_muc_phien_ban.sql"
:r ".\Doc\Database\17_common_cleanup_testahp.sql"
:r ".\Doc\Database\25_common_nhan_vien_nhieu_cskcb_chuc_danh.sql"
:r ".\Doc\Database\26_pdf_only_cls_va_cleanup_schema.sql"
:r ".\Doc\Database\03_main_sto_phac_do.sql"
:r ".\Doc\Database\04_main_sto_cls.sql"
:r ".\Doc\Database\07_auth_dang_nhap_phan_quyen.sql"
:r ".\Doc\Database\08_quan_tri_he_thong.sql"
:r ".\Doc\Database\09_tai_lai_quyen_phien.sql"
:r ".\Doc\Database\10_bao_mat_bootstrap_quan_tri.sql"
:r ".\Doc\Database\11_phan_quyen_mac_dinh.sql"
:r ".\Doc\Database\23_common_viet_tat.sql"
:r ".\Doc\Database\12_sua_stringagg_tai_khoan.sql"
:r ".\Doc\Database\13_khoi_phuc_quyen_admin.sql"
:r ".\Doc\Database\15_common_he_thong_paging.sql"
:r ".\Doc\Database\16_common_cskcb_admin.sql"
:r ".\Doc\Database\19_common_global_admin.sql"

/* Cleanup legacy chay sau khi cac STO canonical da duoc refresh de khong con
   module runtime tham chieu cot/bang sap bi xoa. */
:r ".\Doc\Database\18_main_cleanup_legacy.sql"
:r ".\Doc\Database\27_post_sto_cleanup_orphan_exam_columns.sql"

:r ".\Doc\Database\V114\36_thu_cls_dang_kham_v97.sql"
:r ".\Doc\Database\V114\38_huy_thu_dao_cap_v98.sql"

/* V100 phai tao STO luu ket qua CLS SAU cleanup v85 (file 26) va
   sau cac migration cu. Neu tao truoc, cleanup DROP STO_QL_CLS_*
   se xoa mat STO moi va verifier v100 that bai. */
:r ".\Doc\Database\41_ht_config_thu_tien_chi_dinh_v100.sql"
/* Danh mục mã giảm giá độc lập, đồng bộ 5 mã chuẩn HIS. */
:r ".\Doc\Database\42_dm_ma_giam_gia.sql"

/* Final overlay: chot worklist eligibility sau tat ca override v95-v100. */
:r ".\Doc\Database\V114\43_worklist_eligibility_v100.sql"

/* Drop legacy STO import nhan vien. */
:r ".\Doc\Database\44_remove_nhan_vien_import.sql"
:r ".\Doc\Database\45_toa_thuoc_quoc_gia_v104.sql"
:r ".\Doc\Database\46_tach_ky_so_lien_thong_v105.sql"
:r ".\Doc\Database\V114\47_danh_muc_nha_cung_cap_v106.sql"
:r ".\Doc\Database\48_ky_so_pdf_mau_va_tai_lieu_v107.sql"

:r ".\Doc\Database\49_lien_thong_toa_thuoc_truc_tiep_v108.sql"
:r ".\Doc\Database\50_ky_so_pdf_nghiep_vu_v109.sql"
:r ".\Doc\Database\51_ky_so_pdf_toan_bo_v110.sql"
:r ".\Doc\Database\52_ky_so_pdf_vi_tri_dong_va_ho_so_da_luu_v111.sql"
:r ".\Doc\Database\V114\53_cls_anh_va_in_cap_phat_v112.sql"
:r ".\Doc\Database\V114\54_in_pdf_da_ky_va_chan_phieu_cap_huy_v113.sql"
:r ".\Doc\Database\55_kho_loc_trang_thai_ton.sql"

:r ".\Doc\Database\V114\57_kho_tach_quyen_cap_phat_va_mau_phieu.sql"
:r ".\Doc\Database\V114\58_thao_tac_khong_bat_buoc_ly_do.sql"

:r ".\Doc\Database\60_kho_sto_v114.sql"
:r ".\Doc\Database\62_kho_kiem_tra_v114.sql"
:r ".\Doc\Database\05_kiem_tra_main.sql"
:r ".\Doc\Database\06_chot_phien_ban_main.sql"

PRINT N'QLPM MAIN: CAP NHAT THANH CONG - SCHEMA version 114';
GO
