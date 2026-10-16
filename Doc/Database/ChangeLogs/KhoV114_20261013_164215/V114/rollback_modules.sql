SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_XuatKhac_Luu
    @IDCSKCB BIGINT,@Loai VARCHAR(25),@IDNhaCungCap BIGINT=NULL,@NoiNhan NVARCHAR(300)=NULL,
    @LyDo NVARCHAR(500)=NULL,@DanhSachJson NVARCHAR(MAX),@IDTaiKhoan BIGINT,@IDNhanVien BIGINT=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        SET @Loai=UPPER(LTRIM(RTRIM(ISNULL(@Loai,'')))); SET @LyDo=COALESCE(NULLIF(LTRIM(RTRIM(@LyDo)),N''),CASE @Loai WHEN 'NOI_BO' THEN N'Xuất nội bộ' WHEN 'TRA_NHA_CUNG_CAP' THEN N'Trả thuốc cho nhà cung cấp' WHEN 'THANH_LY' THEN N'Thanh lý thuốc' ELSE N'Xuất kho khác' END);
        IF @Loai NOT IN('NOI_BO','TRA_NHA_CUNG_CAP','THANH_LY')
            THROW 59102,N'Loại xuất không hợp lệ.',1;
        IF @Loai='TRA_NHA_CUNG_CAP' AND @IDNhaCungCap IS NULL
            THROW 59102,N'Trả nhà cung cấp phải chọn nhà cung cấp.',1;
        DECLARE @IDKho BIGINT,@LaAdmin BIT,@IDNVTK BIGINT,@TenActor NVARCHAR(200);
        SELECT @IDKho=ID FROM dbo.DM_Kho WHERE IDCSKCB=@IDCSKCB AND Active=1;
        IF @IDKho IS NULL THROW 59102,N'CSKCB chưa có kho hoạt động.',1;
        SELECT @LaAdmin=T.LaQuanTriHeThong,@IDNVTK=T.IDNhanVien,@TenActor=CASE WHEN T.LaQuanTriHeThong=1 THEN T.Ten_Dang_Nhap ELSE N.HoTen END
        FROM dbo.HT_Tai_Khoan T LEFT JOIN dbo.DM_NhanVien N ON N.ID=T.IDNhanVien AND N.Active=1
        WHERE T.ID=@IDTaiKhoan AND T.Active=1 AND (T.LaQuanTriHeThong=1 OR T.IDCSKCB=@IDCSKCB);
        IF @LaAdmin IS NULL OR NULLIF(LTRIM(RTRIM(@TenActor)),N'') IS NULL THROW 59102,N'Tài khoản thực hiện không hợp lệ.',1;
        IF @LaAdmin=1 SET @IDNhanVien=NULL;
        ELSE IF ISNULL(@IDNhanVien,0)<=0 OR @IDNhanVien<>ISNULL(@IDNVTK,0) THROW 59102,N'Nhân viên không thuộc tài khoản.',1;
        IF ISJSON(@DanhSachJson)<>1 OR LEFT(LTRIM(@DanhSachJson),1)<>N'[' THROW 59102,N'Danh sách lô không hợp lệ.',1;

        DECLARE @D TABLE(IDLo BIGINT PRIMARY KEY,SoLuong DECIMAL(18,4),IDThuoc BIGINT,GiaVon DECIMAL(18,4),Ton DECIMAL(18,4));
        INSERT @D(IDLo,SoLuong)
        SELECT id_lo_thuoc,SUM(so_luong_co_so)
        FROM OPENJSON(@DanhSachJson) WITH(id_lo_thuoc BIGINT '$.id_lo_thuoc',so_luong_co_so DECIMAL(18,4) '$.so_luong_co_so')
        GROUP BY id_lo_thuoc;
        IF NOT EXISTS(SELECT 1 FROM @D) OR EXISTS(SELECT 1 FROM @D WHERE IDLo IS NULL OR SoLuong<=0)
            THROW 59102,N'Chưa chọn lô và số lượng xuất hợp lệ.',1;
        UPDATE D SET IDThuoc=L.IDThuoc,GiaVon=L.GiaNhap,Ton=L.SoLuongTon
        FROM @D D INNER JOIN dbo.QL_Kho_LoThuoc L WITH(UPDLOCK,HOLDLOCK) ON L.ID=D.IDLo
        WHERE L.IDCSKCB=@IDCSKCB AND L.IDKho=@IDKho AND L.Active=1 AND L.BiKhoaXuat=0
          AND (L.HanDung IS NULL OR L.HanDung>=CONVERT(DATE,SYSDATETIME()));
        IF EXISTS(SELECT 1 FROM @D WHERE IDThuoc IS NULL) THROW 59102,N'Có lô bị khóa, hết hạn hoặc không thuộc kho.',1;
        IF EXISTS(SELECT 1 FROM @D WHERE SoLuong>Ton) THROW 59102,N'Số lượng xuất vượt tồn vật lý.',1;

        UPDATE dbo.QL_Kho_SoChungTu WITH(UPDLOCK,HOLDLOCK) SET GiaTri=GiaTri+1 WHERE IDCSKCB=@IDCSKCB AND MaLoai=@Loai;
        IF @@ROWCOUNT=0 INSERT dbo.QL_Kho_SoChungTu(IDCSKCB,MaLoai,GiaTri) VALUES(@IDCSKCB,@Loai,1);
        DECLARE @Seq BIGINT=(SELECT GiaTri FROM dbo.QL_Kho_SoChungTu WHERE IDCSKCB=@IDCSKCB AND MaLoai=@Loai);
        DECLARE @Prefix VARCHAR(3)=CASE @Loai WHEN 'NOI_BO' THEN 'NB' WHEN 'TRA_NHA_CUNG_CAP' THEN 'TN' ELSE 'TL' END;
        DECLARE @So NVARCHAR(30)=@Prefix+CONVERT(CHAR(8),SYSDATETIME(),112)+RIGHT('00000000'+CONVERT(VARCHAR(20),@Seq),8);
        INSERT dbo.QL_Kho_XuatKhac(IDCSKCB,IDKho,Loai,SoPhieu,IDNhaCungCap,NoiNhan,LyDo,IDTaiKhoan,IDNhanVien,TenNguoiThucHienSnapshot)
        VALUES(@IDCSKCB,@IDKho,@Loai,@So,@IDNhaCungCap,NULLIF(LTRIM(RTRIM(@NoiNhan)),N''),@LyDo,@IDTaiKhoan,@IDNhanVien,@TenActor);
        DECLARE @ID BIGINT=SCOPE_IDENTITY();
        INSERT dbo.QL_Kho_XuatKhac_CT
        (IDCSKCB,IDXuatKhac,IDLoThuoc,IDThuoc,SoLuongCoSo,GiaVon,ThanhTien,TenThuocSnapshot,MaThuocSnapshot,SoLoSnapshot,HanDungSnapshot)
        SELECT @IDCSKCB,@ID,D.IDLo,D.IDThuoc,D.SoLuong,D.GiaVon,ROUND(D.SoLuong*D.GiaVon,2),T.TenThuoc,T.MaThuoc,L.SoLo,L.HanDung
        FROM @D D INNER JOIN dbo.DM_Thuoc T ON T.IDCSKCB=@IDCSKCB AND T.ID=D.IDThuoc
        INNER JOIN dbo.QL_Kho_LoThuoc L ON L.ID=D.IDLo;
        UPDATE L SET SoLuongTon=L.SoLuongTon-D.SoLuong FROM dbo.QL_Kho_LoThuoc L INNER JOIN @D D ON D.IDLo=L.ID;
        COMMIT;
        SELECT 200 AS Status,N'Đã lập phiếu xuất kho.' AS Message,@ID AS IDChungTu,@So AS SoPhieu;
    END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; SELECT 400 AS Status,ERROR_MESSAGE() AS Message; END CATCH;
END;
GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_XuatKhac_Huy
    @IDCSKCB BIGINT,@IDChungTu BIGINT,@LyDo NVARCHAR(500)=NULL,@IDTaiKhoan BIGINT,@IDNhanVien BIGINT=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        SET @LyDo=COALESCE(NULLIF(LTRIM(RTRIM(@LyDo)),N''),N'Hủy phiếu xuất kho khác');
        DECLARE @TenActor NVARCHAR(200),@LaAdmin BIT,@IDNVTK BIGINT;
        SELECT @LaAdmin=T.LaQuanTriHeThong,@IDNVTK=T.IDNhanVien,@TenActor=CASE WHEN T.LaQuanTriHeThong=1 THEN T.Ten_Dang_Nhap ELSE N.HoTen END
        FROM dbo.HT_Tai_Khoan T LEFT JOIN dbo.DM_NhanVien N ON N.ID=T.IDNhanVien AND N.Active=1
        WHERE T.ID=@IDTaiKhoan AND T.Active=1 AND (T.LaQuanTriHeThong=1 OR T.IDCSKCB=@IDCSKCB);
        IF @LaAdmin IS NULL THROW 59102,N'Tài khoản thực hiện không hợp lệ.',1;
        IF @LaAdmin=1 SET @IDNhanVien=NULL; ELSE IF @IDNhanVien<>@IDNVTK THROW 59102,N'Nhân viên không thuộc tài khoản.',1;
        IF NOT EXISTS(SELECT 1 FROM dbo.QL_Kho_XuatKhac WITH(UPDLOCK,HOLDLOCK) WHERE IDCSKCB=@IDCSKCB AND ID=@IDChungTu AND DaHuy=0)
            THROW 59102,N'Phiếu xuất không tồn tại hoặc đã hủy.',1;
        UPDATE L SET SoLuongTon=L.SoLuongTon+C.SoLuongCoSo
        FROM dbo.QL_Kho_LoThuoc L INNER JOIN dbo.QL_Kho_XuatKhac_CT C ON C.IDLoThuoc=L.ID
        WHERE C.IDCSKCB=@IDCSKCB AND C.IDXuatKhac=@IDChungTu;
        UPDATE dbo.QL_Kho_XuatKhac SET DaHuy=1,NgayHuy=SYSDATETIME(),IDTaiKhoanHuy=@IDTaiKhoan,IDNhanVienHuy=@IDNhanVien,
               TenNguoiHuySnapshot=@TenActor,LyDoHuy=@LyDo
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDChungTu;
        INSERT dbo.QL_Kho_GiaoDich
        (IDCSKCB,IDKho,IDThuoc,IDLoThuoc,LoaiGiaoDich,SoLuong,GiaVon,LoaiChungTu,IDChungTu,IDChungTuCT,IDTaiKhoan,IDNhanVien,TenNguoiThucHienSnapshot,GhiChu)
        SELECT H.IDCSKCB,H.IDKho,C.IDThuoc,C.IDLoThuoc,'DAO_XUAT_KHAC',C.SoLuongCoSo,C.GiaVon,'HUY_XUAT_KHAC',H.ID,C.ID,
               @IDTaiKhoan,@IDNhanVien,@TenActor,@LyDo
        FROM dbo.QL_Kho_XuatKhac H INNER JOIN dbo.QL_Kho_XuatKhac_CT C ON C.IDCSKCB=H.IDCSKCB AND C.IDXuatKhac=H.ID
        WHERE H.IDCSKCB=@IDCSKCB AND H.ID=@IDChungTu;
        COMMIT; SELECT 200 AS Status,N'Đã hủy và đảo phiếu xuất kho.' AS Message,@IDChungTu AS IDChungTu;
    END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; SELECT 400 AS Status,ERROR_MESSAGE() AS Message; END CATCH;
END;
GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_XuatKhac_DanhSach
    @IDCSKCB BIGINT,@TuNgay DATE=NULL,@DenNgay DATE=NULL,@Loai VARCHAR(25)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT H.ID AS id,H.SoPhieu AS so_phieu,H.Loai AS loai,H.NgayGio AS ngay_gio,H.NoiNhan AS noi_nhan,
           COALESCE(H.TenNguoiThucHienSnapshot,N'') AS nguoi_lap,H.LyDo AS ly_do,H.DaHuy AS da_huy,H.LyDoHuy AS ly_do_huy,
           NCC.TenNhaCungCap AS nha_cung_cap,COUNT(C.ID) AS so_dong,SUM(C.SoLuongCoSo) AS tong_so_luong,SUM(C.ThanhTien) AS tong_gia_von
    FROM dbo.QL_Kho_XuatKhac H LEFT JOIN dbo.QL_Kho_XuatKhac_CT C ON C.IDCSKCB=H.IDCSKCB AND C.IDXuatKhac=H.ID
    LEFT JOIN dbo.DM_NhaCungCap NCC ON NCC.IDCSKCB=H.IDCSKCB AND NCC.ID=H.IDNhaCungCap
    WHERE H.IDCSKCB=@IDCSKCB AND (@Loai IS NULL OR H.Loai=@Loai)
      AND (@TuNgay IS NULL OR H.NgayGio>=@TuNgay) AND (@DenNgay IS NULL OR H.NgayGio<DATEADD(DAY,1,@DenNgay))
    GROUP BY H.ID,H.SoPhieu,H.Loai,H.NgayGio,H.NoiNhan,H.TenNguoiThucHienSnapshot,H.LyDo,H.DaHuy,H.LyDoHuy,NCC.TenNhaCungCap
    ORDER BY H.NgayGio DESC,H.ID DESC;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_KhoaLo_Luu
    @IDCSKCB BIGINT,@IDLoThuoc BIGINT,@Khoa BIT,@LyDo NVARCHAR(500)=NULL,@IDTaiKhoan BIGINT,@IDNhanVien BIGINT=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        SET @LyDo=COALESCE(NULLIF(LTRIM(RTRIM(@LyDo)),N''),CASE WHEN @Khoa=1 THEN N'Khóa lô thuốc' ELSE N'Mở khóa lô thuốc' END);
        DECLARE @TenActor NVARCHAR(200),@LaAdmin BIT,@IDNVTK BIGINT;
        SELECT @LaAdmin=T.LaQuanTriHeThong,@IDNVTK=T.IDNhanVien,@TenActor=CASE WHEN T.LaQuanTriHeThong=1 THEN T.Ten_Dang_Nhap ELSE N.HoTen END
        FROM dbo.HT_Tai_Khoan T LEFT JOIN dbo.DM_NhanVien N ON N.ID=T.IDNhanVien AND N.Active=1
        WHERE T.ID=@IDTaiKhoan AND T.Active=1 AND (T.LaQuanTriHeThong=1 OR T.IDCSKCB=@IDCSKCB);
        IF @LaAdmin IS NULL THROW 59102,N'Tài khoản thực hiện không hợp lệ.',1;
        IF @LaAdmin=1 SET @IDNhanVien=NULL; ELSE IF @IDNhanVien<>@IDNVTK THROW 59102,N'Nhân viên không thuộc tài khoản.',1;
        IF NOT EXISTS(SELECT 1 FROM dbo.QL_Kho_LoThuoc WITH(UPDLOCK,HOLDLOCK) WHERE IDCSKCB=@IDCSKCB AND ID=@IDLoThuoc)
            THROW 59102,N'Lô thuốc không thuộc CSKCB.',1;
        /* Active=0 làm các STO FEFO cũ tự loại lô khóa; tồn vật lý vẫn được giữ nguyên. */
        UPDATE dbo.QL_Kho_LoThuoc
        SET BiKhoaXuat=@Khoa,
            LyDoKhoa=CASE WHEN @Khoa=1 THEN @LyDo ELSE NULL END,
            Active=CASE WHEN @Khoa=1 THEN 0 WHEN SoLuongTon>0 THEN 1 ELSE Active END
        WHERE ID=@IDLoThuoc;
        INSERT dbo.QL_Kho_KhoaLo(IDCSKCB,IDLoThuoc,HanhDong,LyDo,IDTaiKhoan,IDNhanVien,TenNguoiThucHienSnapshot)
        VALUES(@IDCSKCB,@IDLoThuoc,CASE WHEN @Khoa=1 THEN 'KHOA' ELSE 'MO_KHOA' END,@LyDo,@IDTaiKhoan,@IDNhanVien,@TenActor);
        COMMIT; SELECT 200 AS Status,N'Đã cập nhật trạng thái lô.' AS Message,@IDLoThuoc AS IDLoThuoc;
    END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; SELECT 400 AS Status,ERROR_MESSAGE() AS Message; END CATCH;
END;
GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_KhoaLo_LichSu
    @IDCSKCB BIGINT,@IDLoThuoc BIGINT=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT K.ID AS id,K.IDLoThuoc AS id_lo_thuoc,T.MaThuoc AS ma_thuoc,T.TenThuoc AS ten_thuoc,L.SoLo AS so_lo,L.HanDung AS han_dung,
           K.HanhDong AS hanh_dong,K.NgayGio AS ngay_gio,K.LyDo AS ly_do,K.TenNguoiThucHienSnapshot AS nguoi_thuc_hien
    FROM dbo.QL_Kho_KhoaLo K INNER JOIN dbo.QL_Kho_LoThuoc L ON L.ID=K.IDLoThuoc
    INNER JOIN dbo.DM_Thuoc T ON T.IDCSKCB=L.IDCSKCB AND T.ID=L.IDThuoc
    WHERE K.IDCSKCB=@IDCSKCB AND (@IDLoThuoc IS NULL OR K.IDLoThuoc=@IDLoThuoc)
    ORDER BY K.NgayGio DESC,K.ID DESC;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER TRIGGER dbo.TR_QL_Kho_Nhap_CT_GiaoDich
ON dbo.QL_Kho_Nhap_CT
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT dbo.QL_Kho_GiaoDich
    (IDCSKCB,IDKho,IDThuoc,IDLoThuoc,LoaiGiaoDich,SoLuong,GiaVon,NgayGiaoDich,LoaiChungTu,IDChungTu,IDChungTuCT,
     IDTaiKhoan,IDNhanVien,TenNguoiThucHienSnapshot,GhiChu)
    SELECT I.IDCSKCB,H.IDKho,I.IDThuoc,I.IDLoThuoc,'NHAP',I.SoLuongCoSo,L.GiaNhap,H.NgayNhap,'NHAP',H.ID,I.ID,
           H.IDTaiKhoanNhap,H.IDNhanVienNhap,COALESCE(NULLIF(H.TenNguoiNhapSnapshot,N''),N'Legacy/SQL caller'),H.GhiChu
    FROM inserted I INNER JOIN dbo.QL_Kho_Nhap H ON H.IDCSKCB=I.IDCSKCB AND H.ID=I.IDNhap
    INNER JOIN dbo.QL_Kho_LoThuoc L ON L.ID=I.IDLoThuoc;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO

/* Helper nội bộ: không commit riêng; caller hủy thu chịu trách nhiệm transaction.
   Thứ tự khóa: lượt -> master tiền -> chứng từ -> dòng cấp -> lô ID tăng dần. */
CREATE   PROCEDURE dbo.STO_QL_ThuNgan_DaoCapChungTu
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
    IF EXISTS(SELECT 1 FROM dbo.QL_Kho_Hoan WHERE IDCSKCB=@IDCSKCB AND IDChungTuHuy=@IDChungTu)
        THROW 59800,N'Chứng từ đã có bút toán đảo cấp; cần đối chiếu trạng thái.',1;

    /* Không dùng ID dòng toa để đoán một dòng xuất legacy thuộc phiếu thu nào. */
    IF EXISTS
    (
        SELECT 1 FROM dbo.QL_Kho_Xuat_CT X WITH(UPDLOCK,HOLDLOCK)
        INNER JOIN dbo.QL_Kho_Xuat H ON H.IDCSKCB=X.IDCSKCB AND H.ID=X.IDXuat
        WHERE X.IDCSKCB=@IDCSKCB AND H.IDVaoVien=@IDVaoVien
          AND X.IDThuTienChungTuCT IS NULL AND X.SoLuongCoSo>ISNULL(X.SoLuongDaHoan,0)
          AND EXISTS(SELECT 1 FROM dbo.QL_ThuTien_ChungTu_CT D
                     INNER JOIN dbo.QL_ThuTien_CT P ON P.ID=D.IDThuTienCT AND P.IDCSKCB=@IDCSKCB
                     WHERE D.IDChungTu=@IDChungTu AND D.Loai=N'THUOC' AND P.IDToaThuocCT=X.IDToaThuocCT)
    ) THROW 59800,N'Dòng cấp legacy chưa xác định được chứng từ thu. Phải đối chiếu nguồn, không tự đảo tồn.',1;

    IF EXISTS
    (
        SELECT 1 FROM dbo.QL_Kho_Xuat_CT X
        INNER JOIN dbo.QL_Kho_Xuat H ON H.IDCSKCB=X.IDCSKCB AND H.ID=X.IDXuat
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
    FROM dbo.QL_Kho_Xuat_CT X WITH(UPDLOCK,HOLDLOCK)
    INNER JOIN dbo.QL_Kho_Xuat H ON H.IDCSKCB=X.IDCSKCB AND H.ID=X.IDXuat
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
    INSERT dbo.QL_Kho_Hoan(IDCSKCB,IDVaoVien,SoPhieu,NgayHoan,IDNhanVienHoan,LyDo,IDTaiKhoanHoan,IDChungTuHuy,Loai)
    VALUES(@IDCSKCB,@IDVaoVien,@SoPhieu,SYSDATETIME(),@IDNhanVien,
           N'Đảo cấp do hủy chứng từ '+@SoChungTu+N'; không phải xác nhận nhận lại thuốc vật lý.',
           @IDTaiKhoan,@IDChungTu,'DAO_CAP_HUY_THU');
    SET @IDHoan=SCOPE_IDENTITY();
    INSERT dbo.QL_Kho_Hoan_CT(IDHoan,IDXuatCT,SoLuongCoSo) SELECT @IDHoan,IDXuatCT,SoLuong FROM @Dao;
    UPDATE X SET SoLuongDaHoan=ISNULL(X.SoLuongDaHoan,0)+D.SoLuong
    FROM dbo.QL_Kho_Xuat_CT X INNER JOIN @Dao D ON D.IDXuatCT=X.ID;
    /* Trả đúng lượng cơ sở/lô đã lưu khi cấp; không đọc quy đổi danh mục hiện tại. */
    UPDATE L SET SoLuongTon=L.SoLuongTon+D.SoLuong
    FROM dbo.QL_Kho_LoThuoc L INNER JOIN
      (SELECT IDLoThuoc,SUM(SoLuong) SoLuong FROM @Dao GROUP BY IDLoThuoc) D ON D.IDLoThuoc=L.ID
    WHERE L.IDCSKCB=@IDCSKCB;
    /* Phiếu cấp có dòng thuộc chứng từ khác vẫn còn hiệu lực. */
    UPDATE H SET DaHuy=1 FROM dbo.QL_Kho_Xuat H
    WHERE H.IDCSKCB=@IDCSKCB AND H.IDVaoVien=@IDVaoVien AND H.DaHuy=0
      AND EXISTS(SELECT 1 FROM @Dao D WHERE D.IDXuat=H.ID)
      AND NOT EXISTS(SELECT 1 FROM dbo.QL_Kho_Xuat_CT X WHERE X.IDCSKCB=H.IDCSKCB AND X.IDXuat=H.ID
                     AND X.SoLuongCoSo>ISNULL(X.SoLuongDaHoan,0));
    SELECT @SoLuongDaoCoSo=SUM(SoLuong) FROM @Dao;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER TRIGGER dbo.TR_QL_Kho_Xuat_CT_GiaoDich
ON dbo.QL_Kho_Xuat_CT
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT dbo.QL_Kho_GiaoDich
    (IDCSKCB,IDKho,IDThuoc,IDLoThuoc,LoaiGiaoDich,SoLuong,GiaVon,NgayGiaoDich,LoaiChungTu,IDChungTu,IDChungTuCT,
     IDTaiKhoan,IDNhanVien,TenNguoiThucHienSnapshot,GhiChu)
    SELECT I.IDCSKCB,H.IDKho,I.IDThuoc,I.IDLoThuoc,'CAP_PHAT',-I.SoLuongCoSo,I.GiaVon,H.NgayXuat,'CAP_PHAT',H.ID,I.ID,
           H.IDTaiKhoanXuat,H.IDNhanVienXuat,COALESCE(NULLIF(H.TenNguoiXuatSnapshot,N''),N'Legacy/SQL caller'),H.GhiChu
    FROM inserted I INNER JOIN dbo.QL_Kho_Xuat H ON H.IDCSKCB=I.IDCSKCB AND H.ID=I.IDXuat;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER TRIGGER dbo.TR_QL_Kho_Hoan_CT_GiaoDich
ON dbo.QL_Kho_Hoan_CT
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT dbo.QL_Kho_GiaoDich
    (IDCSKCB,IDKho,IDThuoc,IDLoThuoc,LoaiGiaoDich,SoLuong,GiaVon,NgayGiaoDich,LoaiChungTu,IDChungTu,IDChungTuCT,
     IDTaiKhoan,IDNhanVien,TenNguoiThucHienSnapshot,GhiChu)
    SELECT H.IDCSKCB,X.IDKho,XC.IDThuoc,XC.IDLoThuoc,
           CASE WHEN H.Loai='DAO_CAP_HUY_THU' THEN 'DAO_CAP_HUY_THU' ELSE 'HOAN' END,
           I.SoLuongCoSo,XC.GiaVon,H.NgayHoan,CASE WHEN H.Loai='DAO_CAP_HUY_THU' THEN 'DAO_CAP_HUY_THU' ELSE 'HOAN' END,H.ID,I.ID,
           H.IDTaiKhoanHoan,H.IDNhanVienHoan,COALESCE(NULLIF(H.TenNguoiHoanSnapshot,N''),N'Legacy/SQL caller'),H.LyDo
    FROM inserted I INNER JOIN dbo.QL_Kho_Hoan H ON H.ID=I.IDHoan
    INNER JOIN dbo.QL_Kho_Xuat_CT XC ON XC.ID=I.IDXuatCT
    INNER JOIN dbo.QL_Kho_Xuat X ON X.IDCSKCB=XC.IDCSKCB AND X.ID=XC.IDXuat;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER TRIGGER dbo.TR_QL_Kho_DieuChinh_CT_GiaoDich
ON dbo.QL_Kho_DieuChinh_CT
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT dbo.QL_Kho_GiaoDich
    (IDCSKCB,IDKho,IDThuoc,IDLoThuoc,LoaiGiaoDich,SoLuong,GiaVon,NgayGiaoDich,LoaiChungTu,IDChungTu,IDChungTuCT,
     IDTaiKhoan,IDNhanVien,TenNguoiThucHienSnapshot,GhiChu)
    SELECT I.IDCSKCB,H.IDKho,L.IDThuoc,I.IDLoThuoc,CASE WHEN H.Loai='HUY_THUOC' THEN 'HUY_THUOC' ELSE 'DIEU_CHINH' END,
           I.SoLuongThayDoi,L.GiaNhap,H.NgayGio,H.Loai,H.ID,I.ID,H.IDTaiKhoan,H.IDNhanVien,
           COALESCE(NULLIF(H.TenNguoiThucHienSnapshot,N''),N'Legacy/SQL caller'),H.LyDo
    FROM inserted I INNER JOIN dbo.QL_Kho_DieuChinh H ON H.IDCSKCB=I.IDCSKCB AND H.ID=I.IDChungTu
    INNER JOIN dbo.QL_Kho_LoThuoc L ON L.ID=I.IDLoThuoc;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER TRIGGER dbo.TR_QL_Kho_XuatKhac_CT_GiaoDich
ON dbo.QL_Kho_XuatKhac_CT
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT dbo.QL_Kho_GiaoDich
    (IDCSKCB,IDKho,IDThuoc,IDLoThuoc,LoaiGiaoDich,SoLuong,GiaVon,NgayGiaoDich,LoaiChungTu,IDChungTu,IDChungTuCT,
     IDTaiKhoan,IDNhanVien,TenNguoiThucHienSnapshot,GhiChu)
    SELECT I.IDCSKCB,H.IDKho,I.IDThuoc,I.IDLoThuoc,
           CASE H.Loai WHEN 'NOI_BO' THEN 'XUAT_NOI_BO' WHEN 'TRA_NHA_CUNG_CAP' THEN 'TRA_NHA_CUNG_CAP' ELSE 'THANH_LY' END,
           -I.SoLuongCoSo,I.GiaVon,H.NgayGio,'XUAT_KHAC',H.ID,I.ID,H.IDTaiKhoan,H.IDNhanVien,H.TenNguoiThucHienSnapshot,H.LyDo
    FROM inserted I INNER JOIN dbo.QL_Kho_XuatKhac H ON H.IDCSKCB=I.IDCSKCB AND H.ID=I.IDXuatKhac;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER TRIGGER dbo.TR_QL_Kho_Nhap_Huy_GiaoDich
ON dbo.QL_Kho_Nhap
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT dbo.QL_Kho_GiaoDich
    (IDCSKCB,IDKho,IDThuoc,IDLoThuoc,LoaiGiaoDich,SoLuong,GiaVon,NgayGiaoDich,LoaiChungTu,IDChungTu,IDChungTuCT,
     IDTaiKhoan,IDNhanVien,TenNguoiThucHienSnapshot,GhiChu)
    SELECT N.IDCSKCB,N.IDKho,C.IDThuoc,C.IDLoThuoc,'DAO_NHAP',-C.SoLuongCoSo,L.GiaNhap,ISNULL(N.NgayGioHuy,SYSDATETIME()),
           'HUY_NHAP',N.ID,C.ID,N.IDTaiKhoanHuy,N.IDNhanVienHuy,COALESCE(NULLIF(N.TenNguoiHuySnapshot,N''),N'Legacy/SQL caller'),N.LyDoHuy
    FROM inserted N INNER JOIN deleted O ON O.ID=N.ID
    INNER JOIN dbo.QL_Kho_Nhap_CT C ON C.IDCSKCB=N.IDCSKCB AND C.IDNhap=N.ID
    INNER JOIN dbo.QL_Kho_LoThuoc L ON L.ID=C.IDLoThuoc
    WHERE O.DaHuy=0 AND N.DaHuy=1;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_KiemKe_LuuNhap
    @IDCSKCB BIGINT,@IDKiemKe BIGINT=NULL,@GhiChu NVARCHAR(500)=NULL,@DanhSachJson NVARCHAR(MAX),
    @IDTaiKhoan BIGINT,@IDNhanVien BIGINT=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @IDKho BIGINT,@LaAdmin BIT,@IDNVTK BIGINT,@TenActor NVARCHAR(200);
        SELECT @IDKho=ID FROM dbo.DM_Kho WHERE IDCSKCB=@IDCSKCB AND Active=1;
        IF @IDKho IS NULL THROW 59102,N'CSKCB chưa có kho hoạt động.',1;
        SELECT @LaAdmin=T.LaQuanTriHeThong,@IDNVTK=T.IDNhanVien,@TenActor=CASE WHEN T.LaQuanTriHeThong=1 THEN T.Ten_Dang_Nhap ELSE N.HoTen END
        FROM dbo.HT_Tai_Khoan T LEFT JOIN dbo.DM_NhanVien N ON N.ID=T.IDNhanVien AND N.Active=1
        WHERE T.ID=@IDTaiKhoan AND T.Active=1 AND (T.LaQuanTriHeThong=1 OR T.IDCSKCB=@IDCSKCB);
        IF @LaAdmin IS NULL THROW 59102,N'Tài khoản thực hiện không hợp lệ.',1;
        IF @LaAdmin=1 SET @IDNhanVien=NULL; ELSE IF @IDNhanVien<>@IDNVTK THROW 59102,N'Nhân viên không thuộc tài khoản.',1;
        IF ISJSON(@DanhSachJson)<>1 OR LEFT(LTRIM(@DanhSachJson),1)<>N'[' THROW 59102,N'Danh sách kiểm kê không hợp lệ.',1;
        DECLARE @D TABLE(IDLo BIGINT PRIMARY KEY,ThucTe DECIMAL(18,4),SoSach DECIMAL(18,4),IDThuoc BIGINT,SoLo NVARCHAR(100),HanDung DATE);
        INSERT @D(IDLo,ThucTe)
        SELECT id_lo_thuoc,so_luong_thuc_te FROM OPENJSON(@DanhSachJson)
        WITH(id_lo_thuoc BIGINT '$.id_lo_thuoc',so_luong_thuc_te DECIMAL(18,4) '$.so_luong_thuc_te');
        IF NOT EXISTS(SELECT 1 FROM @D) OR EXISTS(SELECT 1 FROM @D WHERE IDLo IS NULL OR ThucTe<0)
            THROW 59102,N'Danh sách kiểm kê có dòng không hợp lệ.',1;
        UPDATE D SET SoSach=L.SoLuongTon,IDThuoc=L.IDThuoc,SoLo=L.SoLo,HanDung=L.HanDung
        FROM @D D INNER JOIN dbo.QL_Kho_LoThuoc L ON L.ID=D.IDLo
        WHERE L.IDCSKCB=@IDCSKCB AND L.IDKho=@IDKho;
        IF EXISTS(SELECT 1 FROM @D WHERE IDThuoc IS NULL) THROW 59102,N'Có lô không thuộc kho hiện tại.',1;

        IF ISNULL(@IDKiemKe,0)<=0
        BEGIN
            UPDATE dbo.QL_Kho_SoChungTu WITH(UPDLOCK,HOLDLOCK) SET GiaTri=GiaTri+1 WHERE IDCSKCB=@IDCSKCB AND MaLoai='KIEM_KE';
            IF @@ROWCOUNT=0 INSERT dbo.QL_Kho_SoChungTu(IDCSKCB,MaLoai,GiaTri) VALUES(@IDCSKCB,'KIEM_KE',1);
            DECLARE @Seq BIGINT=(SELECT GiaTri FROM dbo.QL_Kho_SoChungTu WHERE IDCSKCB=@IDCSKCB AND MaLoai='KIEM_KE');
            DECLARE @So NVARCHAR(30)=N'KK'+CONVERT(CHAR(8),SYSDATETIME(),112)+RIGHT('00000000'+CONVERT(VARCHAR(20),@Seq),8);
            INSERT dbo.QL_Kho_KiemKe(IDCSKCB,IDKho,SoPhieu,GhiChu,IDTaiKhoan,IDNhanVien,TenNguoiThucHienSnapshot)
            VALUES(@IDCSKCB,@IDKho,@So,NULLIF(LTRIM(RTRIM(@GhiChu)),N''),@IDTaiKhoan,@IDNhanVien,@TenActor);
            SET @IDKiemKe=SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            IF NOT EXISTS(SELECT 1 FROM dbo.QL_Kho_KiemKe WITH(UPDLOCK,HOLDLOCK) WHERE IDCSKCB=@IDCSKCB AND ID=@IDKiemKe AND TrangThai='NHAP')
                THROW 59102,N'Phiếu kiểm kê không tồn tại hoặc không còn ở trạng thái nháp.',1;
            UPDATE dbo.QL_Kho_KiemKe SET GhiChu=NULLIF(LTRIM(RTRIM(@GhiChu)),N''),IDTaiKhoan=@IDTaiKhoan,IDNhanVien=@IDNhanVien,
                   TenNguoiThucHienSnapshot=@TenActor WHERE ID=@IDKiemKe;
            DELETE dbo.QL_Kho_KiemKe_CT WHERE IDCSKCB=@IDCSKCB AND IDKiemKe=@IDKiemKe;
        END;
        INSERT dbo.QL_Kho_KiemKe_CT(IDCSKCB,IDKiemKe,IDLoThuoc,IDThuoc,SoLuongSoSach,SoLuongThucTe,SoLoSnapshot,HanDungSnapshot)
        SELECT @IDCSKCB,@IDKiemKe,IDLo,IDThuoc,SoSach,ThucTe,SoLo,HanDung FROM @D;
        COMMIT; SELECT 200 AS Status,N'Đã lưu phiếu kiểm kê nháp.' AS Message,@IDKiemKe AS IDKiemKe;
    END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; SELECT 400 AS Status,ERROR_MESSAGE() AS Message; END CATCH;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_KiemKe_Chot
    @IDCSKCB BIGINT,@IDKiemKe BIGINT,@IDTaiKhoan BIGINT,@IDNhanVien BIGINT=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @IDKho BIGINT,@TenActor NVARCHAR(200),@LaAdmin BIT,@IDNVTK BIGINT,@SoKK NVARCHAR(30);
        SELECT @IDKho=IDKho,@SoKK=SoPhieu FROM dbo.QL_Kho_KiemKe WITH(UPDLOCK,HOLDLOCK)
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDKiemKe AND TrangThai='NHAP';
        IF @IDKho IS NULL THROW 59102,N'Phiếu kiểm kê không tồn tại hoặc đã xử lý.',1;
        SELECT @LaAdmin=T.LaQuanTriHeThong,@IDNVTK=T.IDNhanVien,@TenActor=CASE WHEN T.LaQuanTriHeThong=1 THEN T.Ten_Dang_Nhap ELSE N.HoTen END
        FROM dbo.HT_Tai_Khoan T LEFT JOIN dbo.DM_NhanVien N ON N.ID=T.IDNhanVien AND N.Active=1
        WHERE T.ID=@IDTaiKhoan AND T.Active=1 AND (T.LaQuanTriHeThong=1 OR T.IDCSKCB=@IDCSKCB);
        IF @LaAdmin IS NULL THROW 59102,N'Tài khoản thực hiện không hợp lệ.',1;
        IF @LaAdmin=1 SET @IDNhanVien=NULL; ELSE IF @IDNhanVien<>@IDNVTK THROW 59102,N'Nhân viên không thuộc tài khoản.',1;

        DECLARE @D TABLE(IDLo BIGINT PRIMARY KEY,Truoc DECIMAL(18,4),Sau DECIMAL(18,4),ThayDoi DECIMAL(18,4));
        INSERT @D
        SELECT C.IDLoThuoc,L.SoLuongTon,C.SoLuongThucTe,C.SoLuongThucTe-L.SoLuongTon
        FROM dbo.QL_Kho_KiemKe_CT C INNER JOIN dbo.QL_Kho_LoThuoc L WITH(UPDLOCK,HOLDLOCK) ON L.ID=C.IDLoThuoc
        WHERE C.IDCSKCB=@IDCSKCB AND C.IDKiemKe=@IDKiemKe AND L.IDKho=@IDKho;
        IF NOT EXISTS(SELECT 1 FROM @D) THROW 59102,N'Phiếu kiểm kê chưa có chi tiết.',1;
        UPDATE dbo.QL_Kho_SoChungTu WITH(UPDLOCK,HOLDLOCK) SET GiaTri=GiaTri+1 WHERE IDCSKCB=@IDCSKCB AND MaLoai='DIEU_CHINH_KK';
        IF @@ROWCOUNT=0 INSERT dbo.QL_Kho_SoChungTu VALUES(@IDCSKCB,'DIEU_CHINH_KK',1);
        DECLARE @Seq BIGINT=(SELECT GiaTri FROM dbo.QL_Kho_SoChungTu WHERE IDCSKCB=@IDCSKCB AND MaLoai='DIEU_CHINH_KK');
        DECLARE @So NVARCHAR(30)=N'DC'+CONVERT(CHAR(8),SYSDATETIME(),112)+RIGHT('00000000'+CONVERT(VARCHAR(20),@Seq),8);
        INSERT dbo.QL_Kho_DieuChinh(IDCSKCB,IDKho,Loai,SoPhieu,NgayGio,IDNhanVien,LyDo,IDTaiKhoan,TenNguoiThucHienSnapshot)
        VALUES(@IDCSKCB,@IDKho,'DIEU_CHINH',@So,SYSDATETIME(),@IDNhanVien,N'Chốt kiểm kê '+@SoKK,@IDTaiKhoan,@TenActor);
        DECLARE @IDDieuChinh BIGINT=SCOPE_IDENTITY();
        INSERT dbo.QL_Kho_DieuChinh_CT(IDCSKCB,IDChungTu,IDLoThuoc,SoLuongThayDoi,SoLuongTruoc,SoLuongSau)
        SELECT @IDCSKCB,@IDDieuChinh,IDLo,ThayDoi,Truoc,Sau FROM @D WHERE ThayDoi<>0;
        UPDATE L SET SoLuongTon=D.Sau FROM dbo.QL_Kho_LoThuoc L INNER JOIN @D D ON D.IDLo=L.ID;
        UPDATE dbo.QL_Kho_KiemKe SET TrangThai='DA_CHOT',NgayChot=SYSDATETIME(),IDDieuChinh=@IDDieuChinh,
               IDTaiKhoan=@IDTaiKhoan,IDNhanVien=@IDNhanVien,TenNguoiThucHienSnapshot=@TenActor
        WHERE ID=@IDKiemKe;
        COMMIT; SELECT 200 AS Status,N'Đã chốt kiểm kê và ghi điều chỉnh.' AS Message,@IDKiemKe AS IDKiemKe,@IDDieuChinh AS IDDieuChinh;
    END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; SELECT 400 AS Status,ERROR_MESSAGE() AS Message; END CATCH;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_KiemKe_HuyNhap
    @IDCSKCB BIGINT,@IDKiemKe BIGINT,@IDTaiKhoan BIGINT,@IDNhanVien BIGINT=NULL,@LyDo NVARCHAR(500)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LaAdmin BIT,@IDNVTK BIGINT,@TenActor NVARCHAR(200);
    SET @LyDo=COALESCE(NULLIF(LTRIM(RTRIM(@LyDo)),N''),N'Hủy bản nháp kiểm kê');
    SELECT @LaAdmin=T.LaQuanTriHeThong,@IDNVTK=T.IDNhanVien,@TenActor=CASE WHEN T.LaQuanTriHeThong=1 THEN T.Ten_Dang_Nhap ELSE N.HoTen END
    FROM dbo.HT_Tai_Khoan T LEFT JOIN dbo.DM_NhanVien N ON N.ID=T.IDNhanVien AND N.Active=1
    WHERE T.ID=@IDTaiKhoan AND T.Active=1 AND (T.LaQuanTriHeThong=1 OR T.IDCSKCB=@IDCSKCB);
    IF @LaAdmin IS NULL
    BEGIN SELECT 400 AS Status,N'Tài khoản hủy không hợp lệ.' AS Message; RETURN; END;
    IF @LaAdmin=1 SET @IDNhanVien=NULL;
    ELSE IF ISNULL(@IDNhanVien,0)<=0 OR @IDNhanVien<>ISNULL(@IDNVTK,0)
    BEGIN SELECT 400 AS Status,N'Nhân viên thực hiện không thuộc tài khoản.' AS Message; RETURN; END;
    UPDATE dbo.QL_Kho_KiemKe SET TrangThai='DA_HUY',NgayHuy=SYSDATETIME(),IDTaiKhoanHuy=@IDTaiKhoan,
        IDNhanVienHuy=@IDNhanVien,TenNguoiHuySnapshot=@TenActor,LyDoHuy=@LyDo
    WHERE IDCSKCB=@IDCSKCB AND ID=@IDKiemKe AND TrangThai='NHAP';
    IF @@ROWCOUNT=0 SELECT 400 AS Status,N'Phiếu kiểm kê không tồn tại hoặc không còn là nháp.' AS Message;
    ELSE SELECT 200 AS Status,N'Đã hủy phiếu kiểm kê nháp.' AS Message,@IDKiemKe AS IDKiemKe;
END;
GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_KiemKe_DanhSach
    @IDCSKCB BIGINT,@TuNgay DATE=NULL,@DenNgay DATE=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT H.ID AS id,H.SoPhieu AS so_phieu,H.NgayGio AS ngay_gio,H.TrangThai AS trang_thai,H.GhiChu AS ghi_chu,
           H.TenNguoiThucHienSnapshot AS nguoi_thuc_hien,H.NgayChot AS ngay_chot,H.IDDieuChinh AS id_dieu_chinh,
           H.NgayHuy AS ngay_huy,H.TenNguoiHuySnapshot AS nguoi_huy,H.LyDoHuy AS ly_do_huy,
           COUNT(C.ID) AS so_dong,SUM(ABS(C.ChenhLech)) AS tong_chenh_lech
    FROM dbo.QL_Kho_KiemKe H LEFT JOIN dbo.QL_Kho_KiemKe_CT C ON C.IDCSKCB=H.IDCSKCB AND C.IDKiemKe=H.ID
    WHERE H.IDCSKCB=@IDCSKCB AND (@TuNgay IS NULL OR H.NgayGio>=@TuNgay) AND (@DenNgay IS NULL OR H.NgayGio<DATEADD(DAY,1,@DenNgay))
    GROUP BY H.ID,H.SoPhieu,H.NgayGio,H.TrangThai,H.GhiChu,H.TenNguoiThucHienSnapshot,H.NgayChot,H.IDDieuChinh,H.NgayHuy,H.TenNguoiHuySnapshot,H.LyDoHuy
    ORDER BY H.NgayGio DESC,H.ID DESC;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_KiemKe_ChiTiet
    @IDCSKCB BIGINT,@IDKiemKe BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT H.ID AS id,H.SoPhieu AS so_phieu,H.NgayGio AS ngay_gio,H.TrangThai AS trang_thai,H.GhiChu AS ghi_chu,
           H.TenNguoiThucHienSnapshot AS nguoi_thuc_hien,H.NgayChot AS ngay_chot,H.IDDieuChinh AS id_dieu_chinh,
           H.NgayHuy AS ngay_huy,H.TenNguoiHuySnapshot AS nguoi_huy,H.LyDoHuy AS ly_do_huy
    FROM dbo.QL_Kho_KiemKe H WHERE H.IDCSKCB=@IDCSKCB AND H.ID=@IDKiemKe;
    SELECT C.ID AS id,C.IDLoThuoc AS id_lo_thuoc,C.IDThuoc AS id_thuoc,T.MaThuoc AS ma_thuoc,T.TenThuoc AS ten_thuoc,
           C.SoLoSnapshot AS so_lo,C.HanDungSnapshot AS han_dung,C.SoLuongSoSach AS so_luong_so_sach,
           C.SoLuongThucTe AS so_luong_thuc_te,C.ChenhLech AS chenh_lech
    FROM dbo.QL_Kho_KiemKe_CT C INNER JOIN dbo.DM_Thuoc T ON T.IDCSKCB=C.IDCSKCB AND T.ID=C.IDThuoc
    WHERE C.IDCSKCB=@IDCSKCB AND C.IDKiemKe=@IDKiemKe ORDER BY T.TenThuoc,C.ID;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_ChungTu_ChiTiet
    @IDCSKCB BIGINT,@Loai VARCHAR(25),@ID BIGINT
AS
BEGIN
    SET NOCOUNT ON; SET @Loai=UPPER(LTRIM(RTRIM(@Loai)));
    IF @Loai='XUAT_KHAC'
    BEGIN
        SELECT H.ID AS id,H.SoPhieu AS so_phieu,H.NgayGio AS ngay_gio,H.Loai AS loai,H.LyDo AS ly_do,H.NoiNhan AS doi_tac,
               COALESCE(N.TenNhaCungCap,H.NoiNhan) AS ten_doi_tac,H.TenNguoiThucHienSnapshot AS nguoi_thuc_hien,H.DaHuy AS da_huy,H.LyDoHuy AS ly_do_huy
        FROM dbo.QL_Kho_XuatKhac H LEFT JOIN dbo.DM_NhaCungCap N ON N.IDCSKCB=H.IDCSKCB AND N.ID=H.IDNhaCungCap
        WHERE H.IDCSKCB=@IDCSKCB AND H.ID=@ID;
        SELECT C.ID AS id,C.MaThuocSnapshot AS ma_thuoc,C.TenThuocSnapshot AS ten_thuoc,C.SoLoSnapshot AS so_lo,C.HanDungSnapshot AS han_dung,
               C.SoLuongCoSo AS so_luong,C.GiaVon AS don_gia,C.ThanhTien AS thanh_tien
        FROM dbo.QL_Kho_XuatKhac_CT C WHERE C.IDCSKCB=@IDCSKCB AND C.IDXuatKhac=@ID ORDER BY C.ID; RETURN;
    END;
    IF @Loai='KIEM_KE'
    BEGIN EXEC dbo.STO_QL_Kho_KiemKe_ChiTiet @IDCSKCB=@IDCSKCB,@IDKiemKe=@ID; RETURN; END;
    IF @Loai='NHAP'
    BEGIN EXEC dbo.STO_QL_Kho_Nhap_ChiTiet @IDCSKCB=@IDCSKCB,@IDNhap=@ID; RETURN; END;
    THROW 59103,N'Loại chứng từ không được hỗ trợ.',1;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_DanhSachKho
    @IDCSKCB BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ID AS id,MaKho AS ma,TenKho AS ten
    FROM dbo.DM_Kho
    WHERE IDCSKCB=@IDCSKCB AND Active=1
    ORDER BY TenKho,ID;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_DieuChinh_DanhSach
    @IDCSKCB BIGINT,@TuNgay DATE=NULL,@DenNgay DATE=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT H.ID AS id,H.SoPhieu AS so_phieu,H.Loai AS loai,H.NgayGio AS ngay_gio,NV.HoTen AS nguoi_lap,H.LyDo AS ly_do,
           COUNT(CT.ID) AS so_dong,SUM(CT.SoLuongThayDoi) AS tong_thay_doi
    FROM dbo.QL_Kho_DieuChinh H INNER JOIN dbo.DM_NhanVien NV ON NV.ID=H.IDNhanVien
    INNER JOIN dbo.QL_Kho_DieuChinh_CT CT ON CT.IDCSKCB=H.IDCSKCB AND CT.IDChungTu=H.ID
    WHERE H.IDCSKCB=@IDCSKCB AND (@TuNgay IS NULL OR H.NgayGio>=@TuNgay) AND (@DenNgay IS NULL OR H.NgayGio<DATEADD(DAY,1,@DenNgay))
    GROUP BY H.ID,H.SoPhieu,H.Loai,H.NgayGio,NV.HoTen,H.LyDo ORDER BY H.NgayGio DESC,H.ID DESC;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_DieuChinh_Luu
    @IDCSKCB BIGINT,@IDKho BIGINT=NULL,@Loai VARCHAR(20),@IDNhanVien BIGINT,
    @LyDo NVARCHAR(500)=NULL,@DanhSachJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    SET @Loai=UPPER(LTRIM(RTRIM(ISNULL(@Loai,'')))); SET @LyDo=COALESCE(NULLIF(LTRIM(RTRIM(@LyDo)),N''),CASE WHEN @Loai='HUY_THUOC' THEN N'Hủy thuốc' ELSE N'Điều chỉnh tồn kho' END);
    IF @IDKho IS NULL
        SELECT TOP(1) @IDKho=ID FROM dbo.DM_Kho WHERE IDCSKCB=@IDCSKCB AND Active=1 ORDER BY ID;
    BEGIN TRY
        BEGIN TRAN;
        IF @Loai NOT IN('DIEU_CHINH','HUY_THUOC') THROW 58200,N'Loại chứng từ kho không hợp lệ.',1;
        IF @IDNhanVien<=0 THROW 58200,N'Không xác định được nhân viên thực hiện.',1;
        IF NOT EXISTS(SELECT 1 FROM dbo.DM_Kho WHERE IDCSKCB=@IDCSKCB AND ID=@IDKho AND Active=1) THROW 58200,N'Kho không hợp lệ.',1;
        IF ISJSON(@DanhSachJson)<>1 THROW 58200,N'Danh sách lô thuốc không hợp lệ.',1;
        DECLARE @D TABLE(IDLo BIGINT PRIMARY KEY,ThayDoi DECIMAL(18,4) NOT NULL,Truoc DECIMAL(18,4) NULL,Sau DECIMAL(18,4) NULL);
        INSERT @D(IDLo,ThayDoi)
        SELECT J.IDLo,CASE WHEN @Loai='HUY_THUOC' THEN -ABS(SUM(J.SoLuong)) ELSE SUM(J.SoLuong) END
        FROM OPENJSON(@DanhSachJson) WITH(IDLo BIGINT '$.id_lo_thuoc',SoLuong DECIMAL(18,4) '$.so_luong') J
        WHERE J.IDLo IS NOT NULL AND ISNULL(J.SoLuong,0)<>0 GROUP BY J.IDLo;
        IF NOT EXISTS(SELECT 1 FROM @D) THROW 58200,N'Chưa nhập số lượng cần xử lý.',1;
        UPDATE D SET Truoc=L.SoLuongTon,Sau=L.SoLuongTon+D.ThayDoi
        FROM @D D INNER JOIN dbo.QL_Kho_LoThuoc L WITH(UPDLOCK,HOLDLOCK) ON L.ID=D.IDLo
        WHERE L.IDCSKCB=@IDCSKCB AND L.IDKho=@IDKho;
        IF EXISTS(SELECT 1 FROM @D WHERE Truoc IS NULL) THROW 58200,N'Có lô thuốc không thuộc kho hiện tại.',1;
        IF EXISTS(SELECT 1 FROM @D WHERE Sau<0) THROW 58200,N'Số lượng giảm vượt tồn vật lý của lô.',1;

        DECLARE @Seq BIGINT=NEXT VALUE FOR dbo.SEQ_SoPhieuDieuChinhKho;
        DECLARE @So NVARCHAR(30)=CASE WHEN @Loai='HUY_THUOC' THEN N'HT-' ELSE N'DC-' END+CONVERT(CHAR(8),SYSDATETIME(),112)+RIGHT(N'00000000'+CONVERT(NVARCHAR(20),@Seq),8);
        INSERT dbo.QL_Kho_DieuChinh(IDCSKCB,IDKho,Loai,SoPhieu,NgayGio,IDNhanVien,LyDo)
        VALUES(@IDCSKCB,@IDKho,@Loai,@So,SYSDATETIME(),@IDNhanVien,@LyDo);
        DECLARE @ID BIGINT=SCOPE_IDENTITY();
        INSERT dbo.QL_Kho_DieuChinh_CT(IDCSKCB,IDChungTu,IDLoThuoc,SoLuongThayDoi,SoLuongTruoc,SoLuongSau)
        SELECT @IDCSKCB,@ID,IDLo,ThayDoi,Truoc,Sau FROM @D;
        UPDATE L SET SoLuongTon=D.Sau FROM dbo.QL_Kho_LoThuoc L INNER JOIN @D D ON D.IDLo=L.ID;
        COMMIT;
        SELECT 200 AS Status,N'Đã ghi chứng từ kho.' AS Message,@ID AS IDChungTu,@So AS SoPhieu;
    END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; SELECT 400 AS Status,ERROR_MESSAGE() AS Message; END CATCH;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_DongDaCap
    @IDCSKCB BIGINT, @IDVaoVien BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CT.ID AS id_xuat_ct, X.ID AS id_xuat, X.SoPhieu AS so_phieu,
           X.NgayXuat AS ngay_xuat, CT.IDToaThuocCT AS id_toa_thuoc_ct,
           X.IDTaiKhoanXuat AS id_tai_khoan_xuat, X.IDNhanVienXuat AS id_nhan_vien_xuat,
           X.TenNguoiXuatSnapshot AS nguoi_xuat,
           T.TenThuoc AS ten_thuoc, L.SoLo AS so_lo, L.HanDung AS han_dung,
           COALESCE(D.TenDVT,T.DonViTinh,N'Đơn vị cơ sở') AS don_vi_co_so,
           CT.SoLuongCoSo AS so_luong_cap_co_so,
           CT.SoLuongDaHoan AS so_luong_da_hoan_co_so,
           CT.SoLuongCoSo-ISNULL(CT.SoLuongDaHoan,0) AS con_co_the_hoan_co_so
    FROM dbo.QL_Kho_Xuat_CT CT
    INNER JOIN dbo.QL_Kho_Xuat X ON X.IDCSKCB=CT.IDCSKCB AND X.ID=CT.IDXuat
    INNER JOIN dbo.DM_Thuoc T ON T.IDCSKCB=CT.IDCSKCB AND T.ID=CT.IDThuoc
    INNER JOIN dbo.QL_Kho_LoThuoc L ON L.IDCSKCB=CT.IDCSKCB AND L.ID=CT.IDLoThuoc
    LEFT JOIN dbo.DM_DonViTinh D ON D.IDCSKCB=T.IDCSKCB AND D.ID=T.IDDonViTinh
    WHERE X.IDCSKCB=@IDCSKCB AND X.IDVaoVien=@IDVaoVien AND X.DaHuy=0
      AND CT.SoLuongCoSo-ISNULL(CT.SoLuongDaHoan,0)>0
    ORDER BY X.NgayXuat,X.ID,CT.ID;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_LoThuoc_DanhSach
    @IDCSKCB BIGINT,@IDKho BIGINT=NULL,@IDThuoc BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    IF @IDKho IS NULL
        SELECT TOP(1) @IDKho=ID FROM dbo.DM_Kho WHERE IDCSKCB=@IDCSKCB AND Active=1 ORDER BY ID;
    SELECT L.ID AS id_lo_thuoc,L.SoLo AS so_lo,L.HanDung AS han_dung,L.SoLuongTon AS ton_vat_ly,
           CASE WHEN L.Active=1 AND (L.HanDung IS NULL OR L.HanDung>=CONVERT(DATE,SYSDATETIME())) THEN L.SoLuongTon ELSE 0 END AS ton_kha_dung,
           L.GiaNhap AS gia_nhap,L.NgayNhap AS ngay_nhap,L.Active AS active,
           CASE WHEN L.HanDung IS NOT NULL AND L.HanDung<CONVERT(DATE,SYSDATETIME()) THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS het_han
    FROM dbo.QL_Kho_LoThuoc L
    WHERE L.IDCSKCB=@IDCSKCB AND L.IDKho=@IDKho AND L.IDThuoc=@IDThuoc
      AND (L.Active=1 OR L.SoLuongTon>0)
    ORDER BY CASE WHEN L.HanDung IS NULL THEN 1 ELSE 0 END,L.HanDung,L.NgayNhap,L.ID;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
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
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO

/* Đầu phiếu bổ sung địa chỉ/điện thoại NCC cho mẫu Excel; đọc trong tenant.
   Giữ snapshot tên thuốc/ĐVT/NCC, người nhập và toàn bộ dòng lô hiện có. */
CREATE   PROCEDURE dbo.STO_QL_Kho_Nhap_ChiTiet @IDCSKCB BIGINT,@IDNhap BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT N.ID AS id,N.SoPhieu AS so_phieu,N.NgayNhap AS ngay_nhap,N.SoHoaDon AS so_hoa_don,N.NgayHoaDon AS ngay_hoa_don,
           COALESCE(N.TenNhaCungCapSnapshot,NCC.TenNhaCungCap) AS nha_cung_cap,
           NCC.DiaChi AS dia_chi_ncc,NCC.DienThoai AS dien_thoai_ncc,
           CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.QL_Kho_Nhap_CT D WHERE D.IDCSKCB=N.IDCSKCB AND D.IDNhap=N.ID AND D.TenThuocSnapshot IS NULL)
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
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
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
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_Nhap_Huy
    @IDCSKCB BIGINT,@IDNhap BIGINT,@IDNhanVienHuy BIGINT,@LyDo NVARCHAR(500)=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON; SET @LyDo=COALESCE(NULLIF(LTRIM(RTRIM(@LyDo)),N''),N'Hủy phiếu nhập kho');
    BEGIN TRY
        BEGIN TRAN;
        IF @IDNhanVienHuy<=0 THROW 58100,N'Thiếu nhân viên thực hiện hủy.',1;
        IF NOT EXISTS(SELECT 1 FROM dbo.QL_Kho_Nhap WITH(UPDLOCK,HOLDLOCK)
                      WHERE IDCSKCB=@IDCSKCB AND ID=@IDNhap AND DaHuy=0)
            THROW 58100,N'Phiếu nhập không tồn tại hoặc đã hủy.',1;
        DECLARE @LockLo BIGINT;
        SELECT @LockLo=L.ID FROM dbo.QL_Kho_LoThuoc L WITH(UPDLOCK,HOLDLOCK)
        INNER JOIN dbo.QL_Kho_Nhap_CT CT ON CT.IDLoThuoc=L.ID AND CT.IDCSKCB=L.IDCSKCB
        WHERE CT.IDCSKCB=@IDCSKCB AND CT.IDNhap=@IDNhap ORDER BY L.ID;
        IF EXISTS
        (
            SELECT 1 FROM dbo.QL_Kho_Nhap_CT CT
            INNER JOIN dbo.QL_Kho_LoThuoc L ON L.ID=CT.IDLoThuoc AND L.IDCSKCB=CT.IDCSKCB
            WHERE CT.IDCSKCB=@IDCSKCB AND CT.IDNhap=@IDNhap AND
            (
                L.SoLuongTon<>CT.SoLuongCoSo
                OR EXISTS(SELECT 1 FROM dbo.QL_Kho_Xuat_CT X WHERE X.IDCSKCB=@IDCSKCB AND X.IDLoThuoc=L.ID)
                OR EXISTS(SELECT 1 FROM dbo.QL_Kho_DieuChinh_CT D WHERE D.IDCSKCB=@IDCSKCB AND D.IDLoThuoc=L.ID)
                OR EXISTS(SELECT 1 FROM dbo.QL_Kho_Nhap_CT K WHERE K.IDCSKCB=@IDCSKCB AND K.IDLoThuoc=L.ID AND K.IDNhap<>@IDNhap)
            )
        ) THROW 58100,N'Lô đã có phát sinh cấp/hoàn/điều chỉnh hoặc dùng chung nguồn; không thể hủy nhập.',1;
        UPDATE L SET SoLuongTon=0,Active=0 FROM dbo.QL_Kho_LoThuoc L
        INNER JOIN dbo.QL_Kho_Nhap_CT CT ON CT.IDLoThuoc=L.ID AND CT.IDCSKCB=L.IDCSKCB
        WHERE CT.IDCSKCB=@IDCSKCB AND CT.IDNhap=@IDNhap;
        UPDATE dbo.QL_Kho_Nhap SET DaHuy=1,NgayGioHuy=SYSDATETIME(),IDNhanVienHuy=@IDNhanVienHuy,LyDoHuy=@LyDo
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDNhap;
        COMMIT;
        SELECT 200 AS Status,N'Đã hủy phiếu nhập.' AS Message,@IDNhap AS IDNhap;
    END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; SELECT 400 AS Status,ERROR_MESSAGE() AS Message; END CATCH;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO

/* Danh sách thuốc cho màn hình phân nhóm Kho, có server-side paging. */
CREATE   PROCEDURE dbo.STO_QL_Kho_Thuoc_Danh_Sach
    @IDCSKCB BIGINT,
    @TuKhoa NVARCHAR(500)=NULL,
    @Trang INT=1,
    @KichThuocTrang INT=25,
    @LoaiToaJson NVARCHAR(MAX)=NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @TuKhoa=NULLIF(LTRIM(RTRIM(@TuKhoa)),N'');
    SET @Trang=CASE WHEN @Trang<1 THEN 1 ELSE @Trang END;
    SET @KichThuocTrang=CASE
        WHEN @KichThuocTrang<10 THEN 10
        WHEN @KichThuocTrang>100 THEN 100
        ELSE @KichThuocTrang
    END;

    DECLARE @LoaiToa TABLE(Ma NVARCHAR(20) NOT NULL PRIMARY KEY);
    IF @LoaiToaJson IS NOT NULL
    BEGIN
        IF ISJSON(@LoaiToaJson)<>1
        BEGIN
            THROW 51001, 'LoaiToaJson must be a JSON array.', 1;
        END;

        INSERT INTO @LoaiToa(Ma)
        SELECT DISTINCT LOWER(LTRIM(RTRIM([value])))
        FROM OPENJSON(@LoaiToaJson)
        WHERE [type]=1 AND NULLIF(LTRIM(RTRIM([value])),N'') IS NOT NULL;
    END;

    SELECT
        G.ID AS id,
        G.MaNhomHang AS ma,
        G.TenNhomHang AS ten,
        G.MaLoaiToaThuoc AS ma_loai_don_thuoc
    FROM dbo.DM_NhomHang G
    WHERE G.IDCSKCB=@IDCSKCB AND G.Active=1
    ORDER BY G.MaLoaiToaThuoc,G.TenNhomHang;

    SELECT
        T.ID AS id,
        T.MaThuoc AS ma,
        T.TenThuoc AS ten,
        T.IDNhomHang AS nhom_id,
        G.TenNhomHang AS nhom,
        G.MaLoaiToaThuoc AS ma_loai_don_thuoc
    INTO #Thuoc
    FROM dbo.DM_Thuoc T
    LEFT JOIN dbo.DM_NhomHang G
        ON G.IDCSKCB=T.IDCSKCB AND G.ID=T.IDNhomHang
    WHERE T.IDCSKCB=@IDCSKCB
      AND T.Active=1
      AND
      (
          @TuKhoa IS NULL
          OR T.MaThuoc LIKE N'%'+@TuKhoa+N'%'
          OR T.TenThuoc LIKE N'%'+@TuKhoa+N'%'
      )
      AND
      (
          @LoaiToaJson IS NULL
          OR EXISTS
          (
              SELECT 1
              FROM @LoaiToa F
              WHERE (F.Ma=N'unassigned' AND T.IDNhomHang IS NULL)
                 OR (F.Ma IN(N'c',N'n',N'h') AND G.Active=1 AND LOWER(G.MaLoaiToaThuoc)=F.Ma)
          )
      );

    SELECT COUNT_BIG(*) AS TongSo FROM #Thuoc;

    SELECT id,ma,ten,nhom_id,nhom,ma_loai_don_thuoc
    FROM #Thuoc
    ORDER BY CASE WHEN nhom_id IS NULL THEN 1 ELSE 0 END,ten,id
    OFFSET (@Trang-1)*@KichThuocTrang ROWS
    FETCH NEXT @KichThuocTrang ROWS ONLY;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
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
    LEFT JOIN dbo.QL_Kho_Hoan K ON K.IDCSKCB=C.IDCSKCB AND K.IDChungTuHuy=C.ID AND K.Loai='DAO_CAP_HUY_THU'
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
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO

/* Gán hoặc gỡ nhóm thuốc, luôn khóa theo IDCSKCB của claim phía controller. */
CREATE   PROCEDURE dbo.STO_QL_Kho_Thuoc_GanNhom
    @IDCSKCB BIGINT,
    @IDThuoc BIGINT,
    @IDNhomHang BIGINT=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @IDCSKCB<=0 OR @IDThuoc<=0
    BEGIN
        SELECT 400 AS MaLoi,N'Thiếu thuốc hoặc cơ sở KCB.' AS ThongBao;
        RETURN;
    END;

    IF NOT EXISTS(SELECT 1 FROM dbo.DM_Thuoc WHERE IDCSKCB=@IDCSKCB AND ID=@IDThuoc)
    BEGIN
        SELECT 404 AS MaLoi,N'Không tìm thấy thuốc.' AS ThongBao;
        RETURN;
    END;

    IF @IDNhomHang IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1 FROM dbo.DM_NhomHang
           WHERE IDCSKCB=@IDCSKCB AND ID=@IDNhomHang AND Active=1
       )
    BEGIN
        SELECT 400 AS MaLoi,N'Nhóm thuốc không hợp lệ.' AS ThongBao;
        RETURN;
    END;

    UPDATE dbo.DM_Thuoc
    SET IDNhomHang=@IDNhomHang
    WHERE IDCSKCB=@IDCSKCB AND ID=@IDThuoc;

    SELECT 200 AS MaLoi,N'Đã cập nhật nhóm thuốc.' AS ThongBao;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_TonKho_DanhSach
    @IDCSKCB BIGINT,
    @IDKho BIGINT=NULL,
    @TuKhoa NVARCHAR(300)=NULL,
    @Trang INT=1,
    @KichThuocTrang INT=25,
    @TrangThai NVARCHAR(30)=N'tat_ca'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Ngay DATE=CONVERT(DATE,SYSDATETIME());
    SET @TrangThai=COALESCE(NULLIF(LOWER(LTRIM(RTRIM(@TrangThai))),N''),N'tat_ca');
    IF @TrangThai NOT IN(N'tat_ca',N'con_thuoc',N'het_thuoc',N'sap_het_han',N'het_han_khoa')
        THROW 51000,N'Trang thai loc ton kho khong hop le.',1;
    SET @TuKhoa=NULLIF(LTRIM(RTRIM(@TuKhoa)),N'');
    SET @Trang=CASE WHEN @Trang<1 THEN 1 ELSE @Trang END;
    SET @KichThuocTrang=CASE WHEN @KichThuocTrang<10 THEN 10 WHEN @KichThuocTrang>100 THEN 100 ELSE @KichThuocTrang END;

    IF @IDKho IS NULL
        SELECT TOP(1) @IDKho=ID FROM dbo.DM_Kho WHERE IDCSKCB=@IDCSKCB AND Active=1 ORDER BY ID;

    DECLARE @TonKho TABLE
    (
        id_thuoc BIGINT NOT NULL,
        ma_thuoc NVARCHAR(100) NULL,
        ten_thuoc NVARCHAR(500) NULL,
        don_vi_tinh NVARCHAR(200) NULL,
        ton_vat_ly DECIMAL(38,6) NOT NULL,
        ton_het_han DECIMAL(38,6) NOT NULL,
        ton_kha_dung DECIMAL(38,6) NOT NULL,
        han_gan_nhat DATE NULL,
        so_lo BIGINT NOT NULL,
        gia_ban DECIMAL(38,6) NULL,
        sap_het_han BIT NOT NULL
    );

    INSERT @TonKho
        (id_thuoc,ma_thuoc,ten_thuoc,don_vi_tinh,ton_vat_ly,ton_het_han,ton_kha_dung,han_gan_nhat,so_lo,gia_ban,sap_het_han)
    SELECT
        T.ID,
        T.MaThuoc,
        T.TenThuoc,
        DVT.TenDVT,
        ISNULL(X.ton_vat_ly,0),
        ISNULL(X.ton_het_han,0),
        ISNULL(X.ton_kha_dung,0),
        X.han_gan_nhat,
        ISNULL(X.so_lo,0),
        T.GiaBan,
        CAST(CASE WHEN X.han_gan_nhat BETWEEN @Ngay AND DATEADD(DAY,30,@Ngay) THEN 1 ELSE 0 END AS BIT)
    FROM dbo.DM_Thuoc T
    LEFT JOIN dbo.DM_DonViTinh DVT
      ON DVT.IDCSKCB=T.IDCSKCB AND DVT.ID=T.IDDonViTinh
    OUTER APPLY
    (
        SELECT
            SUM(L.SoLuongTon) AS ton_vat_ly,
            SUM(CASE WHEN L.SoLuongTon>0 AND (L.Active=0 OR L.HanDung<@Ngay) THEN L.SoLuongTon ELSE 0 END) AS ton_het_han,
            SUM(CASE WHEN L.Active=1 AND L.SoLuongTon>0 AND (L.HanDung IS NULL OR L.HanDung>=@Ngay) THEN L.SoLuongTon ELSE 0 END) AS ton_kha_dung,
            MIN(CASE WHEN L.Active=1 AND L.SoLuongTon>0 AND (L.HanDung IS NULL OR L.HanDung>=@Ngay) THEN L.HanDung END) AS han_gan_nhat,
            SUM(CASE WHEN L.SoLuongTon>0 THEN CAST(1 AS BIGINT) ELSE CAST(0 AS BIGINT) END) AS so_lo
        FROM dbo.QL_Kho_LoThuoc L
        WHERE L.IDCSKCB=@IDCSKCB AND L.IDKho=@IDKho AND L.IDThuoc=T.ID
    ) X
    WHERE T.IDCSKCB=@IDCSKCB
      AND T.Active=1
      AND
      (
          @TuKhoa IS NULL
          OR T.MaThuoc LIKE N'%'+@TuKhoa+N'%'
          OR T.TenThuoc LIKE N'%'+@TuKhoa+N'%'
      );

    -- Filtering applies to the complete result before count and pagination.
    DELETE FROM @TonKho WHERE NOT
    (
        @TrangThai=N'tat_ca'
        OR (@TrangThai=N'con_thuoc' AND ton_kha_dung>0)
        OR (@TrangThai=N'het_thuoc' AND ton_vat_ly=0)
        OR (@TrangThai=N'sap_het_han' AND sap_het_han=1)
        OR (@TrangThai=N'het_han_khoa' AND ton_het_han>0)
    );

    SELECT COUNT_BIG(*) AS tong_so FROM @TonKho;

    SELECT *
    FROM @TonKho
    ORDER BY CASE WHEN ton_kha_dung<=0 THEN 0 ELSE 1 END,ten_thuoc,id_thuoc
    OFFSET (@Trang-1)*@KichThuocTrang ROWS
    FETCH NEXT @KichThuocTrang ROWS ONLY;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_Xuat_ChiTiet
    @IDCSKCB BIGINT,
    @IDKho BIGINT,
    @IDVaoVien BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        V.ID AS id_vao_vien,V.MaVaoVien AS ma_vao_vien,
        B.MaBN AS ma_bn,B.HoTen AS ho_ten,B.NgaySinh AS ngay_sinh,
        GT.TenGioiTinh AS gioi_tinh,B.DiaChi AS dia_chi,
        T.SoPhieu AS so_phieu_thu,T.NgayGioThu AS ngay_gio_thu
    FROM dbo.QL_VaoVien V
    INNER JOIN dbo.QL_BenhNhan B ON B.IDCSKCB=V.IDCSKCB AND B.ID=V.IDBenhNhan
    LEFT JOIN dbo.DM_GioiTinh GT ON GT.ID=B.IDGioiTinh
    INNER JOIN dbo.QL_ThuTien T ON T.IDCSKCB=V.IDCSKCB AND T.IDVaoVien=V.ID
    WHERE V.IDCSKCB=@IDCSKCB
      AND V.ID=@IDVaoVien
      AND V.Active=1
      AND V.TrangThaiKham=2
      AND EXISTS
      (
          SELECT 1
          FROM dbo.QL_ThuTien_CT PAY
          WHERE PAY.IDCSKCB=T.IDCSKCB
            AND PAY.IDThuTien=T.ID
            AND PAY.IDToaThuocCT IS NOT NULL
            AND ISNULL(PAY.DaThu,0)=1
            AND EXISTS
            (
                SELECT 1
                FROM dbo.QL_ThuTien_ChungTu_CT D0
                INNER JOIN dbo.QL_ThuTien_ChungTu C0
                  ON C0.ID=D0.IDChungTu
                 AND C0.IDCSKCB=V.IDCSKCB
                 AND C0.IDVaoVien=V.ID
                 AND C0.IDThuTien=T.ID
                 AND C0.Loai='THU'
                 AND C0.TrangThai=1
                WHERE D0.IDThuTienCT=PAY.ID
                  AND D0.Loai=N'THUOC'
                  AND NOT EXISTS
                  (
                      SELECT 1
                      FROM dbo.QL_ThuTien_ChungTu R0
                      WHERE R0.IDChungTuGoc=C0.ID
                        AND R0.Loai='HOAN'
                        AND R0.TrangThai=1
                  )
            )
      );

    SELECT
        TT.ID AS id_toa_thuoc_ct,
        TT.IDThuoc AS id_thuoc,
        TT.MaLoaiToaThuoc AS ma_loai_toa_thuoc,
        TT.NgayKe AS ngay_ke,
        M.MaThuoc AS ma_thuoc,
        M.TenThuoc AS ten_thuoc,
        M.HamLuong AS ham_luong,
        COALESCE(DVTD.TenDVT,DVT.TenDVT,M.DonViTinh) AS don_vi_tinh,
        COALESCE(TT.IDDonViTinhDung,M.IDDonViTinh) AS id_don_vi_tinh,
        TT.SoLuong AS so_luong_ke,
        TT.DonGia AS don_gia,
        TT.SoNgay AS so_ngay,
        TT.Sang AS sang,
        TT.Trua AS trua,
        TT.Chieu AS chieu,
        TT.Toi AS toi,
        TT.LieuDung AS lieu_dung,
        TT.CachDung AS cach_dung,
        COALESCE(NULLIF(TT.HoatChat,N''),M.HoatChat) AS hoat_chat,
        G.TenNhomHang AS nhom_hang,
        NV.HoTen AS bac_si_ke,
        K.TenKho AS kho_xuat,
        Q.HeSoQuyDoi AS he_so_quy_doi,
        CAST(CASE WHEN Q.HeSoQuyDoi IS NULL THEN 0 ELSE 1 END AS BIT) AS co_quy_doi,
        CASE WHEN Q.HeSoQuyDoi IS NULL THEN NULL ELSE TT.SoLuong*Q.HeSoQuyDoi END AS so_luong_ke_co_so,
        ISNULL(CAP.da_cap,0) AS da_cap_co_so,
        CASE
            WHEN Q.HeSoQuyDoi IS NULL THEN NULL
            WHEN TT.SoLuong*Q.HeSoQuyDoi-ISNULL(CAP.da_cap,0)<0 THEN 0
            ELSE TT.SoLuong*Q.HeSoQuyDoi-ISNULL(CAP.da_cap,0)
        END AS con_lai_co_so,
        CASE WHEN Q.HeSoQuyDoi>0 THEN
            (CASE WHEN TT.SoLuong*Q.HeSoQuyDoi-ISNULL(CAP.da_cap,0)<0 THEN 0 ELSE TT.SoLuong*Q.HeSoQuyDoi-ISNULL(CAP.da_cap,0) END)/Q.HeSoQuyDoi
            ELSE NULL END AS con_lai,
        ISNULL(TON.ton,0) AS ton_co_so,
        CASE WHEN Q.HeSoQuyDoi>0 THEN ISNULL(TON.ton,0)/Q.HeSoQuyDoi ELSE NULL END AS ton_theo_dvt,
        TON.han_gan_nhat
    FROM dbo.QL_ToaThuoc_CT TT
    INNER JOIN dbo.QL_ThuTien T
      ON T.IDCSKCB=TT.IDCSKCB AND T.IDVaoVien=TT.IDVaoVien
    INNER JOIN dbo.QL_ThuTien_CT PAY
      ON PAY.IDCSKCB=TT.IDCSKCB
     AND PAY.IDThuTien=T.ID
     AND PAY.IDToaThuocCT=TT.ID
     AND ISNULL(PAY.DaThu,0)=1
    INNER JOIN dbo.DM_Thuoc M ON M.IDCSKCB=TT.IDCSKCB AND M.ID=TT.IDThuoc
    LEFT JOIN dbo.DM_DonViTinh DVT ON DVT.IDCSKCB=M.IDCSKCB AND DVT.ID=M.IDDonViTinh
    LEFT JOIN dbo.DM_DonViTinh DVTD ON DVTD.IDCSKCB=TT.IDCSKCB AND DVTD.ID=TT.IDDonViTinhDung
    LEFT JOIN dbo.DM_NhomHang G ON G.IDCSKCB=M.IDCSKCB AND G.ID=M.IDNhomHang AND G.Active=1
    LEFT JOIN dbo.DM_NhanVien NV ON NV.ID=TT.IDBacSiKe
    LEFT JOIN dbo.DM_Kho K ON K.IDCSKCB=@IDCSKCB AND K.ID=@IDKho AND K.Active=1
    LEFT JOIN dbo.DM_Thuoc_DonViQuyDoi Q
      ON Q.IDCSKCB=TT.IDCSKCB
     AND Q.IDThuoc=TT.IDThuoc
     AND Q.IDDonViTinh=COALESCE(TT.IDDonViTinhDung,M.IDDonViTinh)
     AND Q.Active=1
    OUTER APPLY
    (
        SELECT SUM(XCT.SoLuongCoSo-ISNULL(XCT.SoLuongDaHoan,0)) AS da_cap
        FROM dbo.QL_Kho_Xuat_CT XCT
        INNER JOIN dbo.QL_Kho_Xuat XH
          ON XH.IDCSKCB=XCT.IDCSKCB AND XH.ID=XCT.IDXuat AND XH.DaHuy=0
        WHERE XCT.IDCSKCB=TT.IDCSKCB AND XCT.IDToaThuocCT=TT.ID
    ) CAP
    OUTER APPLY
    (
        SELECT SUM(L.SoLuongTon) AS ton,MIN(CASE WHEN L.SoLuongTon>0 THEN L.HanDung END) AS han_gan_nhat
        FROM dbo.QL_Kho_LoThuoc L
        WHERE L.IDCSKCB=@IDCSKCB
          AND L.IDKho=@IDKho
          AND L.IDThuoc=TT.IDThuoc
          AND L.Active=1
          AND (L.HanDung IS NULL OR L.HanDung>=CONVERT(DATE,SYSDATETIME()))
    ) TON
    WHERE TT.IDCSKCB=@IDCSKCB
      AND TT.IDVaoVien=@IDVaoVien
      AND TT.Active=1
      AND EXISTS
      (
          SELECT 1
          FROM dbo.QL_VaoVien V0
          WHERE V0.IDCSKCB=TT.IDCSKCB
            AND V0.ID=TT.IDVaoVien
            AND V0.Active=1
            AND V0.TrangThaiKham=2
      )
      AND EXISTS
      (
          SELECT 1
          FROM dbo.QL_ThuTien_ChungTu_CT D0
          INNER JOIN dbo.QL_ThuTien_ChungTu C0
            ON C0.ID=D0.IDChungTu
           AND C0.IDCSKCB=TT.IDCSKCB
           AND C0.IDVaoVien=TT.IDVaoVien
           AND C0.IDThuTien=T.ID
           AND C0.Loai='THU'
           AND C0.TrangThai=1
          WHERE D0.IDThuTienCT=PAY.ID
            AND D0.Loai=N'THUOC'
            AND NOT EXISTS
            (
                SELECT 1
                FROM dbo.QL_ThuTien_ChungTu R0
                WHERE R0.IDChungTuGoc=C0.ID
                  AND R0.Loai='HOAN'
                  AND R0.TrangThai=1
            )
      )
    ORDER BY LOWER(TT.MaLoaiToaThuoc),ISNULL(TT.ThuTu,999),TT.ID;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
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
            SELECT 1 FROM dbo.QL_Kho_Xuat_CT X WITH(UPDLOCK,HOLDLOCK)
            INNER JOIN dbo.QL_Kho_Xuat H ON H.IDCSKCB=X.IDCSKCB AND H.ID=X.IDXuat
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
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_Xuat_DanhSach
    @IDCSKCB BIGINT,
    @TuKhoa NVARCHAR(200)=NULL,
    @TrangThai TINYINT=NULL,
    @TrangThaiCsv NVARCHAR(20)=NULL,
    @TuNgay DATE=NULL,
    @DenNgay DATE=NULL,
    @LoaiToa NVARCHAR(20)=NULL,
    @Trang INT=1,
    @KichThuocTrang INT=25
AS
BEGIN
    SET NOCOUNT ON;
    SET @TuKhoa=NULLIF(LTRIM(RTRIM(@TuKhoa)),N'');
    SET @TrangThaiCsv=NULLIF(REPLACE(LTRIM(RTRIM(@TrangThaiCsv)),N' ',N''),N'');
    SET @LoaiToa=LOWER(NULLIF(LTRIM(RTRIM(@LoaiToa)),N''));
    IF @LoaiToa NOT IN(N'c',N'n',N'h') SET @LoaiToa=NULL;
    IF @TrangThai NOT IN(0,1,2) SET @TrangThai=NULL;
    SET @Trang=CASE WHEN @Trang<1 THEN 1 ELSE @Trang END;
    SET @KichThuocTrang=CASE WHEN @KichThuocTrang<10 THEN 10 WHEN @KichThuocTrang>100 THEN 100 ELSE @KichThuocTrang END;
    IF @TuNgay IS NOT NULL AND @DenNgay IS NOT NULL AND @TuNgay>@DenNgay
    BEGIN
        DECLARE @D DATE=@TuNgay;
        SET @TuNgay=@DenNgay;
        SET @DenNgay=@D;
    END;

    ;WITH D AS
    (
        SELECT
            V.ID AS id_vao_vien,V.MaVaoVien AS ma_vao_vien,
            B.MaBN AS ma_bn,B.HoTen AS ho_ten,B.NgaySinh AS ngay_sinh,
            GT.TenGioiTinh AS gioi_tinh,
            T.SoPhieu AS so_phieu_thu,T.NgayGioThu AS ngay_gio_thu,
            X.tong_dong,X.tong_co_so,X.da_cap_co_so,X.thieu_quy_doi,
            CASE
                WHEN ISNULL(X.thieu_quy_doi,0)>0 AND ISNULL(X.da_cap_co_so,0)>0 THEN CAST(1 AS TINYINT)
                WHEN ISNULL(X.thieu_quy_doi,0)>0 THEN CAST(0 AS TINYINT)
                WHEN ISNULL(X.da_cap_co_so,0)<=0 THEN CAST(0 AS TINYINT)
                WHEN ISNULL(X.da_cap_co_so,0)<ISNULL(X.tong_co_so,0) THEN CAST(1 AS TINYINT)
                ELSE CAST(2 AS TINYINT)
            END AS trang_thai_cap
        FROM dbo.QL_VaoVien V
        INNER JOIN dbo.QL_BenhNhan B
          ON B.IDCSKCB=V.IDCSKCB AND B.ID=V.IDBenhNhan
        LEFT JOIN dbo.DM_GioiTinh GT ON GT.ID=B.IDGioiTinh
        INNER JOIN dbo.QL_ThuTien T
          ON T.IDCSKCB=V.IDCSKCB AND T.IDVaoVien=V.ID
        CROSS APPLY
        (
            SELECT
                COUNT_BIG(*) AS tong_dong,
                SUM(CASE WHEN Q.HeSoQuyDoi IS NOT NULL THEN TT.SoLuong*Q.HeSoQuyDoi ELSE 0 END) AS tong_co_so,
                SUM(ISNULL(CAP.da_cap,0)) AS da_cap_co_so,
                SUM(CASE WHEN Q.HeSoQuyDoi IS NULL THEN 1 ELSE 0 END) AS thieu_quy_doi
            FROM dbo.QL_ToaThuoc_CT TT
            INNER JOIN dbo.QL_ThuTien_CT PAY
              ON PAY.IDCSKCB=TT.IDCSKCB
             AND PAY.IDThuTien=T.ID
             AND PAY.IDToaThuocCT=TT.ID
             AND ISNULL(PAY.DaThu,0)=1
            INNER JOIN dbo.DM_Thuoc M
              ON M.IDCSKCB=TT.IDCSKCB AND M.ID=TT.IDThuoc
            LEFT JOIN dbo.DM_Thuoc_DonViQuyDoi Q
              ON Q.IDCSKCB=TT.IDCSKCB
             AND Q.IDThuoc=TT.IDThuoc
             AND Q.IDDonViTinh=COALESCE(TT.IDDonViTinhDung,M.IDDonViTinh)
             AND Q.Active=1
            OUTER APPLY
            (
                SELECT SUM(XCT.SoLuongCoSo-ISNULL(XCT.SoLuongDaHoan,0)) AS da_cap
                FROM dbo.QL_Kho_Xuat_CT XCT
                INNER JOIN dbo.QL_Kho_Xuat XH
                  ON XH.IDCSKCB=XCT.IDCSKCB AND XH.ID=XCT.IDXuat AND XH.DaHuy=0
                WHERE XCT.IDCSKCB=TT.IDCSKCB AND XCT.IDToaThuocCT=TT.ID
            ) CAP
            WHERE TT.IDCSKCB=V.IDCSKCB
              AND TT.IDVaoVien=V.ID
              AND TT.Active=1
              AND (@LoaiToa IS NULL OR LOWER(TT.MaLoaiToaThuoc)=@LoaiToa)
              AND EXISTS
              (
                  SELECT 1
                  FROM dbo.QL_ThuTien_ChungTu_CT D0
                  INNER JOIN dbo.QL_ThuTien_ChungTu C0
                    ON C0.ID=D0.IDChungTu
                   AND C0.IDCSKCB=V.IDCSKCB
                   AND C0.IDVaoVien=V.ID
                   AND C0.IDThuTien=T.ID
                   AND C0.Loai='THU'
                   AND C0.TrangThai=1
                  WHERE D0.IDThuTienCT=PAY.ID
                    AND D0.Loai=N'THUOC'
                    AND NOT EXISTS
                    (
                        SELECT 1
                        FROM dbo.QL_ThuTien_ChungTu R0
                        WHERE R0.IDChungTuGoc=C0.ID
                          AND R0.Loai='HOAN'
                          AND R0.TrangThai=1
                    )
              )
        ) X
        WHERE V.IDCSKCB=@IDCSKCB
          AND V.Active=1
          AND V.TrangThaiKham=2
          AND X.tong_dong>0
          AND (@TuNgay IS NULL OR CONVERT(DATE,COALESCE(T.NgayGioThu,V.NgayGioVaoVien))>=@TuNgay)
          AND (@DenNgay IS NULL OR CONVERT(DATE,COALESCE(T.NgayGioThu,V.NgayGioVaoVien))<=@DenNgay)
          AND
          (
              @TuKhoa IS NULL
              OR B.MaBN LIKE N'%'+@TuKhoa+N'%'
              OR B.HoTen LIKE N'%'+@TuKhoa+N'%'
              OR V.MaVaoVien LIKE N'%'+@TuKhoa+N'%'
              OR ISNULL(T.SoPhieu,N'') LIKE N'%'+@TuKhoa+N'%'
          )
    ),
    F AS
    (
        SELECT *
        FROM D
        WHERE
            (
                @TrangThaiCsv IS NOT NULL
                AND CHARINDEX(N','+CONVERT(NVARCHAR(3),trang_thai_cap)+N',',N','+@TrangThaiCsv+N',')>0
            )
            OR
            (
                @TrangThaiCsv IS NULL
                AND (@TrangThai IS NULL OR trang_thai_cap=@TrangThai)
            )
    )
    SELECT F.*,COUNT(*) OVER() AS tong_so
    FROM F
    ORDER BY CASE trang_thai_cap WHEN 0 THEN 0 WHEN 1 THEN 1 ELSE 2 END,ngay_gio_thu DESC,id_vao_vien DESC
    OFFSET (@Trang-1)*@KichThuocTrang ROWS
    FETCH NEXT @KichThuocTrang ROWS ONLY;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_Xuat_Hoan
    @IDCSKCB BIGINT, @IDVaoVien BIGINT, @IDNhanVienHoan BIGINT,
    @LyDo NVARCHAR(500)=NULL, @DanhSachJson NVARCHAR(MAX)=N'[]', @HoanToanBo BIT=0
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    SET @LyDo=COALESCE(NULLIF(LTRIM(RTRIM(@LyDo)),N''),CASE WHEN @HoanToanBo=1 THEN N'Hủy cấp phát thuốc' ELSE N'Hoàn thuốc về kho' END);
    BEGIN TRY
        BEGIN TRAN;
        IF @IDNhanVienHoan<=0 THROW 58200,N'Không xác định được nhân viên hoàn kho.',1;
        IF ISNULL(ISJSON(@DanhSachJson),0)<>1 OR LEFT(LTRIM(@DanhSachJson),1)<>N'['
            THROW 58200,N'Danh sách hoàn phải là mảng JSON.',1;
        DECLARE @VisitLock BIGINT;
        SELECT @VisitLock=ID FROM dbo.QL_VaoVien WITH(UPDLOCK,HOLDLOCK)
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien AND Active=1;
        IF @VisitLock IS NULL THROW 58200,N'Không tìm thấy lượt khám.',1;

        DECLARE @Y TABLE(IDXuatCT BIGINT PRIMARY KEY,SoLuong DECIMAL(18,4) NOT NULL);
        IF @HoanToanBo=1
        BEGIN
            IF EXISTS(SELECT 1 FROM OPENJSON(@DanhSachJson))
                THROW 58200,N'Hoàn toàn bộ không được kèm danh sách hoàn từng dòng.',1;
            INSERT @Y
            SELECT CT.ID,CT.SoLuongCoSo-ISNULL(CT.SoLuongDaHoan,0)
            FROM dbo.QL_Kho_Xuat_CT CT WITH(UPDLOCK,HOLDLOCK)
            INNER JOIN dbo.QL_Kho_Xuat X ON X.IDCSKCB=CT.IDCSKCB AND X.ID=CT.IDXuat
            WHERE X.IDCSKCB=@IDCSKCB AND X.IDVaoVien=@IDVaoVien AND X.DaHuy=0
              AND CT.SoLuongCoSo-ISNULL(CT.SoLuongDaHoan,0)>0;
        END
        ELSE
        BEGIN
            IF NOT EXISTS(SELECT 1 FROM OPENJSON(@DanhSachJson))
                THROW 58200,N'Chọn dòng cấp và số lượng cần hoàn.',1;
            IF EXISTS
            (
                SELECT 1 FROM OPENJSON(@DanhSachJson) J
                WHERE J.[type]<>5 OR TRY_CONVERT(BIGINT,JSON_VALUE(J.value,'$.id_xuat_ct')) IS NULL
                  OR TRY_CONVERT(BIGINT,JSON_VALUE(J.value,'$.id_xuat_ct'))<=0
                  OR TRY_CONVERT(DECIMAL(18,4),JSON_VALUE(J.value,'$.so_luong_hoan_co_so')) IS NULL
                  OR TRY_CONVERT(DECIMAL(18,4),JSON_VALUE(J.value,'$.so_luong_hoan_co_so'))<=0
            ) THROW 58200,N'Có dòng hoàn không hợp lệ; không tự chuyển sang hoàn toàn bộ.',1;
            INSERT @Y
            SELECT IDXuatCT,SoLuong FROM OPENJSON(@DanhSachJson)
            WITH(IDXuatCT BIGINT '$.id_xuat_ct',SoLuong DECIMAL(18,4) '$.so_luong_hoan_co_so');
        END;
        IF NOT EXISTS(SELECT 1 FROM @Y) THROW 58200,N'Không có lượng đã cấp còn được hoàn.',1;
        IF EXISTS
        (
            SELECT 1 FROM @Y Y
            LEFT JOIN dbo.QL_Kho_Xuat_CT CT WITH(UPDLOCK,HOLDLOCK) ON CT.ID=Y.IDXuatCT AND CT.IDCSKCB=@IDCSKCB
            LEFT JOIN dbo.QL_Kho_Xuat X ON X.IDCSKCB=CT.IDCSKCB AND X.ID=CT.IDXuat
            WHERE CT.ID IS NULL OR X.IDVaoVien<>@IDVaoVien OR X.DaHuy<>0
              OR Y.SoLuong>CT.SoLuongCoSo-ISNULL(CT.SoLuongDaHoan,0)
        ) THROW 58200,N'Dòng xuất không thuộc lượt hoặc số lượng hoàn vượt lượng còn được hoàn.',1;

        /* Khóa lô theo cùng thứ tự ID với các nghiệp vụ kho khác. */
        DECLARE @LockLo BIGINT;
        SELECT @LockLo=L.ID FROM dbo.QL_Kho_LoThuoc L WITH(UPDLOCK,HOLDLOCK)
        WHERE L.IDCSKCB=@IDCSKCB AND EXISTS
          (SELECT 1 FROM @Y Y INNER JOIN dbo.QL_Kho_Xuat_CT CT ON CT.ID=Y.IDXuatCT WHERE CT.IDLoThuoc=L.ID)
        ORDER BY L.ID;
        DECLARE @Seq BIGINT=NEXT VALUE FOR dbo.SEQ_SoPhieuHoanKho;
        DECLARE @SoPhieu NVARCHAR(30)=N'HK'+CONVERT(CHAR(8),SYSDATETIME(),112)+RIGHT(N'00000000'+CONVERT(NVARCHAR(20),@Seq),8);
        INSERT dbo.QL_Kho_Hoan(IDCSKCB,IDVaoVien,SoPhieu,NgayHoan,IDNhanVienHoan,LyDo)
        VALUES(@IDCSKCB,@IDVaoVien,@SoPhieu,SYSDATETIME(),@IDNhanVienHoan,ISNULL(@LyDo,N''));
        DECLARE @IDHoan BIGINT=SCOPE_IDENTITY();
        INSERT dbo.QL_Kho_Hoan_CT(IDHoan,IDXuatCT,SoLuongCoSo)
        SELECT @IDHoan,IDXuatCT,SoLuong FROM @Y;
        UPDATE CT SET SoLuongDaHoan=ISNULL(CT.SoLuongDaHoan,0)+Y.SoLuong
        FROM dbo.QL_Kho_Xuat_CT CT INNER JOIN @Y Y ON Y.IDXuatCT=CT.ID;
        UPDATE L SET SoLuongTon=L.SoLuongTon+R.SoLuong
        FROM dbo.QL_Kho_LoThuoc L INNER JOIN
        (SELECT CT.IDLoThuoc,SUM(Y.SoLuong) SoLuong FROM @Y Y
         INNER JOIN dbo.QL_Kho_Xuat_CT CT ON CT.ID=Y.IDXuatCT GROUP BY CT.IDLoThuoc) R ON R.IDLoThuoc=L.ID
        WHERE L.IDCSKCB=@IDCSKCB;
        UPDATE X SET DaHuy=1 FROM dbo.QL_Kho_Xuat X
        WHERE X.IDCSKCB=@IDCSKCB AND X.IDVaoVien=@IDVaoVien AND X.DaHuy=0
          AND NOT EXISTS(SELECT 1 FROM dbo.QL_Kho_Xuat_CT CT WHERE CT.IDCSKCB=X.IDCSKCB AND CT.IDXuat=X.ID
                         AND CT.SoLuongCoSo-ISNULL(CT.SoLuongDaHoan,0)>0);
        COMMIT;
        SELECT 200 AS Status,N'Đã hủy cấp phát và hoàn thuốc về kho.' AS Message,@IDHoan AS IDHoan,@SoPhieu AS SoPhieu;
    END TRY BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 400 AS Status,ERROR_MESSAGE() AS Message;
    END CATCH;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_Xuat_TheoToa
    @IDCSKCB BIGINT,
    @IDKho BIGINT,
    @IDVaoVien BIGINT,
    @IDNhanVienXuat BIGINT,
    @DanhSachJson NVARCHAR(MAX),
    @GhiChu NVARCHAR(500)=NULL,
    @IDTaiKhoanXuat BIGINT=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS(SELECT 1 FROM dbo.DM_Kho WHERE IDCSKCB=@IDCSKCB AND ID=@IDKho AND Active=1)
            THROW 58200,N'Kho không hợp lệ.',1;
        /* Audit actor is loaded from the authenticated account, never chosen by payload. */
        DECLARE @LaAdmin BIT,@IDNhanVienTaiKhoan BIGINT,@TenNguoiXuat NVARCHAR(200);
        SELECT @LaAdmin=T.LaQuanTriHeThong,@IDNhanVienTaiKhoan=T.IDNhanVien,
               @TenNguoiXuat=CASE WHEN T.LaQuanTriHeThong=1 THEN T.Ten_Dang_Nhap ELSE N.HoTen END
        FROM dbo.HT_Tai_Khoan T
        LEFT JOIN dbo.DM_NhanVien N ON N.ID=T.IDNhanVien AND N.Active=1
        WHERE T.ID=@IDTaiKhoanXuat AND T.Active=1
          AND (T.LaQuanTriHeThong=1 OR T.IDCSKCB=@IDCSKCB);
        IF @LaAdmin IS NULL OR NULLIF(LTRIM(RTRIM(@TenNguoiXuat)),N'') IS NULL
            THROW 58200,N'Tài khoản thực hiện không hợp lệ tại cơ sở này.',1;
        IF NOT EXISTS(SELECT 1 FROM dbo.DM_CSKCB WHERE ID=@IDCSKCB AND Active=1)
            THROW 58200,N'Cơ sở làm việc không hợp lệ.',1;
        IF @LaAdmin=1
            SET @IDNhanVienXuat=NULL;
        ELSE
        BEGIN
            IF ISNULL(@IDNhanVienXuat,0)<=0 OR @IDNhanVienXuat<>ISNULL(@IDNhanVienTaiKhoan,0)
               OR NOT EXISTS(SELECT 1 FROM dbo.DM_NhanVien_CSKCB
                             WHERE IDNhanVien=@IDNhanVienXuat AND IDCSKCB=@IDCSKCB AND Active=1)
                THROW 58200,N'Nhân viên xuất kho không thuộc tài khoản/cơ sở này.',1;
        END;
        /* Khóa master lượt khám để không race với hủy thu / chỉnh khám / hoàn kho. */
        DECLARE @VisitState TINYINT;
        SELECT @VisitState=V.TrangThaiKham
        FROM dbo.QL_VaoVien V WITH(UPDLOCK,HOLDLOCK)
        WHERE V.IDCSKCB=@IDCSKCB AND V.ID=@IDVaoVien AND V.Active=1;

        IF ISNULL(@VisitState,255)<>2
            THROW 58200,N'Lượt khám chưa ở trạng thái Khám xong.',1;

        DECLARE @IDThuTien BIGINT;
        SELECT @IDThuTien=T.ID
        FROM dbo.QL_ThuTien T WITH(UPDLOCK,HOLDLOCK)
        WHERE T.IDCSKCB=@IDCSKCB AND T.IDVaoVien=@IDVaoVien;

        IF @IDThuTien IS NULL
            THROW 58200,N'Lượt khám chưa phát sinh thanh toán toa thuốc.',1;

        IF ISJSON(@DanhSachJson)<>1
            THROW 58200,N'Danh sách cấp thuốc không hợp lệ.',1;

        DECLARE @YeuCau TABLE
        (
            STT INT IDENTITY(1,1) PRIMARY KEY,
            IDToaThuocCT BIGINT NOT NULL,
            SoLuongCap DECIMAL(18,4) NOT NULL,
            IDThuoc BIGINT NULL,
            HeSo DECIMAL(18,6) NULL,
            SoLuongCoSo DECIMAL(18,4) NULL,
            ConLaiCoSo DECIMAL(18,4) NULL
        );

        INSERT @YeuCau(IDToaThuocCT,SoLuongCap)
        SELECT J.IDToaThuocCT,SUM(J.SoLuongCap)
        FROM OPENJSON(@DanhSachJson)
        WITH
        (
            IDToaThuocCT BIGINT '$.id_toa_thuoc_ct',
            SoLuongCap DECIMAL(18,4) '$.so_luong_cap'
        ) J
        WHERE J.IDToaThuocCT IS NOT NULL AND ISNULL(J.SoLuongCap,0)>0
        GROUP BY J.IDToaThuocCT;

        IF NOT EXISTS(SELECT 1 FROM @YeuCau)
            THROW 58200,N'Chưa chọn số lượng thuốc cần cấp.',1;

        IF EXISTS
        (
            SELECT 1
            FROM @YeuCau Y
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM dbo.QL_ThuTien_CT PAY WITH(UPDLOCK,HOLDLOCK)
                WHERE PAY.IDCSKCB=@IDCSKCB
                  AND PAY.IDThuTien=@IDThuTien
                  AND PAY.IDToaThuocCT=Y.IDToaThuocCT
                  AND ISNULL(PAY.DaThu,0)=1
            )
        )
            THROW 58200,N'Chỉ được cấp các dòng thuốc đã thu tiền.',1;

        UPDATE Y
        SET IDThuoc=TT.IDThuoc,
            HeSo=Q.HeSoQuyDoi,
            SoLuongCoSo=Y.SoLuongCap*Q.HeSoQuyDoi,
            ConLaiCoSo=TT.SoLuong*Q.HeSoQuyDoi-ISNULL(CAP.da_cap,0)
        FROM @YeuCau Y
        INNER JOIN dbo.QL_ToaThuoc_CT TT
          ON TT.IDCSKCB=@IDCSKCB AND TT.ID=Y.IDToaThuocCT AND TT.IDVaoVien=@IDVaoVien AND TT.Active=1
        INNER JOIN dbo.DM_Thuoc M
          ON M.IDCSKCB=TT.IDCSKCB AND M.ID=TT.IDThuoc
        INNER JOIN dbo.DM_Thuoc_DonViQuyDoi Q
          ON Q.IDCSKCB=TT.IDCSKCB
         AND Q.IDThuoc=TT.IDThuoc
         AND Q.IDDonViTinh=COALESCE(TT.IDDonViTinhDung,M.IDDonViTinh)
         AND Q.Active=1
        OUTER APPLY
        (
            SELECT SUM(XCT.SoLuongCoSo-ISNULL(XCT.SoLuongDaHoan,0)) AS da_cap
            FROM dbo.QL_Kho_Xuat_CT XCT
            INNER JOIN dbo.QL_Kho_Xuat XH
              ON XH.IDCSKCB=XCT.IDCSKCB AND XH.ID=XCT.IDXuat AND XH.DaHuy=0
            WHERE XCT.IDCSKCB=TT.IDCSKCB AND XCT.IDToaThuocCT=TT.ID
        ) CAP;

        IF EXISTS(SELECT 1 FROM @YeuCau WHERE IDThuoc IS NULL OR HeSo IS NULL OR SoLuongCoSo IS NULL)
            THROW 58200,N'Có dòng toa không hợp lệ hoặc chưa cấu hình quy đổi đơn vị.',1;
        IF EXISTS(SELECT 1 FROM @YeuCau WHERE SoLuongCoSo>ConLaiCoSo+0.0001)
            THROW 58200,N'Số lượng cấp vượt quá số lượng còn lại của toa.',1;

        IF EXISTS
        (
            SELECT 1
            FROM @YeuCau Y
            OUTER APPLY
            (
                SELECT SUM(L.SoLuongTon) AS ton
                FROM dbo.QL_Kho_LoThuoc L WITH(UPDLOCK,HOLDLOCK)
                WHERE L.IDCSKCB=@IDCSKCB
                  AND L.IDKho=@IDKho
                  AND L.IDThuoc=Y.IDThuoc
                  AND L.Active=1
                  AND (L.HanDung IS NULL OR L.HanDung>=CONVERT(DATE,SYSDATETIME()))
            ) T
            WHERE ISNULL(T.ton,0)<Y.SoLuongCoSo
        )
            THROW 58200,N'Tồn kho không đủ để cấp số lượng đã chọn.',1;

        DECLARE @Seq BIGINT=NEXT VALUE FOR dbo.SEQ_SoPhieuXuatKho;
        DECLARE @SoPhieu NVARCHAR(30)=N'XK'+CONVERT(CHAR(8),SYSDATETIME(),112)+RIGHT(N'00000000'+CONVERT(NVARCHAR(20),@Seq),8);

        INSERT dbo.QL_Kho_Xuat(IDCSKCB,IDKho,IDVaoVien,SoPhieu,NgayXuat,IDNhanVienXuat,TongGiaVon,GhiChu,DaHuy,IDTaiKhoanXuat,TenNguoiXuatSnapshot)
        VALUES(@IDCSKCB,@IDKho,@IDVaoVien,@SoPhieu,SYSDATETIME(),@IDNhanVienXuat,0,NULLIF(LTRIM(RTRIM(@GhiChu)),N''),0,@IDTaiKhoanXuat,@TenNguoiXuat);

        DECLARE @IDXuat BIGINT=SCOPE_IDENTITY();
        DECLARE @STT INT,@IDToa BIGINT,@IDThuoc BIGINT,@CanCap DECIMAL(18,4);
        DECLARE yc CURSOR LOCAL FAST_FORWARD FOR
            SELECT STT,IDToaThuocCT,IDThuoc,SoLuongCoSo FROM @YeuCau ORDER BY STT;

        OPEN yc;
        FETCH NEXT FROM yc INTO @STT,@IDToa,@IDThuoc,@CanCap;
        WHILE @@FETCH_STATUS=0
        BEGIN
            WHILE @CanCap>0.0001
            BEGIN
                DECLARE @IDLo BIGINT,@TonLo DECIMAL(18,4),@GiaVon DECIMAL(18,4);
                SET @IDLo=NULL;
                SET @TonLo=NULL;
                SET @GiaVon=NULL;
                SELECT TOP(1)
                    @IDLo=L.ID,@TonLo=L.SoLuongTon,@GiaVon=L.GiaNhap
                FROM dbo.QL_Kho_LoThuoc L WITH(UPDLOCK,HOLDLOCK)
                WHERE L.IDCSKCB=@IDCSKCB
                  AND L.IDKho=@IDKho
                  AND L.IDThuoc=@IDThuoc
                  AND L.Active=1
                  AND L.SoLuongTon>0
                  AND (L.HanDung IS NULL OR L.HanDung>=CONVERT(DATE,SYSDATETIME()))
                ORDER BY CASE WHEN L.HanDung IS NULL THEN 1 ELSE 0 END,L.HanDung,L.NgayNhap,L.ID;

                IF @IDLo IS NULL
                    THROW 58200,N'Không còn lô thuốc hợp lệ để xuất.',1;

                DECLARE @Lay DECIMAL(18,4)=CASE WHEN @TonLo>=@CanCap THEN @CanCap ELSE @TonLo END;

                UPDATE dbo.QL_Kho_LoThuoc
                SET SoLuongTon=SoLuongTon-@Lay
                WHERE ID=@IDLo;

                /* Một dòng legacy có thể từng xuất hiện ở nhiều chứng từ do hủy/thu lại.
                   Khi cấp kho chỉ cần truy vết tới nguồn THU hợp lệ hiện tại; ưu tiên phiếu mới nhất. */
                DECLARE @IDNguonThu BIGINT;
                SET @IDNguonThu=NULL;
                SELECT TOP(1) @IDNguonThu=D.ID
                FROM dbo.QL_ThuTien_ChungTu_CT D
                INNER JOIN dbo.QL_ThuTien_ChungTu C ON C.ID=D.IDChungTu
                INNER JOIN dbo.QL_ThuTien_CT P ON P.ID=D.IDThuTienCT
                WHERE C.IDCSKCB=@IDCSKCB
                  AND C.IDVaoVien=@IDVaoVien
                  AND C.Loai='THU'
                  AND C.TrangThai=1
                  AND P.IDToaThuocCT=@IDToa
                  AND ISNULL(P.DaThu,0)=1
                  AND D.Loai=N'THUOC'
                  AND NOT EXISTS
                  (
                      SELECT 1
                      FROM dbo.QL_ThuTien_ChungTu R
                      WHERE R.IDChungTuGoc=C.ID
                        AND R.Loai='HOAN'
                        AND R.TrangThai=1
                  )
                ORDER BY C.NgayGio DESC,C.ID DESC,D.ID DESC;

                IF @IDNguonThu IS NULL
                    THROW 58200,N'Dòng thuốc chưa có chứng từ thu hợp lệ để cấp phát.',1;
                INSERT dbo.QL_Kho_Xuat_CT(IDCSKCB,IDXuat,IDToaThuocCT,IDThuoc,IDLoThuoc,SoLuongCoSo,GiaVon,ThanhTien,IDThuTienChungTuCT,HeSoQuyDoi)
                VALUES(@IDCSKCB,@IDXuat,@IDToa,@IDThuoc,@IDLo,@Lay,@GiaVon,ROUND(@Lay*@GiaVon,2),@IDNguonThu,
                       (SELECT HeSo FROM @YeuCau WHERE STT=@STT));

                SET @CanCap=@CanCap-@Lay;
            END;

            FETCH NEXT FROM yc INTO @STT,@IDToa,@IDThuoc,@CanCap;
        END;
        CLOSE yc;
        DEALLOCATE yc;

        UPDATE H
        SET TongGiaVon=X.Tong
        FROM dbo.QL_Kho_Xuat H
        CROSS APPLY
        (
            SELECT ISNULL(SUM(ThanhTien),0) AS Tong
            FROM dbo.QL_Kho_Xuat_CT C
            WHERE C.IDCSKCB=@IDCSKCB AND C.IDXuat=H.ID
        ) X
        WHERE H.IDCSKCB=@IDCSKCB AND H.ID=@IDXuat;

        COMMIT;
        SELECT 200 AS Status,N'Xuất thuốc thành công.' AS Message,@IDXuat AS IDXuat,@SoPhieu AS SoPhieu;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local','yc')>=-1
        BEGIN
            IF CURSOR_STATUS('local','yc')> -1 CLOSE yc;
            DEALLOCATE yc;
        END;
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 400 AS Status,ERROR_MESSAGE() AS Message,CAST(NULL AS BIGINT) AS IDXuat,CAST(NULL AS NVARCHAR(30)) AS SoPhieu;
    END CATCH;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO


/* =========================================================
   KIỂM TRA TỒN KHO KHI BÁC SĨ KÊ TOA
   - Dùng kho hoạt động duy nhất/đầu tiên của CSKCB.
   - Chỉ tính lô còn hạn sử dụng.
   - Quy đổi tồn kho về đúng ĐVT bác sĩ đang kê.
   - Nếu cùng thuốc xuất hiện nhiều dòng thì cộng tổng nhu cầu
     trước khi kết luận đủ/thiếu.
   ========================================================= */
CREATE   PROCEDURE dbo.STO_QL_Kham_KiemTraTonThuoc
    @IDCSKCB BIGINT,
    @DanhSachJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    IF ISJSON(@DanhSachJson)<>1
        THROW 58200,N'Danh sách thuốc kiểm tra tồn kho không hợp lệ.',1;

    DECLARE @IDKho BIGINT;
    SELECT TOP(1) @IDKho=ID
    FROM dbo.DM_Kho
    WHERE IDCSKCB=@IDCSKCB AND Active=1
    ORDER BY ID;

    DECLARE @YeuCau TABLE
    (
        RowIndex INT NOT NULL,
        IDThuoc BIGINT NOT NULL,
        IDDonViTinh BIGINT NULL,
        SoLuong DECIMAL(18,4) NOT NULL,
        HeSo DECIMAL(18,6) NULL
    );

    INSERT @YeuCau(RowIndex,IDThuoc,IDDonViTinh,SoLuong)
    SELECT
        J.RowIndex,
        J.IDThuoc,
        J.IDDonViTinh,
        CASE WHEN ISNULL(J.SoLuong,0)<0 THEN 0 ELSE ISNULL(J.SoLuong,0) END
    FROM OPENJSON(@DanhSachJson)
    WITH
    (
        RowIndex INT '$.row_index',
        IDThuoc BIGINT '$.id_thuoc',
        IDDonViTinh BIGINT '$.id_don_vi_tinh',
        SoLuong DECIMAL(18,4) '$.so_luong'
    ) J
    WHERE J.IDThuoc IS NOT NULL;

    UPDATE Y
    SET
        IDDonViTinh=COALESCE(Y.IDDonViTinh,M.IDDonViTinh),
        HeSo=CASE
            WHEN COALESCE(Y.IDDonViTinh,M.IDDonViTinh)=M.IDDonViTinh
                THEN COALESCE(Q.HeSoQuyDoi,CAST(1 AS DECIMAL(18,6)))
            ELSE Q.HeSoQuyDoi
        END
    FROM @YeuCau Y
    INNER JOIN dbo.DM_Thuoc M
      ON M.IDCSKCB=@IDCSKCB AND M.ID=Y.IDThuoc AND M.Active=1
    LEFT JOIN dbo.DM_Thuoc_DonViQuyDoi Q
      ON Q.IDCSKCB=@IDCSKCB
     AND Q.IDThuoc=Y.IDThuoc
     AND Q.IDDonViTinh=COALESCE(Y.IDDonViTinh,M.IDDonViTinh)
     AND Q.Active=1;

    ;WITH B AS
    (
        SELECT
            Y.RowIndex AS row_index,
            Y.IDThuoc AS id_thuoc,
            M.MaThuoc AS ma_thuoc,
            M.TenThuoc AS ten_thuoc,
            Y.IDDonViTinh AS id_don_vi_tinh,
            COALESCE(DVTD.TenDVT,DVT.TenDVT,M.DonViTinh) AS don_vi_tinh,
            Y.SoLuong AS so_luong_ke,
            Y.HeSo AS he_so_quy_doi,
            CASE WHEN Y.HeSo IS NULL OR Y.HeSo<=0 THEN NULL ELSE Y.SoLuong*Y.HeSo END AS can_co_so,
            CAST(CASE WHEN @IDKho IS NULL THEN 0 ELSE 1 END AS BIT) AS co_kho,
            CAST(CASE WHEN Y.HeSo IS NULL OR Y.HeSo<=0 THEN 0 ELSE 1 END AS BIT) AS co_quy_doi,
            ISNULL(TON.ton_co_so,0) AS ton_co_so
        FROM @YeuCau Y
        INNER JOIN dbo.DM_Thuoc M
          ON M.IDCSKCB=@IDCSKCB AND M.ID=Y.IDThuoc AND M.Active=1
        LEFT JOIN dbo.DM_DonViTinh DVT
          ON DVT.IDCSKCB=M.IDCSKCB AND DVT.ID=M.IDDonViTinh
        LEFT JOIN dbo.DM_DonViTinh DVTD
          ON DVTD.IDCSKCB=M.IDCSKCB AND DVTD.ID=Y.IDDonViTinh
        OUTER APPLY
        (
            SELECT SUM(L.SoLuongTon) AS ton_co_so
            FROM dbo.QL_Kho_LoThuoc L
            WHERE @IDKho IS NOT NULL
              AND L.IDCSKCB=@IDCSKCB
              AND L.IDKho=@IDKho
              AND L.IDThuoc=Y.IDThuoc
              AND L.Active=1
              AND L.SoLuongTon>0
              AND (L.HanDung IS NULL OR L.HanDung>=CONVERT(DATE,SYSDATETIME()))
        ) TON
    ),
    C AS
    (
        SELECT
            B.*,
            SUM(ISNULL(B.can_co_so,0)) OVER(PARTITION BY B.id_thuoc) AS tong_can_co_so
        FROM B
    )
    SELECT
        row_index,
        id_thuoc,
        ma_thuoc,
        ten_thuoc,
        id_don_vi_tinh,
        don_vi_tinh,
        so_luong_ke,
        he_so_quy_doi,
        co_kho,
        co_quy_doi,
        ton_co_so,
        CASE
            WHEN he_so_quy_doi IS NULL OR he_so_quy_doi<=0 THEN NULL
            ELSE ROUND(ton_co_so/he_so_quy_doi,3)
        END AS ton_theo_dvt,
        tong_can_co_so,
        CAST(CASE
            WHEN co_kho=0 OR co_quy_doi=0 THEN 0
            WHEN ton_co_so+0.0001>=tong_can_co_so THEN 1
            ELSE 0
        END AS BIT) AS du_ton
    FROM C
    ORDER BY row_index;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_PhieuCap_DanhSach @IDCSKCB BIGINT,@IDVaoVien BIGINT
AS
BEGIN
 SET NOCOUNT ON;
 SELECT ID id,SoPhieu so_phieu,NgayXuat ngay_xuat,DaHuy da_huy
 FROM dbo.QL_Kho_Xuat WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND DaHuy=0
 ORDER BY NgayXuat DESC,ID DESC;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_PhieuCap_In @IDCSKCB BIGINT,@IDXuat BIGINT
AS
BEGIN
 SET NOCOUNT ON;
 SELECT X.ID id,X.SoPhieu so_phieu,X.NgayXuat ngay_xuat,X.GhiChu ghi_chu,X.DaHuy da_huy,X.TenNguoiXuatSnapshot nguoi_xuat,
 V.MaVaoVien ma_vao_vien,V.DanDo dan_do,V.NgayTaiKham ngay_tai_kham,
 B.MaBN ma_bn,B.HoTen ho_ten,B.NgaySinh ngay_sinh,GT.TenGioiTinh gioi_tinh,B.DiaChi dia_chi,B.DienThoai dien_thoai,
 B.GiamHo_HoTen giam_ho,B.GiamHo_MoiQuanHe quan_he,
 C.TenCSKCB ten_cskcb,C.DiaChi dia_chi_cskcb,C.SDT sdt_cskcb,C.Email email_cskcb,C.UrlLogo url_logo,
 (SELECT TOP(1) D.GiaTri FROM dbo.QL_PhieuSinhHieu P JOIN dbo.QL_PhieuSinhHieu_CT D ON D.IDCSKCB=P.IDCSKCB AND D.IDPhieuSinhHieu=P.ID
  JOIN dbo.DM_TriSoSinhHieu S ON S.IDCSKCB=D.IDCSKCB AND S.ID=D.IDTriSoSinhHieu AND S.MaTriSo IN(N'CAN_NANG',N'CANNANG')
  WHERE P.IDCSKCB=X.IDCSKCB AND P.IDVaoVien=X.IDVaoVien ORDER BY P.NgayGioDo DESC,P.ID DESC,D.ID DESC) can_nang,
 (SELECT STRING_AGG(CONVERT(NVARCHAR(MAX),CONCAT(N'(',D.MaBenh,N') ',D.TenBenh)),N'; ')
  WITHIN GROUP(ORDER BY D.BenhChinh DESC,D.ThuTu,D.ID) FROM dbo.QL_ChanDoan_CT D WHERE D.IDCSKCB=X.IDCSKCB AND D.IDVaoVien=X.IDVaoVien) chan_doan
 FROM dbo.QL_Kho_Xuat X
 JOIN dbo.QL_VaoVien V ON V.IDCSKCB=X.IDCSKCB AND V.ID=X.IDVaoVien
 JOIN dbo.QL_BenhNhan B ON B.IDCSKCB=V.IDCSKCB AND B.ID=V.IDBenhNhan
 JOIN dbo.DM_CSKCB C ON C.ID=X.IDCSKCB
 LEFT JOIN dbo.DM_GioiTinh GT ON GT.ID=B.IDGioiTinh
 WHERE X.IDCSKCB=@IDCSKCB AND X.ID=@IDXuat AND X.DaHuy=0;

 -- Use the issued quantity and conversion at dispensing, and selling price
 -- from the linked receipt snapshot. Warehouse ThanhTien/GiaVon are cost.
 SELECT CT.IDToaThuocCT id_toa_thuoc_ct,
 COALESCE(D.Ten,M.TenThuoc) ten_thuoc,M.HamLuong ham_luong,COALESCE(NULLIF(T.HoatChat,N''),M.HoatChat) hoat_chat,
 COALESCE(D.DonViTinh,U.TenDVT,M.DonViTinh) don_vi_tinh,
 CAST(SUM(CT.SoLuongCoSo)/NULLIF(CT.HeSoQuyDoi,0) AS DECIMAL(18,4)) so_luong,
 COALESCE(D.DonGia,T.DonGia) don_gia,
 CAST(ROUND((SUM(CT.SoLuongCoSo)/NULLIF(CT.HeSoQuyDoi,0))*COALESCE(D.DonGia,T.DonGia),0) AS DECIMAL(18,2)) thanh_tien,
 SUM(CT.SoLuongDaHoan) da_hoan_co_so,
 CAST(CASE WHEN D.ID IS NULL THEN 1 ELSE 0 END AS BIT) gia_legacy,
 T.Sang sang,T.Trua trua,T.Chieu chieu,T.Toi toi,T.LieuDung lieu_dung,T.CachDung cach_dung,M.DuongDung duong_dung,
 T.MaLoaiToaThuoc ma_loai_toa,T.NgayKe ngay_ke,H.MaToaQuocGia ma_toa,
 LTRIM(RTRIM(CONCAT(CD.VietTat,N' ',NV.HoTen))) bac_si
 FROM dbo.QL_Kho_Xuat_CT CT
 JOIN dbo.QL_Kho_Xuat X ON X.IDCSKCB=CT.IDCSKCB AND X.ID=CT.IDXuat
 JOIN dbo.QL_ToaThuoc_CT T ON T.IDCSKCB=CT.IDCSKCB AND T.ID=CT.IDToaThuocCT AND T.IDVaoVien=X.IDVaoVien
 JOIN dbo.DM_Thuoc M ON M.IDCSKCB=CT.IDCSKCB AND M.ID=CT.IDThuoc
 LEFT JOIN dbo.DM_DonViTinh U ON U.IDCSKCB=T.IDCSKCB AND U.ID=T.IDDonViTinhDung
 LEFT JOIN dbo.QL_ThuTien_ChungTu_CT D ON D.ID=CT.IDThuTienChungTuCT AND D.Loai=N'THUOC'
  AND EXISTS(SELECT 1 FROM dbo.QL_ThuTien_ChungTu C0 WHERE C0.ID=D.IDChungTu AND C0.IDCSKCB=X.IDCSKCB AND C0.IDVaoVien=X.IDVaoVien)
 LEFT JOIN dbo.QL_ToaThuoc H ON H.IDCSKCB=T.IDCSKCB AND H.ID=T.IDToaThuoc
 LEFT JOIN dbo.DM_NhanVien NV ON NV.ID=T.IDBacSiKe
 LEFT JOIN dbo.DM_ChucDanh CD ON CD.ID=NV.IDChucDanh
 WHERE X.IDCSKCB=@IDCSKCB AND X.ID=@IDXuat AND X.DaHuy=0
 GROUP BY CT.IDToaThuocCT,CT.HeSoQuyDoi,D.ID,D.Ten,M.TenThuoc,M.HamLuong,T.HoatChat,M.HoatChat,D.DonViTinh,U.TenDVT,M.DonViTinh,
 D.DonGia,T.DonGia,T.Sang,T.Trua,T.Chieu,T.Toi,T.LieuDung,T.CachDung,M.DuongDung,T.MaLoaiToaThuoc,T.NgayKe,H.MaToaQuocGia,CD.VietTat,NV.HoTen
 ORDER BY T.NgayKe,CT.IDToaThuocCT;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER TRIGGER dbo.TR_QL_Kho_GiaoDich_BatBien
ON dbo.QL_Kho_GiaoDich
INSTEAD OF UPDATE,DELETE
AS
BEGIN
    THROW 59102,N'Sổ giao dịch kho là bất biến; phải tạo bút toán đảo.',1;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_MotKho_Lay
    @IDCSKCB BIGINT,
    @IDKhoYeuCau BIGINT=NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @SoKho INT,@IDKho BIGINT;
    SELECT @SoKho=COUNT(*),@IDKho=MAX(ID)
    FROM dbo.DM_Kho
    WHERE IDCSKCB=@IDCSKCB AND Active=1;

    IF ISNULL(@SoKho,0)<>1
    BEGIN
        SELECT 409 AS Status,N'CSKCB phải có đúng một kho thuốc hoạt động.' AS Message,CAST(NULL AS BIGINT) AS IDKho;
        RETURN;
    END;
    IF @IDKhoYeuCau IS NOT NULL AND @IDKhoYeuCau<>@IDKho
    BEGIN
        SELECT 409 AS Status,N'Kho yêu cầu không phải kho hoạt động của CSKCB.' AS Message,CAST(NULL AS BIGINT) AS IDKho;
        RETURN;
    END;
    SELECT 200 AS Status,N'OK' AS Message,@IDKho AS IDKho;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_Gia_DanhSach
    @IDCSKCB BIGINT,
    @IDThuoc BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT G.ID AS id,G.IDThuoc AS id_thuoc,G.GiaBan AS gia_ban,G.VAT AS vat,
           G.TuNgay AS tu_ngay,G.DenNgay AS den_ngay,G.TenNguoiThucHienSnapshot AS nguoi_thuc_hien,
           G.GhiChu AS ghi_chu,G.NgayTao AS ngay_tao
    FROM dbo.DM_Thuoc_Gia G
    WHERE G.IDCSKCB=@IDCSKCB AND G.IDThuoc=@IDThuoc
    ORDER BY G.TuNgay DESC,G.ID DESC;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_Gia_Luu
    @IDCSKCB BIGINT,
    @IDThuoc BIGINT,
    @GiaBan DECIMAL(18,2),
    @VAT DECIMAL(5,2),
    @TuNgay DATETIME2(0)=NULL,
    @IDTaiKhoan BIGINT,
    @IDNhanVien BIGINT=NULL,
    @GhiChu NVARCHAR(500)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        SET @TuNgay=ISNULL(@TuNgay,SYSDATETIME());
        IF @GiaBan<0 OR @VAT<0 OR @VAT>100
            THROW 59101,N'Giá bán hoặc VAT không hợp lệ.',1;
        IF NOT EXISTS(SELECT 1 FROM dbo.DM_Thuoc WHERE IDCSKCB=@IDCSKCB AND ID=@IDThuoc AND Active=1)
            THROW 59101,N'Thuốc không tồn tại hoặc đã ngừng hoạt động.',1;

        DECLARE @LaAdmin BIT,@IDNhanVienTaiKhoan BIGINT,@TenActor NVARCHAR(200);
        SELECT @LaAdmin=T.LaQuanTriHeThong,@IDNhanVienTaiKhoan=T.IDNhanVien,
               @TenActor=CASE WHEN T.LaQuanTriHeThong=1 THEN T.Ten_Dang_Nhap ELSE N.HoTen END
        FROM dbo.HT_Tai_Khoan T
        LEFT JOIN dbo.DM_NhanVien N ON N.ID=T.IDNhanVien AND N.Active=1
        WHERE T.ID=@IDTaiKhoan AND T.Active=1
          AND (T.LaQuanTriHeThong=1 OR T.IDCSKCB=@IDCSKCB);
        IF @LaAdmin IS NULL OR NULLIF(LTRIM(RTRIM(@TenActor)),N'') IS NULL
            THROW 59101,N'Tài khoản thực hiện không hợp lệ tại CSKCB.',1;
        IF @LaAdmin=1 SET @IDNhanVien=NULL;
        ELSE IF ISNULL(@IDNhanVien,0)<=0 OR @IDNhanVien<>ISNULL(@IDNhanVienTaiKhoan,0)
            THROW 59101,N'Nhân viên thực hiện không thuộc tài khoản.',1;

        DECLARE @GiaTruoc BIGINT,@GiaKeTiep BIGINT,@TuNgayKeTiep DATETIME2(0);
        IF EXISTS
        (
            SELECT 1 FROM dbo.DM_Thuoc_Gia WITH(UPDLOCK,HOLDLOCK)
            WHERE IDCSKCB=@IDCSKCB AND IDThuoc=@IDThuoc AND TuNgay=@TuNgay
        )
            THROW 59101,N'Đã có một mức giá bắt đầu đúng thời điểm này.',1;
        SELECT TOP(1) @GiaTruoc=ID
        FROM dbo.DM_Thuoc_Gia WITH(UPDLOCK,HOLDLOCK)
        WHERE IDCSKCB=@IDCSKCB AND IDThuoc=@IDThuoc AND TuNgay<@TuNgay
        ORDER BY TuNgay DESC,ID DESC;
        SELECT TOP(1) @GiaKeTiep=ID,@TuNgayKeTiep=TuNgay
        FROM dbo.DM_Thuoc_Gia WITH(UPDLOCK,HOLDLOCK)
        WHERE IDCSKCB=@IDCSKCB AND IDThuoc=@IDThuoc AND TuNgay>@TuNgay
        ORDER BY TuNgay,ID;

        UPDATE dbo.DM_Thuoc_Gia SET DenNgay=@TuNgay WHERE ID=@GiaTruoc;
        INSERT dbo.DM_Thuoc_Gia
        (IDCSKCB,IDThuoc,GiaBan,VAT,TuNgay,DenNgay,IDTaiKhoan,IDNhanVien,TenNguoiThucHienSnapshot,GhiChu)
        VALUES(@IDCSKCB,@IDThuoc,@GiaBan,@VAT,@TuNgay,@TuNgayKeTiep,@IDTaiKhoan,@IDNhanVien,@TenActor,NULLIF(LTRIM(RTRIM(@GhiChu)),N''));
        DECLARE @IDGia BIGINT=SCOPE_IDENTITY();
        UPDATE T SET GiaBan=G.GiaBan,VAT=G.VAT
        FROM dbo.DM_Thuoc T
        CROSS APPLY
        (
            SELECT TOP(1) X.GiaBan,X.VAT
            FROM dbo.DM_Thuoc_Gia X
            WHERE X.IDCSKCB=T.IDCSKCB AND X.IDThuoc=T.ID
              AND X.TuNgay<=SYSDATETIME() AND (X.DenNgay IS NULL OR X.DenNgay>SYSDATETIME())
            ORDER BY X.TuNgay DESC,X.ID DESC
        ) G
        WHERE T.IDCSKCB=@IDCSKCB AND T.ID=@IDThuoc;
        COMMIT;
        SELECT 200 AS Status,N'Đã cập nhật giá thuốc.' AS Message,@IDGia AS IDGia;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 400 AS Status,ERROR_MESSAGE() AS Message,CAST(NULL AS BIGINT) AS IDGia;
    END CATCH;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_DanhMuc_NhapHIS
    @IDCSKCB BIGINT,
    @DanhSachJson NVARCHAR(MAX),
    @ChiXemTruoc BIT=1,
    @IDTaiKhoan BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF ISJSON(@DanhSachJson)<>1 OR LEFT(LTRIM(@DanhSachJson),1)<>N'['
        THROW 59101,N'Manifest HIS phải là JSON array hợp lệ.',1;
    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.HT_Tai_Khoan
        WHERE ID=@IDTaiKhoan AND Active=1 AND (LaQuanTriHeThong=1 OR IDCSKCB=@IDCSKCB)
    )
        THROW 59101,N'Tài khoản import không hợp lệ tại CSKCB.',1;

    DECLARE @Nguon TABLE
    (
        STT INT IDENTITY(1,1) PRIMARY KEY,
        IDThuocHIS BIGINT NULL,MaHangHoa NVARCHAR(50) NULL,TenHangHoa NVARCHAR(500) NULL,
        DonViXuat NVARCHAR(100) NULL,DonViNhap NVARCHAR(100) NULL,HeSo DECIMAL(18,6) NULL,
        DuongDung NVARCHAR(200) NULL,HamLuong NVARCHAR(300) NULL,HoatChat NVARCHAR(500) NULL,
        DangBaoChe NVARCHAR(300) NULL,QuyCach NVARCHAR(500) NULL,SoDangKy NVARCHAR(2000) NULL,
        MaVach NVARCHAR(150) NULL,HangSanXuat NVARCHAR(300) NULL,NuocSanXuat NVARCHAR(200) NULL,
        GiaBan DECIMAL(18,2) NULL,VAT DECIMAL(5,2) NULL,SLMin DECIMAL(18,4) NULL,
        SLMax DECIMAL(18,4) NULL,SoNgayCanhBao INT NULL,
        IDThuocQLPM BIGINT NULL,IDDVTXuat BIGINT NULL,IDDVTNhap BIGINT NULL,
        KetQua VARCHAR(20) NULL,Loi NVARCHAR(500) NULL
    );
    INSERT @Nguon
    (
        IDThuocHIS,MaHangHoa,TenHangHoa,DonViXuat,DonViNhap,HeSo,DuongDung,HamLuong,HoatChat,
        DangBaoChe,QuyCach,SoDangKy,MaVach,HangSanXuat,NuocSanXuat,GiaBan,VAT,SLMin,SLMax,SoNgayCanhBao
    )
    SELECT id_his,NULLIF(LTRIM(RTRIM(ma_hang_hoa)),N''),NULLIF(LTRIM(RTRIM(ten_hang_hoa)),N''),
           NULLIF(LTRIM(RTRIM(don_vi_xuat)),N''),NULLIF(LTRIM(RTRIM(don_vi_nhap)),N''),he_so_quy_doi,
           NULLIF(LTRIM(RTRIM(duong_dung)),N''),NULLIF(LTRIM(RTRIM(ham_luong)),N''),NULLIF(LTRIM(RTRIM(hoat_chat)),N''),
           NULLIF(LTRIM(RTRIM(dang_bao_che)),N''),NULLIF(LTRIM(RTRIM(quy_cach)),N''),NULLIF(LTRIM(RTRIM(so_dang_ky)),N''),
           NULLIF(LTRIM(RTRIM(ma_vach)),N''),NULLIF(LTRIM(RTRIM(hang_san_xuat)),N''),NULLIF(LTRIM(RTRIM(nuoc_san_xuat)),N''),
           gia_ban,vat,sl_min,sl_max,so_ngay_canh_bao
    FROM OPENJSON(@DanhSachJson)
    WITH
    (
        id_his BIGINT '$.id_his',ma_hang_hoa NVARCHAR(50) '$.ma_hang_hoa',ten_hang_hoa NVARCHAR(500) '$.ten_hang_hoa',
        don_vi_xuat NVARCHAR(100) '$.don_vi_xuat',don_vi_nhap NVARCHAR(100) '$.don_vi_nhap',he_so_quy_doi DECIMAL(18,6) '$.he_so_quy_doi',
        duong_dung NVARCHAR(200) '$.duong_dung',ham_luong NVARCHAR(300) '$.ham_luong',hoat_chat NVARCHAR(500) '$.hoat_chat',
        dang_bao_che NVARCHAR(300) '$.dang_bao_che',quy_cach NVARCHAR(500) '$.quy_cach',so_dang_ky NVARCHAR(2000) '$.so_dang_ky',
        ma_vach NVARCHAR(150) '$.ma_vach',hang_san_xuat NVARCHAR(300) '$.hang_san_xuat',nuoc_san_xuat NVARCHAR(200) '$.nuoc_san_xuat',
        gia_ban DECIMAL(18,2) '$.gia_ban',vat DECIMAL(5,2) '$.vat',sl_min DECIMAL(18,4) '$.sl_min',
        sl_max DECIMAL(18,4) '$.sl_max',so_ngay_canh_bao INT '$.so_ngay_canh_bao'
    );

    UPDATE N SET IDThuocQLPM=T.ID
    FROM @Nguon N
    INNER JOIN dbo.DM_Thuoc T ON T.IDCSKCB=@IDCSKCB AND T.IDThuocHISNguon=N.IDThuocHIS
    WHERE N.IDThuocHIS IS NOT NULL;
    UPDATE N SET IDThuocQLPM=X.ID
    FROM @Nguon N
    CROSS APPLY
    (
        SELECT MIN(T.ID) AS ID FROM dbo.DM_Thuoc T
        WHERE T.IDCSKCB=@IDCSKCB AND UPPER(LTRIM(RTRIM(T.MaThuoc)))=UPPER(N.MaHangHoa)
        HAVING COUNT(*)=1
    ) X
    WHERE N.IDThuocQLPM IS NULL AND N.MaHangHoa IS NOT NULL;
    UPDATE N SET IDDVTXuat=X.ID
    FROM @Nguon N
    CROSS APPLY
    (
        SELECT MIN(D.ID) AS ID FROM dbo.DM_DonViTinh D
        WHERE D.IDCSKCB=@IDCSKCB AND D.Active=1 AND UPPER(LTRIM(RTRIM(D.TenDVT)))=UPPER(N.DonViXuat)
        HAVING COUNT(*)=1
    ) X;
    UPDATE N SET IDDVTNhap=X.ID
    FROM @Nguon N
    CROSS APPLY
    (
        SELECT MIN(D.ID) AS ID FROM dbo.DM_DonViTinh D
        WHERE D.IDCSKCB=@IDCSKCB AND D.Active=1 AND UPPER(LTRIM(RTRIM(D.TenDVT)))=UPPER(N.DonViNhap)
        HAVING COUNT(*)=1
    ) X;

    UPDATE N SET Loi=CONCAT_WS(N'; ',
        CASE WHEN IDThuocHIS IS NULL THEN N'Thiếu ID HIS' END,
        CASE WHEN MaHangHoa IS NULL THEN N'Thiếu mã hàng hóa' END,
        CASE WHEN TenHangHoa IS NULL THEN N'Thiếu tên thuốc' END,
        CASE WHEN IDThuocHIS IS NOT NULL AND EXISTS(SELECT 1 FROM @Nguon X WHERE X.IDThuocHIS=N.IDThuocHIS AND X.STT<>N.STT) THEN N'Trùng ID HIS trong manifest' END,
        CASE WHEN MaHangHoa IS NOT NULL AND EXISTS(SELECT 1 FROM @Nguon X WHERE UPPER(X.MaHangHoa)=UPPER(N.MaHangHoa) AND X.STT<>N.STT) THEN N'Trùng mã hàng hóa trong manifest' END,
        CASE WHEN MaHangHoa IS NOT NULL AND (SELECT COUNT(*) FROM dbo.DM_Thuoc T WHERE T.IDCSKCB=@IDCSKCB AND UPPER(LTRIM(RTRIM(T.MaThuoc)))=UPPER(N.MaHangHoa))>1 THEN N'Mã thuốc QLPM không duy nhất' END,
        CASE WHEN IDDVTXuat IS NULL THEN N'Không ghép được đơn vị xuất' END,
        CASE WHEN DonViNhap IS NOT NULL AND IDDVTNhap IS NULL THEN N'Không ghép được đơn vị nhập' END,
        CASE WHEN ISNULL(HeSo,0)<=0 THEN N'Hệ số quy đổi không hợp lệ' END,
        CASE WHEN VAT IS NOT NULL AND (VAT<0 OR VAT>100) THEN N'VAT không hợp lệ' END)
    FROM @Nguon N;
    UPDATE @Nguon SET KetQua=CASE WHEN NULLIF(Loi,N'') IS NOT NULL THEN 'LOI' WHEN IDThuocQLPM IS NULL THEN 'THEM' ELSE 'CAP_NHAT' END;

    IF @ChiXemTruoc=0
    BEGIN
        BEGIN TRY
            BEGIN TRAN;
            UPDATE T SET
                IDThuocHISNguon=COALESCE(T.IDThuocHISNguon,N.IDThuocHIS),
                MaThuocHIS=COALESCE(NULLIF(T.MaThuocHIS,N''),N.MaHangHoa),
                IDDonViTinh=COALESCE(T.IDDonViTinh,N.IDDVTXuat),
                DonViTinh=COALESCE(NULLIF(T.DonViTinh,N''),N.DonViXuat),
                DuongDung=COALESCE(NULLIF(T.DuongDung,N''),N.DuongDung),
                HamLuong=COALESCE(NULLIF(T.HamLuong,N''),N.HamLuong),
                HoatChat=COALESCE(NULLIF(T.HoatChat,N''),N.HoatChat),
                DangBaoChe=COALESCE(NULLIF(T.DangBaoChe,N''),N.DangBaoChe),
                QuyCachDongGoi=COALESCE(NULLIF(T.QuyCachDongGoi,N''),N.QuyCach),
                SoDangKy=COALESCE(NULLIF(T.SoDangKy,N''),N.SoDangKy),MaVach=COALESCE(NULLIF(T.MaVach,N''),N.MaVach),
                HangSanXuat=COALESCE(NULLIF(T.HangSanXuat,N''),N.HangSanXuat),NuocSanXuat=COALESCE(NULLIF(T.NuocSanXuat,N''),N.NuocSanXuat),
                SoLuongTonToiThieu=COALESCE(T.SoLuongTonToiThieu,N.SLMin),SoLuongTonToiDa=COALESCE(T.SoLuongTonToiDa,N.SLMax),
                SoNgayCanhBaoHanDung=COALESCE(T.SoNgayCanhBaoHanDung,N.SoNgayCanhBao)
            FROM dbo.DM_Thuoc T INNER JOIN @Nguon N ON N.IDThuocQLPM=T.ID
            WHERE N.KetQua='CAP_NHAT';

            INSERT dbo.DM_Thuoc
            (IDCSKCB,MaThuoc,TenThuoc,IDDonViTinh,DonViTinh,DuongDung,HamLuong,HoatChat,GiaBan,Active,
             IDThuocHISNguon,MaThuocHIS,DangBaoChe,QuyCachDongGoi,SoDangKy,MaVach,HangSanXuat,NuocSanXuat,
             SoLuongTonToiThieu,SoLuongTonToiDa,SoNgayCanhBaoHanDung,VAT)
            SELECT @IDCSKCB,N.MaHangHoa,N.TenHangHoa,N.IDDVTXuat,N.DonViXuat,N.DuongDung,N.HamLuong,N.HoatChat,
                   ISNULL(N.GiaBan,0),1,N.IDThuocHIS,N.MaHangHoa,N.DangBaoChe,N.QuyCach,N.SoDangKy,N.MaVach,
                   N.HangSanXuat,N.NuocSanXuat,N.SLMin,N.SLMax,N.SoNgayCanhBao,ISNULL(N.VAT,0)
            FROM @Nguon N WHERE N.KetQua='THEM';

            UPDATE N SET IDThuocQLPM=T.ID
            FROM @Nguon N INNER JOIN dbo.DM_Thuoc T
              ON T.IDCSKCB=@IDCSKCB AND T.IDThuocHISNguon=N.IDThuocHIS
            WHERE N.KetQua='THEM';

            MERGE dbo.DM_Thuoc_DonViQuyDoi AS Q
            USING
            (
                SELECT DISTINCT @IDCSKCB IDCSKCB,IDThuocQLPM IDThuoc,IDDVTXuat IDDonViTinh,CONVERT(DECIMAL(18,6),1) HeSo,CONVERT(BIT,1) LaCoSo
                FROM @Nguon WHERE KetQua<>'LOI'
                UNION ALL
                SELECT DISTINCT @IDCSKCB,IDThuocQLPM,IDDVTNhap,HeSo,CONVERT(BIT,0)
                FROM @Nguon WHERE KetQua<>'LOI' AND IDDVTNhap IS NOT NULL AND IDDVTNhap<>IDDVTXuat
            ) S
            ON Q.IDCSKCB=S.IDCSKCB AND Q.IDThuoc=S.IDThuoc AND Q.IDDonViTinh=S.IDDonViTinh
            WHEN MATCHED THEN UPDATE SET HeSoQuyDoi=S.HeSo,LaDonViCoSo=S.LaCoSo,Active=1
            WHEN NOT MATCHED THEN INSERT(IDCSKCB,IDThuoc,IDDonViTinh,HeSoQuyDoi,LaDonViCoSo,Active)
                VALUES(S.IDCSKCB,S.IDThuoc,S.IDDonViTinh,S.HeSo,S.LaCoSo,1);

            INSERT dbo.DM_Thuoc_Gia
            (IDCSKCB,IDThuoc,GiaBan,VAT,TuNgay,IDTaiKhoan,IDNhanVien,TenNguoiThucHienSnapshot,GhiChu)
            SELECT @IDCSKCB,N.IDThuocQLPM,ISNULL(N.GiaBan,0),ISNULL(N.VAT,0),SYSDATETIME(),@IDTaiKhoan,NULL,
                   N'Import HIS v101',N'Giá mở đầu từ manifest HIS'
            FROM @Nguon N
            WHERE N.KetQua='THEM' AND NOT EXISTS
            (
                SELECT 1 FROM dbo.DM_Thuoc_Gia G
                WHERE G.IDCSKCB=@IDCSKCB AND G.IDThuoc=N.IDThuocQLPM
            );
            COMMIT;
        END TRY
        BEGIN CATCH
            IF XACT_STATE()<>0 ROLLBACK;
            THROW;
        END CATCH;
    END;

    SELECT STT AS stt,IDThuocHIS AS id_his,MaHangHoa AS ma_hang_hoa,TenHangHoa AS ten_hang_hoa,
           IDThuocQLPM AS id_thuoc_qlpm,KetQua AS ket_qua,NULLIF(Loi,N'') AS loi,
           DonViXuat AS don_vi_xuat,DonViNhap AS don_vi_nhap,HeSo AS he_so_quy_doi
    FROM @Nguon ORDER BY STT;
    SELECT COUNT(*) AS tong_so,
           SUM(CASE WHEN KetQua='THEM' THEN 1 ELSE 0 END) AS so_them,
           SUM(CASE WHEN KetQua='CAP_NHAT' THEN 1 ELSE 0 END) AS so_cap_nhat,
           SUM(CASE WHEN KetQua='LOI' THEN 1 ELSE 0 END) AS so_loi,
           @ChiXemTruoc AS chi_xem_truoc
    FROM @Nguon;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_TongQuan
    @IDCSKCB BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @IDKho BIGINT; SELECT @IDKho=ID FROM dbo.DM_Kho WHERE IDCSKCB=@IDCSKCB AND Active=1;
    SELECT @IDKho AS id_kho,K.TenKho AS ten_kho,COUNT(DISTINCT T.ID) AS so_thuoc,
           SUM(ISNULL(L.SoLuongTon,0)) AS ton_vat_ly,
           SUM(CASE WHEN L.Active=1 AND L.BiKhoaXuat=0 AND (L.HanDung IS NULL OR L.HanDung>=CONVERT(DATE,SYSDATETIME())) THEN L.SoLuongTon ELSE 0 END) AS ton_kha_dung,
           SUM(CASE WHEN L.BiKhoaXuat=1 THEN L.SoLuongTon ELSE 0 END) AS ton_bi_khoa,
           SUM(CASE WHEN L.HanDung<CONVERT(DATE,SYSDATETIME()) THEN L.SoLuongTon ELSE 0 END) AS ton_het_han,
           SUM(CASE WHEN L.SoLuongTon>0 AND L.HanDung>=CONVERT(DATE,SYSDATETIME()) AND L.HanDung<DATEADD(DAY,ISNULL(T.SoNgayCanhBaoHanDung,30),CONVERT(DATE,SYSDATETIME())) THEN 1 ELSE 0 END) AS so_lo_sap_het_han
    FROM dbo.DM_Kho K LEFT JOIN dbo.QL_Kho_LoThuoc L ON L.IDCSKCB=K.IDCSKCB AND L.IDKho=K.ID
    LEFT JOIN dbo.DM_Thuoc T ON T.IDCSKCB=L.IDCSKCB AND T.ID=L.IDThuoc
    WHERE K.IDCSKCB=@IDCSKCB AND K.ID=@IDKho
    GROUP BY K.TenKho;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_DanhMuc_DanhSach
    @IDCSKCB BIGINT,@TuKhoa NVARCHAR(300)=NULL,@Trang INT=1,@KichThuocTrang INT=25
AS
BEGIN
    SET NOCOUNT ON;
    SET @TuKhoa=NULLIF(LTRIM(RTRIM(@TuKhoa)),N''); SET @Trang=IIF(@Trang<1,1,@Trang);
    SET @KichThuocTrang=CASE WHEN @KichThuocTrang<10 THEN 10 WHEN @KichThuocTrang>100 THEN 100 ELSE @KichThuocTrang END;
    SELECT COUNT_BIG(*) tong_so FROM dbo.DM_Thuoc T WHERE T.IDCSKCB=@IDCSKCB AND (@TuKhoa IS NULL OR T.MaThuoc LIKE N'%'+@TuKhoa+N'%' OR T.TenThuoc LIKE N'%'+@TuKhoa+N'%');
    SELECT T.ID AS id,T.MaThuoc AS ma_thuoc,T.TenThuoc AS ten_thuoc,COALESCE(D.TenDVT,T.DonViTinh) AS don_vi_tinh,
           T.HoatChat AS hoat_chat,T.HamLuong AS ham_luong,T.DuongDung AS duong_dung,T.DangBaoChe AS dang_bao_che,
           T.QuyCachDongGoi AS quy_cach,T.SoDangKy AS so_dang_ky,T.MaVach AS ma_vach,T.HangSanXuat AS hang_san_xuat,
           T.NuocSanXuat AS nuoc_san_xuat,T.GiaBan AS gia_ban,T.VAT AS vat,T.SoLuongTonToiThieu AS ton_toi_thieu,
           T.SoLuongTonToiDa AS ton_toi_da,T.SoNgayCanhBaoHanDung AS so_ngay_canh_bao,T.IDThuocHISNguon AS id_his,T.MaThuocHIS AS ma_his,T.Active AS active
    FROM dbo.DM_Thuoc T LEFT JOIN dbo.DM_DonViTinh D ON D.IDCSKCB=T.IDCSKCB AND D.ID=T.IDDonViTinh
    WHERE T.IDCSKCB=@IDCSKCB AND (@TuKhoa IS NULL OR T.MaThuoc LIKE N'%'+@TuKhoa+N'%' OR T.TenThuoc LIKE N'%'+@TuKhoa+N'%')
    ORDER BY T.TenThuoc,T.ID OFFSET (@Trang-1)*@KichThuocTrang ROWS FETCH NEXT @KichThuocTrang ROWS ONLY;
END;

GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_BaoCao
    @IDCSKCB BIGINT,@Loai VARCHAR(30),@TuNgay DATE=NULL,@DenNgay DATE=NULL,@IDThuoc BIGINT=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Loai=UPPER(LTRIM(RTRIM(ISNULL(@Loai,''))));
    SET @TuNgay=ISNULL(@TuNgay,CONVERT(DATE,DATEADD(DAY,-30,SYSDATETIME()))); SET @DenNgay=ISNULL(@DenNgay,CONVERT(DATE,SYSDATETIME()));
    IF @DenNgay<@TuNgay THROW 59103,N'Khoảng ngày báo cáo không hợp lệ.',1;

    IF @Loai='TON_TONG_HOP'
    BEGIN
        SELECT T.MaThuoc AS ma_thuoc,T.TenThuoc AS ten_thuoc,COALESCE(D.TenDVT,T.DonViTinh) AS don_vi_tinh,
               SUM(L.SoLuongTon) AS ton_vat_ly,
               SUM(CASE WHEN L.Active=1 AND L.BiKhoaXuat=0 AND (L.HanDung IS NULL OR L.HanDung>=CONVERT(DATE,SYSDATETIME())) THEN L.SoLuongTon ELSE 0 END) AS ton_kha_dung,
               SUM(CASE WHEN L.BiKhoaXuat=1 THEN L.SoLuongTon ELSE 0 END) AS ton_bi_khoa,
               SUM(CASE WHEN L.HanDung<CONVERT(DATE,SYSDATETIME()) THEN L.SoLuongTon ELSE 0 END) AS ton_het_han,
               SUM(L.SoLuongTon*L.GiaNhap) AS gia_tri_ton
        FROM dbo.DM_Thuoc T LEFT JOIN dbo.DM_DonViTinh D ON D.IDCSKCB=T.IDCSKCB AND D.ID=T.IDDonViTinh
        LEFT JOIN dbo.QL_Kho_LoThuoc L ON L.IDCSKCB=T.IDCSKCB AND L.IDThuoc=T.ID
        WHERE T.IDCSKCB=@IDCSKCB AND (@IDThuoc IS NULL OR T.ID=@IDThuoc)
        GROUP BY T.MaThuoc,T.TenThuoc,D.TenDVT,T.DonViTinh ORDER BY T.TenThuoc; RETURN;
    END;
    IF @Loai='TON_THEO_LO'
    BEGIN
        SELECT T.MaThuoc AS ma_thuoc,T.TenThuoc AS ten_thuoc,L.SoLo AS so_lo,L.HanDung AS han_dung,L.SoLuongTon AS so_luong_ton,
               L.GiaNhap AS gia_nhap,L.SoLuongTon*L.GiaNhap AS gia_tri,L.BiKhoaXuat AS bi_khoa,
               CASE WHEN L.BiKhoaXuat=1 THEN N'Bị khóa' WHEN L.HanDung<CONVERT(DATE,SYSDATETIME()) THEN N'Hết hạn' ELSE N'Khả dụng' END AS trang_thai
        FROM dbo.QL_Kho_LoThuoc L INNER JOIN dbo.DM_Thuoc T ON T.IDCSKCB=L.IDCSKCB AND T.ID=L.IDThuoc
        WHERE L.IDCSKCB=@IDCSKCB AND L.SoLuongTon<>0 AND (@IDThuoc IS NULL OR L.IDThuoc=@IDThuoc)
        ORDER BY T.TenThuoc,L.HanDung,L.ID; RETURN;
    END;
    IF @Loai='NHAP_XUAT_TON'
    BEGIN
        SELECT T.MaThuoc AS ma_thuoc,T.TenThuoc AS ten_thuoc,
               SUM(CASE WHEN G.NgayGiaoDich<@TuNgay THEN G.SoLuong ELSE 0 END) AS ton_dau,
               SUM(CASE WHEN G.NgayGiaoDich>=@TuNgay AND G.NgayGiaoDich<DATEADD(DAY,1,@DenNgay) AND G.SoLuong>0 THEN G.SoLuong ELSE 0 END) AS nhap,
               -SUM(CASE WHEN G.NgayGiaoDich>=@TuNgay AND G.NgayGiaoDich<DATEADD(DAY,1,@DenNgay) AND G.SoLuong<0 THEN G.SoLuong ELSE 0 END) AS xuat,
               SUM(CASE WHEN G.NgayGiaoDich<DATEADD(DAY,1,@DenNgay) THEN G.SoLuong ELSE 0 END) AS ton_cuoi
        FROM dbo.DM_Thuoc T LEFT JOIN dbo.QL_Kho_GiaoDich G ON G.IDCSKCB=T.IDCSKCB AND G.IDThuoc=T.ID
        WHERE T.IDCSKCB=@IDCSKCB AND (@IDThuoc IS NULL OR T.ID=@IDThuoc)
        GROUP BY T.MaThuoc,T.TenThuoc ORDER BY T.TenThuoc; RETURN;
    END;
    IF @Loai='THE_KHO'
    BEGIN
        IF @IDThuoc IS NULL THROW 59103,N'Thẻ kho yêu cầu chọn thuốc.',1;
        SELECT G.ID AS stt,G.NgayGiaoDich AS ngay_gio,G.LoaiGiaoDich AS loai_giao_dich,G.LoaiChungTu AS loai_chung_tu,G.IDChungTu AS id_chung_tu,
               L.SoLo AS so_lo,L.HanDung AS han_dung,CASE WHEN G.SoLuong>0 THEN G.SoLuong ELSE 0 END AS nhap,
               CASE WHEN G.SoLuong<0 THEN -G.SoLuong ELSE 0 END AS xuat,
               SUM(G.SoLuong) OVER(ORDER BY G.NgayGiaoDich,G.ID ROWS UNBOUNDED PRECEDING) AS ton_luy_ke,
               G.GiaVon AS gia_von,G.TenNguoiThucHienSnapshot AS nguoi_thuc_hien,G.GhiChu AS ghi_chu
        FROM dbo.QL_Kho_GiaoDich G INNER JOIN dbo.QL_Kho_LoThuoc L ON L.ID=G.IDLoThuoc
        WHERE G.IDCSKCB=@IDCSKCB AND G.IDThuoc=@IDThuoc AND G.NgayGiaoDich<DATEADD(DAY,1,@DenNgay)
        ORDER BY G.NgayGiaoDich,G.ID; RETURN;
    END;
    IF @Loai='CANH_BAO'
    BEGIN
        ;WITH X AS
        (
            SELECT T.ID,T.MaThuoc,T.TenThuoc,T.SoLuongTonToiThieu,T.SoLuongTonToiDa,T.SoNgayCanhBaoHanDung,
                   SUM(CASE WHEN L.Active=1 AND L.BiKhoaXuat=0 AND (L.HanDung IS NULL OR L.HanDung>=CONVERT(DATE,SYSDATETIME())) THEN L.SoLuongTon ELSE 0 END) kha_dung,
                   SUM(CASE WHEN L.SoLuongTon>0 AND L.HanDung<CONVERT(DATE,SYSDATETIME()) THEN L.SoLuongTon ELSE 0 END) het_han,
                   MIN(CASE WHEN L.SoLuongTon>0 AND L.HanDung>=CONVERT(DATE,SYSDATETIME()) THEN L.HanDung END) han_gan_nhat
            FROM dbo.DM_Thuoc T LEFT JOIN dbo.QL_Kho_LoThuoc L ON L.IDCSKCB=T.IDCSKCB AND L.IDThuoc=T.ID
            WHERE T.IDCSKCB=@IDCSKCB AND T.Active=1 GROUP BY T.ID,T.MaThuoc,T.TenThuoc,T.SoLuongTonToiThieu,T.SoLuongTonToiDa,T.SoNgayCanhBaoHanDung
        )
        SELECT MaThuoc AS ma_thuoc,TenThuoc AS ten_thuoc,kha_dung AS ton_kha_dung,het_han AS ton_het_han,han_gan_nhat,
               SoLuongTonToiThieu AS ton_toi_thieu,SoLuongTonToiDa AS ton_toi_da,
               CONCAT_WS(N'; ',CASE WHEN SoLuongTonToiThieu IS NOT NULL AND kha_dung<SoLuongTonToiThieu THEN N'Dưới tồn tối thiểu' END,
                    CASE WHEN SoLuongTonToiDa IS NOT NULL AND kha_dung>SoLuongTonToiDa THEN N'Vượt tồn tối đa' END,
                    CASE WHEN het_han>0 THEN N'Có lô hết hạn' END,
                    CASE WHEN han_gan_nhat<DATEADD(DAY,ISNULL(SoNgayCanhBaoHanDung,30),CONVERT(DATE,SYSDATETIME())) THEN N'Sắp hết hạn' END) AS canh_bao
        FROM X WHERE (SoLuongTonToiThieu IS NOT NULL AND kha_dung<SoLuongTonToiThieu)
          OR (SoLuongTonToiDa IS NOT NULL AND kha_dung>SoLuongTonToiDa) OR het_han>0
          OR han_gan_nhat<DATEADD(DAY,ISNULL(SoNgayCanhBaoHanDung,30),CONVERT(DATE,SYSDATETIME()))
        ORDER BY TenThuoc; RETURN;
    END;
    IF @Loai='NHAP_CHI_TIET'
    BEGIN
        SELECT H.SoPhieu AS so_phieu,H.NgayNhap AS ngay_gio,C.MaThuocSnapshot AS ma_thuoc,C.TenThuocSnapshot AS ten_thuoc,
               C.SoLo AS so_lo,C.HanDung AS han_dung,C.SoLuong AS so_luong,C.DonViTinhSnapshot AS don_vi_tinh,C.GiaNhap AS don_gia,
               C.VAT AS vat,C.ThanhTien+C.TienVAT AS thanh_tien,H.TenNhaCungCapSnapshot AS doi_tac,H.DaHuy AS da_huy
        FROM dbo.QL_Kho_Nhap H INNER JOIN dbo.QL_Kho_Nhap_CT C ON C.IDCSKCB=H.IDCSKCB AND C.IDNhap=H.ID
        WHERE H.IDCSKCB=@IDCSKCB AND H.NgayNhap>=@TuNgay AND H.NgayNhap<DATEADD(DAY,1,@DenNgay)
        ORDER BY H.NgayNhap,H.ID,C.ID; RETURN;
    END;
    IF @Loai='CAP_PHAT_CHI_TIET'
    BEGIN
        SELECT H.SoPhieu AS so_phieu,H.NgayXuat AS ngay_gio,T.MaThuoc AS ma_thuoc,T.TenThuoc AS ten_thuoc,L.SoLo AS so_lo,L.HanDung AS han_dung,
               C.SoLuongCoSo AS so_luong,C.SoLuongDaHoan AS da_hoan,C.GiaVon AS don_gia,C.ThanhTien AS thanh_tien,H.TenNguoiXuatSnapshot AS nguoi_thuc_hien,H.DaHuy AS da_huy
        FROM dbo.QL_Kho_Xuat H INNER JOIN dbo.QL_Kho_Xuat_CT C ON C.IDCSKCB=H.IDCSKCB AND C.IDXuat=H.ID
        INNER JOIN dbo.DM_Thuoc T ON T.IDCSKCB=C.IDCSKCB AND T.ID=C.IDThuoc INNER JOIN dbo.QL_Kho_LoThuoc L ON L.ID=C.IDLoThuoc
        WHERE H.IDCSKCB=@IDCSKCB AND H.NgayXuat>=@TuNgay AND H.NgayXuat<DATEADD(DAY,1,@DenNgay)
        ORDER BY H.NgayXuat,H.ID,C.ID; RETURN;
    END;
    THROW 59103,N'Loại báo cáo không được hỗ trợ.',1;
END;

GO
