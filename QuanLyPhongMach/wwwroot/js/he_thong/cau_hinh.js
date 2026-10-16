(() => {
    'use strict';

    const root = document.getElementById('ht-config-root');
    if (!root) return;

    const token = root.querySelector('input[name="__RequestVerificationToken"]')?.value || '';
    const idCskcb = Number(root.dataset.cskcbId || 0);

    if (window.bootstrap?.Tooltip) {
        root.querySelectorAll('.ht-config-code[title]').forEach(element => {
            new window.bootstrap.Tooltip(element);
        });
    }

    root.querySelectorAll('.ht-config-toggle').forEach(toggle => {
        toggle.addEventListener('change', async () => {
            const previousState = !toggle.checked;
            const code = toggle.dataset.configCode || '';
            toggle.disabled = true;

            try {
                const response = await fetch(`/api/he_thong/cau_hinh/trang_thai?id_cskcb=${encodeURIComponent(idCskcb)}`, {
                    method: 'POST',
                    credentials: 'same-origin',
                    headers: {
                        'Content-Type': 'application/json',
                        'RequestVerificationToken': token
                    },
                    body: JSON.stringify({
                        ma_chuc_nang: code,
                        hieu_luc: toggle.checked
                    })
                });
                const result = await response.json().catch(() => null);
                if (!response.ok || result?.status !== 200) {
                    throw new Error(result?.message || 'Không cập nhật được cấu hình.');
                }

                toggle.checked = result.data?.hieu_luc === true;
                window.showToast?.('success', result.message || 'Đã cập nhật cấu hình.');
            } catch (error) {
                toggle.checked = previousState;
                const message = error instanceof Error ? error.message : 'Không cập nhật được cấu hình.';
                if (window.showToast) showToast('error', message);
                else alert(message);
            } finally {
                toggle.disabled = false;
            }
        });
    });
})();
