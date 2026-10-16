(() => {
    const root = document.getElementById('kho-workspace');
    if (!root) return;

    const isManagement = root.dataset.khoMode === 'quan-ly';
    const managementTabs = ['ton-kho', 'nhap-kho', 'dieu-chinh', 'phan-nhom'];
    let pageReady = false;
    let importInitialized = false;
    let adjustmentInitialized = false;

    const canImport = root.dataset.canImport === '1';
    const canDispense = root.dataset.canDispense === '1';
    const canReturn = root.dataset.canReturn === '1';
    const canExport = root.dataset.canExport === '1';
    const money = value => Number(value || 0).toLocaleString('vi-VN') + ' đ';
    const numberText = value => Number(value || 0).toLocaleString('vi-VN', { maximumFractionDigits: 4 });
    const escapeHtml = value => String(value == null ? '' : value).replace(/[&<>"']/g, ch => ({
        '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
    }[ch]));

    let warehouses = [];
    let currentWarehouseId = 0;
    const isManagementPage = root.dataset.khoMode === 'quan-ly';
    const managementTabNames = ['ton-kho', 'nhap-kho', 'dieu-chinh', 'phan-nhom'];
    let currentTab = isManagementPage ? 'ton-kho' : 'xuat-thuoc';

    let stockPage = 1;
    let stockPageSize = 25;
    let stockPager = null;
    let stockSearchTimer = null;
    let stockAbort = null;

    let importRows = [];
    let importDrugSelect = null;
    let importBusy = false;

    let adjustmentDrugSelect = null;
    let adjustmentLots = [];
    let adjustmentBusy = false;

    let dispenseStatus = 'chua_cap';
    let dispensePage = 1;
    let dispensePageSize = 25;
    let dispensePager = null;
    let dispenseSearchTimer = null;
    let dispenseListAbort = null;
    let dispenseDetailAbort = null;
    let selectedVisitId = 0;
    let currentDispenseInfo = null;
    let currentDispenseRows = [];
    let dispenseBusy = false;
    let pendingCancellationVisitId = 0;

    function toast(type, message) {
        if (window.showToast) showToast(type, message);
        else alert(message);
    }

    function dateVN(value) {
        if (!value) return '';
        const d = new Date(value);
        if (Number.isNaN(d.getTime())) return '';
        return String(d.getDate()).padStart(2, '0') + '-' +
            String(d.getMonth() + 1).padStart(2, '0') + '-' + d.getFullYear();
    }

    function expiryMeta(value, nearExpiry) {
        if (!value) return { text: '', cls: '' };
        const d = new Date(value);
        if (Number.isNaN(d.getTime())) return { text: '', cls: '' };
        // Use the same server-side 30-day rule as filtering and pagination.
        return { text: dateVN(value), cls: nearExpiry ? 'text-warning fw-bold' : '' };
    }

    function toIsoDate(raw) {
        const text = String(raw || '').trim();
        if (!text || text === '__-__-____') return null;
        const parts = text.split('-');
        if (parts.length !== 3) return null;
        if (parts[0].length === 4) return text;
        if (parts[2].length !== 4) return null;
        const d = Number(parts[0]);
        const m = Number(parts[1]);
        const y = Number(parts[2]);
        const dt = new Date(y, m - 1, d);
        if (dt.getFullYear() !== y || dt.getMonth() !== m - 1 || dt.getDate() !== d) return null;
        return String(y).padStart(4, '0') + '-' + String(m).padStart(2, '0') + '-' + String(d).padStart(2, '0');
    }

    function setBusy(button, busy, busyText) {
        if (!button) return;
        if (busy) {
            if (!button.dataset.originalHtml) button.dataset.originalHtml = button.innerHTML;
            button.disabled = true;
            button.innerHTML = '<span class="spinner-border spinner-border-sm me-1"></span>' + busyText;
        } else {
            button.disabled = false;
            if (button.dataset.originalHtml) {
                button.innerHTML = button.dataset.originalHtml;
                delete button.dataset.originalHtml;
            }
        }
    }

    async function loadWarehouses() {
        const res = await apiGet('/kho/api/danh-sach-kho');
        if (res.status !== 200 || !Array.isArray(res.data)) {
            throw new Error(res.message || 'Không tải được danh sách kho.');
        }
        warehouses = res.data;
        if (!warehouses.length) throw new Error('Cơ sở chưa có kho hoạt động.');

        // Cấp phát dùng kho hoạt động mặc định của CSKCB.
        currentWarehouseId = Number(warehouses[0].id || 0);
    }

    function initImportDatePicker() {
        const input = document.getElementById('kho-nhap-ngay-hd');
        if (!input || typeof window.initDatePicker !== 'function' || !window.jQuery) return;

        // HIS DateTimePicker calculates its built-in left/top relative to the
        // input parent, even when widgetParent is BODY. Reposition the actual
        // popup against the input's viewport rectangle instead.
        window.initDatePicker(input, {
            widgetParent: 'body',
            widgetPositioning: { horizontal: 'left', vertical: 'bottom' }
        });

        const positionPopup = () => {
            // Do not assume the plugin creates the widget as a direct BODY child.
            const candidates = Array.from(document.querySelectorAll('.bootstrap-datetimepicker-widget'))
                .filter(element => element.getClientRects().length > 0
                    && window.getComputedStyle(element).display !== 'none');
            const popup = candidates[candidates.length - 1];
            if (!popup) return;
            if (popup.parentElement !== document.body) document.body.appendChild(popup);
            popup.classList.add('kho-invoice-datepicker-popup');

            const rect = input.getBoundingClientRect();
            const width = Math.min(360, Math.max(290, window.innerWidth - 16));
            const height = popup.offsetHeight || 330;
            const left = Math.min(Math.max(8, rect.left), Math.max(8, window.innerWidth - width - 8));
            const below = rect.bottom + 4;
            const above = rect.top - height - 4;
            const top = below + height <= window.innerHeight - 8
                ? below : above >= 8 ? above : Math.max(8, window.innerHeight - height - 8);

            // Important overrides the inline left/top from the datetimepicker
            // and prevents the popup from jumping to the page's top-left corner.
            const style = popup.style;
            style.setProperty('position', 'fixed', 'important');
            style.setProperty('left', left + 'px', 'important');
            style.setProperty('top', top + 'px', 'important');
            style.setProperty('right', 'auto', 'important');
            style.setProperty('bottom', 'auto', 'important');
            style.setProperty('width', width + 'px', 'important');
            style.setProperty('z-index', '30000', 'important');
        };

        const schedulePosition = () => {
            positionPopup();
            window.requestAnimationFrame(positionPopup);
        };
        window.jQuery(input).on('dp.show', schedulePosition);
        input.addEventListener('focus', () => window.requestAnimationFrame(positionPopup));
        input.addEventListener('click', () => window.requestAnimationFrame(positionPopup));
        window.addEventListener('resize', positionPopup);
        window.addEventListener('scroll', positionPopup, true);
    }

    function initDispenseFilters() {
        const from = document.getElementById('kho-cap-tu-ngay');
        const to = document.getElementById('kho-cap-den-ngay');

        if (window.initDatePicker) {
            initDatePicker('#kho-cap-tu-ngay');
            initDatePicker('#kho-cap-den-ngay');
        }

        // Cấp phát: mặc định Từ ngày và Đến ngày đều là ngày hiện tại.
        // Chỉ thiết lập khi bộ lọc chưa có giá trị để giữ lựa chọn của người dùng.
        const today = dateVN(new Date());
        if (from && (!from.value || from.value === '__-__-____')) from.value = today;
        if (to && (!to.value || to.value === '__-__-____')) to.value = today;
    }

    function currentWarehouseName() {
        const row = warehouses.find(x => Number(x.id || 0) === Number(currentWarehouseId));
        return row ? String(row.ten || row.ten_kho || row.ma || 'Kho') : '';
    }

    function dispensePrescriptionType(value) {
        const type = String(value || '').toLowerCase();
        if (type === 'n') return 'Toa gây nghiện';
        if (type === 'h') return 'Toa hướng thần / tiền chất';
        return 'Toa cơ bản';
    }

    function dispenseUseText(row) {
        const parts = [];
        if (row.cach_dung) parts.push(String(row.cach_dung));
        const doses = [];
        if (row.sang) doses.push('Sáng ' + row.sang);
        if (row.trua) doses.push('Trưa ' + row.trua);
        if (row.chieu) doses.push('Chiều ' + row.chieu);
        if (row.toi) doses.push('Tối ' + row.toi);
        if (doses.length) parts.push(doses.join(' - '));
        if (row.so_ngay) parts.push(String(row.so_ngay) + ' ngày');
        return parts.join(' • ');
    }

    async function loadSuppliers(selectedId) {
        const select = document.getElementById('kho-nhap-ncc');
        if (!select) return;
        const previous = selectedId ? String(selectedId)
            : String(select.tomselect?.getValue() || select.value || '');
        const res = await apiGet('/kho/api/nha-cung-cap');
        if (res.status !== 200) throw new Error(res.message || 'Không tải được nhà cung cấp.');

        const options = (Array.isArray(res.data) ? res.data : [])
            .map(x => ({ value: String(Number(x.id)), text: String(x.ten || x.ma || '') }));
        if (!select.tomselect && typeof TomSelect !== 'undefined') {
            new TomSelect(select, { create: false, allowEmptyOption: true, dropdownParent: 'body', maxOptions: 1000 });
        }
        const valid = options.some(x => x.value === previous) ? previous : '';
        if (select.tomselect) {
            const ts = select.tomselect;
            ts.clear(true);
            ts.clearOptions();
            ts.addOptions([{ value: '', text: '-- Chọn nhà cung cấp --' }, ...options]);
            ts.refreshOptions(false);
            ts.setValue(valid, true);
        } else {
            select.innerHTML = '<option value="">-- Chọn nhà cung cấp --</option>' + options.map(x =>
                '<option value="' + escapeHtml(x.value) + '">' + escapeHtml(x.text) + '</option>').join('');
            select.value = valid;
        }
    }

    const SUPPLIER_DRAFT_KEY = 'qlpm:kho:nhap:ncc-draft-v1';

    function openSupplierDirectory() {
        if (!canImport) return;
        try {
            sessionStorage.setItem(SUPPLIER_DRAFT_KEY, JSON.stringify({
                rows: importRows,
                supplier: Number(document.getElementById('kho-nhap-ncc')?.value || 0),
                invoice: document.getElementById('kho-nhap-so-hd')?.value || '',
                date: document.getElementById('kho-nhap-ngay-hd')?.value || '',
                note: document.getElementById('kho-nhap-ghi-chu')?.value || ''
            }));
        } catch (_) {
            toast('warning', 'Không lưu được bản nháp phiếu nhập khi chuyển sang danh mục.');
        }
        location.href = '/danh_muc/nha_cung_cap?tu_nhap_kho=1';
    }

    function restoreSupplierDraft(query = new URLSearchParams(location.search)) {
        if (query.get('tab') !== 'nhap-kho') return { returning: false, supplier: 0 };
        let supplier = 0;
        try {
            const raw = sessionStorage.getItem(SUPPLIER_DRAFT_KEY);
            if (raw) {
                const state = JSON.parse(raw);
                if (Array.isArray(state.rows)) importRows = state.rows;
                document.getElementById('kho-nhap-so-hd').value = state.invoice || '';
                document.getElementById('kho-nhap-ghi-chu').value = state.note || '';
                const el = document.getElementById('kho-nhap-ngay-hd');
                const picker = window.jQuery ? window.jQuery(el).data('DateTimePicker') : null;
                if (picker) picker.date(state.date && state.date !== '__-__-____'
                    ? window.moment(state.date, 'DD-MM-YYYY') : null);
                else if (el) el.value = state.date || '__-__-____';
                supplier = Number(state.supplier || 0);
            }
            sessionStorage.removeItem(SUPPLIER_DRAFT_KEY);
        } catch (_) {}
        const selected = Number(query.get('nha_cung_cap_id') || 0);
        return { returning: true, supplier: selected > 0 ? selected : supplier };
    }

    function confirmImportCancellation() {
        return new Promise(resolve => {
            const element = document.getElementById('kho-nhap-huy-modal');
            if (!element || !window.bootstrap?.Modal) {
                toast('error', 'Không mở được hộp xác nhận hủy phiếu nhập.');
                resolve(false);
                return;
            }
            const submit = document.getElementById('kho-nhap-huy-submit');
            const modal = bootstrap.Modal.getOrCreateInstance(element);
            let answer = false;

            function confirmCancellation() {
                answer = true;
                modal.hide();
            }
            function finish() {
                submit.removeEventListener('click', confirmCancellation);
                resolve(answer);
            }
            submit.addEventListener('click', confirmCancellation);
            element.addEventListener('hidden.bs.modal', finish, { once: true });
            element.addEventListener('shown.bs.modal', () => submit.focus(), { once: true });
            modal.show();
        });
    }

    async function loadImportHistory() {
        const body = document.getElementById('kho-nhap-history');
        if (!body) return;
        const res = await apiGet('/kho/api/phieu-nhap');
        if (res.status !== 200) throw new Error(res.message || 'Không tải được phiếu nhập.');
        const rows = Array.isArray(res.data) ? res.data : [];
        body.innerHTML = rows.length ? rows.map(x => {
            const cancelled = Number(x.da_huy) === 1;
            return '<tr><td class="font-monospace">' + escapeHtml(x.so_phieu) + '</td><td>' + escapeHtml(dateVN(x.ngay_nhap)) + '</td>' +
                '<td>' + escapeHtml(x.nha_cung_cap || '') + '</td><td>' + escapeHtml(x.so_hoa_don || '') + '</td>' +
                '<td class="text-end">' + money(x.tong_tien) + '</td><td class="' + (cancelled ? 'text-danger' : 'text-success') + '">' + (cancelled ? 'Đã hủy' : 'Đã nhập') + '</td>' +
                '<td><div class="d-flex flex-wrap gap-2">' +
                '<button class="btn btn-sm btn-outline-success kho-import-doc" data-action="print" data-id="' + Number(x.id) + '"' + (canExport ? '' : ' disabled') + '>In</button>' +
                '<button class="btn btn-sm btn-outline-success kho-import-doc" data-action="excel" data-id="' + Number(x.id) + '"' + (canExport ? '' : ' disabled') + '>Tải Excel</button>' +
                '<button class="btn btn-sm btn-outline-danger kho-import-doc" data-action="cancel" data-id="' + Number(x.id) + '"' + (!cancelled && canReturn ? '' : ' disabled') + '>Hủy</button></div></td></tr>';
        }).join('') : '<tr><td colspan="7" class="text-center text-muted">Chưa có phiếu nhập.</td></tr>';
        body.querySelectorAll('.kho-import-doc').forEach(button => button.addEventListener('click', () => handleImportDocument(button).catch(showError)));
    }

    async function handleImportDocument(button) {
        const id = Number(button.dataset.id || 0), action = button.dataset.action || '';
        if (!id || button.disabled) return;
        if (action === 'print' || action === 'excel') {
            if (!canExport) return;
            if (action === 'print' && importPrintBusy) return;
            if (action === 'print') importPrintBusy = true;
            setBusy(button, true, action === 'print' ? 'Đang tạo bản in...' : 'Đang tải...');
            try {
                const response = await fetch('/kho/phieu-nhap/' + (action === 'print' ? 'pdf' : 'excel') + '?id=' + encodeURIComponent(id),
                    { credentials: 'same-origin', cache: 'no-store' });
                if (!response.ok) {
                    const message = await response.text();
                    throw new Error(message || 'Không tải được phiếu (' + response.status + ').');
                }
                const blob = await response.blob();
                const type = action === 'print' ? 'application/pdf' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
                if (!blob.size || !blob.type.startsWith(type)) throw new Error('File phiếu không hợp lệ.');
                if (action === 'print') await printImportPdf(blob);
                else {
                    const disposition = response.headers.get('Content-Disposition') || '';
                    const utfName = disposition.match(/filename\*=UTF-8''([^;]+)/i);
                    const plainName = disposition.match(/filename="?([^";]+)"?/i);
                    let filename = 'phieu-nhap-' + id + '.xlsx';
                    if (utfName) { try { filename = decodeURIComponent(utfName[1]); } catch (_) { /* Dùng tên dự phòng. */ } }
                    else if (plainName) filename = plainName[1].trim();
                    const url = URL.createObjectURL(blob);
                    const link = document.createElement('a');
                    link.href = url; link.download = filename; document.body.appendChild(link);
                    link.click(); link.remove();
                    window.setTimeout(() => URL.revokeObjectURL(url), 60000);
                }
            } finally {
                if (action === 'print') importPrintBusy = false;
                setBusy(button, false, '');
            }
            return;
        }
        if (action === 'cancel') {
            if (!canReturn) return;
            button.disabled = true;
            try {
                if (!await confirmImportCancellation()) return;
                const res = await apiPost('/kho/api/phieu-nhap/huy', { id });
                if (res.status !== 200) throw new Error(res.message || 'Không hủy được phiếu nhập.');
                toast('success', res.message || 'Đã hủy phiếu nhập.');
                await loadImportHistory();
            } finally { button.disabled = false; }
            return;
        }
    }

    let importPrintUrl = null;
    let importPrintBusy = false;
    async function printImportPdf(blob) {
        const frame = document.getElementById('kho-nhap-print-frame');
        if (!frame) throw new Error('Không tìm thấy vùng in phiếu nhập.');
        if (importPrintUrl) URL.revokeObjectURL(importPrintUrl);
        const url = URL.createObjectURL(blob);
        importPrintUrl = url;
        await new Promise((resolve, reject) => {
            const timeout = window.setTimeout(() => {
                frame.onload = null;
                frame.src = 'about:blank';
                URL.revokeObjectURL(url);
                if (importPrintUrl === url) importPrintUrl = null;
                reject(new Error('Chưa tải được PDF để in. Thử lại.'));
            }, 15000);
            frame.onload = () => {
                window.clearTimeout(timeout); frame.onload = null;
                try {
                    frame.contentWindow.focus();
                    frame.contentWindow.onafterprint = () => {
                        if (importPrintUrl === url) {
                            frame.src = 'about:blank'; URL.revokeObjectURL(url); importPrintUrl = null;
                        }
                    };
                    frame.contentWindow.print(); resolve();
                } catch (error) { reject(error); }
            };
            frame.src = url;
        });
    }

    function activateTab(name, updateUrl = true) {
        if (isManagementPage && !managementTabNames.includes(name)) name = 'ton-kho';
        if (!isManagementPage && name !== 'xuat-thuoc') return;

        currentTab = name;
        document.querySelectorAll('[data-kho-tab]').forEach(btn => {
            const active = btn.dataset.khoTab === name;
            btn.classList.toggle('active', active);
            btn.setAttribute('aria-selected', String(active));
        });
        document.querySelectorAll('[data-kho-panel]').forEach(panel => {
            panel.classList.toggle('d-none', panel.dataset.khoPanel !== name);
        });

        if (isManagementPage && updateUrl) {
            const url = new URL(location.href);
            url.searchParams.set('tab', name);
            history.replaceState(history.state, '', url.pathname + url.search + url.hash);
        }
        if (name === 'ton-kho') loadStock().catch(showError);
        if (name === 'xuat-thuoc') loadDispenseList().catch(showError);
        if (name === 'dieu-chinh') {
            if (!adjustmentInitialized) {
                initAdjustmentDrugSelect();
                adjustmentInitialized = true;
            }
            // Chuyển tab đồng bộ, nạp dữ liệu nền và xử lý lỗi riêng cho mỗi request.
            loadAdjustmentHistory().catch(showError);
            if (adjustmentDrugSelect?.getValue()) loadAdjustmentLots().catch(showError);
        }
        if (name === 'phan-nhom') {
            document.dispatchEvent(new CustomEvent('kho:phan-nhom-activate'));
        }
    }

    /* ==================== ĐIỀU CHỈNH / HỦY THUỐC ==================== */

    function initAdjustmentDrugSelect() {
        if (!window.initRemoteTomSelect) return;
        adjustmentDrugSelect = initRemoteTomSelect('#kho-dc-thuoc', 'dm_thuoc', {
            localSearch: true,
            localSearchTop: 2000,
            dropdownParent: 'body',
            showCodeInItem: true,
            placeholder: 'Chọn thuốc cần điều chỉnh...'
        });
        adjustmentDrugSelect?.on('change', () => loadAdjustmentLots().catch(showError));
    }

    function renderAdjustmentLots() {
        const body = document.getElementById('kho-dc-body');
        if (!body) return;
        if (!adjustmentLots.length) {
            body.innerHTML = '<tr><td colspan="7" class="text-center text-muted py-4">Thuốc chưa có lô nhập trong kho.</td></tr>';
            return;
        }
        const isDisposal = document.getElementById('kho-dc-loai')?.value === 'HUY_THUOC';
        body.innerHTML = adjustmentLots.map((x, index) => {
            const expired = Number(x.het_han) === 1;
            const active = Number(x.active) === 1;
            const state = expired ? '<span class="badge text-bg-danger">Hết hạn</span>'
                : active ? '<span class="badge text-bg-success">Hoạt động</span>'
                : '<span class="badge text-bg-secondary">Đã khóa</span>';
            const min = isDisposal ? ' min="0"' : '';
            return '<tr data-id="' + Number(x.id_lo_thuoc) + '">' +
                '<td class="text-center text-muted">' + (index + 1) + '</td>' +
                '<td>' + escapeHtml(x.so_lo || '(không số lô)') + '</td>' +
                '<td class="text-center ' + (expired ? 'text-danger fw-semibold' : '') + '">' + escapeHtml(dateVN(x.han_dung)) + '</td>' +
                '<td class="text-end">' + numberText(x.ton_vat_ly) + '</td>' +
                '<td class="text-end">' + numberText(x.ton_kha_dung) + '</td>' +
                '<td class="text-center">' + state + '</td>' +
                '<td><input type="number" class="form-control form-control-sm text-end kho-dc-qty" step="0.0001"' + min +
                ' value="0" ' + (!canReturn ? 'disabled' : '') + ' /></td></tr>';
        }).join('');
        const help = document.getElementById('kho-dc-help');
        if (help) help.textContent = isDisposal
            ? 'Hủy thuốc: nhập số lượng dương cần loại khỏi tồn vật lý. Không đổi trạng thái lô để che số tồn.'
            : 'Điều chỉnh: nhập số dương để tăng, số âm để giảm. Tồn sau điều chỉnh không được âm.';
    }

    async function loadAdjustmentLots() {
        const body = document.getElementById('kho-dc-body');
        if (!body) return;
        const idDrug = Number(adjustmentDrugSelect?.getValue() || 0);
        if (!idDrug) {
            adjustmentLots = [];
            body.innerHTML = '<tr><td colspan="7" class="text-center text-muted py-4">Chọn thuốc để xem các lô.</td></tr>';
            return;
        }
        body.innerHTML = '<tr><td colspan="7" class="text-center text-muted py-4">Đang tải lô thuốc...</td></tr>';
        const res = await apiGet('/kho/api/lo-thuoc?id_thuoc=' + encodeURIComponent(idDrug));
        if (res.status !== 200) throw new Error(res.message || 'Không tải được lô thuốc.');
        adjustmentLots = Array.isArray(res.data) ? res.data : [];
        renderAdjustmentLots();
    }

    async function loadAdjustmentHistory() {
        const body = document.getElementById('kho-dc-history');
        if (!body) return;
        const res = await apiGet('/kho/api/dieu-chinh-ton/lich-su');
        if (res.status !== 200) throw new Error(res.message || 'Không tải được lịch sử điều chỉnh tồn.');
        const rows = Array.isArray(res.data) ? res.data : [];
        body.innerHTML = rows.length ? rows.map(x => {
            const disposal = x.loai === 'HUY_THUOC';
            return '<tr><td class="font-monospace">' + escapeHtml(x.so_phieu) + '</td>' +
                '<td>' + escapeHtml(new Date(x.ngay_gio).toLocaleString('vi-VN')) + '</td>' +
                '<td><span class="badge ' + (disposal ? 'text-bg-danger' : 'text-bg-primary') + '">' + (disposal ? 'Hủy thuốc' : 'Điều chỉnh') + '</span></td>' +
                '<td>' + escapeHtml(x.nguoi_lap || '') + '</td><td>' + escapeHtml(x.ly_do || '') + '</td>' +
                '<td class="text-end">' + numberText(x.so_dong) + '</td><td class="text-end">' + numberText(x.tong_thay_doi) + '</td></tr>';
        }).join('') : '<tr><td colspan="7" class="text-center text-muted">Chưa có chứng từ.</td></tr>';
    }

    async function saveAdjustment() {
        if (!canReturn || adjustmentBusy) return;
        const type = document.getElementById('kho-dc-loai')?.value || '';
        const rows = [];
        document.querySelectorAll('#kho-dc-body tr[data-id]').forEach(tr => {
            const quantity = Number(tr.querySelector('.kho-dc-qty')?.value || 0);
            if (quantity !== 0) rows.push({ id_lo_thuoc: Number(tr.dataset.id), so_luong: quantity });
        });
        if (!rows.length) return toast('warning', 'Chưa nhập số lượng cần xử lý.');
        if (type === 'HUY_THUOC' && rows.some(x => x.so_luong <= 0))
            return toast('warning', 'Số lượng hủy phải lớn hơn 0.');

        const btn = document.getElementById('kho-dc-save');
        adjustmentBusy = true;
        setBusy(btn, true, 'Đang lưu...');
        try {
            const res = await apiPost('/kho/api/dieu-chinh-ton', { loai: type, danh_sach: rows });
            if (res.status !== 200) throw new Error(res.message || 'Không lập được chứng từ kho.');
            toast('success', (res.message || 'Đã ghi chứng từ kho.') + (res.data?.SoPhieu ? ' Số ' + res.data.SoPhieu : ''));
            await Promise.all([loadAdjustmentLots(), loadAdjustmentHistory()]);
        } catch (error) {
            toast('error', error.message || 'Không lập được chứng từ kho.');
        } finally {
            adjustmentBusy = false;
            setBusy(btn, false, '');
        }
    }

    /* ==================== TỒN KHO ==================== */

    function ensureStockPager() {
        if (stockPager || !window.createQLPMPagination) return stockPager;
        stockPager = createQLPMPagination({
            container: '#kho-ton-pagination',
            itemName: 'thuốc',
            pageSize: stockPageSize,
            currentPage: stockPage,
            pageSizes: [10, 25, 50, 100],
            compact: true,
            tableScrollSelector: '#kho-ton-scroll',
            onPageChange: (page, size) => {
                stockPage = page;
                stockPageSize = size;
                loadStock().catch(showError);
            }
        });
        return stockPager;
    }

    async function loadStock() {
        const body = document.getElementById('kho-ton-body');
        if (!body) return;

        if (stockAbort) stockAbort.abort();
        const controller = new AbortController();
        stockAbort = controller;
        body.innerHTML = '<tr><td colspan="11" class="text-center text-muted py-4">Đang tải tồn kho...</td></tr>';

        const idKho = currentWarehouseId;
        const params = new URLSearchParams();
        if (idKho) params.set('id_kho', String(idKho));
        const q = document.getElementById('kho-ton-search').value.trim();
        if (q) params.set('q', q);
        params.set('trang_thai', document.getElementById('kho-ton-status')?.value || 'tat_ca');
        params.set('trang', String(stockPage));
        params.set('kich_thuoc_trang', String(stockPageSize));

        const response = await fetch('/kho/api/ton-kho?' + params.toString(), {
            credentials: 'same-origin',
            signal: controller.signal
        });
        const result = await response.json();
        if (controller !== stockAbort) return;
        if (!response.ok || result.status !== 200) throw new Error(result.message || 'Không tải được tồn kho.');

        const rows = result.data && result.data.danh_sach ? result.data.danh_sach : [];
        const total = Number(result.data && result.data.tong_so ? result.data.tong_so : 0);
        stockPage = Number(result.data && result.data.trang ? result.data.trang : stockPage);
        stockPageSize = Number(result.data && result.data.kich_thuoc_trang ? result.data.kich_thuoc_trang : stockPageSize);

        document.getElementById('kho-ton-count').textContent = total + ' thuốc';
        if (!rows.length) {
            body.innerHTML = '<tr><td colspan="11" class="text-center text-muted py-4">Không có thuốc phù hợp.</td></tr>';
        } else {
            body.innerHTML = rows.map((x, index) => {
                const physical = Number(x.ton_vat_ly || 0);
                const expired = Number(x.ton_het_han || 0);
                const stock = Number(x.ton_kha_dung || 0);
                const nearExpiry = x.sap_het_han === true || x.sap_het_han === 1;
                const expiry = expiryMeta(x.han_gan_nhat, nearExpiry);
                const state = physical <= 0 ? '<span class="badge text-bg-danger">Hết thuốc</span>'
                    : stock <= 0 ? '<span class="badge text-bg-secondary">Không cấp được</span>'
                    : '<span class="badge text-bg-success">Còn cấp được</span>';
                const warnings = (nearExpiry ? '<span class="badge text-bg-warning">Sắp hết hạn</span>' : '')
                    + (expired > 0 ? '<span class="badge text-bg-danger">Có lô hết hạn/khóa</span>' : '');
                const stockClass = stock <= 0 ? 'text-danger fw-bold' : '';
                return '<tr>' +
                    '<td class="text-center text-muted">' + ((stockPage - 1) * stockPageSize + index + 1) + '</td>' +
                    '<td>' + escapeHtml(x.ma_thuoc || '') + '</td>' +
                    '<td>' + escapeHtml(x.ten_thuoc || '') + '</td>' +
                    '<td>' + escapeHtml(x.don_vi_tinh || '') + '</td>' +
                    '<td class="text-end">' + numberText(physical) + '</td>' +
                    '<td class="text-end ' + (expired > 0 ? 'text-danger fw-semibold' : '') + '">' + numberText(expired) + '</td>' +
                    '<td class="text-end ' + stockClass + '">' + numberText(stock) + '</td>' +
                    '<td class="text-center ' + expiry.cls + '">' + escapeHtml(expiry.text || (stock > 0 ? 'Chưa có HSD' : '—')) + '</td>' +
                    '<td class="text-center">' + numberText(x.so_lo) + '</td>' +
                    '<td class="text-end">' + money(x.gia_ban) + '</td>' +
                    '<td><div class="d-flex flex-wrap gap-1">' + state + warnings + '</div></td>' +
                    '</tr>';
            }).join('');
        }

        const pager = ensureStockPager();
        if (pager) {
            pager.render(total, stockPage);
            stockPage = pager.getCurrentPage();
            stockPageSize = pager.getPageSize();
        }
    }

    /* ==================== NHẬP KHO ==================== */

    function initImportDrugSelect() {
        if (!window.initRemoteTomSelect || !document.getElementById('kho-nhap-thuoc')) return;
        importDrugSelect = initRemoteTomSelect('#kho-nhap-thuoc', 'dm_thuoc', {
            localSearch: true,
            localSearchTop: 2000,
            dropdownParent: 'body',
            showCodeInItem: true,
            placeholder: 'Tìm và chọn hàng hóa...'
        });
        if (importDrugSelect) importDrugSelect.on('change', value => {
            if (value) addImportRow();
        });
    }

    function addImportRow() {
        if (!canImport) return;
        if (!importDrugSelect) return toast('warning', 'Danh mục thuốc chưa sẵn sàng.');

        const value = importDrugSelect.getValue();
        if (!value) return toast('warning', 'Chọn thuốc cần nhập.');

        const drug = importDrugSelect.options[value];
        if (!drug) return toast('warning', 'Không đọc được thông tin thuốc.');
        if (!drug.id_don_vi_tinh) return toast('warning', 'Thuốc chưa có đơn vị tính mặc định.');

        importRows.push({
            key: Date.now() + Math.random(),
            id_thuoc: Number(drug.id),
            ma: drug.ma || '',
            ten: drug.ten || '',
            id_don_vi_tinh: Number(drug.id_don_vi_tinh),
            don_vi_tinh: drug.don_vi_tinh || '',
            so_lo: '',
            han_dung: '',
            so_luong: 1,
            // Không lấy giá bán làm giá mua; để trống (0) cho người nhập xác nhận.
            gia_nhap: 0
        });
        renderImportRows();
    }

    // Ô nhập thường, chỉ nhận chữ số. SL được phép tối đa 4 chữ số thập phân;
    // giá nhập là VND nguyên. Không cho ký tự e, +, -, hoặc khoảng trắng.
    function cleanImportNumber(value, allowDecimal) {
        let text = String(value || '').replace(/,/g, '.').replace(/[^0-9.]/g, '');
        if (allowDecimal) {
            const dot = text.indexOf('.');
            if (dot >= 0) text = text.slice(0, dot + 1) + text.slice(dot + 1).replace(/\./g, '').slice(0, 4);
            return text.startsWith('.') ? '0' + text : text;
        }
        return text.replace(/\./g, '').slice(0, 15);
    }

    function renderImportRows() {
        const body = document.getElementById('kho-nhap-body');
        const totalEl = document.getElementById('kho-nhap-total');
        if (!body || !totalEl) return;

        // Trước khi thay tbody phải hủy instance cũ để dropdown TomSelect
        // không giữ tham chiếu tới select đã bị tháo khỏi DOM.
        if (importDrugSelect) {
            importDrugSelect.destroy();
            importDrugSelect = null;
        }

        const rowsHtml = importRows.map((row, index) => {
            const amount = Number(row.so_luong || 0) * Number(row.gia_nhap || 0);
            return '<tr data-key="' + row.key + '">' +
                '<td class="text-center text-muted">' + (index + 1) + '</td>' +
                '<td class="text-nowrap">' + escapeHtml(row.ma) + '</td>' +
                '<td class="fw-semibold kho-import-medicine-name" title="' + escapeHtml(row.ten) + '">' + escapeHtml(row.ten) + '</td>' +
                '<td><input type="text" inputmode="decimal" autocomplete="off" class="form-control form-control-sm text-end kho-nhap-sl" aria-label="Số lượng nhập" value="' + Number(row.so_luong || 0) + '" /></td>' +
                '<td class="text-nowrap">' + escapeHtml(row.don_vi_tinh) + '</td>' +
                '<td><input type="text" inputmode="numeric" autocomplete="off" class="form-control form-control-sm text-end kho-nhap-gia" aria-label="Giá nhập" value="' + Number(row.gia_nhap || 0) + '" /></td>' +
                '<td class="text-end fw-semibold kho-nhap-thanh-tien">' + money(amount) + '</td>' +
                '<td><input type="text" class="form-control form-control-sm kho-nhap-so-lo" maxlength="100" value="' + escapeHtml(row.so_lo || '') + '" /></td>' +
                '<td><input type="text" class="form-control form-control-sm kho-nhap-hsd" value="' + escapeHtml(row.han_dung || '') + '" autocomplete="off" placeholder="dd-MM-yyyy" /></td>' +
                '<td class="text-center"><button type="button" class="btn btn-sm btn-link text-danger kho-nhap-remove" title="Xóa dòng thuốc" aria-label="Xóa dòng thuốc"><i class="bi bi-trash"></i></button></td>' +
                '</tr>';
        }).join('');

        const addRow = canImport
            ? '<tr class="kho-import-new-row"><td class="text-center text-muted">+</td><td class="text-muted">—</td>' +
                '<td><select id="kho-nhap-thuoc" class="form-select form-select-sm" aria-label="Tìm và thêm hàng hóa vào phiếu nhập"></select></td>' +
                '<td colspan="7" class="text-muted small">Chọn thuốc để thêm một dòng mới</td></tr>'
            : '';
        body.innerHTML = rowsHtml + addRow ||
            '<tr class="kho-empty-row"><td colspan="10" class="text-center text-muted py-3">Chưa có thuốc trong phiếu nhập.</td></tr>';

        body.querySelectorAll('tr[data-key]').forEach(tr => {
            const key = Number(tr.dataset.key);
            const row = importRows.find(x => Number(x.key) === key);
            if (!row) return;
            const hsd = tr.querySelector('.kho-nhap-hsd');
            if (hsd && window.attachDateAutoMask) window.attachDateAutoMask(hsd, { minYear: 2000 });

            tr.querySelector('.kho-nhap-so-lo').addEventListener('input', e => row.so_lo = e.target.value);
            tr.querySelector('.kho-nhap-hsd').addEventListener('input', e => row.han_dung = e.target.value);
            tr.querySelector('.kho-nhap-sl').addEventListener('input', e => {
                const clean = cleanImportNumber(e.target.value, true);
                if (e.target.value !== clean) e.target.value = clean;
                row.so_luong = Number(clean || 0);
                updateImportAmounts();
            });
            tr.querySelector('.kho-nhap-gia').addEventListener('input', e => {
                const clean = cleanImportNumber(e.target.value, false);
                if (e.target.value !== clean) e.target.value = clean;
                row.gia_nhap = Number(clean || 0);
                updateImportAmounts();
            });
            tr.querySelector('.kho-nhap-remove').addEventListener('click', () => {
                importRows = importRows.filter(x => Number(x.key) !== key);
                renderImportRows();
            });
        });

        initImportDrugSelect();
        updateImportAmounts();
    }

    function updateImportAmounts() {
        const total = importRows.reduce((sum, row) =>
            sum + Number(row.so_luong || 0) * Number(row.gia_nhap || 0), 0);
        document.getElementById('kho-nhap-total').textContent = money(total);
        const count = document.getElementById('kho-nhap-count');
        if (count) count.textContent = String(importRows.length);

        document.querySelectorAll('#kho-nhap-body tr[data-key]').forEach(tr => {
            const row = importRows.find(x => Number(x.key) === Number(tr.dataset.key));
            const cell = tr.querySelector('.kho-nhap-thanh-tien');
            if (row && cell) cell.textContent = money(Number(row.so_luong || 0) * Number(row.gia_nhap || 0));
        });
    }

    async function saveImport() {
        if (!canImport || importBusy) return;
        if (!importRows.length) return toast('warning', 'Chưa có thuốc trong phiếu nhập.');

        const idKho = currentWarehouseId;
        if (!idKho) return toast('warning', 'Cơ sở chưa có kho hoạt động.');

        const payloadRows = [];
        for (const row of importRows) {
            if (Number(row.so_luong || 0) <= 0) return toast('warning', 'Số lượng nhập phải lớn hơn 0.');
            if (Number(row.gia_nhap || 0) < 0) return toast('warning', 'Giá nhập không hợp lệ.');

            let expiry = null;
            if (String(row.han_dung || '').trim()) {
                expiry = toIsoDate(row.han_dung);
                if (!expiry) return toast('warning', 'Hạn dùng phải theo dd-MM-yyyy.');
            }

            payloadRows.push({
                id_thuoc: row.id_thuoc,
                id_don_vi_tinh: row.id_don_vi_tinh,
                so_luong: Number(row.so_luong),
                gia_nhap: Number(row.gia_nhap),
                so_lo: String(row.so_lo || '').trim() || null,
                han_dung: expiry
            });
        }

        const invoiceRaw = document.getElementById('kho-nhap-ngay-hd')?.value.trim() || '';
        const invoiceEmpty = !invoiceRaw || invoiceRaw === '__-__-____';
        const invoiceDate = invoiceEmpty ? null : toIsoDate(invoiceRaw);
        if (!invoiceEmpty && !invoiceDate)
            return toast('warning', 'Ngày hóa đơn phải đúng định dạng dd-MM-yyyy.');

        const btn = document.getElementById('kho-nhap-save');
        importBusy = true;
        setBusy(btn, true, 'Đang nhập...');
        try {
            const res = await apiPost('/kho/api/nhap-kho', {
                id_kho: idKho,
                id_nha_cung_cap: Number(document.getElementById('kho-nhap-ncc')?.value || 0) || null,
                so_hoa_don: document.getElementById('kho-nhap-so-hd').value.trim() || null,
                ngay_hoa_don: invoiceDate,
                ghi_chu: document.getElementById('kho-nhap-ghi-chu').value.trim() || null,
                danh_sach: payloadRows
            });
            if (res.status !== 200) throw new Error(res.message || 'Không nhập được kho.');
            toast('success', res.message || 'Nhập kho thành công.');
            importRows = [];
            document.getElementById('kho-nhap-so-hd').value = '';
            const invoiceInput = document.getElementById('kho-nhap-ngay-hd');
            const invoicePicker = window.jQuery
                ? window.jQuery(invoiceInput).data('DateTimePicker')
                : null;
            if (invoicePicker) invoicePicker.date(null);
            if (invoiceInput) invoiceInput.value = '__-__-____';
            document.getElementById('kho-nhap-ghi-chu').value = '';
            renderImportRows();
            await loadImportHistory();
            stockPage = 1;
        } catch (error) {
            toast('error', error.message || 'Không nhập được kho.');
        } finally {
            importBusy = false;
            setBusy(btn, false, '');
        }
    }

    /* ==================== XUẤT THUỐC ==================== */

    function dispenseStateMeta(value) {
        switch (Number(value)) {
            case 1: return { text: 'Chưa cấp đủ', badge: 'text-bg-info' };
            case 2: return { text: 'Đã cấp', badge: 'text-bg-success' };
            default: return { text: 'Chưa cấp', badge: 'text-bg-warning' };
        }
    }

    function ensureDispensePager() {
        if (dispensePager || !window.createQLPMPagination) return dispensePager;
        dispensePager = createQLPMPagination({
            container: '#kho-cap-pagination',
            itemName: 'toa',
            pageSize: dispensePageSize,
            currentPage: dispensePage,
            pageSizes: [10, 25, 50, 100],
            compact: true,
            tableScrollSelector: '#kho-cap-list-scroll',
            onPageChange: (page, size) => {
                dispensePage = page;
                dispensePageSize = size;
                loadDispenseList().catch(showError);
            }
        });
        return dispensePager;
    }

    async function loadDispenseList() {
        const body = document.getElementById('kho-cap-list-body');
        if (!body) return;

        if (dispenseListAbort) dispenseListAbort.abort();
        const controller = new AbortController();
        dispenseListAbort = controller;
        body.innerHTML = '<tr><td colspan="5" class="text-center text-muted py-4">Đang tải...</td></tr>';

        const params = new URLSearchParams();
        params.set('trang_thai', dispenseStatus);
        params.set('trang', String(dispensePage));
        params.set('kich_thuoc_trang', String(dispensePageSize));

        const q = document.getElementById('kho-cap-search')?.value.trim() || '';
        const from = toIsoDate(document.getElementById('kho-cap-tu-ngay')?.value || '');
        const to = toIsoDate(document.getElementById('kho-cap-den-ngay')?.value || '');
        if (q) params.set('q', q);
        if (from) params.set('tu_ngay', from);
        if (to) params.set('den_ngay', to);

        const response = await fetch('/kho/api/cho-cap?' + params.toString(), {
            credentials: 'same-origin',
            signal: controller.signal
        });
        const result = await response.json();
        if (controller !== dispenseListAbort) return;
        if (!response.ok || result.status !== 200) throw new Error(result.message || 'Không tải được danh sách toa chờ cấp.');

        const rows = result.data && result.data.danh_sach ? result.data.danh_sach : [];
        const total = Number(result.data && result.data.tong_so ? result.data.tong_so : 0);
        dispensePage = Number(result.data && result.data.trang ? result.data.trang : dispensePage);
        dispensePageSize = Number(result.data && result.data.kich_thuoc_trang ? result.data.kich_thuoc_trang : dispensePageSize);
        const count = document.getElementById('kho-cap-count');
        if (count) count.textContent = total;

        if (!rows.length) {
            body.innerHTML = '<tr><td colspan="5" class="text-center text-muted py-4">Không có toa phù hợp.</td></tr>';
            selectedVisitId = 0;
            clearDispenseDetail();
        } else {
            body.innerHTML = rows.map((x, index) => {
                const state = Number(x.trang_thai_cap || 0);
                const selected = Number(x.id_vao_vien) === selectedVisitId ? ' table-active' : '';
                const stateClass = state === 2
                    ? ' kho-cap-row-done'
                    : (state === 1 ? ' kho-cap-row-partial' : ' kho-cap-row-pending');
                const year = x.ngay_sinh ? new Date(x.ngay_sinh).getFullYear() : '';
                const warning = Number(x.thieu_quy_doi || 0) > 0
                    ? '<span class="ms-1 text-danger" title="Thiếu cấu hình quy đổi ĐVT"><i class="bi bi-exclamation-triangle-fill"></i></span>'
                    : '';
                return '<tr class="kho-cap-list-row' + selected + stateClass + '" data-id="' + Number(x.id_vao_vien) + '">' +
                    '<td class="text-center">' + ((dispensePage - 1) * dispensePageSize + index + 1) + '</td>' +
                    '<td>' + escapeHtml(x.ma_bn || '') + '</td>' +
                    '<td class="fw-semibold">' + escapeHtml(String(x.ho_ten || '').toLocaleUpperCase('vi-VN')) + warning + '</td>' +
                    '<td class="text-center">' + escapeHtml(year) + '</td>' +
                    '<td>' + escapeHtml(x.ma_vao_vien || '') + '</td>' +
                    '</tr>';
            }).join('');

            body.querySelectorAll('tr[data-id]').forEach(tr => {
                tr.addEventListener('click', async () => {
                    selectedVisitId = Number(tr.dataset.id || 0);
                    body.querySelectorAll('tr[data-id]').forEach(x => x.classList.toggle('table-active', x === tr));
                    await loadDispenseDetail(selectedVisitId).catch(showError);
                });
            });

            if (!rows.some(x => Number(x.id_vao_vien) === selectedVisitId)) {
                selectedVisitId = Number(rows[0].id_vao_vien);
            }
            body.querySelectorAll('tr[data-id]').forEach(x => {
                x.classList.toggle('table-active', Number(x.dataset.id) === selectedVisitId);
            });
            await loadDispenseDetail(selectedVisitId);
        }

        const pager = ensureDispensePager();
        if (pager) {
            pager.render(total, dispensePage);
            dispensePage = pager.getCurrentPage();
            dispensePageSize = pager.getPageSize();
        }
    }

    async function loadDispenseDetail(id) {
        if (!id) return clearDispenseDetail();
        if (dispenseDetailAbort) dispenseDetailAbort.abort();
        const controller = new AbortController();
        dispenseDetailAbort = controller;

        const idKho = currentWarehouseId;
        const response = await fetch('/kho/api/chi-tiet-cap?id_kho=' + encodeURIComponent(idKho) + '&id_vao_vien=' + encodeURIComponent(id), {
            credentials: 'same-origin',
            signal: controller.signal
        });
        const result = await response.json();
        if (controller !== dispenseDetailAbort) return;
        if (!response.ok || result.status !== 200) throw new Error(result.message || 'Không tải được toa.');

        currentDispenseInfo = result.data && result.data.thong_tin ? result.data.thong_tin : null;
        currentDispenseRows = result.data && result.data.toa_thuoc ? result.data.toa_thuoc : [];
        renderDispenseDetail();
    }

    let dispensePrintBusy = false;
    let dispensePrintUrl = null;
    function syncPrintControls() {
        const ready = canExport && !!currentDispenseInfo && !dispensePrintBusy;
        const button = document.getElementById('kho-in-phieu-cap');
        if (button) button.disabled = !ready || !currentDispenseRows.some(x => Number(x.da_cap_co_so || 0) > 0.0001);
        document.querySelectorAll('.kho-cap-print-group').forEach(groupButton => {
            groupButton.disabled = !ready || groupButton.dataset.printReady !== '1';
        });
    }

    async function printDispenseDocument(twoCopies, groupButton = null) {
        if (dispensePrintBusy || !canExport) return;
        const visit = selectedVisitId;
        const detailRequest = dispenseDetailAbort;
        if (!visit || !currentDispenseInfo || Number(currentDispenseInfo.id_vao_vien) !== visit) return;
        if (twoCopies && (!groupButton || groupButton.disabled)) return;
        const lineIds = twoCopies ? String(groupButton.dataset.lineIds || '').split(',').map(Number).filter(x => x > 0) : [];
        if (twoCopies && !lineIds.length) return;
        const frame = document.getElementById('kho-cap-print-frame');
        if (!frame) return;
        dispensePrintBusy = true;
        syncPrintControls();
        try {
            const endpoint = twoCopies ? '/kho/don-cap-hai-lien/pdf' : '/kho/phieu-cap/pdf';
            const query = new URLSearchParams({ id_vao_vien: String(visit) });
            lineIds.forEach(id => query.append('id_toa_thuoc_ct', String(id)));
            const response = await fetch(endpoint + '?' + query, { credentials: 'same-origin', cache: 'no-store' });
            if (!response.ok) {
                const error = await response.json().catch(() => null);
                throw new Error(error?.message || 'Không tạo được bản in (' + response.status + ').');
            }
            const blob = await response.blob();
            if (blob.type !== 'application/pdf' || !blob.size) throw new Error('File in không phải PDF hợp lệ.');
            if (visit !== selectedVisitId || detailRequest !== dispenseDetailAbort) return;
            if (dispensePrintUrl) URL.revokeObjectURL(dispensePrintUrl);
            const url = URL.createObjectURL(blob);
            dispensePrintUrl = url;
            await new Promise((resolve, reject) => {
                const timer = window.setTimeout(() => {
                    frame.onload = null;
                    reject(new Error('Chưa tải được PDF để in. Thử lại.'));
                }, 15000);
                frame.onload = () => {
                    window.clearTimeout(timer);
                    frame.onload = null;
                    try {
                        if (visit !== selectedVisitId || detailRequest !== dispenseDetailAbort) {
                            if (dispensePrintUrl === url) {
                                frame.src = 'about:blank'; URL.revokeObjectURL(url); dispensePrintUrl = null;
                            }
                            resolve(); return;
                        }
                        frame.contentWindow.focus();
                        frame.contentWindow.onafterprint = () => {
                            if (dispensePrintUrl === url) {
                                frame.src = 'about:blank';
                                URL.revokeObjectURL(url);
                                dispensePrintUrl = null;
                            }
                        };
                        frame.contentWindow.print();
                        resolve();
                    } catch (error) { reject(error); }
                };
                frame.src = url;
            });
        } catch (error) {
            window.logClientError?.('In cấp phát thuốc', error, { id_vao_vien: visit });
            toast('error', error.message);
        } finally {
            dispensePrintBusy = false;
            syncPrintControls();
        }
    }
    document.getElementById('kho-in-phieu-cap')?.addEventListener('click', () => printDispenseDocument(false));
    document.getElementById('kho-cap-detail-body')?.addEventListener('click', event => {
        const button = event.target.closest('.kho-cap-print-group');
        if (!button) return;
        event.stopPropagation();
        printDispenseDocument(true, button);
    });


    function clearDispenseDetail() {
        currentDispenseInfo = null;
        currentDispenseRows = [];
        syncPrintControls();
        document.getElementById('kho-cap-empty').classList.remove('d-none');
        document.getElementById('kho-cap-detail').classList.add('d-none');
    }

    function syncDispenseSelectAll() {
        const selectAll = document.getElementById('kho-cap-select-all');
        if (!selectAll) return;
        const boxes = Array.from(document.querySelectorAll('#kho-cap-detail-body .kho-cap-select:not(:disabled)'));
        const checkedCount = boxes.filter(x => x.checked).length;
        selectAll.disabled = boxes.length === 0;
        selectAll.checked = boxes.length > 0 && checkedCount === boxes.length;
        selectAll.indeterminate = checkedCount > 0 && checkedCount < boxes.length;
    }

    function renderDispenseDetail() {
        if (!currentDispenseInfo) return clearDispenseDetail();

        document.getElementById('kho-cap-empty')?.classList.add('d-none');
        document.getElementById('kho-cap-detail')?.classList.remove('d-none');

        const birthYear = currentDispenseInfo.ngay_sinh ? new Date(currentDispenseInfo.ngay_sinh).getFullYear() : '';
        document.getElementById('kho-cap-ho-ten').textContent =
            String(currentDispenseInfo.ho_ten || '').toLocaleUpperCase('vi-VN');
        document.getElementById('kho-cap-nam-sinh-gioi-tinh').textContent =
            [birthYear, currentDispenseInfo.gioi_tinh].filter(Boolean).join(' - ');
        document.getElementById('kho-cap-ma-bn').textContent = currentDispenseInfo.ma_bn || '';
        document.getElementById('kho-cap-ma-vv').textContent = currentDispenseInfo.ma_vao_vien || '';
        document.getElementById('kho-cap-dia-chi').textContent = currentDispenseInfo.dia_chi || '';

        const table = document.getElementById('kho-cap-medicine-table');
        const body = document.getElementById('kho-cap-detail-body');
        const title = document.getElementById('kho-cap-medicine-title');
        const returnOpen = document.getElementById('kho-hoan-open');
        const saveBtn = document.getElementById('kho-xuat-save');
        const note = document.getElementById('kho-xuat-ghi-chu');
        if (!body || !table || !title) return;

        const pendingRows = currentDispenseRows.filter(x => {
            const convertible = x.co_quy_doi === true || Number(x.co_quy_doi) === 1;
            return !convertible || Number(x.con_lai || 0) > 0.0001;
        });
        const doneRows = currentDispenseRows.filter(x => Number(x.da_cap_co_so || 0) > 0.0001);
        const hasPending = pendingRows.length > 0;
        const hasDone = doneRows.length > 0;
        const readOnly = !hasPending;
        const colspan = readOnly ? 11 : 12;
        const warehouse = currentWarehouseName();
        table.classList.toggle('kho-cap-readonly', readOnly);
        title.classList.toggle('kho-cap-his-section-title-pending', hasPending);
        title.classList.toggle('kho-cap-his-section-title-done', !hasPending && hasDone);
        title.textContent = hasPending && hasDone ? 'Danh sách thuốc — Chưa cấp / Đã cấp'
            : hasPending ? 'Danh sách chưa cấp' : hasDone ? 'Danh sách đã cấp' : 'Danh sách thuốc';

        function groupRows(rows, renderRow, columns) {
            if (!rows.length) return '';
            const groups = new Map();
            rows.forEach(row => {
                const key = String(row.ma_loai_toa_thuoc || 'c') + '|' + String(row.bac_si_ke || '');
                if (!groups.has(key)) groups.set(key, []);
                groups.get(key).push(row);
            });
            let index = 0;
            return Array.from(groups.values()).map(group => {
                const first = group[0];
                const title = dispensePrescriptionType(first.ma_loai_toa_thuoc);
                const doctor = first.bac_si_ke ? ' - Bác sĩ kê toa: ' + escapeHtml(first.bac_si_ke) : '';
                const printRows = currentDispenseRows.filter(x =>
                    String(x.ma_loai_toa_thuoc || 'c') === String(first.ma_loai_toa_thuoc || 'c') &&
                    String(x.bac_si_ke || '') === String(first.bac_si_ke || ''));
                const lineIds = Array.from(new Set(printRows.map(x => Number(x.id_toa_thuoc_ct)).filter(x => x > 0)));
                const issued = printRows.some(x => Number(x.da_cap_co_so || 0) > 0.0001);
                const printButton = canExport ? '<button type="button" class="btn btn-outline-primary btn-sm kho-cap-print-group ms-2"' +
                    ' data-line-ids="' + lineIds.join(',') + '" data-print-ready="' + (issued && lineIds.length ? '1' : '0') + '"' +
                    ' title="In đơn hai liên" aria-label="In đơn hai liên - ' + escapeHtml(title + ' - ' + (first.bac_si_ke || '')) + '" disabled>' +
                    '<i class="bi bi-printer" aria-hidden="true"></i></button>' : '';
                const header = '<tr class="kho-cap-prescription-row"><td colspan="' + columns + '"><strong>' +
                    escapeHtml(title) + '</strong>' + doctor + printButton + '</td></tr>';
                return header + group.map(row => renderRow(row, ++index, warehouse)).join('');
            }).join('');
        }

        const renderPending = (x, index, kho) => {
            const convertible = x.co_quy_doi === true || Number(x.co_quy_doi) === 1;
            const remaining = convertible ? Math.max(0, Number(x.con_lai || 0)) : 0;
            const stock = convertible ? Math.max(0, Number(x.ton_theo_dvt || 0)) : 0;
            const shortage = convertible && stock + 0.0001 < remaining;
            const invalid = !convertible;
            const disabled = !canDispense || invalid || remaining <= 0;
            const warning = invalid
                ? '<div class="small text-danger fw-semibold">Chưa cấu hình quy đổi ĐVT</div>'
                : shortage ? '<div class="small text-danger fw-semibold">Tồn không đủ cấp theo toa</div>' : '';
            return '<tr data-id="' + Number(x.id_toa_thuoc_ct) + '"' +
                (invalid || shortage ? ' class="kho-cap-stock-warning"' : '') + '>' +
                '<td class="text-center kho-cap-select-cell kho-cap-select-col"><input type="checkbox" class="form-check-input m-0 kho-cap-select" aria-label="Chọn cấp thuốc ' +
                    escapeHtml(x.ten_thuoc || '') + '"' + (!disabled ? ' checked' : ' disabled') + ' /></td>' +
                '<td class="text-center">' + index + '</td>' +
                '<td><strong>' + escapeHtml(x.ten_thuoc || '') + '</strong>' + warning + '</td>' +
                '<td>' + escapeHtml(x.ham_luong || '') + '</td>' +
                '<td class="text-center">' + escapeHtml(x.don_vi_tinh || '') + '</td>' +
                '<td class="text-end">' + (convertible ? numberText(remaining) : '-') + '</td>' +
                '<td class="text-end ' + (shortage ? 'text-danger fw-bold' : '') + '">' + (convertible ? numberText(stock) : '-') + '</td>' +
                '<td>' + escapeHtml(x.kho_xuat || kho || '') + '</td>' +
                '<td class="text-end">' + numberText(x.don_gia || 0) + '</td>' +
                '<td>' + escapeHtml(dispenseUseText(x)) + '</td>' +
                '<td>' + escapeHtml(x.hoat_chat || '') + '</td>' +
                '<td>' + escapeHtml(x.nhom_hang || '') + '</td></tr>';
        };

        const renderDone = (x, index, kho) => {
            const convertible = x.co_quy_doi === true || Number(x.co_quy_doi) === 1;
            const factor = Math.max(Number(x.he_so_quy_doi || 1), 0.000001);
            const dispensed = convertible ? Number(x.da_cap_co_so || 0) / factor : 0;
            const stock = convertible ? Number(x.ton_theo_dvt || 0) : 0;
            return '<tr>' +
                (readOnly ? '' : '<td class="kho-cap-select-cell kho-cap-select-col"></td>') +
                '<td class="text-center">' + index + '</td>' +
                '<td><strong>' + escapeHtml(x.ten_thuoc || '') + '</strong></td>' +
                '<td>' + escapeHtml(x.ham_luong || '') + '</td>' +
                '<td class="text-center">' + escapeHtml(x.don_vi_tinh || '') + '</td>' +
                '<td class="text-end">' + numberText(dispensed) + '</td>' +
                '<td class="text-end">' + (convertible ? numberText(stock) : '-') + '</td>' +
                '<td>' + escapeHtml(x.kho_xuat || kho || '') + '</td>' +
                '<td class="text-end">' + numberText(x.don_gia || 0) + '</td>' +
                '<td>' + escapeHtml(dispenseUseText(x)) + '</td>' +
                '<td>' + escapeHtml(x.hoat_chat || '') + '</td>' +
                '<td>' + escapeHtml(x.nhom_hang || '') + '</td></tr>';
        };

        body.innerHTML = (!hasPending && !hasDone)
            ? '<tr><td colspan="' + colspan + '" class="text-center text-muted py-3">Không có thuốc cần xử lý.</td></tr>'
            : (hasPending && hasDone ? '<tr class="kho-cap-mode-row kho-cap-mode-pending"><td colspan="12">Chưa cấp</td></tr>' : '') +
                groupRows(pendingRows, renderPending, 12) +
                (hasPending && hasDone ? '<tr class="kho-cap-mode-row kho-cap-mode-done"><td colspan="12">Đã cấp</td></tr>' : '') +
                groupRows(doneRows, renderDone, colspan);

        syncDispenseSelectAll();
        syncPrintControls();
        if (saveBtn) saveBtn.classList.toggle('d-none', !hasPending);
        if (note) note.classList.toggle('d-none', !hasPending);
        if (returnOpen) returnOpen.classList.toggle('d-none', !canReturn || !hasDone);
        document.querySelector('.kho-cap-detail-pane .kho-cap-action-bar')?.classList.toggle(
            'd-none', (!canDispense || !hasPending) && (!canReturn || !hasDone) && (!canExport || !hasDone));
    }

    function askCancelDispense() {
        if (!canReturn || dispenseBusy || !currentDispenseInfo) return;
        const modal = document.getElementById('kho-huy-cap-confirm-modal');
        if (!modal || !window.bootstrap?.Modal) return toast('error', 'Không mở được cửa sổ xác nhận hủy.');
        pendingCancellationVisitId = Number(currentDispenseInfo.id_vao_vien);
        document.getElementById('kho-huy-cap-confirm-patient').textContent =
            String(currentDispenseInfo.ho_ten || '').toLocaleUpperCase('vi-VN');
        bootstrap.Modal.getOrCreateInstance(modal).show();
    }

    async function cancelDispense() {
        const visitId = pendingCancellationVisitId;
        if (!canReturn || dispenseBusy || !visitId || visitId !== Number(currentDispenseInfo?.id_vao_vien)) {
            toast('warning', 'Bệnh nhân đã thay đổi. Hãy chọn lại trước khi hủy.');
            return;
        }
        const btn = document.getElementById('kho-huy-cap-confirm-accept');
        dispenseBusy = true;
        setBusy(btn, true, 'Đang hủy...');
        try {
            // STO hủy toàn bộ và cập nhật tồn kho trong cùng transaction.
            const res = await apiPost('/kho/api/hoan-thuoc', {
                id_vao_vien: visitId,
                hoan_toan_bo: true,
                danh_sach: []
            });
            if (res.status !== 200) throw new Error(res.message || 'Không hủy được cấp phát.');
            bootstrap.Modal.getOrCreateInstance(document.getElementById('kho-huy-cap-confirm-modal')).hide();
            pendingCancellationVisitId = 0;
            toast('success', 'Đã hủy cấp phát.');
            stockPage = 1;
            await loadDispenseList();
        } catch (error) {
            toast('error', error.message || 'Không hủy được cấp phát.');
        } finally {
            dispenseBusy = false;
            setBusy(btn, false, '');
        }
    }

    async function saveDispense() {
        if (!canDispense || dispenseBusy || !currentDispenseInfo) return;
        const idKho = currentWarehouseId;
        if (!idKho) return toast('warning', 'Cơ sở chưa có kho hoạt động.');

        const rows = [];
        const shortages = [];
        const invalidConfigs = [];

        document.querySelectorAll('#kho-cap-detail-body tr[data-id]').forEach(element => {
            const checkbox = element.querySelector('.kho-cap-select');
            if (!checkbox || !checkbox.checked || checkbox.disabled) return;

            const x = currentDispenseRows.find(item => Number(item.id_toa_thuoc_ct) === Number(element.dataset.id));
            if (!x) return;
            const convertible = x.co_quy_doi === true || Number(x.co_quy_doi) === 1;
            if (!convertible) {
                invalidConfigs.push(x.ten_thuoc || x.ma_thuoc || 'Thuốc');
                return;
            }

            const remaining = Math.max(0, Number(x.con_lai || 0));
            const stock = Math.max(0, Number(x.ton_theo_dvt || 0));
            if (remaining <= 0) return;

            if (stock + 0.0001 < remaining) {
                shortages.push((x.ten_thuoc || x.ma_thuoc || 'Thuốc') + ' (cần ' + numberText(remaining) + ', tồn ' + numberText(stock) + ')');
                return;
            }

            rows.push({
                id_toa_thuoc_ct: Number(x.id_toa_thuoc_ct),
                so_luong_cap: remaining
            });
        });

        if (invalidConfigs.length)
            return toast('warning', 'Chưa cấu hình quy đổi ĐVT: ' + invalidConfigs.join(', '));
        if (shortages.length)
            return toast('warning', 'Tồn kho không đủ để cấp đúng toa: ' + shortages.join('; '));
        if (!rows.length)
            return toast('info', 'Chọn ít nhất một thuốc chưa cấp.');

        const btn = document.getElementById('kho-xuat-save');
        dispenseBusy = true;
        setBusy(btn, true, 'Đang cấp...');
        try {
            const res = await apiPost('/kho/api/xuat-thuoc', {
                id_kho: idKho,
                id_vao_vien: Number(currentDispenseInfo.id_vao_vien),
                ghi_chu: document.getElementById('kho-xuat-ghi-chu')?.value.trim() || null,
                danh_sach: rows
            });
            if (res.status !== 200) throw new Error(res.message || 'Không cấp phát được thuốc.');
            toast('success', res.message || 'Cấp phát thuốc thành công.');
            const note = document.getElementById('kho-xuat-ghi-chu');
            if (note) note.value = '';
            stockPage = 1;
            await loadDispenseList();
        } catch (error) {
            toast('error', error.message || 'Không cấp phát được thuốc.');
        } finally {
            dispenseBusy = false;
            setBusy(btn, false, '');
        }
    }

    function showError(error) {
        if (error && error.name === 'AbortError') return;
        toast('error', error && error.message ? error.message : 'Có lỗi khi tải dữ liệu kho.');
    }

    document.querySelectorAll('[data-kho-tab]').forEach(btn => {
        btn.addEventListener('click', event => {
            event.preventDefault();
            activateTab(btn.dataset.khoTab);
        });
    });

    document.getElementById('kho-ton-refresh')?.addEventListener('click', () => loadStock().catch(showError));
    document.getElementById('kho-ton-status')?.addEventListener('change', () => {
        clearTimeout(stockSearchTimer);
        stockPage = 1;
        loadStock().catch(showError);
    });
    document.getElementById('kho-ton-search')?.addEventListener('input', () => {
        clearTimeout(stockSearchTimer);
        stockSearchTimer = setTimeout(() => {
            stockPage = 1;
            loadStock().catch(showError);
        }, 300);
    });
    document.getElementById('kho-ton-search')?.addEventListener('keydown', e => {
        if (e.key !== 'Enter') return;
        e.preventDefault();
        clearTimeout(stockSearchTimer);
        stockPage = 1;
        loadStock().catch(showError);
    });

    // Nhập kho dùng TomSelect ở dòng cuối bảng, tự thêm thuốc khi chọn.
    document.querySelectorAll('[data-kho-import-view]').forEach(button => {
        button.addEventListener('click', () => {
            const showHistory = button.dataset.khoImportView === 'lich-su';
            document.getElementById('kho-import-form-pane')?.classList.toggle('d-none', showHistory);
            document.getElementById('kho-import-history-pane')?.classList.toggle('d-none', !showHistory);
            document.querySelectorAll('[data-kho-import-view]').forEach(item => {
                const active = item === button;
                item.classList.toggle('active', active);
                item.setAttribute('aria-selected', String(active));
            });
            if (showHistory) loadImportHistory().catch(showError);
        });
    });
    const saveImportBtn = document.getElementById('kho-nhap-save');
    if (saveImportBtn) saveImportBtn.addEventListener('click', saveImport);

    ['kho-cap-tu-ngay', 'kho-cap-den-ngay'].forEach(id => {
        document.getElementById(id)?.addEventListener('change', () => {
            dispensePage = 1;
            loadDispenseList().catch(showError);
        });
    });

    document.getElementById('kho-cap-select-all')?.addEventListener('change', e => {
        document.querySelectorAll('#kho-cap-detail-body .kho-cap-select:not(:disabled)').forEach(x => {
            x.checked = e.target.checked;
        });
        syncDispenseSelectAll();
    });

    // Các dòng được sinh lại khi đổi bệnh nhân, vì vậy dùng event delegation.
    const pendingMedicineBody = document.getElementById('kho-cap-detail-body');
    pendingMedicineBody?.addEventListener('change', e => {
        if (e.target.matches('.kho-cap-select')) syncDispenseSelectAll();
    });
    pendingMedicineBody?.addEventListener('click', e => {
        const cell = e.target.closest('td.kho-cap-select-cell');
        if (!cell || e.target.closest('input')) return;
        const checkbox = cell.querySelector('.kho-cap-select');
        if (checkbox && !checkbox.disabled) checkbox.click();
    });
    document.querySelector('.kho-cap-pending-section th.kho-cap-select-cell')?.addEventListener('click', e => {
        if (e.target.closest('input')) return;
        const checkbox = e.currentTarget.querySelector('#kho-cap-select-all');
        if (checkbox && !checkbox.disabled) checkbox.click();
    });

    document.querySelectorAll('input[name="kho-cap-status"]').forEach(input => {
        input.addEventListener('change', () => {
            if (!input.checked) return;
            dispenseStatus = String(input.value || 'chua_cap');
            dispensePage = 1;
            loadDispenseList().catch(showError);
        });
    });

    document.getElementById('kho-cap-refresh')?.addEventListener('click', () => {
        dispensePage = 1;
        loadDispenseList().catch(showError);
    });

    document.getElementById('kho-cap-search')?.addEventListener('input', () => {
        clearTimeout(dispenseSearchTimer);
        dispenseSearchTimer = setTimeout(() => {
            dispensePage = 1;
            loadDispenseList().catch(showError);
        }, 300);
    });
    document.getElementById('kho-cap-search')?.addEventListener('keydown', e => {
        if (e.key !== 'Enter') return;
        e.preventDefault();
        clearTimeout(dispenseSearchTimer);
        dispensePage = 1;
        loadDispenseList().catch(showError);
    });

    document.getElementById('kho-cap-search-btn')?.addEventListener('click', () => {
        clearTimeout(dispenseSearchTimer);
        dispensePage = 1;
        loadDispenseList().catch(showError);
    });

    const saveDispenseBtn = document.getElementById('kho-xuat-save');
    if (saveDispenseBtn) saveDispenseBtn.addEventListener('click', saveDispense);

    document.getElementById('kho-hoan-open')?.addEventListener('click', askCancelDispense);
    document.getElementById('kho-huy-cap-confirm-accept')?.addEventListener('click', cancelDispense);
    document.getElementById('kho-huy-cap-confirm-modal')?.addEventListener('hidden.bs.modal', () => {
        if (!dispenseBusy) pendingCancellationVisitId = 0;
    });
    document.getElementById('kho-nhap-ncc-add')?.addEventListener('click', openSupplierDirectory);
    document.getElementById('kho-nhap-history-refresh')?.addEventListener('click', () => loadImportHistory().catch(showError));
    document.getElementById('kho-dc-refresh')?.addEventListener('click', () => loadAdjustmentLots().catch(showError));
    document.getElementById('kho-dc-history-refresh')?.addEventListener('click', () => loadAdjustmentHistory().catch(showError));
    document.getElementById('kho-dc-loai')?.addEventListener('change', renderAdjustmentLots);
    document.getElementById('kho-dc-save')?.addEventListener('click', saveAdjustment);

    document.addEventListener('DOMContentLoaded', async () => {
        try {
            if (!isManagementPage) initDispenseFilters();
            await loadWarehouses();
            if (isManagementPage) {
                initImportDatePicker();
                const supplierReturn = restoreSupplierDraft();
                await loadSuppliers(supplierReturn.supplier);
                await loadImportHistory();
                renderImportRows();
                const requested = new URLSearchParams(location.search).get('tab') || 'ton-kho';
                activateTab(supplierReturn.returning ? 'nhap-kho' : requested, false);
                await loadAdjustmentHistory();
            }
            if (!isManagementPage) await loadDispenseList();
        } catch (error) {
            showError(error);
        }
    });
})();
