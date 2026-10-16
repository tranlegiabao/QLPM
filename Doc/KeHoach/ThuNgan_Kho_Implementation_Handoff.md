# Bàn giao triển khai Thu ngân / Kho theo HIS

## Quyết định đã duyệt

- Bổ sung 07-10-2026: thu CLS nội bộ khi bệnh nhân Đang khám; bác sĩ tiếp tục lưu hồ sơ sau thu. Thuốc/công khám vẫn chờ Khám xong; không tự đổi trạng thái khám để thu. Chính sách chặn thực hiện/upload khi chưa thu chưa được duyệt, giữ nguyên.
- Bổ sung 07-10-2026: admin toàn cục đã chọn cơ sở được phát thuốc khi không có hồ sơ nhân viên; phải audit tài khoản thực hiện, không gán nhân viên giả.

- Chỉ thu chỉ định, thuốc dịch vụ; một kho. Không BHYT/KSK/vật tư/toa lẻ/vaccine/tạm ứng/đa kho. Hóa đơn điện tử P2.
- Chứng từ đã ghi nhận bất biến, legacy chỉ đọc.
- Quyết định mới 07-10, bàn giao 08-10-2026: **Hủy chứng từ thu tự đảo cấp thuốc/tồn theo luồng Hủy chứng từ HIS**, không đợi Kho xác nhận hoàn. Chỉ đảo lượng còn đang giao của đúng chứng từ, đúng lô/lượng cơ sở đã lưu. Đây là đảo sổ kho, không phải xác nhận nhận lại thuốc vật lý; cơ sở phải kiểm tra thu hồi thuốc. Quyết định này thay thế điều kiện hoàn kho trước cho **hủy**, không thay đổi **hoàn tiền**: hoàn tiền vẫn cần Kho nhận lại trước. Không tự chuyển tiền hoàn qua ngân hàng.
- Chuyển bố cục PDF và worksheet Excel HIS chuẩn, dùng thông tin cơ sở QLPM; không sao chép thương hiệu/cấu hình bệnh viện riêng.
- Chưa có quyền chạy migration trên DB: cần xác nhận server, DB_NAME(), backup/rollback trước.

## Baseline ngày 07-10-2026

- Nhánh QLPM Hieu_05/10; worktree sạch khi bắt đầu. Không sửa source HIS.
- v94 đã có chứng từ thu tách nhóm, cấp/hoàn một phần, nhập/NCC, điều chỉnh/hủy thuốc. Backlog cũ chưa phản ánh đầy đủ code điều chỉnh.
- Chưa có kiểm chứng DB live, route sau đăng nhập hoặc render PDF/Excel cho thay đổi lần này.

## Thứ tự tiếp tục

1. Chặn API legacy ghi dữ liệu; sửa hoàn kho payload sai thành hoàn tất cả; hủy nhập sau phát sinh; khóa giao dịch cùng lượt.
2. Thu thuốc theo lượng; snapshot quy đổi; liên kết dòng cấp với dòng chứng từ thu; hoàn tiền một phần và UI riêng.
3. Lịch sử/chi tiết chứng từ kho, khóa/mở lô; báo cáo dùng chung dữ liệu UI/PDF/XLSX.
4. Port mẫu HIS: PDFPhieuThuA4, PDFPhieuThuGopA4 (A5), PDFPhieuThuInNhiet, PDFPhieuChiA4; PhieuNhapKhoPDF, PDFPhieuCapPhat, TheKhoPDF và báo cáo kho.
5. Migration v95 nối tiếp (không sửa v94), verifier và kiểm thử DB/đồng thời; so hình PDF và workbook.

## Trạng thái của lần triển khai

### Hủy chứng từ tự đảo cấp thuốc — source v98, bàn giao 08-10-2026

Đã sửa source, **chưa chạy migration/chưa nghiệm thu DB hoặc route sau đăng nhập**. Không đổi source HIS, không thêm project test vào repo theo yêu cầu người dùng. Các phần v95/v96/v97 bên dưới là lịch sử triển khai; điều kiện hủy thuốc cũ trong baseline không còn là chính sách hiện hành.

#### Đã làm

- Tham chiếu đúng luồng `QL_HuyChungTu` → `QlHuyChungTuServices.huyChungTuHangHoa` → `HhCapPhatThuocPKServices.huyCapPhatThuocTheoTaiChinh`: đảo xuất trước hủy tiền. Không nhầm với API thu ngân cũ `huyQLTaiChinhToaThuocDV`, vốn chặn nếu đã cấp. QLPM vẫn hủy **một ID chứng từ**, không tự hủy cả nhóm gộp; giữ lịch sử bất biến thay vì xóa dòng cấp/dòng tiền như HIS.
- `38_huy_thu_dao_cap_v98.sql` nối tiếp v97, không sửa hợp đồng v94/v95. `QL_Kho_Hoan` thêm `Loai` (`NHAN_TRA` / `DAO_CAP_HUY_THU`), `IDChungTuHuy`, `IDTaiKhoanHoan`; nhân viên nullable cho global admin. FK, CHECK và unique filtered theo tenant/chứng từ bảo vệ audit và chống đảo trùng. Dữ liệu hoàn cũ mặc định `NHAN_TRA`; không backfill liên kết cấp/thu legacy.
- Helper `STO_QL_ThuNgan_DaoCapChungTu` yêu cầu transaction ngoài; caller `HuyChungTu` khóa lượt → master tiền → chứng từ → dòng cấp → lô ID tăng dần. Đọc liên kết `IDThuTienChungTuCT` chính xác, trả `SoLuongCoSo - SoLuongDaHoan` về lô gốc, ghi chi tiết đảo tham chiếu dòng cấp. Không lấy quy đổi danh mục hiện tại. Header cấp có dòng của phiếu khác còn giao vẫn active; chỉ đánh dấu hết hiệu lực khi tất cả dòng đã hoàn/đảo hết.
- Hủy thu, cập nhật tồn và ghi audit nằm trong **một transaction**; lỗi thì rollback cả luồng. Reject phiếu đã hủy, đã có HOAN, tổng tiền master sai hoặc liên kết cấp sai/mơ hồ. Legacy thiếu liên kết còn giao phải đối chiếu, không đoán theo dòng toa. Phiếu thu gốc giữ nguyên lượng/giá/tiền, chỉ thay trạng thái và audit hủy. Không tạo chứng từ `HOAN` hay lệnh chuyển tiền ngân hàng.
- Actor lấy từ API/claims; quyền `thu_ngan:Xoa` hiện có cho phép luồng hủy tích hợp (không yêu cầu thêm `kho:Xoa`). STO xác thực tài khoản active thuộc tenant hoặc global admin; nhân viên tenant phải khớp tài khoản và active tại cơ sở. Global admin có working-CSKCB lưu tài khoản, nhân viên NULL, không giả nhân viên.
- Truy vấn `DanhSachChungTu` giữ ba result sets, thêm ID/số/ngày phiếu đảo kho. UI cảnh báo việc tự đảo sổ/không tự chuyển tiền; hàng Đã hủy hiển thị số phiếu đảo, escape dữ liệu. Kiểm tra lại `busy` sau modal để tránh gửi trùng khi mở hai xác nhận.
- `CapNhatTong` v97 tiếp tục tính trạng thái theo eligibility CLS; hủy không ghi đè `DaThu` bằng cờ toàn lượt v94. `HoanTien` v95, API legacy 410 và các mẫu PDF/Excel hiện có **không đổi** trong đợt này.
- Updater `00` và rebuild `20` chạy38 cuối; verifier05 kiểm tra hợp đồng98, chốt06 thêm98 và giữ timestamp94–97. `39_verify_huy_thu_v98_readonly.sql` xác nhận server/database, đối chiếu liên kết/audit/lượng hoàn–đảo và xuất manifest theo lô/chứng từ; không tự sửa dữ liệu.

#### Bằng chứng test cục bộ

- Build app ra `.codex-build/his-v95/cancel-v98-app`: **0 lỗi, 7 warnings** (.NET7 EOL và nullable ở module khác). Không dừng app người dùng; build chưa phải deploy.
- ScriptDom `TSql160Parser` parse SQL38/39/05/06 (loại directive SQLCMD trước parse), cộng guards nguồn: **PASS26**. Kiểm tra transaction, nguồn đúng chứng từ, lượng/lô gốc, legacy reject, header dùng chung, chống trùng, actor, master, v97 eligibility, hoàn tiền không đổi, thứ tự updater/version và escape UI. Không chứng minh bind schema hay chạy STO.
- Chạy hàm `handleDocumentAction` thật lấy từ `thungan.js` trong VM cô lập: **PASS20** (đồng ý/từ chối modal, thông điệp, payload ID, lỗi server, không có modal, hai xác nhận chỉ một request, reload và mở khóa nút, print không gọi hủy). `node --check thungan.js` đạt. Đây không phải browser hay middleware/authentication test.
- Test tạm ở `.codex-build/his-v95/cancel-v98-tests` (gitignore), không commit project test. Người dùng đã xác nhận đang dọn project test. Không dùng số PASS329/61 từ các lần trước làm bằng chứng cho v98.
- Trong phiên có commit/merge đồng thời và xung đột Kho; người dùng đã xử lý merge. Không sửa/resolve hộ `Views/kho/Index.cshtml` hay các thay đổi UI Kho đó. Baseline sau merge `c6fadda`; các file v98 đã được người dùng commit một phần, kiểm tra trạng thái trước khi tiếp tục.

Lệnh chạy lại nếu thư mục tạm vẫn còn:

```powershell
dotnet run --project .codex-build/his-v95/cancel-v98-tests -- D:\project\QLPM
node .codex-build/his-v95/cancel-v98-tests/cancel-ui.test.cjs D:\project\QLPM
node --check QuanLyPhongMach/wwwroot/js/thu_ngan/thungan.js
dotnet build QuanLyPhongMach/QuanLyPhongMach.csproj -o .codex-build/his-v95/cancel-v98-app --no-restore
```

#### Tiếp tục: cutover, rollback và nghiệm thu

1. Xác nhận exact server + `DB_NAME()` + app revision; chưa có quyền chạy migration trong phiên này. Read-only inventory schema/definition thật, kiểm tra legacy thiếu liên kết và constraint hoàn cũ. Không coi source98 là DB98. v98 là common; đồng bộ nhánh qua quy trình tích hợp, không checkout/ghi đè nhánh khác.
2. Khóa ghi Thu ngân/Kho trong cửa sổ được duyệt, backup DB đã kiểm tra restore; export định nghĩa `HuyChungTu`, `DanhSachChungTu` và helper nếu đã có. Lưu manifest toàn bộ receipt snapshots, master tiền, phiếu/dòng cấp, hoàn và từng lô trước/sau. Không cộng số lượng khác thuốc/ĐVT thành một tồn tổng để nghiệm thu.
3. Chạy updater00 trong cùng SQLCMD session, verifier05 đạt mới chốt98. Chạy39 đã điền đúng target, so manifest **migration không đổi tiền/tồn**, chạy updater hai lần kiểm tra idempotent. Không chạy06 riêng. Deploy assets cùng schema; UI cảnh báo mới không được đi với STO hủy cũ.
4. Trước mở ghi: rollback bằng backup/định nghĩa và app revision đã duyệt; không tự drop cột/đổi nhân viên về NOT NULL. Sau phát sinh `DAO_CAP_HUY_THU`, không quay về v95 hoặc xóa bút toán: giữ/export phát sinh và duyệt forward-fix/restore có đối chiếu (global admin reversal có nhân viên NULL). Thực hiện thử rollback trên DB test đã được duyệt, không DB production.
5. Nghiệm thu các ca trong [checklist v98](../Test/README.md#hủy-thu-tự-đảo-cấp-v98). Cần kết quả chạy STO/schema thật, hai session đồng thời và route sau đăng nhập. Cấp/hoàn cũ có nhiều cách khóa lô; thứ tự tăng dần của helper mới **chưa chứng minh toàn hệ thống không deadlock giữa các lượt**. Báo cáo kho tương lai phải ghi cả xuất gốc và đảo ở ngày phát sinh, không loại phiếu `DaHuy=1` rồi vẫn cộng hoàn (sai tồn đầu/cuối).

### Chuẩn hóa vị trí DTO / model

Đã tách public request khỏi controller và model Excel khỏi service, chuẩn hóa file/namespace theo Models/Requests, Printing, Reports, Imports và ViewModels. Không đổi JSON/route/quyền/nghiệp vụ hoặc DB; snapshot67 model/11 controller khớp, harness PASS329 assertions. Chi tiết và quy tắc tiếp tục: [Dto_CodeStructure_Refactor_Handoff.md](Dto_CodeStructure_Refactor_Handoff.md).

### Thu CLS nội bộ khi Đang khám — source v97

Phần này đã sửa source và kiểm tra cục bộ; **chưa triển khai DB/chưa nghiệm thu runtime**. Baseline đầu lượt sửa này worktree sạch; v96 đã có sẵn. Không sửa code HIS, không chạy migration và không kết nối DB.

- `36_thu_cls_dang_kham_v97.sql` override nối tiếp 28/02/v95/v96, không sửa các hợp đồng đã có. `FN_QL_ThuTien_DongCoTheThu` là nguồn điều kiện chung cho queue, chi tiết, thu và tính lại trạng thái: trạng thái 1 chỉ CLS active nội bộ; trạng thái 2 thêm thuốc/công khám active. Gửi ngoài không được chọn thu. Danh sách có badge Đang khám.
- `STO_QL_ThuNgan_ThuTien` giữ hai nhóm chứng từ và snapshot, không dùng cờ DaThu tổng hợp cũ để chặn lần thu mới; kiểm tra từng dòng, tenant, nguồn active và trạng thái khám trong transaction khóa lượt trước. Thu sớm không sửa trạng thái khám.
- `STO_QL_Kham_Luu` bỏ chặn toàn lượt khi có thu. Giữ ID dòng CLS/toa và dòng tiền; khóa source đã thu hoặc có bất kỳ lịch sử chứng từ (kể cả đã hủy/hoàn); không cho xóa/đổi lượng/nơi thực hiện CLS hoặc đổi thuốc/lượng/ĐVT nguồn toa đó. Nguồn thương mại được giữ nguyên, không lấy giá danh mục mới cho dòng khóa. Chẩn đoán, dặn dò, sinh hiệu và nguồn mới/chưa có chứng từ vẫn lưu được.
- `STO_QL_ThuTien_DongBoNguon` chỉ diff nguồn chưa có lịch sử; insert nếu thiếu, update chưa thu chưa có chứng từ, delete nguồn inactive/gửi ngoài chỉ khi chưa thu và chưa từng có chứng từ. Không delete/recreate toàn bộ `QL_ThuTien_CT`. Yêu cầu transaction, tự khóa lượt trước master để không bỏ qua thứ tự khóa. `CapNhatTong` không tính lại dòng đã có chứng từ và tính trạng thái theo nguồn đang đủ điều kiện.
- `STO_QL_Kham_HoanTat` tính lại trạng thái thu sau khi khám xong; không chặn vì đã thu CLS. `ChonBenhNhan` trả BIT DaThu và KhoaNghiepVu riêng; UI khóa lịch sử cả sau hủy/hoàn, hiển thị giá đã lưu và tải lại ID/giá/cờ sau lưu thành công.
- `POST /api/cls/chi_dinh/dam_bao` chuyển từ EF insert chỉ định riêng lẻ sang `STO_QL_Cls_DamBaoChiDinh`: khóa lượt, kiểm tra bác sĩ/tenant/dịch vụ, tạo chỉ định và nguồn tiền cùng transaction. Reject lượng âm/0/quá giới hạn/quá 2 số thập phân, không tự đổi thành 1. Giữ payload/result `id_chi_dinh_ct`; global admin không giả bác sĩ. Chưa lưu hồ sơ đầy đủ thì không gán NgayLuuKhamLanDau. Không thêm policy chặn upload PDF theo thanh toán.
- UI thu ngân chọn dòng theo cờ server `co_the_thu`, fail closed khi schema cũ không có cờ; thuốc/công khám chờ khám xong, gửi ngoài disabled. In theo ID chứng từ tiếp tục dùng snapshot/mẫu đã port, không đổi bố cục ở đợt này.
- Updater/rebuild chạy v97 cuối cùng; verifier/chốt version lên97, giữ94/95/96. `37_verify_thu_cls_v97_readonly.sql` yêu cầu đúng server/database và liệt kê missing/duplicate nguồn để đối chiếu; không backfill/repair migration hàng loạt.

#### Bằng chứng kiểm tra 07-10-2026

- Node test dùng hàm eligibility thật từ thungan.js: trước sửa fail `true !== false` khi dòng chưa đủ thu vẫn chọn được; sau sửa PASS32 assertions (eligibility + khóa lịch sử khám).
- `dotnet run --project tests/ThuNganKho.Contracts -p:BaseOutputPath=D:\project\QLPM\.codex-build\his-v95\tests-bin\ -- D:\project\QLPM`: PASS61 assertions; build ứng dụng qua ProjectReference, parse SQL36/37, checks guards, recording controller→STO helper/claims, input CLS sai, regression v95/v96 và Razor/xlsx fixture. Không start app/port/worker, không SQL thật.
- Node syntax thungan.js/khambenh.js PASS; git diff --check không lỗi whitespace. Warnings .NET7 EOL/nullable cũ không phát sinh từ thay đổi này.
- Chưa chứng minh binding schema, giao dịch/đồng thời, middleware quyền, route sau đăng nhập, PDF thực tế hoặc dữ liệu DB. Không đánh dấu runtime hoàn tất.

#### Bước tiếp theo bắt buộc: cutover và nghiệm thu v97

1. Người dùng xác nhận server + database; read-only kiểm tra `SERVERPROPERTY('ServerName')`, `DB_NAME()`, version thực tế và định nghĩa các module. Tách Hieu/Server118/main; không checkout nhánh khác hoặc áp script local Hieu.
2. Dừng ghi theo cửa sổ bảo trì đã duyệt, backup DB và export định nghĩa 9 STO bị override + function nếu đã tồn tại. Lưu manifest tiền/chứng từ/tồn trước (33/32 và37 sau khi function có). Kiểm tra nguồn thiếu/trùng, legacy không tự nối. Source v97 không có backfill tự động: lượt cũ chỉ đồng bộ chính xác khi lưu/ensure sau triển khai, nếu cần bulk reconciliation phải duyệt danh sách riêng.
3. Chạy updater trong cùng SQLCMD session và chốt97 sau verifier; deploy app/assets cùng lúc. Không chạy app mới với STO cũ: cờ eligibility sẽ fail closed và API lưu nhanh yêu cầu STO mới.
4. Rollback trước khi mở ghi: restore 9 STO từ manifest và function cũ (hoặc drop function mới sau khi phục hồi tất cả module phụ thuộc), deploy app cũ, xử lý version97 bằng quy trình rollback đã duyệt. Sau khi mở ghi/phát sinh thu CLS sớm, không đơn giản restore app/STO cũ (nó lại chặn bác sĩ vì có thu); giữ v97 hoặc duyệt forward-fix/khôi phục DB có đối chiếu nghiệp vụ. Không xóa chứng từ/tồn để rollback.
5. Trên DB/test cơ sở đã duyệt, tạo lượt đang khám có công khám, CLS nội bộ A/B, gửi ngoài C và toa. Lưu, ghi IDs nguồn/dòng tiền; queue có lượt này, chỉ A/B selectable; forged request thuốc/công khám/C bị từ chối mà không đổi tiền/trạng thái.
6. Thu A: chỉ 1 phiếu nhóm CHI_DINH có snapshot A, TrangThaiKham vẫn1; thu lại A bị từ chối. Lưu thêm chẩn đoán/dặn dò/thuốc/B vẫn thành công; ID dòng tiền A, snapshot/tiền phiếu A không đổi. Xóa/đổi lượng/GuiNgoai A bị từ chối và rollback cả lần lưu.
7. Thêm CLS D sau khi đã thu đủ CLS: queue quay lại Chưa thu; thu D tạo phiếu mới, không bị master DaThu cũ chặn. Thay giá/tên danh mục sau thu: giá source khóa và phiếu in theo ID cũ giữ nguyên. Dịch vụ/thuốc/ĐVT đã khóa bị inactive trong danh mục không chặn lưu phần hồ sơ còn lại.
8. Nhận PDF A, tiếp tục lưu và hoàn tất khám (cả path Luu KhamXong và HoanTat nhanh): không mất file/ID. Sau state2, thuốc/công khám được chọn, không thu lại A/D; thu còn lại vẫn tách nhóm. Nguồn có kết quả chưa thu không được xóa.
9. Lưu nhanh CLS bằng dam_bao trước upload: một source+financial row, gọi lặp không nhân đôi; nếu visit ban đầu0 chỉ chuyển1, không gán NgayLuuKhamLanDau/Khám xong. Hai cửa sổ đồng thời save/collect/ensure: một lần thu nguồn, không duplicate/source-id loss hoặc tiền lặp; request nguồn bị xóa trước đó bị từ chối.
10. Hủy/hoàn chứng từ A theo chính sách hiện có rồi lưu tiếp: lịch sử bất biến, source vẫn khóa; không giả DaThu=true trên UI chỉ vì có lịch sử. Legacy paid chưa có snapshot vẫn khóa, không dựng chứng từ giả. Kiểm tra tenant/ownership/quyền: bác sĩ khác, tenant khác, thiếu working-CSKCB bị từ chối.
11. So IDs, SUM chứng từ thu/hủy/hoàn, tiền mặt/chuyển khoản và tồn trước/sau; thu CLS không thay tồn. In ID A chỉ A; in gộp là lựa chọn khác. Kiểm tra route/PDF tiếng Việt sau login, không dùng fixture làm bằng chứng runtime.

### Bổ sung sửa lỗi admin phát thuốc — source v96

- Lỗi đã tái hiện: `POST /kho/api/xuat-thuoc` trả 409 vì global admin có `IDNhanVien=0`, dù helper quyền đã cho `kho:Sua` khi có working-CSKCB. Test trước sửa fail đúng assertion này.
- `kho_controller.XuatThuoc`: yêu cầu working-CSKCB với admin và tài khoản audit cho mọi người; chỉ tài khoản tenant phải có nhân viên. Lấy tenant/actor từ claims, không nhận ID người thực hiện từ payload; admin gửi nhân viên NULL kể cả claim nhân viên cũ còn tồn tại. Từ chối danh sách null/dòng không hợp lệ.
- `34_kho_nguoi_xuat_v96.sql`: override STO cấp v95; thêm FK `QL_Kho_Xuat.IDTaiKhoanXuat`, `TenNguoiXuatSnapshot` và constraint cặp audit. SQL xác thực tài khoản active, cờ global admin trong DB, tenant của tài khoản, nhân viên khớp tài khoản và quan hệ nhân viên–cơ sở active. Snapshot tên lấy từ DB; global admin dùng tên đăng nhập, nhân viên dùng họ tên. Không suy diễn tài khoản chứng từ cũ; giữ NULL legacy. `DongDaCap` trả thêm tài khoản/nhân viên/tên snapshot để tra cứu.
- Migration nối sau auth + v95 trong updater và cuối rebuild; verifier/chốt version nâng v96, giữ nguyên bản ghi v94/v95. Chưa chạy bất cứ SQL trên DB thật, chưa xác minh schema hiện tại của server.
- Harness cuối **PASS 38 assertions**: 23 kiểm tra cũ + parser v96/verifier + guard admin/tenant + đường gọi controller→helper STO qua `RecordingDbConnection` không network. Kiểm tra admin gửi đúng tenant/account và nhân viên DBNull, tenant vẫn gửi cả nhân viên/account. Build pass; đây không phải chứng minh STO bind schema, audit được ghi thực tế hoặc phát thuốc trên route authenticated.
- Phạm vi: chỉ phát thuốc. Admin chưa có nhân viên vẫn bị chặn ở nhập/hoàn/điều chỉnh kho; không lặng lẽ nới các thao tác đó trong lần sửa này. PDF/Excel không đổi.
- Triển khai: xác nhận exact server/DB_NAME() → backup/restore được kiểm tra + manifest tiền/tồn → updater duy nhất → verifier `35_verify_kho_actor_v96_readonly.sql` + đối chiếu manifest → deploy app cùng schema. Cần test thực tế admin không nhân viên cấp toa đã thu, account audit đúng, đổi tên tài khoản không đổi snapshot, tenant thiếu nhân viên/sai cơ sở bị từ chối, tiền/tồn giảm đúng một lần. Không chỉ deploy C# lên STO v95.
- Rollback trước mở ghi: restore backup cùng app revision cũ. Sau có phiếu mới: khóa ghi và giữ/export audit mới để forward-fix; không drop cột hay restore mất phiếu đã cấp. Chưa đồng bộ core sang nhánh khác; không checkout/ghi đè nhánh khác tự động, cần đưa cùng patch non-DSS khi tích hợp.

Đợt 1 đã sửa code và kiểm tra bằng fixture; **toàn bộ kế hoạch CHƯA hoàn thành**. Chưa migrate bất kỳ DB nào. Tiếp tục trên worktree hiện tại, không reset/checkout bỏ các thay đổi.

### Đã sửa trong đợt 1

| Hạng mục | Bằng chứng code | Giới hạn xác minh |
|---|---|---|
| API legacy hủy nhóm/toàn bộ trả 410, không gọi SQL ghi | `thu_ngan_controller.cs`; override STO trong `31_thu_ngan_kho_v95.sql` | Controller fixture; chưa route authenticated |
| Hoàn kho theo đúng dòng cấp, lượng cơ sở; toàn bộ chọn riêng | `kho_controller.cs`, `kho.js`, view Kho; STO `DongDaCap` và `Xuat_Hoan` v95 | Từ chối rỗng/âm/trùng/danh sách kèm toàn bộ ở API; SQL parse, chưa transaction DB |
| Hủy nhập chặn mọi lịch sử xuất hoặc điều chỉnh, kể cả cấp rồi hoàn đủ / tăng rồi giảm về đúng tồn | STO `Nhap_Huy` v95; khóa lô trước kiểm tra lịch sử | Chưa test DB/đồng thời |
| Cấp có FK nguồn thu và snapshot quy đổi | `QL_Kho_Xuat_CT.IDThuTienChungTuCT`, `HeSoQuyDoi`; STO cấp v95 | Chỉ cấp khi đúng một chứng từ thu đang có hiệu lực; **chưa hỗ trợ thu thuốc theo lượng/nhiều phiếu cho cùng dòng toa** |
| Hủy/hoàn tiền chỉ chặn lượng đang giao thuộc nguồn thu liên quan | STO `HuyChungTu`, `HoanTien` v95; khóa lượt trước chứng từ | Nguồn lịch sử mơ hồ giữ NULL và chặn bảo thủ theo dòng toa; chưa DB |
| Snapshot tên/mã/ĐVT thuốc và tên NCC cho phiếu nhập mới | Override STO nhập/chi tiết v95 | Phiếu cũ không bịa snapshot, hiển thị cảnh báo legacy; chưa DB |
| PDF thu A4 theo HIS chuẩn | `Views/thu_ngan/PhieuThuA4.cshtml`; chỉ áp dụng `id_chung_tu` + THU | Razor + render fixture, chưa so với PDF từ HIS chạy thật |
| PDF/Excel nhập kho HIS | `kho_chung_tu_controller.cs`, `PhieuNhap.cshtml`, `LayoutKho.cshtml`, `kho_excel.cs` | Fixture PDF/xlsx; chưa route authenticated hoặc xem trong Excel desktop |

### Route / hợp đồng mới

- `GET /kho/api/dong-da-cap?id_vao_vien=...`: từng dòng xuất còn được hoàn, `id_xuat_ct`, lượng và ĐVT cơ sở.
- `POST /kho/api/hoan-thuoc`: `{ id_vao_vien, ly_do, hoan_toan_bo, danh_sach: [{ id_xuat_ct, so_luong_hoan_co_so }] }`. Không còn payload `id_toa_thuoc_ct` / lượng theo quy đổi danh mục. `hoan_toan_bo=true` phải gửi `[]`; false bắt buộc có dòng dương hợp lệ. Request cũ bị 400, không tự tương thích bằng hoàn tất cả.
- `GET /kho/phieu-nhap/pdf?id=...`, `GET /kho/phieu-nhap/excel?id=...`: tenant lấy từ claims, quyền Xuat kiểm tra tại server, dùng cùng read model/STO chi tiết.
- Print theo ID chứng từ thu giữ snapshot. Print legacy theo lượt và phiếu HOAN hiện vẫn dùng `InPhieu.cshtml` cũ. Không coi chúng đã được port thành mẫu HIS.
- API mới yêu cầu v95. Chạy migration rồi deploy app trong cùng cửa sổ cutover; chưa được deploy app mới lên DB v94.

### Nguồn mẫu và các thích nghi

- Thu A4: `HisSoft/Views/QL_TaiChinh/PDFPhieuThuA4.cshtml`; giữ CSS/bảng 7 cột, bốn vùng chữ ký. Header dùng cơ sở QLPM; bỏ QR ngoài hệ thống và ghi chú VAT trong ngày vì e-invoice P2. Tạm ứng không áp dụng, hiển thị “—”. Bổ sung repeat header/tránh tách dòng, sửa nhãn chuyển khoản bị xuống dòng dấu hai chấm.
- Nhập PDF: `HisSoft/Views/HH_NhapKho/PhieuNhapKhoPDF.cshtml` + `Views/Shared/LayoutPdfPhieuXuatNhapKho.cshtml`; A4 portrait, giữ 13 cột và chữ ký. CK/VAT/hao hụt chưa có dữ liệu hiển thị “—”. Cột tồn đổi rõ thành “SL tồn lúc nhập (cơ sở)” = lượng snapshot nhập, không đọc tồn hiện tại vào chứng từ cũ.
- Nhập xlsx: phương thức xuất phiếu nhập trong `HisSoft/Controllers/HH_NhapKhoController.cs` (vùng khoảng 552–817); giữ worksheet “Phiếu nhập kho”, 14 cột, header 12, data 14 và widths HIS. Mở rộng merge tiêu đề A7:N7 thay A7:L7 bị thiếu cột. Giá/số lượng/ngày lưu kiểu numeric/date, số lô giữ text. Thiết lập vùng in/repeat header.
- Package `ClosedXML 0.105.0`; không dùng EPPlus `NonCommercial`. API tham khảo chính thức: https://docs.closedxml.io/en/v0.105.0/api/index.html . Chưa có renderer artifact-tool trong runtime local để xem workbook; chỉ reopen bằng ClosedXML và kiểm tra ô/format.

### Bằng chứng kiểm tra

- Build ứng dụng thành công, 0 lỗi; cảnh báo .NET 7 hết hỗ trợ và các nullable warning đã tồn tại ở module hệ thống/JSON. Không đổi framework, không dừng app người dùng.
- Harness cuối cùng: **PASS 23 assertions**. Kiểm tra SQL bằng parser chỉ là cú pháp, không phải chạy STO trên schema mục tiêu.
- `node --check` cho `kho.js` và `thungan.js` pass; `git diff --check` pass.
- Harness `tests/ThuNganKho.Contracts`: ScriptDom parse v95 + verifier + before manifest; kiểm tra từ chối request hoàn sai, API 410, số tiền bằng chữ, reopen xlsx kiểm tra numeric/date/số lô, ô gộp/header; Razor render hai mẫu.
- Lệnh: `dotnet run --project tests/ThuNganKho.Contracts -p:BaseOutputPath=D:\project\QLPM\.codex-build\his-v95\tests-bin\ -- D:\project\QLPM`.
- Fixture ở `.codex-build/his-v95/qa` (gitignore, không phải dữ liệu thực): phiếu thu/nhập A4 1 trang; phiếu thu 80 dòng dài 5 trang, đủ dòng 80 và tổng 800.000. PNG trang mẫu, đầu/cuối đã xem. Vùng chữ ký tránh tách trang nên có thể sang trang riêng; cần so bản HIS live khi có dữ liệu mẫu hợp lệ.
- **Các test này không chứng minh bind schema SQL, transaction/idempotence live, chống race, quyền qua middleware hoặc hành vi browser.** Không đánh dấu nghiệm thu nghiệp vụ chỉ vì build/parser pass.

### Việc còn lại, theo thứ tự

1. **Thu thuốc theo lượng (P0):** DTO `so_luong`, UI Số kê/Đã thu/Thu lần này/Còn lại. Tính số thu ròng theo snapshot THU trừ HOAN theo dòng; dịch vụ vẫn thu nguyên dòng. Sửa đồng bộ master, `DaThu` và truy vấn danh sách/chi tiết: không được dùng cờ `DaThu` như bằng chứng đã trả đủ lượng thuốc.
2. **Cấp theo lượng đã trả (P0):** thay guard một nguồn thu trong STO cấp v95 bằng phân bổ vào các dòng chứng từ thu còn lượng được cấp, thứ tự ngày/ID tăng dần. Lưu quy đổi/ĐVT của nguồn thu, không dùng danh mục hiện tại để diễn giải lịch sử. Sửa queue/detail/cap còn lại và test toa 10 → thu 4 → cấp 3 → thu 6. Đang chặn nguồn mơ hồ, không nới guard trước khi hoàn tất phân bổ.
3. **Hoàn tiền một phần (P0):** hiện STO vẫn HOAN toàn bộ và index unique một phiếu HOAN/gốc; UI chưa có quy trình hoàn. Cần liên kết dòng hoàn đến dòng THU gốc, giới hạn lượng/tiền chưa hoàn, trừ lượng còn giao của đúng nguồn, ghi phương thức hoàn thực tế; không tự tăng tồn. Không chỉ thêm nút gọi API hoàn toàn bộ rồi coi hoàn một phần đã xong.
4. Lịch sử/chi tiết/in lại phiếu cấp/hoàn/điều chỉnh/hủy thuốc, khóa/mở khóa lô có audit; kiểm tra thứ tự khóa lô giữa nhiều lượt, hiện mới thống nhất khóa lượt của tài chính với cấp/hoàn.
5. Báo cáo thu/hủy/hoàn theo ngày/nhân viên/phương thức; thẻ kho và nhập–xuất–tồn cả lượng/giá trị theo thời điểm phát sinh (không chỉ Active hiện tại), lô/HSD/sắp hết hạn. UI/PDF/xlsx dùng chung queries.
6. Port tiếp HIS: `PDFPhieuThuGopA4` (A5, thao tác gộp riêng), `PDFPhieuThuInNhiet`, `PDFPhieuChiA4`/nhiệt, `HH_CapPhatThuocPK/PDFPhieuCapPhat`, `HH_TheKho/TheKhoPDF`, mẫu trả thuốc/thanh lý và các báo cáo/worksheet tương ứng. Không port nhánh nội trú/BHYT/đa kho.
7. Kiểm thử target DB, transaction rollback, đồng thời, authenticated routes và visual PDF/xlsx đối chiếu HIS live. Chưa có tài khoản/đích DB được xác nhận trong lần này.

### Migration / cutover / rollback

- `31_thu_ngan_kho_v95.sql` override sau 28/29, đã nối vào 00 và cuối 20 rebuild. 05 kiểm tra hợp đồng v95; 06 giữ bản ghi/timestamp v94 và thêm v95 tên `main-cashier-inventory-his-safety-v95`. **v95 là milestone an toàn, không có nghĩa toàn bộ kế hoạch HIS hoàn thành.** 28/29 không sửa.
- Chốt exact server + DB_NAME() và app revision, khóa ghi Thu ngân/Kho trong cửa sổ cutover. Backup DB được kiểm tra khả năng restore trước khi áp dụng.
- Điền đích đã duyệt trong `33_before_v95_readonly.sql`, chạy read-only và lưu manifest tiền/tồn/chi tiết xuất/định nghĩa STO. Script này không tự backup DB.
- Sau backup mới chạy updater đúng đích. Dùng `32_verify_v95_readonly.sql` AFTER migration đối chiếu manifest và xuất danh sách liên kết nguồn mơ hồ. Không tự sửa NULL theo phỏng đoán. Hai script read-only không nằm trong updater.
- Cổng mở lại: tiền/tồn không đổi ngoài backfill nguồn duy nhất; verifier đạt; smoke/rollback/concurrency đạt; deploy app cùng schema.
- Nếu thất bại trước mở ghi: restore bản sao lưu đã duyệt cùng app revision cũ; không tự DROP cột hay chạy v94 lên app mới. Nếu đã có chứng từ mới: khóa ghi, giữ/export dữ liệu mới, đánh giá phục hồi/forward-fix; không restore mất chứng từ mới khi chưa được duyệt.
