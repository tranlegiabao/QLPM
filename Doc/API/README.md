# API QLPM — main

Response nghiệp vụ thường: `{ "status": 200, "message": "...", "data": ... }`. HTTP 401/403 dành cho xác thực/phân quyền; page MVC thiếu quyền dùng 404.

## Phân trang và giới hạn request

- Danh sách lớn dùng `trang` + `kich_thuoc_trang`; page size thường 10–100.
- Danh mục trị số CLS tối đa 200 dòng/trang.
- Dropdown/danh mục có giới hạn số dòng; `phuong_xa` có thể tới 1000.
- `/api`: authenticated 180 request/phút/account; anonymous 60 request/phút/IP.
- Vượt limit: HTTP 429 + `Retry-After: 60`.
- Request body global: 20 MB.
- Excel CLS: 5 MB.
- Excel nhân viên: file 5 MB, multipart envelope 6 MB.
- File CLS: 15 MB.
- Logo CSKCB: 5 MB.

## Xác thực

- POST `/api/xac_thuc/dang_nhap`
- POST `/api/xac_thuc/dang_xuat`
- GET `/api/xac_thuc/phien_hien_tai`
- GET `/api/xac_thuc/khoi_tao_thong_tin`


QLPM local dùng mật khẩu tài khoản cố định `a`; không có chức năng đổi/reset mật khẩu trên UI.

## Tiếp nhận

- GET `/api/tiep_nhan/danh_sach`
- POST `/api/tiep_nhan/luu`
- POST `/api/tiep_nhan/chuyen_kham`
- GET `/api/tiep_nhan/danh_sach_cong_kham`
- POST `/api/tiep_nhan/bo_cong_kham`
- POST `/api/tiep_nhan/bo_dang_ky`
- POST `/api/tiep_nhan/xoa_benh_nhan`

## Khám

- GET `/api/kham_benh/danh_sach`
- POST `/api/kham_benh/chon_benh_nhan`
- POST `/api/kham_benh/cap_nhat_dang_kham`
- POST `/api/kham_benh/huy_dang_kham`
- POST `/api/kham_benh/luu`
- GET `/api/kham_benh/lich_su`
- GET `/api/kham_benh/lay_toa_cu`
- GET `/api/kham_benh/chi_tiet_lan_kham_cu`
- GET `/api/kham_benh/viet_tat`
- POST `/api/kham_benh/viet_tat`

## Phác đồ

- GET `/api/phac_do/danh_sach`
- GET `/api/phac_do/chi_tiet`
- POST `/api/phac_do/luu`
- POST `/api/phac_do/xoa`

## CLS

Phân hệ CLS hiện hành quản lý kết quả theo chỉ định, không còn import Excel trị số.

Quyền `kham_benh`:
- GET `/api/cls/danh_sach`
- GET `/api/cls/ket_qua`
- POST `/api/cls/chi_dinh/dam_bao`
- POST `/api/cls/file/upload`
- GET `/api/cls/file/{id}`
- POST `/api/cls/file/xoa`

Một chỉ định chỉ giữ đường dẫn file kết quả đang có hiệu lực. Không có API import trị số hoặc duyệt/hủy duyệt CLS.

## Thu ngân

Quyền `thu_ngan`:
- GET `/thu_ngan/api/danh-sach`
- GET `/thu_ngan/api/chi-tiet?id_vao_vien=...`
- POST `/thu_ngan/api/thu-tien`
- POST `/thu_ngan/api/huy-thu`
- GET `/thu_ngan/in-phieu?id_vao_vien=...`

`trang_thai` hỗ trợ `tat_ca | cho_thu | da_thu | da_huy`; UI mặc định `cho_thu`. Chỉ lượt `TrangThaiKham=2` mới xuất hiện. Thu tiền lấy `IDCSKCB` và nhân viên từ claims. Payload thu gửi `chuyen_khoan`, ngân hàng, ghi chú và `danh_sach[]` gồm `id/phu_thu/giam_phan_tram` theo từng dòng; tiền mặt được server tính bằng phần còn lại nên mặc định là toàn bộ tiền thanh toán khi không có chuyển khoản. In phiếu chỉ cho trạng thái Đã thu và luôn đọc lại dữ liệu từ DB.

## Kho

Danh mục nhà cung cấp thuộc **menu Danh mục → Nhà cung cấp** (`/danh_muc/nha_cung_cap`). Nút `+` tại Nhập kho dẫn vào form danh mục (không dùng `window.prompt`). Danh mục lưu theo `IDCSKCB`, không xóa cứng nếu đã có phiếu nhập; thao tác xóa chỉ đặt `Active=0` và giữ lịch sử.

- GET `/kho/api/nha-cung-cap`: danh sách đang hoạt động phục vụ nhập kho.
- GET `/kho/api/nha-cung-cap/danh-sach?q=...&trang_thai=...`: danh mục, gồm hoạt động/ngừng/tất cả.
- POST `/kho/api/nha-cung-cap/luu`: thêm mới (`kho:Them`) hoặc cập nhật (`kho:Sua`), có mã, tên, MST, điện thoại, địa chỉ, trạng thái. Ngừng sử dụng qua cập nhật cũng đòi `kho:Xoa`.
- POST `/kho/api/nha-cung-cap/xoa`: ngừng sử dụng (`kho:Xoa`), không phá khóa ngoại phiếu nhập. Có thể kích hoạt lại bằng quyền sửa.


Quyền `kho`:
- GET `/kho/api/danh-sach-kho`
- GET `/kho/api/ton-kho`
- POST `/kho/api/nhap-kho`
- GET `/kho/api/cho-cap`
- GET `/kho/api/chi-tiet-cap?id_kho=...&id_vao_vien=...`
- POST `/kho/api/xuat-thuoc`
- POST `/kho/api/hoan-thuoc`
- GET `/kho/api/danh-sach` và POST `/kho/api/gan-nhom` cho phân nhóm thuốc hiện hữu.

Xuất thuốc chỉ nhận toa của lượt đã thu; STO quy đổi về đơn vị cơ sở và chọn lô theo FEFO. `hoan-thuoc` hoàn toàn bộ lượng đã cấp còn hiệu lực của lượt về đúng lô trước khi Thu ngân có thể hủy thu.

## Danh mục

- GET `/api/danh_muc/trang_thai_dong_bo`
- POST `/api/danh_muc/dong_bo`
- GET `/api/danh_muc/{loai}`

`POST /api/danh_muc/dong_bo` tạo lại toàn bộ cache JSON từ database QLPM của CSKCB đang chọn. Endpoint này không đọc hoặc ghi HIS.

`gioi_tinh` và `ngan_hang` là danh mục dùng chung; danh mục tenant yêu cầu CSKCB.

## Hệ thống

### CSKCB / địa chỉ
Chỉ global admin `quan_tri_he_thong` được CRUD/chọn CSKCB:
- POST `/api/he_thong/cskcb/chon_lam_viec`
- GET `/api/he_thong/cskcb`
- GET `/api/he_thong/cskcb/{id}`
- POST `/api/he_thong/cskcb/luu`
- POST `/api/he_thong/cskcb/logo`
- POST `/api/he_thong/cskcb/xoa`
- GET `/api/he_thong/dia_chi/tinh_thanh`
- GET `/api/he_thong/dia_chi/phuong_xa?ma_tinh=...`

### Nhân viên
- GET `/api/he_thong/nhan_vien`
- GET `/api/he_thong/nhan_vien_lookup`
- POST `/api/he_thong/nhan_vien/luu`
- POST `/api/he_thong/nhan_vien/xoa`

### Tài khoản
- GET `/api/he_thong/tai_khoan`
- POST `/api/he_thong/tai_khoan/luu`
- POST `/api/he_thong/tai_khoan/trang_thai`
- POST `/api/he_thong/tai_khoan/reset_mat_khau`
- POST `/api/he_thong/tai_khoan/xoa`

### Vai trò / phân quyền
- GET `/api/he_thong/vai_tro`
- GET `/api/he_thong/vai_tro_lookup`
- POST `/api/he_thong/vai_tro/luu`
- POST `/api/he_thong/vai_tro/xoa`
- GET `/api/he_thong/phan_quyen`
- POST `/api/he_thong/phan_quyen/luu`
- POST `/api/he_thong/danh_muc/dong_bo`

## Ký số và liên thông toa thuốc quốc gia

Quyền `lien_thong_toa_thuoc`:

- GET `/api/lien_thong_toa_thuoc/danh-sach`
- GET `/api/lien_thong_toa_thuoc/{id}/kiem-tra`
- GET `/api/lien_thong_toa_thuoc/{id}/xem-payload`
- POST `/api/lien_thong_toa_thuoc/{id}/ky-va-gui`
- POST `/api/lien_thong_toa_thuoc/{id}/gui-lai`
- GET `/api/lien_thong_toa_thuoc/{id}/phien-ban/{versionId}/pdf`

Quyền `he_thong_lien_thong_toa_thuoc`:

- GET/POST `/api/he_thong/lien_thong_toa_thuoc/cau-hinh`
- POST `/api/he_thong/lien_thong_toa_thuoc/bac-si`

Chỉ bác sĩ kê đơn được ký/gửi. Mật khẩu là write-only và được Data Protection mã hóa. Mặc định môi trường `TEST`, URL test và URL ký để trống; backend trả HTTP 503 và không gọi ra ngoài. `409` dùng cho sai trạng thái/revision, `422` cho thiếu dữ liệu nghiệp vụ, `403` cho sai bác sĩ.

## Quy tắc an toàn

- Server dùng claims/filter cho CSKCB và nhân viên; không tin ID client.
- Global admin chưa chọn working-CSKCB không tự có ngữ cảnh nghiệp vụ tenant.
- CCCD exact chặn tạo BN mới; match nhân khẩu học mạnh chỉ cảnh báo, không tự merge.
- SĐT CSKCB/nhân viên chỉ số, tối đa 10 ký tự.
- Upload phải kiểm tra extension/kích thước/path.
