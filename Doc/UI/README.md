# UI/UX QLPM — main

Tài liệu này mô tả UI đang được code hiện tại sử dụng; không dùng mockup cũ làm contract.

## Khung chung

- Header SixOs + menu hệ thống.
- Thanh phân hệ nghiệp vụ nằm ngang.
- Trên desktop ưu tiên bố cục danh sách + form song song, bảng cuộn/sticky khi nhiều cột.
- Dưới breakpoint khoảng 992px, các vùng quản trị trả về chiều cao tự nhiên để xếp dọc responsive.
- Header tài khoản hiển thị **tên đăng nhập nhỏ** và **tên nhân viên/người dùng lớn**.
- Header app dùng `wwwroot/static/logo.svg`; màn đăng nhập/favicon dùng `wwwroot/static/logo12.svg`.

## Menu theo quyền

Dropdown **Quản lý** hiện có thể chứa:
1. **Khám bệnh** — khi account có ít nhất một quyền `tiep_nhan/kham_benh/thu_ngan/kho:Xem`.
2. **Quản lý phác đồ** — khi có `phac_do:Xem`.
3. **Cấu hình kết quả CLS** — khi có `cls_cau_hinh:Xem`.
4. **Hệ thống** — khi có quyền quản trị hệ thống phù hợp.

Code hiện tại đồng thời có link **Hệ thống** riêng trên header khi account có quyền hệ thống.

Mục **Khám bệnh** dẫn tới tab đầu tiên account được phép dùng theo thứ tự:
`Tiếp nhận → Khám bệnh → Thu ngân → Kho`.

Thanh phân hệ bên dưới chỉ hiện đúng tab account có quyền:
`Thông tin hành chính | Khám bệnh | Thu ngân | Kho`.

Route `/` cũng ưu tiên cùng thứ tự trên; global admin mặc định vào `/he_thong`.

## Tiếp nhận

- Danh sách trái, form hành chính phải.
- Ngày sinh nhập tay `dd-MM-yyyy`.
- SĐT chỉ số, tối đa 10 ký tự; CCCD chỉ số, tối đa 12 ký tự.
- Địa chỉ: Số nhà/tên đường → Tỉnh/Thành → Phường/Xã → Địa chỉ ghép.
- Tỉnh thay đổi thì reload Phường/Xã.
- Dropdown nghiệp vụ dùng TomSelect.
- Enter/Tab đi theo flow input.
- Danh sách server paging; mặc định 25, lựa chọn 10/25/50/100.
- Cột tên BN và tùy chọn sticky.
- Khi nhập từ khóa, hệ thống tìm hồ sơ/lượt trên các ngày và bỏ qua ngày/trạng thái đang chọn. Dấu `Cũ` cạnh tên là lượt không thuộc hôm nay; badge `BN cũ` trên form là hồ sơ hiện hữu được dùng để tạo lượt mới.
- Danh mục nền tải song song; PageLoader toàn trang chỉ theo request danh sách chính.

## Khám bệnh

Bố cục: danh sách bệnh nhân trái → cột icon điều hướng giữa → vùng khám cuộn phải.

Thứ tự:
1. BN + phác đồ
2. Sinh hiệu
3. Triệu chứng
4. Chẩn đoán
5. CLS
6. Toa thuốc

Chọn lượt khám chỉ tải dữ liệu, chưa đổi trạng thái. Lần đầu bác sĩ sửa dữ liệu, hệ thống ghi riêng trạng thái `Đang khám` vào DB; dữ liệu khám vẫn chưa được commit. Nút `Lưu nháp` ghi bản nháp vào `sessionStorage` trong tab hiện tại, không gọi API lưu DB. Nếu form còn thay đổi chưa lưu và bác sĩ chọn BN khác, hệ thống tự lưu nháp rồi chuyển ngay, không hỏi modal. Nếu trình duyệt không ghi được nháp thì giữ BN hiện tại và báo lỗi. Khi chuyển tab hoặc rời trang, nháp tiếp tục được lưu tự động.

Danh sách hiện badge `Nháp` sau khi lưu bản nháp. Nháp còn trong cùng tab sau tải lại/điều hướng và mất khi đóng tab. Nút `Khám xong` mới ghi dữ liệu khám xuống DB, bắt buộc đúng một ICD chính; toa thuốc không bắt buộc. Khi hoàn tất thành công, trạng thái đổi sang `Đã khám` và nháp được xóa. Modal xác nhận dùng `hien_thi_xac_nhan`; `modalDirtyGuard` cũ không thuộc luồng này.

## Phác đồ

Pattern cuộn: `Thông tin → Triệu chứng → ICD → CLS → Toa thuốc`.

Không hiển thị input không có API/STO lưu tương ứng.

## Cấu hình CLS

`/cls_ket_qua`: danh sách dịch vụ trái + editor phải. Quyền màn hình là `cls_cau_hinh`; nhập/sửa kết quả CLS trong luồng khám dùng quyền `kham_benh`.

## Quản trị hệ thống

Thứ tự: `Cơ sở KCB → Nhân viên → Tài khoản → Vai trò → Phân quyền`.

Global admin:
- không thuộc một CSKCB cố định;
- chọn CSKCB Active làm ngữ cảnh làm việc;
- có thể hard-delete CSKCB, purge dữ liệu tenant rồi dọn file/cache;
- nếu xóa CSKCB đang được chọn thì **bỏ ngữ cảnh CSKCB**, không bắt buộc logout toàn phiên.

CSKCB hiện có: `MaCSKCB`, `TenCSKCB`, `SoNhaTenDuong`, `DiaChi`, `MaTinh`, `MaPhuongXa`, `SDT`, `Email`, `MaST`, `SoTK`, `IDNganHang`, `UrlLogo`, `Active`.

SĐT CSKCB/nhân viên chỉ nhận số, tối đa 10 ký tự.

### Danh sách quản trị

- Desktop: form trái, danh sách phải.
- Vùng bảng cuộn độc lập; pagination ở đáy card.
- Cột tên và tùy chọn sticky theo contract hiện tại.
- Click dòng để xem/sửa.
- Search/dropdown dùng TomSelect.

### Xóa/reset

- Không cho tự xóa tài khoản hoặc nhân viên đang đăng nhập.
- Xóa tài khoản tự xóa mapping vai trò.
- Xóa nhân viên xóa account/mapping và gỡ reference nullable nhưng giữ bệnh nhân/lượt khám.
- Xóa vai trò tự gỡ mapping tài khoản và quyền; role tenant `quan_tri_cskcb` được bảo vệ không cho xóa.
- Reset mật khẩu quản trị đặt về `a`.

## Autofill/autocomplete

Tất cả form nghiệp vụ tắt autocomplete và gắn guard password manager. **Ngoại lệ duy nhất là login**, vẫn dùng `autocomplete="username"` và `autocomplete="current-password"`.

## Loading/confirm/error

- PageLoader dùng cho tải chính và hỗ trợ request lồng/song song.
- Nút async phải có disabled/loading và restore sau khi xong.
- Hành động nguy hiểm dùng confirm chung.
- Lỗi/quyền/empty state phải hiển thị rõ.

## Quy tắc sửa UI

Không đổi DOM id, request/response API hoặc selector một phía. Nếu đổi contract phải sửa đồng bộ Razor + JS + controller/STO + test.
