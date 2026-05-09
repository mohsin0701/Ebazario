// ============================================================
// EBAZARIO TRADING — SUPABASE CLIENT
// ============================================================
// Replace YOUR_SUPABASE_URL and YOUR_ANON_KEY with your
// actual values from: Supabase Dashboard → Settings → API

// ── CONFIGURE THESE TWO VALUES ──────────────────────────────
// Get them from: Supabase Dashboard → Settings → API
const SUPABASE_URL  = 'https://swygjpilcddqosjbzzfm.supabase.co';
const SUPABASE_ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN3eWdqcGlsY2RkcW9zamJ6emZtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzczMDY3MjUsImV4cCI6MjA5Mjg4MjcyNX0.AEvH2AlV4YwAaGKh69j5MgU1TGTMWX0t4XUEmMixpTI';
// ────────────────────────────────────────────────────────────

// Safe init — won't crash page if keys are still placeholders
const { createClient } = supabase;
let sb;
const _configured = (
  SUPABASE_URL !== 'YOUR_SUPABASE_URL' && 
  SUPABASE_URL.includes('supabase.co') &&
  SUPABASE_ANON !== 'YOUR_SUPABASE_ANON_KEY' &&
  SUPABASE_ANON.length > 20
);
if (_configured) {
  try {
    sb = createClient(SUPABASE_URL, SUPABASE_ANON);
  } catch(e) {
    console.error('[Ebazario] Supabase init failed:', e.message);
  }
} else {
  console.warn('[Ebazario] ⚠️  Supabase not configured yet. Edit js/supabase.js with your project URL and anon key.');
  // Create a stub so pages dont crash on function calls
  sb = {
    auth: {
      getSession: async () => ({ data: { session: null } }),
      getUser: async () => ({ data: { user: null } }),
      signInWithPassword: async () => { throw new Error('Supabase not configured. Edit js/supabase.js first.'); },
      signUp: async () => { throw new Error('Supabase not configured. Edit js/supabase.js first.'); },
      signOut: async () => {},
      signInWithOAuth: async () => ({ error: { message: 'Supabase not configured.' } }),
      resetPasswordForEmail: async () => ({ error: null })
    },
    from: () => ({
      select: () => ({ eq: () => ({ single: async () => ({ data: null, error: null }), data: null, error: null }), data: null, error: null }),
      insert: () => ({ select: () => ({ single: async () => ({ data: null, error: null }) }) }),
      update: () => ({ eq: () => ({ select: () => ({ single: async () => ({ data: null, error: null }) }) }) }),
      upsert: () => ({ select: () => ({ single: async () => ({ data: null, error: null }) }) }),
      delete: () => ({ eq: async () => ({ data: null, error: null }) })
    }),
    storage: { from: () => ({ upload: async () => ({ data: null, error: null }), getPublicUrl: () => ({ data: { publicUrl: '' } }) }) },
    channel: () => ({ on: function(){ return this; }, subscribe: function(){ return this; } })
  };
}

// ─── AUTH HELPERS ────────────────────────────────────────────

async function getSession() {
  const { data: { session } } = await sb.auth.getSession();
  return session;
}

async function getUser() {
  const { data: { user } } = await sb.auth.getUser();
  return user;
}

async function getProfile(userId) {
  // First get base profile
  const { data, error } = await sb
    .from('profiles')
    .select('*')
    .eq('id', userId)
    .single();
  if (error || !data) return { data, error };
  // Then get sub-profile based on role (avoid join errors)
  if (data.role === 'customer') {
    const { data: cp } = await sb.from('customer_profiles').select('*').eq('user_id', userId).single();
    data.customer_profiles = cp || null;
  } else if (data.role === 'seller') {
    const { data: sp } = await sb.from('seller_profiles').select('*').eq('user_id', userId).single();
    data.seller_profiles = sp || null;
  }
  return { data, error: null };
}

async function requireRole(expectedRole, redirectTo) {
  const session = await getSession();
  if (!session) { window.location.href = redirectTo || '../pages/login-customer.html'; return null; }
  const { data: profile } = await getProfile(session.user.id);
  if (!profile || profile.role !== expectedRole) {
    window.location.href = redirectTo || '../index.html';
    return null;
  }
  return { session, profile };
}

async function signOut() {
  await sb.auth.signOut();
  window.location.href = '../index.html';
}

// ─── CUSTOMER AUTH ───────────────────────────────────────────

async function customerSignIn(email, password) {
  const { data, error } = await sb.auth.signInWithPassword({ email, password });
  if (error) throw error;
  // Verify role
  const { data: profile } = await getProfile(data.user.id);
  if (profile?.role !== 'customer') {
    await sb.auth.signOut();
    throw new Error('Not a customer account');
  }
  return data;
}

async function customerSignUp(email, password, meta) {
  const { data, error } = await sb.auth.signUp({
    email, password,
    options: { data: { role: 'customer', ...meta } }
  });
  if (error) throw error;
  // Create customer_profile row
  if (data.user) {
    await sb.from('customer_profiles').insert({
      user_id: data.user.id,
      company_name: meta.company_name,
      position: meta.position
    });
  }
  return data;
}

// ─── SELLER AUTH ─────────────────────────────────────────────

async function sellerSignIn(email, password) {
  const { data, error } = await sb.auth.signInWithPassword({ email, password });
  if (error) throw error;
  const { data: profile } = await getProfile(data.user.id);
  if (profile?.role !== 'seller') {
    await sb.auth.signOut();
    throw new Error('Not a seller account');
  }
  return data;
}

async function sellerSignUp(email, password, meta) {
  const { data, error } = await sb.auth.signUp({
    email, password,
    options: { data: { role: 'seller', ...meta } }
  });
  if (error) throw error;
  if (data.user) {
    await sb.from('seller_profiles').insert({
      user_id: data.user.id,
      company_name: meta.company_name,
      country: meta.country,
      industry: meta.industry,
      plan: 'free',
      status: 'pending'
    });
  }
  return data;
}

// ─── ADMIN AUTH ───────────────────────────────────────────────

async function adminSignIn(email, password) {
  const { data, error } = await sb.auth.signInWithPassword({ email, password });
  if (error) throw error;
  const { data: profile } = await getProfile(data.user.id);
  if (profile?.role !== 'admin') {
    await sb.auth.signOut();
    throw new Error('Admin access denied');
  }
  return data;
}

// ─── PRODUCTS ─────────────────────────────────────────────────

async function getProducts({ category, status = 'approved', search, limit = 20, offset = 0 } = {}) {
  let query = sb
    .from('products')
    .select('*, categories(name, icon, slug), seller_profiles(company_name, avg_rating, country, plan)')
    .eq('status', status)
    .range(offset, offset + limit - 1)
    .order('is_featured', { ascending: false })
    .order('order_count', { ascending: false });

  if (category) query = query.eq('category_id', category);
  if (search) query = query.textSearch('title', search, { type: 'websearch' });

  const { data, error, count } = await query;
  return { data, error, count };
}

async function getProduct(id) {
  const { data, error } = await sb
    .from('products')
    .select('*, categories(*), seller_profiles(*), product_price_tiers(*), reviews(*, profiles(first_name, last_name))')
    .eq('id', id)
    .single();
  return { data, error };
}

async function getSellerProducts(sellerId) {
  const { data, error } = await sb
    .from('products')
    .select('*, categories(name, icon), product_price_tiers(*)')
    .eq('seller_id', sellerId)
    .order('created_at', { ascending: false });
  return { data, error };
}

async function upsertProduct(productData) {
  const { data, error } = await sb
    .from('products')
    .upsert(productData)
    .select()
    .single();
  return { data, error };
}

// ─── ORDERS ──────────────────────────────────────────────────

async function getMyOrders(userId, role = 'buyer') {
  let query = sb
    .from('orders')
    .select('*, seller_profiles(company_name, country)')
    .order('created_at', { ascending: false });

  if (role === 'buyer') query = query.eq('buyer_id', userId);
  else query = query.eq('seller_id', userId);

  const { data, error } = await query;
  return { data, error };
}

async function getOrder(orderId) {
  const { data, error } = await sb
    .from('orders')
    .select('*, profiles!buyer_id(first_name,last_name,email), seller_profiles(company_name,country,avg_rating), addresses(*)')
    .eq('id', orderId)
    .single();
  return { data, error };
}

async function createOrder(orderData) {
  const { data, error } = await sb
    .from('orders')
    .insert(orderData)
    .select()
    .single();
  return { data, error };
}

async function updateOrderStatus(orderId, status, extra = {}) {
  const { data, error } = await sb
    .from('orders')
    .update({ status, ...extra, updated_at: new Date().toISOString() })
    .eq('id', orderId)
    .select()
    .single();
  return { data, error };
}

// ─── RFQs ────────────────────────────────────────────────────

async function getMyRFQs(buyerId) {
  const { data, error } = await sb
    .from('rfqs')
    .select('*, categories(name, icon), rfq_quotes(count)')
    .eq('buyer_id', buyerId)
    .order('created_at', { ascending: false });
  return { data, error };
}

async function createRFQ(rfqData) {
  const { data, error } = await sb
    .from('rfqs')
    .insert(rfqData)
    .select()
    .single();
  return { data, error };
}

async function getOpenRFQs(categoryId) {
  let query = sb
    .from('rfqs')
    .select('*, categories(name), profiles!buyer_id(country)')
    .eq('status', 'open')
    .order('created_at', { ascending: false });
  if (categoryId) query = query.eq('category_id', categoryId);
  const { data, error } = await query;
  return { data, error };
}

async function submitQuote(quoteData) {
  const { data, error } = await sb
    .from('rfq_quotes')
    .upsert(quoteData)
    .select()
    .single();
  return { data, error };
}

// ─── REVIEWS ─────────────────────────────────────────────────

async function submitReview(reviewData) {
  const { data, error } = await sb
    .from('reviews')
    .insert(reviewData)
    .select()
    .single();
  return { data, error };
}

// ─── WISHLIST ─────────────────────────────────────────────────

async function getWishlist(userId) {
  const { data, error } = await sb
    .from('wishlists')
    .select('*, products(id, title, base_price_usd, buyer_price_usd, images, seller_profiles(company_name))')
    .eq('user_id', userId);
  return { data, error };
}

async function toggleWishlist(userId, productId) {
  const { data: existing } = await sb
    .from('wishlists')
    .select('id')
    .eq('user_id', userId)
    .eq('product_id', productId)
    .single();

  if (existing) {
    await sb.from('wishlists').delete().eq('id', existing.id);
    return { added: false };
  } else {
    await sb.from('wishlists').insert({ user_id: userId, product_id: productId });
    return { added: true };
  }
}

// ─── DISPUTES ────────────────────────────────────────────────

async function getMyDisputes(userId, role = 'buyer') {
  let query = sb
    .from('disputes')
    .select('*, orders(order_number, total_usd), seller_profiles(company_name)')
    .order('created_at', { ascending: false });
  if (role === 'buyer') query = query.eq('buyer_id', userId);
  else query = query.eq('seller_id', userId);
  const { data, error } = await query;
  return { data, error };
}

async function fileDispute(disputeData) {
  const { data, error } = await sb
    .from('disputes')
    .insert(disputeData)
    .select()
    .single();
  return { data, error };
}

// ─── NOTIFICATIONS ───────────────────────────────────────────

async function getNotifications(userId, unreadOnly = false) {
  let query = sb
    .from('notifications')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .limit(50);
  if (unreadOnly) query = query.eq('is_read', false);
  const { data, error } = await query;
  return { data, error };
}

async function markNotificationRead(id) {
  await sb.from('notifications').update({ is_read: true }).eq('id', id);
}

async function markAllNotificationsRead(userId) {
  await sb.from('notifications').update({ is_read: true }).eq('user_id', userId);
}

// ─── ADMIN ───────────────────────────────────────────────────

async function adminGetPendingProducts(limit = 20) {
  const { data, error } = await sb
    .from('products')
    .select('*, categories(name), seller_profiles(company_name, plan, avg_rating, status)')
    .eq('status', 'pending_review')
    .order('created_at', { ascending: true })
    .limit(limit);
  return { data, error };
}

async function adminApproveProduct(productId, adminId) {
  const { data, error } = await sb
    .from('products')
    .update({ status: 'approved', reviewed_by: adminId, reviewed_at: new Date().toISOString() })
    .eq('id', productId)
    .select()
    .single();
  // Log action
  await sb.from('audit_log').insert({
    user_id: adminId,
    action: 'product_approved',
    entity_type: 'product',
    entity_id: productId
  });
  return { data, error };
}

async function adminRejectProduct(productId, adminId, reason, notes) {
  const { data, error } = await sb
    .from('products')
    .update({
      status: 'rejected',
      rejection_reason: reason,
      rejection_notes: notes,
      reviewed_by: adminId,
      reviewed_at: new Date().toISOString()
    })
    .eq('id', productId)
    .select()
    .single();
  await sb.from('audit_log').insert({
    user_id: adminId,
    action: 'product_rejected',
    entity_type: 'product',
    entity_id: productId,
    new_data: { reason, notes }
  });
  return { data, error };
}

async function adminGetPendingSellers() {
  const { data, error } = await sb
    .from('seller_profiles')
    .select('*, profiles(email, first_name, last_name, created_at), seller_documents(*)')
    .eq('status', 'pending')
    .order('created_at', { ascending: true });
  return { data, error };
}

async function adminApproveSeller(sellerProfileId, adminId) {
  const { data, error } = await sb
    .from('seller_profiles')
    .update({ status: 'active', approved_at: new Date().toISOString(), approved_by: adminId })
    .eq('id', sellerProfileId)
    .select()
    .single();
  await sb.from('audit_log').insert({
    user_id: adminId,
    action: 'seller_approved',
    entity_type: 'seller_profiles',
    entity_id: sellerProfileId
  });
  return { data, error };
}

async function adminGetPlatformStats() {
  const [orders, sellers, customers, products] = await Promise.all([
    sb.from('orders').select('total_usd, status', { count: 'exact' }),
    sb.from('seller_profiles').select('id, status', { count: 'exact' }),
    sb.from('customer_profiles').select('id', { count: 'exact' }),
    sb.from('products').select('id, status', { count: 'exact' })
  ]);
  return { orders, sellers, customers, products };
}

async function adminGetShippingRates() {
  const { data, error } = await sb
    .from('shipping_rates')
    .select('*')
    .eq('is_active', true)
    .order('destination_label');
  return { data, error };
}

async function adminUpdateShippingRate(id, updates) {
  const { data, error } = await sb
    .from('shipping_rates')
    .update({ ...updates, updated_at: new Date().toISOString() })
    .eq('id', id)
    .select()
    .single();
  return { data, error };
}

async function adminGetAuditLog(limit = 100) {
  const { data, error } = await sb
    .from('audit_log')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(limit);
  return { data, error };
}

async function adminGetPayouts(status = 'pending') {
  const { data, error } = await sb
    .from('seller_payouts')
    .select('*, seller_profiles(company_name, country)')
    .eq('status', status)
    .order('created_at', { ascending: false });
  return { data, error };
}

async function adminProcessPayout(payoutId, adminId, reference) {
  const { data, error } = await sb
    .from('seller_payouts')
    .update({
      status: 'paid',
      paid_at: new Date().toISOString(),
      payment_reference: reference,
      processed_by: adminId
    })
    .eq('id', payoutId)
    .select()
    .single();
  return { data, error };
}

async function moderateProduct(productId, adminId, status, notes = '') {
  const { data, error } = await sb
    .from('products')
    .update({
      status: status,
      reviewed_by: adminId,
      reviewed_at: new Date().toISOString(),
      admin_notes: notes
    })
    .eq('id', productId)
    .select()
    .single();
  return { data, error };
}

// ─── B2B TRANSACTION LOGIC ───────────────────────────────────

async function getProductTiers(productId) {
  const { data, error } = await sb
    .from('product_price_tiers')
    .select('*')
    .eq('product_id', productId)
    .order('min_qty', { ascending: true });
  return { data, error };
}

async function calculateTieredPrice(productId, quantity, basePrice) {
  const { data: tiers } = await getProductTiers(productId);
  if (!tiers || tiers.length === 0) return basePrice;
  
  let finalPrice = basePrice;
  for (const tier of tiers) {
    if (quantity >= tier.min_qty) {
      if (!tier.max_qty || quantity <= tier.max_qty) {
        finalPrice = tier.price_usd;
      } else if (quantity > tier.max_qty) {
        finalPrice = tier.price_usd; // Fallback to last match
      }
    }
  }
  return finalPrice;
}

async function createOrder(buyerId, sellerId, items, shippingId, method) {
  // 1. Generate Order Number
  const orderNum = 'EB-' + Math.random().toString(36).substring(2, 7).toUpperCase();
  
  // 2. Calculate Totals
  let subtotal = 0;
  items.forEach(item => { subtotal += (item.price * item.quantity); });
  
  const platformFee = subtotal * 0.05; // 5% fee
  const total = subtotal + platformFee;

  const { data, error } = await sb
    .from('orders')
    .insert({
      order_number: orderNum,
      buyer_id: buyerId,
      seller_id: sellerId,
      items: items,
      subtotal_usd: subtotal,
      platform_fee_usd: platformFee,
      total_usd: total,
      status: 'pending',
      shipping_address_id: shippingId,
      shipping_method: method,
      payment_status: 'pending'
    })
    .select()
    .single();
  
  if (!error) {
    await sb.from('notifications').insert({
      user_id: sellerId,
      type: 'order_update',
      title: 'New Order: ' + orderNum,
      body: 'A buyer has started a new order. Please check your dashboard.',
      icon: '📦'
    });
  }
  
  return { data, error };
}

async function submitRFQ(buyerId, rfqData) {
  const rfqNum = 'RQ-' + new Date().getFullYear() + '-' + Math.random().toString(36).substring(2, 6).toUpperCase();
  const { data, error } = await sb
    .from('rfqs')
    .insert({
      ...rfqData,
      rfq_number: rfqNum,
      buyer_id: buyerId,
      status: 'open'
    })
    .select()
    .single();
  return { data, error };
}

async function respondToRFQ(rfqId, sellerId, quoteData) {
  const { data, error } = await sb
    .from('rfq_quotes')
    .insert({
      ...quoteData,
      rfq_id: rfqId,
      seller_id: sellerId,
      status: 'pending'
    })
    .select()
    .single();
  
  if (!error) {
    const { data: rfq } = await sb.from('rfqs').select('buyer_id, rfq_number').eq('id', rfqId).single();
    if (rfq) {
      await sb.from('notifications').insert({
        user_id: rfq.buyer_id,
        type: 'rfq_quote',
        title: 'New Quote for ' + rfq.rfq_number,
        body: 'A seller has responded to your RFQ. Review the quote now.',
        icon: '💬'
      });
    }
  }
  return { data, error };
}

// ─── REALTIME SUBSCRIPTIONS ──────────────────────────────────

function subscribeToOrders(userId, role, callback) {
  const filter = role === 'buyer' ? `buyer_id=eq.${userId}` : `seller_id=eq.${userId}`;
  return sb
    .channel('orders_' + userId)
    .on('postgres_changes', {
      event: '*',
      schema: 'public',
      table: 'orders',
      filter
    }, callback)
    .subscribe();
}

function subscribeToNotifications(userId, callback) {
  return sb
    .channel('notifs_' + userId)
    .on('postgres_changes', {
      event: 'INSERT',
      schema: 'public',
      table: 'notifications',
      filter: `user_id=eq.${userId}`
    }, callback)
    .subscribe();
}

// ─── STORAGE HELPERS ─────────────────────────────────────────

async function uploadProductImage(file, sellerId) {
  const ext = file.name.split('.').pop();
  const path = `${sellerId}/${Date.now()}.${ext}`;
  const { data, error } = await sb.storage.from('product-images').upload(path, file);
  if (error) throw error;
  const { data: { publicUrl } } = sb.storage.from('product-images').getPublicUrl(path);
  return publicUrl;
}

async function uploadSellerDocument(file, sellerId, docType) {
  const ext = file.name.split('.').pop();
  const path = `${sellerId}/${docType}_${Date.now()}.${ext}`;
  const { data, error } = await sb.storage.from('seller-documents').upload(path, file);
  if (error) throw error;
  return path;
}

async function uploadAvatar(file, userId) {
  const ext = file.name.split('.').pop();
  const path = `${userId}/avatar.${ext}`;
  const { data, error } = await sb.storage.from('avatars').upload(path, file, { upsert: true });
  if (error) throw error;
  const { data: { publicUrl } } = sb.storage.from('avatars').getPublicUrl(path);
  return publicUrl;
}

// ─── UTILITY ─────────────────────────────────────────────────

function formatUSD(amount) {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(amount);
}

function timeAgo(dateStr) {
  const diff = (Date.now() - new Date(dateStr)) / 1000;
  if (diff < 60) return 'Just now';
  if (diff < 3600) return Math.floor(diff / 60) + 'm ago';
  if (diff < 86400) return Math.floor(diff / 3600) + 'h ago';
  return Math.floor(diff / 86400) + 'd ago';
}

function showToast(msg, type = 'ok') {
  const old = document.querySelectorAll('.sb-toast');
  old.forEach(t => t.remove());
  const t = document.createElement('div');
  t.className = 'sb-toast';
  const c = {
    ok:     { bg:'#ecfdf5', border:'#a7f3d0', color:'#065f46' },
    error:  { bg:'#fef2f2', border:'#fecaca', color:'#991b1b' },
    warn:   { bg:'#fffbeb', border:'#fcd34d', color:'#92400e' }
  }[type] || { bg:'#ecfdf5', border:'#a7f3d0', color:'#065f46' };
  t.style.cssText = `position:fixed;bottom:24px;right:24px;padding:14px 20px;border-radius:14px;font-size:13px;font-weight:700;z-index:9999;box-shadow:0 8px 30px rgba(0,0,0,.12);max-width:380px;font-family:Sora,sans-serif;border:1px solid ${c.border};background:${c.bg};color:${c.color};animation:slideUp 0.3s ease-out`;
  t.textContent = (type === 'ok' ? '✓ ' : type === 'warn' ? '⚠ ' : '✕ ') + msg;
  document.body.appendChild(t);
  setTimeout(() => { t.style.transition = 'opacity .3s'; t.style.opacity = '0'; setTimeout(() => t.remove(), 300); }, 3500);
}

// ─── CATEGORIES ──────────────────────────────────────────────

async function getCategories() {
  const { data, error } = await sb
    .from('categories')
    .select('*')
    .eq('is_active', true)
    .order('sort_order', { ascending: true });
  return { data, error };
}

// ─── SUPER ADMIN CHECK ──────────────────────────────────────

async function isSuperAdmin(userId) {
  const { data } = await sb
    .from('profiles')
    .select('role, email')
    .eq('id', userId)
    .single();
  // Super admin = role 'admin' with specific flag or email
  return data && data.role === 'admin';
}

async function requireAdmin(redirectTo) {
  const session = await getSession();
  if (!session) { window.location.href = redirectTo || '../pages/login-admin.html'; return null; }
  const { data: profile } = await getProfile(session.user.id);
  if (!profile || profile.role !== 'admin') {
    window.location.href = redirectTo || '../index.html';
    return null;
  }
  return { session, profile };
}

// ─── NOTIFICATION COUNT ─────────────────────────────────────

async function getUnreadNotificationCount(userId) {
  const { data, error } = await sb
    .from('notifications')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', userId)
    .eq('is_read', false);
  return { count: data?.length || 0, error };
}

// ─── ADMIN: SELLER REJECTION ────────────────────────────────

async function adminRejectSeller(sellerProfileId, adminId, reason) {
  const { data, error } = await sb
    .from('seller_profiles')
    .update({ status: 'rejected', rejection_reason: reason })
    .eq('id', sellerProfileId)
    .select()
    .single();
  await sb.from('audit_log').insert({
    user_id: adminId,
    action: 'seller_rejected',
    entity_type: 'seller_profiles',
    entity_id: sellerProfileId,
    new_data: { reason }
  });
  return { data, error };
}

// ─── ADMIN: PENDING DOCUMENTS ───────────────────────────────

async function adminGetPendingDocuments() {
  const { data, error } = await sb
    .from('seller_documents')
    .select('*, seller_profiles(company_name, country, user_id, profiles(email, first_name, last_name))')
    .eq('status', 'pending')
    .order('uploaded_at', { ascending: true });
  return { data, error };
}

async function adminApproveDocument(docId, adminId) {
  const { data, error } = await sb
    .from('seller_documents')
    .update({ status: 'approved', reviewed_by: adminId, reviewed_at: new Date().toISOString() })
    .eq('id', docId)
    .select()
    .single();
  await sb.from('audit_log').insert({
    user_id: adminId, action: 'document_approved', entity_type: 'seller_documents', entity_id: docId
  });
  return { data, error };
}

async function adminRejectDocument(docId, adminId, reason) {
  const { data, error } = await sb
    .from('seller_documents')
    .update({ status: 'rejected', reviewed_by: adminId, reviewed_at: new Date().toISOString(), rejection_reason: reason })
    .eq('id', docId)
    .select()
    .single();
  await sb.from('audit_log').insert({
    user_id: adminId, action: 'document_rejected', entity_type: 'seller_documents', entity_id: docId, new_data: { reason }
  });
  return { data, error };
}

// ─── ADMIN: DISPUTES ────────────────────────────────────────

async function adminGetDisputes(status) {
  let query = sb
    .from('disputes')
    .select('*, orders(order_number, total_usd), profiles!buyer_id(first_name, last_name, email), seller_profiles(company_name)')
    .order('created_at', { ascending: false });
  if (status) query = query.eq('status', status);
  const { data, error } = await query;
  return { data, error };
}

async function adminResolveDispute(disputeId, adminId, resolution, refundAmount) {
  const { data, error } = await sb
    .from('disputes')
    .update({
      status: 'resolved', resolution, refund_amount: refundAmount,
      resolved_by: adminId, resolved_at: new Date().toISOString()
    })
    .eq('id', disputeId)
    .select()
    .single();
  await sb.from('audit_log').insert({
    user_id: adminId, action: 'dispute_resolved', entity_type: 'disputes',
    entity_id: disputeId, new_data: { resolution, refundAmount }
  });
  return { data, error };
}

// ─── PLATFORM SETTINGS ──────────────────────────────────────

async function getPlatformSettings() {
  const { data, error } = await sb
    .from('platform_settings')
    .select('*');
  // Convert array to key-value object
  const settings = {};
  if (data) data.forEach(row => { settings[row.key] = row.value; });
  return { settings, error };
}

async function updatePlatformSetting(key, value, adminId) {
  const { data, error } = await sb
    .from('platform_settings')
    .upsert({ key, value, updated_at: new Date().toISOString() })
    .select()
    .single();
  if (adminId) {
    await sb.from('audit_log').insert({
      user_id: adminId, action: 'setting_updated', entity_type: 'platform_settings',
      entity_id: key, new_data: { value }
    });
  }
  return { data, error };
}

// ─── SELLER: EARNINGS ───────────────────────────────────────

async function getSellerEarnings(sellerId) {
  const { data, error } = await sb
    .from('orders')
    .select('total_usd, platform_fee_usd, status, created_at')
    .eq('seller_id', sellerId)
    .in('status', ['delivered', 'completed']);
  if (!data) return { total: 0, fees: 0, net: 0, orders: 0, error };
  const total = data.reduce((s, o) => s + (o.total_usd || 0), 0);
  const fees = data.reduce((s, o) => s + (o.platform_fee_usd || 0), 0);
  return { total, fees, net: total - fees, orders: data.length, error: null };
}
