/* v114 non-warehouse portion. Warehouse definitions are centralized in 60_kho_sto_v114.sql. */
/* v98: Hủy chứng từ tự đảo cấp thuốc theo đúng dòng chứng từ (luồng HIS).
   Không xóa phiếu cấp/snapshot tiền. Đảo là bút toán hệ thống, KHÔNG phải xác nhận
   nhận thuốc vật lý. Hoàn tiền vẫn giữ luồng riêng v95. Không backfill nguồn legacy.
   Chỉ chạy qua 00_CapNhat_TatCa.sql sau khi xác nhận đích và backup. */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_ThuNgan_DanhSachChungTu
    @IDCSKCB BIGINT, @IDVaoVien BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    /* 1) Chứng từ của lượt khám. */
    SELECT C.ID AS id,C.Loai AS loai,C.Nhom AS nhom,C.SoChungTu AS so_chung_tu,C.NgayGio AS ngay_gio,
           COALESCE(NV.HoTen,TK.Ten_Dang_Nhap,N'') AS nguoi_lap,
           C.TongTien AS tong_tien,C.TienGiam AS tien_giam,C.ThucThu AS thuc_thu,
           C.TienMat AS tien_mat,C.ChuyenKhoan AS chuyen_khoan,NH.TenNganHang AS ten_ngan_hang,
           C.GhiChu AS ghi_chu,C.TrangThai AS trang_thai,C.LyDoHuy AS ly_do_huy,
           C.NgayGioHuy AS ngay_gio_huy,COALESCE(NVH.HoTen,TKH.Ten_Dang_Nhap,N'') AS nguoi_huy,
           C.IDChungTuGoc AS id_chung_tu_goc,G.SoChungTu AS so_chung_tu_goc,
           K.ID AS id_dao_kho,K.SoPhieu AS so_phieu_dao_kho,K.NgayHoan AS ngay_dao_kho
    FROM dbo.QL_ThuTien_ChungTu C
    LEFT JOIN dbo.DM_NhanVien NV ON NV.ID=C.IDNhanVien
    LEFT JOIN dbo.HT_Tai_Khoan TK ON TK.ID=C.IDTaiKhoan
    LEFT JOIN dbo.DM_NganHang NH ON NH.ID=C.IDNganHang
    LEFT JOIN dbo.DM_NhanVien NVH ON NVH.ID=C.IDNhanVienHuy
    LEFT JOIN dbo.HT_Tai_Khoan TKH ON TKH.ID=C.IDTaiKhoanHuy
    LEFT JOIN dbo.QL_ThuTien_ChungTu G ON G.ID=C.IDChungTuGoc
    LEFT JOIN (SELECT [ID], [IDCSKCB], [IDVaoVien], [SoPhieu], [NgayGio] AS [NgayHoan], [IDNhanVien] AS [IDNhanVienHoan], [LyDo], [IDTaiKhoan] AS [IDTaiKhoanHoan], [IDChungTuHuy], [LoaiNghiepVu] AS [Loai], [TenNguoiThucHienSnapshot] AS [TenNguoiHoanSnapshot] FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='HOAN') K ON K.IDCSKCB=C.IDCSKCB AND K.IDChungTuHuy=C.ID AND K.Loai='DAO_CAP_HUY_THU'
    WHERE C.IDCSKCB=@IDCSKCB
      AND C.IDVaoVien=@IDVaoVien
    ORDER BY C.NgayGio DESC,C.ID DESC;

    /* 2) Chi tiết của tất cả chứng từ để UI nhóm giống HIS, không gọi N API. */
    SELECT
        D.IDChungTu AS id_chung_tu,
        D.ID AS id,
        D.Loai AS loai,
        D.Ma AS ma,
        D.Ten AS ten,
        D.DonViTinh AS don_vi_tinh,
        D.SoLuong AS so_luong,
        D.DonGia AS don_gia,
        D.ThanhTien AS thanh_tien,
        D.PhuThu AS phu_thu,
        D.GiamPhanTram AS giam_phan_tram,
        D.TienGiam AS tien_giam,
        D.ThanhToan AS thanh_toan
    FROM dbo.QL_ThuTien_ChungTu_CT D
    INNER JOIN dbo.QL_ThuTien_ChungTu C
        ON C.ID=D.IDChungTu
    WHERE C.IDCSKCB=@IDCSKCB
      AND C.IDVaoVien=@IDVaoVien
      AND C.TrangThai=1
    ORDER BY C.NgayGio DESC,C.ID DESC,D.ID;

    /* 3) Audit lịch sử của lượt thu. HOAN là chứng từ mới nên bổ sung
          từ bảng chứng từ để lịch sử không bỏ sót thao tác hoàn tiền. */
    SELECT H.*
    FROM
    (
        SELECT
            L.ID AS id,
            L.HanhDong AS hanh_dong,
            L.SoPhieu AS so_phieu,
            L.NgayGio AS ngay_gio,
            COALESCE(NV.HoTen,TK.Ten_Dang_Nhap,N'') AS nguoi_thuc_hien,
            L.TongTien AS tong_tien,
            L.TienGiam AS tien_giam,
            L.ThucThu AS thuc_thu,
            L.TienMat AS tien_mat,
            L.ChuyenKhoan AS chuyen_khoan,
            NH.TenNganHang AS ten_ngan_hang,
            L.GhiChu AS ghi_chu,
            CREF.Nhom AS nhom
        FROM dbo.QL_ThuTien_LichSu L
        LEFT JOIN dbo.DM_NhanVien NV ON NV.ID=L.IDNhanVien
        LEFT JOIN dbo.HT_Tai_Khoan TK ON TK.ID=L.IDTaiKhoan
        LEFT JOIN dbo.DM_NganHang NH ON NH.ID=L.IDNganHang
        LEFT JOIN dbo.QL_ThuTien_ChungTu CREF
          ON CREF.IDCSKCB=L.IDCSKCB
         AND CREF.SoChungTu=L.SoPhieu
        WHERE L.IDCSKCB=@IDCSKCB
          AND L.IDVaoVien=@IDVaoVien

        UNION ALL

        SELECT
            -C.ID AS id,
            N'HOAN' AS hanh_dong,
            C.SoChungTu AS so_phieu,
            C.NgayGio AS ngay_gio,
            COALESCE(NV.HoTen,TK.Ten_Dang_Nhap,N'') AS nguoi_thuc_hien,
            C.TongTien AS tong_tien,
            C.TienGiam AS tien_giam,
            C.ThucThu AS thuc_thu,
            C.TienMat AS tien_mat,
            C.ChuyenKhoan AS chuyen_khoan,
            NH.TenNganHang AS ten_ngan_hang,
            C.GhiChu AS ghi_chu,
            C.Nhom AS nhom
        FROM dbo.QL_ThuTien_ChungTu C
        LEFT JOIN dbo.DM_NhanVien NV ON NV.ID=C.IDNhanVien
        LEFT JOIN dbo.HT_Tai_Khoan TK ON TK.ID=C.IDTaiKhoan
        LEFT JOIN dbo.DM_NganHang NH ON NH.ID=C.IDNganHang
        WHERE C.IDCSKCB=@IDCSKCB
          AND C.IDVaoVien=@IDVaoVien
          AND C.Loai='HOAN'
    ) H
    ORDER BY H.ngay_gio DESC,H.id DESC;
END;
GO
/* Helper nội bộ: không commit riêng; caller hủy thu chịu trách nhiệm transaction.
   Thứ tự khóa: lượt -> master tiền -> chứng từ -> dòng cấp -> lô ID tăng dần. */
CREATE OR ALTER PROCEDURE dbo.STO_QL_ThuNgan_DaoCapChungTu
    @IDCSKCB BIGINT,@IDChungTu BIGINT,@IDTaiKhoan BIGINT,@IDNhanVien BIGINT=NULL,
    @IDHoan BIGINT OUTPUT,@SoLuongDaoCoSo DECIMAL(18,4) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @IDHoan=NULL; SET @SoLuongDaoCoSo=0;
    IF XACT_STATE()<>1 OR @@TRANCOUNT=0
        THROW 59800,N'Đảo cấp phải nằm trong transaction hủy chứng từ.',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.HT_Tai_Khoan WHERE ID=@IDTaiKhoan AND Active=1
                  AND (IDCSKCB=@IDCSKCB OR LaQuanTriHeThong=1))
        THROW 59800,N'Tài khoản đảo cấp không thuộc cơ sở hoặc không còn hiệu lực.',1;
    DECLARE @IDVaoVien BIGINT,@SoChungTu NVARCHAR(40),@VisitLock BIGINT;
    SELECT @IDVaoVien=IDVaoVien FROM dbo.QL_ThuTien_ChungTu
    WHERE IDCSKCB=@IDCSKCB AND ID=@IDChungTu AND Loai='THU' AND TrangThai=1;
    SELECT @VisitLock=ID FROM dbo.QL_VaoVien WITH(UPDLOCK,HOLDLOCK)
    WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien AND Active=1;
    IF @VisitLock IS NULL THROW 59800,N'Không tìm thấy lượt khám của chứng từ cần đảo cấp.',1;
    SELECT @SoChungTu=SoChungTu FROM dbo.QL_ThuTien_ChungTu WITH(UPDLOCK,HOLDLOCK)
    WHERE IDCSKCB=@IDCSKCB AND ID=@IDChungTu AND Loai='THU' AND TrangThai=1;
    IF @SoChungTu IS NULL THROW 59800,N'Chứng từ không còn hiệu lực.',1;
    IF EXISTS(SELECT 1 FROM (SELECT [ID], [IDCSKCB], [IDVaoVien], [SoPhieu], [NgayGio] AS [NgayHoan], [IDNhanVien] AS [IDNhanVienHoan], [LyDo], [IDTaiKhoan] AS [IDTaiKhoanHoan], [IDChungTuHuy], [LoaiNghiepVu] AS [Loai], [TenNguoiThucHienSnapshot] AS [TenNguoiHoanSnapshot] FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='HOAN') V114R1 WHERE IDCSKCB=@IDCSKCB AND IDChungTuHuy=@IDChungTu)
        THROW 59800,N'Chứng từ đã có bút toán đảo cấp; cần đối chiếu trạng thái.',1;

    /* Không dùng ID dòng toa để đoán một dòng xuất legacy thuộc phiếu thu nào. */
    IF EXISTS
    (
        SELECT 1 FROM (SELECT [ID], [IDCSKCB], [IDChungTu] AS [IDXuat], [IDToaThuocCT], [IDThuoc], [IDLoThuoc], [SoLuongCoSo], [GiaVon], [ThanhTien], [SoLuongDaHoan], [IDThuTienChungTuCT], [HeSoQuyDoi] FROM dbo.QL_Kho_ChungTu_CT WITH(UPDLOCK,HOLDLOCK) WHERE LoaiChungTu='CAP_PHAT') X
        INNER JOIN (SELECT [ID], [IDCSKCB], [IDKho], [IDVaoVien], [SoPhieu], [NgayGio] AS [NgayXuat], [IDNhanVien] AS [IDNhanVienXuat], [TongGiaVon], [GhiChu], [DaHuy], [IDTaiKhoan] AS [IDTaiKhoanXuat], [TenNguoiThucHienSnapshot] AS [TenNguoiXuatSnapshot] FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='CAP_PHAT') H ON H.IDCSKCB=X.IDCSKCB AND H.ID=X.IDXuat
        WHERE X.IDCSKCB=@IDCSKCB AND H.IDVaoVien=@IDVaoVien
          AND X.IDThuTienChungTuCT IS NULL AND X.SoLuongCoSo>ISNULL(X.SoLuongDaHoan,0)
          AND EXISTS(SELECT 1 FROM dbo.QL_ThuTien_ChungTu_CT D
                     INNER JOIN dbo.QL_ThuTien_CT P ON P.ID=D.IDThuTienCT AND P.IDCSKCB=@IDCSKCB
                     WHERE D.IDChungTu=@IDChungTu AND D.Loai=N'THUOC' AND P.IDToaThuocCT=X.IDToaThuocCT)
    ) THROW 59800,N'Dòng cấp legacy chưa xác định được chứng từ thu. Phải đối chiếu nguồn, không tự đảo tồn.',1;

    IF EXISTS
    (
        SELECT 1 FROM (SELECT [ID], [IDCSKCB], [IDChungTu] AS [IDXuat], [IDToaThuocCT], [IDThuoc], [IDLoThuoc], [SoLuongCoSo], [GiaVon], [ThanhTien], [SoLuongDaHoan], [IDThuTienChungTuCT], [HeSoQuyDoi] FROM dbo.QL_Kho_ChungTu_CT WHERE LoaiChungTu='CAP_PHAT') X
        INNER JOIN (SELECT [ID], [IDCSKCB], [IDKho], [IDVaoVien], [SoPhieu], [NgayGio] AS [NgayXuat], [IDNhanVien] AS [IDNhanVienXuat], [TongGiaVon], [GhiChu], [DaHuy], [IDTaiKhoan] AS [IDTaiKhoanXuat], [TenNguoiThucHienSnapshot] AS [TenNguoiXuatSnapshot] FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='CAP_PHAT') H ON H.IDCSKCB=X.IDCSKCB AND H.ID=X.IDXuat
        INNER JOIN dbo.QL_ThuTien_ChungTu_CT D ON D.ID=X.IDThuTienChungTuCT
        INNER JOIN dbo.QL_ThuTien_CT P ON P.ID=D.IDThuTienCT
        WHERE D.IDChungTu=@IDChungTu AND X.SoLuongCoSo>ISNULL(X.SoLuongDaHoan,0)
          AND (X.IDCSKCB<>@IDCSKCB OR H.IDVaoVien<>@IDVaoVien OR H.DaHuy=1
               OR D.Loai<>N'THUOC' OR P.IDCSKCB<>@IDCSKCB OR P.IDToaThuocCT IS NULL
               OR X.IDToaThuocCT<>P.IDToaThuocCT)
    ) THROW 59800,N'Liên kết chứng từ–dòng cấp không nhất quán; cần đối chiếu trước khi hủy.',1;

    DECLARE @Dao TABLE(IDXuatCT BIGINT PRIMARY KEY,IDXuat BIGINT,IDLoThuoc BIGINT,
                       IDThuoc BIGINT,SoLuong DECIMAL(18,4) NOT NULL);
    INSERT @Dao
    SELECT X.ID,X.IDXuat,X.IDLoThuoc,X.IDThuoc,X.SoLuongCoSo-ISNULL(X.SoLuongDaHoan,0)
    FROM (SELECT [ID], [IDCSKCB], [IDChungTu] AS [IDXuat], [IDToaThuocCT], [IDThuoc], [IDLoThuoc], [SoLuongCoSo], [GiaVon], [ThanhTien], [SoLuongDaHoan], [IDThuTienChungTuCT], [HeSoQuyDoi] FROM dbo.QL_Kho_ChungTu_CT WITH(UPDLOCK,HOLDLOCK) WHERE LoaiChungTu='CAP_PHAT') X
    INNER JOIN (SELECT [ID], [IDCSKCB], [IDKho], [IDVaoVien], [SoPhieu], [NgayGio] AS [NgayXuat], [IDNhanVien] AS [IDNhanVienXuat], [TongGiaVon], [GhiChu], [DaHuy], [IDTaiKhoan] AS [IDTaiKhoanXuat], [TenNguoiThucHienSnapshot] AS [TenNguoiXuatSnapshot] FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='CAP_PHAT') H ON H.IDCSKCB=X.IDCSKCB AND H.ID=X.IDXuat
    INNER JOIN dbo.QL_ThuTien_ChungTu_CT D ON D.ID=X.IDThuTienChungTuCT AND D.IDChungTu=@IDChungTu
    WHERE X.IDCSKCB=@IDCSKCB AND H.IDVaoVien=@IDVaoVien AND H.DaHuy=0
      AND D.Loai=N'THUOC' AND X.SoLuongCoSo>ISNULL(X.SoLuongDaHoan,0);
    IF NOT EXISTS(SELECT 1 FROM @Dao) RETURN;

    DECLARE @IDLo BIGINT,@LockLo BIGINT;
    DECLARE LoCursor CURSOR LOCAL FAST_FORWARD FOR SELECT DISTINCT IDLoThuoc FROM @Dao ORDER BY IDLoThuoc;
    OPEN LoCursor; FETCH NEXT FROM LoCursor INTO @IDLo;
    WHILE @@FETCH_STATUS=0
    BEGIN
        SET @LockLo=NULL;
        SELECT @LockLo=ID FROM dbo.QL_Kho_LoThuoc WITH(UPDLOCK,HOLDLOCK)
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDLo;
        IF @LockLo IS NULL THROW 59800,N'Lô cấp không thuộc cơ sở; không thể đảo tồn.',1;
        FETCH NEXT FROM LoCursor INTO @IDLo;
    END;
    CLOSE LoCursor; DEALLOCATE LoCursor;
    IF EXISTS(SELECT 1 FROM @Dao D INNER JOIN dbo.QL_Kho_LoThuoc L ON L.ID=D.IDLoThuoc
              WHERE L.IDCSKCB<>@IDCSKCB OR L.IDThuoc<>D.IDThuoc)
        THROW 59800,N'Lô và thuốc của dòng cấp không khớp.',1;

    DECLARE @Seq BIGINT=NEXT VALUE FOR dbo.SEQ_SoPhieuHoanKho;
    DECLARE @SoPhieu NVARCHAR(30)=N'HK'+CONVERT(CHAR(8),SYSDATETIME(),112)+RIGHT(N'00000000'+CONVERT(NVARCHAR(20),@Seq),8);
    DECLARE @V114_Hoan BIGINT=NEXT VALUE FOR dbo.SEQ_Kho_HOAN;
        INSERT dbo.QL_Kho_ChungTu(ID,LoaiChungTu,IDCSKCB,IDVaoVien,SoPhieu,NgayGio,IDNhanVien,LyDo,IDTaiKhoan,IDChungTuHuy,LoaiNghiepVu)
        VALUES(@V114_Hoan,'HOAN',@IDCSKCB,@IDVaoVien,@SoPhieu,SYSDATETIME(),@IDNhanVien,
           N'Đảo cấp do hủy chứng từ '+@SoChungTu+N'; không phải xác nhận nhận lại thuốc vật lý.',
           @IDTaiKhoan,@IDChungTu,'DAO_CAP_HUY_THU');
    SET @IDHoan=@V114_Hoan;
    INSERT dbo.QL_Kho_ChungTu_CT(ID,LoaiChungTu,IDCSKCB,LoaiChungTuGoc,IDChungTu,IDChungTuCTGoc,SoLuongCoSo)
        SELECT NEXT VALUE FOR dbo.SEQ_Kho_HOAN_CT,'HOAN',@IDCSKCB,'CAP_PHAT',@IDHoan,IDXuatCT,SoLuong FROM @Dao;
    UPDATE X SET SoLuongDaHoan=ISNULL(X.SoLuongDaHoan,0)+D.SoLuong
    FROM (SELECT [ID], [IDCSKCB], [IDChungTu] AS [IDXuat], [IDToaThuocCT], [IDThuoc], [IDLoThuoc], [SoLuongCoSo], [GiaVon], [ThanhTien], [SoLuongDaHoan], [IDThuTienChungTuCT], [HeSoQuyDoi] FROM dbo.QL_Kho_ChungTu_CT WHERE LoaiChungTu='CAP_PHAT') X INNER JOIN @Dao D ON D.IDXuatCT=X.ID;
    /* Trả đúng lượng cơ sở/lô đã lưu khi cấp; không đọc quy đổi danh mục hiện tại. */
    UPDATE L SET SoLuongTon=L.SoLuongTon+D.SoLuong
    FROM dbo.QL_Kho_LoThuoc L INNER JOIN
      (SELECT IDLoThuoc,SUM(SoLuong) SoLuong FROM @Dao GROUP BY IDLoThuoc) D ON D.IDLoThuoc=L.ID
    WHERE L.IDCSKCB=@IDCSKCB;
    /* Phiếu cấp có dòng thuộc chứng từ khác vẫn còn hiệu lực. */
    UPDATE H SET DaHuy=1 FROM (SELECT [ID], [IDCSKCB], [IDKho], [IDVaoVien], [SoPhieu], [NgayGio] AS [NgayXuat], [IDNhanVien] AS [IDNhanVienXuat], [TongGiaVon], [GhiChu], [DaHuy], [IDTaiKhoan] AS [IDTaiKhoanXuat], [TenNguoiThucHienSnapshot] AS [TenNguoiXuatSnapshot] FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='CAP_PHAT') H
    WHERE H.IDCSKCB=@IDCSKCB AND H.IDVaoVien=@IDVaoVien AND H.DaHuy=0
      AND EXISTS(SELECT 1 FROM @Dao D WHERE D.IDXuat=H.ID)
      AND NOT EXISTS(SELECT 1 FROM (SELECT [ID], [IDCSKCB], [IDChungTu] AS [IDXuat], [IDToaThuocCT], [IDThuoc], [IDLoThuoc], [SoLuongCoSo], [GiaVon], [ThanhTien], [SoLuongDaHoan], [IDThuTienChungTuCT], [HeSoQuyDoi] FROM dbo.QL_Kho_ChungTu_CT WHERE LoaiChungTu='CAP_PHAT') X WHERE X.IDCSKCB=H.IDCSKCB AND X.IDXuat=H.ID
                     AND X.SoLuongCoSo>ISNULL(X.SoLuongDaHoan,0));
    SELECT @SoLuongDaoCoSo=SUM(SoLuong) FROM @Dao;
END;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_ThuNgan_HuyChungTu
    @IDCSKCB BIGINT,@IDChungTu BIGINT,@LyDo NVARCHAR(500)=NULL,@IDNhanVien BIGINT=NULL,@IDTaiKhoan BIGINT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON; SET @LyDo=COALESCE(NULLIF(LTRIM(RTRIM(@LyDo)),N''),N'Hủy chứng từ thu');
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @LaQuanTri BIT,@NhanVienTaiKhoan BIGINT;
        SELECT @LaQuanTri=LaQuanTriHeThong,@NhanVienTaiKhoan=IDNhanVien
        FROM dbo.HT_Tai_Khoan WHERE ID=@IDTaiKhoan AND Active=1
          AND (IDCSKCB=@IDCSKCB OR LaQuanTriHeThong=1);
        IF @LaQuanTri IS NULL THROW 58000,N'Tài khoản không thuộc cơ sở hoặc không còn hiệu lực.',1;
        IF @LaQuanTri=1 SET @IDNhanVien=NULL;
        ELSE IF ISNULL(@IDNhanVien,0)<=0 OR @IDNhanVien<>ISNULL(@NhanVienTaiKhoan,0)
             OR NOT EXISTS(SELECT 1 FROM dbo.DM_NhanVien WHERE ID=@IDNhanVien AND Active=1)
             OR NOT EXISTS(SELECT 1 FROM dbo.DM_NhanVien_CSKCB
                           WHERE IDNhanVien=@IDNhanVien AND IDCSKCB=@IDCSKCB AND Active=1)
            THROW 58000,N'Nhân viên thực hiện không khớp tài khoản.',1;
        DECLARE @IDVaoVien BIGINT,@IDThuTien BIGINT,@Loai VARCHAR(10),@TrangThai TINYINT,
                @So NVARCHAR(40),@TienMatCT DECIMAL(18,2),@CKCT DECIMAL(18,2),@VisitLock BIGINT,
                @TongTienCT DECIMAL(18,2),@TienGiamCT DECIMAL(18,2),@ThucThuCT DECIMAL(18,2);
        SELECT @IDVaoVien=IDVaoVien FROM dbo.QL_ThuTien_ChungTu WHERE IDCSKCB=@IDCSKCB AND ID=@IDChungTu;
        SELECT @VisitLock=ID FROM dbo.QL_VaoVien WITH(UPDLOCK,HOLDLOCK)
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien AND Active=1;
        IF @VisitLock IS NULL THROW 58000,N'Không tìm thấy lượt khám của chứng từ.',1;
        DECLARE @MasterLock BIGINT;
        SELECT @MasterLock=ID FROM dbo.QL_ThuTien WITH(UPDLOCK,HOLDLOCK)
        WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien;
        SET @IDVaoVien=NULL;
        SELECT @IDVaoVien=IDVaoVien,@IDThuTien=IDThuTien,@Loai=Loai,@TrangThai=TrangThai,
               @So=SoChungTu,@TienMatCT=TienMat,@CKCT=ChuyenKhoan,
               @TongTienCT=TongTien,@TienGiamCT=TienGiam,@ThucThuCT=ThucThu
        FROM dbo.QL_ThuTien_ChungTu WITH(UPDLOCK,HOLDLOCK) WHERE IDCSKCB=@IDCSKCB AND ID=@IDChungTu;
        IF @IDVaoVien IS NULL OR @MasterLock IS NULL OR @MasterLock<>@IDThuTien
            THROW 58000,N'Không tìm thấy chứng từ hợp lệ.',1;
        IF @Loai<>'THU' THROW 58000,N'Chỉ hủy trực tiếp chứng từ thu.',1;
        IF @TrangThai<>1 THROW 58000,N'Chứng từ đã hủy.',1;
        IF EXISTS(SELECT 1 FROM dbo.QL_ThuTien_ChungTu WHERE IDChungTuGoc=@IDChungTu AND Loai='HOAN' AND TrangThai=1)
            THROW 58000,N'Chứng từ đã có phiếu hoàn tiền.',1;
        IF EXISTS(SELECT 1 FROM dbo.QL_ThuTien WHERE ID=@IDThuTien AND IDCSKCB=@IDCSKCB
                  AND (TienMat<@TienMatCT OR ChuyenKhoan<@CKCT))
            THROW 58000,N'Tổng tiền lượt không khớp chứng từ; cần đối chiếu trước khi hủy.',1;

        DECLARE @IDHoan BIGINT,@SoLuongDaoCoSo DECIMAL(18,4);
        EXEC dbo.STO_QL_ThuNgan_DaoCapChungTu @IDCSKCB=@IDCSKCB,@IDChungTu=@IDChungTu,
             @IDTaiKhoan=@IDTaiKhoan,@IDNhanVien=@IDNhanVien,
             @IDHoan=@IDHoan OUTPUT,@SoLuongDaoCoSo=@SoLuongDaoCoSo OUTPUT;

        /* Snapshot chứng từ gốc giữ nguyên tiền, lượng, giá; chỉ đổi trạng thái hủy. */
        UPDATE dbo.QL_ThuTien_ChungTu SET TrangThai=0,LyDoHuy=@LyDo,NgayGioHuy=SYSDATETIME(),
            IDNhanVienHuy=@IDNhanVien,IDTaiKhoanHuy=@IDTaiKhoan WHERE IDCSKCB=@IDCSKCB AND ID=@IDChungTu;
        UPDATE CT SET DaThu=0,NgayGioHuy=SYSDATETIME(),IDNhanVienHuy=@IDNhanVien,IDTaiKhoanHuy=@IDTaiKhoan
        FROM dbo.QL_ThuTien_CT CT INNER JOIN dbo.QL_ThuTien_ChungTu_CT D ON D.IDThuTienCT=CT.ID AND D.IDChungTu=@IDChungTu
        WHERE CT.IDCSKCB=@IDCSKCB AND NOT EXISTS
            (SELECT 1 FROM dbo.QL_ThuTien_ChungTu C2 INNER JOIN dbo.QL_ThuTien_ChungTu_CT D2 ON D2.IDChungTu=C2.ID
             WHERE D2.IDThuTienCT=CT.ID AND C2.Loai='THU' AND C2.TrangThai=1 AND C2.ID<>@IDChungTu);
        EXEC dbo.STO_QL_ThuTien_CapNhatTong @IDCSKCB=@IDCSKCB,@IDVaoVien=@IDVaoVien;
        /* CapNhatTong v97 đã tính trạng thái theo eligibility, không ghi đè bằng cờ toàn lượt v94. */
        UPDATE dbo.QL_ThuTien SET
            TienMat=TienMat-@TienMatCT,ChuyenKhoan=ChuyenKhoan-@CKCT
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDThuTien;
        INSERT dbo.QL_ThuTien_LichSu(IDCSKCB,IDThuTien,IDVaoVien,HanhDong,SoPhieu,NgayGio,IDNhanVien,IDTaiKhoan,
                                    TongTien,TienGiam,ThucThu,TienMat,ChuyenKhoan,GhiChu)
        VALUES(@IDCSKCB,@IDThuTien,@IDVaoVien,N'HUY',@So,SYSDATETIME(),@IDNhanVien,@IDTaiKhoan,
               @TongTienCT,@TienGiamCT,@ThucThuCT,@TienMatCT,@CKCT,CASE WHEN @IDHoan IS NULL THEN @LyDo
                   ELSE LEFT(CONCAT(@LyDo,N' [Đảo cấp do hủy thu; ID phiếu kho=',@IDHoan,N']'),500) END);
        COMMIT;
        SELECT 200 AS Status,
               CASE WHEN @IDHoan IS NULL THEN N'Đã hủy chứng từ thu.'
                    ELSE N'Đã đảo cấp thuốc của chứng từ và hủy thu. Không tự hoàn tiền qua ngân hàng.' END AS Message,
               @IDChungTu AS IDChungTu,@So AS SoPhieu,@IDHoan AS IDDaoKho,@SoLuongDaoCoSo AS SoLuongDaoCoSo;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 400 AS Status,ERROR_MESSAGE() AS Message;
    END CATCH;
END;
GO
