(() => {
    const state = { page: 1, size: 10, total: 0, pager: null };
    const canSyncJson = document.getElementById('ht-overview-root')?.dataset.canSyncJson === 'true';

    function khoiTaoTomSelect(id, placeholder) {
        const select = document.getElementById(id);
        if (!select || typeof TomSelect === 'undefined') return null;
        if (select.tomselect) return select.tomselect;
        return new TomSelect(select, {
            create: false,
            maxItems: 1,
            allowEmptyOption: true,
            placeholder,
            score: window.tomSelectVietTatScore
        });
    }

    function layGiaTriSelect(id) {
        const select = document.getElementById(id);
        if (!select) return '';
        return select.tomselect
            ? String(select.tomselect.getValue() || '')
            : String(select.value || '');
    }

    function napSelect(id, rows, placeholder, selected = '', disabled = false) {
        const select = document.getElementById(id);
        if (!select) return;
        if (select.tomselect) select.tomselect.destroy();

        select.innerHTML = '';
        const empty = document.createElement('option');
        empty.value = '';
        empty.textContent = placeholder;
        select.appendChild(empty);

        (rows || []).forEach(x => {
            const opt = document.createElement('option');
            opt.value = String(x.value ?? '');
            opt.textContent = String(x.text ?? '');
            select.appendChild(opt);
        });

        select.disabled = disabled;
        const ts = khoiTaoTomSelect(id, placeholder);
        if (ts) {
            ts.setValue(selected ? String(selected) : '', true);
            if (disabled) ts.disable(); else ts.enable();
        } else {
            select.value = selected ? String(selected) : '';
        }
    }

    document.addEventListener('DOMContentLoaded', async () => {
        ganSuKien();
        await taiTinhThanh();
        await taiDanhSach();
    });

    function ganSuKien() {
        document.getElementById('btn-ht-ov-loc')?.addEventListener('click', () => {
            state.page = 1;
            taiDanhSach();
        });

        document.getElementById('btn-ht-ov-xoa-loc')?.addEventListener('click', async () => {
            const ma = document.getElementById('ht-ov-ma');
            const ten = document.getElementById('ht-ov-ten');
            if (ma) ma.value = '';
            if (ten) ten.value = '';
            const tinh = document.getElementById('ht-ov-tinh');
            if (tinh?.tomselect) tinh.tomselect.setValue('', true);
            else if (tinh) tinh.value = '';
            napSelect('ht-ov-phuong', [], 'Tất cả phường / xã', '', true);
            state.page = 1;
            await taiDanhSach();
        });

        ['ht-ov-ma', 'ht-ov-ten'].forEach(id => {
            document.getElementById(id)?.addEventListener('keydown', e => {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    state.page = 1;
                    taiDanhSach();
                }
            });
        });

        document.getElementById('ht-ov-tinh')?.addEventListener('change', async () => {
            await taiPhuongXa(layGiaTriSelect('ht-ov-tinh'));
            state.page = 1;
            taiDanhSach();
        });

        document.getElementById('ht-ov-phuong')?.addEventListener('change', () => {
            state.page = 1;
            taiDanhSach();
        });
    }

    async function goiJson(url) {
        const res = await fetch(url, { credentials: 'same-origin' });
        if (res.status === 401) {
            location.href = '/xac_thuc/dang_nhap?return_url=' + encodeURIComponent(location.pathname + location.search);
            throw new Error('Chưa đăng nhập');
        }
        if (res.status === 403) throw new Error('Bạn không có quyền truy cập.');
        return await res.json();
    }

    async function taiTinhThanh() {
        try {
            const res = await goiJson('/api/he_thong/dia_chi/tinh_thanh');
            napSelect(
                'ht-ov-tinh',
                (res.data || []).map(x => ({ value: x.ma || '', text: x.ten || x.ma || '' })),
                'Tất cả tỉnh / thành',
                layGiaTriSelect('ht-ov-tinh'),
                false
            );
        } catch (e) {
            window.showToast?.('error', e.message || 'Không tải được tỉnh / thành.');
        }
    }

    async function taiPhuongXa(maTinh) {
        if (!maTinh) {
            napSelect('ht-ov-phuong', [], 'Tất cả phường / xã', '', true);
            return;
        }

        try {
            const res = await goiJson('/api/he_thong/dia_chi/phuong_xa?ma_tinh=' + encodeURIComponent(maTinh));
            napSelect(
                'ht-ov-phuong',
                (res.data || []).map(x => ({ value: x.ma || '', text: x.ten || x.ma || '' })),
                'Tất cả phường / xã',
                '',
                false
            );
        } catch (e) {
            window.showToast?.('error', e.message || 'Không tải được phường / xã.');
        }
    }

    async function taiDanhSach() {
        const grid = document.getElementById('ht-overview-grid');
        if (!grid) return;
        document.getElementById('ht-overview-pagination')?.classList.add('d-none');

        const params = new URLSearchParams({
            trang: String(state.page),
            kich_thuoc_trang: '10'
        });

        const ma = document.getElementById('ht-ov-ma')?.value?.trim() || '';
        const ten = document.getElementById('ht-ov-ten')?.value?.trim() || '';
        const maTinh = layGiaTriSelect('ht-ov-tinh');
        const maPhuongXa = layGiaTriSelect('ht-ov-phuong');
        if (ma) params.set('ma_cskcb', ma);
        if (ten) params.set('ten_cskcb', ten);
        if (maTinh) params.set('ma_tinh', maTinh);
        if (maPhuongXa) params.set('ma_phuong_xa', maPhuongXa);

        try {
            grid.innerHTML = '<div class="text-center text-muted py-5 w-100"><span class="spinner-border spinner-border-sm me-2"></span>Đang tải...</div>';
            const res = await goiJson('/api/he_thong/cskcb?' + params.toString());
            const rows = res.data || [];
            state.total = rows.length
                ? Number(rows[0].TongSoDong ?? rows[0].tong_so_dong ?? rows.length)
                : 0;

            if (!rows.length && state.page > 1) {
                state.page = 1;
                return taiDanhSach();
            }

            renderCards(rows);
            renderPager();
        } catch (e) {
            grid.innerHTML = '<div class="text-center text-danger py-5 w-100">Không tải được danh sách cơ sở KCB.</div>';
            window.showToast?.('error', e.message || 'Không tải được danh sách cơ sở KCB.');
        }
    }

    function renderCards(rows) {
        const grid = document.getElementById('ht-overview-grid');
        if (!grid) return;

        if (!rows.length) {
            grid.innerHTML = '<div class="text-center text-muted py-5 w-100"><i class="bi bi-buildings fs-2 d-block mb-2"></i>Không có cơ sở KCB phù hợp bộ lọc.</div>';
            return;
        }

        grid.innerHTML = '';
        rows.forEach(x => {
            const id = Number(x.IDCSKCB || 0);
            const active = x.Active === true || x.Active === 1;
            const card = document.createElement('article');
            card.className = 'ht-cskcb-card ht-cskcb-card-large';
            card.tabIndex = 0;
            card.innerHTML = `
                <div class="ht-cskcb-card-top">
                    <span class="badge ${active ? 'bg-success-subtle text-success border border-success-subtle' : 'bg-secondary-subtle text-secondary border'}">
                        <i class="bi ${active ? 'bi-circle-fill' : 'bi-pause-circle'} me-1"></i>${active ? 'Hoạt động' : 'Ngừng hoạt động'}
                    </span>
                    ${canSyncJson ? '<button type="button" class="btn btn-sm btn-outline-primary ht-overview-card-sync" title="Đồng bộ JSON cho cơ sở này" aria-label="Đồng bộ JSON cho ' + escapeHtml(x.TenCSKCB || '') + '"><i class="bi bi-arrow-repeat me-1"></i>Đồng bộ JSON</button>' : ''}
                </div>
                <div class="ht-cskcb-logo-wrap">
                    ${x.UrlLogo
                        ? '<img src="' + escapeHtml(x.UrlLogo) + '" class="ht-cskcb-logo" alt="Hình ảnh ' + escapeHtml(x.TenCSKCB || '') + '" />'
                        : '<div class="ht-cskcb-logo-placeholder"><i class="bi bi-hospital"></i></div>'}
                </div>
                <div class="ht-cskcb-card-name">${escapeHtml(x.TenCSKCB || '')}</div>
                <div class="ht-cskcb-card-code">${escapeHtml(x.MaCSKCB || '')}</div>
                <div class="ht-cskcb-card-meta">
                    <div title="${escapeHtml(x.DiaChi || '')}"><i class="bi bi-geo-alt me-1"></i>${escapeHtml(x.DiaChi || 'Chưa có địa chỉ')}</div>
                    ${x.SDT ? '<div><i class="bi bi-telephone me-1"></i>' + escapeHtml(x.SDT) + '</div>' : ''}
                </div>
                <div class="ht-cskcb-card-actions">
                    <a class="btn btn-sm btn-primary flex-grow-1" href="/he_thong/cskcb/${id}">
                        <i class="bi bi-box-arrow-in-right me-1"></i>Chọn cơ sở
                    </a>
                </div>`;

            card.querySelector('.ht-overview-card-sync')?.addEventListener('click', async event => {
                event.stopPropagation();
                await dongBoJsonCskcb(id, event.currentTarget);
            });
            const open = () => { location.href = '/he_thong/cskcb/' + id; };
            card.addEventListener('click', e => {
                if (e.target.closest('a,button')) return;
                open();
            });
            card.addEventListener('keydown', e => {
                // Không điều hướng khi dùng Enter/Space trên nút Đồng bộ JSON.
                if (e.target.closest('a,button,input,select,textarea')) return;
                if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault();
                    open();
                }
            });
            grid.appendChild(card);
        });
    }

    // Đồng bộ JSON đúng CSKCB của thẻ, không phụ thuộc cookie CSKCB hiện đang chọn.
    async function dongBoJsonCskcb(id, button) {
        if (!canSyncJson || !Number.isSafeInteger(id) || id <= 0 || button.disabled) return;
        const oldHtml = button.innerHTML;
        button.disabled = true;
        button.innerHTML = '<span class="spinner-border spinner-border-sm me-1" role="status" aria-label="Đang đồng bộ"></span>Đang đồng bộ';
        try {
            const response = await fetch('/api/he_thong/danh_muc/dong_bo?id_cskcb=' + encodeURIComponent(id), {
                method: 'POST',
                credentials: 'same-origin',
                headers: { 'Content-Type': 'application/json' },
                body: '{}'
            });
            if (response.status === 401) {
                location.href = '/xac_thuc/dang_nhap?return_url=' + encodeURIComponent(location.pathname + location.search);
                return;
            }
            if (response.status === 403) throw new Error('Bạn không có quyền đồng bộ danh mục JSON.');
            const result = await response.json();
            if (!response.ok || result.status !== 200)
                throw new Error(result.message || 'Đồng bộ JSON không thành công.');
            window.showToast?.('success', result.message || 'Đã đồng bộ danh mục JSON.');
        } catch (error) {
            window.showToast?.('error', error.message || 'Không thực hiện được đồng bộ JSON.');
        } finally {
            button.disabled = false;
            button.innerHTML = oldHtml;
        }
    }

    function renderPager() {
        const container = document.getElementById('ht-overview-pagination');
        if (state.total <= 10) {
            state.page = 1;
            if (container) {
                container.classList.add('d-none');
                container.innerHTML = '';
            }
            return;
        }

        container?.classList.remove('d-none');
        if (!state.pager) {
            state.pager = createQLPMPagination({
                container: '#ht-overview-pagination',
                itemName: 'cơ sở KCB',
                pageSize: 10,
                currentPage: 1,
                pageSizes: [10],
                compact: true,
                onPageChange: page => {
                    state.page = page;
                    taiDanhSach();
                }
            });
        }
        state.pager.render(state.total, state.page);
        state.page = state.pager.getCurrentPage();
    }

    function escapeHtml(value) {
        return String(value ?? '')
            .replaceAll('&', '&amp;')
            .replaceAll('<', '&lt;')
            .replaceAll('>', '&gt;')
            .replaceAll('"', '&quot;')
            .replaceAll("'", '&#039;');
    }
})();
