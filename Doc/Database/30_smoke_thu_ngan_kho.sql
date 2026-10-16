/*
30_smoke_thu_ngan_kho.sql
Smoke test KHONG ghi dữ liệu cho Thu ngân + Kho.
Chạy sau 00_CapNhat_TatCa.sql.
*/
USE [QLPM];
GO
SET NOCOUNT ON;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.QLPM_SchemaVersion
    WHERE VersionNo=94
)
    THROW 59300,N'Chưa thấy schema v94. Hãy chạy 00_CapNhat_TatCa.sql trước.',1;

DECLARE @RequiredTable TABLE(Name SYSNAME PRIMARY KEY);
INSERT @RequiredTable(Name) VALUES
(N'QL_ThuTien'),(N'QL_ThuTien_CT'),(N'QL_ThuTien_LichSu'),
(N'QL_ThuTien_SoChungTu'),(N'QL_ThuTien_ChungTu'),(N'QL_ThuTien_ChungTu_CT'),
(N'DM_Kho'),(N'DM_NhaCungCap'),(N'DM_Thuoc_DonViQuyDoi'),(N'QL_Kho_LoThuoc'),
(N'QL_Kho_Nhap'),(N'QL_Kho_Nhap_CT'),(N'QL_Kho_Xuat'),(N'QL_Kho_Xuat_CT'),
(N'QL_Kho_Hoan'),(N'QL_Kho_Hoan_CT'),(N'QL_Kho_DieuChinh'),(N'QL_Kho_DieuChinh_CT');

IF EXISTS
(
    SELECT 1
    FROM @RequiredTable R
    WHERE OBJECT_ID(N'dbo.'+R.Name,N'U') IS NULL
)
BEGIN
    SELECT R.Name AS BangThieu
    FROM @RequiredTable R
    WHERE OBJECT_ID(N'dbo.'+R.Name,N'U') IS NULL;
    THROW 59301,N'Thiếu bảng Thu ngân/Kho.',1;
END;

DECLARE @RequiredProc TABLE(Name SYSNAME PRIMARY KEY);
INSERT @RequiredProc(Name) VALUES
(N'STO_QL_ThuNgan_DanhSach'),(N'STO_QL_ThuNgan_ChiTiet'),
(N'STO_QL_ThuNgan_ThuTien'),(N'STO_QL_ThuNgan_DanhSachChungTu'),(N'STO_QL_ThuNgan_ChiTietChungTu'),
(N'STO_QL_ThuNgan_HuyChungTu'),(N'STO_QL_ThuNgan_HoanTien'),
(N'STO_QL_Kho_DanhSachKho'),(N'STO_QL_Kho_TonKho_DanhSach'),
(N'STO_QL_Kho_Nhap'),(N'STO_QL_Kho_Nhap_DanhSach'),(N'STO_QL_Kho_Nhap_ChiTiet'),(N'STO_QL_Kho_Nhap_Huy'),
(N'STO_QL_Kho_LoThuoc_DanhSach'),(N'STO_QL_Kho_DieuChinh_Luu'),(N'STO_QL_Kho_DieuChinh_DanhSach'),
(N'STO_QL_Kho_Xuat_DanhSach'),
(N'STO_QL_Kho_Xuat_ChiTiet'),(N'STO_QL_Kho_Xuat_TheoToa'),
(N'STO_QL_Kho_Xuat_Hoan');

IF EXISTS
(
    SELECT 1
    FROM @RequiredProc R
    WHERE OBJECT_ID(N'dbo.'+R.Name,N'P') IS NULL
)
BEGIN
    SELECT R.Name AS STOThieu
    FROM @RequiredProc R
    WHERE OBJECT_ID(N'dbo.'+R.Name,N'P') IS NULL;
    THROW 59302,N'Thiếu STO Thu ngân/Kho.',1;
END;

IF EXISTS
(
    SELECT 1
    FROM dbo.QL_ThuTien T
    WHERE T.IDTaiKhoanThu IS NULL
      AND EXISTS
      (
          SELECT 1
          FROM dbo.QL_ThuTien_CT CT
          WHERE CT.IDCSKCB=T.IDCSKCB
            AND CT.IDThuTien=T.ID
            AND ISNULL(CT.DaThu,0)=1
      )
)
BEGIN
    SELECT T.IDCSKCB,T.ID,T.IDVaoVien,T.SoPhieu,T.IDNhanVienThu,T.IDTaiKhoanThu
    FROM dbo.QL_ThuTien T
    WHERE T.IDTaiKhoanThu IS NULL
      AND EXISTS
      (
          SELECT 1 FROM dbo.QL_ThuTien_CT CT
          WHERE CT.IDCSKCB=T.IDCSKCB AND CT.IDThuTien=T.ID AND ISNULL(CT.DaThu,0)=1
      );
    THROW 59308,N'Có chứng từ đã phát sinh khoản thu nhưng thiếu tài khoản thực hiện.',1;
END;

IF EXISTS(SELECT 1 FROM dbo.QL_ThuTien WHERE ISNULL(DaHuy,0)=1)
BEGIN
    SELECT * FROM dbo.QL_ThuTien WHERE ISNULL(DaHuy,0)=1;
    THROW 59303,N'QL_ThuTien còn DaHuy=1; bảng tổng hợp chỉ có Chưa thu/Đã thu.',1;
END;

IF EXISTS
(
    SELECT 1
    FROM dbo.QL_ThuTien_CT
    WHERE ISNULL(PhuThu,0)<0
       OR ISNULL(GiamPhanTram,0)<0
       OR ISNULL(GiamPhanTram,0)>100
       OR ISNULL(ThucThu,0)<0
)
BEGIN
    SELECT IDCSKCB,ID,IDThuTien,ThanhTien,PhuThu,GiamPhanTram,TienGiam,ThucThu
    FROM dbo.QL_ThuTien_CT
    WHERE ISNULL(PhuThu,0)<0
       OR ISNULL(GiamPhanTram,0)<0
       OR ISNULL(GiamPhanTram,0)>100
       OR ISNULL(ThucThu,0)<0;
    THROW 59307,N'Có dòng thu tiền vi phạm phụ thu/giảm phần trăm/thực thu.',1;
END;

IF EXISTS
(
    SELECT 1
    FROM dbo.QL_ThuTien_CT
    WHERE ISNULL(DaHuy,0)=1
)
BEGIN
    SELECT IDCSKCB,ID,IDThuTien,DaThu,DaHuy,NgayGioHuy,IDNhanVienHuy,IDTaiKhoanHuy
    FROM dbo.QL_ThuTien_CT
    WHERE ISNULL(DaHuy,0)=1;
    THROW 59309,N'QL_ThuTien_CT còn DaHuy=1; hủy thu phải hoàn tác dòng về Chưa thu.',1;
END;

IF EXISTS
(
    SELECT 1
    FROM dbo.QL_ThuTien T
    CROSS APPLY
    (
        SELECT
            ISNULL(SUM(ROUND(ISNULL(CT.ThanhTien,0),0)+ROUND(ISNULL(CT.PhuThu,0),0)),0) AS Tong,
            ISNULL(SUM(ROUND(ISNULL(CT.TienGiam,0),0)),0) AS Giam,
            ISNULL(SUM(ROUND(ISNULL(CT.ThucThu,0),0)),0) AS Thuc
        FROM dbo.QL_ThuTien_CT CT
        WHERE CT.IDCSKCB=T.IDCSKCB
          AND CT.IDThuTien=T.ID
          AND ISNULL(CT.DaThu,0)=1
    ) X
    WHERE
      (
          ROUND(ISNULL(T.TongTien,0),0)<>ROUND(ISNULL(X.Tong,0),0)
          OR ROUND(ISNULL(T.TienGiam,0),0)<>ROUND(ISNULL(X.Giam,0),0)
          OR ROUND(ISNULL(T.ThucThu,0),0)<>ROUND(ISNULL(X.Thuc,0),0)
      )
)
BEGIN
    THROW 59311,N'Tổng phiếu thu không khớp các dòng còn hiệu lực.',1;
END;

IF EXISTS
(
    SELECT IDCSKCB,IDVaoVien
    FROM dbo.QL_ThuTien
    GROUP BY IDCSKCB,IDVaoVien
    HAVING COUNT(*)>1
)
BEGIN
    SELECT IDCSKCB,IDVaoVien,COUNT(*) AS SoPhieu
    FROM dbo.QL_ThuTien
    GROUP BY IDCSKCB,IDVaoVien
    HAVING COUNT(*)>1;
    THROW 59304,N'Một lượt khám có nhiều hơn một QL_ThuTien hiện hành.',1;
END;

IF EXISTS(SELECT 1 FROM dbo.QL_Kho_LoThuoc WHERE SoLuongTon<0)
BEGIN
    SELECT *
    FROM dbo.QL_Kho_LoThuoc
    WHERE SoLuongTon<0;
    THROW 59305,N'Có tồn kho âm.',1;
END;

IF EXISTS
(
    SELECT 1
    FROM dbo.QL_Kho_Xuat X
    INNER JOIN dbo.QL_Kho_Xuat_CT XCT
      ON XCT.IDCSKCB=X.IDCSKCB AND XCT.IDXuat=X.ID
    LEFT JOIN dbo.QL_ThuTien T
      ON T.IDCSKCB=X.IDCSKCB AND T.IDVaoVien=X.IDVaoVien
    LEFT JOIN dbo.QL_ThuTien_CT PAY
      ON PAY.IDCSKCB=XCT.IDCSKCB
     AND PAY.IDThuTien=T.ID
     AND PAY.IDToaThuocCT=XCT.IDToaThuocCT
     AND ISNULL(PAY.DaThu,0)=1
    WHERE X.DaHuy=0
      AND PAY.ID IS NULL
)
BEGIN
    SELECT X.IDCSKCB,X.ID AS IDXuat,X.IDVaoVien,X.SoPhieu,XCT.IDToaThuocCT
    FROM dbo.QL_Kho_Xuat X
    INNER JOIN dbo.QL_Kho_Xuat_CT XCT
      ON XCT.IDCSKCB=X.IDCSKCB AND XCT.IDXuat=X.ID
    LEFT JOIN dbo.QL_ThuTien T
      ON T.IDCSKCB=X.IDCSKCB AND T.IDVaoVien=X.IDVaoVien
    LEFT JOIN dbo.QL_ThuTien_CT PAY
      ON PAY.IDCSKCB=XCT.IDCSKCB
     AND PAY.IDThuTien=T.ID
     AND PAY.IDToaThuocCT=XCT.IDToaThuocCT
     AND ISNULL(PAY.DaThu,0)=1
    WHERE X.DaHuy=0
      AND PAY.ID IS NULL;
    THROW 59306,N'Có dòng xuất kho còn hiệu lực nhưng dòng toa tương ứng chưa được thu tiền.',1;
END;

/* Tổng quan hai trạng thái Thu ngân theo CSKCB. */
SELECT
    V.IDCSKCB,
    COUNT(*) AS TongLuotKhamXong,
    SUM(CASE WHEN T.ID IS NULL OR ISNULL(S.SoChuaThu,0)>0 OR ISNULL(S.SoDaThu,0)=0 THEN 1 ELSE 0 END) AS ChuaThu,
    SUM(CASE WHEN T.ID IS NOT NULL AND ISNULL(S.SoDaThu,0)>0 AND ISNULL(S.SoChuaThu,0)=0 THEN 1 ELSE 0 END) AS DaThu
FROM dbo.QL_VaoVien V
LEFT JOIN dbo.QL_ThuTien T
  ON T.IDCSKCB=V.IDCSKCB AND T.IDVaoVien=V.ID
OUTER APPLY
(
    SELECT
        SUM(CASE WHEN ISNULL(CT.DaThu,0)=1 THEN 1 ELSE 0 END) AS SoDaThu,
        SUM(CASE WHEN ISNULL(CT.DaThu,0)=0 THEN 1 ELSE 0 END) AS SoChuaThu
    FROM dbo.QL_ThuTien_CT CT
    WHERE CT.IDCSKCB=T.IDCSKCB AND CT.IDThuTien=T.ID
) S
WHERE V.Active=1
  AND V.TrangThaiKham=2
GROUP BY V.IDCSKCB
ORDER BY V.IDCSKCB;

/* Tổng quan kho. */
SELECT
    K.IDCSKCB,
    K.ID AS IDKho,
    K.MaKho,
    K.TenKho,
    COUNT(DISTINCT L.IDThuoc) AS SoThuocCoLo,
    SUM(CASE WHEN L.SoLuongTon>0 THEN L.SoLuongTon ELSE 0 END) AS TongTonCoSo,
    SUM(CASE WHEN L.SoLuongTon>0 AND L.HanDung<CONVERT(DATE,SYSDATETIME()) THEN 1 ELSE 0 END) AS SoLoHetHan,
    SUM(CASE WHEN L.SoLuongTon>0 AND L.HanDung>=CONVERT(DATE,SYSDATETIME())
              AND L.HanDung<=DATEADD(DAY,30,CONVERT(DATE,SYSDATETIME()))
             THEN 1 ELSE 0 END) AS SoLoHetHanTrong30Ngay
FROM dbo.DM_Kho K
LEFT JOIN dbo.QL_Kho_LoThuoc L
  ON L.IDCSKCB=K.IDCSKCB AND L.IDKho=K.ID AND L.Active=1
WHERE K.Active=1
GROUP BY K.IDCSKCB,K.ID,K.MaKho,K.TenKho
ORDER BY K.IDCSKCB,K.ID;

PRINT N'30_smoke_thu_ngan_kho.sql: OK - không phát hiện bất biến tiền/kho bị vi phạm.';
GO
