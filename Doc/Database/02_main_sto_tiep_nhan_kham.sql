/* Canonical STO contract for tiep nhan va kham benh cua nhanh main. */

USE [QLPM];

GO

SET ANSI_NULLS ON;

SET QUOTED_IDENTIFIER ON;

GO

SET NOCOUNT ON;

SET XACT_ABORT ON;

GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_ThuTien_CapNhatTong @IDCSKCB BIGINT,@IDVaoVien BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE T SET TongTien=X.Tong,TienGiam=X.Giam,ThucThu=X.Thuc
    FROM dbo.QL_ThuTien T CROSS APPLY(SELECT ISNULL(SUM(ThanhTien),0) Tong,ISNULL(SUM(TienGiam),0) Giam,ISNULL(SUM(ThucThu),0) Thuc FROM dbo.QL_ThuTien_CT WHERE IDCSKCB=@IDCSKCB AND IDThuTien=T.ID) X
    WHERE T.IDCSKCB=@IDCSKCB AND T.IDVaoVien=@IDVaoVien;
END;

GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_TiepNhan_DanhSach
    @IDCSKCB BIGINT,
    @TuNgay DATE=NULL,
    @DenNgay DATE=NULL,
    @DaChuyenKham BIT=NULL,
    @TuKhoa NVARCHAR(200)=NULL,
    @Trang INT=1,
    @KichThuocTrang INT=25
AS
BEGIN
    SET NOCOUNT ON;
    SET @TuKhoa=NULLIF(LTRIM(RTRIM(@TuKhoa)),N'');
    IF @Trang IS NULL OR @Trang<1 SET @Trang=1;
    IF @KichThuocTrang IS NULL OR @KichThuocTrang<1 SET @KichThuocTrang=25;
    IF @KichThuocTrang>100 SET @KichThuocTrang=100;
    DECLARE @Offset BIGINT=(CONVERT(BIGINT,@Trang)-1)*@KichThuocTrang;

    IF @TuKhoa IS NOT NULL
    BEGIN
        ;WITH TimBN AS
        (
            SELECT TOP(500)
                B.*,
                CASE
                    WHEN B.MaBN=@TuKhoa OR B.SoCCCD=@TuKhoa OR B.DienThoai=@TuKhoa THEN 0
                    WHEN B.MaBN LIKE @TuKhoa+N'%' OR B.SoCCCD LIKE @TuKhoa+N'%' OR B.DienThoai LIKE @TuKhoa+N'%' THEN 1
                    WHEN B.HoTen LIKE @TuKhoa+N'%' THEN 2
                    ELSE 3
                END AS DiemTim
            FROM dbo.QL_BenhNhan B
            WHERE B.IDCSKCB=@IDCSKCB AND B.Active=1
              AND
              (
                  B.MaBN=@TuKhoa OR B.SoCCCD=@TuKhoa OR B.DienThoai=@TuKhoa
                  OR B.MaBN LIKE @TuKhoa+N'%'
                  OR B.SoCCCD LIKE @TuKhoa+N'%'
                  OR B.DienThoai LIKE @TuKhoa+N'%'
                  OR B.HoTen LIKE N'%'+@TuKhoa+N'%'
              )
            ORDER BY
                CASE
                    WHEN B.MaBN=@TuKhoa OR B.SoCCCD=@TuKhoa OR B.DienThoai=@TuKhoa THEN 0
                    WHEN B.MaBN LIKE @TuKhoa+N'%' OR B.SoCCCD LIKE @TuKhoa+N'%' OR B.DienThoai LIKE @TuKhoa+N'%' THEN 1
                    WHEN B.HoTen LIKE @TuKhoa+N'%' THEN 2
                    ELSE 3
                END,
                B.NgayTao DESC,B.ID DESC
        ),
        X AS
        (
            SELECT
                VV.ID AS IDVaoVien,VV.MaVaoVien,VV.NgayGioVaoVien,VV.Ngay,VV.SoThuTu,
                ISNULL(VV.DaChuyenKham,0) AS DaChuyenKham,ISNULL(VV.TrangThaiKham,0) AS TrangThaiKham,
                ISNULL(VV.SinhHieu,0) AS SinhHieu,ISNULL(VV.Kham,0) AS Kham,ISNULL(VV.KeToa,0) AS KeToa,
                VV.IDNguoiTiepNhan,
                B.ID AS IDBenhNhan,B.MaBN,B.HoTen,B.NgaySinh,B.IDGioiTinh,GT.TenGioiTinh,B.SoCCCD,B.DienThoai,B.DiaChi,
                B.IDDanToc,B.IDTinhThanh,B.IDPhuongXa,B.SoNhaTenDuong,B.QuocTich,B.NgheNghiep,
                B.GiamHo_MoiQuanHe,B.GiamHo_HoTen,B.GiamHo_DienThoai,B.GiamHo_SoCCCD,
                B.GhiChu AS GhiChuBenhNhan,VV.GhiChuTiepNhan AS GhiChuLanKham,
                CASE WHEN NULLIF(LTRIM(RTRIM(B.GhiChu)),N'') IS NULL THEN 0 ELSE 1 END AS CoGhiChu,
                B.DiemTim,
                COUNT(*) OVER() AS TongSoDong
            FROM TimBN B
            INNER JOIN dbo.DM_GioiTinh GT ON GT.ID=B.IDGioiTinh AND GT.Active=1
            OUTER APPLY
            (
                SELECT TOP(1)
                    V.ID,V.MaVaoVien,V.NgayGioVaoVien,V.Ngay,V.SoThuTu,V.DaChuyenKham,V.TrangThaiKham,
                    V.SinhHieu,V.Kham,V.KeToa,V.GhiChuTiepNhan,V.IDNguoiTiepNhan
                FROM dbo.QL_VaoVien V
                WHERE V.IDCSKCB=@IDCSKCB AND V.IDBenhNhan=B.ID AND V.Active=1
                ORDER BY V.NgayGioVaoVien DESC,V.ID DESC
            ) VV
        )
        SELECT *
        FROM X
        ORDER BY DiemTim,ISNULL(NgayGioVaoVien,CONVERT(DATETIME2(0),'19000101')) DESC,IDBenhNhan DESC
        OFFSET @Offset ROWS FETCH NEXT @KichThuocTrang ROWS ONLY
        OPTION(RECOMPILE);
        RETURN;
    END;

    SET @TuNgay=ISNULL(@TuNgay,CONVERT(DATE,SYSDATETIME()));
    SET @DenNgay=ISNULL(@DenNgay,@TuNgay);

    ;WITH X AS
    (
        SELECT
            VV.ID AS IDVaoVien,VV.MaVaoVien,VV.NgayGioVaoVien,VV.Ngay,VV.SoThuTu,
            VV.DaChuyenKham,VV.TrangThaiKham,VV.SinhHieu,VV.Kham,VV.KeToa,VV.IDNguoiTiepNhan,
            B.ID AS IDBenhNhan,B.MaBN,B.HoTen,B.NgaySinh,B.IDGioiTinh,GT.TenGioiTinh,B.SoCCCD,B.DienThoai,B.DiaChi,
            B.IDDanToc,B.IDTinhThanh,B.IDPhuongXa,B.SoNhaTenDuong,B.QuocTich,B.NgheNghiep,
            B.GiamHo_MoiQuanHe,B.GiamHo_HoTen,B.GiamHo_DienThoai,B.GiamHo_SoCCCD,
            B.GhiChu AS GhiChuBenhNhan,VV.GhiChuTiepNhan AS GhiChuLanKham,
            CASE WHEN NULLIF(LTRIM(RTRIM(B.GhiChu)),N'') IS NULL THEN 0 ELSE 1 END AS CoGhiChu,
            COUNT(*) OVER() AS TongSoDong
        FROM dbo.QL_VaoVien VV
        INNER JOIN dbo.QL_BenhNhan B ON B.IDCSKCB=VV.IDCSKCB AND B.ID=VV.IDBenhNhan
        INNER JOIN dbo.DM_GioiTinh GT ON GT.ID=B.IDGioiTinh AND GT.Active=1
        WHERE VV.IDCSKCB=@IDCSKCB
          AND VV.Active=1
          AND VV.Ngay BETWEEN @TuNgay AND @DenNgay
          AND (@DaChuyenKham IS NULL OR VV.DaChuyenKham=@DaChuyenKham)
    )
    SELECT *
    FROM X
    ORDER BY NgayGioVaoVien DESC,IDVaoVien DESC
    OFFSET @Offset ROWS FETCH NEXT @KichThuocTrang ROWS ONLY
    OPTION(RECOMPILE);
END;

GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_BenhNhan_KiemTraTrung
    @IDCSKCB BIGINT,
    @IDBenhNhan BIGINT=NULL,
    @HoTen NVARCHAR(150),
    @NgaySinh DATE=NULL,
    @GioiTinh TINYINT=NULL,
    @SoCCCD NVARCHAR(20)=NULL,
    @DienThoai NVARCHAR(20)=NULL,
    @DiaChi NVARCHAR(500)=NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @HoTen=NULLIF(LTRIM(RTRIM(@HoTen)),N'');
    SET @SoCCCD=NULLIF(REPLACE(REPLACE(LTRIM(RTRIM(@SoCCCD)),N' ',N''),N'.',N''),N'');
    SET @DienThoai=NULLIF(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(@DienThoai)),N' ',N''),N'.',N''),N'-',N''),N'');
    SET @DiaChi=NULLIF(LTRIM(RTRIM(@DiaChi)),N'');

    ;WITH X AS
    (
        SELECT
            B.ID AS IDBenhNhan,B.MaBN,B.HoTen,B.NgaySinh,B.IDGioiTinh,B.SoCCCD,B.DienThoai,B.DiaChi,
            CAST
            (
                CASE
                    WHEN @SoCCCD IS NOT NULL
                     AND NULLIF(REPLACE(REPLACE(LTRIM(RTRIM(B.SoCCCD)),N' ',N''),N'.',N''),N'')=@SoCCCD
                        THEN 3
                    WHEN @HoTen IS NOT NULL AND @NgaySinh IS NOT NULL
                     AND LTRIM(RTRIM(B.HoTen))=@HoTen AND B.NgaySinh=@NgaySinh
                     AND @DienThoai IS NOT NULL
                     AND NULLIF(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(B.DienThoai)),N' ',N''),N'.',N''),N'-',N''),N'')=@DienThoai
                        THEN 2
                    WHEN @HoTen IS NOT NULL AND @NgaySinh IS NOT NULL AND @GioiTinh IS NOT NULL
                     AND LTRIM(RTRIM(B.HoTen))=@HoTen AND B.NgaySinh=@NgaySinh AND B.IDGioiTinh=@GioiTinh
                     AND @DiaChi IS NOT NULL AND LTRIM(RTRIM(ISNULL(B.DiaChi,N'')))=@DiaChi
                        THEN 2
                    WHEN @HoTen IS NOT NULL AND @NgaySinh IS NOT NULL AND @GioiTinh IS NOT NULL
                     AND LTRIM(RTRIM(B.HoTen))=@HoTen AND B.NgaySinh=@NgaySinh AND B.IDGioiTinh=@GioiTinh
                        THEN 1
                    ELSE 0
                END AS TINYINT
            ) AS MucDo
        FROM dbo.QL_BenhNhan B
        WHERE B.IDCSKCB=@IDCSKCB
          AND B.Active=1
          AND (@IDBenhNhan IS NULL OR B.ID<>@IDBenhNhan)
    )
    SELECT TOP(20)
        IDBenhNhan,MaBN,HoTen,NgaySinh,IDGioiTinh,SoCCCD,DienThoai,DiaChi,
        MucDo,
        CASE MucDo WHEN 3 THEN N'CHAC' WHEN 2 THEN N'CAO' ELSE N'GOI_Y' END AS MaMucDo
    FROM X
    WHERE MucDo>0
    ORDER BY MucDo DESC,IDBenhNhan DESC;
END;

GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_TiepNhan_Luu
    @IDCSKCB            BIGINT,
    @IDBenhNhan         BIGINT = NULL,
    @IDVaoVien          BIGINT = NULL,
    @HoTen              NVARCHAR(150),
    @NgaySinh           DATE = NULL,
    @GioiTinh           TINYINT = 1,
    @SoCCCD             NVARCHAR(20) = NULL,
    @DienThoai          NVARCHAR(20) = NULL,
    @SoNhaTenDuong      NVARCHAR(255) = NULL,
    @IDPhuongXa         BIGINT = NULL,
    @IDTinhThanh        BIGINT = NULL,
    @DiaChi             NVARCHAR(500) = NULL,
    @IDDanToc            BIGINT = NULL,
    @QuocTich           NVARCHAR(50) = NULL,
    @NgheNghiep         NVARCHAR(100) = NULL,
    @GhiChuBenhNhan     NVARCHAR(500) = NULL,
    @GiamHo_MoiQuanHe   NVARCHAR(50) = NULL,
    @GiamHo_HoTen       NVARCHAR(150) = NULL,
    @GiamHo_DienThoai   NVARCHAR(20) = NULL,
    @GiamHo_SoCCCD      NVARCHAR(20) = NULL,
    @IDNguoiTiepNhan    BIGINT = NULL,
    @GhiChuLanKham      NVARCHAR(500) = NULL,
    @SoThuTu            INT = NULL,
    @ChuyenKham         BIT = 0,
    @CongKhamJson       NVARCHAR(MAX) = NULL,
    @TaoVaoVien         BIT = 1,
    @BoQuaCanhBaoTrung  BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        SET @HoTen=NULLIF(LTRIM(RTRIM(@HoTen)),N'');
        SET @SoCCCD=NULLIF(REPLACE(REPLACE(LTRIM(RTRIM(@SoCCCD)),N' ',N''),N'.',N''),N'');
        SET @DienThoai=NULLIF(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(@DienThoai)),N' ',N''),N'.',N''),N'-',N''),N'');
        SET @DiaChi=NULLIF(LTRIM(RTRIM(@DiaChi)),N'');

        IF @HoTen IS NULL THROW 56000,N'Họ tên bệnh nhân là bắt buộc.',1;
        SET @GioiTinh=ISNULL(@GioiTinh,1);
        IF NOT EXISTS(SELECT 1 FROM dbo.DM_GioiTinh WHERE ID=@GioiTinh AND Active=1)
            THROW 56000,N'Giới tính không hợp lệ.',1;

        IF @NgaySinh IS NOT NULL AND @NgaySinh>CONVERT(DATE,SYSDATETIME())
            THROW 56000,N'Ngày sinh không được lớn hơn ngày hiện tại.',1;

        IF @IDBenhNhan IS NULL OR @IDBenhNhan<=0
        BEGIN
            DECLARE @IDBenhNhanTrung BIGINT,@MucDoTrung TINYINT;

            ;WITH X AS
            (
                SELECT
                    B.ID,
                    CAST
                    (
                        CASE
                            WHEN @SoCCCD IS NOT NULL
                             AND NULLIF(REPLACE(REPLACE(LTRIM(RTRIM(B.SoCCCD)),N' ',N''),N'.',N''),N'')=@SoCCCD
                                THEN 3
                            WHEN @NgaySinh IS NOT NULL
                             AND LTRIM(RTRIM(B.HoTen))=@HoTen AND B.NgaySinh=@NgaySinh
                             AND @DienThoai IS NOT NULL
                             AND NULLIF(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(B.DienThoai)),N' ',N''),N'.',N''),N'-',N''),N'')=@DienThoai
                                THEN 2
                            WHEN @NgaySinh IS NOT NULL
                             AND LTRIM(RTRIM(B.HoTen))=@HoTen AND B.NgaySinh=@NgaySinh AND B.IDGioiTinh=@GioiTinh
                             AND @DiaChi IS NOT NULL AND LTRIM(RTRIM(ISNULL(B.DiaChi,N'')))=@DiaChi
                                THEN 2
                            WHEN @NgaySinh IS NOT NULL
                             AND LTRIM(RTRIM(B.HoTen))=@HoTen AND B.NgaySinh=@NgaySinh AND B.IDGioiTinh=@GioiTinh
                                THEN 1
                            ELSE 0
                        END AS TINYINT
                    ) AS MucDo
                FROM dbo.QL_BenhNhan B WITH(UPDLOCK,HOLDLOCK)
                WHERE B.IDCSKCB=@IDCSKCB AND B.Active=1
            )
            SELECT TOP(1) @IDBenhNhanTrung=ID,@MucDoTrung=MucDo
            FROM X WHERE MucDo>0
            ORDER BY MucDo DESC,ID DESC;

            IF @MucDoTrung=3
            BEGIN
                ROLLBACK;
                SELECT 409 AS Status,
                       N'CCCD đã tồn tại ở một hồ sơ bệnh nhân khác. Hãy chọn hồ sơ hiện có.' AS Message,
                       @IDBenhNhanTrung AS IDBenhNhan,
                       CAST(NULL AS BIGINT) AS IDVaoVien,
                       CAST(0 AS BIT) AS CanhBaoTrung,
                       N'CHAC' AS MucDoTrung;
                RETURN;
            END;

            IF @MucDoTrung=2 AND ISNULL(@BoQuaCanhBaoTrung,0)=0
            BEGIN
                ROLLBACK;
                SELECT 409 AS Status,
                       N'Có hồ sơ rất giống (họ tên + ngày sinh + SĐT hoặc địa chỉ). Hãy đối chiếu trước khi tạo hồ sơ mới.' AS Message,
                       @IDBenhNhanTrung AS IDBenhNhan,
                       CAST(NULL AS BIGINT) AS IDVaoVien,
                       CAST(1 AS BIT) AS CanhBaoTrung,
                       N'CAO' AS MucDoTrung;
                RETURN;
            END;

            DECLARE @SeqBN BIGINT=NEXT VALUE FOR dbo.SEQ_MaBN;
            DECLARE @MaBN NVARCHAR(30)=dbo.FN_QLPM_FormatMaBN(@SeqBN);

            INSERT dbo.QL_BenhNhan
            (
                IDCSKCB,MaBN,HoTen,NgaySinh,IDGioiTinh,SoCCCD,DienThoai,
                SoNhaTenDuong,IDPhuongXa,IDTinhThanh,DiaChi,IDDanToc,QuocTich,NgheNghiep,GhiChu,
                GiamHo_MoiQuanHe,GiamHo_HoTen,GiamHo_DienThoai,GiamHo_SoCCCD,Active
            )
            VALUES
            (
                @IDCSKCB,@MaBN,@HoTen,@NgaySinh,@GioiTinh,@SoCCCD,@DienThoai,
                @SoNhaTenDuong,@IDPhuongXa,@IDTinhThanh,@DiaChi,@IDDanToc,@QuocTich,@NgheNghiep,@GhiChuBenhNhan,
                @GiamHo_MoiQuanHe,@GiamHo_HoTen,@GiamHo_DienThoai,@GiamHo_SoCCCD,1
            );
            SET @IDBenhNhan=SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE dbo.QL_BenhNhan
            SET HoTen=@HoTen,NgaySinh=@NgaySinh,IDGioiTinh=@GioiTinh,
                SoCCCD=@SoCCCD,DienThoai=@DienThoai,
                SoNhaTenDuong=@SoNhaTenDuong,IDPhuongXa=@IDPhuongXa,IDTinhThanh=@IDTinhThanh,DiaChi=@DiaChi,
                IDDanToc=@IDDanToc,QuocTich=COALESCE(NULLIF(@QuocTich,N''),QuocTich),
                NgheNghiep=COALESCE(NULLIF(@NgheNghiep,N''),NgheNghiep),
                GhiChu=@GhiChuBenhNhan,GiamHo_MoiQuanHe=@GiamHo_MoiQuanHe,GiamHo_HoTen=@GiamHo_HoTen,
                GiamHo_DienThoai=@GiamHo_DienThoai,GiamHo_SoCCCD=@GiamHo_SoCCCD,NgayCapNhat=SYSDATETIME()
            WHERE IDCSKCB=@IDCSKCB AND ID=@IDBenhNhan AND Active=1;

            IF @@ROWCOUNT=0 THROW 56000,N'Không tìm thấy bệnh nhân.',1;
        END;

        IF (@IDVaoVien IS NULL OR @IDVaoVien<=0) AND @TaoVaoVien=0
        BEGIN
            COMMIT;
            SELECT 200 AS Status,N'Lưu thông tin bệnh nhân thành công.' AS Message,@IDBenhNhan AS IDBenhNhan,
                   CAST(NULL AS BIGINT) AS IDVaoVien,CAST(0 AS BIT) AS CanhBaoTrung,CAST(NULL AS NVARCHAR(20)) AS MucDoTrung;
            RETURN;
        END;

        DECLARE @NgayHienTai DATE=CONVERT(DATE,SYSDATETIME());

        IF @IDVaoVien IS NULL OR @IDVaoVien<=0
        BEGIN
            DECLARE @IDVaoVienDangMo BIGINT;
            SELECT TOP(1) @IDVaoVienDangMo=V.ID
            FROM dbo.QL_VaoVien V WITH(UPDLOCK,HOLDLOCK)
            WHERE V.IDCSKCB=@IDCSKCB
              AND V.IDBenhNhan=@IDBenhNhan
              AND V.Ngay=@NgayHienTai
              AND V.Active=1
              AND V.TrangThaiKham IN(0,1)
            ORDER BY V.NgayGioVaoVien,V.ID;

            IF @IDVaoVienDangMo IS NOT NULL
            BEGIN
                ROLLBACK;
                SELECT 409 AS Status,
                       N'Bệnh nhân đã có lượt khám chưa hoàn tất trong ngày. Không được tiếp nhận lại; hãy tiếp tục lượt hiện tại.' AS Message,
                       @IDBenhNhan AS IDBenhNhan,@IDVaoVienDangMo AS IDVaoVien,
                       CAST(0 AS BIT) AS CanhBaoTrung,CAST(NULL AS NVARCHAR(20)) AS MucDoTrung;
                RETURN;
            END;

            IF @SoThuTu IS NULL OR @SoThuTu<=0
            BEGIN
                DECLARE @LockResult INT;
                DECLARE @LockName NVARCHAR(255)=N'QLPM_STT_'+CONVERT(NVARCHAR(30),@IDCSKCB)+N'_'+CONVERT(NVARCHAR(8),@NgayHienTai,112);
                EXEC @LockResult=sys.sp_getapplock @Resource=@LockName,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=5000;
                IF @LockResult<0 THROW 56000,N'Không thể cấp số thứ tự tiếp nhận, vui lòng thử lại.',1;

                SELECT @SoThuTu=ISNULL(MAX(SoThuTu),0)+1
                FROM dbo.QL_VaoVien
                WHERE IDCSKCB=@IDCSKCB AND Ngay=@NgayHienTai;
            END;

            DECLARE @SeqVV BIGINT=NEXT VALUE FOR dbo.SEQ_MaVaoVien;
            DECLARE @MaVV NVARCHAR(30)=N'VV'+CASE
                WHEN @SeqVV<1000000 THEN RIGHT(N'000000'+CONVERT(NVARCHAR(20),@SeqVV),6)
                ELSE CONVERT(NVARCHAR(20),@SeqVV) END;

            INSERT dbo.QL_VaoVien
            (
                IDCSKCB,MaVaoVien,IDBenhNhan,Ngay,NgayGioVaoVien,SoThuTu,
                IDNguoiTiepNhan,GhiChuTiepNhan,DaChuyenKham,ThoiGianChuyenKham,TrangThaiKham,Active
            )
            VALUES
            (
                @IDCSKCB,@MaVV,@IDBenhNhan,@NgayHienTai,SYSDATETIME(),@SoThuTu,
                @IDNguoiTiepNhan,@GhiChuLanKham,0,NULL,0,1
            );
            SET @IDVaoVien=SCOPE_IDENTITY();

            INSERT dbo.QL_CongKham(IDCSKCB,IDVaoVien,IDNguoiTao) VALUES(@IDCSKCB,@IDVaoVien,@IDNguoiTiepNhan);
            INSERT dbo.QL_ThuTien(IDCSKCB,IDVaoVien) VALUES(@IDCSKCB,@IDVaoVien);
        END
        ELSE
        BEGIN
            DECLARE @DaChuyen BIT,@TrangThai TINYINT,@DaThu BIT;
            SELECT @DaChuyen=V.DaChuyenKham,@TrangThai=V.TrangThaiKham
            FROM dbo.QL_VaoVien V WITH(UPDLOCK,HOLDLOCK)
            WHERE V.IDCSKCB=@IDCSKCB AND V.ID=@IDVaoVien AND V.IDBenhNhan=@IDBenhNhan AND V.Active=1;

            IF @TrangThai IS NULL THROW 56000,N'Không tìm thấy lượt khám.',1;

            SELECT @DaThu=CASE WHEN EXISTS
            (
                SELECT 1
                FROM dbo.QL_ThuTien T
                INNER JOIN dbo.QL_ThuTien_CT CT
                  ON CT.IDCSKCB=T.IDCSKCB AND CT.IDThuTien=T.ID
                WHERE T.IDCSKCB=@IDCSKCB
                  AND T.IDVaoVien=@IDVaoVien
                  AND ISNULL(CT.DaThu,0)=1
            ) THEN 1 ELSE 0 END;

            IF ISNULL(@DaThu,0)=1 AND @CongKhamJson IS NOT NULL
                THROW 56000,N'Lượt khám đã thu tiền, không được thay đổi công khám.',1;

            IF ISNULL(@DaChuyen,0)=1 AND @CongKhamJson IS NOT NULL
                THROW 56000,N'Lượt khám đã chuyển khám, không được sửa công khám tại tiếp nhận.',1;

            UPDATE dbo.QL_VaoVien
            SET SoThuTu=COALESCE(@SoThuTu,SoThuTu),GhiChuTiepNhan=@GhiChuLanKham,NgayCapNhat=SYSDATETIME()
            WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien;
        END;

        DECLARE @IDCongKham BIGINT=(SELECT ID FROM dbo.QL_CongKham WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien);
        DECLARE @IDThuTien BIGINT=(SELECT ID FROM dbo.QL_ThuTien WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien);

        IF @CongKhamJson IS NOT NULL
        BEGIN
            IF ISJSON(@CongKhamJson)<>1 THROW 56000,N'Dữ liệu công khám không hợp lệ.',1;

            DECLARE @CK TABLE(IDDichVu BIGINT PRIMARY KEY,SoLuong DECIMAL(10,2),GhiChu NVARCHAR(500));
            INSERT @CK(IDDichVu,SoLuong,GhiChu)
            SELECT
                COALESCE(J.IDDichVu,J.id_dich_vu),
                COALESCE(J.SoLuong,J.so_luong,1),
                COALESCE(J.GhiChu,J.ghi_chu)
            FROM OPENJSON(@CongKhamJson)
            WITH
            (
                IDDichVu BIGINT '$.IDDichVu',id_dich_vu BIGINT '$.id_dich_vu',
                SoLuong DECIMAL(10,2) '$.SoLuong',so_luong DECIMAL(10,2) '$.so_luong',
                GhiChu NVARCHAR(500) '$.GhiChu',ghi_chu NVARCHAR(500) '$.ghi_chu'
            ) J
            WHERE COALESCE(J.IDDichVu,J.id_dich_vu) IS NOT NULL;

            IF EXISTS(SELECT 1 FROM @CK WHERE SoLuong<=0)
                THROW 56000,N'Số lượng công khám phải lớn hơn 0.',1;

            IF EXISTS
            (
                SELECT 1 FROM @CK X
                WHERE NOT EXISTS(SELECT 1 FROM dbo.DM_DichVu D WHERE D.IDCSKCB=@IDCSKCB AND D.ID=X.IDDichVu AND D.Active=1)
            )
                THROW 56000,N'Có công khám không tồn tại hoặc đã ngừng hoạt động.',1;

            DELETE T
            FROM dbo.QL_ThuTien_CT T
            INNER JOIN dbo.QL_CongKham_CT C ON C.IDCSKCB=T.IDCSKCB AND C.ID=T.IDCongKhamCT
            WHERE T.IDCSKCB=@IDCSKCB AND T.IDThuTien=@IDThuTien AND C.IDCongKham=@IDCongKham;

            DELETE dbo.QL_CongKham_CT WHERE IDCSKCB=@IDCSKCB AND IDCongKham=@IDCongKham;

            INSERT dbo.QL_CongKham_CT(IDCSKCB,IDCongKham,IDDichVu,SoLuong,DonGia,ThanhTien,GhiChu,Active)
            SELECT @IDCSKCB,@IDCongKham,D.ID,X.SoLuong,D.DonGia,X.SoLuong*D.DonGia,X.GhiChu,1
            FROM @CK X
            INNER JOIN dbo.DM_DichVu D ON D.IDCSKCB=@IDCSKCB AND D.ID=X.IDDichVu AND D.Active=1;

            INSERT dbo.QL_ThuTien_CT(IDCSKCB,IDThuTien,IDCongKhamCT,SoLuong,DonGia,ThanhTien,TienGiam,ThucThu,DaThu)
            SELECT @IDCSKCB,@IDThuTien,ID,SoLuong,DonGia,ThanhTien,0,ThanhTien,0
            FROM dbo.QL_CongKham_CT
            WHERE IDCSKCB=@IDCSKCB AND IDCongKham=@IDCongKham AND Active=1;

            EXEC dbo.STO_QL_ThuTien_CapNhatTong @IDCSKCB,@IDVaoVien;
        END;

        IF @ChuyenKham=1
        BEGIN
            IF NOT EXISTS
            (
                SELECT 1
                FROM dbo.QL_CongKham C
                INNER JOIN dbo.QL_CongKham_CT CT
                  ON CT.IDCSKCB=C.IDCSKCB AND CT.IDCongKham=C.ID AND CT.Active=1
                WHERE C.IDCSKCB=@IDCSKCB AND C.IDVaoVien=@IDVaoVien
            )
                THROW 56000,N'Phải chọn ít nhất một công khám trước khi chuyển khám.',1;

            UPDATE dbo.QL_VaoVien
            SET DaChuyenKham=1,
                ThoiGianChuyenKham=COALESCE(ThoiGianChuyenKham,SYSDATETIME()),
                NgayCapNhat=SYSDATETIME()
            WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien;
        END;

        COMMIT;
        SELECT 200 AS Status,
               CASE WHEN @ChuyenKham=1 THEN N'Tiếp nhận và chuyển khám thành công.' ELSE N'Lưu tiếp nhận thành công.' END AS Message,
               @IDBenhNhan AS IDBenhNhan,@IDVaoVien AS IDVaoVien,
               CAST(0 AS BIT) AS CanhBaoTrung,CAST(NULL AS NVARCHAR(20)) AS MucDoTrung;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 400 AS Status,ERROR_MESSAGE() AS Message,
               @IDBenhNhan AS IDBenhNhan,@IDVaoVien AS IDVaoVien,
               CAST(0 AS BIT) AS CanhBaoTrung,CAST(NULL AS NVARCHAR(20)) AS MucDoTrung;
    END CATCH
END;

GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_TiepNhan_ChuyenKham
    @IDCSKCB BIGINT,@IDVaoVien BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IDBenhNhan BIGINT,@Ngay DATE,@NgayGioVaoVien DATETIME2(0),@TrangThaiKham TINYINT,@DaChuyenKham BIT;
    SELECT @IDBenhNhan=V.IDBenhNhan,@Ngay=V.Ngay,@NgayGioVaoVien=V.NgayGioVaoVien,
           @TrangThaiKham=V.TrangThaiKham,@DaChuyenKham=V.DaChuyenKham
    FROM dbo.QL_VaoVien V
    WHERE V.IDCSKCB=@IDCSKCB AND V.ID=@IDVaoVien AND V.Active=1;

    IF @IDBenhNhan IS NULL
    BEGIN SELECT 404 AS Status,N'Không tìm thấy lượt khám.' AS Message,@IDVaoVien AS IDVaoVien; RETURN; END;

    IF @TrangThaiKham>=2
    BEGIN SELECT 409 AS Status,N'Lượt khám đã hoàn tất hoặc đã hủy, không thể chuyển khám lại.' AS Message,@IDVaoVien AS IDVaoVien; RETURN; END;

    DECLARE @IDVaoVienTruoc BIGINT;
    SELECT TOP(1) @IDVaoVienTruoc=V.ID
    FROM dbo.QL_VaoVien V
    WHERE V.IDCSKCB=@IDCSKCB
      AND V.IDBenhNhan=@IDBenhNhan
      AND V.Ngay=@Ngay
      AND V.Active=1
      AND V.TrangThaiKham IN(0,1)
      AND V.ID<>@IDVaoVien
      AND (V.NgayGioVaoVien<@NgayGioVaoVien OR (V.NgayGioVaoVien=@NgayGioVaoVien AND V.ID<@IDVaoVien))
    ORDER BY V.NgayGioVaoVien,V.ID;

    IF @IDVaoVienTruoc IS NOT NULL
    BEGIN
        SELECT 409 AS Status,
               N'Bệnh nhân đã có một lượt khám trước đó trong ngày chưa hoàn tất. Không thể chuyển lượt tiếp nhận trùng; hãy tiếp tục lượt trước.' AS Message,
               @IDVaoVienTruoc AS IDVaoVien;
        RETURN;
    END;

    IF ISNULL(@DaChuyenKham,0)=1
    BEGIN SELECT 200 AS Status,N'Lượt khám đã được chuyển trước đó.' AS Message,@IDVaoVien AS IDVaoVien; RETURN; END;

    IF NOT EXISTS(SELECT 1 FROM dbo.QL_CongKham C JOIN dbo.QL_CongKham_CT CT ON CT.IDCSKCB=C.IDCSKCB AND CT.IDCongKham=C.ID AND CT.Active=1 WHERE C.IDCSKCB=@IDCSKCB AND C.IDVaoVien=@IDVaoVien)
    BEGIN SELECT 400 AS Status,N'Chưa chọn công khám.' AS Message,@IDVaoVien AS IDVaoVien; RETURN; END;

    UPDATE dbo.QL_VaoVien
    SET DaChuyenKham=1,ThoiGianChuyenKham=ISNULL(ThoiGianChuyenKham,SYSDATETIME()),NgayCapNhat=SYSDATETIME()
    WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien AND Active=1 AND TrangThaiKham IN(0,1);

    SELECT 200 AS Status,N'Chuyển khám thành công.' AS Message,@IDVaoVien AS IDVaoVien;
END;

GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_TiepNhan_LayCongKham
    @IDCSKCB BIGINT,
    @IDVaoVien BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CKC.ID AS IDCongKhamCT,
           CKC.IDCongKham,
           CKC.IDDichVu,
           DV.MaDichVu,
           DV.TenDichVu,
           CKC.SoLuong,
           CKC.DonGia,
           CKC.ThanhTien,
           CKC.GhiChu,
           VV.DaChuyenKham,
           VV.TrangThaiKham,
           ISNULL(TT.DaThu, 0) AS DaThu
    FROM dbo.QL_CongKham_CT CKC
    JOIN dbo.QL_CongKham CK ON CK.IDCSKCB = CKC.IDCSKCB AND CK.ID = CKC.IDCongKham
    JOIN dbo.QL_VaoVien VV ON VV.IDCSKCB = CK.IDCSKCB AND VV.ID = CK.IDVaoVien
    JOIN dbo.DM_DichVu DV ON DV.IDCSKCB = CKC.IDCSKCB AND DV.ID = CKC.IDDichVu
    LEFT JOIN dbo.QL_ThuTien TT ON TT.IDCSKCB = VV.IDCSKCB AND TT.IDVaoVien = VV.ID
    WHERE CKC.IDCSKCB = @IDCSKCB AND CK.IDVaoVien = @IDVaoVien AND CKC.Active = 1
    ORDER BY CKC.ID;
END;

GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_TiepNhan_BoCongKham
    @IDCSKCB BIGINT,
    @IDVaoVien BIGINT,
    @IDCongKhamCTJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @TrangThaiKham TINYINT, @Active BIT;
        SELECT @TrangThaiKham = TrangThaiKham,
               @Active = Active
        FROM dbo.QL_VaoVien WITH (UPDLOCK, HOLDLOCK)
        WHERE IDCSKCB = @IDCSKCB
          AND ID = @IDVaoVien;

        IF @TrangThaiKham IS NULL
        BEGIN
            COMMIT;
            SELECT 404 AS Status, N'Không tìm thấy lượt khám.' AS Message, 0 AS HuyLuotKham, 0 AS SoLuongConLai;
            RETURN;
        END;

        IF @TrangThaiKham <> 0
        BEGIN
            COMMIT;
            SELECT 409 AS Status, N'Chỉ được bỏ công khám khi bệnh nhân chưa khám.' AS Message, 0 AS HuyLuotKham, 0 AS SoLuongConLai;
            RETURN;
        END;

        IF ISNULL(@Active, 0) <> 1
        BEGIN
            COMMIT;
            SELECT 404 AS Status, N'Không tìm thấy lượt khám đang hoạt động.' AS Message, 0 AS HuyLuotKham, 0 AS SoLuongConLai;
            RETURN;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.QL_ThuTien T
            INNER JOIN dbo.QL_ThuTien_CT CT
              ON CT.IDCSKCB=T.IDCSKCB AND CT.IDThuTien=T.ID
            WHERE T.IDCSKCB=@IDCSKCB
              AND T.IDVaoVien=@IDVaoVien
              AND ISNULL(CT.DaThu,0)=1
        )
        BEGIN
            COMMIT;
            SELECT 409 AS Status, N'Lượt khám đã thu tiền, không thể bỏ đăng ký công khám.' AS Message, 0 AS HuyLuotKham, 0 AS SoLuongConLai;
            RETURN;
        END;

        DECLARE @IDs TABLE (ID BIGINT PRIMARY KEY);
        IF ISJSON(@IDCongKhamCTJson)=1
        BEGIN
            INSERT INTO @IDs (ID)
            SELECT DISTINCT TRY_CONVERT(BIGINT, value)
            FROM OPENJSON(@IDCongKhamCTJson)
            WHERE TRY_CONVERT(BIGINT, value) IS NOT NULL;
        END;

        IF NOT EXISTS (SELECT 1 FROM @IDs)
        BEGIN
            COMMIT;
            SELECT 400 AS Status, N'Chưa chọn công khám nào để bỏ đăng ký.' AS Message, 0 AS HuyLuotKham, 0 AS SoLuongConLai;
            RETURN;
        END;

        DECLARE @IDCongKham BIGINT =
        (
            SELECT ID FROM dbo.QL_CongKham
            WHERE IDCSKCB = @IDCSKCB AND IDVaoVien = @IDVaoVien
        );

        IF @IDCongKham IS NULL
        BEGIN
            COMMIT;
            SELECT 404 AS Status, N'Lượt khám không có phiếu công khám.' AS Message, 0 AS HuyLuotKham, 0 AS SoLuongConLai;
            RETURN;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM @IDs I
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM dbo.QL_CongKham_CT CT
                WHERE CT.IDCSKCB = @IDCSKCB
                  AND CT.IDCongKham = @IDCongKham
                  AND CT.ID = I.ID
                  AND CT.Active = 1
            )
        )
        BEGIN
            COMMIT;
            SELECT 400 AS Status, N'Có công khám không thuộc lượt khám hoặc đã được bỏ trước đó.' AS Message, 0 AS HuyLuotKham, 0 AS SoLuongConLai;
            RETURN;
        END;

        DECLARE @IDThuTien BIGINT =
        (
            SELECT ID FROM dbo.QL_ThuTien
            WHERE IDCSKCB = @IDCSKCB AND IDVaoVien = @IDVaoVien
        );

        IF @IDThuTien IS NOT NULL
        BEGIN
            DELETE T
            FROM dbo.QL_ThuTien_CT T
            JOIN dbo.QL_CongKham_CT C
              ON C.IDCSKCB = T.IDCSKCB AND C.ID = T.IDCongKhamCT
            JOIN @IDs I ON I.ID = C.ID
            WHERE T.IDCSKCB = @IDCSKCB
              AND T.IDThuTien = @IDThuTien
              AND C.IDCongKham = @IDCongKham;
        END;

        DELETE CT
        FROM dbo.QL_CongKham_CT CT
        JOIN @IDs I ON I.ID = CT.ID
        WHERE CT.IDCSKCB = @IDCSKCB
          AND CT.IDCongKham = @IDCongKham;

        DECLARE @SoLuongConLai INT = (
            SELECT COUNT(1) FROM dbo.QL_CongKham_CT 
            WHERE IDCSKCB = @IDCSKCB AND IDCongKham = @IDCongKham AND Active = 1
        );

        IF @SoLuongConLai = 0
        BEGIN
            UPDATE dbo.QL_VaoVien
            SET DaChuyenKham = 0,
                TrangThaiKham = 0,
                ThoiGianChuyenKham = NULL,
                IDBacSiKham = NULL,
                BatDauKhamLuc = NULL,
                NgayCapNhat = SYSDATETIME()
            WHERE IDCSKCB = @IDCSKCB AND ID = @IDVaoVien;
        END;

        IF @IDThuTien IS NOT NULL
            EXEC dbo.STO_QL_ThuTien_CapNhatTong @IDCSKCB, @IDVaoVien;

        COMMIT;
        SELECT 200 AS Status,
               CASE WHEN @SoLuongConLai = 0
                    THEN N'Đã bỏ toàn bộ công khám. Lượt tiếp nhận đã được đưa về Chưa chuyển.'
                    ELSE N'Bỏ đăng ký công khám thành công.'
               END AS Message,
               0 AS HuyLuotKham,
               @SoLuongConLai AS SoLuongConLai;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        SELECT 500 AS Status, ERROR_MESSAGE() AS Message, 0 AS HuyLuotKham, 0 AS SoLuongConLai;
    END CATCH
END;

GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_TiepNhan_BoDangKy
    @IDCSKCB BIGINT,
    @IDVaoVien BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @TrangThai TINYINT,@Active BIT;
        SELECT @TrangThai=TrangThaiKham,@Active=Active
        FROM dbo.QL_VaoVien WITH(UPDLOCK,HOLDLOCK)
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien;

        IF @Active IS NULL OR @Active=0
        BEGIN
            ROLLBACK;
            SELECT 404 AS Status,N'Không tìm thấy lượt tiếp nhận đang hoạt động.' AS Message;
            RETURN;
        END;

        IF ISNULL(@TrangThai,0)<>0
           OR EXISTS(SELECT 1 FROM dbo.QL_PhieuSinhHieu WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien)
           OR EXISTS(SELECT 1 FROM dbo.QL_ChanDoan_CT WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien)
           OR EXISTS(SELECT 1 FROM dbo.QL_ChiDinh_CT WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND Active=1)
           OR EXISTS(SELECT 1 FROM dbo.QL_ToaThuoc_CT WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND Active=1)
        BEGIN
            ROLLBACK;
            SELECT 409 AS Status,N'Lượt khám đã phát sinh dữ liệu khám, không được xóa đăng ký tiếp nhận.' AS Message;
            RETURN;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.QL_ThuTien T
            INNER JOIN dbo.QL_ThuTien_CT CT
              ON CT.IDCSKCB=T.IDCSKCB AND CT.IDThuTien=T.ID
            WHERE T.IDCSKCB=@IDCSKCB
              AND T.IDVaoVien=@IDVaoVien
              AND ISNULL(CT.DaThu,0)=1
        )
        BEGIN
            ROLLBACK;
            SELECT 409 AS Status,N'Lượt khám đã thu tiền, không thể xóa.' AS Message;
            RETURN;
        END;

        DELETE CT
        FROM dbo.QL_ThuTien_CT CT
        INNER JOIN dbo.QL_ThuTien T ON T.IDCSKCB=CT.IDCSKCB AND T.ID=CT.IDThuTien
        WHERE T.IDCSKCB=@IDCSKCB AND T.IDVaoVien=@IDVaoVien;

        DELETE dbo.QL_ThuTien WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien;

        DELETE CT
        FROM dbo.QL_CongKham_CT CT
        INNER JOIN dbo.QL_CongKham C ON C.IDCSKCB=CT.IDCSKCB AND C.ID=CT.IDCongKham
        WHERE C.IDCSKCB=@IDCSKCB AND C.IDVaoVien=@IDVaoVien;

        DELETE dbo.QL_CongKham WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien;

        UPDATE dbo.QL_VaoVien
        SET TrangThaiKham=3,Active=0,NgayCapNhat=SYSDATETIME()
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien;

        COMMIT;
        SELECT 200 AS Status,N'Đã hủy lượt tiếp nhận chưa phát sinh dữ liệu khám.' AS Message;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 500 AS Status,ERROR_MESSAGE() AS Message;
    END CATCH
END;

GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_BenhNhan_Xoa @IDCSKCB BIGINT,@IDBenhNhan BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS(SELECT 1 FROM dbo.QL_VaoVien WHERE IDCSKCB=@IDCSKCB AND IDBenhNhan=@IDBenhNhan)
    BEGIN SELECT 409 AS Status,N'Bệnh nhân đã có dữ liệu lượt khám, không được xóa hồ sơ.' AS Message; RETURN; END;
    UPDATE dbo.QL_BenhNhan SET Active=0,NgayCapNhat=SYSDATETIME() WHERE IDCSKCB=@IDCSKCB AND ID=@IDBenhNhan AND Active=1;
    SELECT CASE WHEN @@ROWCOUNT>0 THEN 200 ELSE 404 END AS Status,CASE WHEN @@ROWCOUNT>0 THEN N'Xóa bệnh nhân thành công.' ELSE N'Không tìm thấy bệnh nhân.' END AS Message;
END;

GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_Kham_DanhSach
    @IDCSKCB BIGINT,
    @Ngay DATE=NULL,
    @TrangThaiKham TINYINT=NULL,
    @TuKhoa NVARCHAR(200)=NULL,
    @Trang INT=1,
    @KichThuocTrang INT=25
AS
BEGIN
    SET NOCOUNT ON;
    SET @Ngay=ISNULL(@Ngay,CONVERT(DATE,SYSDATETIME()));
    SET @TuKhoa=NULLIF(LTRIM(RTRIM(@TuKhoa)),N'');
    IF @Trang IS NULL OR @Trang<1 SET @Trang=1;
    IF @KichThuocTrang IS NULL OR @KichThuocTrang<1 SET @KichThuocTrang=25;
    IF @KichThuocTrang>100 SET @KichThuocTrang=100;
    DECLARE @Offset BIGINT=(CONVERT(BIGINT,@Trang)-1)*@KichThuocTrang;

    ;WITH X AS
    (
        SELECT
            VV.ID AS IDVaoVien,VV.SoThuTu,VV.MaVaoVien,VV.NgayGioVaoVien,VV.ThoiGianChuyenKham,
            VV.TrangThaiKham,VV.SinhHieu,VV.Kham,VV.KeToa,VV.IDBacSiKham,
            B.ID AS IDBenhNhan,B.MaBN,B.HoTen,B.NgaySinh,B.IDGioiTinh,GT.TenGioiTinh,B.SoCCCD,B.DienThoai,
            B.GhiChu AS GhiChuBenhNhan,VV.GhiChuTiepNhan AS GhiChuLanKham,
            CASE WHEN NULLIF(LTRIM(RTRIM(B.GhiChu)),N'') IS NULL THEN 0 ELSE 1 END AS CoGhiChu,
            CASE VV.TrangThaiKham WHEN 0 THEN N'CHUA_KHAM' WHEN 1 THEN N'DANG_KHAM' WHEN 2 THEN N'DA_KHAM' ELSE N'KHAC' END AS MaTrangThaiMau,
            CASE VV.TrangThaiKham WHEN 0 THEN N'#DDF4FF' WHEN 1 THEN N'#FFF3BF' WHEN 2 THEN N'#111827' ELSE N'#F3F4F6' END AS MauNen,
            CASE VV.TrangThaiKham WHEN 2 THEN N'#FFFFFF' ELSE N'#111827' END AS MauChu,
            COUNT(*) OVER() AS TongSoDong
        FROM dbo.QL_VaoVien VV
        INNER JOIN dbo.QL_BenhNhan B ON B.IDCSKCB=VV.IDCSKCB AND B.ID=VV.IDBenhNhan
        INNER JOIN dbo.DM_GioiTinh GT ON GT.ID=B.IDGioiTinh AND GT.Active=1
        WHERE VV.IDCSKCB=@IDCSKCB
          AND VV.Ngay=@Ngay
          AND VV.DaChuyenKham=1
          AND VV.Active=1
          AND VV.TrangThaiKham IN(0,1,2)
          /* Worklist khám chỉ trả lượt đủ điều kiện vào bàn khám.
             Khi bật THUCONGKHAMDVTRUOC, lượt CHƯA khám còn công khám
             dương chưa thu sẽ nằm ở Thu ngân, không xuất hiện ở DS bác sĩ. */
          AND
          (
              VV.TrangThaiKham<>0
              OR ISNULL
                 (
                     (SELECT TOP(1) HieuLuc
                      FROM dbo.HT_Config
                      WHERE IDCSKCB=@IDCSKCB
                        AND MaChucNang=N'THUCONGKHAMDVTRUOC'),
                     1
                 )=0
              OR NOT EXISTS
                 (
                     SELECT 1
                     FROM dbo.QL_ThuTien T0
                     INNER JOIN dbo.QL_ThuTien_CT P0
                       ON P0.IDCSKCB=T0.IDCSKCB AND P0.IDThuTien=T0.ID
                     INNER JOIN dbo.QL_CongKham_CT CK0
                       ON CK0.IDCSKCB=P0.IDCSKCB AND CK0.ID=P0.IDCongKhamCT AND CK0.Active=1
                     WHERE T0.IDCSKCB=VV.IDCSKCB
                       AND T0.IDVaoVien=VV.ID
                       AND ISNULL(P0.DaThu,0)=0
                       AND ROUND(ISNULL(P0.ThucThu,P0.ThanhTien),0)>0
                 )
          )
          AND (@TrangThaiKham IS NULL OR VV.TrangThaiKham=@TrangThaiKham)
          AND
          (
              @TuKhoa IS NULL
              OR B.MaBN=@TuKhoa OR B.SoCCCD=@TuKhoa OR B.DienThoai=@TuKhoa
              OR B.MaBN LIKE @TuKhoa+N'%' OR B.SoCCCD LIKE @TuKhoa+N'%' OR B.DienThoai LIKE @TuKhoa+N'%'
              OR B.HoTen LIKE N'%'+@TuKhoa+N'%'
          )
    )
    SELECT *
    FROM X
    ORDER BY ISNULL(ThoiGianChuyenKham,NgayGioVaoVien) ASC,IDVaoVien ASC
    OFFSET @Offset ROWS FETCH NEXT @KichThuocTrang ROWS ONLY
    OPTION(RECOMPILE);
END;

GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_Kham_ChonBenhNhan
    @IDCSKCB BIGINT,
    @IDVaoVien BIGINT,
    @IDBacSi BIGINT,
    @LaQuanTri BIT=0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @TrangThai TINYINT,@DaChuyen BIT,@BSDangKham BIGINT;
        SELECT @TrangThai=TrangThaiKham,@DaChuyen=DaChuyenKham,@BSDangKham=IDBacSiKham
        FROM dbo.QL_VaoVien
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien AND Active=1;

        IF @TrangThai IS NULL
        BEGIN ROLLBACK; SELECT 404 AS Status,N'Không tìm thấy lượt khám.' AS Message; RETURN; END;
        IF ISNULL(@DaChuyen,0)=0
        BEGIN ROLLBACK; SELECT 409 AS Status,N'Bệnh nhân chưa được chuyển khám.' AS Message; RETURN; END;
        IF @TrangThai=3
        BEGIN ROLLBACK; SELECT 409 AS Status,N'Lượt khám đã bị hủy.' AS Message; RETURN; END;

        IF ISNULL(@LaQuanTri,0)=0
           AND @TrangThai IN(0,1)
           AND @BSDangKham IS NOT NULL
           AND @BSDangKham<>@IDBacSi
        BEGIN ROLLBACK; SELECT 409 AS Status,N'Bệnh nhân đang được bác sĩ khác khám.' AS Message; RETURN; END;

        COMMIT;

        SELECT 200 AS Status,N'Tải bệnh nhân thành công.' AS Message;

        SELECT VV.*,BN.MaBN,BN.HoTen,BN.NgaySinh,BN.IDGioiTinh,GT.TenGioiTinh,BN.SoCCCD,BN.DienThoai,BN.DiaChi,BN.GhiChu AS GhiChuBenhNhan
        FROM dbo.QL_VaoVien VV
        INNER JOIN dbo.QL_BenhNhan BN ON BN.IDCSKCB=VV.IDCSKCB AND BN.ID=VV.IDBenhNhan
        INNER JOIN dbo.DM_GioiTinh GT ON GT.ID=BN.IDGioiTinh AND GT.Active=1
        WHERE VV.IDCSKCB=@IDCSKCB AND VV.ID=@IDVaoVien;

        DECLARE @IDPhieu BIGINT=
        (
            SELECT TOP(1) ID
            FROM dbo.QL_PhieuSinhHieu
            WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien
            ORDER BY NgayGioDo DESC,ID DESC
        );

        SELECT P.ID AS IDPhieuSinhHieu,P.NgayGioDo,CT.IDTriSoSinhHieu,DM.MaTriSo,DM.TenTriSo,DM.DonViTinh,CT.GiaTri
        FROM dbo.QL_PhieuSinhHieu P
        INNER JOIN dbo.QL_PhieuSinhHieu_CT CT ON CT.IDCSKCB=P.IDCSKCB AND CT.IDPhieuSinhHieu=P.ID
        INNER JOIN dbo.DM_TriSoSinhHieu DM ON DM.IDCSKCB=CT.IDCSKCB AND DM.ID=CT.IDTriSoSinhHieu
        WHERE P.IDCSKCB=@IDCSKCB AND P.ID=@IDPhieu
        ORDER BY ISNULL(DM.ThuTu,999),DM.ID;

        SELECT * FROM dbo.QL_ChanDoan_CT
        WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien
        ORDER BY ISNULL(ThuTu,999),ID;

        SELECT
            C.*,D.MaDichVu,D.TenDichVu,D.DonViTinh,D.DonGia AS DonGiaDanhMuc,
            CASE
                WHEN NULLIF(LTRIM(RTRIM(C.DuongDanKetQua)),N'') IS NULL THEN 0
                ELSE 2
            END AS TrangThaiKetQua,
            CAST(
                CASE
                    WHEN NULLIF(LTRIM(RTRIM(C.DuongDanKetQua)),N'') IS NULL THEN 0
                    ELSE 1
                END AS BIT
            ) AS CoFileKetQua,
            C.DuongDanKetQua
        FROM dbo.QL_ChiDinh_CT C
        INNER JOIN dbo.DM_DichVu D ON D.IDCSKCB=C.IDCSKCB AND D.ID=C.IDDichVu
        WHERE C.IDCSKCB=@IDCSKCB AND C.IDVaoVien=@IDVaoVien AND C.Active=1
        ORDER BY C.ID;

        SELECT T.*,DM.MaThuoc,DM.TenThuoc,COALESCE(DVTD.TenDVT,DVT.TenDVT,DM.DonViTinh) AS DonViTinh,DM.HamLuong,COALESCE(NULLIF(T.HoatChat,N''),DM.HoatChat) AS HoatChat
        FROM dbo.QL_ToaThuoc_CT T
        INNER JOIN dbo.DM_Thuoc DM ON DM.IDCSKCB=T.IDCSKCB AND DM.ID=T.IDThuoc
        LEFT JOIN dbo.DM_DonViTinh DVT ON DVT.IDCSKCB=DM.IDCSKCB AND DVT.ID=DM.IDDonViTinh
        LEFT JOIN dbo.DM_DonViTinh DVTD ON DVTD.IDCSKCB=T.IDCSKCB AND DVTD.ID=T.IDDonViTinhDung
        WHERE T.IDCSKCB=@IDCSKCB AND T.IDVaoVien=@IDVaoVien AND T.Active=1
        ORDER BY ISNULL(T.ThuTu,999),T.ID;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 409 AS Status,ERROR_MESSAGE() AS Message;
    END CATCH
END;

GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_Kham_CapNhatDangKham
    @IDCSKCB BIGINT,
    @IDVaoVien BIGINT,
    @IDBacSi BIGINT,
    @LaQuanTri BIT=0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @TrangThai TINYINT,@Active BIT,@DaChuyen BIT,@BSDangKham BIGINT;
        SELECT @TrangThai=TrangThaiKham,@Active=Active,@DaChuyen=DaChuyenKham,@BSDangKham=IDBacSiKham
        FROM dbo.QL_VaoVien WITH(UPDLOCK,HOLDLOCK)
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien;

        IF @Active IS NULL OR @Active=0
        BEGIN ROLLBACK; SELECT 404 AS Status,N'Không tìm thấy lượt khám.' AS Message; RETURN; END;
        IF ISNULL(@DaChuyen,0)<>1
        BEGIN ROLLBACK; SELECT 409 AS Status,N'Lượt khám chưa được chuyển khám.' AS Message; RETURN; END;
        IF @TrangThai IN(2,3)
        BEGIN ROLLBACK; SELECT 409 AS Status,N'Lượt khám đã kết thúc hoặc đã hủy.' AS Message; RETURN; END;
        IF ISNULL(@LaQuanTri,0)=0
           AND @TrangThai IN(0,1)
           AND @BSDangKham IS NOT NULL
           AND @BSDangKham<>@IDBacSi
        BEGIN ROLLBACK; SELECT 409 AS Status,N'Bệnh nhân đang được bác sĩ khác khám.' AS Message; RETURN; END;

        IF @TrangThai=0
           AND ISNULL
           (
               (SELECT TOP(1) HieuLuc
                FROM dbo.HT_Config
                WHERE IDCSKCB=@IDCSKCB
                  AND MaChucNang=N'THUCONGKHAMDVTRUOC'),
               1
           )=1
           AND EXISTS
           (
               SELECT 1
               FROM dbo.QL_ThuTien T
               INNER JOIN dbo.QL_ThuTien_CT CT
                 ON CT.IDCSKCB=T.IDCSKCB AND CT.IDThuTien=T.ID
               INNER JOIN dbo.QL_CongKham_CT CK
                 ON CK.IDCSKCB=CT.IDCSKCB AND CK.ID=CT.IDCongKhamCT AND CK.Active=1
               WHERE T.IDCSKCB=@IDCSKCB
                 AND T.IDVaoVien=@IDVaoVien
                 AND ISNULL(CT.DaThu,0)=0
                 AND ROUND(ISNULL(CT.ThucThu,CT.ThanhTien),0)>0
           )
        BEGIN
            ROLLBACK;
            SELECT 409 AS Status,N'Bệnh nhân chưa thanh toán công khám. Thu công khám trước khi bắt đầu khám.' AS Message;
            RETURN;
        END;

        UPDATE dbo.QL_VaoVien
        SET TrangThaiKham=1,
            IDBacSiKham=CASE
                WHEN ISNULL(@LaQuanTri,0)=1 AND @IDBacSi<=0 THEN IDBacSiKham
                WHEN ISNULL(@LaQuanTri,0)=1 AND @BSDangKham IS NOT NULL THEN @BSDangKham
                ELSE COALESCE(IDBacSiKham,@IDBacSi)
            END,
            BatDauKhamLuc=COALESCE(BatDauKhamLuc,SYSDATETIME()),
            NgayCapNhat=SYSDATETIME()
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien;

        COMMIT;
        SELECT 200 AS Status,N'Đã cập nhật trạng thái đang khám.' AS Message;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 409 AS Status,ERROR_MESSAGE() AS Message;
    END CATCH
END;

GO

-- 2. STO hủy trạng thái Đang khám khi xóa trắng (nếu chưa từng lưu chính thức)
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kham_HuyDangKham
    @IDCSKCB BIGINT,
    @IDVaoVien BIGINT,
    @IDBacSi BIGINT,
    @LaQuanTri BIT=0
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.QL_VaoVien V
        WHERE V.IDCSKCB=@IDCSKCB AND V.ID=@IDVaoVien
          AND V.Active=1 AND V.TrangThaiKham=1
          AND V.NgayLuuKhamLanDau IS NULL
          AND ISNULL(@LaQuanTri,0)=0
          AND V.IDBacSiKham IS NOT NULL AND V.IDBacSiKham<>@IDBacSi
    )
    BEGIN
        SELECT 409 AS Status,N'Bệnh nhân đang được bác sĩ khác khám.' AS Message;
        RETURN;
    END;

    IF EXISTS(SELECT 1 FROM dbo.QL_VaoVien WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien AND NgayLuuKhamLanDau IS NOT NULL)
       OR EXISTS(SELECT 1 FROM dbo.QL_PhieuSinhHieu WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien)
       OR EXISTS(SELECT 1 FROM dbo.QL_ChanDoan_CT WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien)
       OR EXISTS(SELECT 1 FROM dbo.QL_ChiDinh_CT WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND Active=1)
       OR EXISTS(SELECT 1 FROM dbo.QL_ToaThuoc_CT WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND Active=1)
    BEGIN
        SELECT 409 AS Status,N'Lượt khám đã có dữ liệu được lưu, không thể trả về Chưa khám.' AS Message;
        RETURN;
    END;

    UPDATE dbo.QL_VaoVien
    SET TrangThaiKham=0,
        IDBacSiKham=NULL,
        BatDauKhamLuc=NULL,
        NgayCapNhat=SYSDATETIME()
    WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien
      AND TrangThaiKham=1 AND Active=1
      AND NgayLuuKhamLanDau IS NULL
      AND (ISNULL(@LaQuanTri,0)=1 OR IDBacSiKham IS NULL OR IDBacSiKham=@IDBacSi);

    SELECT CASE WHEN @@ROWCOUNT>0 THEN 200 ELSE 409 END AS Status,
           CASE WHEN @@ROWCOUNT>0 THEN N'Đã trả lượt khám về trạng thái Chưa khám.'
                ELSE N'Không thể hủy trạng thái đang khám.' END AS Message;
END;

GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_Kham_Luu
    @IDCSKCB BIGINT,
    @IDVaoVien BIGINT,
    @IDBacSi BIGINT,
    @TrieuChung NVARCHAR(2000)=NULL,
    @IDPhacDo BIGINT=NULL,
    @MaPDGoc NVARCHAR(50)=NULL,
    @NgayTaiKham DATE=NULL,
    @DanDo NVARCHAR(1000)=NULL,
    @SinhHieuJson NVARCHAR(MAX)=NULL,
    @ChanDoanJson NVARCHAR(MAX)=NULL,
    @ChiDinhJson NVARCHAR(MAX)=NULL,
    @ToaThuocJson NVARCHAR(MAX)=NULL,
    @KhamXong BIT=0,
    @LaQuanTri BIT=0,
    @CoQuyenSua BIT=0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @TrangThaiHienTai TINYINT,@IDThuTien BIGINT,@BSDangKham BIGINT,@IDBacSiNghiepVu BIGINT;
        DECLARE @FilesToDelete TABLE(ID BIGINT PRIMARY KEY,DuongDanTuongDoi NVARCHAR(1000) NOT NULL);
        DECLARE @CIXoa TABLE(ID BIGINT PRIMARY KEY);
        SELECT @TrangThaiHienTai=V.TrangThaiKham,@BSDangKham=V.IDBacSiKham
        FROM dbo.QL_VaoVien V WITH(UPDLOCK,HOLDLOCK)
        WHERE V.IDCSKCB=@IDCSKCB AND V.ID=@IDVaoVien AND V.Active=1 AND V.DaChuyenKham=1;

        IF @TrangThaiHienTai IS NULL THROW 57000,N'Không tìm thấy lượt khám hoặc chưa chuyển khám.',1;
        IF @TrangThaiHienTai=3 THROW 57000,N'Lượt khám đã bị hủy.',1;
        IF @TrangThaiHienTai=2
            THROW 57000,N'Lượt khám đã hoàn tất; không được phép chỉnh sửa.',1;
        IF ISNULL(@LaQuanTri,0)=0
           AND @BSDangKham IS NOT NULL
           AND @BSDangKham<>@IDBacSi
            THROW 57000,N'Bệnh nhân đang thuộc phiên khám của bác sĩ khác.',1;

        SET @IDBacSiNghiepVu=CASE
            WHEN ISNULL(@LaQuanTri,0)=1 THEN @BSDangKham
            ELSE @IDBacSi
        END;

        SELECT @IDThuTien=ID FROM dbo.QL_ThuTien WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien;
        IF EXISTS
        (
            SELECT 1
            FROM dbo.QL_ThuTien_CT CT
            WHERE CT.IDCSKCB=@IDCSKCB
              AND CT.IDThuTien=@IDThuTien
              AND ISNULL(CT.DaThu,0)=1
        )
            THROW 57000,N'Lượt khám đã phát sinh khoản thu, không thể thay đổi dữ liệu.',1;

        IF @IDPhacDo IS NOT NULL
           AND NOT EXISTS(SELECT 1 FROM dbo.DM_PhacDo WHERE IDCSKCB=@IDCSKCB AND ID=@IDPhacDo AND Active=1)
            THROW 57000,N'Phác đồ không hợp lệ.',1;

        UPDATE dbo.QL_VaoVien
        SET IDBacSiKham=@IDBacSiNghiepVu,
            TrieuChung=@TrieuChung,IDPhacDo=@IDPhacDo,
            MaPDGoc=NULLIF(LTRIM(RTRIM(@MaPDGoc)),N''),
            NgayTaiKham=@NgayTaiKham,DanDo=@DanDo,
            BatDauKhamLuc=COALESCE(BatDauKhamLuc,SYSDATETIME()),
            NgayLuuKhamLanDau=COALESCE(NgayLuuKhamLanDau,SYSDATETIME()),
            NgayCapNhatKham=SYSDATETIME(),NgayCapNhat=SYSDATETIME()
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien;

        /* NULL/[] = khong sua sinh hieu; moi IDVaoVien chi co mot phieu sinh hieu. */
        IF @SinhHieuJson IS NOT NULL
        BEGIN
            IF ISJSON(@SinhHieuJson)<>1 THROW 57000,N'Dữ liệu sinh hiệu không hợp lệ.',1;
            IF EXISTS
            (
                SELECT 1 FROM OPENJSON(@SinhHieuJson)
                WITH(GiaTri NVARCHAR(100) '$.GiaTri')
                WHERE NULLIF(LTRIM(RTRIM(GiaTri)),N'') IS NOT NULL
            )
            BEGIN
                DECLARE @IDPhieuSH BIGINT;
                SELECT TOP (1) @IDPhieuSH=P.ID
                FROM dbo.QL_PhieuSinhHieu P WITH(UPDLOCK,HOLDLOCK)
                WHERE P.IDCSKCB=@IDCSKCB AND P.IDVaoVien=@IDVaoVien
                ORDER BY P.NgayGioDo DESC,P.ID DESC;

                IF @IDPhieuSH IS NULL
                BEGIN
                    INSERT dbo.QL_PhieuSinhHieu(IDCSKCB,IDVaoVien,IDNhanVien,NgayGioDo)
                    VALUES(@IDCSKCB,@IDVaoVien,@IDBacSiNghiepVu,SYSDATETIME());
                    SET @IDPhieuSH=SCOPE_IDENTITY();
                END
                ELSE
                BEGIN
                    UPDATE dbo.QL_PhieuSinhHieu
                    SET IDNhanVien=@IDBacSiNghiepVu,
                        NgayGioDo=SYSDATETIME()
                    WHERE IDCSKCB=@IDCSKCB AND ID=@IDPhieuSH;
                    DELETE dbo.QL_PhieuSinhHieu_CT
                    WHERE IDCSKCB=@IDCSKCB AND IDPhieuSinhHieu=@IDPhieuSH;
                END;

                INSERT dbo.QL_PhieuSinhHieu_CT(IDCSKCB,IDPhieuSinhHieu,IDTriSoSinhHieu,GiaTri)
                SELECT @IDCSKCB,@IDPhieuSH,J.IDTriSoSinhHieu,J.GiaTri
                FROM OPENJSON(@SinhHieuJson)
                WITH(IDTriSoSinhHieu BIGINT '$.IDTriSoSinhHieu',GiaTri NVARCHAR(100) '$.GiaTri') J
                INNER JOIN dbo.DM_TriSoSinhHieu D ON D.IDCSKCB=@IDCSKCB AND D.ID=J.IDTriSoSinhHieu AND D.Active=1
                WHERE NULLIF(LTRIM(RTRIM(J.GiaTri)),N'') IS NOT NULL;

                IF EXISTS(SELECT 1 FROM dbo.QL_PhieuSinhHieu_CT WHERE IDCSKCB=@IDCSKCB AND IDPhieuSinhHieu=@IDPhieuSH)
                    UPDATE dbo.QL_VaoVien SET SinhHieu=1 WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien;
            END;
        END;

        /* Chan doan: NULL = giu nguyen; [] = xoa het. */
        IF @ChanDoanJson IS NOT NULL
        BEGIN
            IF ISJSON(@ChanDoanJson)<>1 THROW 57000,N'Dữ liệu chẩn đoán không hợp lệ.',1;
            DECLARE @CD TABLE(IDICD10 BIGINT PRIMARY KEY,BanDau BIT,BenhChinh BIT,BenhKhac BIT,ThuTu INT,GhiChu NVARCHAR(500));
            INSERT @CD
            SELECT IDICD10,ISNULL(BanDau,0),ISNULL(BenhChinh,0),ISNULL(BenhKhac,0),ThuTu,GhiChu
            FROM OPENJSON(@ChanDoanJson)
            WITH(IDICD10 BIGINT '$.IDICD10',BanDau BIT '$.BanDau',BenhChinh BIT '$.BenhChinh',BenhKhac BIT '$.BenhKhac',ThuTu INT '$.ThuTu',GhiChu NVARCHAR(500) '$.GhiChu')
            WHERE IDICD10 IS NOT NULL;

            IF (@KhamXong=1 AND (SELECT COUNT(*) FROM @CD WHERE BenhChinh=1)<>1)
               OR (ISNULL(@KhamXong,0)=0 AND (SELECT COUNT(*) FROM @CD WHERE BenhChinh=1)>1)
            BEGIN
                ROLLBACK;
                SELECT 400 AS Status,N'Chẩn đoán bắt buộc phải có đúng 1 bệnh chính.' AS Message;
                RETURN;
            END;
            IF EXISTS
            (
                SELECT 1 FROM @CD C
                WHERE NOT EXISTS(SELECT 1 FROM dbo.DM_ICD10 I WHERE I.IDCSKCB=@IDCSKCB AND I.ID=C.IDICD10)
            )
                THROW 57000,N'Có mã ICD-10 không hợp lệ.',1;

            DELETE dbo.QL_ChanDoan_CT WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien;
            INSERT dbo.QL_ChanDoan_CT(IDCSKCB,IDVaoVien,IDICD10,MaBenh,TenBenh,BanDau,BenhChinh,BenhKhac,ThuTu,IDBacSi,GhiChu)
            SELECT @IDCSKCB,@IDVaoVien,I.ID,I.MaBenh,I.TenBenh,C.BanDau,C.BenhChinh,C.BenhKhac,C.ThuTu,@IDBacSiNghiepVu,C.GhiChu
            FROM @CD C INNER JOIN dbo.DM_ICD10 I ON I.IDCSKCB=@IDCSKCB AND I.ID=C.IDICD10;
        END
        ELSE IF (@KhamXong=1 AND
                 (SELECT COUNT(*) FROM dbo.QL_ChanDoan_CT WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND BenhChinh=1)<>1)
             OR (ISNULL(@KhamXong,0)=0 AND
                 (SELECT COUNT(*) FROM dbo.QL_ChanDoan_CT WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND BenhChinh=1)>1)
        BEGIN
            ROLLBACK;
            SELECT 400 AS Status,N'Chẩn đoán bắt buộc phải có đúng 1 bệnh chính.' AS Message;
            RETURN;
        END;

        /* Chi dinh: giu ID de ket qua/file CLS khong bi dut lien ket. */
        IF @ChiDinhJson IS NOT NULL
        BEGIN
            IF ISJSON(@ChiDinhJson)<>1 THROW 57000,N'Dữ liệu chỉ định không hợp lệ.',1;

            DECLARE @CI TABLE
            (
                ID BIGINT NULL,IDDichVu BIGINT NOT NULL,NgayGioChiDinh DATETIME2(0) NULL,SoLuong DECIMAL(10,2) NOT NULL,
                DonGia DECIMAL(18,2) NULL,GuiNgoai BIT NOT NULL,NoiGuiNgoai NVARCHAR(300) NULL,GhiChu NVARCHAR(500) NULL
            );

            INSERT @CI(ID,IDDichVu,NgayGioChiDinh,SoLuong,DonGia,GuiNgoai,NoiGuiNgoai,GhiChu)
            SELECT NULL,J.IDDichVu,J.NgayGioChiDinh,COALESCE(J.SoLuong,1),NULL,ISNULL(J.GuiNgoai,0),J.NoiGuiNgoai,J.GhiChu
            FROM OPENJSON(@ChiDinhJson)
            WITH
            (
                IDDichVu BIGINT '$.IDDichVu',NgayGioChiDinh DATETIME2(0) '$.NgayGioChiDinh',
                SoLuong DECIMAL(10,2) '$.SoLuong',DonGia DECIMAL(18,2) '$.DonGia',
                GuiNgoai BIT '$.GuiNgoai',NoiGuiNgoai NVARCHAR(300) '$.NoiGuiNgoai',GhiChu NVARCHAR(500) '$.GhiChu'
            ) J
            WHERE J.IDDichVu IS NOT NULL;

            IF EXISTS(SELECT 1 FROM @CI WHERE SoLuong<=0)
                THROW 57000,N'Số lượng chỉ định CLS phải lớn hơn 0.',1;

            /* Khong nhan ID dong chi tiet tu client.
               Trong mot luot kham UI khong cho chon trung dich vu, nen tim dong
               hien co bang IDCSKCB + IDVaoVien + IDDichVu. */
            UPDATE X
            SET ID=M.ID
            FROM @CI X
            OUTER APPLY
            (
                SELECT TOP(1) C.ID
                FROM dbo.QL_ChiDinh_CT C WITH(UPDLOCK,HOLDLOCK)
                WHERE C.IDCSKCB=@IDCSKCB
                  AND C.IDVaoVien=@IDVaoVien
                  AND C.IDDichVu=X.IDDichVu
                  AND C.Active=1
                ORDER BY C.ID
            ) M
            WHERE M.ID IS NOT NULL;

            IF EXISTS
            (
                SELECT 1 FROM @CI X
                WHERE NOT EXISTS(SELECT 1 FROM dbo.DM_DichVu D WHERE D.IDCSKCB=@IDCSKCB AND D.ID=X.IDDichVu AND D.Active=1 AND D.LoaiDichVu<>1)
            )
                THROW 57000,N'Có dịch vụ CLS không hợp lệ.',1;

            INSERT @CIXoa(ID)
            SELECT C.ID
            FROM dbo.QL_ChiDinh_CT C WITH(UPDLOCK,HOLDLOCK)
            WHERE C.IDCSKCB=@IDCSKCB AND C.IDVaoVien=@IDVaoVien AND C.Active=1
              AND NOT EXISTS(SELECT 1 FROM @CI X WHERE X.ID=C.ID);

            INSERT @FilesToDelete(ID,DuongDanTuongDoi)
            SELECT C.ID,C.DuongDanKetQua
            FROM @CIXoa X
            INNER JOIN dbo.QL_ChiDinh_CT C ON C.ID=X.ID AND C.IDCSKCB=@IDCSKCB
            WHERE C.IDVaoVien=@IDVaoVien AND NULLIF(LTRIM(RTRIM(C.DuongDanKetQua)),N'') IS NOT NULL;

            DELETE T
            FROM dbo.QL_ThuTien_CT T
            INNER JOIN dbo.QL_ChiDinh_CT C ON C.IDCSKCB=T.IDCSKCB AND C.ID=T.IDChiDinhCT
            WHERE T.IDCSKCB=@IDCSKCB AND T.IDThuTien=@IDThuTien AND C.IDVaoVien=@IDVaoVien;

            UPDATE C
            SET Active=0
            FROM dbo.QL_ChiDinh_CT C
            WHERE C.IDCSKCB=@IDCSKCB AND C.IDVaoVien=@IDVaoVien AND C.Active=1
              AND NOT EXISTS(SELECT 1 FROM @CI X WHERE X.ID=C.ID);

            UPDATE C
            SET IDDichVu=X.IDDichVu,NgayGioChiDinh=COALESCE(X.NgayGioChiDinh,C.NgayGioChiDinh),SoLuong=X.SoLuong,
                DonGia=CASE WHEN X.GuiNgoai=1 THEN 0 ELSE D.DonGia END,
                ThanhTien=CASE WHEN X.GuiNgoai=1 THEN 0 ELSE X.SoLuong*D.DonGia END,
                GuiNgoai=X.GuiNgoai,
                NoiGuiNgoai=CASE WHEN X.GuiNgoai=1 THEN X.NoiGuiNgoai END,GhiChu=X.GhiChu
            FROM dbo.QL_ChiDinh_CT C
            INNER JOIN @CI X ON X.ID=C.ID
            INNER JOIN dbo.DM_DichVu D ON D.IDCSKCB=@IDCSKCB AND D.ID=X.IDDichVu
            WHERE C.IDCSKCB=@IDCSKCB AND C.IDVaoVien=@IDVaoVien AND C.Active=1;

            INSERT dbo.QL_ChiDinh_CT
            (
                IDCSKCB,IDVaoVien,IDDichVu,NgayGioChiDinh,SoLuong,DonGia,ThanhTien,GuiNgoai,NoiGuiNgoai,IDBacSiChiDinh,TrangThai,GhiChu,Active
            )
            SELECT @IDCSKCB,@IDVaoVien,D.ID,COALESCE(X.NgayGioChiDinh,SYSDATETIME()),X.SoLuong,
                   CASE WHEN X.GuiNgoai=1 THEN 0 ELSE D.DonGia END,
                   CASE WHEN X.GuiNgoai=1 THEN 0 ELSE X.SoLuong*D.DonGia END,
                   X.GuiNgoai,
                   CASE WHEN X.GuiNgoai=1 THEN X.NoiGuiNgoai END,@IDBacSiNghiepVu,0,X.GhiChu,1
            FROM @CI X
            INNER JOIN dbo.DM_DichVu D ON D.IDCSKCB=@IDCSKCB AND D.ID=X.IDDichVu
            WHERE ISNULL(X.ID,0)<=0;

            IF @IDThuTien IS NOT NULL
                INSERT dbo.QL_ThuTien_CT(IDCSKCB,IDThuTien,IDChiDinhCT,SoLuong,DonGia,ThanhTien,TienGiam,ThucThu,DaThu)
                SELECT @IDCSKCB,@IDThuTien,C.ID,C.SoLuong,C.DonGia,C.ThanhTien,0,C.ThanhTien,0
                FROM dbo.QL_ChiDinh_CT C
                WHERE C.IDCSKCB=@IDCSKCB AND C.IDVaoVien=@IDVaoVien AND C.Active=1;
        END;

        /* Toa: diff/upsert de giu ID, NULL = giu nguyen. */
        IF @ToaThuocJson IS NOT NULL
        BEGIN
            IF ISJSON(@ToaThuocJson)<>1 THROW 57000,N'Dữ liệu toa thuốc không hợp lệ.',1;

            DECLARE @TT TABLE
            (
                ID BIGINT NULL,IDThuoc BIGINT NOT NULL,MaLoaiToaThuoc NVARCHAR(1) NOT NULL,SoNgay INT NULL,Sang NVARCHAR(50) NULL,Trua NVARCHAR(50) NULL,
                Chieu NVARCHAR(50) NULL,Toi NVARCHAR(50) NULL,LieuDung NVARCHAR(300) NULL,CachDung NVARCHAR(500) NULL,
                NgayKe DATETIME2(0) NULL,SoLuong DECIMAL(10,2) NOT NULL,DonGia DECIMAL(18,2) NULL,ThuTu INT NULL,IDToaThuocCTGoc BIGINT NULL,
                IDDonViTinhDung BIGINT NULL
            );

            IF EXISTS
            (
                SELECT 1
                FROM OPENJSON(@ToaThuocJson)
                WITH(IDThuoc BIGINT '$.IDThuoc',SoLuong DECIMAL(10,2) '$.SoLuong')
                WHERE IDThuoc IS NOT NULL AND ISNULL(SoLuong,0)<=0
            )
                THROW 57000,N'Số lượng thuốc phải lớn hơn 0.',1;

            INSERT @TT
            SELECT NULL,J.IDThuoc,COALESCE(NULLIF(LOWER(LTRIM(RTRIM(J.MaLoaiToaThuoc))),N''),N'c'),J.SoNgay,J.Sang,J.Trua,J.Chieu,J.Toi,J.LieuDung,J.CachDung,
                   J.NgayKe,J.SoLuong,NULL,J.ThuTu,J.IDToaThuocCTGoc,J.IDDonViTinhDung
            FROM OPENJSON(@ToaThuocJson)
            WITH
            (
                IDThuoc BIGINT '$.IDThuoc',MaLoaiToaThuoc NVARCHAR(1) '$.MaLoaiToaThuoc',SoNgay INT '$.SoNgay',
                Sang NVARCHAR(50) '$.Sang',Trua NVARCHAR(50) '$.Trua',Chieu NVARCHAR(50) '$.Chieu',Toi NVARCHAR(50) '$.Toi',
                LieuDung NVARCHAR(300) '$.LieuDung',CachDung NVARCHAR(500) '$.CachDung',NgayKe DATETIME2(0) '$.NgayKe',SoLuong DECIMAL(10,2) '$.SoLuong',
                DonGia DECIMAL(18,2) '$.DonGia',ThuTu INT '$.ThuTu',IDToaThuocCTGoc BIGINT '$.IDToaThuocCTGoc',
                IDDonViTinhDung BIGINT '$.IDDonViTinhDung'
            ) J
            WHERE J.IDThuoc IS NOT NULL AND J.SoLuong>0;

            IF EXISTS(SELECT 1 FROM @TT WHERE ISNULL(ThuTu,0)<=0)
                THROW 57000,N'Thứ tự dòng toa thuốc không hợp lệ.',1;
            IF EXISTS(SELECT ThuTu FROM @TT GROUP BY ThuTu HAVING COUNT(*)>1)
                THROW 57000,N'Thứ tự dòng toa thuốc bị lặp.',1;

            /* Khong nhan ID dong toa tu client.
               Tim dong hien co bang IDCSKCB + IDVaoVien + ThuTu. */
            UPDATE X
            SET ID=M.ID
            FROM @TT X
            OUTER APPLY
            (
                SELECT TOP(1) T.ID
                FROM dbo.QL_ToaThuoc_CT T WITH(UPDLOCK,HOLDLOCK)
                WHERE T.IDCSKCB=@IDCSKCB
                  AND T.IDVaoVien=@IDVaoVien
                  AND T.ThuTu=X.ThuTu
                  AND T.Active=1
                ORDER BY T.ID
            ) M
            WHERE M.ID IS NOT NULL;
            IF EXISTS(SELECT 1 FROM @TT WHERE MaLoaiToaThuoc NOT IN(N'c',N'n',N'h'))
                THROW 57000,N'Loại toa thuốc không hợp lệ.',1;
            /* Một lượt khám được kê đồng thời nhiều loại toa c/n/h.
               MaLoaiToaThuoc được lưu riêng trên từng dòng và chỉ tách khi in. */
            IF EXISTS
            (
                SELECT 1 FROM @TT X
                WHERE NOT EXISTS(SELECT 1 FROM dbo.DM_Thuoc D WHERE D.IDCSKCB=@IDCSKCB AND D.ID=X.IDThuoc AND D.Active=1)
            )
                THROW 57000,N'Có thuốc không hợp lệ.',1;
            IF EXISTS
            (
                SELECT 1 FROM @TT X
                WHERE X.IDDonViTinhDung IS NOT NULL
                  AND NOT EXISTS
                  (
                      SELECT 1
                      FROM dbo.DM_DonViTinh DVT
                      WHERE DVT.IDCSKCB=@IDCSKCB
                        AND DVT.ID=X.IDDonViTinhDung
                        AND DVT.Active=1
                  )
            )
                THROW 57000,N'Đơn vị tính dùng không hợp lệ.',1;
            DELETE X
            FROM dbo.QL_ThuTien_CT X
            INNER JOIN dbo.QL_ToaThuoc_CT T ON T.IDCSKCB=X.IDCSKCB AND T.ID=X.IDToaThuocCT
            WHERE X.IDCSKCB=@IDCSKCB AND X.IDThuTien=@IDThuTien AND T.IDVaoVien=@IDVaoVien;

            UPDATE T
            SET Active=0
            FROM dbo.QL_ToaThuoc_CT T
            WHERE T.IDCSKCB=@IDCSKCB AND T.IDVaoVien=@IDVaoVien AND T.Active=1
              AND NOT EXISTS(SELECT 1 FROM @TT X WHERE X.ID=T.ID);

            UPDATE T
            SET IDThuoc=X.IDThuoc,MaLoaiToaThuoc=X.MaLoaiToaThuoc,IDBacSiKe=@IDBacSiNghiepVu,NgayKe=COALESCE(X.NgayKe,T.NgayKe),SoNgay=X.SoNgay,Sang=X.Sang,Trua=X.Trua,
                Chieu=X.Chieu,Toi=X.Toi,LieuDung=X.LieuDung,CachDung=X.CachDung,SoLuong=X.SoLuong,
                DonGia=D.GiaBan,ThanhTien=X.SoLuong*D.GiaBan,
                ThuTu=X.ThuTu,IDToaThuocCTGoc=X.IDToaThuocCTGoc,
                IDDonViTinhDung=COALESCE(X.IDDonViTinhDung,D.IDDonViTinh),
                HoatChat=CASE
                    WHEN T.IDThuoc=X.IDThuoc AND NULLIF(LTRIM(RTRIM(T.HoatChat)),N'') IS NOT NULL THEN T.HoatChat
                    ELSE D.HoatChat
                END
            FROM dbo.QL_ToaThuoc_CT T
            INNER JOIN @TT X ON X.ID=T.ID
            INNER JOIN dbo.DM_Thuoc D ON D.IDCSKCB=@IDCSKCB AND D.ID=X.IDThuoc
            WHERE T.IDCSKCB=@IDCSKCB AND T.IDVaoVien=@IDVaoVien AND T.Active=1;

            INSERT dbo.QL_ToaThuoc_CT
            (
                IDCSKCB,IDVaoVien,IDThuoc,MaLoaiToaThuoc,NgayKe,IDBacSiKe,SoNgay,Sang,Trua,Chieu,Toi,LieuDung,CachDung,
                SoLuong,DonGia,ThanhTien,ThuTu,IDToaThuocCTGoc,IDDonViTinhDung,HoatChat,Active
            )
            SELECT @IDCSKCB,@IDVaoVien,D.ID,X.MaLoaiToaThuoc,COALESCE(X.NgayKe,SYSDATETIME()),@IDBacSiNghiepVu,X.SoNgay,X.Sang,X.Trua,X.Chieu,X.Toi,X.LieuDung,X.CachDung,
                   X.SoLuong,D.GiaBan,X.SoLuong*D.GiaBan,X.ThuTu,X.IDToaThuocCTGoc,COALESCE(X.IDDonViTinhDung,D.IDDonViTinh),D.HoatChat,1
            FROM @TT X
            INNER JOIN dbo.DM_Thuoc D ON D.IDCSKCB=@IDCSKCB AND D.ID=X.IDThuoc
            WHERE ISNULL(X.ID,0)<=0;

            IF @IDThuTien IS NOT NULL
                INSERT dbo.QL_ThuTien_CT(IDCSKCB,IDThuTien,IDToaThuocCT,SoLuong,DonGia,ThanhTien,TienGiam,ThucThu,DaThu)
                SELECT @IDCSKCB,@IDThuTien,T.ID,T.SoLuong,T.DonGia,T.ThanhTien,0,T.ThanhTien,0
                FROM dbo.QL_ToaThuoc_CT T
                WHERE T.IDCSKCB=@IDCSKCB AND T.IDVaoVien=@IDVaoVien AND T.Active=1;

            UPDATE dbo.QL_VaoVien
            SET KeToa=CASE WHEN EXISTS(SELECT 1 FROM dbo.QL_ToaThuoc_CT WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND Active=1) THEN 1 ELSE 0 END
            WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien;
        END;

        IF @IDThuTien IS NOT NULL EXEC dbo.STO_QL_ThuTien_CapNhatTong @IDCSKCB,@IDVaoVien;

        DECLARE @TrangThaiMoi TINYINT=CASE
            WHEN @TrangThaiHienTai=2 OR @KhamXong=1 THEN 2
            WHEN @TrangThaiHienTai=0 THEN 1
            ELSE @TrangThaiHienTai
        END;

        UPDATE dbo.QL_VaoVien
        SET TrangThaiKham=@TrangThaiMoi,
            Kham=CASE WHEN @KhamXong=1 THEN 1 ELSE Kham END,
            KetThucKhamLuc=CASE WHEN @KhamXong=1 THEN COALESCE(KetThucKhamLuc,SYSDATETIME()) ELSE KetThucKhamLuc END,
            NgayCapNhat=SYSDATETIME()
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien;

        COMMIT;
        /* Chỉ yêu cầu xóa file vật lý sau khi giao dịch SQL đã commit.
           Không trả danh sách nếu lưu không thành công. */
        SELECT 200 AS Status,
               CASE WHEN @TrangThaiMoi=2 THEN N'Khám bệnh hoàn tất thành công.' ELSE N'Lưu dữ liệu khám thành công.' END AS Message,
               ISNULL((SELECT F.DuongDanTuongDoi
                       FROM @FilesToDelete AS F
                       FOR JSON PATH),N'[]') AS FilesToDeleteJson;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 400 AS Status,N'Không thể lưu khám bệnh do dữ liệu không hợp lệ hoặc đã thay đổi.' AS Message;
    END CATCH
END;

GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_Kham_HoanTat
    @IDCSKCB BIGINT,
    @IDVaoVien BIGINT,
    @IDBacSi BIGINT,
    @LaQuanTri BIT=0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @TrangThai TINYINT,@DaChuyen BIT,@BSDangKham BIGINT,@NgayLuuKhamLanDau DATETIME2(0);
        SELECT @TrangThai=V.TrangThaiKham,@DaChuyen=V.DaChuyenKham,@BSDangKham=V.IDBacSiKham,
               @NgayLuuKhamLanDau=V.NgayLuuKhamLanDau
        FROM dbo.QL_VaoVien V WITH(UPDLOCK,HOLDLOCK)
        WHERE V.IDCSKCB=@IDCSKCB AND V.ID=@IDVaoVien AND V.Active=1;

        IF @TrangThai IS NULL THROW 57000,N'Không tìm thấy lượt khám.',1;
        IF ISNULL(@DaChuyen,0)<>1 THROW 57000,N'Lượt khám chưa được chuyển khám.',1;
        IF @TrangThai=3 THROW 57000,N'Lượt khám đã bị hủy.',1;

        IF @NgayLuuKhamLanDau IS NULL
            THROW 57000,N'Lượt khám chưa được lưu.',1;

        IF @TrangThai=2
        BEGIN
            COMMIT;
            SELECT 200 AS Status,N'Lượt khám đã hoàn tất.' AS Message,
                   @IDVaoVien AS IDVaoVien,CAST(2 AS TINYINT) AS TrangThaiKham;
            RETURN;
        END;

        IF ISNULL(@LaQuanTri,0)=0
           AND @BSDangKham IS NOT NULL
           AND @BSDangKham<>@IDBacSi
            THROW 57000,N'Bệnh nhân đang thuộc phiên khám của bác sĩ khác.',1;

        IF (SELECT COUNT(*) FROM dbo.QL_ChanDoan_CT
            WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND BenhChinh=1)<>1
            THROW 57000,N'Chẩn đoán bắt buộc phải có đúng 1 bệnh chính.',1;

        UPDATE dbo.QL_VaoVien
        SET TrangThaiKham=2,
            Kham=1,
            KetThucKhamLuc=COALESCE(KetThucKhamLuc,SYSDATETIME()),
            NgayCapNhatKham=SYSDATETIME(),
            NgayCapNhat=SYSDATETIME()
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien;

        COMMIT;
        SELECT 200 AS Status,N'Khám bệnh hoàn tất thành công.' AS Message,
               @IDVaoVien AS IDVaoVien,CAST(2 AS TINYINT) AS TrangThaiKham;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 400 AS Status,ERROR_MESSAGE() AS Message,
               @IDVaoVien AS IDVaoVien,CAST(NULL AS TINYINT) AS TrangThaiKham;
    END CATCH
END;

GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_Kham_LayToaCu
    @IDCSKCB BIGINT,
    @IDVaoVienCu BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT T.ID AS IDToaThuocCTGoc, T.IDThuoc, T.MaLoaiToaThuoc, DM.MaThuoc, DM.TenThuoc, COALESCE(DVTD.TenDVT,DVT.TenDVT,DM.DonViTinh) AS DonViTinh, T.IDDonViTinhDung, DM.HamLuong, COALESCE(NULLIF(T.HoatChat,N''),DM.HoatChat) AS HoatChat,
           T.SoNgay, T.Sang, T.Trua, T.Chieu, T.Toi, T.LieuDung, T.CachDung, T.SoLuong, T.DonGia, T.ThanhTien, T.ThuTu
    FROM dbo.QL_ToaThuoc_CT T
    JOIN dbo.DM_Thuoc DM ON DM.IDCSKCB = T.IDCSKCB AND DM.ID = T.IDThuoc
    LEFT JOIN dbo.DM_DonViTinh DVT ON DVT.IDCSKCB=DM.IDCSKCB AND DVT.ID=DM.IDDonViTinh
        LEFT JOIN dbo.DM_DonViTinh DVTD ON DVTD.IDCSKCB=T.IDCSKCB AND DVTD.ID=T.IDDonViTinhDung
    WHERE T.IDCSKCB = @IDCSKCB AND T.IDVaoVien = @IDVaoVienCu AND T.Active = 1
    ORDER BY ISNULL(T.ThuTu, 999), T.ID;
END;

GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_Kham_ChiTietLanKhamCu
    @IDCSKCB BIGINT,
    @IDVaoVienCu BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ID, MaVaoVien, TrieuChung, DanDo, NgayTaiKham, IDPhacDo, MaPDGoc
    FROM dbo.QL_VaoVien
    WHERE IDCSKCB = @IDCSKCB AND ID = @IDVaoVienCu;

    DECLARE @IDPhieu BIGINT =
    (
        SELECT TOP 1 ID
        FROM dbo.QL_PhieuSinhHieu
        WHERE IDCSKCB = @IDCSKCB AND IDVaoVien = @IDVaoVienCu
        ORDER BY NgayGioDo DESC, ID DESC
    );

    SELECT CT.IDTriSoSinhHieu, DM.MaTriSo, DM.TenTriSo, DM.DonViTinh, CT.GiaTri
    FROM dbo.QL_PhieuSinhHieu_CT CT
    JOIN dbo.DM_TriSoSinhHieu DM ON DM.IDCSKCB = CT.IDCSKCB AND DM.ID = CT.IDTriSoSinhHieu
    WHERE CT.IDCSKCB = @IDCSKCB AND CT.IDPhieuSinhHieu = @IDPhieu
    ORDER BY ISNULL(DM.ThuTu, 999), DM.ID;

    SELECT CD.IDICD10, CD.MaBenh, CD.TenBenh, CD.BanDau, CD.BenhChinh, CD.BenhKhac, CD.GhiChu
    FROM dbo.QL_ChanDoan_CT CD
    WHERE CD.IDCSKCB = @IDCSKCB AND CD.IDVaoVien = @IDVaoVienCu
    ORDER BY ISNULL(CD.ThuTu, 999), CD.ID;

    SELECT
        C.ID AS IDChiDinhCT,C.IDDichVu,D.MaDichVu,D.TenDichVu,C.SoLuong,C.DonGia,D.DonGia AS DonGiaDanhMuc,
        C.GuiNgoai,C.NoiGuiNgoai,C.GhiChu,
        CASE
            WHEN NULLIF(LTRIM(RTRIM(C.DuongDanKetQua)),N'') IS NULL THEN 0
            ELSE 2
        END AS TrangThaiKetQua,
        CAST(
            CASE
                WHEN NULLIF(LTRIM(RTRIM(C.DuongDanKetQua)),N'') IS NULL THEN 0
                ELSE 1
            END AS BIT
        ) AS CoFileKetQua,
        C.DuongDanKetQua
    FROM dbo.QL_ChiDinh_CT C
    JOIN dbo.DM_DichVu D ON D.IDCSKCB = C.IDCSKCB AND D.ID = C.IDDichVu
    WHERE C.IDCSKCB = @IDCSKCB AND C.IDVaoVien = @IDVaoVienCu AND C.Active = 1
    ORDER BY C.ID;

    SELECT
        T.IDThuoc, T.MaLoaiToaThuoc, M.MaThuoc, M.TenThuoc, COALESCE(DVTD.TenDVT,DVT.TenDVT,M.DonViTinh) AS DonViTinh, T.IDDonViTinhDung, M.HamLuong, COALESCE(NULLIF(T.HoatChat,N''),M.HoatChat) AS HoatChat,
        T.SoNgay, T.Sang, T.Trua, T.Chieu, T.Toi, T.LieuDung, T.CachDung,
        T.SoLuong, T.DonGia, T.ThanhTien, T.ID AS IDToaThuocCTGoc
    FROM dbo.QL_ToaThuoc_CT T
    JOIN dbo.DM_Thuoc M ON M.IDCSKCB = T.IDCSKCB AND M.ID = T.IDThuoc
    LEFT JOIN dbo.DM_DonViTinh DVT ON DVT.IDCSKCB=M.IDCSKCB AND DVT.ID=M.IDDonViTinh
    LEFT JOIN dbo.DM_DonViTinh DVTD ON DVTD.IDCSKCB=T.IDCSKCB AND DVTD.ID=T.IDDonViTinhDung
    WHERE T.IDCSKCB = @IDCSKCB AND T.IDVaoVien = @IDVaoVienCu AND T.Active = 1
    ORDER BY ISNULL(T.ThuTu, 999), T.ID;
END;

GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_Kham_LichSu
    @IDCSKCB BIGINT,
    @IDBenhNhan BIGINT,
    @IDVaoVienHienTai BIGINT = NULL,
    @TuKhoa NVARCHAR(200) = NULL,
    @Trang INT = 1,
    @KichThuocTrang INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    SET @TuKhoa = NULLIF(LTRIM(RTRIM(@TuKhoa)), N'');
    SET @Trang = CASE WHEN @Trang < 1 THEN 1 ELSE @Trang END;
    SET @KichThuocTrang = CASE
        WHEN @KichThuocTrang < 10 THEN 10
        WHEN @KichThuocTrang > 100 THEN 100
        ELSE @KichThuocTrang
    END;

    SELECT
        VV.ID AS IDVaoVien,
        VV.MaVaoVien,
        VV.NgayGioVaoVien,
        VV.BatDauKhamLuc,
        VV.KetThucKhamLuc,
        VV.TrieuChung,
        VV.NgayTaiKham,
        VV.DanDo,
        NV.HoTen AS BacSiKham,
        STRING_AGG(
            (CASE WHEN CD.BanDau = 1 THEN N'[BĐ] ' ELSE N'' END) +
            (CASE WHEN CD.BenhChinh = 1 THEN N'[Chính] ' ELSE N'' END) +
            (CASE WHEN CD.BenhKhac = 1 THEN N'[#] ' ELSE N'' END) +
            CD.MaBenh + N' - ' + CD.TenBenh,
            N'; '
        ) AS ChanDoan,
        (SELECT COUNT(1)
         FROM dbo.QL_ToaThuoc_CT T
         WHERE T.IDCSKCB = VV.IDCSKCB
           AND T.IDVaoVien = VV.ID
           AND T.Active = 1) AS SoLuongThuoc,
        (SELECT COUNT(1)
         FROM dbo.QL_ChiDinh_CT C
         WHERE C.IDCSKCB = VV.IDCSKCB
           AND C.IDVaoVien = VV.ID
           AND C.Active = 1) AS SoLuongChiDinh,
        COUNT(*) OVER() AS TongSoDong
    FROM dbo.QL_VaoVien VV
    LEFT JOIN dbo.DM_NhanVien NV
      ON NV.ID = VV.IDBacSiKham
    LEFT JOIN dbo.QL_ChanDoan_CT CD
      ON CD.IDCSKCB = VV.IDCSKCB
     AND CD.IDVaoVien = VV.ID
    WHERE VV.IDCSKCB = @IDCSKCB
      AND VV.IDBenhNhan = @IDBenhNhan
      /* Lịch sử chỉ nhận lượt đã Khám xong.
         Kham/KeToa là cờ legacy, có dữ liệu toa không đồng nghĩa đã hoàn tất. */
      AND VV.TrangThaiKham = 2
      /* Lượt hiện tại đã Khám xong cũng là một hồ sơ lịch sử hợp lệ. */
      AND (@IDVaoVienHienTai IS NULL OR VV.ID <> @IDVaoVienHienTai OR VV.TrangThaiKham = 2)
      AND VV.Active = 1
      AND
      (
          @TuKhoa IS NULL
          OR NV.HoTen LIKE N'%' + @TuKhoa + N'%'
          OR VV.TrieuChung LIKE N'%' + @TuKhoa + N'%'
          OR CONVERT(NVARCHAR(10), VV.NgayGioVaoVien, 103) LIKE N'%' + @TuKhoa + N'%'
          OR EXISTS
          (
              SELECT 1
              FROM dbo.QL_ChanDoan_CT X
              WHERE X.IDCSKCB = VV.IDCSKCB
                AND X.IDVaoVien = VV.ID
                AND
                (
                    X.MaBenh LIKE N'%' + @TuKhoa + N'%'
                    OR X.TenBenh LIKE N'%' + @TuKhoa + N'%'
                )
          )
      )
    GROUP BY
        VV.ID, VV.MaVaoVien, VV.NgayGioVaoVien, VV.BatDauKhamLuc, VV.KetThucKhamLuc,
        VV.TrieuChung, VV.NgayTaiKham, VV.DanDo, NV.HoTen, VV.IDCSKCB
    ORDER BY VV.NgayGioVaoVien DESC, VV.ID DESC
    OFFSET (@Trang - 1) * @KichThuocTrang ROWS
    FETCH NEXT @KichThuocTrang ROWS ONLY;
END;
GO

PRINT N'02_main_sto_tiep_nhan_kham.sql: OK';

GO
