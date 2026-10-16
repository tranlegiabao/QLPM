# Model và DTO

Model public nằm ở đây, không khai báo request DTO nested trong controller hoặc ghép model Excel vào service.

- `Requests/<PhanHe>/<TypeName>.cs`: body/query DTO và kiểu dòng của request.
- `Printing/<PhanHe>/<TypeName>.cs`: dữ liệu Razor/PDF và kết quả in.
- `Reports/<PhanHe>/<TypeName>.cs`: dữ liệu báo cáo/Excel.
- `Imports/<PhanHe>/<TypeName>.cs`: dòng preview/import.
- `ViewModels/<TypeName>.cs`: model trang MVC.

Namespace khớp thư mục (`QuanLyPhongMach.Models.Requests.Kho`, ...); mỗi public model có file riêng, tên file bằng tên type PascalCase. Giữ tên trường JSON, JsonPropertyName, validation, nullability và mặc định khi refactor. Không dùng EF entity làm request body.

`Entities` chỉ là persistence mapping. Projection private chỉ dùng trong một service có thể giữ private/nested, không đưa thành DTO public để chia sẻ không cần thiết. Exception, filter, interface và helper có hành vi nằm ở Services/Data, không nằm trong Models.

Kiểm tra tự động: `tests/ThuNganKho.Contracts/ModelStructureContracts.cs` đối chiếu layout và snapshot 67 model/11 controller. Khi đổi API có chủ đích phải review diff fixture; không cập nhật snapshot chỉ để làm test xanh.
