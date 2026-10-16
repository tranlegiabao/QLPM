/* v95 nối tiếp v94. Chạy sau 28/29; không chạy tự động trên DB chưa được duyệt.
   Không suy đoán quy đổi lịch sử. Hoàn kho luôn định danh dòng xuất, lượng cơ sở.
   Không có thao tác tài chính nào tự tăng tồn. */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_DongDaCap
    @IDCSKCB BIGINT, @IDVaoVien BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CT.ID AS id_xuat_ct, X.ID AS id_xuat, X.SoPhieu AS so_phieu,
           X.NgayXuat AS ngay_xuat, CT.IDToaThuocCT AS id_toa_thuoc_ct,
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


/* Liên kết nguồn thu và quy đổi lúc cấp. NULL chỉ dành cho lịch sử không chứng minh được. */
IF COL_LENGTH(N'dbo.QL_Kho_Xuat_CT',N'IDThuTienChungTuCT') IS NULL
    ALTER TABLE dbo.QL_Kho_Xuat_CT ADD IDThuTienChungTuCT BIGINT NULL,HeSoQuyDoi DECIMAL(18,6) NULL;
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name=N'FK_QL_Kho_Xuat_CT_ChungTuThu')
    ALTER TABLE dbo.QL_Kho_Xuat_CT WITH CHECK ADD CONSTRAINT FK_QL_Kho_Xuat_CT_ChungTuThu
    FOREIGN KEY(IDThuTienChungTuCT) REFERENCES dbo.QL_ThuTien_ChungTu_CT(ID);
GO
/* Chỉ backfill khi đúng một ứng viên tại thời điểm cấp. Không lấy quy đổi danh mục hiện tại. */
;WITH Nguon AS
(
    SELECT X.ID,MIN(D.ID) IDNguon,COUNT_BIG(*) SoNguon
    FROM dbo.QL_Kho_Xuat_CT X
    INNER JOIN dbo.QL_Kho_Xuat H ON H.IDCSKCB=X.IDCSKCB AND H.ID=X.IDXuat
    INNER JOIN dbo.QL_ThuTien_CT P ON P.IDCSKCB=X.IDCSKCB AND P.IDToaThuocCT=X.IDToaThuocCT
    INNER JOIN dbo.QL_ThuTien_ChungTu_CT D ON D.IDThuTienCT=P.ID AND D.Loai=N'THUOC'
    INNER JOIN dbo.QL_ThuTien_ChungTu C ON C.ID=D.IDChungTu AND C.IDCSKCB=X.IDCSKCB
      AND C.IDVaoVien=H.IDVaoVien AND C.Loai='THU' AND C.NgayGio<=H.NgayXuat
    WHERE X.IDThuTienChungTuCT IS NULL GROUP BY X.ID
)
UPDATE X SET IDThuTienChungTuCT=N.IDNguon FROM dbo.QL_Kho_Xuat_CT X
INNER JOIN Nguon N ON N.ID=X.ID AND N.SoNguon=1;
GO
/* WORKLIST_ELIGIBILITY_V95 */
/* Queue/chi tiết cấp phát phải dùng cùng điều kiện đầu với STO xuất:
   - lượt đã Khám xong;
   - dòng toa active;
   - dòng tiền DaThu=1;
   - có chứng từ THU thuốc đang hiệu lực và chưa bị hoàn.
   Không dùng riêng cờ DaThu làm bằng chứng đủ điều kiện cấp phát. */
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

CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_Xuat_TheoToa
    @IDCSKCB BIGINT,
    @IDKho BIGINT,
    @IDVaoVien BIGINT,
    @IDNhanVienXuat BIGINT,
    @DanhSachJson NVARCHAR(MAX),
    @GhiChu NVARCHAR(500)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS(SELECT 1 FROM dbo.DM_Kho WHERE IDCSKCB=@IDCSKCB AND ID=@IDKho AND Active=1)
            THROW 58200,N'Kho không hợp lệ.',1;
        IF @IDNhanVienXuat<=0
            THROW 58200,N'Không xác định được nhân viên xuất kho.',1;
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

        INSERT dbo.QL_Kho_Xuat(IDCSKCB,IDKho,IDVaoVien,SoPhieu,NgayXuat,IDNhanVienXuat,TongGiaVon,GhiChu,DaHuy)
        VALUES(@IDCSKCB,@IDKho,@IDVaoVien,@SoPhieu,SYSDATETIME(),@IDNhanVienXuat,0,NULLIF(LTRIM(RTRIM(@GhiChu)),N''),0);

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
            SELECT 1 FROM dbo.QL_Kho_Xuat_CT X WITH(UPDLOCK,HOLDLOCK)
            INNER JOIN dbo.QL_Kho_Xuat H ON H.IDCSKCB=X.IDCSKCB AND H.ID=X.IDXuat
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


IF COL_LENGTH(N'dbo.QL_Kho_Nhap_CT',N'TenThuocSnapshot') IS NULL
    ALTER TABLE dbo.QL_Kho_Nhap_CT ADD TenThuocSnapshot NVARCHAR(500) NULL,MaThuocSnapshot NVARCHAR(50) NULL,DonViTinhSnapshot NVARCHAR(100) NULL;
GO
IF COL_LENGTH(N'dbo.QL_Kho_Nhap',N'TenNhaCungCapSnapshot') IS NULL
    ALTER TABLE dbo.QL_Kho_Nhap ADD TenNhaCungCapSnapshot NVARCHAR(500) NULL;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_Nhap
    @IDCSKCB BIGINT,
    @IDKho BIGINT,
    @IDNhanVienNhap BIGINT,
    @IDNhaCungCap BIGINT=NULL,
    @SoHoaDon NVARCHAR(100)=NULL,
    @NgayHoaDon DATE=NULL,
    @GhiChu NVARCHAR(500)=NULL,
    @DanhSachJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS(SELECT 1 FROM dbo.DM_Kho WHERE IDCSKCB=@IDCSKCB AND ID=@IDKho AND Active=1)
            THROW 58100,N'Kho không hợp lệ.',1;
        IF @IDNhanVienNhap<=0
            THROW 58100,N'Không xác định được nhân viên nhập kho.',1;
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

        INSERT dbo.QL_Kho_Nhap(IDCSKCB,IDKho,SoPhieu,SoHoaDon,NgayHoaDon,IDNhaCungCap,NgayNhap,IDNhanVienNhap,TongTien,GhiChu,DaHuy)
        SELECT @IDCSKCB,@IDKho,@SoPhieu,NULLIF(LTRIM(RTRIM(@SoHoaDon)),N''),@NgayHoaDon,@IDNhaCungCap,SYSDATETIME(),@IDNhanVienNhap,
               SUM(SoLuong*GiaNhap),NULLIF(LTRIM(RTRIM(@GhiChu)),N''),0
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

CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_Nhap_ChiTiet @IDCSKCB BIGINT,@IDNhap BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT N.ID AS id,N.SoPhieu AS so_phieu,N.NgayNhap AS ngay_nhap,N.SoHoaDon AS so_hoa_don,N.NgayHoaDon AS ngay_hoa_don,
           COALESCE(N.TenNhaCungCapSnapshot,NCC.TenNhaCungCap) AS nha_cung_cap,CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.QL_Kho_Nhap_CT D WHERE D.IDCSKCB=N.IDCSKCB AND D.IDNhap=N.ID AND D.TenThuocSnapshot IS NULL)
                     OR (N.IDNhaCungCap IS NOT NULL AND N.TenNhaCungCapSnapshot IS NULL) THEN 1 ELSE 0 END AS BIT) AS la_legacy,
           N.TongTien AS tong_tien,N.GhiChu AS ghi_chu,N.DaHuy AS da_huy,N.LyDoHuy AS ly_do_huy,
           N.NgayGioHuy AS ngay_gio_huy,COALESCE(NV.HoTen,N'') AS nguoi_nhap,COALESCE(NVH.HoTen,N'') AS nguoi_huy
    FROM dbo.QL_Kho_Nhap N LEFT JOIN dbo.DM_NhaCungCap NCC ON NCC.IDCSKCB=N.IDCSKCB AND NCC.ID=N.IDNhaCungCap
    LEFT JOIN dbo.DM_NhanVien NV ON NV.ID=N.IDNhanVienNhap LEFT JOIN dbo.DM_NhanVien NVH ON NVH.ID=N.IDNhanVienHuy
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
