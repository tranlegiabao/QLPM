(() => {
    'use strict';

    const loginPath = '/xac_thuc/dang_nhap';
    const currentPath = (window.location.pathname || '').replace(/\/+$/, '').toLowerCase();
    if (currentPath === loginPath) return;

    function tatTuDongDien(el) {
        if (!(el instanceof Element)) return;

        if (el.matches('form')) {
            if (el.getAttribute('autocomplete') !== 'off') {
                el.setAttribute('autocomplete', 'off');
            }
            return;
        }

        if (!el.matches('input, textarea, select')) return;

        if (el.getAttribute('autocomplete') !== 'off') {
            el.setAttribute('autocomplete', 'off');
        }

        // Hạn chế password manager/extension tự điền trên các màn hình nghiệp vụ.
        // Trang đăng nhập không nạp guard này nên vẫn dùng username/current-password bình thường.
        el.setAttribute('data-lpignore', 'true');
        el.setAttribute('data-1p-ignore', 'true');
        el.setAttribute('data-bwignore', 'true');
        el.setAttribute('data-form-type', 'other');
    }

    function quet(root) {
        if (!(root instanceof Document) && !(root instanceof Element)) return;

        if (root instanceof Element) {
            tatTuDongDien(root);
        }

        root.querySelectorAll?.('form, input, textarea, select').forEach(tatTuDongDien);
    }

    function khoiTao() {
        quet(document);

        document.addEventListener('focusin', event => {
            const target = event.target;
            if (target instanceof Element) tatTuDongDien(target);
        }, true);

        const observer = new MutationObserver(mutations => {
            for (const mutation of mutations) {
                if (mutation.type === 'attributes') {
                    tatTuDongDien(mutation.target);
                    continue;
                }

                mutation.addedNodes.forEach(node => {
                    if (node instanceof Element) quet(node);
                });
            }
        });

        observer.observe(document.documentElement, {
            subtree: true,
            childList: true,
            attributes: true,
            attributeFilter: ['autocomplete']
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', khoiTao, { once: true });
    } else {
        khoiTao();
    }
})();
