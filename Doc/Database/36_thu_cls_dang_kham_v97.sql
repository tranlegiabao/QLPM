/* v97: CLS nội bộ được thu khi Đang khám; không mở thuốc/công khám trước Khám xong.
   Override nối tiếp v94-v96, không sửa snapshot/chứng từ hoặc backfill dữ liệu.
   Chỉ triển khai sau xác nhận server/database + backup. Cutover DB và app đồng thời.
   Thứ tự khóa của các write: QL_VaoVien -> QL_ThuTien -> nguồn -> dòng thu.
*/
SET XACT_ABORT ON;
GO
IF OBJECT_ID(N'dbo.QL_ThuTien_ChungTu_CT',N'U') IS NULL
 OR COL_LENGTH(N'dbo.QL_Kho_Xuat',N'IDTaiKhoanXuat') IS NULL
    THROW 59700,N'Yêu cầu schema thu ngân/kho v96 trước v97.',1;
GO

/* Một nguồn điều kiện thu chung cho danh sách, chi tiết và lệnh thu. Không dựa
   vào DaThu tổng hợp (có thể cũ sau khi bác sĩ thêm chỉ định). */
CREATE OR ALTER FUNCTION dbo.FN_QL_ThuTien_DongCoTheThu(@IDCSKCB BIGINT,@IDVaoVien BIGINT)
RETURNS TABLE
AS RETURN
(
    SELECT CT.ID,
        CAST(CASE WHEN V.Active=1 AND V.DaChuyenKham=1
            AND (
                (CK.Active=1 AND V.TrangThaiKham IN(0,1,2))
                OR (CD.Active=1 AND ISNULL(CD.GuiNgoai,0)=0 AND V.TrangThaiKham IN(1,2))
                OR (TT.Active=1 AND V.TrangThaiKham=2)
            ) THEN 1 ELSE 0 END AS BIT) AS CoTheThu,
        CAST(CASE WHEN CT.DaThu=1 OR EXISTS
            (SELECT 1 FROM dbo.QL_ThuTien_ChungTu_CT H WHERE H.IDThuTienCT=CT.ID)
            THEN 1 ELSE 0 END AS BIT) AS KhoaNghiepVu
    FROM dbo.QL_ThuTien_CT CT
    INNER JOIN dbo.QL_ThuTien T ON T.IDCSKCB=CT.IDCSKCB AND T.ID=CT.IDThuTien
    INNER JOIN dbo.QL_VaoVien V ON V.IDCSKCB=T.IDCSKCB AND V.ID=T.IDVaoVien
    LEFT JOIN dbo.QL_ChiDinh_CT CD ON CD.IDCSKCB=CT.IDCSKCB AND CD.ID=CT.IDChiDinhCT AND CD.IDVaoVien=V.ID
    LEFT JOIN dbo.QL_CongKham CKH ON CKH.IDCSKCB=CT.IDCSKCB AND CKH.IDVaoVien=V.ID
    LEFT JOIN dbo.QL_CongKham_CT CK ON CK.IDCSKCB=CT.IDCSKCB AND CK.ID=CT.IDCongKhamCT AND CK.IDCongKham=CKH.ID
    LEFT JOIN dbo.QL_ToaThuoc_CT TT ON TT.IDCSKCB=CT.IDCSKCB AND TT.ID=CT.IDToaThuocCT AND TT.IDVaoVien=V.ID
    WHERE CT.IDCSKCB=@IDCSKCB AND T.IDVaoVien=@IDVaoVien
);
GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_ThuTien_CapNhatTong
    @IDCSKCB BIGINT,
    @IDVaoVien BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE CT
    SET PhuThu=ROUND(ISNULL(CT.PhuThu,0),0),
        GiamPhanTram=CASE
            WHEN ISNULL(CT.GiamPhanTram,0)<0 THEN 0
            WHEN ISNULL(CT.GiamPhanTram,0)>100 THEN 100
            ELSE ISNULL(CT.GiamPhanTram,0)
        END,
        TienGiam=ROUND(
            (ROUND(ISNULL(CT.ThanhTien,0),0)+ROUND(ISNULL(CT.PhuThu,0),0))
            * CASE
                WHEN ISNULL(CT.GiamPhanTram,0)<0 THEN 0
                WHEN ISNULL(CT.GiamPhanTram,0)>100 THEN 100
                ELSE ISNULL(CT.GiamPhanTram,0)
              END / 100.0,
            0
        ),
        ThucThu=
            (ROUND(ISNULL(CT.ThanhTien,0),0)+ROUND(ISNULL(CT.PhuThu,0),0))
            - ROUND(
                (ROUND(ISNULL(CT.ThanhTien,0),0)+ROUND(ISNULL(CT.PhuThu,0),0))
                * CASE
                    WHEN ISNULL(CT.GiamPhanTram,0)<0 THEN 0
                    WHEN ISNULL(CT.GiamPhanTram,0)>100 THEN 100
                    ELSE ISNULL(CT.GiamPhanTram,0)
                  END / 100.0,
                0
              )
    FROM dbo.QL_ThuTien_CT CT
    INNER JOIN dbo.QL_ThuTien T
      ON T.IDCSKCB=CT.IDCSKCB AND T.ID=CT.IDThuTien
    WHERE T.IDCSKCB=@IDCSKCB AND T.IDVaoVien=@IDVaoVien
      AND ISNULL(CT.DaThu,0)=0
      AND NOT EXISTS(SELECT 1 FROM dbo.QL_ThuTien_ChungTu_CT H WHERE H.IDThuTienCT=CT.ID);

    UPDATE T
    SET TongTien=X.Tong,
        TienGiam=X.Giam,
        ThucThu=X.Thuc,
        DaThu=CASE WHEN EXISTS(SELECT 1 FROM dbo.QL_ThuTien_CT C WHERE C.IDCSKCB=@IDCSKCB AND C.IDThuTien=T.ID AND C.DaThu=1)
            AND NOT EXISTS(SELECT 1 FROM dbo.QL_ThuTien_CT C INNER JOIN dbo.FN_QL_ThuTien_DongCoTheThu(@IDCSKCB,@IDVaoVien) E ON E.ID=C.ID
                WHERE C.IDCSKCB=@IDCSKCB AND C.IDThuTien=T.ID AND ISNULL(C.DaThu,0)=0 AND E.CoTheThu=1)
            THEN 1 ELSE 0 END
    FROM dbo.QL_ThuTien T
    CROSS APPLY
    (
        SELECT
            ISNULL(SUM(ROUND(ISNULL(ThanhTien,0),0)+ROUND(ISNULL(PhuThu,0),0)),0) AS Tong,
            ISNULL(SUM(ROUND(ISNULL(TienGiam,0),0)),0) AS Giam,
            ISNULL(SUM(ROUND(ISNULL(ThucThu,0),0)),0) AS Thuc
        FROM dbo.QL_ThuTien_CT
        WHERE IDCSKCB=@IDCSKCB
          AND IDThuTien=T.ID
          AND ISNULL(DaThu,0)=1
    ) X
    WHERE T.IDCSKCB=@IDCSKCB AND T.IDVaoVien=@IDVaoVien;
END;
GO

/* Chỉ được gọi bên trong transaction; luôn khóa lượt trước master. Giữ ID dòng tiền và
   mọi dòng có chứng từ, kể cả đã hủy/hoàn; chỉ diff các dòng chưa có lịch sử. */
CREATE OR ALTER PROCEDURE dbo.STO_QL_ThuTien_DongBoNguon
    @IDCSKCB BIGINT,@IDVaoVien BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT=0 THROW 59700,N'Đồng bộ nguồn thu yêu cầu transaction.',1;
    DECLARE @VisitID BIGINT;
    SELECT @VisitID=ID FROM dbo.QL_VaoVien WITH(UPDLOCK,HOLDLOCK)
    WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien AND Active=1 AND DaChuyenKham=1 AND TrangThaiKham IN(1,2);
    IF @VisitID IS NULL THROW 59700,N'Lượt khám không hợp lệ để đồng bộ nguồn thu.',1;
    DECLARE @IDThuTien BIGINT;
    SELECT @IDThuTien=ID FROM dbo.QL_ThuTien WITH(UPDLOCK,HOLDLOCK)
    WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien;
    IF @IDThuTien IS NULL
    BEGIN
        INSERT dbo.QL_ThuTien(IDCSKCB,IDVaoVien) VALUES(@IDCSKCB,@IDVaoVien);
        SET @IDThuTien=SCOPE_IDENTITY();
    END;

    DELETE CT
    FROM dbo.QL_ThuTien_CT CT
    LEFT JOIN dbo.QL_ChiDinh_CT C ON C.IDCSKCB=CT.IDCSKCB AND C.ID=CT.IDChiDinhCT AND C.IDVaoVien=@IDVaoVien
    LEFT JOIN dbo.QL_ToaThuoc_CT T ON T.IDCSKCB=CT.IDCSKCB AND T.ID=CT.IDToaThuocCT AND T.IDVaoVien=@IDVaoVien
    WHERE CT.IDCSKCB=@IDCSKCB AND CT.IDThuTien=@IDThuTien AND ISNULL(CT.DaThu,0)=0
      AND NOT EXISTS(SELECT 1 FROM dbo.QL_ThuTien_ChungTu_CT H WHERE H.IDThuTienCT=CT.ID)
      AND ((CT.IDChiDinhCT IS NOT NULL AND (ISNULL(C.Active,0)=0 OR C.GuiNgoai=1))
           OR (CT.IDToaThuocCT IS NOT NULL AND ISNULL(T.Active,0)=0));

    UPDATE CT SET SoLuong=C.SoLuong,DonGia=C.DonGia,ThanhTien=C.ThanhTien
    FROM dbo.QL_ThuTien_CT CT
    INNER JOIN dbo.QL_ChiDinh_CT C ON C.IDCSKCB=CT.IDCSKCB AND C.ID=CT.IDChiDinhCT
    WHERE CT.IDCSKCB=@IDCSKCB AND CT.IDThuTien=@IDThuTien AND C.IDVaoVien=@IDVaoVien AND C.Active=1 AND C.GuiNgoai=0
      AND ISNULL(CT.DaThu,0)=0
      AND NOT EXISTS(SELECT 1 FROM dbo.QL_ThuTien_ChungTu_CT H WHERE H.IDThuTienCT=CT.ID);
    INSERT dbo.QL_ThuTien_CT(IDCSKCB,IDThuTien,IDChiDinhCT,SoLuong,DonGia,ThanhTien,TienGiam,ThucThu,DaThu)
    SELECT @IDCSKCB,@IDThuTien,C.ID,C.SoLuong,C.DonGia,C.ThanhTien,0,C.ThanhTien,0
    FROM dbo.QL_ChiDinh_CT C
    WHERE C.IDCSKCB=@IDCSKCB AND C.IDVaoVien=@IDVaoVien AND C.Active=1 AND C.GuiNgoai=0
      AND NOT EXISTS(SELECT 1 FROM dbo.QL_ThuTien_CT CT WITH(UPDLOCK,HOLDLOCK)
          WHERE CT.IDCSKCB=@IDCSKCB AND CT.IDThuTien=@IDThuTien AND CT.IDChiDinhCT=C.ID);

    UPDATE CT SET SoLuong=T.SoLuong,DonGia=T.DonGia,ThanhTien=T.ThanhTien
    FROM dbo.QL_ThuTien_CT CT
    INNER JOIN dbo.QL_ToaThuoc_CT T ON T.IDCSKCB=CT.IDCSKCB AND T.ID=CT.IDToaThuocCT
    WHERE CT.IDCSKCB=@IDCSKCB AND CT.IDThuTien=@IDThuTien AND T.IDVaoVien=@IDVaoVien AND T.Active=1
      AND ISNULL(CT.DaThu,0)=0
      AND NOT EXISTS(SELECT 1 FROM dbo.QL_ThuTien_ChungTu_CT H WHERE H.IDThuTienCT=CT.ID);
    INSERT dbo.QL_ThuTien_CT(IDCSKCB,IDThuTien,IDToaThuocCT,SoLuong,DonGia,ThanhTien,TienGiam,ThucThu,DaThu)
    SELECT @IDCSKCB,@IDThuTien,T.ID,T.SoLuong,T.DonGia,T.ThanhTien,0,T.ThanhTien,0
    FROM dbo.QL_ToaThuoc_CT T
    WHERE T.IDCSKCB=@IDCSKCB AND T.IDVaoVien=@IDVaoVien AND T.Active=1
      AND NOT EXISTS(SELECT 1 FROM dbo.QL_ThuTien_CT CT WITH(UPDLOCK,HOLDLOCK)
          WHERE CT.IDCSKCB=@IDCSKCB AND CT.IDThuTien=@IDThuTien AND CT.IDToaThuocCT=T.ID);
    EXEC dbo.STO_QL_ThuTien_CapNhatTong @IDCSKCB,@IDVaoVien;
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

        SELECT @IDThuTien=ID FROM dbo.QL_ThuTien WITH(UPDLOCK,HOLDLOCK)
        WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien;

        IF @TrangThaiHienTai=0
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
               FROM dbo.QL_ThuTien_CT CT
               INNER JOIN dbo.QL_CongKham_CT CK
                 ON CK.IDCSKCB=CT.IDCSKCB AND CK.ID=CT.IDCongKhamCT AND CK.Active=1
               WHERE CT.IDCSKCB=@IDCSKCB
                 AND CT.IDThuTien=@IDThuTien
                 AND ISNULL(CT.DaThu,0)=0
                 AND ROUND(ISNULL(CT.ThucThu,CT.ThanhTien),0)>0
           )
            THROW 57000,N'Bệnh nhân chưa thanh toán công khám. Thu công khám trước khi bắt đầu khám.',1;

        DECLARE @KhoaCLS TABLE(ID BIGINT PRIMARY KEY);
        DECLARE @KhoaToa TABLE(ID BIGINT PRIMARY KEY);
        INSERT @KhoaCLS
        SELECT DISTINCT CT.IDChiDinhCT FROM dbo.QL_ThuTien_CT CT
        INNER JOIN dbo.FN_QL_ThuTien_DongCoTheThu(@IDCSKCB,@IDVaoVien) E ON E.ID=CT.ID
        WHERE CT.IDCSKCB=@IDCSKCB AND CT.IDThuTien=@IDThuTien AND E.KhoaNghiepVu=1 AND CT.IDChiDinhCT IS NOT NULL
          AND EXISTS(SELECT 1 FROM dbo.QL_ChiDinh_CT C WHERE C.IDCSKCB=@IDCSKCB AND C.ID=CT.IDChiDinhCT AND C.IDVaoVien=@IDVaoVien AND C.Active=1);
        INSERT @KhoaToa
        SELECT DISTINCT CT.IDToaThuocCT FROM dbo.QL_ThuTien_CT CT
        INNER JOIN dbo.FN_QL_ThuTien_DongCoTheThu(@IDCSKCB,@IDVaoVien) E ON E.ID=CT.ID
        WHERE CT.IDCSKCB=@IDCSKCB AND CT.IDThuTien=@IDThuTien AND E.KhoaNghiepVu=1 AND CT.IDToaThuocCT IS NOT NULL
          AND EXISTS(SELECT 1 FROM dbo.QL_ToaThuoc_CT T WHERE T.IDCSKCB=@IDCSKCB AND T.ID=CT.IDToaThuocCT AND T.IDVaoVien=@IDVaoVien AND T.Active=1);

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

            IF EXISTS(SELECT IDDichVu FROM @CI GROUP BY IDDichVu HAVING COUNT(*)>1)
                THROW 57000,N'Chỉ định CLS bị lặp dịch vụ.',1;
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
                WHERE NOT EXISTS(SELECT 1 FROM @KhoaCLS K WHERE K.ID=X.ID)
                  AND NOT EXISTS(SELECT 1 FROM dbo.DM_DichVu D WHERE D.IDCSKCB=@IDCSKCB AND D.ID=X.IDDichVu AND D.Active=1 AND D.LoaiDichVu<>1)
            )
                THROW 57000,N'Có dịch vụ CLS không hợp lệ.',1;

            INSERT @CIXoa(ID)
            SELECT C.ID
            FROM dbo.QL_ChiDinh_CT C WITH(UPDLOCK,HOLDLOCK)
            WHERE C.IDCSKCB=@IDCSKCB AND C.IDVaoVien=@IDVaoVien AND C.Active=1
              AND NOT EXISTS(SELECT 1 FROM @CI X WHERE X.ID=C.ID);

            IF EXISTS(SELECT 1 FROM @CIXoa X INNER JOIN @KhoaCLS K ON K.ID=X.ID)
                THROW 57000,N'Không được xóa CLS đã thu hoặc đã có chứng từ.',1;
            IF EXISTS(SELECT 1 FROM @CI X INNER JOIN @KhoaCLS K ON K.ID=X.ID
                      INNER JOIN dbo.QL_ChiDinh_CT C ON C.ID=X.ID AND C.IDCSKCB=@IDCSKCB
                      WHERE X.SoLuong<>C.SoLuong OR X.GuiNgoai<>C.GuiNgoai)
                THROW 57000,N'Không được đổi số lượng/nơi thực hiện CLS đã có chứng từ.',1;

            INSERT @FilesToDelete(ID,DuongDanTuongDoi)
            SELECT C.ID,C.DuongDanKetQua
            FROM @CIXoa X
            INNER JOIN dbo.QL_ChiDinh_CT C ON C.ID=X.ID AND C.IDCSKCB=@IDCSKCB
            WHERE C.IDVaoVien=@IDVaoVien AND NULLIF(LTRIM(RTRIM(C.DuongDanKetQua)),N'') IS NOT NULL;


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
            WHERE C.IDCSKCB=@IDCSKCB AND C.IDVaoVien=@IDVaoVien AND C.Active=1
              AND NOT EXISTS(SELECT 1 FROM @KhoaCLS K WHERE K.ID=C.ID);

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
                WHERE NOT EXISTS(SELECT 1 FROM @KhoaToa K WHERE K.ID=X.ID)
                  AND NOT EXISTS(SELECT 1 FROM dbo.DM_Thuoc D WHERE D.IDCSKCB=@IDCSKCB AND D.ID=X.IDThuoc AND D.Active=1)
            )
                THROW 57000,N'Có thuốc không hợp lệ.',1;
            IF EXISTS
            (
                SELECT 1 FROM @TT X
                WHERE NOT EXISTS(SELECT 1 FROM @KhoaToa K WHERE K.ID=X.ID)
                  AND X.IDDonViTinhDung IS NOT NULL
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
            IF EXISTS(SELECT 1 FROM @KhoaToa K
                LEFT JOIN @TT X ON X.ID=K.ID
                INNER JOIN dbo.QL_ToaThuoc_CT T ON T.IDCSKCB=@IDCSKCB AND T.ID=K.ID
                WHERE X.ID IS NULL OR X.IDThuoc<>T.IDThuoc OR X.SoLuong<>T.SoLuong
                   OR X.MaLoaiToaThuoc<>T.MaLoaiToaThuoc
                   OR COALESCE(X.IDDonViTinhDung,T.IDDonViTinhDung,0)<>ISNULL(T.IDDonViTinhDung,0))
                THROW 57000,N'Không được xóa/đổi thuốc, số lượng hoặc đơn vị dòng toa đã có chứng từ.',1;

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
            WHERE T.IDCSKCB=@IDCSKCB AND T.IDVaoVien=@IDVaoVien AND T.Active=1
              AND NOT EXISTS(SELECT 1 FROM @KhoaToa K WHERE K.ID=T.ID);

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


            UPDATE dbo.QL_VaoVien
            SET KeToa=CASE WHEN EXISTS(SELECT 1 FROM dbo.QL_ToaThuoc_CT WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND Active=1) THEN 1 ELSE 0 END
            WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien;
        END;



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

        EXEC dbo.STO_QL_ThuTien_DongBoNguon @IDCSKCB,@IDVaoVien;

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
        SELECT 400 AS Status,CASE WHEN ERROR_NUMBER()=57000 THEN ERROR_MESSAGE()
            ELSE N'Không thể lưu khám bệnh do dữ liệu không hợp lệ hoặc đã thay đổi.' END AS Message;
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

        EXEC dbo.STO_QL_ThuTien_CapNhatTong @IDCSKCB,@IDVaoVien;
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
            C.*,
            CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.QL_ThuTien_CT F WHERE F.IDCSKCB=@IDCSKCB AND F.IDChiDinhCT=C.ID AND F.DaThu=1) THEN 1 ELSE 0 END AS BIT) AS DaThu,
            CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.QL_ThuTien_CT F INNER JOIN dbo.FN_QL_ThuTien_DongCoTheThu(@IDCSKCB,@IDVaoVien) E ON E.ID=F.ID
                 WHERE F.IDCSKCB=@IDCSKCB AND F.IDChiDinhCT=C.ID AND E.KhoaNghiepVu=1) THEN 1 ELSE 0 END AS BIT) AS KhoaNghiepVu,
            D.MaDichVu,D.TenDichVu,D.DonViTinh,D.DonGia AS DonGiaDanhMuc,
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

        SELECT T.*,
            CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.QL_ThuTien_CT F WHERE F.IDCSKCB=@IDCSKCB AND F.IDToaThuocCT=T.ID AND F.DaThu=1) THEN 1 ELSE 0 END AS BIT) AS DaThu,
            CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.QL_ThuTien_CT F INNER JOIN dbo.FN_QL_ThuTien_DongCoTheThu(@IDCSKCB,@IDVaoVien) E ON E.ID=F.ID
                 WHERE F.IDCSKCB=@IDCSKCB AND F.IDToaThuocCT=T.ID AND E.KhoaNghiepVu=1) THEN 1 ELSE 0 END AS BIT) AS KhoaNghiepVu,
            DM.MaThuoc,DM.TenThuoc,COALESCE(DVTD.TenDVT,DVT.TenDVT,DM.DonViTinh) AS DonViTinh,DM.HamLuong,COALESCE(NULLIF(T.HoatChat,N''),DM.HoatChat) AS HoatChat
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

CREATE OR ALTER PROCEDURE dbo.STO_QL_ThuNgan_ThuTien
    @IDCSKCB BIGINT,
    @IDVaoVien BIGINT,
    @IDNhanVienThu BIGINT=NULL,
    @IDTaiKhoanThu BIGINT,
    @ChuyenKhoan DECIMAL(18,2)=0,
    @IDNganHang BIGINT=NULL,
    @GhiChu NVARCHAR(500)=NULL,
    @DanhSachJson NVARCHAR(MAX)=N'[]'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @ChuyenKhoan=ROUND(ISNULL(@ChuyenKhoan,0),0);
    SET @GhiChu=NULLIF(LTRIM(RTRIM(@GhiChu)),N'');

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @TrangThaiKham TINYINT,@Active BIT;
        SELECT @TrangThaiKham=TrangThaiKham,@Active=Active
        FROM dbo.QL_VaoVien WITH(UPDLOCK,HOLDLOCK)
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien;

        IF @Active IS NULL OR @Active=0
            THROW 58000,N'Không tìm thấy lượt khám.',1;
        IF @TrangThaiKham NOT IN(0,1,2)
            THROW 58000,N'Lượt khám chưa ở trạng thái được thu tiền.',1;
        IF @IDTaiKhoanThu<=0
           OR NOT EXISTS(SELECT 1 FROM dbo.HT_Tai_Khoan WHERE ID=@IDTaiKhoanThu AND Active=1)
            THROW 58000,N'Không xác định được tài khoản thực hiện thu tiền.',1;
        IF ISNULL(@IDNhanVienThu,0)<=0 SET @IDNhanVienThu=NULL;

        DECLARE
            @IDThuTien BIGINT,
            @DaThu BIT,
            @SoPhieu NVARCHAR(30),
            @IDChungTu BIGINT,
            @SoChungTu NVARCHAR(40),
            @IDChungTuChiDinh BIGINT=NULL,
            @IDChungTuToa BIGINT=NULL,
            @SoChungTuChiDinh NVARCHAR(40)=NULL,
            @SoChungTuToa NVARCHAR(40)=NULL,
            @TienMatCu DECIMAL(18,2)=0,
            @ChuyenKhoanCu DECIMAL(18,2)=0,
            @IDNganHangCu BIGINT=NULL;

        SELECT
            @IDThuTien=ID,
            @DaThu=DaThu,
            @SoPhieu=SoPhieu,
            @TienMatCu=ISNULL(TienMat,0),
            @ChuyenKhoanCu=ISNULL(ChuyenKhoan,0),
            @IDNganHangCu=IDNganHang
        FROM dbo.QL_ThuTien WITH(UPDLOCK,HOLDLOCK)
        WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien;

        IF @IDThuTien IS NULL
        BEGIN
            INSERT dbo.QL_ThuTien(IDCSKCB,IDVaoVien)
            VALUES(@IDCSKCB,@IDVaoVien);
            SET @IDThuTien=SCOPE_IDENTITY();
            SET @DaThu=0;
            SET @TienMatCu=0;
            SET @ChuyenKhoanCu=0;
            SET @IDNganHangCu=NULL;
        END;


        IF ISJSON(@DanhSachJson)<>1
            THROW 58000,N'Danh sách khoản thu không hợp lệ.',1;

        DECLARE @DC TABLE
        (
            ID BIGINT PRIMARY KEY,
            PhuThu DECIMAL(18,2) NOT NULL,
            GiamPhanTram DECIMAL(5,2) NOT NULL
        );

        INSERT @DC(ID,PhuThu,GiamPhanTram)
        SELECT J.ID,ROUND(ISNULL(J.PhuThu,0),0),ISNULL(J.GiamPhanTram,0)
        FROM OPENJSON(@DanhSachJson)
        WITH
        (
            ID BIGINT '$.id',
            PhuThu DECIMAL(18,2) '$.phu_thu',
            GiamPhanTram DECIMAL(5,2) '$.giam_phan_tram'
        ) J
        WHERE J.ID IS NOT NULL;

        IF NOT EXISTS(SELECT 1 FROM @DC)
            THROW 58000,N'Chọn ít nhất một khoản cần thu.',1;
        IF EXISTS(SELECT 1 FROM @DC WHERE PhuThu<0)
            THROW 58000,N'Phụ thu không được nhỏ hơn 0.',1;
        IF EXISTS(SELECT 1 FROM @DC WHERE GiamPhanTram<0 OR GiamPhanTram>100)
            THROW 58000,N'Giảm (%) phải từ 0 đến 100.',1;

        IF EXISTS
        (
            SELECT 1
            FROM @DC D
            LEFT JOIN dbo.QL_ThuTien_CT CT
              ON CT.IDCSKCB=@IDCSKCB
             AND CT.IDThuTien=@IDThuTien
             AND CT.ID=D.ID
            WHERE CT.ID IS NULL OR ISNULL(CT.DaThu,0)=1
               OR NOT EXISTS(SELECT 1 FROM dbo.FN_QL_ThuTien_DongCoTheThu(@IDCSKCB,@IDVaoVien) E WHERE E.ID=CT.ID AND E.CoTheThu=1)
        )
            THROW 58000,N'Có khoản đã thu, không thuộc lượt khám hoặc chưa được phép thu. Trước khám chỉ thu công khám; đang khám chỉ thu công khám và CLS nội bộ.',1;

        UPDATE CT
        SET CT.PhuThu=D.PhuThu,
            CT.GiamPhanTram=D.GiamPhanTram,
            CT.TienGiam=ROUND((ROUND(ISNULL(CT.ThanhTien,0),0)+D.PhuThu)*D.GiamPhanTram/100.0,0),
            CT.ThucThu=(ROUND(ISNULL(CT.ThanhTien,0),0)+D.PhuThu)
                      -ROUND((ROUND(ISNULL(CT.ThanhTien,0),0)+D.PhuThu)*D.GiamPhanTram/100.0,0)
        FROM dbo.QL_ThuTien_CT CT
        INNER JOIN @DC D ON D.ID=CT.ID
        WHERE CT.IDCSKCB=@IDCSKCB AND CT.IDThuTien=@IDThuTien;

        DECLARE
            @TongLanNay DECIMAL(18,2),@GiamLanNay DECIMAL(18,2),@PhaiThuLanNay DECIMAL(18,2),
            @SoDongChiDinh INT,@TongChiDinh DECIMAL(18,2),@GiamChiDinh DECIMAL(18,2),@ThuChiDinh DECIMAL(18,2),
            @SoDongToa INT,@TongToa DECIMAL(18,2),@GiamToa DECIMAL(18,2),@ThuToa DECIMAL(18,2);

        SELECT
            @TongLanNay=ISNULL(SUM(ROUND(ISNULL(CT.ThanhTien,0),0)+ROUND(ISNULL(CT.PhuThu,0),0)),0),
            @GiamLanNay=ISNULL(SUM(ROUND(ISNULL(CT.TienGiam,0),0)),0),
            @PhaiThuLanNay=ISNULL(SUM(ROUND(ISNULL(CT.ThucThu,0),0)),0),
            @SoDongChiDinh=ISNULL(SUM(CASE WHEN CT.IDToaThuocCT IS NULL THEN 1 ELSE 0 END),0),
            @TongChiDinh=ISNULL(SUM(CASE WHEN CT.IDToaThuocCT IS NULL THEN ROUND(ISNULL(CT.ThanhTien,0),0)+ROUND(ISNULL(CT.PhuThu,0),0) ELSE 0 END),0),
            @GiamChiDinh=ISNULL(SUM(CASE WHEN CT.IDToaThuocCT IS NULL THEN ROUND(ISNULL(CT.TienGiam,0),0) ELSE 0 END),0),
            @ThuChiDinh=ISNULL(SUM(CASE WHEN CT.IDToaThuocCT IS NULL THEN ROUND(ISNULL(CT.ThucThu,0),0) ELSE 0 END),0),
            @SoDongToa=ISNULL(SUM(CASE WHEN CT.IDToaThuocCT IS NOT NULL THEN 1 ELSE 0 END),0),
            @TongToa=ISNULL(SUM(CASE WHEN CT.IDToaThuocCT IS NOT NULL THEN ROUND(ISNULL(CT.ThanhTien,0),0)+ROUND(ISNULL(CT.PhuThu,0),0) ELSE 0 END),0),
            @GiamToa=ISNULL(SUM(CASE WHEN CT.IDToaThuocCT IS NOT NULL THEN ROUND(ISNULL(CT.TienGiam,0),0) ELSE 0 END),0),
            @ThuToa=ISNULL(SUM(CASE WHEN CT.IDToaThuocCT IS NOT NULL THEN ROUND(ISNULL(CT.ThucThu,0),0) ELSE 0 END),0)
        FROM dbo.QL_ThuTien_CT CT
        INNER JOIN @DC D ON D.ID=CT.ID
        WHERE CT.IDCSKCB=@IDCSKCB AND CT.IDThuTien=@IDThuTien;

        IF @ChuyenKhoan<0 OR @ChuyenKhoan>@PhaiThuLanNay
            THROW 58000,N'Số tiền chuyển khoản không hợp lệ.',1;

        IF @ChuyenKhoan>0 AND
           (@IDNganHang IS NULL OR NOT EXISTS(SELECT 1 FROM dbo.DM_NganHang WHERE ID=@IDNganHang AND Active=1))
            THROW 58000,N'Chọn ngân hàng khi có thanh toán chuyển khoản.',1;

        DECLARE
            @TienMatLanNay DECIMAL(18,2)=@PhaiThuLanNay-@ChuyenKhoan,
            @CKChiDinh DECIMAL(18,2)=CASE WHEN @ChuyenKhoan>@ThuChiDinh THEN @ThuChiDinh ELSE @ChuyenKhoan END,
            @CKToa DECIMAL(18,2)=0,
            @TienMatChiDinh DECIMAL(18,2)=0,
            @TienMatToa DECIMAL(18,2)=0;

        SET @CKToa=@ChuyenKhoan-@CKChiDinh;
        SET @TienMatChiDinh=@ThuChiDinh-@CKChiDinh;
        SET @TienMatToa=@ThuToa-@CKToa;

        IF @TienMatLanNay<0 OR @TienMatChiDinh<0 OR @TienMatToa<0
            THROW 58000,N'Số tiền thanh toán không hợp lệ.',1;

        IF @SoDongChiDinh>0
        BEGIN
            EXEC dbo.STO_QL_ThuNgan_CapSoChungTu
                @IDCSKCB=@IDCSKCB,@Loai='THU',@SoChungTu=@SoChungTuChiDinh OUTPUT;

            INSERT dbo.QL_ThuTien_ChungTu
                (IDCSKCB,IDVaoVien,IDThuTien,Loai,Nhom,SoChungTu,NgayGio,IDNhanVien,IDTaiKhoan,
                 TongTien,TienGiam,ThucThu,TienMat,ChuyenKhoan,IDNganHang,GhiChu)
            VALUES
                (@IDCSKCB,@IDVaoVien,@IDThuTien,'THU',N'CHI_DINH',@SoChungTuChiDinh,SYSDATETIME(),@IDNhanVienThu,@IDTaiKhoanThu,
                 @TongChiDinh,@GiamChiDinh,@ThuChiDinh,@TienMatChiDinh,@CKChiDinh,@IDNganHang,@GhiChu);
            SET @IDChungTuChiDinh=SCOPE_IDENTITY();

            INSERT dbo.QL_ThuTien_ChungTu_CT
                (IDChungTu,IDThuTienCT,Loai,Ma,Ten,DonViTinh,SoLuong,DonGia,ThanhTien,PhuThu,GiamPhanTram,TienGiam,ThanhToan)
            SELECT @IDChungTuChiDinh,CT.ID,
                CASE WHEN CT.IDCongKhamCT IS NOT NULL THEN N'CONG_KHAM' WHEN CT.IDChiDinhCT IS NOT NULL THEN N'CLS' ELSE N'KHAC' END,
                COALESCE(DVCK.MaDichVu,DVCD.MaDichVu,N''),
                COALESCE(DVCK.TenDichVu,DVCD.TenDichVu,N'Khoản thu'),
                COALESCE(DVCK.DonViTinh,DVCD.DonViTinh,N''),
                CT.SoLuong,ROUND(CT.DonGia,0),ROUND(CT.ThanhTien,0),ROUND(CT.PhuThu,0),CT.GiamPhanTram,ROUND(CT.TienGiam,0),ROUND(CT.ThucThu,0)
            FROM dbo.QL_ThuTien_CT CT
            INNER JOIN @DC D ON D.ID=CT.ID
            LEFT JOIN dbo.QL_CongKham_CT CK ON CK.IDCSKCB=CT.IDCSKCB AND CK.ID=CT.IDCongKhamCT
            LEFT JOIN dbo.DM_DichVu DVCK ON DVCK.IDCSKCB=CK.IDCSKCB AND DVCK.ID=CK.IDDichVu
            LEFT JOIN dbo.QL_ChiDinh_CT CD ON CD.IDCSKCB=CT.IDCSKCB AND CD.ID=CT.IDChiDinhCT
            LEFT JOIN dbo.DM_DichVu DVCD ON DVCD.IDCSKCB=CD.IDCSKCB AND DVCD.ID=CD.IDDichVu
            WHERE CT.IDCSKCB=@IDCSKCB AND CT.IDThuTien=@IDThuTien AND CT.IDToaThuocCT IS NULL;

            INSERT dbo.QL_ThuTien_LichSu
                (IDCSKCB,IDThuTien,IDVaoVien,HanhDong,SoPhieu,NgayGio,IDNhanVien,IDTaiKhoan,TongTien,TienGiam,ThucThu,TienMat,ChuyenKhoan,IDNganHang,GhiChu)
            VALUES
                (@IDCSKCB,@IDThuTien,@IDVaoVien,N'THU',@SoChungTuChiDinh,SYSDATETIME(),@IDNhanVienThu,@IDTaiKhoanThu,
                 @TongChiDinh,@GiamChiDinh,@ThuChiDinh,@TienMatChiDinh,@CKChiDinh,@IDNganHang,@GhiChu);
        END;

        IF @SoDongToa>0
        BEGIN
            EXEC dbo.STO_QL_ThuNgan_CapSoChungTu
                @IDCSKCB=@IDCSKCB,@Loai='THU',@SoChungTu=@SoChungTuToa OUTPUT;

            INSERT dbo.QL_ThuTien_ChungTu
                (IDCSKCB,IDVaoVien,IDThuTien,Loai,Nhom,SoChungTu,NgayGio,IDNhanVien,IDTaiKhoan,
                 TongTien,TienGiam,ThucThu,TienMat,ChuyenKhoan,IDNganHang,GhiChu)
            VALUES
                (@IDCSKCB,@IDVaoVien,@IDThuTien,'THU',N'TOA_THUOC',@SoChungTuToa,SYSDATETIME(),@IDNhanVienThu,@IDTaiKhoanThu,
                 @TongToa,@GiamToa,@ThuToa,@TienMatToa,@CKToa,@IDNganHang,@GhiChu);
            SET @IDChungTuToa=SCOPE_IDENTITY();

            INSERT dbo.QL_ThuTien_ChungTu_CT
                (IDChungTu,IDThuTienCT,Loai,Ma,Ten,DonViTinh,SoLuong,DonGia,ThanhTien,PhuThu,GiamPhanTram,TienGiam,ThanhToan)
            SELECT @IDChungTuToa,CT.ID,N'THUOC',
                COALESCE(TH.MaThuoc,N''),
                COALESCE(TH.TenThuoc,N'Khoản thu'),
                COALESCE(DVTThuoc.TenDVT,TH.DonViTinh,N''),
                CT.SoLuong,ROUND(CT.DonGia,0),ROUND(CT.ThanhTien,0),ROUND(CT.PhuThu,0),CT.GiamPhanTram,ROUND(CT.TienGiam,0),ROUND(CT.ThucThu,0)
            FROM dbo.QL_ThuTien_CT CT
            INNER JOIN @DC D ON D.ID=CT.ID
            LEFT JOIN dbo.QL_ToaThuoc_CT TT ON TT.IDCSKCB=CT.IDCSKCB AND TT.ID=CT.IDToaThuocCT
            LEFT JOIN dbo.DM_Thuoc TH ON TH.IDCSKCB=TT.IDCSKCB AND TH.ID=TT.IDThuoc
            LEFT JOIN dbo.DM_DonViTinh DVTThuoc ON DVTThuoc.IDCSKCB=TT.IDCSKCB AND DVTThuoc.ID=TT.IDDonViTinhDung
            WHERE CT.IDCSKCB=@IDCSKCB AND CT.IDThuTien=@IDThuTien AND CT.IDToaThuocCT IS NOT NULL;

            INSERT dbo.QL_ThuTien_LichSu
                (IDCSKCB,IDThuTien,IDVaoVien,HanhDong,SoPhieu,NgayGio,IDNhanVien,IDTaiKhoan,TongTien,TienGiam,ThucThu,TienMat,ChuyenKhoan,IDNganHang,GhiChu)
            VALUES
                (@IDCSKCB,@IDThuTien,@IDVaoVien,N'THU',@SoChungTuToa,SYSDATETIME(),@IDNhanVienThu,@IDTaiKhoanThu,
                 @TongToa,@GiamToa,@ThuToa,@TienMatToa,@CKToa,@IDNganHang,@GhiChu);
        END;

        SET @IDChungTu=COALESCE(@IDChungTuChiDinh,@IDChungTuToa);
        SET @SoChungTu=COALESCE(@SoChungTuChiDinh,@SoChungTuToa);

        UPDATE CT
        SET DaThu=1
        FROM dbo.QL_ThuTien_CT CT
        INNER JOIN @DC D ON D.ID=CT.ID
        WHERE CT.IDCSKCB=@IDCSKCB AND CT.IDThuTien=@IDThuTien;

        DECLARE
            @TongTien DECIMAL(18,2),@TienGiam DECIMAL(18,2),@PhaiThu DECIMAL(18,2),
            @SoDongConLai INT,@SoDongDaThu INT;

        SELECT
            @TongTien=ISNULL(SUM(CASE WHEN ISNULL(DaThu,0)=1 THEN ROUND(ISNULL(ThanhTien,0),0)+ROUND(ISNULL(PhuThu,0),0) ELSE 0 END),0),
            @TienGiam=ISNULL(SUM(CASE WHEN ISNULL(DaThu,0)=1 THEN ROUND(ISNULL(TienGiam,0),0) ELSE 0 END),0),
            @PhaiThu=ISNULL(SUM(CASE WHEN ISNULL(DaThu,0)=1 THEN ROUND(ISNULL(ThucThu,0),0) ELSE 0 END),0),
            @SoDongConLai=SUM(CASE WHEN ISNULL(DaThu,0)=0 THEN 1 ELSE 0 END),
            @SoDongDaThu=SUM(CASE WHEN ISNULL(DaThu,0)=1 THEN 1 ELSE 0 END)
        FROM dbo.QL_ThuTien_CT CT WITH(HOLDLOCK)
        WHERE CT.IDCSKCB=@IDCSKCB AND CT.IDThuTien=@IDThuTien
          AND EXISTS(SELECT 1 FROM dbo.FN_QL_ThuTien_DongCoTheThu(@IDCSKCB,@IDVaoVien) E
              WHERE E.ID=CT.ID AND (E.CoTheThu=1 OR CT.DaThu=1));

        IF NULLIF(LTRIM(RTRIM(ISNULL(@SoPhieu,N''))),N'') IS NULL
            SET @SoPhieu=@SoChungTu;

        UPDATE dbo.QL_ThuTien
        SET SoPhieu=@SoPhieu,
            NgayGioThu=SYSDATETIME(),
            IDNhanVienThu=@IDNhanVienThu,
            IDTaiKhoanThu=@IDTaiKhoanThu,
            TongTien=@TongTien,
            TienGiam=@TienGiam,
            ThucThu=@PhaiThu,
            TienMat=@TienMatCu+@TienMatLanNay,
            ChuyenKhoan=@ChuyenKhoanCu+@ChuyenKhoan,
            IDNganHang=CASE WHEN @ChuyenKhoan>0 THEN @IDNganHang ELSE @IDNganHangCu END,
            DaThu=CASE WHEN ISNULL(@SoDongDaThu,0)>0 AND ISNULL(@SoDongConLai,0)=0 THEN 1 ELSE 0 END,
            DaHuy=0,
            GhiChu=@GhiChu
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDThuTien;

        COMMIT;
        SELECT 200 AS Status,N'Thu tiền thành công.' AS Message,
               @IDThuTien AS IDThuTien,@IDChungTu AS IDChungTu,@SoChungTu AS SoPhieu,
               @IDChungTuChiDinh AS IDChungTuChiDinh,@SoChungTuChiDinh AS SoPhieuChiDinh,
               @IDChungTuToa AS IDChungTuToaThuoc,@SoChungTuToa AS SoPhieuToaThuoc,
               @TongTien AS TongTien,@TienGiam AS TienGiam,@PhaiThu AS ThucThu,
               @TienMatCu+@TienMatLanNay AS TienMat,
               @ChuyenKhoanCu+@ChuyenKhoan AS ChuyenKhoan,
               CASE WHEN ISNULL(@SoDongConLai,0)>0 THEN CAST(0 AS TINYINT) ELSE CAST(1 AS TINYINT) END AS TrangThaiThu;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 400 AS Status,ERROR_MESSAGE() AS Message,
               CAST(NULL AS BIGINT) AS IDThuTien,CAST(NULL AS NVARCHAR(30)) AS SoPhieu;
    END CATCH;
END;
GO

/* Đường lưu nhanh trước upload PDF phải tạo cả nguồn thu trong cùng transaction.
   Chính sách thu trước khi nhập kết quả được áp tại STO_QL_Cls_LuuDuongDanKetQua từ v100. */
CREATE OR ALTER PROCEDURE dbo.STO_QL_Cls_DamBaoChiDinh
    @IDCSKCB BIGINT,@IDVaoVien BIGINT,@IDDichVu BIGINT,@IDBacSi BIGINT=NULL,
    @LaQuanTri BIT=0,@CoQuyenSua BIT=0,@SoLuong DECIMAL(10,2)=1,
    @GuiNgoai BIT=0,@NoiGuiNgoai NVARCHAR(300)=NULL,@GhiChu NVARCHAR(500)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @TrangThai TINYINT,@BacSi BIGINT,@IDChiDinhCT BIGINT,@IDThuTien BIGINT,@DonGia DECIMAL(18,2);
        SELECT @TrangThai=TrangThaiKham,@BacSi=IDBacSiKham FROM dbo.QL_VaoVien WITH(UPDLOCK,HOLDLOCK)
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien AND Active=1 AND DaChuyenKham=1;
        IF @TrangThai IS NULL OR @TrangThai=3 THROW 59700,N'Không tìm thấy lượt khám CLS hợp lệ.',1;
        IF @LaQuanTri=0 AND (ISNULL(@IDBacSi,0)<=0 OR (@BacSi IS NOT NULL AND @BacSi<>@IDBacSi))
            THROW 59700,N'Bệnh nhân đang thuộc phiên khám của bác sĩ khác.',1;
        IF @SoLuong IS NULL OR @SoLuong<=0 THROW 59700,N'Số lượng CLS phải lớn hơn 0.',1;
        SELECT @DonGia=CASE WHEN @GuiNgoai=1 THEN 0 ELSE DonGia END FROM dbo.DM_DichVu
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDDichVu AND Active=1 AND LoaiDichVu<>1;
        IF @DonGia IS NULL THROW 59700,N'Dịch vụ CLS không hợp lệ.',1;

        /* Match Luu/ThuTien lock order even when the source is not yet present. */
        SELECT @IDThuTien=ID FROM dbo.QL_ThuTien WITH(UPDLOCK,HOLDLOCK)
        WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien;

        SELECT TOP(1) @IDChiDinhCT=ID FROM dbo.QL_ChiDinh_CT WITH(UPDLOCK,HOLDLOCK)
        WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien AND IDDichVu=@IDDichVu AND Active=1 ORDER BY ID;

        IF @IDChiDinhCT IS NULL
           AND @TrangThai=0
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
               FROM dbo.QL_ThuTien_CT P
               INNER JOIN dbo.QL_CongKham_CT CK
                 ON CK.IDCSKCB=P.IDCSKCB AND CK.ID=P.IDCongKhamCT AND CK.Active=1
               WHERE P.IDCSKCB=@IDCSKCB
                 AND P.IDThuTien=@IDThuTien
                 AND ISNULL(P.DaThu,0)=0
                 AND ROUND(ISNULL(P.ThucThu,P.ThanhTien),0)>0
           )
            THROW 59700,N'Bệnh nhân chưa thanh toán công khám. Thu công khám trước khi chỉ định CLS.',1;

        IF @IDThuTien IS NULL
        BEGIN
            INSERT dbo.QL_ThuTien(IDCSKCB,IDVaoVien) VALUES(@IDCSKCB,@IDVaoVien);
            SET @IDThuTien=SCOPE_IDENTITY();
        END;
        IF @IDChiDinhCT IS NULL
        BEGIN
            IF @TrangThai=2 AND @CoQuyenSua=0 THROW 59700,N'Lượt khám đã hoàn tất; tài khoản không có quyền chỉnh sửa.',1;
            INSERT dbo.QL_ChiDinh_CT(IDCSKCB,IDVaoVien,IDDichVu,NgayGioChiDinh,SoLuong,DonGia,ThanhTien,GuiNgoai,NoiGuiNgoai,IDBacSiChiDinh,TrangThai,GhiChu,Active)
            VALUES(@IDCSKCB,@IDVaoVien,@IDDichVu,SYSDATETIME(),@SoLuong,@DonGia,@SoLuong*@DonGia,@GuiNgoai,
                CASE WHEN @GuiNgoai=1 THEN @NoiGuiNgoai END,CASE WHEN @LaQuanTri=1 THEN @BacSi ELSE @IDBacSi END,0,@GhiChu,1);
            SET @IDChiDinhCT=SCOPE_IDENTITY();
        END;
        /* Đang khám nhưng chưa lưu hồ sơ đầy đủ: không đánh dấu NgayLuuKhamLanDau.
           Also reconcile status0 for orders created by the former quick EF path. */
        UPDATE dbo.QL_VaoVien SET TrangThaiKham=CASE WHEN TrangThaiKham=0 THEN 1 ELSE TrangThaiKham END,
            IDBacSiKham=COALESCE(IDBacSiKham,CASE WHEN @LaQuanTri=0 THEN @IDBacSi END),
            BatDauKhamLuc=COALESCE(BatDauKhamLuc,SYSDATETIME()),NgayCapNhat=SYSDATETIME()
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien;
        EXEC dbo.STO_QL_ThuTien_DongBoNguon @IDCSKCB,@IDVaoVien;
        COMMIT;
        SELECT 200 AS Status,N'Đã lưu chỉ định CLS và đồng bộ nguồn thu.' AS Message,@IDChiDinhCT AS IDChiDinhCT;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT 400 AS Status,CASE WHEN ERROR_NUMBER()=59700 THEN ERROR_MESSAGE()
            ELSE N'Không thể lưu chỉ định CLS do dữ liệu không hợp lệ hoặc đã thay đổi.' END AS Message;
    END CATCH;
END;
GO
PRINT N'36_thu_cls_dang_kham_v97.sql: source contract v97.';
GO
