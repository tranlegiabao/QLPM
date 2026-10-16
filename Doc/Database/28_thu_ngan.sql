/*
28_thu_ngan.sql
Thu ngân: chỉ thu sau khi khám xong, một phiếu thu cho mỗi IDVaoVien.
Trạng thái UI chỉ có:
- NULL = Tất cả
- 0 = Chưa thu (gồm chưa thu gì hoặc mới thu một phần)
- 1 = Đã thu (toàn bộ khoản đã được thu)
Hủy thu là thao tác hoàn tác DaThu về 0; lịch sử hủy vẫn được lưu để audit, không tạo trạng thái UI riêng.
*/

IF DB_NAME()<>N'QLPM'
    THROW 59000,N'Script thu ngân chỉ được chạy trên database QLPM.',1;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.sequences
    WHERE schema_id=SCHEMA_ID(N'dbo') AND name=N'SEQ_SoPhieuThu'
)
    EXEC(N'CREATE SEQUENCE dbo.SEQ_SoPhieuThu AS BIGINT START WITH 1 INCREMENT BY 1;');
GO

IF COL_LENGTH(N'dbo.QL_ThuTien',N'IDTaiKhoanThu') IS NULL
    ALTER TABLE dbo.QL_ThuTien ADD IDTaiKhoanThu BIGINT NULL;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.foreign_keys
    WHERE parent_object_id=OBJECT_ID(N'dbo.QL_ThuTien')
      AND name=N'FK_QL_ThuTien_TaiKhoanThu'
)
    ALTER TABLE dbo.QL_ThuTien WITH CHECK
        ADD CONSTRAINT FK_QL_ThuTien_TaiKhoanThu
        FOREIGN KEY(IDTaiKhoanThu) REFERENCES dbo.HT_Tai_Khoan(ID)
        ON DELETE SET NULL;
GO

IF OBJECT_ID(N'dbo.QL_ThuTien_LichSu',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.QL_ThuTien_LichSu
    (
        ID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_QL_ThuTien_LichSu PRIMARY KEY,
        IDCSKCB BIGINT NOT NULL,
        IDThuTien BIGINT NOT NULL,
        IDVaoVien BIGINT NOT NULL,
        HanhDong NVARCHAR(20) NOT NULL,
        SoPhieu NVARCHAR(30) NULL,
        NgayGio DATETIME2(0) NOT NULL CONSTRAINT DF_QL_ThuTien_LichSu_Ngay DEFAULT(SYSDATETIME()),
        IDNhanVien BIGINT NULL,
        IDTaiKhoan BIGINT NULL,
        TongTien DECIMAL(18,2) NOT NULL CONSTRAINT DF_QL_ThuTien_LichSu_Tong DEFAULT(0),
        TienGiam DECIMAL(18,2) NOT NULL CONSTRAINT DF_QL_ThuTien_LichSu_Giam DEFAULT(0),
        ThucThu DECIMAL(18,2) NOT NULL CONSTRAINT DF_QL_ThuTien_LichSu_Thu DEFAULT(0),
        TienMat DECIMAL(18,2) NOT NULL CONSTRAINT DF_QL_ThuTien_LichSu_TM DEFAULT(0),
        ChuyenKhoan DECIMAL(18,2) NOT NULL CONSTRAINT DF_QL_ThuTien_LichSu_CK DEFAULT(0),
        IDNganHang BIGINT NULL,
        GhiChu NVARCHAR(500) NULL,
        CONSTRAINT CK_QL_ThuTien_LichSu_HanhDong CHECK(HanhDong IN(N'THU',N'HUY')),
        CONSTRAINT FK_QL_ThuTien_LichSu_Thu FOREIGN KEY(IDCSKCB,IDThuTien) REFERENCES dbo.QL_ThuTien(IDCSKCB,ID),
        CONSTRAINT FK_QL_ThuTien_LichSu_VV FOREIGN KEY(IDCSKCB,IDVaoVien) REFERENCES dbo.QL_VaoVien(IDCSKCB,ID),
        CONSTRAINT FK_QL_ThuTien_LichSu_NV FOREIGN KEY(IDNhanVien) REFERENCES dbo.DM_NhanVien(ID),
        CONSTRAINT FK_QL_ThuTien_LichSu_TK FOREIGN KEY(IDTaiKhoan) REFERENCES dbo.HT_Tai_Khoan(ID) ON DELETE SET NULL,
        CONSTRAINT FK_QL_ThuTien_LichSu_NH FOREIGN KEY(IDNganHang) REFERENCES dbo.DM_NganHang(ID)
    );
    CREATE INDEX IX_QL_ThuTien_LichSu_VV ON dbo.QL_ThuTien_LichSu(IDCSKCB,IDVaoVien,NgayGio DESC,ID DESC);
END;
GO

IF COL_LENGTH(N'dbo.QL_ThuTien_LichSu',N'IDTaiKhoan') IS NULL
    ALTER TABLE dbo.QL_ThuTien_LichSu ADD IDTaiKhoan BIGINT NULL;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.foreign_keys
    WHERE parent_object_id=OBJECT_ID(N'dbo.QL_ThuTien_LichSu')
      AND name=N'FK_QL_ThuTien_LichSu_TK'
)
    ALTER TABLE dbo.QL_ThuTien_LichSu WITH CHECK
        ADD CONSTRAINT FK_QL_ThuTien_LichSu_TK
        FOREIGN KEY(IDTaiKhoan) REFERENCES dbo.HT_Tai_Khoan(ID)
        ON DELETE SET NULL;
GO

/* Backfill actor account cho dữ liệu thu cũ theo nhân viên + CSKCB.
   Global admin trước v91 không thể thu vì controller đã chặn IDNhanVien=0. */
UPDATE T
SET IDTaiKhoanThu=A.ID
FROM dbo.QL_ThuTien T
OUTER APPLY
(
    SELECT TOP(1) TK.ID
    FROM dbo.HT_Tai_Khoan TK
    WHERE TK.IDNhanVien=T.IDNhanVienThu
      AND TK.IDCSKCB=T.IDCSKCB
    ORDER BY CASE WHEN TK.Active=1 THEN 0 ELSE 1 END,TK.ID DESC
) A
WHERE T.IDTaiKhoanThu IS NULL
  AND T.IDNhanVienThu IS NOT NULL
  AND A.ID IS NOT NULL;
GO

UPDATE L
SET IDTaiKhoan=COALESCE(T.IDTaiKhoanThu,A.ID)
FROM dbo.QL_ThuTien_LichSu L
LEFT JOIN dbo.QL_ThuTien T
  ON T.IDCSKCB=L.IDCSKCB AND T.ID=L.IDThuTien
OUTER APPLY
(
    SELECT TOP(1) TK.ID
    FROM dbo.HT_Tai_Khoan TK
    WHERE TK.IDNhanVien=L.IDNhanVien
      AND (TK.IDCSKCB=L.IDCSKCB OR TK.IDCSKCB IS NULL)
    ORDER BY CASE WHEN TK.Active=1 THEN 0 ELSE 1 END,TK.ID DESC
) A
WHERE L.IDTaiKhoan IS NULL
  AND COALESCE(T.IDTaiKhoanThu,A.ID) IS NOT NULL;
GO

/* Điều chỉnh thu ngân theo đúng HIS: phụ thu là tiền; giảm là tỷ lệ %. */
IF COL_LENGTH(N'dbo.QL_ThuTien_CT',N'PhuThu') IS NULL
    ALTER TABLE dbo.QL_ThuTien_CT
        ADD PhuThu DECIMAL(18,2) NOT NULL
            CONSTRAINT DF_QL_ThuTien_CT_PhuThu DEFAULT(0);
GO

IF COL_LENGTH(N'dbo.QL_ThuTien_CT',N'GiamPhanTram') IS NULL
    ALTER TABLE dbo.QL_ThuTien_CT
        ADD GiamPhanTram DECIMAL(5,2) NOT NULL
            CONSTRAINT DF_QL_ThuTien_CT_GiamPhanTram DEFAULT(0);
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id=OBJECT_ID(N'dbo.QL_ThuTien_CT')
      AND name=N'CK_QL_ThuTien_CT_GiamPhanTram'
)
    ALTER TABLE dbo.QL_ThuTien_CT WITH CHECK
        ADD CONSTRAINT CK_QL_ThuTien_CT_GiamPhanTram
        CHECK(GiamPhanTram>=0 AND GiamPhanTram<=100);
GO

IF COL_LENGTH(N'dbo.QL_ThuTien_CT',N'DaHuy') IS NULL
    ALTER TABLE dbo.QL_ThuTien_CT
        ADD DaHuy BIT NOT NULL
            CONSTRAINT DF_QL_ThuTien_CT_DaHuy DEFAULT(0);
GO

IF COL_LENGTH(N'dbo.QL_ThuTien_CT',N'NgayGioHuy') IS NULL
    ALTER TABLE dbo.QL_ThuTien_CT ADD NgayGioHuy DATETIME2(0) NULL;
GO

IF COL_LENGTH(N'dbo.QL_ThuTien_CT',N'IDNhanVienHuy') IS NULL
    ALTER TABLE dbo.QL_ThuTien_CT ADD IDNhanVienHuy BIGINT NULL;
GO

IF COL_LENGTH(N'dbo.QL_ThuTien_CT',N'IDTaiKhoanHuy') IS NULL
    ALTER TABLE dbo.QL_ThuTien_CT ADD IDTaiKhoanHuy BIGINT NULL;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.foreign_keys
    WHERE parent_object_id=OBJECT_ID(N'dbo.QL_ThuTien_CT')
      AND name=N'FK_QL_ThuTienCT_NhanVienHuy'
)
    ALTER TABLE dbo.QL_ThuTien_CT WITH CHECK
        ADD CONSTRAINT FK_QL_ThuTienCT_NhanVienHuy
        FOREIGN KEY(IDNhanVienHuy) REFERENCES dbo.DM_NhanVien(ID);
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.foreign_keys
    WHERE parent_object_id=OBJECT_ID(N'dbo.QL_ThuTien_CT')
      AND name=N'FK_QL_ThuTienCT_TaiKhoanHuy'
)
    ALTER TABLE dbo.QL_ThuTien_CT WITH CHECK
        ADD CONSTRAINT FK_QL_ThuTienCT_TaiKhoanHuy
        FOREIGN KEY(IDTaiKhoanHuy) REFERENCES dbo.HT_Tai_Khoan(ID)
        ON DELETE SET NULL;
GO

IF EXISTS
(
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id=OBJECT_ID(N'dbo.QL_ThuTien_LichSu')
      AND name=N'CK_QL_ThuTien_LichSu_HanhDong'
)
    ALTER TABLE dbo.QL_ThuTien_LichSu DROP CONSTRAINT CK_QL_ThuTien_LichSu_HanhDong;
GO

ALTER TABLE dbo.QL_ThuTien_LichSu WITH CHECK
    ADD CONSTRAINT CK_QL_ThuTien_LichSu_HanhDong
    CHECK(HanhDong IN(N'THU',N'HUY',N'HUY_CHI_DINH',N'HUY_TOA_THUOC'));
GO

/* v93: Thu ngân chỉ còn Chưa thu / Đã thu.
   Dữ liệu từng được đánh dấu hủy được đưa về Chưa thu; lịch sử hủy vẫn giữ trong QL_ThuTien_LichSu. */
UPDATE dbo.QL_ThuTien_CT
SET DaThu=0,
    DaHuy=0
WHERE ISNULL(DaHuy,0)=1;
GO

UPDATE dbo.QL_ThuTien
SET DaHuy=0
WHERE ISNULL(DaHuy,0)=1;
GO

/* v94: lớp chứng từ bất biến cho từng lần thu/hoàn. QL_ThuTien tiếp tục là
   bảng tổng hợp theo lượt khám để giữ tương thích với dữ liệu và STO cũ. */
IF OBJECT_ID(N'dbo.QL_ThuTien_SoChungTu',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.QL_ThuTien_SoChungTu
    (
        IDCSKCB BIGINT NOT NULL,
        Nam SMALLINT NOT NULL,
        Loai VARCHAR(10) NOT NULL,
        SoCuoi BIGINT NOT NULL CONSTRAINT DF_QL_ThuTien_SoChungTu_SoCuoi DEFAULT(0),
        CONSTRAINT PK_QL_ThuTien_SoChungTu PRIMARY KEY(IDCSKCB,Nam,Loai),
        CONSTRAINT CK_QL_ThuTien_SoChungTu_Loai CHECK(Loai IN('THU','HOAN')),
        CONSTRAINT FK_QL_ThuTien_SoChungTu_CSKCB FOREIGN KEY(IDCSKCB) REFERENCES dbo.DM_CSKCB(ID)
    );
END;
GO

IF OBJECT_ID(N'dbo.QL_ThuTien_ChungTu',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.QL_ThuTien_ChungTu
    (
        ID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_QL_ThuTien_ChungTu PRIMARY KEY,
        IDCSKCB BIGINT NOT NULL, IDVaoVien BIGINT NOT NULL, IDThuTien BIGINT NOT NULL,
        Loai VARCHAR(10) NOT NULL, Nhom NVARCHAR(20) NULL, IDChungTuGoc BIGINT NULL, SoChungTu NVARCHAR(40) NOT NULL,
        NgayGio DATETIME2(0) NOT NULL CONSTRAINT DF_QL_ThuTien_ChungTu_NgayGio DEFAULT(SYSDATETIME()),
        IDNhanVien BIGINT NULL, IDTaiKhoan BIGINT NOT NULL,
        TongTien DECIMAL(18,2) NOT NULL, TienGiam DECIMAL(18,2) NOT NULL, ThucThu DECIMAL(18,2) NOT NULL,
        TienMat DECIMAL(18,2) NOT NULL, ChuyenKhoan DECIMAL(18,2) NOT NULL, IDNganHang BIGINT NULL,
        GhiChu NVARCHAR(500) NULL, TrangThai TINYINT NOT NULL CONSTRAINT DF_QL_ThuTien_ChungTu_TrangThai DEFAULT(1),
        LyDoHuy NVARCHAR(500) NULL, NgayGioHuy DATETIME2(0) NULL, IDNhanVienHuy BIGINT NULL, IDTaiKhoanHuy BIGINT NULL,
        CONSTRAINT UQ_QL_ThuTien_ChungTu_So UNIQUE(IDCSKCB,SoChungTu),
        CONSTRAINT CK_QL_ThuTien_ChungTu_Loai CHECK(Loai IN('THU','HOAN')),
        CONSTRAINT CK_QL_ThuTien_ChungTu_TrangThai CHECK(TrangThai IN(0,1)),
        CONSTRAINT CK_QL_ThuTien_ChungTu_Tien CHECK(TongTien>=0 AND TienGiam>=0 AND ThucThu>=0 AND TienMat>=0 AND ChuyenKhoan>=0 AND TienMat+ChuyenKhoan=ThucThu),
        CONSTRAINT FK_QL_ThuTien_ChungTu_ThuTien FOREIGN KEY(IDCSKCB,IDThuTien) REFERENCES dbo.QL_ThuTien(IDCSKCB,ID),
        CONSTRAINT FK_QL_ThuTien_ChungTu_VaoVien FOREIGN KEY(IDCSKCB,IDVaoVien) REFERENCES dbo.QL_VaoVien(IDCSKCB,ID),
        CONSTRAINT FK_QL_ThuTien_ChungTu_Goc FOREIGN KEY(IDChungTuGoc) REFERENCES dbo.QL_ThuTien_ChungTu(ID),
        CONSTRAINT FK_QL_ThuTien_ChungTu_NV FOREIGN KEY(IDNhanVien) REFERENCES dbo.DM_NhanVien(ID),
        CONSTRAINT FK_QL_ThuTien_ChungTu_TK FOREIGN KEY(IDTaiKhoan) REFERENCES dbo.HT_Tai_Khoan(ID),
        CONSTRAINT FK_QL_ThuTien_ChungTu_NH FOREIGN KEY(IDNganHang) REFERENCES dbo.DM_NganHang(ID),
        CONSTRAINT FK_QL_ThuTien_ChungTu_NVH FOREIGN KEY(IDNhanVienHuy) REFERENCES dbo.DM_NhanVien(ID),
        CONSTRAINT FK_QL_ThuTien_ChungTu_TKH FOREIGN KEY(IDTaiKhoanHuy) REFERENCES dbo.HT_Tai_Khoan(ID)
    );
    CREATE INDEX IX_QL_ThuTien_ChungTu_VaoVien ON dbo.QL_ThuTien_ChungTu(IDCSKCB,IDVaoVien,NgayGio DESC,ID DESC);
    CREATE UNIQUE INDEX UX_QL_ThuTien_ChungTu_HoanGoc ON dbo.QL_ThuTien_ChungTu(IDChungTuGoc) WHERE Loai='HOAN' AND TrangThai=1;
END;
GO

IF COL_LENGTH(N'dbo.QL_ThuTien_ChungTu',N'Nhom') IS NULL
    ALTER TABLE dbo.QL_ThuTien_ChungTu ADD Nhom NVARCHAR(20) NULL;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE parent_object_id=OBJECT_ID(N'dbo.QL_ThuTien_ChungTu')
      AND name=N'CK_QL_ThuTien_ChungTu_Nhom'
)
    ALTER TABLE dbo.QL_ThuTien_ChungTu WITH CHECK
        ADD CONSTRAINT CK_QL_ThuTien_ChungTu_Nhom
        CHECK(Nhom IN(N'CHI_DINH',N'TOA_THUOC'));
GO

IF OBJECT_ID(N'dbo.QL_ThuTien_ChungTu_CT',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.QL_ThuTien_ChungTu_CT
    (
        ID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_QL_ThuTien_ChungTu_CT PRIMARY KEY,
        IDChungTu BIGINT NOT NULL, IDThuTienCT BIGINT NOT NULL,
        Loai NVARCHAR(20) NOT NULL, Ma NVARCHAR(50) NULL, Ten NVARCHAR(500) NOT NULL, DonViTinh NVARCHAR(100) NULL,
        SoLuong DECIMAL(18,3) NOT NULL, DonGia DECIMAL(18,2) NOT NULL, ThanhTien DECIMAL(18,2) NOT NULL,
        PhuThu DECIMAL(18,2) NOT NULL, GiamPhanTram DECIMAL(5,2) NOT NULL, TienGiam DECIMAL(18,2) NOT NULL, ThanhToan DECIMAL(18,2) NOT NULL,
        CONSTRAINT FK_QL_ThuTien_ChungTu_CT_ChungTu FOREIGN KEY(IDChungTu) REFERENCES dbo.QL_ThuTien_ChungTu(ID),
        CONSTRAINT FK_QL_ThuTien_ChungTu_CT_ThuTienCT FOREIGN KEY(IDThuTienCT) REFERENCES dbo.QL_ThuTien_CT(ID),
        CONSTRAINT CK_QL_ThuTien_ChungTu_CT_Tien CHECK(SoLuong>=0 AND DonGia>=0 AND ThanhTien>=0 AND PhuThu>=0 AND GiamPhanTram BETWEEN 0 AND 100 AND TienGiam>=0 AND ThanhToan>=0)
    );
    CREATE INDEX IX_QL_ThuTien_ChungTu_CT_ChungTu ON dbo.QL_ThuTien_ChungTu_CT(IDChungTu,ID);
    CREATE INDEX IX_QL_ThuTien_ChungTu_CT_ThuTienCT ON dbo.QL_ThuTien_ChungTu_CT(IDThuTienCT,IDChungTu);
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_ThuNgan_CapSoChungTu
    @IDCSKCB BIGINT, @Loai VARCHAR(10), @SoChungTu NVARCHAR(40) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF @Loai NOT IN('THU','HOAN') THROW 58000,N'Loại chứng từ không hợp lệ.',1;
    DECLARE @Nam SMALLINT=YEAR(SYSDATETIME()),@So BIGINT,@MaCS NVARCHAR(10);
    SELECT @MaCS=UPPER(REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(MaCSKCB,N''))),N' ',N''),N'-',N''))
    FROM dbo.DM_CSKCB WITH(HOLDLOCK) WHERE ID=@IDCSKCB;
    IF NULLIF(@MaCS,N'') IS NULL SET @MaCS=N'CS'+RIGHT(N'00'+CONVERT(NVARCHAR(10),@IDCSKCB),2);
    SET @MaCS=LEFT(@MaCS,10);
    UPDATE dbo.QL_ThuTien_SoChungTu WITH(UPDLOCK,HOLDLOCK)
    SET @So=SoCuoi=SoCuoi+1 WHERE IDCSKCB=@IDCSKCB AND Nam=@Nam AND Loai=@Loai;
    IF @@ROWCOUNT=0 BEGIN
        INSERT dbo.QL_ThuTien_SoChungTu(IDCSKCB,Nam,Loai,SoCuoi) VALUES(@IDCSKCB,@Nam,@Loai,1);
        SET @So=1;
    END;
    SET @SoChungTu=CASE WHEN @Loai='THU' THEN N'PT-' ELSE N'HT-' END+@MaCS+N'-'+CONVERT(NVARCHAR(4),@Nam)+N'-'+RIGHT(N'000000'+CONVERT(NVARCHAR(20),@So),6);
END;
GO

/* Tiền thu tại QLPM dùng VND nguyên; giá gốc ở bảng nguồn vẫn giữ precision. */
/* v96: migrate chứng từ thu legacy đang gộp chỉ định + toa thuốc.
   - Phiếu thuần một nhóm chỉ backfill Nhom.
   - Phiếu mixed đang hoạt động, chưa hoàn: giữ phiếu cũ làm CHI_DINH,
     tạo phiếu mới TOA_THUOC và chuyển các dòng thuốc sang phiếu mới.
   - Phiếu đã hủy/đã hoàn giữ nguyên để không làm biến dạng audit lịch sử. */
UPDATE C
SET C.Nhom=N'TOA_THUOC'
FROM dbo.QL_ThuTien_ChungTu C
WHERE C.Nhom IS NULL
  AND EXISTS
  (
      SELECT 1
      FROM dbo.QL_ThuTien_ChungTu_CT D
      WHERE D.IDChungTu=C.ID
        AND D.Loai=N'THUOC'
  )
  AND NOT EXISTS
  (
      SELECT 1
      FROM dbo.QL_ThuTien_ChungTu_CT D
      WHERE D.IDChungTu=C.ID
        AND D.Loai<>N'THUOC'
  );
GO

UPDATE C
SET C.Nhom=N'CHI_DINH'
FROM dbo.QL_ThuTien_ChungTu C
WHERE C.Nhom IS NULL
  AND EXISTS
  (
      SELECT 1
      FROM dbo.QL_ThuTien_ChungTu_CT D
      WHERE D.IDChungTu=C.ID
        AND D.Loai<>N'THUOC'
  )
  AND NOT EXISTS
  (
      SELECT 1
      FROM dbo.QL_ThuTien_ChungTu_CT D
      WHERE D.IDChungTu=C.ID
        AND D.Loai=N'THUOC'
  );
GO

DECLARE
    @MigID BIGINT,
    @MigIDCSKCB BIGINT,
    @MigIDVaoVien BIGINT,
    @MigIDThuTien BIGINT,
    @MigSoCu NVARCHAR(40),
    @MigSoMoi NVARCHAR(40),
    @MigNgay DATETIME2(0),
    @MigIDNhanVien BIGINT,
    @MigIDTaiKhoan BIGINT,
    @MigIDNganHang BIGINT,
    @MigGhiChu NVARCHAR(500),
    @MigTongCD DECIMAL(18,2),
    @MigGiamCD DECIMAL(18,2),
    @MigThuCD DECIMAL(18,2),
    @MigTongToa DECIMAL(18,2),
    @MigGiamToa DECIMAL(18,2),
    @MigThuToa DECIMAL(18,2),
    @MigCKCu DECIMAL(18,2),
    @MigCKCD DECIMAL(18,2),
    @MigCKToa DECIMAL(18,2),
    @MigTMCD DECIMAL(18,2),
    @MigTMToa DECIMAL(18,2),
    @MigIDMoi BIGINT;

DECLARE c_mig_chung_tu CURSOR LOCAL FAST_FORWARD FOR
SELECT
    C.ID,C.IDCSKCB,C.IDVaoVien,C.IDThuTien,C.SoChungTu,C.NgayGio,
    C.IDNhanVien,C.IDTaiKhoan,C.IDNganHang,C.GhiChu,C.ChuyenKhoan
FROM dbo.QL_ThuTien_ChungTu C
WHERE C.Loai='THU'
  AND C.Nhom IS NULL
  AND C.TrangThai=1
  AND EXISTS
  (
      SELECT 1 FROM dbo.QL_ThuTien_ChungTu_CT D
      WHERE D.IDChungTu=C.ID AND D.Loai=N'THUOC'
  )
  AND EXISTS
  (
      SELECT 1 FROM dbo.QL_ThuTien_ChungTu_CT D
      WHERE D.IDChungTu=C.ID AND D.Loai<>N'THUOC'
  )
  AND NOT EXISTS
  (
      SELECT 1
      FROM dbo.QL_ThuTien_ChungTu H
      WHERE H.IDChungTuGoc=C.ID
        AND H.Loai='HOAN'
  )
ORDER BY C.ID;

OPEN c_mig_chung_tu;
FETCH NEXT FROM c_mig_chung_tu INTO
    @MigID,@MigIDCSKCB,@MigIDVaoVien,@MigIDThuTien,@MigSoCu,@MigNgay,
    @MigIDNhanVien,@MigIDTaiKhoan,@MigIDNganHang,@MigGhiChu,@MigCKCu;

WHILE @@FETCH_STATUS=0
BEGIN
    SELECT
        @MigTongCD=ISNULL(SUM(CASE WHEN Loai<>N'THUOC' THEN ThanhTien+PhuThu ELSE 0 END),0),
        @MigGiamCD=ISNULL(SUM(CASE WHEN Loai<>N'THUOC' THEN TienGiam ELSE 0 END),0),
        @MigThuCD=ISNULL(SUM(CASE WHEN Loai<>N'THUOC' THEN ThanhToan ELSE 0 END),0),
        @MigTongToa=ISNULL(SUM(CASE WHEN Loai=N'THUOC' THEN ThanhTien+PhuThu ELSE 0 END),0),
        @MigGiamToa=ISNULL(SUM(CASE WHEN Loai=N'THUOC' THEN TienGiam ELSE 0 END),0),
        @MigThuToa=ISNULL(SUM(CASE WHEN Loai=N'THUOC' THEN ThanhToan ELSE 0 END),0)
    FROM dbo.QL_ThuTien_ChungTu_CT
    WHERE IDChungTu=@MigID;

    SET @MigCKCD=CASE WHEN ISNULL(@MigCKCu,0)>@MigThuCD THEN @MigThuCD ELSE ISNULL(@MigCKCu,0) END;
    SET @MigCKToa=ISNULL(@MigCKCu,0)-@MigCKCD;
    SET @MigTMCD=@MigThuCD-@MigCKCD;
    SET @MigTMToa=@MigThuToa-@MigCKToa;

    EXEC dbo.STO_QL_ThuNgan_CapSoChungTu
        @IDCSKCB=@MigIDCSKCB,@Loai='THU',@SoChungTu=@MigSoMoi OUTPUT;

    INSERT dbo.QL_ThuTien_ChungTu
        (IDCSKCB,IDVaoVien,IDThuTien,Loai,Nhom,SoChungTu,NgayGio,IDNhanVien,IDTaiKhoan,
         TongTien,TienGiam,ThucThu,TienMat,ChuyenKhoan,IDNganHang,GhiChu,TrangThai)
    VALUES
        (@MigIDCSKCB,@MigIDVaoVien,@MigIDThuTien,'THU',N'TOA_THUOC',@MigSoMoi,@MigNgay,
         @MigIDNhanVien,@MigIDTaiKhoan,@MigTongToa,@MigGiamToa,@MigThuToa,@MigTMToa,@MigCKToa,
         CASE WHEN @MigCKToa>0 THEN @MigIDNganHang ELSE NULL END,@MigGhiChu,1);
    SET @MigIDMoi=SCOPE_IDENTITY();

    UPDATE dbo.QL_ThuTien_ChungTu_CT
    SET IDChungTu=@MigIDMoi
    WHERE IDChungTu=@MigID
      AND Loai=N'THUOC';

    UPDATE dbo.QL_ThuTien_ChungTu
    SET Nhom=N'CHI_DINH',
        TongTien=@MigTongCD,
        TienGiam=@MigGiamCD,
        ThucThu=@MigThuCD,
        TienMat=@MigTMCD,
        ChuyenKhoan=@MigCKCD,
        IDNganHang=CASE WHEN @MigCKCD>0 THEN @MigIDNganHang ELSE NULL END
    WHERE ID=@MigID;

    /* Audit THU cũ đi theo phiếu chỉ định; tạo thêm audit cho phiếu toa. */
    UPDATE dbo.QL_ThuTien_LichSu
    SET TongTien=@MigTongCD,
        TienGiam=@MigGiamCD,
        ThucThu=@MigThuCD,
        TienMat=@MigTMCD,
        ChuyenKhoan=@MigCKCD,
        IDNganHang=CASE WHEN @MigCKCD>0 THEN @MigIDNganHang ELSE NULL END
    WHERE IDCSKCB=@MigIDCSKCB
      AND IDVaoVien=@MigIDVaoVien
      AND HanhDong=N'THU'
      AND SoPhieu=@MigSoCu;

    INSERT dbo.QL_ThuTien_LichSu
        (IDCSKCB,IDThuTien,IDVaoVien,HanhDong,SoPhieu,NgayGio,IDNhanVien,IDTaiKhoan,
         TongTien,TienGiam,ThucThu,TienMat,ChuyenKhoan,IDNganHang,GhiChu)
    VALUES
        (@MigIDCSKCB,@MigIDThuTien,@MigIDVaoVien,N'THU',@MigSoMoi,@MigNgay,@MigIDNhanVien,@MigIDTaiKhoan,
         @MigTongToa,@MigGiamToa,@MigThuToa,@MigTMToa,@MigCKToa,
         CASE WHEN @MigCKToa>0 THEN @MigIDNganHang ELSE NULL END,@MigGhiChu);

    FETCH NEXT FROM c_mig_chung_tu INTO
        @MigID,@MigIDCSKCB,@MigIDVaoVien,@MigIDThuTien,@MigSoCu,@MigNgay,
        @MigIDNhanVien,@MigIDTaiKhoan,@MigIDNganHang,@MigGhiChu,@MigCKCu;
END;

CLOSE c_mig_chung_tu;
DEALLOCATE c_mig_chung_tu;
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
    WHERE T.IDCSKCB=@IDCSKCB AND T.IDVaoVien=@IDVaoVien;

    UPDATE T
    SET TongTien=X.Tong,
        TienGiam=X.Giam,
        ThucThu=X.Thuc
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

/* Migrate giảm tiền legacy sang tỷ lệ % theo phiếu nếu trước đây chỉ lưu tổng giảm.
   Chỉ chạy với phiếu chưa có bất kỳ GiamPhanTram nào để re-run không ghi đè dữ liệu v90. */
;WITH Legacy AS
(
    SELECT
        T.IDCSKCB,
        T.ID AS IDThuTien,
        T.TienGiam,
        SUM(ROUND(ISNULL(CT.ThanhTien,0),0)) AS TongGoc,
        MAX(CASE WHEN ISNULL(CT.GiamPhanTram,0)>0 THEN 1 ELSE 0 END) AS CoGiamPhanTram
    FROM dbo.QL_ThuTien T
    INNER JOIN dbo.QL_ThuTien_CT CT
      ON CT.IDCSKCB=T.IDCSKCB AND CT.IDThuTien=T.ID
    WHERE ISNULL(T.TienGiam,0)>0
    GROUP BY T.IDCSKCB,T.ID,T.TienGiam
),
P AS
(
    SELECT
        IDCSKCB,
        IDThuTien,
        CASE
            WHEN TongGoc<=0 THEN CAST(0 AS DECIMAL(5,2))
            WHEN TienGiam>=TongGoc THEN CAST(100 AS DECIMAL(5,2))
            ELSE CAST(ROUND(TienGiam*100.0/TongGoc,2) AS DECIMAL(5,2))
        END AS GiamPhanTram
    FROM Legacy
    WHERE CoGiamPhanTram=0
)
UPDATE CT
SET CT.GiamPhanTram=P.GiamPhanTram,
    CT.TienGiam=ROUND(ROUND(ISNULL(CT.ThanhTien,0),0)*P.GiamPhanTram/100.0,0),
    CT.ThucThu=ROUND(ISNULL(CT.ThanhTien,0),0)
        - ROUND(ROUND(ISNULL(CT.ThanhTien,0),0)*P.GiamPhanTram/100.0,0)
FROM dbo.QL_ThuTien_CT CT
INNER JOIN P
  ON P.IDCSKCB=CT.IDCSKCB AND P.IDThuTien=CT.IDThuTien;
GO

/* Đồng bộ lại master theo chi tiết canonical sau migration/re-run.
   Master DaThu=1 chỉ khi mọi dòng đã thu; thu một phần vẫn là Chưa thu (0). */
UPDATE T
SET T.TongTien=X.Tong,
    T.TienGiam=X.Giam,
    T.ThucThu=X.Thuc,
    T.ChuyenKhoan=CASE
        WHEN X.Thuc<=0 THEN 0
        WHEN ISNULL(T.ChuyenKhoan,0)>X.Thuc THEN X.Thuc
        ELSE ISNULL(T.ChuyenKhoan,0)
    END,
    T.TienMat=CASE
        WHEN X.Thuc<=0 THEN 0
        ELSE X.Thuc-CASE
            WHEN ISNULL(T.ChuyenKhoan,0)>X.Thuc THEN X.Thuc
            ELSE ISNULL(T.ChuyenKhoan,0)
        END
    END,
    T.IDNganHang=CASE
        WHEN X.Thuc<=0 OR ISNULL(T.ChuyenKhoan,0)<=0 THEN NULL
        ELSE T.IDNganHang
    END,
    T.DaThu=CASE WHEN X.SoDaThu>0 AND X.SoChuaThu=0 THEN 1 ELSE 0 END,
    T.DaHuy=0,
    T.SoPhieu=CASE WHEN X.SoDaThu=0 THEN NULL ELSE T.SoPhieu END,
    T.NgayGioThu=CASE WHEN X.SoDaThu=0 THEN NULL ELSE T.NgayGioThu END,
    T.IDNhanVienThu=CASE WHEN X.SoDaThu=0 THEN NULL ELSE T.IDNhanVienThu END,
    T.IDTaiKhoanThu=CASE WHEN X.SoDaThu=0 THEN NULL ELSE T.IDTaiKhoanThu END
FROM dbo.QL_ThuTien T
CROSS APPLY
(
    SELECT
        ISNULL(SUM(CASE WHEN ISNULL(CT.DaThu,0)=1
                       THEN ROUND(ISNULL(CT.ThanhTien,0),0)+ROUND(ISNULL(CT.PhuThu,0),0) ELSE 0 END),0) AS Tong,
        ISNULL(SUM(CASE WHEN ISNULL(CT.DaThu,0)=1
                       THEN ROUND(ISNULL(CT.TienGiam,0),0) ELSE 0 END),0) AS Giam,
        ISNULL(SUM(CASE WHEN ISNULL(CT.DaThu,0)=1
                       THEN ROUND(ISNULL(CT.ThucThu,0),0) ELSE 0 END),0) AS Thuc,
        ISNULL(SUM(CASE WHEN ISNULL(CT.DaThu,0)=1 THEN 1 ELSE 0 END),0) AS SoDaThu,
        ISNULL(SUM(CASE WHEN ISNULL(CT.DaThu,0)=0 THEN 1 ELSE 0 END),0) AS SoChuaThu
    FROM dbo.QL_ThuTien_CT CT
    WHERE CT.IDCSKCB=T.IDCSKCB
      AND CT.IDThuTien=T.ID
) X;
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
        ) X
        OUTER APPLY
        (
            SELECT
                SUM(CASE WHEN ISNULL(CT.DaThu,0)=1 THEN 1 ELSE 0 END) AS SoDaThu,
                SUM(CASE WHEN ISNULL(CT.DaThu,0)=0 THEN 1 ELSE 0 END) AS SoChuaThu
            FROM dbo.QL_ThuTien_CT CT
            WHERE CT.IDCSKCB=V.IDCSKCB
              AND CT.IDThuTien=T.ID
        ) S
        WHERE V.IDCSKCB=@IDCSKCB
          AND V.Active=1
          AND V.TrangThaiKham=2
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

CREATE OR ALTER PROCEDURE dbo.STO_QL_ThuNgan_DanhSachBenhNhanChungTu
    @IDCSKCB BIGINT,
    @TuNgay DATE=NULL,
    @DenNgay DATE=NULL,
    @TuKhoa NVARCHAR(200)=NULL,
    @Trang INT=1,
    @KichThuocTrang INT=25
AS
BEGIN
    SET NOCOUNT ON;

    SET @TuKhoa=NULLIF(LTRIM(RTRIM(@TuKhoa)),N'');
    SET @TuNgay=COALESCE(@TuNgay,CONVERT(DATE,SYSDATETIME()));
    SET @DenNgay=COALESCE(@DenNgay,CONVERT(DATE,SYSDATETIME()));
    IF @DenNgay<@TuNgay
    BEGIN
        DECLARE @Tmp DATE=@TuNgay;
        SET @TuNgay=@DenNgay;
        SET @DenNgay=@Tmp;
    END;

    SET @Trang=CASE WHEN @Trang<1 THEN 1 ELSE @Trang END;
    SET @KichThuocTrang=CASE
        WHEN @KichThuocTrang<10 THEN 10
        WHEN @KichThuocTrang>100 THEN 100
        ELSE @KichThuocTrang
    END;

    /* QL chứng từ phải lấy theo lần THU thực tế, không phụ thuộc hoàn toàn
       vào bảng chứng từ mới vì dữ liệu legacy có thể đã thu nhưng chưa có
       QL_ThuTien_ChungTu. */
    ;WITH PhatSinhThu AS
    (
        /* Chứng từ mới: nguồn chuẩn cho các lần thu hiện tại. */
        SELECT
            C.IDVaoVien,
            C.NgayGio AS NgayThu
        FROM dbo.QL_ThuTien_ChungTu C
        WHERE C.IDCSKCB=@IDCSKCB
          AND C.Loai='THU'
          AND C.NgayGio>=@TuNgay
          AND C.NgayGio<DATEADD(DAY,1,@DenNgay)

        UNION ALL

        /* Audit thu: bao phủ các lần thu đã ghi lịch sử nhưng chưa có
           chứng từ mới. Tránh nhân đôi khi đã có chứng từ cùng số phiếu. */
        SELECT
            L.IDVaoVien,
            L.NgayGio AS NgayThu
        FROM dbo.QL_ThuTien_LichSu L
        WHERE L.IDCSKCB=@IDCSKCB
          AND L.HanhDong=N'THU'
          AND L.NgayGio>=@TuNgay
          AND L.NgayGio<DATEADD(DAY,1,@DenNgay)
          AND NOT EXISTS
          (
              SELECT 1
              FROM dbo.QL_ThuTien_ChungTu C
              WHERE C.IDCSKCB=L.IDCSKCB
                AND C.IDVaoVien=L.IDVaoVien
                AND C.Loai='THU'
                AND ISNULL(C.SoChungTu,N'')=ISNULL(L.SoPhieu,N'')
          )

        UNION ALL

        /* Legacy: master/chi tiết đã thu trước khi có bảng chứng từ/audit mới. */
        SELECT
            T.IDVaoVien,
            T.NgayGioThu AS NgayThu
        FROM dbo.QL_ThuTien T
        WHERE T.IDCSKCB=@IDCSKCB
          AND T.NgayGioThu IS NOT NULL
          AND T.NgayGioThu>=@TuNgay
          AND T.NgayGioThu<DATEADD(DAY,1,@DenNgay)
          AND EXISTS
          (
              SELECT 1
              FROM dbo.QL_ThuTien_CT CT
              WHERE CT.IDCSKCB=T.IDCSKCB
                AND CT.IDThuTien=T.ID
                AND ISNULL(CT.DaThu,0)=1
          )
          AND NOT EXISTS
          (
              SELECT 1
              FROM dbo.QL_ThuTien_ChungTu C
              WHERE C.IDCSKCB=T.IDCSKCB
                AND C.IDVaoVien=T.IDVaoVien
                AND C.Loai='THU'
          )
          AND NOT EXISTS
          (
              SELECT 1
              FROM dbo.QL_ThuTien_LichSu L
              WHERE L.IDCSKCB=T.IDCSKCB
                AND L.IDVaoVien=T.IDVaoVien
                AND L.HanhDong=N'THU'
          )
    ),
    PS AS
    (
        SELECT
            IDVaoVien,
            MAX(NgayThu) AS ngay_chung_tu
        FROM PhatSinhThu
        GROUP BY IDVaoVien
    ),
    D AS
    (
        SELECT
            V.ID AS id_vao_vien,
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
            PS.ngay_chung_tu,
            (
                SELECT COUNT_BIG(*)
                FROM dbo.QL_ThuTien_ChungTu C
                WHERE C.IDCSKCB=@IDCSKCB
                  AND C.IDVaoVien=V.ID
            ) AS so_chung_tu,
            CASE
                WHEN EXISTS
                (
                    SELECT 1
                    FROM dbo.QL_ThuTien T
                    INNER JOIN dbo.QL_ThuTien_CT CT
                        ON CT.IDCSKCB=T.IDCSKCB
                       AND CT.IDThuTien=T.ID
                    WHERE T.IDCSKCB=@IDCSKCB
                      AND T.IDVaoVien=V.ID
                      AND ISNULL(CT.DaThu,0)=1
                )
                THEN CAST(1 AS TINYINT)
                ELSE CAST(0 AS TINYINT)
            END AS trang_thai_thu
        FROM PS
        INNER JOIN dbo.QL_VaoVien V
            ON V.IDCSKCB=@IDCSKCB AND V.ID=PS.IDVaoVien
        INNER JOIN dbo.QL_BenhNhan B
            ON B.IDCSKCB=V.IDCSKCB AND B.ID=V.IDBenhNhan
        LEFT JOIN dbo.DM_GioiTinh GT ON GT.ID=B.IDGioiTinh
        WHERE V.Active=1
          AND
          (
              @TuKhoa IS NULL
              OR B.MaBN LIKE N'%'+@TuKhoa+N'%'
              OR B.HoTen LIKE N'%'+@TuKhoa+N'%'
              OR ISNULL(B.DienThoai,N'') LIKE N'%'+@TuKhoa+N'%'
              OR ISNULL(B.SoCCCD,N'') LIKE N'%'+@TuKhoa+N'%'
              OR V.MaVaoVien LIKE N'%'+@TuKhoa+N'%'
              OR EXISTS
              (
                  SELECT 1
                  FROM dbo.QL_ThuTien_ChungTu C2
                  WHERE C2.IDCSKCB=@IDCSKCB
                    AND C2.IDVaoVien=V.ID
                    AND C2.SoChungTu LIKE N'%'+@TuKhoa+N'%'
              )
              OR EXISTS
              (
                  SELECT 1
                  FROM dbo.QL_ThuTien T2
                  WHERE T2.IDCSKCB=@IDCSKCB
                    AND T2.IDVaoVien=V.ID
                    AND ISNULL(T2.SoPhieu,N'') LIKE N'%'+@TuKhoa+N'%'
              )
          )
    )
    SELECT
        D.*,
        COUNT(*) OVER() AS tong_so
    FROM D
    ORDER BY D.ngay_chung_tu DESC,D.id_vao_vien DESC
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
    ) X
    OUTER APPLY
    (
        SELECT
            SUM(CASE WHEN ISNULL(CT.DaThu,0)=1 THEN 1 ELSE 0 END) AS SoDaThu,
            SUM(CASE WHEN ISNULL(CT.DaThu,0)=0 THEN 1 ELSE 0 END) AS SoChuaThu
        FROM dbo.QL_ThuTien_CT CT
        WHERE CT.IDCSKCB=V.IDCSKCB
          AND CT.IDThuTien=T.ID
    ) S
    WHERE V.IDCSKCB=@IDCSKCB
      AND V.ID=@IDVaoVien
      AND V.Active=1
      AND V.TrangThaiKham=2;

    SELECT
        CT.ID AS id,
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
        IF @TrangThaiKham<>2
            THROW 58000,N'Chỉ được thu tiền sau khi bác sĩ đã khám xong.',1;
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

        IF ISNULL(@DaThu,0)=1
            THROW 58000,N'Lượt khám đã thu đủ các khoản.',1;

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
        )
            THROW 58000,N'Có khoản đã thu hoặc không thuộc lượt khám.',1;

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
        FROM dbo.QL_ThuTien_CT WITH(HOLDLOCK)
        WHERE IDCSKCB=@IDCSKCB AND IDThuTien=@IDThuTien;

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

CREATE OR ALTER PROCEDURE dbo.STO_QL_ThuNgan_HuyNhom
    @IDCSKCB BIGINT,
    @IDVaoVien BIGINT,
    @Nhom NVARCHAR(20),
    @IDNhanVienHuy BIGINT=NULL,
    @IDTaiKhoanHuy BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Nhom=UPPER(LTRIM(RTRIM(ISNULL(@Nhom,N''))));

    BEGIN TRY
        BEGIN TRAN;

        IF @Nhom NOT IN(N'CHI_DINH',N'TOA_THUOC')
            THROW 58000,N'Nhóm hủy thu không hợp lệ.',1;
        IF @IDTaiKhoanHuy<=0
           OR NOT EXISTS(SELECT 1 FROM dbo.HT_Tai_Khoan WHERE ID=@IDTaiKhoanHuy AND Active=1)
            THROW 58000,N'Không xác định được tài khoản thực hiện hủy thu.',1;
        IF ISNULL(@IDNhanVienHuy,0)<=0 SET @IDNhanVienHuy=NULL;

        DECLARE @VisitLock BIGINT;
        SELECT @VisitLock=ID
        FROM dbo.QL_VaoVien WITH(UPDLOCK,HOLDLOCK)
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien AND Active=1;
        IF @VisitLock IS NULL
            THROW 58000,N'Không tìm thấy lượt khám.',1;

        DECLARE
            @IDThuTien BIGINT,
            @SoPhieu NVARCHAR(30),
            @ChuyenKhoanCu DECIMAL(18,2),
            @IDNganHang BIGINT;

        SELECT
            @IDThuTien=ID,
            @SoPhieu=SoPhieu,
            @ChuyenKhoanCu=ISNULL(ChuyenKhoan,0),
            @IDNganHang=IDNganHang
        FROM dbo.QL_ThuTien WITH(UPDLOCK,HOLDLOCK)
        WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien;

        IF @IDThuTien IS NULL
            THROW 58000,N'Lượt khám chưa có phiếu thu.',1;

        /* Chỉ hủy phần toa thuốc mới liên quan tới cấp kho.
           Hủy chỉ định không được bắt hoàn kho nếu phần toa vẫn còn hiệu lực. */
        IF @Nhom=N'TOA_THUOC'
           AND OBJECT_ID(N'dbo.QL_Kho_Xuat',N'U') IS NOT NULL
           AND EXISTS
           (
               SELECT 1
               FROM dbo.QL_Kho_Xuat
               WHERE IDCSKCB=@IDCSKCB
                 AND IDVaoVien=@IDVaoVien
                 AND DaHuy=0
           )
            THROW 58000,N'Toa đã được cấp thuốc; phải hoàn kho trước khi hủy thu toa thuốc.',1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.QL_ThuTien_CT
            WHERE IDCSKCB=@IDCSKCB
              AND IDThuTien=@IDThuTien
              AND ISNULL(DaThu,0)=1
              AND
              (
                  (@Nhom=N'CHI_DINH' AND (IDCongKhamCT IS NOT NULL OR IDChiDinhCT IS NOT NULL))
                  OR (@Nhom=N'TOA_THUOC' AND IDToaThuocCT IS NOT NULL)
              )
        )
            THROW 58000,N'Nhóm này chưa có khoản đã thu để hủy.',1;

        UPDATE dbo.QL_ThuTien_CT
        SET DaThu=0,
            DaHuy=0,
            NgayGioHuy=SYSDATETIME(),
            IDNhanVienHuy=@IDNhanVienHuy,
            IDTaiKhoanHuy=@IDTaiKhoanHuy
        WHERE IDCSKCB=@IDCSKCB
          AND IDThuTien=@IDThuTien
          AND ISNULL(DaThu,0)=1
          AND
          (
              (@Nhom=N'CHI_DINH' AND (IDCongKhamCT IS NOT NULL OR IDChiDinhCT IS NOT NULL))
              OR (@Nhom=N'TOA_THUOC' AND IDToaThuocCT IS NOT NULL)
          );

        DECLARE
            @TongTien DECIMAL(18,2),
            @TienGiam DECIMAL(18,2),
            @ThucThu DECIMAL(18,2),
            @ChuyenKhoanMoi DECIMAL(18,2),
            @TienMatMoi DECIMAL(18,2),
            @SoDongDaThu INT;

        SELECT
            @TongTien=ISNULL(SUM(CASE WHEN ISNULL(DaThu,0)=1
                                     THEN ROUND(ISNULL(ThanhTien,0),0)+ROUND(ISNULL(PhuThu,0),0) ELSE 0 END),0),
            @TienGiam=ISNULL(SUM(CASE WHEN ISNULL(DaThu,0)=1
                                     THEN ROUND(ISNULL(TienGiam,0),0) ELSE 0 END),0),
            @ThucThu=ISNULL(SUM(CASE WHEN ISNULL(DaThu,0)=1
                                    THEN ROUND(ISNULL(ThucThu,0),0) ELSE 0 END),0),
            @SoDongDaThu=ISNULL(SUM(CASE WHEN ISNULL(DaThu,0)=1 THEN 1 ELSE 0 END),0)
        FROM dbo.QL_ThuTien_CT WITH(HOLDLOCK)
        WHERE IDCSKCB=@IDCSKCB
          AND IDThuTien=@IDThuTien;

        SET @ChuyenKhoanMoi=CASE
            WHEN @ThucThu<=0 THEN 0
            WHEN @ChuyenKhoanCu>@ThucThu THEN @ThucThu
            ELSE @ChuyenKhoanCu
        END;
        SET @TienMatMoi=@ThucThu-@ChuyenKhoanMoi;
        IF @ChuyenKhoanMoi=0 SET @IDNganHang=NULL;

        /* Rule nghiệp vụ: hủy một nhóm hoàn tác nhóm đó về Chưa thu; không sinh trạng thái hủy. */
        UPDATE dbo.QL_ThuTien
        SET SoPhieu=CASE WHEN @SoDongDaThu=0 THEN NULL ELSE SoPhieu END,
            NgayGioThu=CASE WHEN @SoDongDaThu=0 THEN NULL ELSE NgayGioThu END,
            IDNhanVienThu=CASE WHEN @SoDongDaThu=0 THEN NULL ELSE IDNhanVienThu END,
            IDTaiKhoanThu=CASE WHEN @SoDongDaThu=0 THEN NULL ELSE IDTaiKhoanThu END,
            TongTien=@TongTien,
            TienGiam=@TienGiam,
            ThucThu=@ThucThu,
            TienMat=@TienMatMoi,
            ChuyenKhoan=@ChuyenKhoanMoi,
            IDNganHang=@IDNganHang,
            DaThu=0,
            DaHuy=0
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDThuTien;

        INSERT dbo.QL_ThuTien_LichSu
            (IDCSKCB,IDThuTien,IDVaoVien,HanhDong,SoPhieu,NgayGio,IDNhanVien,IDTaiKhoan,TongTien,TienGiam,ThucThu,TienMat,ChuyenKhoan,IDNganHang,GhiChu)
        VALUES
            (
                @IDCSKCB,
                @IDThuTien,
                @IDVaoVien,
                CASE WHEN @Nhom=N'TOA_THUOC' THEN N'HUY_TOA_THUOC' ELSE N'HUY_CHI_DINH' END,
                @SoPhieu,
                SYSDATETIME(),
                @IDNhanVienHuy,
                @IDTaiKhoanHuy,
                @TongTien,
                @TienGiam,
                @ThucThu,
                @TienMatMoi,
                @ChuyenKhoanMoi,
                @IDNganHang,
                CASE WHEN @Nhom=N'TOA_THUOC' THEN N'Hủy thu toa thuốc.' ELSE N'Hủy thu chỉ định.' END
            );

        COMMIT;
        SELECT
            200 AS Status,
            CASE WHEN @Nhom=N'TOA_THUOC' THEN N'Đã hủy thu toa thuốc.' ELSE N'Đã hủy thu chỉ định.' END AS Message,
            @IDThuTien AS IDThuTien,
            @SoPhieu AS SoPhieu,
            @TongTien AS TongTien,
            @TienGiam AS TienGiam,
            @ThucThu AS ThucThu,
            @TienMatMoi AS TienMat,
            @ChuyenKhoanMoi AS ChuyenKhoan,
            CAST(0 AS TINYINT) AS TrangThaiThu;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT
            400 AS Status,
            ERROR_MESSAGE() AS Message,
            CAST(NULL AS BIGINT) AS IDThuTien,
            CAST(NULL AS NVARCHAR(30)) AS SoPhieu;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_ThuNgan_HuyThu
    @IDCSKCB BIGINT,
    @IDVaoVien BIGINT,
    @IDNhanVienHuy BIGINT=NULL,
    @IDTaiKhoanHuy BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF @IDTaiKhoanHuy<=0
           OR NOT EXISTS(SELECT 1 FROM dbo.HT_Tai_Khoan WHERE ID=@IDTaiKhoanHuy AND Active=1)
            THROW 58000,N'Không xác định được tài khoản thực hiện hủy thu.',1;
        IF ISNULL(@IDNhanVienHuy,0)<=0 SET @IDNhanVienHuy=NULL;

        DECLARE @VisitLock BIGINT;
        SELECT @VisitLock=ID
        FROM dbo.QL_VaoVien WITH(UPDLOCK,HOLDLOCK)
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDVaoVien AND Active=1;
        IF @VisitLock IS NULL
            THROW 58000,N'Không tìm thấy lượt khám.',1;

        DECLARE
            @IDThuTien BIGINT,
            @SoPhieu NVARCHAR(30);

        SELECT
            @IDThuTien=ID,
            @SoPhieu=SoPhieu
        FROM dbo.QL_ThuTien WITH(UPDLOCK,HOLDLOCK)
        WHERE IDCSKCB=@IDCSKCB AND IDVaoVien=@IDVaoVien;

        IF @IDThuTien IS NULL
            THROW 58000,N'Lượt khám chưa có phiếu thu.',1;
        IF NOT EXISTS
        (
            SELECT 1 FROM dbo.QL_ThuTien_CT
            WHERE IDCSKCB=@IDCSKCB
              AND IDThuTien=@IDThuTien
              AND ISNULL(DaThu,0)=1
        )
            THROW 58000,N'Lượt khám chưa có khoản đã thu để hủy.',1;

        IF OBJECT_ID(N'dbo.QL_Kho_Xuat',N'U') IS NOT NULL
           AND EXISTS
           (
               SELECT 1
               FROM dbo.QL_Kho_Xuat
               WHERE IDCSKCB=@IDCSKCB
                 AND IDVaoVien=@IDVaoVien
                 AND DaHuy=0
           )
            THROW 58000,N'Toa đã được cấp thuốc; phải xử lý hoàn kho trước khi hủy thu.',1;

        INSERT dbo.QL_ThuTien_LichSu
            (IDCSKCB,IDThuTien,IDVaoVien,HanhDong,SoPhieu,NgayGio,IDNhanVien,IDTaiKhoan,TongTien,TienGiam,ThucThu,TienMat,ChuyenKhoan,IDNganHang,GhiChu)
        SELECT
            IDCSKCB,ID,IDVaoVien,N'HUY',SoPhieu,SYSDATETIME(),@IDNhanVienHuy,@IDTaiKhoanHuy,
            TongTien,TienGiam,ThucThu,TienMat,ChuyenKhoan,IDNganHang,N'Hủy toàn bộ phiếu thu.'
        FROM dbo.QL_ThuTien
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDThuTien;

        UPDATE dbo.QL_ThuTien_CT
        SET DaThu=0,
            DaHuy=0,
            NgayGioHuy=SYSDATETIME(),
            IDNhanVienHuy=@IDNhanVienHuy,
            IDTaiKhoanHuy=@IDTaiKhoanHuy
        WHERE IDCSKCB=@IDCSKCB
          AND IDThuTien=@IDThuTien
          AND ISNULL(DaThu,0)=1;

        UPDATE dbo.QL_ThuTien
        SET DaThu=0,
            DaHuy=0,
            SoPhieu=NULL,
            NgayGioThu=NULL,
            TongTien=0,
            TienGiam=0,
            ThucThu=0,
            TienMat=0,
            ChuyenKhoan=0,
            IDNganHang=NULL
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDThuTien;

        COMMIT;
        SELECT 200 AS Status,N'Đã hủy thu; chứng từ đã về Chưa thu.' AS Message,@IDThuTien AS IDThuTien,@SoPhieu AS SoPhieu;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        SELECT
            400 AS Status,
            ERROR_MESSAGE() AS Message,
            CAST(NULL AS BIGINT) AS IDThuTien,
            CAST(NULL AS NVARCHAR(30)) AS SoPhieu;
    END CATCH;
END;
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
           C.IDChungTuGoc AS id_chung_tu_goc,G.SoChungTu AS so_chung_tu_goc
    FROM dbo.QL_ThuTien_ChungTu C
    LEFT JOIN dbo.DM_NhanVien NV ON NV.ID=C.IDNhanVien
    LEFT JOIN dbo.HT_Tai_Khoan TK ON TK.ID=C.IDTaiKhoan
    LEFT JOIN dbo.DM_NganHang NH ON NH.ID=C.IDNganHang
    LEFT JOIN dbo.DM_NhanVien NVH ON NVH.ID=C.IDNhanVienHuy
    LEFT JOIN dbo.HT_Tai_Khoan TKH ON TKH.ID=C.IDTaiKhoanHuy
    LEFT JOIN dbo.QL_ThuTien_ChungTu G ON G.ID=C.IDChungTuGoc
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

CREATE OR ALTER PROCEDURE dbo.STO_QL_ThuNgan_LichSuHuyChungTu
    @IDCSKCB BIGINT,
    @IDVaoVien BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    /* 1) Thông tin lượt/BN. Không phụ thuộc TrangThaiKham. */
    SELECT
        V.ID AS id_vao_vien,
        V.MaVaoVien AS ma_vao_vien,
        B.ID AS id_benh_nhan,
        B.MaBN AS ma_bn,
        B.HoTen AS ho_ten,
        B.NgaySinh AS ngay_sinh,
        GT.TenGioiTinh AS gioi_tinh,
        B.DienThoai AS dien_thoai,
        B.DiaChi AS dia_chi
    FROM dbo.QL_VaoVien V
    INNER JOIN dbo.QL_BenhNhan B
        ON B.IDCSKCB=V.IDCSKCB
       AND B.ID=V.IDBenhNhan
    LEFT JOIN dbo.DM_GioiTinh GT
        ON GT.ID=B.IDGioiTinh
    WHERE V.IDCSKCB=@IDCSKCB
      AND V.ID=@IDVaoVien
      AND V.Active=1;

    /* 2) Lịch sử hủy chứng từ theo đúng contract mẫu HIS
          Doc/UI/pdf-mẫu/EXCELLichSuHuyChungTu.xlsx. */
    SELECT
        C.ID AS id,
        C.NgayGio AS ngay_thu,
        CASE
            WHEN C.Nhom=N'TOA_THUOC' OR (C.Nhom IS NULL AND ISNULL(X.so_thuoc,0)>0 AND ISNULL(X.so_khac,0)=0)
                THEN N'TOATHUOCDV'
            ELSE N'KHAMDV'
        END AS nguon_thu,
        C.SoChungTu AS so_chung_tu,
        N'huỷ' AS trang_thai_xoa,
        C.NgayGioHuy AS ngay_gio_huy,
        COALESCE(TKH.Ten_Dang_Nhap,N'') AS ten_nguoi_dang_nhap_huy,
        CAST(NULL AS DATETIME2(0)) AS ngay_gio_xoa,
        CAST(NULL AS NVARCHAR(200)) AS ten_nguoi_dang_nhap_xoa,
        CAST(NULL AS NVARCHAR(200)) AS ten_nguoi_xoa,
        C.LyDoHuy AS ly_do_xoa,
        B.DienThoai AS so_dien_thoai_benh_nhan,
        CONCAT(
            N'Mã BN: ',ISNULL(B.MaBN,N''),
            N' - Mã VV: ',ISNULL(V.MaVaoVien,N''),
            N' - Họ tên: ',ISNULL(B.HoTen,N''),
            N' - Năm sinh: ',CASE WHEN B.NgaySinh IS NULL THEN N'' ELSE CONVERT(NVARCHAR(4),YEAR(B.NgaySinh)) END,
            N' - Giới tính: ',ISNULL(GT.TenGioiTinh,N''),
            N' - Địa chỉ: ',ISNULL(B.DiaChi,N'')
        ) AS thong_tin_hanh_chinh,
        CONCAT(
            CASE
                WHEN C.Nhom=N'TOA_THUOC' OR (C.Nhom IS NULL AND ISNULL(X.so_thuoc,0)>0 AND ISNULL(X.so_khac,0)=0)
                    THEN N'Thuốc DV: '
                ELSE N'DVKT : '
            END,
            FORMAT(C.ThucThu,N'N0',N'en-US'),
            N' (',
            ISNULL(ND.noi_dung,N''),
            CASE WHEN NULLIF(ND.noi_dung,N'') IS NULL THEN N'' ELSE N'; ' END,
            N')'
        ) AS noi_dung_huy
    FROM dbo.QL_ThuTien_ChungTu C
    INNER JOIN dbo.QL_VaoVien V
        ON V.IDCSKCB=C.IDCSKCB
       AND V.ID=C.IDVaoVien
    INNER JOIN dbo.QL_BenhNhan B
        ON B.IDCSKCB=V.IDCSKCB
       AND B.ID=V.IDBenhNhan
    LEFT JOIN dbo.DM_GioiTinh GT
        ON GT.ID=B.IDGioiTinh
    LEFT JOIN dbo.HT_Tai_Khoan TKH
        ON TKH.ID=C.IDTaiKhoanHuy
    OUTER APPLY
    (
        SELECT
            SUM(CASE WHEN D.Loai=N'THUOC' THEN 1 ELSE 0 END) AS so_thuoc,
            SUM(CASE WHEN D.Loai<>N'THUOC' THEN 1 ELSE 0 END) AS so_khac
        FROM dbo.QL_ThuTien_ChungTu_CT D
        WHERE D.IDChungTu=C.ID
    ) X
    OUTER APPLY
    (
        SELECT STRING_AGG(
            CAST(CONCAT(
                D.Ten,N': ',
                FORMAT(D.SoLuong,N'0.###',N'en-US'),N' x ',
                FORMAT(D.DonGia,N'N0',N'en-US'),N' x ',
                FORMAT(100-ISNULL(D.GiamPhanTram,0),N'0.##',N'en-US'),N'%'
            ) AS NVARCHAR(MAX)),
            N'; '
        ) WITHIN GROUP (ORDER BY D.ID) AS noi_dung
        FROM dbo.QL_ThuTien_ChungTu_CT D
        WHERE D.IDChungTu=C.ID
    ) ND
    WHERE C.IDCSKCB=@IDCSKCB
      AND C.IDVaoVien=@IDVaoVien
      AND C.Loai='THU'
      AND C.TrangThai=0
    ORDER BY C.NgayGioHuy DESC,C.ID DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_QL_ThuNgan_ChiTietChungTu
    @IDCSKCB BIGINT, @IDChungTu BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT C.ID AS id_chung_tu,C.IDVaoVien AS id_vao_vien,C.Loai AS loai,C.Nhom AS nhom,C.SoChungTu AS so_phieu,
           C.NgayGio AS ngay_gio_thu,C.TrangThai AS trang_thai,C.LyDoHuy AS ly_do_huy,
           B.MaBN AS ma_bn,B.HoTen AS ho_ten,B.NgaySinh AS ngay_sinh,GT.TenGioiTinh AS gioi_tinh,
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

CREATE OR ALTER PROCEDURE dbo.STO_QL_ThuNgan_HuyChungTu
    @IDCSKCB BIGINT,@IDChungTu BIGINT,@LyDo NVARCHAR(500)=NULL,@IDNhanVien BIGINT=NULL,@IDTaiKhoan BIGINT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON; SET @LyDo=COALESCE(NULLIF(LTRIM(RTRIM(@LyDo)),N''),N'Hủy chứng từ thu');
    BEGIN TRY
        BEGIN TRAN;
        IF NOT EXISTS(SELECT 1 FROM dbo.HT_Tai_Khoan WHERE ID=@IDTaiKhoan AND Active=1) THROW 58000,N'Tài khoản thực hiện không hợp lệ.',1;
        DECLARE @IDVaoVien BIGINT,@IDThuTien BIGINT,@Loai VARCHAR(10),@TrangThai TINYINT,@So NVARCHAR(40),@TienMatCT DECIMAL(18,2),@CKCT DECIMAL(18,2);
        SELECT @IDVaoVien=IDVaoVien,@IDThuTien=IDThuTien,@Loai=Loai,@TrangThai=TrangThai,@So=SoChungTu,@TienMatCT=TienMat,@CKCT=ChuyenKhoan
        FROM dbo.QL_ThuTien_ChungTu WITH(UPDLOCK,HOLDLOCK) WHERE IDCSKCB=@IDCSKCB AND ID=@IDChungTu;
        IF @IDVaoVien IS NULL THROW 58000,N'Không tìm thấy chứng từ.',1;
        IF @Loai<>'THU' THROW 58000,N'Chỉ hủy trực tiếp chứng từ thu.',1;
        IF @TrangThai<>1 THROW 58000,N'Chứng từ đã hủy.',1;
        IF EXISTS(SELECT 1 FROM dbo.QL_ThuTien_ChungTu WHERE IDChungTuGoc=@IDChungTu AND Loai='HOAN' AND TrangThai=1)
            THROW 58000,N'Chứng từ đã có phiếu hoàn tiền.',1;
        IF OBJECT_ID(N'dbo.QL_Kho_Xuat',N'U') IS NOT NULL AND EXISTS
        (SELECT 1 FROM dbo.QL_Kho_Xuat X WHERE X.IDCSKCB=@IDCSKCB AND X.IDVaoVien=@IDVaoVien AND X.DaHuy=0
          AND EXISTS(SELECT 1 FROM dbo.QL_ThuTien_ChungTu_CT D WHERE D.IDChungTu=@IDChungTu AND D.Loai=N'THUOC'))
            THROW 58000,N'Toa đã cấp thuốc; phải hoàn kho trước khi hủy thu.',1;

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
        SELECT @IDVaoVien=IDVaoVien,@IDThuTien=IDThuTien,@TienMatCT=TienMat,@CKCT=ChuyenKhoan FROM dbo.QL_ThuTien_ChungTu WITH(UPDLOCK,HOLDLOCK)
        WHERE IDCSKCB=@IDCSKCB AND ID=@IDChungTuGoc AND Loai='THU' AND TrangThai=1;
        IF @IDVaoVien IS NULL THROW 58000,N'Chứng từ thu gốc không hợp lệ hoặc đã hủy.',1;
        IF EXISTS(SELECT 1 FROM dbo.QL_ThuTien_ChungTu WHERE IDChungTuGoc=@IDChungTuGoc AND Loai='HOAN' AND TrangThai=1)
            THROW 58000,N'Chứng từ đã được hoàn tiền.',1;
        IF OBJECT_ID(N'dbo.QL_Kho_Xuat',N'U') IS NOT NULL AND EXISTS
        (SELECT 1 FROM dbo.QL_Kho_Xuat X WHERE X.IDCSKCB=@IDCSKCB AND X.IDVaoVien=@IDVaoVien AND X.DaHuy=0
          AND EXISTS(SELECT 1 FROM dbo.QL_ThuTien_ChungTu_CT D WHERE D.IDChungTu=@IDChungTuGoc AND D.Loai=N'THUOC'))
            THROW 58000,N'Toa đã cấp thuốc; phải hoàn kho trước khi hoàn tiền.',1;

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

PRINT N'28_thu_ngan.sql: OK';
GO
