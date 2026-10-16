# Branch contract — main và Hieu_QLPM

## Quy tắc gốc

Hai nhánh dùng **cùng core contract QLPM**.

- `main`: toàn bộ chức năng phòng mạch chung.
- `Hieu_QLPM`: toàn bộ chức năng của `main` + DSS gợi ý kê toa.
- Khác biệt được phép: DSS/AHP/Rule-based và các màn/API/dữ liệu phục vụ riêng DSS.

Không tạo khác biệt non-DSS ở Tiếp nhận, Khám bệnh, Phác đồ, CLS, Auth, Phân quyền, Quản trị hệ thống, Thu ngân/Kho, entity, DTO, API contract hoặc schema core.

Core source hiện hành dùng **schema v100**; DB thực tế phải xác minh riêng. Hard-clean DSS/legacy được đưa vào từ v70 và tiếp tục là invariant. Xem [Database README](Database/README.md).

## Common bắt buộc giống

- .NET 7, EF Core 7, SQL Server `QLPM`.
- Cookie auth, claims, server-side authorization.
- Multi-tenant theo `IDCSKCB`; không tin ID tenant/nhân viên từ client.
- Global admin không thuộc tenant cố định; working-CSKCB là ngữ cảnh session.
- Tiếp nhận + chống trùng BN + công khám + chuyển khám.
- `QL_BenhNhan.IDGioiTinh`.
- Khám, sinh hiệu, ICD, chỉ định, toa, lịch sử, cụm từ viết tắt.
- Phác đồ.
- CLS common: cấu hình, import trị số, kết quả, file, lịch sử; không duyệt/hủy duyệt.
- `DM_DichVu.LoaiKetQua` + `IDFormKQ`.
- Config trị số ở `QL_CLS_FormKQXN_CT`; master không giữ range runtime.
- `QL_CLS_FormKQXN.TenForm` là tên form vật lý.
- Paging/rate limit/request limit.
- UI common, selector DOM và API contract common.
- Danh mục JSON common.
- Auth/quản trị semantics common.

## Hieu-only

- `dich_vu_ahp`.
- Controller/model/view/JS DSS/Rule-based.
- Service AHP.
- Menu/link/modal DSS.
- Bảng/STO/migration `DSS_*`.
- Dữ liệu AHP/Rule-based và workflow góp ý/kiểm định DSS.

## Khi sửa

Thay đổi non-DSS:
1. sửa contract chung;
2. đồng bộ hai nhánh;
3. diff;
4. build/test cả hai;
5. DB common cuối của Hieu phải tương thích main.

Thay đổi DSS:
- chỉ sửa Hieu, trừ hạ tầng thực sự common;
- không đưa DSS sang main.

## Database

Main dùng `Doc/Database/00_CapNhat_TatCa.sql`. Schema source hiện hành v100 hard-clean DSS/legacy sau khi migrate phần canonical cần giữ. Thay đổi v97 (thu CLS đang khám), v98 (hủy thu tự đảo cấp thuốc), v99 (cấu hình thu công khám trước theo CSKCB) và v100 (cấu hình thu tiền trước chỉ định CLS theo CSKCB) là common, không phải overlay Hieu; đồng bộ branch qua quy trình tích hợp, không checkout/ghi đè nhánh khác trong phiên sửa này.

Không dùng updater main trên DB cần giữ overlay DSS cũ. DSS phải được triển khai trên core canonical hiện hành và không tái tạo legacy common.

## Checklist

- Không credential thật.
- Không `[TEST-AHP]` trong production.
- Common code không gọi STO legacy riêng Hieu.
- `TenHienThi` form không phải cột vật lý bắt buộc; dùng `TenForm`.
- Diff non-DSS phải được xử lý.
