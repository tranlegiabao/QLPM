# Ngữ cảnh miền nghiệp vụ QLPM

## Thuật ngữ luồng in khám bệnh

- **Lượt khám**: một lần người bệnh vào khám, định danh bằng `IDVaoVien` và mã hiển thị `MaVaoVien`.
- **Bản nháp**: dữ liệu đang hiển thị trên tab Khám bệnh, có thể chưa được lưu. In bản nháp không ghi hoặc cập nhật dữ liệu trong cơ sở dữ liệu.
- **Dữ liệu đã lưu**: dữ liệu được đọc lại từ cơ sở dữ liệu theo `IDVaoVien`, dùng khi in từ Lịch sử khám bệnh.
- **Phiếu chỉ định**: tài liệu liệt kê dịch vụ bác sĩ chỉ định cho một lượt khám.
- **Chỉ định nội bộ**: dịch vụ được thực hiện tại cơ sở đang làm việc; bản in có đơn giá, thành tiền và tổng tiền.
- **Chỉ định gửi ngoài**: dịch vụ được chuyển sang nơi khác thực hiện; bản in ẩn giá và hiển thị nơi gửi ngoài.
- **Toa thuốc**: một nhóm thuốc có cùng ngày kê và cùng loại toa.
- **Mã toa thuốc**: mã hiển thị trên bản in, gồm `MaCSKCB`, phần số của `MaVaoVien` được đệm trái đủ 7 chữ số, dấu gạch ngang và `MaLoaiDonThuoc`; ví dụ cơ sở `CS001`, lượt `VV000125`, loại `c` thành `CS0010000125-c`. Các toa cùng lượt khám và cùng loại dùng chung mã. Mã được tính khi dựng PDF và không lưu thành cột riêng.
- **Loại toa**: danh mục `DM_LoaiToaThuoc` quyết định tiêu đề toa thuốc.
- **Đơn vị dùng**: đơn vị áp dụng cho liều sáng, trưa, chiều và tối; có thể khác đơn vị cấp phát của thuốc.
- **Cha/mẹ/người giám hộ**: nhóm thông tin trên `QL_BenhNhan` gồm mối quan hệ, họ tên, điện thoại và CCCD; bản in luôn hiện các nhãn này và để trống giá trị chưa có.
- **Bản in PDF**: file PDF tạm được tạo theo yêu cầu và đưa vào iframe ẩn để mở hộp thoại in của trình duyệt; QLPM không lưu snapshot của file này.
- **Cơ sở đang làm việc**: tenant `IDCSKCB` lấy từ claims hoặc ngữ cảnh làm việc của quản trị viên hệ thống.

## Thuật ngữ Thu ngân

**Chứng từ thu**:
Bản ghi bất biến của một lần thực nhận tiền. Một lượt khám có thể có nhiều chứng từ thu.
_Tránh dùng_: Phiếu thu cộng dồn

**Hủy thu**:
Vô hiệu hóa một chứng từ thu do ghi nhận sai và không biểu diễn việc chi tiền lại cho người bệnh.
_Tránh dùng_: Hoàn tiền

**Hoàn tiền**:
Trả lại tiền đã nhận và tạo một chứng từ hoàn riêng liên kết với chứng từ thu gốc.
_Tránh dùng_: Hủy thu

## Thuật ngữ Kho

**Tồn thực tế**:
Tổng số lượng thuốc đang hiện diện trong kho, gồm cả lượng chưa được phép cấp.

**Tồn hết hạn/khóa**:
Phần tồn thực tế thuộc lô hết hạn hoặc bị khóa và không được dùng để cấp thuốc.

**Tồn khả dụng**:
Phần tồn thực tế còn hạn, không bị khóa và được phép cấp tại thời điểm kiểm tra.

**Cấp thuốc một phần**:
Cấp ít hơn số lượng còn phải cấp của một dòng toa và tiếp tục theo dõi phần chưa cấp.

**Hoàn thuốc**:
Đưa một số lượng thuốc đã cấp về đúng lô kho; có thể thực hiện theo từng dòng và số lượng.

**Phiếu điều chỉnh kho**:
Chứng từ bất biến ghi nhận tăng hoặc giảm tồn có lý do, không thay thế phiếu nhập hay phiếu cấp thuốc.

**Phiếu hủy thuốc**:
Chứng từ giảm tồn thực tế đối với thuốc hết hạn, hỏng hoặc không còn được phép sử dụng.

## Thuật ngữ chuyển đổi dữ liệu

**Dữ liệu legacy**:
Chứng từ được tạo trước thời điểm chuyển đổi và được giữ nguyên để tra cứu, không tự suy diễn thành các chứng từ mới.

**Thời điểm cutover**:
Mốc ngày giờ từ đó hệ thống chỉ ghi nhận chứng từ theo hợp đồng nghiệp vụ mới.
