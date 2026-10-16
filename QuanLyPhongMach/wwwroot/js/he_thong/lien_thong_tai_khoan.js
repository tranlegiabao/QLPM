(() => {
    const root = document.getElementById('ht-root');
    if (!root) return;

    const field = id => document.getElementById(id);
    const states = {
        cs: { id: 0, tenant: 0, editable: false, sequence: 0, loaded: false, hasPassword: false, originalDoctor: false },
        nv: { id: 0, tenant: 0, editable: false, sequence: 0, loaded: false, hasPassword: false, originalDoctor: false }
    };

    async function api(url, options = {}) {
        const response = await fetch(url, { credentials: 'same-origin', ...options });
        const result = await response.json().catch(() => ({}));
        if (!response.ok || result.status !== 200)
            throw new Error(result.message || 'Không đọc/lưu được tài khoản liên thông.');
        return result;
    }

    const urlFor = (kind, id, tenant) => kind === 'cs'
        ? `/api/he_thong/cskcb/${id}/lien-thong`
        : `/api/he_thong/nhan_vien/${id}/lien-thong?id_cskcb=${tenant}`;

    function isDoctor() {
        return field('ht-nv-la-bac-si')?.checked === true;
    }

    function setEditable(kind) {
        const state = states[kind];
        const panel = field(`ht-${kind}-ltt`);
        if (!panel) return;
        const show = kind === 'cs' || isDoctor();
        panel.classList.toggle('d-none', !show);
        const allow = kind === 'cs'
            ? (state.id === 0 || state.editable) && (state.id === 0 || state.loaded)
            : show && state.tenant > 0
                && (state.id === 0 || state.editable)
                && (state.id === 0 || !state.originalDoctor || state.loaded);
        panel.querySelectorAll('input').forEach(el => { el.disabled = !allow; });
    }

    for (const kind of ['cs', 'nv']) {
        const panel = field(`ht-${kind}-ltt`);
        if (!panel) continue;

        document.addEventListener(`ht:${kind}-form`, async event => {
            const state = states[kind];
            const seq = ++state.sequence;
            state.id = Number(event.detail.id || 0);
            state.tenant = Number(event.detail.tenant || 0);
            state.editable = !!event.detail.editable;
            state.originalDoctor = kind === 'nv' && !!event.detail.doctor;
            state.loaded = false;
            state.hasPassword = false;

            field(`ht-${kind}-ltt-ma`).value = '';
            field(`ht-${kind}-ltt-mk`).value = '';
            if (kind === 'nv') field('ht-nv-ltt-cchn').value = '';
            field(`ht-${kind}-ltt-active`).checked = kind === 'nv';
            field(`ht-${kind}-ltt-info`).textContent = state.id
                ? 'Đang tải tài khoản liên thông...'
                : 'Tài khoản liên thông được lưu cùng hồ sơ.';
            setEditable(kind);

            if (!state.id || (kind === 'nv' && (!state.originalDoctor || !state.tenant))) return;
            try {
                const result = await api(urlFor(kind, state.id, state.tenant));
                if (seq !== state.sequence) return;
                const data = result.data || {};
                field(`ht-${kind}-ltt-ma`).value = data.ma_lien_thong || '';
                if (kind === 'nv') field('ht-nv-ltt-cchn').value = data.so_chung_chi_hanh_nghe || '';
                field(`ht-${kind}-ltt-active`).checked = kind === 'cs' ? !!data.hieu_luc : !!data.active;
                state.hasPassword = !!data.da_cau_hinh_mat_khau;
                state.loaded = true;
                field(`ht-${kind}-ltt-info`).textContent = state.hasPassword
                    ? 'Đã có mật khẩu. Để trống để giữ nguyên.'
                    : 'Chưa có mật khẩu liên thông.';
            } catch (error) {
                if (seq === state.sequence)
                    field(`ht-${kind}-ltt-info`).textContent = error.message;
            } finally {
                if (seq === state.sequence) setEditable(kind);
            }
        });
    }

    // Trên hồ sơ mới, checkbox bác sĩ có thể được chọn trước lần Lưu nhân viên đầu tiên.
    field('ht-nv-la-bac-si')?.addEventListener('change', () => setEditable('nv'));

    function payloadFor(kind) {
        const panel = field(`ht-${kind}-ltt`);
        if (!panel || (kind === 'nv' && !isDoctor())) return null;
        const state = states[kind];
        if (state.id > 0 && (kind === 'cs' || state.originalDoctor) && !state.loaded)
            throw new Error('Chưa đọc được tài khoản liên thông. Tải lại hồ sơ trước khi lưu.');
        const payload = {
            ma_lien_thong: field(`ht-${kind}-ltt-ma`).value.trim(),
            mat_khau: field(`ht-${kind}-ltt-mk`).value
        };
        if (payload.ma_lien_thong.length > 100 || payload.mat_khau.length > 500)
            throw new Error('Mã hoặc mật khẩu liên thông vượt quá độ dài cho phép.');

        if (kind === 'cs') {
            payload.hieu_luc = field('ht-cs-ltt-active').checked;
            if (payload.hieu_luc && (!payload.ma_lien_thong || (!payload.mat_khau.trim() && !state.hasPassword)))
                throw new Error('Nhập mã và mật khẩu cơ sở trước khi bật liên thông.');
        } else {
            payload.active = field('ht-nv-ltt-active').checked;
            payload.so_chung_chi_hanh_nghe = field('ht-nv-ltt-cchn').value.trim();
            if (payload.so_chung_chi_hanh_nghe.length > 100)
                throw new Error('Chứng chỉ hành nghề vượt quá 100 ký tự.');
        }
        return payload;
    }

    async function save(kind, id, tenant) {
        const payload = payloadFor(kind);
        if (!payload) return;
        const state = states[kind];
        const seq = state.sequence;
        if (!(id > 0) || (kind === 'nv' && !(tenant > 0)))
            throw new Error('Chưa xác định được hồ sơ để lưu tài khoản liên thông.');
        if (state.id > 0 && state.id !== id)
            throw new Error('Hồ sơ đã thay đổi. Chọn lại hồ sơ trước khi lưu.');

        const result = await api(urlFor(kind, id, tenant), {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        if (seq === state.sequence) {
            state.id = id;
            state.tenant = tenant;
            state.loaded = true;
            state.hasPassword = !!payload.mat_khau.trim() || state.hasPassword;
            field(`ht-${kind}-ltt-mk`).value = '';
            field(`ht-${kind}-ltt-info`).textContent =
                'Đã lưu. Để trống mật khẩu để giữ nguyên.';
            setEditable(kind);
        }
        return result;
    }

    // Hai nút Lưu của hồ sơ CSKCB và nhân viên là điểm lưu duy nhất cho cả phần liên thông.
    window.qlpmLienThongTaiKhoan = {
        kiemTraCskcb: () => payloadFor('cs'),
        luuCskcb: id => save('cs', Number(id), 0),
        kiemTraNhanVien: () => payloadFor('nv'),
        luuNhanVien: (id, tenant) => save('nv', Number(id), Number(tenant))
    };
})();
