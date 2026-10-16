# Đối chiếu Thu ngân và Kho: QLPM so với HisSoft

## 1. Mục đích và trạng thái

Tài liệu này ghi nhận kết quả đối chiếu mã nguồn và backlog đã thống nhất cho QLPM. Phần hiện trạng ở mục 3 là baseline trước triển khai; trạng thái mới nhất nằm ngay bên dưới.

| Phạm vi | Nguồn đối chiếu |
|---|---|
| QLPM | Nhánh `Hieu_05/10` |
| HisSoft | Nhánh `Hieu_01/10` |
| Mức xác minh | Đọc tĩnh controller, view, JavaScript, service và STO/script SQL |
| Chưa xác minh | Route sau đăng nhập, dữ liệu và STO trên DB live, hành vi trình duyệt, kết quả triển khai |

Các thay đổi cục bộ có sẵn trong hai repo được giữ nguyên.

### Trạng thái triển khai ngày 07-10-2026

| Hạng mục | Trạng thái code | Xác minh |
|---|---|---|
| Hủy chứng từ tự đảo cấp thuốc (quyết định mới) | Source v98: transaction đảo đúng dòng thu/lô còn giao trước hủy; giữ lịch sử/audit, legacy mơ hồ reject | PASS26 source/parser +20 action VM; build đạt; chưa migrate DB/auth/concurrency |
| Thu CLS nội bộ khi Đang khám, lưu tiếp sau thu | Source v97: condition chung, giữ ID/snapshot và khóa từng nguồn, lưu nhanh đồng bộ tiền | PASS61 .NET +32 Node; chưa migrate DB/login/runtime/concurrency |
| P0.1 chứng từ thu độc lập, lịch sử, hủy và in lại | Đã có; v98 tự đảo đúng nguồn cấp khi hủy; API legacy vẫn vô hiệu hóa | Build/fixture pass; chưa DB/route live |
| P0.1 thu thuốc theo lượng và hoàn tiền một phần | Chưa hoàn tất | DTO/UI/SQL thu còn nguyên dòng; hoàn còn toàn bộ, UI hoàn chưa có |
| P0.2 tồn vật lý–hết hạn/khóa–khả dụng, cấp/hoàn một phần | Đã có; v95 hoàn đúng dòng xuất và lựa chọn toàn bộ riêng | Chưa giới hạn cấp theo lượng đã trả; chưa DB/route live |
| P1.1 nhà cung cấp, ngày/số hóa đơn, lịch sử/xem/in/hủy phiếu nhập | Đã triển khai | Build + JS pass; chưa chạy DB/route live |
| P1.1 điều chỉnh tồn và hủy thuốc hết hạn/hỏng | Đã có UI/STO; còn chi tiết/in lại | Chưa DB/route live |
| Mẫu HIS: phiếu thu A4; nhập kho PDF/xlsx | Đã port code và nối route | Fixture Razor/PDF/xlsx pass; chưa so HIS live/Excel desktop |
| P1.2 báo cáo PDF/Excel | Chưa triển khai | Backlog |
| P2 hóa đơn điện tử | Chưa triển khai | Chờ chọn nhà cung cấp/API |

Đợt sửa mới bổ sung v95 `main-cashier-inventory-his-safety-v95` sau v94, không sửa script 28/29. Chưa chạy migration trong lần này; cần xác nhận server/database và thực hiện backup/cutover/đối chiếu theo mục 7. v95 không có nghĩa toàn bộ backlog HIS đã hoàn thành.

Chi tiết thay đổi, test, giới hạn và thứ tự tiếp tục: [ThuNgan_Kho_Implementation_Handoff.md](ThuNgan_Kho_Implementation_Handoff.md).

## 2. Biên nghiệp vụ đã chốt

QLPM là hệ thống phòng khám với một kho. Các chức năng dưới đây của HisSoft **không được coi là thiếu** và không nằm trong backlog QLPM hiện tại:

- Thu BHYT, khám sức khỏe, vật tư, toa lẻ, vaccine và thanh toán nội trú/ra viện.
- Tạm ứng.
- Phân quyền đa kho và điều chuyển giữa nhiều kho.
- Các nghiệp vụ HIS khác chỉ cần khi QLPM được mở rộng phạm vi sản phẩm.

Hóa đơn điện tử được giữ ở P2 dưới dạng tích hợp tùy cơ sở.

## 3. Hiện trạng có trong source QLPM

### 3.1. Thu ngân

QLPM hiện có:

- Danh sách lượt đã khám xong; lọc, tìm kiếm và phân trang.
- Chi tiết chỉ định và thuốc theo lượt khám.
- Chọn từng dòng để thu; hỗ trợ phụ thu, giảm phần trăm, tiền mặt, chuyển khoản/ngân hàng và ghi chú.
- Thu nhiều lần theo các dòng chưa thu, nhưng số tiền hiện được cộng dồn vào một master của lượt khám.
- Hủy toàn bộ hoặc hủy nhóm chỉ định/toa; chặn hủy tiền thuốc khi thuốc đã được cấp.
- In phiếu thu từ dữ liệu đọc lại trong DB.
- Ghi lịch sử hành động ở tầng SQL.

Bằng chứng chính:

- [`thu_ngan_controller.cs`](../../QuanLyPhongMach/Controllers/thu_ngan_controller.cs)
- [`thungan.js`](../../QuanLyPhongMach/wwwroot/js/thu_ngan/thungan.js)
- [`28_thu_ngan.sql`](../Database/28_thu_ngan.sql)

### 3.2. Kho

QLPM hiện có:

- Một kho sử dụng cho cơ sở; tồn quản lý theo thuốc và lô.
- Nhập nhiều dòng với đơn vị quy đổi, số lô, hạn dùng, số lượng, giá nhập, số hóa đơn và ghi chú.
- Không nhập lô đã hết hạn; xuất thuốc theo FEFO và không cho tồn âm.
- Chỉ cấp dòng thuốc đã thu tiền; dữ liệu SQL cho phép số lượng cấp nhưng UI hiện gửi toàn bộ số còn lại.
- Hoàn thuốc về đúng lô, nhưng hiện hoàn toàn bộ lượng đã cấp còn hiệu lực của lượt.
- Phân nhóm thuốc hiện hữu.

Bằng chứng chính:

- [`kho_controller.cs`](../../QuanLyPhongMach/Controllers/kho_controller.cs)
- [`kho.js`](../../QuanLyPhongMach/wwwroot/js/kho/kho.js)
- [`nhom-thuoc.js`](../../QuanLyPhongMach/wwwroot/js/kho/nhom-thuoc.js)
- [`29_kho_nghiep_vu.sql`](../Database/29_kho_nghiep_vu.sql)

## 4. Khoảng thiếu cần xử lý cho QLPM

### 4.1. Thu ngân

1. Một lần thu chưa có chứng từ độc lập; các lần thu của cùng lượt bị cộng dồn.
2. Chưa phân biệt hủy chứng từ do sai sót với hoàn tiền thực tế cho người bệnh.
3. Chưa có danh sách lịch sử chứng từ để tìm, xem và in lại đúng từng lần thu/hủy/hoàn.
4. Quyền thao tác mới dừng ở `Xem/Sửa`, chưa tách các hành động có rủi ro tài chính.
5. Chưa có báo cáo vận hành theo ngày, thu ngân và phương thức thanh toán.

### 4.2. Kho

1. Tồn hiển thị chưa tách tồn thực tế, tồn hết hạn/khóa và tồn khả dụng.
2. UI chưa cho chủ động cấp một phần và giữ lại số lượng còn phải cấp.
3. Hoàn thuốc chưa hỗ trợ từng dòng và số lượng.
4. Phiếu nhập chưa gắn nhà cung cấp và chưa có màn hình lịch sử/xem/in lại.
5. Chưa có phiếu điều chỉnh tồn và phiếu hủy thuốc hết hạn/hỏng.
6. Chưa có thẻ kho, báo cáo nhập-xuất-tồn và báo cáo lô/hạn dùng.

## 5. Backlog đã chốt

### P0.1 — Chứng từ Thu ngân độc lập

#### Hợp đồng nghiệp vụ

- Mỗi lần thực nhận tiền tạo một chứng từ thu riêng; một lượt khám có thể có nhiều chứng từ.
- Chứng từ đã ghi nhận là bất biến. Sai sót được xử lý bằng hủy chứng từ và lập chứng từ mới.
- Mỗi loại chứng từ có chuỗi số riêng theo cơ sở và năm; ví dụ `PT-CS01-2026-000001`.
- Tách rõ:
  - **Hủy thu**: vô hiệu hóa chứng từ ghi sai, không biểu diễn dòng tiền chi ra.
  - **Hoàn tiền**: tạo chứng từ hoàn riêng, liên kết chứng từ thu gốc và biểu diễn tiền đã trả lại.
- Hủy và hoàn bắt buộc có lý do, người thực hiện và thời điểm thực hiện.
- Không hoàn tiền của dòng thuốc còn lượng đã cấp chưa hoàn kho tương ứng.

#### Quyền

- `Thu`.
- `Hủy thu`.
- `Hoàn tiền`.
- `In lại`.
- `Xem báo cáo`.

#### Giao diện/API tối thiểu

- Danh sách chứng từ theo ngày, người bệnh, mã lượt, số chứng từ, người thu và trạng thái.
- Xem chi tiết và in lại đúng dữ liệu của từng chứng từ.
- Tạo chứng từ hoàn từ chứng từ thu gốc; không nhập một khoản hoàn không có nguồn.
- Hiển thị rõ chứng từ bị hủy, chứng từ hoàn và quan hệ giữa chúng.

#### Tiêu chí nghiệm thu

- Hai lần thu một lượt sinh hai số chứng từ khác nhau và in lại độc lập.
- Hủy một chứng từ không làm thay đổi chứng từ thu khác của cùng lượt.
- Hoàn một phần không vượt quá số đã thu trừ số đã hoàn trước đó.
- Hai yêu cầu đồng thời không được thu hoặc hoàn trùng cùng một dòng chi phí.
- Lịch sử giữ nguyên dữ liệu tài chính của chứng từ sau khi giá danh mục thay đổi.

### P0.2 — Tính đúng tồn và cấp/hoàn thuốc theo số lượng

#### Hợp đồng nghiệp vụ

- Tách ba số:
  - **Tồn thực tế**: toàn bộ lượng đang hiện diện trong kho.
  - **Tồn hết hạn/khóa**: lượng không được cấp.
  - **Tồn khả dụng**: lượng còn hạn, không khóa và được phép cấp.
- Cho cấp một phần theo từng dòng toa; theo dõi `Số kê`, `Đã cấp`, `Còn phải cấp`.
- Cho hoàn theo dòng, số lượng và phiếu cấp; thao tác “Hoàn toàn bộ” chỉ là lối tắt.
- Thuốc hết hạn tự bị loại khỏi tồn khả dụng nhưng không tự giảm tồn thực tế.
- Giảm tồn thực tế của thuốc hết hạn/hỏng chỉ qua phiếu hủy thuốc.
- Điều chỉnh tăng/giảm chỉ qua phiếu điều chỉnh có lý do và lịch sử.

#### Quyền

- `Nhập`.
- `Cấp thuốc`.
- `Hoàn thuốc`.
- `Điều chỉnh/Hủy thuốc`.
- `Xem báo cáo`.

#### Tiêu chí nghiệm thu

- Thiếu tồn vẫn có thể cấp phần đang có và giữ đúng số lượng còn thiếu.
- Không dòng nào được cấp vượt số còn phải cấp hoặc tồn khả dụng.
- Hoàn một phần trả đúng số lượng về đúng lô đã xuất và không làm tăng quá lượng đã cấp.
- Lô hết hạn/khóa vẫn xuất hiện trong tồn thực tế nhưng không được FEFO chọn để cấp.
- Hai thao tác xuất/hoàn đồng thời không tạo tồn âm hoặc hoàn vượt lượng đã cấp.
- Hủy chứng từ thuốc tự đảo phần cấp còn giao của đúng chứng từ trong cùng transaction trước hủy thu (quyết định mới v98, thay điều kiện Kho xác nhận trước cho hủy). Hoàn tiền vẫn cần Kho nhận lại trước. Đảo do hủy là bút toán sổ, không xác nhận thuốc vật lý hay tự chuyển tiền ngân hàng.

### P1.1 — Nhà cung cấp và vòng đời phiếu kho

- Danh mục nhà cung cấp tối giản, có trạng thái hoạt động.
- Phiếu nhập lưu nhà cung cấp, số hóa đơn, ngày hóa đơn và ghi chú.
- Danh sách lịch sử phiếu nhập/cấp/hoàn/điều chỉnh/hủy thuốc; hỗ trợ xem và in lại.
- Chứng từ kho đã ghi nhận là bất biến.
- Chỉ được hủy phiếu nhập khi toàn bộ số lượng từ phiếu chưa phát sinh xuất/cấp. Nếu đã phát sinh, xử lý bằng chứng từ điều chỉnh phù hợp.
- Không đưa đơn mua hàng hoặc quy trình duyệt mua vào phạm vi hiện tại.

### P1.2 — Báo cáo vận hành

#### Thu ngân

- Lịch sử từng lần thu, hủy và hoàn.
- Tổng hợp theo ngày, thu ngân và tiền mặt/chuyển khoản.
- Xuất PDF/Excel.
- Không gồm sổ kế toán, công nợ hoặc đối soát ngân hàng.

#### Kho

- Nhập-xuất-tồn.
- Thẻ kho.
- Tồn theo lô và hạn dùng.
- Thuốc sắp hết hạn/hết hạn.
- Lịch sử chứng từ.
- Xuất PDF/Excel.

### P2 — Hóa đơn điện tử

- Thiết kế dưới dạng tích hợp tùy cơ sở, không chặn nghiệp vụ thu ngân cốt lõi.
- Chọn nhà cung cấp hóa đơn và hợp đồng API ở một quyết định riêng trước khi triển khai.
- Không đưa các nhánh BHYT, KSK, vật tư, toa lẻ, vaccine hoặc nội trú của HisSoft vào hạng mục này.

## 6. Chức năng HisSoft chỉ tham khảo khi mở rộng sản phẩm

Các nhóm sau tồn tại ở HisSoft nhưng không thuộc backlog đã duyệt của QLPM:

- Thu BHYT, KSK, vật tư, toa lẻ, vaccine, tạm ứng và thanh toán ra viện.
- Tài chính tổng hợp cấp bệnh viện, thu gộp nhiều nhánh và nghiệp vụ kế toán mở rộng.
- Đa kho, phân quyền theo kho và nhập/xuất điều chuyển nội bộ.
- Xuất sử dụng, xuất thanh lý, định vị hàng theo kho và các danh mục hậu cần cấp HIS.

Nguồn tham khảo HisSoft:

- `Controllers/QL_TaiChinhController.cs`
- `Services/ManagermentServices/QlTaiChinhServices.cs`
- `Controllers/HH_NhapKhoController.cs`
- `Controllers/HH_HangTonKhoController.cs`
- `Controllers/HH_TheKhoController.cs`

## 7. Chuyển đổi dữ liệu và cutover

1. Chốt ngày giờ cutover và đóng thao tác Thu ngân/Kho cũ trong thời gian chuyển đổi.
2. Sao lưu DB và lập manifest đối chiếu tối thiểu:
   - tổng tiền đã thu/chưa thu theo lượt;
   - số chứng từ và tổng tiền mặt/chuyển khoản;
   - tồn theo thuốc, kho, lô và hạn dùng;
   - lượng đã cấp và đã hoàn theo dòng toa.
3. Giữ chứng từ cũ dưới dạng **dữ liệu legacy** chỉ đọc.
4. Không tự chia phiếu thu cũ thành nhiều chứng từ mới vì không đủ bằng chứng để tái tạo chính xác từng lần giao tiền.
5. Từ thời điểm cutover, mọi ghi nhận mới dùng hợp đồng chứng từ mới.
6. Chạy kiểm tra đối chiếu tiền–tồn và các quan hệ thu–cấp–hoàn trước khi mở lại hệ thống.
7. Chuẩn bị script rollback và điều kiện dừng rõ ràng trước khi thực thi trên DB thật.

## 8. Thứ tự thực hiện và phụ thuộc

1. Chốt schema, STO và chiến lược dữ liệu legacy cho P0.1.
2. Triển khai chứng từ Thu ngân, quyền và kiểm thử đồng thời.
3. Chốt schema giao dịch kho và quan hệ giữa cấp/hoàn thuốc với chứng từ tài chính.
4. Triển khai P0.2 và kiểm thử liên thông Thu ngân → Kho → hoàn kho → hoàn tiền.
5. Triển khai P1.1 rồi P1.2 trên cùng hợp đồng chứng từ.
6. Chỉ bắt đầu P2 sau khi chọn nhà cung cấp hóa đơn và duyệt hợp đồng tích hợp.

Không triển khai theo kiểu chỉ sửa giao diện. Các quy tắc bất biến, chống ghi trùng, giới hạn số lượng và quan hệ tiền–kho phải được bảo vệ ở STO/constraint/transaction; C# chịu trách nhiệm xác thực request và điều phối.

## 9. Cổng xác minh cho từng hạng mục

Bổ sung 07-10-2026 — admin toàn cục phát thuốc: source/API/STO v96 đã sửa để audit tài khoản thay vì nhân viên giả. Build + 38 assertions pass (kết nối DB giả trong bộ nhớ); **chưa triển khai DB/route thực tế**, chưa đóng nghiệm thu. Xem `ThuNgan_Kho_Implementation_Handoff.md`, migration `34_kho_nguoi_xuat_v96.sql`, verifier read-only `35_verify_kho_actor_v96_readonly.sql`. Chỉ phát thuốc; nhập/hoàn/điều chỉnh còn giữ điều kiện nhân viên.

Mỗi hạng mục chỉ được đánh dấu hoàn thành khi có đủ:

1. Kiểm tra schema/STO idempotent trên đúng DB mục tiêu.
2. Test rollback và test cạnh tranh cho các thao tác ghi tiền/tồn.
3. Build ứng dụng thành công mà không ghi đè thay đổi không liên quan.
4. Kiểm tra route sau đăng nhập với đúng quyền thao tác.
5. Đối chiếu bản in PDF/Excel với dữ liệu DB.
6. Smoke test liên thông: thu một phần → cấp một phần → hoàn thuốc → hoàn tiền.
