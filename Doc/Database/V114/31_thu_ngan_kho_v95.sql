/* v114 non-warehouse portion. Warehouse definitions are centralized in 60_kho_sto_v114.sql. */
/* v95 nối tiếp v94. Chạy sau 28/29; không chạy tự động trên DB chưa được duyệt.
   Không suy đoán quy đổi lịch sử. Hoàn kho luôn định danh dòng xuất, lượng cơ sở.
   Không có thao tác tài chính nào tự tăng tồn. */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
/* Chặn cả người gọi trực tiếp SQL, không chỉ đổi tên URL. */
CREATE OR ALTER PROCEDURE dbo.STO_QL_ThuNgan_HuyNhom
    @IDCSKCB BIGINT,@IDVaoVien BIGINT,@Nhom NVARCHAR(20),@IDNhanVienHuy BIGINT=NULL,@IDTaiKhoanHuy BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 410 AS Status,N'Nghiệp vụ legacy chỉ đọc. Hủy theo ID chứng từ.' AS Message;
END;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_ThuNgan_HuyThu
    @IDCSKCB BIGINT,@IDVaoVien BIGINT,@IDNhanVienHuy BIGINT=NULL,@IDTaiKhoanHuy BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 410 AS Status,N'Nghiệp vụ legacy chỉ đọc. Hủy theo ID chứng từ.' AS Message;
END;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_ThuNgan_HuyChungTu
    @IDCSKCB BIGINT,@IDChungTu BIGINT,@LyDo NVARCHAR(500)=NULL,@IDNhanVien BIGINT=NULL,@IDTaiKhoan BIGINT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON; SET @LyDo=COALESCE(NULLIF(LTRIM(RTRIM(@LyDo)),N''),N'Hủy chứng từ thu');
    BEGIN TRY
        BEGIN TRAN;
        IF NOT EXISTS(SELECT 1 FROM dbo.HT_Tai_Khoan WHERE ID=@IDTaiKhoan AND Active=1) THROW 58000,N'Tài khoản thực hiện không hợp lệ.',1;
        DECLARE @IDVaoVien BIGINT,@IDThuTien BIGINT,@Loai VARCHAR(10),@TrangThai TINYINT,@So NVARCHAR(40),@TienMatCT DECIMAL(18,2),@CKCT DECIMAL(18,2);
        SELECT @IDVaoVien=IDVaoVien FROM dbo.QL_ThuTien_ChungTu WHERE IDCSKCB=@IDCSKCB AND ID=@IDChungTu;
        DECLARE @VisitLock BIGINT;
        SELECT @VisitLock=ID FROM dbo.QL_VaoVien WITH(UPDLOCK,HOLDLOCK)
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien AND Active=1;
        IF @VisitLock IS NULL THROW 58000,N'Không tìm thấy lượt khám của chứng từ.',1;
        SELECT @IDVaoVien=IDVaoVien,@IDThuTien=IDThuTien,@Loai=Loai,@TrangThai=TrangThai,@So=SoChungTu,@TienMatCT=TienMat,@CKCT=ChuyenKhoan
        FROM dbo.QL_ThuTien_ChungTu WITH(UPDLOCK,HOLDLOCK) WHERE IDCSKCB=@IDCSKCB AND ID=@IDChungTu;
        IF @IDVaoVien IS NULL THROW 58000,N'Không tìm thấy chứng từ.',1;
        IF @Loai<>'THU' THROW 58000,N'Chỉ hủy trực tiếp chứng từ thu.',1;
        IF @TrangThai<>1 THROW 58000,N'Chứng từ đã hủy.',1;
        IF EXISTS(SELECT 1 FROM dbo.QL_ThuTien_ChungTu WHERE IDChungTuGoc=@IDChungTu AND Loai='HOAN' AND TrangThai=1)
            THROW 58000,N'Chứng từ đã có phiếu hoàn tiền.',1;
        IF EXISTS
        (
            SELECT 1 FROM (SELECT [ID], [IDCSKCB], [IDChungTu] AS [IDXuat], [IDToaThuocCT], [IDThuoc], [IDLoThuoc], [SoLuongCoSo], [GiaVon], [ThanhTien], [SoLuongDaHoan], [IDThuTienChungTuCT], [HeSoQuyDoi] FROM dbo.QL_Kho_ChungTu_CT WITH(UPDLOCK,HOLDLOCK) WHERE LoaiChungTu='CAP_PHAT') X
            INNER JOIN (SELECT [ID], [IDCSKCB], [IDKho], [IDVaoVien], [SoPhieu], [NgayGio] AS [NgayXuat], [IDNhanVien] AS [IDNhanVienXuat], [TongGiaVon], [GhiChu], [DaHuy], [IDTaiKhoan] AS [IDTaiKhoanXuat], [TenNguoiThucHienSnapshot] AS [TenNguoiXuatSnapshot] FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='CAP_PHAT') H ON H.IDCSKCB=X.IDCSKCB AND H.ID=X.IDXuat
            WHERE X.IDCSKCB=@IDCSKCB AND H.IDVaoVien=@IDVaoVien
              AND X.SoLuongCoSo-ISNULL(X.SoLuongDaHoan,0)>0
              AND EXISTS
              (
                  SELECT 1 FROM dbo.QL_ThuTien_ChungTu_CT D
                  INNER JOIN dbo.QL_ThuTien_CT P ON P.ID=D.IDThuTienCT AND P.IDCSKCB=@IDCSKCB
                  WHERE D.IDChungTu=@IDChungTu AND D.Loai=N'THUOC'
                    AND (X.IDThuTienChungTuCT=D.ID OR
                         (X.IDThuTienChungTuCT IS NULL AND X.IDToaThuocCT=P.IDToaThuocCT))
              )
        ) THROW 58000,N'Thuốc của chứng từ này còn đang giao; Kho phải xác nhận nhận lại trước khi xử lý tiền.',1;

        UPDATE dbo.QL_ThuTien_ChungTu SET TrangThai=0,LyDoHuy=@LyDo,NgayGioHuy=SYSDATETIME(),
            IDNhanVienHuy=CASE WHEN ISNULL(@IDNhanVien,0)>0 THEN @IDNhanVien END,IDTaiKhoanHuy=@IDTaiKhoan WHERE ID=@IDChungTu;
        UPDATE CT SET DaThu=0,NgayGioHuy=SYSDATETIME(),IDNhanVienHuy=CASE WHEN ISNULL(@IDNhanVien,0)>0 THEN @IDNhanVien END,IDTaiKhoanHuy=@IDTaiKhoan
        FROM dbo.QL_ThuTien_CT CT INNER JOIN dbo.QL_ThuTien_ChungTu_CT D ON D.IDThuTienCT=CT.ID AND D.IDChungTu=@IDChungTu
        WHERE NOT EXISTS(SELECT 1 FROM dbo.QL_ThuTien_ChungTu C2 INNER JOIN dbo.QL_ThuTien_ChungTu_CT D2 ON D2.IDChungTu=C2.ID
                         WHERE D2.IDThuTienCT=CT.ID AND C2.Loai='THU' AND C2.TrangThai=1 AND C2.ID<>@IDChungTu);
        EXEC dbo.STO_QL_ThuTien_CapNhatTong @IDCSKCB=@IDCSKCB,@IDVaoVien=@IDVaoVien;
        UPDATE T SET TienMat=CASE WHEN T.TienMat>=@TienMatCT THEN T.TienMat-@TienMatCT ELSE 0 END,
            ChuyenKhoan=CASE WHEN T.ChuyenKhoan>=@CKCT THEN T.ChuyenKhoan-@CKCT ELSE 0 END,
            DaThu=CASE WHEN EXISTS(SELECT 1 FROM dbo.QL_ThuTien_CT X WHERE X.IDCSKCB=@IDCSKCB AND X.IDThuTien=@IDThuTien AND X.DaThu=1)
                        AND NOT EXISTS(SELECT 1 FROM dbo.QL_ThuTien_CT X WHERE X.IDCSKCB=@IDCSKCB AND X.IDThuTien=@IDThuTien AND X.DaThu=0) THEN 1 ELSE 0 END
        FROM dbo.QL_ThuTien T
        WHERE T.IDCSKCB=@IDCSKCB AND T.ID=@IDThuTien;
        INSERT dbo.QL_ThuTien_LichSu(IDCSKCB,IDThuTien,IDVaoVien,HanhDong,SoPhieu,NgayGio,IDNhanVien,IDTaiKhoan,GhiChu)
        VALUES(@IDCSKCB,@IDThuTien,@IDVaoVien,N'HUY',@So,SYSDATETIME(),CASE WHEN ISNULL(@IDNhanVien,0)>0 THEN @IDNhanVien END,@IDTaiKhoan,@LyDo);
        COMMIT;
        SELECT 200 AS Status,N'Đã hủy chứng từ thu.' AS Message,@IDChungTu AS IDChungTu,@So AS SoPhieu;
    END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; SELECT 400 AS Status,ERROR_MESSAGE() AS Message; END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_ThuNgan_HoanTien
    @IDCSKCB BIGINT,@IDChungTuGoc BIGINT,@LyDo NVARCHAR(500)=NULL,@IDNhanVien BIGINT=NULL,@IDTaiKhoan BIGINT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON; SET @LyDo=COALESCE(NULLIF(LTRIM(RTRIM(@LyDo)),N''),N'Hoàn tiền chứng từ thu');
    BEGIN TRY
        BEGIN TRAN;
        IF NOT EXISTS(SELECT 1 FROM dbo.HT_Tai_Khoan WHERE ID=@IDTaiKhoan AND Active=1) THROW 58000,N'Tài khoản thực hiện không hợp lệ.',1;
        DECLARE @IDVaoVien BIGINT,@IDThuTien BIGINT,@So NVARCHAR(40),@IDHoan BIGINT,@TienMatCT DECIMAL(18,2),@CKCT DECIMAL(18,2);
        SELECT @IDVaoVien=IDVaoVien FROM dbo.QL_ThuTien_ChungTu WHERE IDCSKCB=@IDCSKCB AND ID=@IDChungTuGoc;
        DECLARE @VisitLock BIGINT;
        SELECT @VisitLock=ID FROM dbo.QL_VaoVien WITH(UPDLOCK,HOLDLOCK)
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien AND Active=1;
        IF @VisitLock IS NULL THROW 58000,N'Không tìm thấy lượt khám của chứng từ.',1;
        SET @IDVaoVien=NULL;
        SELECT @IDVaoVien=IDVaoVien,@IDThuTien=IDThuTien,@TienMatCT=TienMat,@CKCT=ChuyenKhoan FROM dbo.QL_ThuTien_ChungTu WITH(UPDLOCK,HOLDLOCK)
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDChungTuGoc AND Loai='THU' AND TrangThai=1;
        IF @IDVaoVien IS NULL THROW 58000,N'Chứng từ thu gốc không hợp lệ hoặc đã hủy.',1;
        IF EXISTS(SELECT 1 FROM dbo.QL_ThuTien_ChungTu WHERE IDChungTuGoc=@IDChungTuGoc AND Loai='HOAN' AND TrangThai=1)
            THROW 58000,N'Chứng từ đã được hoàn tiền.',1;
        IF EXISTS
        (
            SELECT 1 FROM (SELECT [ID], [IDCSKCB], [IDChungTu] AS [IDXuat], [IDToaThuocCT], [IDThuoc], [IDLoThuoc], [SoLuongCoSo], [GiaVon], [ThanhTien], [SoLuongDaHoan], [IDThuTienChungTuCT], [HeSoQuyDoi] FROM dbo.QL_Kho_ChungTu_CT WITH(UPDLOCK,HOLDLOCK) WHERE LoaiChungTu='CAP_PHAT') X
            INNER JOIN (SELECT [ID], [IDCSKCB], [IDKho], [IDVaoVien], [SoPhieu], [NgayGio] AS [NgayXuat], [IDNhanVien] AS [IDNhanVienXuat], [TongGiaVon], [GhiChu], [DaHuy], [IDTaiKhoan] AS [IDTaiKhoanXuat], [TenNguoiThucHienSnapshot] AS [TenNguoiXuatSnapshot] FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='CAP_PHAT') H ON H.IDCSKCB=X.IDCSKCB AND H.ID=X.IDXuat
            WHERE X.IDCSKCB=@IDCSKCB AND H.IDVaoVien=@IDVaoVien
              AND X.SoLuongCoSo-ISNULL(X.SoLuongDaHoan,0)>0
              AND EXISTS
              (
                  SELECT 1 FROM dbo.QL_ThuTien_ChungTu_CT D
                  INNER JOIN dbo.QL_ThuTien_CT P ON P.ID=D.IDThuTienCT AND P.IDCSKCB=@IDCSKCB
                  WHERE D.IDChungTu=@IDChungTuGoc AND D.Loai=N'THUOC'
                    AND (X.IDThuTienChungTuCT=D.ID OR
                         (X.IDThuTienChungTuCT IS NULL AND X.IDToaThuocCT=P.IDToaThuocCT))
              )
        ) THROW 58000,N'Thuốc của chứng từ này còn đang giao; Kho phải xác nhận nhận lại trước khi xử lý tiền.',1;

        EXEC dbo.STO_QL_ThuNgan_CapSoChungTu @IDCSKCB=@IDCSKCB,@Loai='HOAN',@SoChungTu=@So OUTPUT;
        INSERT dbo.QL_ThuTien_ChungTu(IDCSKCB,IDVaoVien,IDThuTien,Loai,Nhom,IDChungTuGoc,SoChungTu,NgayGio,IDNhanVien,IDTaiKhoan,
                                     TongTien,TienGiam,ThucThu,TienMat,ChuyenKhoan,IDNganHang,GhiChu)
        SELECT IDCSKCB,IDVaoVien,IDThuTien,'HOAN',Nhom,ID,@So,SYSDATETIME(),CASE WHEN ISNULL(@IDNhanVien,0)>0 THEN @IDNhanVien END,@IDTaiKhoan,
               TongTien,TienGiam,ThucThu,TienMat,ChuyenKhoan,IDNganHang,@LyDo FROM dbo.QL_ThuTien_ChungTu WHERE ID=@IDChungTuGoc;
        SET @IDHoan=SCOPE_IDENTITY();
        INSERT dbo.QL_ThuTien_ChungTu_CT(IDChungTu,IDThuTienCT,Loai,Ma,Ten,DonViTinh,SoLuong,DonGia,ThanhTien,PhuThu,GiamPhanTram,TienGiam,ThanhToan)
        SELECT @IDHoan,IDThuTienCT,Loai,Ma,Ten,DonViTinh,SoLuong,DonGia,ThanhTien,PhuThu,GiamPhanTram,TienGiam,ThanhToan
        FROM dbo.QL_ThuTien_ChungTu_CT WHERE IDChungTu=@IDChungTuGoc;
        UPDATE CT SET DaThu=0,NgayGioHuy=SYSDATETIME(),IDNhanVienHuy=CASE WHEN ISNULL(@IDNhanVien,0)>0 THEN @IDNhanVien END,IDTaiKhoanHuy=@IDTaiKhoan
        FROM dbo.QL_ThuTien_CT CT INNER JOIN dbo.QL_ThuTien_ChungTu_CT D ON D.IDThuTienCT=CT.ID AND D.IDChungTu=@IDChungTuGoc;
        EXEC dbo.STO_QL_ThuTien_CapNhatTong @IDCSKCB=@IDCSKCB,@IDVaoVien=@IDVaoVien;
        UPDATE T SET TienMat=CASE WHEN T.TienMat>=@TienMatCT THEN T.TienMat-@TienMatCT ELSE 0 END,
            ChuyenKhoan=CASE WHEN T.ChuyenKhoan>=@CKCT THEN T.ChuyenKhoan-@CKCT ELSE 0 END,
            DaThu=CASE WHEN EXISTS(SELECT 1 FROM dbo.QL_ThuTien_CT X WHERE X.IDCSKCB=@IDCSKCB AND X.IDThuTien=@IDThuTien AND X.DaThu=1)
                        AND NOT EXISTS(SELECT 1 FROM dbo.QL_ThuTien_CT X WHERE X.IDCSKCB=@IDCSKCB AND X.IDThuTien=@IDThuTien AND X.DaThu=0) THEN 1 ELSE 0 END
        FROM dbo.QL_ThuTien T
        WHERE T.IDCSKCB=@IDCSKCB AND T.ID=@IDThuTien;
        COMMIT;
        SELECT 200 AS Status,N'Hoàn tiền thành công.' AS Message,@IDHoan AS IDChungTu,@So AS SoPhieu;
    END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; SELECT 400 AS Status,ERROR_MESSAGE() AS Message; END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_ThuNgan_ChiTietChungTu
    @IDCSKCB BIGINT, @IDChungTu BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT C.ID AS id_chung_tu,C.IDVaoVien AS id_vao_vien,C.Loai AS loai,C.Nhom AS nhom,C.SoChungTu AS so_phieu,
           C.NgayGio AS ngay_gio_thu,C.TrangThai AS trang_thai,C.LyDoHuy AS ly_do_huy,
           B.MaBN AS ma_bn,B.HoTen AS ho_ten,B.DiaChi AS dia_chi,B.DienThoai AS dien_thoai,B.NgaySinh AS ngay_sinh,GT.TenGioiTinh AS gioi_tinh,
           V.MaVaoVien AS ma_vao_vien,COALESCE(NV.HoTen,TK.Ten_Dang_Nhap,N'') AS nhan_vien_thu,
           C.TongTien AS tong_tien,C.TienGiam AS tien_giam,C.ThucThu AS da_thu,
           C.TienMat AS tien_mat,C.ChuyenKhoan AS chuyen_khoan,NH.TenNganHang AS ten_ngan_hang,C.GhiChu AS ghi_chu,
           C.IDChungTuGoc AS id_chung_tu_goc,G.SoChungTu AS so_chung_tu_goc
    FROM dbo.QL_ThuTien_ChungTu C
    INNER JOIN dbo.QL_VaoVien V ON V.IDCSKCB=C.IDCSKCB AND V.ID=C.IDVaoVien
    INNER JOIN dbo.QL_BenhNhan B ON B.IDCSKCB=V.IDCSKCB AND B.ID=V.IDBenhNhan
    LEFT JOIN dbo.DM_GioiTinh GT ON GT.ID=B.IDGioiTinh
    LEFT JOIN dbo.DM_NhanVien NV ON NV.ID=C.IDNhanVien
    LEFT JOIN dbo.HT_Tai_Khoan TK ON TK.ID=C.IDTaiKhoan
    LEFT JOIN dbo.DM_NganHang NH ON NH.ID=C.IDNganHang
    LEFT JOIN dbo.QL_ThuTien_ChungTu G ON G.ID=C.IDChungTuGoc
    WHERE C.IDCSKCB=@IDCSKCB AND C.ID=@IDChungTu;

    SELECT ID AS id,Loai AS loai,Ma AS ma,Ten AS ten,DonViTinh AS don_vi_tinh,
           SoLuong AS so_luong,DonGia AS don_gia,ThanhTien AS thanh_tien,PhuThu AS phu_thu,
           GiamPhanTram AS giam_phan_tram,TienGiam AS tien_giam,ThanhToan AS thanh_toan
    FROM dbo.QL_ThuTien_ChungTu_CT WHERE IDChungTu=@IDChungTu ORDER BY ID;
END;
GO
