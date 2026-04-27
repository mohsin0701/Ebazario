-- ============================================================
-- EBAZARIO TRADING — SCHEMA UPDATE v2
-- ============================================================
-- Run this AFTER running supabase_schema.sql (v1)
-- Adds missing tables, indexes, and policies needed for 
-- approval pages and full platform functionality

-- ============================================================
-- 1. ADD MISSING COLUMNS (safe — only if they don't exist)
-- ============================================================

-- Products: add full-text search column
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='products' AND column_name='search_vector') THEN
    ALTER TABLE products ADD COLUMN search_vector TSVECTOR;
  END IF;
END $$;

-- Seller profiles: add rejection timestamp
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='seller_profiles' AND column_name='rejected_at') THEN
    ALTER TABLE seller_profiles ADD COLUMN rejected_at TIMESTAMPTZ;
  END IF;
END $$;

-- ============================================================
-- 2. PRODUCT VIEWS TRACKING
-- ============================================================
CREATE TABLE IF NOT EXISTS product_views (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  viewer_id UUID REFERENCES profiles(id),
  ip_hash TEXT,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS prod_views_prod_idx ON product_views(product_id, created_at DESC);

-- ============================================================
-- 3. SELLER NOTIFICATIONS LOG
-- ============================================================
CREATE TABLE IF NOT EXISTS seller_notification_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  seller_id UUID NOT NULL REFERENCES seller_profiles(id) ON DELETE CASCADE,
  notification_type TEXT NOT NULL, -- 'product_approved','product_rejected','seller_approved','seller_rejected','doc_approved','doc_rejected','payout_processed'
  subject TEXT,
  body TEXT,
  related_entity_type TEXT,
  related_entity_id UUID,
  sent_at TIMESTAMPTZ DEFAULT NOW(),
  read_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS seller_notif_seller_idx ON seller_notification_log(seller_id, sent_at DESC);

-- ============================================================
-- 4. PRODUCT INQUIRY (Contact Seller)
-- ============================================================
CREATE TABLE IF NOT EXISTS product_inquiries (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  buyer_id UUID NOT NULL REFERENCES profiles(id),
  seller_id UUID NOT NULL REFERENCES seller_profiles(id),
  message TEXT NOT NULL,
  quantity INT,
  status TEXT DEFAULT 'open', -- open, replied, closed
  seller_reply TEXT,
  seller_replied_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 5. BLOCKED IPS (Security)
-- ============================================================
CREATE TABLE IF NOT EXISTS blocked_ips (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ip_address TEXT UNIQUE NOT NULL,
  reason TEXT,
  blocked_by UUID REFERENCES profiles(id),
  blocked_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ
);

-- ============================================================
-- 6. PLATFORM REVENUE SNAPSHOTS (for Reports)
-- ============================================================
CREATE TABLE IF NOT EXISTS revenue_snapshots (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  period_date DATE NOT NULL UNIQUE,
  gmv_usd DECIMAL(16,2) DEFAULT 0,
  order_count INT DEFAULT 0,
  commission_usd DECIMAL(14,2) DEFAULT 0,
  subscription_usd DECIMAL(14,2) DEFAULT 0,
  total_revenue_usd DECIMAL(14,2) DEFAULT 0,
  active_sellers INT DEFAULT 0,
  new_sellers INT DEFAULT 0,
  active_buyers INT DEFAULT 0,
  new_buyers INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 7. SELLER DOCUMENT CHECKLIST (per category requirements)
-- ============================================================
CREATE TABLE IF NOT EXISTS category_doc_requirements (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  category_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  document_type document_type NOT NULL,
  is_required BOOLEAN DEFAULT TRUE,
  description TEXT,
  UNIQUE(category_id, document_type)
);

-- Seed required documents per category
INSERT INTO category_doc_requirements (category_id, document_type, is_required, description)
SELECT c.id, 'ce_certificate'::document_type, TRUE, 'Required for EU market access'
FROM categories c WHERE c.slug = 'electronics'
ON CONFLICT DO NOTHING;

INSERT INTO category_doc_requirements (category_id, document_type, is_required, description)
SELECT c.id, 'fcc_certificate'::document_type, TRUE, 'Required for US market access'
FROM categories c WHERE c.slug = 'electronics'
ON CONFLICT DO NOTHING;

INSERT INTO category_doc_requirements (category_id, document_type, is_required, description)
SELECT c.id, 'fda_approval'::document_type, TRUE, 'Mandatory for all medical devices and health products'
FROM categories c WHERE c.slug = 'healthcare'
ON CONFLICT DO NOTHING;

INSERT INTO category_doc_requirements (category_id, document_type, is_required, description)
SELECT c.id, 'reach'::document_type, TRUE, 'EU REACH compliance required for chemicals'
FROM categories c WHERE c.slug = 'chemicals'
ON CONFLICT DO NOTHING;

INSERT INTO category_doc_requirements (category_id, document_type, is_required, description)
SELECT c.id, 'haccp'::document_type, TRUE, 'Food safety certification required'
FROM categories c WHERE c.slug = 'food-agri'
ON CONFLICT DO NOTHING;

-- ============================================================
-- 8. ADMIN QUICK STATS VIEW
-- ============================================================
CREATE OR REPLACE VIEW admin_dashboard_stats AS
SELECT
  (SELECT COUNT(*) FROM products WHERE status = 'pending_review') AS pending_products,
  (SELECT COUNT(*) FROM seller_profiles WHERE status = 'pending') AS pending_sellers,
  (SELECT COUNT(*) FROM seller_documents WHERE status = 'pending') AS pending_documents,
  (SELECT COUNT(*) FROM disputes WHERE status = 'open') AS open_disputes,
  (SELECT COUNT(*) FROM orders WHERE status NOT IN ('delivered','cancelled','refunded')) AS active_orders,
  (SELECT COUNT(*) FROM seller_profiles WHERE status = 'active') AS total_active_sellers,
  (SELECT COUNT(*) FROM profiles WHERE role = 'customer') AS total_customers,
  (SELECT SUM(total_usd) FROM orders WHERE status = 'delivered' AND created_at >= date_trunc('month', NOW())) AS gmv_this_month,
  (SELECT SUM(platform_fee_usd) FROM orders WHERE status = 'delivered' AND created_at >= date_trunc('month', NOW())) AS revenue_this_month;

-- ============================================================
-- 9. SELLER PERFORMANCE VIEW
-- ============================================================
CREATE OR REPLACE VIEW seller_performance AS
SELECT
  sp.id,
  sp.company_name,
  sp.country,
  sp.plan,
  sp.status,
  sp.avg_rating,
  sp.response_rate,
  sp.on_time_delivery_rate,
  COUNT(DISTINCT p.id) AS product_count,
  COUNT(DISTINCT o.id) AS order_count,
  COALESCE(SUM(o.subtotal_usd) FILTER (WHERE o.status = 'delivered'), 0) AS total_revenue,
  COALESCE(SUM(o.subtotal_usd) FILTER (WHERE o.status = 'delivered' AND o.created_at >= date_trunc('month', NOW())), 0) AS revenue_this_month,
  COUNT(DISTINCT d.id) FILTER (WHERE d.status = 'open') AS open_disputes
FROM seller_profiles sp
LEFT JOIN products p ON p.seller_id = sp.id AND p.status = 'approved'
LEFT JOIN orders o ON o.seller_id = sp.id
LEFT JOIN disputes d ON d.seller_id = sp.id
GROUP BY sp.id, sp.company_name, sp.country, sp.plan, sp.status, sp.avg_rating, sp.response_rate, sp.on_time_delivery_rate;

-- ============================================================
-- 10. ENABLE RLS ON NEW TABLES
-- ============================================================
ALTER TABLE product_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_inquiries ENABLE ROW LEVEL SECURITY;
ALTER TABLE seller_notification_log ENABLE ROW LEVEL SECURITY;

-- Product views: admins see all, buyers see own
CREATE POLICY "Admin see all product views" ON product_views FOR SELECT USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
CREATE POLICY "Anyone can insert view" ON product_views FOR INSERT WITH CHECK (TRUE);

-- Product inquiries: buyers and sellers see their own
CREATE POLICY "Buyers see own inquiries" ON product_inquiries FOR ALL USING (buyer_id = auth.uid());
CREATE POLICY "Sellers see own inquiries" ON product_inquiries FOR SELECT USING (
  seller_id IN (SELECT id FROM seller_profiles WHERE user_id = auth.uid())
);
CREATE POLICY "Sellers reply to inquiries" ON product_inquiries FOR UPDATE USING (
  seller_id IN (SELECT id FROM seller_profiles WHERE user_id = auth.uid())
);

-- Seller notification log: sellers see their own
CREATE POLICY "Sellers read own notifications" ON seller_notification_log FOR SELECT USING (
  seller_id IN (SELECT id FROM seller_profiles WHERE user_id = auth.uid())
);

-- ============================================================
-- 11. FUNCTION: Auto-notify seller on product status change
-- ============================================================
CREATE OR REPLACE FUNCTION notify_seller_on_product_review()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status IN ('approved', 'rejected') AND OLD.status = 'pending_review' THEN
    INSERT INTO seller_notification_log (seller_id, notification_type, subject, body, related_entity_type, related_entity_id)
    VALUES (
      NEW.seller_id,
      CASE WHEN NEW.status = 'approved' THEN 'product_approved' ELSE 'product_rejected' END,
      CASE WHEN NEW.status = 'approved' 
        THEN 'Your product "' || LEFT(NEW.title, 60) || '" has been approved!'
        ELSE 'Action required: "' || LEFT(NEW.title, 60) || '" was not approved'
      END,
      CASE WHEN NEW.status = 'approved'
        THEN 'Great news! Your product is now live on the Ebazario marketplace.'
        ELSE COALESCE('Reason: ' || NEW.rejection_notes, 'Please review and resubmit.')
      END,
      'products',
      NEW.id
    );
    -- Also create in-app notification for seller
    INSERT INTO notifications (user_id, type, title, body, action_url)
    SELECT 
      p.user_id,
      'system'::notification_type,
      CASE WHEN NEW.status = 'approved' THEN '✓ Product Approved' ELSE '⚠ Product Needs Attention' END,
      CASE WHEN NEW.status = 'approved' 
        THEN LEFT(NEW.title, 80) || ' is now live!'
        ELSE LEFT(NEW.title, 80) || ' — ' || COALESCE(NEW.rejection_notes, 'See details')
      END,
      '/pages/seller-dashboard.html'
    FROM seller_profiles p WHERE p.id = NEW.seller_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_product_review_notify ON products;
CREATE TRIGGER trg_product_review_notify
  AFTER UPDATE OF status ON products
  FOR EACH ROW EXECUTE FUNCTION notify_seller_on_product_review();

-- ============================================================
-- 12. FUNCTION: Auto-notify seller on seller status change
-- ============================================================
CREATE OR REPLACE FUNCTION notify_seller_on_approval()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status IN ('active', 'rejected') AND OLD.status = 'pending' THEN
    INSERT INTO notifications (user_id, type, title, body, action_url)
    VALUES (
      NEW.user_id,
      'system'::notification_type,
      CASE WHEN NEW.status = 'active' THEN '🎉 Seller Account Approved!' ELSE '⚠ Seller Application Update' END,
      CASE WHEN NEW.status = 'active'
        THEN 'Congratulations! Your Ebazario seller account is now active. Start listing products!'
        ELSE COALESCE('Reason: ' || NEW.rejection_notes, 'Your application needs attention. Please contact support.')
      END,
      '/pages/seller-dashboard.html'
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_seller_approval_notify ON seller_profiles;
CREATE TRIGGER trg_seller_approval_notify
  AFTER UPDATE OF status ON seller_profiles
  FOR EACH ROW EXECUTE FUNCTION notify_seller_on_approval();

-- ============================================================
-- 13. FUNCTION: Update product search vector
-- ============================================================
CREATE OR REPLACE FUNCTION update_product_search_vector()
RETURNS TRIGGER AS $$
BEGIN
  NEW.search_vector = to_tsvector('english', 
    COALESCE(NEW.title, '') || ' ' || 
    COALESCE(NEW.description, '') || ' ' ||
    COALESCE(array_to_string(NEW.keywords, ' '), '') || ' ' ||
    COALESCE(array_to_string(NEW.certifications, ' '), '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_product_search_vector ON products;
CREATE TRIGGER trg_product_search_vector
  BEFORE INSERT OR UPDATE OF title, description, keywords, certifications ON products
  FOR EACH ROW EXECUTE FUNCTION update_product_search_vector();

-- Update existing products
UPDATE products SET search_vector = to_tsvector('english', 
  COALESCE(title, '') || ' ' || COALESCE(description, '')
);

CREATE INDEX IF NOT EXISTS products_search_vector_idx ON products USING GIN(search_vector);

-- ============================================================
-- SUCCESS MESSAGE
-- ============================================================
DO $$ BEGIN
  RAISE NOTICE '✅ Ebazario Schema v2 applied successfully! % tables/views added.', 8;
END $$;
