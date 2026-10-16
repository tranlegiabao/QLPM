# Luồng nghiệp vụ QLPM — main

Luồng dưới đây là contract source v97; trạng thái DB và route thực tế phải kiểm chứng sau cutover. Xem [bàn giao Thu ngân/Kho](../KeHoach/ThuNgan_Kho_Implementation_Handoff.md).

## Tiếp nhận

```text
Tìm/nhập bệnh nhân
→ nhập hành chính
→ chọn công khám
→ lưu
→ chuyển khám
→ nếu account có quyền Khám: mở /kham_benh?id_vao_vien=...
→ nếu không: ở lại Tiếp nhận và tải lại danh sách
```

### Tìm và tiếp nhận bệnh nhân cũ

- Từ khóa tìm kiếm được dùng để tìm hồ sơ/lượt cũ trên các ngày; khi có từ khóa, bộ lọc ngày và trạng thái chuyển khám không áp dụng.
- Chọn lượt/hồ sơ cũ sẽ nạp thông tin hành chính vào form để tạo lượt tiếp nhận mới. Badge `BN cũ` biểu thị form đang dùng hồ sơ bệnh nhân đã có; dấu `Cũ` trong danh sách biểu thị lượt không thuộc ngày hiện tại.
- Với lượt đã khám xong trong ngày, Tiếp nhận thông báo đang tạo lượt mới và giữ nguyên lượt trước.

## Khám

```text
Chọn lượt (chỉ đọc; chưa đổi trạng thái)
→ nhập lần đầu: ghi riêng TrangThaiKham=1 vào DB
→ Sinh hiệu
→ Triệu chứng/bệnh sử
→ Chẩn đoán ICD
→ Chỉ định CLS
→ Toa thuốc
→ Lưu: STO_QL_Kham_Luu ghi dữ liệu vào DB, giữ trạng thái Đang khám
→ thu CLS nội bộ đã lưu (không cần Khám xong); bác sĩ tiếp tục lưu hồ sơ
→ Khám xong: bắt buộc đúng 1 ICD chính, toa thuốc tùy chọn
→ STO_QL_Kham_Luu với KhamXong=1 hoặc STO_QL_Kham_HoanTat đặt TrangThaiKham=2
```

Màn Khám dạng cuộn: BN + phác đồ → sinh hiệu → triệu chứng → chẩn đoán → CLS → toa thuốc.

## Phác đồ

Phác đồ gồm thông tin, triệu chứng, nhiều ICD, CLS mẫu và thuốc mẫu. Áp dụng phác đồ chỉ nạp vào bản nháp để bác sĩ kiểm tra trước khi lưu.

## CLS

```text
Chỉ định CLS → Lưu (hoặc STO_QL_Cls_DamBaoChiDinh khi tải kết quả)
→ chỉ định và nguồn tiền được lưu trong cùng transaction
→ chọn hoặc thả một file PDF (tối đa 15 MB)
→ tải lên thành file hiện hành; file cũ được dọn sau khi thay thế thành công.

Một chỉ định có tối đa một file hiện hành. Dịch vụ chưa cấu hình form kết quả vẫn tải file được.
```

Kết quả chỉ lưu một PDF qua DuongDanKetQua; không trích trị số hoặc lưu mô tả nhập tay. File cũ được giữ tới khi cập nhật đường dẫn thành công. Chưa áp policy bắt buộc thanh toán trước upload; không có luồng duyệt/hủy duyệt CLS.

## Danh mục JSON

QLPM database là nguồn dữ liệu; JSON là cache/read-model. Script `24_json_danh_muc_phien_ban.sql` cấu hình trigger version cho `DM_CSKCB`, `DM_DanToc`, `DM_TinhThanh`, `DM_PhuongXa`, `DM_ICD10`, `DM_DichVu`, `DM_DonViTinh`, `DM_Thuoc`, `DM_TriSoSinhHieu`, `DM_NhanVien`, `DM_PhacDo`, `DM_QuocTich`, `DM_NgheNghiep`, `DM_GioiTinh` và `DM_NganHang`. INSERT/UPDATE/DELETE trên các bảng có trigger đánh dấu version JSON dirty cho CSKCB liên quan; thay đổi bảng khác không tự động tăng version nếu không có trigger tương ứng.

Worker kiểm tra lịch mỗi 30 giây và chạy tối đa một lượt mỗi ngày theo ngày giờ SQL Server, xử lý các CSKCB dirty. Nếu ứng dụng khởi động sau nửa đêm, lượt trong ngày chạy khi worker phát hiện lịch đến hạn; lỗi hoặc process dừng giữa lượt được retry sau 15 phút. Nút **Đồng bộ danh mục JSON** trong Hệ thống gọi API `/api/he_thong/danh_muc/dong_bo` để tạo lại cache ngay cho CSKCB đang chọn. Khi tạo JSON, service chỉ đọc QLPM và ghi file JSON; runtime không truy cập HIS.

## Auth

Đăng nhập → DB xác thực → cookie/claims → reload quyền → global authorization → menu/API.


### Hỗ trợ sau khi đã khám
Tài khoản `quan_tri_he_thong` có thể mở và chỉnh sửa lượt đã `Đã khám` khi bác sĩ nhờ hỗ trợ. Việc chỉnh sửa không hạ trạng thái lượt khám và không đổi bác sĩ phụ trách thành nhân viên hỗ trợ.

Tại Tiếp nhận:
- Lượt đã chuyển khám/đang khám chỉ cho sửa hồ sơ hành chính và thông tin người giám hộ trong `QL_BenhNhan`; không sửa công khám, STT, trạng thái hay bác sĩ của lượt.
- Lượt đã khám xong vẫn có thể tiếp nhận lại để tạo `IDVaoVien` mới như trước. Nếu chọn **Sửa thông tin BN**, hệ thống chỉ cập nhật `QL_BenhNhan` và giữ nguyên lượt đã khám.


## Thu ngân

Luồng chuẩn: Tiếp nhận → Đang khám → lưu CLS → thu các CLS nội bộ được chọn → bác sĩ tiếp tục khám/lưu → Khám xong → thu công khám, thuốc và CLS còn lại. Không thu thuốc/công khám trước Khám xong và không đổi trạng thái khám để thu. CLS gửi ngoài vẫn thuộc hồ sơ, không được chọn thu.

Bộ lọc Thu ngân gồm **Chưa thu / Đã thu / Tất cả**; tính theo khoản hiện được phép thu. Thêm CLS sau lần thu đầu hoặc Khám xong có khoản mới sẽ trở về Chưa thu. Mỗi lần thu tách chứng từ CHI_DINH và TOA_THUOC nếu có dòng tương ứng; in theo ID chứng từ lấy snapshot, in gộp lượt là lựa chọn riêng.

Sau thu CLS, không khóa toàn hồ sơ khám. Dòng đã thu hoặc từng có chứng từ (kể cả đã hủy/hoàn) giữ ID và thông tin thương mại, không được xóa/đổi lượng/nơi thực hiện/giá; bác sĩ vẫn cập nhật hồ sơ và thêm nguồn mới. Không xóa chỉ định đã thực hiện/có PDF. Hủy chứng từ và hoàn tiền tách biệt, không sửa snapshot; thuốc đã giao phải được Kho xác nhận hoàn trước khi xử lý tiền của đúng chứng từ.

## Kho

`DM_Thuoc` là danh mục, không phải số tồn. Tồn quản lý theo kho và lô tại `QL_Kho_LoThuoc`; đơn vị kê/nhập quy về đơn vị cơ sở bằng `DM_Thuoc_DonViQuyDoi`. Nhập kho ghi lô và hạn dùng; không nhận lô đã hết hạn. Xuất thuốc chỉ lấy dòng toa đã thanh toán của lượt Khám xong, không yêu cầu mọi công khám/CLS khác đã thu, và phân bổ lô theo **FEFO** (hết hạn trước xuất trước), không cho tồn âm và không xuất lô hết hạn. Cấp/hoàn một phần; hoàn theo đúng dòng cấp/lô hoặc cờ hoàn toàn bộ riêng. Thu CLS không thay tồn thuốc. Backlog thu thuốc theo số lượng còn chưa hoàn tất; không coi v97 là đã xong toàn bộ parity kho.
