(() => {
    const root = document.getElementById('kho-nhom-thuoc-root');
    if (!root) return;

    const body = document.getElementById('kho-thuoc-tbody');
    const search = document.getElementById('kho-thuoc-search');
    const count = document.getElementById('kho-thuoc-count');
    let groups = [];
    let currentPage = 1;
    let pageSize = 25;
    let pager = null;
    let searchTimer = null;
    let activeListRequest = null;
    let editMedicineId = 0;

    const escapeHtml = value => String(value ?? '').replace(/[&<>"']/g, ch => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]));
    const typeName = code => ({ c: 'Đơn thuốc cơ bản', n: 'Đơn thuốc gây nghiện', h: 'Đơn hướng tâm thần / tiền chất' }[code] || 'Chưa phân loại');

    function setRowEditMode(row, editable) {
        if (!row) return;
        const id = Number(row.dataset.id || 0);
        editMedicineId = editable ? id : 0;
        body.querySelectorAll('tr').forEach(tr => tr.classList.remove('selected', 'table-active'));
        body.querySelectorAll('.kho-type-checkbox').forEach(input => { input.disabled = true; });
        if (!editable) return;
        row.classList.add('selected', 'table-active');
        row.querySelectorAll('.kho-type-checkbox').forEach(input => {
            input.disabled = input.dataset.available !== '1';
        });
    }

    function ensurePager() {
        if (pager) return pager;
        pager = createQLPMPagination({
            container: '#kho-thuoc-pagination',
            itemName: 'thuốc',
            pageSize,
            currentPage,
            pageSizes: [10, 25, 50, 100],
            compact: true,
            tableScrollSelector: '#kho-thuoc-table-container',
            onPageChange: (page, size) => {
                currentPage = page;
                pageSize = size;
                load().catch(showError);
            }
        });
        return pager;
    }

    async function load() {
        activeListRequest?.abort();
        const request = new AbortController();
        activeListRequest = request;
        editMedicineId = 0;
        body.innerHTML = '<tr><td colspan="7" class="text-center text-muted py-4">Đang tải danh mục...</td></tr>';
        const query = new URLSearchParams();
        if (search.value.trim()) query.set('q', search.value.trim());
        query.set('trang', currentPage);
        query.set('kich_thuoc_trang', pageSize);
        const selectedFilters = [...document.querySelectorAll('.kho-filter-type:checked')].map(input => input.value);
        if (selectedFilters.length < document.querySelectorAll('.kho-filter-type').length) {
            if (selectedFilters.length) selectedFilters.forEach(type => query.append('loai_toa', type));
            else query.set('loai_toa', 'none');
        }
        let response;
        let result;
        try {
            response = await fetch(`/kho/api/danh-sach?${query}`, { credentials: 'same-origin', signal: request.signal });
            result = await response.json();
        } catch (error) {
            if (error.name === 'AbortError') return;
            throw error;
        }
        if (request !== activeListRequest) return;
        if (!response.ok || result.status !== 200) throw new Error(result.message || 'Không tải được danh mục thuốc.');
        groups = result.data.nhom_hang || [];
        currentPage = Number(result.data.trang) || 1;
        pageSize = Number(result.data.kich_thuoc_trang) || pageSize;
        const medicines = result.data.thuoc || [];
        const total = Number(result.data.tong_so) || 0;
        if (!medicines.length && currentPage > 1) {
            currentPage = 1;
            return load();
        }
        render(medicines, total);
        ensurePager().render(total, currentPage);
        currentPage = pager.getCurrentPage();
        pageSize = pager.getPageSize();
    }

    function render(medicines, total) {
        const unassigned = medicines.filter(x => !x.nhom_id).length;
        count.textContent = `${total} thuốc · trang này có ${unassigned} chưa phân nhóm`;
        if (!medicines.length) {
            body.innerHTML = '<tr><td colspan="7" class="text-center text-muted py-4">Không có thuốc phù hợp.</td></tr>';
            return;
        }
        body.innerHTML = medicines.map((item, index) => {
            const type = String(item.ma_loai_don_thuoc || '').toLowerCase();
            const checkboxes = ['c', 'n', 'h'].map(code => {
                const group = groups.find(x => String(x.ma_loai_don_thuoc || '').toLowerCase() === code);
                const title = typeName(code);
                return `<td class="text-center"><input class="form-check-input kho-type-checkbox" type="checkbox" data-type="${code}" data-group-id="${group?.id || ''}" data-available="${group ? '1' : '0'}" aria-label="${escapeHtml(title)}" ${type === code ? 'checked' : ''} disabled /></td>`;
            }).join('');
            return `<tr data-id="${item.id}" data-type="${type}"><td class="text-center text-muted">${(currentPage - 1) * pageSize + index + 1}</td><td class="text-nowrap">${escapeHtml(item.ma)}</td><td>${escapeHtml(item.ten)}</td>${checkboxes}<td class="text-center"><button type="button" class="btn btn-sm btn-light border py-0 px-2 kho-row-edit" title="Chỉnh sửa phân nhóm" aria-label="Chỉnh sửa phân nhóm"><i class="bi bi-pencil-square"></i></button></td></tr>`;
        }).join('');

        body.querySelectorAll('tr[data-id]').forEach(row => {
            row.addEventListener('click', event => {
                if (event.target.closest('button, input, .dropdown-menu')) return;
                setRowEditMode(row, false);
            });
            row.querySelector('.kho-row-edit')?.addEventListener('click', event => {
                event.stopPropagation();
                const active = editMedicineId === Number(row.dataset.id || 0);
                setRowEditMode(row, !active);
            });
        });
    }

    body.addEventListener('change', async event => {
        const checkbox = event.target.closest('.kho-type-checkbox');
        if (!checkbox) return;
        const row = checkbox.closest('tr');
        if (!row || Number(row.dataset.id || 0) !== editMedicineId) {
            event.preventDefault();
            return;
        }
        const selectedType = checkbox.dataset.type;
        if (!checkbox.checked && row.dataset.type !== selectedType) return;
        const groupId = checkbox.checked ? Number(checkbox.dataset.groupId) : null;
        const rowCheckboxes = [...row.querySelectorAll('.kho-type-checkbox')];
        rowCheckboxes.forEach(input => input.disabled = true);
        try {
            const response = await fetch('/kho/api/gan-nhom', {
                method: 'POST', credentials: 'same-origin', headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ id_thuoc: Number(row.dataset.id), id_nhom_hang: groupId })
            });
            const result = await response.json();
            if (!response.ok || result.status !== 200) throw new Error(result.message || 'Không cập nhật được nhóm thuốc.');
            editMedicineId = 0;
            await load();
        } catch (error) {
            window.showToast ? showToast('error', error.message) : alert(error.message);
            await load();
        } finally {
            rowCheckboxes.forEach(input => input.disabled = false);
        }
    });

    const filterAll = document.getElementById('kho-filter-all');
    const filterTypes = [...document.querySelectorAll('.kho-filter-type')];
    filterAll.addEventListener('change', () => {
        filterTypes.forEach(input => input.checked = filterAll.checked);
        currentPage = 1;
        load().catch(showError);
    });
    filterTypes.forEach(input => input.addEventListener('change', () => {
        filterAll.checked = filterTypes.every(filter => filter.checked);
        currentPage = 1;
        load().catch(showError);
    }));

    function searchNow() {
        clearTimeout(searchTimer);
        currentPage = 1;
        load().catch(showError);
    }

    search.addEventListener('input', () => {
        clearTimeout(searchTimer);
        searchTimer = setTimeout(() => {
            currentPage = 1;
            load().catch(showError);
        }, 300);
    });
    document.getElementById('kho-thuoc-filter').addEventListener('click', searchNow);
    search.addEventListener('keydown', event => {
        if (event.key === 'Enter') { event.preventDefault(); searchNow(); }
    });
    document.getElementById('kho-thuoc-refresh').addEventListener('click', () => load().catch(showError));
    function showError(error) { window.showToast ? showToast('error', error.message || 'Không tải được danh mục thuốc.') : alert(error.message || error); }

    let hasLoaded = false;
    function loadWhenActive() {
        if (hasLoaded) return;
        hasLoaded = true;
        load().catch(error => {
            hasLoaded = false;
            showError(error);
        });
    }

    document.addEventListener('kho:phan-nhom-activate', loadWhenActive);
    // Vẫn tải được khi người dùng mở trực tiếp ?tab=phan-nhom,
    // không phụ thuộc vào việc khởi tạo các chức năng Kho khác.
    function loadInitialTab() {
        const panel = root.closest('[data-kho-panel="phan-nhom"]');
        if (panel && !panel.classList.contains('d-none')) loadWhenActive();
    }
    if (document.readyState === 'loading')
        document.addEventListener('DOMContentLoaded', loadInitialTab, { once: true });
    else loadInitialTab();
})();
