USE [QLPM];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/*
    30_phan_quyen_bs_tiep_nhan_va_quan_ly_nhan_vien.sql

    - Sửa lỗi SQL Server 8711 của STO_HT_Tai_Khoan_Danh_Sach.
    - Bổ sung chức năng quản trị Nhân viên.
    - Tạo vai trò mặc định Bác sĩ / Tiếp nhận nếu chưa có.
    - Gán quyền mặc định tối thiểu cho hai vai trò mới.
*/

CREATE OR ALTER PROCEDURE dbo.STO_HT_Tai_Khoan_Danh_Sach
    @IDCSKCB BIGINT=NULL,
    @TuKhoa NVARCHAR(200)=NULL,
    @Trang INT=1,
    @KichThuocTrang INT=25
AS
BEGIN
    SET NOCOUNT ON;
    SET @TuKhoa=NULLIF(LTRIM(RTRIM(@TuKhoa)),N'');
    SET @Trang=CASE WHEN @Trang<1 THEN 1 ELSE @Trang END;
    SET @KichThuocTrang=CASE WHEN @KichThuocTrang<10 THEN 10 WHEN @KichThuocTrang>100 THEN 100 ELSE @KichThuocTrang END;

    ;WITH D AS
    (
        SELECT
            T.ID AS ID_Tai_Khoan,T.IDCSKCB,C.MaCSKCB,C.TenCSKCB,T.IDNhanVien,
            N.MaNhanVien,N.HoTen,N.IDChucDanh,CD.TenChucDanh AS ChucDanh,
            T.Ten_Dang_Nhap,T.Bat_Buoc_Doi_Mat_Khau,T.So_Lan_Dang_Nhap_Sai,T.Khoa_Den_Luc,T.Lan_Dang_Nhap_Cuoi,T.Active,
            STRING_AGG(V.Ten_Vai_Tro,N', ') WITHIN GROUP (ORDER BY V.Ten_Vai_Tro,V.ID) AS Vai_Tro,
            STRING_AGG(CONVERT(NVARCHAR(MAX),V.ID),N',') AS ID_Vai_Tro
        FROM dbo.HT_Tai_Khoan T
        INNER JOIN dbo.DM_CSKCB C ON C.ID=T.IDCSKCB
        INNER JOIN dbo.DM_NhanVien N ON N.ID=T.IDNhanVien
        INNER JOIN dbo.DM_NhanVien_CSKCB M
            ON M.IDNhanVien=N.ID AND M.IDCSKCB=T.IDCSKCB AND M.Active=1
        LEFT JOIN dbo.DM_ChucDanh CD ON CD.ID=N.IDChucDanh
        LEFT JOIN dbo.HT_Tai_Khoan_Vai_Tro TV
          ON TV.IDCSKCB=T.IDCSKCB AND TV.ID_Tai_Khoan=T.ID AND TV.Active=1
        LEFT JOIN dbo.DM_Vai_Tro V
          ON V.IDCSKCB=TV.IDCSKCB AND V.ID=TV.ID_Vai_Tro AND V.Active=1
        WHERE T.LaQuanTriHeThong=0
          AND (@IDCSKCB IS NULL OR T.IDCSKCB=@IDCSKCB)
          AND
          (
              @TuKhoa IS NULL
              OR T.Ten_Dang_Nhap LIKE N'%'+@TuKhoa+N'%'
              OR N.MaNhanVien LIKE N'%'+@TuKhoa+N'%'
              OR N.HoTen LIKE N'%'+@TuKhoa+N'%'
              OR C.MaCSKCB LIKE N'%'+@TuKhoa+N'%'
              OR C.TenCSKCB LIKE N'%'+@TuKhoa+N'%'
          )
        GROUP BY
            T.ID,T.IDCSKCB,C.MaCSKCB,C.TenCSKCB,T.IDNhanVien,
            N.MaNhanVien,N.HoTen,N.IDChucDanh,CD.TenChucDanh,
            T.Ten_Dang_Nhap,T.Bat_Buoc_Doi_Mat_Khau,T.So_Lan_Dang_Nhap_Sai,
            T.Khoa_Den_Luc,T.Lan_Dang_Nhap_Cuoi,T.Active
    )
    SELECT D.*,COUNT(*) OVER() AS TongSoDong
    FROM D
    ORDER BY D.ID_Tai_Khoan DESC
    OFFSET (@Trang-1)*@KichThuocTrang ROWS
    FETCH NEXT @KichThuocTrang ROWS ONLY;
END;
GO

/* Metadata chức năng Nhân viên */
DECLARE @IDCSKCB BIGINT;
DECLARE cs CURSOR LOCAL FAST_FORWARD FOR
    SELECT ID FROM dbo.DM_CSKCB WHERE Active = 1;

OPEN cs;
FETCH NEXT FROM cs INTO @IDCSKCB;
WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @IDPhanHeHeThong BIGINT;

    SELECT @IDPhanHeHeThong = ID
    FROM dbo.HT_Phan_He
    WHERE IDCSKCB = @IDCSKCB AND Ma_Phan_He = N'he_thong';

    IF @IDPhanHeHeThong IS NULL
    BEGIN
        INSERT dbo.HT_Phan_He(IDCSKCB, Ma_Phan_He, Ten_Phan_He, Thu_Tu, Active)
        VALUES(@IDCSKCB, N'he_thong', N'Hệ thống', 3, 1);
        SET @IDPhanHeHeThong = SCOPE_IDENTITY();
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.HT_Chuc_Nang
        WHERE IDCSKCB = @IDCSKCB AND Ma_Chuc_Nang = N'he_thong_nhan_vien'
    )
    BEGIN
        INSERT dbo.HT_Chuc_Nang
        (
            IDCSKCB, ID_Phan_He, Ma_Chuc_Nang, Ten_Chuc_Nang,
            Duong_Dan, Thu_Tu, Active
        )
        VALUES
        (
            @IDCSKCB, @IDPhanHeHeThong, N'he_thong_nhan_vien', N'Nhân viên',
            N'/he_thong?tab=nhan_vien', 1, 1
        );
    END;

    /* Admin hiện hữu được cấp toàn quyền chức năng Nhân viên. */
    INSERT dbo.HT_Quyen_Vai_Tro
    (
        IDCSKCB, ID_Vai_Tro, ID_Chuc_Nang,
        Xem, Them, Sua, Xoa, Xuat, Ca_Nhan
    )
    SELECT
        @IDCSKCB, VT.ID, CN.ID,
        1,1,1,1,1,1
    FROM dbo.DM_Vai_Tro VT
    JOIN dbo.HT_Chuc_Nang CN
      ON CN.IDCSKCB = @IDCSKCB
     AND CN.Ma_Chuc_Nang = N'he_thong_nhan_vien'
     AND CN.Active = 1
    WHERE VT.IDCSKCB = @IDCSKCB
      AND VT.Ma_Vai_Tro = N'quan_tri_cskcb'
      AND VT.Active = 1
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.HT_Quyen_Vai_Tro Q
          WHERE Q.IDCSKCB = @IDCSKCB
            AND Q.ID_Vai_Tro = VT.ID
            AND Q.ID_Chuc_Nang = CN.ID
      );

    /* Vai trò mặc định: Tiếp nhận */
    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.DM_Vai_Tro
        WHERE IDCSKCB = @IDCSKCB AND Ma_Vai_Tro = N'tiep_nhan'
    )
    BEGIN
        INSERT dbo.DM_Vai_Tro(IDCSKCB, Ma_Vai_Tro, Ten_Vai_Tro, Mo_Ta, Active)
        VALUES(@IDCSKCB, N'tiep_nhan', N'Tiếp nhận', N'Tiếp nhận bệnh nhân và quản lý lượt tiếp nhận.', 1);
    END;

    /* Vai trò mặc định: Bác sĩ */
    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.DM_Vai_Tro
        WHERE IDCSKCB = @IDCSKCB AND Ma_Vai_Tro = N'bac_si'
    )
    BEGIN
        INSERT dbo.DM_Vai_Tro(IDCSKCB, Ma_Vai_Tro, Ten_Vai_Tro, Mo_Ta, Active)
        VALUES(@IDCSKCB, N'bac_si', N'Bác sĩ', N'Khám bệnh, xem phác đồ và sử dụng hỗ trợ kê toa.', 1);
    END;

    /* Vai trò mặc định: Thu ngân */
    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.DM_Vai_Tro
        WHERE IDCSKCB = @IDCSKCB AND Ma_Vai_Tro = N'thu_ngan'
    )
    BEGIN
        INSERT dbo.DM_Vai_Tro(IDCSKCB, Ma_Vai_Tro, Ten_Vai_Tro, Mo_Ta, Active)
        VALUES(@IDCSKCB, N'thu_ngan', N'Thu ngân', N'Thu tiền và hủy thu cho lượt khám đã hoàn tất.', 1);
    END;

    /* Vai trò mặc định: Kho */
    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.DM_Vai_Tro
        WHERE IDCSKCB = @IDCSKCB AND Ma_Vai_Tro = N'kho'
    )
    BEGIN
        INSERT dbo.DM_Vai_Tro(IDCSKCB, Ma_Vai_Tro, Ten_Vai_Tro, Mo_Ta, Active)
        VALUES(@IDCSKCB, N'kho', N'Quản lý kho', N'Quản lý tồn kho, nhập kho và phân nhóm thuốc.', 1);
    END;

    DECLARE @IDVaiTroTiepNhan BIGINT =
    (
        SELECT TOP 1 ID
        FROM dbo.DM_Vai_Tro
        WHERE IDCSKCB = @IDCSKCB AND Ma_Vai_Tro = N'tiep_nhan'
    );

    DECLARE @IDVaiTroBacSi BIGINT =
    (
        SELECT TOP 1 ID
        FROM dbo.DM_Vai_Tro
        WHERE IDCSKCB = @IDCSKCB AND Ma_Vai_Tro = N'bac_si'
    );

    DECLARE @IDVaiTroThuNgan BIGINT =
    (
        SELECT TOP 1 ID
        FROM dbo.DM_Vai_Tro
        WHERE IDCSKCB = @IDCSKCB AND Ma_Vai_Tro = N'thu_ngan'
    );

    DECLARE @IDVaiTroKho BIGINT =
    (
        SELECT TOP 1 ID
        FROM dbo.DM_Vai_Tro
        WHERE IDCSKCB = @IDCSKCB AND Ma_Vai_Tro = N'kho'
    );

    /* Tiếp nhận: toàn quyền trong phân hệ tiếp nhận. */
    INSERT dbo.HT_Quyen_Vai_Tro
    (
        IDCSKCB, ID_Vai_Tro, ID_Chuc_Nang,
        Xem, Them, Sua, Xoa, Xuat, Ca_Nhan
    )
    SELECT
        @IDCSKCB, @IDVaiTroTiepNhan, CN.ID,
        1,1,1,1,0,0
    FROM dbo.HT_Chuc_Nang CN
    WHERE CN.IDCSKCB = @IDCSKCB
      AND CN.Ma_Chuc_Nang = N'tiep_nhan'
      AND CN.Active = 1
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.HT_Quyen_Vai_Tro Q
          WHERE Q.IDCSKCB = @IDCSKCB
            AND Q.ID_Vai_Tro = @IDVaiTroTiepNhan
            AND Q.ID_Chuc_Nang = CN.ID
      );

    /* Bác sĩ: khám bệnh và xem phác đồ. DSS chỉ tồn tại ở Hieu_QLPM. */
    INSERT dbo.HT_Quyen_Vai_Tro
    (
        IDCSKCB, ID_Vai_Tro, ID_Chuc_Nang,
        Xem, Them, Sua, Xoa, Xuat, Ca_Nhan
    )
    SELECT
        @IDCSKCB, @IDVaiTroBacSi, CN.ID,
        1,
        CASE WHEN CN.Ma_Chuc_Nang = N'kham_benh' THEN 1 ELSE 0 END,
        CASE WHEN CN.Ma_Chuc_Nang = N'kham_benh' THEN 1 ELSE 0 END,
        0,0,1
    FROM dbo.HT_Chuc_Nang CN
    WHERE CN.IDCSKCB = @IDCSKCB
      AND CN.Ma_Chuc_Nang IN (N'kham_benh',N'phac_do')
      AND CN.Active = 1
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.HT_Quyen_Vai_Tro Q
          WHERE Q.IDCSKCB = @IDCSKCB
            AND Q.ID_Vai_Tro = @IDVaiTroBacSi
            AND Q.ID_Chuc_Nang = CN.ID
      );

    /* Thu ngân: xem và sửa nghiệp vụ thu ngân; không có quyền xóa dữ liệu gốc. */
    INSERT dbo.HT_Quyen_Vai_Tro
    (
        IDCSKCB, ID_Vai_Tro, ID_Chuc_Nang,
        Xem, Them, Sua, Xoa, Xuat, Ca_Nhan
    )
    SELECT @IDCSKCB,@IDVaiTroThuNgan,CN.ID,1,1,1,0,1,0
    FROM dbo.HT_Chuc_Nang CN
    WHERE CN.IDCSKCB=@IDCSKCB
      AND CN.Ma_Chuc_Nang=N'thu_ngan'
      AND CN.Active=1
      AND NOT EXISTS
      (
          SELECT 1 FROM dbo.HT_Quyen_Vai_Tro Q
          WHERE Q.IDCSKCB=@IDCSKCB
            AND Q.ID_Vai_Tro=@IDVaiTroThuNgan
            AND Q.ID_Chuc_Nang=CN.ID
      );

    /* Kho: xem và sửa nghiệp vụ kho. */
    INSERT dbo.HT_Quyen_Vai_Tro
    (
        IDCSKCB, ID_Vai_Tro, ID_Chuc_Nang,
        Xem, Them, Sua, Xoa, Xuat, Ca_Nhan
    )
    SELECT @IDCSKCB,@IDVaiTroKho,CN.ID,1,1,1,0,1,0
    FROM dbo.HT_Chuc_Nang CN
    WHERE CN.IDCSKCB=@IDCSKCB
      AND CN.Ma_Chuc_Nang=N'kho'
      AND CN.Active=1
      AND NOT EXISTS
      (
          SELECT 1 FROM dbo.HT_Quyen_Vai_Tro Q
          WHERE Q.IDCSKCB=@IDCSKCB
            AND Q.ID_Vai_Tro=@IDVaiTroKho
            AND Q.ID_Chuc_Nang=CN.ID
      );

    FETCH NEXT FROM cs INTO @IDCSKCB;
END;
CLOSE cs;
DEALLOCATE cs;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_Nhan_Vien_Danh_Sach
    @IDCSKCB BIGINT=NULL,
    @TuKhoa NVARCHAR(200)=NULL,
    @Trang INT=1,
    @KichThuocTrang INT=25
AS
BEGIN
    SET NOCOUNT ON;
    SET @TuKhoa=NULLIF(LTRIM(RTRIM(@TuKhoa)),N'');
    SET @Trang=CASE WHEN @Trang<1 THEN 1 ELSE @Trang END;
    SET @KichThuocTrang=CASE WHEN @KichThuocTrang<10 THEN 10 WHEN @KichThuocTrang>100 THEN 100 ELSE @KichThuocTrang END;

    ;WITH D AS
    (
        SELECT
            N.ID AS IDNhanVien,
            @IDCSKCB AS IDCSKCB,
            MAP.IDCSKCBs,
            MAP.TenCSKCB,
            N.MaNhanVien,
            N.HoTen,
            N.LaBacSi,
            N.IDChucDanh,
            CD.TenChucDanh AS ChucDanh,
            CD.VietTat AS VietTatChucDanh,
            N.DienThoai,
            N.SoNhaTenDuong,
            N.DiaChi,
            N.MaTinh,
            N.MaPhuongXa,
            N.Email,
            N.Active,
            CASE WHEN TK.ID IS NULL THEN CAST(0 AS BIT) ELSE CAST(1 AS BIT) END AS DaCoTaiKhoan,
            TK.Ten_Dang_Nhap
        FROM dbo.DM_NhanVien N
        LEFT JOIN dbo.DM_ChucDanh CD ON CD.ID=N.IDChucDanh
        CROSS APPLY
        (
            SELECT
                STRING_AGG(CONVERT(NVARCHAR(MAX),M.IDCSKCB),N',')
                    WITHIN GROUP (ORDER BY M.IDCSKCB) AS IDCSKCBs,
                STRING_AGG(CONVERT(NVARCHAR(MAX),C.TenCSKCB),N', ')
                    WITHIN GROUP (ORDER BY M.IDCSKCB) AS TenCSKCB
            FROM dbo.DM_NhanVien_CSKCB M
            INNER JOIN dbo.DM_CSKCB C ON C.ID=M.IDCSKCB
            WHERE M.IDNhanVien=N.ID AND M.Active=1
        ) MAP
        OUTER APPLY
        (
            SELECT TOP(1) T.ID,T.Ten_Dang_Nhap
            FROM dbo.HT_Tai_Khoan T
            WHERE T.IDNhanVien=N.ID
              AND T.LaQuanTriHeThong=0
              AND (@IDCSKCB IS NULL OR T.IDCSKCB=@IDCSKCB)
            ORDER BY CASE WHEN T.Active=1 THEN 0 ELSE 1 END,T.ID DESC
        ) TK
        WHERE
            (@IDCSKCB IS NULL OR EXISTS
            (
                SELECT 1 FROM dbo.DM_NhanVien_CSKCB M0
                WHERE M0.IDNhanVien=N.ID AND M0.IDCSKCB=@IDCSKCB AND M0.Active=1
            ))
            AND
            (
                @TuKhoa IS NULL
                OR N.MaNhanVien LIKE N'%'+@TuKhoa+N'%'
                OR N.HoTen LIKE N'%'+@TuKhoa+N'%'
                OR N.DienThoai LIKE N'%'+@TuKhoa+N'%'
                OR N.Email LIKE N'%'+@TuKhoa+N'%'
                OR ISNULL(CD.TenChucDanh,N'') LIKE N'%'+@TuKhoa+N'%'
                OR ISNULL(MAP.TenCSKCB,N'') LIKE N'%'+@TuKhoa+N'%'
            )
    )
    SELECT D.*,COUNT(*) OVER() AS TongSoDong
    FROM D
    ORDER BY D.IDNhanVien DESC
    OFFSET (@Trang-1)*@KichThuocTrang ROWS
    FETCH NEXT @KichThuocTrang ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_Nhan_Vien_Luu
    @IDCSKCB BIGINT,
    @IDNhanVien BIGINT=NULL,
    @MaNhanVien NVARCHAR(30),
    @HoTen NVARCHAR(200),
    @LaBacSi BIT=0,
    @IDChucDanh BIGINT=NULL,
    @CSKCBJson NVARCHAR(MAX)=N'[]',
    @DienThoai NVARCHAR(20)=NULL,
    @SoNhaTenDuong NVARCHAR(300)=NULL,
    @MaTinh NVARCHAR(20)=NULL,
    @MaPhuongXa NVARCHAR(20)=NULL,
    @Email NVARCHAR(200)=NULL,
    @Active BIT=1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        SET @MaNhanVien=NULLIF(LTRIM(RTRIM(@MaNhanVien)),N'');
        SET @HoTen=NULLIF(LTRIM(RTRIM(@HoTen)),N'');
        SET @DienThoai=NULLIF(LTRIM(RTRIM(@DienThoai)),N'');
        SET @SoNhaTenDuong=NULLIF(LTRIM(RTRIM(@SoNhaTenDuong)),N'');
        SET @MaTinh=NULLIF(LTRIM(RTRIM(@MaTinh)),N'');
        SET @MaPhuongXa=NULLIF(LTRIM(RTRIM(@MaPhuongXa)),N'');
        SET @Email=NULLIF(LTRIM(RTRIM(@Email)),N'');

        IF @IDCSKCB<=0 OR NOT EXISTS(SELECT 1 FROM dbo.DM_CSKCB WHERE ID=@IDCSKCB AND Active=1)
            THROW 51000,N'Cơ sở đang làm việc không hợp lệ.',1;
        IF @MaNhanVien IS NULL OR @HoTen IS NULL
            THROW 51000,N'Mã nhân viên và họ tên là bắt buộc.',1;
        IF @DienThoai IS NOT NULL AND (LEN(@DienThoai)>10 OR @DienThoai LIKE N'%[^0-9]%')
            THROW 51000,N'Số điện thoại chỉ được nhập số và tối đa 10 ký tự.',1;
        IF @IDChucDanh IS NOT NULL
           AND NOT EXISTS(SELECT 1 FROM dbo.DM_ChucDanh WHERE ID=@IDChucDanh AND Active=1)
            THROW 51000,N'Chức danh không tồn tại hoặc đã ngừng hoạt động.',1;
        IF ISJSON(ISNULL(@CSKCBJson,N''))<>1
            THROW 51000,N'Danh sách cơ sở làm việc không hợp lệ.',1;

        DECLARE @CS TABLE(IDCSKCB BIGINT PRIMARY KEY);
        INSERT @CS(IDCSKCB)
        SELECT DISTINCT TRY_CONVERT(BIGINT,[value])
        FROM OPENJSON(@CSKCBJson)
        WHERE TRY_CONVERT(BIGINT,[value])>0;

        IF NOT EXISTS(SELECT 1 FROM @CS WHERE IDCSKCB=@IDCSKCB)
            INSERT @CS(IDCSKCB) VALUES(@IDCSKCB);

        IF EXISTS
        (
            SELECT 1 FROM @CS X
            LEFT JOIN dbo.DM_CSKCB C ON C.ID=X.IDCSKCB AND C.Active=1
            WHERE C.ID IS NULL
        )
            THROW 51000,N'Danh sách cơ sở làm việc có cơ sở không tồn tại hoặc đã ngừng.',1;

        IF EXISTS
        (
            SELECT 1 FROM dbo.DM_NhanVien N
            WHERE N.MaNhanVien=@MaNhanVien
              AND (@IDNhanVien IS NULL OR N.ID<>@IDNhanVien)
        )
            THROW 51000,N'Mã nhân viên đã tồn tại ở hồ sơ khác.',1;

        DECLARE @TenChucDanh NVARCHAR(200)=NULL,
                @TenTinh NVARCHAR(200)=NULL,
                @TenPhuongXa NVARCHAR(200)=NULL,
                @DiaChi NVARCHAR(500)=NULL;

        IF @IDChucDanh IS NOT NULL
            SELECT @TenChucDanh=TenChucDanh FROM dbo.DM_ChucDanh WHERE ID=@IDChucDanh;

        IF @MaTinh IS NOT NULL
            SELECT TOP(1) @TenTinh=T.TenTinh
            FROM dbo.DM_TinhThanh T
            WHERE T.Active=1 AND T.MaTinh=@MaTinh
            ORDER BY CASE WHEN T.IDCSKCB=@IDCSKCB THEN 0 ELSE 1 END,T.ID;

        IF @MaPhuongXa IS NOT NULL
            SELECT TOP(1) @TenPhuongXa=P.TenPhuongXa
            FROM dbo.DM_PhuongXa P
            LEFT JOIN dbo.DM_TinhThanh T ON T.IDCSKCB=P.IDCSKCB AND T.ID=P.IDTinhThanh
            WHERE P.Active=1
              AND P.MaPhuongXa=@MaPhuongXa
              AND (@MaTinh IS NULL OR T.MaTinh=@MaTinh)
            ORDER BY CASE WHEN P.IDCSKCB=@IDCSKCB THEN 0 ELSE 1 END,P.ID;

        SET @DiaChi=NULLIF(CONCAT_WS(N', ',@SoNhaTenDuong,@TenPhuongXa,@TenTinh),N'');

        BEGIN TRAN;

        IF @IDNhanVien IS NULL OR @IDNhanVien<=0
        BEGIN
            INSERT dbo.DM_NhanVien
            (
                MaNhanVien,HoTen,LaBacSi,IDChucDanh,DienThoai,
                SoNhaTenDuong,DiaChi,MaTinh,MaPhuongXa,Email,Active
            )
            VALUES
            (
                @MaNhanVien,@HoTen,@LaBacSi,@IDChucDanh,@DienThoai,
                @SoNhaTenDuong,@DiaChi,@MaTinh,@MaPhuongXa,@Email,@Active
            );
            SET @IDNhanVien=SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            IF NOT EXISTS
            (
                SELECT 1
                FROM dbo.DM_NhanVien_CSKCB M
                WHERE M.IDNhanVien=@IDNhanVien AND M.IDCSKCB=@IDCSKCB AND M.Active=1
            )
                THROW 51000,N'Nhân viên không thuộc cơ sở đang quản lý.',1;

            UPDATE dbo.DM_NhanVien
            SET MaNhanVien=@MaNhanVien,
                HoTen=@HoTen,
                LaBacSi=@LaBacSi,
                IDChucDanh=@IDChucDanh,
                DienThoai=@DienThoai,
                SoNhaTenDuong=@SoNhaTenDuong,
                DiaChi=@DiaChi,
                MaTinh=@MaTinh,
                MaPhuongXa=@MaPhuongXa,
                Email=@Email,
                Active=@Active
            WHERE ID=@IDNhanVien;

            IF @@ROWCOUNT=0 THROW 51000,N'Không tìm thấy nhân viên.',1;
        END;

        UPDATE M
        SET Active=CASE WHEN X.IDCSKCB IS NULL THEN 0 ELSE 1 END
        FROM dbo.DM_NhanVien_CSKCB M
        LEFT JOIN @CS X ON X.IDCSKCB=M.IDCSKCB
        WHERE M.IDNhanVien=@IDNhanVien;

        UPDATE M
        SET Active=1
        FROM dbo.DM_NhanVien_CSKCB M
        INNER JOIN @CS X ON X.IDCSKCB=M.IDCSKCB
        WHERE M.IDNhanVien=@IDNhanVien;

        INSERT dbo.DM_NhanVien_CSKCB(IDNhanVien,IDCSKCB,Active)
        SELECT @IDNhanVien,X.IDCSKCB,1
        FROM @CS X
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.DM_NhanVien_CSKCB M
            WHERE M.IDNhanVien=@IDNhanVien AND M.IDCSKCB=X.IDCSKCB
        );

        COMMIT;
        SELECT 200 AS Status,N'Lưu nhân viên và cơ sở làm việc thành công.' AS Message,@IDNhanVien AS IDNhanVien;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 400 AS Status,ERROR_MESSAGE() AS Message,@IDNhanVien AS IDNhanVien;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_Nhan_Vien_Xoa
    @IDCSKCB BIGINT,
    @IDNhanVien BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.DM_NhanVien_CSKCB
        WHERE IDNhanVien=@IDNhanVien AND IDCSKCB=@IDCSKCB AND Active=1
    )
    BEGIN
        SELECT 404 AS Status,N'Nhân viên không thuộc cơ sở này.' AS Message;
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRAN;

        DELETE TV
        FROM dbo.HT_Tai_Khoan_Vai_Tro TV
        INNER JOIN dbo.HT_Tai_Khoan T
          ON T.IDCSKCB=TV.IDCSKCB AND T.ID=TV.ID_Tai_Khoan
        WHERE T.IDCSKCB=@IDCSKCB AND T.IDNhanVien=@IDNhanVien;

        DELETE dbo.HT_Tai_Khoan
        WHERE IDCSKCB=@IDCSKCB AND IDNhanVien=@IDNhanVien AND LaQuanTriHeThong=0;

        UPDATE dbo.DM_NhanVien_CSKCB
        SET Active=0
        WHERE IDNhanVien=@IDNhanVien AND IDCSKCB=@IDCSKCB;

        IF NOT EXISTS
        (
            SELECT 1 FROM dbo.DM_NhanVien_CSKCB
            WHERE IDNhanVien=@IDNhanVien AND Active=1
        )
            UPDATE dbo.DM_NhanVien SET Active=0 WHERE ID=@IDNhanVien;

        COMMIT;
        SELECT 200 AS Status,N'Đã gỡ nhân viên khỏi cơ sở. Dữ liệu khám lịch sử được giữ nguyên.' AS Message;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 500 AS Status,ERROR_MESSAGE() AS Message;
    END CATCH
END;
GO

SELECT N'30_phan_quyen_bs_tiep_nhan_va_quan_ly_nhan_vien.sql hoàn tất.' AS Message;
GO
