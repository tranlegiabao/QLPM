/**
 * phacdo.js - Module quản lý danh mục Phác đồ điều trị mẫu (Chuẩn Khám Bệnh & HisSoft)
 */
(function () {
    let selectedPhacDoId = null;
    let listIcd10Mau = [];
    let listClsMau = [];
    let listThuocMau = [];
    let currentDanhSachPhacDo = [];
    let pdCurrentPage = 1;
    let pdPageSize = 25;
    let pdServerTotal = 0;
    let pdPagination = null;
    let phacDoEditMode = true;
    let pdFloatingMenu = null;
    let pdFloatingMenuOutsideHandler = null;

    let selectIcd10Instance = null;
    let selectDichVuInstance = null;
    let inlineSelectThuocInstance = null;
    let replacementSelectThuocInstance = null;
    let replacementSelectCleanup = null;
    let thuocDvtSelectInstances = [];

    function dongMenuPhacDo() {
        pdFloatingMenu?.remove();
        pdFloatingMenu = null;
        if (pdFloatingMenuOutsideHandler) {
            document.removeEventListener('pointerdown', pdFloatingMenuOutsideHandler, true);
            pdFloatingMenuOutsideHandler = null;
        }
    }

    function moMenuPhacDo(button, pd) {
        dongMenuPhacDo();
        const menu = document.createElement('div');
        menu.className = 'dropdown-menu show shadow';
        menu.style.position = 'fixed';
        menu.style.zIndex = '2000';
        menu.innerHTML = '<button type="button" class="dropdown-item act-edit"><i class="bi bi-pencil me-2 text-primary"></i>Sửa phác đồ</button>';
        document.body.appendChild(menu);
        pdFloatingMenu = menu;

        const rect = button.getBoundingClientRect();
        const menuRect = menu.getBoundingClientRect();
        menu.style.left = Math.max(8, Math.min(rect.right - menuRect.width, window.innerWidth - menuRect.width - 8)) + 'px';
        menu.style.top = Math.max(8, Math.min(rect.bottom + 4, window.innerHeight - menuRect.height - 8)) + 'px';

        menu.querySelector('.act-edit')?.addEventListener('click', async e => {
            e.stopPropagation();
            dongMenuPhacDo();
            document.querySelectorAll('#pd-table-body tr').forEach(r => r.classList.remove('selected', 'table-active'));
            button.closest('tr')?.classList.add('selected', 'table-active');
            await chonPhacDo(pd.id, true);
        });

        pdFloatingMenuOutsideHandler = e => {
            if (menu.contains(e.target) || button.contains(e.target)) return;
            dongMenuPhacDo();
        };
        document.addEventListener('pointerdown', pdFloatingMenuOutsideHandler, true);
    }

    function setPhacDoEditMode(choSua) {
        phacDoEditMode = choSua === true;
        document.querySelectorAll('#pd-form input:not(#pd-id), #pd-form textarea, #pd-form select').forEach(el => {
            el.disabled = !phacDoEditMode;
        });

        [selectIcd10Instance, selectDichVuInstance, inlineSelectThuocInstance]
            .filter(Boolean)
            .forEach(ts => phacDoEditMode ? ts.enable() : ts.disable());
        thuocDvtSelectInstances
            .filter(Boolean)
            .forEach(ts => phacDoEditMode ? ts.enable() : ts.disable());

        document.querySelectorAll('#pd-form .btn-pd-xoa-icd10, #pd-form .btn-xoa-cls, #pd-form .btn-xoa-t')
            .forEach(btn => { btn.disabled = !phacDoEditMode; });

        document.querySelectorAll('#pd-tbody-thuoc tr:not(.row-new-entry) .col-sticky-thuoc').forEach(cell => {
            cell.classList.toggle('pd-drug-click-cell', phacDoEditMode);
            cell.title = phacDoEditMode ? 'Nhấp để đổi thuốc' : '';
        });

        const save = document.getElementById('btn-pd-luu');
        if (save) save.disabled = !phacDoEditMode;
        const remove = document.getElementById('btn-pd-xoa');
        if (remove) remove.disabled = !phacDoEditMode;
    }

    function capRenderedTableRows(wrapperSelector) {
        const wrapper = document.querySelector(wrapperSelector);
        if (!wrapper) return;

        // Đồng bộ tab Khám: bảng hiển thị toàn bộ dòng, chỉ cuộn ngang khi cần.
        wrapper.classList.remove('table-cap-active');
        wrapper.style.setProperty('max-height', 'none', 'important');
        wrapper.style.removeProperty('height');
    }

    document.addEventListener('DOMContentLoaded', async () => {
        initTomSelects();
        initSectionNavigation();
        setupPrescriptionTypeSelector();
        setupSymptomCollapse();
        bindEvents();
        resetFormPhacDo();
        await loadDanhSachPhacDo();
    });

    function initSectionNavigation() {
        const scroller = document.getElementById('pd-scroll-area');
        const buttons = Array.from(document.querySelectorAll('.pd-section-nav-btn'));
        if (!scroller || buttons.length === 0) return;

        if (window.bootstrap?.Tooltip) {
            buttons.forEach(btn => {
                if (!bootstrap.Tooltip.getInstance(btn)) {
                    new bootstrap.Tooltip(btn, { boundary: 'window' });
                }
            });
        }

        const sections = buttons
            .map(btn => document.getElementById(btn.dataset.target))
            .filter(Boolean);

        const setActive = (targetId) => {
            buttons.forEach(btn => {
                btn.classList.toggle('active', btn.dataset.target === targetId);
            });
        };

        buttons.forEach(btn => {
            btn.addEventListener('click', () => {
                const target = document.getElementById(btn.dataset.target);
                if (!target) return;

                const scrollerRect = scroller.getBoundingClientRect();
                const targetRect = target.getBoundingClientRect();
                const top = scroller.scrollTop + targetRect.top - scrollerRect.top - 6;

                scroller.scrollTo({ top: Math.max(0, top), behavior: 'smooth' });
                setActive(btn.dataset.target);
            });
        });

        let rafId = 0;
        scroller.addEventListener('scroll', () => {
            if (rafId) cancelAnimationFrame(rafId);
            rafId = requestAnimationFrame(() => {
                if (!sections.length) return;

                // Nếu đã cuộn sát đáy thì section cuối phải active.
                // Trước đây Toa thuốc thường không lên đủ cao để vượt ngưỡng,
                // nên icon CLS vẫn sáng dù người dùng đang ở Toa thuốc.
                const nearBottom = scroller.scrollTop + scroller.clientHeight >= scroller.scrollHeight - 8;
                if (nearBottom) {
                    setActive(sections[sections.length - 1].id);
                    return;
                }

                const scrollerTop = scroller.getBoundingClientRect().top + 72;
                let activeSection = sections[0].id;

                sections.forEach(section => {
                    if (section.getBoundingClientRect().top <= scrollerTop) {
                        activeSection = section.id;
                    }
                });

                setActive(activeSection);
            });
        }, { passive: true });
    }

    function setupPrescriptionTypeSelector() {
        const select = document.getElementById('pd-loai-toa');
        if (!select) return;

        const defaults = [
            { id: 'c', ma: 'c', ten: 'Đơn thuốc cơ bản', viettat: 'DTCB' },
            { id: 'n', ma: 'n', ten: 'Đơn thuốc gây nghiện', viettat: 'DTGN' },
            { id: 'h', ma: 'h', ten: 'Đơn thuốc hướng tâm thần và thuốc tiền chất', viettat: 'DTHTTVTTC' }
        ];

        const renderOptions = (items, selected = 'c') => {
            const byCode = new Map(
                (items || [])
                    .filter(item => ['c', 'n', 'h'].includes(String(item?.ma || item?.id || '').trim().toLowerCase()))
                    .map(item => [String(item.ma || item.id).trim().toLowerCase(), item])
            );

            select.replaceChildren(...defaults.map(fallback => {
                const item = byCode.get(fallback.ma) || fallback;
                const option = document.createElement('option');
                option.value = fallback.ma;
                option.textContent = `${item.ten || fallback.ten} [${item.viettat || fallback.viettat}]`;
                return option;
            }));
            select.value = defaults.some(item => item.ma === selected) ? selected : 'c';
        };

        const selected = select.value || 'c';
        renderOptions(defaults, selected);

        fetch('/api/kham_benh/loai_toa', { credentials: 'same-origin' })
            .then(response => response.ok ? response.json() : null)
            .then(result => {
                if (!result || result.status !== 200 || !Array.isArray(result.data)) return;
                renderOptions(result.data, select.value || selected);
            })
            .catch(() => { });

        // Giống tab Khám: Loại toa chỉ lọc thuốc thêm tiếp theo,
        // không thay đổi các thuốc mẫu đã có trong phác đồ.
        select.addEventListener('change', () => renderThuocTable());
    }

    function setupSymptomCollapse() {
        const input = document.getElementById('pd-trieu-chung');
        if (!(input instanceof HTMLTextAreaElement)) return;

        const collapse = () => {
            input.classList.remove('kb-expanded');
            input.classList.add('kb-collapsed');
            input.style.removeProperty('height');
        };
        const expand = () => {
            input.classList.remove('kb-collapsed');
            input.classList.add('kb-expanded');
            input.style.setProperty('height', 'auto', 'important');
            const maxHeight = Math.max(96, window.innerHeight * 0.28);
            input.style.setProperty('height', `${Math.min(input.scrollHeight, maxHeight)}px`, 'important');
        };

        input.addEventListener('focus', expand);
        input.addEventListener('input', () => {
            if (document.activeElement === input) expand();
        });
        input.addEventListener('blur', collapse);
        collapse();
    }

    function initPhacDoDrugPicker(el, maLoaiToa, onSelect) {
        const code = ['c', 'n', 'h'].includes(String(maLoaiToa || '').toLowerCase())
            ? String(maLoaiToa).toLowerCase()
            : 'c';
        const picker = initRemoteTomSelect(
            el,
            `/api/danh_muc/dm_thuoc?ma_loai_toa_thuoc=${encodeURIComponent(code)}`,
            {
                placeholder: 'Tìm tên thuốc, hoạt chất...',
                dropdownParent: 'body',
                preload: 'focus',
                loadThrottle: 100,
                maxOptions: 30,
                render: {
                    option: (data, escape) => `
                        <div class="kb-his-drug-option">
                            <div class="kb-his-drug-info">
                                <div class="kb-his-drug-name">${escape(data.ten || '')}</div>
                                <div class="kb-his-drug-fields">
                                    ${data.ham_luong ? `<span><b>HL:</b> ${escape(data.ham_luong)}</span>` : ''}
                                    ${data.hoat_chat ? `<span><b>HC:</b> ${escape(data.hoat_chat)}</span>` : ''}
                                    ${data.don_vi_tinh ? `<span><b>ĐVT:</b> ${escape(data.don_vi_tinh)}</span>` : ''}
                                    ${data.duong_dung ? `<span><b>ĐD:</b> ${escape(data.duong_dung)}</span>` : ''}
                                </div>
                            </div>
                            <div class="kb-his-drug-stockbox">
                                <div><b>Giá DV:</b> ${Number(data.gia_ban ?? data.don_gia ?? 0).toLocaleString('vi-VN')} đ</div>
                            </div>
                        </div>`,
                    item: (data, escape) => `<div class="kb-medicine-selected">${escape(data.ten || '')}</div>`
                }
            },
            onSelect
        );
        if (picker) picker.dropdown?.classList.add('kb-his-drug-dropdown', 'kb-exam-dropdown');
        return picker;
    }

    function moChonThayThuoc(cell, item, rowIndex) {
        if (!phacDoEditMode || !cell) return;

        if (replacementSelectCleanup) {
            replacementSelectCleanup();
            replacementSelectCleanup = null;
        }
        try { replacementSelectThuocInstance?.destroy?.(); } catch (_) { }
        replacementSelectThuocInstance = null;

        cell.innerHTML = '<select class="form-table w-100 pd-replace-thuoc"></select>';
        const select = cell.querySelector('select');
        if (!select) return;

        const loai = item.MaLoaiToaThuoc || document.getElementById('pd-loai-toa')?.value || 'c';
        let selected = false;
        replacementSelectThuocInstance = initPhacDoDrugPicker(select, loai, (thuoc) => {
            if (!thuoc?.id) return;
            selected = true;
            item.IDThuoc = thuoc.id;
            item.MaThuoc = thuoc.ma || '';
            item.TenThuoc = thuoc.ten || '';
            item.HoatChat = thuoc.hoat_chat || '';
            item.DonViTinh = thuoc.don_vi_tinh || 'Viên';
            item.IDDonViTinhDung = thuoc.id_don_vi_tinh || null;
            item.DonViTinhDung = thuoc.don_vi_tinh || 'Viên';
            item.DuongDung = thuoc.duong_dung || item.DuongDung || 'Uống';
            item.MaLoaiToaThuoc = String(thuoc.ma_loai_toa_thuoc || loai || 'c').toLowerCase();
            item.DonGia = parseFloat(thuoc.gia_ban ?? thuoc.don_gia) || 0;
            item.ThanhTien = (parseFloat(item.SoLuong) || 1) * item.DonGia;
            renderThuocTable({ focusIndex: rowIndex, focusField: 'sngay' });
        });

        replacementSelectThuocInstance?.focus();
        replacementSelectThuocInstance?.open();

        const outside = e => {
            const dropdown = replacementSelectThuocInstance?.dropdown;
            if (cell.contains(e.target) || dropdown?.contains(e.target)) return;
            document.removeEventListener('pointerdown', outside, true);
            replacementSelectCleanup = null;
            if (!selected) renderThuocTable();
        };
        replacementSelectCleanup = () => document.removeEventListener('pointerdown', outside, true);
        setTimeout(() => document.addEventListener('pointerdown', outside, true), 0);
    }

    function initTomSelects() {
        // 1. Chẩn đoán ICD-10
        selectIcd10Instance = initRemoteTomSelect('#pd-select-icd10', 'dm_icd10', {
            localSearch: true,
            localSearchTop: 1000
        }, (item) => {
            if (listIcd10Mau.some(x => Number(x.id) === Number(item.id))) {
                showToast('warning', 'ICD-10 đã có trong phác đồ.');
                selectIcd10Instance?.clear();
                return;
            }

            const viTriMoi = listIcd10Mau.length;
            listIcd10Mau.push({
                id: item.id,
                ma: item.ma,
                ten: item.ten,
                ban_dau: viTriMoi === 0,
                benh_chinh: viTriMoi === 1,
                benh_khac: viTriMoi >= 2
            });
            selectIcd10Instance?.clear();
            renderIcd10Table();
        });

        // 2. Dịch vụ Kỹ thuật / CLS mẫu
        selectDichVuInstance = initRemoteTomSelect('#pd-select-dich-vu', 'dm_dich_vu', {
            localSearch: true,
            localSearchTop: 1000,
            render: {
                option: (data, escape) => `
                    <div class="kb-service-option" title="${escape(data.ten || '')}">
                        <span class="kb-service-option-name">${escape(data.ten || '')}</span>
                        ${data.ma ? `<span class="kb-service-option-code">[${escape(data.ma)}]</span>` : ''}
                        ${data.don_gia !== undefined && data.don_gia !== null ? `<span class="kb-service-option-price">${Number(data.don_gia || 0).toLocaleString('vi-VN')} đ</span>` : ''}
                        ${data.don_vi_tinh ? `<span class="kb-service-option-unit">(${escape(data.don_vi_tinh)})</span>` : ''}
                    </div>`,
                item: (data, escape) => `<div class="kb-service-selected" title="${escape(data.ten || '')}">${escape(data.ten || '')}</div>`
            }
        }, (item) => {
            themClsMau({
                IDDichVu: item.id,
                MaDichVu: item.ma,
                TenDichVu: item.ten,
                SoLuong: 1,
                DonGia: item.don_gia || 0,
                GuiNgoai: false,
                NoiGuiNgoai: '',
                GhiChu: ''
            });
            selectDichVuInstance?.clear();
        });

        if (selectDichVuInstance) {
            selectDichVuInstance.dropdown?.classList.add('kb-service-dropdown');
            selectDichVuInstance.wrapper?.classList.add('kb-service-select');
        }
    }

    function renderIcd10Table() {
        const table = document.getElementById('pd-table-icd10');
        const badge = document.getElementById('pd-icd10-selected-badge');
        const tbody = document.getElementById('pd-tbody-icd10');

        // Đồng bộ header bằng JS để tránh trường hợp Razor/View cũ còn 3 cột
        // trong khi tbody mới đã render 6 cột.
        if (table) {
            let colgroup = table.querySelector('colgroup[data-pd-icd-cols]');
            if (!colgroup) {
                colgroup = document.createElement('colgroup');
                colgroup.setAttribute('data-pd-icd-cols', '1');
                colgroup.innerHTML = `
                    <col style="width: 90px;">
                    <col>
                    <col style="width: 45px;">
                    <col style="width: 55px;">
                    <col style="width: 45px;">
                    <col style="width: 40px;">
                `;
                table.insertBefore(colgroup, table.firstChild);
            }

            let thead = table.querySelector('thead');
            if (!thead) {
                thead = document.createElement('thead');
                table.insertBefore(thead, tbody || null);
            }

            thead.innerHTML = `
                <tr>
                    <th>Mã bệnh</th>
                    <th>Tên bệnh</th>
                    <th class="text-center">BĐ</th>
                    <th class="text-center">Chính</th>
                    <th class="text-center" title="Bệnh khác">#</th>
                    <th class="text-center">Xóa</th>
                </tr>
            `;
        }
        if (badge) {
            badge.textContent = listIcd10Mau.length > 0 ? `${listIcd10Mau.length} chẩn đoán ICD-10` : 'Chưa chọn ICD-10';
        }
        if (!tbody) return;

        tbody.innerHTML = '';
        if (listIcd10Mau.length === 0) {
            tbody.innerHTML = '<tr><td colspan="6" class="text-center text-muted py-2">Chưa chọn chẩn đoán ICD-10</td></tr>';
            capRenderedTableRows('.pd-icd-table-wrap', '#pd-table-icd10', 3);
            return;
        }

        listIcd10Mau.forEach((icd, index) => {
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td class="fw-bold text-primary text-nowrap">${icd.ma || ''}</td>
                <td class="text-wrap">${icd.ten || ''}</td>
                <td class="text-center"><input type="checkbox" class="form-check-input chk-pd-ban-dau" ${icd.ban_dau ? 'checked' : ''} /></td>
                <td class="text-center"><input type="checkbox" class="form-check-input chk-pd-benh-chinh" ${icd.benh_chinh ? 'checked' : ''} /></td>
                <td class="text-center"><input type="checkbox" class="form-check-input chk-pd-benh-khac" ${icd.benh_khac ? 'checked' : ''} /></td>
                <td class="text-center">
                    <button type="button" class="btn btn-sm btn-link text-danger p-0 btn-pd-xoa-icd10" title="Bỏ chẩn đoán">
                        <i class="bi bi-x-circle"></i>
                    </button>
                </td>`;

            tr.querySelector('.chk-pd-ban-dau')?.addEventListener('change', e => {
                icd.ban_dau = e.target.checked;
            });
            tr.querySelector('.chk-pd-benh-chinh')?.addEventListener('change', e => {
                icd.benh_chinh = e.target.checked;
                if (icd.benh_chinh) {
                    listIcd10Mau.forEach((x, i) => {
                        if (i !== index) x.benh_chinh = false;
                    });
                    renderIcd10Table();
                }
            });
            tr.querySelector('.chk-pd-benh-khac')?.addEventListener('change', e => {
                icd.benh_khac = e.target.checked;
            });
            tr.querySelector('.btn-pd-xoa-icd10')?.addEventListener('click', () => {
                listIcd10Mau.splice(index, 1);
                renderIcd10Table();
            });
            tbody.appendChild(tr);
        });

        capRenderedTableRows('.pd-icd-table-wrap', '#pd-table-icd10', 3);
    }

    // ================= DANH SÁCH PHÁC ĐỒ (CỘT TRÁI) =================
    async function loadDanhSachPhacDo(selectedIdTarget = null) {
        const tuKhoa = document.getElementById('pd-filter-tu-khoa')?.value.trim() || '';
        const res = await withPageloader(() => apiGet('/api/phac_do/danh_sach', { tu_khoa: tuKhoa, trang: pdCurrentPage, kich_thuoc_trang: pdPageSize })
        );

        const tbody = document.getElementById('pd-table-body');
        if (!tbody) return;
        tbody.innerHTML = '';

        if (res.status !== 200 || !Array.isArray(res.data)) {
            currentDanhSachPhacDo = [];
            pdServerTotal = 0;
        } else {
            currentDanhSachPhacDo = res.data;
            pdServerTotal = currentDanhSachPhacDo.length
                ? Number(currentDanhSachPhacDo[0].tong_so_dong || 0)
                : 0;
        }

        if (!pdPagination) {
            pdPagination = createQLPMPagination({
                container: '#pd-pagination',
                tableScrollSelector: '#pd-table',
                itemName: 'phác đồ',
                pageSize: pdPageSize,
                currentPage: pdCurrentPage,
                pageSizes: [10, 25, 50, 100],
                showCount: true,
                compact: true,
                onPageChange: (newPage, newSize) => {
                    pdCurrentPage = newPage;
                    pdPageSize = newSize;
                    loadDanhSachPhacDo();
                }
            });
        }

        if (!currentDanhSachPhacDo.length && pdCurrentPage > 1 && pdServerTotal === 0) {
            pdCurrentPage = 1;
            return loadDanhSachPhacDo(selectedIdTarget);
        }

        if (pdPagination) {
            pdPagination.render(pdServerTotal, pdCurrentPage);
            pdPageSize = pdPagination.getPageSize();
            pdCurrentPage = pdPagination.getCurrentPage();
        }

        if (!currentDanhSachPhacDo.length) {
            tbody.innerHTML = '<tr><td colspan="4" class="text-center text-muted py-4">Chưa có phác đồ điều trị nào</td></tr>';
            return;
        }

        const startIndex = (pdCurrentPage - 1) * pdPageSize;
        currentDanhSachPhacDo.forEach((pd, index) => {
            const tr = document.createElement('tr');
            tr.setAttribute('data-id', pd.id);

            const isSelected = selectedIdTarget
                ? Number(pd.id) === Number(selectedIdTarget)
                : (index === 0 && !selectedPhacDoId);

            if (isSelected) {
                tr.classList.add('selected', 'table-active');
                chonPhacDo(pd.id, false);
            }

            tr.innerHTML = `
                <td class="text-center fw-bold text-muted">${startIndex + index + 1}</td>
                <td class="col-sticky-name fw-bold">${pd.ten_phac_do || ''}</td>
                <td class="pd-col-code fw-bold text-primary">${pd.ma_phac_do || ''}</td>
                <td class="col-sticky-options text-center">
                    <button type="button" class="btn btn-sm btn-light border py-0 px-2 btn-pd-menu" title="Tùy chọn"><i class="bi bi-list"></i></button>
                </td>
            `;

            tr.querySelector('.btn-pd-menu')?.addEventListener('click', e => {
                e.stopPropagation();
                moMenuPhacDo(e.currentTarget, pd);
            });

            tr.addEventListener('click', e => {
                if (e.target.closest('button, .dropdown-menu')) return;
                document.querySelectorAll('#pd-table-body tr').forEach(r => r.classList.remove('selected', 'table-active'));
                tr.classList.add('selected', 'table-active');
                chonPhacDo(pd.id, false);
            });

            tbody.appendChild(tr);
        });
    }

    // ================= CHI TIẾT PHÁC ĐỒ (CỘT PHẢI) =================
    async function chonPhacDo(id, choSua = false) {
        selectedPhacDoId = id;
        const res = await withPageloader(() => apiGet('/api/phac_do/chi_tiet', { id: id })
        );
        if (res.status !== 200 || !res.data) {
            showToast('error', res.message || 'Không tải được phác đồ.');
            return;
        }

        const data = res.data;
        const info = data.thong_tin;

        document.getElementById('pd-id').value = info.ID;
        document.getElementById('pd-ma').value = info.MaPhacDo || '';
        document.getElementById('pd-ten').value = info.TenPhacDo || '';
        document.getElementById('pd-trieu-chung').value = info.TrieuChung || '';
        
        // ICD-10 mẫu: hỗ trợ nhiều chẩn đoán.
        listIcd10Mau = (data.chan_doan || []).map(cd => ({
            id: cd.IDICD10,
            ma: cd.MaBenh || '',
            ten: cd.TenBenh || '',
            ban_dau: cd.BanDau === true || Number(cd.BanDau) === 1,
            benh_chinh: cd.BenhChinh === true || Number(cd.BenhChinh) === 1,
            benh_khac: cd.BenhKhac === true || Number(cd.BenhKhac) === 1
        }));

        listIcd10Mau.forEach(icd => {
            selectIcd10Instance?.addOption({ id: icd.id, ma: icd.ma, ten: icd.ten });
        });
        selectIcd10Instance?.clear();
        renderIcd10Table();

        // Chỉ định CLS mẫu
        listClsMau = (data.chi_dinh || []).map(c => ({
            IDDichVu: c.IDDichVu,
            MaDichVu: c.MaDichVu,
            TenDichVu: c.TenDichVu,
            SoLuong: c.SoLuong || 1,
            DonGia: c.DonGia || 0,
            GuiNgoai: c.GuiNgoai === true,
            NoiGuiNgoai: c.NoiGuiNgoai || '',
            GhiChu: c.GhiChu || ''
        }));
        renderClsTable();

        // Toa thuốc điều trị mẫu (chuẩn HisSoft)
        let maxSoNgay = 3;
        listThuocMau = (data.thuoc || []).map(t => {
            const soNgay = t.SoNgay || 3;
            if (soNgay > maxSoNgay) maxSoNgay = soNgay;
            const sl = t.SoLuong || 1;
            const donGia = t.DonGia || 0;
            return {
                IDThuoc: t.IDThuoc,
                MaThuoc: t.MaThuoc || '',
                TenThuoc: t.TenThuoc,
                HoatChat: t.HoatChat || '',
                DonViTinh: t.DonViTinh || 'Viên',
                IDDonViTinhDung: t.IDDonViTinhDung || null,
                DonViTinhDung: t.DonViTinhDung || t.DonViTinh || 'Viên',
                DuongDung: t.DuongDung || 'Uống',
                SoNgay: soNgay,
                Sang: (t.Sang !== undefined && t.Sang !== null) ? String(t.Sang) : '0',
                Trua: (t.Trua !== undefined && t.Trua !== null) ? String(t.Trua) : '0',
                Chieu: (t.Chieu !== undefined && t.Chieu !== null) ? String(t.Chieu) : '0',
                Toi: (t.Toi !== undefined && t.Toi !== null) ? String(t.Toi) : '0',
                LieuDung: t.LieuDung || '',
                CachDung: t.CachDung || '',
                SoLuong: sl,
                DonGia: donGia,
                ThanhTien: sl * donGia,
                MaLoaiToaThuoc: String(t.MaLoaiToaThuoc || 'c').trim().toLowerCase()
            };
        });

        const toaSoNgayEl = document.getElementById('pd-toa-so-ngay');
        if (toaSoNgayEl) toaSoNgayEl.value = maxSoNgay;
        const loaiToaEl = document.getElementById('pd-loai-toa');
        if (loaiToaEl) loaiToaEl.value = listThuocMau[0]?.MaLoaiToaThuoc || 'c';

        renderThuocTable();

        // Mở collapse tương ứng nếu có dữ liệu
        if (listClsMau.length > 0) {
            const clsCollapse = document.getElementById('pd-collapse-chi-dinh');
            if (clsCollapse && !clsCollapse.classList.contains('show')) {
                new bootstrap.Collapse(clsCollapse, { show: true });
            }
        }

        const btnXoa = document.getElementById('btn-pd-xoa');
        if (btnXoa) btnXoa.style.display = 'inline-block';
        setPhacDoEditMode(choSua);
    }

    function resetFormPhacDo() {
        selectedPhacDoId = null;
        document.getElementById('pd-id').value = '';
        document.getElementById('pd-ma').value = '';
        document.getElementById('pd-ten').value = '';
        document.getElementById('pd-trieu-chung').value = '';

        const toaSoNgayEl = document.getElementById('pd-toa-so-ngay');
        if (toaSoNgayEl) toaSoNgayEl.value = 3;
        const loaiToaEl = document.getElementById('pd-loai-toa');
        if (loaiToaEl) loaiToaEl.value = 'c';

        listIcd10Mau = [];
        selectIcd10Instance?.clear();
        renderIcd10Table();

        listClsMau = [];
        renderClsTable();

        listThuocMau = [];
        renderThuocTable();

        const btnXoa = document.getElementById('btn-pd-xoa');
        if (btnXoa) btnXoa.style.display = 'none';

        document.getElementById('pd-ma').focus();

        const scroller = document.getElementById('pd-scroll-area');
        if (scroller) scroller.scrollTo({ top: 0, behavior: 'smooth' });
        document.querySelectorAll('.pd-section-nav-btn').forEach(btn => {
            btn.classList.toggle('active', btn.dataset.target === 'pd-section-thong-tin');
        });
        setPhacDoEditMode(true);
    }

    // ================= CHỈ ĐỊNH DỊCH VỤ KỸ THUẬT / CLS MẪU =================
    function themClsMau(item) {
        if (listClsMau.some(x => x.IDDichVu === item.IDDichVu)) {
                showToast('warning', 'Dịch vụ đã có trong phác đồ.');
            return;
        }
        listClsMau.push(item);
        renderClsTable();

        const clsCollapse = document.getElementById('pd-collapse-chi-dinh');
        if (clsCollapse && !clsCollapse.classList.contains('show')) {
            new bootstrap.Collapse(clsCollapse, { show: true });
        }
    }

    function renderClsTable() {
        const tbody = document.getElementById('pd-tbody-cls');
        const countEl = document.getElementById('pd-cls-count');
        const tongTienEl = document.getElementById('pd-cls-tong-tien');
        if (!tbody) return;
        tbody.innerHTML = '';

        let tongTien = 0;
        listClsMau.forEach(c => {
            const donGiaTinh = c.GuiNgoai ? 0 : (parseFloat(c.DonGia) || 0);
            tongTien += (parseFloat(c.SoLuong) || 1) * donGiaTinh;
        });

        if (countEl) {
            countEl.innerText = listClsMau.length;
            countEl.className = listClsMau.length > 0
                ? 'badge bg-primary rounded-pill kb-title-count'
                : 'badge bg-secondary-subtle text-secondary rounded-pill kb-title-count';
        }
        if (tongTienEl) {
            tongTienEl.innerText = `Cộng CĐ: ${Number(tongTien).toLocaleString('vi-VN')} đ`;
        }

        if (listClsMau.length === 0) {
            tbody.innerHTML = '<tr><td colspan="5" class="text-center text-muted py-2">Chưa có dịch vụ cận lâm sàng mẫu</td></tr>';
            capRenderedTableRows('.pd-cls-table-wrap', '#pd-table-cls', 3);
            return;
        }

        listClsMau.forEach((item, index) => {
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td class="pd-sticky-service-col">
                    <div class="pd-service-name-cell" title="${(item.TenDichVu || '') + (item.MaDichVu ? ' (' + item.MaDichVu + ')' : '')}">
                        <strong>${item.TenDichVu || ''}</strong>${item.MaDichVu ? ` <small class="text-muted ms-1">(${item.MaDichVu})</small>` : ''}
                    </div>
                </td>
                <td class="text-center">
                    <input type="number" class="form-control form-control-sm text-center p-0 inp-sl" min="1" value="${item.SoLuong}" />
                </td>
                <td class="text-end">${Number(item.GuiNgoai ? 0 : item.DonGia).toLocaleString('vi-VN')} đ</td>
                <td class="text-center">
                    <input type="checkbox" class="form-check-input chk-gui-ngoai" ${item.GuiNgoai ? 'checked' : ''} />
                </td>
                <td class="text-center">
                    <button type="button" class="btn btn-sm btn-link text-danger p-0 btn-xoa-cls" title="Xóa"><i class="bi bi-trash3-fill"></i></button>
                </td>
            `;

            tr.querySelector('.inp-sl')?.addEventListener('input', (e) => {
                item.SoLuong = parseFloat(e.target.value) || 1;
                renderClsTable();
            });

            tr.querySelector('.chk-gui-ngoai')?.addEventListener('change', (e) => {
                item.GuiNgoai = e.target.checked;
                renderClsTable();
            });

            tr.querySelector('.btn-xoa-cls')?.addEventListener('click', () => {
                listClsMau.splice(index, 1);
                renderClsTable();
            });

            tbody.appendChild(tr);
        });

        capRenderedTableRows('.pd-cls-table-wrap', '#pd-table-cls', 3);
    }

    // ================= TOA THUỐC MẪU (CHUẨN HISSOFT & TAB KHÁM BỆNH) =================
    function syncThuocThead() {
        const thead = document.querySelector('#pd-table-thuoc thead');
        if (!thead) return;
        thead.innerHTML = `
            <tr class="text-center align-middle bg-light qlpm-one-line-head-row">
                <th class="col-sticky-stt text-center" style="width:26px;min-width:26px;max-width:26px;">TT</th>
                <th class="col-sticky-thuoc text-start" style="width:150px;min-width:150px;max-width:150px;">Thuốc</th>
                <th style="width:100px;min-width:100px;max-width:100px;" class="text-start">Hoạt chất</th>
                <th class="text-center" title="Số ngày">SN</th>
                <th class="text-center">ĐVT</th>
                <th style="width:55px;min-width:55px;max-width:55px;" class="text-center">Sáng</th>
                <th style="width:55px;min-width:55px;max-width:55px;" class="text-center">Trưa</th>
                <th style="width:55px;min-width:55px;max-width:55px;" class="text-center">Chiều</th>
                <th style="width:55px;min-width:55px;max-width:55px;" class="text-center">Tối</th>
                <th style="width:90px;min-width:90px;max-width:90px;" class="text-center" title="Đường dùng">ĐD</th>
                <th style="width:180px;min-width:180px;max-width:180px;" class="text-start">Cách dùng khác</th>
                <th style="width:90px;min-width:90px;max-width:90px;" class="text-end">Đơn giá</th>
                <th style="width:105px;min-width:105px;max-width:105px;" class="text-end">Thành tiền</th>
                <th class="col-sticky-dvt-dung text-center" style="width:68px;min-width:68px;max-width:68px;">ĐVT dùng</th>
                <th class="col-sticky-sl text-center" style="width:55px;min-width:55px;max-width:55px;">SL</th>
                <th class="col-sticky-xoa text-center" style="width:45px;min-width:45px;max-width:45px;">Xóa</th>
            </tr>
        `;
    }

    function updateThuocTotals() {
        let tongTien = 0;
        listThuocMau.forEach(t => {
            tongTien += (parseFloat(t.ThanhTien) || 0);
        });

        const totalEl = document.getElementById('pd-thuoc-tong-tien');
        if (totalEl) totalEl.innerText = `Tổng tiền thuốc: ${Number(tongTien).toLocaleString('vi-VN')} đ`;

        const footerTotalEl = document.getElementById('pd-footer-tong-tien');
        if (footerTotalEl) {
            footerTotalEl.innerHTML = `<i class="bi bi-cash-stack me-1"></i> Cộng Thuốc: <strong>${Number(tongTien).toLocaleString('vi-VN')} đ</strong>`;
        }

        const countEl = document.getElementById('pd-thuoc-count');
        if (countEl) {
            countEl.innerText = listThuocMau.length;
            countEl.className = listThuocMau.length > 0
                ? 'badge bg-success rounded-pill kb-title-count'
                : 'badge bg-secondary-subtle text-secondary rounded-pill kb-title-count';
        }
    }

    function renderThuocTable(focusTarget = null) {
        syncThuocThead();

        const tbody = document.getElementById('pd-tbody-thuoc');
        if (!tbody) return;

        if (inlineSelectThuocInstance) {
            inlineSelectThuocInstance.destroy();
            inlineSelectThuocInstance = null;
        }
        if (replacementSelectCleanup) {
            replacementSelectCleanup();
            replacementSelectCleanup = null;
        }
        if (replacementSelectThuocInstance) {
            try { replacementSelectThuocInstance.destroy(); } catch (_) { }
            replacementSelectThuocInstance = null;
        }

        thuocDvtSelectInstances.forEach(instance => {
            try { instance?.destroy?.(); } catch (_) { }
        });
        thuocDvtSelectInstances = [];

        tbody.innerHTML = '';

        // 1. Render các dòng thuốc đã có
        listThuocMau.forEach((t, index) => {
            const realIdx = index;
            const tr = document.createElement('tr');
            tr.className = 'align-middle';

            const valSang = (t.Sang !== undefined && t.Sang !== null && t.Sang !== '' && t.Sang !== '0' && t.Sang !== 0) ? t.Sang : '';
            const valTrua = (t.Trua !== undefined && t.Trua !== null && t.Trua !== '' && t.Trua !== '0' && t.Trua !== 0) ? t.Trua : '';
            const valChieu = (t.Chieu !== undefined && t.Chieu !== null && t.Chieu !== '' && t.Chieu !== '0' && t.Chieu !== 0) ? t.Chieu : '';
            const valToi = (t.Toi !== undefined && t.Toi !== null && t.Toi !== '' && t.Toi !== '0' && t.Toi !== 0) ? t.Toi : '';

            tr.innerHTML = `
                <td class="col-sticky-stt text-center text-muted fw-bold">${index + 1}</td>
                <td class="col-sticky-thuoc ${phacDoEditMode ? 'pd-drug-click-cell' : ''}" title="${phacDoEditMode ? 'Nhấp để đổi thuốc' : ''}">
                    <div class="fw-bold text-primary px-1 text-truncate pd-drug-current-name" title="${t.TenThuoc || ''}">${t.TenThuoc || ''}</div>
                </td>
                <td>
                    <div class="text-muted small px-1 text-truncate" title="${t.HoatChat || ''}">${t.HoatChat || ''}</div>
                </td>
                <td class="text-center">
                    <input type="number" class="form-control form-control-sm form-table text-center inp-sngay" value="${t.SoNgay || 1}" min="1" max="90" />
                </td>
                <td class="text-center small">${t.DonViTinh || 'Viên'}</td>
                <td class="text-center">
                    <input type="text" inputmode="decimal" pattern="[0-9]*[.,]?[0-9]*" class="form-control form-control-sm form-table text-center inp-sang" value="${valSang}" />
                </td>
                <td class="text-center">
                    <input type="text" inputmode="decimal" pattern="[0-9]*[.,]?[0-9]*" class="form-control form-control-sm form-table text-center inp-trua" value="${valTrua}" />
                </td>
                <td class="text-center">
                    <input type="text" inputmode="decimal" pattern="[0-9]*[.,]?[0-9]*" class="form-control form-control-sm form-table text-center inp-chieu" value="${valChieu}" />
                </td>
                <td class="text-center">
                    <input type="text" inputmode="decimal" pattern="[0-9]*[.,]?[0-9]*" class="form-control form-control-sm form-table text-center inp-toi" value="${valToi}" />
                </td>
                <td class="text-center small">${t.DuongDung || 'Uống'}</td>
                <td>
                    <input type="text" class="form-control form-control-sm form-table inp-cach-dung" value="${t.CachDung || ''}" />
                </td>
                <td class="text-end small px-1">${Number(t.DonGia || 0).toLocaleString('vi-VN')}</td>
                <td class="text-end fw-bold text-dark px-1 cell-thanh-tien">${Number(t.ThanhTien || 0).toLocaleString('vi-VN')}</td>
                <td class="col-sticky-dvt-dung p-0">
                    <select id="pd-dvt-dung-${index}" class="form-select form-select-sm form-table inp-dvt-dung">
                        <option value="${t.DonViTinhDung || t.DonViTinh || 'Viên'}" selected>${t.DonViTinhDung || t.DonViTinh || 'Viên'}</option>
                    </select>
                </td>
                <td class="col-sticky-sl p-0">
                    <input type="number" step="any" class="form-control form-control-sm form-table text-center fw-bold text-primary inp-sl" min="0" value="${t.SoLuong || 1}" />
                </td>
                <td class="col-sticky-xoa text-center">
                    <button type="button" class="btn btn-sm btn-link btn-xoa-row p-0 btn-xoa-t" title="Xóa thuốc"><i class="bi bi-trash"></i></button>
                </td>
            `;

            const inpSngay = tr.querySelector('.inp-sngay');
            const inpSang = tr.querySelector('.inp-sang');
            const inpTrua = tr.querySelector('.inp-trua');
            const inpChieu = tr.querySelector('.inp-chieu');
            const inpToi = tr.querySelector('.inp-toi');
            const inpCachDung = tr.querySelector('.inp-cach-dung');
            const inpSl = tr.querySelector('.inp-sl');
            const inpDvtDung = tr.querySelector('.inp-dvt-dung');
            const cellThanhTien = tr.querySelector('.cell-thanh-tien');
            const cellThuoc = tr.querySelector('.col-sticky-thuoc');

            cellThuoc?.addEventListener('click', () => moChonThayThuoc(cellThuoc, t, realIdx));

            if (inpDvtDung) {
                const dvtSelect = initRemoteTomSelect(inpDvtDung, 'don_vi_tinh', {
                    valueField: 'ten',
                    labelField: 'ten',
                    searchField: ['ten'],
                    showCodeInItem: false,
                    localSearch: true,
                    localSearchTop: 1000,
                    dropdownParent: 'body',
                    placeholder: '-- ĐVT --',
                    render: {
                        option: (data, escape) => `<div class="kb-dvt-option">${escape(data.ten || '')}</div>`,
                        item: (data, escape) => `<div class="kb-dvt-item">${escape(data.ten || '')}</div>`
                    }
                }, (item) => {
                    if (!item?.ten) return;
                    t.DonViTinhDung = item.ten;
                    t.IDDonViTinhDung = item.id || null;
                });

                if (dvtSelect) {
                    dvtSelect.dropdown?.classList.add('kb-dvt-dung-dropdown');
                    dvtSelect.wrapper?.classList.add('kb-dvt-dung-select');
                    thuocDvtSelectInstances.push(dvtSelect);
                    if (t.DonViTinhDung || t.DonViTinh) {
                        dvtSelect.setValue(t.DonViTinhDung || t.DonViTinh, true);
                    }
                }
            }

        // Chặn ký tự không phải số ở liều Sáng/Trưa/Chiều/Tối; vẫn cho phép số thập phân (0.5 hoặc 0,5).
        [inpSang, inpTrua, inpChieu, inpToi].forEach(inp => {
            if (!inp) return;
            inp.addEventListener('beforeinput', (e) => {
                if (e.inputType === 'insertText' && e.data && !/^[0-9.,]+$/.test(e.data)) {
                    e.preventDefault();
                }
            });
            inp.addEventListener('input', () => {
                let value = inp.value.replace(/,/g, '.').replace(/[^0-9.]/g, '');
                const dotIndex = value.indexOf('.');
                if (dotIndex >= 0) {
                    value = value.slice(0, dotIndex + 1) + value.slice(dotIndex + 1).replace(/\./g, '');
                }
                if (inp.value !== value) inp.value = value;
            });
        });

            // Bôi đen khi focus để gõ đè số mới siêu tốc
            [inpSang, inpTrua, inpChieu, inpToi, inpSngay, inpSl, inpCachDung].forEach(inp => {
                inp?.addEventListener('focus', () => inp.select());
            });

            const recomputeRow = () => {
                const s = parseFloat(inpSang?.value) || 0;
                const trua = parseFloat(inpTrua?.value) || 0;
                const c = parseFloat(inpChieu?.value) || 0;
                const toi = parseFloat(inpToi?.value) || 0;
                const ngay = parseInt(inpSngay?.value) || 1;
                const sumLieu = s + trua + c + toi;
                const sl = (sumLieu === 0 ? 1 : sumLieu) * ngay;

                t.Sang = inpSang?.value ? inpSang.value.trim() : '0';
                t.Trua = inpTrua?.value ? inpTrua.value.trim() : '0';
                t.Chieu = inpChieu?.value ? inpChieu.value.trim() : '0';
                t.Toi = inpToi?.value ? inpToi.value.trim() : '0';
                t.SoNgay = ngay;
                t.SoLuong = sl;
                t.ThanhTien = sl * (parseFloat(t.DonGia) || 0);
                t.LieuDung = `${t.Sang}-${t.Trua}-${t.Chieu}-${t.Toi}`;

                if (inpSl) inpSl.value = sl;
                if (cellThanhTien) cellThanhTien.innerText = Number(t.ThanhTien).toLocaleString('vi-VN');

                updateThuocTotals();
            };

            inpSngay?.addEventListener('input', recomputeRow);
            inpSang?.addEventListener('input', recomputeRow);
            inpTrua?.addEventListener('input', recomputeRow);
            inpChieu?.addEventListener('input', recomputeRow);
            inpToi?.addEventListener('input', recomputeRow);

            inpSl?.addEventListener('change', (e) => {
                const sl = parseFloat(e.target.value) || 1;
                t.SoLuong = sl;
                t.ThanhTien = sl * (parseFloat(t.DonGia) || 0);
                if (cellThanhTien) cellThanhTien.innerText = Number(t.ThanhTien).toLocaleString('vi-VN');
                updateThuocTotals();
            });

            inpCachDung?.addEventListener('input', (e) => {
                t.CachDung = e.target.value;
            });

            // Điều hướng Enter: Số ngày -> Sáng -> Trưa -> Chiều -> Tối -> Cách dùng -> dòng thuốc mới.
            inpSngay?.addEventListener('keydown', (e) => {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    inpSang?.focus();
                    inpSang?.select();
                }
            });
            inpSang?.addEventListener('keydown', (e) => {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    inpTrua?.focus();
                    inpTrua?.select();
                }
            });
            inpTrua?.addEventListener('keydown', (e) => {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    inpChieu?.focus();
                    inpChieu?.select();
                }
            });
            inpChieu?.addEventListener('keydown', (e) => {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    inpToi?.focus();
                    inpToi?.select();
                }
            });
            inpToi?.addEventListener('keydown', (e) => {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    inpCachDung?.focus();
                    inpCachDung?.select();
                }
            });
            inpCachDung?.addEventListener('keydown', (e) => {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    if (inlineSelectThuocInstance) {
                        inlineSelectThuocInstance.focus();
                        inlineSelectThuocInstance.open();
                    }
                }
            });

            tr.querySelector('.btn-xoa-t')?.addEventListener('click', () => {
                listThuocMau.splice(realIdx, 1);
                renderThuocTable();
            });

            tbody.appendChild(tr);
        });

        // 2. Dòng chọn thuốc chỉ là dòng nhập, chưa tính là một dòng toa.
        const blankTr = document.createElement('tr');
        blankTr.className = 'row-new-entry align-middle';
        blankTr.innerHTML = `
            <td class="text-center"></td>
            <td class="col-sticky-thuoc p-0">
                <select id="pd-inline-select-thuoc" class="form-table w-100"></select>
            </td>
            <td></td>
            <td></td>
            <td></td>
            <td></td>
            <td></td>
            <td></td>
            <td></td>
            <td></td>
            <td></td>
            <td></td>
            <td></td>
            <td class="col-sticky-dvt-dung"></td>
            <td class="col-sticky-sl"></td>
            <td class="col-sticky-xoa"></td>
        `;
        tbody.appendChild(blankTr);

        // Khởi tạo TomSelect cho dòng trống: dropdown gắn vào body không bao giờ bị che
        const inlineSelectEl = document.getElementById('pd-inline-select-thuoc');
        if (inlineSelectEl) {
            const maLoaiToa = document.getElementById('pd-loai-toa')?.value || 'c';
            inlineSelectThuocInstance = initPhacDoDrugPicker(inlineSelectEl, maLoaiToa, (item) => {
                if (!item || !item.id) return;

                const soNgayDefault = parseInt(document.getElementById('pd-toa-so-ngay')?.value) || 3;
                const sang = 1;
                const trua = 0;
                const chieu = 1;
                const toi = 0;
                const sumLieu = sang + trua + chieu + toi;
                const sl = (sumLieu === 0 ? 1 : sumLieu) * soNgayDefault;
                const donGia = parseFloat(item.gia_ban || item.don_gia) || 0;
                const thanhTien = sl * donGia;
                const cachDung = (item.duong_dung && item.duong_dung.toLowerCase().includes('bôi'))
                    ? 'Bôi ngoài da'
                    : ((item.duong_dung && item.duong_dung.toLowerCase().includes('nhỏ'))
                        ? 'Nhỏ mắt/tai'
                        : 'Uống sau ăn');

                listThuocMau.push({
                    IDThuoc: item.id,
                    MaThuoc: item.ma || '',
                    TenThuoc: item.ten,
                    HoatChat: item.hoat_chat || '',
                    DonViTinh: item.don_vi_tinh || 'Viên',
                    IDDonViTinhDung: item.id_don_vi_tinh || null,
                    DonViTinhDung: item.don_vi_tinh || 'Viên',
                    DuongDung: item.duong_dung || 'Uống',
                    SoNgay: soNgayDefault,
                    Sang: '1',
                    Trua: '0',
                    Chieu: '1',
                    Toi: '0',
                    LieuDung: `${sang}-${trua}-${chieu}-${toi}`,
                    CachDung: cachDung,
                    SoLuong: sl,
                    DonGia: donGia,
                    ThanhTien: thanhTien,
                    MaLoaiToaThuoc: String(item.ma_loai_toa_thuoc || maLoaiToa || 'c').toLowerCase()
                });

                renderThuocTable({ focusIndex: listThuocMau.length - 1, focusField: 'sngay' });

                const toaCollapse = document.getElementById('pd-collapse-toa-thuoc');
                if (toaCollapse && !toaCollapse.classList.contains('show')) {
                    new bootstrap.Collapse(toaCollapse, { show: true });
                }
            });
        }

        updateThuocTotals();
        capRenderedTableRows('.pd-thuoc-table-wrap', '#pd-table-thuoc', 5);

        // Tự động focus vào ô liều dùng của dòng mới thêm
        if (focusTarget && focusTarget.focusIndex !== undefined) {
            setTimeout(() => {
                const rows = tbody.querySelectorAll('tr:not(.row-new-entry)');
                const targetRow = rows[focusTarget.focusIndex];
                if (targetRow) {
                    const inp = targetRow.querySelector(`.inp-${focusTarget.focusField || 'sang'}`);
                    if (inp) {
                        inp.focus();
                        inp.select();
                    }
                }
            }, 50);
        }
    }

    // ================= IN DANH SÁCH =================
    async function inDanhSachPhacDo() {
        let danhSach = currentDanhSachPhacDo;
        if (!danhSach || danhSach.length === 0) {
            const tuKhoa = document.getElementById('pd-filter-tu-khoa')?.value.trim() || '';
            const res = await apiGet('/api/phac_do/danh_sach', { tu_khoa: tuKhoa });
            danhSach = (res.status === 200 && Array.isArray(res.data)) ? res.data : [];
        }

        if (!danhSach || danhSach.length === 0) {
            showToast('warning', 'Không có phác đồ để in.');
            return;
        }

        const rows = danhSach.map((pd, index) => `
            <tr>
                <td class="text-center">${index + 1}</td>
                <td>${pd.ma_phac_do || ''}</td>
                <td>${pd.ten_phac_do || ''}</td>
            </tr>`).join('');

        const html = `<!doctype html>
<html lang="vi">
<head>
    <meta charset="utf-8" />
    <title>Danh sách phác đồ</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 24px; color: #111827; }
        h2 { text-align: center; margin: 0 0 4px; color: #0284c7; }
        .subtitle { text-align: center; margin-bottom: 18px; color: #64748b; font-size: 13px; }
        table { width: 100%; border-collapse: collapse; font-size: 13px; }
        th, td { border: 1px solid #334155; padding: 6px 8px; }
        th { background: #e0f2fe; color: #0c4a6e; text-align: center; }
        .text-center { text-align: center; }
        @media print { body { margin: 12mm; } }
    </style>
</head>
<body>
    <h2>DANH SÁCH PHÁC ĐỒ ĐIỀU TRỊ</h2>
    <div class="subtitle">Ngày in: ${new Date().toLocaleDateString('vi-VN')}</div>
    <table>
        <thead>
            <tr>
                <th style="width: 60px;">STT</th>
                <th style="width: 180px;">Mã phác đồ</th>
                <th>Tên phác đồ</th>
            </tr>
        </thead>
        <tbody>${rows}</tbody>
    </table>
    <script>window.onload = function(){ window.print(); setTimeout(function(){ window.close(); }, 300); };</script>
</body>
</html>`;

        const printWindow = window.open('', '_blank', 'width=900,height=700');
        if (!printWindow) {
        showToast('error', 'Trình duyệt đang chặn cửa sổ in.');
            return;
        }
        printWindow.document.open();
        printWindow.document.write(html);
        printWindow.document.close();
    }

    // ================= SỰ KIỆN NÚT VÀ FORM =================
    function bindEvents() {
        document.getElementById('btn-pd-them-moi')?.addEventListener('click', resetFormPhacDo);
        document.getElementById('btn-pd-in-ds')?.addEventListener('click', inDanhSachPhacDo);
        document.getElementById('btn-pd-lam-moi')?.addEventListener('click', resetFormPhacDo);

        document.getElementById('btn-pd-tim-kiem')?.addEventListener('click', () => {
            pdCurrentPage = 1;
            loadDanhSachPhacDo();
        });
        document.getElementById('btn-pd-reload')?.addEventListener('click', () => {
            pdCurrentPage = 1;
            loadDanhSachPhacDo();
        });
        document.getElementById('pd-filter-tu-khoa')?.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
                e.preventDefault();
                pdCurrentPage = 1;
                loadDanhSachPhacDo();
            }
        });

        // Thay đổi SNgày ở footer -> cập nhật toàn bộ thuốc trong đơn mẫu
        document.getElementById('pd-toa-so-ngay')?.addEventListener('change', (e) => {
            const newNgay = parseInt(e.target.value) || 1;
            if (newNgay < 1) return;
            listThuocMau.forEach(t => {
                t.SoNgay = newNgay;
                const s = parseFloat(t.Sang) || 0;
                const trua = parseFloat(t.Trua) || 0;
                const c = parseFloat(t.Chieu) || 0;
                const toi = parseFloat(t.Toi) || 0;
                const sumLieu = s + trua + c + toi;
                t.SoLuong = (sumLieu === 0 ? 1 : sumLieu) * newNgay;
                t.ThanhTien = t.SoLuong * (parseFloat(t.DonGia) || 0);
            });
            renderThuocTable();
        });

        // Nút Lưu phác đồ
        document.getElementById('btn-pd-luu')?.addEventListener('click', async () => {
            if (!phacDoEditMode) return;
            const ma = document.getElementById('pd-ma').value.trim();
            const ten = document.getElementById('pd-ten').value.trim();
            if (!ma || !ten) {
                showToast('warning', 'Nhập mã và tên phác đồ.');
                return;
            }

            const soBenhChinh = listIcd10Mau.filter(icd => icd.benh_chinh === true).length;
            if (soBenhChinh !== 1) {
                showToast('warning', 'Chọn đúng 1 bệnh chính.');
                document.getElementById('pd-section-chan-doan')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
                selectIcd10Instance?.focus?.();
                return;
            }

            const trieuChung = document.getElementById('pd-trieu-chung')?.value.trim() || null;

            // Chuẩn hóa payload danh sách chỉ định
            const chiDinhPayload = listClsMau.map((c, idx) => ({
                IDDichVu: c.IDDichVu,
                SoLuong: parseFloat(c.SoLuong) || 1,
                DonGia: parseFloat(c.DonGia) || 0,
                GuiNgoai: c.GuiNgoai === true,
                NoiGuiNgoai: c.NoiGuiNgoai || '',
                GhiChu: c.GhiChu || '',
                ThuTu: idx + 1
            }));

            // Chuẩn hóa payload danh sách thuốc
            const thuocPayload = listThuocMau.map((t, idx) => ({
                IDThuoc: t.IDThuoc,
                IDDonViTinhDung: t.IDDonViTinhDung || null,
                SoNgay: parseInt(t.SoNgay) || 3,
                Sang: String(t.Sang || '0'),
                Trua: String(t.Trua || '0'),
                Chieu: String(t.Chieu || '0'),
                Toi: String(t.Toi || '0'),
                LieuDung: t.LieuDung || `${t.Sang || 0}-${t.Trua || 0}-${t.Chieu || 0}-${t.Toi || 0}`,
                DuongDung: t.DuongDung || 'Uống',
                CachDung: t.CachDung || '',
                SoLuong: parseFloat(t.SoLuong) || 1,
                DonGia: parseFloat(t.DonGia) || 0,
                ThuTu: idx + 1
            }));

            const payload = {
                id: document.getElementById('pd-id').value ? Number(document.getElementById('pd-id').value) : null,
                ma_phac_do: ma,
                ten_phac_do: ten,
                chan_doan: listIcd10Mau.map((icd, idx) => ({
                    IDICD10: icd.id,
                    BanDau: icd.ban_dau === true,
                    BenhChinh: icd.benh_chinh === true,
                    BenhKhac: icd.benh_khac === true,
                    ThuTu: idx + 1
                })),
                trieu_chung: trieuChung,
                chi_dinh: chiDinhPayload,
                thuoc: thuocPayload
            };

            const res = await apiPost('/api/phac_do/luu', payload);
            if (res.status === 200) {
                showToast('success', res.message || 'Đã lưu phác đồ.');
                const targetId = res.data?.id || selectedPhacDoId;
                await loadDanhSachPhacDo(targetId);
                setPhacDoEditMode(false);
            } else {
                showToast('error', res.message || 'Không lưu được phác đồ.');
            }
        });

        // Nút Xóa phác đồ
        document.getElementById('btn-pd-xoa')?.addEventListener('click', async () => {
            if (!selectedPhacDoId) return;
            const dongY = await hien_thi_xac_nhan({
                tieu_de: 'Xóa phác đồ điều trị',
                noi_dung: 'Bạn có chắc chắn muốn xóa phác đồ điều trị này không?',
                nhan_dong_y: 'Xóa phác đồ',
                lop_nut: 'btn-danger'
            });
            if (!dongY) return;

            const res = await apiPost('/api/phac_do/xoa', { id: selectedPhacDoId });
            if (res.status === 200) {
                showToast('success', res.message || 'Đã xóa phác đồ.');
                resetFormPhacDo();
                await loadDanhSachPhacDo();
            } else {
                showToast('error', res.message || 'Không xóa được phác đồ.');
            }
        });
    }
})();
