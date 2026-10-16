# Mapping danh mục tham khảo HIS → QLPM

> Tài liệu mapping nghiệp vụ tham khảo, **không phải migration, cấu hình kết nối hay luồng runtime**. HIS chỉ là đối tượng mẫu để đối chiếu. Ứng dụng QLPM main hiện không kết nối, đọc hoặc ghi HIS; không dùng tài liệu này để truy cập HIS.

## 1. Nguyên tắc

- Các cột HIS bên dưới chỉ mô tả mapping tham khảo; không có thao tác runtime đọc nguồn HIS.
- Không ghi host/user/password thật trong tài liệu/source.
- Đích là DB `QLPM`.
- Danh mục tenant phải gắn đúng `IDCSKCB`.
- Ưu tiên map bằng mã nghiệp vụ, không copy identity ID giữa hai DB.
- Field không có nguồn thì để NULL/default hoặc lấy từ nguồn cấu hình riêng; không tự bịa dữ liệu.

## 2. Mapping chính

### 2.1 CSKCB: `ThongTinDoanhNghiep` → `DM_CSKCB`

| HIS | QLPM | Ghi chú |
|---|---|---|
| `MaCSKCB` | `MaCSKCB` | khóa mapping |
| `TenCSKCB` | `TenCSKCB` | |
| `DiaChi` | `DiaChi` | giữ full address nếu source chỉ có một chuỗi |
| — | `SoNhaTenDuong` | NULL nếu source không tách |
| — | `MaTinh` | NULL nếu không có mapping chuẩn |
| — | `MaPhuongXa` | NULL nếu không có mapping chuẩn |
| `DienThoai` | `SDT` | runtime quản trị chỉ nhận số, tối đa 10 ký tự |
| `Email` | `Email` | |
| `MaSoThue` | `MaST` | |
| `SoTk` | `SoTK` | |
| — | `IDNganHang` | map qua mã ngân hàng nếu có |
| — | `UrlLogo` | không tự sinh |
| `Active` | `Active` | |

### 2.2 Ngân hàng

`DM_NganHang → DM_NganHang`: map `MaNganHang`, `TenNganHang`, `Active`. Danh mục dùng chung, không có `IDCSKCB`.

### 2.3 Dân tộc

`DM_DanToc → DM_DanToc`: gắn `IDCSKCB`, map `MaDanToc`, `TenDanToc`, `Active`. Logical key: `IDCSKCB + MaDanToc`.

### 2.4 Tỉnh/Thành

`DM_TinhCuTru → DM_TinhThanh`: gắn `IDCSKCB`, map mã/tên/Active.

### 2.5 Phường/Xã

`DM_XaCuTru → DM_PhuongXa`:
- gắn `IDCSKCB`;
- `MaXa → MaPhuongXa`;
- `TenXa → TenPhuongXa`;
- tỉnh nguồn phải map sang `DM_TinhThanh.ID` bằng mã tỉnh, không copy ID trực tiếp.

### 2.6 ICD10

`DM_ICD → DM_ICD10`: gắn `IDCSKCB`, map `MaBenh`, `TenBenh`, `Active`.

### 2.7 Dịch vụ: `DM_DichVuKyThuat` → `DM_DichVu`

| HIS | QLPM | Quy tắc |
|---|---|---|
| `MaDichVu` | `MaDichVu` | khóa mapping tenant |
| `TenDichVu` | `TenDichVu` | |
| `IDNhomDichVu` | `LoaiDichVu` | công khám → 1; loại khác theo mapping nghiệp vụ |
| `DonViTinh` | `DonViTinh` | |
| `GiaTrongGio` | `DonGia` | |
| — | `ChoPhepGuiNgoai` | default 0 nếu không có nguồn |
| `Active` | `Active` | |

Runtime JSON:
- `LoaiDichVu=1` → `dm_cong_kham.json`;
- `LoaiDichVu<>1` → `dm_dich_vu.json`.

### 2.8 Đơn vị tính thuốc

`HH_DM_DonViTinh → DM_DonViTinh`: gắn `IDCSKCB`, map bằng `MaDVT`, giữ `TenDVT` + `Active`. Không giả định ID nguồn = ID đích.

Mapping `HH_DM_DonViTinh → DM_DonViTinh` ở đây chỉ là ví dụ quan hệ dữ liệu. Runtime không đọc bảng `HH_DM_DonViTinh`, không upsert dữ liệu từ HIS và không dùng `ConnectionStrings:HIS` hoặc `ServerHISConnection`. `DM_DonViTinh` của QLPM được quản lý trong database QLPM.

### 2.9 Thuốc: `HH_DM_HangHoa` → `DM_Thuoc`

| HIS | QLPM |
|---|---|
| `MaHangHoa` | `MaThuoc` |
| `TenHangHoa` | `TenThuoc` |
| `IDDonViTinhXuat` | `IDDonViTinh` sau khi map DVT |
| tên DVT | `DonViTinh` legacy/fallback |
| đường dùng | `DuongDung` |
| `HamLuong` | `HamLuong` |
| `HoatChat` | `HoatChat` |
| `GiaBanLe` | `GiaBan` |
| `Active` | `Active` |

Runtime ưu tiên `DM_DonViTinh.TenDVT`, fallback `DM_Thuoc.DonViTinh`.

### 2.10 Trị số sinh hiệu

Đích `DM_TriSoSinhHieu`, theo tenant. Mã thường dùng:
`MACH`, `NDO`, `HA`, `NT`, `SPO2`, `CCAO`, `CNANG`, `BMI`.

Map tên, đơn vị tính, thứ tự và Active.

### 2.11 Nhân viên/Bác sĩ và chức danh

QLPM tự quản lý mô hình nhân viên, **không yêu cầu tương thích cấu trúc HIS**:

- `DM_NhanVien` là hồ sơ nhân viên dùng chung toàn hệ thống, không giữ `IDCSKCB`.
- `DM_NhanVien_CSKCB(IDNhanVien, IDCSKCB, Active)` là bảng nối N-N: một nhân viên có thể thuộc nhiều cơ sở và một cơ sở có nhiều nhân viên.
- `DM_ChucDanh(ID, MaChucDanh, TenChucDanh, VietTat, Active)` là danh mục chức danh dùng chung.
- `DM_NhanVien.IDChucDanh` tham chiếu chức danh; dropdown chức danh đọc từ `dung_chung/dm_chuc_danh.json`.
- Vai trò và phân quyền (`DM_Vai_Tro`, `HT_Quyen_Vai_Tro`) là khái niệm riêng, không dùng thay cho chức danh nghề nghiệp.
- Account vẫn liên kết bằng `HT_Tai_Khoan.IDNhanVien` và `HT_Tai_Khoan.IDCSKCB`; cùng một nhân viên có thể có tài khoản riêng ở từng cơ sở.

### 2.12 Quốc tịch và Nghề nghiệp

Hai JSON này có canonical table tenant trong QLPM:

- `DM_QuocTich(IDCSKCB, ID, MaQuocTich, TenQuocTich, Active)` → `dm_quoc_tich.json`;
- `DM_NgheNghiep(IDCSKCB, ID, MaNgheNghiep, TenNgheNghiep, Active)` → `dm_nghe_nghiep.json`.

JSON không còn là nguồn dữ liệu độc lập; worker đọc từ hai bảng này khi publish cache.

### 2.13 Phác đồ điều trị mẫu

Canonical QLPM:
- `DM_PhacDo`: header (`IDCSKCB`, `MaPhacDo`, `TenPhacDo`, `TrieuChung`, `Active`).
- `DM_PhacDo_ChanDoan`: nhiều ICD + cờ BanDau/BenhChinh/BenhKhac.
- `DM_PhacDo_ChiDinh`: CLS mẫu.
- `DM_PhacDo_Thuoc`: thuốc/liều mẫu.

Không dùng `QL_PhacDo`, `QL_PhacDo_ChiTiet` hay `DM_PhacDo.IDICD10` legacy.

## 3. Danh mục JSON runtime

Nút/API **Đồng bộ danh mục** là full sync thủ công cho CSKCB đang quản lý; service chỉ đọc database QLPM và xuất cache JSON. Không có kết nối HIS trong luồng này.

Kiến trúc runtime:
- DB canonical là **nguồn chuẩn**;
- JSON là **read-model/cache**;
- mỗi CSKCB có một dòng version trong `HT_JSON_CSKCB`;
- source table thay đổi → trigger tăng `VersionNo` và đặt `TrangThai=CHO_DONG_BO`;
- `PublishedVersionNo` chỉ cập nhật sau khi toàn bộ JSON publish thành công;
- không tạo file vật lý `v1/v2`; chỉ giữ JSON hiện hành + version metadata trong DB;
- worker kiểm tra lịch mỗi 30 giây theo giờ SQL Server, tối đa chạy một lượt mỗi ngày và chỉ convert CSKCB đang dirty; sau khi ứng dụng khởi động trễ, lượt trong ngày chạy khi worker phát hiện đã đến ngày cần chạy, không đảm bảo đúng giây 00:00;
- lỗi hoặc process bị gián đoạn được thử lại sau 15 phút;
- login **không convert JSON**; nếu thiếu file/manifest thì chỉ đánh dấu dirty để worker xử lý;
- nhiều instance được khóa bằng SQL application lock để không chạy nightly trùng nhau;
- lỗi một CSKCB không chặn CSKCB khác; JSON published cũ được giữ nguyên, tenant lỗi vẫn dirty/LOI để retry;
- runtime không đọc/ghi HIS; thay đổi các bảng QLPM có trigger version trong script `24_json_danh_muc_phien_ban.sql` mới đánh dấu version JSON dirty.

Các JSON tenant hiện hành:
- dân tộc, tỉnh/thành, phường/xã, ICD10, công khám, dịch vụ, đơn vị tính, thuốc, trị số sinh hiệu, nhân viên, bác sĩ, phác đồ, quốc tịch, nghề nghiệp.

Các JSON dùng chung:
- `dm_ngan_hang.json`;
- `dm_gioi_tinh.json`;
- `dm_chuc_danh.json`.

Khi full sync, file có nội dung không đổi không bị ghi lại nên mtime/cache không bị đổi. Đồng bộ cùng một CSKCB được serialize bằng lock; root manifest và JSON dùng chung có common lock riêng.

## 4. Version/worker contract

| Thành phần | Vai trò |
|---|---|
| `HT_JSON_CSKCB` | version/dirty/published theo CSKCB |
| `HT_JSON_DongBo_Lich` | lịch nightly và trạng thái lần chạy gần nhất |
| `24_json_danh_muc_phien_ban.sql` | tạo metadata, canonical table Quốc tịch/Nghề nghiệp và trigger dirty |
| `danh_muc_json_worker` | chạy nền theo giờ server, xử lý dirty CSKCB |

## 5. Database contract

| Nhóm | Script | Cách dùng |
|---|---|---|
| Updater | `00_CapNhat_TatCa.sql` | entry point duy nhất |
| Schema/STO | `01`–`04` + common scripts | canonical runtime |
| Viết tắt | `23_common_viet_tat.sql` | common runtime |
| Verifier | `05_kiem_tra_main.sql` | kiểm tra, không sửa |
| Version | `06_chot_phien_ban_main.sql` | ghi **84** sau verifier |
