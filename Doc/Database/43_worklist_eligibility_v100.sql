/*
QLPM v100 - final worklist eligibility overlay.
Muc tieu: chot cac STO danh sach nghiep vu SAU tat ca migration/override cu.
Khong tao bang, khong sua du lieu.
*/
USE [QLPM];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;
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

CREATE OR ALTER PROCEDURE dbo.STO_QL_ThuNgan_DanhSach
    @IDCSKCB BIGINT,
    @TuNgay DATE=NULL,
    @DenNgay DATE=NULL,
    @TrangThai TINYINT=NULL,
    @TuKhoa NVARCHAR(200)=NULL,
    @Trang INT=1,
    @KichThuocTrang INT=25
AS
BEGIN
    SET NOCOUNT ON;

    SET @TuKhoa=NULLIF(LTRIM(RTRIM(@TuKhoa)),N'');
    SET @TuNgay=COALESCE(@TuNgay,CONVERT(DATE,SYSDATETIME()));
    SET @DenNgay=COALESCE(@DenNgay,@TuNgay);
    IF @DenNgay<@TuNgay
    BEGIN
        DECLARE @Tmp DATE=@TuNgay;
        SET @TuNgay=@DenNgay;
        SET @DenNgay=@Tmp;
    END;

    IF @TrangThai NOT IN(0,1) SET @TrangThai=NULL;
    SET @Trang=CASE WHEN @Trang<1 THEN 1 ELSE @Trang END;
    SET @KichThuocTrang=CASE
        WHEN @KichThuocTrang<10 THEN 10
        WHEN @KichThuocTrang>100 THEN 100
        ELSE @KichThuocTrang
    END;

    ;WITH D AS
    (
        SELECT
            V.ID AS id_vao_vien,
            V.TrangThaiKham AS trang_thai_kham,
            V.MaVaoVien AS ma_vao_vien,
            V.SoThuTu AS so_thu_tu,
            V.NgayGioVaoVien AS ngay_gio_vao_vien,
            V.KetThucKhamLuc AS ket_thuc_kham_luc,
            B.ID AS id_benh_nhan,
            B.MaBN AS ma_bn,
            B.HoTen AS ho_ten,
            B.NgaySinh AS ngay_sinh,
            GT.TenGioiTinh AS gioi_tinh,
            B.DienThoai AS dien_thoai,
            B.SoCCCD AS so_cccd,
            B.DiaChi AS dia_chi,
            BS.HoTen AS bac_si,
            T.ID AS id_thu_tien,
            T.SoPhieu AS so_phieu,
            T.NgayGioThu AS ngay_gio_thu,
            ISNULL(X.TongTien,0) AS tong_tien,
            ISNULL(X.TienGiam,0) AS tien_giam,
            ISNULL(X.DaThuTien,0) AS da_thu,
            ISNULL(S.SoDaThu,0) AS so_dong_da_thu,
            CASE
                WHEN ISNULL(S.SoDaThu,0)>0 AND ISNULL(S.SoChuaThu,0)=0 THEN CAST(1 AS TINYINT)
                ELSE CAST(0 AS TINYINT)
            END AS trang_thai_thu
        FROM dbo.QL_VaoVien V
        INNER JOIN dbo.QL_BenhNhan B
            ON B.IDCSKCB=V.IDCSKCB AND B.ID=V.IDBenhNhan
        LEFT JOIN dbo.DM_GioiTinh GT ON GT.ID=B.IDGioiTinh
        LEFT JOIN dbo.DM_NhanVien BS ON BS.ID=V.IDBacSiKham
        LEFT JOIN dbo.QL_ThuTien T
            ON T.IDCSKCB=V.IDCSKCB AND T.IDVaoVien=V.ID
        OUTER APPLY
        (
            SELECT
                SUM(CASE WHEN 1=1
                         THEN ROUND(ISNULL(CT.ThanhTien,0),0)+ROUND(ISNULL(CT.PhuThu,0),0) ELSE 0 END) AS TongTien,
                SUM(CASE WHEN 1=1
                         THEN ROUND(ISNULL(CT.TienGiam,0),0) ELSE 0 END) AS TienGiam,
                SUM(CASE WHEN ISNULL(CT.DaThu,0)=1
                         THEN ROUND(ISNULL(CT.ThucThu,0),0) ELSE 0 END) AS DaThuTien
            FROM dbo.QL_ThuTien_CT CT
            WHERE CT.IDCSKCB=V.IDCSKCB
              AND CT.IDThuTien=T.ID
              AND EXISTS(SELECT 1 FROM dbo.FN_QL_ThuTien_DongCoTheThu(V.IDCSKCB,V.ID) E WHERE E.ID=CT.ID AND (E.CoTheThu=1 OR CT.DaThu=1))
        ) X
        OUTER APPLY
        (
            SELECT
                SUM(CASE WHEN ISNULL(CT.DaThu,0)=1 THEN 1 ELSE 0 END) AS SoDaThu,
                SUM(CASE WHEN ISNULL(CT.DaThu,0)=0 THEN 1 ELSE 0 END) AS SoChuaThu
            FROM dbo.QL_ThuTien_CT CT
            WHERE CT.IDCSKCB=V.IDCSKCB
              AND CT.IDThuTien=T.ID
              AND EXISTS(SELECT 1 FROM dbo.FN_QL_ThuTien_DongCoTheThu(V.IDCSKCB,V.ID) E WHERE E.ID=CT.ID AND (E.CoTheThu=1 OR CT.DaThu=1))
        ) S
        WHERE V.IDCSKCB=@IDCSKCB
          AND V.Active=1
          AND V.DaChuyenKham=1
          AND V.TrangThaiKham IN(0,1,2)
          AND EXISTS
          (
              SELECT 1
              FROM dbo.QL_ThuTien_CT CT0
              INNER JOIN dbo.FN_QL_ThuTien_DongCoTheThu(V.IDCSKCB,V.ID) E0 ON E0.ID=CT0.ID
              WHERE CT0.IDCSKCB=V.IDCSKCB
                AND CT0.IDThuTien=T.ID
                AND (E0.CoTheThu=1 OR ISNULL(CT0.DaThu,0)=1)
          )
          AND
          (
              @TuKhoa IS NOT NULL
              OR (V.Ngay>=@TuNgay AND V.Ngay<=@DenNgay)
          )
          AND
          (
              @TuKhoa IS NULL
              OR B.MaBN LIKE N'%'+@TuKhoa+N'%'
              OR B.HoTen LIKE N'%'+@TuKhoa+N'%'
              OR ISNULL(B.DienThoai,N'') LIKE N'%'+@TuKhoa+N'%'
              OR ISNULL(B.SoCCCD,N'') LIKE N'%'+@TuKhoa+N'%'
              OR V.MaVaoVien LIKE N'%'+@TuKhoa+N'%'
              OR ISNULL(T.SoPhieu,N'') LIKE N'%'+@TuKhoa+N'%'
          )
    ),
    F AS
    (
        SELECT *
        FROM D
        WHERE @TrangThai IS NULL OR trang_thai_thu=@TrangThai
    )
    SELECT
        F.*,
        CASE WHEN tong_tien-tien_giam<0 THEN 0 ELSE tong_tien-tien_giam END AS phai_thu,
        COUNT(*) OVER() AS tong_so
    FROM F
    ORDER BY
        CASE trang_thai_thu WHEN 0 THEN 0 ELSE 1 END,
        COALESCE(ket_thuc_kham_luc,ngay_gio_vao_vien) DESC,
        id_vao_vien DESC
    OFFSET (@Trang-1)*@KichThuocTrang ROWS
    FETCH NEXT @KichThuocTrang ROWS ONLY;
END;
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

CREATE OR ALTER PROCEDURE dbo.STO_QL_ThuNgan_ChiTiet
    @IDCSKCB BIGINT,
    @IDVaoVien BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IDThuTien BIGINT=
    (
        SELECT T.ID
        FROM dbo.QL_ThuTien T
        WHERE T.IDCSKCB=@IDCSKCB AND T.IDVaoVien=@IDVaoVien
    );

    SELECT
        V.ID AS id_vao_vien,
        V.TrangThaiKham AS trang_thai_kham,
        V.MaVaoVien AS ma_vao_vien,
        V.NgayGioVaoVien AS ngay_gio_vao_vien,
        V.KetThucKhamLuc AS ket_thuc_kham_luc,
        B.ID AS id_benh_nhan,
        B.MaBN AS ma_bn,
        B.HoTen AS ho_ten,
        B.NgaySinh AS ngay_sinh,
        GT.TenGioiTinh AS gioi_tinh,
        B.DienThoai AS dien_thoai,
        B.SoCCCD AS so_cccd,
        B.DiaChi AS dia_chi,
        BS.HoTen AS bac_si,
        T.ID AS id_thu_tien,
        T.SoPhieu AS so_phieu,
        T.NgayGioThu AS ngay_gio_thu,
        COALESCE(NVThu.HoTen,TKThu.Ten_Dang_Nhap,N'') AS nhan_vien_thu,
        ISNULL(T.TienMat,0) AS tien_mat,
        ISNULL(T.ChuyenKhoan,0) AS chuyen_khoan,
        T.IDNganHang AS id_ngan_hang,
        NH.TenNganHang AS ten_ngan_hang,
        T.GhiChu AS ghi_chu,
        ISNULL(X.TongTien,0) AS tong_tien,
        ISNULL(X.TienGiam,0) AS tien_giam,
        ISNULL(X.TongThanhToan,0) AS tong_thanh_toan,
        CAST(0 AS DECIMAL(18,2)) AS so_du_tam_ung,
        CASE
            WHEN ISNULL(S.SoDaThu,0)>0 AND ISNULL(S.SoChuaThu,0)=0 THEN CAST(1 AS TINYINT)
            ELSE CAST(0 AS TINYINT)
        END AS trang_thai_thu,
        ISNULL(X.DaThuTien,0) AS da_thu
    FROM dbo.QL_VaoVien V
    INNER JOIN dbo.QL_BenhNhan B
        ON B.IDCSKCB=V.IDCSKCB AND B.ID=V.IDBenhNhan
    LEFT JOIN dbo.DM_GioiTinh GT ON GT.ID=B.IDGioiTinh
    LEFT JOIN dbo.DM_NhanVien BS ON BS.ID=V.IDBacSiKham
    LEFT JOIN dbo.QL_ThuTien T
        ON T.IDCSKCB=V.IDCSKCB AND T.IDVaoVien=V.ID
    LEFT JOIN dbo.DM_NhanVien NVThu ON NVThu.ID=T.IDNhanVienThu
    LEFT JOIN dbo.HT_Tai_Khoan TKThu ON TKThu.ID=T.IDTaiKhoanThu
    LEFT JOIN dbo.DM_NganHang NH ON NH.ID=T.IDNganHang
    OUTER APPLY
    (
        SELECT
            SUM(CASE WHEN ISNULL(CT.DaThu,0)=1
                     THEN ROUND(ISNULL(CT.ThanhTien,0),0)+ROUND(ISNULL(CT.PhuThu,0),0) ELSE 0 END) AS TongTien,
            SUM(CASE WHEN ISNULL(CT.DaThu,0)=1
                     THEN ROUND(ISNULL(CT.TienGiam,0),0) ELSE 0 END) AS TienGiam,
            SUM(CASE WHEN ISNULL(CT.DaThu,0)=1
                     THEN ROUND(ISNULL(CT.ThucThu,0),0) ELSE 0 END) AS TongThanhToan,
            SUM(CASE WHEN ISNULL(CT.DaThu,0)=1
                     THEN ROUND(ISNULL(CT.ThucThu,0),0) ELSE 0 END) AS DaThuTien
        FROM dbo.QL_ThuTien_CT CT
        WHERE CT.IDCSKCB=V.IDCSKCB
          AND CT.IDThuTien=T.ID
          AND EXISTS(SELECT 1 FROM dbo.FN_QL_ThuTien_DongCoTheThu(V.IDCSKCB,V.ID) E WHERE E.ID=CT.ID AND (E.CoTheThu=1 OR CT.DaThu=1))
    ) X
    OUTER APPLY
    (
        SELECT
            SUM(CASE WHEN ISNULL(CT.DaThu,0)=1 THEN 1 ELSE 0 END) AS SoDaThu,
            SUM(CASE WHEN ISNULL(CT.DaThu,0)=0 THEN 1 ELSE 0 END) AS SoChuaThu
        FROM dbo.QL_ThuTien_CT CT
        WHERE CT.IDCSKCB=V.IDCSKCB
          AND CT.IDThuTien=T.ID
          AND EXISTS(SELECT 1 FROM dbo.FN_QL_ThuTien_DongCoTheThu(V.IDCSKCB,V.ID) E WHERE E.ID=CT.ID AND (E.CoTheThu=1 OR CT.DaThu=1))
    ) S
    WHERE V.IDCSKCB=@IDCSKCB
      AND V.ID=@IDVaoVien
      AND V.Active=1
      AND V.DaChuyenKham=1
      AND V.TrangThaiKham IN(0,1,2);

    SELECT
        CT.ID AS id,
        E.CoTheThu AS co_the_thu,
        CASE
            WHEN CT.IDCongKhamCT IS NOT NULL THEN N'CONG_KHAM'
            WHEN CT.IDChiDinhCT IS NOT NULL THEN N'CLS'
            WHEN CT.IDToaThuocCT IS NOT NULL THEN N'THUOC'
            ELSE N'KHAC'
        END AS loai,
        CASE
            WHEN CT.IDCongKhamCT IS NOT NULL THEN 1
            WHEN CT.IDChiDinhCT IS NOT NULL THEN 2
            WHEN CT.IDToaThuocCT IS NOT NULL THEN 3
            ELSE 9
        END AS thu_tu_loai,
        COALESCE(DVCK.MaDichVu,DVCD.MaDichVu,TH.MaThuoc,N'') AS ma,
        COALESCE(DVCK.TenDichVu,DVCD.TenDichVu,TH.TenThuoc,N'Khoản thu') AS ten,
        COALESCE(DVTThuoc.TenDVT,DVCK.DonViTinh,DVCD.DonViTinh,TH.DonViTinh,N'') AS don_vi_tinh,
        CT.SoLuong AS so_luong,
        ROUND(CT.DonGia,0) AS don_gia,
        ROUND(CT.ThanhTien,0) AS thanh_tien,
        ROUND(ISNULL(CT.PhuThu,0),0) AS phu_thu,
        ISNULL(CT.GiamPhanTram,0) AS giam_phan_tram,
        ROUND(ISNULL(CT.TienGiam,0),0) AS tien_giam,
        ROUND(ISNULL(CT.ThucThu,0),0) AS thanh_toan,
        ISNULL(CT.DaThu,0) AS da_thu,
        ISNULL(CT.DaHuy,0) AS da_huy,
        CT.NgayGioHuy AS ngay_gio_huy,
        CASE WHEN CD.GuiNgoai=1 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS gui_ngoai,
        CD.NoiGuiNgoai AS noi_gui_ngoai,
        COALESCE(CK.GhiChu,CD.GhiChu,TT.CachDung,N'') AS ghi_chu
    FROM dbo.QL_ThuTien_CT CT
    INNER JOIN dbo.FN_QL_ThuTien_DongCoTheThu(@IDCSKCB,@IDVaoVien) E ON E.ID=CT.ID
    LEFT JOIN dbo.QL_CongKham_CT CK
        ON CK.IDCSKCB=CT.IDCSKCB AND CK.ID=CT.IDCongKhamCT
    LEFT JOIN dbo.DM_DichVu DVCK
        ON DVCK.IDCSKCB=CK.IDCSKCB AND DVCK.ID=CK.IDDichVu
    LEFT JOIN dbo.QL_ChiDinh_CT CD
        ON CD.IDCSKCB=CT.IDCSKCB AND CD.ID=CT.IDChiDinhCT
    LEFT JOIN dbo.DM_DichVu DVCD
        ON DVCD.IDCSKCB=CD.IDCSKCB AND DVCD.ID=CD.IDDichVu
    LEFT JOIN dbo.QL_ToaThuoc_CT TT
        ON TT.IDCSKCB=CT.IDCSKCB AND TT.ID=CT.IDToaThuocCT
    LEFT JOIN dbo.DM_Thuoc TH
        ON TH.IDCSKCB=TT.IDCSKCB AND TH.ID=TT.IDThuoc
    LEFT JOIN dbo.DM_DonViTinh DVTThuoc
        ON DVTThuoc.IDCSKCB=TT.IDCSKCB AND DVTThuoc.ID=TT.IDDonViTinhDung
    WHERE CT.IDCSKCB=@IDCSKCB
      AND CT.IDThuTien=@IDThuTien
      /* Chi tiết trả cả dòng chưa thu và đã thu.
         UI tự lọc theo radio Chưa thu / Đã thu / Tất cả.
         DaThu=1 luôn ở chế độ chỉ đọc; thao tác thu vẫn được STO_QL_ThuNgan_ThuTien chặn server-side. */
      AND (CK.Active=1 OR CD.Active=1 OR TT.Active=1)
    ORDER BY
        CASE
            WHEN CT.IDCongKhamCT IS NOT NULL THEN 1
            WHEN CT.IDChiDinhCT IS NOT NULL THEN 2
            WHEN CT.IDToaThuocCT IS NOT NULL THEN 3
            ELSE 9
        END,
        CT.ID;
END;
GO

PRINT N'43_worklist_eligibility_v100.sql: OK';
GO
