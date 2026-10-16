USE [QLPM];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/*
    20_bo_sung_dang_nhap_phan_quyen.sql
    - Khong tao tai khoan/mat khau mac dinh.
    - Mat khau duoc hash bang ASP.NET Core PasswordHasher truoc khi ghi DB.
*/

IF OBJECT_ID(N'dbo.DM_Vai_Tro', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DM_Vai_Tro
    (
        ID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DM_Vai_Tro PRIMARY KEY,
        IDCSKCB BIGINT NOT NULL,
        Ma_Vai_Tro NVARCHAR(100) NOT NULL,
        Ten_Vai_Tro NVARCHAR(300) NOT NULL,
        Mo_Ta NVARCHAR(1000) NULL,
        Active BIT NOT NULL CONSTRAINT DF_DM_Vai_Tro_Active DEFAULT(1),
        Ngay_Tao DATETIME2(0) NOT NULL CONSTRAINT DF_DM_Vai_Tro_Ngay_Tao DEFAULT(SYSDATETIME()),
        Ngay_Cap_Nhat DATETIME2(0) NULL,
        CONSTRAINT FK_DM_Vai_Tro_CSKCB FOREIGN KEY(IDCSKCB) REFERENCES dbo.DM_CSKCB(ID),
        CONSTRAINT UQ_DM_Vai_Tro UNIQUE(IDCSKCB, Ma_Vai_Tro),
        CONSTRAINT UQ_DM_Vai_Tro_CSKCB_ID UNIQUE(IDCSKCB, ID)
    );
END;
GO

IF OBJECT_ID(N'dbo.HT_Phan_He', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.HT_Phan_He
    (
        ID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_HT_Phan_He PRIMARY KEY,
        IDCSKCB BIGINT NOT NULL,
        Ma_Phan_He NVARCHAR(100) NOT NULL,
        Ten_Phan_He NVARCHAR(300) NOT NULL,
        Thu_Tu INT NULL,
        Active BIT NOT NULL CONSTRAINT DF_HT_Phan_He_Active DEFAULT(1),
        CONSTRAINT FK_HT_Phan_He_CSKCB FOREIGN KEY(IDCSKCB) REFERENCES dbo.DM_CSKCB(ID),
        CONSTRAINT UQ_HT_Phan_He UNIQUE(IDCSKCB, Ma_Phan_He),
        CONSTRAINT UQ_HT_Phan_He_CSKCB_ID UNIQUE(IDCSKCB, ID)
    );
END;
GO

IF OBJECT_ID(N'dbo.HT_Chuc_Nang', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.HT_Chuc_Nang
    (
        ID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_HT_Chuc_Nang PRIMARY KEY,
        IDCSKCB BIGINT NOT NULL,
        ID_Phan_He BIGINT NOT NULL,
        Ma_Chuc_Nang NVARCHAR(150) NOT NULL,
        Ten_Chuc_Nang NVARCHAR(300) NOT NULL,
        Duong_Dan NVARCHAR(500) NULL,
        Thu_Tu INT NULL,
        Active BIT NOT NULL CONSTRAINT DF_HT_Chuc_Nang_Active DEFAULT(1),
        CONSTRAINT FK_HT_Chuc_Nang_CSKCB FOREIGN KEY(IDCSKCB) REFERENCES dbo.DM_CSKCB(ID),
        CONSTRAINT FK_HT_Chuc_Nang_Phan_He FOREIGN KEY(IDCSKCB, ID_Phan_He) REFERENCES dbo.HT_Phan_He(IDCSKCB, ID),
        CONSTRAINT UQ_HT_Chuc_Nang UNIQUE(IDCSKCB, Ma_Chuc_Nang),
        CONSTRAINT UQ_HT_Chuc_Nang_CSKCB_ID UNIQUE(IDCSKCB, ID)
    );
END;
GO

IF OBJECT_ID(N'dbo.HT_Tai_Khoan', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.HT_Tai_Khoan
    (
        ID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_HT_Tai_Khoan PRIMARY KEY,
        IDCSKCB BIGINT NOT NULL,
        IDNhanVien BIGINT NOT NULL,
        Ten_Dang_Nhap NVARCHAR(150) NOT NULL,
        Mat_Khau_Hash NVARCHAR(1000) NOT NULL,
        Bat_Buoc_Doi_Mat_Khau BIT NOT NULL CONSTRAINT DF_HT_Tai_Khoan_BBDMK DEFAULT(0),
        So_Lan_Dang_Nhap_Sai INT NOT NULL CONSTRAINT DF_HT_Tai_Khoan_Sai DEFAULT(0),
        Khoa_Den_Luc DATETIME2(0) NULL,
        Lan_Dang_Nhap_Cuoi DATETIME2(0) NULL,
        Active BIT NOT NULL CONSTRAINT DF_HT_Tai_Khoan_Active DEFAULT(1),
        Ngay_Tao DATETIME2(0) NOT NULL CONSTRAINT DF_HT_Tai_Khoan_Ngay_Tao DEFAULT(SYSDATETIME()),
        Ngay_Cap_Nhat DATETIME2(0) NULL,
        RowVersion ROWVERSION,
        CONSTRAINT FK_HT_Tai_Khoan_CSKCB FOREIGN KEY(IDCSKCB) REFERENCES dbo.DM_CSKCB(ID),
        CONSTRAINT FK_HT_Tai_Khoan_NhanVien FOREIGN KEY(IDNhanVien) REFERENCES dbo.DM_NhanVien(ID),
        CONSTRAINT UQ_HT_Tai_Khoan_Ten UNIQUE(Ten_Dang_Nhap),
        CONSTRAINT UQ_HT_Tai_Khoan_NhanVien UNIQUE(IDCSKCB, IDNhanVien),
        CONSTRAINT UQ_HT_Tai_Khoan_CSKCB_ID UNIQUE(IDCSKCB, ID)
    );
END;
GO

IF OBJECT_ID(N'dbo.HT_Tai_Khoan_Vai_Tro', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.HT_Tai_Khoan_Vai_Tro
    (
        ID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_HT_Tai_Khoan_Vai_Tro PRIMARY KEY,
        IDCSKCB BIGINT NOT NULL,
        ID_Tai_Khoan BIGINT NOT NULL,
        ID_Vai_Tro BIGINT NOT NULL,
        Active BIT NOT NULL CONSTRAINT DF_HT_TKVT_Active DEFAULT(1),
        CONSTRAINT FK_HT_TKVT_TaiKhoan FOREIGN KEY(IDCSKCB, ID_Tai_Khoan) REFERENCES dbo.HT_Tai_Khoan(IDCSKCB, ID),
        CONSTRAINT FK_HT_TKVT_VaiTro FOREIGN KEY(IDCSKCB, ID_Vai_Tro) REFERENCES dbo.DM_Vai_Tro(IDCSKCB, ID),
        CONSTRAINT UQ_HT_TKVT UNIQUE(IDCSKCB, ID_Tai_Khoan, ID_Vai_Tro)
    );
END;
GO

IF OBJECT_ID(N'dbo.HT_Quyen_Vai_Tro', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.HT_Quyen_Vai_Tro
    (
        ID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_HT_Quyen_Vai_Tro PRIMARY KEY,
        IDCSKCB BIGINT NOT NULL,
        ID_Vai_Tro BIGINT NOT NULL,
        ID_Chuc_Nang BIGINT NOT NULL,
        Xem BIT NOT NULL CONSTRAINT DF_HT_QVT_Xem DEFAULT(0),
        Them BIT NOT NULL CONSTRAINT DF_HT_QVT_Them DEFAULT(0),
        Sua BIT NOT NULL CONSTRAINT DF_HT_QVT_Sua DEFAULT(0),
        Xoa BIT NOT NULL CONSTRAINT DF_HT_QVT_Xoa DEFAULT(0),
        Xuat BIT NOT NULL CONSTRAINT DF_HT_QVT_Xuat DEFAULT(0),
        Ca_Nhan BIT NOT NULL CONSTRAINT DF_HT_QVT_CaNhan DEFAULT(0),
        CONSTRAINT FK_HT_QVT_VaiTro FOREIGN KEY(IDCSKCB, ID_Vai_Tro) REFERENCES dbo.DM_Vai_Tro(IDCSKCB, ID),
        CONSTRAINT FK_HT_QVT_ChucNang FOREIGN KEY(IDCSKCB, ID_Chuc_Nang) REFERENCES dbo.HT_Chuc_Nang(IDCSKCB, ID),
        CONSTRAINT UQ_HT_QVT UNIQUE(IDCSKCB, ID_Vai_Tro, ID_Chuc_Nang)
    );
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_Dang_Nhap_Lay_Tai_Khoan
    @Ten_Dang_Nhap NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP(1)
        T.ID AS ID_Tai_Khoan,
        T.IDCSKCB,
        T.IDNhanVien,
        T.Ten_Dang_Nhap,
        T.Mat_Khau_Hash,
        T.Bat_Buoc_Doi_Mat_Khau,
        T.So_Lan_Dang_Nhap_Sai,
        T.Khoa_Den_Luc,
        T.Lan_Dang_Nhap_Cuoi,
        T.Active AS Tai_Khoan_Active,
        T.LaQuanTriHeThong,
        CASE WHEN T.LaQuanTriHeThong=1 THEN T.Ten_Dang_Nhap ELSE N.HoTen END AS HoTen,
        CASE WHEN T.LaQuanTriHeThong=1 THEN N'ADMIN' ELSE N.MaNhanVien END AS MaNhanVien,
        CASE WHEN T.LaQuanTriHeThong=1 THEN CAST(0 AS BIT) ELSE ISNULL(N.LaBacSi,0) END AS LaBacSi,
        CASE WHEN T.LaQuanTriHeThong=1 THEN N'Quản trị hệ thống' ELSE CD.TenChucDanh END AS ChucDanh,
        CASE
            WHEN T.LaQuanTriHeThong=1 THEN CAST(1 AS BIT)
            WHEN ISNULL(N.Active,0)=1 AND ISNULL(M.Active,0)=1 THEN CAST(1 AS BIT)
            ELSE CAST(0 AS BIT)
        END AS Nhan_Vien_Active,
        CASE WHEN T.LaQuanTriHeThong=1 THEN NULL ELSE C.TenCSKCB END AS TenCSKCB,
        CASE WHEN T.LaQuanTriHeThong=1 THEN CAST(1 AS BIT) ELSE ISNULL(C.Active,0) END AS CSKCB_Active
    FROM dbo.HT_Tai_Khoan T
    LEFT JOIN dbo.DM_NhanVien N
      ON T.LaQuanTriHeThong=0 AND N.ID=T.IDNhanVien
    LEFT JOIN dbo.DM_NhanVien_CSKCB M
      ON T.LaQuanTriHeThong=0 AND M.IDNhanVien=T.IDNhanVien AND M.IDCSKCB=T.IDCSKCB
    LEFT JOIN dbo.DM_ChucDanh CD ON CD.ID=N.IDChucDanh
    LEFT JOIN dbo.DM_CSKCB C
      ON T.LaQuanTriHeThong=0 AND C.ID=T.IDCSKCB
    WHERE T.Ten_Dang_Nhap COLLATE Latin1_General_100_BIN2
        = LTRIM(RTRIM(@Ten_Dang_Nhap)) COLLATE Latin1_General_100_BIN2;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_Dang_Nhap_Ghi_Ket_Qua
    @ID_Tai_Khoan BIGINT,
    @Thanh_Cong BIT,
    @So_Lan_Sai_Toi_Da INT = 5,
    @So_Phut_Khoa INT = 15
AS
BEGIN
    SET NOCOUNT ON;
    IF @Thanh_Cong = 1
    BEGIN
        UPDATE dbo.HT_Tai_Khoan
        SET So_Lan_Dang_Nhap_Sai = 0,
            Khoa_Den_Luc = NULL,
            Lan_Dang_Nhap_Cuoi = SYSDATETIME(),
            Ngay_Cap_Nhat = SYSDATETIME()
        WHERE ID = @ID_Tai_Khoan;
        RETURN;
    END;

    UPDATE dbo.HT_Tai_Khoan
    SET So_Lan_Dang_Nhap_Sai = So_Lan_Dang_Nhap_Sai + 1,
        Khoa_Den_Luc = CASE WHEN So_Lan_Dang_Nhap_Sai + 1 >= @So_Lan_Sai_Toi_Da THEN DATEADD(MINUTE, @So_Phut_Khoa, SYSDATETIME()) ELSE Khoa_Den_Luc END,
        Ngay_Cap_Nhat = SYSDATETIME()
    WHERE ID = @ID_Tai_Khoan;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_Lay_Quyen_Tai_Khoan
    @ID_Tai_Khoan BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT VT.ID AS ID_Vai_Tro, VT.Ma_Vai_Tro, VT.Ten_Vai_Tro
    FROM dbo.HT_Tai_Khoan_Vai_Tro TV
    INNER JOIN dbo.DM_Vai_Tro VT ON VT.IDCSKCB = TV.IDCSKCB AND VT.ID = TV.ID_Vai_Tro AND VT.Active = 1
    WHERE TV.ID_Tai_Khoan = @ID_Tai_Khoan AND TV.Active = 1;

    SELECT
        CN.Ma_Chuc_Nang,
        MAX(CONVERT(INT, Q.Xem)) AS Xem,
        MAX(CONVERT(INT, Q.Them)) AS Them,
        MAX(CONVERT(INT, Q.Sua)) AS Sua,
        MAX(CONVERT(INT, Q.Xoa)) AS Xoa,
        MAX(CONVERT(INT, Q.Xuat)) AS Xuat,
        MAX(CONVERT(INT, Q.Ca_Nhan)) AS CaNhan
    FROM dbo.HT_Tai_Khoan_Vai_Tro TV
    INNER JOIN dbo.HT_Quyen_Vai_Tro Q ON Q.IDCSKCB = TV.IDCSKCB AND Q.ID_Vai_Tro = TV.ID_Vai_Tro
    INNER JOIN dbo.HT_Chuc_Nang CN ON CN.IDCSKCB = Q.IDCSKCB AND CN.ID = Q.ID_Chuc_Nang AND CN.Active = 1
    WHERE TV.ID_Tai_Khoan = @ID_Tai_Khoan AND TV.Active = 1
    GROUP BY CN.Ma_Chuc_Nang;
END;
GO

CREATE OR ALTER PROCEDURE dbo.STO_HT_Khoi_Tao_Quan_Tri
    @IDCSKCB BIGINT,
    @IDNhanVien BIGINT,
    @Ten_Dang_Nhap NVARCHAR(150),
    @Mat_Khau_Hash NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF EXISTS (SELECT 1 FROM dbo.HT_Tai_Khoan WHERE IDCSKCB = @IDCSKCB)
        BEGIN
            ROLLBACK;
            SELECT 409 AS Status, N'Cơ sở đã có tài khoản. Không cho phép bootstrap quản trị lần hai.' AS Message;
            RETURN;
        END;

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.DM_NhanVien N
            INNER JOIN dbo.DM_NhanVien_CSKCB M
                ON M.IDNhanVien=N.ID AND M.IDCSKCB=@IDCSKCB AND M.Active=1
            WHERE N.ID=@IDNhanVien AND N.Active=1
        )
        BEGIN
            ROLLBACK;
            SELECT 404 AS Status, N'Không tìm thấy nhân viên đang hoạt động.' AS Message;
            RETURN;
        END;

        DECLARE @IDVaiTro BIGINT;
        INSERT dbo.DM_Vai_Tro(IDCSKCB, Ma_Vai_Tro, Ten_Vai_Tro, Mo_Ta)
        VALUES(@IDCSKCB, N'quan_tri_he_thong', N'Quản trị hệ thống', N'Vai trò bootstrap đầu tiên của QLPM.');
        SET @IDVaiTro = SCOPE_IDENTITY();

        DECLARE @IDTaiKhoan BIGINT;
        INSERT dbo.HT_Tai_Khoan(IDCSKCB, IDNhanVien, Ten_Dang_Nhap, Mat_Khau_Hash, Bat_Buoc_Doi_Mat_Khau)
        VALUES(@IDCSKCB, @IDNhanVien, LTRIM(RTRIM(@Ten_Dang_Nhap)), @Mat_Khau_Hash, 0);
        SET @IDTaiKhoan = SCOPE_IDENTITY();

        INSERT dbo.HT_Tai_Khoan_Vai_Tro(IDCSKCB, ID_Tai_Khoan, ID_Vai_Tro)
        VALUES(@IDCSKCB, @IDTaiKhoan, @IDVaiTro);

        INSERT dbo.HT_Quyen_Vai_Tro(IDCSKCB, ID_Vai_Tro, ID_Chuc_Nang, Xem, Them, Sua, Xoa, Xuat, Ca_Nhan)
        SELECT @IDCSKCB, @IDVaiTro, ID, 1,1,1,1,1,1
        FROM dbo.HT_Chuc_Nang
        WHERE IDCSKCB = @IDCSKCB AND Active = 1;

        COMMIT;
        SELECT 200 AS Status, N'Khởi tạo quản trị thành công.' AS Message;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SELECT 500 AS Status, ERROR_MESSAGE() AS Message;
    END CATCH
END;
GO
