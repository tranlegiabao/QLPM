(() => {
    const root = document.getElementById('kho-ncc-panel');
    if (!root) return;

    const canAdd = root.dataset.canImport === '1';
    const canEdit = root.dataset.canEditSupplier === '1';
    const canDelete = root.dataset.canReturn === '1';
    const openedFromImport = new URLSearchParams(location.search).get('tu_nhap_kho') === '1';
    function returnToImport(id = 0) {
        const query = new URLSearchParams({ tab: 'nhap-kho' });
        if (id > 0) query.set('nha_cung_cap_id', String(id));
        location.assign('/kho/quan-ly?' + query.toString());
    }
    const form = document.getElementById('kho-ncc-form');
    const list = document.getElementById('kho-ncc-body');
    const field = id => document.getElementById('kho-ncc-' + id);
    const escapeHtml = value => String(value ?? '').replace(/[&<>"']/g, ch =>
        ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]));
    const toast = (kind, msg) => window.showToast?.(kind, msg);
    let rows = [];
    let page = 1;
    const pageSize = 10;
    let selectedId = 0;
    let selectedIsActive = true;
    let fromImport = openedFromImport;
    let busy = false;
    let searchTimer = null;
    let listToken = 0;

    function active(row) {
        return row.active === true || Number(row.active) === 1;
    }

    function setEditable() {
        const writable = selectedId ? canEdit : canAdd;
        for (const id of ['ma', 'ten', 'mst', 'sdt', 'dia-chi', 'active']) {
            field(id).disabled = !writable;
        }
        field('active').disabled = !writable || (selectedId > 0 && !canDelete && selectedIsActive);
        field('save').disabled = !writable || busy;
    }

    function clearForm(importMode = openedFromImport) {
        selectedId = 0;
        selectedIsActive = true;
        fromImport = importMode;
        form.reset();
        field('id').value = '0';
        field('active').checked = true;
        field('ma').value = '';
        document.getElementById('kho-ncc-form-title').textContent = importMode
            ? 'Thêm nhà cung cấp cho phiếu nhập'
            : 'Thêm nhà cung cấp';
        setEditable();
        if (importMode) field('ten').focus();
    }

    function editRow(row) {
        selectedId = Number(row.id);
        selectedIsActive = active(row);
        fromImport = false;
        field('id').value = String(selectedId);
        field('ma').value = row.ma || '';
        field('ten').value = row.ten || '';
        field('mst').value = row.ma_so_thue || '';
        field('sdt').value = row.dien_thoai || '';
        field('dia-chi').value = row.dia_chi || '';
        field('active').checked = active(row);
        document.getElementById('kho-ncc-form-title').textContent = 'Cập nhật nhà cung cấp';
        setEditable();
        field('ten').focus();
    }

    function render() {
        const total = rows.length;
        const pages = Math.max(1, Math.ceil(total / pageSize));
        page = Math.max(1, Math.min(page, pages));
        const shown = rows.slice((page - 1) * pageSize, page * pageSize);
        list.innerHTML = shown.length ? shown.map((x, idx) => {
            const isActive = active(x);
            return '<tr data-id="' + Number(x.id) + '"' + (Number(x.id) === selectedId ? ' class="table-active"' : '') + '>' +
                '<td class="text-center">' + ((page - 1) * pageSize + idx + 1) + '</td>' +
                '<td class="text-nowrap">' + escapeHtml(x.ma) + '</td>' +
                '<td class="fw-semibold">' + escapeHtml(x.ten) + '</td>' +
                '<td>' + escapeHtml(x.ma_so_thue) + '</td>' +
                '<td class="text-nowrap">' + escapeHtml(x.dien_thoai) + '</td>' +
                '<td>' + escapeHtml(x.dia_chi) + '</td>' +
                '<td><span class="badge ' + (isActive ? 'text-bg-success' : 'text-bg-secondary') + '">' +
                    (isActive ? 'Hoạt động' : 'Ngừng') + '</span></td>' +
                '<td class="text-center text-nowrap">' +
                    (openedFromImport && isActive ? '<button type="button" class="btn btn-sm btn-outline-success kho-ncc-choose me-1" title="Chọn để nhập kho"><i class="bi bi-check2"></i></button> ' : '') +
                    (canEdit ? '<button type="button" class="btn btn-sm btn-outline-primary kho-ncc-edit" title="Sửa nhà cung cấp"><i class="bi bi-pencil"></i></button> ' : '') +
                    (canDelete && isActive ? '<button type="button" class="btn btn-sm btn-outline-danger kho-ncc-delete" title="Ngừng sử dụng (không xóa phiếu nhập)"><i class="bi bi-trash"></i></button>' : '') +
                    '</td></tr>';
        }).join('') : '<tr><td colspan="8" class="text-center text-muted py-4">Không có nhà cung cấp phù hợp.</td></tr>';

        field('count').textContent = total + ' nhà cung cấp';
        document.getElementById('kho-ncc-page-info').textContent = 'Trang ' + page + ' / ' + pages;
        field('prev').disabled = page <= 1;
        field('next').disabled = page >= pages;
        document.getElementById('kho-ncc-pager').classList.toggle('d-none', pages <= 1);
    }

    async function load() {
        const token = ++listToken;
        const status = document.querySelector('input[name="kho-ncc-status"]:checked')?.value || 'hoat_dong';
        const params = new URLSearchParams({
            q: field('search').value.trim(),
            trang_thai: status
        });
        list.innerHTML = '<tr><td colspan="8" class="text-center text-muted py-4">Đang tải...</td></tr>';
        try {
            const response = await fetch('/kho/api/nha-cung-cap/danh-sach?' + params, { credentials: 'same-origin' });
            const data = await response.json().catch(() => ({}));
            if (!response.ok || data.status !== 200) throw new Error(data.message || 'Không tải được danh mục nhà cung cấp.');
            if (token !== listToken) return;
            rows = Array.isArray(data.data) ? data.data : [];
            render();
        } catch (error) {
            if (token !== listToken) return;
            rows = [];
            list.innerHTML = '<tr><td colspan="8" class="text-center text-danger py-4">' + escapeHtml(error.message) + '</td></tr>';
            field('count').textContent = '';
            document.getElementById('kho-ncc-pager').classList.add('d-none');
        }
    }

    async function post(url, payload) {
        const response = await fetch(url, {
            method: 'POST',
            credentials: 'same-origin',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        const data = await response.json().catch(() => ({}));
        if (!response.ok || data.status !== 200) throw new Error(data.message || 'Không thực hiện được thao tác.');
        return data;
    }

    async function save(event) {
        event.preventDefault();
        if (busy) return;
        if (!(selectedId ? canEdit : canAdd)) {
            toast('warning', 'Không có quyền lưu nhà cung cấp.');
            return;
        }
        const name = field('ten').value.trim();
        const phone = field('sdt').value.trim();
        if (!name) { toast('warning', 'Phải nhập tên nhà cung cấp.'); field('ten').focus(); return; }
        if (phone && !/^[0-9]{1,10}$/.test(phone)) {
            toast('warning', 'Điện thoại chỉ được nhập tối đa 10 chữ số.'); field('sdt').focus(); return;
        }
        const oldId = selectedId;
        const shouldReturn = fromImport && oldId === 0;
        const payload = {
            id: oldId, ma: field('ma').value.trim() || null,
            ten: name, ma_so_thue: field('mst').value.trim() || null,
            dien_thoai: phone || null, dia_chi: field('dia-chi').value.trim() || null,
            active: field('active').checked
        };
        busy = true;
        setEditable();
        try {
            const result = await post('/kho/api/nha-cung-cap/luu', payload);
            const id = Number(result.data?.ID ?? result.data?.id ?? oldId);
            toast('success', result.message || 'Đã lưu nhà cung cấp.');
            fromImport = false;
            selectedId = id;
            if (shouldReturn && payload.active) {
                returnToImport(id);
                return;
            }
            await load();
            const updated = rows.find(x => Number(x.id) === id);
            if (updated) editRow(updated);
            else clearForm();
        } catch (error) { toast('error', error.message); }
        finally { busy = false; setEditable(); }
    }

    async function deactivate(id) {
        if (!canDelete || busy) return;
        const item = rows.find(x => Number(x.id) === id);
        if (!item) return;
        if (typeof window.hien_thi_xac_nhan !== 'function') {
            toast('error', 'Không mở được hộp xác nhận.');
            return;
        }
        const confirmed = await window.hien_thi_xac_nhan({
            tieu_de: 'Ngừng sử dụng nhà cung cấp?',
            noi_dung: 'Nhà cung cấp ' + item.ten + ' sẽ không xuất hiện khi lập phiếu nhập mới. Lịch sử phiếu nhập được giữ nguyên.',
            nhan_dong_y: 'Ngừng sử dụng',
            nhan_khong: 'Quay lại',
            lop_nut: 'btn-danger'
        });
        if (!confirmed) return;
        busy = true;
        setEditable();
        try {
            const result = await post('/kho/api/nha-cung-cap/xoa', { id });
            toast('success', result.message || 'Đã ngừng sử dụng.');
            if (selectedId === id) clearForm();
            await load();
        } catch (error) { toast('error', error.message); }
        finally { busy = false; setEditable(); }
    }

    list.addEventListener('click', event => {
        const button = event.target.closest('button');
        if (!button) return;
        const id = Number(button.closest('tr')?.dataset.id || 0);
        const row = rows.find(x => Number(x.id) === id);
        if (!row) return;
        if (button.classList.contains('kho-ncc-choose') && active(row)) {
            returnToImport(id);
            return;
        }
        if (button.classList.contains('kho-ncc-edit')) editRow(row);
        if (button.classList.contains('kho-ncc-delete')) deactivate(id);
    });
    form.addEventListener('submit', save);
    field('new').addEventListener('click', () => clearForm());
    field('clear').addEventListener('click', () => clearForm());
    field('refresh').addEventListener('click', () => load());
    field('search-btn').addEventListener('click', () => { page = 1; load(); });
    field('search').addEventListener('input', () => {
        clearTimeout(searchTimer);
        searchTimer = setTimeout(() => { page = 1; load(); }, 300);
    });
    document.querySelectorAll('input[name="kho-ncc-status"]').forEach(radio => {
        radio.addEventListener('change', () => { page = 1; load(); });
    });
    field('prev').addEventListener('click', () => { page -= 1; render(); });
    field('next').addEventListener('click', () => { page += 1; render(); });

    clearForm(openedFromImport);
    load();
})();
