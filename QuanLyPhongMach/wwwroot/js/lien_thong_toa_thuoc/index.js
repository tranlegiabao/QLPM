(() => {
    const root = document.getElementById('ltt-root');
    if (!root) return;
    const canSend = root.dataset.canSend === '1';
    const field = id => document.getElementById('ltt-' + id);
    const body = field('body');
    const selected = new Set();
    let rows = [], page = 1, pageSize = 25, pager = null, busy = false, activeLoad = null;
    const visitId = Number(new URLSearchParams(location.search).get('id_vao_vien') || 0);
    const escapeHtml = value => String(value ?? '').replace(/[&<>"']/g, ch => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;' }[ch]));
    const states = { CHO_GUI:'Chờ gửi', DANG_GUI:'Đang gửi', THANH_CONG:'Đã liên thông', TU_CHOI:'Bị từ chối', LOI_GUI:'Lỗi gửi', KHONG_RO_KET_QUA:'Chưa rõ kết quả' };
    const dateVN = value => {
        const d = new Date(value);
        return Number.isNaN(d.getTime()) ? '' : `${String(d.getDate()).padStart(2,'0')}-${String(d.getMonth()+1).padStart(2,'0')}-${d.getFullYear()}`;
    };
    function isoDate(value) {
        const match = /^(\d{2})-(\d{2})-(\d{4})$/.exec(value || '');
        if (!match) throw new Error('Nhập ngày theo định dạng dd-MM-yyyy.');
        const d = new Date(Number(match[3]), Number(match[2])-1, Number(match[1]));
        if (dateVN(d) !== value) throw new Error('Ngày lọc không hợp lệ.');
        return `${match[3]}-${match[2]}-${match[1]}`;
    }
    async function request(url, options = {}) {
        const response = await fetch(url, { credentials:'same-origin', ...options });
        const result = await response.json().catch(() => ({}));
        if (!response.ok || result.status !== 200) throw new Error(result.message || `HTTP ${response.status}`);
        return result;
    }
    const eligible = row => canSend && !row.da_lien_thong && !['CHO_GUI','DANG_GUI','THANH_CONG','KHONG_RO_KET_QUA'].includes(row.trang_thai);
    function syncSelection() {
        const available = rows.filter(eligible);
        const all = field('check-all');
        all.disabled = busy || !available.length;
        all.checked = available.length > 0 && available.every(x => selected.has(Number(x.id)));
        all.indeterminate = selected.size > 0 && !all.checked;
        field('selected').textContent = selected.size ? `Đã chọn ${selected.size} toa` : '';
        if (field('gui')) field('gui').disabled = busy || !selected.size;
    }
    async function load() {
        if (busy) return;
        activeLoad?.abort();
        const abort = new AbortController(); activeLoad = abort;
        selected.clear(); rows = []; syncSelection();
        body.innerHTML = '<tr><td colspan="10" class="text-center text-muted py-4">Đang tải...</td></tr>';
        try {
            const from = isoDate(field('tu-ngay').value), to = isoDate(field('den-ngay').value);
            if (from > to) throw new Error('Từ ngày phải trước hoặc bằng Đến ngày.');
            const query = new URLSearchParams({ tu_ngay:from, den_ngay:to,
                trang_thai:root.querySelector('input[name="ltt-trang-thai"]:checked').value,
                ma_toa:field('ma-toa').value.trim(), ma_vao_vien:field('ma-vv').value.trim(),
                trang:String(page), kich_thuoc_trang:String(pageSize) });
            const doctor = field('bac-si').value;
            if (doctor) query.set('id_bac_si', doctor);
            if (visitId > 0) query.set('id_vao_vien', String(visitId));
            const result = await request('/api/lien_thong_toa_thuoc/danh-sach?' + query, { signal:abort.signal });
            if (abort !== activeLoad) return;
            rows = result.data || [];
            body.innerHTML = rows.length ? rows.map(x => {
                const state = x.da_lien_thong ? 'Đã liên thông' : states[x.trang_thai] || 'Chưa liên thông';
                const cls = x.da_lien_thong ? 'text-success' : ['TU_CHOI','LOI_GUI','KHONG_RO_KET_QUA'].includes(x.trang_thai) ? 'text-danger' : '';
                return `<tr data-id="${Number(x.id)}" class="${cls} ltt-row" tabindex="0" aria-label="Xem thông tin toa ${escapeHtml(x.ma_toa_quoc_gia)}">
                    <td class="text-center"><input type="checkbox" class="form-check-input ltt-select" value="${Number(x.id)}" aria-label="Chọn toa ${escapeHtml(x.ma_toa_quoc_gia)}" ${eligible(x) ? '' : 'disabled'} /></td>
                    <td>${escapeHtml(x.bac_si)}</td><td>${escapeHtml(dateVN(x.ngay_ke))}</td><td>${escapeHtml(x.ma_toa_quoc_gia || 'Chưa cấp mã')}</td>
                    <td>${escapeHtml(({c:'Cơ bản',n:'Gây nghiện',h:'Hướng thần / tiền chất'})[x.ma_loai_toa_thuoc] || x.ma_loai_toa_thuoc)}</td>
                    <td>${escapeHtml(x.ma_benh_nhan)}</td><td class="fw-semibold">${escapeHtml(x.ho_ten)}</td><td>${escapeHtml(x.ma_vao_vien)}</td><td>${escapeHtml(state)}</td>
                    <td class="text-center">${x.co_phan_hoi ? '<button type="button" class="btn btn-outline-secondary btn-sm ltt-response" title="Xem phản hồi"><i class="bi bi-eye"></i></button>' : ''}</td></tr>`;
            }).join('') : '<tr><td colspan="10" class="text-center text-muted py-4">Không có toa thuốc phù hợp.</td></tr>';
            field('total').textContent = `${Number(result.tong_so || 0)} toa`;
            if (!pager && window.createQLPMPagination) pager = createQLPMPagination({ container:'#ltt-pagination', itemName:'toa',
                pageSize, currentPage:page, pageSizes:[10,25,50,100], compact:true, tableScrollSelector:'#ltt-table-scroll',
                onPageChange:(next, size) => { page=next; pageSize=size; load(); } });
            pager?.render(Number(result.tong_so || 0), page);
            syncSelection();
        } catch (error) {
            if (error.name === 'AbortError' || abort !== activeLoad) return;
            body.innerHTML = `<tr><td colspan="10" class="text-center text-danger py-4">${escapeHtml(error.message)}</td></tr>`;
            field('total').textContent = ''; syncSelection();
        }
    }
    async function showDetail(id, response) {
        try {
            const result = await request(`/api/lien_thong_toa_thuoc/${id}/${response ? 'phan-hoi' : 'xem-payload'}`);
            field('detail-title').textContent = response ? 'Thông báo liên thông' : 'Thông tin gửi đơn thuốc';
            field('detail').textContent = JSON.stringify(result.data, null, 2);
            bootstrap.Modal.getOrCreateInstance(field('detail-modal')).show();
        } catch (error) { window.showToast?.('error', error.message); }
    }
    body.addEventListener('change', event => {
        if (!event.target.matches('.ltt-select') || busy) return;
        const id = Number(event.target.value);
        if (event.target.checked) selected.add(id); else selected.delete(id);
        syncSelection();
    });
    body.addEventListener('click', event => {
        if (event.target.closest('input') || busy) return;
        const row = event.target.closest('tr[data-id]'); if (!row) return;
        showDetail(Number(row.dataset.id), !!event.target.closest('.ltt-response'));
    });
    body.addEventListener('keydown', event => {
        if (event.key !== 'Enter' || event.target.closest('button,input') || busy) return;
        const row = event.target.closest('tr[data-id]'); if (row) showDetail(Number(row.dataset.id), false);
    });
    field('check-all').addEventListener('change', event => {
        selected.clear();
        if (event.target.checked) rows.filter(eligible).forEach(x => selected.add(Number(x.id)));
        body.querySelectorAll('.ltt-select').forEach(x => { x.checked = selected.has(Number(x.value)); });
        syncSelection();
    });
    field('gui')?.addEventListener('click', async () => {
        if (busy || !selected.size) return;
        const batch = rows.filter(x => selected.has(Number(x.id)) && eligible(x));
        if (!batch.length) return;
        busy = true; syncSelection();
        root.querySelectorAll('input,select,button').forEach(x => { x.disabled = true; });
        field('bac-si').tomselect?.disable();
        field('progress-close').disabled = true; field('progress-results').replaceChildren();
        bootstrap.Modal.getOrCreateInstance(field('progress-modal')).show();
        try {
            for (let i=0; i<batch.length; i++) {
                const row=batch[i];
                field('progress-status').textContent = `Đang gửi ${i+1}/${batch.length}: ${row.ma_toa_quoc_gia || row.id}`;
                let state='LOI_GUI', message='';
                try {
                    const result = await request(`/api/lien_thong_toa_thuoc/${row.id}/lien-thong`, { method:'POST' });
                    state=result.data.trang_thai; message=result.message || states[state] || state;
                } catch (error) { message=error.message; }
                const item=document.createElement('div');
                item.className='border rounded p-2 mb-2 ' + (state === 'THANH_CONG' ? 'text-success' : 'text-danger');
                item.textContent=`${row.ma_toa_quoc_gia || row.id} — ${message}`;
                field('progress-results').appendChild(item);
            }
            field('progress-status').textContent=`Hoàn tất ${batch.length} toa.`;
        } finally {
            busy=false; field('progress-close').disabled=false;
            root.querySelectorAll('input,select,button').forEach(x => { x.disabled=false; });
            field('bac-si').tomselect?.enable();
            await load();
        }
    });
    field('tim').addEventListener('click', () => { page=1; load(); });
    for (const id of ['ma-toa','ma-vv']) field(id).addEventListener('keydown', e => { if(e.key==='Enter') { page=1; load(); } });
    document.addEventListener('DOMContentLoaded', async () => {
        const today=new Date(), from=new Date(today); from.setDate(from.getDate()-7);
        window.initDatePicker?.('#ltt-tu-ngay'); window.initDatePicker?.('#ltt-den-ngay');
        field('tu-ngay').value=dateVN(from); field('den-ngay').value=dateVN(today);
        try {
            const result=await request('/api/lien_thong_toa_thuoc/bac-si');
            window.initTomSelect?.('#ltt-bac-si', { options:result.data || [], allowEmptyOption:true, placeholder:'Tất cả bác sĩ' });
        } catch(error) { window.showToast?.('error', error.message); }
        await load();
    });
})();
