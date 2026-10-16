# Bàn giao chuẩn hóa DTO / tổ chức C# — 07-10-2026

## Phạm vi và baseline

- Nhánh Hieu_05/10. Rà AST toàn bộ C# runtime: 65 file trước, 130 file sau tách type. Không sửa HIS, SQL, migration, JS, route, quyền hay nghiệp vụ.
- Baseline dùng mã đang có sau commit người dùng trong lúc bắt đầu rà; bao gồm source v97 và service Excel lịch sử hủy mới. Không reset/checkout; giữ workbook ở Doc/UI/pdf-mẫu. Có commit UI khác và file test cập nhật đồng thời: đọc lại rồi ghép thay đổi reference/test, không ghi đè thay đổi đó.
- Lỗi tổ chức: 27 request nested trong 5 controller (Kho11, Thu ngân5, Khám7, CLS2, Phác đồ2); hai model Excel public trong service; request và model in/exception lẫn trong file aggregate.

## Đã sửa

- 67 public data/view models có file riêng trong Models; namespace theo thư mục. Requests chia 7 phân hệ, Printing chia Kho/ThuNgan/KhamBenh, Reports/ThuNgan, Imports/HeThong và ViewModels.
- 16 type snake_case cũ chuyển PascalCase (DangNhapRequest, CskcbLuuRequest, NhanVienImportExcelRow, ...). Giữ nguyên property và JsonPropertyName, không đổi wire contract/default.
- Tách KhamBenhPrintValidationException sang Services/Printing. DbMultipleResult, yeu_cau_quyen_attribute và 2 interface in/render có file riêng đúng layer; namespace Services/Data giữ nguyên với các utility/interface.
- Cập nhật controller/service/test/Razor. Không còn kho_controller.XuatThuocRequest; dùng Models.Requests.Kho.XuatThuocRequest. Private projection đọc STO/query trong service vẫn private, không biến thành API DTO.
- File aggregate Models cũ thay bằng file type tương ứng; không xóa class/nghiệp vụ/dữ liệu. Header CoSo của KhoNhapPrintModel vẫn dùng ThuNganPrintModel theo contract cũ; không thiết kế lại mẫu in.
- Models/README.md và Doc/AGENTS_QuanLyPhongMach.md quy định vị trí/guard để tránh tái phạm.

## Kiểm tra và giới hạn

- Capture baseline thật trước refactor: DtoContractSnapshot.cs; fixture dto-contracts-before-refactor.json chứa 67 model/11 controller. Đối chiếu default + populated JSON, property types/nullability/get-set/annotations, route/quyền/parameter: kết quả trước/sau bằng nhau.
- ModelStructureContracts.cs kiểm tra request không public/nested, model không ở Services, PascalCase, file/namespace tương ứng, request không trực tiếp chứa EF entity. Không tự cập nhật fixture để bỏ qua thay đổi ngoài ý định.
- Build net7.0 qua ProjectReference gồm biên dịch Razor: thành công. Harness PASS329 assertions gồm regression v95/v96/v97, recording DB, workbook, render Razor.
- AST sau: 130 file không lỗi cú pháp, không public nested request/data model ngoài Models. Không thêm dependency Roslyn/.NET10 vào app; tool chỉ đọc local dùng SDK ở .codex-build/his-v95/dto-audit (ignored).
- Node regression CLS PASS32 assertions, git diff --check không lỗi whitespace; kiểm tra reference không còn namespace Models root/DTO kiểu controller.Request.
- Còn NETSDK1138 (.NET7 EOL) và 6 nullable warning có sẵn ở he_thong_controller/danh_muc_json_dich_vu; không đổi semantics để xóa warning trong đợt tổ chức DTO.
- Chưa test route sau đăng nhập/DB thật. Không chạy app/worker hay migration. Điều kiện xác nhận server/database cho v97 giữ nguyên.

## Chạy lại

```powershell
dotnet run --project tests/ThuNganKho.Contracts -p:BaseOutputPath=D:\project\QLPM\.codex-build\his-v95\tests-bin\ -- D:\project\QLPM
node tests/ThuNganKho.Contracts/cls-collection.test.cjs
git diff --check
```

Đây là core common: tích hợp sang branch khác qua quy trình review/cherry-pick được duyệt, không tự checkout/ghi đè worktree khác. CLR tên/namespace đã đổi; consumer C# ngoài repo nếu có cần cập nhật. HTTP JSON/route giữ nguyên.
