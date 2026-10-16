/* v96: phát thuốc bởi global admin, audit bằng tài khoản thực hiện.
   Chạy qua updater sau v95 + auth schema. Không backfill tài khoản từ nhân viên.
   Legacy giữ NULL; không thay đổi tiền/tồn hay dữ liệu chứng từ cũ. */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
GO
IF COL_LENGTH(N'dbo.QL_Kho_Xuat',N'IDTaiKhoanXuat') IS NULL
    ALTER TABLE dbo.QL_Kho_Xuat ADD IDTaiKhoanXuat BIGINT NULL;
IF COL_LENGTH(N'dbo.QL_Kho_Xuat',N'TenNguoiXuatSnapshot') IS NULL
    ALTER TABLE dbo.QL_Kho_Xuat ADD TenNguoiXuatSnapshot NVARCHAR(200) NULL;
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'dbo.QL_Kho_Xuat') AND name=N'FK_QL_Kho_Xuat_TaiKhoan')
    ALTER TABLE dbo.QL_Kho_Xuat WITH CHECK ADD CONSTRAINT FK_QL_Kho_Xuat_TaiKhoan
        FOREIGN KEY(IDTaiKhoanXuat) REFERENCES dbo.HT_Tai_Khoan(ID);
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.QL_Kho_Xuat') AND name=N'CK_QL_Kho_Xuat_ActorSnapshot')
    ALTER TABLE dbo.QL_Kho_Xuat WITH CHECK ADD CONSTRAINT CK_QL_Kho_Xuat_ActorSnapshot CHECK
        ((IDTaiKhoanXuat IS NULL AND TenNguoiXuatSnapshot IS NULL) OR
         (IDTaiKhoanXuat IS NOT NULL AND NULLIF(LTRIM(RTRIM(TenNguoiXuatSnapshot)),N'') IS NOT NULL));
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
