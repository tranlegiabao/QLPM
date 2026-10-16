/* READ ONLY. Replace both placeholders with the approved target before running.
   No USE: fail closed rather than switching a mistakenly selected database. */
SET NOCOUNT ON;
DECLARE @ExpectedServer NVARCHAR(128)=N'<CONFIRMED_SERVER>';
DECLARE @ExpectedDatabase SYSNAME=N'<CONFIRMED_DATABASE>';
IF @ExpectedServer=N'<CONFIRMED_SERVER>' OR @ExpectedDatabase=N'<CONFIRMED_DATABASE>'
 OR CONVERT(NVARCHAR(128),SERVERPROPERTY(N'ServerName'))<>@ExpectedServer OR DB_NAME()<>@ExpectedDatabase
    THROW 59701,N'Chưa xác nhận đúng server/database cho verifier v97.',1;

IF OBJECT_ID(N'dbo.FN_QL_ThuTien_DongCoTheThu',N'IF') IS NULL
 OR OBJECT_ID(N'dbo.STO_QL_Cls_DamBaoChiDinh',N'P') IS NULL
 OR OBJECT_ID(N'dbo.STO_QL_ThuTien_DongBoNguon',N'P') IS NULL
    THROW 59701,N'Thiếu contract v97.',1;
IF ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_Luu')),N'') NOT LIKE N'%@KhoaCLS%'
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_ThuNgan_ThuTien')),N'') NOT LIKE N'%FN_QL_ThuTien_DongCoTheThu%'
    THROW 59701,N'Chưa có write guards v97.',1;

SELECT CONVERT(NVARCHAR(128),SERVERPROPERTY(N'ServerName')) AS ServerName,DB_NAME() AS DatabaseName;
SELECT VersionNo,AppliedAt FROM dbo.QLPM_SchemaVersion WHERE VersionNo>=94 ORDER BY VersionNo;
/* Inventory, not auto repair: legacy/missing/duplicate sources require reconciliation. */
SELECT V.IDCSKCB,V.ID AS IDVaoVien,C.ID AS IDChiDinhCT,COUNT(CT.ID) AS SoDongTien
FROM dbo.QL_VaoVien V
INNER JOIN dbo.QL_ChiDinh_CT C ON C.IDCSKCB=V.IDCSKCB AND C.IDVaoVien=V.ID AND C.Active=1 AND C.GuiNgoai=0
LEFT JOIN dbo.QL_ThuTien T ON T.IDCSKCB=V.IDCSKCB AND T.IDVaoVien=V.ID
LEFT JOIN dbo.QL_ThuTien_CT CT ON CT.IDCSKCB=T.IDCSKCB AND CT.IDThuTien=T.ID AND CT.IDChiDinhCT=C.ID
WHERE V.Active=1 AND V.TrangThaiKham IN(1,2)
GROUP BY V.IDCSKCB,V.ID,C.ID HAVING COUNT(CT.ID)<>1;
SELECT CT.IDCSKCB,T.IDVaoVien,CT.ID AS IDThuTienCT,CT.IDChiDinhCT,CT.IDToaThuocCT
FROM dbo.QL_ThuTien_CT CT
INNER JOIN dbo.QL_ThuTien T ON T.IDCSKCB=CT.IDCSKCB AND T.ID=CT.IDThuTien
INNER JOIN dbo.QL_VaoVien V ON V.IDCSKCB=T.IDCSKCB AND V.ID=T.IDVaoVien
CROSS APPLY dbo.FN_QL_ThuTien_DongCoTheThu(V.IDCSKCB,V.ID) E
WHERE E.ID=CT.ID AND V.TrangThaiKham=1 AND E.CoTheThu=1
 AND (CT.IDChiDinhCT IS NULL OR CT.IDToaThuocCT IS NOT NULL OR CT.IDCongKhamCT IS NOT NULL);
SELECT IDCSKCB,Loai,TrangThai,COUNT_BIG(*) AS SoPhieu,SUM(ThucThu) AS ThucThu
FROM dbo.QL_ThuTien_ChungTu GROUP BY IDCSKCB,Loai,TrangThai ORDER BY IDCSKCB,Loai,TrangThai;
SELECT IDCSKCB,IDKho,SUM(SoLuongTon) AS TongTon FROM dbo.QL_Kho_LoThuoc GROUP BY IDCSKCB,IDKho;
PRINT N'v97 readonly inventory complete; this is NOT a runtime/concurrency test.';
