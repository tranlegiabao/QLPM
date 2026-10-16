/**
 * khambenh.js - Module quản lý nghiệp vụ và giao diện Khám bệnh
 */
let selectedIdVaoVien = null;
let selectedDaLuuKham = false;
let selectedIdBenhNhan = null;
let selectedPatientStatus = null;
let userCanEditKham = false;
let selectedPatientCanEdit = true;
let khamReadOnlyObserver = null;
const khamControlDisabledStates = new WeakMap();
let isSwitchingPatient = false;
let isCompletingKham = false;
let isKhamDirty = false;
let saveOutcomeUnknown = false;
let selectPhacDoInstance = null;
let currentPhacDoId = null;
let currentPhacDoMa = '';
let currentPhacDoTen = '';
let selectIcd10Instance = null;
let selectDichVuInstance = null;
let inlineSelectThuocInstance = null;
let toaReplacementSelectInstance = null;
let toaReplacementCleanup = null;
let toaDvtSelectInstances = [];
let toaDateTimePickerInstances = [];
let chiDinhDateTimePickerInstances = [];
let currentToaTab = 'toa_chinh';
let kbDataList = [];
let kbServerTotal = 0;
let kbCurrentPage = 1;
let kbPageSize = 10;
let kbPagination = null;

// Bộ nhớ client-side cho lượt khám đang chọn
let currentVitals = {};
let listChanDoan = [];
let listChiDinh = [];
let listToaThuoc = [];
let currentSelectedPatient = null;
let currentLichSuList = [];
let selectedLichSuLanKham = null;
let lichSuBenhNhanId = null;
let lichSuCurrentPage = 1;
let lichSuPageSize = 10;
let lichSuServerTotal = 0;
let lichSuPagination = null;
let lichSuSearchTimer = null;
let lichSuDetailRequestId = 0;

// Thông tin cơ sở KCB hiện tại (fetch từ API khi init)
let currentCskcbInfo = null;
let toaStockCheckTimer = null;
let toaStockCheckRequestId = 0;
const kbDrugCatalogCache = new Map();
const KB_DRUG_CACHE_TTL_MS = 60 * 1000;
const KB_DRUG_CACHE_MAX = 80;

// Không chèn dòng cảnh báo dưới tên thuốc: nền đỏ của dòng thể hiện tình trạng tồn kho.
function applyToaStockIndicators() {
    const invalidStates = new Set(['insufficient', 'no_warehouse', 'no_conversion']);
    listToaThuoc.forEach((t, index) => {
        const row = document.querySelector(`#kb-tbody-toa-thuoc tr[data-stock-index="${index}"]`);
        if (!row) return;
        row.classList.toggle('kb-stock-insufficient', invalidStates.has(t.ton_trang_thai));
    });
}

async function hienThiCanhBaoTonToaThuoc(thieu) {
    const rows = Array.isArray(thieu) ? thieu : [];
    if (!rows.length) return;

    const noiDung = rows.slice(0, 5).map(t => {
        const ten = t.ten_thuoc || t.ma_thuoc || 'Thuốc';
        const dvt = t.don_vi_tinh ? ' ' + t.don_vi_tinh : '';
        const trangThai = String(t.ton_trang_thai || '');

        if (trangThai === 'no_warehouse')
            return ten + ': chưa có kho thuốc hoạt động.';
        if (trangThai === 'no_conversion')
            return ten + ': chưa cấu hình quy đổi ĐVT' + dvt + '.';

        const can = formatNumberVN(roundDecimal(Number(t.so_luong || 0), 3));
        const con = formatNumberVN(roundDecimal(Number(t.ton_kha_dung || 0), 3));
        return ten + ': cần ' + can + dvt + ', tồn khả dụng ' + con + dvt + '.';
    }).join('\n');

    const suffix = rows.length > 5 ? '\nVà ' + (rows.length - 5) + ' thuốc khác.' : '';
    const message = noiDung + suffix + '\n\nKhông thể lưu hồ sơ cho tới khi toa thuốc đủ điều kiện tồn kho.';

    if (typeof window.hien_thi_xac_nhan === 'function') {
        await window.hien_thi_xac_nhan({
            tieu_de: 'Cảnh báo tồn kho thuốc',
            noi_dung: message,
            nhan_dong_y: 'Đã hiểu',
            an_nut_khong: true,
            lop_nut: 'btn-warning'
        });
        return;
    }

    showToast('warning', message);
}

async function kiemTraTonToaThuoc({ showWarning = false, warningIndex = null } = {}) {
    if (!selectedPatientCanEdit) return true;

    const danhSach = listToaThuoc
        .map((t, index) => ({
            row_index: index,
            id_thuoc: Number(t.id_thuoc || 0),
            id_don_vi_tinh: Number(t.id_don_vi_tinh_dung || 0) || null,
            so_luong: Math.max(0, Number(t.so_luong || 0))
        }))
        .filter(x => x.id_thuoc > 0);

    if (!danhSach.length) return true;

    const requestId = ++toaStockCheckRequestId;
    try {
        const res = await apiPost('/api/kham_benh/kiem_tra_ton_thuoc', { danh_sach: danhSach });
        if (requestId !== toaStockCheckRequestId) return true;
        if (!res || res.status !== 200 || !Array.isArray(res.data)) {
            if (showWarning) {
                const message = res?.message || 'Không kiểm tra được tồn kho thuốc.';
                if (typeof window.hien_thi_xac_nhan === 'function') {
                    await window.hien_thi_xac_nhan({
                        tieu_de: 'Không kiểm tra được tồn kho',
                        noi_dung: message + '\n\nKhông thể lưu hồ sơ cho tới khi kiểm tra tồn kho thành công.',
                        nhan_dong_y: 'Đã hiểu',
                        an_nut_khong: true,
                        lop_nut: 'btn-warning'
                    });
                } else showToast('warning', message);
            }
            return false;
        }

        const byIndex = new Map(res.data.map(x => [Number(x.row_index), x]));
        listToaThuoc.forEach((t, index) => {
            if (t.da_thu) return;
            const x = byIndex.get(index);
            if (!x) {
                t.ton_trang_thai = 'no_conversion';
                t.ton_kha_dung = 0;
                return;
            }

            t.ton_kha_dung = x.ton_theo_dvt == null ? 0 : Number(x.ton_theo_dvt);
            t.ton_du = x.du_ton === true || Number(x.du_ton) === 1;

            const coKho = x.co_kho === true || Number(x.co_kho) === 1;
            const coQuyDoi = x.co_quy_doi === true || Number(x.co_quy_doi) === 1;
            t.ton_trang_thai = !coKho
                ? 'no_warehouse'
                : !coQuyDoi
                    ? 'no_conversion'
                    : t.ton_du
                        ? 'enough'
                        : 'insufficient';
        });

        applyToaStockIndicators();

        const thieu = listToaThuoc.filter(t => !t.da_thu && ['insufficient', 'no_warehouse', 'no_conversion'].includes(t.ton_trang_thai));
        if (showWarning && thieu.length) {
            const canhBao = Number.isInteger(warningIndex)
                ? thieu.filter(t => listToaThuoc.indexOf(t) === warningIndex)
                : thieu;
            if (canhBao.length) await hienThiCanhBaoTonToaThuoc(canhBao);
        }
        return thieu.length === 0;
    } catch (err) {
        if (requestId !== toaStockCheckRequestId) return true;
        if (showWarning) {
            const message = 'Không kiểm tra được tồn kho thuốc.';
            if (typeof window.hien_thi_xac_nhan === 'function') {
                await window.hien_thi_xac_nhan({
                    tieu_de: 'Không kiểm tra được tồn kho',
                    noi_dung: message + '\n\nKhông thể lưu hồ sơ cho tới khi kiểm tra tồn kho thành công.',
                    nhan_dong_y: 'Đã hiểu',
                    an_nut_khong: true,
                    lop_nut: 'btn-warning'
                });
            } else showToast('warning', message);
        }
        return false;
    }
}

function scheduleToaStockCheck() {
    clearTimeout(toaStockCheckTimer);
    if (!selectedPatientCanEdit || !listToaThuoc.length) return;
    toaStockCheckTimer = setTimeout(() => {
        kiemTraTonToaThuoc().catch(() => { });
    }, 250);
}

async function fetchCskcbHienTai() {
    try {
        const res = await fetch('/api/he_thong/cskcb/hien_tai');
        if (!res.ok) return;
        const json = await res.json();
        if (json?.status === 200 && json?.data) {
            currentCskcbInfo = json.data;
        }
    } catch (e) {
        // Bỏ qua lỗi, sẽ dùng fallback khi in
    }
}

function escapeHtml(str) {
    if (!str) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

function roundDecimal(num, decimals = 3) {
    if (num === null || num === undefined || isNaN(num)) return 0;
    const factor = Math.pow(10, decimals);
    return Math.round((Number(num) + Number.EPSILON) * factor) / factor;
}

function formatKhamDateTime(value) {
    if (!value) return '';

    if (window.moment) {
        let m = moment(value, [
            'DD-MM-YYYY HH:mm',
            'DD/MM/YYYY HH:mm',
            moment.ISO_8601
        ], true);
        if (!m.isValid()) m = moment(value);
        return m.isValid() ? m.format('DD-MM-YYYY HH:mm') : '';
    }

    const d = value instanceof Date ? value : new Date(value);
    if (Number.isNaN(d.getTime())) return '';
    const pad = n => String(n).padStart(2, '0');
    return `${pad(d.getDate())}-${pad(d.getMonth() + 1)}-${d.getFullYear()} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

function getKhamNowDateTime() {
    const d = new Date();
    const pad = n => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
}
function formatKhamDateOnly(value) {
    if (!value) return '';
    if (window.moment) {
        let m = moment(value, ['DD-MM-YYYY HH:mm', 'DD/MM/YYYY HH:mm', 'DD-MM-YYYY', 'DD/MM/YYYY', moment.ISO_8601], true);
        if (!m.isValid()) m = moment(value);
        return m.isValid() ? m.format('DD-MM-YYYY') : '';
    }
    const d = value instanceof Date ? value : new Date(value);
    if (Number.isNaN(d.getTime())) return '';
    const pad = n => String(n).padStart(2, '0');
    return `${pad(d.getDate())}-${pad(d.getMonth() + 1)}-${d.getFullYear()}`;
}

function formatKhamDateWithEllipsis(value) {
    if (!value) return '';
    const dateOnly = formatKhamDateOnly(value);
    return dateOnly ? `${dateOnly}...` : '';
}

function getKhamDateTimePickerPortal() {
    if (!document.body) return null;

    let portal = document.getElementById('kb-kham-datetimepicker-portal');
    if (portal) return portal;

    portal = document.createElement('div');
    portal.id = 'kb-kham-datetimepicker-portal';
    portal.className = 'kb-kham-datetimepicker-portal';
    document.body.appendChild(portal);
    return portal;
}

function initToaDateTimePicker(input, initialValue, onChange, disabled = false, registry = toaDateTimePickerInstances) {
    if (!input || typeof window.initDateTimePicker !== 'function') return null;

    let initialMoment = null;
    if (window.moment) {
        initialMoment = moment(initialValue, [
            'DD-MM-YYYY HH:mm',
            'DD/MM/YYYY HH:mm',
            'DD-MM-YYYY',
            'DD/MM/YYYY',
            moment.ISO_8601
        ], true);
        if (!initialMoment.isValid()) initialMoment = moment();
    }

    const options = {
        useCurrent: false,
        sideBySide: true,
        collapse: false,
        showTodayButton: false,
        showClear: false,
        showClose: false,
        widgetPositioning: {
            horizontal: 'auto',
            vertical: 'auto'
        }
    };

    // Datepicker của bảng phải nằm ngoài vùng table-responsive/#kb-entry-scroll.
    // Portal riêng vừa tránh overflow của bảng, vừa tạo positioning context hợp lệ
    // cho bootstrap-datetimepicker trước khi sự kiện dp.show được phát ra.
    let pickerPortal = null;
    if (window.jQuery) {
        pickerPortal = getKhamDateTimePickerPortal();
        if (pickerPortal) {
            options.widgetParent = window.jQuery(pickerPortal);
        }
    }

    if (initialMoment?.isValid()) {
        options.defaultDate = initialMoment;
    }

    const picker = window.initDateTimePicker(input, options);
    if (!picker) return null;

    registry.push(picker);
    if (disabled) picker.disable?.();

    if (window.jQuery) {
        const $input = window.jQuery(input);
        const $pickerPortal = pickerPortal ? window.jQuery(pickerPortal) : window.jQuery();

        const positionKhamPicker = () => {
            const $widget = $pickerPortal
                .children('.bootstrap-datetimepicker-widget:visible')
                .last();
            if (!$widget.length) return;

            const rect = input.getBoundingClientRect();
            const viewportWidth = document.documentElement.clientWidth || window.innerWidth;
            const viewportHeight = document.documentElement.clientHeight || window.innerHeight;
            const gutter = 8;
            const gap = 4;

            $widget.addClass('kb-kham-datetimepicker');

            const widgetWidth = $widget.outerWidth() || 304;
            const widgetHeight = $widget.outerHeight() || 320;

            let viewportLeft = Math.max(
                gutter,
                Math.min(rect.left, viewportWidth - widgetWidth - gutter)
            );

            const spaceBelow = viewportHeight - rect.bottom;
            const spaceAbove = rect.top;
            const openBelow = spaceBelow >= widgetHeight + gap || spaceBelow >= spaceAbove;

            let viewportTop = openBelow
                ? rect.bottom + gap
                : rect.top - widgetHeight - gap;

            viewportTop = Math.max(
                gutter,
                Math.min(viewportTop, viewportHeight - widgetHeight - gutter)
            );

            // Dùng CSS variables + !important ở stylesheet để chặn hàm place()
            // của bootstrap-datetimepicker ghi đè tọa độ sau khi popup đã mở.
            $widget[0].style.setProperty('--kb-picker-left', `${Math.round(viewportLeft)}px`);
            $widget[0].style.setProperty('--kb-picker-top', `${Math.round(viewportTop)}px`);
        };

        const bindViewportReposition = () => {
            window.jQuery(window)
                .off('resize.kbKhamPicker scroll.kbKhamPicker')
                .on('resize.kbKhamPicker scroll.kbKhamPicker', positionKhamPicker);
        };

        const unbindViewportReposition = () => {
            window.jQuery(window).off('resize.kbKhamPicker scroll.kbKhamPicker');
        };

        $input
            .off('dp.show.kbKhamPicker dp.hide.kbKhamPicker')
            .on('dp.show.kbKhamPicker', () => {
                positionKhamPicker();
                bindViewportReposition();
                window.requestAnimationFrame(() => {
                    positionKhamPicker();
                    window.requestAnimationFrame(positionKhamPicker);
                });
            })
            .on('dp.hide.kbKhamPicker', () => {
                unbindViewportReposition();
                applyEllipsisValue();
            });
    }

    const applyEllipsisValue = () => {
        if (document.activeElement === input) return;
        const dp = window.jQuery ? window.jQuery(input).data('DateTimePicker') : null;
        const m = dp?.date() || initialMoment;
        if (m && m.isValid()) {
            const fullTimeStr = m.format('DD-MM-YYYY HH:mm');
            input.title = fullTimeStr;
            input.value = `${m.format('DD-MM-YYYY')}...`;
        }
    };

    const restoreFullValue = () => {
        const dp = window.jQuery ? window.jQuery(input).data('DateTimePicker') : null;
        const m = dp?.date() || initialMoment;
        if (m && m.isValid()) {
            const fullTimeStr = m.format('DD-MM-YYYY HH:mm');
            input.title = fullTimeStr;
            input.value = fullTimeStr;
        }
    };

    input.addEventListener('focus', restoreFullValue);
    input.addEventListener('blur', applyEllipsisValue);

    const sync = (e) => {
        if (!window.moment) return;
        let valStr = input.value || '';
        let selected = moment(valStr, [
            'DD-MM-YYYY HH:mm',
            'DD/MM/YYYY HH:mm',
            'DD-MM-YYYY...',
            'DD/MM/YYYY...',
            'DD-MM-YYYY',
            'DD/MM/YYYY'
        ], true);
        if (!selected.isValid() && e?.date) {
            selected = moment(e.date);
        }
        if (!selected.isValid()) return;
        initialMoment = selected.clone();
        const fullTimeStr = selected.format('DD-MM-YYYY HH:mm');
        const isoStr = selected.format('YYYY-MM-DDTHH:mm:ss');
        input.title = fullTimeStr;
        if (document.activeElement !== input) {
            input.value = `${selected.format('DD-MM-YYYY')}...`;
        } else {
            input.value = fullTimeStr;
        }
        if (typeof onChange === 'function') {
            onChange(fullTimeStr, isoStr);
        }
    };
    if (window.jQuery) {
        window.jQuery(input).off('dp.change.kbKhamPicker').on('dp.change.kbKhamPicker', (e) => {
            sync(e);
            if (document.activeElement !== input) {
                applyEllipsisValue();
            }
        });
    }
    input.addEventListener('input', sync);
    input.addEventListener('change', sync);

    applyEllipsisValue();

    return picker;
}

function formatCurrencyVN(val, decimals = 0) {
    if (val === null || val === undefined || isNaN(val)) return '0 đ';
    const rounded = roundDecimal(val, decimals);
    return rounded.toLocaleString('en-US', {
        minimumFractionDigits: 0,
        maximumFractionDigits: decimals
    }) + ' đ';
}

function formatNumberVN(val, decimals = 0) {
    if (val === null || val === undefined || isNaN(val)) return '0';
    const rounded = roundDecimal(val, decimals);
    return rounded.toLocaleString('en-US', {
        minimumFractionDigits: 0,
        maximumFractionDigits: decimals
    });
}

function tachHuyetAp(value) {
    const raw = String(value || '').trim();
    if (!raw) return { tamThu: '', tamTruong: '' };
    const parts = raw.split(/[\/-]/).map(x => x.trim()).filter(Boolean);
    return { tamThu: parts[0] || '', tamTruong: parts[1] || '' };
}

function ghepHuyetAp(tamThu, tamTruong) {
    const tt = tamThu === null || tamThu === undefined ? '' : String(tamThu).trim();
    const tr = tamTruong === null || tamTruong === undefined ? '' : String(tamTruong).trim();
    if (tt && tr) return `${tt}/${tr}`;
    return tt || tr || '';
}

function setHuyetApInputs(value) {
    const parts = tachHuyetAp(value);
    const tamThuEl = document.getElementById('sh-huyet-ap-tam-thu');
    const tamTruongEl = document.getElementById('sh-huyet-ap-tam-truong');
    const canonicalEl = document.getElementById('sh-huyet-ap');
    if (tamThuEl) tamThuEl.value = parts.tamThu;
    if (tamTruongEl) tamTruongEl.value = parts.tamTruong;
    if (canonicalEl) canonicalEl.value = ghepHuyetAp(parts.tamThu, parts.tamTruong);
}

function syncHuyetApValue() {
    const canonicalEl = document.getElementById('sh-huyet-ap');
    const value = ghepHuyetAp(
        document.getElementById('sh-huyet-ap-tam-thu')?.value || '',
        document.getElementById('sh-huyet-ap-tam-truong')?.value || ''
    );
    if (canonicalEl) canonicalEl.value = value;
    return value;
}

function capRenderedTableRows(wrapperSelector) {
    const wrapper = document.querySelector(wrapperSelector);
    if (!wrapper) return;
    wrapper.classList.remove('table-cap-active');
    wrapper.style.setProperty('max-height', 'none', 'important');
    wrapper.style.removeProperty('height');
}

// Khởi tạo
document.addEventListener('DOMContentLoaded', async () => {
    setupPrescriptionTypeSelector();
    setupSymptomCollapse();
    try { sessionStorage.removeItem('qlpm_kb_drafts_v1'); } catch (e) { console.warn('Không xóa được nháp khám cũ:', e); }
    initFilters();
    initTomSelects();
    initEvents();
    initSectionNavigation();
    initVietTatTrieuChung();
    initKhamKeyboardNavigation();
    initPatientListHorizontalScrollState();

    const root = document.getElementById('kham-benh-root');
    userCanEditKham = root?.dataset.canSuaKham === 'true';
    const targetIdVaoVien = root ? root.getAttribute('data-target-id-vaovien') : null;

    // Nạp thông tin cơ sở KCB hiện tại để dùng khi in toa
    fetchCskcbHienTai();

    await loadDanhSachBenhNhan(targetIdVaoVien || null);
});


function initPatientListHorizontalScrollState() {
    const wrap = document.querySelector('.kham-benh-table-wrap');
    if (!wrap) return;

    const updateScrollState = () => {
        wrap.classList.toggle('kb-horizontal-scrolled', wrap.scrollLeft > 1);
    };

    wrap.addEventListener('scroll', updateScrollState, { passive: true });
    updateScrollState();
}

function setKhamPatientEditing(status) {
    selectedPatientStatus = Number(status);
    selectedPatientCanEdit = selectedPatientStatus !== 2 && userCanEditKham;

    const root = document.getElementById('kb-detail-container');
    if (!root) return;

    root.classList.toggle('kb-readonly-mode', !selectedPatientCanEdit);
    root.setAttribute('aria-readonly', String(!selectedPatientCanEdit));

    root.querySelector('#kb-readonly-notice')?.remove();

    if (root.dataset.readOnlyToastBound !== 'true') {
        root.dataset.readOnlyToastBound = 'true';
        root.addEventListener('pointerdown', event => {
            if (selectedPatientCanEdit) return;
            const target = event.target instanceof Element
                ? event.target.closest('input:not([type="hidden"]), textarea, select, .ts-control, button')
                : null;
            if (!target || ['btn-kb-luu', 'btn-kb-kham-xong', 'btn-kb-in-chi-dinh', 'btn-kb-in-toa-thuoc', 'btn-kb-ky-so-toa', 'btn-kb-ky-so-chi-dinh'].includes(target.id) || target.classList.contains('btn-kq-cls')) return;
            event.preventDefault();
            showToast('warning', 'Lượt khám đã xong, không thể sửa.');
        }, true);
    }

    const updateControls = (container) => {
        container.querySelectorAll('input, textarea, select, button').forEach(el => {
            if (['btn-kb-luu', 'btn-kb-kham-xong', 'btn-kb-in-chi-dinh', 'btn-kb-in-toa-thuoc', 'btn-kb-ky-so-toa', 'btn-kb-ky-so-chi-dinh'].includes(el.id) || el.classList.contains('btn-kq-cls')) return;
            if (!selectedPatientCanEdit) {
                if (!khamControlDisabledStates.has(el)) khamControlDisabledStates.set(el, el.disabled);
                el.disabled = true;
                el.tomselect?.disable?.();
            } else if (khamControlDisabledStates.has(el)) {
                el.disabled = khamControlDisabledStates.get(el);
                khamControlDisabledStates.delete(el);
                if (!el.disabled) el.tomselect?.enable?.();
            }
        });
    };

    updateControls(root);
    if (!khamReadOnlyObserver) {
        khamReadOnlyObserver = new MutationObserver(records => {
            if (!selectedPatientCanEdit && records.some(record => record.addedNodes.length)) updateControls(root);
        });
        khamReadOnlyObserver.observe(root, { childList: true, subtree: true });
    }

    [selectPhacDoInstance, selectIcd10Instance, selectDichVuInstance, inlineSelectThuocInstance, ...toaDvtSelectInstances]
        .forEach(instance => {
            if (!instance) return;
            if (selectedPatientCanEdit) instance.enable?.();
            else instance.disable?.();
        });

    updateKhamSaveActionState();
}

function initFilters() {
    initDatePicker('#kb-filter-ngay', { defaultDate: 'today' });
    initDatePicker('#kb-ngay-tai-kham', { minDate: 'today' });

    const elFilterNgay = document.getElementById('kb-filter-ngay');
    if (elFilterNgay && (!elFilterNgay.value || elFilterNgay.value === '__-__-____')) {
        elFilterNgay.value = formatDateVN(new Date());
    }

    document.querySelectorAll('input[name="kb-filter-trang-thai"]').forEach(r => {
        r.addEventListener('change', () => {
            loadDanhSachBenhNhan();
        });
    });

    document.getElementById('btn-kb-tim-kiem')?.addEventListener('click', () => {
        loadDanhSachBenhNhan();
    });
    document.getElementById('btn-kb-reload')?.addEventListener('click', () => {
        loadDanhSachBenhNhan();
    });
    document.getElementById('kb-filter-tu-khoa')?.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
            e.preventDefault();
            loadDanhSachBenhNhan();
        }
    });

    // Tính toán BMI tự động
    const calcBmi = () => {
        const hCm = parseFloat(document.getElementById('sh-chieu-cao')?.value);
        const wKg = parseFloat(document.getElementById('sh-can-nang')?.value);
        const bmiInput = document.getElementById('sh-bmi');
        if (hCm > 0 && wKg > 0) {
            const hM = hCm / 100;
            const bmi = (wKg / (hM * hM)).toFixed(1);
            if (bmiInput) bmiInput.value = bmi;
        } else {
            if (bmiInput) bmiInput.value = '';
        }
    };
    document.getElementById('sh-chieu-cao')?.addEventListener('input', () => { markDirty(); calcBmi(); });
    document.getElementById('sh-can-nang')?.addEventListener('input', () => { markDirty(); calcBmi(); });

    // Chỉ các vùng nhập nghiệp vụ mới được sửa; thông tin BN phía trên chỉ để hiển thị.
    ['sh-mach', 'sh-nhiet-do', 'sh-nhip-tho', 'sh-spo2', 'kb-trieu-chung', 'kb-ngay-tai-kham', 'kb-dan-do', 'kb-toa-so-ngay'].forEach(id => {
        document.getElementById(id)?.addEventListener('input', () => markDirty());
    });
    ['sh-huyet-ap-tam-thu', 'sh-huyet-ap-tam-truong'].forEach(id => {
        document.getElementById(id)?.addEventListener('input', () => {
            syncHuyetApValue();
            markDirty();
        });
    });
    document.getElementById('kb-chk-tai-kham')?.addEventListener('change', () => markDirty());
}

function initKhamKeyboardNavigation() {
    const root = document.getElementById('kb-detail-container');
    if (!root) return;

    const getInputs = () => Array.from(root.querySelectorAll(
        'input:not([type="hidden"]):not([type="button"]):not([type="submit"]):not([type="reset"]):not([readonly]):not([disabled]),' +
        'textarea:not([readonly]):not([disabled]),select:not([disabled])'
    )).filter(el => {
        if (!(el instanceof HTMLElement)) return false;
        if (el.closest('.d-none,[hidden]')) return false;
        if (el.matches('.inp-ngay-ke, .inp-ngay-ke-new')) return false;
        if (el.classList.contains('ts-hidden-accessible') || el.classList.contains('tomselected')) return false;
        if (el.tabIndex < 0) return false;
        const style = window.getComputedStyle(el);
        return style.display !== 'none' && style.visibility !== 'hidden' && el.getClientRects().length > 0;
    });

    const focusField = (el) => {
        if (!el) return;
        el.focus({ preventScroll: true });
        if (typeof el.select === 'function' && !['checkbox', 'radio'].includes(el.type)) {
            try { el.select(); } catch (_) { }
        }
        el.scrollIntoView({ block: 'nearest', inline: 'nearest' });
    };

    root.addEventListener('keydown', (e) => {
        if (e.defaultPrevented || e.isComposing || e.ctrlKey || e.altKey || e.metaKey) return;
        if (e.key !== 'Tab') return;

        const target = e.target;
        if (!(target instanceof HTMLElement) || !target.matches('input, textarea, select')) return;

        const inputs = getInputs();
        const index = inputs.indexOf(target);
        if (inputs.length === 0) return;

        const direction = e.shiftKey ? -1 : 1;
        if (index < 0) {
            if (!target.matches('.inp-ngay-ke, .inp-ngay-ke-new')) return;
            const position = Node.DOCUMENT_POSITION_FOLLOWING;
            const nearbyInputs = inputs.filter(input => {
                const relation = target.compareDocumentPosition(input);
                return direction > 0
                    ? Boolean(relation & position)
                    : Boolean(relation & Node.DOCUMENT_POSITION_PRECEDING);
            });
            e.preventDefault();
            const nextInput = direction > 0
                ? nearbyInputs[0]
                : nearbyInputs[nearbyInputs.length - 1];
            focusField(nextInput || inputs[direction > 0 ? 0 : inputs.length - 1]);
            return;
        }

        e.preventDefault();
        for (let step = 1; step <= inputs.length; step++) {
            const nextIndex = (index + (direction * step) + inputs.length) % inputs.length;
            focusField(inputs[nextIndex]);
            break;
        }
    });
}

function initSectionNavigation() {
    const scroller = document.getElementById('kb-entry-scroll');
    const buttons = Array.from(document.querySelectorAll('.kb-section-nav-btn'));
    if (!scroller || buttons.length === 0) return;

    // Khởi tạo tooltip chỉ dẫn rõ ràng cho bác sĩ
    if (typeof bootstrap !== 'undefined' && bootstrap.Tooltip) {
        buttons.forEach(btn => {
            new bootstrap.Tooltip(btn, { boundary: 'window' });
        });
    }

    const sections = buttons
        .map(btn => document.getElementById(btn.dataset.target))
        .filter(Boolean);

    buttons.forEach(btn => {
        btn.addEventListener('click', () => {
            scrollToKhamSection(btn.dataset.target);
        });
    });

    let ticking = false;
    scroller.addEventListener('scroll', () => {
        if (ticking) return;
        ticking = true;
        requestAnimationFrame(() => {
            capNhatIconKhamDangActive(scroller, sections, buttons);
            ticking = false;
        });
    }, { passive: true });

    capNhatIconKhamDangActive(scroller, sections, buttons);
}

function scrollToKhamSection(targetId, smooth = true) {
    const scroller = document.getElementById('kb-entry-scroll');
    const target = document.getElementById(targetId);
    if (!scroller || !target) return;

    const scrollerRect = scroller.getBoundingClientRect();
    const targetRect = target.getBoundingClientRect();
    const stickyHeight = document.getElementById('kb-section-thong-tin')?.getBoundingClientRect().height || 0;
    const top = scroller.scrollTop + (targetRect.top - scrollerRect.top) - (targetId === 'kb-section-thong-tin' ? 6 : stickyHeight + 12);

    scroller.scrollTo({
        top: Math.max(0, top),
        behavior: smooth ? 'smooth' : 'auto'
    });

    document.querySelectorAll('.kb-section-nav-btn').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.target === targetId);
    });
}

function resetKhamSectionNavigation() {
    const scroller = document.getElementById('kb-entry-scroll');
    if (scroller) scroller.scrollTop = 0;
    document.querySelectorAll('.kb-section-nav-btn').forEach((btn, index) => {
        btn.classList.toggle('active', index === 0);
    });
}

function capNhatIconKhamDangActive(scroller, sections, buttons) {
    if (!sections.length) return;

    const scrollTop = Math.max(0, scroller.scrollTop);
    const maxScrollTop = Math.max(0, scroller.scrollHeight - scroller.clientHeight);

    // Khi vừa mở trang/vừa hiện form, vùng scroll có thể chưa đo layout xong
    // nên maxScrollTop = 0. Trạng thái này phải mặc định ở Thông tin BN,
    // không được hiểu nhầm là đang ở cuối trang (Toa thuốc).
    const isAtTop = scrollTop <= 8;
    const isAtBottom = maxScrollTop > 8 && (maxScrollTop - scrollTop <= 8);

    let active = sections[0];

    if (isAtBottom) {
        active = sections[sections.length - 1];
    } else if (!isAtTop) {
        const top = scroller.getBoundingClientRect().top + 24;

        for (const section of sections) {
            if (section.getBoundingClientRect().top <= top) active = section;
            else break;
        }
    }

    buttons.forEach(btn => {
        btn.classList.toggle('active', btn.dataset.target === active.id);
    });
}

async function hienThiPhacDoDaChon(idPhacDo, maPhacDo = '', tenPhacDo = '', allowFetch = true) {
    currentPhacDoId = idPhacDo ? Number(idPhacDo) : null;
    currentPhacDoMa = maPhacDo || '';
    currentPhacDoTen = tenPhacDo || '';

    if (!selectPhacDoInstance) return;

    if (!currentPhacDoId) {
        selectPhacDoInstance.clear(true);
        return;
    }

    let option = selectPhacDoInstance.options[String(currentPhacDoId)]
        || selectPhacDoInstance.options[currentPhacDoId];

    if ((!option || !option.ten) && allowFetch) {
        try {
            const res = await apiGet('/api/phac_do/chi_tiet', { id: currentPhacDoId });
            const info = res?.status === 200 ? res.data?.thong_tin : null;
            if (info) {
                currentPhacDoMa = info.MaPhacDo || currentPhacDoMa;
                currentPhacDoTen = info.TenPhacDo || currentPhacDoTen || currentPhacDoMa;
                option = {
                    id: info.ID || currentPhacDoId,
                    ma: currentPhacDoMa,
                    ten: currentPhacDoTen
                };
                selectPhacDoInstance.addOption(option);
            }
        } catch (_) { }
    }

    if (!option) {
        option = {
            id: currentPhacDoId,
            ma: currentPhacDoMa,
            ten: currentPhacDoTen || currentPhacDoMa || ('Phác đồ #' + currentPhacDoId)
        };
        selectPhacDoInstance.addOption(option);
    }

    selectPhacDoInstance.setValue(String(currentPhacDoId), true);
}

function initTomSelects() {
    // 0. Tìm kiếm và nạp Phác đồ mẫu
    selectPhacDoInstance = initRemoteTomSelect('#kb-select-phac-do', '/api/phac_do/danh_sach', {
        placeholder: '-- Chọn --',
        dropdownParent: 'body',
        localSearch: true,
        localSearchTop: 1000,
        localSearchParams: { kich_thuoc_trang: 1000 },
        showCodeInItem: false,
        searchField: ['ten', 'ma', 'ten_icd10', 'ma_icd10'],
        render: {
            option: (data, escape) => {
                const ten = data.ten || data.ma || '';
                const ma = data.ma || '';
                const icd = [data.ma_icd10, data.ten_icd10].filter(Boolean).join(' - ');
                const title = [
                    ten,
                    ma ? `Mã: ${ma}` : '',
                    icd ? `ICD: ${icd}` : ''
                ].filter(Boolean).join(' | ');

                return `
                    <div class="kb-phacdo-option" title="${escape(title)}">
                        <span class="kb-phacdo-option-name">${escape(ten)}</span>
                        ${ma ? `<span class="kb-phacdo-option-code">${escape(ma)}</span>` : ''}
                    </div>`;
            },
            item: (data, escape) => `<div class="kb-phacdo-selected" title="${escape(data.ten || data.ma || '')}">${escape(data.ten || data.ma || '')}</div>`
        }
    }, async (item) => {
        if (!item || !item.id) return;
        const lyDoThayThe = lyDoKhongDuocThayToanBoPhacDo();
        if (lyDoThayThe) {
            showToast('warning', lyDoThayThe);
            await hienThiPhacDoDaChon(currentPhacDoId, currentPhacDoMa, currentPhacDoTen);
            return;
        }
        const dataXemTruoc = await xemTruocPhacDoKham(item);
        if (!dataXemTruoc) {
            await hienThiPhacDoDaChon(currentPhacDoId, currentPhacDoMa, currentPhacDoTen);
            return;
        }

        const applied = await apDungPhacDo(item.id, dataXemTruoc);
        if (!applied) {
            await hienThiPhacDoDaChon(currentPhacDoId, currentPhacDoMa, currentPhacDoTen);
        }
    });

    if (selectPhacDoInstance) {
        selectPhacDoInstance.dropdown?.classList.add('kb-phacdo-dropdown', 'kb-exam-dropdown');
        selectPhacDoInstance.wrapper?.classList.add('kb-phacdo-select');

        // Dropdown gắn vào body để không bị pane cắt. Khi mở, canh mép phải
        // theo ô Phác đồ và co chiều rộng để không tràn khỏi viewport.
        const canhDropdownPhacDo = () => {
            const dropdown = selectPhacDoInstance?.dropdown;
            const wrapper = selectPhacDoInstance?.wrapper;
            if (!dropdown || !wrapper) return;

            const rect = wrapper.getBoundingClientRect();
            const viewportWidth = document.documentElement.clientWidth || window.innerWidth;
            const gutter = 8;
            const availableWidth = Math.max(0, viewportWidth - (gutter * 2));
            const width = Math.min(Math.max(rect.width, 320), availableWidth);
            const maxLeft = Math.max(gutter, viewportWidth - gutter - width);
            const left = Math.min(Math.max(gutter, rect.right - width), maxLeft);

            dropdown.style.setProperty('width', `${Math.round(width)}px`, 'important');
            dropdown.style.setProperty('min-width', '0', 'important');
            dropdown.style.setProperty('max-width', `${Math.round(availableWidth)}px`, 'important');
            dropdown.style.left = `${Math.round(window.scrollX + left)}px`;
        };

        selectPhacDoInstance.on('dropdown_open', () => {
            requestAnimationFrame(canhDropdownPhacDo);
        });
    }

    // 1. Tìm kiếm ICD10
    selectIcd10Instance = initRemoteTomSelect('#kb-select-icd10', 'dm_icd10', {
        localSearch: true,
        localSearchTop: 1000
    }, (item) => {
        themChanDoan({
            id_icd10: item.id,
            ma_benh: item.ma,
            ten_benh: item.ten,
            ban_dau: false,
            benh_chinh: false,
            benh_khac: false,
            ghi_chu: ''
        });
        selectIcd10Instance?.clear();
    });
    selectIcd10Instance?.dropdown?.classList.add('kb-exam-dropdown');

    // 2. Tìm kiếm Dịch vụ cận lâm sàng
    selectDichVuInstance = initRemoteTomSelect('#kb-select-dich-vu', 'dm_dich_vu', {
        localSearch: true,
        localSearchTop: 1000,
        dropdownParent: 'body',
        render: {
            option: (data, escape) => {
                const gia = Number(data.don_gia || 0).toLocaleString('vi-VN');
                return `
                    <div class="kb-service-option" title="${escape(data.ten || '')}">
                        <div class="kb-service-option-head">
                            <span class="kb-service-option-name">${escape(data.ten || '')}</span>
                            ${data.ma ? `<span class="kb-service-option-code">[${escape(data.ma)}]</span>` : ''}
                        </div>
                        <div class="kb-service-option-price-line">Đơn giá: ${gia} đ</div>
                    </div>`;
            },
            item: (data, escape) => `<div class="kb-service-selected" title="${escape(data.ten || '')}">${escape(data.ten || '')}</div>`
        }
    }, (item) => {
        const donGia = roundDecimal(item.don_gia || 0, 3);
        themChiDinh({
            id: 0,
            id_dich_vu: item.id,
            ma_dich_vu: item.ma,
            ten_dich_vu: item.ten,
            ngay_gio_chi_dinh: getKhamNowDateTime(),
            so_luong: 1,
            don_gia: donGia,
            don_gia_goc: donGia,
            thanh_tien: donGia,
            gui_ngoai: false,
            noi_gui_ngoai: '',
            ghi_chu: '',
            da_thu: false
        });
        selectDichVuInstance?.clear();
    });

    if (selectDichVuInstance) {
        selectDichVuInstance.dropdown?.classList.add('kb-service-dropdown', 'kb-exam-dropdown');
        selectDichVuInstance.wrapper?.classList.add('kb-service-select');

        // Dropdown Chỉ định rộng kiểu HIS nhưng luôn nằm gọn trong viewport.
        const canhDropdownDichVu = () => {
            const dropdown = selectDichVuInstance?.dropdown;
            const wrapper = selectDichVuInstance?.wrapper;
            if (!dropdown || !wrapper) return;

            const rect = wrapper.getBoundingClientRect();
            const viewportWidth = document.documentElement.clientWidth || window.innerWidth;
            const gutter = 8;
            const availableWidth = Math.max(0, viewportWidth - gutter * 2);
            const width = Math.min(Math.max(rect.width, 720), availableWidth);
            const left = Math.min(
                Math.max(gutter, rect.left),
                Math.max(gutter, viewportWidth - gutter - width)
            );

            dropdown.style.setProperty('width', `${Math.round(width)}px`, 'important');
            dropdown.style.setProperty('min-width', '0', 'important');
            dropdown.style.setProperty('max-width', `${Math.round(availableWidth)}px`, 'important');
            dropdown.style.left = `${Math.round(window.scrollX + left)}px`;
        };

        selectDichVuInstance.on('dropdown_open', () => requestAnimationFrame(canhDropdownDichVu));
    }
}

function updateKhamSaveActionState() {
    const btnLuu = document.getElementById('btn-kb-luu');
    const btnKhamXong = document.getElementById('btn-kb-kham-xong');
    const blocked = !selectedIdVaoVien || !selectedPatientCanEdit || isCompletingKham || saveOutcomeUnknown;

    if (btnLuu) btnLuu.disabled = blocked || !isKhamDirty;
    if (btnKhamXong) btnKhamXong.disabled = blocked || Number(selectedPatientStatus) === 2;
}

function markDirty() {
    if (!selectedPatientCanEdit || isSwitchingPatient) return;
    isKhamDirty = true;
    const statusEl = document.getElementById('qlpm-header-status');
    if (statusEl) {
        statusEl.innerHTML = '<span class="text-warning"><i class="bi bi-circle-fill me-1"></i> C\u00f3 d\u1eef li\u1ec7u ch\u01b0a l\u01b0u</span>';
    }
    updateKhamSaveActionState();
}

function clearDirty() {
    isKhamDirty = false;
    const statusEl = document.getElementById('qlpm-header-status');
    if (statusEl) statusEl.innerHTML = '';
    updateKhamSaveActionState();
}

function fillSinhHieuInputs(shData) {
    const vitalsMap = {
        1: 'sh-mach',
        2: 'sh-nhiet-do',
        5: 'sh-nhip-tho',
        6: 'sh-spo2',
        7: 'sh-chieu-cao',
        8: 'sh-can-nang',
        9: 'sh-bmi'
    };

    ['sh-mach', 'sh-nhiet-do', 'sh-huyet-ap', 'sh-nhip-tho', 'sh-spo2', 'sh-chieu-cao', 'sh-can-nang', 'sh-bmi'].forEach(id => {
        const el = document.getElementById(id);
        if (el) el.value = '';
    });
    setHuyetApInputs('');

    if (!shData) return;

    if (Array.isArray(shData)) {
        let haTamThu = '';
        let haTamTruong = '';
        let haDayDu = '';

        shData.forEach(item => {
            haDayDu ||= item.HuyetAp ?? item.huyet_ap ?? '';
            const idTriSo = Number(item.IDTriSoSinhHieu);
            const code = String(item.MaTriSo || '').toUpperCase();
            const value = item.GiaTri ?? '';

            if (idTriSo === 3 || code === 'HA_TT') {
                haTamThu = value;
                return;
            }
            if (idTriSo === 4 || code === 'HA_TR') {
                haTamTruong = value;
                return;
            }

            let targetId = vitalsMap[idTriSo];
            if (!targetId && code) {
                if (code === 'MACH') targetId = 'sh-mach';
                else if (code === 'NHIET_DO') targetId = 'sh-nhiet-do';
                else if (code === 'NHIP_THO') targetId = 'sh-nhip-tho';
                else if (code === 'SPO2') targetId = 'sh-spo2';
                else if (code === 'CHIEU_CAO') targetId = 'sh-chieu-cao';
                else if (code === 'CAN_NANG') targetId = 'sh-can-nang';
                else if (code === 'BMI') targetId = 'sh-bmi';
            }

            if (targetId) {
                const el = document.getElementById(targetId);
                if (el) el.value = value;
            }
        });

        setHuyetApInputs(haDayDu || ghepHuyetAp(haTamThu, haTamTruong));
    } else if (typeof shData === 'object') {
        const setVal = (id, val) => {
            const el = document.getElementById(id);
            if (el && val !== undefined && val !== null) el.value = val;
        };
        setVal('sh-mach', shData.mach ?? shData.Mach);
        setVal('sh-nhiet-do', shData.nhiet_do ?? shData.NhietDo);
        const haCoSan = shData.huyet_ap ?? shData.HuyetAp;
        const haTamThu = shData.huyet_ap_tam_thu ?? shData.HuyetApTamThu;
        const haTamTruong = shData.huyet_ap_tam_truong ?? shData.HuyetApTamTruong;
        setHuyetApInputs(haCoSan || ghepHuyetAp(haTamThu, haTamTruong));
        setVal('sh-nhip-tho', shData.nhip_tho ?? shData.NhipTho);
        setVal('sh-spo2', shData.spo2 ?? shData.SpO2);
        setVal('sh-chieu-cao', shData.chieu_cao ?? shData.ChieuCao);
        setVal('sh-can-nang', shData.can_nang ?? shData.CanNang);
        setVal('sh-bmi', shData.bmi ?? shData.BMI);
    }

    const hEl = document.getElementById('sh-chieu-cao');
    const wEl = document.getElementById('sh-can-nang');
    const bmiEl = document.getElementById('sh-bmi');
    if (hEl && wEl && bmiEl && (!bmiEl.value || bmiEl.value.trim() === '')) {
        const hM = parseFloat(hEl.value) / 100;
        const wKg = parseFloat(wEl.value);
        if (hM > 0 && wKg > 0) {
            bmiEl.value = (wKg / (hM * hM)).toFixed(1);
        }
    }
}

function setHeaderHoTen(value) {
    const el = document.getElementById('kb-header-ho-ten');
    if (!el) return;

    const text = String(value || '');
    el.value = text;
    el.removeAttribute('size');
    el.style.removeProperty('font-size');

    // Vị trí các cột phải cố định. Nếu tên dài thì chỉ thu nhỏ chữ
    // bên trong đúng vùng tên, không được đẩy Ngày sinh/Giới tính/Phác đồ.
    requestAnimationFrame(() => {
        const available = Math.max(0, el.clientWidth - 4);
        if (!available || !text) return;

        const styles = window.getComputedStyle(el);
        const maxFont = parseFloat(styles.fontSize) || 17;
        const minFont = 12.5;
        const canvas = setHeaderHoTen._canvas || (setHeaderHoTen._canvas = document.createElement('canvas'));
        const ctx = canvas.getContext('2d');
        if (!ctx) return;

        let fontSize = maxFont;
        const weight = styles.fontWeight || '700';
        const family = styles.fontFamily || 'sans-serif';

        const measure = () => {
            ctx.font = `${weight} ${fontSize}px ${family}`;
            return ctx.measureText(text).width;
        };

        while (fontSize > minFont && measure() > available) {
            fontSize -= 0.5;
        }

        el.style.setProperty('font-size', `${fontSize}px`, 'important');
    });
}

function setHeaderGioiTinh(val) {
    const sel = document.getElementById('kb-header-gioi-tinh');
    const txt = document.getElementById('kb-header-gioi-tinh-text');
    let v = 1;
    if (val !== undefined && val !== null && val !== '') {
        if (typeof val === 'number') {
            v = val;
        } else {
            const s = String(val).trim().toLowerCase();
            if (s === '1' || s === 'nam' || s === 'true') v = 1;
            else if (s === '0' || s === 'nữ' || s === 'nu' || s === 'false') v = 0;
            else if (s === '2' || s === 'khác' || s === 'khac') v = 2;
            else v = Number(val) || 1;
        }
    }
    if (sel) sel.value = v;
    if (txt) txt.value = v === 1 ? 'Nam' : (v === 0 ? 'Nữ' : 'Khác');
}

async function xoaTrangForm() {
    if (!selectedIdVaoVien) {
        showToast('warning', 'Chọn bệnh nhân trước.');
        return;
    }
    if (!selectedPatientCanEdit) {
        showToast('warning', 'Lượt khám đã xong, không thể sửa.');
        return;
    }

    // Reset sinh hiệu
    ['sh-mach', 'sh-nhiet-do', 'sh-huyet-ap', 'sh-nhip-tho', 'sh-spo2', 'sh-chieu-cao', 'sh-can-nang', 'sh-bmi'].forEach(id => {
        const el = document.getElementById(id);
        if (el) el.value = '';
    });
    setHuyetApInputs('');

    // Reset triệu chứng, ngày tái khám, ghi chú
    ['kb-trieu-chung', 'kb-ngay-tai-kham', 'kb-dan-do'].forEach(id => {
        const el = document.getElementById(id);
        if (el) el.value = '';
    });

    if (document.getElementById('kb-toa-so-ngay')) document.getElementById('kb-toa-so-ngay').value = '3';
    if (document.getElementById('kb-loai-toa')) document.getElementById('kb-loai-toa').value = 'c';
    if (document.getElementById('kb-chk-tai-kham')) {
        document.getElementById('kb-chk-tai-kham').checked = true;
        document.getElementById('kb-ngay-tai-kham').disabled = false;
        tinhVaGanNgayTaiKham(3);
    }

    // Reset phác đồ và danh sách chẩn đoán, chỉ định, toa thuốc
    currentPhacDoId = null;
    currentPhacDoMa = '';
    currentPhacDoTen = '';
    selectPhacDoInstance?.clear(true);

    listChanDoan = [];
    renderChanDoanTable();

    listChiDinh = [];
    renderChiDinhTable();

    listToaThuoc = [];
    renderToaThuocTable();

    // Xóa trắng chỉ tác động vùng nhập trên UI, tuyệt đối không đổi TrangThaiKham.
    // Đây là thay đổi chưa lưu nên vẫn phải đánh dấu dirty để tránh mất dữ liệu ngoài ý muốn.
    markDirty();

    showToast('success', 'Đã xóa nội dung đang nhập.');
}

function openKhamBenhCollapse(kind) {
    // Giữ compatibility với các lệnh gọi cũ; UI hiện tại là dạng cuộn, không còn collapse.
    setTimeout(() => {
        if (kind === 'toa_thuoc') {
            inlineSelectThuocInstance?.sync?.();
        } else {
            selectDichVuInstance?.sync();
        }
    }, 0);
}

function autoSwitchSubTab() {
    selectDichVuInstance?.sync();
    inlineSelectThuocInstance?.sync?.();
}

function initEvents() {
    document.getElementById('btn-kb-xoa-trang')?.addEventListener('click', xoaTrangForm);
    document.getElementById('btn-kb-luu')?.addEventListener('click', () => luuKhamBenh(false));
    document.getElementById('btn-kb-kham-xong')?.addEventListener('click', () => luuKhamBenh(true));
    document.getElementById('btn-kb-ke-lai')?.addEventListener('click', () => {
        if (!selectedPatientCanEdit) {
            showToast('warning', 'Lượt khám đã xong, không thể sửa.');
            return;
        }
        moModalLichSu();
    });

    // In chỉ định theo từng phiếu và in toa thuốc riêng.
    document.getElementById('btn-kb-in-chi-dinh')?.addEventListener('click', inPhieuChiDinh);
    document.getElementById('btn-kb-in-toa-thuoc')?.addEventListener('click', inToaThuoc);
    document.getElementById('btn-kb-ky-so-toa')?.addEventListener('click', () => kySoVaIn('toa_thuoc'));
    document.getElementById('btn-kb-ky-so-chi-dinh')?.addEventListener('click', () => kySoVaIn('chi_dinh'));

    // Tìm kiếm và nút kê lại trong modal lịch sử
    document.getElementById('modal-ls-search')?.addEventListener('input', () => {
        clearTimeout(lichSuSearchTimer);
        lichSuSearchTimer = setTimeout(() => {
            lichSuCurrentPage = 1;
            taiTrangLichSuKham();
        }, 250);
    });
    document.getElementById('btn-modal-ls-ke-lai')?.addEventListener('click', () => {
        if (!selectedPatientCanEdit) {
            showToast('warning', 'Lượt khám đã xong, không thể sửa.');
            return;
        }
        if (selectedLichSuLanKham) {
            napDuLieuLanKhamCu(selectedLichSuLanKham.IDVaoVien, selectedLichSuLanKham.NgayStr);
        }
    });

    // UI dạng cuộn không còn accordion; TomSelect được sync trực tiếp khi dữ liệu thay đổi.

    // Thay đổi số ngày toa thuốc ở footer
    document.getElementById('kb-toa-so-ngay')?.addEventListener('input', (e) => {
        const ngayMoi = parseInt(e.target.value) || 1;
        listToaThuoc.forEach(t => {
            t.so_ngay = ngayMoi;
            const s = parseFloat(t.sang) || 0;
            const trua = parseFloat(t.trua) || 0;
            const c = parseFloat(t.chieu) || 0;
            const toi = parseFloat(t.toi) || 0;
            const sum = s + trua + c + toi;
            const sl = roundDecimal((sum === 0 ? 1 : sum) * ngayMoi, 3);
            t.so_luong = sl;
            t.thanh_tien = roundDecimal(sl * (parseFloat(t.don_gia) || 0), 3);
        });
        if (document.getElementById('kb-chk-tai-kham')?.checked) {
            tinhVaGanNgayTaiKham(ngayMoi);
        }
        markDirty();
        renderToaThuocTable();
    });

    // Checkbox hẹn tái khám tự động tính ngày
    document.getElementById('kb-chk-tai-kham')?.addEventListener('change', (e) => {
        const isChecked = e.target.checked;
        const inpNgay = document.getElementById('kb-ngay-tai-kham');
        if (inpNgay) {
            inpNgay.disabled = !isChecked;
            if (isChecked) {
                const soNgay = parseInt(document.getElementById('kb-toa-so-ngay')?.value) || 3;
                tinhVaGanNgayTaiKham(soNgay);
            } else {
                inpNgay.value = '';
                if (inpNgay._flatpickr) inpNgay._flatpickr.clear();
            }
        }
        markDirty();
    });

    document.getElementById('kb-dan-do')?.addEventListener('input', () => markDirty());
    document.getElementById('kb-ngay-tai-kham')?.addEventListener('change', () => markDirty());
}

function setupPrescriptionTypeSelector() {
    const select = document.getElementById('kb-loai-toa');
    if (!select) return;

    // Contract giống HIS: id/ma là c|n|h, còn viettat là mã hiển thị bên phải.
    const defaults = [
        { id: 'c', ma: 'c', ten: 'Đơn thuốc cơ bản', viettat: 'DTCB', active: true },
        { id: 'n', ma: 'n', ten: 'Đơn thuốc gây nghiện', viettat: 'DTGN', active: true },
        { id: 'h', ma: 'h', ten: 'Đơn thuốc hướng tâm thần và thuốc tiền chất', viettat: 'DTHTTVTTC', active: true }
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
            option.dataset.viettat = item.viettat || fallback.viettat;
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

    // Dropdown này chỉ lọc danh mục thuốc sẽ thêm tiếp theo.
    // Mỗi dòng thuốc tự giữ MaLoaiToaThuoc riêng nên cùng một lượt khám
    // có thể kê đồng thời toa cơ bản, hướng tâm thần/tiền chất và gây nghiện.
    select.addEventListener('change', () => {
        renderToaThuocTable();
    });
}

function setupSymptomCollapse() {
    const input = document.getElementById('kb-trieu-chung');
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
    input.addEventListener('input', expand);
    input.addEventListener('blur', collapse);

    collapse();
}

function updateRecordTotal() {
    const rx = Math.round(listToaThuoc.reduce((sum, row) => sum + (Number(row.thanh_tien) || 0), 0));
    const services = Math.round(listChiDinh.reduce((sum, row) => sum + (Number(row.thanh_tien) || 0), 0));
    const total = rx + services;
    const totalEl = document.getElementById('kb-tong-ho-so');
    if (totalEl) totalEl.textContent = `${formatNumberVN(total)} đ`;

    const cdTotalEl = document.getElementById('kb-chi-dinh-tong-tien');
    if (cdTotalEl) cdTotalEl.textContent = `Cộng CĐ: ${formatNumberVN(services)} đ`;
}

function prescriptionTypeName(code) {
    return ({ c: 'Đơn thuốc cơ bản', n: 'Đơn thuốc gây nghiện', h: 'Đơn thuốc hướng tâm thần và thuốc tiền chất' })[String(code || 'c').trim().toLowerCase()] || 'Đơn thuốc cơ bản';
}

function prescriptionTypeSummary(rows) {
    const codes = [...new Set((rows || [])
        .map(row => String(row?.MaLoaiToaThuoc || row?.ma_loai_toa_thuoc || 'c').trim().toLowerCase())
        .filter(code => ['c', 'n', 'h'].includes(code)))];
    return codes.length ? codes.map(prescriptionTypeName).join(' + ') : prescriptionTypeName('c');
}

// Modal phác đồ hiển thị chính dữ liệu trả về từ STO, chỉ đọc trước khi áp dụng.
function renderXemTruocPhacDoKham(data) {
    const info = data.thong_tin || {};
    const diagnoses = Array.isArray(data.chan_doan) ? data.chan_doan : [];
    const orders = Array.isArray(data.chi_dinh) ? data.chi_dinh : [];
    const drugs = Array.isArray(data.thuoc) ? data.thuoc : [];
    const setText = (id, value) => {
        const el = document.getElementById(id);
        if (el) el.textContent = String(value ?? '').trim();
    };
    const money = v => Number(v || 0).toLocaleString('vi-VN', { maximumFractionDigits: 0 }) + ' đ';
    const numberText = v => formatNumberVN(roundDecimal(Number(v || 0), 3), 3);
    const yes = v => v === true || Number(v) === 1;
    const cell = (value, cls = '') => '<td class="' + cls + '">' + escapeHtml(String(value ?? '')) + '</td>';
    const checkboxCell = v => '<td class="text-center"><input type="checkbox" class="form-check-input" disabled ' + (yes(v) ? 'checked' : '') + ' /></td>';
    const tableBody = (id, rows) => { const el = document.getElementById(id); if (el) el.innerHTML = rows; };

    setText('kb-pd-preview-code', [info.MaPhacDo, info.TenPhacDo].filter(Boolean).join(' - '));
    setText('kb-pd-preview-symptoms', info.TrieuChung || '');

    tableBody('kb-pd-preview-diagnoses', diagnoses.length ? diagnoses.map(cd =>
        '<tr>' + cell(cd.MaBenh, 'fw-semibold') + cell(cd.TenBenh)
        + checkboxCell(cd.BanDau) + checkboxCell(cd.BenhChinh) + checkboxCell(cd.BenhKhac) + '</tr>'
    ).join('') : '');

    let orderTotal = 0;
    const orderRows = orders.map(o => {
        const external = yes(o.GuiNgoai);
        const price = external ? 0 : roundDecimal(Number(o.DonGiaDanhMuc ?? o.DonGia ?? 0), 3);
        const quantity = roundDecimal(Number(o.SoLuong || 1), 3);
        orderTotal += price * quantity;
        return '<tr>' + cell('', 'text-muted text-center')
            + cell((o.TenDichVu || '') + (o.MaDichVu ? ' (' + o.MaDichVu + ')' : ''))
            + cell(numberText(quantity), 'text-center')
            + cell(money(price), 'text-end')
            + checkboxCell(external) + '</tr>';
    });
    tableBody('kb-pd-preview-orders-body', orderRows.length
        ? orderRows.join('') : '');
    setText('kb-pd-preview-orders-total', money(orderTotal));

    const days = [...new Set(drugs.map(d => Number(d.SoNgay || 1)).filter(Number.isFinite))];
    setText('kb-pd-preview-days', days.length ? days.join(', ') : '');
    const types = [...new Set(drugs.map(d => String(d.MaLoaiToaThuoc || '').trim().toLowerCase()).filter(Boolean))];
    setText('kb-pd-preview-type', types.length ? types.map(prescriptionTypeName).join(' + ') : '');

    let drugTotal = 0;
    const drugRows = drugs.map((d, i) => {
        const quantity = roundDecimal(Number(d.SoLuong || 1), 3);
        const price = roundDecimal(Number(d.DonGia || 0), 3);
        const amount = quantity * price;
        drugTotal += amount;
        return '<tr>'
            + cell(i + 1, 'text-center')
            + cell('', 'text-muted text-center')
            + cell(d.TenThuoc || d.MaThuoc || '', 'fw-semibold')
            + cell(d.HoatChat || d.TenHoatChat || '')
            + cell(d.SoNgay ?? '', 'text-center')
            + cell(d.DonViTinh || '')
            + cell(d.Sang ?? '', 'text-center')
            + cell(d.Trua ?? '', 'text-center')
            + cell(d.Chieu ?? '', 'text-center')
            + cell(d.Toi ?? '', 'text-center')
            + cell(d.DuongDung || '')
            + cell(d.CachDung || '')
            + cell(money(price), 'text-end')
            + cell(money(amount), 'text-end fw-semibold')
            + cell(d.DonViTinhDung || d.DonViTinh || '')
            + cell(numberText(quantity), 'text-center') + '</tr>';
    });
    tableBody('kb-pd-preview-medicines', drugRows.length
        ? drugRows.join('') : '');
    setText('kb-pd-preview-medicine-total', money(drugTotal));
    setText('kb-pd-preview-grand-total', money(orderTotal + drugTotal));

    const scroll = document.getElementById('kb-pd-preview-body');
    if (scroll) scroll.scrollTop = 0;
}

async function xemTruocPhacDoKham(item) {
    if (!selectedIdVaoVien || !selectedPatientCanEdit) {
        showToast('warning', 'Chọn lượt khám chưa hoàn tất trước khi áp dụng phác đồ.');
        return null;
    }

    let response;
    try {
        response = await apiGet('/api/phac_do/chi_tiet', { id: item.id });
        if (response?.status !== 200 || !response.data?.thong_tin) {
            showToast('error', response?.message || 'Không tải được dữ liệu phác đồ.');
            return null;
        }
    } catch (_) {
        showToast('error', 'Không tải được dữ liệu phác đồ.');
        return null;
    }

    const modal = document.getElementById('modalXemTruocPhacDo');
    const applyButton = document.getElementById('kb-pd-preview-apply');
    if (!modal || !applyButton || !window.bootstrap?.Modal) {
        showToast('error', 'Không thể mở modal xem trước phác đồ.');
        return null;
    }

    renderXemTruocPhacDoKham(response.data);
    return new Promise(resolve => {
        const instance = bootstrap.Modal.getOrCreateInstance(modal);
        let approved = false;
        const onApply = () => {
            if (approved) return;
            approved = true;
            applyButton.disabled = true;
            instance.hide();
        };
        const onHidden = () => {
            applyButton.removeEventListener('click', onApply);
            applyButton.disabled = false;
            resolve(approved ? response.data : null);
        };
        applyButton.addEventListener('click', onApply);
        modal.addEventListener('hidden.bs.modal', onHidden, { once: true });
        instance.show();
    });
}

// ==========================================
// ÁP DỤNG PHÁC ĐỒ ĐIỀU TRỊ MẪU
// ==========================================
function lyDoKhongDuocThayToanBoPhacDo() {
    if (!selectedIdVaoVien || !selectedPatientCanEdit || Number(selectedPatientStatus) === 2) {
        return 'Lượt khám đã hoàn tất hoặc không có quyền sửa, không thể thay thế phác đồ.';
    }
    if (listChiDinh.some(c => dongKhamDaKhoa(c))) {
        return 'Có chỉ định CLS đã thu tiền hoặc khóa nghiệp vụ. Không thể thay thế toàn bộ vì sẽ ảnh hưởng chứng từ.';
    }
    if (listChiDinh.some(c => clsHasResult(c) || Number(c.trang_thai_ket_qua || 0) > 0)) {
        return 'Có chỉ định CLS đã có kết quả. Không thể thay thế toàn bộ dữ liệu đã xử lý.';
    }
    if (listToaThuoc.some(t => dongKhamDaKhoa(t) || t.id_toa_thuoc_ct_goc)) {
        return 'Có thuốc đã thu tiền, cấp phát hoặc khóa nghiệp vụ. Không thể thay thế toàn bộ toa thuốc.';
    }
    return '';
}

async function apDungPhacDo(idPhacDo, dataXemTruoc = null) {
    const lyDo = lyDoKhongDuocThayToanBoPhacDo();
    if (lyDo) {
        showToast('warning', lyDo);
        return false;
    }
    showPageloader();
    try {
        // Sử dụng đúng dữ liệu đã xem trước; chỉ tải từ API nếu gọi hàm độc lập.
        let data = dataXemTruoc;
        if (!data) {
            const res = await apiGet('/api/phac_do/chi_tiet', { id: idPhacDo });
            if (res.status !== 200 || !res.data) {
                showToast('error', 'Không thể nạp dữ liệu phác đồ.');
                return false;
            }
            data = res.data;
        }
        const info = data.thong_tin;
        if (!info) {
            showToast('error', 'Thông tin phác đồ không hợp lệ.');
            return false;
        }

        // THAY TOÀN BỘ: xóa tất cả dữ liệu đang nhập, kể cả khi phác đồ
        // không có chẩn đoán, CLS hoặc thuốc. Chỉ thông tin bệnh nhân giữ nguyên.
        listChanDoan = [];
        listChiDinh = [];
        listToaThuoc = [];
        fillSinhHieuInputs(null);
        currentVitals = {};
        const danDo = document.getElementById('kb-dan-do');
        if (danDo) danDo.value = '';
        const taiKham = document.getElementById('kb-ngay-tai-kham');
        const chkTaiKham = document.getElementById('kb-chk-tai-kham');
        // Áp phác đồ vẫn mặc định chọn hẹn tái khám, không tự bỏ tick.
        if (chkTaiKham) chkTaiKham.checked = true;
        if (taiKham) {
            taiKham.disabled = false;
            tinhVaGanNgayTaiKham(parseInt(document.getElementById('kb-toa-so-ngay')?.value, 10) || 3);
        }

        currentPhacDoId = Number(info?.ID || idPhacDo);
        currentPhacDoMa = info?.MaPhacDo || '';
        currentPhacDoTen = info?.TenPhacDo || currentPhacDoMa;
        selectPhacDoInstance?.addOption({
            id: currentPhacDoId,
            ma: currentPhacDoMa,
            ten: currentPhacDoTen
        });
        selectPhacDoInstance?.setValue(String(currentPhacDoId), true);

        // 1. Triệu chứng: thay thế, tuyệt đối không nối vào triệu chứng cũ.
        document.getElementById('kb-trieu-chung').value = info.TrieuChung || '';

        // 2. ICD10 của phác đồ + bộ cờ BĐ / Chính / #
        const chanDoanPhacDo = Array.isArray(data.chan_doan) ? data.chan_doan : [];
        chanDoanPhacDo.forEach(cd => {
            const idIcd = Number(cd.IDICD10);
            let chanDoan = listChanDoan.find(x => Number(x.id_icd10) === idIcd);
            const laBanDau = cd.BanDau === true || Number(cd.BanDau) === 1;
            const laChinh = cd.BenhChinh === true || Number(cd.BenhChinh) === 1;
            const laKhac = cd.BenhKhac === true || Number(cd.BenhKhac) === 1;

            if (!chanDoan) {
                chanDoan = {
                    id_icd10: cd.IDICD10,
                    ma_benh: cd.MaBenh,
                    ten_benh: cd.TenBenh,
                    ban_dau: laBanDau,
                    benh_chinh: laChinh,
                    benh_khac: laKhac,
                    ghi_chu: ''
                };
                listChanDoan.push(chanDoan);
            } else {
                chanDoan.ban_dau = chanDoan.ban_dau || laBanDau;
                chanDoan.benh_khac = chanDoan.benh_khac || laKhac;
                if (laChinh) chanDoan.benh_chinh = true;
            }

            if (laChinh) {
                listChanDoan.forEach(x => {
                    if (x !== chanDoan) x.benh_chinh = false;
                });
            }
        });

        chuanHoaThuTuChanDoan();
        renderChanDoanTable();

        // 4. Chỉ định CLS
        if (data.chi_dinh && data.chi_dinh.length > 0) {
            data.chi_dinh.forEach(cd => {
                const exists = listChiDinh.some(c => c.id_dich_vu === cd.IDDichVu);
                if (!exists) {
                    const cdDonGiaGoc = roundDecimal(cd.DonGiaDanhMuc ?? cd.DonGia ?? 0, 3);
                    const cdGuiNgoai = cd.GuiNgoai === true;
                    const cdDonGia = cdGuiNgoai ? 0 : cdDonGiaGoc;
                    const cdSoLuong = roundDecimal(cd.SoLuong || 1, 3);
                    listChiDinh.push({
                        id: null,
                        id_dich_vu: cd.IDDichVu,
                        ma_dich_vu: cd.MaDichVu,
                        ten_dich_vu: cd.TenDichVu,
                        ngay_gio_chi_dinh: getKhamNowDateTime(),
                        don_gia: cdDonGia,
                        don_gia_goc: cdDonGiaGoc,
                        so_luong: cdSoLuong,
                        thanh_tien: roundDecimal(cdSoLuong * cdDonGia, 3),
                        gui_ngoai: cdGuiNgoai,
                        noi_gui_ngoai: cd.NoiGuiNgoai || '',
                        noi_dung_mau: cd.NoiDungMau || null,
                        ghi_chu: '',
                        id_chi_dinh_ct_goc: null,
                        da_thu: false
                    });
                }
            });
        }
        renderChiDinhTable();

        // 5. Toa thuốc
        const thuocPhacDo = Array.isArray(data.thuoc) ? data.thuoc : [];
        if (thuocPhacDo.length > 0) {
            thuocPhacDo.forEach(t => {
                const exists = listToaThuoc.some(x => Number(x.id_thuoc) === Number(t.IDThuoc));
                if (exists) return;

                const sl = roundDecimal(t.SoLuong || 1, 3);
                const donGia = roundDecimal(t.DonGia || 0, 3);
                listToaThuoc.push({
                    id: null,
                    id_thuoc: t.IDThuoc,
                    ma_thuoc: t.MaThuoc,
                    ten_thuoc: t.TenThuoc,
                    ten_hoat_chat: t.HoatChat || t.TenHoatChat || '',
                    don_vi_tinh: t.DonViTinhDung || t.DonViTinh || '',
                    id_don_vi_tinh_dung: t.IDDonViTinhDung || null,
                    so_ngay: t.SoNgay || 1,
                    sang: t.Sang || '0',
                    trua: t.Trua || '0',
                    chieu: t.Chieu || '0',
                    toi: t.Toi || '0',
                    lieu_dung: t.LieuDung || '',
                    duong_dung: t.DuongDung || '',
                    cach_dung: t.CachDung || '',
                    so_luong: sl,
                    don_gia: donGia,
                    thanh_tien: roundDecimal(sl * donGia, 3),
                    ngay_ke: getKhamNowDateTime(),
                    id_toa_thuoc_ct_goc: null,
                    ma_loai_toa_thuoc: String(t.MaLoaiToaThuoc || 'c').trim().toLowerCase(),
                    da_thu: false
                });
            });
        }
        // Toolbar SN/Loại toa không được giữ giá trị cũ khi nạp phác đồ mới.
        const soNgay = listToaThuoc.length
            ? Math.max(...listToaThuoc.map(t => Number(t.so_ngay) || 1))
            : 3;
        const soNgayInput = document.getElementById('kb-toa-so-ngay');
        if (soNgayInput) soNgayInput.value = String(soNgay);
        const loaiToa = document.getElementById('kb-loai-toa');
        if (loaiToa) loaiToa.value = listToaThuoc[0]?.ma_loai_toa_thuoc || 'c';
        if (document.getElementById('kb-chk-tai-kham')?.checked) {
            tinhVaGanNgayTaiKham(soNgay);
        }
        renderToaThuocTable();

        markDirty();
        showToast('success', `Đã thay thế toàn bộ dữ liệu khám trên form bằng phác đồ "${currentPhacDoTen}". Hãy kiểm tra lại trước khi lưu.`);
        return true;
    } catch (err) {
        showToast('error', 'Không nạp được phác đồ.');
        return false;
    } finally {
        hidePageloader();
    }
}

// ==========================================
// TẢI & HIỂN THỊ DANH SÁCH BỆNH NHÂN CỘT TRÁI
// ==========================================
async function loadDanhSachBenhNhan(targetId = null) {
    const ngay = document.getElementById('kb-filter-ngay')?.value;
    const tt = document.querySelector('input[name="kb-filter-trang-thai"]:checked')?.value ?? '';
    const tuKhoa = document.getElementById('kb-filter-tu-khoa')?.value;

    let url = `/api/kham_benh/danh_sach?trang=${encodeURIComponent(kbCurrentPage)}&kich_thuoc_trang=${encodeURIComponent(kbPageSize)}`;
    if (ngay) {
        const iso = parseDateVNToISO(ngay);
        if (iso) url += `&ngay=${iso}`;
    }
    if (tt !== '') url += `&trang_thai_kham=${tt}`;
    if (tuKhoa) url += `&tu_khoa=${encodeURIComponent(tuKhoa)}`;

    const res = await withPageloader(() => apiGet(url)
    );
    if (res.status !== 200 || !res.data) {
        kbDataList = [];
        kbServerTotal = 0;
    } else {
        kbDataList = res.data;
        kbServerTotal = kbDataList.length > 0 ? Number(kbDataList[0].TongSoDong || kbDataList.length) : 0;
    }

    if (!kbDataList.length && kbCurrentPage > 1) {
        kbCurrentPage = 1;
        return loadDanhSachBenhNhan(targetId);
    }

    renderTableBenhNhan(targetId);
}

function renderTableBenhNhan(targetId = null) {
    const tbody = document.getElementById('kb-table-body');
    if (!tbody) return;
    tbody.innerHTML = '';

    const total = kbServerTotal;
    if (!kbPagination) {
        kbPagination = createQLPMPagination({
            container: '#kb-pagination',
            tableScrollSelector: '.kham-benh-table-wrap',
            itemName: 'BN',
            pageSize: kbPageSize,
            currentPage: kbCurrentPage,
            pageSizes: [10, 25, 50, 100],
            showCount: true,
            compact: true,
            onPageChange: (newPage, newSize) => {
                kbCurrentPage = newPage;
                kbPageSize = newSize;
                loadDanhSachBenhNhan(selectedIdVaoVien);
            }
        });
    }

    if (!kbDataList || kbDataList.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" class="text-center text-muted py-4">Không có bệnh nhân nào</td></tr>';
        if (kbPagination) kbPagination.render(0, 1);
        return;
    }

    if (kbPagination) {
        kbPagination.render(total, kbCurrentPage);
        kbPageSize = kbPagination.getPageSize();
        kbCurrentPage = kbPagination.getCurrentPage();
    }

    const pageItems = kbDataList;

    pageItems.forEach((bn, index) => {
        const tr = document.createElement('tr');
        tr.setAttribute('data-id-vao-vien', bn.IDVaoVien);
        tr.setAttribute('data-id-benh-nhan', bn.IDBenhNhan);
        const soThuTuHienThi = (kbCurrentPage - 1) * kbPageSize + index + 1;

        const isDangKham = Number(bn.TrangThaiKham) === 1;

        if (bn.TrangThaiKham === 2) {
            tr.className = 'tr-da-kham text-status-da-kham';
        } else if (isDangKham) {
            tr.className = 'tr-dang-kham text-status-dang-kham';
        } else {
            tr.className = 'tr-chua-kham text-status-chua-kham';
        }

        if (selectedIdVaoVien && bn.IDVaoVien === selectedIdVaoVien) {
            tr.classList.add('selected', 'table-active');
        }

        const gcBn = (bn.GhiChuBenhNhan || '').trim();
        const gcLk = (bn.GhiChuLanKham || '').trim();
        const hasNote = Boolean(gcBn || gcLk || bn.CoGhiChu);
        let noteTooltip = '';
        if (gcBn && gcLk) {
            noteTooltip = `Ghi chú BN: ${gcBn}\nGhi chú khám: ${gcLk}`;
        } else if (gcBn) {
            noteTooltip = `Ghi chú BN: ${gcBn}`;
        } else if (gcLk) {
            noteTooltip = `Ghi chú khám: ${gcLk}`;
        } else if (hasNote) {
            noteTooltip = 'Có ghi chú';
        }

        const starHtml = hasNote
            ? `<span class="star-note" data-bs-toggle="tooltip" data-bs-placement="top" title="${escapeHtml(noteTooltip)}">★</span>`
            : '';

        tr.innerHTML = `
            <td class="col-sticky-stt kb-patient-stt-column text-center fw-bold"><span class="kb-patient-stt-value">${soThuTuHienThi}</span></td>
            <td class="fw-bold text-nowrap kb-patient-name-column"><span class="kb-patient-name-wrap"><span class="text-uppercase kb-patient-name-text">${escapeHtml(bn.HoTen || '')}</span>${starHtml}</span></td>
            <td class="text-center small">${bn.NamSinh || (bn.NgaySinh ? new Date(bn.NgaySinh).getFullYear() : '')}</td>
            <td class="text-center small">${bn.GioiTinh === 1 ? 'Nam' : (bn.GioiTinh === 0 ? 'Nữ' : 'Khác')}</td>
            <td><span class="badge bg-light text-dark border small">${escapeHtml(bn.MaBN || '--')}</span></td>
            <td class="text-center col-sticky-ls kb-history-col">
                <button type="button" tabindex="-1" class="btn btn-sm btn-link p-0 text-primary btn-xem-ls" title="Xem lịch sử khám">
                    <i class="bi bi-clock-history"></i>
                </button>
            </td>
        `;

        tr.addEventListener('click', (e) => {
            if (e.target.closest('.btn-xem-ls')) {
                e.stopPropagation();
                moModalLichSu(bn.IDBenhNhan);
                return;
            }
            if (bn.IDVaoVien === selectedIdVaoVien && Number(selectedPatientStatus) !== 2) return;
            chonBenhNhan(bn.IDVaoVien);
        });

        tbody.appendChild(tr);
    });

    // Kích hoạt Bootstrap tooltips cho icon ngôi sao đỏ
    if (window.bootstrap?.Tooltip) {
        const tooltips = tbody.querySelectorAll('[data-bs-toggle="tooltip"]');
        tooltips.forEach(el => new bootstrap.Tooltip(el));
    }

    if (targetId) {
        const found = kbDataList.find(x => x.IDVaoVien == targetId);
        if (found) {
            chonBenhNhan(found.IDVaoVien);
        }
    }
}

// ==========================================
// CHỌN BỆNH NHÂN & TẢI CHI TIẾT LƯỢT KHÁM
// ==========================================
async function chonBenhNhan(idVaoVien, forceReload = false) {
    if (!idVaoVien || isSwitchingPatient || (isCompletingKham && !forceReload) || saveOutcomeUnknown
        || (!forceReload && Number(selectedIdVaoVien) === Number(idVaoVien))) return false;

    isSwitchingPatient = true;
    const patientFromList = kbDataList.find(x => Number(x.IDVaoVien) === Number(idVaoVien));
    showPageloader();
    try {
        const res = await apiPost('/api/kham_benh/chon_benh_nhan', {
            id_vao_vien: idVaoVien
        });

        if (res.status !== 200 || !res.data) {
            showToast('error', res.message || 'Không tải được hồ sơ bệnh nhân.');
            return false;
        }

        const data = res.data;
        const bn = data.thong_tin;
        if (!bn) {
            showToast('error', 'Không tìm thấy hồ sơ trong lượt khám.');
            return false;
        }

        const selectedStatus = Number(bn.TrangThaiKham ?? patientFromList?.TrangThaiKham ?? 0);
        selectedIdVaoVien = idVaoVien;
        selectedDaLuuKham = Boolean(bn?.NgayLuuKhamLanDau);
        selectedIdBenhNhan = bn ? bn.IDBenhNhan : null;
        currentSelectedPatient = bn;
        const patientInList = kbDataList.find(x => Number(x.IDVaoVien) === Number(idVaoVien));
        if (patientInList) patientInList.TrangThaiKham = selectedStatus;
        renderTableBenhNhan();
        setKhamPatientEditing(selectedStatus);

        // Hiển thị khung chi tiết, ẩn empty state
        document.getElementById('kb-empty-state')?.classList.add('d-none');
        document.getElementById('kb-detail-container')?.classList.remove('d-none');
    if (!forceReload) resetKhamSectionNavigation();

        // Header bệnh nhân
        setHeaderHoTen(bn.HoTen || '');
        document.getElementById('kb-header-nam-sinh').value = bn.NgaySinh ? formatDateVN(bn.NgaySinh) : '';
        const gt = (bn.GioiTinh !== undefined && bn.GioiTinh !== null) ? bn.GioiTinh : (kbDataList.find(x => Number(x.IDVaoVien) === Number(idVaoVien))?.GioiTinh ?? 1);
        setHeaderGioiTinh(gt);

        await hienThiPhacDoDaChon(bn.IDPhacDo || null, bn.MaPDGoc || '', '');

        // 1. Sinh hiệu
        fillSinhHieuInputs(data.sinh_hieu);
        const bpCurrent = tachHuyetAp(document.getElementById('sh-huyet-ap')?.value || '');
        currentVitals = {
            mach: document.getElementById('sh-mach')?.value || '',
            nhiet_do: document.getElementById('sh-nhiet-do')?.value || '',
            huyet_ap: document.getElementById('sh-huyet-ap')?.value || '',
            huyet_ap_tam_thu: bpCurrent.tamThu,
            huyet_ap_tam_truong: bpCurrent.tamTruong,
            nhip_tho: document.getElementById('sh-nhip-tho')?.value || '',
            spo2: document.getElementById('sh-spo2')?.value || '',
            chieu_cao: document.getElementById('sh-chieu-cao')?.value || '',
            can_nang: document.getElementById('sh-can-nang')?.value || '',
            bmi: document.getElementById('sh-bmi')?.value || ''
        };

        // 2. Triệu chứng lâm sàng
        document.getElementById('kb-trieu-chung').value = bn.TrieuChung || '';

        // 3. Chẩn đoán ICD10
        listChanDoan = [];
        if (data.chan_doan && data.chan_doan.length > 0) {
            listChanDoan = data.chan_doan.map(c => ({
                id_icd10: c.IDICD10,
                ma_benh: c.MaBenh,
                ten_benh: c.TenBenh,
                ban_dau: c.BanDau === true,
                benh_chinh: c.BenhChinh === true,
                benh_khac: c.BenhKhac === true,
                ghi_chu: c.GhiChu || ''
            }));
        }
        chuanHoaThuTuChanDoan();
        renderChanDoanTable();

        // 4. Chỉ định dịch vụ
        listChiDinh = [];
        if (data.chi_dinh && data.chi_dinh.length > 0) {
            listChiDinh = data.chi_dinh.map(cd => {
                const guiNgoai = cd.GuiNgoai === true;
                const donGiaGoc = roundDecimal((cd.DaThu === true || cd.KhoaNghiepVu === true)
                    ? (cd.DonGia ?? 0) : (cd.DonGiaDanhMuc ?? cd.DonGia ?? 0), 3);
                const donGia = guiNgoai ? 0 : donGiaGoc;
                const soLuong = roundDecimal(cd.SoLuong || 1, 3);
                return {
                    id: cd.ID,
                    id_dich_vu: cd.IDDichVu,
                    ma_dich_vu: cd.MaDichVu,
                    ten_dich_vu: cd.TenDichVu,
                    ngay_gio_chi_dinh: cd.NgayGioChiDinh || null,
                    don_gia: donGia,
                    don_gia_goc: donGiaGoc,
                    so_luong: soLuong,
                    thanh_tien: roundDecimal(soLuong * donGia, 3),
                    gui_ngoai: guiNgoai,
                    noi_gui_ngoai: cd.NoiGuiNgoai || '',
                    noi_dung_mau: cd.NoiDungMau || null,
                    ghi_chu: cd.GhiChu || '',
                    id_chi_dinh_ct_goc: cd.IDChiDinhCTGoc || null,
                    da_thu: cd.DaThu === true,
                    khoa_nghiep_vu: cd.KhoaNghiepVu === true,
                    trang_thai_ket_qua: Number(cd.TrangThaiKetQua || 0),
                    co_file_ket_qua: cd.CoFileKetQua === true,
                    duong_dan_ket_qua: cd.DuongDanKetQua || null
                };
            });
        }
        renderChiDinhTable();

        // 5. Toa thuốc
        listToaThuoc = [];
        if (data.toa_thuoc && data.toa_thuoc.length > 0) {
            listToaThuoc = data.toa_thuoc.map(t => {
                const soLuong = roundDecimal(t.SoLuong || 1, 3);
                const donGia = roundDecimal(t.DonGia || 0, 3);
                return {
                    id: t.ID,
                    ma_loai_toa_thuoc: t.MaLoaiToaThuoc || 'c',
                    id_thuoc: t.IDThuoc,
                    ma_thuoc: t.MaThuoc,
                    ten_thuoc: t.TenThuoc,
                    ten_hoat_chat: t.HoatChat || t.TenHoatChat || '',
                    don_vi_tinh: t.DonViTinh || '',
                    id_don_vi_tinh_dung: t.IDDonViTinhDung || null,
                    so_ngay: t.SoNgay || 1,
                    sang: t.Sang || '0',
                    trua: t.Trua || '0',
                    chieu: t.Chieu || '0',
                    toi: t.Toi || '0',
                    lieu_dung: t.LieuDung || '',
                    cach_dung: t.CachDung || '',
                    so_luong: soLuong,
                    don_gia: donGia,
                    thanh_tien: roundDecimal(soLuong * donGia, 3),
                    ngay_ke: t.NgayKe || getKhamNowDateTime(),
                    id_toa_thuoc_ct_goc: t.IDToaThuocCTGoc || null,
                    da_thu: t.DaThu === true,
                    khoa_nghiep_vu: t.KhoaNghiepVu === true
                };
            });
        }
        const loadedType = listToaThuoc[0]?.ma_loai_toa_thuoc || 'c';
        const typeSelect = document.getElementById('kb-loai-toa');
        if (typeSelect) typeSelect.value = loadedType;
        renderToaThuocTable();

        // 6. Tái khám
        if (bn.NgayTaiKham) {
            const d = new Date(bn.NgayTaiKham);
            document.getElementById('kb-ngay-tai-kham').value = `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}/${d.getFullYear()}`;
            if (document.getElementById('kb-chk-tai-kham')) {
                document.getElementById('kb-chk-tai-kham').checked = true;
                document.getElementById('kb-ngay-tai-kham').disabled = false;
            }
        } else {
            document.getElementById('kb-ngay-tai-kham').value = '';
            if (document.getElementById('kb-chk-tai-kham')) {
                // Chỉ tự tick cho lượt chưa lưu; hồ sơ đã lưu không có
                // NgayTaiKham nghĩa là bác sĩ đã chủ động không hẹn tái khám.
                const defaultTaiKham = !selectedDaLuuKham && selectedStatus !== 2;
                document.getElementById('kb-chk-tai-kham').checked = defaultTaiKham;
                document.getElementById('kb-ngay-tai-kham').disabled = !defaultTaiKham;
                if (defaultTaiKham) {
                    const soNgayMacDinh = listToaThuoc.length
                        ? Math.max(...listToaThuoc.map(t => parseInt(t.so_ngay) || 1))
                        : 3;
                    document.getElementById('kb-toa-so-ngay').value = String(soNgayMacDinh);
                    tinhVaGanNgayTaiKham(soNgayMacDinh);
                }
            }
        }
        document.getElementById('kb-dan-do').value = bn.DanDo || '';

        const maxNgay = listToaThuoc.length
            ? Math.max(...listToaThuoc.map(t => parseInt(t.so_ngay) || 1))
            : 3;
        if (document.getElementById('kb-toa-so-ngay')) {
            document.getElementById('kb-toa-so-ngay').value = String(maxNgay || 3);
        }

        autoSwitchSubTab();

        // Các control có thể được khởi tạo/mở khóa khi nạp dữ liệu.
        // Áp trạng thái lần cuối sau khi render để hồ sơ khám xong luôn chỉ đọc.
        setKhamPatientEditing(selectedStatus);

        // Highlight row trong bảng bên trái
        document.querySelectorAll('#kb-table-body tr').forEach(row => {
            if (row.getAttribute('data-id-vao-vien') == idVaoVien) {
                row.classList.add('selected', 'table-active');
            } else {
                row.classList.remove('selected', 'table-active');
            }
        });

        clearDirty();
        return true;
    } catch (err) {
        showToast('error', 'Không tải được thông tin khám.');
        return false;
    } finally {
        hidePageloader();
        isSwitchingPatient = false;
    }
}

// ==========================================
// RENDER BẢNG CHẨN ĐOÁN chẩn đoán
// ==========================================
function themChanDoan(item) {
    if (listChanDoan.length >= 12) {
        showToast('warning', 'Chỉ chọn tối đa 12 chẩn đoán.');
        return;
    }
    if (listChanDoan.some(x => x.id_icd10 === item.id_icd10)) {
        showToast('warning', 'Bệnh này đã có trong danh sách chẩn đoán.');
        return;
    }

    // Phân loại mặc định theo thứ tự chọn ICD:
    // 1) ICD đầu tiên  = Bệnh ban đầu
    // 2) ICD thứ hai   = Bệnh chính
    // 3) Từ ICD thứ ba = #
    const viTriMoi = listChanDoan.length;
    const itemFull = {
        ...item,
        ban_dau: viTriMoi === 0,
        benh_chinh: viTriMoi === 1,
        benh_khac: viTriMoi >= 2
    };

    listChanDoan.push(itemFull);
    chuanHoaThuTuChanDoan();
    markDirty();
    renderChanDoanTable();
}

function chuanHoaThuTuChanDoan() {
    if (listChanDoan.length === 0) return;

    // BĐ / Chính / # là các cờ độc lập trên cùng một ICD.
    // Chỉ giữ quy tắc nghiệp vụ: tối đa 1 bệnh chính trong một lượt khám.
    const idxChinh = listChanDoan.findIndex(x => x.benh_chinh);
    if (idxChinh >= 0) {
        listChanDoan.forEach((x, i) => {
            if (i !== idxChinh) x.benh_chinh = false;
        });
    }
}

function renderChanDoanTable() {
    const tbody = document.getElementById('kb-tbody-icd10');
    if (!tbody) return;
    tbody.innerHTML = '';

    if (listChanDoan.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" class="text-center text-muted py-2">Chưa có chẩn đoán. Gõ tìm kiếm chẩn đoán phía trên để thêm.</td></tr>';
        capRenderedTableRows('.kb-icd-scroll', '#kb-table-icd10', 3);
        return;
    }

    listChanDoan.forEach((cd, index) => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td>${escapeHtml(cd.ma_benh || '')}</td>
            <td>${escapeHtml(cd.ten_benh || '')}</td>
            <td class="text-center">
                <input type="checkbox" class="form-check-input chk-ban-dau" ${cd.ban_dau ? 'checked' : ''} />
            </td>
            <td class="text-center">
                <input type="checkbox" class="form-check-input chk-benh-chinh" ${cd.benh_chinh ? 'checked' : ''} />
            </td>
            <td class="text-center">
                <input type="checkbox" class="form-check-input chk-benh-khac" ${cd.benh_khac ? 'checked' : ''} />
            </td>
            <td class="text-center">
                <button type="button" tabindex="-1" class="btn btn-sm btn-link text-danger p-0 btn-xoa-cd"><i class="bi bi-trash"></i></button>
            </td>
        `;

        // Sự kiện checkbox Ban đầu
        tr.querySelector('.chk-ban-dau').addEventListener('change', (e) => {
            cd.ban_dau = e.target.checked;
            markDirty();
        });

        // Checkbox Chính: độc lập với BĐ và #, nhưng mỗi lượt chỉ có tối đa 1 bệnh chính.
        tr.querySelector('.chk-benh-chinh').addEventListener('change', (e) => {
            cd.benh_chinh = e.target.checked;
            if (cd.benh_chinh) {
                listChanDoan.forEach((item, i) => {
                    if (i !== index) item.benh_chinh = false;
                });
            }
            markDirty();
            renderChanDoanTable();
        });

        // Checkbox #: độc lập, không tự bỏ cờ BĐ hoặc Chính.
        tr.querySelector('.chk-benh-khac').addEventListener('change', (e) => {
            cd.benh_khac = e.target.checked;
            markDirty();
        });

        // Xóa chẩn đoán
        tr.querySelector('.btn-xoa-cd').addEventListener('click', () => {
            listChanDoan.splice(index, 1);
            chuanHoaThuTuChanDoan();
            markDirty();
            renderChanDoanTable();
        });

        tbody.appendChild(tr);
    });

    capRenderedTableRows('.kb-icd-scroll', '#kb-table-icd10', 3);
}

// ==========================================
// RENDER BẢNG CHỈ ĐỊNH DỊCH VỤ / CẬN LÂM SÀNG
// ==========================================
function themChiDinh(item) {
    if (listChiDinh.some(x => x.id_dich_vu === item.id_dich_vu)) {
        showToast('warning', 'Dịch vụ này đã được thêm vào danh sách.');
        return;
    }
    item.gui_ngoai = item.gui_ngoai === true;
    item.ngay_gio_chi_dinh = item.ngay_gio_chi_dinh || item.NgayGioChiDinh || getKhamNowDateTime();
    item.don_gia_goc = roundDecimal(item.don_gia_goc ?? item.don_gia ?? 0, 3);
    item.don_gia = item.gui_ngoai ? 0 : item.don_gia_goc;
    item.thanh_tien = roundDecimal((parseFloat(item.so_luong) || 1) * item.don_gia, 3);
    listChiDinh.push(item);
    markDirty();
    renderChiDinhTable();
    openKhamBenhCollapse('dvkt');
}

function clsHasResult(order) {
    return order?.co_file_ket_qua === true || !!(order?.duong_dan_ket_qua);
}

function dongKhamDaKhoa(row) {
    return row?.da_thu === true || row?.khoa_nghiep_vu === true;
}

function renderChiDinhTable() {
    const tbody = document.getElementById('kb-tbody-chi-dinh');
    const totalEl = document.getElementById('kb-chi-dinh-tong-tien');

    if (!tbody) return;

    chiDinhDateTimePickerInstances.forEach(instance => {
        try { instance?.destroy?.(); } catch (_) { }
    });
    chiDinhDateTimePickerInstances = [];
    tbody.innerHTML = '';

    let tongTien = 0;
    if (listChiDinh.length === 0) {
        tbody.innerHTML = '<tr><td colspan="7" class="text-center text-muted py-2">Chưa có chỉ định dịch vụ.</td></tr>';
        if (totalEl) totalEl.innerText = 'Cộng CĐ: 0 đ';
        updateRecordTotal();
        capRenderedTableRows('.kb-order-scroll', '#kb-table-chi-dinh', 3);
        return;
    }

    listChiDinh.forEach((ci, index) => {
        ci.don_gia_goc = roundDecimal(ci.don_gia_goc ?? ci.don_gia ?? 0, 3);
        ci.don_gia = ci.gui_ngoai ? 0 : ci.don_gia_goc;
        ci.thanh_tien = roundDecimal((parseFloat(ci.so_luong) || 1) * ci.don_gia, 3);
        tongTien += ci.thanh_tien;
        const hasResult = clsHasResult(ci);
        const resultTitle = hasResult
            ? 'Mở tài liệu kết quả'
            : 'Chưa có tài liệu kết quả';
        const tr = document.createElement('tr');

        ci.ngay_gio_chi_dinh = ci.ngay_gio_chi_dinh || getKhamNowDateTime();

        tr.innerHTML = `
            <td class="kb-order-datetime-col p-0">
                <div class="kb-ngay-ke-picker-host">
                    <input type="text"
                           id="kb-chi-dinh-ngay-gio-${index}"
                           class="form-control form-control-sm form-table text-center inp-ngay-chi-dinh"
                           value="${escapeHtml(formatKhamDateWithEllipsis(ci.ngay_gio_chi_dinh))}"
                           title="${escapeHtml(formatKhamDateTime(ci.ngay_gio_chi_dinh))}"
                           autocomplete="off"
                           ${dongKhamDaKhoa(ci) ? 'disabled' : ''} />
                </div>
            </td>
            <td class="kb-sticky-service-col">
                <div class="kb-service-name-cell" title="${escapeHtml((ci.ten_dich_vu || '') + (ci.ma_dich_vu ? ' (' + ci.ma_dich_vu + ')' : ''))}">
                    <span class="fw-semibold">${escapeHtml(ci.ten_dich_vu || '')}</span>
                    ${ci.ma_dich_vu ? '<small class="text-muted ms-1">(' + escapeHtml(ci.ma_dich_vu) + ')</small>' : ''}
                </div>
            </td>
            <td class="text-center">
                <input type="number" step="any" class="form-control form-control-sm text-center p-0 inp-sl"
                       min="1" value="${ci.so_luong}" ${dongKhamDaKhoa(ci) ? 'disabled' : ''} />
            </td>
            <td class="text-end">${formatNumberVN(ci.don_gia || 0)}</td>
            <td class="text-center">
                <button type="button" tabindex="-1"
                        class="btn btn-sm btn-link p-0 btn-kq-cls ${hasResult ? 'kq-co' : 'kq-chua-co'}"
                        ${hasResult ? '' : 'disabled'}
                        title="${escapeHtml(resultTitle)}"
                        aria-label="${escapeHtml(resultTitle)}">
                    <i class="bi bi-eye kb-eye-icon"></i>
                </button>
            </td>
            <td class="text-center">
                <input type="checkbox" class="form-check-input chk-gui-ngoai"
                       ${ci.gui_ngoai ? 'checked' : ''} ${dongKhamDaKhoa(ci) ? 'disabled' : ''}
                       title="Gửi thực hiện ngoài cơ sở" />
            </td>
            <td class="text-center text-nowrap kb-order-actions-col">
                <div class="kb-order-actions">
                    <button type="button" tabindex="-1" class="btn btn-sm btn-link text-primary p-0 btn-cls-upload kb-order-action-btn"
                            ${Number(ci.id_dich_vu) > 0 ? '' : 'disabled'} title="Tải file kết quả lên" aria-label="Tải file kết quả lên">
                        <i class="bi bi-file-earmark-arrow-up"></i>
                    </button>
                    ${dongKhamDaKhoa(ci)
                        ? '<button type="button" tabindex="-1" class="btn btn-sm btn-link text-danger opacity-50 p-0 btn-xoa-ci kb-order-action-btn" title="Không thể xóa: chỉ định đã thu hoặc bị khóa nghiệp vụ" aria-label="Không thể xóa chỉ định" disabled><i class="bi bi-trash"></i></button>'
                        : '<button type="button" tabindex="-1" class="btn btn-sm btn-link text-danger p-0 btn-xoa-ci kb-order-action-btn" title="Xóa chỉ định"><i class="bi bi-trash"></i></button>'}
                </div>
            </td>
        `;

        const inpNgayChiDinh = tr.querySelector('.inp-ngay-chi-dinh');
        if (inpNgayChiDinh) {
            initToaDateTimePicker(
                inpNgayChiDinh,
                ci.ngay_gio_chi_dinh,
                (_displayValue, dateTimeValue) => {
                    ci.ngay_gio_chi_dinh = dateTimeValue;
                    markDirty();
                },
                dongKhamDaKhoa(ci),
                chiDinhDateTimePickerInstances
            );
        }

        tr.querySelector('.inp-sl')?.addEventListener('input', (evt) => {
            const sl = roundDecimal(parseFloat(evt.target.value) || 1, 3);
            ci.so_luong = sl;
            ci.thanh_tien = roundDecimal(sl * (parseFloat(ci.don_gia) || 0), 0);
            markDirty();
            renderChiDinhTable();
        });

        tr.querySelector('.chk-gui-ngoai')?.addEventListener('change', (evt) => {
            ci.gui_ngoai = evt.target.checked;
            ci.don_gia = ci.gui_ngoai ? 0 : roundDecimal(ci.don_gia_goc || 0, 3);
            ci.thanh_tien = roundDecimal((parseFloat(ci.so_luong) || 1) * ci.don_gia, 3);
            markDirty();
            renderChiDinhTable();
        });

        tr.querySelector('.btn-kq-cls')?.addEventListener('click', () => moXemKetQuaCls(ci));
        tr.querySelector('.btn-cls-upload')?.addEventListener('click', () => moTaiFileKetQuaCls(ci));

        tr.querySelector('.btn-xoa-ci')?.addEventListener('click', async () => {
            if (hasResult) {
                const ok = await hien_thi_xac_nhan({
                    tieu_de: 'Xóa chỉ định có kết quả',
                    noi_dung: 'Chỉ định này đã có file kết quả CLS. Khi lưu, file sẽ bị gỡ khỏi hồ sơ và xóa khỏi máy chủ. Bạn có muốn tiếp tục?',
                    nhan_dong_y: 'Xóa chỉ định',
                    lop_nut: 'btn-danger'
                });
                if (!ok) return;
            }
            listChiDinh.splice(index, 1);
            markDirty();
            renderChiDinhTable();
        });

        tbody.appendChild(tr);
    });

    tongTien = roundDecimal(tongTien, 0);
    if (totalEl) totalEl.innerText = `Cộng CĐ: ${formatNumberVN(tongTien)} đ`;
    updateRecordTotal();
    capRenderedTableRows('.kb-order-scroll', '#kb-table-chi-dinh', 3);
}

// ==========================================
// RENDER BẢNG TOA THUỐC (CHUẨN HISSOFT: INLINE GRID ENTRY)
// ==========================================
function tinhVaGanNgayTaiKham(soNgay) {
    const n = parseInt(soNgay) || 0;
    if (n <= 0) return;
    const targetDate = new Date();
    targetDate.setDate(targetDate.getDate() + n);
    const d = String(targetDate.getDate()).padStart(2, '0');
    const m = String(targetDate.getMonth() + 1).padStart(2, '0');
    const y = targetDate.getFullYear();
    const str = `${d}/${m}/${y}`;
    const inp = document.getElementById('kb-ngay-tai-kham');
    if (inp) {
        inp.value = str;
        if (inp._flatpickr) {
            inp._flatpickr.setDate(targetDate, false);
        }
    }
}

function updateToaThuocTotals() {
    let tongTien = 0;
    listToaThuoc.forEach(t => {
        tongTien += (parseFloat(t.thanh_tien) || 0);
    });
    tongTien = roundDecimal(tongTien, 0);

    const totalEl = document.getElementById('kb-toa-thuoc-tong-tien');
    if (totalEl) totalEl.innerText = `Tổng tiền thuốc: ${formatNumberVN(tongTien)} đ`;

    const footerTotalEl = document.getElementById('kb-footer-tong-tien');
    if (footerTotalEl) footerTotalEl.innerHTML = `<i class="bi bi-cash-stack me-1"></i> Cộng Thuốc: <strong>${formatNumberVN(tongTien)} đ</strong>`;

    updateRecordTotal();
}

function themToaThuoc(item) {
    if (listToaThuoc.some(x => x.id_thuoc === item.id_thuoc)) {
        showToast('warning', 'Thuốc này đã có trong đơn thuốc.');
        return;
    }
    item.ngay_ke = item.ngay_ke || getKhamNowDateTime();
    listToaThuoc.push(item);
    markDirty();
    renderToaThuocTable({ focusIndex: listToaThuoc.length - 1, focusField: 'sngay' });
    openKhamBenhCollapse('toa_thuoc');
}


/* Danh sách thuốc theo HIS: dữ liệu danh mục JSON, tồn kho kiểm tra trực tiếp. */
function kbDrugCacheKey(maLoaiToa, query) {
    return String(maLoaiToa || 'c').trim().toLowerCase() + '|' + String(query || '').trim().toLowerCase();
}

function kbCloneDrugItems(items) {
    return (items || []).map(item => ({ ...item }));
}

function kbGetCachedDrugItems(key) {
    const cached = kbDrugCatalogCache.get(key);
    if (!cached) return null;
    if (Date.now() - cached.at > KB_DRUG_CACHE_TTL_MS) {
        kbDrugCatalogCache.delete(key);
        return null;
    }
    return kbCloneDrugItems(cached.items);
}

function kbSetCachedDrugItems(key, items) {
    if (kbDrugCatalogCache.size >= KB_DRUG_CACHE_MAX) {
        const oldestKey = kbDrugCatalogCache.keys().next().value;
        if (oldestKey !== undefined) kbDrugCatalogCache.delete(oldestKey);
    }
    kbDrugCatalogCache.set(key, { at: Date.now(), items: kbCloneDrugItems(items) });
}

function kbApplyDrugStockResult(items, stocks) {
    if (!Array.isArray(items) || !Array.isArray(stocks)) return;
    const map = new Map(stocks.map(x => [Number(x.row_index), x]));
    items.forEach((item, index) => {
        const value = map.get(index);
        if (!value) return;
        const hasWarehouse = value.co_kho === true || Number(value.co_kho) === 1;
        const convertible = value.co_quy_doi === true || Number(value.co_quy_doi) === 1;
        item.his_stock_status = !hasWarehouse ? 'no_warehouse' : !convertible ? 'no_conversion' : 'ok';
        item.his_stock_quantity = convertible && value.ton_theo_dvt != null
            ? Number(value.ton_theo_dvt)
            : null;
    });
}


function kbHISDrugOption(data, escape) {
    const price = data.gia_ban ?? data.don_gia;
    const stockState = data.his_stock_status;
    const stockText = stockState === 'ok'
        ? formatNumberVN(roundDecimal(Number(data.his_stock_quantity || 0), 3))
        : stockState === 'no_warehouse' ? 'Chưa có kho'
        : stockState === 'no_conversion' ? 'Chưa quy đổi ĐVT'
        : stockState === 'loading' ? 'Đang kiểm tra...'
        : 'Chưa xác định';
    const stockColor = stockState === 'ok'
        ? (Number(data.his_stock_quantity || 0) > 0 ? 'text-success' : 'text-danger')
        : (stockState ? 'text-warning' : 'text-muted');
    return '<div class="kb-his-drug-option">' +
        '<div class="kb-his-drug-info">' +
            '<div class="kb-his-drug-name">' + escape(data.ten || '') + '</div>' +
            '<div class="kb-his-drug-fields">' +
                '<span><b>HL:</b> ' + escape(data.ham_luong || '—') + '</span>' +
                '<span><b>HC:</b> ' + escape(data.hoat_chat || '—') + '</span>' +
                '<span><b>ĐVT:</b> ' + escape(data.don_vi_tinh || '—') + '</span>' +
                '<span><b>ĐD:</b> ' + escape(data.duong_dung || '—') + '</span>' +
            '</div>' +
        '</div>' +
        '<div class="kb-his-drug-stockbox">' +
            '<div class="' + stockColor + '"><b>Tồn:</b> ' + escape(stockText) + '</div>' +
            '<div><b>Giá DV:</b> ' + (price == null ? '—' : escape(formatNumberVN(Number(price)) + ' đ')) + '</div>' +
        '</div>' +
    '</div>';
}

function kbHISDrugPickerOptions(maLoaiToa) {
    return {
        placeholder: 'Tìm tên thuốc, hoạt chất...',
        dropdownParent: 'body',
        preload: 'focus',
        loadThrottle: 100,
        maxOptions: 30,
        load: async function (query, callback) {
            const picker = this;
            const typeCode = String(maLoaiToa || 'c').trim().toLowerCase();
            const searchText = String(query || '');
            const cacheKey = kbDrugCacheKey(typeCode, searchText);
            let items = kbGetCachedDrugItems(cacheKey);

            if (!items) {
                try {
                    const params = new URLSearchParams({
                        q: searchText,
                        top: '30',
                        ma_loai_toa_thuoc: typeCode
                    });
                    const response = await fetch('/api/danh_muc/dm_thuoc?' + params, { credentials: 'same-origin' });
                    if (!response.ok) throw new Error('Không lấy được danh mục thuốc');
                    const json = await response.json();
                    items = Array.isArray(json.data) ? json.data : [];
                    kbSetCachedDrugItems(cacheKey, items);
                } catch (_) {
                    callback();
                    return;
                }
            }

            // Không chờ DB tồn kho mới mở dropdown. Danh mục thuốc hiện ngay;
            // tồn kho chỉ là thông tin bổ sung và được cập nhật nền.
            items.forEach(item => {
                if (!item.his_stock_status) item.his_stock_status = 'loading';
            });
            callback(items);

            if (!items.length) return;

            try {
                const stocks = await apiPost('/api/kham_benh/kiem_tra_ton_thuoc', {
                    danh_sach: items.map((item, index) => ({
                        row_index: index,
                        id_thuoc: Number(item.id || 0),
                        id_don_vi_tinh: Number(item.id_don_vi_tinh || 0) || null,
                        so_luong: 1
                    }))
                });

                if (stocks?.status !== 200 || !Array.isArray(stocks.data)) return;
                kbApplyDrugStockResult(items, stocks.data);

                items.forEach(item => {
                    const key = String(item.id);
                    const current = picker?.options?.[key];
                    if (!current || typeof picker.updateOption !== 'function') return;
                    picker.updateOption(key, { ...current, ...item });
                });

                if (picker?.isOpen && typeof picker.refreshOptions === 'function') {
                    picker.refreshOptions(false);
                }
            } catch (_) {
                // Dropdown vẫn dùng được; khi chọn thuốc hệ thống còn kiểm tra tồn
                // trực tiếp trước lưu nên không hạ mức an toàn nghiệp vụ.
            }
        },
        render: {
            option: kbHISDrugOption,
            item: (data, escape) => '<div class="kb-medicine-selected">' + escape(data.ten || '') + '</div>'
        }
    };
}

function kbBindHISDrugDropdown(picker, replacement = false) {
    if (!picker) return;
    picker.dropdown?.classList.add('kb-his-drug-dropdown', 'kb-exam-dropdown');
    if (replacement) picker.dropdown?.classList.add('kb-drug-replace-dropdown');
    const reposition = () => {
        if (!picker.isOpen || !picker.dropdown || !picker.wrapper) return;
        const r = picker.wrapper.getBoundingClientRect();
        const vw = document.documentElement.clientWidth || window.innerWidth, vh = window.innerHeight;
        const margin = 12, width = Math.min(840, vw - 2 * margin);
        const left = Math.max(margin, Math.min(r.left, vw - width - margin));
        const below = vh - r.bottom - margin, above = r.top - margin;
        const opensUp = below < 235 && above > below;
        const height = Math.max(95, Math.min(365, (opensUp ? above : below) - 8));
        // HIS chừa khoảng hở giữa ô chọn và mép popup, kể cả khi xổ lên.
        const gap = 9;
        const top = opensUp ? r.top - height - gap : r.bottom + gap;
        picker.dropdown.style.setProperty('width', Math.round(width) + 'px', 'important');
        picker.dropdown.style.setProperty('min-width', '0', 'important');
        picker.dropdown.style.left = Math.round(window.scrollX + left) + 'px';
        picker.dropdown.style.top = Math.round(window.scrollY + Math.max(margin, top)) + 'px';
        const content = picker.dropdown.querySelector('.ts-dropdown-content');
        if (content) content.style.maxHeight = Math.round(height) + 'px';
    };
    picker.on('dropdown_open', () => requestAnimationFrame(reposition));
    picker.on('load', () => requestAnimationFrame(reposition));
    picker.on('type', () => requestAnimationFrame(reposition));
}

function syncToaThuocThead() {
    const thead = document.querySelector('#kb-table-toa-thuoc thead');
    if (!thead) return;
    thead.innerHTML = `
        <tr class="text-center align-middle bg-light qlpm-one-line-head-row">
            <th class="col-sticky-stt text-center" style="width:26px;min-width:26px;max-width:26px;">TT</th>
            <th class="col-ngay-ke text-center" style="width:72px;min-width:72px;max-width:72px;">Ngày giờ</th>
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
            <th class="col-sticky-sl text-center" style="width:36px;min-width:36px;max-width:36px;">SL</th>
            <th class="col-sticky-xoa text-center" style="width:45px;min-width:45px;max-width:45px;">Xóa</th>
        </tr>
    `;
}

function renderToaThuocTable(focusTarget = null) {
    syncToaThuocThead();

    const tbody = document.getElementById('kb-tbody-toa-thuoc');
    if (!tbody) return;

    if (inlineSelectThuocInstance) {
        inlineSelectThuocInstance.destroy();
        inlineSelectThuocInstance = null;
    }
    if (toaReplacementSelectInstance) {
        try { toaReplacementSelectInstance.destroy(); } catch (_) { }
        toaReplacementSelectInstance = null;
    }

    toaReplacementCleanup = null;

    toaDvtSelectInstances.forEach(instance => {
        try { instance?.destroy(); } catch (_) { }
    });
    toaDvtSelectInstances = [];

    toaDateTimePickerInstances.forEach(instance => {
        try { instance?.destroy?.(); } catch (_) { }
    });
    toaDateTimePickerInstances = [];

    tbody.innerHTML = '';

    // 1. Render các dòng thuốc đã kê
    listToaThuoc.forEach((t, index) => {
        const realIdx = index;
        const tr = document.createElement('tr');
        tr.className = 'align-middle';
        tr.dataset.stockIndex = String(index);

        const valSang = (t.sang !== undefined && t.sang !== null && t.sang !== '' && t.sang !== '0' && t.sang !== 0) ? t.sang : '';
        const valTrua = (t.trua !== undefined && t.trua !== null && t.trua !== '' && t.trua !== '0' && t.trua !== 0) ? t.trua : '';
        const valChieu = (t.chieu !== undefined && t.chieu !== null && t.chieu !== '' && t.chieu !== '0' && t.chieu !== 0) ? t.chieu : '';
        const valToi = (t.toi !== undefined && t.toi !== null && t.toi !== '' && t.toi !== '0' && t.toi !== 0) ? t.toi : '';
        t.ngay_ke = t.ngay_ke || getKhamNowDateTime();

        tr.innerHTML = `
            <td class="col-sticky-stt text-center text-muted fw-bold">${index + 1}</td>
            <td class="col-ngay-ke p-0">
                <div class="kb-ngay-ke-picker-host">
                    <input type="text" id="kb-ngay-ke-${index}" class="form-control form-control-sm form-table text-center inp-ngay-ke" value="${escapeHtml(formatKhamDateWithEllipsis(t.ngay_ke))}" title="${escapeHtml(formatKhamDateTime(t.ngay_ke))}" autocomplete="off" ${dongKhamDaKhoa(t) ? 'disabled' : ''} />
                </div>
            </td>
            <td class="col-sticky-thuoc ${!dongKhamDaKhoa(t) && selectedPatientCanEdit ? 'kb-drug-click-cell' : ''}">
                <div class="kb-drug-name-host px-1">
                    <span class="kb-drug-current-name" title="${escapeHtml(t.ten_thuoc || '')}">${escapeHtml(t.ten_thuoc || '')}</span>
                </div>
            </td>
            <td>
                <div class="text-muted small px-1 text-truncate" title="${escapeHtml(t.ten_hoat_chat || '')}">${escapeHtml(t.ten_hoat_chat || '-')}</div>
            </td>
            <td class="text-center">
                <input type="number" class="form-control form-control-sm form-table text-center inp-sngay" value="${t.so_ngay || 1}" min="1" max="90" ${dongKhamDaKhoa(t) ? 'disabled' : ''} />
            </td>
            <td class="text-center">${escapeHtml(t.don_vi_tinh || 'Viên')}</td>
            <td class="text-center">
                <input type="text" inputmode="decimal" pattern="[0-9]*[.,]?[0-9]*" class="form-control form-control-sm form-table text-center inp-sang" value="${valSang}" ${dongKhamDaKhoa(t) ? 'disabled' : ''} />
            </td>
            <td class="text-center">
                <input type="text" inputmode="decimal" pattern="[0-9]*[.,]?[0-9]*" class="form-control form-control-sm form-table text-center inp-trua" value="${valTrua}" ${dongKhamDaKhoa(t) ? 'disabled' : ''} />
            </td>
            <td class="text-center">
                <input type="text" inputmode="decimal" pattern="[0-9]*[.,]?[0-9]*" class="form-control form-control-sm form-table text-center inp-chieu" value="${valChieu}" ${dongKhamDaKhoa(t) ? 'disabled' : ''} />
            </td>
            <td class="text-center">
                <input type="text" inputmode="decimal" pattern="[0-9]*[.,]?[0-9]*" class="form-control form-control-sm form-table text-center inp-toi" value="${valToi}" ${dongKhamDaKhoa(t) ? 'disabled' : ''} />
            </td>
            <td class="text-center small">${escapeHtml(t.duong_dung || 'Uống')}</td>
            <td>
                <input type="text" class="form-control form-control-sm form-table inp-cach-dung" value="${escapeHtml(t.cach_dung || '')}" ${dongKhamDaKhoa(t) ? 'disabled' : ''} />
            </td>
            <td class="text-end small px-1">${formatNumberVN(t.don_gia || 0)}</td>
            <td class="text-end px-1 cell-thanh-tien">${formatNumberVN(t.thanh_tien || 0)}</td>
            <td class="col-sticky-dvt-dung p-0">
                <select id="kb-dvt-dung-${index}" class="form-select form-select-sm form-table inp-dvt-dung" ${dongKhamDaKhoa(t) ? 'disabled' : ''}>
                    <option value="${escapeHtml(t.don_vi_tinh || 'Viên')}" selected>${escapeHtml(t.don_vi_tinh || 'Viên')}</option>
                </select>
            </td>
            <td class="col-sticky-sl p-0">
                <input type="number" step="any" class="form-control form-control-sm form-table text-center inp-sl" min="0" value="${t.so_luong || 1}" ${dongKhamDaKhoa(t) ? 'disabled' : ''} />
            </td>
            <td class="col-sticky-xoa text-center">
                ${dongKhamDaKhoa(t) ? '<button type="button" tabindex="-1" class="btn btn-sm btn-link btn-xoa-row text-danger opacity-50 p-0 btn-xoa-t" title="Không thể xóa: thuốc đã thu hoặc bị khóa nghiệp vụ" aria-label="Không thể xóa thuốc" disabled><i class="bi bi-trash"></i></button>' : '<button type="button" tabindex="-1" class="btn btn-sm btn-link btn-xoa-row p-0 btn-xoa-t" title="Xóa thuốc"><i class="bi bi-trash"></i></button>'}
            </td>
        `;

        const inpSngay = tr.querySelector('.inp-sngay');
        const inpSang = tr.querySelector('.inp-sang');
        const inpTrua = tr.querySelector('.inp-trua');
        const inpChieu = tr.querySelector('.inp-chieu');
        const inpToi = tr.querySelector('.inp-toi');
        const inpCachDung = tr.querySelector('.inp-cach-dung');
        const inpSl = tr.querySelector('.inp-sl');
        const inpNgayKe = tr.querySelector('.inp-ngay-ke');
        const inpDvtDung = tr.querySelector('.inp-dvt-dung');
        const cellThanhTien = tr.querySelector('.cell-thanh-tien');

        // Bấm toàn bộ ô tên thuốc để đổi; dòng đã thu/khóa không thể sửa.
        const drugCell = tr.querySelector('td.col-sticky-thuoc');
        const openDrugReplacement = () => {
            if (!selectedPatientCanEdit || dongKhamDaKhoa(t)) return;
            if (drugCell?.classList.contains('kb-drug-editing')) return;
            toaReplacementCleanup?.();

            const host = tr.querySelector('.kb-drug-name-host');
            const name = tr.querySelector('.kb-drug-current-name');
            if (!host || !name || !drugCell) return;
            drugCell.classList.add('kb-drug-editing');
            name.classList.add('d-none');

            const selector = document.createElement('select');
            selector.className = 'kb-drug-replace-select w-100';
            host.appendChild(selector);
            let applied = false;
            let picker = null;
            let closed = false;
            const restore = () => {
                if (applied || closed) return;
                closed = true;
                if (toaReplacementSelectInstance === picker) toaReplacementSelectInstance = null;
                if (toaReplacementCleanup === restore) toaReplacementCleanup = null;
                try { picker?.destroy(); } catch (_) { }
                selector.remove();
                name.classList.remove('d-none');
                drugCell.classList.remove('kb-drug-editing');
            };

            picker = initRemoteTomSelect(selector, 'dm_thuoc',
                kbHISDrugPickerOptions(t.ma_loai_toa_thuoc || 'c'), async (item) => {
                if (!item?.id || listToaThuoc[realIdx] !== t || dongKhamDaKhoa(t)) return;
                if (Number(item.id) === Number(t.id_thuoc)) return restore();
                if (listToaThuoc.some((row, rowIndex) =>
                    rowIndex !== realIdx && Number(row.id_thuoc) === Number(item.id)
                )) {
                    showToast('warning', 'Thuốc này đã có trong toa, vui lòng chọn thuốc khác.');
                    return;
                }

                applied = true;
                t.id_thuoc = item.id;
                t.ma_thuoc = item.ma || '';
                t.ten_thuoc = item.ten || '';
                t.ten_hoat_chat = item.hoat_chat || '';
                t.don_vi_tinh = item.don_vi_tinh || 'Viên';
                t.id_don_vi_tinh_dung = item.id_don_vi_tinh || null;
                t.duong_dung = item.duong_dung || 'Uống';
                // Giữ thời gian kê, số ngày và liều BS đã nhập; giá/ĐVT thay theo thuốc mới.
                t.don_gia = roundDecimal(Number(item.gia_ban || item.don_gia || 0), 0);
                t.thanh_tien = roundDecimal(Number(t.so_luong || 0) * t.don_gia, 0);
                t.ton_trang_thai = '';
                t.ton_kha_dung = 0;
                toaStockCheckRequestId++;
                clearTimeout(toaStockCheckTimer);
                toaStockCheckTimer = null;
                markDirty();
                renderToaThuocTable({ focusIndex: realIdx, focusField: 'sngay' });
                clearTimeout(toaStockCheckTimer);
                toaStockCheckTimer = null;
                showToast('info', 'Đã đổi thuốc. Kiểm tra lại liều dùng, cách dùng và số lượng.');
                await kiemTraTonToaThuoc({ showWarning: true, warningIndex: realIdx });
            });

            if (!picker) return restore();
            toaReplacementSelectInstance = picker;
            toaReplacementCleanup = restore;
            kbBindHISDrugDropdown(picker, true);
            picker.on('dropdown_close', () => {
                setTimeout(() => {
                    if (!applied && toaReplacementSelectInstance === picker) restore();
                }, 0);
            });
            picker.control_input?.addEventListener('keydown', event => {
                if (event.key === 'Escape') {
                    event.preventDefault();
                    event.stopPropagation();
                    restore();
                }
            });
            picker.focus();
            picker.open();

        };

        if (drugCell?.classList.contains('kb-drug-click-cell')) {
            drugCell.tabIndex = 0;
            drugCell.setAttribute('role', 'button');
            drugCell.setAttribute('aria-label', 'Đổi thuốc ' + (t.ten_thuoc || ''));
            drugCell.addEventListener('click', event => {
                // TomSelect đã mở tự quản lý click trong control.
                if (event.target instanceof Element && event.target.closest('.ts-wrapper')) return;
                openDrugReplacement();
            });
            drugCell.addEventListener('keydown', event => {
                if (event.target !== drugCell || !['Enter', ' '].includes(event.key)) return;
                event.preventDefault();
                openDrugReplacement();
            });
        }

        if (inpNgayKe) {
            initToaDateTimePicker(
                inpNgayKe,
                t.ngay_ke,
                (displayValue, dateTimeValue) => {
                    t.ngay_ke = dateTimeValue;
                    markDirty();
                },
                dongKhamDaKhoa(t)
            );
        }

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
                t.don_vi_tinh = item.ten;
                t.id_don_vi_tinh_dung = item.id || null;
                t.ton_trang_thai = '';
                markDirty();
                scheduleToaStockCheck();
            });

            if (dvtSelect) {
                dvtSelect.dropdown?.classList.add('kb-dvt-dung-dropdown', 'kb-exam-dropdown');
                dvtSelect.wrapper?.classList.add('kb-dvt-dung-select');
                toaDvtSelectInstances.push(dvtSelect);
                if (t.don_vi_tinh) {
                    dvtSelect.setValue(t.don_vi_tinh, true);
                }
                if (dongKhamDaKhoa(t)) {
                    dvtSelect.disable();
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

        // Bôi đen khi click vào ô để nhập nhanh
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
            const sl = roundDecimal((sumLieu === 0 ? 1 : sumLieu) * ngay, 3);

            t.sang = inpSang?.value ? inpSang.value.trim() : '0';
            t.trua = inpTrua?.value ? inpTrua.value.trim() : '0';
            t.chieu = inpChieu?.value ? inpChieu.value.trim() : '0';
            t.toi = inpToi?.value ? inpToi.value.trim() : '0';
            t.so_ngay = ngay;
            t.so_luong = sl;
            t.thanh_tien = roundDecimal(sl * (parseFloat(t.don_gia) || 0), 0);
            t.lieu_dung = `${t.sang}-${t.trua}-${t.chieu}-${t.toi}`;

            if (inpSl) inpSl.value = sl;
            if (cellThanhTien) cellThanhTien.innerText = formatNumberVN(t.thanh_tien);

            t.ton_trang_thai = '';
            updateToaThuocTotals();
            markDirty();
            applyToaStockIndicators();
            scheduleToaStockCheck();
        };

        inpSngay?.addEventListener('input', recomputeRow);
        inpSang?.addEventListener('input', recomputeRow);
        inpTrua?.addEventListener('input', recomputeRow);
        inpChieu?.addEventListener('input', recomputeRow);
        inpToi?.addEventListener('input', recomputeRow);

        inpSl?.addEventListener('change', (e) => {
            const sl = roundDecimal(parseFloat(e.target.value) || 1, 3);
            t.so_luong = sl;
            t.thanh_tien = roundDecimal(sl * (parseFloat(t.don_gia) || 0), 0);
            inpSl.value = sl;
            if (cellThanhTien) cellThanhTien.innerText = formatNumberVN(t.thanh_tien);
            t.ton_trang_thai = '';
            updateToaThuocTotals();
            markDirty();
            applyToaStockIndicators();
            scheduleToaStockCheck();
        });

        inpCachDung?.addEventListener('input', (e) => {
            t.cach_dung = e.target.value;
            markDirty();
        });

        // Enter/Tab do initKhamKeyboardNavigation xử lý thống nhất; không đi qua nút thao tác.

        tr.querySelector('.btn-xoa-t')?.addEventListener('click', () => {
            listToaThuoc.splice(realIdx, 1);
            markDirty();
            renderToaThuocTable();
        });

        tbody.appendChild(tr);
    });

    // Dòng nhập thuốc mới: có sẵn Ngày giờ hiện tại nhưng chưa tính là một dòng toa thật.
    let newRowNgayKe = getKhamNowDateTime();
    const pickerTr = document.createElement('tr');
    pickerTr.className = 'kb-drug-picker-row align-middle';
    pickerTr.innerHTML = `
        <td class="text-center"></td>
        <td class="col-ngay-ke p-0">
            <div class="kb-ngay-ke-picker-host">
            <input type="text" id="kb-new-ngay-ke" class="form-control form-control-sm form-table text-center inp-ngay-ke-new" value="${escapeHtml(formatKhamDateWithEllipsis(newRowNgayKe))}" title="${escapeHtml(formatKhamDateTime(newRowNgayKe))}" autocomplete="off" />
            </div>
        </td>
        <td class="col-sticky-thuoc p-0">
            <select id="kb-inline-select-thuoc" class="form-table w-100"></select>
        </td>
        <td colspan="11"></td>
        <td class="col-sticky-dvt-dung"></td>
        <td class="col-sticky-sl"></td>
        <td class="col-sticky-xoa"></td>
    `;
    tbody.appendChild(pickerTr);

    const newNgayKeInput = document.getElementById('kb-new-ngay-ke');
    if (newNgayKeInput) {
        initToaDateTimePicker(newNgayKeInput, newRowNgayKe, (_displayValue, dateTimeValue) => { newRowNgayKe = dateTimeValue; }, false);
    }

    // Chọn thuốc -> biến dòng nhập thành toa thật; render sau đó sinh dòng nhập mới kế tiếp.
    const inlineSelectEl = document.getElementById('kb-inline-select-thuoc');
    if (inlineSelectEl) {
        inlineSelectThuocInstance = initRemoteTomSelect(inlineSelectEl, 'dm_thuoc',
            kbHISDrugPickerOptions(document.getElementById('kb-loai-toa')?.value || 'c'), async (item) => {
            if (!item || !item.id) return;

            const soNgayDefault = parseInt(document.getElementById('kb-toa-so-ngay')?.value) || 3;
            const sang = 1;
            const trua = 0;
            const chieu = 1;
            const toi = 0;
            const sumLieu = sang + trua + chieu + toi;
            const sl = roundDecimal((sumLieu === 0 ? 1 : sumLieu) * soNgayDefault, 3);
            const donGia = roundDecimal(parseFloat(item.gia_ban || item.don_gia) || 0, 0);
            const thanhTien = roundDecimal(sl * donGia, 0);
            const cachDung = (item.duong_dung && item.duong_dung.toLowerCase().includes('bôi'))
                ? 'Bôi ngoài da'
                : ((item.duong_dung && item.duong_dung.toLowerCase().includes('nhỏ'))
                    ? 'Nhỏ mắt/tai'
                    : 'Uống sau ăn');

            const ngayKeMoi = newRowNgayKe || getKhamNowDateTime();

            listToaThuoc.push({
                id: null,
                id_thuoc: item.id,
                ma_thuoc: item.ma || '',
                ten_thuoc: item.ten,
                ten_hoat_chat: item.hoat_chat || '',
                don_vi_tinh: item.don_vi_tinh || 'Viên',
                id_don_vi_tinh_dung: item.id_don_vi_tinh || null,
                duong_dung: item.duong_dung || 'Uống',
                so_ngay: soNgayDefault,
                sang: '1',
                trua: '0',
                chieu: '1',
                toi: '0',
                lieu_dung: `${sang}-${trua}-${chieu}-${toi}`,
                cach_dung: cachDung,
                so_luong: sl,
                don_gia: donGia,
                thanh_tien: thanhTien,
                ngay_ke: ngayKeMoi,
                id_toa_thuoc_ct_goc: null,
                ma_loai_toa_thuoc: String(item.ma_loai_toa_thuoc || document.getElementById('kb-loai-toa')?.value || 'c').trim().toLowerCase(),
                da_thu: false
            });

            markDirty();
            const newIndex = listToaThuoc.length - 1;
            renderToaThuocTable({ focusIndex: newIndex, focusField: 'sngay' });
            openKhamBenhCollapse('toa_thuoc');

            // Chọn thuốc là kiểm tra tồn ngay. Hủy timer render vừa tạo để
            // request nền không ghi đè request cảnh báo tức thời.
            clearTimeout(toaStockCheckTimer);
            toaStockCheckTimer = null;
            await kiemTraTonToaThuoc({ showWarning: true, warningIndex: newIndex });
        });
        kbBindHISDrugDropdown(inlineSelectThuocInstance);
    }

    updateToaThuocTotals();
    capRenderedTableRows('.kb-prescription-scroll', '#kb-table-toa-thuoc', 5);
    applyToaStockIndicators();
    scheduleToaStockCheck();

    // Tự động focus vào ô liều dùng của dòng vừa tạo (nếu có yêu cầu)
    if (focusTarget && focusTarget.focusIndex !== undefined) {
        setTimeout(() => {
            const rows = tbody.querySelectorAll('tr:not(.kb-drug-picker-row)');
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

// ==========================================
// LƯU KẾT QUẢ KHÁM BỆNH (ATOMIC)
// ==========================================
function capNhatDanhSachBenhNhanSauLuu(idVaoVien, trangThaiKham) {
    const id = Number(idVaoVien);
    const status = Number(trangThaiKham ?? 0);
    const patientIndex = kbDataList.findIndex(x => Number(x.IDVaoVien) === id);

    if (patientIndex >= 0) kbDataList[patientIndex].TrangThaiKham = status;
    if (currentSelectedPatient) currentSelectedPatient.TrangThaiKham = status;

    const filterValue = document.querySelector('input[name="kb-filter-trang-thai"]:checked')?.value ?? '';
    if (filterValue !== '' && Number(filterValue) !== status && patientIndex >= 0) {
        kbDataList.splice(patientIndex, 1);
        kbServerTotal = Math.max(0, kbServerTotal - 1);
    }

    renderTableBenhNhan();
}

async function luuKhamBenh(isKhamXong = false) {
    if (!selectedIdVaoVien) {
        showToast('warning', 'Chưa chọn bệnh nhân nào.');
        return;
    }
    if (!selectedPatientCanEdit) {
        showToast('warning', 'Lượt khám đã xong, không thể sửa.');
        return;
    }

    if (isCompletingKham || saveOutcomeUnknown) return;

    if (!isKhamXong && !isKhamDirty) {
        updateKhamSaveActionState();
        return;
    }

    const soBenhChinh = listChanDoan.filter(cd => cd.benh_chinh === true).length;
    if (isKhamXong && soBenhChinh !== 1) {
        showToast('warning', 'Ch\u1ecdn \u0111\u00fang 1 ICD ch\u00ednh.');
        document.getElementById('kb-section-chan-doan')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
        selectIcd10Instance?.focus?.();
        return;
    }
    if (!isKhamXong && soBenhChinh > 1) {
        showToast('warning', 'Ch\u1ec9 \u0111\u01b0\u1ee3c ch\u1ecdn t\u1ed1i \u0111a 1 ICD ch\u00ednh.');
        return;
    }

    if (listToaThuoc.some(t => !t.da_thu)) {
        const tonHopLe = await kiemTraTonToaThuoc({ showWarning: true });
        if (!tonHopLe) {
            document.getElementById('kb-section-toa-thuoc')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
            return;
        }
    }

    if (isKhamXong && !isKhamDirty && selectedDaLuuKham) {
        await hoanTatKhamDaLuu();
        return;
    }

    const bp = tachHuyetAp(document.getElementById('sh-huyet-ap')?.value || '');
    const sinhHieuPayload = [
        { IDTriSoSinhHieu: 1, GiaTri: document.getElementById('sh-mach')?.value || null },
        { IDTriSoSinhHieu: 2, GiaTri: document.getElementById('sh-nhiet-do')?.value || null },
        { IDTriSoSinhHieu: 3, GiaTri: bp.tamThu || null },
        { IDTriSoSinhHieu: 4, GiaTri: bp.tamTruong || null },
        { IDTriSoSinhHieu: 5, GiaTri: document.getElementById('sh-nhip-tho')?.value || null },
        { IDTriSoSinhHieu: 6, GiaTri: document.getElementById('sh-spo2')?.value || null },
        { IDTriSoSinhHieu: 7, GiaTri: document.getElementById('sh-chieu-cao')?.value || null },
        { IDTriSoSinhHieu: 8, GiaTri: document.getElementById('sh-can-nang')?.value || null },
        { IDTriSoSinhHieu: 9, GiaTri: document.getElementById('sh-bmi')?.value || null }
    ].filter(x => x.GiaTri !== null && String(x.GiaTri).trim() !== '');

    // 2. Chẩn đoán
    const chanDoanPayload = listChanDoan.map((cd, idx) => ({
        IDICD10: cd.id_icd10,
        BanDau: cd.ban_dau,
        BenhChinh: cd.benh_chinh,
        BenhKhac: cd.benh_khac,
        ThuTu: idx + 1,
        GhiChu: cd.ghi_chu
    }));

    // 3. Chỉ định
    const invalidChiDinhNgayGioIndex = listChiDinh.findIndex(ci => !fromDateTimeLocal(ci.ngay_gio_chi_dinh));
    if (invalidChiDinhNgayGioIndex >= 0) {
        showToast('warning', 'Ngày giờ chỉ định không hợp lệ.');
        document.getElementById(`kb-chi-dinh-ngay-gio-${invalidChiDinhNgayGioIndex}`)?.focus();
        return;
    }

    const chiDinhPayload = listChiDinh.map(ci => ({
        IDDichVu: ci.id_dich_vu,
        NgayGioChiDinh: fromDateTimeLocal(ci.ngay_gio_chi_dinh),
        SoLuong: ci.so_luong,
        GuiNgoai: ci.gui_ngoai,
        NoiGuiNgoai: ci.noi_gui_ngoai,
        GhiChu: ci.ghi_chu
    }));

    // 4. Toa thuốc
    const invalidNgayKeIndex = listToaThuoc.findIndex(t => !fromDateTimeLocal(t.ngay_ke));
    if (invalidNgayKeIndex >= 0) {
        showToast('warning', 'Ngày giờ kê toa không hợp lệ.');
        document.getElementById(`kb-ngay-ke-${invalidNgayKeIndex}`)?.focus();
        return;
    }

    const toaThuocPayload = listToaThuoc.map((t, idx) => ({
        IDThuoc: t.id_thuoc,
        NgayKe: fromDateTimeLocal(t.ngay_ke),
        SoNgay: t.so_ngay,
        Sang: t.sang,
        Trua: t.trua,
        Chieu: t.chieu,
        Toi: t.toi,
        LieuDung: t.lieu_dung,
        CachDung: t.cach_dung,
        SoLuong: t.so_luong,
        ThuTu: idx + 1,
        IDToaThuocCTGoc: t.id_toa_thuoc_ct_goc,
        IDDonViTinhDung: t.id_don_vi_tinh_dung || null,
        MaLoaiToaThuoc: t.ma_loai_toa_thuoc || document.getElementById('kb-loai-toa')?.value || 'c',
        DonViTinh: t.don_vi_tinh || null
    }));

    // Ngày tái khám
    const coHenTaiKham = document.getElementById('kb-chk-tai-kham')?.checked === true;
    const ngayTaiKhamStr = coHenTaiKham ? document.getElementById('kb-ngay-tai-kham')?.value : null;
    const ngayTaiKhamVal = coHenTaiKham ? parseDateVNToISO(ngayTaiKhamStr) : null;

    const payload = {
        id_vao_vien: selectedIdVaoVien,
        trieu_chung: document.getElementById('kb-trieu-chung')?.value || null,
        id_phac_do: currentPhacDoId || null,
        ma_pd_goc: currentPhacDoMa || null,
        ngay_tai_kham: ngayTaiKhamVal,
        dan_do: document.getElementById('kb-dan-do')?.value || null,
        sinh_hieu: sinhHieuPayload,
        chan_doan: chanDoanPayload,
        chi_dinh: chiDinhPayload,
        toa_thuoc: toaThuocPayload,
        kham_xong: Boolean(isKhamXong)
    };

    isCompletingKham = true;
    updateKhamSaveActionState();

    try {
        const savedIdVaoVien = Number(selectedIdVaoVien);
        const res = await apiPost('/api/kham_benh/luu', payload);
        if (res.status !== 200) {
            showToast('error', res.message || 'Kh\u00f4ng l\u01b0u \u0111\u01b0\u1ee3c h\u1ed3 s\u01a1 kh\u00e1m.');
            return;
        }

        selectedDaLuuKham = true;
        selectedPatientStatus = isKhamXong
            ? 2
            : (Number(selectedPatientStatus) === 0 ? 1 : Number(selectedPatientStatus || 1));
        capNhatDanhSachBenhNhanSauLuu(savedIdVaoVien, selectedPatientStatus);
        setKhamPatientEditing(selectedPatientStatus);
        clearDirty();

        // Refresh stable IDs, stored prices and per-line financial locks.
        // A failed refresh does not mean the save failed; prevent stale edits.
        if (!await chonBenhNhan(savedIdVaoVien, true)) {
            saveOutcomeUnknown = true;
            showToast('warning', 'Đã lưu khám nhưng chưa tải lại được hồ sơ. Tải lại trước khi sửa tiếp.');
        }

        showToast('success', res.message || (isKhamXong ? '\u0110\u00e3 l\u01b0u v\u00e0 ho\u00e0n t\u1ea5t kh\u00e1m.' : '\u0110\u00e3 l\u01b0u h\u1ed3 s\u01a1 kh\u00e1m.'));
    } catch (err) {
        saveOutcomeUnknown = true;
        updateKhamSaveActionState();
        showToast('error', 'Kh\u00f4ng x\u00e1c \u0111\u1ecbnh \u0111\u01b0\u1ee3c tr\u1ea1ng th\u00e1i l\u01b0u. T\u1ea3i l\u1ea1i trang tr\u01b0\u1edbc khi l\u01b0u ti\u1ebfp.');
    } finally {
        isCompletingKham = false;
        updateKhamSaveActionState();
    }
}

async function hoanTatKhamDaLuu() {
    if (!selectedIdVaoVien || !selectedDaLuuKham || isCompletingKham || saveOutcomeUnknown) return;

    const savedIdVaoVien = Number(selectedIdVaoVien);
    isCompletingKham = true;
    updateKhamSaveActionState();

    try {
        const res = await apiPost('/api/kham_benh/hoan_tat', {
            id_vao_vien: selectedIdVaoVien
        });

        if (res.status !== 200) {
            showToast('error', res.message || 'Kh\u00f4ng ho\u00e0n t\u1ea5t \u0111\u01b0\u1ee3c l\u01b0\u1ee3t kh\u00e1m.');
            return;
        }

        selectedDaLuuKham = true;
        selectedPatientStatus = 2;
        capNhatDanhSachBenhNhanSauLuu(savedIdVaoVien, selectedPatientStatus);
        setKhamPatientEditing(selectedPatientStatus);
        clearDirty();

        showToast('success', res.message || 'Khám bệnh hoàn tất thành công.');
    } catch (err) {
        saveOutcomeUnknown = true;
        updateKhamSaveActionState();
        showToast('error', 'Kh\u00f4ng x\u00e1c \u0111\u1ecbnh \u0111\u01b0\u1ee3c tr\u1ea1ng th\u00e1i ho\u00e0n t\u1ea5t. T\u1ea3i l\u1ea1i trang tr\u01b0\u1edbc khi thao t\u00e1c ti\u1ebfp.');
    } finally {
        isCompletingKham = false;
        updateKhamSaveActionState();
    }
}

async function moModalLichSu(idBenhNhanTarget = null) {
    const isTargetValid = typeof idBenhNhanTarget === 'number'
        || (typeof idBenhNhanTarget === 'string' && !isNaN(Number(idBenhNhanTarget)) && idBenhNhanTarget.trim() !== '');
    const idBN = isTargetValid ? Number(idBenhNhanTarget) : selectedIdBenhNhan;

    if (!idBN) {
        showToast('warning', 'Chưa chọn bệnh nhân để xem lịch sử.');
        return;
    }

    const modalEl = document.getElementById('modalKhamLichSu');
    if (!modalEl) return;

    lichSuBenhNhanId = idBN;
    lichSuCurrentPage = 1;
    selectedLichSuLanKham = null;
    lichSuDetailRequestId++;

    const searchEl = document.getElementById('modal-ls-search');
    if (searchEl) searchEl.value = '';

    const infoEl = document.getElementById('modal-ls-patient-info');
    if (infoEl) {
        const hoTen = document.getElementById('kb-header-ho-ten')?.value || currentSelectedPatient?.HoTen || '';
        const maBn = currentSelectedPatient?.MaBN || '';
        infoEl.textContent = `Bệnh nhân: ${hoTen} ${maBn ? `(${maBn})` : ''}`;
    }

    const emptyDetailEl = document.getElementById('modal-ls-detail-empty');
    const contentDetailEl = document.getElementById('modal-ls-detail-content');
    if (emptyDetailEl) emptyDetailEl.classList.remove('d-none');
    if (contentDetailEl) {
        contentDetailEl.classList.add('d-none');
        contentDetailEl.innerHTML = '';
    }

    const btnKeLai = document.getElementById('btn-modal-ls-ke-lai');
    if (btnKeLai) btnKeLai.disabled = true;

    bootstrap.Modal.getOrCreateInstance(modalEl).show();
    await taiTrangLichSuKham();
}

async function taiTrangLichSuKham() {
    if (!lichSuBenhNhanId) return;

    const listContainer = document.getElementById('modal-ls-list-container');
    if (listContainer) {
        listContainer.innerHTML = '<div class="text-center text-muted py-4"><div class="spinner-border spinner-border-sm text-primary me-2"></div>Đang tải lịch sử...</div>';
    }

    const query = new URLSearchParams();
    query.set('id_benh_nhan', String(lichSuBenhNhanId));
    query.set('trang', String(lichSuCurrentPage));
    query.set('kich_thuoc_trang', String(lichSuPageSize));

    if (selectedIdVaoVien) {
        query.set('id_vao_vien_hien_tai', String(selectedIdVaoVien));
    }

    const keyword = document.getElementById('modal-ls-search')?.value?.trim() || '';
    if (keyword) query.set('tu_khoa', keyword);

    try {
        const res = await apiGet('/api/kham_benh/lich_su?' + query.toString());
        if (res.status !== 200 || !Array.isArray(res.data)) {
            currentLichSuList = [];
            lichSuServerTotal = 0;
        } else {
            currentLichSuList = res.data.map(item => {
                const rawDate = item.NgayGioVaoVien || item.NgayVaoVien;
                const d = rawDate ? new Date(rawDate) : null;
                const ngayStr = d && !Number.isNaN(d.getTime())
                    ? `${String(d.getDate()).padStart(2, '0')}-${String(d.getMonth() + 1).padStart(2, '0')}-${d.getFullYear()} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
                    : '';
                return { ...item, NgayStr: ngayStr };
            });
            lichSuServerTotal = currentLichSuList.length
                ? Number(currentLichSuList[0].TongSoDong || currentLichSuList.length)
                : 0;
        }

        if (!currentLichSuList.length && lichSuCurrentPage > 1) {
            lichSuCurrentPage = 1;
            return taiTrangLichSuKham();
        }

        if (!lichSuPagination) {
            lichSuPagination = createQLPMPagination({
                container: '#modal-ls-pagination',
                itemName: 'lần khám',
                pageSize: lichSuPageSize,
                currentPage: lichSuCurrentPage,
                pageSizes: [10, 25, 50, 100],
                showCount: true,
                compact: true,
                onPageChange: (newPage, newSize) => {
                    lichSuCurrentPage = newPage;
                    lichSuPageSize = newSize;
                    taiTrangLichSuKham();
                }
            });
        }

        if (lichSuPagination) {
            lichSuPagination.render(lichSuServerTotal, lichSuCurrentPage);
            lichSuCurrentPage = lichSuPagination.getCurrentPage();
            lichSuPageSize = lichSuPagination.getPageSize();
        }

        renderLichSuList(currentLichSuList);

        // Tải lại danh sách không tự đổi hồ sơ đang xem; chỉ thao tác chọn dòng mới tải chi tiết.
    } catch (e) {
        currentLichSuList = [];
        lichSuServerTotal = 0;
        if (listContainer) {
            listContainer.innerHTML = `<div class="text-center text-danger py-4">Lỗi tải lịch sử: ${escapeHtml(e.message || 'Không thể tải dữ liệu.')}</div>`;
        }
        lichSuPagination?.render(0, 1);
    }
}

function renderLichSuList(items) {
    const listContainer = document.getElementById('modal-ls-list-container');
    if (!listContainer) return;
    listContainer.innerHTML = '';

    if (!items || items.length === 0) {
        listContainer.innerHTML = '<div class="text-center text-muted py-3 small">Không tìm thấy lần khám nào phù hợp.</div>';
        return;
    }

    items.forEach(item => {
        const div = document.createElement('div');
        div.className = 'modal-ls-item';
        div.setAttribute('data-id-vaovien', item.IDVaoVien);
        if (selectedLichSuLanKham && Number(selectedLichSuLanKham.IDVaoVien) === Number(item.IDVaoVien)) {
            div.classList.add('active');
        }

        div.innerHTML = `
            <div class="d-flex justify-content-between align-items-center mb-1">
                <strong class="text-primary small"><i class="bi bi-calendar3 me-1"></i>${item.NgayStr}</strong>
                <span class="badge bg-light text-dark border" style="font-size: 11px;">${escapeHtml(item.BacSiKham || item.TenBacSi || 'Bác sĩ')}</span>
            </div>
            <div class="text-truncate small fw-medium" title="${escapeHtml(item.ChanDoan || item.TrieuChung || '')}">
                ${item.ChanDoan ? escapeHtml(item.ChanDoan) : (item.TrieuChung ? escapeHtml(item.TrieuChung) : '<span class="text-muted">Không có chẩn đoán</span>')}
            </div>
            <div class="d-flex gap-2 mt-1" style="font-size: 11px;">
                <span class="text-success"><i class="bi bi-capsule me-1"></i>${item.SoLuongThuoc || 0} thuốc</span>
                <span class="text-info"><i class="bi bi-clipboard2-pulse me-1"></i>${item.SoLuongChiDinh || 0} DVKT</span>
            </div>
        `;

        div.addEventListener('click', () => {
            chonLanKhamLichSu(item);
        });

        listContainer.appendChild(div);
    });
}

async function chonLanKhamLichSu(item) {
    selectedLichSuLanKham = item;
    const requestId = ++lichSuDetailRequestId;

    // Highlight item đang chọn
    document.querySelectorAll('.modal-ls-item').forEach(el => {
        if (el.getAttribute('data-id-vaovien') == item.IDVaoVien) {
            el.classList.add('active');
        } else {
            el.classList.remove('active');
        }
    });

    const emptyDetailEl = document.getElementById('modal-ls-detail-empty');
    const contentDetailEl = document.getElementById('modal-ls-detail-content');
    const btnKeLai = document.getElementById('btn-modal-ls-ke-lai');
    if (btnKeLai) btnKeLai.disabled = true;

    if (emptyDetailEl) emptyDetailEl.classList.add('d-none');
    if (contentDetailEl) {
        contentDetailEl.classList.remove('d-none');
        contentDetailEl.innerHTML = '<div class="text-center text-muted py-5"><div class="spinner-border spinner-border-sm text-primary me-2"></div>Đang tải chi tiết lần khám...</div>';
    }

    try {
        const res = await apiGet(`/api/kham_benh/chi_tiet_lan_kham_cu?id_vao_vien_cu=${item.IDVaoVien}`);
        if (requestId !== lichSuDetailRequestId) return;
        if (res.status !== 200 || !res.data) {
            if (contentDetailEl) contentDetailEl.innerHTML = `<div class="modal-ls-load-error"><i class="bi bi-exclamation-circle me-2"></i>${escapeHtml(res.message || 'Không thể tải hồ sơ lần khám này.')}</div>`;
            return;
        }

        const d = res.data;
        const info = d.thong_tin || {};
        const hasValue = value => value !== null && value !== undefined && String(value).trim() !== '';
        const displayValue = (value, fallback = '—') => hasValue(value) ? escapeHtml(String(value)) : fallback;
        const vitalRows = Array.isArray(d.sinh_hieu)
            ? d.sinh_hieu
            : (d.sinh_hieu && typeof d.sinh_hieu === 'object'
                ? Object.entries(d.sinh_hieu).map(([key, value]) => ({ TenTriSo: key, GiaTri: value }))
                : []);
        // HA_TT và HA_TR lưu riêng trong DB nhưng lịch sử hiển thị chung "Huyết áp" (TT/TR).
        // Gom ngay tại vị trí chỉ số huyết áp đầu tiên để không tạo hai ô riêng.
        const vitals = [];
        const huyetAp = { tamThu: '', tamTruong: '', dayDu: '' };
        let huyetApItem = null;
        vitalRows.forEach(v => {
            const value = v.GiaTri ?? v.gia_tri;
            if (!hasValue(value)) return;
            const maTriSo = String(v.MaTriSo ?? v.ma_tri_so ?? '').trim().toUpperCase();
            const tenTriSo = String(v.TenTriSo ?? v.ten_tri_so ?? '').trim();
            const tenKhongDau = tenTriSo.normalize('NFD').replace(/[\u0300-\u036f]/g, '')
                .replace(/[đĐ]/g, 'd').toLowerCase();
            const loaiHa = maTriSo === 'HA_TT' || tenKhongDau === 'huyet ap tam thu'
                ? 'tamThu'
                : maTriSo === 'HA_TR' || tenKhongDau === 'huyet ap tam truong'
                    ? 'tamTruong'
                    : maTriSo === 'HA' || maTriSo === 'HUYET_AP' || tenKhongDau === 'huyet ap'
                        ? 'dayDu'
                        : null;
            if (loaiHa) {
                huyetAp[loaiHa] = String(value).trim();
                if (!huyetApItem) {
                    huyetApItem = { name: 'Huyết áp', value: '', unit: 'mmHg' };
                    vitals.push(huyetApItem);
                }
                return;
            }
            vitals.push({
                name: displayValue(tenTriSo || maTriSo, 'Chỉ số'),
                value: displayValue(value),
                unit: displayValue(v.DonViTinh ?? v.don_vi_tinh, '')
            });
        });
        if (huyetApItem) {
            const ttTr = ghepHuyetAp(huyetAp.tamThu, huyetAp.tamTruong);
            huyetApItem.value = escapeHtml(
                huyetAp.tamThu && huyetAp.tamTruong ? ttTr : (huyetAp.dayDu || ttTr)
            );
        }

        const chanDoanList = Array.isArray(d.chan_doan) ? d.chan_doan : [];
        const chiDinhList = Array.isArray(d.chi_dinh) ? d.chi_dinh : [];
        const toaThuocList = Array.isArray(d.toa_thuoc) ? d.toa_thuoc : [];
        const dateText = item.NgayStr || (item.NgayGioVaoVien ? formatDateTimeHistory(item.NgayGioVaoVien) : 'Không có thời gian');
        const doctorText = item.BacSiKham || item.TenBacSi || 'Chưa ghi nhận';
        const formSection = (icon, title, body, sectionType = '') => `
            <section class="section-box kb-scroll-section modal-ls-form-section ${sectionType ? 'modal-ls-section-' + sectionType : ''}">
                <div class="kb-title-content-row modal-ls-title-content">
                    <div class="section-title kb-compact-title modal-ls-form-title"><i class="bi ${icon} me-1"></i>${title}</div>
                    <div class="kb-title-content-body modal-ls-form-body">${body}</div>
                </div>
            </section>`;
        // Luôn hiển thị đầy đủ nhãn sinh hiệu theo tab Khám bệnh.
        // Lượt khám không có số đo thì giữ ô giá trị rỗng, không chèn thông báo.
        const vitalKey = value => String(value ?? '').normalize('NFD')
            .replace(/[\u0300-\u036f]/g, '').replace(/[đĐ]/g, 'd')
            .toUpperCase().replace(/[^A-Z0-9]/g, '');
        const displayedVitalKeys = new Set();
        const configuredVitals = [
            { label: 'Mạch', keys: ['MACH'], unit: 'Lần/P' },
            { label: 'Nhiệt độ', keys: ['NHIETDO'], unit: '°C' },
            { label: 'Huyết áp', keys: ['HUYETAP', 'HA'], unit: 'mmHg' },
            { label: 'Nhịp thở', keys: ['NHIPTHO'], unit: 'Lần/P' },
            { label: 'SpO2', keys: ['SPO2'], unit: '%' },
            { label: 'Chiều cao', keys: ['CHIEUCAO'], unit: 'cm' },
            { label: 'Cân nặng', keys: ['CANNANG'], unit: 'Kg' },
            { label: 'BMI', keys: ['BMI'], unit: 'Kg/m²' }
        ];
        const vitalDisplayRows = configuredVitals.map(field => {
            const found = vitals.find(v => field.keys.includes(vitalKey(v.name)));
            if (found) displayedVitalKeys.add(vitalKey(found.name));
            return {
                name: escapeHtml(field.label),
                value: found?.value ?? '',
                unit: escapeHtml(field.unit)
            };
        });
        // Vẫn hiển thị các chỉ số mở rộng nếu CSKCB cấu hình thêm.
        vitals.forEach(v => {
            if (!displayedVitalKeys.has(vitalKey(v.name))) {
                vitalDisplayRows.push(v);
            }
        });
        const vitalHtml = `<div class="modal-ls-vital-grid">${vitalDisplayRows.map(vital => `
            <div class="input-group input-group-sm modal-ls-vital-field">
                <span class="input-group-text">${vital.name}</span>
                <span class="form-control text-center fw-semibold modal-ls-vital-value">${vital.value}</span>
                ${vital.unit ? `<span class="input-group-text modal-ls-vital-unit">${vital.unit}</span>` : ''}
            </div>`).join('')}</div>`;
        const diagnosisHtml = chanDoanList.length ? `
            <div class="table-responsive border rounded">
                <table class="table table-sm table-bordered m-0 grid-mini qlpm-one-line-head">
                    <thead><tr><th>Mã bệnh</th><th>Tên bệnh / ghi chú</th><th class="text-center">BĐ</th><th class="text-center">Chính</th><th class="text-center">#</th></tr></thead>
                    <tbody>${chanDoanList.map(c => `<tr>
                        <td class="fw-semibold text-primary">${displayValue(c.MaBenh, '')}</td>
                        <td>${displayValue(c.TenBenh, '')}${hasValue(c.GhiChu) ? `<small class="modal-ls-row-note">${escapeHtml(c.GhiChu)}</small>` : ''}</td>
                        <td class="text-center"><input type="checkbox" class="form-check-input" disabled ${c.BanDau ? 'checked' : ''} /></td>
                        <td class="text-center"><input type="checkbox" class="form-check-input" disabled ${c.BenhChinh ? 'checked' : ''} /></td>
                        <td class="text-center"><input type="checkbox" class="form-check-input" disabled ${c.BenhKhac ? 'checked' : ''} /></td>
                    </tr>`).join('')}</tbody>
                </table>
            </div>` : '<div class="text-muted small">Chưa ghi nhận chẩn đoán.</div>';
        const orderTotal = chiDinhList.reduce((sum, cd) =>
            sum + Math.max(0, Number(cd.SoLuong || 1)) * Number(cd.DonGia || 0), 0);
        const ordersHtml = chiDinhList.length ? `
            <div class="d-flex justify-content-end align-items-center mb-1">
                <span class="badge bg-light text-primary border qlpm-money-total">Cộng CĐ: ${formatCurrencyVN(orderTotal)}</span>
            </div>
            <div class="table-responsive border rounded">
                <table class="table table-sm table-bordered m-0 grid-mini qlpm-one-line-head">
                    <thead><tr><th>Công việc / dịch vụ</th><th class="text-center">SL</th><th class="text-end">Đơn giá</th><th class="text-center">Kết quả</th><th class="text-center">Gửi ngoài</th></tr></thead>
                    <tbody>${chiDinhList.map(cd => {
                        const isExternal = cd.GuiNgoai === true || Number(cd.GuiNgoai) === 1 || String(cd.GuiNgoai).toLowerCase() === 'true';
                        const idChiDinh = Number(cd.IDChiDinhCT || cd.ID || 0);
                        const hasResult = cd.CoFileKetQua === true || Number(cd.CoFileKetQua) === 1 || !!(cd.DuongDanKetQua);
                        const resultTitle = hasResult ? 'Xem file kết quả CLS' : 'Chưa có file kết quả CLS';
                        return `<tr>
                            <td><strong>${displayValue(cd.TenDichVu, 'Dịch vụ')}</strong>${cd.MaDichVu ? `<small class="d-block text-muted">${escapeHtml(cd.MaDichVu)}</small>` : ''}${hasValue(cd.GhiChu) ? `<small class="modal-ls-row-note">${escapeHtml(cd.GhiChu)}</small>` : ''}</td>
                            <td class="text-center">${displayValue(cd.SoLuong)}</td>
                            <td class="text-end">${hasValue(cd.DonGia) ? formatCurrencyVN(cd.DonGia) : '—'}</td>
                            <td class="text-center">
                                <button type="button" class="btn btn-sm btn-link p-0 btn-kq-cls ${hasResult ? 'kq-co' : 'kq-chua-co'}"
                                        data-history-cls-preview data-id-chi-dinh="${idChiDinh}"
                                        data-service="${escapeHtml(cd.TenDichVu || '')}"
                                        ${hasResult ? '' : 'disabled'} title="${resultTitle}" aria-label="${resultTitle}">
                                    <i class="bi bi-eye kb-eye-icon"></i>
                                </button>
                            </td>
                            <td class="text-center">${isExternal ? `<span class="badge bg-info-subtle text-info-emphasis">Có</span>${hasValue(cd.NoiGuiNgoai) ? `<small class="d-block">${escapeHtml(cd.NoiGuiNgoai)}</small>` : ''}` : 'Không'}</td>
                        </tr>`;
                    }).join('')}</tbody>
                </table>
            </div>` : '';
        const medicineTotal = toaThuocList.reduce((sum, t) => sum +
            (t.ThanhTien == null ? Number(t.SoLuong || 0) * Number(t.DonGia || 0) : Number(t.ThanhTien || 0)), 0);
        const medicineDays = [...new Set(toaThuocList.map(t => Number(t.SoNgay)).filter(Number.isFinite))];
        const medicineHtml = toaThuocList.length ? `
            <div class="d-flex flex-wrap align-items-center gap-2 mb-1">
                ${medicineDays.length ? `<span class="modal-ls-prescription-meta">SN: <strong>${medicineDays.join(', ')}</strong></span>` : ''}
                <span class="modal-ls-prescription-meta">Loại toa: <strong>${escapeHtml(prescriptionTypeSummary(toaThuocList))}</strong></span>
                <span class="badge bg-success-subtle text-success border border-success-subtle qlpm-money-total ms-auto">Cộng Thuốc: ${formatCurrencyVN(medicineTotal)}</span>
            </div>
            <div class="table-responsive border rounded">
                <table class="table table-sm table-bordered m-0 grid-mini qlpm-one-line-head modal-ls-medicine-table modal-ls-prescription-table">
                    <thead><tr>
                        <th class="col-sticky-stt text-center">TT</th><th class="col-ngay-ke text-center">Ngày giờ</th><th class="col-sticky-thuoc">Thuốc</th><th>Hoạt chất</th><th class="text-center" title="Số ngày">SN</th><th class="text-center">ĐVT</th>
                        <th class="text-center">Sáng</th><th class="text-center">Trưa</th><th class="text-center">Chiều</th><th class="text-center">Tối</th><th class="text-center" title="Đường dùng">ĐD</th><th>Cách dùng khác</th>
                        <th class="text-end">Đơn giá</th><th class="text-end">Thành tiền</th><th class="col-sticky-dvt-dung text-center">ĐVT dùng</th><th class="col-sticky-sl text-center">SL</th>
                    </tr></thead>
                    <tbody>${toaThuocList.map((t, index) => `<tr>
                        <td class="col-sticky-stt text-center">${index + 1}</td>
                        <td class="col-ngay-ke text-center" title="${hasValue(t.NgayKe) ? escapeHtml(formatKhamDateTime(t.NgayKe)) : ''}">${hasValue(t.NgayKe) ? escapeHtml(formatKhamDateWithEllipsis(t.NgayKe)) : '—'}</td>
                        <td class="col-sticky-thuoc"><div class="modal-ls-medicine-name">${displayValue(t.TenThuoc, 'Thuốc')}</div>${t.MaThuoc ? `<small class="d-block text-muted">${escapeHtml(t.MaThuoc)}</small>` : ''}${t.HamLuong ? `<small class="d-block text-muted">${escapeHtml(t.HamLuong)}</small>` : ''}</td>
                        <td>${displayValue(t.HoatChat)}</td>
                        <td class="text-center">${displayValue(t.SoNgay)}</td>
                        <td>${displayValue(t.DonViTinh)}</td>
                        <td class="text-center">${displayValue(t.Sang, '0')}</td><td class="text-center">${displayValue(t.Trua, '0')}</td><td class="text-center">${displayValue(t.Chieu, '0')}</td><td class="text-center">${displayValue(t.Toi, '0')}</td>
                        <td>${displayValue(t.DuongDung ?? t.LieuDung)}</td><td>${displayValue(t.CachDung)}</td>
                        <td class="text-end">${hasValue(t.DonGia) ? formatCurrencyVN(t.DonGia) : '—'}</td>
                        <td class="text-end fw-semibold">${hasValue(t.ThanhTien) ? formatCurrencyVN(t.ThanhTien) : '—'}</td>
                        <td class="col-sticky-dvt-dung text-center">${displayValue(t.DonViTinh)}</td>
                        <td class="col-sticky-sl text-center fw-semibold">${displayValue(t.SoLuong)}</td>
                    </tr>`).join('')}</tbody>
                </table>
            </div>` : '<div class="text-muted small">Không kê thuốc trong lần khám này.</div>';
        const followupHtml = `
            <div class="d-flex flex-column gap-1">
                ${hasValue(info.DanDo) ? `<div class="input-group input-group-sm"><span class="input-group-text">Dặn dò</span><div class="form-control h-auto text-wrap">${escapeHtml(info.DanDo)}</div></div>` : ''}
                ${hasValue(info.NgayTaiKham) ? `<div class="input-group input-group-sm"><span class="input-group-text">Tái khám</span><div class="form-control">${escapeHtml(formatDateVN(info.NgayTaiKham))}</div></div>` : ''}
                ${!hasValue(info.DanDo) && !hasValue(info.NgayTaiKham) ? '<div class="text-muted small">Chưa có dặn dò hoặc lịch tái khám.</div>' : ''}
            </div>`;

        const html = `
            <div class="modal-ls-exam-view">
                <section class="section-box kb-scroll-section modal-ls-visit-info">
                    <i class="bi bi-calendar2-check me-1 text-primary"></i><strong>${escapeHtml(dateText)}</strong>
                    <span class="mx-2 text-muted">|</span><i class="bi bi-person-badge me-1 text-primary"></i>${escapeHtml(doctorText)}
                    ${item.MaVaoVien ? `<span class="mx-2 text-muted">|</span><span>Mã lượt: <strong>${escapeHtml(item.MaVaoVien)}</strong></span>` : ''}
                </section>
                <div class="modal-ls-clinical-group">
                    ${formSection('bi-heart-pulse', 'Sinh hiệu:', vitalHtml, 'vitals')}
                    ${formSection('bi-chat-heart-fill', 'Triệu chứng:', hasValue(info.TrieuChung) ? `<div class="modal-ls-readonly-text">${escapeHtml(info.TrieuChung)}</div>` : '<div class="modal-ls-readonly-text"></div>', 'symptoms')}
                    ${formSection('bi-activity', `Chẩn đoán (${chanDoanList.length}):`, diagnosisHtml, 'diagnoses')}
                </div>
                ${formSection('bi-clipboard2-pulse-fill', `Chỉ định (${chiDinhList.length}):`, ordersHtml || '', 'orders')}
                ${formSection('bi-capsule', `Toa thuốc (${toaThuocList.length}):`, medicineHtml, 'medicines')}
                ${formSection('bi-chat-left-dots', 'Dặn dò:', followupHtml, 'advice')}
            </div>`;

        if (requestId !== lichSuDetailRequestId) return;
        if (contentDetailEl) {
            contentDetailEl.innerHTML = html;
            contentDetailEl.onclick = event => {
                const button = event.target.closest('[data-history-cls-preview]');
                if (!button || button.disabled) return;
                const idChiDinh = Number(button.dataset.idChiDinh || 0);
                if (idChiDinh <= 0) return;

                currentClsOrder = { id: idChiDinh, ten_dich_vu: button.dataset.service || '' };
                currentClsInfo = {
                    IDChiDinhCT: idChiDinh,
                    CoFileKetQua: true
                };
                openClsResultPreview();
            };
        }
        if (btnKeLai) btnKeLai.disabled = false;
    } catch (err) {
        if (requestId !== lichSuDetailRequestId) return;
        if (contentDetailEl) contentDetailEl.innerHTML = `<div class="modal-ls-load-error"><i class="bi bi-exclamation-circle me-2"></i>${escapeHtml(err.message || 'Không thể tải chi tiết lần khám.')}</div>`;
        if (btnKeLai) btnKeLai.disabled = true;
    }
}

function formatDateTimeHistory(value) {
    if (!value) return '';
    const d = new Date(value);
    if (Number.isNaN(d.getTime())) return String(value);
    const pad = n => String(n).padStart(2, '0');
    return `${pad(d.getDate())}/${pad(d.getMonth() + 1)}/${d.getFullYear()} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

async function napDuLieuLanKhamCu(idVaoVienCu, ngayStr) {
    if (!selectedIdVaoVien) {
        showToast('warning', 'Chọn lượt khám đang tiếp nhận để nạp dữ liệu.');
        return;
    }

    const coSinhHieu = ['sh-mach', 'sh-nhiet-do', 'sh-huyet-ap', 'sh-nhip-tho', 'sh-spo2', 'sh-chieu-cao', 'sh-can-nang', 'sh-bmi']
        .some(id => (document.getElementById(id)?.value || '').trim() !== '');

    const coDuLieu = (listToaThuoc && listToaThuoc.length > 0) ||
                     (listChanDoan && listChanDoan.length > 0) ||
                     (listChiDinh && listChiDinh.length > 0) ||
                     (document.getElementById('kb-trieu-chung')?.value.trim() !== '') ||
                     coSinhHieu;

    if (coDuLieu) {
        const ok = await hien_thi_xac_nhan({
            tieu_de: 'Nạp dữ liệu lần khám cũ',
            noi_dung: `Bạn có muốn thay thế toàn bộ dữ liệu đang nhập bằng dữ liệu của lần khám ngày ${ngayStr || ''} không?`,
            nhan_dong_y: 'Đồng ý thay thế',
            lop_nut: 'btn-primary'
        });
        if (!ok) return;
    }

    showPageloader();
    try {
        const res = await apiGet(`/api/kham_benh/chi_tiet_lan_kham_cu?id_vao_vien_cu=${idVaoVienCu}`);
        if (res.status !== 200 || !res.data) {
            showToast('error', res.message || 'Không tải được lần khám cũ.');
            return;
        }

        const d = res.data;
        const info = d.thong_tin || {};

        // 0. Sinh hiệu
        if (d.sinh_hieu) {
            fillSinhHieuInputs(d.sinh_hieu);
        }

        // 1. Triệu chứng & Dặn dò & Tái khám
        document.getElementById('kb-trieu-chung').value = info.TrieuChung || '';
        document.getElementById('kb-dan-do').value = info.DanDo || '';
        if (info.NgayTaiKham) {
            const dTk = new Date(info.NgayTaiKham);
            document.getElementById('kb-ngay-tai-kham').value = `${String(dTk.getDate()).padStart(2, '0')}-${String(dTk.getMonth() + 1).padStart(2, '0')}-${dTk.getFullYear()}`;
            if (document.getElementById('kb-chk-tai-kham')) {
                document.getElementById('kb-chk-tai-kham').checked = true;
                document.getElementById('kb-ngay-tai-kham').disabled = false;
            }
        } else {
            document.getElementById('kb-ngay-tai-kham').value = '';
            if (document.getElementById('kb-chk-tai-kham')) {
                document.getElementById('kb-chk-tai-kham').checked = false;
                document.getElementById('kb-ngay-tai-kham').disabled = true;
            }
        }

        // 2. Chẩn đoán
        listChanDoan = (d.chan_doan || []).map(c => ({
            id_icd10: c.IDICD10,
            ma_benh: c.MaBenh,
            ten_benh: c.TenBenh,
            ban_dau: c.BanDau === true,
            benh_chinh: c.BenhChinh === true,
            benh_khac: c.BenhKhac === true,
            ghi_chu: c.GhiChu || ''
        }));
        renderChanDoanTable();

        // 3. Chỉ định dịch vụ
        listChiDinh = (d.chi_dinh || []).map(cd => {
            const guiNgoai = cd.GuiNgoai === true;
            const donGiaGoc = roundDecimal(cd.DonGiaDanhMuc ?? cd.DonGia ?? 0, 3);
            const donGia = guiNgoai ? 0 : donGiaGoc;
            const soLuong = roundDecimal(cd.SoLuong || 1, 3);
            return {
                id: null,
                id_dich_vu: cd.IDDichVu,
                ma_dich_vu: cd.MaDichVu,
                ten_dich_vu: cd.TenDichVu,
                ngay_gio_chi_dinh: getKhamNowDateTime(),
                don_gia: donGia,
                don_gia_goc: donGiaGoc,
                so_luong: soLuong,
                thanh_tien: roundDecimal(soLuong * donGia, 3),
                gui_ngoai: guiNgoai,
                noi_gui_ngoai: cd.NoiGuiNgoai || '',
                noi_dung_mau: cd.NoiDungMau || null,
                ghi_chu: cd.GhiChu || '',
                id_chi_dinh_ct_goc: cd.IDChiDinhCTGoc || null,
                da_thu: false
            };
        });
        renderChiDinhTable();

        // 4. Toa thuốc
        listToaThuoc = (d.toa_thuoc || []).map(t => {
            const soLuong = roundDecimal(t.SoLuong || 1, 3);
            const donGia = roundDecimal(t.DonGia || 0, 3);
            return {
                id: null,
                ma_loai_toa_thuoc: t.MaLoaiToaThuoc || 'c',
                id_thuoc: t.IDThuoc,
                ma_thuoc: t.MaThuoc,
                ten_thuoc: t.TenThuoc,
                ten_hoat_chat: t.HoatChat || t.TenHoatChat || '',
                don_vi_tinh: t.DonViTinh || 'Viên',
                id_don_vi_tinh_dung: t.IDDonViTinhDung || null,
                so_ngay: t.SoNgay || 1,
                sang: t.Sang || '0',
                trua: t.Trua || '0',
                chieu: t.Chieu || '0',
                toi: t.Toi || '0',
                lieu_dung: t.LieuDung || '',
                cach_dung: t.CachDung || '',
                so_luong: soLuong,
                don_gia: donGia,
                thanh_tien: roundDecimal(soLuong * donGia, 3),
                ngay_ke: getKhamNowDateTime(),
                id_toa_thuoc_ct_goc: t.IDToaThuocCTGoc || null,
                da_thu: false
            };
        });
        if (listToaThuoc.length > 0) {
            const elLoaiToa = document.getElementById('kb-loai-toa');
            if (elLoaiToa) elLoaiToa.value = listToaThuoc[0].ma_loai_toa_thuoc || 'c';
            const maxNgay = Math.max(...listToaThuoc.map(t => parseInt(t.so_ngay) || 1));
            const elSoNgay = document.getElementById('kb-toa-so-ngay');
            if (elSoNgay) elSoNgay.value = maxNgay || 3;
        } else if (document.getElementById('kb-loai-toa')) document.getElementById('kb-loai-toa').value = 'c';
        renderToaThuocTable();

        // Đóng modal lịch sử
        const modalEl = document.getElementById('modalKhamLichSu');
        if (modalEl) {
            const bs = bootstrap.Modal.getInstance(modalEl);
            if (bs) bs.hide();
        }

        markDirty();
        showToast('success', `Đã nạp dữ liệu khám ngày ${ngayStr || ''}.`);
    } catch (err) {
        showToast('error', 'Không tải được lần khám cũ.');
    } finally {
        hidePageloader();
    }
}

function formatNgaySinhVoiTuoi(ngaySinhRaw) {
    if (!ngaySinhRaw) return '—';
    let dateObj = null;
    let ngaySinhStr = '';
    let namSinh = 0;

    if (ngaySinhRaw instanceof Date) {
        dateObj = ngaySinhRaw;
    } else if (typeof ngaySinhRaw === 'string') {
        const clean = ngaySinhRaw.trim();
        const parts = clean.split('T')[0].split(/[-/]/);
        if (parts.length === 3) {
            if (parts[0].length === 4) {
                namSinh = parseInt(parts[0], 10);
                ngaySinhStr = `${parts[2]}-${parts[1]}-${parts[0]}`;
            } else if (parts[2].length === 4) {
                namSinh = parseInt(parts[2], 10);
                ngaySinhStr = `${parts[0]}-${parts[1]}-${parts[2]}`;
            }
        } else if (clean.length === 4 && !isNaN(clean)) {
            namSinh = parseInt(clean, 10);
            ngaySinhStr = clean;
        }
    }

    if (!namSinh && dateObj && !isNaN(dateObj.getTime())) {
        namSinh = dateObj.getFullYear();
        const d = String(dateObj.getDate()).padStart(2, '0');
        const m = String(dateObj.getMonth() + 1).padStart(2, '0');
        ngaySinhStr = `${d}-${m}-${namSinh}`;
    }

    if (!ngaySinhStr) ngaySinhStr = String(ngaySinhRaw);

    const currentYear = new Date().getFullYear();
    if (namSinh && namSinh > 1900 && namSinh <= currentYear) {
        const tuoi = currentYear - namSinh;
        return `${ngaySinhStr} (${tuoi}T)`;
    }
    return ngaySinhStr;
}

// ==========================================
let khamBenhPdfObjectUrl = null;
let khamBenhPdfBusy = false;

function taoDuLieuInBanNhap() {
    syncHuyetApValue();
    const bp = tachHuyetAp(document.getElementById('sh-huyet-ap')?.value || '');
    const sinhHieu = [
        { IDTriSoSinhHieu: 1, GiaTri: document.getElementById('sh-mach')?.value || null },
        { IDTriSoSinhHieu: 2, GiaTri: document.getElementById('sh-nhiet-do')?.value || null },
        { IDTriSoSinhHieu: 3, GiaTri: bp.tamThu || null },
        { IDTriSoSinhHieu: 4, GiaTri: bp.tamTruong || null },
        { IDTriSoSinhHieu: 5, GiaTri: document.getElementById('sh-nhip-tho')?.value || null },
        { IDTriSoSinhHieu: 6, GiaTri: document.getElementById('sh-spo2')?.value || null },
        { IDTriSoSinhHieu: 7, GiaTri: document.getElementById('sh-chieu-cao')?.value || null },
        { IDTriSoSinhHieu: 8, GiaTri: document.getElementById('sh-can-nang')?.value || null },
        { IDTriSoSinhHieu: 9, GiaTri: document.getElementById('sh-bmi')?.value || null }
    ].filter(x => x.GiaTri !== null && String(x.GiaTri).trim() !== '');
    const ngaySinh = parseDateVNToISO(document.getElementById('kb-header-nam-sinh')?.value || '') || null;
    const ngayTaiKham = document.getElementById('kb-chk-tai-kham')?.checked
        ? parseDateVNToISO(document.getElementById('kb-ngay-tai-kham')?.value || '') || null
        : null;

    return {
        nguon: 'ban_nhap',
        id_vao_vien: Number(selectedIdVaoVien || 0),
        ho_ten: document.getElementById('kb-header-ho-ten')?.value?.trim() || null,
        ngay_sinh: ngaySinh,
        id_gioi_tinh: Number(document.getElementById('kb-header-gioi-tinh')?.value || 0) || null,
        trieu_chung: document.getElementById('kb-trieu-chung')?.value || null,
        ngay_tai_kham: ngayTaiKham,
        dan_do: document.getElementById('kb-dan-do')?.value || null,
        sinh_hieu: sinhHieu,
        chan_doan: listChanDoan.map(cd => ({
            IDICD10: Number(cd.id_icd10 || 0) || null,
            GhiChu: cd.ghi_chu || null,
            BenhChinh: cd.benh_chinh === true
        })),
        chi_dinh: listChiDinh.map(ci => ({
            IDDichVu: Number(ci.id_dich_vu || 0),
            NgayGioChiDinh: fromDateTimeLocal(ci.ngay_gio_chi_dinh),
            SoLuong: Number(ci.so_luong || 0),
            GuiNgoai: ci.gui_ngoai === true,
            NoiGuiNgoai: ci.noi_gui_ngoai || null,
            GhiChu: ci.ghi_chu || null
        })),
        toa_thuoc: listToaThuoc.map(t => ({
            IDThuoc: Number(t.id_thuoc || 0),
            NgayKe: fromDateTimeLocal(t.ngay_ke),
            SoNgay: Number(t.so_ngay || 0) || null,
            Sang: t.sang || null,
            Trua: t.trua || null,
            Chieu: t.chieu || null,
            Toi: t.toi || null,
            LieuDung: t.lieu_dung || null,
            CachDung: t.cach_dung || null,
            SoLuong: Number(t.so_luong || 0),
            IDDonViTinhDung: Number(t.id_don_vi_tinh_dung || 0) || null,
            MaLoaiToaThuoc: t.ma_loai_toa_thuoc || document.getElementById('kb-loai-toa')?.value || 'c'
        }))
    };
}

function taoDuLieuInDaLuu(idVaoVien) {
    return { nguon: 'da_luu', id_vao_vien: Number(idVaoVien || 0) };
}

async function docLoiPdf(response) {
    try {
        const data = await response.json();
        return data?.message || 'Không tạo được file PDF.';
    } catch {
        return 'Không tạo được file PDF.';
    }
}

function datTrangThaiTaoPdf(isBusy) {
    khamBenhPdfBusy = isBusy;
    ['btn-kb-in-chi-dinh', 'btn-kb-in-toa-thuoc'].forEach(id => {
        const button = document.getElementById(id);
        if (button) button.disabled = isBusy;
    });
}

function donPdfDangIn() {
    if (khamBenhPdfObjectUrl) URL.revokeObjectURL(khamBenhPdfObjectUrl);
    khamBenhPdfObjectUrl = null;
    const frame = document.getElementById('kham-benh-print-frame');
    if (frame) {
        frame.onload = null;
        frame.removeAttribute('src');
    }
}

async function inPdfBangTrinhDuyet(endpoint, payload) {
    if (khamBenhPdfBusy) return;
    const frame = document.getElementById('kham-benh-print-frame');
    if (!frame) return;
    donPdfDangIn();
    datTrangThaiTaoPdf(true);
    try {
        const response = await fetch(endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        if (!response.ok) throw new Error(await docLoiPdf(response));
        const blob = await response.blob();
        khamBenhPdfObjectUrl = URL.createObjectURL(blob);
        frame.onload = () => {
            frame.onload = null;
            window.setTimeout(() => {
                try {
                    if (frame.contentWindow) {
                        frame.contentWindow.onafterprint = donPdfDangIn;
                        frame.contentWindow.focus();
                        frame.contentWindow.print();
                    }
                } catch {
                    donPdfDangIn();
                    showToast('error', 'Không mở được hộp thoại in của trình duyệt.');
                } finally {
                    datTrangThaiTaoPdf(false);
                }
            }, 100);
        };
        frame.src = khamBenhPdfObjectUrl;
    } catch (error) {
        donPdfDangIn();
        datTrangThaiTaoPdf(false);
        showToast('error', error.message || 'Không tạo được file PDF.');
    }
}

async function inPhieuChiDinh() {
    if (!selectedIdVaoVien) {
        showToast('warning', 'Chưa chọn bệnh nhân để in phiếu chỉ định.');
        return;
    }
    const payload = taoDuLieuInBanNhap();
    payload.gop_chi_dinh = false;
    await inPdfBangTrinhDuyet('/api/kham_benh/in/chi_dinh', payload);
}

async function inToaThuoc() {
    if (!selectedIdVaoVien) {
        showToast('warning', 'Chưa chọn bệnh nhân để in toa thuốc.');
        return;
    }
    await inPdfBangTrinhDuyet('/api/kham_benh/in/toa_thuoc', taoDuLieuInBanNhap());
}

let kbKySoBusy = false;

async function kySoVaIn(loaiTaiLieu) {
    if (kbKySoBusy || khamBenhPdfBusy) return;
    if (!selectedIdVaoVien) { showToast('warning','Chưa chọn bệnh nhân để ký.'); return; }
    const visit = Number(selectedIdVaoVien);
    const frame = document.getElementById('kham-benh-print-frame');
    if (!frame) { showToast('error','Không có khung in PDF.'); return; }
    kbKySoBusy = true;
    const buttons = ['btn-kb-ky-so-toa','btn-kb-ky-so-chi-dinh'].map(id=>document.getElementById(id)).filter(Boolean);
    const previous = buttons.map(button=>({button,disabled:button.disabled,html:button.innerHTML}));
    buttons.forEach(button=>button.disabled=true);
    const active = document.getElementById(loaiTaiLieu === 'chi_dinh' ? 'btn-kb-ky-so-chi-dinh' : 'btn-kb-ky-so-toa');
    if (active) active.innerHTML = '<span class="spinner-border spinner-border-sm me-1"></span>';
    datTrangThaiTaoPdf(true);
    try {
        const response = await fetch('/api/ky_so_pdf/ky-toan-bo', {
            method:'POST',headers:{'Content-Type':'application/json'},
            body:JSON.stringify({id_vao_vien:visit,loai_tai_lieu:loaiTaiLieu})
        });
        if (response.status === 404) {
            const failure = await response.json().catch(() => null);
            throw new Error(failure?.message || 'Ứng dụng đang chạy chưa có API ký mới. Stop rồi F5 lại QLPM trong Visual Studio.');
        }
        if (!response.ok) throw new Error(await docLoiPdf(response));
        const result = await response.json();
        if (result.status !== 200 || !Number.isSafeInteger(Number(result.data?.id_tai_lieu)) || Number(result.data.id_tai_lieu)<=0)
            throw new Error(result.message || 'Không có PDF đã ký để in.');
        const pdf = await fetch('/api/ky_so_pdf/tai-lieu/'+Number(result.data.id_tai_lieu),{cache:'no-store'});
        if (!pdf.ok) throw new Error('PDF đã ký được lưu nhưng chưa tải được. Bấm Ký số để mở lại, không ký trùng.');
        if (pdf.headers.get('X-QLPM-PDF-Da-Ky') !== 'true' || pdf.headers.get('X-QLPM-PDF-Trang-Thai') !== 'DA_KY')
            throw new Error('Bản ký đã hết hiệu lực. Kiểm tra hồ sơ trước khi in.');
        const blob = await pdf.blob();
        if (blob.type !== 'application/pdf' || !blob.size) throw new Error('File PDF đã ký không hợp lệ.');
        donPdfDangIn();
        khamBenhPdfObjectUrl = URL.createObjectURL(blob);
        await new Promise((resolve,reject)=>{
            const deadline = window.setTimeout(()=>{frame.onload=null;reject(new Error('Trình duyệt chưa tải được PDF ký để in. Bấm Ký số để mở lại.'));},15000);
            frame.onload = ()=>{
                frame.onload = null;
                window.setTimeout(()=>{
                    window.clearTimeout(deadline);
                    try {
                        if (!frame.contentWindow) throw new Error('Không mở được hộp thoại in của trình duyệt.');
                        frame.contentWindow.onafterprint = donPdfDangIn;
                        frame.contentWindow.focus();
                        frame.contentWindow.print();
                        resolve();
                    } catch(error) { reject(error); }
                },100);
            };
            frame.src = khamBenhPdfObjectUrl;
        });
    } catch(error) { donPdfDangIn(); showToast('error',error.message || 'Không hoàn tất ký PDF.'); }
    finally {
        kbKySoBusy = false; datTrangThaiTaoPdf(false);
        previous.forEach(({button,disabled,html})=>{button.innerHTML=html;button.disabled=disabled;});
    }
}

// ==========================================
// KẾT QUẢ CLS: TẢI LÊN VÀ XEM TÀI LIỆU
// ==========================================
let currentClsOrder = null;
let currentClsInfo = null;
let pendingClsFile = null;
let clsUploadInProgress = false;
let clsEditingDisabled = false;
let clsPreviewObjectUrl = null;
let clsPreviewRequestId = 0;
const clsEnsureOrderPromises = new WeakMap();

async function damBaoChiDinhClsDaLuu(order) {
    if (!order) return 0;
    const currentId = Number(order.id || 0);
    if (currentId > 0) return currentId;

    if (!selectedIdVaoVien || !order.id_dich_vu) {
        showToast('warning', 'Chưa đủ thông tin lượt khám hoặc dịch vụ CLS.');
        return 0;
    }

    const existingPromise = clsEnsureOrderPromises.get(order);
    if (existingPromise) return existingPromise;

    const promise = (async () => {
        try {
            const res = await apiPost('/api/cls/chi_dinh/dam_bao', {
                id_vao_vien: Number(selectedIdVaoVien),
                id_dich_vu: Number(order.id_dich_vu),
                so_luong: Number(order.so_luong || 1),
                gui_ngoai: order.gui_ngoai === true,
                noi_gui_ngoai: order.noi_gui_ngoai || null,
                ghi_chu: order.ghi_chu || null
            });

            const id = Number(res?.data?.id_chi_dinh_ct || 0);
            if (res?.status !== 200 || id <= 0) {
                showToast('error', res?.message || 'Không tạo được chỉ định CLS để tải file.');
                return 0;
            }

            order.id = id;
            renderChiDinhTable();
            return id;
        } catch (error) {
            window.logClientError?.('Tạo chỉ định CLS để tải file', error, { idVaoVien: selectedIdVaoVien });
            showToast('error', 'Không tạo được chỉ định CLS để tải file.');
            return 0;
        } finally {
            clsEnsureOrderPromises.delete(order);
        }
    })();

    clsEnsureOrderPromises.set(order, promise);
    return promise;
}

async function moTaiFileKetQuaCls(order) {
    const idChiDinh = await damBaoChiDinhClsDaLuu(order);
    if (idChiDinh <= 0) return;
    currentClsOrder = order;
    currentClsInfo = null;

    resetClsModal();
    const modalEl = document.getElementById('modalKetQuaCls');
    bootstrap.Modal.getOrCreateInstance(modalEl).show();

    try {
        const res = await apiGet('/api/cls/ket_qua?id_chi_dinh_ct=' + encodeURIComponent(order.id));
        if (res.status !== 200) {
            showToast('error', res.message || 'Không tải được danh sách file.');
            return;
        }

        currentClsInfo = res.data || {};

        fillClsModal();
    } catch (e) {
        window.logClientError?.('Tải kết quả CLS', e, { idChiDinh: order.id });
        showToast('error', 'Không tải được danh sách file. Thử lại.');
    }
}

async function moXemKetQuaCls(order) {
    if (!order?.id || !clsHasResult(order)) return;

    try {
        const res = await apiGet('/api/cls/ket_qua?id_chi_dinh_ct=' + encodeURIComponent(order.id));
        if (res.status !== 200) {
            showToast('error', res.message || 'Không tải được tài liệu kết quả CLS.');
            return;
        }

        const info = res.data || {};
        order.co_file_ket_qua = info.CoFileKetQua === true;
        order.duong_dan_ket_qua = info.DuongDanKetQua || null;
        if (!order.co_file_ket_qua) {
            renderChiDinhTable();
            showToast('warning', 'Chưa có file kết quả.');
            return;
        }

        currentClsOrder = order;
        currentClsInfo = info;
        openClsResultPreview();
    } catch (e) {
        window.logClientError?.('Mở tài liệu CLS', e, { idChiDinh: order.id });
        showToast('error', 'Không tải được file kết quả. Thử lại.');
    }
}

function resetClsModal() {
    const title = document.getElementById('cls-modal-title-service');
    const patient = document.getElementById('cls-modal-patient');
    if (title) title.textContent = currentClsOrder?.ten_dich_vu || 'Dịch vụ CLS';
    if (patient) patient.textContent = currentSelectedPatient
        ? `${currentSelectedPatient.HoTen || ''} ${currentSelectedPatient.MaBN ? '• ' + currentSelectedPatient.MaBN : ''}`
        : '';

    const input = document.getElementById('cls-file-input');
    if (input) input.value = '';
    pendingClsFile = null;
    renderClsUploadQueue();

    updateClsStatusUi(0);
    renderClsFiles();
    setClsEditingDisabled(!selectedPatientCanEdit);
}

function fillClsModal() {
    const info = currentClsInfo || {};
    const status = Number(info.TrangThai || 0);

    document.getElementById('cls-modal-title-service').textContent =
        `${info.MaDichVu ? '[' + info.MaDichVu + '] ' : ''}${info.TenDichVu || currentClsOrder?.ten_dich_vu || ''}`;
    document.getElementById('cls-modal-patient').textContent =
        `${info.HoTen || currentSelectedPatient?.HoTen || ''}${info.MaBN ? ' • ' + info.MaBN : ''}${info.NgaySinh ? ' • NS ' + formatDateVN(info.NgaySinh) : ''}`;

    renderClsFiles();
    updateClsStatusUi(status);
    setClsEditingDisabled(!selectedPatientCanEdit);
    syncCurrentOrderFromCls();
}

async function reloadCurrentClsResult() {
    if (!currentClsOrder?.id) return;
    const res = await apiGet('/api/cls/ket_qua?id_chi_dinh_ct=' + encodeURIComponent(currentClsOrder.id));
    if (res.status !== 200) return;
    currentClsInfo = res.data || {};
    fillClsModal();
}

function syncCurrentOrderFromCls() {
    if (!currentClsOrder || !currentClsInfo) return;
    currentClsOrder.trang_thai_ket_qua = Number(currentClsInfo.TrangThai || 0);
    currentClsOrder.co_file_ket_qua = currentClsInfo.CoFileKetQua === true;
    currentClsOrder.duong_dan_ket_qua = currentClsInfo.DuongDanKetQua || null;
    renderChiDinhTable();
}

function updateClsStatusUi(status) {
    const badge = document.getElementById('cls-result-status');
    const meta = clsStatusBadgeMeta(status);

    if (badge) {
        badge.className = 'badge ' + meta.cls;
        badge.textContent = meta.text;
    }
}

function setClsEditingDisabled(disabled) {
    clsEditingDisabled = Boolean(disabled);
    const upload = document.getElementById('btn-cls-upload');
    const input = document.getElementById('cls-file-input');
    const zone = document.getElementById('cls-file-dropzone');
    if (input) input.disabled = clsEditingDisabled || clsUploadInProgress;
    if (zone) {
        zone.classList.toggle('is-disabled', clsEditingDisabled || clsUploadInProgress);
        zone.setAttribute('aria-disabled', String(clsEditingDisabled || clsUploadInProgress));
    }
    renderClsUploadQueue();
    renderClsFiles();
}

function renderClsFiles() {
    const body = document.getElementById('cls-file-list');
    const count = document.getElementById('cls-file-count');
    const hasFile = currentClsInfo?.CoFileKetQua === true;
    if (count) count.textContent = hasFile ? '1' : '0';
    if (!body) return;

    if (!hasFile) {
        body.innerHTML = '<div class="text-muted small py-3 text-center">Chưa có tài liệu kết quả.</div>';
        return;
    }

    const idChiDinh = Number(currentClsInfo.IDChiDinhCT || currentClsOrder?.id || 0);
    const ext = String(currentClsInfo.DuongDanKetQua || '').split('.').pop().toLowerCase();
    const image = ['jpg', 'jpeg', 'png', 'webp'].includes(ext);
    body.innerHTML = `
        <div class="d-flex align-items-center justify-content-between border rounded px-2 py-2 mb-1">
            <div class="text-truncate me-2">
                <i class="bi ${image ? 'bi-file-earmark-image text-primary' : 'bi-file-earmark-pdf text-danger'} me-1"></i>
                <a href="/api/cls/file/${idChiDinh}" target="_blank" rel="noopener">Kết quả CLS.${image ? ext : 'pdf'}</a>
            </div>
            <button type="button" class="btn btn-sm btn-link text-danger p-0" data-cls-delete-file title="Xóa file" ${clsEditingDisabled ? 'disabled' : ''}><i class="bi bi-trash"></i></button>
        </div>`;

    body.querySelector('[data-cls-delete-file]')?.addEventListener('click', async () => {
        if (idChiDinh <= 0 || clsEditingDisabled) return;
        const res = await apiPost('/api/cls/file/xoa', { id_chi_dinh_ct: idChiDinh });
        showToast(res.status === 200 ? 'success' : 'error', res.message || (res.status === 200 ? 'Đã xóa file.' : 'Không xóa được file.'));
        if (res.status === 200) await reloadCurrentClsResult();
    });
}

function openClsResultPreview() {
    const overlay = document.getElementById('cls-result-preview-overlay');
    const title = document.getElementById('cls-viewer-title-service');
    const patient = document.getElementById('cls-viewer-patient');
    if (!overlay) return;

    if (title) title.textContent = currentClsOrder?.ten_dich_vu || 'Kết quả CLS';
    if (patient) {
        patient.textContent = currentSelectedPatient
            ? `${currentSelectedPatient.HoTen || ''}${currentSelectedPatient.MaBN ? ' | ' + currentSelectedPatient.MaBN : ''}`
            : '';
    }
    overlay.classList.remove('d-none');
    overlay.setAttribute('aria-hidden', 'false');
    document.getElementById('btn-cls-preview-close')?.focus();
    showClsPreviewFile(Number(currentClsInfo?.IDChiDinhCT || currentClsOrder?.id || 0));
}

async function showClsPreviewFile(id) {
    if (id <= 0) return;

    const frame = document.getElementById('cls-result-pdf-viewer');
    const notice = document.getElementById('cls-viewer-download-notice');
    const downloadLink = document.getElementById('cls-viewer-download-link');
    const loading = document.getElementById('cls-viewer-loading');
    const printButton = document.getElementById('btn-cls-preview-print');
    const requestId = ++clsPreviewRequestId;

    if (clsPreviewObjectUrl) {
        URL.revokeObjectURL(clsPreviewObjectUrl);
        clsPreviewObjectUrl = null;
    }
    if (frame) { frame.removeAttribute('srcdoc'); frame.src = 'about:blank'; }
    if (downloadLink) {
        downloadLink.href = `/api/cls/file/${id}?inline=false`;
        downloadLink.textContent = 'Tải file';
        downloadLink.classList.remove('d-none');
    }
    if (printButton) {
        printButton.disabled = false;
        printButton.classList.remove('d-none');
    }
    notice?.classList.add('d-none');
    loading?.classList.remove('d-none');

    try {
        const response = await fetch(`/api/cls/file/${id}?inline=true`, {
            credentials: 'same-origin',
            headers: { Accept: 'application/pdf,image/jpeg,image/png,image/webp' }
        });
        if (!response.ok) {
            const result = await response.json().catch(() => null);
            if (requestId !== clsPreviewRequestId) return;
            loading?.classList.add('d-none');
            const message = response.status === 401
                ? (result?.message || 'Phiên đăng nhập hết hạn. Đăng nhập lại.')
                : response.status === 403
                    ? (result?.message || 'Bạn chưa có quyền xem file.')
                    : 'Không tải được file xem trước. Thử tải file về.';
            showToast('error', message);
            return;
        }

        const pdfBlob = await response.blob();
        if (requestId !== clsPreviewRequestId) return;
        if (!['application/pdf', 'image/jpeg', 'image/png', 'image/webp'].includes(pdfBlob.type))
            throw new Error('Định dạng tài liệu kết quả không được hỗ trợ.');
        clsPreviewObjectUrl = URL.createObjectURL(pdfBlob);
        if (frame && pdfBlob.type.startsWith('image/')) {
            frame.srcdoc = '<!doctype html><html><head><style>html,body{margin:0;height:100%;background:#f5f5f5}body{display:flex;align-items:center;justify-content:center}img{max-width:100%;max-height:100%;object-fit:contain}@media print{html,body{background:white;height:auto;display:block}img{max-width:100%;max-height:95vh}}</style></head><body><img alt="Kết quả CLS" src="' + escapeHtml(clsPreviewObjectUrl) + '"></body></html>';
        } else if (frame) frame.src = clsPreviewObjectUrl;
        loading?.classList.add('d-none');
    } catch (error) {
        window.logClientError?.('Xem trước file kết quả CLS', error, { idChiDinh: id });
        if (requestId === clsPreviewRequestId) {
            loading?.classList.add('d-none');
            showToast('error', 'Không tải được file xem trước. Thử tải file về.');
        }
    }
}

function closeClsResultPreview() {
    clsPreviewRequestId++;
    const overlay = document.getElementById('cls-result-preview-overlay');
    const frame = document.getElementById('cls-result-pdf-viewer');
    const loading = document.getElementById('cls-viewer-loading');
    if (frame) { frame.removeAttribute('srcdoc'); frame.src = 'about:blank'; }
    if (loading) loading.classList.add('d-none');
    if (clsPreviewObjectUrl) URL.revokeObjectURL(clsPreviewObjectUrl);
    clsPreviewObjectUrl = null;
    overlay?.classList.add('d-none');
    overlay?.setAttribute('aria-hidden', 'true');
}

function formatClsFileSize(size) {
    const bytes = Number(size) || 0;
    if (bytes < 1024 * 1024) return `${Math.max(1, Math.ceil(bytes / 1024))} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function renderClsUploadQueue() {
    const list = document.getElementById('cls-upload-queue');
    const button = document.getElementById('btn-cls-upload');
    if (list) {
        list.innerHTML = pendingClsFile ? `
            <div class="cls-upload-queue-item d-flex align-items-center justify-content-between border rounded px-2 py-2 mb-1">
                <div class="text-truncate me-2">
                    <i class="bi bi-paperclip me-1"></i>
                    <span>${escapeHtml(pendingClsFile.name)}</span>
                    <span class="text-muted small ms-1">${formatClsFileSize(pendingClsFile.size)}</span>
                </div>
                <button type="button" class="btn btn-sm btn-link text-danger p-0" data-cls-remove-selected aria-label="Bỏ file đã chọn" ${clsUploadInProgress || clsEditingDisabled ? 'disabled' : ''}>
                    <i class="bi bi-x-lg"></i>
                </button>
            </div>` : '';

        list.querySelector('[data-cls-remove-selected]')?.addEventListener('click', () => {
            if (clsUploadInProgress) return;
            pendingClsFile = null;
            renderClsUploadQueue();
        });
    }
    if (button) {
        button.disabled = clsUploadInProgress || clsEditingDisabled || !pendingClsFile;
        if (!clsUploadInProgress) {
            button.innerHTML = '<i class="bi bi-upload me-1"></i>Tải file đã chọn lên';
        }
    }
}

function addClsFiles(files) {
    const maxFileBytes = 15 * 1024 * 1024;
    const selected = Array.from(files || []);
    if (selected.length > 1) {
        showToast('warning', 'Mỗi lần chỉ chọn một file.');
        return;
    }
    const file = selected[0];
    if (!file) return;
    if (!/\.(pdf|jpe?g|png|webp)$/i.test(file.name || '')) {
        showToast('warning', 'Chọn PDF hoặc ảnh JPG, JPEG, PNG, WEBP.');
        return;
    }
    if (file.size <= 0) {
        showToast('warning', 'File không có dữ liệu.');
        return;
    }
    if (file.size > maxFileBytes) {
        showToast('warning', 'File vượt quá giới hạn 15 MB.');
        return;
    }
    pendingClsFile = file;
    renderClsUploadQueue();
}

function initClsFileDropzone() {
    const zone = document.getElementById('cls-file-dropzone');
    const input = document.getElementById('cls-file-input');
    if (!zone || !input) return;

    zone.addEventListener('click', () => {
        if (!input.disabled && !clsUploadInProgress) input.click();
    });
    zone.addEventListener('keydown', event => {
        if (event.key !== 'Enter' && event.key !== ' ') return;
        event.preventDefault();
        if (!input.disabled && !clsUploadInProgress) input.click();
    });
    input.addEventListener('change', () => {
        addClsFiles(Array.from(input.files || []));
        input.value = '';
    });

    ['dragenter', 'dragover'].forEach(type => zone.addEventListener(type, event => {
        event.preventDefault();
        if (!input.disabled && !clsUploadInProgress) zone.classList.add('is-dragover');
    }));
    zone.addEventListener('dragleave', event => {
        if (!zone.contains(event.relatedTarget)) zone.classList.remove('is-dragover');
    });
    zone.addEventListener('drop', event => {
        event.preventDefault();
        zone.classList.remove('is-dragover');
        if (input.disabled || clsUploadInProgress) return;
        addClsFiles(Array.from(event.dataTransfer?.files || []));
    });
}

async function uploadFileKetQuaCls() {
    if (!currentClsOrder?.id || clsUploadInProgress) return;
    if (!pendingClsFile) {
        showToast('warning', 'Chọn file trước khi tải.');
        return;
    }

    const button = document.getElementById('btn-cls-upload');
    clsUploadInProgress = true;
    renderClsUploadQueue();
    if (button) button.innerHTML = '<span class="spinner-border spinner-border-sm me-1" aria-hidden="true"></span>Đang tải';
    const form = new FormData();
    form.append('id_chi_dinh_ct', String(currentClsOrder.id));
    form.append('file', pendingClsFile);
    try {
        const response = await fetch('/api/cls/file/upload', {
            method: 'POST',
            credentials: 'same-origin',
            body: form
        });
        const result = await response.json().catch(() => null);
        if (response.status === 401) showToast('error', result?.message || 'Phiên đăng nhập hết hạn. Đăng nhập lại.');
        else if (response.status === 403) showToast('error', result?.message || 'Bạn chưa có quyền tải file.');
        else if (response.ok && Number(result?.status) === 200) {
            pendingClsFile = null;
            await reloadCurrentClsResult();
            showToast('success', 'Đã thay file kết quả CLS.');
        } else {
            showToast('error', response.status === 413
                ? 'File vượt quá giới hạn 15 MB.'
                : (result?.message || `Không tải được file (${response.status}).`));
        }
    } catch (error) {
        window.logClientError?.('Tải file kết quả CLS', error, { idChiDinh: currentClsOrder.id });
        showToast('error', 'Không kết nối được máy chủ. File hiện tại vẫn được giữ.');
    } finally {
        clsUploadInProgress = false;
        renderClsUploadQueue();
    }
}

function clsStatusBadgeMeta(status) {
    if (Number(status) === 2) return { text: 'Có kết quả', cls: 'bg-success' };
    return { text: 'Chưa có KQ', cls: 'bg-secondary' };
}

/* function clsEvalMeta(value) {
    if (value === 1) return { text: '↓ Thấp', cls: 'bg-info text-dark' };
    if (value === 2) return { text: '↑ Cao', cls: 'bg-danger' };
    if (value === 3) return { text: '! Bất thường', cls: 'bg-warning text-dark' };
    return { text: 'Bình thường', cls: 'bg-success-subtle text-success border' };
}

function buildNormalRange(m) {
    if (m.GHMin != null && m.GHMax != null) return `${m.GHMin} - ${m.GHMax}`;
    if (m.GHMin != null) return `≥ ${m.GHMin}`;
    if (m.GHMax != null) return `≤ ${m.GHMax}`;
    return '';
}

function parseLocaleNumber(value) {
    if (value == null || String(value).trim() === '') return null;
    const n = Number(String(value).replace(',', '.'));
    return Number.isFinite(n) ? n : null;
}

function nullableNumber(value) {
    if (value === null || value === undefined || value === '') return null;
    const n = Number(value);
    return Number.isFinite(n) ? n : null;
} */

function fromDateTimeLocal(value) {
    if (!value) return null;

    if (window.moment) {
        const m = moment(value, [
            'DD-MM-YYYY HH:mm',
            'DD/MM/YYYY HH:mm',
            moment.ISO_8601
        ], true);
        return m.isValid() ? m.format('YYYY-MM-DDTHH:mm:ss') : null;
    }

    const match = String(value).trim().match(/^(\d{2})[-\/](\d{2})[-\/](\d{4})\s+(\d{2}):(\d{2})$/);
    if (!match) return null;
    return `${match[3]}-${match[2]}-${match[1]}T${match[4]}:${match[5]}:00`;
}

document.getElementById('btn-cls-upload')?.addEventListener('click', uploadFileKetQuaCls);
initClsFileDropzone();
document.getElementById('btn-cls-preview-close')?.addEventListener('click', closeClsResultPreview);
document.getElementById('cls-result-preview-overlay')?.addEventListener('click', event => {
    if (event.target.id === 'cls-result-preview-overlay') closeClsResultPreview();
});
document.getElementById('btn-cls-preview-print')?.addEventListener('click', () => {
    if (!clsPreviewObjectUrl) return;
    const frame = document.getElementById('cls-result-pdf-viewer');
    try {
        frame?.contentWindow?.focus();
        frame?.contentWindow?.print();
    } catch (error) {
        window.logClientError?.('In kết quả CLS', error);
        showToast('error', 'Không mở được hộp thoại in. Hãy dùng nút tải file.');
    }
});
document.addEventListener('keydown', event => {
    if (event.key === 'Escape'
        && !document.getElementById('cls-result-preview-overlay')?.classList.contains('d-none')) {
        closeClsResultPreview();
    }
});

// ==========================================
// QUẢN LÝ CỤM TỪ VIẾT TẮT TRIỆU CHỨNG / DẶN DÒ (DATABASE + LOCAL CACHE)
// ==========================================
const VIET_TAT_CONFIG = {
    TRIEU_CHUNG: {
        storageKey: 'qlpm_viet_tat_trieu_chung',
        label: 'Triệu chứng',
        defaults: [
            { ma: 't', cumTu: 'ngứa 2 tai' },
            { ma: 't', cumTu: 'Đau tê cẳng chân hai bên' },
            { ma: 't', cumTu: 'Khó ở' },
            { ma: 'MM', cumTu: 'MỆT MỎI' },
            { ma: 'sh', cumTu: 'sốt, ho, đau họng.' },
            { ma: 't', cumTu: 'Sốt, ho, khó thở' },
            { ma: 't', cumTu: 'Viêm phế quản' }
        ]
    },
    DAN_DO: {
        storageKey: 'qlpm_viet_tat_dan_do',
        label: 'Dặn dò',
        defaults: []
    }
};

let vietTatModalInstance = null;
let vietTatActiveLoai = 'TRIEU_CHUNG';
const vietTatCacheByLoai = new Map();

function normalizeVietTatLoai(loai) {
    const key = String(loai || '').trim().toUpperCase();
    return VIET_TAT_CONFIG[key] ? key : 'TRIEU_CHUNG';
}

async function loadVietTatFromApi(loai = vietTatActiveLoai) {
    const type = normalizeVietTatLoai(loai);
    try {
        const res = await fetch(`/api/kham_benh/viet_tat?loai=${encodeURIComponent(type)}`, { credentials: 'same-origin' });
        if (res.ok) {
            const data = await res.json();
            if (data.status === 200 && Array.isArray(data.data)) {
                const list = data.data.map(d => ({
                    ma: d.ma || '',
                    cumTu: d.cum_tu || ''
                }));
                setVietTatList(list, type);
                return list;
            }
        }
    } catch (e) {
        console.warn(`Không tải được danh mục viết tắt ${type} từ máy chủ, dùng dữ liệu lưu tạm:`, e);
    }
    return getVietTatList(type);
}

function getVietTatList(loai = vietTatActiveLoai) {
    const type = normalizeVietTatLoai(loai);
    if (vietTatCacheByLoai.has(type)) {
        return vietTatCacheByLoai.get(type) || [];
    }

    const config = VIET_TAT_CONFIG[type];
    try {
        const raw = localStorage.getItem(config.storageKey);
        if (raw) {
            const parsed = JSON.parse(raw);
            if (Array.isArray(parsed)) {
                vietTatCacheByLoai.set(type, parsed);
                return parsed;
            }
        }
    } catch (e) {
        console.warn(`Lỗi đọc localStorage cụm từ viết tắt ${type}:`, e);
    }

    const defaults = config.defaults.map(item => ({ ...item }));
    vietTatCacheByLoai.set(type, defaults);
    return defaults;
}

function setVietTatList(list, loai = vietTatActiveLoai) {
    const type = normalizeVietTatLoai(loai);
    const normalized = Array.isArray(list) ? list : [];
    vietTatCacheByLoai.set(type, normalized);
    try {
        localStorage.setItem(VIET_TAT_CONFIG[type].storageKey, JSON.stringify(normalized));
    } catch (e) {
        console.warn(`Lỗi ghi localStorage cụm từ viết tắt ${type}:`, e);
    }
}

function initVietTatTrieuChung() {
    const bindInput = (elementId, loai) => {
        const el = document.getElementById(elementId);
        if (!el) return;

        el.addEventListener('contextmenu', (e) => {
            e.preventDefault();
            openModalVietTat(loai);
        });
        el.addEventListener('keydown', (e) => handleVietTatKeydown(el, e, loai));
    };

    bindInput('kb-trieu-chung', 'TRIEU_CHUNG');
    bindInput('kb-dan-do', 'DAN_DO');

    // Nạp trước hai bộ dữ liệu, không chặn UI.
    loadVietTatFromApi('TRIEU_CHUNG');
    loadVietTatFromApi('DAN_DO');

    document.getElementById('btn-them-viet-tat')?.addEventListener('click', () => {
        addVietTatRow('', '', true, true);
    });
    document.getElementById('btn-luu-viet-tat')?.addEventListener('click', saveVietTatFromModal);
}

async function openModalVietTat(loai = 'TRIEU_CHUNG') {
    vietTatActiveLoai = normalizeVietTatLoai(loai);
    const modalEl = document.getElementById('modalVietTatTrieuChung');
    if (!modalEl) return;

    const badge = document.getElementById('modal-viet-tat-loai');
    if (badge) badge.textContent = VIET_TAT_CONFIG[vietTatActiveLoai].label;

    if (!vietTatModalInstance && typeof bootstrap !== 'undefined' && bootstrap.Modal) {
        vietTatModalInstance = new bootstrap.Modal(modalEl);
    }

    renderVietTatTable();
    vietTatModalInstance?.show();

    await loadVietTatFromApi(vietTatActiveLoai);
    renderVietTatTable();
}

function renderVietTatTable() {
    const tbody = document.getElementById('tbody-viet-tat');
    if (!tbody) return;
    tbody.innerHTML = '';

    const list = getVietTatList(vietTatActiveLoai);
    if (list.length === 0) {
        addVietTatRow('', '', false, false);
        return;
    }

    list.forEach(item => {
        addVietTatRow(item.ma || '', item.cumTu || '', false, false);
    });
}

function addVietTatRow(ma = '', cumTu = '', focus = false, atTop = false) {
    const tbody = document.getElementById('tbody-viet-tat');
    if (!tbody) return;

    const tr = document.createElement('tr');
    tr.className = 'viet-tat-row align-middle';
    tr.innerHTML = `
        <td style="border-right: 1px solid #dee2e6; border-bottom: 1px solid #dee2e6; padding: 0;">
            <input type="text" class="form-control form-control-sm vt-input-ma border-0 bg-transparent shadow-none"
                   value="${escapeHtml(ma)}" placeholder="" style="border-radius: 0; padding: 6px 10px; font-size: 13.5px; height: 36px; width: 100%; color: #212529;" />
        </td>
        <td style="border-right: 1px solid #dee2e6; border-bottom: 1px solid #dee2e6; padding: 0;">
            <textarea class="form-control form-control-sm vt-input-cum-tu border-0 bg-transparent shadow-none" rows="1"
                      placeholder="" style="border-radius: 0; padding: 6px 10px; font-size: 13.5px; resize: vertical; min-height: 36px; height: 36px; width: 100%; color: #212529;">${escapeHtml(cumTu)}</textarea>
        </td>
        <td style="border-bottom: 1px solid #dee2e6; padding: 0; text-align: center; vertical-align: middle;">
            <button type="button" class="btn btn-link text-danger p-0 text-decoration-none btn-xoa-vt w-100 d-flex align-items-center justify-content-center"
                    title="Xóa dòng" style="font-size: 14px; line-height: 1; height: 36px; opacity: 0.85;">
                <i class="bi bi-x-lg"></i>
            </button>
        </td>
    `;

    tr.querySelector('.btn-xoa-vt')?.addEventListener('click', () => {
        tr.remove();
        if (tbody.querySelectorAll('tr').length === 0) {
            addVietTatRow('', '', false, false);
        }
    });

    if (atTop) {
        tbody.prepend(tr);
        const container = document.getElementById('table-viet-tat-container');
        if (container) container.scrollTop = 0;
    } else {
        tbody.appendChild(tr);
    }

    if (focus) {
        tr.querySelector('.vt-input-ma')?.focus();
    }
}

async function saveVietTatFromModal() {
    const tbody = document.getElementById('tbody-viet-tat');
    if (!tbody) return;

    const rows = tbody.querySelectorAll('tr.viet-tat-row');
    const newList = [];

    rows.forEach((tr, index) => {
        const ma = tr.querySelector('.vt-input-ma')?.value?.trim() || '';
        const cumTu = tr.querySelector('.vt-input-cum-tu')?.value?.trim() || '';
        if (ma || cumTu) {
            newList.push({ ma, cumTu, thu_tu: index + 1 });
        }
    });

    const loai = vietTatActiveLoai;
    setVietTatList(newList, loai);

    try {
        const payload = {
            loai,
            danh_sach: newList.map(item => ({
                ma: item.ma,
                cum_tu: item.cumTu,
                thu_tu: item.thu_tu
            }))
        };

        const res = await fetch('/api/kham_benh/viet_tat', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'same-origin',
            body: JSON.stringify(payload)
        });

        if (res.ok) {
            const result = await res.json();
            showToast(result.status === 200 ? 'success' : 'warning',
                result.message || (result.status === 200 ? 'Đã lưu cụm từ viết tắt.' : 'Không lưu được cụm từ viết tắt.'));
        } else {
            showToast('success', 'Đã lưu vào bộ nhớ tạm.');
        }
    } catch (err) {
        console.warn('Lỗi lưu cụm từ viết tắt vào DB:', err);
        showToast('success', 'Đã lưu cụm từ viết tắt tạm thời.');
    }

    if (vietTatModalInstance) {
        vietTatModalInstance.hide();
    } else {
        const modalEl = document.getElementById('modalVietTatTrieuChung');
        if (modalEl && typeof bootstrap !== 'undefined') {
            bootstrap.Modal.getInstance(modalEl)?.hide();
        }
    }
}

function handleVietTatKeydown(el, e, loai = 'TRIEU_CHUNG') {
    if (e.key !== ' ' && e.key !== 'Enter' && e.key !== 'Tab') return;
    if (e.isComposing) return;

    const list = getVietTatList(loai);
    if (!list || list.length === 0) return;

    const pos = el.selectionStart;
    const text = el.value;
    const textBefore = text.slice(0, pos);
    const match = textBefore.match(/([^\s\n\r]+)$/);
    if (!match) return;

    const word = match[1];
    let found = list.find(x => x.ma && x.ma.trim() === word);
    if (!found) {
        found = list.find(x => x.ma && x.ma.trim().toLowerCase() === word.toLowerCase());
    }

    if (found && found.cumTu) {
        e.preventDefault();
        const start = pos - word.length;
        const textAfter = text.slice(pos);
        const replacement = found.cumTu;
        // Nếu khớp viết tắt thì Enter/Tab xác nhận cụm từ; Enter bình thường vẫn xuống dòng trong textarea.
        const suffix = e.key === ' ' ? ' ' : '';

        el.value = text.slice(0, start) + replacement + suffix + textAfter;
        const newPos = start + replacement.length + suffix.length;
        el.setSelectionRange(newPos, newPos);
        el.dispatchEvent(new Event('input', { bubbles: true }));
        if (typeof markDirty === 'function') markDirty();
    }
}
