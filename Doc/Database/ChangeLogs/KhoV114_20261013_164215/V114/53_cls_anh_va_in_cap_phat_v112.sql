/* v114 non-warehouse portion. Warehouse definitions are centralized in 60_kho_sto_v114.sql. */
:ON ERROR EXIT
USE [QLPM];
GO
SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;SET NOCOUNT ON;
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF EXISTS(SELECT 1 FROM sys.check_constraints WHERE name=N'CK_QL_Cls_KetQuaFile')
 ALTER TABLE dbo.QL_ChiDinh_CT DROP CONSTRAINT CK_QL_Cls_KetQuaFile;
EXEC(N'CREATE OR ALTER FUNCTION dbo.FN_Cls_FileDuocHoTro(@Path NVARCHAR(1000))
RETURNS BIT WITH SCHEMABINDING
AS
BEGIN
 SET @Path=LOWER(RTRIM(@Path));
 RETURN CASE WHEN NULLIF(LTRIM(@Path),N'''') IS NULL OR RIGHT(@Path,4) IN(N''.pdf'',N''.jpg'',N''.png'')
 OR RIGHT(@Path,5) IN(N''.jpeg'',N''.webp'') THEN 1 ELSE 0 END;
END;');
ALTER TABLE dbo.QL_ChiDinh_CT WITH CHECK ADD CONSTRAINT CK_QL_Cls_KetQuaFile CHECK(dbo.FN_Cls_FileDuocHoTro(DuongDanKetQua)=1);
COMMIT;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Cls_LuuDuongDanKetQua
    @IDCSKCB BIGINT,
    @IDChiDinhCT BIGINT,
    @DuongDanKetQua NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @DuongDanKetQua=NULLIF(LTRIM(RTRIM(@DuongDanKetQua)),N'');
    IF @IDCSKCB<=0 OR @IDChiDinhCT<=0 OR @DuongDanKetQua IS NULL OR dbo.FN_Cls_FileDuocHoTro(@DuongDanKetQua)=0
       OR @DuongDanKetQua NOT LIKE N'App_Data/cls/'+CONVERT(NVARCHAR(20),@IDCSKCB)+N'/'+CONVERT(NVARCHAR(20),@IDChiDinhCT)+N'/%'
       OR CHARINDEX(N'..',@DuongDanKetQua)>0 OR CHARINDEX(N'\',@DuongDanKetQua)>0 OR CHARINDEX(N':',@DuongDanKetQua)>0
    BEGIN
        SELECT 400 AS Status,N'Dữ liệu file kết quả CLS không hợp lệ.' AS Message,
               CAST(NULL AS NVARCHAR(1000)) AS DuongDanKetQuaCu;
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @IDVaoVien BIGINT,@ThanhTien DECIMAL(18,2),@DuongDanKetQuaCu NVARCHAR(1000);
        SELECT @IDVaoVien=C.IDVaoVien,@ThanhTien=C.ThanhTien,@DuongDanKetQuaCu=C.DuongDanKetQua
        FROM dbo.QL_ChiDinh_CT C WITH(UPDLOCK,HOLDLOCK)
        WHERE C.IDCSKCB=@IDCSKCB AND C.ID=@IDChiDinhCT AND C.Active=1;

        IF @IDVaoVien IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT 404 AS Status,N'Không tìm thấy chỉ định CLS hợp lệ.' AS Message,
                   CAST(NULL AS NVARCHAR(1000)) AS DuongDanKetQuaCu;
            RETURN;
        END;

        /* Quy tắc chung: không sửa dữ liệu CLS sau khi lượt khám đã hoàn tất. */
        IF EXISTS (
            SELECT 1
            FROM dbo.QL_VaoVien V
            WHERE V.IDCSKCB=@IDCSKCB AND V.ID=@IDVaoVien AND V.TrangThaiKham=2
        )
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT 409 AS Status,N'Lượt khám đã hoàn tất; không thể thay đổi file kết quả CLS.' AS Message,
                   @DuongDanKetQuaCu AS DuongDanKetQuaCu;
            RETURN;
        END;

        IF ISNULL
           (
               (SELECT TOP(1) HieuLuc
                FROM dbo.HT_Config
                WHERE IDCSKCB=@IDCSKCB
                  AND MaChucNang=N'THUTIENCHIDINHTRUOC'),
               1
           )=1
           AND
           (
               EXISTS
               (
                   SELECT 1
                   FROM dbo.QL_ThuTien_CT T WITH(UPDLOCK,HOLDLOCK)
                   WHERE T.IDCSKCB=@IDCSKCB
                     AND T.IDChiDinhCT=@IDChiDinhCT
                     AND ISNULL(T.DaThu,0)=0
                     AND ROUND(ISNULL(T.ThucThu,T.ThanhTien),0)>0
               )
               OR
               (
                   ROUND(ISNULL(@ThanhTien,0),0)>0
                   AND NOT EXISTS
                   (
                       SELECT 1
                       FROM dbo.QL_ThuTien_CT T WITH(UPDLOCK,HOLDLOCK)
                       WHERE T.IDCSKCB=@IDCSKCB
                         AND T.IDChiDinhCT=@IDChiDinhCT
                   )
               )
           )
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT 409 AS Status,N'Chỉ định CLS chưa thanh toán. Thu tiền chỉ định trước khi nhập kết quả.' AS Message,
                   @DuongDanKetQuaCu AS DuongDanKetQuaCu;
            RETURN;
        END;

        UPDATE dbo.QL_ChiDinh_CT
        SET DuongDanKetQua=@DuongDanKetQua
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDChiDinhCT AND Active=1;

        COMMIT TRANSACTION;
        SELECT 200 AS Status,N'Đã lưu file kết quả CLS.' AS Message,
               @DuongDanKetQuaCu AS DuongDanKetQuaCu;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        THROW; -- Let the server log the actual SQL exception.
    END CATCH;
END;
GO
CREATE OR ALTER TRIGGER dbo.TR_QL_ChiDinh_CT_KyPdf ON dbo.QL_ChiDinh_CT AFTER INSERT,UPDATE,DELETE
AS
BEGIN
 SET NOCOUNT ON;
 ;WITH Changed AS (SELECT COALESCE(i.IDCSKCB,d.IDCSKCB) IDCSKCB,COALESCE(i.IDVaoVien,d.IDVaoVien) IDVaoVien
 FROM inserted i FULL JOIN deleted d ON i.IDCSKCB=d.IDCSKCB AND i.ID=d.ID
 WHERE i.ID IS NULL OR d.ID IS NULL OR EXISTS(SELECT i.IDVaoVien, i.IDDichVu, i.SoLuong, i.DonGia, i.ThanhTien, i.GuiNgoai, i.NoiGuiNgoai, i.NgayGioChiDinh, i.IDBacSiChiDinh, i.GhiChu, i.Active EXCEPT SELECT d.IDVaoVien, d.IDDichVu, d.SoLuong, d.DonGia, d.ThanhTien, d.GuiNgoai, d.NoiGuiNgoai, d.NgayGioChiDinh, d.IDBacSiChiDinh, d.GhiChu, d.Active))
 UPDATE V SET PhienBanLamSang=V.PhienBanLamSang+1,NgayCapNhatKham=CASE WHEN V.NgayLuuKhamLanDau IS NULL THEN V.NgayCapNhatKham ELSE SYSDATETIME() END
 FROM dbo.QL_VaoVien V JOIN (SELECT DISTINCT IDCSKCB,IDVaoVien FROM Changed) C ON C.IDCSKCB=V.IDCSKCB AND C.IDVaoVien=V.ID;
END;
GO
CREATE OR ALTER TRIGGER dbo.TR_QL_VaoVien_KyPdf ON dbo.QL_VaoVien AFTER UPDATE
AS
BEGIN
 SET NOCOUNT ON;
 ;WITH Changed AS (SELECT COALESCE(i.IDCSKCB,d.IDCSKCB) IDCSKCB,COALESCE(i.ID,d.ID) IDVaoVien
 FROM inserted i FULL JOIN deleted d ON i.IDCSKCB=d.IDCSKCB AND i.ID=d.ID
 WHERE i.ID IS NULL OR d.ID IS NULL OR EXISTS(SELECT i.IDBenhNhan, i.MaVaoVien, i.IDBacSiKham, i.TrieuChung, i.DanDo, i.NgayTaiKham, i.Active EXCEPT SELECT d.IDBenhNhan, d.MaVaoVien, d.IDBacSiKham, d.TrieuChung, d.DanDo, d.NgayTaiKham, d.Active))
 UPDATE V SET PhienBanLamSang=V.PhienBanLamSang+1,NgayCapNhatKham=CASE WHEN V.NgayLuuKhamLanDau IS NULL THEN V.NgayCapNhatKham ELSE SYSDATETIME() END
 FROM dbo.QL_VaoVien V JOIN (SELECT DISTINCT IDCSKCB,IDVaoVien FROM Changed) C ON C.IDCSKCB=V.IDCSKCB AND C.IDVaoVien=V.ID;
END;
GO
CREATE OR ALTER TRIGGER dbo.TR_QL_PhieuSinhHieu_KyPdf ON dbo.QL_PhieuSinhHieu AFTER INSERT,UPDATE,DELETE
AS
BEGIN
 SET NOCOUNT ON;
 ;WITH Changed AS (SELECT COALESCE(i.IDCSKCB,d.IDCSKCB) IDCSKCB,COALESCE(i.IDVaoVien,d.IDVaoVien) IDVaoVien
 FROM inserted i FULL JOIN deleted d ON i.IDCSKCB=d.IDCSKCB AND i.ID=d.ID
 WHERE i.ID IS NULL OR d.ID IS NULL OR EXISTS(SELECT i.IDVaoVien, i.NgayGioDo EXCEPT SELECT d.IDVaoVien, d.NgayGioDo))
 UPDATE V SET PhienBanLamSang=V.PhienBanLamSang+1,NgayCapNhatKham=CASE WHEN V.NgayLuuKhamLanDau IS NULL THEN V.NgayCapNhatKham ELSE SYSDATETIME() END
 FROM dbo.QL_VaoVien V JOIN (SELECT DISTINCT IDCSKCB,IDVaoVien FROM Changed) C ON C.IDCSKCB=V.IDCSKCB AND C.IDVaoVien=V.ID;
END;
GO
CREATE OR ALTER TRIGGER dbo.TR_QL_PhieuSinhHieu_CT_KyPdf ON dbo.QL_PhieuSinhHieu_CT AFTER INSERT,UPDATE,DELETE
AS
BEGIN
 SET NOCOUNT ON;
 ;WITH Changed AS (
 SELECT COALESCE(i.IDCSKCB,d.IDCSKCB) IDCSKCB,COALESCE(i.IDPhieuSinhHieu,d.IDPhieuSinhHieu) IDPhieuSinhHieu
 FROM inserted i FULL JOIN deleted d ON i.IDCSKCB=d.IDCSKCB AND i.ID=d.ID
 WHERE i.ID IS NULL OR d.ID IS NULL OR EXISTS(SELECT i.IDPhieuSinhHieu,i.IDTriSoSinhHieu,i.GiaTri EXCEPT SELECT d.IDPhieuSinhHieu,d.IDTriSoSinhHieu,d.GiaTri))
 UPDATE V SET PhienBanLamSang=V.PhienBanLamSang+1,NgayCapNhatKham=CASE WHEN V.NgayLuuKhamLanDau IS NULL THEN V.NgayCapNhatKham ELSE SYSDATETIME() END
 FROM dbo.QL_VaoVien V JOIN (SELECT DISTINCT P.IDCSKCB,P.IDVaoVien FROM Changed C JOIN dbo.QL_PhieuSinhHieu P
 ON P.IDCSKCB=C.IDCSKCB AND P.ID=C.IDPhieuSinhHieu) X ON X.IDCSKCB=V.IDCSKCB AND X.IDVaoVien=V.ID;
END;
GO
CREATE OR ALTER TRIGGER dbo.TR_QL_BenhNhan_KyPdf ON dbo.QL_BenhNhan AFTER UPDATE
AS
BEGIN
 SET NOCOUNT ON;
 UPDATE V SET PhienBanLamSang=V.PhienBanLamSang+1,NgayCapNhatKham=CASE WHEN V.NgayLuuKhamLanDau IS NULL THEN V.NgayCapNhatKham ELSE SYSDATETIME() END
 FROM dbo.QL_VaoVien V JOIN inserted i ON i.IDCSKCB=V.IDCSKCB AND i.ID=V.IDBenhNhan
 JOIN deleted d ON d.IDCSKCB=i.IDCSKCB AND d.ID=i.ID
 WHERE EXISTS(SELECT i.MaBN,i.HoTen,i.NgaySinh,i.IDGioiTinh,i.SoCCCD,i.DiaChi,i.DienThoai,i.GiamHo_MoiQuanHe,i.GiamHo_HoTen,i.GiamHo_DienThoai,i.GiamHo_SoCCCD EXCEPT SELECT d.MaBN,d.HoTen,d.NgaySinh,d.IDGioiTinh,d.SoCCCD,d.DiaChi,d.DienThoai,d.GiamHo_MoiQuanHe,d.GiamHo_HoTen,d.GiamHo_DienThoai,d.GiamHo_SoCCCD);
END;
GO
PRINT N'53_cls_anh_va_in_cap_phat_v112.sql: OK; no stock movements or external signing.';
GO
