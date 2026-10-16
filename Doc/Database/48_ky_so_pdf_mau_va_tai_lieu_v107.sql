:ON ERROR EXIT
USE [QLPM];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.DM_CSKCB',N'U') IS NULL OR OBJECT_ID(N'dbo.QL_VaoVien',N'U') IS NULL
    OR OBJECT_ID(N'dbo.QL_ToaThuoc',N'U') IS NULL
    THROW 59201,N'Chua co schema luot kham, toa thuoc va co so KCB. Chay v104 truoc.',1;
GO

/* Mau vi tri ky theo tung co so: file PDF A5 tham chieu kysochidinh, kysotoathuoc.
   Toa do PDF goc duoi-trai, don vi point; khong dong nghia co chu ky that. */
IF OBJECT_ID(N'dbo.HT_KySoPdf_Mau',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.HT_KySoPdf_Mau
    (
        IDCSKCB BIGINT NOT NULL,
        MaLoai NVARCHAR(30) NOT NULL,
        TrangKy INT NOT NULL CONSTRAINT DF_HT_KySoPdf_TrangKy DEFAULT(1),
        X1 DECIMAL(9,2) NOT NULL, Y1 DECIMAL(9,2) NOT NULL,
        X2 DECIMAL(9,2) NOT NULL, Y2 DECIMAL(9,2) NOT NULL,
        NgayCapNhat DATETIME2(0) NOT NULL CONSTRAINT DF_HT_KySoPdf_NgayCapNhat DEFAULT(SYSDATETIME()),
        CONSTRAINT PK_HT_KySoPdf_Mau PRIMARY KEY(IDCSKCB,MaLoai),
        CONSTRAINT FK_HT_KySoPdf_Mau_CSKCB FOREIGN KEY(IDCSKCB) REFERENCES dbo.DM_CSKCB(ID),
        CONSTRAINT CK_HT_KySoPdf_Loai CHECK(MaLoai IN(N'toa_thuoc',N'chi_dinh')),
        CONSTRAINT CK_HT_KySoPdf_ViTri CHECK(
            TrangKy BETWEEN 1 AND 100 AND X1>=0 AND Y1>=0 AND X2>X1 AND Y2>Y1
            AND X2<=420 AND Y2<=596)
    );
END;
GO

/* Chi them mau chua co; KHONG ghi de toa do do CSKCB da sua khi chay lai updater. */
INSERT dbo.HT_KySoPdf_Mau(IDCSKCB,MaLoai,TrangKy,X1,Y1,X2,Y2)
SELECT C.ID,V.MaLoai,1,V.X1,V.Y1,V.X2,V.Y2
FROM dbo.DM_CSKCB C
CROSS JOIN
(
    VALUES
    (N'toa_thuoc',CONVERT(DECIMAL(9,2),266),CONVERT(DECIMAL(9,2),193),CONVERT(DECIMAL(9,2),406),CONVERT(DECIMAL(9,2),238)),
    (N'chi_dinh',CONVERT(DECIMAL(9,2),249),CONVERT(DECIMAL(9,2),200),CONVERT(DECIMAL(9,2),389),CONVERT(DECIMAL(9,2),245))
) V(MaLoai,X1,Y1,X2,Y2)
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.HT_KySoPdf_Mau M
    WHERE M.IDCSKCB=C.ID AND M.MaLoai=V.MaLoai
);
GO

/* Luu tru cho chu ky thuc trong tuong lai. Dry-run KHONG duoc insert vao bang nay. */
IF OBJECT_ID(N'dbo.QL_KySoPdf_TaiLieu',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.QL_KySoPdf_TaiLieu
    (
        ID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_QL_KySoPdf_TaiLieu PRIMARY KEY,
        IDCSKCB BIGINT NOT NULL,
        IDVaoVien BIGINT NOT NULL,
        IDToaThuoc BIGINT NULL,
        MaLoai NVARCHAR(30) NOT NULL,
        NhomChiDinh TINYINT NULL, -- 0 noi bo, 1 gui ngoai; NULL cho toa thuoc
        SoPhienBan INT NOT NULL,
        PhienBanLamSang BIGINT NOT NULL,
        TrangThai NVARCHAR(30) NOT NULL,
        PdfNguon VARBINARY(MAX) NOT NULL,
        PdfDaKy VARBINARY(MAX) NOT NULL,
        Sha256Nguon CHAR(64) NOT NULL,
        Sha256DaKy CHAR(64) NOT NULL,
        NhaCungCapKy NVARCHAR(120) NULL,
        SerialChungThu NVARCHAR(200) NULL,
        MaHoSoKy NVARCHAR(200) NULL,
        NgayKy DATETIME2(0) NOT NULL,
        IDBacSiKy BIGINT NOT NULL,
        IDTaiKhoanKy BIGINT NOT NULL,
        NgayTao DATETIME2(0) NOT NULL CONSTRAINT DF_QL_KySoPdf_TL_NgayTao DEFAULT(SYSDATETIME()),
        CONSTRAINT CK_QL_KySoPdf_TL_Loai CHECK(MaLoai IN(N'toa_thuoc',N'chi_dinh')),
        CONSTRAINT CK_QL_KySoPdf_TL_TrangThai CHECK(TrangThai IN(N'DA_KY',N'HET_HIEU_LUC')),
        CONSTRAINT CK_QL_KySoPdf_TL_Nhom CHECK(
            (MaLoai=N'toa_thuoc' AND IDToaThuoc IS NOT NULL AND NhomChiDinh IS NULL) OR
            (MaLoai=N'chi_dinh' AND IDToaThuoc IS NULL AND NhomChiDinh IN(0,1))),
        CONSTRAINT CK_QL_KySoPdf_TL_Hash CHECK(LEN(Sha256Nguon)=64 AND LEN(Sha256DaKy)=64),
        CONSTRAINT FK_QL_KySoPdf_TL_VaoVien FOREIGN KEY(IDCSKCB,IDVaoVien)
            REFERENCES dbo.QL_VaoVien(IDCSKCB,ID),
        CONSTRAINT FK_QL_KySoPdf_TL_Toa FOREIGN KEY(IDCSKCB,IDToaThuoc)
            REFERENCES dbo.QL_ToaThuoc(IDCSKCB,ID),
        CONSTRAINT FK_QL_KySoPdf_TL_NhanVien FOREIGN KEY(IDBacSiKy) REFERENCES dbo.DM_NhanVien(ID),
        CONSTRAINT FK_QL_KySoPdf_TL_TaiKhoan FOREIGN KEY(IDTaiKhoanKy) REFERENCES dbo.HT_Tai_Khoan(ID)
    );
    CREATE INDEX IX_QL_KySoPdf_TL_Luot ON dbo.QL_KySoPdf_TaiLieu
        (IDCSKCB,IDVaoVien,MaLoai,NgayKy DESC);
END;
GO

IF OBJECT_ID(N'dbo.QL_KySoPdf_Audit',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.QL_KySoPdf_Audit
    (
        ID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_QL_KySoPdf_Audit PRIMARY KEY,
        IDCSKCB BIGINT NOT NULL,
        IDVaoVien BIGINT NOT NULL,
        MaLoai NVARCHAR(30) NOT NULL,
        HanhDong NVARCHAR(60) NOT NULL,
        IDTaiLieu BIGINT NULL,
        IDNhanVien BIGINT NULL,
        IDTaiKhoan BIGINT NULL,
        MaKetQua NVARCHAR(60) NULL,
        Sha256Pdf CHAR(64) NULL,
        NgayTao DATETIME2(0) NOT NULL CONSTRAINT DF_QL_KySoPdf_Audit_Ngay DEFAULT(SYSDATETIME()),
        CONSTRAINT FK_QL_KySoPdf_Audit_CSKCB FOREIGN KEY(IDCSKCB) REFERENCES dbo.DM_CSKCB(ID),
        CONSTRAINT FK_QL_KySoPdf_Audit_TaiLieu FOREIGN KEY(IDTaiLieu) REFERENCES dbo.QL_KySoPdf_TaiLieu(ID)
    );
    CREATE INDEX IX_QL_KySoPdf_Audit_Luot ON dbo.QL_KySoPdf_Audit(IDCSKCB,IDVaoVien,NgayTao DESC);
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_KySoPdf_Mau_DanhSach @IDCSKCB BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT MaLoai AS ma_loai,TrangKy AS trang_ky,
        X1 AS x1,Y1 AS y1,X2 AS x2,Y2 AS y2,NgayCapNhat AS ngay_cap_nhat
    FROM dbo.HT_KySoPdf_Mau
    WHERE IDCSKCB=@IDCSKCB
    ORDER BY CASE WHEN MaLoai=N'toa_thuoc' THEN 0 ELSE 1 END;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_KySoPdf_Mau_Lay
    @IDCSKCB BIGINT,@MaLoai NVARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TrangKy AS trang_ky, X1 AS x1,Y1 AS y1,X2 AS x2,Y2 AS y2,
        N'['+CONVERT(NVARCHAR(30),X1)+N', '+CONVERT(NVARCHAR(30),Y1)
        +N', '+CONVERT(NVARCHAR(30),X2)+N', '+CONVERT(NVARCHAR(30),Y2)+N']' AS rect
    FROM dbo.HT_KySoPdf_Mau
    WHERE IDCSKCB=@IDCSKCB AND MaLoai=@MaLoai;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_KySoPdf_Mau_Luu
    @IDCSKCB BIGINT,@MaLoai NVARCHAR(30),@TrangKy INT,
    @X1 DECIMAL(9,2),@Y1 DECIMAL(9,2),@X2 DECIMAL(9,2),@Y2 DECIMAL(9,2)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @MaLoai NOT IN(N'toa_thuoc',N'chi_dinh')
        OR @TrangKy NOT BETWEEN 1 AND 100 OR @X1<0 OR @Y1<0
        OR @X2<=@X1 OR @Y2<=@Y1 OR @X2>420 OR @Y2>596
        THROW 59205,N'Toa do ky PDF A5 khong hop le.',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.DM_CSKCB WHERE ID=@IDCSKCB)
        THROW 59206,N'Co so KCB khong hop le.',1;

    BEGIN TRANSACTION;
    UPDATE dbo.HT_KySoPdf_Mau WITH(UPDLOCK,HOLDLOCK)
       SET TrangKy=@TrangKy,X1=@X1,Y1=@Y1,X2=@X2,Y2=@Y2,NgayCapNhat=SYSDATETIME()
    WHERE IDCSKCB=@IDCSKCB AND MaLoai=@MaLoai;
    IF @@ROWCOUNT=0
    BEGIN
        INSERT dbo.HT_KySoPdf_Mau(IDCSKCB,MaLoai,TrangKy,X1,Y1,X2,Y2)
        VALUES(@IDCSKCB,@MaLoai,@TrangKy,@X1,@Y1,@X2,@Y2);
    END;
    COMMIT;
    SELECT 200 AS Status,N'Da luu mau ky PDF.' AS Message;
END;
GO

PRINT N'48_ky_so_pdf_mau_va_tai_lieu_v107.sql: OK.';
GO
