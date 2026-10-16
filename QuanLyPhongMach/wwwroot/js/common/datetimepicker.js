// datetimepicker.js - Adapter cho Bootstrap DateTimePicker dùng chung của HisSoft.
(function () {
    const hisIcons = {
        date: 'bi bi-calendar3',
        up: 'bi bi-chevron-up',
        down: 'bi bi-chevron-down',
        previous: 'bi bi-chevron-left',
        next: 'bi bi-chevron-right',
        time: 'bi bi-clock',
        today: 'bi bi-crosshair',
        clear: 'bi bi-trash',
        close: 'bi bi-x-lg'
    };

    function resolveElement(elOrSelector) {
        return typeof elOrSelector === 'string'
            ? document.querySelector(elOrSelector)
            : elOrSelector;
    }

    function normalizeMomentOption(value, endOfDay = false) {
        if (!value) return value;
        if (value === 'today') {
            return endOfDay ? moment().endOf('day') : moment();
        }
        return value;
    }

    const EMPTY_DATE_MASK = '__-__-____';

    // Cơ chế Auto-mask nhập ngày dd-mm-yyyy: 2 dấu '-' hiển thị cố định mọi lúc, gõ xong ngày tự nhảy qua tháng, gõ xong tháng tự nhảy qua năm
    function attachDateAutoMask(input, options = {}) {
        if (!input || input.dataset.autoMaskBound) return;
        input.dataset.autoMaskBound = 'true';
        input.setAttribute('placeholder', EMPTY_DATE_MASK);
        input.setAttribute('maxlength', '10');
        const minYear = Number.isInteger(options.minYear) ? options.minYear : null;

        function getDateMaskError(value) {
            if (!minYear || !value || value === EMPTY_DATE_MASK || !/\d/.test(value)) return '';
            if (!/^[\d_]{2}-[\d_]{2}-[\d_]{4}$/.test(value)) {
                if (value.includes('_')) return '';
                return 'Ngày sinh phải nhập theo định dạng dd-MM-yyyy.';
            }

            const [ngayRaw, thangRaw, namRaw] = value.split('-');
            if (/^\d/.test(ngayRaw) && Number(ngayRaw[0]) > 3) return 'Ngày phải từ 01 đến 31.';
            if (/^\d{2}$/.test(ngayRaw)) {
                const ngay = Number(ngayRaw);
                if (ngay < 1 || ngay > 31) return 'Ngày phải từ 01 đến 31.';
            }

            if (/^\d/.test(thangRaw) && Number(thangRaw[0]) > 1) return 'Tháng phải từ 01 đến 12.';
            if (/^\d{2}$/.test(thangRaw)) {
                const thang = Number(thangRaw);
                if (thang < 1 || thang > 12) return 'Tháng phải từ 01 đến 12.';
            }

            const namPrefix = /^\d+/.exec(namRaw)?.[0] || '';
            if (namPrefix) {
                const namLonNhat = Number(namPrefix.padEnd(4, '9').slice(0, 4));
                if (namLonNhat < minYear) return `Năm sinh phải từ ${minYear} trở lên.`;
            }

            if (/^\d{2}$/.test(ngayRaw) && /^\d{2}$/.test(thangRaw)) {
                const ngay = Number(ngayRaw);
                const thang = Number(thangRaw);
                const nam = /^\d{4}$/.test(namRaw) ? Number(namRaw) : null;
                const namNhuan = nam !== null && (nam % 400 === 0 || (nam % 4 === 0 && nam % 100 !== 0));
                const soNgayTrongThang = [4, 6, 9, 11].includes(thang)
                    ? 30
                    : thang === 2 ? (nam === null || namNhuan ? 29 : 28) : 31;
                if (ngay > soNgayTrongThang) {
                    return `Tháng ${String(thang).padStart(2, '0')} không có ngày ${String(ngay).padStart(2, '0')}.`;
                }
                if (nam !== null && nam < minYear) return `Năm sinh phải từ ${minYear} trở lên.`;
            }

            return '';
        }

        function setDateMaskError(value, show) {
            if (!minYear) return '';
            const message = getDateMaskError(value);
            input.setCustomValidity(message);
            if (message && show && typeof input.reportValidity === 'function') input.reportValidity();
            return message;
        }

        // Đảm bảo ban đầu luôn có dấu '-' hiển thị mọi lúc
        if (!input.value || input.value.trim() === '') {
            input.value = EMPTY_DATE_MASK;
        } else if (/^\d{4}-\d{2}-\d{2}$/.test(input.value.trim())) {
            const parts = input.value.trim().split('-');
            input.value = `${parts[2]}-${parts[1]}-${parts[0]}`;
        }

        function sanitizeMaskValue(val) {
            if (!val || val === EMPTY_DATE_MASK) return EMPTY_DATE_MASK;
            let digits = val.replace(/[^\d]/g, '');
            if (!digits) return EMPTY_DATE_MASK;
            let d1 = digits[0] || '_';
            let d2 = digits[1] || '_';
            let m1 = digits[2] || '_';
            let m2 = digits[3] || '_';
            let y1 = digits[4] || '_';
            let y2 = digits[5] || '_';
            let y3 = digits[6] || '_';
            let y4 = digits[7] || '_';
            return `${d1}${d2}-${m1}${m2}-${y1}${y2}${y3}${y4}`;
        }

        input.addEventListener('focus', function () {
            if (!this.value || this.value === EMPTY_DATE_MASK) {
                this.value = EMPTY_DATE_MASK;
                setTimeout(() => {
                    try { this.setSelectionRange(0, 0); } catch (err) {}
                }, 10);
            } else {
                const firstUnderscore = this.value.indexOf('_');
                if (firstUnderscore !== -1) {
                    setTimeout(() => {
                        try { this.setSelectionRange(firstUnderscore, firstUnderscore); } catch (err) {}
                    }, 10);
                }
            }
        });

        input.addEventListener('click', function () {
            const pos = this.selectionStart;
            if (pos === 2) {
                this.setSelectionRange(3, 3);
            } else if (pos === 5) {
                this.setSelectionRange(6, 6);
            }
        });

        input.addEventListener('keydown', function (e) {
            if (['Tab', 'Enter', 'Escape'].includes(e.key) || e.ctrlKey || e.metaKey) {
                return;
            }

            // Xử lý phím điều hướng
            if (e.key === 'ArrowLeft') {
                const pos = this.selectionStart;
                if (pos === 3 || pos === 6) {
                    e.preventDefault();
                    this.setSelectionRange(pos - 2, pos - 2);
                }
                return;
            }
            if (e.key === 'ArrowRight') {
                const pos = this.selectionStart;
                if (pos === 1 || pos === 4) {
                    e.preventDefault();
                    this.setSelectionRange(pos + 2, pos + 2);
                }
                return;
            }
            if (e.key === 'Home') {
                e.preventDefault();
                this.setSelectionRange(0, 0);
                return;
            }
            if (e.key === 'End') {
                e.preventDefault();
                this.setSelectionRange(10, 10);
                return;
            }

            // Xử lý phím số 0-9
            if (/^\d$/.test(e.key)) {
                e.preventDefault();
                let val = this.value;
                if (val.length !== 10 || val.charAt(2) !== '-' || val.charAt(5) !== '-') {
                    val = sanitizeMaskValue(val);
                }
                const chars = val.split('');
                let pos = this.selectionStart;
                const selectionEnd = this.selectionEnd;
                if (minYear && selectionEnd > pos) {
                    const editablePositions = [0, 1, 3, 4, 6, 7, 8, 9];
                    const firstSelectedPosition = editablePositions.find(p => p >= pos && p < selectionEnd);
                    for (const p of editablePositions) {
                        if (p >= pos && p < selectionEnd) chars[p] = '_';
                    }
                    if (firstSelectedPosition !== undefined) pos = firstSelectedPosition;
                }

                if (pos === 2) pos = 3;
                if (pos === 5) pos = 6;
                if (pos >= 10) return;

                chars[pos] = e.key;
                const nextValue = chars.join('');
                if (setDateMaskError(nextValue, true)) return;
                this.value = nextValue;

                let nextPos = pos + 1;
                if (nextPos === 2) nextPos = 3; // Nhảy qua dấu '-' để nhập tháng
                if (nextPos === 5) nextPos = 6; // Nhảy qua dấu '-' để nhập năm
                this.setSelectionRange(nextPos, nextPos);
                this.dispatchEvent(new Event('input', { bubbles: true }));
                return;
            }

            // Xử lý phím Backspace (dấu '-' không bao giờ bị xóa)
            if (e.key === 'Backspace') {
                e.preventDefault();
                let val = this.value;
                if (val.length !== 10 || val.charAt(2) !== '-' || val.charAt(5) !== '-') {
                    val = sanitizeMaskValue(val);
                }
                const chars = val.split('');
                let start = this.selectionStart;
                let end = this.selectionEnd;

                if (start !== end) {
                    for (let i = start; i < end; i++) {
                        if (i !== 2 && i !== 5) {
                            chars[i] = '_';
                        }
                    }
                    this.value = chars.join('');
                    this.setSelectionRange(start, start);
                    this.dispatchEvent(new Event('input', { bubbles: true }));
                    return;
                }

                if (start <= 0) return;
                let delPos = start - 1;
                // Nếu lùi trúng dấu '-', nhảy qua xóa số trước dấu '-'
                if (delPos === 2 || delPos === 5) {
                    delPos = delPos - 1;
                }
                if (delPos >= 0) {
                    chars[delPos] = '_';
                    this.value = chars.join('');
                    this.setSelectionRange(delPos, delPos);
                    this.dispatchEvent(new Event('input', { bubbles: true }));
                }
                return;
            }

            // Xử lý phím Delete (dấu '-' không bao giờ bị xóa)
            if (e.key === 'Delete') {
                e.preventDefault();
                let val = this.value;
                if (val.length !== 10 || val.charAt(2) !== '-' || val.charAt(5) !== '-') {
                    val = sanitizeMaskValue(val);
                }
                const chars = val.split('');
                let start = this.selectionStart;
                let end = this.selectionEnd;

                if (start !== end) {
                    for (let i = start; i < end; i++) {
                        if (i !== 2 && i !== 5) {
                            chars[i] = '_';
                        }
                    }
                    this.value = chars.join('');
                    this.setSelectionRange(start, start);
                    this.dispatchEvent(new Event('input', { bubbles: true }));
                    return;
                }

                let delPos = start;
                if (delPos === 2 || delPos === 5) {
                    delPos = delPos + 1;
                }
                if (delPos < 10) {
                    chars[delPos] = '_';
                    this.value = chars.join('');
                    this.setSelectionRange(delPos, delPos);
                    this.dispatchEvent(new Event('input', { bubbles: true }));
                }
                return;
            }

            e.preventDefault();
        });

        input.addEventListener('paste', function (e) {
            e.preventDefault();
            const text = (e.clipboardData || window.clipboardData)?.getData('text') || '';
            const digits = text.replace(/[^\d]/g, '');
            let nextValue = this.value;
            if (digits.length >= 8) {
                const d = digits.substring(0, 2);
                const m = digits.substring(2, 4);
                const y = digits.substring(4, 8);
                nextValue = `${d}-${m}-${y}`;
            } else if (digits.length > 0) {
                nextValue = sanitizeMaskValue(digits);
            }
            if (setDateMaskError(nextValue, true)) return;
            this.value = nextValue;
            this.setSelectionRange(Math.min(nextValue.length, 10), Math.min(nextValue.length, 10));
            this.dispatchEvent(new Event('input', { bubbles: true }));
        });

        if (minYear) {
            input.addEventListener('input', function () {
                setDateMaskError(this.value, false);
            });
            setDateMaskError(input.value, false);
        }

        input.addEventListener('blur', function () {
            const val = this.value.trim();
            if (minYear) {
                if (!val || val === EMPTY_DATE_MASK || !/\d/.test(val)) this.value = EMPTY_DATE_MASK;
                setDateMaskError(this.value, false);
                return;
            }

            // Nếu không có số nào hoặc rỗng: giữ nguyên mask '__-__-____' (dấu '-' luôn hiển thị mọi lúc)
            if (!val || val === EMPTY_DATE_MASK || !/\d/.test(val)) {
                this.value = EMPTY_DATE_MASK;
                return;
            }

            // Nếu đã nhập đầy đủ 8 chữ số
            if (!val.includes('_')) {
                const parts = val.split('-');
                if (parts.length === 3) {
                    let d = parseInt(parts[0], 10);
                    let m = parseInt(parts[1], 10);
                    let y = parseInt(parts[2], 10);
                    if (isNaN(d) || d < 1) d = 1;
                    if (d > 31) d = 31;
                    if (isNaN(m) || m < 1) m = 1;
                    if (m > 12) m = 12;
                    if (isNaN(y) || y < 1900) y = new Date().getFullYear();
                    this.value = `${String(d).padStart(2, '0')}-${String(m).padStart(2, '0')}-${y}`;
                    this.dispatchEvent(new Event('input', { bubbles: true }));
                    this.dispatchEvent(new Event('change', { bubbles: true }));
                }
            }
        });
    }


    const EMPTY_DATETIME_MASK = '__-__-____ __:__';

    // Auto-mask datetime dd-mm-yyyy HH:mm: luôn giữ '-', khoảng trắng và ':'.
    function attachDateTimeAutoMask(input) {
        if (!input || input.dataset.autoDateTimeMaskBound) return;
        input.dataset.autoDateTimeMaskBound = 'true';
        input.setAttribute('placeholder', EMPTY_DATETIME_MASK);
        input.setAttribute('maxlength', '16');

        const editablePositions = [0, 1, 3, 4, 6, 7, 8, 9, 11, 12, 14, 15];
        const editableSet = new Set(editablePositions);

        function sanitizeMaskValue(val) {
            if (!val || val === EMPTY_DATETIME_MASK) return EMPTY_DATETIME_MASK;
            const digits = String(val).replace(/[^\d]/g, '').slice(0, 12);
            const chars = EMPTY_DATETIME_MASK.split('');
            editablePositions.forEach((pos, idx) => {
                chars[pos] = digits[idx] || '_';
            });
            return chars.join('');
        }

        function normalizeCurrentValue() {
            const value = String(input.value || '');
            const validShape =
                value.length === 16 &&
                value.charAt(2) === '-' &&
                value.charAt(5) === '-' &&
                value.charAt(10) === ' ' &&
                value.charAt(13) === ':';

            if (!validShape) {
                input.value = sanitizeMaskValue(value);
            }
        }

        function nextEditable(pos) {
            for (const p of editablePositions) {
                if (p >= pos) return p;
            }
            return 16;
        }

        function previousEditable(pos) {
            for (let i = editablePositions.length - 1; i >= 0; i--) {
                if (editablePositions[i] < pos) return editablePositions[i];
            }
            return 0;
        }

        function clearRange(chars, start, end) {
            for (let i = start; i < end; i++) {
                if (editableSet.has(i)) chars[i] = '_';
            }
        }

        if (!input.value || input.value.trim() === '') {
            input.value = EMPTY_DATETIME_MASK;
        } else {
            const raw = input.value.trim();
            if (/^\d{4}-\d{2}-\d{2}[T\s]\d{2}:\d{2}/.test(raw) && window.moment) {
                const m = moment(raw);
                input.value = m.isValid() ? m.format('DD-MM-YYYY HH:mm') : sanitizeMaskValue(raw);
            } else if (/^\d{2}[\/-]\d{2}[\/-]\d{4}\s+\d{2}:\d{2}$/.test(raw)) {
                const parts = raw.replace(/\//g, '-');
                input.value = parts;
            } else {
                input.value = sanitizeMaskValue(raw);
            }
        }

        input.addEventListener('focus', function () {
            normalizeCurrentValue();
            const firstUnderscore = this.value.indexOf('_');
            const pos = firstUnderscore >= 0 ? firstUnderscore : 0;
            setTimeout(() => {
                try { this.setSelectionRange(pos, pos); } catch (_) {}
            }, 0);
        });

        input.addEventListener('click', function () {
            normalizeCurrentValue();
            const pos = this.selectionStart ?? 0;
            if (!editableSet.has(pos) && pos < 16) {
                const next = nextEditable(pos);
                try { this.setSelectionRange(next, next); } catch (_) {}
            }
        });

        input.addEventListener('keydown', function (e) {
            if (['Tab', 'Enter', 'Escape'].includes(e.key) || e.ctrlKey || e.metaKey || e.altKey) {
                return;
            }

            normalizeCurrentValue();
            const chars = this.value.split('');
            let start = this.selectionStart ?? 0;
            let end = this.selectionEnd ?? start;

            if (/^\d$/.test(e.key)) {
                e.preventDefault();

                if (start !== end) {
                    clearRange(chars, start, end);
                }

                const pos = nextEditable(start);
                if (pos >= 16) return;

                chars[pos] = e.key;
                this.value = chars.join('');

                const next = nextEditable(pos + 1);
                try { this.setSelectionRange(next, next); } catch (_) {}
                this.dispatchEvent(new Event('input', { bubbles: true }));
                return;
            }

            if (e.key === 'Backspace') {
                e.preventDefault();

                if (start !== end) {
                    clearRange(chars, start, end);
                    this.value = chars.join('');
                    const caret = nextEditable(start);
                    try { this.setSelectionRange(caret, caret); } catch (_) {}
                } else {
                    const pos = previousEditable(start);
                    chars[pos] = '_';
                    this.value = chars.join('');
                    try { this.setSelectionRange(pos, pos); } catch (_) {}
                }

                this.dispatchEvent(new Event('input', { bubbles: true }));
                return;
            }

            if (e.key === 'Delete') {
                e.preventDefault();

                if (start !== end) {
                    clearRange(chars, start, end);
                    this.value = chars.join('');
                    const caret = nextEditable(start);
                    try { this.setSelectionRange(caret, caret); } catch (_) {}
                } else {
                    const pos = nextEditable(start);
                    if (pos < 16) {
                        chars[pos] = '_';
                        this.value = chars.join('');
                        try { this.setSelectionRange(pos, pos); } catch (_) {}
                    }
                }

                this.dispatchEvent(new Event('input', { bubbles: true }));
                return;
            }

            if (e.key === 'ArrowLeft') {
                e.preventDefault();
                const pos = previousEditable(start);
                try { this.setSelectionRange(pos, pos); } catch (_) {}
                return;
            }

            if (e.key === 'ArrowRight') {
                e.preventDefault();
                const pos = nextEditable(start + 1);
                try { this.setSelectionRange(pos, pos); } catch (_) {}
                return;
            }

            if (e.key === 'Home') {
                e.preventDefault();
                try { this.setSelectionRange(0, 0); } catch (_) {}
                return;
            }

            if (e.key === 'End') {
                e.preventDefault();
                try { this.setSelectionRange(16, 16); } catch (_) {}
                return;
            }

            e.preventDefault();
        });

        input.addEventListener('paste', function (e) {
            e.preventDefault();
            const text = (e.clipboardData || window.clipboardData)?.getData('text') || '';
            this.value = sanitizeMaskValue(text);
            const firstUnderscore = this.value.indexOf('_');
            const pos = firstUnderscore >= 0 ? firstUnderscore : 16;
            try { this.setSelectionRange(pos, pos); } catch (_) {}
            this.dispatchEvent(new Event('input', { bubbles: true }));
        });

        input.addEventListener('blur', function () {
            normalizeCurrentValue();

            if (!/\d/.test(this.value)) {
                this.value = EMPTY_DATETIME_MASK;
                return;
            }

            if (this.value.includes('_')) return;

            if (window.moment) {
                const m = moment(this.value, 'DD-MM-YYYY HH:mm', true);
                if (m.isValid()) {
                    this.value = m.format('DD-MM-YYYY HH:mm');
                    this.dispatchEvent(new Event('input', { bubbles: true }));
                    this.dispatchEvent(new Event('change', { bubbles: true }));
                }
            }
        });
    }

    function initialize(elOrSelector, options, hasTime) {
        const el = resolveElement(elOrSelector);
        if (!el || !window.jQuery?.fn?.datetimepicker || !window.moment) return null;

        const $el = window.jQuery(el);
        const current = $el.data('DateTimePicker');
        if (current) current.destroy();

        const defaults = {
            locale: 'vi',
            format: hasTime ? 'DD-MM-YYYY HH:mm' : 'DD-MM-YYYY',
            extraFormats: hasTime
                ? ['DD-MM-YYYY HH:mm', 'DD/MM/YYYY HH:mm', 'DD-MM-YYYY', 'DD/MM/YYYY', 'YYYY']
                : ['DD-MM-YYYY', 'DD/MM/YYYY', 'YYYY'],
            useStrict: false,
            useCurrent: false,
            widgetPositioning: {
                horizontal: 'auto',
                vertical: 'auto'
            },
            icons: hisIcons,
            keyBinds: {
                left: null,
                right: null
            }
        };

        const mappedOptions = Object.assign({}, options);
        if (Object.prototype.hasOwnProperty.call(mappedOptions, 'defaultDate')) {
            mappedOptions.defaultDate = normalizeMomentOption(mappedOptions.defaultDate);
        }
        if (Object.prototype.hasOwnProperty.call(mappedOptions, 'maxDate')) {
            mappedOptions.maxDate = normalizeMomentOption(mappedOptions.maxDate, true);
        }
        if (Object.prototype.hasOwnProperty.call(mappedOptions, 'minDate')) {
            mappedOptions.minDate = normalizeMomentOption(mappedOptions.minDate);
        }

        delete mappedOptions.dateFormat;
        delete mappedOptions.enableTime;
        delete mappedOptions.time_24hr;
        delete mappedOptions.allowInput;
        if (el.parentElement) {
            const parentPos = window.getComputedStyle ? window.getComputedStyle(el.parentElement).position : el.parentElement.style.position;
            if (parentPos === 'static') {
                el.parentElement.style.position = 'relative';
            }
        }

        // Nếu có defaultDate (ví dụ: 'today'): tự động gán ngày hôm nay vào ô input
        if (mappedOptions.defaultDate) {
            const defMoment = normalizeMomentOption(mappedOptions.defaultDate);
            mappedOptions.defaultDate = defMoment;
            el.value = defMoment.format(hasTime ? 'DD-MM-YYYY HH:mm' : 'DD-MM-YYYY');
        }

        $el.datetimepicker(Object.assign({}, defaults, mappedOptions));

        $el.on('dp.change', function () {
            el.dispatchEvent(new Event('input', { bubbles: true }));
            el.dispatchEvent(new Event('change', { bubbles: true }));
        });

        // Nếu datetimepicker có date mà input vẫn chưa có giá trị, đồng bộ từ date
        const dpInstance = $el.data('DateTimePicker');
        if (dpInstance && dpInstance.date() && (!el.value || el.value === EMPTY_DATE_MASK)) {
            el.value = dpInstance.date().format(hasTime ? 'DD-MM-YYYY HH:mm' : 'DD-MM-YYYY');
        }

        // Date-only và DateTime đều giữ mask cố định khi xóa/nhập tay.
        if (!hasTime) {
            attachDateAutoMask(el);
        } else {
            attachDateTimeAutoMask(el);
        }

        return dpInstance;
    }

    // Cho phép các ô ngày nhập tay dùng cùng cơ chế mask mà không khởi tạo DateTimePicker.
    window.attachDateAutoMask = function (elOrSelector, options = {}) {
        const el = resolveElement(elOrSelector);
        attachDateAutoMask(el, options);
        return el;
    };

    window.initDatePicker = function (elOrSelector, options = {}) {
        return initialize(elOrSelector, options, false);
    };

    window.initDateTimePicker = function (elOrSelector, options = {}) {
        return initialize(elOrSelector, options, true);
    };
})();

// Helper chuyển đổi Date sang định dạng dd-mm-yyyy chuẩn
window.formatDateVN = function (d) {
    if (!d) return '';
    if (typeof d === 'string') {
        const clean = d.split('T')[0].trim();
        if (clean === '__-__-____') return '';
        if (/^\d{4}-\d{2}-\d{2}$/.test(clean)) {
            const [y, m, day] = clean.split('-');
            return `${day}-${m}-${y}`;
        }
        if (/^\d{2}-\d{2}-\d{4}$/.test(clean)) {
            return clean;
        }
    }
    const date = new Date(d);
    if (isNaN(date.getTime())) return '';
    const day = String(date.getDate()).padStart(2, '0');
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const year = date.getFullYear();
    return `${day}-${month}-${year}`;
};

// Helper parse dd-mm-yyyy hoặc dd/MM/yyyy sang ISO yyyy-MM-dd
window.parseDateVNToISO = function (vnStr) {
    if (!vnStr) return null;
    vnStr = String(vnStr).trim();
    if (!vnStr || vnStr === '__-__-____' || vnStr.includes('_')) return null;
    const sep = vnStr.includes('-') ? '-' : (vnStr.includes('/') ? '/' : null);
    if (!sep) return null;
    const parts = vnStr.split(sep);
    if (parts.length !== 3) return null;
    // Nếu phần tử đầu tiên đã là năm (4 ký tự) -> đã là yyyy-MM-dd
    if (parts[0].length === 4) {
        return `${parts[0]}-${parts[1].padStart(2, '0')}-${parts[2].padStart(2, '0')}`;
    }
    // Ngược lại dd-MM-yyyy -> yyyy-MM-dd
    return `${parts[2]}-${parts[1].padStart(2, '0')}-${parts[0].padStart(2, '0')}`;
};

