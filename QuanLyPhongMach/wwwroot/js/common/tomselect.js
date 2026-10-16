// tomselect.js - Khởi tạo TomSelect thống nhất cho toàn bộ dropdown
function chuanHoaTuKhoaTomSelect(str) {
    return String(str || '')
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .replace(/[đĐ]/g, match => match === 'đ' ? 'd' : 'D')
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '');
}

function taoKyTuVietTat(str) {
    if (!str) return '';
    const khongDau = String(str).normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[đĐ]/g, match => match === 'đ' ? 'd' : 'D');
    const words = khongDau.split(/[\s\-_/.,]+/);
    return words.filter(w => w.length > 0).map(w => w[0]).join('').toLowerCase();
}

window.taoKyTuVietTat = taoKyTuVietTat;

window.tomSelectVietTatScore = function (search) {
    const scoreFn = this.getScoreFunction(search);
    const query = chuanHoaTuKhoaTomSelect(search);
    const labelField = this.settings.labelField;
    const searchFields = Array.isArray(this.settings.searchField)
        ? this.settings.searchField.map(field => typeof field === 'string' ? field : field?.field)
        : [this.settings.searchField];
    const fields = [...new Set([
        labelField,
        ...searchFields,
        'ten', 'text', 'name', 'ho_ten', 'hoten', 'ten_vai_tro', 'hoat_chat', 'viet_tat'
    ].filter(Boolean))];

    return function (item) {
        const baseScore = scoreFn(item);
        if (baseScore > 0 || !query) return baseScore;

        return fields.some(field => {
            const value = item?.[field];
            if (value === undefined || value === null) return false;
            const text = String(value);
            const abbreviations = field.toLowerCase() === 'viet_tat'
                ? [chuanHoaTuKhoaTomSelect(text)]
                : [chuanHoaTuKhoaTomSelect(taoKyTuVietTat(text))];
            return abbreviations.some(abbreviation => abbreviation && abbreviation.includes(query));
        }) ? 1 : 0;
    };
};

window.initTomSelect = function (elOrSelector, options = {}) {
    const el = typeof elOrSelector === 'string' ? document.querySelector(elOrSelector) : elOrSelector;
    if (!el) return null;

    if (el.tomselect) {
        el.tomselect.destroy();
    }

    const showCode = options.showCodeInItem !== false;
    const defaultOpts = {
        valueField: 'id',
        labelField: 'ten',
        searchField: ['ten', 'ma', 'viet_tat'],
        create: false,
        maxItems: 1,
        placeholder: '-- Chọn --',
        score: window.tomSelectVietTatScore,
        render: {
            option: function (data, escape) {
                if (!data.viet_tat && data.ten) {
                    data.viet_tat = taoKyTuVietTat(data.ten);
                }
                return `<div>${escape(data.ten)}${data.ma ? ` <small class="text-muted">(${escape(data.ma)})</small>` : ''}</div>`;
            },
            item: function (data, escape) {
                if (!showCode) {
                    return `<div>${escape(data.ten)}</div>`;
                }
                return `<div>${escape(data.ten)}${data.ma ? ` <small class="text-muted">(${escape(data.ma)})</small>` : ''}</div>`;
            }
        }
    };

    return new TomSelect(el, Object.assign({}, defaultOpts, options));
};

window.initRemoteTomSelect = function (elOrSelector, loaiDanhMuc, customOpts = {}, callback = null) {
    const el = typeof elOrSelector === 'string' ? document.querySelector(elOrSelector) : elOrSelector;
    if (!el) return null;

    if (el.tomselect) {
        el.tomselect.destroy();
    }

    let onSelectCallback = callback;
    if (typeof customOpts === 'function') {
        onSelectCallback = customOpts;
        customOpts = {};
    } else if (customOpts && typeof customOpts.onSelect === 'function') {
        onSelectCallback = customOpts.onSelect;
    }

    const showCode = customOpts.showCodeInItem !== false;
    const isThuoc = loaiDanhMuc === 'thuoc' || loaiDanhMuc === 'dm_thuoc';
    const localSearch = customOpts.localSearch === true;
    const localSearchTop = Math.max(20, Number(customOpts.localSearchTop || 1000));
    const localSearchParams = customOpts.localSearchParams || {};
    const tomSelectCustomOpts = Object.assign({}, customOpts);
    delete tomSelectCustomOpts.localSearch;
    delete tomSelectCustomOpts.localSearchTop;
    delete tomSelectCustomOpts.localSearchParams;

    let localLoadPromise = null;

    const opts = {
        valueField: 'id',
        labelField: 'ten',
        searchField: ['ten', 'ma', 'hoat_chat', 'ham_luong', 'viet_tat'],
        create: false,
        preload: localSearch ? true : 'focus',
        loadThrottle: localSearch ? null : 300,
        placeholder: isThuoc ? '-- Gõ tên biệt dược hoặc hoạt chất để kê đơn --' : '-- Tìm kiếm và chọn --',
        score: window.tomSelectVietTatScore,
        load: function (query, callback) {
            let baseUrl = loaiDanhMuc;
            if (!baseUrl.startsWith('/')) {
                baseUrl = `/api/danh_muc/${loaiDanhMuc}`;
            }

            const buildUrl = (searchText, top) => {
                const params = new URLSearchParams();
                params.set('q', searchText || '');
                params.set('top', String(top));
                if (localSearch) {
                    Object.entries(localSearchParams).forEach(([key, value]) => {
                        if (value !== undefined && value !== null && value !== '') {
                            params.set(key, String(value));
                        }
                    });
                }
                const sep = baseUrl.includes('?') ? '&' : '?';
                return `${baseUrl}${sep}${params.toString()}`;
            };

            if (localSearch) {
                if (!localLoadPromise) {
                    localLoadPromise = fetch(buildUrl('', localSearchTop))
                        .then(res => res.json())
                        .then(json => Array.isArray(json.data) ? json.data : []);
                }
                localLoadPromise
                    .then(items => callback(items))
                    .catch(() => callback());
                return;
            }

            fetch(buildUrl(query || '', 20))
                .then(res => res.json())
                .then(json => callback(json.data || []))
                .catch(() => callback());
        },
        onChange: function (val) {
            if (!val) return;
            const data = this.options[val];
            if (data && onSelectCallback) {
                onSelectCallback(data);
            }
        },
        render: {
            option: function (data, escape) {
                if (isThuoc) {
                    return `<div class="py-1 border-bottom">
                        <div class="d-flex justify-content-between">
                            <strong class="text-primary">${escape(data.ten)}</strong>
                            <span class="text-danger fw-bold">${Number(data.don_gia || 0).toLocaleString('vi-VN')} đ</span>
                        </div>
                        <div class="small text-muted">
                            ${data.ham_luong ? `<span>HL: <strong>${escape(data.ham_luong)}</strong></span> | ` : ''}
                            ${data.hoat_chat ? `<span>HC: <em>${escape(data.hoat_chat)}</em></span> | ` : ''}
                            <span>ĐVT: ${escape(data.don_vi_tinh || 'Viên')}</span>
                            ${data.duong_dung ? ` | <span>ĐD: ${escape(data.duong_dung)}</span>` : ''}
                        </div>
                    </div>`;
                }

                let extra = '';
                if (data.don_gia) {
                    extra += ` <span class="badge bg-light text-dark border ms-1">${Number(data.don_gia).toLocaleString('vi-VN')} đ</span>`;
                }
                if (data.don_vi_tinh) {
                    extra += ` <small class="text-secondary">(${escape(data.don_vi_tinh)})</small>`;
                }
                return `<div class="py-1">
                    <strong>${escape(data.ten)}</strong>${data.ma ? ` <small class="text-muted">[${escape(data.ma)}]</small>` : ''}
                    ${extra}
                </div>`;
            },
            item: function (data, escape) {
                if (!showCode) {
                    return `<div>${escape(data.ten)}</div>`;
                }
                return `<div>${escape(data.ten)}${data.ma ? ` <small class="text-muted">(${escape(data.ma)})</small>` : ''}</div>`;
            }
        }
    };

    return new TomSelect(el, Object.assign({}, opts, tomSelectCustomOpts));
};

