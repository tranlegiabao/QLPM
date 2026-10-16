(() => {
    const root = document.getElementById('thu-ngan-root');
    if (!root) return;

    const canCollect = root.dataset.canCollect === '1';
    const canRefund = root.dataset.canRefund === '1';
    const canCancel = root.dataset.canCancel === '1';
    const canExport = root.dataset.canExport === '1';
    const listBody = document.getElementById('thu-ngan-list-body');
    const serviceBody = document.getElementById('thu-ngan-service-body');
    const medicineBody = document.getElementById('thu-ngan-medicine-body');
    const searchInput = document.getElementById('thu-ngan-search');
    const countEl = document.getElementById('thu-ngan-count');
    const emptyEl = document.getElementById('thu-ngan-empty');
    const detailEl = document.getElementById('thu-ngan-detail');
    const detailStatus = document.getElementById('thu-ngan-detail-status');
    const elChuyenKhoan = document.getElementById('tn-chuyen-khoan');
    const elTienMat = document.getElementById('tn-tien-mat');
    const elTongThanhToan = document.getElementById('tn-tong-thanh-toan');
    const elNganHang = document.getElementById('tn-ngan-hang');
    const elGhiChu = document.getElementById('tn-ghi-chu');
    const btnThu = document.getElementById('tn-btn-thu');
    const documentCurrent = document.getElementById('tn-document-current');
    const documentEmpty = document.getElementById('thu-ngan-document-empty');
    const documentDetail = document.getElementById('thu-ngan-document-detail');
    const documentPatient = document.getElementById('tn-document-patient');
    const historyEmpty = document.getElementById('thu-ngan-history-empty');
    const historyDetail = document.getElementById('thu-ngan-history-detail');
    const historyBody = document.getElementById('tn-history-body');
    const historyPatient = document.getElementById('tn-history-patient');
    const historyExcel = document.getElementById('tn-history-excel');
    const serviceDiscount = document.getElementById('tn-service-discount');
    const medicineDiscount = document.getElementById('tn-medicine-discount');
    let discountCatalog = [];
    const serviceSelectAll = document.getElementById('tn-service-select-all');
    const medicineSelectAll = document.getElementById('tn-medicine-select-all');
    const printFrame = document.getElementById('thu-ngan-print-frame');

    let currentSection = 'thu-tien';
    let currentStatus = 'cho_thu';
    let currentPage = 1;
    let pageSize = 10;
    let pager = null;
    let selectedVisitId = 0;
    let currentDetail = null;
    let currentDetailRows = [];
    let searchTimer = null;
    let listAbort = null;
    let detailAbort = null;
    let busy = false;
    let cashierPdfObjectUrl = null;

    const escapeHtml = value => String(value == null ? '' : value).replace(/[&<>"']/g, ch => ({
        '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
    }[ch]));

    const formatQuantity = value => Number(value || 0).toLocaleString('en-US', {
        minimumFractionDigits: 0,
        maximumFractionDigits: 3
    });

    const formatMoneyNumber = value => Math.round(Number(value || 0)).toLocaleString('en-US', {
        minimumFractionDigits: 0,
        maximumFractionDigits: 0
    });

    const money = value => formatMoneyNumber(value) + ' đ';

    const parseMoney = value => {
        const normalized = String(value == null ? '' : value)
            .replace(/\s+/g, '')
            .replace(/đ/gi, '')
            .replace(/,/g, '');
        const parsed = Number(normalized);
        return Number.isFinite(parsed) ? parsed : 0;
    };

    function toast(type, message) {
        if (window.showToast) showToast(type, message);
        else alert(message);
    }

    function localDate(value) {
        if (!value) return '';
        const d = new Date(value);
        if (Number.isNaN(d.getTime())) return '';
        return String(d.getDate()).padStart(2, '0') + '-' +
            String(d.getMonth() + 1).padStart(2, '0') + '-' +
            d.getFullYear();
    }

    function localDateTime(value) {
        if (!value) return '';
        const d = new Date(value);
        if (Number.isNaN(d.getTime())) return '';
        return String(d.getHours()).padStart(2, '0') + ':' +
            String(d.getMinutes()).padStart(2, '0') + ' ' + localDate(value);
    }

    function todayVN() {
        if (window.formatDateVN) return formatDateVN(new Date());
        return localDate(new Date());
    }

    function toIsoDate(raw) {
        const text = String(raw || '').trim().replace(/\//g, '-');
        if (!text) return '';
        const p = text.split('-');
        if (p.length !== 3) return '';
        if (p[0].length === 4) return p[0] + '-' + p[1].padStart(2, '0') + '-' + p[2].padStart(2, '0');
        if (p[2].length === 4) return p[2] + '-' + p[1].padStart(2, '0') + '-' + p[0].padStart(2, '0');
        return '';
    }

    function stateMeta(value) {
        return Number(value) === 1
            ? { text: 'Đã thu', badge: 'text-bg-success', row: 'thu-ngan-status-paid' }
            : { text: 'Chưa thu', badge: 'text-bg-warning', row: 'thu-ngan-status-pending' };
    }

    function ensurePager() {
        if (pager || !window.createQLPMPagination) return pager;
        pager = createQLPMPagination({
            container: '#thu-ngan-pagination',
            itemName: 'lượt',
            pageSize,
            currentPage,
            pageSizes: [10, 25, 50, 100],
            compact: true,
            tableScrollSelector: '#thu-ngan-list-scroll',
            onPageChange: (page, size) => {
                currentPage = page;
                pageSize = size;
                loadList().catch(showError);
            }
        });
        return pager;
    }

    async function loadBanks() {
        if (!elNganHang) return;
        try {
            const res = await apiGet('/api/danh_muc/ngan_hang', { top: 500 });
            if (res.status !== 200 || !Array.isArray(res.data)) return;
            let html = '<option value="">-- Chuyển khoản --</option>';
            res.data.forEach(x => {
                html += '<option value="' + Number(x.id) + '">' + escapeHtml(x.ten || x.ma || '') + '</option>';
            });
            elNganHang.innerHTML = html;
        } catch (_) { }
    }

    function selectedStatus() {
        return document.querySelector('input[name="thu-ngan-filter-status"]:checked')?.value || 'cho_thu';
    }

    async function activateSection(name) {
        currentSection = ['thu-tien', 'chung-tu', 'lich-su'].includes(name) ? name : 'thu-tien';

        document.querySelectorAll('[data-thu-ngan-group]').forEach(button => {
            button.classList.toggle('active', button.dataset.thuNganGroup === currentSection);
        });
        document.querySelectorAll('[data-thu-ngan-panel]').forEach(panel => {
            panel.classList.toggle('d-none', panel.dataset.thuNganPanel !== currentSection);
        });
        document.querySelectorAll('[data-thu-ngan-filter]').forEach(filter => {
            const sections = String(filter.dataset.thuNganFilter || '').split(/\s+/).filter(Boolean);
            filter.classList.toggle('d-none', !sections.includes(currentSection));
        });
        document.querySelector('[data-thu-ngan-payment-status]')?.classList.toggle('d-none', currentSection !== 'thu-tien');

        currentPage = 1;
        selectedVisitId = 0;
        clearDetail();
        await loadList();
    }

    async function loadList() {
        if (listAbort) listAbort.abort();
        const controller = new AbortController();
        listAbort = controller;
        listBody.innerHTML = '<tr><td colspan="10" class="text-center text-muted py-4">Đang tải...</td></tr>';

        const params = new URLSearchParams();
        params.set('trang', String(currentPage));
        params.set('kich_thuoc_trang', String(pageSize));

        const q = searchInput?.value.trim() || '';
        if (q) params.set('q', q);

        let endpoint = '/thu_ngan/api/danh-sach';
        if (currentSection === 'chung-tu' || currentSection === 'lich-su') {
            endpoint = '/thu_ngan/api/danh-sach-chung-tu';
            const tuNgay = toIsoDate(document.getElementById('thu-ngan-tu-ngay')?.value || '');
            const denNgay = toIsoDate(document.getElementById('thu-ngan-den-ngay')?.value || '');
            if (tuNgay) params.set('tu_ngay', tuNgay);
            if (denNgay) params.set('den_ngay', denNgay);
        } else {
            currentStatus = selectedStatus();
            params.set('trang_thai', currentStatus);
            const ngay = toIsoDate(document.getElementById('thu-ngan-ngay')?.value || '');
            if (ngay) params.set('ngay', ngay);
        }

        const response = await fetch(endpoint + '?' + params.toString(), {
            credentials: 'same-origin',
            signal: controller.signal
        });
        const result = await response.json();
        if (controller !== listAbort) return;
        if (!response.ok || result.status !== 200) throw new Error(result.message || 'Không tải được danh sách thu ngân.');

        const rows = result.data?.danh_sach || [];
        const total = Number(result.data?.tong_so || 0);
        pageSize = Number(result.data?.kich_thuoc_trang || pageSize);
        currentPage = Number(result.data?.trang || currentPage);

        if (countEl) countEl.textContent = total + ' lượt';
        renderList(rows);

        const pg = ensurePager();
        if (pg) {
            pg.render(total, currentPage);
            currentPage = pg.getCurrentPage();
            pageSize = pg.getPageSize();
        }

        if (!rows.length) {
            selectedVisitId = 0;
            clearDetail();
            return;
        }

        let target = rows.find(x => Number(x.id_vao_vien) === selectedVisitId);
        if (!target) target = rows[0];
        selectedVisitId = Number(target.id_vao_vien);
        markSelectedRow();
        await loadDetail(selectedVisitId);
    }

    function rowActionsHtml(x) {
        const id = Number(x.id_vao_vien);
        const status = Number(x.trang_thai_thu || 0);
        let items =
            '<li><button type="button" class="dropdown-item thu-ngan-row-action" data-action="view" data-id="' + id + '">' +
                '<i class="bi bi-eye me-2"></i>' +
                (currentSection === 'chung-tu' ? 'Xem chứng từ' : (currentSection === 'lich-su' ? 'Xem lịch sử' : 'Xem chi tiết')) +
                '</button></li>';

        if (currentSection === 'thu-tien' && status === 0 && canCollect) {
            items +=
                '<li><button type="button" class="dropdown-item thu-ngan-row-action" data-action="collect" data-id="' + id + '">' +
                    '<i class="bi bi-cash-stack me-2"></i>Thu tiền</button></li>';
        }

        return '<div class="dropdown thu-ngan-row-dropdown">' +
            '<button type="button" class="btn btn-sm btn-outline-secondary thu-ngan-row-menu" data-bs-toggle="dropdown" aria-expanded="false" title="Tùy chọn">' +
                '<i class="bi bi-list"></i>' +
            '</button>' +
            '<ul class="dropdown-menu dropdown-menu-end">' + items + '</ul>' +
        '</div>';
    }

    function renderList(rows) {
        if (!rows.length) {
            listBody.innerHTML = '<tr><td colspan="10" class="text-center text-muted py-4">Không có lượt phù hợp.</td></tr>';
            return;
        }

        const start = (currentPage - 1) * pageSize;
        listBody.innerHTML = rows.map((x, index) => {
            const id = Number(x.id_vao_vien);
            const state = stateMeta(x.trang_thai_thu);
            const selected = id === selectedVisitId ? ' selected table-active' : '';
            return '<tr class="' + state.row + selected + '" data-id="' + id + '">' +
                '<td class="text-center font-monospace">' + (x.so_thu_tu != null ? escapeHtml(x.so_thu_tu) : (start + index + 1)) + '</td>' +
                '<td class="text-nowrap sticky-col sticky-col-ten-bn">' +
                    '<span class="fw-bold text-uppercase">' + escapeHtml(x.ho_ten || '') + '</span>' +
                '</td>' +
                '<td class="text-center text-nowrap">' + escapeHtml(localDate(x.ngay_gio_vao_vien)) + '</td>' +
                '<td class="text-center text-nowrap">' + escapeHtml(localDate(x.ngay_sinh)) + '</td>' +
                '<td class="text-center text-nowrap">' + escapeHtml(x.gioi_tinh || '') + '</td>' +
                '<td class="text-nowrap">' + escapeHtml(x.so_cccd || '') + '</td>' +
                '<td class="text-nowrap">' + escapeHtml(x.dien_thoai || '') + '</td>' +
                '<td class="col-dia-chi" title="' + escapeHtml(x.dia_chi || '') + '">' + escapeHtml(x.dia_chi || '') + '</td>' +
                '<td class="fw-bold col-ma-bn">' + escapeHtml(x.ma_bn || '') + '</td>' +
                '<td class="text-center thu-ngan-action-cell sticky-col sticky-col-tuy-chon">' + rowActionsHtml(x) + '</td>' +
            '</tr>';
        }).join('');

        listBody.querySelectorAll('tr[data-id]').forEach(row => {
            row.addEventListener('click', async () => {
                const id = Number(row.dataset.id || 0);
                if (!id) return;
                selectedVisitId = id;
                markSelectedRow();
                await loadDetail(id).catch(showError);
            });
        });

        listBody.querySelectorAll('.thu-ngan-row-dropdown').forEach(menu => {
            menu.addEventListener('click', event => event.stopPropagation());
        });

        listBody.querySelectorAll('.thu-ngan-row-action').forEach(button => {
            button.addEventListener('click', async event => {
                event.stopPropagation();
                const id = Number(button.dataset.id || 0);
                const action = button.dataset.action || '';
                if (!id) return;

                selectedVisitId = id;
                markSelectedRow();
                await loadDetail(id).catch(showError);

                if (action === 'collect') {
                    await activateSection('thu-tien');
                    btnThu?.focus();
                }
            });
        });
    }

    function markSelectedRow() {
        listBody.querySelectorAll('tr[data-id]').forEach(row => {
            const selected = Number(row.dataset.id) === selectedVisitId;
            row.classList.toggle('selected', selected);
            row.classList.toggle('table-active', selected);
        });
    }

    async function loadDetail(id) {
        if (currentSection === 'lich-su') {
            await loadDocumentHistory(id);
            return;
        }

        if (detailAbort) detailAbort.abort();
        const controller = new AbortController();
        detailAbort = controller;

        const response = await fetch('/thu_ngan/api/chi-tiet?id_vao_vien=' + encodeURIComponent(id), {
            credentials: 'same-origin',
            signal: controller.signal
        });
        const result = await response.json();
        if (controller !== detailAbort) return;
        if (!response.ok || result.status !== 200) throw new Error(result.message || 'Không tải được chi tiết.');

        currentDetail = result.data?.thong_tin || null;
        currentDetailRows = Array.isArray(result.data?.chi_tiet)
            ? result.data.chi_tiet
                .filter(x => {
                    if (currentSection !== 'thu-tien') return true;
                    const paid = Number(x.da_thu || 0) === 1;
                    if (currentStatus === 'da_thu') return paid;
                    if (currentStatus === 'cho_thu') return !paid;
                    return true;
                })
                .map(x => ({
                    ...x,
                    phu_thu: Math.round(Number(x.phu_thu || 0)),
                    giam_phan_tram: Number(x.giam_phan_tram || 0),
                    selected: canSelectForCollection(x)
                }))
            : [];

        if (!currentDetail) {
            clearDetail();
            return;
        }
        renderDetail();
        if (currentSection === 'chung-tu') await loadDocuments(id);
    }

    function clearDetail() {
        currentDetail = null;
        currentDetailRows = [];
        emptyEl?.classList.remove('d-none');
        detailEl?.classList.add('d-none');
        detailStatus?.classList.add('d-none');
        documentEmpty?.classList.remove('d-none');
        documentDetail?.classList.add('d-none');
        historyEmpty?.classList.remove('d-none');
        historyDetail?.classList.add('d-none');
        if (documentPatient) documentPatient.textContent = '';
        if (documentCurrent) documentCurrent.innerHTML = '<tr><td colspan="7" class="text-center text-muted">Chưa có chứng từ.</td></tr>';
        if (historyPatient) historyPatient.textContent = '';
        if (historyBody) historyBody.innerHTML = '<tr><td colspan="6" class="text-center text-muted">Chưa có lịch sử.</td></tr>';
    }

    function formatPercent(value) {
        const n = Number(String(value ?? 0).replace(',', '.'));
        return Number.isFinite(n)
            ? String(Math.min(100, Math.max(0, Math.round(n * 100) / 100)))
            : '0';
    }

    function parsePercent(value) {
        const n = Number(String(value ?? '').trim().replace(',', '.'));
        return Number.isFinite(n) ? Math.min(100, Math.max(0, n)) : 0;
    }

    function linePayment(row) {
        const base = Math.round(Number(row.thanh_tien || 0)) + Math.round(Number(row.phu_thu || 0));
        const percent = Math.min(100, Math.max(0, Number(row.giam_phan_tram || 0)));
        return Math.max(0, base - Math.round(base * percent / 100));
    }

    function lineInputDisabled(row) {
        return !canSelectForCollection(row);
    }

    function canSelectForCollection(row) {
        // Server owns the clinical/source eligibility; fail closed on old schemas.
        return canCollect && Number(row?.co_the_thu || 0) === 1 && Number(row?.da_thu || 0) !== 1;
    }

    function selectedForCollection(row) {
        return canSelectForCollection(row) && row?.selected === true;
    }

    function rowCheckboxHtml(row) {
        const paid = Number(row?.da_thu || 0) === 1;
        const checked = paid || row?.selected === true;
        const disabled = !canSelectForCollection(row);
        const title = paid ? 'Đã thu' : 'Chọn dòng để thu';
        return '<input type="checkbox" class="form-check-input m-0 tn-line-select" data-id="' + Number(row.id) + '" ' +
            (checked ? 'checked ' : '') + (disabled ? 'disabled ' : '') +
            'title="' + title + '" />';
    }

    function renderDetail() {
        emptyEl?.classList.add('d-none');
        detailEl?.classList.remove('d-none');
        documentEmpty?.classList.add('d-none');
        documentDetail?.classList.remove('d-none');
        if (documentPatient) {
            const patientName = currentDetail?.ho_ten || '';
            const patientCode = currentDetail?.ma_bn || '';
            const visitCode = currentDetail?.ma_vao_vien || '';
            documentPatient.textContent = [patientName, patientCode, visitCode].filter(Boolean).join(' • ');
        }

        const state = stateMeta(currentDetail.trang_thai_thu);
        if (detailStatus) {
            detailStatus.className = 'badge ' + state.badge;
            detailStatus.textContent = state.text + (Number(currentDetail.trang_thai_kham) === 1 ? ' · Đang khám: chỉ thu CLS nội bộ' : '');
            detailStatus.classList.remove('d-none');
        }

        const serviceRows = currentDetailRows.filter(x => String(x.loai || '').toUpperCase() !== 'THUOC');
        const medicineRows = currentDetailRows.filter(x => String(x.loai || '').toUpperCase() === 'THUOC');
        // Tab Thu tiền chỉ chiếm chiều cao cho nhóm còn khoản chưa thu.
        document.getElementById('tn-service-section')?.classList.toggle('d-none', serviceRows.length === 0);
        document.getElementById('tn-medicine-section')?.classList.toggle('d-none', medicineRows.length === 0);
        const noRows = serviceRows.length === 0 && medicineRows.length === 0;
        const noRowsEl = document.getElementById('tn-no-unpaid');
        if (noRowsEl) {
            noRowsEl.textContent = currentStatus === 'da_thu'
                ? 'Không có khoản nào đã thu.'
                : (currentStatus === 'tat_ca' ? 'Không có khoản thu nào.' : 'Không còn khoản nào chưa thu.');
            noRowsEl.classList.toggle('d-none', !noRows);
        }
        document.getElementById('tn-payment-footer')?.classList.toggle('d-none', noRows);

        if (!serviceRows.length) {
            serviceBody.innerHTML = '<tr><td colspan="6" class="text-center text-muted py-3">Không có chỉ định.</td></tr>';
        } else {
            serviceBody.innerHTML = serviceRows.map((x, index) => {
                const outside = x.gui_ngoai
                    ? '<span class="badge text-bg-light ms-1" title="' + escapeHtml(x.noi_gui_ngoai || '') + '">Gửi ngoài</span>'
                    : '';
                const disabled = lineInputDisabled(x);
                return '<tr data-payment-row="' + Number(x.id) + '">' +
                    '<td class="text-center">' + rowCheckboxHtml(x) + '</td>' +
                    '<td class="thu-ngan-content-cell"><div>' +
                        '<span>' + escapeHtml(x.ten || '') + '</span>' + outside + '</div>' +
                        (!x.gui_ngoai && Number(x.co_the_thu || 0) !== 1 && Number(x.da_thu || 0) !== 1 ? '<small class="text-muted">Chờ khám xong</small>' : '') +
                        (x.ghi_chu ? '<div class="small text-muted">' + escapeHtml(x.ghi_chu) + '</div>' : '') +
                    '</td>' +
                    '<td class="text-center">' + formatQuantity(x.so_luong) + '</td>' +
                    '<td class="text-end">' + money(x.don_gia) + '</td>' +
                    '<td><input type="text" inputmode="decimal" pattern="[0-9]*[.,]?[0-9]{0,2}" autocomplete="off" class="form-control form-control-sm text-center tn-line-discount" data-id="' + Number(x.id) + '" value="' + formatPercent(x.giam_phan_tram) + '" ' + (disabled ? 'disabled' : '') + ' /></td>' +
                    '<td class="text-end fw-semibold tn-line-payment">' + money(linePayment(x)) + '</td>' +
                '</tr>';
            }).join('');
        }

        if (!medicineRows.length) {
            medicineBody.innerHTML = '<tr><td colspan="7" class="text-center text-muted py-3">Không có toa thuốc.</td></tr>';
        } else {
            medicineBody.innerHTML = medicineRows.map((x, index) => {
                const disabled = lineInputDisabled(x);
                return '<tr data-payment-row="' + Number(x.id) + '">' +
                    '<td class="text-center">' + rowCheckboxHtml(x) + '</td>' +
                    '<td><div class="fw-semibold">' + escapeHtml(x.ten || '') + '</div>' +
                        (Number(x.co_the_thu || 0) !== 1 && Number(x.da_thu || 0) !== 1 ? '<small class="text-muted">Chờ khám xong</small>' : '') +
                        (x.ghi_chu ? '<div class="small text-muted">' + escapeHtml(x.ghi_chu) + '</div>' : '') +
                    '</td>' +
                    '<td class="text-center">' + formatQuantity(x.so_luong) + '</td>' +
                    '<td class="text-center">' + escapeHtml(x.don_vi_tinh || '') + '</td>' +
                    '<td class="text-end">' + money(x.don_gia) + '</td>' +
                    '<td><input type="text" inputmode="decimal" pattern="[0-9]*[.,]?[0-9]{0,2}" autocomplete="off" class="form-control form-control-sm text-center tn-line-discount" data-id="' + Number(x.id) + '" value="' + formatPercent(x.giam_phan_tram) + '" ' + (disabled ? 'disabled' : '') + ' /></td>' +
                    '<td class="text-end fw-semibold tn-line-payment">' + money(linePayment(x)) + '</td>' +
                '</tr>';
            }).join('');
        }

        bindLineAdjustmentInputs();
        bindLineSelection();
        syncSelectAll();

        const paid = Number(currentDetail.trang_thai_thu) === 1;
        if (serviceDiscount) {
            serviceDiscount.value = '';
            serviceDiscount.disabled = !canCollect || !serviceRows.some(canSelectForCollection);
        }
        if (medicineDiscount) {
            medicineDiscount.value = '';
            medicineDiscount.disabled = !canCollect || !medicineRows.some(canSelectForCollection);
        }

        // Phiếu chưa thu đủ có thể đã phát sinh một lần thu trước.
        // Ô thanh toán bên dưới luôn biểu diễn LẦN THU HIỆN TẠI, không nạp lại
        // chuyển khoản cũ để tránh cộng trùng khi SQL cộng dồn các lần thu.
        elChuyenKhoan.value = formatMoneyNumber(paid ? Number(currentDetail.chuyen_khoan || 0) : 0);
        elNganHang.value = paid && currentDetail.id_ngan_hang ? String(currentDetail.id_ngan_hang) : '';
        elGhiChu.value = paid ? (currentDetail.ghi_chu || '') : '';

        if (elNganHang) elNganHang.disabled = paid || !canCollect;
        if (elChuyenKhoan) {
            elChuyenKhoan.disabled = paid || !canCollect || !elNganHang?.value;
            if (!elNganHang?.value && !paid) elChuyenKhoan.value = formatMoneyNumber(0);
        }
        if (elGhiChu) elGhiChu.disabled = paid || !canCollect;

        if (btnThu) {
            btnThu.classList.toggle('d-none', paid || !canCollect);
            btnThu.textContent = 'Lưu';
        }

        updatePaymentSummary();
    }

    function digitsOnly(input, maxDigits = 12) {
        const clean = String(input.value || '').replace(/\D/g, '').slice(0, maxDigits);
        if (input.value !== clean) input.value = clean;
        return clean;
    }

    function bindLineAdjustmentInputs() {
        document.querySelectorAll('.tn-line-surcharge').forEach(input => {
            input.addEventListener('focus', () => {
                input.value = String(Math.max(0, Math.round(parseMoney(input.value))));
                input.select();
            });
            input.addEventListener('input', () => {
                const row = currentDetailRows.find(x => Number(x.id) === Number(input.dataset.id));
                if (!row) return;
                const clean = digitsOnly(input, 12);
                row.phu_thu = Math.max(0, Number(clean || 0));
                updatePaymentSummary();
            });
            input.addEventListener('blur', () => {
                const row = currentDetailRows.find(x => Number(x.id) === Number(input.dataset.id));
                if (!row) return;
                row.phu_thu = Math.round(Math.max(0, Number(row.phu_thu || 0)));
                input.value = formatMoneyNumber(row.phu_thu);
                updatePaymentSummary();
            });
        });

        document.querySelectorAll('.tn-line-discount').forEach(input => {
            input.addEventListener('focus', () => input.select());
            input.addEventListener('input', () => {
                const row = currentDetailRows.find(x => Number(x.id) === Number(input.dataset.id));
                if (!row) return;
                const raw = String(input.value || '').replace(/[^0-9.,]/g, '').replace(',', '.');
                const clean = (raw.match(/^\d{0,3}(?:\.\d{0,2})?/) || [''])[0];
                if (input.value !== clean) input.value = clean;
                const parsed = parsePercent(clean);
                row.giam_phan_tram = parsed;
                if (Number(clean) > 100) input.value = '100';
                updatePaymentSummary();
            });
            input.addEventListener('blur', () => {
                const row = currentDetailRows.find(x => Number(x.id) === Number(input.dataset.id));
                if (!row) return;
                row.giam_phan_tram = parsePercent(row.giam_phan_tram);
                input.value = formatPercent(row.giam_phan_tram);
                updatePaymentSummary();
            });
        });
    }

    function bindLineSelection() {
        document.querySelectorAll('.tn-line-select').forEach(input => {
            input.addEventListener('change', () => {
                const row = currentDetailRows.find(x => Number(x.id) === Number(input.dataset.id));
                if (!row || !canSelectForCollection(row)) return;
                row.selected = input.checked;
                syncSelectAll();
                updatePaymentSummary();
            });
        });
    }

    function rowsByGroup(group) {
        const medicine = group === 'THUOC';
        return currentDetailRows.filter(row =>
            (String(row.loai || '').toUpperCase() === 'THUOC') === medicine
        );
    }

    function syncSelectAllOne(control, group) {
        if (!control) return;
        const rows = rowsByGroup(group).filter(canSelectForCollection);
        const selected = rows.filter(x => x.selected === true).length;
        control.disabled = rows.length === 0;
        control.checked = rows.length > 0 && selected === rows.length;
        control.indeterminate = selected > 0 && selected < rows.length;
    }

    function syncSelectAll() {
        syncSelectAllOne(serviceSelectAll, 'DICH_VU');
        syncSelectAllOne(medicineSelectAll, 'THUOC');
    }

    function setGroupSelection(group, checked) {
        rowsByGroup(group).forEach(row => {
            if (canSelectForCollection(row)) row.selected = checked;
        });
        document.querySelectorAll('.tn-line-select').forEach(input => {
            const row = currentDetailRows.find(x => Number(x.id) === Number(input.dataset.id));
            if (row && canSelectForCollection(row)) input.checked = row.selected === true;
        });
        syncSelectAll();
        updatePaymentSummary();
    }

    function updatePaymentSummary() {
        if (!currentDetail) return;

        const status = Number(currentDetail.trang_thai_thu || 0);
        const fullyPaid = status === 1;
        let serviceTotal = 0;
        let medicineTotal = 0;

        const viewingPaid = currentSection === 'thu-tien' &&
            (currentStatus === 'da_thu' ||
             (currentStatus === 'tat_ca' && Number(currentDetail.trang_thai_thu || 0) === 1));

        currentDetailRows.forEach(row => {
            const payment = viewingPaid && Number(row.da_thu || 0) === 1
                ? Math.max(0, Math.round(Number(row.thanh_toan ?? linePayment(row))))
                : linePayment(row);
            const include = viewingPaid
                ? Number(row.da_thu || 0) === 1
                : selectedForCollection(row);

            if (include) {
                if (String(row.loai || '').toUpperCase() === 'THUOC') medicineTotal += payment;
                else serviceTotal += payment;
            }

            const tr = document.querySelector('tr[data-payment-row="' + Number(row.id) + '"]');
            const cell = tr?.querySelector('.tn-line-payment');
            if (cell) cell.textContent = money(payment);
        });

        const total = Math.max(0, Math.round(serviceTotal + medicineTotal));
        let transfer = Math.round(Math.max(0, parseMoney(elChuyenKhoan?.value || 0)));
        if (transfer > total) transfer = total;
        const cash = Math.max(0, total - transfer);

        const serviceSubtotal = document.getElementById('tn-service-subtotal');
        const medicineSubtotal = document.getElementById('tn-medicine-subtotal');
        if (serviceSubtotal) serviceSubtotal.textContent = money(serviceTotal);
        if (medicineSubtotal) medicineSubtotal.textContent = money(medicineTotal);
        if (elTongThanhToan) elTongThanhToan.textContent = formatMoneyNumber(total);
        if (elTienMat) elTienMat.textContent = formatMoneyNumber(cash);

        if (elNganHang) {
            elNganHang.disabled = !canCollect || fullyPaid;
        }
        if (elChuyenKhoan) {
            const hasBank = !!elNganHang?.value;
            elChuyenKhoan.disabled = !canCollect || fullyPaid || !hasBank;
            if (!hasBank && !fullyPaid && parseMoney(elChuyenKhoan.value) !== 0) {
                elChuyenKhoan.value = formatMoneyNumber(0);
                if (elTienMat) elTienMat.textContent = formatMoneyNumber(total);
            }
        }
    }

    async function collectPayment() {
        if (!canCollect || !currentDetail || busy) return;

        const selectedRows = currentDetailRows.filter(selectedForCollection);
        if (!selectedRows.length)
            return toast('warning', 'Chọn ít nhất một chỉ định hoặc thuốc cần thu.');

        const transfer = Math.round(Math.max(0, parseMoney(elChuyenKhoan?.value || 0)));
        const total = selectedRows.reduce((sum, row) => sum + linePayment(row), 0);
        const maxTransfer = Math.max(0, total);

        if (transfer > maxTransfer) return toast('warning', 'Số tiền chuyển khoản vượt tổng thanh toán.');
        if (transfer > 0 && !elNganHang.value) return toast('warning', 'Chọn ngân hàng khi có chuyển khoản.');

        for (const row of selectedRows) {
            const surcharge = Math.round(Math.max(0, Number(row.phu_thu || 0)));
            const discount = Number(row.giam_phan_tram || 0);
            if (surcharge < 0) return toast('warning', 'Phụ thu không hợp lệ.');
            if (discount < 0 || discount > 100) return toast('warning', 'Giảm (%) phải từ 0 đến 100.');
        }

        busy = true;
        if (btnThu) btnThu.disabled = true;
        try {
            const result = await apiPost('/thu_ngan/api/thu-tien', {
                id_vao_vien: Number(currentDetail.id_vao_vien),
                chuyen_khoan: transfer,
                id_ngan_hang: transfer > 0 ? Number(elNganHang.value) : null,
                ghi_chu: elGhiChu.value.trim() || null,
                danh_sach: selectedRows.map(row => ({
                    id: Number(row.id),
                    phu_thu: Math.round(Math.max(0, Number(row.phu_thu || 0))),
                    giam_phan_tram: Math.min(100, Math.max(0, Number(row.giam_phan_tram || 0)))
                }))
            });
            if (result.status !== 200) throw new Error(result.message || 'Không thu được tiền.');
            toast('success', result.message || 'Thu tiền thành công.');
            await loadList();
        } catch (error) {
            toast('error', error.message || 'Không thu được tiền.');
        } finally {
            busy = false;
            if (btnThu) btnThu.disabled = false;
        }
    }

    async function loadDocuments(visitId) {
        if (!documentCurrent) return;
        const response = await fetch('/thu_ngan/api/chung-tu?id_vao_vien=' + encodeURIComponent(visitId), { credentials: 'same-origin' });
        const result = await response.json();
        if (!response.ok || result.status !== 200) throw new Error(result.message || 'Không tải được chứng từ.');

        renderDocuments(
            Array.isArray(result.data?.chung_tu) ? result.data.chung_tu : [],
            Array.isArray(result.data?.chi_tiet) ? result.data.chi_tiet : []
        );
    }

    function documentActionsHtml(doc, refunded) {
        const id = Number(doc.id || 0);
        const isReceipt = String(doc.loai || '').toUpperCase() === 'THU';
        const active = Number(doc.trang_thai) === 1;
        let actions = canExport && active
            ? '<button class="btn btn-sm btn-outline-success tn-doc-action" data-action="print" data-id="' + id + '" title="In chứng từ"><i class="bi bi-printer"></i></button> '
            : '';
        if (isReceipt && active && !refunded.has(id) && canCancel)
            actions += '<button class="btn btn-sm btn-outline-danger tn-doc-action" data-action="cancel" data-id="' + id + '">Hủy</button>';
        return actions;
    }

    function documentGroupLabel(value) {
        const group = String(value || '').toUpperCase();
        if (group === 'CHI_DINH') return 'chỉ định';
        if (group === 'TOA_THUOC') return 'toa thuốc';
        return '';
    }

    function historyActionLabel(value, group) {
        const action = String(value || '').toUpperCase();
        const groupLabel = documentGroupLabel(group);
        const suffix = groupLabel ? ' - ' + groupLabel : '';
        if (action === 'THU') return 'Thu tiền' + suffix;
        if (action === 'HUY') return 'Hủy chứng từ' + suffix;
        if (action === 'HOAN') return 'Hoàn tiền' + suffix;
        if (action === 'HUY_CHI_DINH') return 'Hủy chỉ định';
        if (action === 'HUY_TOA_THUOC') return 'Hủy toa thuốc';
        return (action || 'Cập nhật') + suffix;
    }

    function renderDocuments(documents, details) {
        if (!documentCurrent) return;

        const activeIds = new Set(
            documents
                .filter(x => Number(x.trang_thai) === 1)
                .map(x => Number(x.id || 0))
        );
        details = details.filter(x => activeIds.has(Number(x.id_chung_tu || 0)));

        const refunded = new Set(
            documents
                .filter(x => String(x.loai || '').toUpperCase() === 'HOAN' && Number(x.trang_thai) === 1)
                .map(x => Number(x.id_chung_tu_goc || 0))
                .filter(Boolean)
        );
        const detailsByDocument = new Map();
        details.forEach(row => {
            const id = Number(row.id_chung_tu || 0);
            if (!detailsByDocument.has(id)) detailsByDocument.set(id, []);
            detailsByDocument.get(id).push(row);
        });

        if (!documents.length) {
            documentCurrent.innerHTML = '<tr><td colspan="8" class="text-center text-muted py-3">BN chưa có chứng từ trong hệ thống.</td></tr>';
        } else {
            documentCurrent.innerHTML = documents.map(doc => {
                const id = Number(doc.id || 0);
                const isReceipt = String(doc.loai || '').toUpperCase() === 'THU';
                const active = Number(doc.trang_thai) === 1;
                const rows = detailsByDocument.get(id) || [];
                const label = isReceipt ? 'Phiếu thu' : 'Phiếu hoàn';
                const original = doc.so_chung_tu_goc ? ' - Gốc: ' + escapeHtml(doc.so_chung_tu_goc) : '';
                const reason = doc.ly_do_huy ? ' - Lý do: ' + escapeHtml(doc.ly_do_huy) : '';

                if (!active) {
                    const cancelledAt = doc.ngay_gio_huy
                        ? ' - Hủy lúc: ' + escapeHtml(localDateTime(doc.ngay_gio_huy))
                        : '';
                    const reversal = doc.so_phieu_dao_kho
                        ? ' - Đảo cấp do hủy thu: ' + escapeHtml(doc.so_phieu_dao_kho)
                        : '';
                    return '<tr class="tn-document-header tn-document-header-cancelled">' +
                        '<td colspan="7">' +
                            '<div class="tn-document-header-row">' +
                                '<div class="tn-document-header-info"><strong>' + label + ': ' + escapeHtml(doc.so_chung_tu || '') +
                                '</strong> - Ngày: ' + escapeHtml(localDateTime(doc.ngay_gio)) +
                                ' - Người thu: ' + escapeHtml(doc.nguoi_lap || '') +
                                ' - <strong>Đã hủy</strong>' + cancelledAt + reason + reversal + '</div>' +
                            '</div>' +
                        '</td>' +
                    '</tr>';
                }

                const state = isReceipt ? 'Đã thu' : 'Đã hoàn';
                const header =
                    '<tr class="tn-document-header tn-document-header-active">' +
                        '<td colspan="7">' +
                            '<div class="tn-document-header-row">' +
                                '<div class="tn-document-header-info"><strong>' + label + ': ' + escapeHtml(doc.so_chung_tu || '') +
                                '</strong> - Ngày: ' + escapeHtml(localDateTime(doc.ngay_gio)) +
                                ' - Người thu: ' + escapeHtml(doc.nguoi_lap || '') +
                                ' - <span>' + state + '</span>' + original + '</div>' +
                                '<div class="tn-document-header-actions">' + documentActionsHtml(doc, refunded) + '</div>' +
                            '</div>' +
                        '</td>' +
                    '</tr>';

                const detailHtml = rows.length
                    ? rows.map((row, index) =>
                        '<tr class="tn-document-line">' +
                            '<td class="text-center">' + (index + 1) + '</td>' +
                            '<td>' + escapeHtml(row.ten || row.ma || '') + '</td>' +
                            '<td class="text-center">' + formatQuantity(row.so_luong) + '</td>' +
                            '<td class="text-center">' + escapeHtml(row.don_vi_tinh || '') + '</td>' +
                            '<td class="text-end">' + money(row.don_gia) + '</td>' +
                            '<td class="text-center">' + formatPercent(row.giam_phan_tram) + '</td>' +
                            '<td class="text-end fw-semibold">' + money(row.thanh_toan) + '</td>' +
                        '</tr>'
                    ).join('')
                    : '<tr><td colspan="7" class="text-center text-muted">Chứng từ chưa có chi tiết.</td></tr>';

                const sign = isReceipt ? '' : '-';
                const total =
                    '<tr class="tn-document-total">' +
                        '<td colspan="6" class="text-end fw-semibold">Tổng ' + label.toLowerCase() + '</td>' +
                        '<td class="text-end fw-bold">' + sign + money(doc.thuc_thu) + '</td>' +
                    '</tr>';
                return header + detailHtml + total;
            }).join('');
        }

        documentCurrent.querySelectorAll('.tn-doc-action').forEach(button => {
            button.addEventListener('click', () => handleDocumentAction(button));
        });
    }

    async function loadDocumentHistory(visitId) {
        if (!historyBody) return;
        historyBody.innerHTML = '<tr><td colspan="6" class="text-center text-muted py-3">Đang tải...</td></tr>';

        const response = await fetch('/thu_ngan/api/chung-tu?id_vao_vien=' + encodeURIComponent(visitId), {
            credentials: 'same-origin'
        });
        const result = await response.json();
        if (!response.ok || result.status !== 200)
            throw new Error(result.message || 'Không tải được lịch sử chứng từ.');

        const rows = Array.isArray(result.data?.lich_su) ? result.data.lich_su : [];
        historyEmpty?.classList.add('d-none');
        historyDetail?.classList.remove('d-none');
        renderDocumentHistory(rows);
    }

    function renderDocumentHistory(rows) {
        if (!historyBody) return;
        if (!rows.length) {
            historyBody.innerHTML = '<tr><td colspan="6" class="text-center text-muted py-3">Chưa có lịch sử thao tác.</td></tr>';
            return;
        }

        historyBody.innerHTML = rows.map(row =>
            '<tr>' +
                '<td class="text-nowrap">' + escapeHtml(localDateTime(row.ngay_gio)) + '</td>' +
                '<td>' + escapeHtml(historyActionLabel(row.hanh_dong, row.nhom)) + '</td>' +
                '<td class="font-monospace text-nowrap">' + escapeHtml(row.so_phieu || '') + '</td>' +
                '<td class="text-end fw-semibold">' + money(row.thuc_thu) + '</td>' +
                '<td class="text-nowrap">' + escapeHtml(row.nguoi_thuc_hien || '') + '</td>' +
                '<td>' + escapeHtml(row.ghi_chu || '') + '</td>' +
            '</tr>'
        ).join('');
    }

    async function handleDocumentAction(button) {
        const id = Number(button.dataset.id || 0);
        const action = button.dataset.action || '';
        if (!id || busy) return;
        if (action === 'print') return printReceipt(id);
        if (action !== 'cancel') return;

        if (typeof window.hien_thi_xac_nhan !== 'function') {
            toast('error', 'Không mở được hộp xác nhận.');
            return;
        }

        const confirmed = await window.hien_thi_xac_nhan({
            tieu_de: 'Hủy chứng từ',
            noi_dung: 'Hủy chứng từ này? Nếu thuốc đã cấp, hệ thống sẽ tự đảo lượng còn cấp của đúng chứng từ về đúng lô kho. Đây là đảo sổ kho, không phải xác nhận đã nhận lại thuốc thực tế; cần kiểm tra việc thu hồi thuốc. Thao tác này không tự hoàn tiền qua ngân hàng.',
            nhan_dong_y: 'Hủy chứng từ',
            nhan_khong: 'Không',
            lop_nut: 'btn-danger'
        });
        if (!confirmed || busy) return;

        busy = true;
        button.disabled = true;
        try {
            const result = await apiPost('/thu_ngan/api/huy-chung-tu', { id_chung_tu: id });
            if (result.status !== 200) throw new Error(result.message || 'Không hủy được chứng từ.');
            toast('success', result.message || 'Đã hủy chứng từ.');
            await loadList();
        } catch (error) {
            toast('error', error.message || 'Không hủy được chứng từ.');
        } finally {
            busy = false;
            button.disabled = false;
        }
    }

    function cleanupCashierPdf() {
        if (cashierPdfObjectUrl) URL.revokeObjectURL(cashierPdfObjectUrl);
        cashierPdfObjectUrl = null;
        if (printFrame) {
            printFrame.onload = null;
            printFrame.removeAttribute('src');
        }
    }

    async function printReceipt(id) {
        const documentId = Number(id || 0);
        if (!documentId || !printFrame || busy) return;

        cleanupCashierPdf();
        try {
            const response = await fetch('/thu_ngan/in-phieu?id_chung_tu=' + encodeURIComponent(documentId), {
                credentials: 'same-origin',
                headers: { Accept: 'application/pdf' }
            });
            if (!response.ok) {
                const message = await response.text();
                throw new Error(message || 'Không tạo được phiếu thu.');
            }

            const blob = await response.blob();
            cashierPdfObjectUrl = URL.createObjectURL(blob);
            printFrame.onload = () => {
                printFrame.onload = null;
                window.setTimeout(() => {
                    try {
                        if (!printFrame.contentWindow) throw new Error();
                        printFrame.contentWindow.onafterprint = cleanupCashierPdf;
                        printFrame.contentWindow.focus();
                        printFrame.contentWindow.print();
                    } catch {
                        cleanupCashierPdf();
                        toast('error', 'Không mở được hộp thoại in của trình duyệt.');
                    }
                }, 100);
            };
            printFrame.src = cashierPdfObjectUrl;
        } catch (error) {
            cleanupCashierPdf();
            toast('error', error?.message || 'Không in được phiếu thu.');
        }
    }

    function showError(error) {
        if (error?.name === 'AbortError') return;
        toast('error', error?.message || 'Có lỗi khi tải dữ liệu thu ngân.');
    }

    document.querySelectorAll('input[name="thu-ngan-filter-status"]').forEach(radio => {
        radio.addEventListener('change', () => {
            if (currentSection !== 'thu-tien') return;
            currentPage = 1;
            loadList().catch(showError);
        });
    });

    const refresh = document.getElementById('thu-ngan-refresh');
    if (refresh) refresh.addEventListener('click', () => {
        currentPage = 1;
        loadList().catch(showError);
    });

    const searchBtn = document.getElementById('thu-ngan-search-btn');
    if (searchBtn) searchBtn.addEventListener('click', () => {
        currentPage = 1;
        loadList().catch(showError);
    });

    if (searchInput) {
        searchInput.addEventListener('input', () => {
            clearTimeout(searchTimer);
            searchTimer = setTimeout(() => {
                currentPage = 1;
                loadList().catch(showError);
            }, 300);
        });
        searchInput.addEventListener('keydown', event => {
            if (event.key !== 'Enter') return;
            event.preventDefault();
            clearTimeout(searchTimer);
            currentPage = 1;
            loadList().catch(showError);
        });
    }

    const ngayThuNgan = document.getElementById('thu-ngan-ngay');
    if (ngayThuNgan) {
        ngayThuNgan.addEventListener('change', () => {
            currentPage = 1;
            loadList().catch(showError);
        });
    }

    if (elNganHang) {
        elNganHang.addEventListener('change', () => {
            const hasBank = !!elNganHang.value;
            if (elChuyenKhoan) {
                elChuyenKhoan.disabled = !canCollect || !hasBank;
                if (!hasBank) {
                    elChuyenKhoan.value = formatMoneyNumber(0);
                } else if (canCollect) {
                    elChuyenKhoan.focus();
                    elChuyenKhoan.select();
                }
            }
            updatePaymentSummary();
        });
    }

    if (elChuyenKhoan) {
        elChuyenKhoan.addEventListener('focus', () => {
            elChuyenKhoan.value = String(Math.max(0, parseMoney(elChuyenKhoan.value)));
            elChuyenKhoan.select();
        });
        elChuyenKhoan.addEventListener('input', updatePaymentSummary);
        elChuyenKhoan.addEventListener('blur', () => {
            elChuyenKhoan.value = formatMoneyNumber(Math.max(0, parseMoney(elChuyenKhoan.value)));
            updatePaymentSummary();
        });
    }

    serviceSelectAll?.addEventListener('change', () => setGroupSelection('DICH_VU', serviceSelectAll.checked));
    medicineSelectAll?.addEventListener('change', () => setGroupSelection('THUOC', medicineSelectAll.checked));

    function bindGroupDiscount(select, group) {
        select?.addEventListener('change', () => {
            if (select.value === '') return;
            const item = discountCatalog.find(x => String(x.id) === select.value);
            if (!item) return;
            const percent = parsePercent(item.ti_le);
            rowsByGroup(group).forEach(row => {
                if (selectedForCollection(row) && !lineInputDisabled(row))
                    row.giam_phan_tram = percent;
            });
            document.querySelectorAll('.tn-line-discount').forEach(input => {
                const row = currentDetailRows.find(x => Number(x.id) === Number(input.dataset.id));
                if (row && !input.disabled) input.value = formatPercent(row.giam_phan_tram);
            });
            updatePaymentSummary();
        });
    }

    async function loadDiscountCatalog() {
        // Thu ngân chỉ đọc bản JSON đã xuất bản cho CSKCB đăng nhập.
        // API danh_muc chọn tenant từ phiên làm việc, không truyền CSKCB tùy ý.
        const res = await apiGet('/api/danh_muc/ma_giam_gia', { top: 1000 });
        if (res.status !== 200 || !Array.isArray(res.data))
            throw new Error(res.message || 'Không tải được JSON mã giảm giá của cơ sở.');
        discountCatalog = res.data.map(x => ({
            id: Number(x.id),
            ma_giam_gia: x.ma || '',
            ten_giam_gia: x.ten || '',
            ti_le: Number(x.ti_le)
        })).filter(x => x.id > 0 && Number.isFinite(x.ti_le) && x.ti_le >= 0 && x.ti_le <= 100);
        for (const select of [serviceDiscount, medicineDiscount]) {
            if (!select) continue;
            const oldValue = select.value;
            select.innerHTML = '<option value="">-- Mã giảm giá --</option>' + discountCatalog.map(x =>
                '<option value="' + Number(x.id) + '">' +
                escapeHtml(x.ten_giam_gia || x.ma_giam_gia) +
                '</option>').join('');
            if (discountCatalog.some(x => String(x.id) === oldValue))
                select.value = oldValue;
        }
    }

    bindGroupDiscount(serviceDiscount, 'DICH_VU');
    bindGroupDiscount(medicineDiscount, 'THUOC');

    historyExcel?.addEventListener('click', () => {
        if (!canExport || selectedVisitId <= 0) return;
        window.location.href = '/thu_ngan/lich-su-chung-tu/excel?id_vao_vien=' + encodeURIComponent(selectedVisitId);
    });

    document.querySelectorAll('[data-thu-ngan-group]').forEach(button => {
        button.addEventListener('click', () => {
            activateSection(button.dataset.thuNganGroup).catch(showError);
        });
    });

    if (btnThu) btnThu.addEventListener('click', collectPayment);
    document.addEventListener('DOMContentLoaded', async () => {
        const ngay = document.getElementById('thu-ngan-ngay');
        const tuNgay = document.getElementById('thu-ngan-tu-ngay');
        const denNgay = document.getElementById('thu-ngan-den-ngay');

        if (window.initDatePicker) {
            initDatePicker('#thu-ngan-ngay', { defaultDate: 'today' });
            initDatePicker('#thu-ngan-tu-ngay');
            initDatePicker('#thu-ngan-den-ngay');
        }

        const today = todayVN();

        if (ngay && (!ngay.value || ngay.value === '__-__-____')) ngay.value = today;
        if (tuNgay && (!tuNgay.value || tuNgay.value === '__-__-____')) tuNgay.value = today;
        if (denNgay && (!denNgay.value || denNgay.value === '__-__-____')) denNgay.value = today;

        await loadDiscountCatalog().catch(showError);
        await loadBanks();
        await loadList().catch(showError);
    });
})();
