USE [QLPM];
GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_DieuChinh_Luu
    @IDCSKCB BIGINT,@IDKho BIGINT=NULL,@Loai VARCHAR(20),@IDNhanVien BIGINT,
    @LyDo NVARCHAR(500),@DanhSachJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    SET @Loai=UPPER(LTRIM(RTRIM(ISNULL(@Loai,'')))); SET @LyDo=NULLIF(LTRIM(RTRIM(@LyDo)),N'');
    IF @IDKho IS NULL
        SELECT TOP(1) @IDKho=ID FROM dbo.DM_Kho WHERE IDCSKCB=@IDCSKCB AND Active=1 ORDER BY ID;
    BEGIN TRY
        BEGIN TRAN;
        IF @Loai NOT IN('DIEU_CHINH','HUY_THUOC') THROW 58200,N'Loại chứng từ kho không hợp lệ.',1;
        IF @IDNhanVien<=0 THROW 58200,N'Không xác định được nhân viên thực hiện.',1;
        IF @LyDo IS NULL THROW 58200,N'Phải nhập lý do điều chỉnh/hủy thuốc.',1;
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
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_KhoaLo_Luu
    @IDCSKCB BIGINT,@IDLoThuoc BIGINT,@Khoa BIT,@LyDo NVARCHAR(500),@IDTaiKhoan BIGINT,@IDNhanVien BIGINT=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        SET @LyDo=NULLIF(LTRIM(RTRIM(@LyDo)),N''); IF @LyDo IS NULL THROW 59102,N'Phải nhập lý do khóa/mở lô.',1;
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
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_KiemKe_HuyNhap
    @IDCSKCB BIGINT,@IDKiemKe BIGINT,@IDTaiKhoan BIGINT,@IDNhanVien BIGINT=NULL,@LyDo NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LaAdmin BIT,@IDNVTK BIGINT,@TenActor NVARCHAR(200);
    SET @LyDo=NULLIF(LTRIM(RTRIM(@LyDo)),N'');
    SELECT @LaAdmin=T.LaQuanTriHeThong,@IDNVTK=T.IDNhanVien,@TenActor=CASE WHEN T.LaQuanTriHeThong=1 THEN T.Ten_Dang_Nhap ELSE N.HoTen END
    FROM dbo.HT_Tai_Khoan T LEFT JOIN dbo.DM_NhanVien N ON N.ID=T.IDNhanVien AND N.Active=1
    WHERE T.ID=@IDTaiKhoan AND T.Active=1 AND (T.LaQuanTriHeThong=1 OR T.IDCSKCB=@IDCSKCB);
    IF @LaAdmin IS NULL OR @LyDo IS NULL
    BEGIN SELECT 400 AS Status,N'Tài khoản hoặc lý do hủy không hợp lệ.' AS Message; RETURN; END;
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
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_Nhap_Huy
    @IDCSKCB BIGINT,@IDNhap BIGINT,@IDNhanVienHuy BIGINT,@LyDo NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON; SET @LyDo=NULLIF(LTRIM(RTRIM(@LyDo)),N'');
    BEGIN TRY
        BEGIN TRAN;
        IF @LyDo IS NULL OR @IDNhanVienHuy<=0 THROW 58100,N'Thiếu nhân viên hoặc lý do hủy.',1;
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
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_Xuat_Hoan
    @IDCSKCB BIGINT, @IDVaoVien BIGINT, @IDNhanVienHoan BIGINT,
    @LyDo NVARCHAR(500)=NULL, @DanhSachJson NVARCHAR(MAX)=N'[]', @HoanToanBo BIT=0
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    SET @LyDo=NULLIF(LTRIM(RTRIM(@LyDo)),N'');
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
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_XuatKhac_Huy
    @IDCSKCB BIGINT,@IDChungTu BIGINT,@LyDo NVARCHAR(500),@IDTaiKhoan BIGINT,@IDNhanVien BIGINT=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        SET @LyDo=NULLIF(LTRIM(RTRIM(@LyDo)),N''); IF @LyDo IS NULL THROW 59102,N'Phải nhập lý do hủy.',1;
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
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_XuatKhac_Luu
    @IDCSKCB BIGINT,@Loai VARCHAR(25),@IDNhaCungCap BIGINT=NULL,@NoiNhan NVARCHAR(300)=NULL,
    @LyDo NVARCHAR(500),@DanhSachJson NVARCHAR(MAX),@IDTaiKhoan BIGINT,@IDNhanVien BIGINT=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        SET @Loai=UPPER(LTRIM(RTRIM(ISNULL(@Loai,'')))); SET @LyDo=NULLIF(LTRIM(RTRIM(@LyDo)),N'');
        IF @Loai NOT IN('NOI_BO','TRA_NHA_CUNG_CAP','THANH_LY') OR @LyDo IS NULL
            THROW 59102,N'Loại xuất hoặc lý do không hợp lệ.',1;
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
CREATE OR ALTER PROCEDURE dbo.STO_QL_ThuNgan_HoanTien
    @IDCSKCB BIGINT,@IDChungTuGoc BIGINT,@LyDo NVARCHAR(500),@IDNhanVien BIGINT=NULL,@IDTaiKhoan BIGINT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON; SET @LyDo=NULLIF(LTRIM(RTRIM(@LyDo)),N'');
    BEGIN TRY
        BEGIN TRAN;
        IF @LyDo IS NULL THROW 58000,N'Phải nhập lý do hoàn tiền.',1;
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
CREATE OR ALTER PROCEDURE dbo.STO_QL_ThuNgan_HuyChungTu
    @IDCSKCB BIGINT,@IDChungTu BIGINT,@LyDo NVARCHAR(500)=NULL,@IDNhanVien BIGINT=NULL,@IDTaiKhoan BIGINT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON; SET @LyDo=NULLIF(LTRIM(RTRIM(@LyDo)),N'');
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
