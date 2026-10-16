# AGENTS — QLPM main

## Mục tiêu

Duy trì ứng dụng quản lý phòng mạch `.NET 7`, SQL Server `QLPM`, schema main hiện hành **v88**.

Luồng:
`Tiếp nhận → Chuyển khám → Khám → Sinh hiệu/ICD/CLS/Toa thuốc → Đã khám`.

`Đã khám` chỉ khi bác sĩ bấm `Khám xong`; toa thuốc có thể rỗng. Sửa hồ sơ đã hoàn tất theo quyền quản trị vẫn giữ trạng thái `Đã khám`.

Đọc `Doc/BRANCH_CONTRACT.md` trước khi sửa. Thay đổi non-DSS phải đồng bộ `Hieu_QLPM`.

## Core

- `IDVaoVien` là khóa lượt khám.
- Multi-tenant theo `IDCSKCB`.
- Business rule quan trọng nằm trong STO/constraint/trigger.
- Không tin `IDCSKCB`/ID nhân viên/bác sĩ từ client.
- Tenant user lấy ngữ cảnh từ claims.
- Global admin không thuộc tenant cố định; phải chọn working-CSKCB trước nghiệp vụ tenant.
- Page thiếu quyền → 404; API thiếu quyền → 403.
- `QL_BenhNhan.IDGioiTinh`; tuổi tính từ `NgaySinh`.
- Sinh hiệu chỉ nhập trong Khám.
- CCCD exact là định danh mạnh; match yếu không tự merge.
- Không xóa/vô hiệu hóa chỉ định đã có kết quả CLS.
- CLS không duyệt/hủy duyệt, không tự thêm LIS/máy xét nghiệm.
- Master trị số = identity/metadata; config form = `QL_CLS_FormKQXN_CT`.
- `QL_CLS_FormKQXN.TenForm` là tên form vật lý.
- `DM_VietTat` phục vụ viết tắt theo CSKCB/nhân viên.
- Danh sách lớn server paging.
- Không commit secret/data test production.

## Tổ chức C# / DTO

- Request DTO ở `Models/Requests/<PhanHe>`, dữ liệu in ở `Models/Printing`, báo cáo Excel ở `Models/Reports`, preview/import ở `Models/Imports`, model trang ở `Models/ViewModels`.
- Mỗi public model có file tên PascalCase khớp type; namespace khớp thư mục. Không khai báo public request nested trong controller hoặc model dữ liệu trong service.
- Giữ JSON name/annotation/default khi chuyển DTO; Entities không phải request body. Projection chỉ phục vụ một service có thể giữ private/nested.
- Exception/interface/filter/helper có hành vi nằm đúng Services/Data, file riêng. Xem `QuanLyPhongMach/Models/README.md`; chạy architecture/snapshot guards trong `tests/ThuNganKho.Contracts`.

## UI

- Thanh phân hệ ngang.
- Tiếp nhận: danh sách trái, form phải; ngày sinh nhập tay; địa chỉ Số nhà → Tỉnh → Phường/Xã.
- Khám: danh sách trái, icon giữa, form cuộn phải.
- Vùng khám: BN + phác đồ → sinh hiệu → triệu chứng → chẩn đoán → CLS → toa.
- Dropdown dùng TomSelect.
- Autofill tắt toàn hệ thống trừ login.
- Import nhân viên phải preview/chỉnh trước khi lưu.
- Không đổi DOM/API một phía.

## Database

Chỉ chạy `Doc/Database/00_CapNhat_TatCa.sql`.

Main phải sạch: không DSS/AHP, không legacy dormant, không hai source-of-truth. Verifier phải PASS trước khi chốt version.

Khi đổi DB:
1. sửa schema/STO;
2. sửa updater + verifier + version;
3. sửa docs/test;
4. build main;
5. đồng bộ core sang Hieu và build/test khi Hieu sẵn sàng.

## Không đưa vào main

- `DSS_*`;
- service AHP;
- controller/view/js DSS;
- menu/modal DSS;
- data `[TEST-AHP]`.

## Kiểm tra cuối

- Audit diff main ↔ Hieu.
- STO signature khớp controller.
- API/DOM/SQL contract đồng bộ.
- Updater tạo đủ table/STO code runtime đang gọi.
- Không secret thật.
