// xac_nhan.js - Modal xác nhận dùng chung, không sử dụng hộp thoại native của trình duyệt.
(function () {
    window.hien_thi_xac_nhan = function (tuy_chon = {}) {
        return new Promise((resolve) => {
            const modal_element = document.getElementById('modalXacNhanChung');
            const tieu_de_element = document.getElementById('modal-xac-nhan-tieu-de');
            const noi_dung_element = document.getElementById('modal-xac-nhan-noi-dung');
            const nut_dong_y = document.getElementById('btn-modal-xac-nhan-dong-y');
            const nut_khong = modal_element?.querySelector('.modal-footer [data-bs-dismiss="modal"]');

            if (!modal_element || !tieu_de_element || !noi_dung_element || !nut_dong_y || !window.bootstrap?.Modal) {
                showToast('error', 'Không mở được hộp xác nhận. Thao tác đã hủy.');
                resolve(false);
                return;
            }

            tieu_de_element.textContent = tuy_chon.tieu_de || 'Xác nhận thao tác';
            noi_dung_element.textContent = tuy_chon.noi_dung || 'Bạn có muốn tiếp tục không?';
            nut_dong_y.textContent = tuy_chon.nhan_dong_y || 'Đồng ý';
            nut_dong_y.className = `btn ${tuy_chon.lop_nut || 'btn-primary'}`;

            if (nut_khong) {
                nut_khong.classList.toggle('d-none', tuy_chon.an_nut_khong === true);
                nut_khong.textContent = tuy_chon.nhan_khong || 'Không';
            }

            const modal = bootstrap.Modal.getOrCreateInstance(modal_element);
            let da_hoan_tat = false;

            const hoan_tat = (ket_qua) => {
                if (da_hoan_tat) return;
                da_hoan_tat = true;
                if (nut_khong) nut_khong.classList.remove('d-none');
                resolve(ket_qua);
            };

            const xu_ly_dong_y = () => {
                hoan_tat(true);
                modal.hide();
            };

            const xu_ly_an_modal = () => {
                nut_dong_y.removeEventListener('click', xu_ly_dong_y);
                hoan_tat(false);
            };

            nut_dong_y.addEventListener('click', xu_ly_dong_y, { once: true });
            modal_element.addEventListener('hidden.bs.modal', xu_ly_an_modal, { once: true });
            modal.show();
        });
    };
})();
