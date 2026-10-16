// api.js - Helper thực thi gọi HTTP API
window.escapeHtml = function (str) {
    if (!str) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
};

window.formatCurrencyVN = function (val) {
    if (val === null || val === undefined || isNaN(val)) return '0 đ';
    return Number(val).toLocaleString('vi-VN') + ' đ';
};

window.logClientError = function (context, error, details = null) {
    console.error(`[QLPM] ${context || 'Lỗi ứng dụng'}`, error, details || '');
};

window.apiGet = async function (url, params = {}) {
    try {
        const queryParams = new URLSearchParams();
        for (const [key, value] of Object.entries(params)) {
            if (value !== null && value !== undefined && value !== '') {
                queryParams.append(key, value);
            }
        }
        const fullUrl = queryParams.toString() ? `${url}?${queryParams.toString()}` : url;
        const res = await fetch(fullUrl, {
            headers: { 'Accept': 'application/json' }
        });
        if (res.status === 401) {
            window.location.href = `/xac_thuc/dang_nhap?return_url=${encodeURIComponent(location.pathname + location.search)}`;
            return { status: 401, message: 'Phiên đăng nhập đã hết hạn.' };
        }
        if (res.status === 403) {
            showToast('warning', 'Bạn không có quyền thực hiện việc này.');
            return { status: 403, message: 'Không có quyền truy cập.' };
        }
        if (!res.ok) {
            let payload = null;
            try { payload = await res.json(); } catch (_) { }
            const message = payload?.message || `HTTP ${res.status}: ${res.statusText}`;
            window.logClientError('apiGet Error', new Error(message), { url, status: res.status, response: payload });
            return {
                status: Number(payload?.status || res.status),
                message,
                data: payload?.data ?? null
            };
        }
        return await res.json();
    } catch (err) {
        window.logClientError('apiGet', err, { url });
        showToast('error', 'Không kết nối được máy chủ.');
        return { status: 500, message: 'Không tải được dữ liệu.' };
    }
};

window.apiPost = async function (url, data = {}) {
    try {
        const res = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            },
            body: JSON.stringify(data)
        });
        if (res.status === 401) {
            window.location.href = `/xac_thuc/dang_nhap?return_url=${encodeURIComponent(location.pathname + location.search)}`;
            return { status: 401, message: 'Phiên đăng nhập đã hết hạn.' };
        }
        if (res.status === 403) {
            showToast('warning', 'Bạn không có quyền thực hiện việc này.');
            return { status: 403, message: 'Không có quyền truy cập.' };
        }
        if (!res.ok) {
            let payload = null;
            try { payload = await res.json(); } catch (_) { }
            const message = payload?.message || `HTTP ${res.status}: ${res.statusText}`;
            window.logClientError('apiPost Error', new Error(message), { url, status: res.status, response: payload });
            return {
                status: Number(payload?.status || res.status),
                message,
                data: payload?.data ?? null
            };
        }
        return await res.json();
    } catch (err) {
        window.logClientError('apiPost', err, { url });
        showToast('error', 'Không gửi được dữ liệu.');
        return { status: 500, message: 'Không gửi được dữ liệu.' };
    }
};
