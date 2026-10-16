SET IDENTITY_INSERT dbo.QL_Kho_Nhap ON;
INSERT dbo.QL_Kho_Nhap([ID],[IDCSKCB],[IDKho],[SoPhieu],[SoHoaDon],[NgayNhap],[IDNhanVienNhap],[TongTien],[GhiChu],[DaHuy],[IDNhaCungCap],[NgayHoaDon],[NgayGioHuy],[IDNhanVienHuy],[LyDoHuy],[TenNhaCungCapSnapshot],[IDTaiKhoanNhap],[TenNguoiNhapSnapshot],[IDTaiKhoanHuy],[TenNguoiHuySnapshot]) SELECT [ID],[IDCSKCB],[IDKho],[SoPhieu],[SoHoaDon],[NgayGio],[IDNhanVien],[TongTien],[GhiChu],[DaHuy],[IDNhaCungCap],[NgayHoaDon],[NgayGioHuy],[IDNhanVienHuy],[LyDoHuy],[TenNhaCungCapSnapshot],[IDTaiKhoan],[TenNguoiThucHienSnapshot],[IDTaiKhoanHuy],[TenNguoiHuySnapshot] FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='NHAP';
SET IDENTITY_INSERT dbo.QL_Kho_Nhap OFF;
GO
SET IDENTITY_INSERT dbo.QL_Kho_Nhap_CT ON;
INSERT dbo.QL_Kho_Nhap_CT([ID],[IDCSKCB],[IDNhap],[IDThuoc],[IDDonViTinh],[HeSoQuyDoi],[SoLuong],[SoLuongCoSo],[GiaNhap],[ThanhTien],[SoLo],[HanDung],[IDLoThuoc],[TenThuocSnapshot],[MaThuocSnapshot],[DonViTinhSnapshot],[VAT],[TienVAT]) SELECT [ID],[IDCSKCB],[IDChungTu],[IDThuoc],[IDDonViTinh],[HeSoQuyDoi],[SoLuong],[SoLuongCoSo],[GiaNhap],[ThanhTien],[SoLo],[HanDung],[IDLoThuoc],[TenThuocSnapshot],[MaThuocSnapshot],[DonViTinhSnapshot],[VAT],[TienVAT] FROM dbo.QL_Kho_ChungTu_CT WHERE LoaiChungTu='NHAP';
SET IDENTITY_INSERT dbo.QL_Kho_Nhap_CT OFF;
GO
SET IDENTITY_INSERT dbo.QL_Kho_Xuat ON;
INSERT dbo.QL_Kho_Xuat([ID],[IDCSKCB],[IDKho],[IDVaoVien],[SoPhieu],[NgayXuat],[IDNhanVienXuat],[TongGiaVon],[GhiChu],[DaHuy],[IDTaiKhoanXuat],[TenNguoiXuatSnapshot]) SELECT [ID],[IDCSKCB],[IDKho],[IDVaoVien],[SoPhieu],[NgayGio],[IDNhanVien],[TongGiaVon],[GhiChu],[DaHuy],[IDTaiKhoan],[TenNguoiThucHienSnapshot] FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='CAP_PHAT';
SET IDENTITY_INSERT dbo.QL_Kho_Xuat OFF;
GO
SET IDENTITY_INSERT dbo.QL_Kho_Xuat_CT ON;
INSERT dbo.QL_Kho_Xuat_CT([ID],[IDCSKCB],[IDXuat],[IDToaThuocCT],[IDThuoc],[IDLoThuoc],[SoLuongCoSo],[GiaVon],[ThanhTien],[SoLuongDaHoan],[IDThuTienChungTuCT],[HeSoQuyDoi]) SELECT [ID],[IDCSKCB],[IDChungTu],[IDToaThuocCT],[IDThuoc],[IDLoThuoc],[SoLuongCoSo],[GiaVon],[ThanhTien],[SoLuongDaHoan],[IDThuTienChungTuCT],[HeSoQuyDoi] FROM dbo.QL_Kho_ChungTu_CT WHERE LoaiChungTu='CAP_PHAT';
SET IDENTITY_INSERT dbo.QL_Kho_Xuat_CT OFF;
GO
SET IDENTITY_INSERT dbo.QL_Kho_Hoan ON;
INSERT dbo.QL_Kho_Hoan([ID],[IDCSKCB],[IDVaoVien],[SoPhieu],[NgayHoan],[IDNhanVienHoan],[LyDo],[IDTaiKhoanHoan],[IDChungTuHuy],[Loai],[TenNguoiHoanSnapshot]) SELECT [ID],[IDCSKCB],[IDVaoVien],[SoPhieu],[NgayGio],[IDNhanVien],[LyDo],[IDTaiKhoan],[IDChungTuHuy],[LoaiNghiepVu],[TenNguoiThucHienSnapshot] FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='HOAN';
SET IDENTITY_INSERT dbo.QL_Kho_Hoan OFF;
GO
SET IDENTITY_INSERT dbo.QL_Kho_Hoan_CT ON;
INSERT dbo.QL_Kho_Hoan_CT([ID],[IDHoan],[IDXuatCT],[SoLuongCoSo]) SELECT [ID],[IDChungTu],[IDChungTuCTGoc],[SoLuongCoSo] FROM dbo.QL_Kho_ChungTu_CT WHERE LoaiChungTu='HOAN';
SET IDENTITY_INSERT dbo.QL_Kho_Hoan_CT OFF;
GO
SET IDENTITY_INSERT dbo.QL_Kho_DieuChinh ON;
INSERT dbo.QL_Kho_DieuChinh([ID],[IDCSKCB],[IDKho],[Loai],[SoPhieu],[NgayGio],[IDNhanVien],[LyDo],[IDTaiKhoan],[TenNguoiThucHienSnapshot]) SELECT [ID],[IDCSKCB],[IDKho],[LoaiNghiepVu],[SoPhieu],[NgayGio],[IDNhanVien],[LyDo],[IDTaiKhoan],[TenNguoiThucHienSnapshot] FROM dbo.QL_Kho_ChungTu WHERE LoaiChungTu='DIEU_CHINH';
SET IDENTITY_INSERT dbo.QL_Kho_DieuChinh OFF;
GO
SET IDENTITY_INSERT dbo.QL_Kho_DieuChinh_CT ON;
INSERT dbo.QL_Kho_DieuChinh_CT([ID],[IDCSKCB],[IDChungTu],[IDLoThuoc],[SoLuongThayDoi],[SoLuongTruoc],[SoLuongSau]) SELECT [ID],[IDCSKCB],[IDChungTu],[IDLoThuoc],[SoLuongThayDoi],[SoLuongTruoc],[SoLuongSau] FROM dbo.QL_Kho_ChungTu_CT WHERE LoaiChungTu='DIEU_CHINH';
SET IDENTITY_INSERT dbo.QL_Kho_DieuChinh_CT OFF;
GO
