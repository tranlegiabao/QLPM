// toast.js - Thư viện thông báo showToast theo chuẩn Section 8.2
(function () {
    let container = document.getElementById('qlpm-toast-container');
    if (!container) {
        container = document.createElement('div');
        container.id = 'qlpm-toast-container';
        container.className = 'toast-container position-fixed top-0 end-0 p-3';
        container.style.zIndex = '99999';
        document.body.appendChild(container);
    }

    window.showToast = function (type, message) {
        if (!message) return;
        
        const toastId = 'toast-' + Date.now() + '-' + Math.floor(Math.random() * 1000);
        let bgClass = 'bg-primary text-white';
        let icon = '<i class="bi bi-info-circle-fill me-2"></i>';
        let headerTitle = 'Thông báo';

        switch (type?.toLowerCase()) {
            case 'success':
                bgClass = 'bg-success text-white';
                icon = '<i class="bi bi-check-circle-fill me-2"></i>';
                headerTitle = 'Thành công';
                break;
            case 'error':
            case 'danger':
                bgClass = 'bg-danger text-white';
                icon = '<i class="bi bi-exclamation-triangle-fill me-2"></i>';
                headerTitle = 'Lỗi';
                break;
            case 'warning':
                bgClass = 'bg-warning text-dark';
                icon = '<i class="bi bi-exclamation-circle-fill me-2"></i>';
                headerTitle = 'Cảnh báo';
                break;
            case 'info':
                bgClass = 'bg-info text-dark';
                icon = '<i class="bi bi-info-circle-fill me-2"></i>';
                headerTitle = 'Thông tin';
                break;
        }

        const toastHtml = `
            <div id="${toastId}" class="toast align-items-center ${bgClass} border-0 shadow-lg mb-2" role="alert" aria-live="assertive" aria-atomic="true">
                <div class="d-flex">
                    <div class="toast-body fs-6 py-2 px-3">
                        ${icon}<strong>${headerTitle}:</strong> ${message}
                    </div>
                    <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast" aria-label="Close"></button>
                </div>
            </div>
        `;

        container.insertAdjacentHTML('beforeend', toastHtml);
        const toastEl = document.getElementById(toastId);
        
        if (window.bootstrap && window.bootstrap.Toast) {
            const bsToast = new bootstrap.Toast(toastEl, { delay: 4000 });
            bsToast.show();
            toastEl.addEventListener('hidden.bs.toast', () => toastEl.remove());
        } else {
            toastEl.classList.add('show');
            setTimeout(() => {
                toastEl.remove();
            }, 4000);
        }
    };
})();
