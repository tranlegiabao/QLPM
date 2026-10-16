# Quy định pháp lý áp dụng cho phòng khám và QLPM

Tài liệu này tổng hợp các văn bản quy phạm pháp luật có ảnh hưởng trực tiếp đến việc vận hành phòng khám tư nhân và thiết kế phần mềm QLPM. Nội dung được rà soát theo nguồn chính thức đến ngày **05/10/2026**.

Đây là tài liệu định hướng tuân thủ cho sản phẩm. Khi triển khai tại một cơ sở cụ thể, phải đối chiếu giấy phép hoạt động, phạm vi hành nghề, danh mục kỹ thuật được phê duyệt và quy định chuyên khoa của chính cơ sở đó.

Các mục "QLPM phải/cần/nên" dưới đây là **yêu cầu hoặc mục tiêu kiểm soát**, không phải xác nhận rằng runtime hiện tại đã triển khai đầy đủ. Muốn kết luận đã đáp ứng phải kiểm tra riêng code, cơ sở dữ liệu, cấu hình, chữ ký điện tử và kết nối thực tế.

## 1. Xác định đúng loại hình phòng khám

"Phòng mạch" là cách gọi thông thường, không phải tên một loại hình pháp lý duy nhất. Trước khi cấu hình QLPM phải xác định cơ sở thuộc loại nào:

- phòng khám bác sĩ y khoa;
- phòng khám chuyên khoa hoặc liên chuyên khoa;
- phòng khám đa khoa;
- cơ sở khám bệnh, chữa bệnh y học gia đình;
- hình thức chuyên biệt khác được pháp luật cho phép.

Loại hình trên giấy phép quyết định điều kiện cơ sở vật chất, nhân sự, phạm vi hoạt động và danh mục kỹ thuật được thực hiện.

## 2. Danh mục văn bản cần theo dõi

| Văn bản | Trạng thái tại ngày rà soát | Nội dung liên quan QLPM |
|---|---|---|
| [Luật 15/2023/QH15 - Luật Khám bệnh, chữa bệnh](https://vbpl.vn/hanoi/Pages/vbpq-toanvan.aspx?ItemID=168125) | Đang áp dụng | Giấy phép hành nghề, giấy phép hoạt động, quyền người bệnh, hồ sơ bệnh án, chỉ định, kê đơn, giá dịch vụ và hệ thống thông tin khám chữa bệnh. |
| [Nghị định 96/2023/NĐ-CP](https://vanban.chinhphu.vn/?classid=1&docid=209491&pageid=27160) | Hết hiệu lực một phần; các phần còn lại tiếp tục áp dụng | Điều kiện cấp phép theo từng loại hình phòng khám, đăng ký hành nghề, người chịu trách nhiệm chuyên môn, cơ sở vật chất và nhân sự. |
| [Nghị định 148/2025/NĐ-CP](https://vanban.chinhphu.vn/?classid=0&docid=213932&pageid=27160) | Còn hiệu lực từ 01/07/2025 | Phân quyền, phân cấp và điều chỉnh thủ tục hành chính y tế có liên quan Nghị định 96/2023/NĐ-CP. |
| [Thông tư 32/2023/TT-BYT](https://vbpl.vn/TW/Pages/vbpq-toanvan.aspx?ItemID=167907) | Hết hiệu lực một phần; phải đọc theo phần còn hiệu lực | Phạm vi hành nghề, mẫu và nội dung hồ sơ bệnh án, hoạt động chuyên môn theo Luật Khám bệnh, chữa bệnh. |
| [Thông tư 23/2024/TT-BYT](https://vbpl.vn/TW/Pages/ivbpq-toanvan.aspx?ItemID=170581) | Còn hiệu lực | Danh mục kỹ thuật trong khám bệnh, chữa bệnh. Từ 01/07/2026 áp dụng danh mục tại Phụ lục II. |
| [Thông tư 26/2025/TT-BYT](https://vbpl.vn/tiengiang/Pages/vbpq-toanvan.aspx?ItemID=179735) | Còn hiệu lực từ 01/07/2025 | Đơn thuốc và kê đơn thuốc hóa dược, sinh phẩm trong điều trị ngoại trú. |
| [Thông tư 55/2025/TT-BYT](https://vbpl.vn/TW/Pages/vbpq-toanvan.aspx?ItemID=185609) | Còn hiệu lực từ 01/03/2026 | Kê đơn thuốc cổ truyền, thuốc dược liệu và kê đơn kết hợp; chỉ áp dụng khi phòng khám có nghiệp vụ này. |
| [Thông tư 13/2025/TT-BYT](https://vbpl.vn/boyte/Pages/vbpq-toanvan.aspx?ItemID=178219) | Còn hiệu lực từ 21/07/2025 | Lập, cập nhật, ký, lưu trữ và khai thác hồ sơ bệnh án điện tử. |
| [Thông tư 33/2025/TT-BYT](https://vbpl.vn/TW/Pages/vbpq-toanvan.aspx?ItemID=181190) | Còn hiệu lực từ 01/07/2025 | Thời hạn lưu trữ hồ sơ, tài liệu ngành y tế; hồ sơ bệnh án nội trú và ngoại trú thông thường lưu 10 năm. |
| [Thông tư 38/2024/TT-BYT](https://vbpl.vn/TW/Pages/vbpq-toanvan.aspx?ItemID=176350) | Chưa có hiệu lực tại ngày rà soát; có hiệu lực từ 01/01/2027 | Hệ thống thông tin quản lý hoạt động khám bệnh, chữa bệnh; chuẩn bị dữ liệu có cấu trúc và khả năng kết nối API. |
| [Thông tư 16/2018/TT-BYT](https://vbpl.vn/TW/Pages/ivbpq-toanvan.aspx?ItemID=132194) | Còn hiệu lực | Kiểm soát nhiễm khuẩn tại cơ sở khám bệnh, chữa bệnh công và tư. |
| [Thông tư 20/2021/TT-BYT](https://vbpl.vn/hanoi/Pages/vbpq-print.aspx?ItemID=166211) | Còn hiệu lực | Phân loại, thu gom, lưu giữ và bàn giao chất thải y tế trong khuôn viên cơ sở. |
| [Thông tư 09/2015/TT-BYT](https://vbpl.vn/TW/Pages/vbpq-toanvan.aspx?ItemID=67130) | Tiếp tục áp dụng đối với phần còn hiệu lực | Xác nhận nội dung quảng cáo dịch vụ khám bệnh, chữa bệnh; phải đọc cùng thủ tục/phân quyền hiện hành. |
| [Luật 91/2025/QH15 - Luật Bảo vệ dữ liệu cá nhân](https://vbpl.vn/TW/Pages/vbpq-toanvan.aspx?ItemID=179252) | Còn hiệu lực từ 01/01/2026 | Dữ liệu sức khỏe là dữ liệu cần được bảo vệ chặt chẽ; quy định quyền của chủ thể dữ liệu và trách nhiệm xử lý dữ liệu. |
| [Nghị định 356/2025/NĐ-CP](https://vbpl.vn/bocongan/Pages/vbpq-toanvan.aspx?ItemID=187276) | Còn hiệu lực từ 01/01/2026 | Hướng dẫn Luật Bảo vệ dữ liệu cá nhân, gồm phân quyền truy cập và biện pháp bảo mật khi xử lý dữ liệu nhạy cảm. |
| [Nghị định 117/2020/NĐ-CP](https://vanban.chinhphu.vn/default.aspx?docid=201105&pageid=27160) và văn bản sửa đổi | Phải đọc theo bản đã được sửa đổi, bổ sung | Xử phạt vi phạm hành chính trong lĩnh vực y tế. |

## 3. Điều kiện vận hành phòng khám

### 3.1. Giấy phép và cơ sở vật chất

Phòng khám chỉ được hoạt động khi có giấy phép đúng loại hình và duy trì đủ điều kiện đã được cấp phép. Các điều kiện chung cần quản lý gồm:

- địa điểm hoạt động cố định;
- biển hiệu, sơ đồ và biển chỉ dẫn;
- điện, nước, phòng cháy chữa cháy, bảo vệ môi trường;
- kiểm soát nhiễm khuẩn và an toàn bức xạ nếu có;
- thiết bị phù hợp với phạm vi hoạt động và danh mục kỹ thuật;
- khu vực tiệt khuẩn hoặc hợp đồng tiệt khuẩn khi sử dụng lại dụng cụ;
- hộp cấp cứu phản vệ và thuốc cấp cứu phù hợp.

Đối với **phòng khám bác sĩ y khoa**, phòng khám bệnh phải có diện tích tối thiểu 10 m². Nếu thực hiện kỹ thuật hoặc thủ thuật thì phải có thêm phòng phù hợp, thông thường tối thiểu 10 m²; kỹ thuật vận động trị liệu có yêu cầu diện tích riêng.

### 3.2. Người hành nghề

QLPM phải có khả năng đối chiếu các thông tin sau trước khi cho phép thực hiện nghiệp vụ chuyên môn:

- số và tình trạng giấy phép hành nghề;
- phạm vi hành nghề;
- CSKCB và địa điểm đã đăng ký;
- chức danh, vị trí chuyên môn;
- thời gian hành nghề tại từng cơ sở;
- tình trạng người chịu trách nhiệm chuyên môn và văn bản ủy quyền khi vắng mặt.

Một người có thể đăng ký tại nhiều cơ sở nhưng thời gian hành nghề không được trùng nhau. Người chịu trách nhiệm chuyên môn kỹ thuật phải làm toàn thời gian tại cơ sở, có phạm vi phù hợp và đáp ứng thời gian hành nghề theo quy định. Khi cơ sở không còn người hành nghề phù hợp, dịch vụ tương ứng phải tạm dừng cho đến khi có người thay thế hợp lệ.

### 3.3. Phạm vi chuyên môn và danh mục kỹ thuật

Một chỉ định hoặc dịch vụ chỉ hợp lệ khi đồng thời thỏa mãn:

1. bác sĩ/người hành nghề có phạm vi hành nghề phù hợp;
2. CSKCB được phép hoạt động trong phạm vi tương ứng;
3. kỹ thuật thuộc danh mục được cơ quan có thẩm quyền cho phép tại CSKCB;
4. cơ sở có đủ nhân lực, thiết bị và điều kiện thực hiện;
5. chỉ định phù hợp tình trạng người bệnh và quy định chuyên môn kỹ thuật.

Không có một bảng pháp lý duy nhất quy định mọi cặp `chẩn đoán -> dịch vụ`. Ngoài các điều kiện pháp lý trên, cơ sở phải áp dụng hướng dẫn chẩn đoán, điều trị và quy trình chuyên môn tương ứng.

## 4. Hồ sơ khám bệnh và thời hạn lưu trữ

Điều 69 Luật Khám bệnh, chữa bệnh yêu cầu người bệnh điều trị nội trú, điều trị ban ngày và điều trị ngoại trú phải được lập, cập nhật hồ sơ bệnh án. Hồ sơ giấy và hồ sơ điện tử có giá trị pháp lý như nhau khi đáp ứng quy định.

Hồ sơ một lượt khám cần liên kết được tối thiểu:

- người bệnh và thông tin định danh;
- CSKCB, khoa/phòng và lần khám;
- người tiếp nhận, người khám, người chỉ định, người thực hiện và người ký;
- lý do khám, bệnh sử, khám lâm sàng, sinh hiệu;
- chẩn đoán;
- chỉ định, kết quả cận lâm sàng và tài liệu đính kèm;
- thuốc, cách dùng và hướng dẫn điều trị;
- thời điểm tạo, cập nhật, ký, hủy hoặc điều chỉnh;
- kết quả và hướng xử trí của lần khám.

Theo Thông tư 33/2025/TT-BYT, hồ sơ bệnh án nội trú và ngoại trú thông thường phải lưu **10 năm**. Vì vậy, dữ liệu đã hoàn tất hoặc đã ký không được thiết kế theo kiểu cập nhật đè làm mất nội dung cũ. QLPM nên lưu phiên bản, người thay đổi, thời điểm, lý do và quan hệ giữa bản bị hủy với bản thay thế.

### Lộ trình hồ sơ bệnh án điện tử

Theo Thông tư 13/2025/TT-BYT:

- bệnh viện phải hoàn thành triển khai trước 30/09/2025;
- các cơ sở khám bệnh, chữa bệnh khác "có người bệnh điều trị nội trú, điều trị ban ngày và điều trị ngoại trú" phải hoàn thành chậm nhất **31/12/2026** (giữ nguyên cách diễn đạt tại điểm b khoản 1 Điều 4 của Thông tư).

QLPM cần bảo đảm hồ sơ điện tử có thể hiển thị, ký/xác nhận điện tử, lưu trữ, tra cứu và kết xuất theo mẫu được áp dụng tại cơ sở.

## 5. Kê đơn ngoại trú

Theo Luật Khám bệnh, chữa bệnh và Thông tư 26/2025/TT-BYT:

- người kê đơn phải có quyền và phạm vi hành nghề phù hợp;
- thuốc phải phù hợp chẩn đoán, tình trạng bệnh, hướng dẫn điều trị hoặc tài liệu chuyên môn được phép áp dụng;
- không kê thực phẩm chức năng trong đơn thuốc;
- phải ghi rõ tên thuốc, nồng độ/hàm lượng, số lượng, liều mỗi lần, số lần dùng, đường dùng, thời điểm dùng và số ngày dùng;
- trẻ dưới 72 tháng phải ghi tuổi theo tháng, cân nặng và thông tin người đưa trẻ đi khám;
- thời gian dùng thuốc thông thường không quá 30 ngày; một số bệnh mạn tính thuộc danh mục có thể kê tối đa 90 ngày;
- đơn thuốc có giá trị mua hoặc lĩnh thuốc tối đa 5 ngày kể từ ngày kê;
- thuốc gây nghiện, hướng thần và tiền chất dùng mẫu, số liên và quy trình riêng;
- một lần khám nhiều chuyên khoa tại cùng cơ sở lập một đơn thuốc có thể gồm chỉ định thuốc của nhiều chuyên khoa;
- cơ sở phải gửi đơn thuốc điện tử lên Hệ thống đơn thuốc quốc gia theo quy định.

Lộ trình kê đơn điện tử đã kết thúc: bệnh viện trước 01/10/2025 và các cơ sở khám bệnh, chữa bệnh khác trước 01/01/2026.

## 6. Chỉ định dịch vụ kỹ thuật

Điều 62 Luật Khám bệnh, chữa bệnh yêu cầu việc khám, chỉ định phương pháp chữa bệnh và kê đơn phải tuân thủ quy định chuyên môn kỹ thuật; người hành nghề phải chỉ định kịp thời, chính xác và chịu trách nhiệm về quyết định của mình.

QLPM phải chặn hoặc kiểm soát các trường hợp:

- người dùng không có giấy phép hoặc phạm vi hành nghề phù hợp;
- dịch vụ ngoài phạm vi hoạt động hoặc danh mục kỹ thuật của CSKCB;
- hồ sơ không xác định được người chỉ định, thời điểm, chẩn đoán hoặc lượt khám;
- thủ thuật xâm lấn chưa có xác nhận đồng ý khi pháp luật yêu cầu;
- chỉ định đã có kết quả nhưng bị xóa vật lý;
- chỉ định đã ký bị sửa mà không có lịch sử và lý do.

Các cảnh báo như chỉ định trùng, chỉ định giá trị cao, không thường phù hợp với chẩn đoán hoặc điều kiện thanh toán BHYT nên là hỗ trợ quyết định lâm sàng. Không nên tự động thay thế quyết định chuyên môn của bác sĩ nếu chưa có quy tắc pháp lý/chuyên môn được phê duyệt làm căn cứ.

## 7. Giá, quảng cáo và thông tin công khai

Phòng khám tư nhân được quyết định giá dịch vụ nhưng phải kê khai và niêm yết công khai. Hệ thống cần lưu được:

- bảng giá và thời gian hiệu lực;
- giá áp dụng tại thời điểm cung cấp dịch vụ;
- loại giá/dịch vụ;
- giảm trừ, miễn giảm và người phê duyệt nếu có;
- chứng từ thanh toán liên quan.

Quảng cáo dịch vụ khám bệnh, chữa bệnh phải phù hợp giấy phép hoạt động, phạm vi chuyên môn và nội dung được phép. Không được quảng cáo dịch vụ hoặc kỹ thuật ngoài phạm vi đã được cấp phép.

## 8. Dữ liệu cá nhân và bảo mật

Dữ liệu sức khỏe là dữ liệu cá nhân nhạy cảm. QLPM phải hỗ trợ ít nhất:

- phân quyền theo CSKCB, vai trò và nhiệm vụ;
- xác thực người dùng và thu hồi quyền kịp thời;
- nhật ký xem, tạo, sửa, ký, in, tải và chia sẻ hồ sơ;
- mã hóa hoặc biện pháp bảo vệ phù hợp khi lưu trữ và truyền dữ liệu;
- sao lưu, phục hồi và kiểm tra khả năng phục hồi;
- quản lý căn cứ/sự đồng ý khi chia sẻ cho bên thứ ba;
- giới hạn dữ liệu hiển thị và xuất ra đúng mục đích;
- cô lập dữ liệu giữa các CSKCB;
- quy trình xử lý yêu cầu của chủ thể dữ liệu và sự cố dữ liệu.

Không được dùng dữ liệu khám bệnh thật cho kiểm thử hoặc chia sẻ ra ngoài phạm vi được phép nếu chưa có căn cứ hợp lệ và biện pháp bảo vệ tương ứng.

## 9. Chuẩn bị kết nối hệ thống quốc gia

Thông tư 38/2024/TT-BYT có hiệu lực từ 01/01/2027. QLPM cần chuẩn bị dữ liệu có cấu trúc để cung cấp đầy đủ, chính xác và kịp thời thông tin quản lý hoạt động khám bệnh, chữa bệnh.

Các nhóm dữ liệu cần sẵn sàng gồm:

- thông tin CSKCB, giấy phép và thời gian hoạt động;
- danh sách người hành nghề và lịch hành nghề;
- người bệnh và thông tin định danh;
- lượt khám/đợt điều trị;
- chẩn đoán ICD;
- chỉ định, kết quả dịch vụ kỹ thuật;
- thuốc và đơn thuốc;
- chi phí, giá dịch vụ và thông tin BHYT nếu có;
- báo cáo hoạt động chuyên môn.

Không nên dùng file JSON danh mục nội bộ làm nguồn pháp lý duy nhất. Danh mục cần có mã chuẩn, phiên bản, nguồn, ngày hiệu lực và khả năng đối chiếu với dữ liệu đã phát sinh.

## 10. Ánh xạ vào contract QLPM

Các khóa `IDVaoVien`, `IDCSKCB` và ID của từng chứng từ là thiết kế nội bộ; pháp luật không quy định tên khóa cơ sở dữ liệu. Contract hiện hành của QLPM áp dụng như sau:

- `IDVaoVien` định danh một lượt khám;
- `IDCSKCB` xác định tenant/cơ sở chịu trách nhiệm hồ sơ;
- đơn thuốc, phiếu chỉ định, kết quả và tài liệu có ID riêng;
- mọi bảng nghiệp vụ phải truy ngược được lượt khám và CSKCB;
- ID từ client không phải căn cứ phân quyền; server lấy CSKCB làm việc từ claims/session;
- dữ liệu đã ký phải có lịch sử thay đổi, không chỉ xác định insert/update bằng việc bản ghi có tồn tại;
- thao tác hủy/điều chỉnh phải lưu người thực hiện, thời điểm và lý do;
- dữ liệu cần giữ đủ thời hạn pháp luật kể cả khi tài khoản hoặc danh mục đã ngừng sử dụng.

## 11. Checklist trước khi triển khai tại một CSKCB

- [ ] Xác định đúng loại hình trên giấy phép hoạt động.
- [ ] Nhập số, ngày cấp, cơ quan cấp và phạm vi hoạt động.
- [ ] Nhập danh mục kỹ thuật được phép của cơ sở.
- [ ] Kiểm tra giấy phép và lịch đăng ký của từng người hành nghề.
- [ ] Cấu hình người chịu trách nhiệm chuyên môn và cơ chế ủy quyền.
- [ ] Cấu hình bảng giá và ngày hiệu lực.
- [ ] Cấu hình mẫu hồ sơ bệnh án áp dụng.
- [ ] Cấu hình loại đơn thuốc và nghiệp vụ thuốc kiểm soát đặc biệt nếu có.
- [ ] Kết nối hoặc chuẩn bị kết nối Hệ thống đơn thuốc quốc gia.
- [ ] Kiểm tra chữ ký/xác nhận điện tử và khả năng in, kết xuất hồ sơ.
- [ ] Kiểm tra phân quyền, audit log, sao lưu và phục hồi.
- [ ] Kiểm tra chính sách lưu hồ sơ tối thiểu 10 năm.
- [ ] Chuẩn bị dữ liệu/API cho Thông tư 38/2024/TT-BYT từ 01/01/2027.
- [ ] Rà soát quy định chuyên khoa, BHYT, xét nghiệm, chẩn đoán hình ảnh, bức xạ hoặc y học cổ truyền nếu cơ sở có thực hiện.

## 12. Nguyên tắc cập nhật tài liệu

Trước khi dùng tài liệu này làm căn cứ triển khai phải kiểm tra lại trạng thái văn bản tại Cơ sở dữ liệu quốc gia về văn bản pháp luật. Khi văn bản bị sửa đổi, thay thế hoặc hết hiệu lực:

1. cập nhật bảng văn bản và ngày rà soát;
2. xác định rule QLPM bị ảnh hưởng;
3. cập nhật code, STO/constraint/trigger và kiểm thử tương ứng;
4. ghi rõ phần nào là yêu cầu pháp luật, phần nào là quyết định thiết kế của QLPM.
