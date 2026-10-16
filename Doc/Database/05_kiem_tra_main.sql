:ON ERROR EXIT
/* Final verifier for QLPM main schema v113. */
USE [QLPM];
GO
SET NOCOUNT ON;
GO

IF DB_NAME()<>N'QLPM'
    THROW 59090,N'Verifier chỉ được chạy trên database QLPM.',1;

DECLARE @Loi NVARCHAR(MAX)=N'';

/* Required tables kept by the final contract. */
DECLARE @RequiredTable TABLE(TableName SYSNAME PRIMARY KEY);
INSERT @RequiredTable VALUES
(N'QL_ChiDinh_CT'),(N'DM_NhanVien'),(N'DM_NhanVien_CSKCB'),(N'DM_ChucDanh'),
(N'DM_LoaiToaThuoc'),(N'QL_ToaThuoc_CT'),(N'HT_JSON_CSKCB'),
(N'HT_JSON_DongBo_Lich'),(N'QLPM_SchemaVersion'),
(N'QL_ToaThuoc'),(N'QL_ToaThuoc_PhienBan'),(N'QL_ToaThuoc_LanGui'),
(N'QL_ToaThuoc_Audit'),(N'HT_LienThongToaThuoc_CauHinh'),(N'HT_LienThongToaThuoc_BacSi'),
(N'HT_KySoPdf_Mau'),(N'QL_KySoPdf_TaiLieu'),(N'QL_KySoPdf_Audit');

SELECT @Loi+=N'- Thiếu bảng bắt buộc dbo.'+R.TableName+N'.'+CHAR(13)+CHAR(10)
FROM @RequiredTable R
WHERE OBJECT_ID(N'dbo.'+R.TableName,N'U') IS NULL;

IF COL_LENGTH(N'dbo.QL_VaoVien',N'NgayLuuKhamLanDau') IS NULL
    SET @Loi+=N'- QL_VaoVien thiếu NgayLuuKhamLanDau.'+CHAR(13)+CHAR(10);
ELSE IF NOT EXISTS
(
    SELECT 1 FROM sys.columns C
    INNER JOIN sys.types T ON T.user_type_id=C.user_type_id
    WHERE C.object_id=OBJECT_ID(N'dbo.QL_VaoVien')
      AND C.name=N'NgayLuuKhamLanDau' AND T.name=N'datetime2'
      AND C.scale=0 AND C.is_nullable=1
)
    SET @Loi+=N'- QL_VaoVien.NgayLuuKhamLanDau phải là DATETIME2(0) NULL.'+CHAR(13)+CHAR(10);

IF COL_LENGTH(N'dbo.QL_VaoVien',N'NgayCapNhatKham') IS NULL
    SET @Loi+=N'- QL_VaoVien thiếu NgayCapNhatKham.'+CHAR(13)+CHAR(10);
ELSE IF NOT EXISTS
(
    SELECT 1 FROM sys.columns C
    INNER JOIN sys.types T ON T.user_type_id=C.user_type_id
    WHERE C.object_id=OBJECT_ID(N'dbo.QL_VaoVien')
      AND C.name=N'NgayCapNhatKham' AND T.name=N'datetime2'
      AND C.scale=0 AND C.is_nullable=1
)
    SET @Loi+=N'- QL_VaoVien.NgayCapNhatKham phải là DATETIME2(0) NULL.'+CHAR(13)+CHAR(10);

IF EXISTS
(
    SELECT 1 FROM dbo.QL_VaoVien
    WHERE (NgayLuuKhamLanDau IS NULL AND NgayCapNhatKham IS NOT NULL)
       OR (NgayLuuKhamLanDau IS NOT NULL AND NgayCapNhatKham<NgayLuuKhamLanDau)
)
    SET @Loi+=N'- Mốc lưu/cập nhật khám trên QL_VaoVien không hợp lệ.'+CHAR(13)+CHAR(10);

/* CLS file: PDF or supported raster image. */
IF COL_LENGTH(N'dbo.QL_ChiDinh_CT',N'DuongDanKetQua') IS NULL
    SET @Loi+=N'- Thiếu QL_ChiDinh_CT.DuongDanKetQua.'+CHAR(13)+CHAR(10);
ELSE IF NOT EXISTS
(
    SELECT 1 FROM sys.columns C
    INNER JOIN sys.types T ON T.user_type_id=C.user_type_id
    WHERE C.object_id=OBJECT_ID(N'dbo.QL_ChiDinh_CT')
      AND C.name=N'DuongDanKetQua' AND T.name=N'nvarchar'
      AND C.max_length=2000 AND C.is_nullable=1
)
    SET @Loi+=N'- QL_ChiDinh_CT.DuongDanKetQua phải là NVARCHAR(1000) NULL.'+CHAR(13)+CHAR(10);

IF EXISTS
(
    SELECT 1 FROM dbo.QL_ChiDinh_CT
    WHERE NULLIF(LTRIM(RTRIM(DuongDanKetQua)),N'') IS NOT NULL
      AND LOWER(RIGHT(RTRIM(DuongDanKetQua),4)) NOT IN(N'.pdf',N'.jpg',N'.png')
      AND LOWER(RIGHT(RTRIM(DuongDanKetQua),5)) NOT IN(N'.jpeg',N'.webp')
)
    SET @Loi+=N'- QL_ChiDinh_CT còn đường dẫn kết quả không phải PDF.'+CHAR(13)+CHAR(10);

/* No structured or legacy CLS storage remains. */
DECLARE @ForbiddenTable TABLE(TableName SYSNAME PRIMARY KEY);
INSERT @ForbiddenTable VALUES
(N'QL_CLS_DM_TriSoXN'),(N'QL_CLS_FormKQXN'),(N'QL_CLS_FormKQXN_CT'),
(N'QL_CLS_KetQuaXN_CT'),(N'QL_CLS_PhieuKetQua'),(N'QL_CLS_PhieuKetQua_File'),
(N'QL_CLS_KetQua_LichSu'),(N'QL_CLS_DichVu_FormKQ'),
(N'QL_KetQuaCLS'),(N'QL_KetQuaCLS_File'),(N'DM_LoaiDonThuoc'),
(N'QL_Thuoc_Di_Ung'),(N'QL_PhieuKham'),(N'sysdiagrams');

SELECT @Loi+=N'- Còn bảng legacy dbo.'+T.name+N'.'+CHAR(13)+CHAR(10)
FROM sys.tables T
WHERE SCHEMA_NAME(T.schema_id)=N'dbo'
  AND (T.name LIKE N'DSS[_]%' OR EXISTS(SELECT 1 FROM @ForbiddenTable F WHERE F.TableName=T.name));

/* No legacy columns remain. */
DECLARE @ForbiddenColumn TABLE(TableName SYSNAME,ColumnName SYSNAME,PRIMARY KEY(TableName,ColumnName));
INSERT @ForbiddenColumn VALUES
(N'DM_NhanVien',N'UserId'),(N'DM_NhanVien',N'IDCSKCB'),(N'DM_NhanVien',N'ChucDanh'),
(N'DM_DichVu',N'LoaiKetQua'),(N'DM_DichVu',N'IDFormKQ'),
(N'QL_BenhNhan',N'GioiTinh'),(N'QL_BenhNhan',N'Tuoi'),
(N'DM_PhacDo',N'NoiDung'),(N'DM_PhacDo',N'IDICD10'),(N'DM_PhacDo',N'BanDau'),(N'DM_PhacDo',N'BenhChinh'),(N'DM_PhacDo',N'BenhKhac'),
(N'QL_ChiDinh_CT',N'NgayGioThucHien'),(N'QL_ChiDinh_CT',N'NgayGioKetQua'),
(N'QL_ChiDinh_CT',N'IDNhanVienThucHien'),(N'QL_ChiDinh_CT',N'IDBacSiThucHien'),(N'QL_ChiDinh_CT',N'IDPhieuKetQua'),
(N'QL_VaoVien',N'MaLoaiDonThuoc'),(N'QL_VaoVien',N'MaLoaiToaThuoc'),(N'QL_VaoVien',N'HuongDieuTri'),(N'QL_VaoVien',N'GhiChu'),
(N'QL_PhieuSinhHieu',N'HuyetAp'),
(N'QL_ToaThuoc_CT',N'MaLoaiDonThuoc'),(N'DM_NhomHang',N'MaLoaiDonThuoc'),
(N'DM_LoaiToaThuoc',N'MaLoaiDonThuoc'),(N'DM_LoaiToaThuoc',N'TenLoaiDonThuoc');

SELECT @Loi+=N'- Còn cột legacy dbo.'+F.TableName+N'.'+F.ColumnName+N'.'+CHAR(13)+CHAR(10)
FROM @ForbiddenColumn F
WHERE COL_LENGTH(N'dbo.'+F.TableName,F.ColumnName) IS NOT NULL;

/* Visit notes are split by ownership: reception note vs doctor instructions. */
IF COL_LENGTH(N'dbo.QL_VaoVien',N'GhiChuTiepNhan') IS NULL
    SET @Loi+=N'- QL_VaoVien thiếu GhiChuTiepNhan.'+CHAR(13)+CHAR(10);
ELSE IF NOT EXISTS
(
    SELECT 1 FROM sys.columns C
    INNER JOIN sys.types T ON T.user_type_id=C.user_type_id
    WHERE C.object_id=OBJECT_ID(N'dbo.QL_VaoVien')
      AND C.name=N'GhiChuTiepNhan'
      AND T.name=N'nvarchar' AND C.max_length=2000 AND C.is_nullable=1
)
    SET @Loi+=N'- QL_VaoVien.GhiChuTiepNhan phải là NVARCHAR(1000) NULL.'+CHAR(13)+CHAR(10);

IF COL_LENGTH(N'dbo.QL_VaoVien',N'DanDo') IS NULL
    SET @Loi+=N'- QL_VaoVien thiếu DanDo.'+CHAR(13)+CHAR(10);
ELSE IF NOT EXISTS
(
    SELECT 1 FROM sys.columns C
    INNER JOIN sys.types T ON T.user_type_id=C.user_type_id
    WHERE C.object_id=OBJECT_ID(N'dbo.QL_VaoVien')
      AND C.name=N'DanDo'
      AND T.name=N'nvarchar' AND C.max_length=2000 AND C.is_nullable=1
)
    SET @Loi+=N'- QL_VaoVien.DanDo phải là NVARCHAR(1000) NULL.'+CHAR(13)+CHAR(10);

/* Employee N-N facility mapping. */
IF COL_LENGTH(N'dbo.DM_NhanVien',N'IDChucDanh') IS NULL
    SET @Loi+=N'- DM_NhanVien thiếu IDChucDanh.'+CHAR(13)+CHAR(10);

IF OBJECT_ID(N'dbo.DM_NhanVien_CSKCB',N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS
    (
        SELECT 1 FROM sys.key_constraints K
        INNER JOIN sys.index_columns I1 ON I1.object_id=K.parent_object_id AND I1.index_id=K.unique_index_id AND I1.key_ordinal=1
        INNER JOIN sys.columns C1 ON C1.object_id=I1.object_id AND C1.column_id=I1.column_id
        INNER JOIN sys.index_columns I2 ON I2.object_id=K.parent_object_id AND I2.index_id=K.unique_index_id AND I2.key_ordinal=2
        INNER JOIN sys.columns C2 ON C2.object_id=I2.object_id AND C2.column_id=I2.column_id
        WHERE K.parent_object_id=OBJECT_ID(N'dbo.DM_NhanVien_CSKCB') AND K.type=N'PK'
          AND C1.name=N'IDNhanVien' AND C2.name=N'IDCSKCB'
    )
        SET @Loi+=N'- DM_NhanVien_CSKCB thiếu PK (IDNhanVien,IDCSKCB).'+CHAR(13)+CHAR(10);

    IF EXISTS
    (
        SELECT 1 FROM dbo.DM_NhanVien_CSKCB M
        LEFT JOIN dbo.DM_NhanVien N ON N.ID=M.IDNhanVien
        LEFT JOIN dbo.DM_CSKCB C ON C.ID=M.IDCSKCB
        WHERE N.ID IS NULL OR C.ID IS NULL
    )
        SET @Loi+=N'- DM_NhanVien_CSKCB có mapping mồ côi.'+CHAR(13)+CHAR(10);
END;

/* DM_ChucDanh must equal the exact canonical set, no LEGACY/random code. */
IF OBJECT_ID(N'dbo.DM_ChucDanh',N'U') IS NOT NULL
BEGIN
    DECLARE @CanonicalTitle TABLE(Ma NVARCHAR(60) PRIMARY KEY,Ten NVARCHAR(200),VietTat NVARCHAR(50),Active BIT);
    INSERT @CanonicalTitle VALUES
    (N'1',N'Bác sĩ',N'BS',1),(N'2',N'Y sĩ',N'YS',1),(N'3',N'Điều dưỡng',N'ĐD',1),
    (N'4',N'Nữ hộ sinh',N'NHS',1),(N'5',N'Kỹ thuật viên',N'KTV',1),
    (N'6',N'Cử nhân CĐHA',N'CN CĐHA',1),(N'7',N'Dược sĩ đại học',N'DSĐH',1),
    (N'8',N'Dược sĩ trung cấp',N'DSTC',1),(N'9',N'Lương y',N'LY',0),
    (N'10',N'Cử nhân xét nghiệm',N'CN XN',1),(N'11',N'Dược sĩ cao đẳng',N'DSCĐ',1);

    IF (SELECT COUNT(*) FROM dbo.DM_ChucDanh)<>11
       OR EXISTS
       (
           SELECT 1 FROM @CanonicalTitle E
           FULL JOIN dbo.DM_ChucDanh A ON A.MaChucDanh=E.Ma
           WHERE E.Ma IS NULL OR A.ID IS NULL OR A.TenChucDanh<>E.Ten
              OR ISNULL(A.VietTat,N'')<>ISNULL(E.VietTat,N'') OR A.Active<>E.Active
       )
        SET @Loi+=N'- DM_ChucDanh không đúng chính xác bộ canonical 1..11.'+CHAR(13)+CHAR(10);

    IF EXISTS
    (
        SELECT 1 FROM dbo.DM_NhanVien N
        LEFT JOIN dbo.DM_ChucDanh C ON C.ID=N.IDChucDanh
        WHERE N.IDChucDanh IS NOT NULL AND C.ID IS NULL
    )
        SET @Loi+=N'- DM_NhanVien.IDChucDanh có tham chiếu mồ côi.'+CHAR(13)+CHAR(10);
END;

/* Canonical prescription type and per-prescription-line storage. */
IF COL_LENGTH(N'dbo.DM_LoaiToaThuoc',N'MaLoaiToaThuoc') IS NULL
OR COL_LENGTH(N'dbo.DM_LoaiToaThuoc',N'TenLoaiToaThuoc') IS NULL
    SET @Loi+=N'- DM_LoaiToaThuoc thiếu cột canonical.'+CHAR(13)+CHAR(10);
ELSE IF NOT EXISTS
(
    SELECT 1 FROM sys.columns C INNER JOIN sys.types T ON T.user_type_id=C.user_type_id
    WHERE C.object_id=OBJECT_ID(N'dbo.DM_LoaiToaThuoc') AND C.name=N'MaLoaiToaThuoc'
      AND T.name=N'nvarchar' AND C.max_length=2 AND C.is_nullable=0
)
    SET @Loi+=N'- DM_LoaiToaThuoc.MaLoaiToaThuoc phải là NVARCHAR(1) NOT NULL.'+CHAR(13)+CHAR(10);

IF COL_LENGTH(N'dbo.DM_LoaiToaThuoc',N'TenLoaiToaThuoc') IS NOT NULL
AND NOT EXISTS
(
    SELECT 1 FROM sys.columns C INNER JOIN sys.types T ON T.user_type_id=C.user_type_id
    WHERE C.object_id=OBJECT_ID(N'dbo.DM_LoaiToaThuoc') AND C.name=N'TenLoaiToaThuoc'
      AND T.name=N'nvarchar' AND C.max_length=1000 AND C.is_nullable=0
)
    SET @Loi+=N'- DM_LoaiToaThuoc.TenLoaiToaThuoc phai la NVARCHAR(500) NOT NULL.'+CHAR(13)+CHAR(10);

IF COL_LENGTH(N'dbo.QL_ToaThuoc_CT',N'MaLoaiToaThuoc') IS NULL
    SET @Loi+=N'- QL_ToaThuoc_CT thiếu MaLoaiToaThuoc.'+CHAR(13)+CHAR(10);
ELSE IF EXISTS(SELECT 1 FROM dbo.QL_ToaThuoc_CT WHERE MaLoaiToaThuoc NOT IN(N'c',N'n',N'h'))
    SET @Loi+=N'- QL_ToaThuoc_CT có mã loại toa ngoài c/n/h.'+CHAR(13)+CHAR(10);

IF COL_LENGTH(N'dbo.QL_ToaThuoc_CT',N'HoatChat') IS NULL
    SET @Loi+=N'- QL_ToaThuoc_CT thiếu HoatChat snapshot.'+CHAR(13)+CHAR(10);
ELSE IF NOT EXISTS
(
    SELECT 1 FROM sys.columns C
    INNER JOIN sys.types T ON T.user_type_id=C.user_type_id
    WHERE C.object_id=OBJECT_ID(N'dbo.QL_ToaThuoc_CT')
      AND C.name=N'HoatChat'
      AND T.name=N'nvarchar'
      AND C.max_length>=2000
      AND C.is_nullable=1
)
    SET @Loi+=N'- QL_ToaThuoc_CT.HoatChat phải là NVARCHAR(1000) NULL hoặc lớn hơn.'+CHAR(13)+CHAR(10);

IF OBJECT_ID(N'dbo.DM_LoaiToaThuoc',N'U') IS NOT NULL
AND EXISTS
(
    SELECT V.Ma FROM (VALUES(N'c'),(N'n'),(N'h')) V(Ma)
    WHERE NOT EXISTS(SELECT 1 FROM dbo.DM_LoaiToaThuoc T WHERE T.MaLoaiToaThuoc=V.Ma AND T.Active=1)
)
    SET @Loi+=N'- DM_LoaiToaThuoc thiếu một trong ba mã active c/n/h.'+CHAR(13)+CHAR(10);

IF OBJECT_ID(N'dbo.STO_QL_Kham_Luu',N'P') IS NOT NULL
AND OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_Luu')) LIKE N'%Một toa chỉ được chứa thuốc cùng loại toa đã chọn.%'
    SET @Loi+=N'- STO_QL_Kham_Luu còn chặn kê chung thuốc c/n/h trong cùng lượt khám.'+CHAR(13)+CHAR(10);

IF OBJECT_ID(N'dbo.STO_QL_Kham_Luu',N'P') IS NOT NULL
AND OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_Luu')) LIKE N'%@HuyetAp%'
    SET @Loi+=N'- STO_QL_Kham_Luu còn tham số HuyetAp trùng với HA_TT/HA_TR.'+CHAR(13)+CHAR(10);

IF OBJECT_ID(N'dbo.STO_QL_Kham_Luu',N'P') IS NOT NULL
AND
(
    OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_Luu')) LIKE N'%@GhiChu NVARCHAR%'
    OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_Luu')) LIKE N'%GhiChu=@GhiChu%'
    OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_Luu')) NOT LIKE N'%@DanDo NVARCHAR%'
    OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_Luu')) NOT LIKE N'%DanDo=@DanDo%'
)
    SET @Loi+=N'- STO_QL_Kham_Luu chưa dùng DanDo riêng; không được ghi chung QL_VaoVien.GhiChu.'+CHAR(13)+CHAR(10);

IF OBJECT_ID(N'dbo.STO_QL_Kham_Luu',N'P') IS NOT NULL
AND
(
    OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_Luu')) LIKE N'%@HoTen%'
    OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_Luu')) LIKE N'%@NgaySinh%'
    OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_Luu')) LIKE N'%@GioiTinh%'
    OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_Luu')) LIKE N'%UPDATE dbo.QL_BenhNhan%'
)
    SET @Loi+=N'- STO_QL_Kham_Luu còn sửa thông tin hành chính bệnh nhân; tab Khám chỉ được đọc các trường này.'+CHAR(13)+CHAR(10);

IF OBJECT_ID(N'dbo.STO_QL_Kham_Luu',N'P') IS NOT NULL
AND
(
    OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_Luu')) LIKE N'%QL_PhieuKham%'
    OR EXISTS
    (
        SELECT 1 FROM sys.parameters
        WHERE object_id=OBJECT_ID(N'dbo.STO_QL_Kham_Luu') AND name=N'@IDPhieuKham'
    )
    OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_Luu')) NOT LIKE N'%NgayLuuKhamLanDau=COALESCE%'
    OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_Luu')) NOT LIKE N'%NgayCapNhatKham=SYSDATETIME()%'
)
    SET @Loi+=N'- STO_QL_Kham_Luu chưa dùng QL_VaoVien làm master duy nhất của lượt khám.'+CHAR(13)+CHAR(10);

IF OBJECT_ID(N'dbo.STO_QL_Kham_HoanTat',N'P') IS NOT NULL
AND
(
    OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_HoanTat')) LIKE N'%QL_PhieuKham%'
    OR EXISTS
    (
        SELECT 1 FROM sys.parameters
        WHERE object_id=OBJECT_ID(N'dbo.STO_QL_Kham_HoanTat') AND name=N'@IDPhieuKham'
    )
    OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_HoanTat')) NOT LIKE N'%@NgayLuuKhamLanDau%'
)
    SET @Loi+=N'- STO_QL_Kham_HoanTat còn phụ thuộc phiếu khám riêng.'+CHAR(13)+CHAR(10);

/* v97 khóa theo từng dòng đã thu/có chứng từ; không khóa trắng toàn bộ hồ sơ khám.
   Vì vậy không còn kiểm tra literal ISNULL(CT.DaThu,0)=1 của contract cũ. */
IF OBJECT_ID(N'dbo.STO_QL_Kham_Luu',N'P') IS NOT NULL
AND
(
    OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_Luu')) NOT LIKE N'%QL_ThuTien_CT%'
    OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_Luu')) NOT LIKE N'%FN_QL_ThuTien_DongCoTheThu%'
    OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_Luu')) NOT LIKE N'%KhoaNghiepVu=1%'
    OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_Luu')) NOT LIKE N'%@KhoaCLS%'
    OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_Luu')) NOT LIKE N'%@KhoaToa%'
)
    SET @Loi+=N'- STO_QL_Kham_Luu chưa khóa đúng từng dòng chi phí đã thu/có chứng từ theo contract v97.'+CHAR(13)+CHAR(10);

IF OBJECT_ID(N'dbo.STO_QL_Kham_LichSu',N'P') IS NULL
OR UPPER(REPLACE(REPLACE(REPLACE(REPLACE(
       ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_LichSu')),N''),
       N' ',N''),NCHAR(9),N''),NCHAR(13),N''),NCHAR(10),N''))
   NOT LIKE N'%VV.ID<>@IDVAOVIENHIENTAIORVV.TRANGTHAIKHAM=2%'
    SET @Loi+=N'- STO_QL_Kham_LichSu chưa đưa lượt Khám xong hiện tại vào lịch sử khám.'+CHAR(13)+CHAR(10);

/* Chỉ phát hiện tham chiếu schema CLS đã xóa, không coi TÊN của hai
   procedure canonical v97/v100 là tham chiếu đến bảng QL_CLS_*.
   Các biểu thức legacy khác vẫn được rà trên cả hai procedure. */
SELECT @Loi+=N'- Module còn tham chiếu legacy: '
    +QUOTENAME(OBJECT_SCHEMA_NAME(M.object_id))+N'.'+QUOTENAME(OBJECT_NAME(M.object_id))+N'.'+CHAR(13)+CHAR(10)
FROM sys.sql_modules M
WHERE
  (
       REPLACE(
           REPLACE(M.definition,N'STO_QL_Cls_DamBaoChiDinh',N''),
           N'STO_QL_Cls_LuuDuongDanKetQua',N'') LIKE N'%QL[_]CLS[_]%'
    OR M.definition LIKE N'%QL[_]KetQuaCLS%'
    OR M.definition LIKE N'%DM[_]LoaiDonThuoc%'
    OR M.definition LIKE N'%MaLoaiDonThuoc%'
    OR M.definition LIKE N'%DM[_]NhanVien%[.]ChucDanh%'
    OR M.definition LIKE N'%DM[_]DichVu%[.]LoaiKetQua%'
    OR M.definition LIKE N'%DM[_]DichVu%[.]IDFormKQ%'
    OR M.definition LIKE N'%HuongDieuTri%'
  );

/* Hai STO dbo canonical v97/v100 là ngoại lệ có chủ đích.
   Verifier ở cuối file vẫn kiểm tra nội dung guard THUTIENCHIDINHTRUOC. */
IF EXISTS
(
    SELECT 1
    FROM sys.procedures
    WHERE name LIKE N'STO[_]QL[_]CLS[_]%'
      AND object_id<>ISNULL(OBJECT_ID(N'dbo.STO_QL_Cls_DamBaoChiDinh',N'P'),-1)
      AND object_id<>ISNULL(OBJECT_ID(N'dbo.STO_QL_Cls_LuuDuongDanKetQua',N'P'),-1)
)
    SET @Loi+=N'- Còn STO structured CLS legacy ngoài hai STO canonical v97/v100.'+CHAR(13)+CHAR(10);
IF OBJECT_ID(N'dbo.TR_QL_ChiDinh_CT_BaoVeKetQuaCLS',N'TR') IS NOT NULL
    SET @Loi+=N'- Còn trigger CLS structured cũ.'+CHAR(13)+CHAR(10);

/* Thu ngân / kho runtime. */
DECLARE @RequiredCashWarehouseTable TABLE(TableName SYSNAME PRIMARY KEY);
INSERT @RequiredCashWarehouseTable VALUES
(N'QL_ThuTien'),(N'QL_ThuTien_CT'),(N'QL_ThuTien_LichSu'),(N'QL_ThuTien_SoChungTu'),
(N'QL_ThuTien_ChungTu'),(N'QL_ThuTien_ChungTu_CT'),(N'DM_Kho'),(N'DM_Thuoc_DonViQuyDoi'),
(N'DM_NhaCungCap'),(N'QL_Kho_LoThuoc'),(N'QL_Kho_ChungTu'),(N'QL_Kho_ChungTu_CT'),(N'QL_Kho_GiaoDich');

SELECT @Loi+=N'- Thiếu bảng dbo.'+T.TableName+N'.'+CHAR(13)+CHAR(10)
FROM @RequiredCashWarehouseTable T
WHERE OBJECT_ID(N'dbo.'+T.TableName,N'U') IS NULL;

IF OBJECT_ID(N'dbo.QL_ThuTien_CT',N'U') IS NOT NULL
BEGIN
    IF COL_LENGTH(N'dbo.QL_ThuTien_CT',N'PhuThu') IS NULL
        SET @Loi+=N'- QL_ThuTien_CT thiếu PhuThu.'+CHAR(13)+CHAR(10);
    IF COL_LENGTH(N'dbo.QL_ThuTien_CT',N'GiamPhanTram') IS NULL
        SET @Loi+=N'- QL_ThuTien_CT thiếu GiamPhanTram.'+CHAR(13)+CHAR(10);
    IF COL_LENGTH(N'dbo.QL_ThuTien_CT',N'DaHuy') IS NULL
        SET @Loi+=N'- QL_ThuTien_CT thiếu DaHuy legacy/audit.'+CHAR(13)+CHAR(10);
    IF COL_LENGTH(N'dbo.QL_ThuTien_CT',N'NgayGioHuy') IS NULL
        SET @Loi+=N'- QL_ThuTien_CT thiếu NgayGioHuy.'+CHAR(13)+CHAR(10);
    IF COL_LENGTH(N'dbo.QL_ThuTien_CT',N'IDNhanVienHuy') IS NULL
        SET @Loi+=N'- QL_ThuTien_CT thiếu IDNhanVienHuy.'+CHAR(13)+CHAR(10);
    IF COL_LENGTH(N'dbo.QL_ThuTien_CT',N'IDTaiKhoanHuy') IS NULL
        SET @Loi+=N'- QL_ThuTien_CT thiếu IDTaiKhoanHuy.'+CHAR(13)+CHAR(10);
END;

IF OBJECT_ID(N'dbo.QL_ThuTien',N'U') IS NOT NULL
AND COL_LENGTH(N'dbo.QL_ThuTien',N'IDTaiKhoanThu') IS NULL
    SET @Loi+=N'- QL_ThuTien thiếu IDTaiKhoanThu để audit global admin.'+CHAR(13)+CHAR(10);

IF OBJECT_ID(N'dbo.QL_ThuTien_LichSu',N'U') IS NOT NULL
AND COL_LENGTH(N'dbo.QL_ThuTien_LichSu',N'IDTaiKhoan') IS NULL
    SET @Loi+=N'- QL_ThuTien_LichSu thiếu IDTaiKhoan.'+CHAR(13)+CHAR(10);

IF OBJECT_ID(N'dbo.QL_ThuTien_ChungTu',N'U') IS NOT NULL
BEGIN
    IF COL_LENGTH(N'dbo.QL_ThuTien_ChungTu',N'IDChungTuGoc') IS NULL
        SET @Loi+=N'- QL_ThuTien_ChungTu thiếu liên kết chứng từ gốc.'+CHAR(13)+CHAR(10);
    IF COL_LENGTH(N'dbo.QL_ThuTien_ChungTu',N'LyDoHuy') IS NULL
        SET @Loi+=N'- QL_ThuTien_ChungTu thiếu audit lý do hủy.'+CHAR(13)+CHAR(10);
END;

IF OBJECT_ID(N'dbo.QL_ThuTien_CT',N'U') IS NOT NULL
AND EXISTS(SELECT 1 FROM dbo.QL_ThuTien_CT WHERE ISNULL(DaHuy,0)=1)
    SET @Loi+=N'- QL_ThuTien_CT còn DaHuy=1; hủy thu phải hoàn tác dòng về Chưa thu.'+CHAR(13)+CHAR(10);

IF OBJECT_ID(N'dbo.QL_ThuTien',N'U') IS NOT NULL
BEGIN
    IF EXISTS(SELECT 1 FROM dbo.QL_ThuTien WHERE ISNULL(DaHuy,0)=1)
        SET @Loi+=N'- QL_ThuTien còn DaHuy=1; bảng tổng hợp chỉ có Chưa thu/Đã thu.'+CHAR(13)+CHAR(10);

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes I
        INNER JOIN sys.index_columns IC1
          ON IC1.object_id=I.object_id AND IC1.index_id=I.index_id AND IC1.key_ordinal=1
        INNER JOIN sys.columns C1
          ON C1.object_id=IC1.object_id AND C1.column_id=IC1.column_id
        INNER JOIN sys.index_columns IC2
          ON IC2.object_id=I.object_id AND IC2.index_id=I.index_id AND IC2.key_ordinal=2
        INNER JOIN sys.columns C2
          ON C2.object_id=IC2.object_id AND C2.column_id=IC2.column_id
        WHERE I.object_id=OBJECT_ID(N'dbo.QL_ThuTien')
          AND I.is_unique=1
          AND C1.name=N'IDCSKCB'
          AND C2.name=N'IDVaoVien'
    )
        SET @Loi+=N'- QL_ThuTien thiếu unique (IDCSKCB,IDVaoVien).'+CHAR(13)+CHAR(10);
END;

IF OBJECT_ID(N'dbo.QL_Kho_LoThuoc',N'U') IS NOT NULL
AND EXISTS(SELECT 1 FROM dbo.QL_Kho_LoThuoc WHERE SoLuongTon<0)
    SET @Loi+=N'- QL_Kho_LoThuoc có tồn âm.'+CHAR(13)+CHAR(10);

IF OBJECT_ID(N'dbo.QL_Kho_ChungTu_CT',N'U') IS NOT NULL
AND (COL_LENGTH(N'dbo.QL_Kho_ChungTu_CT',N'SoLuongDaHoan') IS NULL
     OR EXISTS(SELECT 1 FROM (SELECT [ID], [IDCSKCB], [IDChungTu] AS [IDXuat], [IDToaThuocCT], [IDThuoc], [IDLoThuoc], [SoLuongCoSo], [GiaVon], [ThanhTien], [SoLuongDaHoan], [IDThuTienChungTuCT], [HeSoQuyDoi] FROM dbo.QL_Kho_ChungTu_CT WHERE LoaiChungTu='CAP_PHAT') V114R1 WHERE SoLuongDaHoan<0 OR SoLuongDaHoan>SoLuongCoSo))
    SET @Loi+=N'- QL_Kho_Xuat_CT thiếu hoặc sai số lượng đã hoàn.'+CHAR(13)+CHAR(10);

IF OBJECT_ID(N'dbo.QL_Kho_ChungTu',N'U') IS NOT NULL
AND EXISTS
(
    SELECT 1
    FROM (SELECT [ID], [IDCSKCB], [IDKho], [IDVaoVien], [SoPhieu], [NgayGio] AS [NgayXuat], [IDNhanVien] AS [IDNhanVienXuat], [TongGiaVon], [GhiChu], [DaHuy], [IDTaiKhoan] AS [IDTaiKhoanXuat], [TenNguoiThucHienSnapshot] AS [TenNguoiXuatSnapshot] FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='CAP_PHAT') X
    INNER JOIN (SELECT [ID], [IDCSKCB], [IDChungTu] AS [IDXuat], [IDToaThuocCT], [IDThuoc], [IDLoThuoc], [SoLuongCoSo], [GiaVon], [ThanhTien], [SoLuongDaHoan], [IDThuTienChungTuCT], [HeSoQuyDoi] FROM dbo.QL_Kho_ChungTu_CT WHERE LoaiChungTu='CAP_PHAT') XCT
      ON XCT.IDCSKCB=X.IDCSKCB AND XCT.IDXuat=X.ID
    LEFT JOIN dbo.QL_ThuTien T
      ON T.IDCSKCB=X.IDCSKCB AND T.IDVaoVien=X.IDVaoVien
    LEFT JOIN dbo.QL_ThuTien_CT PAY
      ON PAY.IDCSKCB=XCT.IDCSKCB
     AND PAY.IDThuTien=T.ID
     AND PAY.IDToaThuocCT=XCT.IDToaThuocCT
     AND ISNULL(PAY.DaThu,0)=1
    WHERE X.DaHuy=0
      AND PAY.ID IS NULL
)
    SET @Loi+=N'- Có dòng xuất kho còn hiệu lực nhưng dòng toa tương ứng chưa được thu tiền.'+CHAR(13)+CHAR(10);

/* Critical runtime procedures rebuilt against the final schema. */
DECLARE @RequiredProcedure TABLE(ProcName SYSNAME PRIMARY KEY);
INSERT @RequiredProcedure VALUES
(N'STO_QL_TiepNhan_Luu'),(N'STO_QL_TiepNhan_DanhSach'),
(N'STO_QL_Kham_ChonBenhNhan'),(N'STO_QL_Kham_HuyDangKham'),(N'STO_QL_Kham_Luu'),(N'STO_QL_Kham_HoanTat'),(N'STO_QL_Kham_LichSu'),
(N'STO_QL_Kham_LayToaCu'),(N'STO_QL_Kham_ChiTietLanKhamCu'),
(N'STO_DM_PhacDo_DanhSach'),(N'STO_DM_PhacDo_ChiTiet'),(N'STO_DM_PhacDo_Luu'),
(N'STO_HT_Dang_Nhap_Lay_Tai_Khoan'),(N'STO_HT_Lay_Quyen_Tai_Khoan'),
(N'STO_HT_Nhan_Vien_Danh_Sach'),(N'STO_HT_Nhan_Vien_Luu'),
(N'STO_QL_ThuNgan_DanhSach'),(N'STO_QL_ThuNgan_ChiTiet'),(N'STO_QL_ThuNgan_ThuTien'),
(N'STO_QL_ThuNgan_CapSoChungTu'),(N'STO_QL_ThuNgan_DanhSachChungTu'),(N'STO_QL_ThuNgan_ChiTietChungTu'),
(N'STO_QL_ThuNgan_HuyChungTu'),(N'STO_QL_ThuNgan_HoanTien'),
(N'STO_QL_Kho_DanhSachKho'),(N'STO_QL_Kho_TonKho_DanhSach'),(N'STO_QL_Kho_Nhap'),
(N'STO_DM_NhaCungCap_DanhSach'),(N'STO_DM_NhaCungCap_QuanLy_DanhSach'),
(N'STO_DM_NhaCungCap_Luu'),(N'STO_DM_NhaCungCap_Xoa'),
(N'STO_QL_KySoPdf_Mau_DanhSach'),(N'STO_QL_KySoPdf_Mau_Lay'),(N'STO_QL_KySoPdf_Mau_Luu'),
(N'STO_QL_Kho_Nhap_DanhSach'),(N'STO_QL_Kho_Nhap_ChiTiet'),(N'STO_QL_Kho_Nhap_Huy'),
(N'STO_QL_Kho_LoThuoc_DanhSach'),(N'STO_QL_Kho_DieuChinh_Luu'),(N'STO_QL_Kho_DieuChinh_DanhSach'),
(N'STO_QL_Kho_Thuoc_Danh_Sach'),(N'STO_QL_Kho_Thuoc_GanNhom'),
(N'STO_QL_Kho_Xuat_DanhSach'),(N'STO_QL_Kho_Xuat_ChiTiet'),(N'STO_QL_Kho_Xuat_TheoToa'),(N'STO_QL_Kho_Xuat_Hoan'),
(N'STO_QL_Kham_KiemTraTonThuoc');

SELECT @Loi+=N'- Thiếu procedure dbo.'+R.ProcName+N'.'+CHAR(13)+CHAR(10)
FROM @RequiredProcedure R WHERE OBJECT_ID(N'dbo.'+R.ProcName,N'P') IS NULL;

IF OBJECT_ID(N'dbo.STO_QL_Kho_Xuat_TheoToa',N'P') IS NOT NULL
AND OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kho_Xuat_TheoToa')) NOT LIKE N'%IDToaThuocCT=Y.IDToaThuocCT%DaThu%'
    SET @Loi+=N'- STO_QL_Kho_Xuat_TheoToa chưa kiểm tra thanh toán theo từng dòng toa.'+CHAR(13)+CHAR(10);


/* Worklist phải lọc từ DB theo điều kiện vào phân hệ; UI không được nhận dòng chưa đủ điều kiện rồi mới chặn. */
IF OBJECT_ID(N'dbo.STO_QL_Kham_DanhSach',N'P') IS NULL
OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_DanhSach')) NOT LIKE N'%THUCONGKHAMDVTRUOC%'
OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_DanhSach')) NOT LIKE N'%ISNULL(P0.DaThu,0)=0%'
    SET @Loi+=N'- STO_QL_Kham_DanhSach chưa lọc BN chưa thu công khám khi cấu hình thu trước bật.'+CHAR(13)+CHAR(10);

IF OBJECT_ID(N'dbo.STO_QL_Kham_LichSu',N'P') IS NULL
OR UPPER(REPLACE(REPLACE(REPLACE(REPLACE(
       ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_LichSu')),N''),
       N' ',N''),NCHAR(9),N''),NCHAR(13),N''),NCHAR(10),N''))
   NOT LIKE N'%ANDVV.TRANGTHAIKHAM=2%'
OR UPPER(REPLACE(REPLACE(REPLACE(REPLACE(
       ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_LichSu')),N''),
       N' ',N''),NCHAR(9),N''),NCHAR(13),N''),NCHAR(10),N''))
   LIKE N'%VV.KHAM=1ORVV.KETOA=1%'
    SET @Loi+=N'- STO_QL_Kham_LichSu phải chỉ trả lượt TrangThaiKham=2; cờ Kham/KeToa không được coi là đã khám.'+CHAR(13)+CHAR(10);

IF OBJECT_ID(N'dbo.STO_QL_Kho_Xuat_DanhSach',N'P') IS NULL
OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kho_Xuat_DanhSach')) NOT LIKE N'%V.TrangThaiKham=2%'
OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kho_Xuat_DanhSach')) NOT LIKE N'%QL_ThuTien_ChungTu_CT%'
OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kho_Xuat_DanhSach')) NOT LIKE N'%D0.Loai=N''THUOC''%'
OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kho_Xuat_DanhSach')) NOT LIKE N'%C0.TrangThai=1%'
    SET @Loi+=N'- STO_QL_Kho_Xuat_DanhSach chưa lọc đúng Khám xong + chứng từ THU thuốc còn hiệu lực.'+CHAR(13)+CHAR(10);

IF OBJECT_ID(N'dbo.STO_QL_Kho_Xuat_ChiTiet',N'P') IS NULL
OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kho_Xuat_ChiTiet')) NOT LIKE N'%V.TrangThaiKham=2%'
OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kho_Xuat_ChiTiet')) NOT LIKE N'%QL_ThuTien_ChungTu_CT%'
OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kho_Xuat_ChiTiet')) NOT LIKE N'%D0.Loai=N''THUOC''%'
    SET @Loi+=N'- STO_QL_Kho_Xuat_ChiTiet chưa dùng cùng eligibility với danh sách cấp phát.'+CHAR(13)+CHAR(10);

IF OBJECT_ID(N'dbo.STO_QL_ThuNgan_DanhSach',N'P') IS NULL
OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_ThuNgan_DanhSach')) NOT LIKE N'%FN_QL_ThuTien_DongCoTheThu%'
    SET @Loi+=N'- STO_QL_ThuNgan_DanhSach chưa dùng eligibility tài chính chung.'+CHAR(13)+CHAR(10);

IF OBJECT_ID(N'dbo.STO_QL_ThuNgan_DanhSach',N'P') IS NOT NULL
AND
(
    OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_ThuNgan_DanhSach')) LIKE N'%CAST(2 AS TINYINT)%'
    OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_ThuNgan_DanhSach')) LIKE N'%CAST(3 AS TINYINT)%'
    OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_ThuNgan_DanhSach')) NOT LIKE N'%@TrangThai NOT IN(0,1)%'
)
    SET @Loi+=N'- STO_QL_ThuNgan_DanhSach phải chỉ có trạng thái Chưa thu (0) / Đã thu (1).'+CHAR(13)+CHAR(10);

IF OBJECT_ID(N'dbo.STO_QL_ThuNgan_ChiTiet',N'P') IS NOT NULL
AND
(
    OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_ThuNgan_ChiTiet')) NOT LIKE N'%AS da_thu%'
    OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_ThuNgan_ChiTiet')) LIKE N'%CAST(2 AS TINYINT)%'
    OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_ThuNgan_ChiTiet')) LIKE N'%CAST(3 AS TINYINT)%'
)
    SET @Loi+=N'- STO_QL_ThuNgan_ChiTiet chưa theo contract 2 trạng thái và thu chọn từng dòng.'+CHAR(13)+CHAR(10);

IF OBJECT_ID(N'dbo.STO_QL_ThuNgan_ChiTiet',N'P') IS NULL
OR UPPER(REPLACE(REPLACE(REPLACE(REPLACE(
       ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_ThuNgan_ChiTiet')),N''),
       N' ',N''),NCHAR(9),N''),NCHAR(13),N''),NCHAR(10),N''))
   LIKE N'%ANDISNULL(CT.DATHU,0)=0%'
    SET @Loi+=N'- STO_QL_ThuNgan_ChiTiet không được loại dòng đã thu; UI cần xem được Chưa thu / Đã thu / Tất cả.'+CHAR(13)+CHAR(10);

IF OBJECT_ID(N'dbo.STO_QL_ThuNgan_ThuTien',N'P') IS NOT NULL
AND
(
    OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_ThuNgan_ThuTien')) NOT LIKE N'%Chọn ít nhất một khoản cần thu%'
    OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_ThuNgan_ThuTien')) LIKE N'%CAST(3 AS TINYINT)%'
)
    SET @Loi+=N'- STO_QL_ThuNgan_ThuTien chưa theo contract thu chọn dòng với trạng thái 0/1.'+CHAR(13)+CHAR(10);

IF OBJECT_ID(N'dbo.STO_QL_ThuNgan_HuyNhom',N'P') IS NOT NULL
AND
(
    OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_ThuNgan_HuyNhom')) LIKE N'%DaHuy=1%'
    OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_ThuNgan_HuyNhom')) NOT LIKE N'%410 AS Status%'
)
    SET @Loi+=N'- STO legacy hủy nhóm phải bị vô hiệu hóa (410).'+CHAR(13)+CHAR(10);

IF OBJECT_ID(N'dbo.STO_QL_ThuNgan_HuyThu',N'P') IS NOT NULL
AND OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_ThuNgan_HuyThu')) LIKE N'%DaHuy=1%'
    SET @Loi+=N'- STO_QL_ThuNgan_HuyThu phải hoàn tác về Chưa thu, không sinh trạng thái Đã hủy.'+CHAR(13)+CHAR(10);

/* JSON versioning remains part of the runtime contract. */
IF COL_LENGTH(N'dbo.QL_Kho_ChungTu_CT',N'IDThuTienChungTuCT') IS NULL
 OR COL_LENGTH(N'dbo.QL_Kho_ChungTu_CT',N'HeSoQuyDoi') IS NULL
    SET @Loi+=N'- Thiếu liên kết nguồn thu/snapshot quy đổi v95.'+CHAR(13)+CHAR(10);
IF COL_LENGTH(N'dbo.QL_Kho_ChungTu_CT',N'TenThuocSnapshot') IS NULL
 OR COL_LENGTH(N'dbo.QL_Kho_ChungTu',N'TenNhaCungCapSnapshot') IS NULL
    SET @Loi+=N'- Thiếu snapshot chứng từ nhập kho v95.'+CHAR(13)+CHAR(10);
IF OBJECT_ID(N'dbo.STO_QL_Kho_DongDaCap',N'P') IS NULL
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kho_Xuat_Hoan')),N'') NOT LIKE N'%@HoanToanBo BIT=0%'
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kho_Nhap_Huy')),N'') NOT LIKE N'%LoaiChungTu=''DIEU_CHINH''%'
    SET @Loi+=N'- Thiếu STO hoàn theo dòng/hủy nhập an toàn v95.'+CHAR(13)+CHAR(10);
IF ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_ThuNgan_HuyThu')),N'') NOT LIKE N'%410 AS Status%'
    SET @Loi+=N'- STO legacy hủy toàn bộ phải bị vô hiệu hóa.'+CHAR(13)+CHAR(10);

IF OBJECT_ID(N'dbo.TR_DM_ChucDanh_JSON_VERSION',N'TR') IS NULL
    SET @Loi+=N'- Thiếu trigger TR_DM_ChucDanh_JSON_VERSION.'+CHAR(13)+CHAR(10);

/* v96: account audit is required for every new dispense; legacy is not backfilled. */
IF COL_LENGTH(N'dbo.QL_Kho_ChungTu',N'IDTaiKhoan') IS NULL
 OR COL_LENGTH(N'dbo.QL_Kho_ChungTu',N'TenNguoiThucHienSnapshot') IS NULL
 OR EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.QL_Kho_ChungTu') AND name=N'IDNhanVien' AND is_nullable=0)
    SET @Loi+=N'- Thiếu audit tài khoản/nhân viên nullable của phiếu cấp v96.'+CHAR(13)+CHAR(10);
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'dbo.QL_Kho_ChungTu')
              AND name=N'FK_V114_FK_QL_Kho_DieuChinh_TaiKhoan' AND is_disabled=0 AND is_not_trusted=0)
 OR NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.QL_Kho_ChungTu')
              AND name=N'CK_V114_CK_QL_Kho_Xuat_ActorSnapshot' AND is_disabled=0 AND is_not_trusted=0)
    SET @Loi+=N'- Thiếu constraint audit phiếu cấp v96.'+CHAR(13)+CHAR(10);
IF NOT EXISTS(SELECT 1 FROM sys.parameters WHERE object_id=OBJECT_ID(N'dbo.STO_QL_Kho_Xuat_TheoToa') AND name=N'@IDTaiKhoanXuat')
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kho_Xuat_TheoToa')),N'') NOT LIKE N'%T.LaQuanTriHeThong%'
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kho_Xuat_TheoToa')),N'') NOT LIKE N'%DM_NhanVien_CSKCB%'
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kho_Xuat_TheoToa')),N'') NOT LIKE N'%TenNguoiThucHienSnapshot%'
    SET @Loi+=N'- STO phát thuốc chưa xác thực/lưu tài khoản thực hiện v96.'+CHAR(13)+CHAR(10);

/* v97: clinical state and payment state stay independent.
   STO_QL_Cls_DamBaoChiDinh là helper canonical v97, không phải structured CLS legacy. */
IF OBJECT_ID(N'dbo.FN_QL_ThuTien_DongCoTheThu',N'IF') IS NULL
 OR OBJECT_ID(N'dbo.STO_QL_ThuTien_DongBoNguon',N'P') IS NULL
 OR OBJECT_ID(N'dbo.STO_QL_Cls_DamBaoChiDinh',N'P') IS NULL
    SET @Loi+=N'- Thiếu điều kiện thu/đồng bộ CLS v97.'+CHAR(13)+CHAR(10);
IF ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_ThuNgan_ThuTien')),N'') NOT LIKE N'%FN_QL_ThuTien_DongCoTheThu%'
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_ThuNgan_ChiTiet')),N'') NOT LIKE N'%AS co_the_thu%'
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_ThuNgan_DanhSach')),N'') NOT LIKE N'%AS trang_thai_kham%'
    SET @Loi+=N'- Thu ngân chưa có contract thu CLS khi đang khám v97.'+CHAR(13)+CHAR(10);
IF ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_Luu')),N'') NOT LIKE N'%@KhoaCLS%'
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_Luu')),N'') LIKE N'%Lượt khám đã phát sinh khoản thu, không thể thay đổi dữ liệu%'
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_ChonBenhNhan')),N'') NOT LIKE N'%AS KhoaNghiepVu%'
    SET @Loi+=N'- Lưu/tải khám chưa bảo vệ từng dòng có chứng từ v97.'+CHAR(13)+CHAR(10);

/* v98: cancellation reverses only exact receipt-linked dispense, atomically. */
IF COL_LENGTH(N'dbo.QL_Kho_ChungTu',N'IDTaiKhoan') IS NULL
 OR COL_LENGTH(N'dbo.QL_Kho_ChungTu',N'IDChungTuHuy') IS NULL
 OR COL_LENGTH(N'dbo.QL_Kho_ChungTu',N'LoaiNghiepVu') IS NULL
 OR EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.QL_Kho_ChungTu') AND name=N'IDNhanVien' AND is_nullable=0)
    SET @Loi+=N'- Thiếu audit/loại bút toán đảo cấp v98.'+CHAR(13)+CHAR(10);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.QL_Kho_ChungTu')
              AND name=N'UX_QL_Kho_ChungTu_DaoThu' AND is_unique=1 AND has_filter=1 AND is_disabled=0)
 OR NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.QL_Kho_ChungTu')
              AND name=N'CK_V114_CK_QL_Kho_Hoan_Loai' AND is_disabled=0 AND is_not_trusted=0)
 OR NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'dbo.QL_Kho_ChungTu')
              AND name=N'FK_V114_FK_QL_Kho_Hoan_ChungTuHuy' AND is_disabled=0 AND is_not_trusted=0)
 OR NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'dbo.QL_Kho_ChungTu')
              AND name=N'FK_V114_FK_QL_Kho_DieuChinh_TaiKhoan' AND is_disabled=0 AND is_not_trusted=0)
    SET @Loi+=N'- Thiếu constraint liên kết/audit đảo cấp v98.'+CHAR(13)+CHAR(10);
IF OBJECT_ID(N'dbo.STO_QL_ThuNgan_DaoCapChungTu',N'P') IS NULL
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_ThuNgan_DaoCapChungTu')),N'') NOT LIKE N'%D.ID=X.IDThuTienChungTuCT AND D.IDChungTu=@IDChungTu%'
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_ThuNgan_DaoCapChungTu')),N'') NOT LIKE N'%@@TRANCOUNT=0%'
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_ThuNgan_HuyChungTu')),N'') NOT LIKE N'%EXEC dbo.STO_QL_ThuNgan_DaoCapChungTu%'
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_ThuNgan_DanhSachChungTu')),N'') NOT LIKE N'%AS so_phieu_dao_kho%'
    SET @Loi+=N'- Thiếu luồng hủy thu/đảo cấp và audit UI v98.'+CHAR(13)+CHAR(10);

/* v99: per-CSKCB config controls the existing upfront examination-fee guard. */
IF OBJECT_ID(N'dbo.HT_Config',N'U') IS NULL
 OR COL_LENGTH(N'dbo.HT_Config',N'IDCSKCB') IS NULL
 OR COL_LENGTH(N'dbo.HT_Config',N'MaChucNang') IS NULL
 OR COL_LENGTH(N'dbo.HT_Config',N'HieuLuc') IS NULL
    SET @Loi+=N'- Thiếu bảng HT_Config v99.'+CHAR(13)+CHAR(10);
IF OBJECT_ID(N'dbo.HT_Config',N'U') IS NOT NULL
AND NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id=OBJECT_ID(N'dbo.HT_Config')
      AND name=N'UQ_HT_Config_IDCSKCB_MaChucNang'
      AND type=N'UQ'
)
    SET @Loi+=N'- Thiếu ràng buộc duy nhất CSKCB + mã cấu hình v99.'+CHAR(13)+CHAR(10);
IF OBJECT_ID(N'dbo.HT_Config',N'U') IS NOT NULL
AND EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id=OBJECT_ID(N'dbo.HT_Config')
      AND name=N'UQ_HT_Config_MaChucNang'
      AND type=N'UQ'
)
    SET @Loi+=N'- Còn ràng buộc cấu hình global cũ v99.'+CHAR(13)+CHAR(10);
IF OBJECT_ID(N'dbo.HT_Config',N'U') IS NOT NULL
AND OBJECT_ID(N'dbo.DM_CSKCB',N'U') IS NOT NULL
AND EXISTS
(
    SELECT 1
    FROM dbo.DM_CSKCB C
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.HT_Config H
        WHERE H.IDCSKCB=C.ID
          AND H.MaChucNang=N'THUCONGKHAMDVTRUOC'
    )
)
    SET @Loi+=N'- Có CSKCB thiếu cấu hình THUCONGKHAMDVTRUOC v99.'+CHAR(13)+CHAR(10);
IF OBJECT_ID(N'dbo.STO_HT_Config_DanhSach',N'P') IS NULL
 OR OBJECT_ID(N'dbo.STO_HT_Config_CapNhatTrangThai',N'P') IS NULL
 OR NOT EXISTS(SELECT 1 FROM sys.parameters WHERE object_id=OBJECT_ID(N'dbo.STO_HT_Config_DanhSach') AND name=N'@IDCSKCB')
 OR NOT EXISTS(SELECT 1 FROM sys.parameters WHERE object_id=OBJECT_ID(N'dbo.STO_HT_Config_CapNhatTrangThai') AND name=N'@IDCSKCB')
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_CapNhatDangKham')),N'') NOT LIKE N'%THUCONGKHAMDVTRUOC%'
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_CapNhatDangKham')),N'') NOT LIKE N'%IDCSKCB=@IDCSKCB%'
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_ChonBenhNhan')),N'') NOT LIKE N'%THUCONGKHAMDVTRUOC%'
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_ChonBenhNhan')),N'') NOT LIKE N'%IDCSKCB=@IDCSKCB%'
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_Luu')),N'') NOT LIKE N'%THUCONGKHAMDVTRUOC%'
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kham_Luu')),N'') NOT LIKE N'%IDCSKCB=@IDCSKCB%'
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Cls_DamBaoChiDinh')),N'') NOT LIKE N'%THUCONGKHAMDVTRUOC%'
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_HT_CSKCB_Luu')),N'') NOT LIKE N'%THUCONGKHAMDVTRUOC%'
    SET @Loi+=N'- Thiếu STO quản trị hoặc chốt thu công khám theo config v99.'+CHAR(13)+CHAR(10);

/* v100: per-CSKCB payment guard when saving the result of a priced CLS order. */
IF OBJECT_ID(N'dbo.HT_Config',N'U') IS NOT NULL
AND OBJECT_ID(N'dbo.DM_CSKCB',N'U') IS NOT NULL
AND EXISTS
(
    SELECT 1
    FROM dbo.DM_CSKCB C
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.HT_Config H
        WHERE H.IDCSKCB=C.ID
          AND H.MaChucNang=N'THUTIENCHIDINHTRUOC'
    )
)
    SET @Loi+=N'- Có CSKCB thiếu cấu hình THUTIENCHIDINHTRUOC v100.'+CHAR(13)+CHAR(10);
IF OBJECT_ID(N'dbo.STO_QL_Cls_LuuDuongDanKetQua',N'P') IS NULL
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Cls_LuuDuongDanKetQua')),N'') NOT LIKE N'%THUTIENCHIDINHTRUOC%'
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Cls_LuuDuongDanKetQua')),N'') NOT LIKE N'%IDCSKCB=@IDCSKCB%'
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Cls_LuuDuongDanKetQua')),N'') NOT LIKE N'%DuongDanKetQua=@DuongDanKetQua%'
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_HT_CSKCB_Luu')),N'') NOT LIKE N'%THUTIENCHIDINHTRUOC%'
    SET @Loi+=N'- Thiếu chốt thu tiền trước khi nhập kết quả chỉ định theo CSKCB v100.'+CHAR(13)+CHAR(10);

/* Danh mục giảm giá cho Thu ngân: mức lẻ 5,5% không được làm tròn. */
IF OBJECT_ID(N'dbo.DM_MaGiamGia',N'U') IS NULL
 OR COL_LENGTH(N'dbo.DM_MaGiamGia',N'IDCSKCB') IS NULL
 OR COL_LENGTH(N'dbo.DM_MaGiamGia',N'MaGiamGia') IS NULL
 OR COL_LENGTH(N'dbo.DM_MaGiamGia',N'TenGiamGia') IS NULL
 OR COL_LENGTH(N'dbo.DM_MaGiamGia',N'TiLe') IS NULL
 OR COL_LENGTH(N'dbo.DM_MaGiamGia',N'Active') IS NULL
 OR OBJECT_ID(N'dbo.STO_QL_ThuNgan_MaGiamGia_DanhSach',N'P') IS NULL
 OR OBJECT_ID(N'dbo.STO_QL_ThuNgan_MaGiamGia_Luu',N'P') IS NULL
 OR OBJECT_ID(N'dbo.TR_DM_MaGiamGia_JSON_VERSION',N'TR') IS NULL
 OR OBJECT_ID(N'dbo.TR_DM_CSKCB_MaGiamGia_Default',N'TR') IS NULL
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_ThuNgan_MaGiamGia_DanhSach')),N'') NOT LIKE N'%IDCSKCB%'
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_ThuNgan_MaGiamGia_Luu')),N'') NOT LIKE N'%IDCSKCB%'
    SET @Loi+=N'- Thiếu bảng/STO danh mục mã giảm giá cho Thu ngân.'+CHAR(13)+CHAR(10);

/* v105: Cac cau hinh ky so va lien thong doc lap. */
IF COL_LENGTH(N'dbo.HT_LienThongToaThuoc_CauHinh',N'KySoHieuLuc') IS NULL
 OR COL_LENGTH(N'dbo.HT_LienThongToaThuoc_CauHinh',N'LienThongHieuLuc') IS NULL
    SET @Loi+=N'- Thieu cot KySoHieuLuc/LienThongHieuLuc v105.'+CHAR(13)+CHAR(10);

/* v104: digitally signed national prescriptions; fail closed while TEST URL or signer is blank. */
IF COL_LENGTH(N'dbo.DM_Thuoc',N'MaThuocQuocGia') IS NULL
 OR COL_LENGTH(N'dbo.QL_VaoVien',N'PhienBanLamSang') IS NULL
 OR COL_LENGTH(N'dbo.QL_ToaThuoc_CT',N'IDToaThuoc') IS NULL
    SET @Loi+=N'- Thieu cot nen tang lien thong toa thuoc v104.'+CHAR(13)+CHAR(10);
IF OBJECT_ID(N'dbo.STO_QL_ToaThuoc_DongBoDauToa',N'P') IS NULL
 OR OBJECT_ID(N'dbo.STO_QL_ToaThuoc_LuuPhienBanDaKy',N'P') IS NULL
 OR OBJECT_ID(N'dbo.STO_QL_ToaThuoc_XepHangGui',N'P') IS NULL
 OR OBJECT_ID(N'dbo.STO_QL_ToaThuoc_BatDauGui',N'P') IS NULL
 OR OBJECT_ID(N'dbo.STO_QL_ToaThuoc_GhiNhanKetQuaGui',N'P') IS NULL
 OR OBJECT_ID(N'dbo.TR_QL_ToaThuoc_CT_LienThong',N'TR') IS NULL
 OR OBJECT_ID(N'dbo.TR_QL_ChanDoan_CT_LienThong',N'TR') IS NULL
    SET @Loi+=N'- Thieu STO hoac trigger bao ve lien thong toa thuoc v104.'+CHAR(13)+CHAR(10);
IF OBJECT_ID(N'dbo.HT_LienThongToaThuoc_CauHinh',N'U') IS NOT NULL
AND EXISTS
(
    SELECT 1 FROM dbo.DM_CSKCB C
    WHERE NOT EXISTS(SELECT 1 FROM dbo.HT_LienThongToaThuoc_CauHinh H WHERE H.IDCSKCB=C.ID)
)
    SET @Loi+=N'- Co CSKCB thieu cau hinh lien thong toa thuoc v104.'+CHAR(13)+CHAR(10);
IF OBJECT_ID(N'dbo.HT_LienThongToaThuoc_CauHinh',N'U') IS NOT NULL
AND EXISTS
(
    SELECT 1 FROM dbo.HT_LienThongToaThuoc_CauHinh
    WHERE HieuLuc=1
      AND
      (
          (MoiTruong=N'TEST' AND NULLIF(LTRIM(RTRIM(ApiBaseUrlTest)),N'') IS NULL)
          OR (MoiTruong=N'PRODUCTION' AND NULLIF(LTRIM(RTRIM(ApiBaseUrlProduction)),N'') IS NULL)
          OR NULLIF(LTRIM(RTRIM(UrlKyDuLieu)),N'') IS NULL
          OR NULLIF(LTRIM(RTRIM(UrlKyPdf)),N'') IS NULL
      )
)
    SET @Loi+=N'- Cau hinh lien thong dang bat nhung thieu API cua moi truong hoac URL ky so.'+CHAR(13)+CHAR(10);
IF OBJECT_ID(N'dbo.QL_ToaThuoc',N'U') IS NOT NULL
AND EXISTS(SELECT 1 FROM dbo.QL_ToaThuoc WHERE MaToaQuocGia IS NOT NULL AND LEN(MaToaQuocGia)<>14)
    SET @Loi+=N'- Co ma toa quoc gia khong du 14 ky tu.'+CHAR(13)+CHAR(10);

/* v108: direct unsigned delivery, independently retained signed history. */
IF OBJECT_ID(N'dbo.QL_ToaThuoc_LienThongPayload',N'U') IS NULL
 OR OBJECT_ID(N'dbo.QL_ToaThuoc_LienThongLanGui',N'U') IS NULL
 OR OBJECT_ID(N'dbo.STO_QL_ToaThuoc_LienThong_KiemTra',N'P') IS NULL
 OR OBJECT_ID(N'dbo.STO_QL_ToaThuoc_LienThong_BatDau',N'P') IS NULL
 OR OBJECT_ID(N'dbo.STO_QL_ToaThuoc_LienThong_KetQua',N'P') IS NULL
 OR OBJECT_ID(N'dbo.STO_QL_ToaThuoc_LienThong_DanhSach',N'P') IS NULL
 OR OBJECT_ID(N'dbo.STO_QL_ToaThuoc_LienThong_PhanHoi',N'P') IS NULL
    SET @Loi+=N'- Thieu snapshot/STO lien thong truc tiep v108.'+CHAR(13)+CHAR(10);

/* v109: independently persisted signed PDFs and signing attempts. */
IF OBJECT_ID(N'dbo.QL_KySoPdf_LanKy',N'U') IS NULL
 OR OBJECT_ID(N'dbo.STO_QL_KySoPdf_KiemTra',N'P') IS NULL
 OR OBJECT_ID(N'dbo.STO_QL_KySoPdf_BatDau',N'P') IS NULL
 OR OBJECT_ID(N'dbo.STO_QL_KySoPdf_KetQua',N'P') IS NULL
 OR OBJECT_ID(N'dbo.STO_QL_KySoPdf_CauHinh_Luu',N'P') IS NULL
 OR OBJECT_ID(N'dbo.STO_QL_KySoPdf_TaiLieu_DanhSach',N'P') IS NULL
 OR OBJECT_ID(N'dbo.STO_QL_KySoPdf_TaiLieu_Lay',N'P') IS NULL
    SET @Loi+=N'- Thieu contract ky PDF nghiep vu v109.'+CHAR(13)+CHAR(10);
IF EXISTS(SELECT 1 FROM dbo.HT_LienThongToaThuoc_CauHinh WHERE KySoHieuLuc=1
    AND (NULLIF(LTRIM(RTRIM(UrlKyPdf)),N'') IS NULL OR UrlKyPdf NOT LIKE N'https://%'))
    SET @Loi+=N'- Ky PDF dang bat nhung thieu URL HTTPS.'+CHAR(13)+CHAR(10);

/* v110: sign complete documents without source-preview selection. */
IF OBJECT_ID(N'dbo.STO_QL_KySoPdf_ToanBo_HienTai',N'P') IS NULL
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_KySoPdf_KiemTra')),N'') NOT LIKE N'%@NhomChiDinh=2%'
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_KySoPdf_KiemTra')),N'') NOT LIKE N'%Luot co toa cua bac si khac%'
    SET @Loi+=N'- Thieu contract ky PDF toan bo v110.'+CHAR(13)+CHAR(10);

/* v111: dynamic PDF positions and saved clinical rows. */
IF COL_LENGTH(N'dbo.QL_KySoPdf_LanKy',N'ViTriKyJson') IS NULL
 OR COL_LENGTH(N'dbo.QL_KySoPdf_LanKy',N'PdfDangKy') IS NULL
 OR COL_LENGTH(N'dbo.QL_KySoPdf_TaiLieu',N'PhienBanMauKy') IS NULL
 OR OBJECT_ID(N'dbo.STO_QL_KySoPdf_TienDo',N'P') IS NULL
 OR OBJECT_ID(N'dbo.TR_QL_ChiDinh_CT_KyPdf',N'TR') IS NULL
 OR OBJECT_ID(N'dbo.TR_QL_VaoVien_KyPdf',N'TR') IS NULL
 OR OBJECT_ID(N'dbo.TR_QL_PhieuSinhHieu_KyPdf',N'TR') IS NULL
 OR OBJECT_ID(N'dbo.TR_QL_PhieuSinhHieu_CT_KyPdf',N'TR') IS NULL
 OR OBJECT_ID(N'dbo.TR_QL_BenhNhan_KyPdf',N'TR') IS NULL
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_KySoPdf_KiemTra')),N'') LIKE N'%TrangThaiKham=2%'
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_KySoPdf_ToanBo_HienTai')),N'') NOT LIKE N'%PhienBanMauKy=2%'
 SET @Loi+=N'- Thieu contract ky PDF vi tri dong/ho so da luu v111.'+CHAR(13)+CHAR(10);

/* v112: image results and read-only dispensing prints. */
IF OBJECT_ID(N'dbo.FN_Cls_FileDuocHoTro',N'FN') IS NULL
 OR NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE name=N'CK_QL_Cls_KetQuaFile' AND is_disabled=0 AND is_not_trusted=0)
 OR OBJECT_ID(N'dbo.STO_QL_Kho_PhieuCap_DanhSach',N'P') IS NULL
 OR OBJECT_ID(N'dbo.STO_QL_Kho_PhieuCap_In',N'P') IS NULL
 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Cls_LuuDuongDanKetQua')),N'') NOT LIKE N'%FN_Cls_FileDuocHoTro%'
 SET @Loi+=N'- Thieu contract CLS anh/in cap phat v112.'+CHAR(13)+CHAR(10);

/* v113: print current signed bytes; never print cancelled dispensing documents. */
IF OBJECT_ID(N'dbo.STO_QL_KySoPdf_In_HienTai',N'P') IS NULL
 OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_KySoPdf_In_HienTai')) NOT LIKE N'%T.PhienBanLamSang=V.PhienBanLamSang%'
 OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kho_PhieuCap_DanhSach')) NOT LIKE N'%DaHuy=0%'
 OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.STO_QL_Kho_PhieuCap_In')) NOT LIKE N'%X.DaHuy=0%'
 SET @Loi+=N'- Thieu contract in PDF da ky/chan phieu cap huy v113.'+CHAR(13)+CHAR(10);

IF @Loi<>N''
BEGIN
    PRINT @Loi;
    THROW 59099,N'QLPM main schema v114 verification failed.',1;
END;

EXEC sys.sp_set_session_context @key=N'QLPM_MAIN_VERIFIED',@value=114,@read_only=0;
PRINT N'05_kiem_tra_main.sql: OK - schema main v114 verified.';
GO
