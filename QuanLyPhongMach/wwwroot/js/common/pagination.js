/**
 * pagination.js - Component Phân trang Cao cấp dùng chung cho QLPM
 */
window.createQLPMPagination = function (config) {
    let currentPage = config.currentPage || 1;
    let pageSize = config.pageSize !== undefined ? config.pageSize : 25;
    let totalItems = config.totalItems || 0;

    const container = typeof config.container === 'string' ? document.querySelector(config.container) : config.container;
    if (!container) {
        console.warn('QLPM pagination: không tìm thấy container', config.container);
        return {
            render: (newTotal, newCurrentPage) => {
                if (newTotal !== undefined) totalItems = newTotal;
                if (newCurrentPage !== undefined) currentPage = Math.max(1, Number(newCurrentPage) || 1);
            },
            getCurrentPage: () => currentPage,
            getPageSize: () => pageSize,
            setPage: (p) => {
                currentPage = Math.max(1, Number(p) || 1);
            }
        };
    }
    const itemName = config.itemName || 'BN';
    const pageSizes = config.pageSizes || [10, 25, 50, 100, 0];
    const onPageChange = config.onPageChange || function () { };
    const tableScrollSelector = config.tableScrollSelector || '.qlpm-table-container';
    const compact = Boolean(config.compact);

    function getTotalPages() {
        if (pageSize === 0 || totalItems <= 0) return 1;
        return Math.ceil(totalItems / pageSize);
    }

    function render(newTotal, newCurrentPage) {
        if (newTotal !== undefined) totalItems = newTotal;
        if (newCurrentPage !== undefined) currentPage = newCurrentPage;

        const totalPages = getTotalPages();
        if (currentPage > totalPages) currentPage = totalPages || 1;
        if (currentPage < 1) currentPage = 1;

        const from = totalItems === 0 ? 0 : (pageSize === 0 ? 1 : (currentPage - 1) * pageSize + 1);
        const to = totalItems === 0 ? 0 : (pageSize === 0 ? totalItems : Math.min(currentPage * pageSize, totalItems));

        let rightHtml = '';
        if (compact) {
            rightHtml = `
                <div class="qlpm-pagination-nav">
                    <button type="button" class="btn-page-pill btn-nav-pill" data-page="${currentPage - 1}" ${currentPage <= 1 ? 'disabled' : ''} title="Trang trước">
                        <i class="bi bi-chevron-left"></i>
                    </button>
                    <span class="qlpm-page-indicator">Trang <strong>${currentPage}</strong>/${Math.max(totalPages, 1)}</span>
                    <button type="button" class="btn-page-pill btn-nav-pill" data-page="${currentPage + 1}" ${currentPage >= totalPages || pageSize === 0 ? 'disabled' : ''} title="Trang sau">
                        <i class="bi bi-chevron-right"></i>
                    </button>
                </div>
            `;
        } else if (pageSize > 0 && totalPages > 1) {
            rightHtml = `
                <div class="qlpm-pagination-nav">
                    <button type="button" class="btn-page-pill btn-nav-pill" data-page="1" ${currentPage <= 1 ? 'disabled' : ''} title="Trang đầu">
                        <i class="bi bi-chevron-double-left"></i>
                    </button>
                    <button type="button" class="btn-page-pill btn-nav-pill" data-page="${currentPage - 1}" ${currentPage <= 1 ? 'disabled' : ''} title="Trang trước">
                        <i class="bi bi-chevron-left"></i>
                    </button>

                    <div class="qlpm-page-numbers">
                        ${renderPageNumbers(totalPages, currentPage)}
                    </div>

                    <button type="button" class="btn-page-pill btn-nav-pill" data-page="${currentPage + 1}" ${currentPage >= totalPages ? 'disabled' : ''} title="Trang sau">
                        <i class="bi bi-chevron-right"></i>
                    </button>
                    <button type="button" class="btn-page-pill btn-nav-pill" data-page="${totalPages}" ${currentPage >= totalPages ? 'disabled' : ''} title="Trang cuối">
                        <i class="bi bi-chevron-double-right"></i>
                    </button>
                </div>

                <div class="qlpm-jump-page-wrap" title="Nhập số trang và nhấn Enter">
                    <span class="jump-label">Đến:</span>
                    <input type="number" min="1" max="${totalPages}" class="qlpm-jump-input" value="${currentPage}" />
                    <span class="jump-total">/ ${totalPages}</span>
                </div>
            `;
        } else {
            rightHtml = `
                <div class="qlpm-pagination-nav">
                    <button type="button" class="btn-page-pill btn-nav-pill" disabled title="Trang trước">
                        <i class="bi bi-chevron-left"></i>
                    </button>
                    <span class="qlpm-page-indicator text-muted">Trang <strong>1</strong>/1</span>
                    <button type="button" class="btn-page-pill btn-nav-pill" disabled title="Trang sau">
                        <i class="bi bi-chevron-right"></i>
                    </button>
                </div>
            `;
        }

        container.className = 'qlpm-pagination-bar' + (compact ? ' qlpm-pagination-compact' : '');
        container.innerHTML = `
            <div class="qlpm-pagination-left">
                <select class="qlpm-page-size-select" title="Số lượng hiển thị mỗi trang">
                    ${pageSizes.map(size => `
                        <option value="${size}" ${size === pageSize ? 'selected' : ''}>
                            ${size === 0 ? 'Tất cả' : size}
                        </option>
                    `).join('')}
                </select>
            </div>

            <div class="qlpm-pagination-right">
                ${rightHtml}
            </div>
        `;

        // Event listeners
        const sizeSelect = container.querySelector('.qlpm-page-size-select');
        if (sizeSelect) {
            sizeSelect.addEventListener('change', function () {
                const newSize = Number(this.value);
                if (newSize !== pageSize) {
                    pageSize = newSize;
                    currentPage = 1;
                    triggerPageChange();
                }
            });
        }

        container.querySelectorAll('.btn-page-pill[data-page]:not([disabled])').forEach(btn => {
            btn.addEventListener('click', function () {
                const p = Number(this.dataset.page);
                if (p && p !== currentPage) {
                    currentPage = p;
                    triggerPageChange();
                }
            });
        });

        const jumpInput = container.querySelector('.qlpm-jump-input');
        if (jumpInput) {
            const handleJump = () => {
                let val = parseInt(jumpInput.value, 10);
                if (isNaN(val) || val < 1) val = 1;
                if (val > totalPages) val = totalPages;
                if (val !== currentPage) {
                    currentPage = val;
                    triggerPageChange();
                } else {
                    jumpInput.value = currentPage;
                }
            };

            jumpInput.addEventListener('keydown', function (e) {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    handleJump();
                }
            });
            jumpInput.addEventListener('change', handleJump);
        }
    }

    function renderPageNumbers(totalPages, current) {
        let html = '';
        if (totalPages <= 1) {
            return `<button type="button" class="btn-page-pill active" data-page="1">1</button>`;
        }

        const maxVisible = 3;
        let start = 1;
        let end = totalPages;

        if (totalPages > maxVisible) {
            if (current <= 2) {
                start = 1;
                end = 3;
            } else if (current >= totalPages - 1) {
                start = totalPages - 2;
                end = totalPages;
            } else {
                start = current - 1;
                end = current + 1;
            }
        }

        for (let i = start; i <= end; i++) {
            html += `<button type="button" class="btn-page-pill ${i === current ? 'active' : ''}" data-page="${i}">${i}</button>`;
        }
        return html;
    }

    function triggerPageChange() {
        if (tableScrollSelector) {
            const scrollEl = document.querySelector(tableScrollSelector);
            if (scrollEl) {
                scrollEl.scrollTo({ top: 0, behavior: 'smooth' });
            }
        }
        onPageChange(currentPage, pageSize);
    }

    return {
        render: render,
        getCurrentPage: () => currentPage,
        getPageSize: () => pageSize,
        setPage: (p) => {
            currentPage = p;
            render();
        }
    };
};
