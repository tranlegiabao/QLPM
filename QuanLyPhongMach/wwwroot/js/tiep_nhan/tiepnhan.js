// tiepnhan.js - Nghiệp vụ màn hình Thông tin hành chính / Tiếp nhận
(function () {
    let tsGioiTinh, tsDanToc, tsQuocTich, tsNgheNghiep, tsTinhThanh, tsPhuongXa;
    let selectedCongKham = []; // Danh sách công khám đã chọn: [{ IDDichVu, TenDichVu, SoLuong, DonGia }]
    let allCongKhamAvailable = []; // Toàn bộ công khám từ cache JSON
    let selectedVaoVienId = null;
    let selectedDaChuyenKham = false;
    let selectedTrangThaiKham = 0;
    let chiSuaThongTinBenhNhan = false;
    let tiepNhanDaLuu = false;
    let dangNapFormTiepNhan = false;
    let tnDataList = [];
    let tnServerTotal = 0;
    let tnCurrentPage = 1;
    let tnPageSize = 25;
    let tnPagination = null;

    function escapeHtml(str) {
        if (!str) return '';
        return String(str)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    function formatCurrencyVN(val) {
        if (val === null || val === undefined || isNaN(val)) return '0 đ';
        return Number(val).toLocaleString('vi-VN') + ' đ';
    }

    document.addEventListener('DOMContentLoaded', async () => {
        initControls();
        bindEvents();

        // Danh mục nền và danh sách tiếp nhận tải song song.
        // PageLoader chỉ bám theo loadDanhSachTiepNhan(), không chờ toàn bộ dropdown.
        await Promise.all([
            loadDropdownData(),
            loadDanhSachTiepNhan()
        ]);
    });

    function initControls() {
        // Chỉ bộ lọc ngày dùng DateTimePicker. Ngày sinh nhập tay theo dd-MM-yyyy.
        initDatePicker('#tn-filter-tu-ngay', { defaultDate: 'today' });
        initDatePicker('#tn-filter-den-ngay', { defaultDate: 'today' });

        const todayStr = formatDateVN(new Date());
        const elTuNgay = document.getElementById('tn-filter-tu-ngay');
        const elDenNgay = document.getElementById('tn-filter-den-ngay');
        if (elTuNgay && (!elTuNgay.value || elTuNgay.value === '__-__-____')) elTuNgay.value = todayStr;
        if (elDenNgay && (!elDenNgay.value || elDenNgay.value === '__-__-____')) elDenNgay.value = todayStr;

        const elNgaySinh = document.getElementById('tn-ngay-sinh');
        if (elNgaySinh && window.attachDateAutoMask) {
            window.attachDateAutoMask(elNgaySinh, { minYear: 1800 });
        }

        // Auto show/hide section giám hộ khi ngày sinh nhập tay thay đổi.
        if (elNgaySinh) {
            elNgaySinh.addEventListener('change', () => kiemTraVaHienThiGiamHo());
            elNgaySinh.addEventListener('input', () => kiemTraVaHienThiGiamHo());
            elNgaySinh.addEventListener('blur', () => kiemTraVaHienThiGiamHo());
        }

        // TomSelect Giới tính
        tsGioiTinh = initTomSelect('#tn-gioi-tinh', { placeholder: 'Chọn giới tính', showCodeInItem: false });

        // TomSelect Quốc tịch - mặc định Việt Nam, cho phép tìm kiếm nhanh
        tsQuocTich = initTomSelect('#tn-quoc-tich', { placeholder: 'Chọn quốc tịch', showCodeInItem: false, create: true });

        // TomSelect Dân tộc - chỉ hiển thị tên khi chọn theo yêu cầu
        tsDanToc = initTomSelect('#tn-dan-toc', { placeholder: 'Chọn dân tộc', showCodeInItem: false });

        // TomSelect Nghề nghiệp - cho phép chọn hoặc nhập tự do
        tsNgheNghiep = initTomSelect('#tn-nghe-nghiep', { placeholder: 'Chọn nghề nghiệp', showCodeInItem: false, create: true });

        // TomSelect Tỉnh thành - chỉ hiển thị tên khi chọn theo yêu cầu
        tsTinhThanh = initTomSelect('#tn-tinh-thanh', {
            placeholder: 'Chọn tỉnh/thành',
            showCodeInItem: false,
            onChange: async function (val) {
                await capNhatPhuongXaTheoTinh(val);
                tuDongGhepDiaChi();
            }
        });

        // TomSelect Phường xã - chỉ hiển thị tên khi chọn theo yêu cầu; cho phép tự gõ nếu danh mục chưa có
        tsPhuongXa = initTomSelect('#tn-phuong-xa', {
            placeholder: 'Chọn phường/xã',
            showCodeInItem: false,
            maxOptions: 1000,
            create: true,
            onChange: function () {
                tuDongGhepDiaChi();
            }
        });
    }

    // Kiểm tra tuổi và show/hide section giám hộ
    function kiemTraNgaySinhNhapLieu(rawValue) {
        const raw = String(rawValue || '').trim();
        if (!raw || raw === '__-__-____' || !/\d/.test(raw)) {
            return { hopLe: true, iso: null };
        }

        const match = /^(\d{2})-(\d{2})-(\d{4})$/.exec(raw);
        if (!match) return { hopLe: false, message: 'Hãy nhập đầy đủ ngày sinh theo dd-MM-yyyy.' };

        const ngay = Number(match[1]);
        const thang = Number(match[2]);
        const nam = Number(match[3]);
        if (nam < 1800) return { hopLe: false, message: 'Năm sinh phải từ 1800 trở lên.' };
        if (thang < 1 || thang > 12) return { hopLe: false, message: 'Tháng sinh phải từ 01 đến 12.' };

        const namNhuan = nam % 400 === 0 || (nam % 4 === 0 && nam % 100 !== 0);
        const soNgayTrongThang = [4, 6, 9, 11].includes(thang)
            ? 30
            : thang === 2 ? (namNhuan ? 29 : 28) : 31;
        if (ngay < 1 || ngay > soNgayTrongThang) {
            return { hopLe: false, message: `Ngày sinh không hợp lệ cho tháng ${String(thang).padStart(2, '0')}.` };
        }

        return { hopLe: true, iso: `${String(nam).padStart(4, '0')}-${String(thang).padStart(2, '0')}-${String(ngay).padStart(2, '0')}` };
    }

    function setNgaySinhValue(value) {
        const el = document.getElementById('tn-ngay-sinh');
        if (!el) return;
        el.value = value;
        el.setCustomValidity('');
    }

    function kiemTraVaHienThiGiamHo() {
        const ngaySinhRaw = document.getElementById('tn-ngay-sinh')?.value || '';
        const sectionGiamHo = document.getElementById('section-giam-ho');
        if (!sectionGiamHo) return;

        const ketQuaNgaySinh = kiemTraNgaySinhNhapLieu(ngaySinhRaw);
        if (!ketQuaNgaySinh.hopLe || !ketQuaNgaySinh.iso) {
            sectionGiamHo.classList.add('d-none');
            return;
        }

        const parts = ketQuaNgaySinh.iso.split('-');
        const namSinh = parseInt(parts[0], 10);
        const thangSinh = parseInt(parts[1], 10);
        const ngaySinh = parseInt(parts[2], 10);

        const now = new Date();
        const namHienTai = now.getFullYear();
        const thangHienTai = now.getMonth() + 1;
        const ngayHienTai = now.getDate();

        let tuoi = namHienTai - namSinh;
        if (thangHienTai < thangSinh || (thangHienTai === thangSinh && ngayHienTai < ngaySinh)) {
            tuoi--;
        }

        if (tuoi < 18) {
            sectionGiamHo.classList.remove('d-none');
        } else {
            sectionGiamHo.classList.add('d-none');
            // Xóa giá trị khi ẩn
            const gh = document.getElementById('tn-giam-ho-moi-quan-he');
            const ghHoTen = document.getElementById('tn-giam-ho-ho-ten');
            const ghDt = document.getElementById('tn-giam-ho-dien-thoai');
            const ghCccd = document.getElementById('tn-giam-ho-cccd');
            if (gh) gh.value = '';
            if (ghHoTen) ghHoTen.value = '';
            if (ghDt) ghDt.value = '';
            if (ghCccd) ghCccd.value = '';
        }
    }

    async function loadDropdownData() {
        try {
            const [
                resGt,
                resQt,
                resDt,
                resNn,
                resTt,
                resCk
            ] = await Promise.all([
                apiGet('/api/danh_muc/gioi_tinh?top=20'),
                apiGet('/api/danh_muc/quoc_tich?top=100'),
                apiGet('/api/danh_muc/dan_toc?top=100'),
                apiGet('/api/danh_muc/nghe_nghiep?top=100'),
                apiGet('/api/danh_muc/tinh_thanh?top=100'),
                apiGet('/api/danh_muc/cong_kham')
            ]);

            if (resGt.status === 200 && Array.isArray(resGt.data) && tsGioiTinh) {
                tsGioiTinh.clearOptions();
                tsGioiTinh.addOptions(resGt.data);
                const macDinh = resGt.data.find(x => Number(x.id) === 1) || resGt.data[0];
                if (macDinh) tsGioiTinh.setValue(String(macDinh.id), true);
            }

            if (resQt.status === 200 && resQt.data && tsQuocTich) {
                tsQuocTich.clearOptions();
                tsQuocTich.addOptions(resQt.data);
                const vn = resQt.data.find(q => q.ma === 'VN' || q.ten?.toLowerCase().includes('việt nam'));
                if (vn) tsQuocTich.setValue(String(vn.id));
            }

            if (resDt.status === 200 && resDt.data && tsDanToc) {
                tsDanToc.clearOptions();
                tsDanToc.addOptions(resDt.data);
                const kinh = resDt.data.find(d => Number(d.id) === 1 || d.ma === '01' || d.ten?.toLowerCase() === 'kinh');
                const kinhId = kinh ? String(kinh.id) : '1';
                tsDanToc.setValue(kinhId);
            }

            if (resNn.status === 200 && resNn.data && tsNgheNghiep) {
                tsNgheNghiep.clearOptions();
                tsNgheNghiep.addOptions(resNn.data);
            }

            if (resTt.status === 200 && resTt.data && tsTinhThanh) {
                tsTinhThanh.clearOptions();
                tsTinhThanh.addOptions(resTt.data);
            }

            if (resCk.status === 200 && resCk.data) {
                allCongKhamAvailable = resCk.data;
                if (selectedCongKham.length === 0) {
                    const defaultCk = allCongKhamAvailable.find(c => c.id === 1) || allCongKhamAvailable[0];
                    if (defaultCk) {
                        themCongKham(defaultCk);
                        renderCongKhamPreview();
                    }
                }
            }
        } catch (err) {
            console.error('Lỗi nạp danh mục dropdown:', err);
        }
    }

    async function capNhatPhuongXaTheoTinh(idTinh, silent = false) {
        if (!tsPhuongXa) return;
        tsPhuongXa.clear(silent);
        tsPhuongXa.clearOptions();
        if (!idTinh) return;

        const resPx = await apiGet(`/api/danh_muc/phuong_xa?id_tinh=${idTinh}&top=1000`);
        if (resPx.status === 200 && resPx.data) {
            tsPhuongXa.addOptions(resPx.data);
            tsPhuongXa.refreshOptions(false);
        }
    }

    function tuDongGhepDiaChi() {
        const soNha = document.getElementById('tn-so-nha').value.trim();
        const tenPx = tsPhuongXa ? tsPhuongXa.getItem(tsPhuongXa.getValue())?.textContent?.trim() : '';
        const tenTt = tsTinhThanh ? tsTinhThanh.getItem(tsTinhThanh.getValue())?.textContent?.trim() : '';

        const parts = [];
        if (soNha) parts.push(soNha);
        if (tenPx && !tenPx.startsWith('--')) parts.push(tenPx);
        if (tenTt && !tenTt.startsWith('--')) parts.push(tenTt);

        if (parts.length > 0) {
            document.getElementById('tn-dia-chi').value = parts.join(', ');
        }
    }

    async function loadDanhSachTiepNhan(selectedIdVaoVienTarget = null) {
        const tuNgayRaw = document.getElementById('tn-filter-tu-ngay').value;
        const denNgayRaw = document.getElementById('tn-filter-den-ngay').value;
        const tuKhoa = document.getElementById('tn-filter-tu-khoa').value.trim();

        let daChuyenKham = null;
        // Khi có từ khóa tìm kiếm: KHÔNG lọc theo trạng thái chuyển khám hoặc ngày
        if (!tuKhoa) {
            const radStatus = document.querySelector('input[name="tn-filter-status"]:checked')?.value;
            if (radStatus === '0') daChuyenKham = false;
            else if (radStatus === '1') daChuyenKham = true;
        }

        const params = {
            tu_ngay: !tuKhoa ? parseDateVNToISO(tuNgayRaw) : null,
            den_ngay: !tuKhoa ? parseDateVNToISO(denNgayRaw) : null,
            da_chuyen_kham: daChuyenKham,
            tu_khoa: tuKhoa,
            trang: tnCurrentPage,
            kich_thuoc_trang: tnPageSize
        };

        const res = await withPageloader(() => apiGet('/api/tiep_nhan/danh_sach', params)
        );
        if (res.status !== 200 || !res.data) {
            tnDataList = [];
            tnServerTotal = 0;
        } else {
            tnDataList = res.data;
            tnServerTotal = tnDataList.length > 0 ? Number(tnDataList[0].TongSoDong || tnDataList.length) : 0;
        }

        // Nếu bộ lọc mới làm trang hiện tại vượt phạm vi, quay lại trang 1 và nạp lại đúng 1 lần.
        if (!tnDataList.length && tnCurrentPage > 1) {
            tnCurrentPage = 1;
            return loadDanhSachTiepNhan(selectedIdVaoVienTarget);
        }

        renderTableTiepNhan(selectedIdVaoVienTarget);
    }

    function renderTableTiepNhan(selectedIdVaoVienTarget = null) {
        const tbody = document.getElementById('tn-table-body');
        if (!tbody) return;
        tbody.innerHTML = '';

        if (!tnPagination) {
            tnPagination = createQLPMPagination({
                container: '#tn-pagination',
                tableScrollSelector: '.qlpm-table-container',
                itemName: 'BN',
                pageSize: tnPageSize,
                currentPage: tnCurrentPage,
                pageSizes: [10, 25, 50, 100],
                showCount: true,
                onPageChange: (newPage, newSize) => {
                    tnCurrentPage = newPage;
                    tnPageSize = newSize;
                    loadDanhSachTiepNhan(selectedVaoVienId);
                }
            });
        }

        if (!tnDataList || tnDataList.length === 0) {
            tbody.innerHTML = `<tr><td colspan="10" class="text-center text-muted py-4">Không có lượt tiếp nhận nào phù hợp.</td></tr>`;
            if (tnPagination) tnPagination.render(0, 1);
            return;
        }

        const total = tnServerTotal;
        if (tnPagination) {
            tnPagination.render(total, tnCurrentPage);
            tnPageSize = tnPagination.getPageSize();
            tnCurrentPage = tnPagination.getCurrentPage();
        }

        const startIdx = (tnCurrentPage - 1) * tnPageSize;
        const pageItems = tnDataList;

        const todayStr = formatDateVN(new Date());

        pageItems.forEach((item, index) => {
            const globalIndex = startIdx + index;
            const tr = document.createElement('tr');
            tr.setAttribute('data-id-vao-vien', item.IDVaoVien || '');
            tr.setAttribute('data-id-benh-nhan', item.IDBenhNhan || '');
            tr.dataset.item = JSON.stringify(item);

            // Trạng thái tiếp nhận: Chưa chuyển khám (xanh), Đã chuyển khám (đen)
            tr.className = item.DaChuyenKham
                ? 'tr-da-chuyen text-status-da-chuyen'
                : 'tr-chua-chuyen text-status-chua-chuyen';

            const isSelected = selectedIdVaoVienTarget && Number(item.IDVaoVien) === Number(selectedIdVaoVienTarget);
            const visitDateStr = formatDateVN(item.NgayGioVaoVien || item.Ngay);
            const isToday = Boolean(item.IDVaoVien) && (!visitDateStr || visitDateStr === todayStr);

            if (isSelected) {
                tr.classList.add('selected', 'table-active');
                const isCompletedVisit = Number(item.TrangThaiKham) === 2;
                const keepPatientEditMode = chiSuaThongTinBenhNhan
                    && Number(selectedVaoVienId) === Number(item.IDVaoVien);
                if (keepPatientEditMode || (isToday && !isCompletedVisit)) {
                    fillFormTiepNhan(item, keepPatientEditMode);
                } else {
                    fillOldPatientTiepNhan(item, isToday && isCompletedVisit);
                }
            }

            // Ghi chú bất kể loại nào (bệnh nhân hoặc lần khám)
            const gcBn = (item.GhiChuBenhNhan || '').trim();
            const gcLk = (item.GhiChuLanKham || '').trim();
            const hasNote = Boolean(gcBn) || Boolean(gcLk) || item.CoGhiChu === 1;

            let noteTooltip = '';
            if (gcBn && gcLk) {
                noteTooltip = `Ghi chú BN: ${gcBn}\nGhi chú khám: ${gcLk}`;
            } else if (gcBn) {
                noteTooltip = `Ghi chú BN: ${gcBn}`;
            } else if (gcLk) {
                noteTooltip = `Ghi chú khám: ${gcLk}`;
            } else if (hasNote) {
                noteTooltip = 'Có ghi chú';
            }

            const star = hasNote
                ? `<span class="star-note" data-bs-toggle="tooltip" data-bs-placement="top" title="${escapeHtml(noteTooltip)}">★</span>`
                : '';
            const oldBadge = !isToday
                ? `<span class="badge bg-secondary-subtle text-secondary ms-1 fw-normal font-monospace" style="font-size: 10px;">Cũ</span>`
                : '';
            const gioiTinhText = item.TenGioiTinh || '';
            const displayStt = item.SoThuTu != null ? item.SoThuTu : (total - globalIndex);

            tr.innerHTML = `
                <td class="text-center font-monospace col-stt">${displayStt}</td>
                <td class="text-nowrap sticky-col sticky-col-ten-bn"><span class="d-inline-flex align-items-center"><span class="fw-bold text-uppercase">${item.HoTen || ''}</span>${star}${oldBadge}</span></td>
                <td class="text-center text-nowrap col-ngay-tn">${formatDateVN(item.NgayGioVaoVien || item.Ngay) || '<span class="text-muted fst-italic">Chưa khám</span>'}</td>
                <td class="text-center text-nowrap col-ngay-sinh">${formatDateVN(item.NgaySinh)}</td>
                <td class="text-center text-nowrap col-gioi-tinh">${gioiTinhText}</td>
                <td class="text-nowrap col-cccd">${item.SoCCCD || ''}</td>
                <td class="text-nowrap col-sdt">${item.DienThoai || ''}</td>
                <td class="col-dia-chi" title="${escapeHtml(item.DiaChi || '')}">${escapeHtml(item.DiaChi || '')}</td>
                <td class="fw-bold col-ma-bn">${item.MaBN || ''}</td>
                <td class="text-center sticky-col sticky-col-tuy-chon" onclick="event.stopPropagation();">
                    <div class="dropdown">
                        <button class="btn btn-sm btn-light border py-0 px-1" data-bs-toggle="dropdown"><i class="bi bi-list"></i></button>
                        <ul class="dropdown-menu dropdown-menu-end shadow-sm small">
                            ${item.IDVaoVien && Number(item.TrangThaiKham) === 0 ? `<li><a class="dropdown-item text-danger" href="javascript:void(0)" onclick="boDangKyTiepNhan(${item.IDVaoVien})"><i class="bi bi-x-circle me-1"></i> Bỏ công khám</a></li>` : ''}
                            ${item.IDVaoVien && Number(item.TrangThaiKham) === 2 ? `<li><a class="dropdown-item" href="javascript:void(0)" onclick="suaThongTinBenhNhanDaKham(${item.IDVaoVien})"><i class="bi bi-pencil-square me-1"></i> Sửa thông tin BN</a></li>` : ''}
                            ${item.IDVaoVien ? `<li><a class="dropdown-item text-danger" href="javascript:void(0)" onclick="xoaTiepNhanTrongNgay(${item.IDVaoVien})"><i class="bi bi-trash me-1"></i> Xóa BN</a></li>` : `<li><a class="dropdown-item text-danger" href="javascript:void(0)" onclick="xoaHoSoBenhNhan(${item.IDBenhNhan})"><i class="bi bi-trash me-1"></i> Xóa hồ sơ BN</a></li>`}
                            <li><a class="dropdown-item" href="javascript:void(0)" onclick="xemGhiChu('${item.IDVaoVien || ''}', '${item.IDBenhNhan || ''}')"><i class="bi bi-chat-dots me-1"></i> Ghi chú</a></li>
                        </ul>
                    </div>
                </td>
            `;

            tr.addEventListener('click', () => {
                document.querySelectorAll('#tn-table-body tr').forEach(r => r.classList.remove('selected', 'table-active'));
                tr.classList.add('selected', 'table-active');
                const rowVisitDateStr = formatDateVN(item.NgayGioVaoVien || item.Ngay);
                const rowIsToday = !rowVisitDateStr || rowVisitDateStr === todayStr;
                const isCompletedVisit = Number(item.TrangThaiKham) === 2;
                if (rowIsToday && !isCompletedVisit) {
                    fillFormTiepNhan(item);
                } else {
                    fillOldPatientTiepNhan(item, rowIsToday && isCompletedVisit);
                }
            });

            tbody.appendChild(tr);
        });

        // Kích hoạt Bootstrap tooltips cho dấu sao ghi chú
        tbody.querySelectorAll('[data-bs-toggle="tooltip"]').forEach(el => {
            new bootstrap.Tooltip(el);
        });

        // Quản lý z-index khi mở dropdown để tránh bị hàng dưới che
        if (!tbody.dataset.dropdownEventsBound) {
            tbody.dataset.dropdownEventsBound = 'true';
            tbody.addEventListener('show.bs.dropdown', (e) => {
                const row = e.target.closest('tr');
                if (row) row.classList.add('table-dropdown-open');
            });
            tbody.addEventListener('hidden.bs.dropdown', (e) => {
                const row = e.target.closest('tr');
                if (row) row.classList.remove('table-dropdown-open');
            });
        }
    }

    function setTomSelectByTextOrValue(tsInstance, textOrVal, defaultVal = '', silent = false) {
        if (!tsInstance) return;
        if (!textOrVal) {
            if (defaultVal) {
                tsInstance.setValue(defaultVal, silent);
            } else {
                tsInstance.clear(silent);
            }
            return;
        }
        const strVal = String(textOrVal).trim();
        // Kiểm tra xem đã có option theo ID/value chưa
        if (tsInstance.options[strVal]) {
            tsInstance.setValue(strVal, silent);
            return;
        }
        // Kiểm tra theo text
        const matchedKey = Object.keys(tsInstance.options).find(k => {
            const opt = tsInstance.options[k];
            return opt && opt.ten && opt.ten.toLowerCase() === strVal.toLowerCase();
        });
        if (matchedKey) {
            tsInstance.setValue(matchedKey, silent);
        } else {
            // Thêm option mới nếu cho phép tự do
            tsInstance.addOption({ id: strVal, ma: strVal, ten: strVal });
            tsInstance.setValue(strVal, silent);
        }
    }

    function capNhatNutChuyenKham(daChuyenKham = false) {
        const btnChuyen = document.getElementById('btn-tn-chuyen-kham');
        if (!btnChuyen) return;

        if (daChuyenKham) {
            btnChuyen.disabled = true;
            btnChuyen.innerHTML = '<i class="bi bi-check2-all me-1"></i> Đã chuyển khám';
            btnChuyen.classList.replace('btn-chuyen-kham', 'btn-secondary');
            btnChuyen.title = 'Lượt khám đã được chuyển';
            return;
        }

        const coIdVaoVien = Number(document.getElementById('tn-id-vao-vien')?.value || 0) > 0;
        const coCongKham = selectedCongKham.length > 0;
        const coTheChuyen = tiepNhanDaLuu && coIdVaoVien && coCongKham;

        btnChuyen.disabled = !coTheChuyen;
        btnChuyen.innerHTML = '<i class="bi bi-arrow-right-circle-fill me-1"></i> Chuyển khám';
        btnChuyen.classList.replace('btn-secondary', 'btn-chuyen-kham');

        if (!tiepNhanDaLuu || !coIdVaoVien) {
            btnChuyen.title = 'Phải bấm Lưu tiếp nhận trước khi chuyển khám';
        } else if (!coCongKham) {
            btnChuyen.title = 'Phải có ít nhất 1 công khám đã lưu';
        } else {
            btnChuyen.title = 'Chuyển sang phòng khám';
        }
    }

    function danhDauTiepNhanChuaLuu() {
        if (dangNapFormTiepNhan || !tiepNhanDaLuu) return;
        tiepNhanDaLuu = false;
        capNhatNutChuyenKham(chiSuaThongTinBenhNhan && selectedDaChuyenKham);
    }

    function capNhatCheDoChiSuaThongTinBenhNhan(chiSua) {
        const btnCongKham = document.getElementById('btn-mo-modal-cong-kham');
        if (btnCongKham) {
            btnCongKham.disabled = chiSua;
            btnCongKham.title = chiSua ? 'Lượt đã chuyển khám: công khám được giữ nguyên.' : '';
        }

        const stt = document.getElementById('tn-stt-ngay');
        if (stt) stt.readOnly = chiSua;

        const ghiChuLanKham = document.getElementById('tn-ghi-chu-lan-kham');
        if (ghiChuLanKham) ghiChuLanKham.readOnly = chiSua;
    }

    function fillFormTiepNhan(item, forcePatientOnly = false) {
        dangNapFormTiepNhan = true;
        tiepNhanDaLuu = true;
        selectedDaChuyenKham = Boolean(item.DaChuyenKham);
        selectedTrangThaiKham = Number(item.TrangThaiKham || 0);
        chiSuaThongTinBenhNhan = Boolean(forcePatientOnly || selectedDaChuyenKham || selectedTrangThaiKham === 1);
        capNhatCheDoChiSuaThongTinBenhNhan(chiSuaThongTinBenhNhan);
        selectedVaoVienId = item.IDVaoVien;
        document.getElementById('tn-id-benh-nhan').value = item.IDBenhNhan || '';
        document.getElementById('tn-id-vao-vien').value = item.IDVaoVien || '';
        document.getElementById('tn-stt-ngay').value = item.SoThuTu || '';
        document.getElementById('tn-ma-bn').value = item.MaBN || '';
        document.getElementById('tn-ho-ten').value = item.HoTen || '';
        setNgaySinhValue(formatDateVN(item.NgaySinh) || '__-__-____');
        document.getElementById('tn-dien-thoai').value = item.DienThoai || '';
        document.getElementById('tn-cccd').value = item.SoCCCD || '';
        document.getElementById('tn-dia-chi').value = item.DiaChi || '';
        document.getElementById('tn-ghi-chu-bn').value = item.GhiChuBenhNhan || '';
        document.getElementById('tn-ghi-chu-lan-kham').value = item.GhiChuLanKham || '';

        if (tsGioiTinh) tsGioiTinh.setValue(String(item.IDGioiTinh ?? 1), true);
        if (tsDanToc) tsDanToc.setValue(String(item.IDDanToc || 1), true);
        setTomSelectByTextOrValue(tsQuocTich, item.QuocTich, '1', true);
        setTomSelectByTextOrValue(tsNgheNghiep, item.NgheNghiep, '', true);

        if (item.SoNhaTenDuong) document.getElementById('tn-so-nha').value = item.SoNhaTenDuong;
        if (tsTinhThanh) {
            if (item.IDTinhThanh) {
                tsTinhThanh.setValue(item.IDTinhThanh, true);
                capNhatPhuongXaTheoTinh(item.IDTinhThanh, true).then(() => {
                    if (tsPhuongXa && item.IDPhuongXa) tsPhuongXa.setValue(item.IDPhuongXa, true);
                });
            } else {
                tsTinhThanh.clear();
                if (tsPhuongXa) { tsPhuongXa.clear(); tsPhuongXa.clearOptions(); }
            }
        }

        // Điền thông tin giám hộ
        const ghMqh = document.getElementById('tn-giam-ho-moi-quan-he');
        const ghHoTen = document.getElementById('tn-giam-ho-ho-ten');
        const ghDt = document.getElementById('tn-giam-ho-dien-thoai');
        const ghCccd = document.getElementById('tn-giam-ho-cccd');
        if (ghMqh) ghMqh.value = item.GiamHo_MoiQuanHe || '';
        if (ghHoTen) ghHoTen.value = item.GiamHo_HoTen || '';
        if (ghDt) ghDt.value = item.GiamHo_DienThoai || '';
        if (ghCccd) ghCccd.value = item.GiamHo_SoCCCD || '';
        kiemTraVaHienThiGiamHo();

        // Chỉ sáng Chuyển khám sau khi xác nhận lượt đã lưu và có công khám trong DB.
        selectedCongKham = [];
        renderCongKhamPreview();
        capNhatNutChuyenKham(Boolean(item.DaChuyenKham));

        const badgeBnCu = document.getElementById('tn-badge-bn-cu');
        if (badgeBnCu) badgeBnCu.classList.add('d-none');

        // Tự động tải công khám của lượt khám
        if (item.IDVaoVien) {
            apiGet(`/api/tiep_nhan/danh_sach_cong_kham?id_vao_vien=${item.IDVaoVien}`).then(resCk => {
                if (resCk.status === 200 && Array.isArray(resCk.data)) {
                    selectedCongKham = resCk.data.map(c => ({
                        IDDichVu: c.IDDichVu || c.id_dich_vu,
                        TenDichVu: c.TenDichVu || c.ten_dich_vu,
                        SoLuong: c.SoLuong || c.so_luong || 1,
                        DonGia: c.DonGia || c.don_gia || 0
                    }));
                    renderCongKhamPreview();
                    capNhatNutChuyenKham(Boolean(item.DaChuyenKham));
                }
            }).catch(e => console.warn('Lỗi nạp công khám:', e));
        } else {
            renderCongKhamPreview();
        }

        dangNapFormTiepNhan = false;
    }

    function fillOldPatientTiepNhan(item, isSameDayReturn = false) {
        dangNapFormTiepNhan = true;
        tiepNhanDaLuu = false;
        selectedVaoVienId = null;
        selectedDaChuyenKham = false;
        selectedTrangThaiKham = 0;
        chiSuaThongTinBenhNhan = false;
        capNhatCheDoChiSuaThongTinBenhNhan(false);
        document.getElementById('tn-id-benh-nhan').value = item.IDBenhNhan || '';
        document.getElementById('tn-id-vao-vien').value = '';
        document.getElementById('tn-stt-ngay').value = '';
        document.getElementById('tn-ma-bn').value = item.MaBN || '';
        document.getElementById('tn-ho-ten').value = item.HoTen || '';
        setNgaySinhValue(formatDateVN(item.NgaySinh) || '__-__-____');
        document.getElementById('tn-dien-thoai').value = item.DienThoai || '';
        document.getElementById('tn-cccd').value = item.SoCCCD || '';
        document.getElementById('tn-so-nha').value = item.SoNhaTenDuong || '';
        document.getElementById('tn-dia-chi').value = item.DiaChi || '';
        document.getElementById('tn-ghi-chu-bn').value = item.GhiChuBenhNhan || '';
        document.getElementById('tn-ghi-chu-lan-kham').value = '';

        if (tsGioiTinh) tsGioiTinh.setValue(String(item.IDGioiTinh ?? 1), true);
        if (tsDanToc) tsDanToc.setValue(String(item.IDDanToc || 1));
        setTomSelectByTextOrValue(tsQuocTich, item.QuocTich, '1');
        setTomSelectByTextOrValue(tsNgheNghiep, item.NgheNghiep, '');

        if (item.SoNhaTenDuong) document.getElementById('tn-so-nha').value = item.SoNhaTenDuong;
        if (tsTinhThanh) {
            if (item.IDTinhThanh) {
                tsTinhThanh.setValue(item.IDTinhThanh);
                capNhatPhuongXaTheoTinh(item.IDTinhThanh).then(() => {
                    if (tsPhuongXa && item.IDPhuongXa) tsPhuongXa.setValue(item.IDPhuongXa);
                });
            } else {
                tsTinhThanh.clear();
                if (tsPhuongXa) { tsPhuongXa.clear(); tsPhuongXa.clearOptions(); }
            }
        }

        // Điền thông tin giám hộ
        const ghMqh = document.getElementById('tn-giam-ho-moi-quan-he');
        const ghHoTen = document.getElementById('tn-giam-ho-ho-ten');
        const ghDt = document.getElementById('tn-giam-ho-dien-thoai');
        const ghCccd = document.getElementById('tn-giam-ho-cccd');
        if (ghMqh) ghMqh.value = item.GiamHo_MoiQuanHe || '';
        if (ghHoTen) ghHoTen.value = item.GiamHo_HoTen || '';
        if (ghDt) ghDt.value = item.GiamHo_DienThoai || '';
        if (ghCccd) ghCccd.value = item.GiamHo_SoCCCD || '';
        kiemTraVaHienThiGiamHo();

        // Hiển thị badge BN cũ
        const badgeBnCu = document.getElementById('tn-badge-bn-cu');
        if (badgeBnCu) badgeBnCu.classList.remove('d-none');

        // Khởi tạo công khám mặc định cho lượt tiếp nhận mới hôm nay
        selectedCongKham = [];
        if (allCongKhamAvailable.length > 0) {
            const defaultCk = allCongKhamAvailable.find(c => c.id === 1) || allCongKhamAvailable[0];
            if (defaultCk) themCongKham(defaultCk);
        }
        renderCongKhamPreview();

        // Lượt mới chưa lưu: Chuyển khám luôn mờ dù đã chọn công khám.
        capNhatNutChuyenKham(false);

        dangNapFormTiepNhan = false;

        if (isSameDayReturn) {
            showToast('info', `BN ${item.HoTen} đã khám hôm nay. Đang tạo lượt mới; hồ sơ cũ được giữ nguyên.`);
        } else {
            showToast('info', `Đã nạp hồ sơ ${item.HoTen}. Chọn công khám rồi bấm Lưu.`);
        }
    }

    function resetFormTiepNhan() {
        dangNapFormTiepNhan = true;
        tiepNhanDaLuu = false;
        selectedVaoVienId = null;
        selectedDaChuyenKham = false;
        selectedTrangThaiKham = 0;
        chiSuaThongTinBenhNhan = false;
        capNhatCheDoChiSuaThongTinBenhNhan(false);
        document.getElementById('tn-id-benh-nhan').value = '';
        document.getElementById('tn-id-vao-vien').value = '';
        document.getElementById('tn-stt-ngay').value = '';
        document.getElementById('tn-ma-bn').value = '';
        document.getElementById('tn-ho-ten').value = '';
        setNgaySinhValue('__-__-____');
        document.getElementById('tn-dien-thoai').value = '';
        document.getElementById('tn-cccd').value = '';
        document.getElementById('tn-so-nha').value = '';
        document.getElementById('tn-dia-chi').value = '';
        document.getElementById('tn-ghi-chu-bn').value = '';
        document.getElementById('tn-ghi-chu-lan-kham').value = '';

        if (tsGioiTinh) tsGioiTinh.setValue('1', true);
        if (tsDanToc) tsDanToc.setValue('1');
        if (tsQuocTich) tsQuocTich.setValue('1');
        if (tsNgheNghiep) tsNgheNghiep.clear();
        if (tsTinhThanh) tsTinhThanh.clear();
        if (tsPhuongXa) { tsPhuongXa.clear(); tsPhuongXa.clearOptions(); }

        // Reset giám hộ
        const ghMqh = document.getElementById('tn-giam-ho-moi-quan-he');
        const ghHoTen = document.getElementById('tn-giam-ho-ho-ten');
        const ghDt = document.getElementById('tn-giam-ho-dien-thoai');
        const ghCccd = document.getElementById('tn-giam-ho-cccd');
        if (ghMqh) ghMqh.value = '';
        if (ghHoTen) ghHoTen.value = '';
        if (ghDt) ghDt.value = '';
        if (ghCccd) ghCccd.value = '';
        const sectionGiamHo = document.getElementById('section-giam-ho');
        if (sectionGiamHo) sectionGiamHo.classList.add('d-none');

        selectedCongKham = [];
        if (allCongKhamAvailable.length > 0) {
            const defaultCk = allCongKhamAvailable.find(c => c.id === 1) || allCongKhamAvailable[0];
            if (defaultCk) themCongKham(defaultCk);
        }
        renderCongKhamPreview();

        capNhatNutChuyenKham(false);

        const badgeBnCu = document.getElementById('tn-badge-bn-cu');
        if (badgeBnCu) badgeBnCu.classList.add('d-none');

        dangNapFormTiepNhan = false;
        document.getElementById('tn-ho-ten').focus();
    }

    function renderCongKhamPreview() {
        const tomTat = document.getElementById('tn-cong-kham-tom-tat');
        if (!tomTat) return;
        if (selectedCongKham.length === 0) {
            tomTat.textContent = 'Công khám';
            return;
        }
        tomTat.textContent = selectedCongKham.length === 1
            ? selectedCongKham[0].TenDichVu
            : `${selectedCongKham.length} công khám đã chọn`;
    }

    function openModalCongKham() {
        if (chiSuaThongTinBenhNhan) {
            showToast('info', 'Lượt đã chuyển khám: công khám được giữ nguyên.');
            return;
        }
        const modalEl = document.getElementById('modalCongKham');
        const bsModal = new bootstrap.Modal(modalEl);
        const tenBenhNhan = document.getElementById('tn-ho-ten')?.value.trim();
        document.getElementById('modal-ck-ten-benh-nhan').textContent = tenBenhNhan || 'Chưa chọn bệnh nhân';

        renderAvailableCongKhamList();
        renderSelectedCongKhamListModal();

        bsModal.show();
    }

    function renderAvailableCongKhamList(searchQuery = '') {
        const container = document.getElementById('modal-ck-available-list');
        container.innerHTML = '';

        const q = searchQuery.toLowerCase().trim();
        const filtered = allCongKhamAvailable.filter(ck => {
            if (!q) return true;
            return ck.ten.toLowerCase().includes(q) || ck.ma.toLowerCase().includes(q);
        });

        if (filtered.length === 0) {
            container.innerHTML = `<div class="text-muted p-2 text-center small">Không tìm thấy công khám nào.</div>`;
            return;
        }

        filtered.forEach(ck => {
            const isAdded = selectedCongKham.some(s => s.IDDichVu === ck.id);
            const div = document.createElement('div');
            div.className = 'd-flex justify-content-between align-items-center p-2 border-bottom hover-bg';
            div.innerHTML = `
                <div>
                    <strong>${ck.ten}</strong>
                    <div class="small text-muted">${Number(ck.don_gia || 0).toLocaleString('vi-VN')} đ / ${ck.don_vi_tinh || 'Lần'}</div>
                </div>
                <button type="button" class="btn btn-sm ${isAdded ? 'btn-secondary disabled' : 'btn-outline-primary'}" ${isAdded ? 'disabled' : ''}>
                    <i class="bi bi-plus-lg"></i>
                </button>
            `;
            div.querySelector('button').addEventListener('click', () => {
                themCongKham(ck);
                danhDauTiepNhanChuaLuu();
                renderAvailableCongKhamList(searchQuery);
                renderSelectedCongKhamListModal();
            });
            container.appendChild(div);
        });
    }

    function renderSelectedCongKhamListModal() {
        const tbody = document.getElementById('modal-ck-selected-body');
        tbody.innerHTML = '';

        if (selectedCongKham.length === 0) {
            tbody.innerHTML = `<tr><td colspan="3" class="text-center text-muted py-3">Chưa chọn công khám nào.</td></tr>`;
            return;
        }

        selectedCongKham.forEach((ck, idx) => {
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td><strong>${ck.TenDichVu}</strong></td>
                <td class="text-end">${Number(ck.DonGia || 0).toLocaleString('vi-VN')} đ</td>
                <td class="text-center">
                    <button type="button" class="btn btn-sm btn-link text-danger p-0" title="Xóa"><i class="bi bi-trash3-fill"></i></button>
                </td>
            `;
            tr.querySelector('button').addEventListener('click', () => {
                selectedCongKham.splice(idx, 1);
                danhDauTiepNhanChuaLuu();
                renderAvailableCongKhamList(document.getElementById('modal-ck-search').value);
                renderSelectedCongKhamListModal();
            });
            tbody.appendChild(tr);
        });
    }

    function themCongKham(ck) {
        if (selectedCongKham.some(s => s.IDDichVu === ck.id)) return;
        selectedCongKham.push({
            IDDichVu: ck.id,
            TenDichVu: ck.ten,
            SoLuong: 1,
            DonGia: ck.don_gia || 0
        });
    }

    const tnEnterFlow = [
        'tn-stt-ngay',
        'tn-ho-ten',
        'tn-ngay-sinh',
        'tn-gioi-tinh',
        'tn-quoc-tich',
        'tn-dan-toc',
        'tn-nghe-nghiep',
        'tn-dien-thoai',
        'tn-cccd',
        'tn-so-nha',
        'tn-tinh-thanh',
        'tn-phuong-xa',
        'tn-dia-chi',
        'tn-giam-ho-moi-quan-he',
        'tn-giam-ho-ho-ten',
        'tn-giam-ho-dien-thoai',
        'tn-giam-ho-cccd'
    ];

    function tomSelectTheoId(id) {
        switch (id) {
            case 'tn-gioi-tinh': return tsGioiTinh;
            case 'tn-quoc-tich': return tsQuocTich;
            case 'tn-dan-toc': return tsDanToc;
            case 'tn-nghe-nghiep': return tsNgheNghiep;
            case 'tn-tinh-thanh': return tsTinhThanh;
            case 'tn-phuong-xa': return tsPhuongXa;
            default: return null;
        }
    }

    function tomSelectDangFocus(ts) {
        if (!ts) return false;
        const active = document.activeElement;
        return active === ts.control_input || ts.control?.contains(active);
    }

    function controlCoTheFocus(id) {
        const el = document.getElementById(id);
        if (!el || el.disabled || el.readOnly) return false;
        if (el.closest('.d-none') || el.hidden) return false;
        return true;
    }

    function focusControl(id) {
        if (!controlCoTheFocus(id)) return false;
        const ts = tomSelectTheoId(id);
        if (ts) {
            ts.focus();
            return true;
        }

        const el = document.getElementById(id);
        el?.focus();
        if (el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') && typeof el.select === 'function') {
            el.select();
        }
        return Boolean(el);
    }

    function focusTiepTheo(idHienTai) {
        const index = tnEnterFlow.indexOf(idHienTai);
        for (let i = index + 1; i < tnEnterFlow.length; i++) {
            if (focusControl(tnEnterFlow[i])) return;
        }
        document.getElementById('btn-mo-modal-cong-kham')?.focus();
    }

    function bindEnterNavigation() {
        tnEnterFlow.forEach(id => {
            const el = document.getElementById(id);
            const ts = tomSelectTheoId(id);

            if (ts) {
                const tsInput = ts.control_input;
                tsInput?.addEventListener('keydown', e => {
                    if (!['Enter', 'Tab'].includes(e.key) || e.shiftKey || e.ctrlKey || e.altKey) return;

                    // Bắt trạng thái dropdown trước handler nội bộ của TomSelect:
                    // Enter/Tab khi dropdown đang mở chỉ dùng để chọn/đóng option, không được nhảy ô.
                    if (ts.isOpen) return;

                    e.preventDefault();
                    e.stopImmediatePropagation();
                    focusTiepTheo(id);
                }, true);
                return;
            }

            el?.addEventListener('keydown', e => {
                if (!['Enter', 'Tab'].includes(e.key) || e.shiftKey || e.ctrlKey || e.altKey) return;
                e.preventDefault();
                if (id === 'tn-ngay-sinh') kiemTraVaHienThiGiamHo();
                focusTiepTheo(id);
            });
        });
    }

    function bindEvents() {
        bindEnterNavigation();

        const formTiepNhan = document.getElementById('tn-form');
        const danhDauNeuSuaForm = (e) => {
            const el = e.target;
            if (!el || el.type === 'hidden' || el.readOnly || el.disabled) return;
            danhDauTiepNhanChuaLuu();
        };
        formTiepNhan?.addEventListener('input', danhDauNeuSuaForm);
        formTiepNhan?.addEventListener('change', danhDauNeuSuaForm);

        document.getElementById('btn-tn-reload').addEventListener('click', () => loadDanhSachTiepNhan(selectedVaoVienId));
        document.getElementById('btn-tn-tim-kiem').addEventListener('click', () => loadDanhSachTiepNhan());
        document.getElementById('tn-filter-tu-khoa').addEventListener('keyup', (e) => {
            if (e.key === 'Enter') loadDanhSachTiepNhan();
        });

        document.getElementById('btn-tn-tao-moi').addEventListener('click', resetFormTiepNhan);


        document.getElementById('btn-mo-modal-cong-kham').addEventListener('click', openModalCongKham);
        document.getElementById('modal-ck-search').addEventListener('input', (e) => {
            renderAvailableCongKhamList(e.target.value);
        });

        document.getElementById('btn-modal-ck-xac-nhan').addEventListener('click', () => {
            renderCongKhamPreview();
            const modalEl = document.getElementById('modalCongKham');
            const bsModal = bootstrap.Modal.getInstance(modalEl);
            if (bsModal) bsModal.hide();
        });

        document.getElementById('tn-so-nha').addEventListener('input', tuDongGhepDiaChi);

        // Ràng buộc giới hạn số điện thoại max 10 số, CCCD max 12 số, STT số
        document.getElementById('tn-dien-thoai').addEventListener('input', (e) => {
            e.target.value = e.target.value.replace(/\D/g, '').slice(0, 10);
        });

        document.getElementById('tn-cccd').addEventListener('input', (e) => {
            e.target.value = e.target.value.replace(/\D/g, '').slice(0, 12);
        });

        // Giám hộ: giới hạn số ký tự
        document.getElementById('tn-giam-ho-dien-thoai')?.addEventListener('input', (e) => {
            e.target.value = e.target.value.replace(/\D/g, '').slice(0, 10);
        });
        document.getElementById('tn-giam-ho-cccd')?.addEventListener('input', (e) => {
            e.target.value = e.target.value.replace(/\D/g, '').slice(0, 12);
        });

        document.getElementById('tn-stt-ngay').addEventListener('input', (e) => {
            e.target.value = e.target.value.replace(/\D/g, '');
        });

        // Xử lý nút xóa liên kết BN cũ trên badge
        const badgeBnCu = document.getElementById('tn-badge-bn-cu');
        if (badgeBnCu) {
            badgeBnCu.addEventListener('click', (e) => {
                e.stopPropagation();
                document.getElementById('tn-id-benh-nhan').value = '';
                document.getElementById('tn-ma-bn').value = '';
                badgeBnCu.classList.add('d-none');
                showToast('info', 'Đã chuyển sang nhập bệnh nhân mới.');
            });
        }

        // Nút Lưu tiếp nhận (Section 9.2)
        document.getElementById('btn-tn-luu').addEventListener('click', async () => {
            const hoTen = document.getElementById('tn-ho-ten').value.trim();
            if (!hoTen) {
                showToast('warning', 'Nhập họ tên bệnh nhân.');
                document.getElementById('tn-ho-ten').focus();
                return;
            }

            const elNgaySinh = document.getElementById('tn-ngay-sinh');
            const ketQuaNgaySinh = kiemTraNgaySinhNhapLieu(elNgaySinh?.value);
            const loiMaskNgaySinh = elNgaySinh?.validationMessage || '';
            if (!ketQuaNgaySinh.hopLe || loiMaskNgaySinh) {
                const message = loiMaskNgaySinh || ketQuaNgaySinh.message;
                showToast('warning', message || 'Ngày sinh không hợp lệ.');
                elNgaySinh?.focus();
                elNgaySinh?.reportValidity();
                return;
            }
            elNgaySinh?.setCustomValidity('');

            if (!chiSuaThongTinBenhNhan && selectedCongKham.length === 0) {
                showToast('warning', 'Chọn ít nhất một công khám.');
                openModalCongKham();
                return;
            }

            const currentIdVv = document.getElementById('tn-id-vao-vien').value ? Number(document.getElementById('tn-id-vao-vien').value) : null;
            const sttVal = document.getElementById('tn-stt-ngay').value.trim();
            const payload = {
                id_benh_nhan: document.getElementById('tn-id-benh-nhan').value ? Number(document.getElementById('tn-id-benh-nhan').value) : null,
                id_vao_vien: currentIdVv,
                so_thu_tu: sttVal ? parseInt(sttVal, 10) : null,
                ho_ten: hoTen,
                ngay_sinh: ketQuaNgaySinh.iso,
                    id_gioi_tinh: tsGioiTinh && tsGioiTinh.getValue() ? Number(tsGioiTinh.getValue()) : 1,
                so_cccd: document.getElementById('tn-cccd').value.trim() || null,
                dien_thoai: document.getElementById('tn-dien-thoai').value.trim() || null,
                so_nha_ten_duong: document.getElementById('tn-so-nha').value.trim() || null,
                id_phuong_xa: tsPhuongXa && tsPhuongXa.getValue() ? Number(tsPhuongXa.getValue()) : null,
                id_tinh_thanh: tsTinhThanh && tsTinhThanh.getValue() ? Number(tsTinhThanh.getValue()) : null,
                dia_chi: document.getElementById('tn-dia-chi').value.trim() || null,
                id_dan_toc: tsDanToc && tsDanToc.getValue() ? Number(tsDanToc.getValue()) : null,
                quoc_tich: tsQuocTich && tsQuocTich.getValue() ? (tsQuocTich.getItem(tsQuocTich.getValue())?.textContent?.trim() || tsQuocTich.getValue()) : 'Việt Nam',
                nghe_nghiep: tsNgheNghiep && tsNgheNghiep.getValue() ? (tsNgheNghiep.getItem(tsNgheNghiep.getValue())?.textContent?.trim() || tsNgheNghiep.getValue()) : null,
                ghi_chu_benh_nhan: document.getElementById('tn-ghi-chu-bn').value.trim() || null,
                ghi_chu_lan_kham: document.getElementById('tn-ghi-chu-lan-kham').value.trim() || null,
                cong_kham: chiSuaThongTinBenhNhan ? null : selectedCongKham,
                chi_sua_thong_tin_benh_nhan: chiSuaThongTinBenhNhan,
                // Lưu tiếp nhận phải tạo lượt và MaVaoVien mới khi form chưa có lượt hôm nay.
                // IDBenhNhan/MaBN vẫn được giữ nguyên nếu đây là bệnh nhân quay lại.
                tao_vao_vien: !currentIdVv,
                chuyen_kham: false,
                giam_ho_moi_quan_he: document.getElementById('tn-giam-ho-moi-quan-he')?.value || null,
                giam_ho_ho_ten: document.getElementById('tn-giam-ho-ho-ten')?.value.trim() || null,
                giam_ho_dien_thoai: document.getElementById('tn-giam-ho-dien-thoai')?.value.trim() || null,
                giam_ho_so_cccd: document.getElementById('tn-giam-ho-cccd')?.value.trim() || null,
                bo_qua_canh_bao_trung: false
            };

            let res = await apiPost('/api/tiep_nhan/luu', payload);

            // CHAC: trùng CCCD xác định, SQL không cho phép tạo hồ sơ mới.
            // Không gửi lại với bo_qua_canh_bao_trung, vì cờ này chỉ dành cho mức CAO.
            if (res.status === 409 && res.data?.muc_do_trung === 'CHAC') {
                const idDaCo = Number(res.data?.id_benh_nhan);
                if (!Number.isSafeInteger(idDaCo) || idDaCo <= 0) {
                    showToast('warning', res.message || 'CCCD đã thuộc hồ sơ khác. Hãy kiểm tra trước khi lưu.');
                    document.getElementById('tn-cccd')?.focus();
                    return;
                }

                try {
                    const ketQuaHoSo = await apiGet(`/api/tiep_nhan/benh_nhan/${encodeURIComponent(idDaCo)}`);
                    if (ketQuaHoSo.status !== 200 || !ketQuaHoSo.data)
                        throw new Error(ketQuaHoSo.message || 'Không tải được hồ sơ trùng CCCD.');

                    const hoSo = ketQuaHoSo.data;
                    const cccd = String(hoSo.SoCCCD || '');
                    const cccdAn = cccd.length >= 4 ? '***' + cccd.slice(-4) : 'Chưa có';
                    const dongY = await window.hien_thi_xac_nhan({
                        tieu_de: 'CCCD đã tồn tại — kiểm tra hồ sơ bệnh nhân',
                        noi_dung: `CCCD này đã thuộc hồ sơ: ${hoSo.MaBN || ('ID ' + idDaCo)} — ${hoSo.HoTen || ''}; ngày sinh: ${formatDateVN(hoSo.NgaySinh) || 'Chưa có'}; CCCD: ${cccdAn}.\nNếu đúng người bệnh, chọn “Dùng hồ sơ này”. Nếu khác người, chọn “Sửa CCCD” và kiểm tra lại trước khi lưu. Không tự thay đổi hồ sơ cũ.`,
                        nhan_dong_y: 'Dùng hồ sơ này',
                        nhan_khong: 'Sửa CCCD',
                        lop_nut: 'btn-primary'
                    });
                    if (!dongY) {
                        document.getElementById('tn-cccd')?.focus();
                        return;
                    }

                    // Nạp chính thông tin của bệnh nhân đã có; không gán ID cũ
                    // vào dữ liệu người khác vừa nhập hoặc tự lưu đè hồ sơ.
                    const congKhamDangChon = [...selectedCongKham];
                    fillOldPatientTiepNhan(hoSo);
                    if (congKhamDangChon.length) {
                        selectedCongKham = congKhamDangChon;
                        renderCongKhamPreview();
                    }
                    showToast('info', 'Đã chọn hồ sơ hiện có. Kiểm tra thông tin, rồi bấm Lưu để tạo lượt tiếp nhận.');
                } catch (error) {
                    showToast('error', error.message || 'Không kiểm tra được hồ sơ trùng CCCD.');
                }
                return;
            }

            if (res.status === 409 && res.data?.canh_bao_trung === true) {
                const dongY = await window.hien_thi_xac_nhan({
                    tieu_de: 'Phát hiện hồ sơ bệnh nhân có thể trùng',
                    noi_dung: res.message || 'Thông tin bệnh nhân rất giống hồ sơ đã có. Hãy kiểm tra hồ sơ cũ trước khi quyết định tạo mới.',
                    nhan_dong_y: 'Vẫn tạo hồ sơ mới',
                    nhan_khong: 'Không, để kiểm tra',
                    lop_nut: 'btn-warning'
                });
                if (!dongY) return;

                payload.bo_qua_canh_bao_trung = true;
                res = await apiPost('/api/tiep_nhan/luu', payload);
            }

            if (res.status === 409 && res.data?.id_vao_vien && res.data?.canh_bao_trung !== true) {
                const existingIdVaoVien = Number(res.data.id_vao_vien);
                const today = formatDateVN(new Date());

                document.getElementById('tn-filter-tu-khoa').value = '';
                document.getElementById('tn-filter-tu-ngay').value = today;
                document.getElementById('tn-filter-den-ngay').value = today;
                document.getElementById('tn-rad-tat-ca').checked = true;

                await loadDanhSachTiepNhan(existingIdVaoVien);
                showToast('warning', res.message || 'BN còn lượt khám chưa xong. Hãy tiếp tục lượt đó.');
                return;
            }

            if (res.status === 200) {
                if (res.data?.id_benh_nhan) {
                    document.getElementById('tn-id-benh-nhan').value = res.data.id_benh_nhan;
                }

                if (chiSuaThongTinBenhNhan && currentIdVv) {
                    document.getElementById('tn-id-vao-vien').value = currentIdVv;
                    tiepNhanDaLuu = true;
                    selectedVaoVienId = currentIdVv;
                    capNhatNutChuyenKham(selectedDaChuyenKham);
                    await loadDanhSachTiepNhan(currentIdVv);
                    showToast('success', res.message || 'Đã cập nhật thông tin bệnh nhân.');
                    return;
                }

                if (!res.data?.id_vao_vien) {
                    document.getElementById('tn-id-vao-vien').value = '';
                    showToast('error', 'Đã lưu hồ sơ nhưng chưa tạo được lượt khám.');
                    return;
                }

                const newVaoVienId = res.data.id_vao_vien;
                document.getElementById('tn-id-vao-vien').value = newVaoVienId;
                tiepNhanDaLuu = true;
                capNhatNutChuyenKham(false);

                // Quay đúng về danh sách Chưa chuyển của hôm nay, không giữ nhánh tìm kiếm BN cũ.
                const today = formatDateVN(new Date());
                document.getElementById('tn-filter-tu-khoa').value = '';
                document.getElementById('tn-filter-tu-ngay').value = today;
                document.getElementById('tn-filter-den-ngay').value = today;
                document.getElementById('tn-rad-chua-chuyen').checked = true;

                await loadDanhSachTiepNhan(newVaoVienId);
                showToast('success', res.message || 'Đã lưu tiếp nhận.');
            } else {
                showToast('error', res.message || 'Không lưu được tiếp nhận.');
            }
        });

        // Nút Chuyển khám (Section 9.3)
        document.getElementById('btn-tn-chuyen-kham').addEventListener('click', async () => {
            const idVaoVien = document.getElementById('tn-id-vao-vien').value;
            if (!idVaoVien) {
                showToast('warning', 'Chọn hoặc lưu lượt khám trước khi chuyển.');
                return;
            }

            const res = await apiPost('/api/tiep_nhan/chuyen_kham', {
                id_vao_vien: Number(idVaoVien)
            });

            if (res.status === 409 && res.data?.id_vao_vien && Number(res.data.id_vao_vien) !== Number(idVaoVien)) {
                const existingIdVaoVien = Number(res.data.id_vao_vien);
                const today = formatDateVN(new Date());

                document.getElementById('tn-filter-tu-khoa').value = '';
                document.getElementById('tn-filter-tu-ngay').value = today;
                document.getElementById('tn-filter-den-ngay').value = today;
                document.getElementById('tn-rad-tat-ca').checked = true;

                await loadDanhSachTiepNhan(existingIdVaoVien);
                showToast('warning', res.message || 'BN còn lượt khám chưa xong. Hãy tiếp tục lượt đó.');
                return;
            }

            if (res.status === 200) {
                const coQuyenKhamBenh = res.data?.co_quyen_kham_benh === true;
                if (coQuyenKhamBenh) {
                    showToast('success', res.message || 'Đã chuyển BN sang khám.');
                    setTimeout(() => {
                        window.location.href = `/kham_benh?id_vao_vien=${idVaoVien}`;
                    }, 600);
                } else {
                    showToast('success', res.message || 'Đã chuyển khám.');
                    document.getElementById('tn-rad-chua-chuyen').checked = true;
                    await loadDanhSachTiepNhan();
                }
            } else {
                showToast('error', res.message || 'Không chuyển được lượt khám.');
            }
        });
    }

    // Modal Bỏ đăng ký công khám
    let bdkCurrentVaoVienId = null;
    let bdkCongKhamList = [];
    let modalBoDangKyInstance = null;

    function mapCongKhamTuApi(dsCongKham) {
        return dsCongKham.map(c => ({
            IDDichVu: c.IDDichVu || c.id_dich_vu,
            TenDichVu: c.TenDichVu || c.ten_dich_vu,
            SoLuong: c.SoLuong || c.so_luong || 1,
            DonGia: c.DonGia || c.don_gia || 0
        }));
    }

    async function taiLaiSauKhiBoCongKham() {
        const idVaoVien = bdkCurrentVaoVienId;
        const resReload = await apiGet(`/api/tiep_nhan/danh_sach_cong_kham?id_vao_vien=${idVaoVien}`);
        bdkCongKhamList = resReload.status === 200 && Array.isArray(resReload.data) ? resReload.data : [];

        if (selectedVaoVienId === idVaoVien) {
            selectedCongKham = mapCongKhamTuApi(bdkCongKhamList);
            renderCongKhamPreview();
            capNhatNutChuyenKham(false);
        }

        await loadDanhSachTiepNhan(idVaoVien);

        if (bdkCongKhamList.length > 0) {
            renderBdkCongKhamTable();
            capNhatBdkSummary();
            return;
        }

        if (modalBoDangKyInstance) modalBoDangKyInstance.hide();

        capNhatNutChuyenKham(false);
    }

    window.boDangKyTiepNhan = async function (idVaoVien) {
        bdkCurrentVaoVienId = idVaoVien;
        const patient = tnDataList.find(p => p.IDVaoVien === idVaoVien);
        const infoEl = document.getElementById('modal-bdk-patient-info');
        if (infoEl && patient) {
            infoEl.innerHTML = `BN: <strong>${patient.HoTen}</strong> | Mã BN: <strong>${patient.MaBN}</strong> | STT: <strong>${patient.SoThuTu || '--'}</strong>`;
        } else if (infoEl) {
            infoEl.textContent = `Lượt vào viện #${idVaoVien}`;
        }

        const tbody = document.getElementById('modal-bdk-table-body');
        tbody.innerHTML = `<tr><td colspan="8" class="text-center text-muted py-3"><div class="spinner-border spinner-border-sm text-primary me-2"></div>Đang tải danh sách công khám...</td></tr>`;

        const checkAll = document.getElementById('modal-bdk-check-all');
        if (checkAll) checkAll.checked = false;
        capNhatBdkSummary();

        if (!modalBoDangKyInstance) {
            const modalEl = document.getElementById('modalBoDangKy');
            if (modalEl) modalBoDangKyInstance = new bootstrap.Modal(modalEl);
        }
        if (modalBoDangKyInstance) modalBoDangKyInstance.show();

        try {
            const res = await apiGet(`/api/tiep_nhan/danh_sach_cong_kham?id_vao_vien=${idVaoVien}`);
            if (res.status === 200 && res.data && res.data.length > 0) {
                bdkCongKhamList = res.data;
                renderBdkCongKhamTable();
            } else {
                tbody.innerHTML = `<tr><td colspan="8" class="text-center text-muted py-3">Lượt khám này không còn công khám nào.</td></tr>`;
            }
        } catch (e) {
            tbody.innerHTML = `<tr><td colspan="8" class="text-center text-danger py-3">Lỗi tải danh sách công khám: ${e.message}</td></tr>`;
        }
    };

    function renderBdkCongKhamTable() {
        const tbody = document.getElementById('modal-bdk-table-body');
        tbody.innerHTML = '';
        bdkCongKhamList.forEach((item, index) => {
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td class="text-center">
                    <input type="checkbox" class="form-check-input bdk-item-check" data-id="${item.IDCongKhamCT}" data-price="${item.ThanhTien || 0}" />
                </td>
                <td class="text-center">${index + 1}</td>
                <td><span class="badge bg-light text-dark border">${item.MaDichVu || '--'}</span></td>
                <td class="fw-medium">${item.TenDichVu || ''}</td>
                <td class="text-end">${formatCurrencyVN(item.DonGia || 0)}</td>
                <td class="text-end fw-bold text-primary">${formatCurrencyVN(item.ThanhTien || 0)}</td>
                <td class="text-muted small">${item.GhiChu || ''}</td>
                <td class="text-center">
                    <button type="button" class="btn btn-sm btn-outline-danger py-0 px-2 btn-bdk-delete-single" data-id="${item.IDCongKhamCT}" data-name="${escapeHtml(item.TenDichVu || 'công khám')}" title="Bỏ riêng công khám này">
                        <i class="bi bi-trash"></i>
                    </button>
                </td>
            `;
            tbody.appendChild(tr);
        });

        tbody.querySelectorAll('.bdk-item-check').forEach(chk => {
            chk.addEventListener('change', () => {
                const allChecks = tbody.querySelectorAll('.bdk-item-check');
                const checkAll = document.getElementById('modal-bdk-check-all');
                if (checkAll) {
                    checkAll.checked = Array.from(allChecks).length > 0 && Array.from(allChecks).every(c => c.checked);
                }
                capNhatBdkSummary();
            });
        });

        tbody.querySelectorAll('.btn-bdk-delete-single').forEach(btn => {
            btn.addEventListener('click', async (e) => {
                e.stopPropagation();
                const idCk = Number(btn.dataset.id);
                const tenCk = btn.dataset.name;

                const isOnlyOne = bdkCongKhamList.length === 1;
                let msg = `Bạn có chắc muốn bỏ công khám "${tenCk}" không?`;
                if (isOnlyOne) {
                    msg = `Đây là công khám cuối cùng của lượt khám. Bỏ công khám này sẽ đưa lượt tiếp nhận về trạng thái Chưa chuyển. Bạn có chắc chắn không?`;
                }

                const dongY = await hien_thi_xac_nhan({
                    tieu_de: 'Bỏ công khám',
                    noi_dung: msg,
                    nhan_dong_y: 'Bỏ công khám',
                    lop_nut: 'btn-danger'
                });
                if (!dongY) return;

                try {
                    const res = await apiPost('/api/tiep_nhan/bo_cong_kham', {
                                id_vao_vien: bdkCurrentVaoVienId,
                        id_cong_kham_ct_list: [idCk]
                    });

                    if (res.status === 200) {
                    showToast('success', res.message || 'Đã bỏ công khám.');
                        await taiLaiSauKhiBoCongKham();
                    } else {
                    showToast('error', res.message || 'Không bỏ được công khám.');
                    }
                } catch (err) {
                    showToast('error', 'Không kết nối được máy chủ.');
                }
            });
        });
    }

    function capNhatBdkSummary() {
        const checks = document.querySelectorAll('#modal-bdk-table-body .bdk-item-check:checked');
        const count = checks.length;
        let total = 0;
        checks.forEach(c => {
            total += Number(c.dataset.price || 0);
        });
        const summaryEl = document.getElementById('modal-bdk-summary');
        const moneyEl = document.getElementById('modal-bdk-total-money');
        if (summaryEl) {
            summaryEl.textContent = `Đã chọn: ${count} / ${bdkCongKhamList.length} công khám`;
        }
        if (moneyEl) {
            moneyEl.textContent = count > 0 ? `Tổng tiền bỏ: ${formatCurrencyVN(total)}` : '';
        }
    }

    document.getElementById('modal-bdk-check-all')?.addEventListener('change', function () {
        const isChecked = this.checked;
        document.querySelectorAll('#modal-bdk-table-body .bdk-item-check').forEach(c => {
            c.checked = isChecked;
        });
        capNhatBdkSummary();
    });

    document.getElementById('btn-modal-bdk-xac-nhan')?.addEventListener('click', async function () {
        const checkedBoxes = document.querySelectorAll('#modal-bdk-table-body .bdk-item-check:checked');
        if (checkedBoxes.length === 0) {
            showToast('warning', 'Chọn công khám cần bỏ.');
            return;
        }

        const selectedIds = Array.from(checkedBoxes).map(c => Number(c.dataset.id));
        const isBOHet = selectedIds.length === bdkCongKhamList.length;

        let confirmMsg = `Bạn có chắc muốn bỏ ${selectedIds.length} công khám đã chọn không?`;
        if (isBOHet) {
            confirmMsg = `Bạn đang chọn bỏ TẤT CẢ (${selectedIds.length}) công khám. Thông tin bệnh nhân và lượt tiếp nhận vẫn được giữ lại, lượt tiếp nhận sẽ trở về trạng thái Chưa chuyển. Bạn có chắc chắn không?`;
        }

        const dongY = await hien_thi_xac_nhan({
            tieu_de: 'Xác nhận bỏ đăng ký công khám',
            noi_dung: confirmMsg,
            nhan_dong_y: isBOHet ? 'Xác nhận bỏ hết' : 'Bỏ công khám',
            lop_nut: 'btn-danger'
        });
        if (!dongY) return;

        try {
            const res = await apiPost('/api/tiep_nhan/bo_cong_kham', {
                id_vao_vien: bdkCurrentVaoVienId,
                id_cong_kham_ct_list: selectedIds
            });

            if (res.status === 200) {
                showToast('success', res.message || 'Đã bỏ đăng ký.');
                await taiLaiSauKhiBoCongKham();
            } else {
                showToast('error', res.message || 'Không thực hiện được thao tác.');
            }
        } catch (e) {
            showToast('error', 'Không thực hiện được thao tác.');
        }
    });

    window.suaThongTinBenhNhanDaKham = function (idVaoVien) {
        const item = Array.isArray(tnDataList)
            ? tnDataList.find(x => Number(x.IDVaoVien) === Number(idVaoVien))
            : null;
        if (!item) {
            showToast('warning', 'Không tìm thấy lượt khám cần sửa.');
            return;
        }

        const row = document.querySelector(`#tn-table-body tr[data-id-vao-vien="${idVaoVien}"]`);
        document.querySelectorAll('#tn-table-body tr').forEach(r => r.classList.remove('selected', 'table-active'));
        if (row) row.classList.add('selected', 'table-active');

        fillFormTiepNhan(item, true);
        showToast('info', 'Đang sửa thông tin hành chính BN. Công khám và dữ liệu khám được giữ nguyên.');
    };

    window.xoaTiepNhanTrongNgay = async function (idVaoVien) {
        const dongY = await hien_thi_xac_nhan({
            tieu_de: 'Xóa tiếp nhận bệnh nhân',
            noi_dung: 'Hành động này sẽ xóa toàn bộ dịch vụ công khám và lượt tiếp nhận trong ngày của bệnh nhân này. Thông tin hồ sơ bệnh nhân vẫn được lưu lại. Bạn có chắc chắn muốn xóa?',
            nhan_dong_y: 'Xác nhận xóa',
            lop_nut: 'btn-danger'
        });
        if (!dongY) return;

        try {
            const res = await apiPost('/api/tiep_nhan/bo_dang_ky', { id_cskcb: 2, id_vao_vien: idVaoVien });
            if (res.status === 200) {
                showToast('success', res.message || 'Đã xóa tiếp nhận hôm nay.');
                await loadDanhSachTiepNhan();
                resetFormTiepNhan();
            } else {
                showToast('error', res.message || 'Không xóa được tiếp nhận.');
            }
        } catch (e) {
            showToast('error', 'Không thực hiện được thao tác.');
        }
    };

    window.xoaHoSoBenhNhan = async function (idBenhNhan) {
        const dongY = await hien_thi_xac_nhan({
            tieu_de: 'Xóa hồ sơ bệnh nhân',
            noi_dung: 'Chỉ có thể xóa hồ sơ chưa phát sinh lượt khám. Bạn có chắc chắn muốn xóa không?',
            nhan_dong_y: 'Xóa hồ sơ',
            lop_nut: 'btn-danger'
        });
        if (!dongY) return;
        const res = await apiPost('/api/tiep_nhan/xoa_benh_nhan', { id_cskcb: 2, id_benh_nhan: idBenhNhan });
        if (res.status === 200) {
            showToast('success', res.message || 'Đã xóa bệnh nhân.');
            loadDanhSachTiepNhan();
            resetFormTiepNhan();
        } else {
            showToast('error', res.message || 'Không xóa được bệnh nhân.');
        }
    };

    window.xemGhiChu = function (idVaoVien, idBenhNhan) {
        let row = null;
        if (idVaoVien) {
            row = document.querySelector(`#tn-table-body tr[data-id-vao-vien="${idVaoVien}"]`);
        }
        if (!row && idBenhNhan) {
            row = document.querySelector(`#tn-table-body tr[data-id-benh-nhan="${idBenhNhan}"]`);
        }
        if (!row) return;

        let item = null;
        if (typeof tnDataList !== 'undefined' && Array.isArray(tnDataList)) {
            if (idVaoVien) {
                item = tnDataList.find(x => String(x.IDVaoVien) === String(idVaoVien));
            }
            if (!item && idBenhNhan) {
                item = tnDataList.find(x => String(x.IDBenhNhan) === String(idBenhNhan));
            }
        }
        if (!item && row.dataset.item) {
            try {
                item = JSON.parse(row.dataset.item);
            } catch (e) {
                console.warn('Lỗi parse dataset.item:', e);
            }
        }
        if (!item) {
            showToast('warning', 'Không tìm thấy bệnh nhân.');
            return;
        }

        document.querySelectorAll('#tn-table-body tr').forEach(r => r.classList.remove('selected', 'table-active'));
        row.classList.add('selected', 'table-active');
        fillFormTiepNhan(item);

        const ghiChu = {
            benh_nhan: item.GhiChuBenhNhan || '',
            lan_kham: item.GhiChuLanKham || ''
        };
        const editor = document.getElementById('modal-note-editor');
        const radios = document.querySelectorAll('input[name="modal-note-type"]');
        const radioBenhNhan = document.getElementById('modal-note-type-bn');
        let loaiHienTai = 'benh_nhan';

        radioBenhNhan.checked = true;
        editor.value = ghiChu.benh_nhan;

        const radioLanKham = document.getElementById('modal-note-type-lk');
        if (radioLanKham) {
            radioLanKham.disabled = chiSuaThongTinBenhNhan;
            if (chiSuaThongTinBenhNhan) radioLanKham.title = 'Lượt đã chuyển khám: chỉ sửa ghi chú hồ sơ BN.';
        }

        radios.forEach(radio => {
            radio.onchange = () => {
                ghiChu[loaiHienTai] = editor.value;
                loaiHienTai = radio.value;
                editor.value = ghiChu[loaiHienTai];
            };
        });

        document.getElementById('btn-modal-note-luu').onclick = () => {
            ghiChu[loaiHienTai] = editor.value;
            document.getElementById('tn-ghi-chu-bn').value = ghiChu.benh_nhan;
            document.getElementById('tn-ghi-chu-lan-kham').value = ghiChu.lan_kham;
            danhDauTiepNhanChuaLuu();
            item.GhiChuBenhNhan = ghiChu.benh_nhan;
            item.GhiChuLanKham = ghiChu.lan_kham;
            item.CoGhiChu = ghiChu.benh_nhan.trim() || ghiChu.lan_kham.trim() ? 1 : 0;
            row.dataset.item = JSON.stringify(item);

            // Cập nhật ngay ngôi sao ghi chú trên dòng hiện tại
            const tenTd = row.querySelector('.col-ten-bn') || row.querySelector('.sticky-col-ten-bn');
            if (tenTd) {
                const existingStar = tenTd.querySelector('.star-note');
                if (existingStar) {
                    const tip = bootstrap.Tooltip.getInstance(existingStar);
                    if (tip) tip.dispose();
                    existingStar.remove();
                }
                const hasNoteNow = Boolean(ghiChu.benh_nhan.trim()) || Boolean(ghiChu.lan_kham.trim());
                if (hasNoteNow) {
                    let tipText = '';
                    if (ghiChu.benh_nhan.trim() && ghiChu.lan_kham.trim()) {
                        tipText = `Ghi chú BN: ${ghiChu.benh_nhan.trim()}\nGhi chú khám: ${ghiChu.lan_kham.trim()}`;
                    } else if (ghiChu.benh_nhan.trim()) {
                        tipText = `Ghi chú BN: ${ghiChu.benh_nhan.trim()}`;
                    } else {
                        tipText = `Ghi chú khám: ${ghiChu.lan_kham.trim()}`;
                    }
                    const starEl = document.createElement('span');
                    starEl.className = 'star-note ms-1 fw-bold text-danger';
                    starEl.dataset.bsToggle = 'tooltip';
                    starEl.dataset.bsPlacement = 'top';
                    starEl.title = tipText;
                    starEl.textContent = '★';
                    tenTd.appendChild(starEl);
                    new bootstrap.Tooltip(starEl);
                }
            }

            const modalGhiChuEl = document.getElementById('modalGhiChu');
            if (modalGhiChuEl) bootstrap.Modal.getOrCreateInstance(modalGhiChuEl).hide();
            showToast('info', 'Ghi chú sẽ lưu khi bấm Lưu.');
        };

        const modalEl = document.getElementById('modalGhiChu');
        if (modalEl) bootstrap.Modal.getOrCreateInstance(modalEl).show();
    };
})();

