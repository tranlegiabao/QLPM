/* v114 non-warehouse portion. Warehouse definitions are centralized in 60_kho_sto_v114.sql. */
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
