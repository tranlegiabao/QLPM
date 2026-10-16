(() => {
    let dsCskcb = [];
    let dsCskcbTongQuan = [];
    let dsNhanVien = [];
    let dsTaiKhoan = [];
    let dsVaiTro = [];
    let dsVaiTroLookup = [];
    let dsChucDanh = [];
    let dsChucDanhLookup = [];
    const htPaging = {
        ov: { page: 1, size: 10, total: 0, pager: null },
        cs: { page: 1, size: 25, total: 0, pager: null },
        nv: { page: 1, size: 25, total: 0, pager: null },
        tk: { page: 1, size: 25, total: 0, pager: null },
        vt: { page: 1, size: 25, total: 0, pager: null },
        cd: { page: 1, size: 25, total: 0, pager: null }
    };
    let tsNhanVien = null;
    let tsNhanVienChucDanh = null;
    let tsTaiKhoanVaiTro = null;
    let tsPhanQuyenVaiTro = null;
    let htLayoutResizeTimer = null;
    const htLayoutObservers = [];

    const htRoot = document.getElementById('ht-root');
    const canDeleteCskcb = htRoot?.dataset.canDeleteCskcb === 'true';
    const canDeleteNv = htRoot?.dataset.canDeleteNv === 'true';
    const canDeleteTk = htRoot?.dataset.canDeleteTk === 'true';
    const canDeleteVt = htRoot?.dataset.canDeleteVt === 'true';
    const isGlobalAdmin = htRoot?.dataset.globalAdmin === 'true';
    const pageMode = htRoot?.dataset.page || 'legacy';
    let idCskcbQuanTri = Number(htRoot?.dataset.cskcbId || sessionStorage.getItem('qlpm_ht_cskcb') || 0);
    let tenCskcbQuanTri = (htRoot?.dataset.cskcbName || sessionStorage.getItem('qlpm_ht_cskcb_ten') || '').trim();
    let logoFileChoLuu = null;
    let logoObjectUrl = null;
    let htFloatingActionMenu = null;
    let htFloatingActionButton = null;
    let htFloatingActionOutsideHandler = null;
    const htSearchTerms = { cs: '', nv: '', tk: '', vt: '', cd: '' };
    const htSearchTomSelect = {};
    const htSearchTimers = {};
    let dsTinhThanhHeThong = [];
    const htLoadedTabs = new Set();

    document.addEventListener('DOMContentLoaded', async () => {
        tatAutofillHeThong();
        ganSuKien();
        khoiTaoTimKiemQuanTri();
        khoiTaoBoCucDanhSach();
        capNhatNguCanhUi();

        if (pageMode === 'detail') {
            await taiTinhThanhHeThong();
            const activeTab = document.querySelector('#ht-root .ht-detail-content > .tab-pane.active')?.id;
            const activeSelector = activeTab ? '#' + activeTab : null;
            if (activeSelector) await taiTabKhiMo(activeSelector);
        } else if (isGlobalAdmin) {
            await taiTongQuanCskcb(true);
        } else {
            await taiDuLieuTenant();
        }

        requestAnimationFrame(() => dongBoChieuCaoDanhSach());
        hienThiThongBaoLuuCskcb();
    });

    function hienThiThongBaoLuuCskcb() {
        const key = 'qlpm_ht_cskcb_save_toast';
        const stored = sessionStorage.getItem(key);
        if (!stored) return;
        sessionStorage.removeItem(key);
        try {
            const notice = JSON.parse(stored);
            if (notice.path === window.location.pathname && Date.now() - notice.createdAt < 120000) {
                showToast('success', notice.message || 'Lưu cơ sở KCB thành công.');
            }
        } catch (_) {
            // Bỏ qua thông báo chuyển trang không hợp lệ.
        }
    }

    function tatAutofillHeThong() {
        const apply = root => {
            if (!root?.querySelectorAll) return;
            root.querySelectorAll('input, textarea').forEach(el => {
                const type = String(el.getAttribute('type') || 'text').toLowerCase();
                if (['hidden', 'file', 'checkbox', 'radio', 'button', 'submit'].includes(type)) return;
                el.setAttribute('autocomplete', type === 'password' ? 'new-password' : 'off');
                el.setAttribute('data-lpignore', 'true');
                el.setAttribute('data-1p-ignore', 'true');
                el.setAttribute('autocapitalize', 'off');
                el.setAttribute('spellcheck', 'false');
            });
        };

        apply(htRoot);
        if (htRoot && typeof MutationObserver !== 'undefined') {
            const observer = new MutationObserver(mutations => {
                mutations.forEach(m => m.addedNodes.forEach(node => {
                    if (node.nodeType !== Node.ELEMENT_NODE) return;
                    if (node.matches?.('input, textarea')) apply(node.parentElement || htRoot);
                    else apply(node);
                }));
            });
            observer.observe(htRoot, { childList: true, subtree: true });
        }
    }

    function layTuKhoaTimKiemQuanTri(key, inputId) {
        return Object.prototype.hasOwnProperty.call(htSearchTerms, key)
            ? String(htSearchTerms[key] || '').trim()
            : (document.getElementById(inputId)?.value?.trim() || '');
    }

    function khoiTaoTimKiemQuanTri() {
        const configs = {
            cs: { id: 'ht-cs-filter', load: taiCskcb },
            nv: { id: 'ht-nv-filter', load: taiNhanVien },
            tk: { id: 'ht-tk-filter', load: taiTaiKhoan },
            vt: { id: 'ht-vt-filter', load: taiVaiTro },
            cd: { id: 'ht-cd-filter', load: taiChucDanh }
        };

        Object.entries(configs).forEach(([key, cfg]) => {
            const input = document.getElementById(cfg.id);
            if (!input || input.tomselect) return;
            htSearchTerms[key] = input.value || '';
            const ts = new TomSelect(input, {
                create: false,
                maxItems: 1,
                openOnFocus: false,
                persist: false,
                placeholder: input.getAttribute('placeholder') || 'Tìm kiếm...',
                score: window.tomSelectVietTatScore,
                render: { no_results: () => '<div class="d-none"></div>' },
                onType(value) {
                    htSearchTerms[key] = value || '';
                    this.close();
                    window.clearTimeout(htSearchTimers[key]);
                    htSearchTimers[key] = window.setTimeout(() => {
                        htPaging[key].page = 1;
                        cfg.load(true);
                    }, 220);
                }
            });
            ts.control_input?.setAttribute('autocomplete', 'off');
            ts.control_input?.setAttribute('data-lpignore', 'true');
            ts.control_input?.setAttribute('data-1p-ignore', 'true');
            htSearchTomSelect[key] = ts;
        });
    }

    function sttNguoc(state, index) {
        const total = Math.max(0, Number(state?.total || 0));
        const page = Math.max(1, Number(state?.page || 1));
        const size = Math.max(1, Number(state?.size || 25));
        return Math.max(1, total - ((page - 1) * size + index));
    }

    function ganSuKienXemDong(tr, callback) {
        tr.classList.add('ht-clickable-row');
        tr.addEventListener('click', e => {
            if (e.target.closest('button, a, input, select, textarea, .dropdown-menu, .ts-wrapper')) return;
            tr.parentElement?.querySelectorAll('tr.selected, tr.table-active').forEach(row => row.classList.remove('selected', 'table-active'));
            tr.classList.add('selected', 'table-active');
            callback?.();
        });
    }

    function duaFormVaoTamNhin(controlId) {
        if (pageMode !== 'detail') return;
        const card = document.getElementById(controlId)?.closest('.ht-detail-form-card');
        const content = card?.closest('.ht-detail-content');
        if (!card || !content) return;
        requestAnimationFrame(() => {
            const rect = card.getBoundingClientRect();
            const viewport = content.getBoundingClientRect();
            const top = Math.max(0, viewport.top);
            const bottom = Math.min(window.innerHeight, viewport.bottom);
            const visibleHeight = Math.min(rect.height, Math.max(0, bottom - top));
            if (rect.top < top || rect.top + visibleHeight > bottom) {
                content.scrollTop += rect.top - viewport.top - 12;
            }
        });
    }

    function datControlSua(id, choSua) {
        const el = document.getElementById(id);
        if (!el) return;
        if (el.tomselect) {
            if (choSua) el.tomselect.enable();
            else el.tomselect.disable();
            return;
        }
        el.disabled = !choSua;
    }

    function datCheDoForm(ids, saveButtonId, choSua) {
        ids.forEach(id => datControlSua(id, choSua));
        const save = document.getElementById(saveButtonId);
        if (save) save.disabled = !choSua;
    }

    function datCheDoCskcb(choSua) {
        datCheDoForm([
            'ht-cs-ma','ht-cs-ten','ht-cs-so-nha','ht-cs-sdt','ht-cs-tinh','ht-cs-phuong',
            'ht-cs-email','ht-cs-ma-st','ht-cs-so-tk','ht-cs-ngan-hang','ht-cs-active',
            'ht-cs-logo-link','ht-cs-logo-file','btn-ht-cs-logo-file'
        ], 'btn-ht-cs-luu', choSua);
    }

    function datCheDoNhanVien(choSua) {
        datCheDoForm([
            'ht-nv-ma','ht-nv-ho-ten','ht-nv-chuc-danh','ht-nv-dien-thoai',
            'ht-nv-email','ht-nv-so-nha','ht-nv-tinh','ht-nv-phuong','ht-nv-la-bac-si','ht-nv-active'
        ], 'btn-ht-nv-luu', choSua);
    }

    function datCheDoTaiKhoan(choSua) {
        datCheDoForm([
            'ht-tk-nhan-vien','ht-tk-ten','ht-tk-vai-tro'
        ], 'btn-ht-tk-luu', choSua);
    }

    function datCheDoVaiTro(choSua) {
        datCheDoForm([
            'ht-vt-ma','ht-vt-ten','ht-vt-mo-ta','ht-vt-active'
        ], 'btn-ht-vt-luu', choSua);
    }

    function datCheDoChucDanh(choSua) {
        datCheDoForm([
            'ht-cd-ma','ht-cd-ten','ht-cd-viet-tat','ht-cd-active'
        ], 'btn-ht-cd-luu', choSua);
    }

    function dongMenuTuyChonNoi() {
        htFloatingActionMenu?.remove();
        htFloatingActionMenu = null;
        htFloatingActionButton = null;
        if (htFloatingActionOutsideHandler) {
            document.removeEventListener('pointerdown', htFloatingActionOutsideHandler, true);
            htFloatingActionOutsideHandler = null;
        }
    }

    function moMenuTuyChon(button, actions) {
        if (htFloatingActionMenu && htFloatingActionButton === button) {
            dongMenuTuyChonNoi();
            return;
        }
        dongMenuTuyChonNoi();
        const menu = document.createElement('div');
        menu.className = 'dropdown-menu show ht-floating-action-menu shadow';
        menu.innerHTML = actions.map(action => `${action.dividerBefore ? '<div class="dropdown-divider"></div>' : ''}
            <button type="button" class="dropdown-item ${action.danger ? 'text-danger' : ''} act-${action.id}"><i class="bi ${action.icon} me-2 ${action.iconClass || ''}"></i>${action.label}</button>
        `).join('');
        document.body.appendChild(menu);
        htFloatingActionMenu = menu;
        htFloatingActionButton = button;

        const rect = button.getBoundingClientRect();
        const menuRect = menu.getBoundingClientRect();
        let left = Math.max(8, Math.min(rect.right - menuRect.width, window.innerWidth - menuRect.width - 8));
        let top = rect.bottom + 4;
        if (top + menuRect.height > window.innerHeight - 8) top = rect.top - menuRect.height - 4;
        menu.style.left = `${Math.round(left)}px`;
        menu.style.top = `${Math.max(8, Math.round(top))}px`;

        actions.forEach(action => menu.querySelector(`.act-${action.id}`)?.addEventListener('click', async e => {
            e.stopPropagation();
            dongMenuTuyChonNoi();
            await action.run();
        }));

        htFloatingActionOutsideHandler = e => {
            if (menu.contains(e.target) || button.contains(e.target)) return;
            dongMenuTuyChonNoi();
        };
        document.addEventListener('pointerdown', htFloatingActionOutsideHandler, true);
    }

    function moMenuTaiKhoan(button, x, active) {
        moMenuTuyChon(button, [
            { id: 'edit', label: 'Sửa', icon: 'bi-pencil', iconClass: 'text-primary', run: () => suaTaiKhoan(x, true) },
            { id: 'state', label: active ? 'Khóa tài khoản' : 'Mở tài khoản', icon: active ? 'bi-lock' : 'bi-unlock', iconClass: active ? 'text-danger' : 'text-success', run: () => { datNguCanhTuDong(x); return doiTrangThaiTaiKhoan(x, !active); } },
            ...(canDeleteTk ? [{ id: 'delete', label: 'Xóa tài khoản', icon: 'bi-trash', danger: true, dividerBefore: true, run: () => { datNguCanhTuDong(x); return xoaTaiKhoan(x); } }] : [])
        ]);
    }

    function khoiTaoBoCucDanhSach() {
        if (pageMode === 'detail') {
            khoiTaoTabChiTiet();
            return;
        }
        const paneSelector = '#ht-tab-nhan-vien, #ht-tab-chuc-danh, #ht-tab-cskcb, #ht-tab-tai-khoan, #ht-tab-vai-tro';
        const panes = [...document.querySelectorAll(paneSelector)];

        panes.forEach(pane => {
            const row = pane.querySelector(':scope > .row');
            const formCard = row?.querySelector(':scope > .col-lg-4 > .card');
            const listCard = row?.querySelector(':scope > .col-lg-8 > .card');
            if (!formCard || !listCard) return;

            listCard.classList.add('ht-admin-list-card');

            if (typeof ResizeObserver !== 'undefined') {
                const observer = new ResizeObserver(() => {
                    if (pane.classList.contains('active')) dongBoChieuCaoDanhSach(pane);
                });
                observer.observe(formCard);
                htLayoutObservers.push(observer);
            }
        });

        if (pageMode === 'detail') {
            khoiTaoTabChiTiet();
        } else {
            document.querySelectorAll('#ht-tabs [data-bs-toggle="tab"]').forEach(tab => {
                tab.addEventListener('shown.bs.tab', async e => {
                    const selector = e.target?.getAttribute('data-bs-target');
                    const pane = selector ? document.querySelector(selector) : null;
                    await taiTabKhiMo(selector);
                    requestAnimationFrame(() => dongBoChieuCaoDanhSach(pane));
                });
            });
        }

        window.addEventListener('resize', () => {
            window.clearTimeout(htLayoutResizeTimer);
            htLayoutResizeTimer = window.setTimeout(() => dongBoChieuCaoDanhSach(), 80);
        });

        requestAnimationFrame(() => dongBoChieuCaoDanhSach());
    }

    // Chi tiết cơ sở có hai hàng tab: nhóm cấp 1 và các tab con cấp 2.
    // Dùng một bộ điều phối để chỉ có duy nhất một pane active, tránh lỗi
    // Bootstrap Tab khi nút điều khiển nằm trong hai danh sách nav khác nhau.
    function khoiTaoTabChiTiet() {
        const mainTabs = document.getElementById('ht-tabs');
        const subTabs = document.getElementById('ht-subtabs');
        const content = document.querySelector('#ht-root .ht-detail-content');
        if (!mainTabs || !subTabs || !content) return;

        const groups = [...mainTabs.querySelectorAll('[data-ht-group]')];
        const subItems = [...subTabs.querySelectorAll('[data-ht-subgroup]')];
        const subButtons = [...subTabs.querySelectorAll('[data-ht-target]')];

        function activate(selector, group) {
            const pane = selector ? content.querySelector(selector) : null;
            const groupButton = groups.find(button => button.dataset.htGroup === group);
            if (!pane || !groupButton || groupButton.disabled) return;

            for (const item of content.querySelectorAll(':scope > .tab-pane')) {
                const active = item === pane;
                item.classList.toggle('active', active);
                item.classList.toggle('show', active);
            }

            groups.forEach(button => {
                const active = button === groupButton;
                button.classList.toggle('active', active);
                button.setAttribute('aria-selected', String(active));
            });

            const hasSubtabs = group === 'nhan-su' || group === 'quyen';
            subTabs.classList.toggle('d-none', !hasSubtabs);
            let visibleCount = 0;
            subItems.forEach(item => {
                const visible = hasSubtabs && item.dataset.htSubgroup === group;
                item.classList.toggle('d-none', !visible);
                if (visible) visibleCount++;
            });
            subTabs.style.setProperty('--ht-sub-count', String(Math.max(1, visibleCount)));

            subButtons.forEach(button => {
                const active = button.dataset.htTarget === selector;
                button.classList.toggle('active', active);
                button.setAttribute('aria-selected', String(active));
                button.tabIndex = active ? 0 : -1;
            });
            if (hasSubtabs) groupButton.dataset.htLast = selector;
            taiTabKhiMo(selector).catch(error => {
                console.error('Không tải được tab quản trị:', error);
                showToast('error', 'Không tải được dữ liệu của tab.');
            });
        }

        groups.forEach(button => {
            button.addEventListener('click', () => {
                if (button.disabled) return;
                const group = button.dataset.htGroup;
                const selector = group === 'cskcb' || group === 'cau-hinh'
                    ? button.dataset.htTarget
                    : button.dataset.htLast || button.dataset.htDefault;
                activate(selector, group);
            });
        });
        subButtons.forEach(button => {
            button.addEventListener('click', () => {
                if (button.disabled) return;
                const group = button.closest('[data-ht-subgroup]')?.dataset.htSubgroup;
                activate(button.dataset.htTarget, group);
            });
        });
    }

    function dongBoChieuCaoDanhSach(pane = null) {
        if (pageMode === 'detail') return;
        const panes = pane
            ? [pane]
            : [...document.querySelectorAll('#ht-tab-nhan-vien.active, #ht-tab-chuc-danh.active, #ht-tab-cskcb.active, #ht-tab-tai-khoan.active, #ht-tab-vai-tro.active')];

        panes.forEach(currentPane => {
            const row = currentPane?.querySelector(':scope > .row');
            const formCard = row?.querySelector(':scope > .col-lg-4 > .card');
            const listCard = row?.querySelector(':scope > .col-lg-8 > .card');
            if (!formCard || !listCard) return;

            if (window.innerWidth < 992) {
                listCard.style.removeProperty('height');
                listCard.style.removeProperty('max-height');
                return;
            }

            const formHeight = Math.ceil(formCard.getBoundingClientRect().height);
            if (formHeight <= 0) return;

            listCard.style.height = formHeight + 'px';
            listCard.style.maxHeight = formHeight + 'px';
        });
    }

    function ganSuKien() {
        document.getElementById('btn-ht-cs-luu')?.addEventListener('click', luuCskcb);
        document.getElementById('btn-ht-cs-moi')?.addEventListener('click', resetFormCskcb);
        document.getElementById('btn-ht-cs-tai-lai')?.addEventListener('click', taiCskcb);
        document.getElementById('btn-ht-cs-filter')?.addEventListener('click', () => { htPaging.cs.page = 1; taiCskcb(); });
        document.getElementById('ht-cs-filter')?.addEventListener('keydown', e => {
            if (e.key === 'Enter') { e.preventDefault(); htPaging.cs.page = 1; taiCskcb(); }
        });
        document.getElementById('btn-ht-nv-luu')?.addEventListener('click', luuNhanVien);
        document.getElementById('btn-ht-nv-moi')?.addEventListener('click', resetFormNhanVien);
        document.getElementById('btn-ht-nv-tai-lai')?.addEventListener('click', taiNhanVien);
        document.getElementById('btn-ht-nv-filter')?.addEventListener('click', () => { htPaging.nv.page = 1; taiNhanVien(); });
        document.getElementById('ht-nv-filter')?.addEventListener('keydown', e => {
            if (e.key === 'Enter') { e.preventDefault(); htPaging.nv.page = 1; taiNhanVien(); }
        });
        document.getElementById('ht-cs-tinh')?.addEventListener('change', async () => {
            await taiPhuongXaHeThong('cs', layGiaTriSelect('ht-cs-tinh'));
        });
        document.getElementById('ht-nv-tinh')?.addEventListener('change', async () => {
            await taiPhuongXaHeThong('nv', layGiaTriSelect('ht-nv-tinh'));
        });

        ['ht-cs-sdt', 'ht-nv-dien-thoai'].forEach(id => {
            const el = document.getElementById(id);
            el?.addEventListener('input', () => {
                el.value = chiLaySo(el.value, 10);
            });
        });
        document.getElementById('btn-ht-tk-luu')?.addEventListener('click', luuTaiKhoan);
        document.getElementById('btn-ht-tk-moi')?.addEventListener('click', resetFormTaiKhoan);
        document.getElementById('btn-ht-tk-tai-lai')?.addEventListener('click', taiTaiKhoan);
        document.getElementById('btn-ht-tk-filter')?.addEventListener('click', () => { htPaging.tk.page = 1; taiTaiKhoan(); });
        document.getElementById('ht-tk-filter')?.addEventListener('keydown', e => {
            if (e.key === 'Enter') { e.preventDefault(); htPaging.tk.page = 1; taiTaiKhoan(); }
        });
        document.getElementById('btn-ht-cd-luu')?.addEventListener('click', luuChucDanh);
        document.getElementById('btn-ht-cd-moi')?.addEventListener('click', resetFormChucDanh);
        document.getElementById('btn-ht-cd-tai-lai')?.addEventListener('click', taiChucDanh);
        document.getElementById('btn-ht-cd-filter')?.addEventListener('click', () => { htPaging.cd.page = 1; taiChucDanh(); });
        document.getElementById('ht-cd-filter')?.addEventListener('keydown', e => {
            if (e.key === 'Enter') { e.preventDefault(); htPaging.cd.page = 1; taiChucDanh(); }
        });
        document.getElementById('btn-ht-vt-luu')?.addEventListener('click', luuVaiTro);
        document.getElementById('btn-ht-vt-moi')?.addEventListener('click', resetFormVaiTro);
        document.getElementById('btn-ht-vt-tai-lai')?.addEventListener('click', taiVaiTro);
        document.getElementById('btn-ht-vt-filter')?.addEventListener('click', () => { htPaging.vt.page = 1; taiVaiTro(); });
        document.getElementById('ht-vt-filter')?.addEventListener('keydown', e => {
            if (e.key === 'Enter') { e.preventDefault(); htPaging.vt.page = 1; taiVaiTro(); }
        });
        document.getElementById('btn-ht-pq-luu')?.addEventListener('click', luuPhanQuyen);
        document.getElementById('btn-ht-dong-bo')?.addEventListener('click', dongBoDanhMuc);
        document.getElementById('ht-pq-vai-tro')?.addEventListener('change', e => taiPhanQuyen(e.target.value));
        document.getElementById('btn-ht-overview-reload')?.addEventListener('click', () => taiTongQuanCskcb(true));
        document.getElementById('btn-ht-overview-search')?.addEventListener('click', () => {
            htPaging.ov.page = 1;
            taiTongQuanCskcb(true);
        });
        document.getElementById('ht-overview-search')?.addEventListener('keydown', e => {
            if (e.key === 'Enter') {
                e.preventDefault();
                htPaging.ov.page = 1;
                taiTongQuanCskcb(true);
            }
        });
        document.getElementById('ht-overview-status')?.addEventListener('change', () => {
            htPaging.ov.page = 1;
            taiTongQuanCskcb(true);
        });
        document.getElementById('btn-ht-context-clear')?.addEventListener('click', () => {
            idCskcbQuanTri = 0;
            tenCskcbQuanTri = '';
            sessionStorage.removeItem('qlpm_ht_cskcb');
            sessionStorage.removeItem('qlpm_ht_cskcb_ten');
            htLoadedTabs.clear();
            capNhatNguCanhUi();
            renderTongQuanCskcb();
            const tab = document.querySelector('[data-bs-target="#ht-tab-tong-quan"]');
            if (tab && window.bootstrap?.Tab) bootstrap.Tab.getOrCreateInstance(tab).show();
        });

        const fileInputAnh = document.getElementById('ht-cs-logo-file');
        const dropzoneAnh = document.getElementById('ht-cs-image-dropzone');

        document.getElementById('btn-ht-cs-logo-file')?.addEventListener('click', e => {
            e.stopPropagation();
            fileInputAnh?.click();
        });
        fileInputAnh?.addEventListener('change', e => {
            const file = e.target.files?.[0];
            if (file) xemTruocLogoFile(file);
            e.target.value = '';
        });
        dropzoneAnh?.addEventListener('click', e => {
            if (e.target.closest('button')) return;
            fileInputAnh?.click();
        });
        dropzoneAnh?.addEventListener('keydown', e => {
            if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault();
                fileInputAnh?.click();
            }
        });
        ['dragenter', 'dragover'].forEach(type => dropzoneAnh?.addEventListener(type, e => {
            e.preventDefault();
            dropzoneAnh.classList.add('is-dragover');
        }));
        ['dragleave', 'drop'].forEach(type => dropzoneAnh?.addEventListener(type, e => {
            e.preventDefault();
            dropzoneAnh.classList.remove('is-dragover');
        }));
        dropzoneAnh?.addEventListener('drop', e => {
            const file = e.dataTransfer?.files?.[0];
            if (file) xemTruocLogoFile(file);
        });

        document.getElementById('btn-ht-cs-logo-link-apply')?.addEventListener('click', () => {
            const url = document.getElementById('ht-cs-logo-link')?.value?.trim() || '';
            if (!url) { showToast('warning', 'Nhập liên kết hình ảnh.'); return; }
            huyLogoFileChoLuu();
            capNhatLogoCskcb(url);
        });
        document.getElementById('btn-ht-cs-logo-clear')?.addEventListener('click', () => {
            huyLogoFileChoLuu();
            capNhatLogoCskcb('');
        });
        window.addEventListener('resize', dongMenuTuyChonNoi);
        document.querySelector('.admin-workspace')?.addEventListener('scroll', dongMenuTuyChonNoi, true);

        document.getElementById('btn-ht-cs-xoa-page')?.addEventListener('click', () => {
            const id = Number(document.getElementById('ht-cs-id')?.value || idCskcbQuanTri || 0);
            if (id <= 0) return;
            xoaCskcb({
                IDCSKCB: id,
                MaCSKCB: document.getElementById('ht-cs-ma')?.value || '',
                TenCSKCB: document.getElementById('ht-cs-ten')?.value || tenCskcbQuanTri
            });
        });

    }

    async function goiJson(url, options = {}) {
        const res = await fetch(url, {
            credentials: 'same-origin',
            headers: { 'Content-Type': 'application/json', ...(options.headers || {}) },
            ...options
        });
        if (res.status === 401) {
            window.location.href = `/xac_thuc/dang_nhap?return_url=${encodeURIComponent(location.pathname + location.search)}`;
            throw new Error('Chưa đăng nhập');
        }
        if (res.status === 403) throw new Error('Bạn không có quyền thực hiện chức năng này.');
        const data = await res.json();
        return data;
    }

    function chiLaySo(value, max = 10) {
        return String(value || '').replace(/\D/g, '').slice(0, max);
    }

    function khoiTaoTomSelectDon(select, placeholder) {
        if (!select || typeof TomSelect === 'undefined') return null;
        if (select.tomselect) return select.tomselect;
        const ts = new TomSelect(select, {
            create: false,
            maxItems: 1,
            allowEmptyOption: true,
            placeholder: placeholder || '-- Chọn --',
            score: window.tomSelectVietTatScore
        });
        ts.control_input?.setAttribute('autocomplete', 'off');
        ts.control_input?.setAttribute('data-lpignore', 'true');
        ts.control_input?.setAttribute('data-1p-ignore', 'true');
        return ts;
    }

    function layGiaTriSelect(id) {
        const el = document.getElementById(id);
        if (!el) return '';
        return el.tomselect ? String(el.tomselect.getValue() || '') : String(el.value || '');
    }

    function datGiaTriSelect(id, value, silent = true) {
        const el = document.getElementById(id);
        if (!el) return;
        const val = value == null ? '' : String(value);
        if (el.tomselect) el.tomselect.setValue(val, silent);
        else el.value = val;
    }

    function napOptionsSelect(id, rows, placeholder, selected = '', disabled = false) {
        const select = document.getElementById(id);
        if (!select) return null;

        if (select.tomselect) select.tomselect.destroy();
        select.innerHTML = '';
        const empty = document.createElement('option');
        empty.value = '';
        empty.textContent = placeholder;
        select.appendChild(empty);

        (rows || []).forEach(x => {
            const option = document.createElement('option');
            option.value = String(x.value ?? x.ma ?? x.id ?? '');
            option.textContent = String(x.text ?? x.ten ?? x.ma ?? '');
            select.appendChild(option);
        });

        select.disabled = disabled;
        const ts = khoiTaoTomSelectDon(select, placeholder);
        if (ts) {
            ts.setValue(selected ? String(selected) : '', true);
            if (disabled) ts.disable(); else ts.enable();
        } else {
            select.value = selected ? String(selected) : '';
        }
        return ts;
    }

    async function taiTinhThanhHeThong() {
        const cs = document.getElementById('ht-cs-tinh');
        const nv = document.getElementById('ht-nv-tinh');
        if (!cs && !nv) return;

        try {
            const res = await goiJson('/api/he_thong/dia_chi/tinh_thanh');
            dsTinhThanhHeThong = res.data || [];

            for (const select of [cs, nv].filter(Boolean)) {
                const current = select.tomselect
                    ? String(select.tomselect.getValue() || '')
                    : String(select.value || select.dataset.pendingValue || '');
                napOptionsSelect(
                    select.id,
                    dsTinhThanhHeThong.map(x => ({ value: x.ma || '', text: x.ten || x.ma || '' })),
                    '-- Chọn tỉnh / thành --',
                    current,
                    false
                );
            }
        } catch (e) {
            console.error('Không tải được tỉnh/thành:', e);
        }
    }

    async function taiPhuongXaHeThong(prefix, maTinh, selected = '') {
        const id = 'ht-' + prefix + '-phuong';
        const select = document.getElementById(id);
        if (!select) return;

        if (!maTinh) {
            napOptionsSelect(id, [], '-- Chọn phường / xã --', '', true);
            return;
        }

        try {
            const res = await goiJson('/api/he_thong/dia_chi/phuong_xa?ma_tinh=' + encodeURIComponent(maTinh));
            napOptionsSelect(
                id,
                (res.data || []).map(x => ({ value: x.ma || '', text: x.ten || x.ma || '' })),
                '-- Chọn phường / xã --',
                selected || '',
                false
            );
        } catch (e) {
            console.error('Không tải được phường/xã:', e);
        }
    }

    function urlTheoCskcb(url) {
        if (!isGlobalAdmin) return url;
        const sep = url.includes('?') ? '&' : '?';
        return url + sep + 'id_cskcb=' + encodeURIComponent(idCskcbQuanTri || 0);
    }

    function contextKey(selector) {
        return `${selector || ''}:${isGlobalAdmin ? (idCskcbQuanTri || 0) : 'tenant'}`;
    }

    async function taiTabKhiMo(selector) {
        if (!selector) return;
        const key = contextKey(selector);
        if (htLoadedTabs.has(key)) return;

        if (selector === '#ht-tab-tong-quan') {
            await taiTongQuanCskcb(false);
            htLoadedTabs.add(key);
            return;
        }

        if (pageMode === 'detail' && idCskcbQuanTri <= 0 && selector !== '#ht-tab-cskcb') {
            showToast('warning', 'Lưu cơ sở KCB trước.');
            return;
        }

        if (selector === '#ht-tab-cskcb') {
            await taiNganHangCskcb();
            if (pageMode === 'detail') {
                if (idCskcbQuanTri > 0) await taiChiTietCskcb();
                else resetFormCskcb();
            } else {
                await taiCskcb();
            }
            htLoadedTabs.add(key);
            return;
        }

        if (selector === '#ht-tab-nhan-vien') {
            await Promise.all([
                taiNhanVien(),
                taiChucDanhDropdown(),
                (!isGlobalAdmin || idCskcbQuanTri > 0) ? taiDanhSachNhanVien() : Promise.resolve()
            ]);
        } else if (selector === '#ht-tab-chuc-danh') {
            await taiChucDanh();
        } else if (selector === '#ht-tab-tai-khoan') {
            await taiTaiKhoan();
            if (!isGlobalAdmin || idCskcbQuanTri > 0) {
                await Promise.all([taiDanhSachNhanVien(), taiVaiTroLookup()]);
            }
        } else if (selector === '#ht-tab-vai-tro') {
            await taiVaiTro();
        } else if (selector === '#ht-tab-phan-quyen') {
            if (isGlobalAdmin && idCskcbQuanTri <= 0) {
                hienThiCanChonCskcb(selector);
                return;
            }
            await taiVaiTroLookup();
        }

        htLoadedTabs.add(key);
    }

    function hienThiCanChonCskcb(selector) {
        const messages = {
            '#ht-tab-nhan-vien': ['ht-nv-body', 10],
            '#ht-tab-chuc-danh': ['ht-cd-body', 6],
            '#ht-tab-tai-khoan': ['ht-tk-body', 8],
            '#ht-tab-vai-tro': ['ht-vt-body', 6],
            '#ht-tab-phan-quyen': ['ht-pq-body', 9]
        };
        const item = messages[selector];
        if (!item) return;
        const body = document.getElementById(item[0]);
        if (body) {
            body.innerHTML = `<tr><td colspan="${item[1]}" class="text-center text-muted py-4">
                <i class="bi bi-building me-1"></i>Chọn một cơ sở KCB ở tab Tổng quan để tải dữ liệu.
            </td></tr>`;
        }
    }

    async function taiDuLieuTenant() {
        const tasks = [taiDanhSachNhanVien(), taiVaiTroLookup(), taiVaiTro(), taiChucDanhDropdown()];
        if (document.getElementById('ht-nv-body')) tasks.push(taiNhanVien());
        await Promise.all(tasks);
        await taiTaiKhoan();
    }

    async function taiTongQuanCskcb(force = false) {
        const grid = document.getElementById('ht-overview-grid');
        if (!grid) return;

        const key = contextKey('#ht-tab-tong-quan');
        if (!force && htLoadedTabs.has(key) && dsCskcbTongQuan.length) {
            renderTongQuanCskcb();
            return;
        }

        const state = htPaging.ov;
        const q = document.getElementById('ht-overview-search')?.value?.trim() || '';
        const status = document.getElementById('ht-overview-status')?.value ?? '';
        const params = new URLSearchParams({
            trang: String(state.page),
            kich_thuoc_trang: '10'
        });
        if (q) params.set('q', q);
        if (status === '1') params.set('active', 'true');
        if (status === '0') params.set('active', 'false');

        try {
            grid.innerHTML = '<div class="text-center text-muted py-5 w-100"><span class="spinner-border spinner-border-sm me-2"></span>Đang tải cơ sở KCB...</div>';
            const res = await goiJson('/api/he_thong/cskcb?' + params.toString());
            dsCskcbTongQuan = res.data || [];
            state.total = tongSoDong(dsCskcbTongQuan);

            if (!dsCskcbTongQuan.length && state.page > 1) {
                state.page = 1;
                return taiTongQuanCskcb(true);
            }

            if (!state.pager) {
                state.pager = createQLPMPagination({
                    container: '#ht-overview-pagination',
                    itemName: 'cơ sở KCB',
                    pageSize: 10,
                    currentPage: state.page,
                    pageSizes: [10],
                    showCount: true,
                    compact: true,
                    onPageChange: newPage => {
                        state.page = newPage;
                        taiTongQuanCskcb(true);
                    }
                });
            }
            state.pager?.render(state.total, state.page);
            renderTongQuanCskcb();
            htLoadedTabs.add(key);
        } catch (e) {
            grid.innerHTML = '<div class="text-center text-danger py-5 w-100">Không tải được danh sách cơ sở KCB.</div>';
            showToast('error', 'Không tải được danh sách cơ sở KCB.');
        }
    }

    function renderTongQuanCskcb() {
        const grid = document.getElementById('ht-overview-grid');
        if (!grid) return;

        if (!dsCskcbTongQuan.length) {
            grid.innerHTML = '<div class="text-center text-muted py-5 w-100"><i class="bi bi-buildings fs-3 d-block mb-2"></i>Không có cơ sở KCB phù hợp bộ lọc.</div>';
            return;
        }

        grid.innerHTML = '';
        dsCskcbTongQuan.forEach(x => {
            const id = Number(x.IDCSKCB || 0);
            const selected = idCskcbQuanTri === id;
            const active = x.Active === true || x.Active === 1;
            const card = document.createElement('article');
            card.className = 'ht-cskcb-card' + (selected ? ' is-selected' : '');
            card.tabIndex = 0;
            card.innerHTML = `
                <div class="ht-cskcb-card-top">
                    <span class="badge ${active ? 'bg-success-subtle text-success border border-success-subtle' : 'bg-secondary-subtle text-secondary border'}">
                        <i class="bi ${active ? 'bi-circle-fill' : 'bi-pause-circle'} me-1"></i>${active ? 'Hoạt động' : 'Ngừng hoạt động'}
                    </span>
                    ${selected ? '<span class="badge bg-primary"><i class="bi bi-check2 me-1"></i>Đang thao tác</span>' : ''}
                </div>
                <div class="ht-cskcb-logo-wrap">
                    ${x.UrlLogo
                        ? '<img src="' + escapeHtml(x.UrlLogo) + '" alt="' + escapeHtml(x.TenCSKCB || 'Logo CSKCB') + '" class="ht-cskcb-logo" />'
                        : '<div class="ht-cskcb-logo-placeholder"><i class="bi bi-hospital"></i></div>'}
                </div>
                <div class="ht-cskcb-card-name" title="${escapeHtml(x.TenCSKCB || '')}">${escapeHtml(x.TenCSKCB || '')}</div>
                <div class="ht-cskcb-card-code">${escapeHtml(x.MaCSKCB || '')}</div>
                <div class="ht-cskcb-card-meta">
                    ${x.DiaChi ? '<div><i class="bi bi-geo-alt me-1"></i>' + escapeHtml(x.DiaChi) + '</div>' : ''}
                    ${x.SDT ? '<div><i class="bi bi-telephone me-1"></i>' + escapeHtml(x.SDT) + '</div>' : ''}
                </div>
                <div class="ht-cskcb-card-actions">
                    <button type="button" class="btn btn-sm ${selected ? 'btn-primary' : 'btn-outline-primary'} btn-overview-select">
                        <i class="bi ${selected ? 'bi-check2-circle' : 'bi-cursor-fill'} me-1"></i>${selected ? 'Đang chọn' : 'Chọn cơ sở'}
                    </button>
                    <button type="button" class="btn btn-sm btn-outline-secondary btn-overview-edit" title="Mở thông tin cơ sở">
                        <i class="bi bi-pencil"></i>
                    </button>
                </div>`;

            const select = () => chonCskcbQuanTri(x);
            card.querySelector('.btn-overview-select')?.addEventListener('click', e => { e.stopPropagation(); select(); });
            card.querySelector('.btn-overview-edit')?.addEventListener('click', e => {
                e.stopPropagation();
                chonCskcbQuanTri(x);
                ganFormCskcb(x);
                const tab = document.querySelector('[data-bs-target="#ht-tab-cskcb"]');
                if (tab && window.bootstrap?.Tab) bootstrap.Tab.getOrCreateInstance(tab).show();
            });
            card.addEventListener('click', select);
            card.addEventListener('keydown', e => {
                if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault();
                    select();
                }
            });
            grid.appendChild(card);
        });
    }

        async function chonCskcbQuanTri(x) {
        const id = Number(x?.IDCSKCB || 0);
        if (!id) return;

        const ten = (x.TenCSKCB || x.MaCSKCB || '').trim();
        try {
            const res = await goiJson('/api/he_thong/cskcb/chon_lam_viec', {
                method: 'POST',
                body: JSON.stringify({ id_cskcb: id })
            });
            if (res.status !== 200) {
                showToast('warning', res.message || 'Không chọn được cơ sở KCB.');
                return;
            }
        } catch (e) {
            showToast('error', 'Không chọn được cơ sở KCB.');
            return;
        }

        idCskcbQuanTri = id;
        tenCskcbQuanTri = ten;
        sessionStorage.setItem('qlpm_ht_cskcb', String(id));
        sessionStorage.setItem('qlpm_ht_cskcb_ten', tenCskcbQuanTri);
        ['nv','tk','vt'].forEach(k => {
            htPaging[k].page = 1;
            htPaging[k].total = 0;
        });
        htLoadedTabs.clear();
        htLoadedTabs.add(contextKey('#ht-tab-tong-quan'));
        resetFormNhanVien();
        resetFormTaiKhoan();
        resetFormVaiTro();
        if (tsPhanQuyenVaiTro) tsPhanQuyenVaiTro.clear(true);
        capNhatNguCanhUi();
        renderTongQuanCskcb();
        showToast('success', 'Đang thao tác tại ' + tenCskcbQuanTri + '.');
    }

    function datNguCanhTuDong(x) {
        if (pageMode === 'detail') return false;
        if (!isGlobalAdmin) return false;
        const id = Number(x?.IDCSKCB || 0);
        if (!id || id === idCskcbQuanTri) return false;

        idCskcbQuanTri = id;
        tenCskcbQuanTri = (x.TenCSKCB || x.MaCSKCB || ('CSKCB #' + id)).trim();
        sessionStorage.setItem('qlpm_ht_cskcb', String(id));
        sessionStorage.setItem('qlpm_ht_cskcb_ten', tenCskcbQuanTri);
        htLoadedTabs.clear();
        capNhatNguCanhUi();
        renderTongQuanCskcb();
        return true;
    }

    function capNhatNguCanhUi() {
        const wrap = document.getElementById('ht-admin-context');
        const name = document.getElementById('ht-admin-context-name');
        const hasContext = isGlobalAdmin && idCskcbQuanTri > 0;
        wrap?.classList.toggle('d-none', !hasContext);
        if (name) name.textContent = tenCskcbQuanTri || ('CSKCB #' + idCskcbQuanTri);
    }

    function huyLogoFileChoLuu() {
        logoFileChoLuu = null;
        if (logoObjectUrl) {
            URL.revokeObjectURL(logoObjectUrl);
            logoObjectUrl = null;
        }
    }

    function xemTruocLogoFile(file) {
        const allowed = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
        if (!allowed.includes(file.type)) {
            showToast('warning', 'Chỉ hỗ trợ JPG, PNG, WEBP hoặc GIF.');
            return;
        }
        if (file.size > 5 * 1024 * 1024) {
            showToast('warning', 'Hình ảnh tối đa 5 MB.');
            return;
        }

        huyLogoFileChoLuu();
        logoFileChoLuu = file;
        logoObjectUrl = URL.createObjectURL(file);

        const target = document.getElementById('ht-cs-url-logo');
        const preview = document.getElementById('ht-cs-logo-preview');
        const wrap = document.getElementById('ht-cs-logo-preview-wrap');
        const text = document.getElementById('ht-cs-logo-text');
        const link = document.getElementById('ht-cs-logo-link');

        // Giữ URL ảnh hiện tại cho tới khi upload file mới thành công.
        // Nhờ vậy nếu upload lỗi, ảnh cũ vẫn còn nguyên trong DB và trên server.
        if (preview) preview.src = logoObjectUrl;
        wrap?.classList.remove('d-none');
        document.getElementById('ht-cs-image-dropzone')?.classList.add('has-image');
        if (text) text.textContent = file.name;
        if (link) link.value = '';
    }

    function capNhatLogoCskcb(url) {
        const value = (url || '').trim();
        const target = document.getElementById('ht-cs-url-logo');
        const text = document.getElementById('ht-cs-logo-text');
        const link = document.getElementById('ht-cs-logo-link');
        const preview = document.getElementById('ht-cs-logo-preview');
        const wrap = document.getElementById('ht-cs-logo-preview-wrap');

        if (target) target.value = value;
        if (text) text.textContent = value ? value.split('/').pop() || 'Đã chọn hình ảnh' : '';
        if (link) link.value = value.startsWith('http://') || value.startsWith('https://') ? value : '';

        const dropzone = document.getElementById('ht-cs-image-dropzone');
        if (value) {
            if (preview) preview.src = value;
            wrap?.classList.remove('d-none');
            dropzone?.classList.add('has-image');
        } else {
            preview?.removeAttribute('src');
            wrap?.classList.add('d-none');
            dropzone?.classList.remove('has-image');
        }
    }

    async function taiLogoCskcb(file, idCskcb) {
        if (!file || idCskcb <= 0) return null;

        const formData = new FormData();
        formData.append('id_cskcb', String(idCskcb));
        formData.append('file', file);
        const response = await fetch('/api/he_thong/cskcb/logo', {
            method: 'POST',
            credentials: 'same-origin',
            body: formData
        });
        if (response.status === 401) {
            window.location.href = '/xac_thuc/dang_nhap?return_url=' + encodeURIComponent(location.pathname + location.search);
            return null;
        }
        if (response.status === 403) throw new Error('Bạn không có quyền tải logo.');

        const res = await response.json();
        if (res.status !== 200) throw new Error(res.message || 'Không tải được hình ảnh.');
        return res;
    }

    async function taiChiTietCskcb() {
        if (idCskcbQuanTri <= 0) return;
        const res = await goiJson('/api/he_thong/cskcb/' + encodeURIComponent(idCskcbQuanTri));
        if (res.status !== 200 || !res.data) throw new Error(res.message || 'Không tải được thông tin cơ sở KCB.');

        huyLogoFileChoLuu();
        await ganFormCskcb(res.data);
        tenCskcbQuanTri = (res.data.TenCSKCB || '').trim();

        const title = document.getElementById('ht-detail-title');
        const code = document.getElementById('ht-detail-code');
        if (title) title.textContent = tenCskcbQuanTri || 'Cơ sở KCB';
        if (code) code.textContent = res.data.MaCSKCB || '';
    }

    function tongSoDong(rows) {
        return Array.isArray(rows) && rows.length
            ? Number(rows[0].TongSoDong ?? rows[0].tong_so_dong ?? rows.length)
            : 0;
    }

    function damBaoPhanTrang(key, container, itemName, loader) {
        const state = htPaging[key];
        if (state.pager) return state.pager;
        state.pager = createQLPMPagination({
            container,
            itemName,
            pageSize: state.size,
            currentPage: state.page,
            pageSizes: [10, 25, 50, 100],
            showCount: true,
            compact: true,
            onPageChange: (newPage, newSize) => {
                state.page = newPage;
                state.size = newSize;
                loader();
            }
        });
        return state.pager;
    }

    async function taiNganHangCskcb() {
        const select = document.getElementById('ht-cs-ngan-hang');
        if (!select) return;
        try {
            const res = await goiJson(isGlobalAdmin ? '/api/danh_muc/ngan_hang?top=1000&id_cskcb=0' : '/api/danh_muc/ngan_hang?top=1000');
            const current = select.dataset.pendingValue
                || (select.tomselect ? String(select.tomselect.getValue() || '') : String(select.value || ''));
            napOptionsSelect(
                'ht-cs-ngan-hang',
                (res.data || []).map(x => ({
                    value: String(x.id),
                    text: (x.ma ? x.ma + ' - ' : '') + (x.ten || '')
                })),
                '-- Không chọn --',
                current,
                false
            );
        } catch (e) {
            console.error('Không tải được danh mục ngân hàng:', e);
        }
    }

    async function taiCskcb(silent = false) {
        const body = document.getElementById('ht-cs-body');
        if (!body) return;
        const state = htPaging.cs;
        try {
            const q = layTuKhoaTimKiemQuanTri('cs', 'ht-cs-filter');
            const url = '/api/he_thong/cskcb?trang=' + state.page + '&kich_thuoc_trang=' + state.size + (q ? '&q=' + encodeURIComponent(q) : '');
            const res = silent ? await goiJson(url) : await withPageloader(() => goiJson(url));
            dsCskcb = res.data || [];
            state.total = tongSoDong(dsCskcb);

            if (!dsCskcb.length && state.page > 1) {
                state.page = 1;
                return taiCskcb();
            }

            const pager = damBaoPhanTrang('cs', '#ht-cs-pagination', 'cơ sở KCB', taiCskcb);
            if (pager) {
                pager.render(state.total, state.page);
                state.page = pager.getCurrentPage();
                state.size = pager.getPageSize();
            }

            renderCskcb();
        } catch (e) {
            body.innerHTML = '<tr><td colspan="6" class="text-center text-danger">Không tải được danh sách CSKCB.</td></tr>';
            showToast('error', 'Không thực hiện được thao tác.');
        }
    }

        function renderCskcb() {
        const body = document.getElementById('ht-cs-body');
        if (!body) return;
        body.innerHTML = '';
        const state = htPaging.cs;
        dsCskcb.forEach((x, index) => {
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td class="ht-col-stt text-center">${sttNguoc(state, index)}</td>
                <td class="fw-semibold">${escapeHtml(x.MaCSKCB || '')}</td>
                <td class="ht-sticky-name ht-col-name fw-semibold">${escapeHtml(x.TenCSKCB || '')}</td>
                <td class="text-truncate" style="min-width:220px;max-width:320px;" title="${escapeHtml(x.DiaChi || '')}">${escapeHtml(x.DiaChi || '') || '-'}</td>
                <td class="text-nowrap">${escapeHtml(x.SDT || '') || '-'}</td>
                <td class="text-nowrap">${escapeHtml(x.Email || '') || '-'}</td>
                <td class="text-nowrap">${escapeHtml(x.MaST || '') || '-'}</td>
                <td class="text-nowrap">${escapeHtml(x.TenNganHang || '') || '-'}</td>
                <td class="text-nowrap">${escapeHtml(x.SoTK || '') || '-'}</td>
                <td class="text-center">${x.Active ? '<span class="badge bg-success">Hoạt động</span>' : '<span class="badge bg-secondary">Ngừng</span>'}</td>
                <td class="text-center text-nowrap ht-sticky-action ht-action-col">
                    <button type="button" class="btn btn-sm btn-light border py-0 px-2 btn-cs-menu" title="Tùy chọn"><i class="bi bi-list"></i></button>
                </td>`;
            tr.querySelector('.btn-cs-menu')?.addEventListener('click', e => {
                e.stopPropagation();
                moMenuTuyChon(e.currentTarget, [
                    { id: 'edit', label: 'Sửa', icon: 'bi-pencil', iconClass: 'text-primary', run: () => ganFormCskcb(x, true) },
                    ...(canDeleteCskcb ? [{ id: 'delete', label: 'Xóa', icon: 'bi-trash', danger: true, dividerBefore: true, run: () => xoaCskcb(x) }] : [])
                ]);
            });
            ganSuKienXemDong(tr, () => ganFormCskcb(x, false));
            body.appendChild(tr);
        });
        if (!dsCskcb.length) body.innerHTML = '<tr><td colspan="11" class="text-center text-muted">Chưa có cơ sở KCB.</td></tr>';
    }

    async function ganFormCskcb(x, choSua = true) {
        huyLogoFileChoLuu();
        document.getElementById('ht-cs-id').value = x.IDCSKCB || '';
        document.getElementById('ht-cs-ma').value = x.MaCSKCB || '';
        document.getElementById('ht-cs-ten').value = x.TenCSKCB || '';
        document.getElementById('ht-cs-so-nha').value = x.SoNhaTenDuong || '';
        document.getElementById('ht-cs-sdt').value = chiLaySo(x.SDT || '', 10);
        datGiaTriSelect('ht-cs-tinh', x.MaTinh || '');
        await taiPhuongXaHeThong('cs', x.MaTinh || '', x.MaPhuongXa || '');
        document.getElementById('ht-cs-email').value = x.Email || '';
        document.getElementById('ht-cs-ma-st').value = x.MaST || '';
        document.getElementById('ht-cs-so-tk').value = x.SoTK || '';
        capNhatLogoCskcb(x.UrlLogo || '');
        const nganHang = document.getElementById('ht-cs-ngan-hang');
        if (nganHang) {
            nganHang.dataset.pendingValue = x.IDNganHang ? String(x.IDNganHang) : '';
            datGiaTriSelect('ht-cs-ngan-hang', nganHang.dataset.pendingValue);
        }
        document.getElementById('ht-cs-active').checked = x.Active === true || x.Active === 1;
        datCheDoCskcb(choSua);
        document.dispatchEvent(new CustomEvent('ht:cs-form', { detail:{ id:Number(x.IDCSKCB || 0), editable:choSua } }));
    }

    function resetFormCskcb() {
        huyLogoFileChoLuu();
        ['ht-cs-id','ht-cs-ma','ht-cs-ten','ht-cs-so-nha','ht-cs-sdt','ht-cs-email','ht-cs-ma-st','ht-cs-so-tk']
            .forEach(id => { const el = document.getElementById(id); if (el) el.value = ''; });
        capNhatLogoCskcb('');
        datGiaTriSelect('ht-cs-tinh', '');
        napOptionsSelect('ht-cs-phuong', [], '-- Chọn phường / xã --', '', true);
        const nganHang = document.getElementById('ht-cs-ngan-hang');
        if (nganHang) {
            datGiaTriSelect('ht-cs-ngan-hang', '');
            delete nganHang.dataset.pendingValue;
        }
        const active = document.getElementById('ht-cs-active');
        if (active) active.checked = true;
        datCheDoCskcb(true);
        document.dispatchEvent(new CustomEvent('ht:cs-form', { detail:{ id:0, editable:false } }));
    }

    async function luuCskcb() {
        const button = document.getElementById('btn-ht-cs-luu');
        if (button?.dataset.saving === '1') return;

        const payload = {
            id_cskcb: Number(document.getElementById('ht-cs-id')?.value || 0) || null,
            ma_cskcb: document.getElementById('ht-cs-ma')?.value?.trim() || '',
            ten_cskcb: document.getElementById('ht-cs-ten')?.value?.trim() || '',
            so_nha_ten_duong: document.getElementById('ht-cs-so-nha')?.value?.trim() || null,
            ma_tinh: layGiaTriSelect('ht-cs-tinh') || null,
            ma_phuong_xa: layGiaTriSelect('ht-cs-phuong') || null,
            sdt: chiLaySo(document.getElementById('ht-cs-sdt')?.value || '', 10) || null,
            email: document.getElementById('ht-cs-email')?.value?.trim() || null,
            ma_st: document.getElementById('ht-cs-ma-st')?.value?.trim() || null,
            so_tk: document.getElementById('ht-cs-so-tk')?.value?.trim() || null,
            id_ngan_hang: Number(document.getElementById('ht-cs-ngan-hang')?.value || 0) || null,
            url_logo: document.getElementById('ht-cs-url-logo')?.value?.trim() || null,
            active: document.getElementById('ht-cs-active')?.checked !== false
        };

        if (!payload.ma_cskcb || !payload.ten_cskcb) {
            showToast('warning', 'Nhập mã và tên cơ sở KCB.');
            return;
        }
        try {
            window.qlpmLienThongTaiKhoan?.kiemTraCskcb?.();
        } catch (error) {
            showToast('warning', error.message || 'Kiểm tra tài khoản liên thông.');
            return;
        }

        if (button) {
            button.dataset.saving = '1';
            button.disabled = true;
        }
        let daLuuCoSo = false;
        try {
            const res = await goiJson('/api/he_thong/cskcb/luu', {
                method: 'POST',
                body: JSON.stringify(payload)
            });
            if (res.status !== 200) {
                showToast('error', res.message || 'Không lưu được cơ sở KCB.');
                return;
            }
            daLuuCoSo = true;

            const idMoi = Number(res.data?.IDCSKCB || payload.id_cskcb || 0);
            if (idMoi <= 0) throw new Error('Không nhận được mã cơ sở KCB đã lưu.');
            idCskcbQuanTri = idMoi;
            const idInput = document.getElementById('ht-cs-id');
            if (idInput) idInput.value = String(idMoi);
            if (pageMode === 'detail' && !payload.id_cskcb)
                history.replaceState(null, '', '/he_thong/cskcb/' + idMoi);

            await window.qlpmLienThongTaiKhoan?.luuCskcb?.(idMoi);

            if (logoFileChoLuu) {
                const upload = await taiLogoCskcb(logoFileChoLuu, idMoi);
                if (!upload) return;
            }

            huyLogoFileChoLuu();
            if (pageMode === 'detail') {
                const path = '/he_thong/cskcb/' + idMoi;
                sessionStorage.setItem('qlpm_ht_cskcb_save_toast', JSON.stringify({
                    path,
                    message: 'Đã lưu cơ sở KCB và tài khoản liên thông.',
                    createdAt: Date.now()
                }));
                window.location.href = path;
                return;
            }

            showToast('success', 'Đã lưu cơ sở KCB và tài khoản liên thông.');
            resetFormCskcb();
            await taiCskcb();
        } catch (error) {
            const prefix = daLuuCoSo ? 'Đã lưu cơ sở KCB nhưng chưa hoàn tất phần liên thông hoặc logo: ' : 'Không lưu được cơ sở KCB: ';
            showToast('error', prefix + (error.message || 'Lỗi không xác định.'));
        } finally {
            if (button) {
                delete button.dataset.saving;
                button.disabled = false;
            }
        }
    }

    async function xoaCskcb(x) {
        const ok = await hien_thi_xac_nhan({
            tieu_de: 'Xóa cơ sở KCB',
            noi_dung: `XÓA TOÀN BỘ "${x.TenCSKCB || x.MaCSKCB}"? Toàn bộ dữ liệu nghiệp vụ, danh mục, tài khoản, file CLS và cache của cơ sở sẽ bị xóa vĩnh viễn.`,
            nhan_dong_y: 'XÓA TOÀN BỘ',
            lop_nut: 'btn-danger'
        });
        if (!ok) return;
        try {
            const res = await goiJson('/api/he_thong/cskcb/xoa', { method: 'POST', body: JSON.stringify({ id_cskcb: x.IDCSKCB }) });
            const daXoaDb = res.status === 200 || res.status === 207;
            showToast(res.status === 200 ? 'success' : (res.status === 207 ? 'warning' : 'error'), res.message);
            if (daXoaDb) {
                if (res.data?.dang_xuat) {
                    window.location.href = '/xac_thuc/dang_nhap';
                    return;
                }
                resetFormCskcb();
                if (pageMode === 'detail') {
                    window.location.href = '/he_thong';
                    return;
                }
                await taiCskcb();
                if (isGlobalAdmin) {
                    if (idCskcbQuanTri === Number(x.IDCSKCB)) {
                        idCskcbQuanTri = 0;
                        tenCskcbQuanTri = '';
                        sessionStorage.removeItem('qlpm_ht_cskcb');
                        sessionStorage.removeItem('qlpm_ht_cskcb_ten');
                        capNhatNguCanhUi();
                    }
                    htLoadedTabs.clear();
                    await taiTongQuanCskcb(true);
                }
            }
        } catch (e) { showToast('error', 'Không thực hiện được thao tác.'); }
    }

    async function taiNhanVien(silent = false) {
        const body = document.getElementById('ht-nv-body');
        if (!body) return;
        const state = htPaging.nv;

        try {
            const q = layTuKhoaTimKiemQuanTri('nv', 'ht-nv-filter');
            const url = '/api/he_thong/nhan_vien?trang=' + state.page + '&kich_thuoc_trang=' + state.size + (q ? '&q=' + encodeURIComponent(q) : '');
            const res = silent ? await goiJson(urlTheoCskcb(url)) : await withPageloader(() => goiJson(urlTheoCskcb(url)));
            dsNhanVien = res.data || [];
            state.total = tongSoDong(dsNhanVien);

            if (!dsNhanVien.length && state.page > 1) {
                state.page = 1;
                return taiNhanVien();
            }

            const pager = damBaoPhanTrang('nv', '#ht-nv-pagination', 'nhân viên', taiNhanVien);
            if (pager) {
                pager.render(state.total, state.page);
                state.page = pager.getCurrentPage();
                state.size = pager.getPageSize();
            }

            renderNhanVien();
        } catch (e) {
            showToast('error', 'Không thực hiện được thao tác.');
        }
    }

        function renderNhanVien() {
        const body = document.getElementById('ht-nv-body');
        if (!body) return;
        const detail = pageMode === 'detail';
        const state = htPaging.nv;
        if (!dsNhanVien.length) {
            body.innerHTML = '<tr><td colspan="' + (detail ? 10 : 11) + '" class="text-center text-muted py-3">Chưa có nhân viên.</td></tr>';
            return;
        }
        body.innerHTML = '';
        dsNhanVien.forEach((x, index) => {
            const tr = document.createElement('tr');
            const active = x.Active === true || x.Active === 1;
            const laBacSi = x.LaBacSi === true || x.LaBacSi === 1;
            const daCoTaiKhoan = x.DaCoTaiKhoan === true || x.DaCoTaiKhoan === 1;
            tr.innerHTML = `
                <td class="ht-col-stt text-center">${sttNguoc(state, index)}</td>
                ${detail ? '' : '<td>' + escapeHtml(x.TenCSKCB || '') + '</td>'}
                <td class="ht-sticky-name ht-col-name"><strong>${escapeHtml(x.HoTen || '')}</strong></td>
                <td>${escapeHtml(x.ChucDanh || '')}</td>
                <td class="text-nowrap">${escapeHtml(x.DienThoai || '') || '-'}</td>
                <td class="text-nowrap">${escapeHtml(x.Email || '') || '-'}</td>
                <td class="text-center">${laBacSi ? '<i class="bi bi-check-circle-fill text-success"></i>' : '-'}</td>
                <td>${daCoTaiKhoan ? '<span class="badge bg-primary-subtle text-primary border">' + escapeHtml(x.Ten_Dang_Nhap || 'Đã có') + '</span>' : '<span class="text-muted">Chưa có</span>'}</td>
                <td class="ht-col-code fw-semibold">${escapeHtml(x.MaNhanVien || '')}</td>
                <td class="text-center"><span class="badge ${active ? 'bg-success' : 'bg-secondary'}">${active ? 'Hoạt động' : 'Ngừng'}</span></td>
                <td class="text-center text-nowrap ht-sticky-action ht-action-col">
                    <button type="button" class="btn btn-sm btn-light border py-0 px-2 btn-nv-menu" title="Tùy chọn"><i class="bi bi-list"></i></button>
                </td>`;
            tr.querySelector('.btn-nv-menu')?.addEventListener('click', e => {
                e.stopPropagation();
                moMenuTuyChon(e.currentTarget, [
                    { id: 'edit', label: 'Sửa nhân viên', icon: 'bi-pencil', iconClass: 'text-primary', run: () => suaNhanVien(x, true) },
                    ...(canDeleteNv ? [{ id: 'delete', label: 'Gỡ khỏi cơ sở', icon: 'bi-trash', danger: true, dividerBefore: true, run: () => { datNguCanhTuDong(x); return xoaNhanVien(x); } }] : [])
                ]);
            });
            ganSuKienXemDong(tr, () => suaNhanVien(x, false));
            body.appendChild(tr);
        });
    }

    async function suaNhanVien(x, choSua = true) {
        datNguCanhTuDong(x);
        document.getElementById('ht-nv-id').value = x.IDNhanVien || '';
        document.getElementById('ht-nv-ma').value = x.MaNhanVien || '';
        document.getElementById('ht-nv-ho-ten').value = x.HoTen || '';
        const idChucDanh = x.IDChucDanh ? String(x.IDChucDanh) : '';
        if (tsNhanVienChucDanh) {
            tsNhanVienChucDanh.setValue(idChucDanh, true);
        } else {
            const selectChucDanh = document.getElementById('ht-nv-chuc-danh');
            if (selectChucDanh) selectChucDanh.value = idChucDanh;
        }

        document.getElementById('ht-nv-dien-thoai').value = chiLaySo(x.DienThoai || '', 10);
        document.getElementById('ht-nv-email').value = x.Email || '';
        document.getElementById('ht-nv-so-nha').value = x.SoNhaTenDuong || '';
        datGiaTriSelect('ht-nv-tinh', x.MaTinh || '');
        await taiPhuongXaHeThong('nv', x.MaTinh || '', x.MaPhuongXa || '');
        document.getElementById('ht-nv-la-bac-si').checked = x.LaBacSi === true || x.LaBacSi === 1;
        document.getElementById('ht-nv-active').checked = x.Active === true || x.Active === 1;
        datCheDoNhanVien(choSua);
        duaFormVaoTamNhin('ht-nv-ma');
        document.dispatchEvent(new CustomEvent('ht:nv-form', { detail:{ id:Number(x.IDNhanVien || 0), tenant:idCskcbQuanTri, doctor:!!document.getElementById('ht-nv-la-bac-si').checked, editable:choSua } }));
    }

        function resetFormNhanVien() {
        ['ht-nv-id','ht-nv-ma','ht-nv-ho-ten','ht-nv-dien-thoai','ht-nv-so-nha','ht-nv-email'].forEach(id => {
            const el = document.getElementById(id);
            if (el) el.value = '';
        });
        tsNhanVienChucDanh?.clear(true);
        if (!tsNhanVienChucDanh) {
            const chucDanh = document.getElementById('ht-nv-chuc-danh');
            if (chucDanh) chucDanh.value = '';
        }
        datGiaTriSelect('ht-nv-tinh', '');
        napOptionsSelect('ht-nv-phuong', [], '-- Chọn phường / xã --', '', true);
        const laBacSi = document.getElementById('ht-nv-la-bac-si');
        const active = document.getElementById('ht-nv-active');
        if (laBacSi) laBacSi.checked = false;
        if (active) active.checked = true;
        document.querySelectorAll('#ht-nv-body tr.selected, #ht-nv-body tr.table-active').forEach(x => x.classList.remove('selected', 'table-active'));
        datCheDoNhanVien(true);
        document.dispatchEvent(new CustomEvent('ht:nv-form', { detail:{ id:0, tenant:idCskcbQuanTri, doctor:false, editable:false } }));
    }

        async function luuNhanVien() {
        if (isGlobalAdmin && idCskcbQuanTri <= 0) { showToast('warning', 'Chọn cơ sở KCB trước.'); return; }
        const payload = {
            id_nhan_vien: Number(document.getElementById('ht-nv-id')?.value || 0) || null,
            ma_nhan_vien: document.getElementById('ht-nv-ma')?.value?.trim() || '',
            ho_ten: document.getElementById('ht-nv-ho-ten')?.value?.trim() || '',
            la_bac_si: document.getElementById('ht-nv-la-bac-si')?.checked === true,
            id_chuc_danh: Number(tsNhanVienChucDanh?.getValue() || document.getElementById('ht-nv-chuc-danh')?.value || 0) || null,
            chuc_danh: (() => {
                const id = String(tsNhanVienChucDanh?.getValue() || document.getElementById('ht-nv-chuc-danh')?.value || '');
                const item = dsChucDanhLookup.find(x => String(x.id) === id);
                return item?.ten || null;
            })(),
            dien_thoai: chiLaySo(document.getElementById('ht-nv-dien-thoai')?.value || '', 10) || null,
            so_nha_ten_duong: document.getElementById('ht-nv-so-nha')?.value?.trim() || null,
            ma_tinh: layGiaTriSelect('ht-nv-tinh') || null,
            ma_phuong_xa: layGiaTriSelect('ht-nv-phuong') || null,
            email: document.getElementById('ht-nv-email')?.value?.trim() || null,
            active: document.getElementById('ht-nv-active')?.checked !== false
        };
        if (!payload.ma_nhan_vien || !payload.ho_ten) { showToast('warning', 'Nhập mã nhân viên và họ tên.'); return; }

        const laThemMoi = !payload.id_nhan_vien;
        try {
            if (payload.la_bac_si) window.qlpmLienThongTaiKhoan?.kiemTraNhanVien?.();
        } catch (error) {
            showToast('warning', error.message || 'Kiểm tra tài khoản liên thông bác sĩ.');
            return;
        }

        const button = document.getElementById('btn-ht-nv-luu');
        if (button?.dataset.saving === '1') return;
        if (button) { button.dataset.saving = '1'; button.disabled = true; }
        let daLuuNhanVien = false;
        try {
            const res = await goiJson(urlTheoCskcb('/api/he_thong/nhan_vien/luu'), { method: 'POST', body: JSON.stringify(payload) });
            if (res.status !== 200) {
                showToast('error', res.message || 'Không lưu được nhân viên.');
                return;
            }
            daLuuNhanVien = true;
            if (payload.la_bac_si) {
                const idMoi = Number(res.data?.IDNhanVien || payload.id_nhan_vien || 0);
                if (idMoi <= 0) throw new Error('Không nhận được mã nhân viên đã lưu.');
                await window.qlpmLienThongTaiKhoan?.luuNhanVien?.(idMoi, idCskcbQuanTri);
            }
            showToast('success', res.message || 'Đã lưu nhân viên và tài khoản liên thông.');
            resetFormNhanVien();
            if (laThemMoi) htPaging.nv.page = 1;
            await taiNhanVien();
        } catch (error) {
            const prefix = daLuuNhanVien ? 'Đã lưu nhân viên nhưng chưa lưu được tài khoản liên thông: ' : 'Không lưu được nhân viên: ';
            showToast('error', prefix + (error.message || 'Lỗi không xác định.'));
        } finally {
            if (button) { delete button.dataset.saving; button.disabled = false; }
        }
    }


    async function xoaNhanVien(x) {
        const ok = await hien_thi_xac_nhan({
            tieu_de: 'Gỡ nhân viên khỏi cơ sở',
            noi_dung: `Gỡ nhân viên "${x.HoTen || x.MaNhanVien}" khỏi cơ sở đang quản lý? Tài khoản tại cơ sở này sẽ bị xóa; dữ liệu khám lịch sử vẫn được giữ nguyên.`,
            nhan_dong_y: 'GỠ KHỎI CƠ SỞ',
            lop_nut: 'btn-danger'
        });
        if (!ok) return;
        try {
            const res = await goiJson(urlTheoCskcb('/api/he_thong/nhan_vien/xoa'), { method: 'POST', body: JSON.stringify({ id_nhan_vien: x.IDNhanVien }) });
            showToast(res.status === 200 ? 'success' : 'error', res.message);
            if (res.status === 200) {
                resetFormNhanVien();
                await Promise.all([taiNhanVien(), taiDanhSachNhanVien(), taiTaiKhoan()]);
            }
        } catch (e) { showToast('error', 'Không thực hiện được thao tác.'); }
    }

    async function taiDanhSachNhanVien() {
        const select = document.getElementById('ht-tk-nhan-vien');
        if (!select) return;

        tsNhanVien?.destroy();
        select.innerHTML = '<option value="">-- Chọn nhân viên --</option>';

        tsNhanVien = new TomSelect(select, {
            valueField: 'id',
            labelField: 'text',
            searchField: ['text', 'viet_tat'],
            create: false,
            allowEmptyOption: true,
            preload: true,
            loadThrottle: 250,
            score: window.tomSelectVietTatScore,
            load: async (query, callback) => {
                try {
                    const res = await goiJson(urlTheoCskcb('/api/he_thong/nhan_vien_lookup?q=' + encodeURIComponent(query || '') + '&top=100'));
                    const options = (res.data || [])
                        .filter(x => x.Active === true || x.Active === 1)
                        .map(x => ({
                            id: String(x.IDNhanVien),
                            text: (x.MaNhanVien ? x.MaNhanVien + ' - ' : '') + (x.HoTen || ''),
                            ho_ten: x.HoTen || '',
                            viet_tat: window.taoKyTuVietTat?.(x.HoTen || '') || ''
                        }));
                    callback(options);
                } catch {
                    callback();
                }
            }
        });
    }

    async function taiChucDanhDropdown() {
        const select = document.getElementById('ht-nv-chuc-danh');
        if (!select) return;
        try {
            const res = await goiJson('/api/danh_muc/chuc_danh?top=100');
            dsChucDanhLookup = res.data || [];
            const current = tsNhanVienChucDanh
                ? String(tsNhanVienChucDanh.getValue() || '')
                : String(select.value || '');

            tsNhanVienChucDanh?.destroy();
            select.innerHTML = '<option value="">-- Chọn chức danh --</option>'
                + dsChucDanhLookup.map(x => {
                    const label = x.viet_tat ? `${x.viet_tat} - ${x.ten || ''}` : (x.ten || '');
                    return `<option value="${escapeHtml(String(x.id || ''))}">${escapeHtml(label)}</option>`;
                }).join('');

            tsNhanVienChucDanh = new TomSelect(select, {
                create: false,
                maxItems: 1,
                allowEmptyOption: true,
                valueField: 'value',
                searchField: ['text'],
                placeholder: '-- Chọn chức danh --',
                score: window.tomSelectVietTatScore
            });
            tsNhanVienChucDanh.control_input?.setAttribute('autocomplete', 'off');
            tsNhanVienChucDanh.control_input?.setAttribute('data-lpignore', 'true');
            tsNhanVienChucDanh.control_input?.setAttribute('data-1p-ignore', 'true');
            if (current && tsNhanVienChucDanh.options[current])
                tsNhanVienChucDanh.setValue(current, true);
        } catch {
            dsChucDanhLookup = [];
            showToast('error', 'Không tải được danh mục chức danh JSON.');
        }
    }

    async function taiVaiTroLookup() {
        try {
            const res = await goiJson(urlTheoCskcb('/api/he_thong/vai_tro_lookup?top=100'));
            dsVaiTroLookup = res.data || [];
            khoiTaoSelectVaiTro();
        } catch (e) {
            showToast('error', 'Không thực hiện được thao tác.');
        }
    }

    async function taiVaiTro(silent = false) {
        const state = htPaging.vt;
        try {
            const q = layTuKhoaTimKiemQuanTri('vt', 'ht-vt-filter');
            const url = '/api/he_thong/vai_tro?trang=' + state.page + '&kich_thuoc_trang=' + state.size + (q ? '&q=' + encodeURIComponent(q) : '');
            const res = silent ? await goiJson(urlTheoCskcb(url)) : await withPageloader(() => goiJson(urlTheoCskcb(url)));
            dsVaiTro = res.data || [];
            state.total = tongSoDong(dsVaiTro);

            if (!dsVaiTro.length && state.page > 1) {
                state.page = 1;
                return taiVaiTro();
            }

            const pager = damBaoPhanTrang('vt', '#ht-vt-pagination', 'vai trò', taiVaiTro);
            if (pager) {
                pager.render(state.total, state.page);
                state.page = pager.getCurrentPage();
                state.size = pager.getPageSize();
            }

            renderVaiTro();
        } catch (e) {
            showToast('error', 'Không thực hiện được thao tác.');
        }
    }

    function khoiTaoSelectVaiTro() {
        const tk = document.getElementById('ht-tk-vai-tro');
        const pq = document.getElementById('ht-pq-vai-tro');
        const active = dsVaiTroLookup.filter(x => x.Active === true || x.Active === 1);

        if (tk) {
            tk.innerHTML = active.map(x => `<option value="${x.ID_Vai_Tro}">${escapeHtml(x.Ten_Vai_Tro || '')}</option>`).join('');
            tsTaiKhoanVaiTro?.destroy();
            tsTaiKhoanVaiTro = new TomSelect(tk, { plugins: ['remove_button'], create: false, score: window.tomSelectVietTatScore });
            tsTaiKhoanVaiTro.control_input?.setAttribute('autocomplete', 'off');
            tsTaiKhoanVaiTro.control_input?.setAttribute('data-lpignore', 'true');
            tsTaiKhoanVaiTro.control_input?.setAttribute('data-1p-ignore', 'true');
        }

        if (pq) {
            pq.innerHTML = '<option value="">-- Chọn vai trò --</option>' + active.map(x => `<option value="${x.ID_Vai_Tro}">${escapeHtml(x.Ten_Vai_Tro || '')}</option>`).join('');
            tsPhanQuyenVaiTro?.destroy();
            tsPhanQuyenVaiTro = new TomSelect(pq, { create: false, allowEmptyOption: true, score: window.tomSelectVietTatScore });
            tsPhanQuyenVaiTro.control_input?.setAttribute('autocomplete', 'off');
            tsPhanQuyenVaiTro.control_input?.setAttribute('data-lpignore', 'true');
            tsPhanQuyenVaiTro.control_input?.setAttribute('data-1p-ignore', 'true');
            tsPhanQuyenVaiTro.on('change', value => taiPhanQuyen(value));
        }
    }

    async function taiTaiKhoan(silent = false) {
        const state = htPaging.tk;
        try {
            const q = layTuKhoaTimKiemQuanTri('tk', 'ht-tk-filter');
            const url = '/api/he_thong/tai_khoan?trang=' + state.page + '&kich_thuoc_trang=' + state.size + (q ? '&q=' + encodeURIComponent(q) : '');
            const res = silent ? await goiJson(urlTheoCskcb(url)) : await withPageloader(() => goiJson(urlTheoCskcb(url)));
            dsTaiKhoan = res.data || [];
            state.total = tongSoDong(dsTaiKhoan);

            if (!dsTaiKhoan.length && state.page > 1) {
                state.page = 1;
                return taiTaiKhoan();
            }

            const pager = damBaoPhanTrang('tk', '#ht-tk-pagination', 'tài khoản', taiTaiKhoan);
            if (pager) {
                pager.render(state.total, state.page);
                state.page = pager.getCurrentPage();
                state.size = pager.getPageSize();
            }

            renderTaiKhoan();
        } catch (e) {
            showToast('error', 'Không thực hiện được thao tác.');
        }
    }

        function renderTaiKhoan() {
        const body = document.getElementById('ht-tk-body');
        if (!body) return;
        const detail = pageMode === 'detail';
        const state = htPaging.tk;
        if (!dsTaiKhoan.length) {
            body.innerHTML = '<tr><td colspan="' + (detail ? 8 : 9) + '" class="text-center text-muted py-3">Chưa có tài khoản.</td></tr>';
            return;
        }
        body.innerHTML = '';
        dsTaiKhoan.forEach((x, index) => {
            const tr = document.createElement('tr');
            const active = x.Active === true || x.Active === 1;
            tr.innerHTML = `
                <td class="ht-col-stt text-center">${sttNguoc(state, index)}</td>
                ${detail ? '' : '<td>' + escapeHtml(x.TenCSKCB || '') + '</td>'}
                <td class="ht-sticky-name ht-col-name"><strong>${escapeHtml(x.HoTen || '')}</strong></td>
                <td class="ht-col-login">${escapeHtml(x.Ten_Dang_Nhap || '')}</td>
                <td>${escapeHtml(x.Vai_Tro || '')}</td>
                <td class="small text-nowrap">${x.Lan_Dang_Nhap_Cuoi ? formatDateTime(x.Lan_Dang_Nhap_Cuoi) : '-'}</td>
                <td class="ht-col-code">${escapeHtml(x.MaNhanVien || '')}</td>
                <td class="text-center"><span class="badge ${active ? 'bg-success' : 'bg-secondary'}">${active ? 'Hoạt động' : 'Khóa'}</span></td>
                <td class="text-center ht-sticky-action ht-action-col">
                    <button type="button" class="btn btn-sm btn-light border py-0 px-2 btn-tk-menu" title="Tùy chọn"><i class="bi bi-list"></i></button>
                </td>`;
            tr.querySelector('.btn-tk-menu')?.addEventListener('click', e => { e.stopPropagation(); moMenuTaiKhoan(e.currentTarget, x, active); });
            ganSuKienXemDong(tr, () => suaTaiKhoan(x, false));
            body.appendChild(tr);
        });
    }

    async function suaTaiKhoan(x, choSua = true) {
        const doiNguCanh = datNguCanhTuDong(x);
        if (doiNguCanh) await Promise.all([taiDanhSachNhanVien(), taiVaiTroLookup()]);
        document.getElementById('ht-tk-id').value = x.ID_Tai_Khoan || '';
        document.getElementById('ht-tk-ten').value = x.Ten_Dang_Nhap || '';
        if (x.IDNhanVien) {
            tsNhanVien?.addOption({
                id: String(x.IDNhanVien),
                text: (x.MaNhanVien ? x.MaNhanVien + ' - ' : '') + (x.HoTen || '')
            });
            tsNhanVien?.setValue(String(x.IDNhanVien), true);
        }
        const roleIds = String(x.ID_Vai_Tro || '').split(',').map(v => v.trim()).filter(Boolean);
        tsTaiKhoanVaiTro?.setValue(roleIds, true);
        datCheDoTaiKhoan(choSua);
        duaFormVaoTamNhin('ht-tk-ten');
    }

    function resetFormTaiKhoan() {
        document.getElementById('ht-tk-id').value = '';
        document.getElementById('ht-tk-ten').value = '';
        tsNhanVien?.clear(true);
        tsTaiKhoanVaiTro?.clear(true);
        datCheDoTaiKhoan(true);
    }

        async function luuTaiKhoan() {
        if (isGlobalAdmin && idCskcbQuanTri <= 0) { showToast('warning', 'Chọn cơ sở KCB trước.'); return; }
        const id = Number(document.getElementById('ht-tk-id')?.value || 0) || null;
        const payload = {
            id_tai_khoan: id,
            id_nhan_vien: Number(tsNhanVien?.getValue() || 0),
            ten_dang_nhap: document.getElementById('ht-tk-ten')?.value?.trim() || '',
            vai_tro_ids: (tsTaiKhoanVaiTro?.getValue() || []).map(Number)
        };
        const laThemMoi = !id;
        try {
            const res = await goiJson(urlTheoCskcb('/api/he_thong/tai_khoan/luu'), { method: 'POST', body: JSON.stringify(payload) });
            showToast(res.status === 200 ? 'success' : 'error', res.message);
            if (res.status === 200) {
                resetFormTaiKhoan();
                if (laThemMoi) htPaging.tk.page = 1;
                await taiTaiKhoan();
            }
        } catch (e) { showToast('error', 'Không thực hiện được thao tác.'); }
    }

    async function doiTrangThaiTaiKhoan(x, active) {
        const ok = await hien_thi_xac_nhan({
            tieu_de: active ? 'Mở tài khoản' : 'Khóa tài khoản',
            noi_dung: `${active ? 'Mở' : 'Khóa'} tài khoản ${x.Ten_Dang_Nhap}?`,
            nhan_dong_y: active ? 'Mở tài khoản' : 'Khóa tài khoản',
            lop_nut: active ? 'btn-success' : 'btn-danger'
        });
        if (!ok) return;
        try {
            const res = await goiJson(urlTheoCskcb('/api/he_thong/tai_khoan/trang_thai'), { method: 'POST', body: JSON.stringify({ id_tai_khoan: x.ID_Tai_Khoan, active }) });
            showToast(res.status === 200 ? 'success' : 'error', res.message);
            if (res.status === 200) await taiTaiKhoan();
        } catch (e) { showToast('error', 'Không thực hiện được thao tác.'); }
    }

    async function xoaTaiKhoan(x) {
        const ok = await hien_thi_xac_nhan({
            tieu_de: 'Xóa tài khoản',
            noi_dung: `Xóa tài khoản "${x.Ten_Dang_Nhap}"? Thao tác này sẽ xóa các gán vai trò của tài khoản.`,
            nhan_dong_y: 'Xóa',
            lop_nut: 'btn-danger'
        });
        if (!ok) return;
        try {
            const res = await goiJson(urlTheoCskcb('/api/he_thong/tai_khoan/xoa'), {
                method: 'POST',
                body: JSON.stringify({ id_tai_khoan: x.ID_Tai_Khoan })
            });
            showToast(res.status === 200 ? 'success' : 'error', res.message);
            if (res.status === 200) {
                resetFormTaiKhoan();
                await Promise.all([taiTaiKhoan(), taiNhanVien(), taiDanhSachNhanVien()]);
            }
        } catch (e) { showToast('error', 'Không thực hiện được thao tác.'); }
    }

    async function taiChucDanh(silent = false) {
        const body = document.getElementById('ht-cd-body');
        if (!body || !isGlobalAdmin) return;
        const state = htPaging.cd;
        try {
            const q = layTuKhoaTimKiemQuanTri('cd', 'ht-cd-filter');
            const url = '/api/he_thong/chuc_danh?trang=' + state.page
                + '&kich_thuoc_trang=' + state.size
                + (q ? '&q=' + encodeURIComponent(q) : '');
            const res = silent ? await goiJson(url) : await withPageloader(() => goiJson(url));
            dsChucDanh = res.data || [];
            state.total = tongSoDong(dsChucDanh);

            if (!dsChucDanh.length && state.page > 1) {
                state.page = 1;
                return taiChucDanh();
            }

            const pager = damBaoPhanTrang('cd', '#ht-cd-pagination', 'chức danh', taiChucDanh);
            if (pager) {
                pager.render(state.total, state.page);
                state.page = pager.getCurrentPage();
                state.size = pager.getPageSize();
            }
            renderChucDanh();
        } catch {
            showToast('error', 'Không tải được danh sách chức danh.');
        }
    }

    function renderChucDanh() {
        const body = document.getElementById('ht-cd-body');
        if (!body) return;
        const state = htPaging.cd;
        body.innerHTML = dsChucDanh.length
            ? ''
            : '<tr><td colspan="6" class="text-center text-muted py-3">Chưa có chức danh.</td></tr>';

        dsChucDanh.forEach((x, index) => {
            const tr = document.createElement('tr');
            const moForm = (choSua = false) => {
                document.getElementById('ht-cd-id').value = x.IDChucDanh || '';
                document.getElementById('ht-cd-ma').value = x.MaChucDanh || '';
                document.getElementById('ht-cd-ten').value = x.TenChucDanh || '';
                document.getElementById('ht-cd-viet-tat').value = x.VietTat || '';
                document.getElementById('ht-cd-active').checked = x.Active === true || x.Active === 1;
                datCheDoChucDanh(choSua);
                duaFormVaoTamNhin('ht-cd-ma');
            };
            tr.innerHTML = `
                <td class="ht-col-stt text-center">${sttNguoc(state, index)}</td>
                <td class="ht-sticky-name ht-col-role">${escapeHtml(x.TenChucDanh || '')}</td>
                <td>${escapeHtml(x.VietTat || '')}</td>
                <td class="ht-col-code">${escapeHtml(x.MaChucDanh || '')}</td>
                <td class="text-center"><span class="badge ${x.Active ? 'bg-success' : 'bg-secondary'}">${x.Active ? 'Hoạt động' : 'Ngừng'}</span></td>
                <td class="text-center text-nowrap ht-sticky-action ht-action-col">
                    <button type="button" class="btn btn-sm btn-light border py-0 px-2 btn-cd-menu" title="Tùy chọn"><i class="bi bi-list"></i></button>
                </td>`;
            tr.querySelector('.btn-cd-menu')?.addEventListener('click', e => {
                e.stopPropagation();
                moMenuTuyChon(e.currentTarget, [
                    { id: 'edit', label: 'Sửa chức danh', icon: 'bi-pencil', iconClass: 'text-primary', run: () => moForm(true) },
                    { id: 'delete', label: 'Xóa chức danh', icon: 'bi-trash', danger: true, dividerBefore: true, run: () => xoaChucDanh(x) }
                ]);
            });
            ganSuKienXemDong(tr, () => moForm(false));
            body.appendChild(tr);
        });
    }

    function resetFormChucDanh() {
        ['ht-cd-id', 'ht-cd-ma', 'ht-cd-ten', 'ht-cd-viet-tat'].forEach(id => {
            const el = document.getElementById(id);
            if (el) el.value = '';
        });
        const active = document.getElementById('ht-cd-active');
        if (active) active.checked = true;
        document.querySelectorAll('#ht-cd-body tr.selected, #ht-cd-body tr.table-active')
            .forEach(x => x.classList.remove('selected', 'table-active'));
        datCheDoChucDanh(true);
    }

    async function luuChucDanh() {
        if (!isGlobalAdmin) return;
        const payload = {
            id_chuc_danh: Number(document.getElementById('ht-cd-id')?.value || 0) || null,
            ma_chuc_danh: document.getElementById('ht-cd-ma')?.value?.trim() || '',
            ten_chuc_danh: document.getElementById('ht-cd-ten')?.value?.trim() || '',
            viet_tat: document.getElementById('ht-cd-viet-tat')?.value?.trim() || null,
            active: document.getElementById('ht-cd-active')?.checked !== false
        };
        if (!payload.ma_chuc_danh || !payload.ten_chuc_danh) {
            showToast('warning', 'Nhập mã và tên chức danh.');
            return;
        }
        try {
            const res = await goiJson('/api/he_thong/chuc_danh/luu', {
                method: 'POST',
                body: JSON.stringify(payload)
            });
            showToast(res.status === 200 ? 'success' : 'error', res.message);
            if (res.status === 200) {
                resetFormChucDanh();
                htPaging.cd.page = 1;
                await taiChucDanh();
            }
        } catch {
            showToast('error', 'Không lưu được chức danh.');
        }
    }

    async function xoaChucDanh(x) {
        const ok = await hien_thi_xac_nhan({
            tieu_de: 'Xóa chức danh',
            noi_dung: `Xóa chức danh "${x.TenChucDanh || x.MaChucDanh}"?`,
            nhan_dong_y: 'XÓA',
            lop_nut: 'btn-danger'
        });
        if (!ok) return;
        try {
            const res = await goiJson('/api/he_thong/chuc_danh/xoa', {
                method: 'POST',
                body: JSON.stringify({ id_chuc_danh: x.IDChucDanh })
            });
            showToast(res.status === 200 ? 'success' : 'error', res.message);
            if (res.status === 200) {
                resetFormChucDanh();
                await taiChucDanh();
            }
        } catch {
            showToast('error', 'Không xóa được chức danh.');
        }
    }

        function renderVaiTro() {
        const body = document.getElementById('ht-vt-body');
        if (!body) return;
        const detail = pageMode === 'detail';
        const state = htPaging.vt;
        body.innerHTML = dsVaiTro.length ? '' : '<tr><td colspan="' + (detail ? 6 : 7) + '" class="text-center text-muted">Chưa có vai trò.</td></tr>';
        dsVaiTro.forEach((x, index) => {
            const tr = document.createElement('tr');
            const moForm = (choSua = false) => {
                datNguCanhTuDong(x);
                document.getElementById('ht-vt-id').value = x.ID_Vai_Tro || '';
                document.getElementById('ht-vt-ma').value = x.Ma_Vai_Tro || '';
                document.getElementById('ht-vt-ten').value = x.Ten_Vai_Tro || '';
                document.getElementById('ht-vt-mo-ta').value = x.Mo_Ta || '';
                document.getElementById('ht-vt-active').checked = x.Active === true || x.Active === 1;
                datCheDoVaiTro(choSua);
                duaFormVaoTamNhin('ht-vt-ma');
            };
            tr.innerHTML = `
                <td class="ht-col-stt text-center">${sttNguoc(state, index)}</td>
                ${detail ? '' : '<td>' + escapeHtml(x.TenCSKCB || '') + '</td>'}
                <td class="ht-sticky-name ht-col-role">${escapeHtml(x.Ten_Vai_Tro || '')}</td>
                <td>${escapeHtml(x.Mo_Ta || '')}</td>
                <td class="ht-col-code">${escapeHtml(x.Ma_Vai_Tro || '')}</td>
                <td>${x.Active ? '<span class="badge bg-success">Hoạt động</span>' : '<span class="badge bg-secondary">Ngừng</span>'}</td>
                <td class="text-center text-nowrap ht-sticky-action ht-action-col">
                    <button type="button" class="btn btn-sm btn-light border py-0 px-2 btn-vt-menu" title="Tùy chọn"><i class="bi bi-list"></i></button>
                </td>`;
            tr.querySelector('.btn-vt-menu')?.addEventListener('click', e => {
                e.stopPropagation();
                moMenuTuyChon(e.currentTarget, [
                    { id: 'edit', label: 'Sửa', icon: 'bi-pencil', iconClass: 'text-primary', run: () => moForm(true) },
                    ...(canDeleteVt ? [{ id: 'delete', label: 'Xóa vai trò', icon: 'bi-trash', danger: true, dividerBefore: true, run: () => { datNguCanhTuDong(x); return xoaVaiTro(x); } }] : [])
                ]);
            });
            ganSuKienXemDong(tr, () => moForm(false));
            body.appendChild(tr);
        });
    }

    function resetFormVaiTro() {
        const id = document.getElementById('ht-vt-id');
        const ma = document.getElementById('ht-vt-ma');
        const ten = document.getElementById('ht-vt-ten');
        const moTa = document.getElementById('ht-vt-mo-ta');
        const active = document.getElementById('ht-vt-active');
        if (id) id.value = '';
        if (ma) ma.value = '';
        if (ten) ten.value = '';
        if (moTa) moTa.value = '';
        if (active) active.checked = true;
        datCheDoVaiTro(true);
    }

    async function luuVaiTro() {
        if (isGlobalAdmin && idCskcbQuanTri <= 0) { showToast('warning', 'Chọn cơ sở KCB trước.'); return; }
        const payload = {
            id_vai_tro: Number(document.getElementById('ht-vt-id').value || 0) || null,
            ma_vai_tro: document.getElementById('ht-vt-ma').value.trim(),
            ten_vai_tro: document.getElementById('ht-vt-ten').value.trim(),
            mo_ta: document.getElementById('ht-vt-mo-ta').value.trim(),
            active: document.getElementById('ht-vt-active').checked
        };
        try {
            const res = await goiJson(urlTheoCskcb('/api/he_thong/vai_tro/luu'), { method: 'POST', body: JSON.stringify(payload) });
            showToast(res.status === 200 ? 'success' : 'error', res.message);
            if (res.status === 200) {
                resetFormVaiTro();
                await Promise.all([taiVaiTro(), taiVaiTroLookup()]);
            }
        } catch (e) { showToast('error', 'Không thực hiện được thao tác.'); }
    }


    async function xoaVaiTro(x) {
        const ok = await hien_thi_xac_nhan({
            tieu_de: 'Xóa vai trò',
            noi_dung: `Xóa vai trò "${x.Ten_Vai_Tro || x.Ma_Vai_Tro}"? Vai trò sẽ bị gỡ khỏi mọi tài khoản và toàn bộ cấu hình phân quyền sẽ bị xóa.`,
            nhan_dong_y: 'XÓA',
            lop_nut: 'btn-danger'
        });
        if (!ok) return;
        try {
            const res = await goiJson(urlTheoCskcb('/api/he_thong/vai_tro/xoa'), { method: 'POST', body: JSON.stringify({ id_vai_tro: x.ID_Vai_Tro }) });
            showToast(res.status === 200 ? 'success' : 'error', res.message);
            if (res.status === 200) {
                resetFormVaiTro();
                await Promise.all([taiVaiTro(), taiVaiTroLookup(), taiTaiKhoan()]);
            }
        } catch (e) { showToast('error', 'Không thực hiện được thao tác.'); }
    }

    async function taiPhanQuyen(idVaiTro) {
        const body = document.getElementById('ht-pq-body');
        if (!body) return;
        if (!idVaiTro) { body.innerHTML = '<tr><td colspan="9" class="text-center text-muted">Chọn vai trò để cấu hình.</td></tr>'; return; }
        try {
            const res = await withPageloader(() => goiJson(urlTheoCskcb(`/api/he_thong/phan_quyen?id_vai_tro=${encodeURIComponent(idVaiTro)}`))
            );
            body.innerHTML = '';
            (res.data || []).forEach(x => {
                const tr = document.createElement('tr');
                tr.dataset.idChucNang = x.ID_Chuc_Nang;

                const quyenKeys = ['Xem', 'Them', 'Sua', 'Xoa', 'Xuat', 'Ca_Nhan'];
                const daChonTatCa = quyenKeys.every(k => x[k] === true || x[k] === 1);

                tr.innerHTML = `
                    <td>${escapeHtml(x.Ten_Phan_He || '')}</td>
                    <td>${escapeHtml(x.Ten_Chuc_Nang || '')}</td>
                    ${quyenKeys.map(k => `<td class="text-center"><input type="checkbox" class="form-check-input pq-${k.toLowerCase()}" ${x[k] ? 'checked' : ''}></td>`).join('')}
                    <td class="text-center"><input type="checkbox" class="form-check-input pq-tat-ca" ${daChonTatCa ? 'checked' : ''} title="Chọn hoặc bỏ toàn bộ quyền của chức năng này"></td>
                `;

                const tatCa = tr.querySelector('.pq-tat-ca');
                const cacQuyen = quyenKeys
                    .map(k => tr.querySelector(`.pq-${k.toLowerCase()}`))
                    .filter(Boolean);

                tatCa?.addEventListener('change', () => {
                    cacQuyen.forEach(cb => { cb.checked = tatCa.checked; });
                });

                cacQuyen.forEach(cb => {
                    cb.addEventListener('change', () => {
                        if (tatCa) tatCa.checked = cacQuyen.every(x => x.checked);
                    });
                });

                body.appendChild(tr);
            });
        } catch (e) { showToast('error', 'Không thực hiện được thao tác.'); }
    }

    async function luuPhanQuyen() {
        if (isGlobalAdmin && idCskcbQuanTri <= 0) { showToast('warning', 'Chọn cơ sở KCB trước.'); return; }
        const idVaiTro = Number(tsPhanQuyenVaiTro?.getValue() || 0);
        if (!idVaiTro) { showToast('warning', 'Chọn vai trò trước khi lưu.'); return; }
        const quyen = [...document.querySelectorAll('#ht-pq-body tr[data-id-chuc-nang]')].map(tr => ({
            id_chuc_nang: Number(tr.dataset.idChucNang),
            xem: tr.querySelector('.pq-xem')?.checked || false,
            them: tr.querySelector('.pq-them')?.checked || false,
            sua: tr.querySelector('.pq-sua')?.checked || false,
            xoa: tr.querySelector('.pq-xoa')?.checked || false,
            xuat: tr.querySelector('.pq-xuat')?.checked || false,
            ca_nhan: tr.querySelector('.pq-ca_nhan')?.checked || false
        }));
        try {
            const res = await goiJson(urlTheoCskcb('/api/he_thong/phan_quyen/luu'), { method: 'POST', body: JSON.stringify({ id_vai_tro: idVaiTro, quyen }) });
            showToast(res.status === 200 ? 'success' : 'error', res.message);
        } catch (e) { showToast('error', 'Không thực hiện được thao tác.'); }
    }

    async function dongBoDanhMuc() {
        if (isGlobalAdmin && idCskcbQuanTri <= 0) { showToast('warning', 'Chọn cơ sở KCB cần đồng bộ.'); return; }

        const btn = document.getElementById('btn-ht-dong-bo');
        if (btn?.dataset.loading === '1') return;
        const oldHtml = btn?.innerHTML || '';

        try {
            if (btn) {
                btn.dataset.loading = '1';
                btn.disabled = true;
                btn.innerHTML = '<span class="spinner-border spinner-border-sm" role="status" aria-label="Đang đồng bộ"></span>';
                btn.title = 'Đang đồng bộ danh mục';
            }

            const res = await goiJson(urlTheoCskcb('/api/he_thong/danh_muc/dong_bo'), { method: 'POST', body: '{}' });
            showToast(res.status === 200 ? 'success' : 'error', res.message);
        } catch (e) {
            showToast('error', 'Không thực hiện được thao tác.');
        } finally {
            if (btn) {
                delete btn.dataset.loading;
                btn.disabled = false;
                btn.innerHTML = oldHtml;
                btn.title = 'Đồng bộ danh mục';
            }
        }
    }

    function formatDateTime(v) {
        if (!v) return '-';
        const d = new Date(v);
        if (Number.isNaN(d.getTime())) return String(v);
        return d.toLocaleString('vi-VN');
    }

    function escapeHtml(value) {
        return String(value ?? '').replace(/[&<>'"]/g, ch => ({ '&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;' }[ch]));
    }
})();
