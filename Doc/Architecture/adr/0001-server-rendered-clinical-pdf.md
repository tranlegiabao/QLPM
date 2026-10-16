# ADR 0001: PDF lâm sàng được dựng ở server

- Trạng thái: Chấp nhận
- Ngày: 2026-10-01

## Bối cảnh

Luồng in phiếu chỉ định và toa thuốc trước đây tải tệp HTML tĩnh, thay placeholder bằng JavaScript rồi gọi `iframe.print()`. Cách này cho phép dữ liệu định danh, giá và nội dung giả từ client đi vào bản in; bố cục phụ thuộc trình duyệt và không dùng lại được cho lịch sử khám bệnh.

QLPM cần in được cả dữ liệu đang nhập chưa lưu và dữ liệu lịch sử, đồng thời giữ ranh giới tenant và dữ liệu danh mục ở server.

## Quyết định

- Dùng Razor phía server để dựng HTML và `Haukcode.WkHtmlToPdfDotNet` để chuyển thành PDF A5 dọc, lề 0,5 cm.
- Hai API `/api/kham_benh/in/chi_dinh` và `/api/kham_benh/in/toa_thuoc` trả trực tiếp `application/pdf`.
- Request khai báo nguồn `ban_nhap` hoặc `da_luu`.
- Bản nháp nhận giá trị có thể sửa trên màn hình nhưng không ghi DB. Server đọc và xác minh lượt khám, cơ sở, bác sĩ, ICD, dịch vụ, thuốc, loại toa, đơn vị và giá theo `IDCSKCB`.
- Dữ liệu đã lưu chỉ nhận `IDVaoVien` và được đọc lại từ DB.
- Quyền `Sua` được yêu cầu cho bản nháp; quyền `Xem` được dùng cho dữ liệu đã lưu.
- PDF được tạo theo yêu cầu và không được lưu như snapshot lịch sử.
- Server tạo mã toa hiển thị bằng `MaCSKCB`, phần số của `MaVaoVien` được đệm trái đủ 7 chữ số và `MaLoaiDonThuoc`. Mã này không nhận từ client và không được lưu riêng trong DB.
- Client nạp PDF vào iframe ẩn rồi gọi hộp thoại in của trình duyệt, cùng cách mở bản in đang dùng trong HisSoft.
- Phiếu chỉ định và toa thuốc luôn hiện các nhãn sinh hiệu cùng thông tin cha/mẹ/người giám hộ; dữ liệu chưa có được để trống.

## Hệ quả

- Bản in nhất quán giữa tab Khám bệnh và Lịch sử khám bệnh.
- Không còn tệp HTML placeholder, dữ liệu fallback, barcode JavaScript hoặc luồng in iframe HTML.
- Lịch sử phản ánh dữ liệu hiện tại trong DB tại thời điểm in; QLPM không tái tạo chính xác một bản PDF đã phát hành trước đây nếu dữ liệu đã được sửa.
- Runtime Windows x64 phải đóng gói và nạp được `wkhtmltox.dll` từ gói NuGet.
