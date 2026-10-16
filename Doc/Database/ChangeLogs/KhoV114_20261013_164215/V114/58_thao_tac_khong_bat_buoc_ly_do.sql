/* v114 non-warehouse portion. Warehouse definitions are centralized in 60_kho_sto_v114.sql. */
USE [QLPM];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO
/* Không bắt người dùng nhập lý do; SQL tự ghi nội dung thao tác khi thiếu.
   Giữ quy tắc nghiệp vụ, actor/tenant, lịch sử và các tham số API hiện có.
   Các STO không có màn hình chỉ cập nhật nếu đang tồn tại, không phục hồi chức năng đã bỏ. */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
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
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
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
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
