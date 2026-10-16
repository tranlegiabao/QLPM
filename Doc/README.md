# QLPM — tài liệu hiện hành

Tài liệu này mô tả **runtime hiện tại của nhánh `main`**. Khi Markdown và code mâu thuẫn, code/runtime + schema verifier là nguồn kiểm tra cuối; sau đó phải cập nhật lại tài liệu để không giữ hai contract khác nhau.

## Branch contract

- `main`: toàn bộ chức năng phòng mạch chung.
- `Hieu_QLPM`: cùng core contract với `main`, chỉ thêm DSS gợi ý kê toa = AHP + Rule-based và các thành phần DSS liên quan.
- Mọi thay đổi non-DSS phải được đồng bộ giữa hai nhánh.

Xem [BRANCH_CONTRACT.md](BRANCH_CONTRACT.md).

## Công nghệ

- ASP.NET Core MVC, target `.NET 7`.
- EF Core SQL Server 7.0.20.
- SQL Server database `QLPM`.
- Cookie Authentication + claims + authorization filters.
- Business rule chính nằm trong Stored Procedure/constraint/trigger; C# validate request, map dữ liệu và điều phối.
- Razor + Bootstrap + JavaScript.
- Không commit credential thật; cấu hình local dùng `appsettings.local.json`, user-secrets hoặc environment variable.

## Quy tắc nền

- QLPM là multi-CSKCB; dữ liệu nghiệp vụ phải tách theo `IDCSKCB`.
- `IDVaoVien` là khóa nghiệp vụ trung tâm của một lần khám.
- Server không tin `IDCSKCB`/ID nhân viên/bác sĩ do client gửi lên; ngữ cảnh lấy từ claims/session.
- Global admin `quan_tri_he_thong` không thuộc CSKCB cố định. Muốn thao tác nghiệp vụ phải chọn một CSKCB làm việc.
- Không có quyền vào trang MVC → HTTP 404; API đã đăng nhập nhưng thiếu quyền → HTTP 403.
- Main không có DSS/AHP/Rule-based.
- Không giữ schema legacy dormant hoặc hai source-of-truth cho cùng dữ liệu.

## Phân hệ

| Phân hệ | Route | Trạng thái |
|---|---|---|
| Tiếp nhận | `/tiep_nhan` | Đang dùng |
| Khám bệnh | `/kham_benh` | Đang dùng |
| Phác đồ | `/phac_do` | Đang dùng |
| Cấu hình/kết quả CLS | `/cls_ket_qua` + API `/api/cls/*` | Đang dùng |
| Hệ thống | `/he_thong` | Đang dùng |
| Thu ngân | `/thu_ngan` | Đang dùng |
| Kho | `/kho` | Đang dùng |

## Tài liệu

- [Contract hai nhánh](BRANCH_CONTRACT.md)
- [Kiến trúc](Architecture/README.md)
- [Luồng nghiệp vụ](Flow/README.md)
- [Database](Database/README.md)
- [UI/UX](UI/README.md)
- [API](API/README.md)
- [Quy định pháp lý áp dụng cho phòng khám và QLPM](Compliance/README.md)
- [Checklist test](Test/README.md)
- [Mapping tham khảo HIS (không dùng trong runtime)](Database/mapping_his_qlpm.md)
- [Quy ước agent](AGENTS_QuanLyPhongMach.md)

## Chạy ứng dụng

```powershell
cd D:\project\QLPM
git checkout main
git pull
dotnet restore .\QuanLyPhongMach.sln
dotnet build .\QuanLyPhongMach.sln
dotnet run --project .\QuanLyPhongMach\QuanLyPhongMach.csproj
```

## Cập nhật database

```powershell
sqlcmd -S HIEU -d master -E -C -b -f 65001 -i "D:\project\QLPM\Doc\Database\00_CapNhat_TatCa.sql"
```

Updater hiện hành chốt **schema main v92**. Updater áp schema/STO canonical, auth/phân quyền, quản trị, CLS, import và cụm từ viết tắt, hard-clean legacy rồi mới chạy verifier. Chỉ khi verifier đạt trong cùng session mới ghi version.
