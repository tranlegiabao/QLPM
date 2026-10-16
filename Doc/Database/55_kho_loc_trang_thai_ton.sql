-- Read-only stock filter overlay; no operating-data or schema-table changes.
USE [QLPM];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.STO_QL_Kho_TonKho_DanhSach
    @IDCSKCB BIGINT,
    @IDKho BIGINT=NULL,
    @TuKhoa NVARCHAR(300)=NULL,
    @Trang INT=1,
    @KichThuocTrang INT=25,
    @TrangThai NVARCHAR(30)=N'tat_ca'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Ngay DATE=CONVERT(DATE,SYSDATETIME());
    SET @TrangThai=COALESCE(NULLIF(LOWER(LTRIM(RTRIM(@TrangThai))),N''),N'tat_ca');
    IF @TrangThai NOT IN(N'tat_ca',N'con_thuoc',N'het_thuoc',N'sap_het_han',N'het_han_khoa')
        THROW 51000,N'Trang thai loc ton kho khong hop le.',1;
    SET @TuKhoa=NULLIF(LTRIM(RTRIM(@TuKhoa)),N'');
    SET @Trang=CASE WHEN @Trang<1 THEN 1 ELSE @Trang END;
    SET @KichThuocTrang=CASE WHEN @KichThuocTrang<10 THEN 10 WHEN @KichThuocTrang>100 THEN 100 ELSE @KichThuocTrang END;

    IF @IDKho IS NULL
        SELECT TOP(1) @IDKho=ID FROM dbo.DM_Kho WHERE IDCSKCB=@IDCSKCB AND Active=1 ORDER BY ID;

    DECLARE @TonKho TABLE
    (
        id_thuoc BIGINT NOT NULL,
        ma_thuoc NVARCHAR(100) NULL,
        ten_thuoc NVARCHAR(500) NULL,
        don_vi_tinh NVARCHAR(200) NULL,
        ton_vat_ly DECIMAL(38,6) NOT NULL,
        ton_het_han DECIMAL(38,6) NOT NULL,
        ton_kha_dung DECIMAL(38,6) NOT NULL,
        han_gan_nhat DATE NULL,
        so_lo BIGINT NOT NULL,
        gia_ban DECIMAL(38,6) NULL,
        sap_het_han BIT NOT NULL
    );

    INSERT @TonKho
        (id_thuoc,ma_thuoc,ten_thuoc,don_vi_tinh,ton_vat_ly,ton_het_han,ton_kha_dung,han_gan_nhat,so_lo,gia_ban,sap_het_han)
    SELECT
        T.ID,
        T.MaThuoc,
        T.TenThuoc,
        DVT.TenDVT,
        ISNULL(X.ton_vat_ly,0),
        ISNULL(X.ton_het_han,0),
        ISNULL(X.ton_kha_dung,0),
        X.han_gan_nhat,
        ISNULL(X.so_lo,0),
        T.GiaBan,
        CAST(CASE WHEN X.han_gan_nhat BETWEEN @Ngay AND DATEADD(DAY,30,@Ngay) THEN 1 ELSE 0 END AS BIT)
    FROM dbo.DM_Thuoc T
    LEFT JOIN dbo.DM_DonViTinh DVT
      ON DVT.IDCSKCB=T.IDCSKCB AND DVT.ID=T.IDDonViTinh
    OUTER APPLY
    (
        SELECT
            SUM(L.SoLuongTon) AS ton_vat_ly,
            SUM(CASE WHEN L.SoLuongTon>0 AND (L.Active=0 OR L.HanDung<@Ngay) THEN L.SoLuongTon ELSE 0 END) AS ton_het_han,
            SUM(CASE WHEN L.Active=1 AND L.SoLuongTon>0 AND (L.HanDung IS NULL OR L.HanDung>=@Ngay) THEN L.SoLuongTon ELSE 0 END) AS ton_kha_dung,
            MIN(CASE WHEN L.Active=1 AND L.SoLuongTon>0 AND (L.HanDung IS NULL OR L.HanDung>=@Ngay) THEN L.HanDung END) AS han_gan_nhat,
            SUM(CASE WHEN L.SoLuongTon>0 THEN CAST(1 AS BIGINT) ELSE CAST(0 AS BIGINT) END) AS so_lo
        FROM dbo.QL_Kho_LoThuoc L
        WHERE L.IDCSKCB=@IDCSKCB AND L.IDKho=@IDKho AND L.IDThuoc=T.ID
    ) X
    WHERE T.IDCSKCB=@IDCSKCB
      AND T.Active=1
      AND
      (
          @TuKhoa IS NULL
          OR T.MaThuoc LIKE N'%'+@TuKhoa+N'%'
          OR T.TenThuoc LIKE N'%'+@TuKhoa+N'%'
      );

    -- Filtering applies to the complete result before count and pagination.
    DELETE FROM @TonKho WHERE NOT
    (
        @TrangThai=N'tat_ca'
        OR (@TrangThai=N'con_thuoc' AND ton_kha_dung>0)
        OR (@TrangThai=N'het_thuoc' AND ton_vat_ly=0)
        OR (@TrangThai=N'sap_het_han' AND sap_het_han=1)
        OR (@TrangThai=N'het_han_khoa' AND ton_het_han>0)
    );

    SELECT COUNT_BIG(*) AS tong_so FROM @TonKho;

    SELECT *
    FROM @TonKho
    ORDER BY CASE WHEN ton_kha_dung<=0 THEN 0 ELSE 1 END,ten_thuoc,id_thuoc
    OFFSET (@Trang-1)*@KichThuocTrang ROWS
    FETCH NEXT @KichThuocTrang ROWS ONLY;
END;
GO
