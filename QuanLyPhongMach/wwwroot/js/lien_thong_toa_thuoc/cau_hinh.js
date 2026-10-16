(function () {
    const root = document.getElementById('ltt-config-root'); if (!root) return;
    let doctors = [];
    const pdfTemplates = document.getElementById('ltt-pdf-template-body');
    const escapeTemplate = value => String(value ?? '').replace(/[&<>'"]/g,
        c => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));

    async function loadPdfTemplates() {
        if (!pdfTemplates) return;
        const result = await request('/api/he_thong/lien_thong_toa_thuoc/mau-ky');
        const rows = result.data || [];
        pdfTemplates.innerHTML = rows.length ? rows.map(row => `<tr data-loai="${escapeTemplate(row.ma_loai)}">
            <td class="text-nowrap fw-semibold">${row.ma_loai === 'toa_thuoc' ? 'Toa thuốc' : 'Chỉ định CLS'}</td>
            ${['trang_ky', 'x1', 'y1', 'x2', 'y2'].map(key =>
                '<td><input type="number" class="form-control form-control-sm ltt-pdf-' + key + '" min="' +
                (key === 'trang_ky' ? '1' : '0') + '" max="' + (key === 'trang_ky' ? '100' : key[0] === 'x' ? '420' : '596') +
                '" step="' + (key === 'trang_ky' ? '1' : '0.01') + '" value="' + Number(row[key] ?? 0) + '" /></td>').join('')}
            <td><button type="button" class="btn btn-sm btn-outline-primary ltt-pdf-save">Lưu</button></td></tr>`).join('')
            : '<tr><td colspan="7" class="text-danger text-center">Chưa có mẫu ký; cần cập nhật SQL v107.</td></tr>';
    }

    pdfTemplates?.addEventListener('click', async event => {
        const button = event.target.closest('button.ltt-pdf-save');
        if (!button) return;
        const tr = button.closest('tr');
        const payload = { ma_loai: tr.dataset.loai };
        for (const key of ['trang_ky','x1','y1','x2','y2']) {
            const input = tr.querySelector('.ltt-pdf-' + key);
            if (!input || input.value.trim() === '' || !Number.isFinite(Number(input.value))) {
                showToast('warning', 'Tọa độ và trang ký phải là số hợp lệ.');
                return;
            }
            payload[key] = Number(input.value);
        }
        if (payload.trang_ky < 1 || !Number.isInteger(payload.trang_ky) ||
            payload.x1 < 0 || payload.y1 < 0 || payload.x2 <= payload.x1 ||
            payload.y2 <= payload.y1 || payload.x2 > 420 || payload.y2 > 596)
            return showToast('warning', 'Tọa độ khung ký phải nằm trong trang A5.');
        button.disabled = true;
        try {
            await request('/api/he_thong/lien_thong_toa_thuoc/mau-ky',
                { method: 'POST', body: JSON.stringify(payload) });
            showToast('success', 'Đã lưu mẫu ký PDF tại CSKCB.');
            await loadPdfTemplates();
        } catch (error) { showToast('error', error.message); }
        finally { button.disabled = false; }
    });
    async function request(url, options) {
        const response = await fetch(url, { headers: { 'Content-Type': 'application/json' }, ...options });
        const data = await response.json().catch(() => ({}));
        if (!response.ok) throw new Error(data.message || `HTTP ${response.status}`);
        return data;
    }
    const escapeHtml = value => String(value ?? '').replace(/[&<>'"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));
    function renderDoctors() {
        document.getElementById('cfg-doctor-body').innerHTML = doctors.map(x => `<tr data-id="${x.id_nhan_vien}">
          <td><div class="fw-semibold">${escapeHtml(x.ho_ten)}</div><small>${escapeHtml(x.ma_nhan_vien)}</small></td>
          <td><input class="form-control form-control-sm doctor-code" value="${escapeHtml(x.ma_lien_thong || '')}" /></td>
          <td><input class="form-control form-control-sm doctor-license" value="${escapeHtml(x.so_chung_chi_hanh_nghe || '')}" /></td>
          <td><input type="password" autocomplete="new-password" class="form-control form-control-sm doctor-password" placeholder="${x.da_cau_hinh_mat_khau ? 'Đã cấu hình — để trống để giữ' : 'Chưa cấu hình'}" /></td>
          <td class="text-center"><input type="checkbox" class="form-check-input doctor-active" ${x.active ? 'checked' : ''} /></td>
          <td><button class="btn btn-sm btn-outline-primary doctor-save">Lưu</button></td></tr>`).join('');
    }
    async function load() {
        const result = await request('/api/he_thong/lien_thong_toa_thuoc/cau-hinh'); const x = result.data;
        document.getElementById('cfg-moi-truong').value = x.moi_truong;
        document.getElementById('cfg-api-prod').value = x.api_base_url_production || '';
        document.getElementById('cfg-api-test').value = x.api_base_url_test || '';
        document.getElementById('cfg-url-ky-data').value = x.url_ky_du_lieu || '';
        document.getElementById('cfg-url-ky-pdf').value = x.url_ky_pdf || '';
        document.getElementById('cfg-ma-cskcb').value = x.ma_lien_thong_cskcb || '';
        document.getElementById('cfg-ky-active').checked = x.ky_so_hieu_luc === true;
        document.getElementById('cfg-lien-thong-active').checked = x.lien_thong_hieu_luc === true;
        document.getElementById('cfg-password-state').textContent = x.da_cau_hinh_mat_khau_cskcb ? 'Đã cấu hình; để trống để giữ mật khẩu hiện tại.' : 'Chưa cấu hình.';
        doctors = x.bac_si || []; renderDoctors();
    }
    document.getElementById('ltt-config-form').addEventListener('submit', async event => {
        event.preventDefault();
        try {
            await request('/api/he_thong/lien_thong_toa_thuoc/cau-hinh', { method: 'POST', body: JSON.stringify({
                MoiTruong: document.getElementById('cfg-moi-truong').value,
                ApiBaseUrlProduction: document.getElementById('cfg-api-prod').value,
                ApiBaseUrlTest: document.getElementById('cfg-api-test').value || null,
                UrlKyDuLieu: document.getElementById('cfg-url-ky-data').value || null,
                UrlKyPdf: document.getElementById('cfg-url-ky-pdf').value || null,
                MaLienThongCskcb: document.getElementById('cfg-ma-cskcb').value || null,
                MatKhauCskcb: document.getElementById('cfg-password').value || null,
                KySoHieuLuc: document.getElementById('cfg-ky-active').checked,
                LienThongHieuLuc: document.getElementById('cfg-lien-thong-active').checked
            }) }); showToast('success', 'Đã lưu cấu hình.'); document.getElementById('cfg-password').value = ''; await load();
        } catch (error) { showToast('error', error.message); }
    });
    document.getElementById('cfg-doctor-body').addEventListener('click', async event => {
        const button = event.target.closest('.doctor-save'); if (!button) return;
        const row = button.closest('tr'); button.disabled = true;
        try {
            await request('/api/he_thong/lien_thong_toa_thuoc/bac-si', { method: 'POST', body: JSON.stringify({
                IdNhanVien: Number(row.dataset.id), MaLienThong: row.querySelector('.doctor-code').value || null,
                SoChungChiHanhNghe: row.querySelector('.doctor-license').value || null,
                MatKhau: row.querySelector('.doctor-password').value || null, Active: row.querySelector('.doctor-active').checked
            }) }); showToast('success', 'Đã lưu cấu hình bác sĩ.'); await load();
        } catch (error) { showToast('error', error.message); } finally { button.disabled = false; }
    });
    load().catch(error => showToast('error', error.message));
    loadPdfTemplates().catch(error => {
        if (pdfTemplates) pdfTemplates.innerHTML =
            '<tr><td colspan="7" class="text-danger text-center">Không tải được mẫu ký. Hãy chạy SQL v107.</td></tr>';
        showToast('error', error.message);
    });
})();
