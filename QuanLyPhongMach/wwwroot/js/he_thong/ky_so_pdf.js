(() => {
    const panel=document.getElementById('ht-cs-ky-pdf'); if (!panel) return;
    const field=id=>document.getElementById('ht-cs-ky-pdf-'+id);
    let id=0,editable=false,sequence=0;
    const enable=allow=>panel.querySelectorAll('input,button').forEach(el=>el.disabled=!allow);
    async function api(options={}) {
        const response=await fetch('/api/he_thong/cskcb/'+id+'/ky-so-pdf',{credentials:'same-origin',...options});
        const result=await response.json().catch(()=>({}));
        if (!response.ok || result.status!==200) throw new Error(result.message || 'Không đọc/lưu được cấu hình ký PDF.');
        return result;
    }
    document.addEventListener('ht:cs-form',async e=>{
        const current=++sequence; id=Number(e.detail.id || 0); editable=!!e.detail.editable;
        enable(false);field('url').value='';field('active').checked=false;
        field('info').textContent=id ? 'Đang tải cấu hình ký PDF...' : 'Lưu hồ sơ cơ sở trước khi cấu hình ký PDF.';
        if (!id) return;
        try {
            const data=(await api()).data;if (current!==sequence)return;
            field('url').value=data.url_ky_pdf || '';field('active').checked=!!data.hieu_luc;
            field('info').textContent='Mã cơ sở ký: '+data.ma_cskcb+'. Mã người ký lấy từ mã nhân viên của bác sĩ.';
            enable(editable);
        } catch(error) { if (current===sequence)field('info').textContent=error.message; }
    });
    field('save').addEventListener('click',async()=>{
        if (!id || !editable)return;const current=sequence;enable(false);
        try { const result=await api({method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({hieu_luc:field('active').checked,url_ky_pdf:field('url').value.trim()})});window.showToast?.('success',result.message); }
        catch(error){window.showToast?.('error',error.message);}
        finally{if (current===sequence)enable(editable);}
    });
})();
