(function(){
  const cfg=window.ZOMA_CONFIG;
  if(!window.supabase){console.error('Supabase SDK not loaded');return;}
  window.sb=window.supabase.createClient(cfg.SUPABASE_URL,cfg.SUPABASE_ANON_KEY);
  const $=(s,r=document)=>r.querySelector(s), $$=(s,r=document)=>[...r.querySelectorAll(s)];
  window.zoma={
    cfg,$,$$,
    escape(v){return String(v??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[m]))},
    toast(msg,type=''){const t=$('#toast')||document.body.appendChild(Object.assign(document.createElement('div'),{id:'toast',className:'toast'}));t.textContent=msg;t.className='toast show '+(type||'');clearTimeout(window.__zt);window.__zt=setTimeout(()=>t.className='toast',3500)},
    cardId(){return 'ZOMA-'+Math.random().toString(36).slice(2,8).toUpperCase()},
    orderNo(){return 'ZOMA-'+Math.floor(1000+Math.random()*9000)},
    publicUrl(id){return cfg.SITE_URL.replace(/\/$/,'')+'/activation.html?id='+encodeURIComponent(id)},
    async currentUser(){const {data}=await sb.auth.getUser();return data.user},
    async signOut(){await sb.auth.signOut();location.href=cfg.SITE_URL+'index.html'},
    async isAdmin(){const u=await this.currentUser();if(!u)return null;const {data}=await sb.from('admins').select('*').eq('id',u.id).maybeSingle();return data},
    async requireAdmin(){const a=await this.isAdmin();if(!a){location.href='../admin/login.html';return null}return a},
    async log(action,entity_type,entity_id,metadata={}){try{const u=await this.currentUser();await sb.from('audit_logs').insert({admin_id:u?.id||null,action,entity_type,entity_id,metadata})}catch(e){}},
    statusLabel(s){return ({pending:'قيد المراجعة',confirmed:'تم التأكيد',preparing:'جاري التجهيز',ready:'جاهز',shipped:'تم الشحن',delivered:'تم التسليم',rejected:'مرفوض',unactivated:'غير مفعّلة',active:'نشطة',suspended:'موقوفة'})[s]||s},
    statusClass(s){return ['delivered','active','ready'].includes(s)?'success':['rejected','suspended'].includes(s)?'danger':['pending','preparing','unactivated'].includes(s)?'warning':'info'},
    money(v){return `${Number(v||0).toLocaleString('ar-EG')} ${cfg.CURRENCY}`},
    async uploadPhoto(file){const u=await this.currentUser();if(!u)throw Error('يجب تسجيل الدخول');const ext=(file.name.split('.').pop()||'jpg').toLowerCase();const path=`${u.id}/${crypto.randomUUID()}.${ext}`;const {error}=await sb.storage.from('profile-photos').upload(path,file,{upsert:false,contentType:file.type||'image/jpeg'});if(error)throw error;return sb.storage.from('profile-photos').getPublicUrl(path).data.publicUrl},
    wa(phone){let p=String(phone||'').replace(/\D/g,'');if(p.startsWith('0'))p='20'+p.slice(1);if(!p.startsWith('20'))p='20'+p;return 'https://wa.me/'+p},
    vcard(profile){return `BEGIN:VCARD\nVERSION:3.0\nFN:${profile.full_name||''}\nTEL:${profile.whatsapp_1||''}\nTEL:${profile.whatsapp_2||''}\nURL:${profile.facebook_url||profile.tiktok_url||''}\nEND:VCARD`},
    download(name,text){const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([text],{type:'text/vcard'}));a.download=name;a.click();URL.revokeObjectURL(a.href)},
    async writeNfc(card,orderId){if(!('NDEFWriter' in window))throw Error('جهازك أو متصفحك لا يدعم Web NFC. استخدم Android + Chrome عبر HTTPS.');const writer=new NDEFWriter();await writer.write({records:[{recordType:'url',data:card.public_url}]});const u=await this.currentUser();await sb.from('nfc_writes').insert({card_id:card.id,order_id:orderId,admin_id:u.id,status:'success',written_url:card.public_url});return true}
  };
  window.addEventListener('unhandledrejection',e=>console.error(e.reason));
})();
