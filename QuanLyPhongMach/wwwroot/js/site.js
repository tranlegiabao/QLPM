// site.js - Global utility functions for QLPM

window.formatCurrencyVN = function (val) {
    if (val === null || val === undefined || isNaN(val)) return '0 đ';
    return Number(val).toLocaleString('vi-VN') + ' đ';
};

