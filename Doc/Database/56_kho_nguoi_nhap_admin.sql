-- Import actor: global admin uses account identity, never a borrowed employee.
-- Existing documents are preserved; this overlay does not backfill actors.
USE [QLPM];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
IF COL_LENGTH(N'dbo.QL_Kho_Nhap',N'IDTaiKhoanNhap') IS NULL
    ALTER TABLE dbo.QL_Kho_Nhap ADD IDTaiKhoanNhap BIGINT NULL;
IF COL_LENGTH(N'dbo.QL_Kho_Nhap',N'TenNguoiNhapSnapshot') IS NULL
    ALTER TABLE dbo.QL_Kho_Nhap ADD TenNguoiNhapSnapshot NVARCHAR(200) NULL;
IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.QL_Kho_Nhap') AND name=N'IDNhanVienNhap' AND is_nullable=0)
    ALTER TABLE dbo.QL_Kho_Nhap ALTER COLUMN IDNhanVienNhap BIGINT NULL;
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'dbo.QL_Kho_Nhap') AND name=N'FK_QL_Kho_Nhap_TaiKhoanNhap')
    ALTER TABLE dbo.QL_Kho_Nhap WITH CHECK ADD CONSTRAINT FK_QL_Kho_Nhap_TaiKhoanNhap
        FOREIGN KEY(IDTaiKhoanNhap) REFERENCES dbo.HT_Tai_Khoan(ID);
GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_Nhap
    @IDCSKCB BIGINT,
    @IDKho BIGINT,
    @IDNhanVienNhap BIGINT=NULL,
    @IDNhaCungCap BIGINT=NULL,
    @SoHoaDon NVARCHAR(100)=NULL,
    @NgayHoaDon DATE=NULL,
    @GhiChu NVARCHAR(500)=NULL,
    @DanhSachJson NVARCHAR(MAX),
    @IDTaiKhoanNhap BIGINT=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS(SELECT 1 FROM dbo.DM_Kho WHERE IDCSKCB=@IDCSKCB AND ID=@IDKho AND Active=1)
            THROW 58100,N'Kho không hợp lệ.',1;
        /* Audit actor is loaded from the authenticated account, never chosen by payload. */
        DECLARE @LaAdmin BIT,@IDNhanVienTaiKhoan BIGINT,@TenNguoiNhap NVARCHAR(200);
        IF NOT EXISTS(SELECT 1 FROM dbo.DM_CSKCB WHERE ID=@IDCSKCB AND Active=1)
            THROW 58100,N'Cơ sở làm việc không hợp lệ.',1;
        IF @IDTaiKhoanNhap IS NULL
        BEGIN
            -- Older employee-only callers remain valid during application cutover.
            -- A global admin with no employee cannot use this legacy branch.
            SELECT @TenNguoiNhap=N.HoTen
            FROM dbo.DM_NhanVien N
            JOIN dbo.DM_NhanVien_CSKCB M ON M.IDNhanVien=N.ID AND M.IDCSKCB=@IDCSKCB AND M.Active=1
            WHERE N.ID=@IDNhanVienNhap AND N.Active=1;
            IF NULLIF(LTRIM(RTRIM(@TenNguoiNhap)),N'') IS NULL
                THROW 58100,N'Không xác định được nhân viên nhập kho tại cơ sở này.',1;
        END
        ELSE
        BEGIN
        SELECT @LaAdmin=T.LaQuanTriHeThong,@IDNhanVienTaiKhoan=T.IDNhanVien,
               @TenNguoiNhap=CASE WHEN T.LaQuanTriHeThong=1 THEN T.Ten_Dang_Nhap ELSE N.HoTen END
        FROM dbo.HT_Tai_Khoan T
        LEFT JOIN dbo.DM_NhanVien N ON N.ID=T.IDNhanVien AND N.Active=1
        WHERE T.ID=@IDTaiKhoanNhap AND T.Active=1
          AND (T.LaQuanTriHeThong=1 OR T.IDCSKCB=@IDCSKCB);
        IF @LaAdmin IS NULL OR NULLIF(LTRIM(RTRIM(@TenNguoiNhap)),N'') IS NULL
            THROW 58100,N'Tài khoản thực hiện không hợp lệ tại cơ sở này.',1;
        IF @LaAdmin=1
            SET @IDNhanVienNhap=NULL;
        ELSE
        BEGIN
            IF ISNULL(@IDNhanVienNhap,0)<=0 OR @IDNhanVienNhap<>ISNULL(@IDNhanVienTaiKhoan,0)
               OR NOT EXISTS(SELECT 1 FROM dbo.DM_NhanVien_CSKCB
                             WHERE IDNhanVien=@IDNhanVienNhap AND IDCSKCB=@IDCSKCB AND Active=1)
                THROW 58100,N'Nhân viên nhập kho không thuộc tài khoản/cơ sở này.',1;
        END;
        END;
        IF @IDNhaCungCap IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.DM_NhaCungCap WHERE IDCSKCB=@IDCSKCB AND ID=@IDNhaCungCap AND Active=1)
            THROW 58100,N'Nhà cung cấp không hợp lệ.',1;
        IF ISJSON(@DanhSachJson)<>1
            THROW 58100,N'Danh sách nhập kho không hợp lệ.',1;

        DECLARE @CT TABLE
        (
            STT INT IDENTITY(1,1) PRIMARY KEY,
            IDThuoc BIGINT NOT NULL,
            IDDonViTinh BIGINT NOT NULL,
            SoLuong DECIMAL(18,4) NOT NULL,
            GiaNhap DECIMAL(18,2) NOT NULL,
            SoLo NVARCHAR(100) NULL,
            HanDung DATE NULL,
            HeSo DECIMAL(18,6) NULL
        );

        INSERT @CT(IDThuoc,IDDonViTinh,SoLuong,GiaNhap,SoLo,HanDung)
        SELECT
            J.IDThuoc,J.IDDonViTinh,J.SoLuong,J.GiaNhap,
            NULLIF(LTRIM(RTRIM(J.SoLo)),N''),J.HanDung
        FROM OPENJSON(@DanhSachJson)
        WITH
        (
            IDThuoc BIGINT '$.id_thuoc',
            IDDonViTinh BIGINT '$.id_don_vi_tinh',
            SoLuong DECIMAL(18,4) '$.so_luong',
            GiaNhap DECIMAL(18,2) '$.gia_nhap',
            SoLo NVARCHAR(100) '$.so_lo',
            HanDung DATE '$.han_dung'
        ) J
        WHERE J.IDThuoc IS NOT NULL;

        IF NOT EXISTS(SELECT 1 FROM @CT)
            THROW 58100,N'Chưa có thuốc nhập kho.',1;
        IF EXISTS(SELECT 1 FROM @CT WHERE SoLuong<=0 OR GiaNhap<0)
            THROW 58100,N'Số lượng hoặc giá nhập không hợp lệ.',1;
        IF EXISTS(SELECT 1 FROM @CT WHERE HanDung IS NOT NULL AND HanDung<CONVERT(DATE,SYSDATETIME()))
            THROW 58100,N'Không được nhập lô thuốc đã hết hạn.',1;
        IF EXISTS
        (
            SELECT 1 FROM @CT C
            WHERE NOT EXISTS
            (
                SELECT 1 FROM dbo.DM_Thuoc T
                WHERE T.IDCSKCB=@IDCSKCB AND T.ID=C.IDThuoc AND T.Active=1
            )
        )
            THROW 58100,N'Có thuốc không thuộc cơ sở hoặc đã ngừng hoạt động.',1;

        UPDATE C
        SET HeSo=Q.HeSoQuyDoi
        FROM @CT C
        INNER JOIN dbo.DM_Thuoc_DonViQuyDoi Q
          ON Q.IDCSKCB=@IDCSKCB
         AND Q.IDThuoc=C.IDThuoc
         AND Q.IDDonViTinh=C.IDDonViTinh
         AND Q.Active=1;

        IF EXISTS(SELECT 1 FROM @CT WHERE HeSo IS NULL OR HeSo<=0)
            THROW 58100,N'Có thuốc chưa cấu hình quy đổi đơn vị tính.',1;

        DECLARE @Seq BIGINT=NEXT VALUE FOR dbo.SEQ_SoPhieuNhapKho;
        DECLARE @SoPhieu NVARCHAR(30)=N'NK'+CONVERT(CHAR(8),SYSDATETIME(),112)+RIGHT(N'00000000'+CONVERT(NVARCHAR(20),@Seq),8);

        INSERT dbo.QL_Kho_Nhap(IDCSKCB,IDKho,SoPhieu,SoHoaDon,NgayHoaDon,IDNhaCungCap,NgayNhap,IDNhanVienNhap,TongTien,GhiChu,DaHuy,IDTaiKhoanNhap,TenNguoiNhapSnapshot)
        SELECT @IDCSKCB,@IDKho,@SoPhieu,NULLIF(LTRIM(RTRIM(@SoHoaDon)),N''),@NgayHoaDon,@IDNhaCungCap,SYSDATETIME(),@IDNhanVienNhap,
               SUM(SoLuong*GiaNhap),NULLIF(LTRIM(RTRIM(@GhiChu)),N''),0,@IDTaiKhoanNhap,@TenNguoiNhap
        FROM @CT;

        DECLARE @IDNhap BIGINT=SCOPE_IDENTITY();
        DECLARE @STT INT,@IDThuoc BIGINT,@IDDVT BIGINT,@SL DECIMAL(18,4),@Gia DECIMAL(18,2),@SoLo NVARCHAR(100),@HanDung DATE,@HeSo DECIMAL(18,6);
        DECLARE c CURSOR LOCAL FAST_FORWARD FOR
            SELECT STT,IDThuoc,IDDonViTinh,SoLuong,GiaNhap,SoLo,HanDung,HeSo FROM @CT ORDER BY STT;

        OPEN c;
        FETCH NEXT FROM c INTO @STT,@IDThuoc,@IDDVT,@SL,@Gia,@SoLo,@HanDung,@HeSo;
        WHILE @@FETCH_STATUS=0
        BEGIN
            DECLARE @SLCoSo DECIMAL(18,4)=@SL*@HeSo;
            DECLARE @GiaCoSo DECIMAL(18,4)=CASE WHEN @HeSo>0 THEN @Gia/@HeSo ELSE 0 END;
            DECLARE @IDLo BIGINT;
            SET @IDLo=NULL;

            /* Mỗi phiếu nhập giữ lô tồn riêng, kể cả cùng số lô/HSD, để có thể
               chứng minh chính xác lô của phiếu đã phát sinh xuất hay chưa. */
            INSERT dbo.QL_Kho_LoThuoc(IDCSKCB,IDKho,IDThuoc,SoLo,HanDung,GiaNhap,SoLuongNhap,SoLuongTon,NgayNhap,Active)
            VALUES(@IDCSKCB,@IDKho,@IDThuoc,@SoLo,@HanDung,@GiaCoSo,@SLCoSo,@SLCoSo,SYSDATETIME(),1);
            SET @IDLo=SCOPE_IDENTITY();

            INSERT dbo.QL_Kho_Nhap_CT
                (IDCSKCB,IDNhap,IDThuoc,IDDonViTinh,HeSoQuyDoi,SoLuong,SoLuongCoSo,GiaNhap,ThanhTien,SoLo,HanDung,IDLoThuoc)
            VALUES
                (@IDCSKCB,@IDNhap,@IDThuoc,@IDDVT,@HeSo,@SL,@SLCoSo,@Gia,@SL*@Gia,@SoLo,@HanDung,@IDLo);

            FETCH NEXT FROM c INTO @STT,@IDThuoc,@IDDVT,@SL,@Gia,@SoLo,@HanDung,@HeSo;
        END;
        CLOSE c;
        DEALLOCATE c;

        UPDATE CT SET TenThuocSnapshot=T.TenThuoc,MaThuocSnapshot=T.MaThuoc,
                      DonViTinhSnapshot=COALESCE(D.TenDVT,T.DonViTinh)
        FROM dbo.QL_Kho_Nhap_CT CT
        INNER JOIN dbo.DM_Thuoc T ON T.IDCSKCB=CT.IDCSKCB AND T.ID=CT.IDThuoc
        LEFT JOIN dbo.DM_DonViTinh D ON D.IDCSKCB=CT.IDCSKCB AND D.ID=CT.IDDonViTinh
        WHERE CT.IDCSKCB=@IDCSKCB AND CT.IDNhap=@IDNhap;
        UPDATE N SET TenNhaCungCapSnapshot=NCC.TenNhaCungCap
        FROM dbo.QL_Kho_Nhap N LEFT JOIN dbo.DM_NhaCungCap NCC ON NCC.IDCSKCB=N.IDCSKCB AND NCC.ID=N.IDNhaCungCap
        WHERE N.IDCSKCB=@IDCSKCB AND N.ID=@IDNhap;
        COMMIT;
        SELECT 200 AS Status,N'Nhập kho thành công.' AS Message,@IDNhap AS IDNhap,@SoPhieu AS SoPhieu;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local','c')>=-1
        BEGIN
            IF CURSOR_STATUS('local','c')> -1 CLOSE c;
            DEALLOCATE c;
        END;
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 400 AS Status,ERROR_MESSAGE() AS Message,CAST(NULL AS BIGINT) AS IDNhap,CAST(NULL AS NVARCHAR(30)) AS SoPhieu;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_Nhap_DanhSach
    @IDCSKCB BIGINT,@TuNgay DATE=NULL,@DenNgay DATE=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT N.ID AS id,N.SoPhieu AS so_phieu,N.NgayNhap AS ngay_nhap,N.SoHoaDon AS so_hoa_don,N.NgayHoaDon AS ngay_hoa_don,
           NCC.TenNhaCungCap AS nha_cung_cap,N.TongTien AS tong_tien,N.DaHuy AS da_huy,N.LyDoHuy AS ly_do_huy,
           COALESCE(NULLIF(N.TenNguoiNhapSnapshot,N''),NV.HoTen,TK.Ten_Dang_Nhap,N'') AS nguoi_nhap,COUNT(CT.ID) AS so_dong
    FROM dbo.QL_Kho_Nhap N
    LEFT JOIN dbo.DM_NhaCungCap NCC ON NCC.IDCSKCB=N.IDCSKCB AND NCC.ID=N.IDNhaCungCap
    LEFT JOIN dbo.DM_NhanVien NV ON NV.ID=N.IDNhanVienNhap
    LEFT JOIN dbo.QL_Kho_Nhap_CT CT ON CT.IDCSKCB=N.IDCSKCB AND CT.IDNhap=N.ID
    LEFT JOIN dbo.HT_Tai_Khoan TK ON TK.ID=N.IDTaiKhoanNhap
    WHERE N.IDCSKCB=@IDCSKCB AND (@TuNgay IS NULL OR N.NgayNhap>=@TuNgay) AND (@DenNgay IS NULL OR N.NgayNhap<DATEADD(DAY,1,@DenNgay))
    GROUP BY N.ID,N.SoPhieu,N.NgayNhap,N.SoHoaDon,N.NgayHoaDon,NCC.TenNhaCungCap,N.TongTien,N.DaHuy,N.LyDoHuy,NV.HoTen,N.TenNguoiNhapSnapshot,TK.Ten_Dang_Nhap
    ORDER BY N.NgayNhap DESC,N.ID DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_Nhap_ChiTiet @IDCSKCB BIGINT,@IDNhap BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT N.ID AS id,N.SoPhieu AS so_phieu,N.NgayNhap AS ngay_nhap,N.SoHoaDon AS so_hoa_don,N.NgayHoaDon AS ngay_hoa_don,
           COALESCE(N.TenNhaCungCapSnapshot,NCC.TenNhaCungCap) AS nha_cung_cap,CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.QL_Kho_Nhap_CT D WHERE D.IDCSKCB=N.IDCSKCB AND D.IDNhap=N.ID AND D.TenThuocSnapshot IS NULL)
                     OR (N.IDNhaCungCap IS NOT NULL AND N.TenNhaCungCapSnapshot IS NULL) THEN 1 ELSE 0 END AS BIT) AS la_legacy,
           N.TongTien AS tong_tien,N.GhiChu AS ghi_chu,N.DaHuy AS da_huy,N.LyDoHuy AS ly_do_huy,
           N.NgayGioHuy AS ngay_gio_huy,COALESCE(NULLIF(N.TenNguoiNhapSnapshot,N''),NV.HoTen,TK.Ten_Dang_Nhap,N'') AS nguoi_nhap,COALESCE(NVH.HoTen,N'') AS nguoi_huy
    FROM dbo.QL_Kho_Nhap N LEFT JOIN dbo.DM_NhaCungCap NCC ON NCC.IDCSKCB=N.IDCSKCB AND NCC.ID=N.IDNhaCungCap
    LEFT JOIN dbo.DM_NhanVien NV ON NV.ID=N.IDNhanVienNhap LEFT JOIN dbo.DM_NhanVien NVH ON NVH.ID=N.IDNhanVienHuy
    LEFT JOIN dbo.HT_Tai_Khoan TK ON TK.ID=N.IDTaiKhoanNhap
    WHERE N.IDCSKCB=@IDCSKCB AND N.ID=@IDNhap;
    SELECT CT.ID AS id,CT.IDThuoc AS id_thuoc,COALESCE(CT.MaThuocSnapshot,T.MaThuoc) AS ma_thuoc,COALESCE(CT.TenThuocSnapshot,T.TenThuoc) AS ten_thuoc,COALESCE(CT.DonViTinhSnapshot,DVT.TenDVT) AS don_vi_tinh,
           CT.HeSoQuyDoi AS he_so_quy_doi,CT.SoLuongCoSo AS so_luong_co_so,CT.SoLuong AS so_luong,CT.GiaNhap AS gia_nhap,CT.ThanhTien AS thanh_tien,CT.SoLo AS so_lo,CT.HanDung AS han_dung,
           L.SoLuongNhap AS so_luong_nhap_co_so,L.SoLuongTon AS so_luong_ton_co_so
    FROM dbo.QL_Kho_Nhap_CT CT INNER JOIN dbo.DM_Thuoc T ON T.IDCSKCB=CT.IDCSKCB AND T.ID=CT.IDThuoc
    LEFT JOIN dbo.DM_DonViTinh DVT ON DVT.IDCSKCB=CT.IDCSKCB AND DVT.ID=CT.IDDonViTinh
    INNER JOIN dbo.QL_Kho_LoThuoc L ON L.ID=CT.IDLoThuoc
    WHERE CT.IDCSKCB=@IDCSKCB AND CT.IDNhap=@IDNhap ORDER BY CT.ID;
END;
GO
