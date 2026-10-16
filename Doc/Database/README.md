# Database — QLPM main contract

Schema source hiện hành: **v104 — `main-national-prescription-signing-framework-v104`**; migration này yêu cầu target đã có warehouse v103.

> Checkout này không chứa các migration v101-v103. Không dùng updater hiện tại để nâng trực tiếp từ v100 lên v104; phải xác nhận target đã ở v103 trước khi triển khai.

## Contract v104 — ký số và liên thông toa thuốc quốc gia

- `QL_ToaThuoc` là đầu toa con của `QL_VaoVien`; `QL_ToaThuoc_CT` vẫn là nguồn dòng thuốc tương thích cho khám, thu ngân và kho.
- `QL_ToaThuoc_PhienBan`, `QL_ToaThuoc_LanGui` và `QL_ToaThuoc_Audit` giữ snapshot đã ký, outbox thủ công và dấu vết trạng thái.
- `DM_Thuoc.MaThuocQuocGia` là mã gửi ra ngoài; không dùng `MaThuoc` nội bộ thay thế.
- Mặc định từng CSKCB ở môi trường `TEST`, `ApiBaseUrlTest=NULL`, URL ký trống và `HieuLuc=0`. Không có fallback sang production.
- Source chỉ chuẩn bị framework. Chưa được coi là đã triển khai DB, đã ký thật hoặc đã liên thông thật cho tới khi có signer và sandbox chính thức.

## Điểm chạy chuẩn

Chạy updater trong một phiên `sqlcmd` để verifier và bước chốt version dùng chung `SESSION_CONTEXT`:

```powershell
sqlcmd -S <server> -d master -E -C -b -f 65001 -i "D:\project\QLPM\Doc\Database\00_CapNhat_TatCa.sql"
```

Không chạy riêng `06_chot_phien_ban_main.sql`. File này chỉ chốt v104 sau khi `05_kiem_tra_main.sql` đã thành công trong cùng session.

## Contract v94

### Override nối tiếp v95/v96/v97/v98/v99/v100/v101/v102/v103/v104

- v95: hoàn kho theo dòng cấp/lượng cơ sở, payload sai không hoàn toàn bộ; hủy nhập kiểm tra lịch sử; FK nguồn thu/quy đổi cấp và snapshot nhập kho. Không sửa script/hợp đồng v94.
- v96: `34_kho_nguoi_xuat_v96.sql` sau schema auth và v95. Global admin đã chọn cơ sở được phát thuốc với `IDNhanVienXuat=NULL`; mọi phiếu cấp mới lưu `IDTaiKhoanXuat` + `TenNguoiXuatSnapshot`. STO kiểm tra tài khoản active; tài khoản tenant phải khớp nhân viên active thuộc cơ sở. Không backfill audit phiếu cũ.
- `35_verify_kho_actor_v96_readonly.sql`: verifier audit sau migration; phải điền đúng server/database được duyệt. Kết hợp manifest trước/sau v95 để đối chiếu tiền/tồn.
- v97: `36_thu_cls_dang_kham_v97.sql` sau v96; thu CLS nội bộ khi Đang khám, thuốc/công khám sau Khám xong; giữ ID dòng thu và khóa từng nguồn có chứng từ. Lưu nhanh CLS qua STO đồng bộ nguồn thu trong cùng transaction, không tự hoàn tất khám và không áp chính sách bắt buộc thu trước upload PDF.
- `37_verify_thu_cls_v97_readonly.sql`: xác nhận target, kiểm tra contract và liệt kê nguồn CLS thiếu/trùng dòng tiền để đối chiếu; không tự sửa dữ liệu cũ.
- v98: `38_huy_thu_dao_cap_v98.sql` chạy sau v97 cuối updater/rebuild. Hủy chứng từ thu tự đảo phần cấp còn giao của đúng dòng chứng từ về lô/lượng cơ sở gốc, rồi hủy thu trong cùng transaction. Giữ receipt/issue snapshots, ghi bút toán `DAO_CAP_HUY_THU` khác `NHAN_TRA`; audit tài khoản thực hiện, global admin không giả nhân viên. Legacy mơ hồ phải đối chiếu, không tự nối. Không đổi `HoanTien`, không phát lệnh hoàn tiền ngân hàng.
- `39_verify_huy_thu_v98_readonly.sql`: xác nhận target, đối chiếu receipt hủy–bút toán đảo–dòng cấp/audit/lượng và manifest tồn từng lô. Không tự sửa; không nằm trong updater.
- v99: `HT_Config` lưu cấu hình theo `IDCSKCB`; seed `THUCONGKHAMDVTRUOC=1` cho từng cơ sở và cho cơ sở tạo mới để giữ nguyên hành vi bắt buộc thu công khám trước. Nếu DB đã từng chạy bản v99 global, migration giữ trạng thái hiện tại rồi nhân sang từng CSKCB trước khi đổi unique key. Tắt config chỉ bỏ chốt tại lúc bắt đầu khám của đúng cơ sở, không xóa khoản phải thu và không ảnh hưởng điều kiện thu CLS/cấp thuốc.
- v100: seed idempotent `THUTIENCHIDINHTRUOC=1` theo từng CSKCB và cho cơ sở tạo mới. Khi bật, chỉ định CLS có tiền phải được thu trước khi nhập/upload kết quả; khi tắt, cho phép nhập kết quả rồi thu sau. Chỉ định gửi ngoài hoặc có thực thu bằng 0 không bị chặn. Thiếu dòng config được coi là bật để fail-safe.
- Chỉ chuẩn bị source; chưa xác nhận/migrate DB thực tế lên v104. App/assets mới cần STO v104, cutover schema + app cùng lúc. Backup/export định nghĩa và manifest trước, chạy updater hai lần trên đích test đã duyệt. Sau phát sinh dữ liệu ký/gửi không rollback về schema cũ bằng cách xóa audit; cần forward-fix hoặc restore có đối chiếu.

### Nền tảng chứng từ v94
- Mỗi lần thu tạo một chứng từ `THU` bất biến trong `QL_ThuTien_ChungTu` và snapshot dòng ở `QL_ThuTien_ChungTu_CT`; `QL_ThuTien` vẫn là bảng tổng hợp tương thích theo lượt khám.
- Hủy thu và hoàn tiền là hai nghiệp vụ riêng. Hủy đổi trạng thái phiếu thu, không tạo dòng tiền ra; hoàn tiền tạo chứng từ `HOAN` liên kết phiếu gốc. Ghi người và thời điểm; hủy hiện cho phép lý do tùy chọn, hoàn tiền bắt buộc lý do.
- Chính sách hiện hành v98: hủy tự đảo sổ kho, không phải xác nhận nhận lại thuốc vật lý (cơ sở phải kiểm tra thu hồi). Hoàn tiền vẫn cần Kho nhận lại trước. Quyết định mới thay điều kiện hoàn kho trước cho hủy, không đổi hoàn tiền hay đưa nghiệp vụ ngân hàng vào cancellation.
- Số phiếu tách theo cơ sở/năm/loại qua `QL_ThuTien_SoChungTu`, dạng `PT-<CS>-<năm>-<số>` và `HT-<CS>-<năm>-<số>`.
- Dữ liệu thu trước v94 không được dựng chứng từ giả; UI hiển thị là dữ liệu legacy chỉ đọc.
- Thu ngân audit cả tài khoản thực hiện: `QL_ThuTien.IDTaiKhoanThu` và `QL_ThuTien_LichSu.IDTaiKhoan`; global admin không cần giả lập nhân viên.
- Thu ngân theo bố cục HIS: phụ thu theo từng dòng, giảm giá theo `%`, mặc định thu tiền mặt; `QL_ThuTien_CT.PhuThu/GiamPhanTram` là dữ liệu canonical.

- `QL_VaoVien.GhiChu` cũ được tách thành `GhiChuTiepNhan` (tiếp nhận) và `DanDo` (bác sĩ); cột `GhiChu` legacy bị xóa sau khi STO được rebuild.

- `QL_VaoVien` là master duy nhất của lượt khám theo `(IDCSKCB, ID)`. `NgayLuuKhamLanDau` phân biệt lượt mới mở với lượt đã lưu chính thức; `NgayCapNhatKham` ghi lần cập nhật khám gần nhất. Bảng `QL_PhieuKham` đã bị loại bỏ.

- DB đích là `QLPM`; dữ liệu nghiệp vụ theo tenant `IDCSKCB`.
- CLS chỉ có 0 hoặc 1 PDF trên mỗi `QL_ChiDinh_CT`; source of truth là `DuongDanKetQua NVARCHAR(1000) NULL`.
- Không còn bảng, STO, trigger hay UI structured CLS. `04_main_sto_cls.sql` và `14_common_cls_tri_so_import.sql` chỉ còn vai trò dọn object cũ; updater không chạy file 14.
- `DM_NhanVien` là hồ sơ dùng chung. Quan hệ nhân viên–cơ sở là N-N qua `DM_NhanVien_CSKCB`.
- Chức danh lấy duy nhất qua `DM_NhanVien.IDChucDanh -> DM_ChucDanh.ID`; không còn `DM_NhanVien.ChucDanh`.
- `DM_ChucDanh` chỉ có 11 dòng canonical mã `1` đến `11`; vai trò/phân quyền không phải chức danh.
- Loại toa dùng `DM_LoaiToaThuoc.MaLoaiToaThuoc/TenLoaiToaThuoc` và `QL_ToaThuoc_CT.MaLoaiToaThuoc`; không còn `DM_LoaiDonThuoc` hay `MaLoaiDonThuoc`.
- `HT_JSON_CSKCB`, `HT_JSON_DongBo_Lich` và `QLPM_SchemaVersion` được giữ lại.
- `QL_BenhNhan.IDGioiTinh` là canonical; tuổi được tính từ ngày sinh.
- Thu ngân nhận CLS nội bộ ở `TrangThaiKham=1`; thuốc/công khám chỉ ở `TrangThaiKham=2`. CLS gửi ngoài không được chọn thu. Một `QL_ThuTien` cho một `IDVaoVien`; UI vẫn `Chưa thu / Đã thu / Tất cả`, mặc định `Chưa thu`. Trạng thái tính theo khoản hiện được phép thu, không tính thuốc/công khám đang chờ hoàn tất. Thêm CLS hoặc hoàn tất khám có khoản mới sẽ trở về Chưa thu.
- Bác sĩ được lưu tiếp sau thu CLS; nguồn đã thu/đã có lịch sử chứng từ không được xóa, đổi số lượng hay giá; dòng tiền không bị tạo lại. Nguồn có PDF/đã thực hiện không được xóa. `DaThu` và `KhoaNghiepVu` là hai cờ riêng.
- `QL_ThuTien_LichSu` được giữ cho tương thích/audit legacy; nguồn in lại từ v94 là snapshot chứng từ.
- Kho chỉ cấp **dòng thuốc đã thu tiền** (`QL_ThuTien_CT.IDToaThuocCT` + `DaThu=1`); không bắt buộc các khoản CLS/công khám khác đã thu. Tồn quản lý theo `DM_Kho` + `QL_Kho_LoThuoc`, xuất theo FEFO và không xuất lô hết hạn.
- Kho cho cấp một phần và theo dõi kê/đã cấp/còn lại; v95 hoàn theo dòng cấp và lượng cơ sở, hoàn toàn bộ dùng cờ riêng (không còn danh sách trống tự hoàn tất cả). Mỗi lần hoàn có phiếu `QL_Kho_Hoan` và trả đúng lô đã xuất.
- Báo cáo tồn tách `tồn vật lý`, `hết hạn` và `khả dụng`; lô hết hạn không được cấp nhưng chỉ giảm tồn vật lý khi có chứng từ xử lý riêng.

## Các script chính

- `00_CapNhat_TatCa.sql`: updater idempotent chuẩn.
- `01_main_schema_contract.sql`: schema nền còn hiệu lực.
- `02_main_sto_tiep_nhan_kham.sql`: STO Tiếp nhận/Khám theo contract PDF-only.
- `03_main_sto_phac_do.sql`: STO Phác đồ.
- `04_main_sto_cls.sql`: drop-only cho STO CLS structured cũ.
- `05_kiem_tra_main.sql`: verifier hợp đồng schema/STO v104; không thay kiểm thử runtime.
- `06_chot_phien_ban_main.sql`: chốt version sau verifier.
- `18_main_cleanup_legacy.sql`: dọn DSS/legacy; giữ bảng CLS cũ cho tới migration 26.
- `25a_common_nhan_vien_chuc_danh_schema.sql`: prelude schema nhân viên/chức danh.
- `25_common_nhan_vien_nhieu_cskcb_chuc_danh.sql`: quan hệ N-N, JSON version và STO nhân viên.
- `26_pdf_only_cls_va_cleanup_schema.sql`: migrate PDF mới nhất, canonicalize chức danh/loại toa, rồi drop schema legacy.
- `28_thu_ngan.sql`: danh sách/chi tiết, chứng từ thu độc lập, hủy và hoàn tiền sau khi khám xong.
- `29_kho_nghiep_vu.sql`: kho thuốc, lô/HSD, quy đổi ĐVT, nhập kho và xuất thuốc theo toa đã thanh toán bằng FEFO.
- `36_thu_cls_dang_kham_v97.sql`: override luồng thu CLS đang khám và bảo toàn dòng tiền khi lưu tiếp.
- `37_verify_thu_cls_v97_readonly.sql`: verifier/inventory chỉ đọc, target phải xác nhận trước.
- `38_huy_thu_dao_cap_v98.sql`: hủy thu tích hợp đảo cấp đúng chứng từ, bổ sung loại/liên kết/audit bút toán kho.
- `39_verify_huy_thu_v98_readonly.sql`: đối chiếu đảo cấp chỉ đọc, target phải xác nhận trước.
- `40_ht_config_thu_cong_kham_v99.sql`: tạo/seed cấu hình theo CSKCB và hai STO danh sách/cập nhật trạng thái.
- `41_ht_config_thu_tien_chi_dinh_v100.sql`: seed config và STO lưu đường dẫn kết quả có chốt thu tiền chỉ định theo CSKCB.
- `20_REBUILD_ALL_STO_MAIN.sql`: script bảo trì drop/rebuild toàn bộ `dbo.STO_%` và phục hồi override canonical tới v104; không xóa dữ liệu nghiệp vụ.
- `45_toa_thuoc_quoc_gia_v104.sql`: đầu toa, snapshot ký, outbox/audit, cấu hình mã hóa và khóa sửa dữ liệu đã gửi.

## Ranh giới database

Các script trong `Doc/Database/Hieu` và file tạo mới Server 118 là contract riêng. Không áp migration local Hieu sang target khác nếu chưa có chỉ định rõ ràng. Runtime ứng dụng dùng `ConnectionStrings:QLPM`; không thêm kết nối HIS vào contract này.
