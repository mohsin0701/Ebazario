
// ── NAVIGATION ──────────────────────────────────────────────
function nav(el) {
  if (!el) return;
  var id = el.getAttribute('data-sec');
  if (!id) return;
  document.querySelectorAll('.sec').forEach(function(s){ s.classList.remove('active'); });
  document.querySelectorAll('.sb-item').forEach(function(s){ s.classList.remove('active'); });
  var sec = document.getElementById(id);
  if (sec) sec.classList.add('active');
  el.classList.add('active');
  var lbl = el.querySelector('.sb-label');
  var tb = document.querySelector('.tb-title');
  if (tb) tb.textContent = lbl ? lbl.textContent.trim() : 'Admin Panel';
  window.scrollTo(0,0);
}

// ── TABS ────────────────────────────────────────────────────
function showTab(id, btn) {
  var par = btn.closest('[data-tabs]');
  par.querySelectorAll('.tab-btn').forEach(function(t){ t.classList.remove('on'); });
  par.querySelectorAll('.tabpane').forEach(function(t){ t.classList.remove('on'); });
  btn.classList.add('on');
  var p = document.getElementById(id);
  if (p) p.classList.add('on');
}

// ── MODALS ──────────────────────────────────────────────────
function openModal(id){ var m=document.getElementById(id); if(m)m.classList.add('show'); }
function closeModal(id){ var m=document.getElementById(id); if(m)m.classList.remove('show'); }

// ── TOAST ────────────────────────────────────────────────────
function showToast(msg, type) {
  document.querySelectorAll('.adm-toast').forEach(function(t){ t.remove(); });
  var t = document.createElement('div');
  t.className = 'adm-toast';
  var c = {
    ok:    ['#dcfce7','#86efac','#15803d'],
    warn:  ['#fef3c7','#fcd34d','#92400e'],
    danger:['#fee2e2','#fca5a5','#991b1b']
  }[type] || ['#dcfce7','#86efac','#15803d'];
  t.style.cssText = 'position:fixed;bottom:24px;right:24px;padding:12px 18px;border-radius:10px;font-size:13px;font-weight:600;z-index:9999;box-shadow:0 4px 20px rgba(0,0,0,.12);max-width:360px;font-family:DM Sans,sans-serif;border:1px solid '+c[1]+';background:'+c[0]+';color:'+c[2];
  t.textContent = (type==='ok'?'✓ ':type==='warn'?'⚠ ':'✕ ') + msg;
  document.body.appendChild(t);
  setTimeout(function(){ t.style.transition='opacity .3s'; t.style.opacity='0'; setTimeout(function(){ t.remove(); },300); },3000);
}

// ── PRODUCT APPROVAL ────────────────────────────────────────
function approveProduct(btn, name) {
  var card = btn ? btn.closest('.prc') : null;
  if (card) {
    card.style.transition = 'all .35s';
    card.style.opacity = '0';
    card.style.transform = 'translateX(24px)';
    setTimeout(function(){ if(card.parentNode) card.remove(); }, 350);
  }
  var badge = document.querySelector('[data-sec=sec-prod-approval] .sb-bdg');
  if (badge) badge.textContent = Math.max(0, parseInt(badge.textContent||0) - 1);
  showToast((name||'Product') + ' approved!', 'ok');
}

function rejectProduct(reason, notes) {
  closeModal('modal-reject-prod');
  showToast('Product rejected. Seller notified.', 'warn');
}

// ── SELLER APPROVAL ─────────────────────────────────────────
async function approveSeller(btn, name, sellerId) {
  var row = btn ? btn.closest('tr') : null;
  if (sellerId && typeof sb !== 'undefined') {
    try {
      await sb.from('seller_profiles').update({ status: 'active' }).eq('user_id', sellerId);
    } catch(e) { console.error('Error approving seller:', e); }
  }
  if (row) { row.style.transition='opacity .3s'; row.style.opacity='0'; setTimeout(function(){ if(row.parentNode)row.remove(); },300); }
  var badge = document.querySelector('[data-sec=sec-seller-approval] .sb-bdg');
  if (badge) badge.textContent = Math.max(0, parseInt(badge.textContent||0) - 1);
  showToast((name||'Seller') + ' approved!', 'ok');
}

// ── DOCUMENT APPROVAL ───────────────────────────────────────
function approveDoc(btn) {
  var card = btn ? btn.closest('.doc-card') : null;
  if (card) {
    card.querySelectorAll('.pill').forEach(function(p){ p.className='pill p-ok'; p.textContent='Approved ✓'; });
    card.querySelectorAll('button').forEach(function(b){ if(b.textContent.includes('Approve')||b.textContent.includes('Reject')) b.remove(); });
  }
  var badge = document.querySelector('[data-sec=sec-doc-approval] .sb-bdg');
  if (badge) badge.textContent = Math.max(0, parseInt(badge.textContent||0) - 1);
  showToast('Document approved!', 'ok');
}

// ── SAVE MARGIN ─────────────────────────────────────────────
function saveMargin(btn, cat, inputId) {
  var inp = document.getElementById(inputId);
  var val = inp ? inp.value : '?';
  var row = btn ? btn.closest('tr') : null;
  if (row && row.cells[2]) row.cells[2].innerHTML = '<strong style="color:var(--pl)">'+val+'%</strong>';
  showToast(cat + ' margin updated to ' + val + '%', 'ok');
}

// ── TOGGLE ───────────────────────────────────────────────────
function toggle(el){ el.classList.toggle('on'); }

// ── SIGN OUT ─────────────────────────────────────────────────
function adminSignOut() {
  if (_configured) {
    sb.auth.signOut().then(function(){
      window.location.href = 'login-admin.html';
    });
  } else {
    window.location.href = 'login-admin.html';
  }
}

// ── ADMIN INIT - NO REDIRECT LOOP ───────────────────────────
(async function initAdmin() {
  // Demo mode - just show dashboard without auth check
  if (!_configured) {
    console.warn('[Ebazario] Demo mode - no auth check');
    return;
  }

  try {
    const auth = await requireRole('admin', 'login-admin.html');
    if (!auth) return;
    const { session } = auth;
    let profile = auth.profile;
    var userId = session.user.id;
    var userEmail = session.user.email;

    console.log('[Admin] Session found for:', userEmail);
    
    // In demo mode or if just created, we might need to ensure profile exists
    let { data: profileRes, error: profileErr } = await getProfile(userId);
    if (profileErr || !profileRes) {
      console.warn('[Admin] Profile not found, creating base profile...');
      await sb.from('profiles').upsert({
        id: userId,
        email: userEmail,
        role: 'admin',
        first_name: 'Super',
        last_name: 'Admin',
        is_active: true
      });
      // Refresh profile
      const p2 = await getProfile(userId);
      profileRes = p2.data;
    }

    profile = profileRes;
    console.log('[Admin] Profile role:', profile.role);

    // Role check
    if (profile.role !== 'admin') {
      console.warn('[Admin] Role is not admin:', profile.role, '- signing out');
      await sb.auth.signOut();
      window.location.href = 'login-admin.html';
      return;
    }

    // SUCCESS - update UI
    window._adminId = userId;
    window._adminEmail = userEmail;

    var fullName = ((profile.first_name||'') + ' ' + (profile.last_name||'')).trim() || 'Admin';
    document.querySelectorAll('.tb-pro span').forEach(function(el){ el.textContent = fullName; });
    document.querySelectorAll('.sb-admin strong').forEach(function(el){ el.textContent = fullName; });
    document.querySelectorAll('.sb-admin span').forEach(function(el){ el.textContent = userEmail; });

    console.log('[Admin] Dashboard loaded for:', userEmail);

    // Load counts and dynamic data
    setTimeout(async function(){
      try {
        // 1. Load Stats
        const { count: prodCount } = await sb.from('products').select('*', { count: 'exact', head: true }).eq('status', 'approved');
        const { count: sellerCount } = await sb.from('seller_profiles').select('*', { count: 'exact', head: true }).eq('status', 'active');
        const { count: buyerCount } = await sb.from('profiles').select('*', { count: 'exact', head: true }).eq('role', 'customer');
        const { data: orderData } = await sb.from('orders').select('total_usd');
        
        const totalGMV = orderData ? orderData.reduce((acc, o) => acc + parseFloat(o.total_usd || 0), 0) : 0;
        const platformFee = totalGMV * 0.05;

        const statVals = document.querySelectorAll('.stat-val');
        if (statVals[0]) statVals[0].textContent = '$' + (totalGMV/1000000).toFixed(2) + 'M';
        if (statVals[1]) statVals[1].textContent = orderData ? orderData.length : 0;
        if (statVals[2]) statVals[2].textContent = sellerCount || 0;
        if (statVals[3]) statVals[3].textContent = (buyerCount/1000).toFixed(1) + 'K';

        // 2. Load Pending Actions Counts
        var selectors = [
          { query: sb.from('products').select('id',{count:'exact',head:true}).eq('status','pending_review'), badge: '[data-sec=sec-prod-approval] .sb-bdg' },
          { query: sb.from('seller_profiles').select('id',{count:'exact',head:true}).eq('status','pending'), badge: '[data-sec=sec-seller-approval] .sb-bdg' },
          { query: sb.from('seller_documents').select('id',{count:'exact',head:true}).eq('status','pending'), badge: '[data-sec=sec-doc-approval] .sb-bdg' },
          { query: sb.from('disputes').select('id',{count:'exact',head:true}).eq('status','open'), badge: '[data-sec=sec-disputes] .sb-bdg' }
        ];
        
        for (var i=0; i<selectors.length; i++) {
          var r = await selectors[i].query;
          if (r.count != null) {
            var b = document.querySelector(selectors[i].badge);
            if (b) b.textContent = r.count;
          }
        }

        // 2.5 Load Pending Sellers Dynamically
        const { data: pendingSellers } = await sb.from('seller_profiles')
          .select('*, profiles!seller_profiles_user_id_fkey(email)')
          .eq('status', 'pending')
          .order('created_at', { ascending: false });
        
        const pendingTbody = document.getElementById('sap-pending-body');
        if (pendingTbody) {
          if (pendingSellers && pendingSellers.length > 0) {
            pendingTbody.innerHTML = pendingSellers.map(s => {
              const email = s.profiles?.email || 'No email';
              const name = s.company_name || 'Unknown Company';
              const date = s.created_at ? new Date(s.created_at).toLocaleDateString() : 'Recent';
              const av = name.charAt(0).toUpperCase();
              return `<tr>
                <td><div style="display:flex;align-items:center;gap:10px"><div class="s-av">${av}</div><div><strong style="display:block">${name}</strong><span style="font-size:11px;color:var(--muted)">${email}</span></div></div></td>
                <td>${s.country || 'Unknown'}</td><td><span class="pill p-blue">${s.industry || 'General'}</span></td><td><span class="pill p-muted">${s.plan || 'Free'}</span></td>
                <td><span class="pill p-warn">Pending</span></td><td style="font-size:12px;color:var(--muted)">${date}</td>
                <td><div style="display:flex;gap:5px">
                  <button class="btn btn-ok btn-sm" onclick="approveSeller(this, '${name.replace(/'/g,"\\'").replace(/"/g,'&quot;')}', '${s.user_id}')">✓ Approve</button>
                  <button class="btn btn-danger btn-sm" onclick="if(confirm('Reject this seller?')) { this.closest('tr').remove(); showToast('Seller rejected','warn'); }">✕ Reject</button>
                </div></td>
              </tr>`;
            }).join('');
          } else {
            pendingTbody.innerHTML = '<tr><td colspan="7" style="text-align:center;padding:20px;color:var(--muted)">No pending sellers.</td></tr>';
          }
        }

        // 3. Load Recent Orders
        const { data: recentOrders } = await sb.from('orders').select('order_number, total_usd, status, profiles!orders_buyer_id_fkey(first_name, last_name, country)').order('created_at', { ascending: false }).limit(5);
        if (recentOrders && recentOrders.length > 0) {
            const orderTbody = document.querySelector('#sec-dashboard .tbl tbody');
            if (orderTbody) {
                orderTbody.innerHTML = recentOrders.map(o => `
                    <tr>
                        <td><strong>${o.order_number}</strong></td>
                        <td>${o.profiles?.first_name || 'User'} ${o.profiles?.last_name || ''}</td>
                        <td>$${parseFloat(o.total_usd).toLocaleString()}</td>
                        <td><span class="pill ${o.status === 'delivered' ? 'p-ok' : (o.status === 'disputed' ? 'p-danger' : 'p-blue')}">${o.status}</span></td>
                    </tr>
                `).join('');
            }
        }

        // 4. Load Live Activity (Audit Log)
        const { data: logs } = await sb.from('audit_log').select('*').order('created_at', { ascending: false }).limit(6);
        if (logs && logs.length > 0) {
        const actContainer = document.querySelector('.card-head:has(.pill)'); // Note: :has is modern, but we catch errors
        // Alternative for older browsers:
        const livePill = Array.from(document.querySelectorAll('.pill.p-ok')).find(p => p.textContent.includes('LIVE'));
        const liveContainer = livePill ? livePill.closest('.card') : null;
        
        if (liveContainer) {
            const head = liveContainer.querySelector('.card-head').outerHTML;
            const logHtml = logs.map(l => `
                <div class="act-item">
                    <div class="act-dot ${l.action.includes('Approved') ? 'ad-ok' : 'ad-blue'}">${l.action.includes('Login') ? '👤' : '✓'}</div>
                    <div>
                        <div style="font-size:13px"><strong>${l.action}</strong> — ${l.entity_type || 'System'}</div>
                        <div style="font-size:11px;color:var(--muted)">${new Date(l.created_at).toLocaleTimeString()}</div>
                    </div>
                </div>
            `).join('');
            liveContainer.innerHTML = head + logHtml;
        }
        }

      } catch(e){ console.warn('Dashboard data load error:', e); }
    }, 1000);

  } catch(e) {
    console.error('[Admin] Unexpected error:', e);
    // Don't redirect on unexpected errors - just show dashboard
  }
})();
