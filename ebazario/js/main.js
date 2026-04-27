// ═══════════════════════════════════════════════════════════════
// EBAZARIO TRADING — MAIN JS (Enhanced v5)
// Global utilities, shipping calculator, auth state, nav rendering
// ═══════════════════════════════════════════════════════════════

// ── SHIPPING RATES ──
var shippingRates = {
  ae:  { air: 4.5,  sea: 1200, dtd: 6.8,  name: "UAE / Dubai" },
  sa:  { air: 4.8,  sea: 1350, dtd: 7.2,  name: "Saudi Arabia" },
  us:  { air: 5.2,  sea: 1800, dtd: 8.5,  name: "United States" },
  uk:  { air: 5.6,  sea: 1600, dtd: 8.0,  name: "United Kingdom" },
  de:  { air: 5.4,  sea: 1550, dtd: 7.9,  name: "Germany" },
  au:  { air: 6.2,  sea: 2100, dtd: 9.8,  name: "Australia" },
  in:  { air: 3.8,  sea: 900,  dtd: 5.2,  name: "India" },
  ng:  { air: 7.5,  sea: 2400, dtd: 11.2, name: "Nigeria" },
  br:  { air: 6.8,  sea: 2200, dtd: 10.5, name: "Brazil" },
  jp:  { air: 4.2,  sea: 1100, dtd: 6.0,  name: "Japan" },
  kr:  { air: 4.0,  sea: 1050, dtd: 5.8,  name: "South Korea" },
  fr:  { air: 5.5,  sea: 1580, dtd: 7.8,  name: "France" },
  tr:  { air: 4.6,  sea: 1250, dtd: 6.6,  name: "Turkey" },
  za:  { air: 6.5,  sea: 2000, dtd: 10.0, name: "South Africa" },
  mx:  { air: 5.8,  sea: 1700, dtd: 8.2,  name: "Mexico" },
  eg:  { air: 5.0,  sea: 1400, dtd: 7.0,  name: "Egypt" },
  pk:  { air: 4.2,  sea: 1000, dtd: 5.8,  name: "Pakistan" },
  my:  { air: 3.6,  sea: 850,  dtd: 5.0,  name: "Malaysia" },
  id:  { air: 4.0,  sea: 950,  dtd: 5.5,  name: "Indonesia" },
  th:  { air: 3.8,  sea: 880,  dtd: 5.2,  name: "Thailand" }
};

// ── SHIPPING CALCULATOR ──
function calcShipping() {
  var dest = document.getElementById("ship-dest").value;
  var type = document.getElementById("ship-type")?.value;
  var wt = parseFloat(document.getElementById("ship-weight").value) || 0;
  var result = document.getElementById("ship-result");
  if (!dest || !wt) { showToast("Please fill destination and weight.", "warn"); return; }
  var r = shippingRates[dest];
  if (!r) { showToast("Destination not available yet.", "error"); return; }
  var airC = (r.air * wt).toFixed(2);
  var seaC = r.sea.toFixed(2);
  var dtdC = (r.dtd * wt).toFixed(2);
  result.style.display = "block";
  result.innerHTML = '<h4 style="font-family:Sora,sans-serif;font-size:15px;font-weight:800;color:var(--primary);margin-bottom:14px">📦 Shipping Quote to ' + r.name + '</h4>' +
    '<div class="ship-option"><div><div class="ship-method">✈️ Air Freight</div><div class="ship-time">3–7 business days</div></div><div class="ship-price">$' + airC + '</div></div>' +
    '<div class="ship-option"><div><div class="ship-method">🚢 Sea Freight (FCL)</div><div class="ship-time">18–35 business days</div></div><div class="ship-price">$' + seaC + '</div></div>' +
    '<div class="ship-option"><div><div class="ship-method">🚪 Door-to-Door</div><div class="ship-time">5–12 business days</div></div><div class="ship-price">$' + dtdC + '</div></div>' +
    '<p style="font-size:11px;color:var(--text-muted);margin-top:12px;font-weight:500">Estimates only. Final quote confirmed by the Ebazario logistics team after order confirmation.</p>';
}

// ── QUANTITY CONTROL ──
function changeQty(delta) {
  var inp = document.getElementById("qty-input");
  if (!inp) return;
  var v = parseInt(inp.value) || 50;
  inp.value = Math.max(1, v + delta);
  if (typeof updateOrderTotal === 'function') updateOrderTotal();
}

// ── BUY NOW HANDLER ──
async function handleBuyNow(productId, sellerId, basePrice) {
  if (typeof _configured === 'undefined' || !_configured) {
    showToast("This is a demo. Log in to start trading.", "warn");
    return;
  }
  
  try {
    const session = await getSession();
    if (!session || !session.user) {
      window.location.href = (window.location.pathname.includes('/pages/') ? '' : 'pages/') + 'login-customer.html';
      return;
    }

    const qty = parseInt(document.getElementById("qty-input")?.value || 1);
    const finalPrice = await calculateTieredPrice(productId, qty, basePrice);
    
    const confirmMsg = "Confirm your bulk order for " + qty + " units at " + formatUSD(finalPrice) + "/unit?\nTotal: " + formatUSD(finalPrice * qty);
    
    if (confirm(confirmMsg)) {
      showToast("Processing with Trade Assurance...", "ok");
      
      const items = [{ product_id: productId, quantity: qty, price: finalPrice }];
      const res = await createOrder(session.user.id, sellerId, items, null, 'air');
      
      if (res.error) {
        showToast("Order failed: " + res.error.message, "error");
      } else {
        showToast("Order " + res.data.order_number + " placed successfully!", "ok");
        setTimeout(() => {
          window.location.href = (window.location.pathname.includes('/pages/') ? '' : 'pages/') + 'customer-dashboard.html';
        }, 1500);
      }
    }
  } catch(e) {
    console.error("Purchase error:", e);
    showToast("Could not process purchase.", "error");
  }
}

// ── TAB SWITCHING ──
function switchTab(tabName, ctx) {
  var panes = document.querySelectorAll((ctx || "") + " .tab-pane");
  var tabs = document.querySelectorAll((ctx || "") + " .detail-tab");
  var names = Array.from(tabs).map(function(t) { return t.getAttribute("data-tab"); });
  tabs.forEach(function(t, i) { t.classList.toggle("active", names[i] === tabName); });
  panes.forEach(function(p) { p.classList.toggle("active", p.id === "tab-" + tabName); });
}

// ── SEARCH ──
// ─── SEARCH ───
function doSearch() {
  var q = document.getElementById("nav-search");
  if (q && q.value.trim()) {
    // Robust path resolution: find project root relative to current location
    var pathPrefix = '';
    var depth = window.location.pathname.split('/').length - 1;
    // This is a simple heuristic: if we are deeper than 2 levels (root + pages/or other), add ../
    if (window.location.pathname.includes('/categories/') || window.location.pathname.includes('/products/')) {
      pathPrefix = ''; // siblings or specific logic
    }
    // Better: use the known structure
    var isSub = window.location.pathname.includes('/pages/');
    var isDeep = window.location.pathname.includes('/categories/') || window.location.pathname.includes('/products/');
    
    var root = isSub ? (isDeep ? '../../' : '../') : './';
    window.location.href = root + "pages/categories/electronics.html";
  }
}

// ─── GLOBAL NAV AUTH STATE ───
async function updateNavAuth() {
  if (typeof _configured === 'undefined' || !_configured) return;
  if (typeof getSession === 'undefined' || typeof getProfile === 'undefined') return;
  
  try {
    const session = await getSession();
    const navAuth = document.getElementById('nav-auth');
    if (!navAuth) return;
    if (!session || !session.user) return;

    const { data: profile } = await getProfile(session.user.id);
    if (!profile) return;

    const name = profile.first_name || (profile.email ? profile.email.split('@')[0] : 'User');
    const initial = name.charAt(0).toUpperCase();
    let dashLink = profile.role === 'admin' ? 'admin-dashboard.html' : 
                   (profile.role === 'seller' ? 'seller-dashboard.html' : 'customer-dashboard.html');

    const isInSubFolder = window.location.pathname.includes('/pages/');
    const pBase = isInSubFolder ? '' : 'pages/';

    navAuth.innerHTML = `
      <div class="btn-login-menu">
        <a href="${pBase}${dashLink}" class="nav-btn btn-outline" style="display:inline-flex;align-items:center;gap:8px">
          <span style="width:24px;height:24px;border-radius:50%;background:linear-gradient(135deg,var(--p),var(--pl));display:flex;align-items:center;justify-content:center;font-size:10px;font-weight:800;color:#fff">${initial}</span>
          ${name} ▾
        </a>
        <div class="login-dropdown">
           <a href="${pBase}${dashLink}">📊 Dashboard</a>
           <a href="${pBase}customer-dashboard.html">👤 My Account</a>
           <div class="divider"></div>
           <a href="#" onclick="handleGlobalSignOut(event)">🚪 Sign Out</a>
        </div>
      </div>
      <a href="${pBase}${dashLink}" class="nav-btn btn-primary">Dashboard</a>
    `;
  } catch(e) { console.warn('[Ebazario] Nav Auth error:', e); }
}

async function handleGlobalSignOut(e) {
  if (e) e.preventDefault();
  if (typeof signOut === 'function') await signOut();
  else if (typeof sb !== 'undefined') {
    await sb.auth.signOut();
    window.location.href = window.location.pathname.includes('/pages/') ? '../index.html' : 'index.html';
  }
}

// ── SCROLL EFFECT FOR NAV ──
function initScrollNav() {
  var nav = document.getElementById('mainNav') || document.querySelector('nav');
  if (!nav) return;
  window.addEventListener('scroll', function() {
    nav.classList.toggle('scrolled', window.scrollY > 20);
  });
}

// ── INTERSECTION OBSERVER FOR ANIMATIONS ──
function initScrollAnimations() {
  if (!('IntersectionObserver' in window)) return;
  var observer = new IntersectionObserver(function(entries) {
    entries.forEach(function(entry) {
      if (entry.isIntersecting) {
        entry.target.style.animation = 'fadeIn 0.6s ease-out both';
        entry.target.style.animationDelay = (entry.target.dataset.delay || '0') + 's';
        observer.unobserve(entry.target);
      }
    });
  }, { threshold: 0.1 });

  document.querySelectorAll('.product-card, .cat-card, .supplier-card').forEach(function(el, i) {
    el.style.opacity = '0';
    el.dataset.delay = ((i % 5) * 0.08).toString();
    observer.observe(el);
  });
}

// ── TOAST (fallback if supabase.js not loaded) ──
if (typeof showToast === 'undefined') {
  window.showToast = function(msg, type) {
    var old = document.querySelectorAll('.sb-toast');
    old.forEach(function(t) { t.remove(); });
    var t = document.createElement('div');
    t.className = 'sb-toast';
    var colors = {
      ok:    { bg: '#ecfdf5', border: '#a7f3d0', color: '#065f46' },
      error: { bg: '#fef2f2', border: '#fecaca', color: '#991b1b' },
      warn:  { bg: '#fffbeb', border: '#fcd34d', color: '#92400e' }
    };
    var c = colors[type] || colors.ok;
    var icon = type === 'ok' ? '✓' : type === 'warn' ? '⚠' : '✕';
    t.style.cssText = 'position:fixed;bottom:24px;right:24px;padding:14px 20px;border-radius:14px;font-size:13px;font-weight:700;z-index:9999;box-shadow:0 8px 30px rgba(0,0,0,0.12);max-width:380px;font-family:Sora,sans-serif;border:1px solid ' + c.border + ';background:' + c.bg + ';color:' + c.color + ';animation:slideUp 0.3s ease-out';
    t.textContent = icon + ' ' + msg;
    document.body.appendChild(t);
    setTimeout(function() { t.style.transition = 'opacity .3s'; t.style.opacity = '0'; setTimeout(function() { t.remove(); }, 300); }, 3500);
  };
}

// ── INIT ──
document.addEventListener("DOMContentLoaded", function() {
  // Search enter key
  var s = document.getElementById("nav-search");
  if (s) s.addEventListener("keydown", function(e) { if (e.key === "Enter") doSearch(); });

  // Scroll effects
  initScrollNav();
  initScrollAnimations();

  // Auth state (non-blocking)
  updateNavAuth();
});
