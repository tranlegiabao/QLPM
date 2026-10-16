:ON ERROR EXIT
USE [QLPM];
GO
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
IF OBJECT_ID(N'dbo.QL_ToaThuoc',N'U') IS NULL
    THROW 59200,N'Thieu contract toa thuoc v104.',1;
GO
IF OBJECT_ID(N'dbo.QL_ToaThuoc_LienThongPayload',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.QL_ToaThuoc_LienThongPayload(
        ID BIGINT IDENTITY PRIMARY KEY,
        IDCSKCB BIGINT NOT NULL,
        IDToaThuoc BIGINT NOT NULL,
        IDBacSiKe BIGINT NOT NULL,
        PhienBanNguon BIGINT NOT NULL,
        JsonPayload NVARCHAR(MAX) NOT NULL,
        Sha256Json CHAR(64) NOT NULL,
        NgayTao DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT UQ_QL_LTTT_Payload UNIQUE(IDCSKCB,ID),
        CONSTRAINT FK_QL_LTTT_Payload_Toa FOREIGN KEY(IDCSKCB,IDToaThuoc) REFERENCES dbo.QL_ToaThuoc(IDCSKCB,ID),
        CONSTRAINT FK_QL_LTTT_Payload_BacSi FOREIGN KEY(IDBacSiKe) REFERENCES dbo.DM_NhanVien(ID),
        CONSTRAINT CK_QL_LTTT_Payload_Json CHECK(ISJSON(JsonPayload)=1 AND JSON_VALUE(JsonPayload,'$.signature')=N'')
    );
    CREATE INDEX IX_QL_LTTT_Payload_Toa ON dbo.QL_ToaThuoc_LienThongPayload(IDCSKCB,IDToaThuoc,ID DESC);
END;
GO
IF OBJECT_ID(N'dbo.QL_ToaThuoc_LienThongLanGui',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.QL_ToaThuoc_LienThongLanGui(
        ID BIGINT IDENTITY PRIMARY KEY,
        IDCSKCB BIGINT NOT NULL,
        IDPayload BIGINT NOT NULL,
        IdempotencyKey UNIQUEIDENTIFIER NOT NULL,
        TrangThai NVARCHAR(30) NOT NULL DEFAULT N'DANG_GUI',
        HttpStatus INT NULL,
        MaKetQua NVARCHAR(100) NULL,
        PhanHoiDaLoc NVARCHAR(MAX) NULL,
        LoiCuoi NVARCHAR(1000) NULL,
        IDNhanVienYeuCau BIGINT NULL,
        IDTaiKhoanYeuCau BIGINT NOT NULL,
        BatDauLuc DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
        KetThucLuc DATETIME2(0) NULL,
        CONSTRAINT UQ_QL_LTTT_LanGui_Key UNIQUE(IdempotencyKey),
        CONSTRAINT FK_QL_LTTT_LanGui_Payload FOREIGN KEY(IDCSKCB,IDPayload) REFERENCES dbo.QL_ToaThuoc_LienThongPayload(IDCSKCB,ID),
        CONSTRAINT FK_QL_LTTT_LanGui_TaiKhoan FOREIGN KEY(IDTaiKhoanYeuCau) REFERENCES dbo.HT_Tai_Khoan(ID),
        CONSTRAINT FK_QL_LTTT_LanGui_NhanVien FOREIGN KEY(IDNhanVienYeuCau) REFERENCES dbo.DM_NhanVien(ID),
        CONSTRAINT CK_QL_LTTT_LanGui_TrangThai CHECK(TrangThai IN(N'DANG_GUI',N'THANH_CONG',N'TU_CHOI',N'LOI_GUI',N'KHONG_RO_KET_QUA'))
    );
    CREATE INDEX IX_QL_LTTT_LanGui_Payload ON dbo.QL_ToaThuoc_LienThongLanGui(IDCSKCB,IDPayload,ID DESC);
END;
GO
-- Authorization is independent of the prescribing doctor. The actor must be an
-- active account with Sua in this tenant, or a real global administrator.
CREATE OR ALTER PROCEDURE dbo.STO_QL_ToaThuoc_LienThong_KiemTra
    @IDCSKCB BIGINT,@IDToaThuoc BIGINT,@IDTaiKhoan BIGINT,@IDNhanVien BIGINT=NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS(SELECT 1 FROM dbo.HT_Tai_Khoan T WHERE T.ID=@IDTaiKhoan AND T.Active=1 AND
        (T.LaQuanTriHeThong=1 OR (T.IDCSKCB=@IDCSKCB AND ISNULL(T.IDNhanVien,0)=ISNULL(@IDNhanVien,0)
        AND EXISTS(SELECT 1 FROM dbo.HT_Tai_Khoan_Vai_Tro TV
            JOIN dbo.DM_Vai_Tro V ON V.ID=TV.ID_Vai_Tro AND V.IDCSKCB=TV.IDCSKCB AND V.Active=1
            JOIN dbo.HT_Quyen_Vai_Tro Q ON Q.IDCSKCB=TV.IDCSKCB AND Q.ID_Vai_Tro=TV.ID_Vai_Tro AND Q.Sua=1
            JOIN dbo.HT_Chuc_Nang F ON F.IDCSKCB=Q.IDCSKCB AND F.ID=Q.ID_Chuc_Nang AND F.Active=1
            WHERE TV.IDCSKCB=@IDCSKCB AND TV.ID_Tai_Khoan=T.ID AND TV.Active=1 AND F.Ma_Chuc_Nang=N'lien_thong_toa_thuoc'))))
        THROW 59201,N'Tai khoan khong co quyen lien thong tai co so nay.',1;
    DECLARE @State NVARCHAR(30),@Visit BIGINT,@Doctor BIGINT;
    SELECT @State=TrangThai,@Visit=IDVaoVien,@Doctor=IDBacSiKe FROM dbo.QL_ToaThuoc
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDToaThuoc;
    IF @Visit IS NULL THROW 59202,N'Khong tim thay toa thuoc trong co so.',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.QL_VaoVien WHERE IDCSKCB=@IDCSKCB AND ID=@Visit AND Active=1 AND TrangThaiKham=2)
        THROW 59203,N'Phai Kham xong truoc khi lien thong.',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.DM_NhanVien N JOIN dbo.DM_NhanVien_CSKCB M ON M.IDNhanVien=N.ID
        WHERE N.ID=@Doctor AND N.Active=1 AND N.LaBacSi=1 AND M.IDCSKCB=@IDCSKCB AND M.Active=1)
        THROW 59203,N'Bac si ke toa khong con hoat dong tai co so.',1;
    IF @State IN(N'CHO_GUI',N'DANG_GUI',N'THANH_CONG',N'KHONG_RO_KET_QUA')
        OR EXISTS(SELECT 1 FROM dbo.QL_ToaThuoc_LanGui L JOIN dbo.QL_ToaThuoc_PhienBan P ON P.ID=L.IDToaThuocPhienBan AND P.IDCSKCB=L.IDCSKCB
            WHERE P.IDCSKCB=@IDCSKCB AND P.IDToaThuoc=@IDToaThuoc AND L.TrangThai IN(N'CHO_GUI',N'DANG_GUI',N'THANH_CONG',N'KHONG_RO_KET_QUA'))
        OR EXISTS(SELECT 1 FROM dbo.QL_ToaThuoc_LienThongLanGui L JOIN dbo.QL_ToaThuoc_LienThongPayload P ON P.ID=L.IDPayload AND P.IDCSKCB=L.IDCSKCB
            WHERE P.IDCSKCB=@IDCSKCB AND P.IDToaThuoc=@IDToaThuoc AND L.TrangThai IN(N'DANG_GUI',N'THANH_CONG',N'KHONG_RO_KET_QUA'))
        THROW 59204,N'Toa da gui, dang gui hoac chua ro ket qua; khong duoc gui trung.',1;
END;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_ToaThuoc_LienThong_BatDau
    @IDCSKCB BIGINT,@IDToaThuoc BIGINT,@IDTaiKhoan BIGINT,@IDNhanVien BIGINT=NULL,
    @PhienBanNguon BIGINT,@JsonPayload NVARCHAR(MAX),@Sha256Json CHAR(64),@IdempotencyKey UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @Visit BIGINT,@Doctor BIGINT,@State NVARCHAR(30),@Revision BIGINT,@Payload BIGINT,@Attempt BIGINT;
        SELECT @Visit=IDVaoVien,@Doctor=IDBacSiKe,@State=TrangThai FROM dbo.QL_ToaThuoc WITH(UPDLOCK,HOLDLOCK)
            WHERE IDCSKCB=@IDCSKCB AND ID=@IDToaThuoc;
        EXEC dbo.STO_QL_ToaThuoc_LienThong_KiemTra @IDCSKCB,@IDToaThuoc,@IDTaiKhoan,@IDNhanVien;
        SELECT @Revision=PhienBanLamSang FROM dbo.QL_VaoVien WITH(UPDLOCK,HOLDLOCK) WHERE IDCSKCB=@IDCSKCB AND ID=@Visit;
        IF @Revision<>@PhienBanNguon THROW 59205,N'Toa vua thay doi; phai tao lai payload.',1;
        IF ISJSON(@JsonPayload)<>1 OR ISNULL(JSON_VALUE(@JsonPayload,'$.signature'),N'NOT_EMPTY')<>N''
            OR JSON_VALUE(@JsonPayload,'$.ma_don_thuoc')<>(SELECT MaToaQuocGia FROM dbo.QL_ToaThuoc WHERE IDCSKCB=@IDCSKCB AND ID=@IDToaThuoc)
            THROW 59205,N'Payload lien thong khong hop le.',1;
        INSERT dbo.QL_ToaThuoc_LienThongPayload(IDCSKCB,IDToaThuoc,IDBacSiKe,PhienBanNguon,JsonPayload,Sha256Json)
            VALUES(@IDCSKCB,@IDToaThuoc,@Doctor,@PhienBanNguon,@JsonPayload,@Sha256Json);
        SET @Payload=SCOPE_IDENTITY();
        INSERT dbo.QL_ToaThuoc_LienThongLanGui(IDCSKCB,IDPayload,IdempotencyKey,IDNhanVienYeuCau,IDTaiKhoanYeuCau)
            VALUES(@IDCSKCB,@Payload,@IdempotencyKey,@IDNhanVien,@IDTaiKhoan);
        SET @Attempt=SCOPE_IDENTITY();
        UPDATE dbo.QL_ToaThuoc SET TrangThai=N'DANG_GUI',NgayCapNhat=SYSDATETIME() WHERE IDCSKCB=@IDCSKCB AND ID=@IDToaThuoc;
        INSERT dbo.QL_ToaThuoc_Audit(IDCSKCB,IDToaThuoc,HanhDong,TrangThaiTu,TrangThaiDen,IDNhanVien,IDTaiKhoan)
            VALUES(@IDCSKCB,@IDToaThuoc,N'LIEN_THONG_TRUC_TIEP',@State,N'DANG_GUI',@IDNhanVien,@IDTaiKhoan);
        COMMIT;
        SELECT @Attempt AS IDLanGui;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_ToaThuoc_LienThong_KetQua
    @IDCSKCB BIGINT,@IDLanGui BIGINT,@TrangThai NVARCHAR(30),@HttpStatus INT=NULL,
    @MaKetQua NVARCHAR(100)=NULL,@PhanHoiDaLoc NVARCHAR(MAX)=NULL,@LoiCuoi NVARCHAR(1000)=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @TrangThai NOT IN(N'THANH_CONG',N'TU_CHOI',N'LOI_GUI',N'KHONG_RO_KET_QUA') THROW 59205,N'Trang thai ket qua khong hop le.',1;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- Same lock order as BatDau and clinical triggers: header, then attempt.
        DECLARE @Toa BIGINT,@Account BIGINT,@Actor BIGINT;
        SELECT @Toa=P.IDToaThuoc FROM dbo.QL_ToaThuoc_LienThongLanGui L
            JOIN dbo.QL_ToaThuoc_LienThongPayload P ON P.ID=L.IDPayload AND P.IDCSKCB=L.IDCSKCB
            WHERE L.IDCSKCB=@IDCSKCB AND L.ID=@IDLanGui;
        SELECT @Toa=ID FROM dbo.QL_ToaThuoc WITH(UPDLOCK,HOLDLOCK) WHERE IDCSKCB=@IDCSKCB AND ID=@Toa;
        SELECT @Account=IDTaiKhoanYeuCau,@Actor=IDNhanVienYeuCau FROM dbo.QL_ToaThuoc_LienThongLanGui WITH(UPDLOCK,HOLDLOCK)
            WHERE IDCSKCB=@IDCSKCB AND ID=@IDLanGui AND TrangThai=N'DANG_GUI';
        IF @Account IS NULL THROW 59204,N'Lan gui da ket thuc hoac khong ton tai.',1;
        UPDATE dbo.QL_ToaThuoc_LienThongLanGui SET TrangThai=@TrangThai,HttpStatus=@HttpStatus,MaKetQua=@MaKetQua,
            PhanHoiDaLoc=@PhanHoiDaLoc,LoiCuoi=LEFT(@LoiCuoi,1000),KetThucLuc=SYSDATETIME()
            WHERE IDCSKCB=@IDCSKCB AND ID=@IDLanGui;
        UPDATE dbo.QL_ToaThuoc SET TrangThai=@TrangThai,NgayCapNhat=SYSDATETIME() WHERE IDCSKCB=@IDCSKCB AND ID=@Toa;
        INSERT dbo.QL_ToaThuoc_Audit(IDCSKCB,IDToaThuoc,HanhDong,TrangThaiTu,TrangThaiDen,IDNhanVien,IDTaiKhoan,LyDo)
            VALUES(@IDCSKCB,@Toa,N'KET_QUA_LIEN_THONG_TRUC_TIEP',N'DANG_GUI',@TrangThai,@Actor,@Account,LEFT(@LoiCuoi,1000));
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_ToaThuoc_LienThong_DanhSach
    @IDCSKCB BIGINT,@TuNgay DATE,@DenNgay DATE,@TrangThai NVARCHAR(30)=NULL,
    @IDBacSi BIGINT=NULL,@MaToa NVARCHAR(100)=NULL,@MaVaoVien NVARCHAR(100)=NULL,@IDVaoVien BIGINT=NULL,
    @Trang INT=1,@KichThuocTrang INT=25
AS
BEGIN
    SET NOCOUNT ON;
    SET @Trang=CASE WHEN @Trang<1 THEN 1 ELSE @Trang END;
    SET @KichThuocTrang=CASE WHEN @KichThuocTrang<10 THEN 10 WHEN @KichThuocTrang>100 THEN 100 ELSE @KichThuocTrang END;
    SELECT H.ID AS id,H.IDVaoVien AS id_vao_vien,H.MaToaQuocGia AS ma_toa_quoc_gia,H.MaLoaiToaThuoc AS ma_loai_toa_thuoc,
        H.NgayKe AS ngay_ke,V.MaVaoVien AS ma_vao_vien,B.MaBn AS ma_benh_nhan,B.HoTen AS ho_ten,
        H.IDBacSiKe AS id_bac_si,N.HoTen AS bac_si,H.TrangThai AS trang_thai,
        CONVERT(BIT,CASE WHEN H.TrangThai=N'THANH_CONG' OR EXISTS(SELECT 1 FROM dbo.QL_ToaThuoc_PhienBan P
            JOIN dbo.QL_ToaThuoc_LanGui LG ON LG.IDCSKCB=P.IDCSKCB AND LG.IDToaThuocPhienBan=P.ID
            WHERE P.IDCSKCB=H.IDCSKCB AND P.IDToaThuoc=H.ID AND LG.TrangThai=N'THANH_CONG') THEN 1 ELSE 0 END) AS da_lien_thong,
        COALESCE(D.PhanHoiDaLoc,L.PhanHoiDaLoc) AS phan_hoi,COALESCE(D.LoiCuoi,L.LoiCuoi) AS loi_cuoi,
        CONVERT(BIT,CASE WHEN D.ID IS NOT NULL OR L.ID IS NOT NULL THEN 1 ELSE 0 END) AS co_phan_hoi
    INTO #DanhSach
    FROM dbo.QL_ToaThuoc H JOIN dbo.QL_VaoVien V ON V.IDCSKCB=H.IDCSKCB AND V.ID=H.IDVaoVien
    JOIN dbo.QL_BenhNhan B ON B.IDCSKCB=V.IDCSKCB AND B.ID=V.IDBenhNhan JOIN dbo.DM_NhanVien N ON N.ID=H.IDBacSiKe
    OUTER APPLY(SELECT TOP(1) A.ID,A.PhanHoiDaLoc,A.LoiCuoi FROM dbo.QL_ToaThuoc_LienThongPayload P
        JOIN dbo.QL_ToaThuoc_LienThongLanGui A ON A.IDCSKCB=P.IDCSKCB AND A.IDPayload=P.ID
        WHERE P.IDCSKCB=H.IDCSKCB AND P.IDToaThuoc=H.ID ORDER BY A.ID DESC) D
    OUTER APPLY(SELECT TOP(1) A.ID,A.PhanHoiDaLoc,A.LoiCuoi FROM dbo.QL_ToaThuoc_PhienBan P
        JOIN dbo.QL_ToaThuoc_LanGui A ON A.IDCSKCB=P.IDCSKCB AND A.IDToaThuocPhienBan=P.ID
        WHERE P.IDCSKCB=H.IDCSKCB AND P.IDToaThuoc=H.ID ORDER BY A.ID DESC) L
    WHERE H.IDCSKCB=@IDCSKCB AND V.Active=1 AND V.TrangThaiKham=2 AND H.NgayKe BETWEEN @TuNgay AND @DenNgay
        AND (@IDBacSi IS NULL OR H.IDBacSiKe=@IDBacSi)
        AND (@IDVaoVien IS NULL OR H.IDVaoVien=@IDVaoVien)
        AND (NULLIF(@MaToa,N'') IS NULL OR CHARINDEX(@MaToa,H.MaToaQuocGia)>0)
        AND (NULLIF(@MaVaoVien,N'') IS NULL OR CHARINDEX(@MaVaoVien,V.MaVaoVien)>0);
    SELECT COUNT(*) AS tong_so FROM #DanhSach WHERE NULLIF(@TrangThai,N'') IS NULL
        OR (@TrangThai=N'DA_LIEN_THONG' AND da_lien_thong=1) OR (@TrangThai=N'CHUA_LIEN_THONG' AND da_lien_thong=0);
    SELECT * FROM #DanhSach WHERE NULLIF(@TrangThai,N'') IS NULL
        OR (@TrangThai=N'DA_LIEN_THONG' AND da_lien_thong=1) OR (@TrangThai=N'CHUA_LIEN_THONG' AND da_lien_thong=0)
    ORDER BY ngay_ke DESC,id DESC OFFSET (@Trang-1)*@KichThuocTrang ROWS FETCH NEXT @KichThuocTrang ROWS ONLY;
END;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_ToaThuoc_LienThong_PhanHoi
    @IDCSKCB BIGINT,@IDToaThuoc BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP(20) * FROM (
        SELECT L.ID AS id_lan_gui,N'TRUC_TIEP' AS nguon,L.TrangThai AS trang_thai,L.HttpStatus AS http_status,
            L.MaKetQua AS ma_ket_qua,L.PhanHoiDaLoc AS phan_hoi,L.LoiCuoi AS loi_cuoi,L.BatDauLuc AS bat_dau_luc,L.KetThucLuc AS ket_thuc_luc
        FROM dbo.QL_ToaThuoc_LienThongLanGui L JOIN dbo.QL_ToaThuoc_LienThongPayload P ON P.ID=L.IDPayload AND P.IDCSKCB=L.IDCSKCB
        WHERE P.IDCSKCB=@IDCSKCB AND P.IDToaThuoc=@IDToaThuoc
        UNION ALL
        SELECT L.ID,N'PHIEN_BAN_CU',L.TrangThai,L.HttpStatus,L.MaKetQua,L.PhanHoiDaLoc,L.LoiCuoi,L.BatDauLuc,L.KetThucLuc
        FROM dbo.QL_ToaThuoc_LanGui L JOIN dbo.QL_ToaThuoc_PhienBan P ON P.ID=L.IDToaThuocPhienBan AND P.IDCSKCB=L.IDCSKCB
        WHERE P.IDCSKCB=@IDCSKCB AND P.IDToaThuoc=@IDToaThuoc
    ) H ORDER BY bat_dau_luc DESC,id_lan_gui DESC;
END;
GO
PRINT N'49_lien_thong_toa_thuoc_truc_tiep_v108.sql: prepared; no operational prescriptions sent.';
GO
