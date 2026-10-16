# Kế hoạch ký số và liên thông QLPM — Hieu_12/10_1

**Nguồn tham chiếu:** báo cáo kỹ thuật `BAO_CAO_KY_SO_VA_LIEN_THONG_TOA_THUOC(1).md` người dùng cung cấp; source QLPM nhánh `Hieu_12/10`; hai PDF mẫu `Doc/UI/pdf-mẫu/kysochidinh.pdf`, `Doc/UI/pdf-mẫu/kysotoathuoc.pdf`.

**Nhánh triển khai:** `Hieu_12/10_1` (tách từ `Hieu_12/10` tại `caf872dd3340bdfda1a33495ea2030355332186f`).

**Phạm vi:** sửa **(1) Ký số toa thuốc PDF**, sửa **(2) Liên thông toa thuốc quốc gia**, tạo mới **(3) Ký số phiếu chỉ định CLS**. Dịch vụ ký PDF dùng chung là hạ tầng của (1) và (3), không coi là chức năng thay thế ký chỉ định.

## Tiến độ triển khai (12/10/2026)

| Hạng mục | Tình trạng |
|---|---|
| Đồng bộ UI `Hieu_12/10` | Đã merge CSS mới vào `Hieu_12/10_1` |
| P0 Gỡ khóa toàn cục theo yêu cầu 12/10 | Đã gỡ khóa service/HTTP/worker/UI; kiểm tra contract dùng transport giả |
| P1 Adapter ký PDF theo hợp đồng HISoft | Đã tạo interface/adapter + DI; **chưa thể ký thật** khi thiếu URL/credential provider được cấp |
| P2 Ký toa thuốc | Có xem trước PDF đã lưu, hash, khung ký; **chưa có PDF ký thật** |
| P3 Ký chỉ định CLS | Có nút Ký số, modal xem trước và chọn phiếu nội bộ/gửi ngoài; **chưa có PDF ký thật** |
| P4 Liên thông quốc gia | Client/worker đã gỡ khóa toàn cục; gửi theo cấu hình và trạng thái. Có xem trước JSON riêng |
| P5 Cấu hình mẫu ký và schema | Có migration `48_ky_so_pdf_mau_va_tai_lieu_v107.sql`, form CSKCB, kho tài liệu ký/audit dự phòng |
| Build & kiểm thử an toàn | CI .NET 7 và SafetyChecks; chưa chạy migration trên SQL Server máy người dùng |

Đọc thêm `Doc/Test/KySo_v107.md` trước khi thử. Không nhầm chức năng **xem trước ký** với chữ ký hợp lệ PKI/CMS. Muốn triển khai ký thật cần hợp đồng API, tài khoản và đặc tả chính thức của provider ký số; nếu chưa có, không đánh dấu P1–P3 hoàn tất nghiệp vụ LIVE.

## 1. Phân tích hai mẫu ký số

| Thuộc tính | Ký số chỉ định | Ký số toa thuốc |
|---|---|---|
| File | `kysochidinh.pdf` | `kysotoathuoc.pdf` |
| PDF | PDF 1.4, một trang, A5 `MediaBox [0 0 419 596]` | PDF 1.4, một trang, A5 `MediaBox [0 0 419 596]` |
| Khung trường chữ ký `/Rect` | `[249 200 389 245]` | `[266 193 406 238]` |
| Kích thước khung | 140 × 45 pt | 140 × 45 pt |
| Cấu trúc chữ ký | `/FT /Sig`, `/ByteRange`, `/SubFilter /adbe.pkcs7.detached` | Tương tự |
| Nội dung chữ ký | CMS/PKCS#7 detached | CMS/PKCS#7 detached |

**Lưu ý:** Các thông số đọc từ cấu trúc PDF. Chưa xác minh tính hợp lệ mật mã, chuỗi tin cậy/thu hồi chứng thư hoặc so sánh ảnh render; không suy ra API ký của HISoft chỉ từ mẫu đã ký.

## 2. Quy tắc nền tảng (bắt buộc)

1. **Tích hợp theo cấu hình:** không còn khóa toàn cục; HTTP client và worker xử lý nghiệp vụ khi đủ cấu hình, quyền và trạng thái. TEST/PRODUCTION vẫn tách biệt, không tự chuyển môi trường.
2. **Không tạo trạng thái thành công giả:** xem trước JSON/PDF, vị trí ký, request cấu trúc và kết quả validator; **không** tạo PDF ký giả, không ghi `DA_KY`, `THANH_CONG`, không cập nhật `DaDangKy` chỉ vì xem trước. Lưu lịch sử mô phỏng tách khỏi giao dịch thật.
3. **Hai cơ chế riêng:** ký PDF với CMS/PAdES không đồng nghĩa đã ký JSON; `signature` JSON quốc gia chỉ được tạo nếu đặc tả chính thức yêu cầu và xác định rõ thuật toán/encoding. Không dùng PDF `dataSign` gán vào `signature`.
4. **Ký và liên thông không tự gọi nhau:** bác sĩ ký PDF bằng hành động riêng; liên thông là hành động riêng, không tự gửi sau khi ký.
5. **Phân quyền + tenant:** chỉ bác sĩ phù hợp/người được phân quyền được ký; kiểm soát `IDCSKCB`, chủ hồ sơ, bản PDF trước ký và phiên bản dữ liệu; audit đầy đủ và chống thao tác lặp.
6. **API thật:** Dược Quốc gia `https://api.donthuocquocgia.vn`; các endpoint `/api/auth/dang-nhap-bac-si`, `/api/auth/dang-nhap-co-so-kham-chua-benh`, `/api/v1/them-bac-si`, `/api/v1/gui-don-thuoc`. URL ký PDF theo cấu hình từng provider/CSKCB; báo cáo HISoft không cung cấp URL thật, không bịa ra. Dùng UAT của provider khi có thông tin tích hợp hợp lệ.

## 3. Giai đoạn triển khai

### P0 — Cấu hình tích hợp và kiểm tra luồng gửi

- Dùng cấu hình hiệu lực ký/liên thông và môi trường từng CSKCB; kiểm tra endpoint, adapter, timeout và credential trước khi thực hiện.
- Worker xử lý hàng đợi `CHO_GUI` theo luồng hiện hữu; chỉ gửi khi đủ cấu hình liên thông, API môi trường và phiên bản toa.
- Các thao tác xem trước/mô phỏng JSON không thay đổi trạng thái nghiệp vụ ký/gửi thật.
- Kiểm tra contract HTTP bằng transport giả: request ký PDF, login/đăng ký/gửi quốc gia, response lỗi, che credential và signer chưa cấu hình. Không khởi động host/worker trong harness.

### P1 — Hạ tầng ký PDF dùng chung

- Tạo adapter `IPdfSigningProvider` độc lập `IToaThuocSigner`: request PDF Base64, mã CSKCB, mã người ký, trang, vị trí (X/Y), kích thước; response có `statusCode`, `message`, `dataSign`, `maHoSo` theo hợp đồng HISoft **sau khi xác nhận đặc tả API ký thực tế**.
- Cấu hình tọa độ và kiểu hiển thị theo loại `TOA_THUOC` / `CHI_DINH_CLS`, không hard-code mẫu A5 cho mọi phiếu; kiểm tra vị trí khi nhiều trang và phân trang.
- Lưu cả file gốc và file ký thành công theo revision, hash SHA-256, chứng thư, người ký, thời điểm, tài liệu nguồn. Kiểm tra cấu trúc `/ByteRange`, CMS/PAdES và tính toàn vẹn PDF; nếu không đạt, báo lỗi và không đổi trạng thái.
- Modal xác nhận ký số nếu cơ sở bật chính sách; **mã xác nhận 6 số chỉ là xác thực thao tác UI**, không thay thế chữ ký PKI.
- Cấu trúc kho tài liệu và phân quyền truy xuất PDF ký phải độc lập các đường dẫn của máy chạy HISoft.

### P2 — Sửa ký số **toa thuốc**

- Giữ nút `Ký số` ở Khám bệnh; chỉ lấy bản toa đã lưu/khám hoàn tất, không ký nháp frontend.
- Dùng `KhamBenhPrintService.InToaThuocAsync` để sinh PDF, áp khung ký mẫu `kysotoathuoc.pdf` cho A5 (có thể override theo CSKCB); xem trước trước khi xác nhận.
- Tách PDF signer khỏi `ToaThuocDeliveryService.KySoAsync` đang đòi ký JSON + PDF cùng một lần. Quy tắc `signature` JSON không suy diễn từ mẫu PDF.
- Giữ lịch sử `QL_ToaThuoc_PhienBan` / `QL_ToaThuoc_Audit` và trạng thái liên thông hiện tại tương thích; điều chỉnh schema/STO nếu cần để theo dõi PDF ký riêng và rõ ràng.
- Khi sửa thuốc/chẩn đoán, invalidate chữ ký của phiên bản cũ; không ký lại vô hạn hoặc dùng bản ký cũ để xuất/gửi bản mới.

### P3 — **Tạo mới Ký số chỉ định CLS**

- Thêm nút `Ký số` tại khu vực **Chỉ định** cạnh nút In; quyền, cảnh báo, trạng thái, xem trước, tải và xem lại PDF ký.
- Dùng `KhamBenhPrintService.InChiDinhAsync` trên dữ liệu đã lưu. Hiện service tách phiếu gửi ngoài/nội bộ: mỗi PDF cần id/phiên bản riêng và ký độc lập; không ký chung các phiếu nếu nghiệp vụ in tách riêng.
- Áp khung ký mẫu `kysochidinh.pdf` cho mẫu A5, hỗ trợ vị trí cấu hình theo mẫu và số trang.
- Tạo liên kết tài liệu ký vào `IDCSKCB`, `IDVaoVien`, loại phiếu/nhóm chỉ định và revision/hash; không trộn với file kết quả CLS bệnh nhân. Nếu chỉ định nguồn thay đổi, phiên bản ký cũ mất hiệu lực theo quy tắc nghiệp vụ.
- Dùng cùng adapter PDF signer, modal xác nhận và audit với ký toa.

### P4 — Sửa **liên thông toa thuốc quốc gia**

- Giữ trang nghiệp vụ liên thông riêng (nút Liên thông đã bỏ ở Khám bệnh); kiểm tra và tạo payload, xem trước JSON đã mask, xem lịch sử, thử hợp đồng API nội bộ.
- Chỉnh `ToaThuocReadinessService`: kiểm tra **điều kiện ký PDF** và **điều kiện liên thông** độc lập; không khóa cứng liên thông vào việc ký PDF trừ khi quy định quốc gia/đơn vị tích hợp thực sự yêu cầu.
- Map và xác thực đầy đủ trường dữ liệu từ báo cáo HISoft: bệnh nhân, cơ sở, bác sĩ, chẩn đoán ICD, thuốc và liều, thời điểm, loại đơn; không tự đặt `signature` rỗng/giả rồi tuyên bố ký thành công.
- Giữ HTTP typed client, outbox, idempotency key, audit và worker hiện có. Bổ sung retry/backoff có kiểm soát và trạng thái cần đối soát; **không gửi lại tự động** khi không rõ API đã nhận.
- Xem trước JSON là thao tác riêng để kiểm tra dữ liệu; các action ký, xếp hàng và gửi API thực hiện nghiệp vụ theo cấu hình.

### P5 — UI, migration và kiểm thử nghiệm thu

- `Hệ thống → Cấu hình ký số & liên thông`: tab dịch vụ ký, loại mẫu ký, CSKCB, bác sĩ, môi trường, trạng thái cấu hình và thông báo điều kiện còn thiếu.
- UI phân biệt `Xem trước` và `Ký số`: trang Quản lý gọi ký nghiệp vụ; nút xem trước ở Khám bệnh chỉ trả PDF nguồn chưa ký.
- Migration SQL version kế tiếp từ v106, có script chạy lặp an toàn, verifier, rollback plan. Tuyệt đối không cập nhật DB thật khi chưa xác nhận test trên bản sao.
- Nghiệm thu: khung chữ ký đúng hai mẫu A5; kiểm thử nhiều trang, gửi ngoài/nội bộ, tenant, token/secret không lộ, bản ký bị thay đổi không hợp lệ, không lưu bản ký giả, kiểm tra client/worker theo cấu hình; build .NET 7, test tự động và thử giao diện.

## 4. Tiêu chí dừng/điều kiện còn thiếu

- Hai PDF mẫu chứa chữ ký CMS ở dạng PDF thực, nhưng **không chứng minh** URL/provider ký hoặc tình trạng hiệu lực chứng thư. Phải xác thực provider và chính sách chứng thư khi mở tích hợp thật.
- Cần tài liệu hợp đồng API ký PDF (endpoint thực, xác thực, schema, hệ tọa độ, response), tài khoản tích hợp được cấp hợp lệ. Báo cáo HISoft nói URL nằm trong `HT_DuongDanKySo`, chưa công bố giá trị.
- Cần tài liệu chính thức cho trường `signature` khi gửi JSON quốc gia. Không sao chép `signature = ""` hoặc coi chữ ký PDF là chữ ký JSON nếu chưa được chuẩn hóa.
- Đã triển khai source cho xem trước và gỡ khóa toàn cục; các hạng mục ký/lưu thật còn phải hoàn thiện và xác minh riêng.
