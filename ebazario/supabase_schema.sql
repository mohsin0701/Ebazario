-- ============================================================
-- EBAZARIO TRADING — SUPABASE COMPLETE DATABASE SCHEMA
-- ============================================================
-- Run this entire file in your Supabase SQL Editor
-- Project: https://supabase.com → New Project → SQL Editor

-- ============================================================
-- EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- for full-text search

-- ============================================================
-- ENUMS
-- ============================================================
CREATE TYPE user_role AS ENUM ('customer', 'seller', 'admin');
CREATE TYPE seller_plan AS ENUM ('free', 'silver', 'gold', 'platinum');
CREATE TYPE seller_status AS ENUM ('pending', 'active', 'suspended', 'banned');
CREATE TYPE product_status AS ENUM ('draft', 'pending_review', 'approved', 'rejected', 'archived');
CREATE TYPE order_status AS ENUM ('pending', 'confirmed', 'processing', 'shipped', 'in_transit', 'delivered', 'disputed', 'cancelled', 'refunded');
CREATE TYPE payment_status AS ENUM ('pending', 'held_escrow', 'released', 'refunded', 'failed');
CREATE TYPE shipping_method AS ENUM ('air', 'sea_fcl', 'sea_lcl', 'door_to_door', 'courier');
CREATE TYPE document_status AS ENUM ('pending', 'approved', 'rejected', 'expired');
CREATE TYPE document_type AS ENUM ('business_license', 'ce_certificate', 'fcc_certificate', 'fda_approval', 'iso_9001', 'iso_13485', 'rohs', 'reach', 'haccp', 'oeko_tex', 'export_license', 'factory_audit', 'other');
CREATE TYPE rfq_status AS ENUM ('open', 'closed', 'awarded', 'expired');
CREATE TYPE dispute_status AS ENUM ('open', 'under_review', 'resolved', 'closed');
CREATE TYPE dispute_outcome AS ENUM ('buyer_won', 'seller_won', 'partial_refund', 'split', 'reshipment');
CREATE TYPE payout_status AS ENUM ('pending', 'processing', 'paid', 'failed');
CREATE TYPE notification_type AS ENUM ('order_update', 'rfq_quote', 'dispute', 'shipment', 'review_request', 'payment', 'system', 'marketing');
CREATE TYPE address_type AS ENUM ('commercial', 'warehouse', 'residential');
CREATE TYPE rejection_reason AS ENUM ('missing_certification', 'poor_images', 'incomplete_description', 'pricing_issue', 'duplicate', 'prohibited', 'fraudulent_docs', 'incomplete_application', 'other');

-- ============================================================
-- 1. PROFILES (extends Supabase auth.users)
-- ============================================================
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role user_role NOT NULL DEFAULT 'customer',
  first_name TEXT,
  last_name TEXT,
  email TEXT UNIQUE NOT NULL,
  phone TEXT,
  avatar_url TEXT,
  country TEXT,
  city TEXT,
  state TEXT,
  preferred_language TEXT DEFAULT 'en',
  preferred_currency TEXT DEFAULT 'USD',
  date_of_birth DATE,
  is_verified BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  two_factor_enabled BOOLEAN DEFAULT FALSE,
  last_login_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 2. CUSTOMER PROFILES
-- ============================================================
CREATE TABLE customer_profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID UNIQUE NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  company_name TEXT,
  industry TEXT,
  company_size TEXT,
  annual_budget_usd TEXT,
  website TEXT,
  business_reg_number TEXT,
  position TEXT,
  trade_assurance_active BOOLEAN DEFAULT TRUE,
  total_orders INT DEFAULT 0,
  total_spent_usd DECIMAL(14,2) DEFAULT 0,
  loyalty_tier TEXT DEFAULT 'standard', -- standard, silver, gold
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 3. SELLER PROFILES
-- ============================================================
CREATE TABLE seller_profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID UNIQUE NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  company_name TEXT NOT NULL,
  company_description TEXT,
  industry TEXT,
  country TEXT NOT NULL,
  city TEXT,
  established_year INT,
  employee_count TEXT,
  annual_revenue TEXT,
  website TEXT,
  business_reg_number TEXT,
  plan seller_plan NOT NULL DEFAULT 'free',
  plan_expires_at TIMESTAMPTZ,
  status seller_status NOT NULL DEFAULT 'pending',
  verification_score INT DEFAULT 0, -- 0-100
  total_products INT DEFAULT 0,
  total_orders INT DEFAULT 0,
  total_revenue_usd DECIMAL(14,2) DEFAULT 0,
  avg_rating DECIMAL(3,2) DEFAULT 0,
  response_rate DECIMAL(5,2) DEFAULT 0,
  on_time_delivery_rate DECIMAL(5,2) DEFAULT 0,
  dispute_rate DECIMAL(5,2) DEFAULT 0,
  rejection_reason rejection_reason,
  rejection_notes TEXT,
  approved_at TIMESTAMPTZ,
  approved_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 4. ADDRESSES
-- ============================================================
CREATE TABLE addresses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  label TEXT,
  type address_type DEFAULT 'commercial',
  first_name TEXT,
  last_name TEXT,
  company TEXT,
  street_line1 TEXT NOT NULL,
  street_line2 TEXT,
  city TEXT NOT NULL,
  state TEXT,
  postal_code TEXT,
  country TEXT NOT NULL,
  phone TEXT,
  is_default BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 5. PAYMENT METHODS
-- ============================================================
CREATE TABLE payment_methods (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL, -- 'card', 'paypal', 'bank_transfer'
  label TEXT,
  last_four TEXT,
  expiry_month INT,
  expiry_year INT,
  card_brand TEXT,
  paypal_email TEXT,
  bank_name TEXT,
  bank_account_last_four TEXT,
  bank_routing TEXT,
  stripe_payment_method_id TEXT, -- Stripe token (never store raw card)
  is_default BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 6. CATEGORIES
-- ============================================================
CREATE TABLE categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  slug TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  icon TEXT,
  description TEXT,
  parent_id UUID REFERENCES categories(id),
  required_certifications TEXT[], -- array of cert names
  platform_margin_pct DECIMAL(5,2) NOT NULL DEFAULT 10.00,
  is_active BOOLEAN DEFAULT TRUE,
  sort_order INT DEFAULT 0,
  product_count INT DEFAULT 0,
  seller_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed categories
INSERT INTO categories (slug, name, icon, platform_margin_pct, required_certifications, sort_order) VALUES
  ('electronics',    'Electronics & Electrical', '🔌', 12.00, ARRAY['CE','FCC','RoHS'], 1),
  ('machinery',      'Machinery & Equipment',    '⚙️', 10.00, ARRAY['CE','ISO 9001'],   2),
  ('apparel',        'Apparel & Textiles',        '👗', 18.00, ARRAY['OEKO-TEX'],       3),
  ('food-agri',      'Food & Agriculture',        '🌿',  8.00, ARRAY['HACCP'],          4),
  ('chemicals',      'Chemicals & Plastics',      '⚗️',  9.00, ARRAY['REACH','SDS'],    5),
  ('construction',   'Construction & Real Estate','🏗️', 10.00, ARRAY['CE'],             6),
  ('auto-parts',     'Auto Parts & Accessories',  '🚗', 14.00, ARRAY['ISO/TS 16949'],   7),
  ('healthcare',     'Health & Medical',          '🏥', 15.00, ARRAY['FDA','CE'],       8),
  ('furniture',      'Furniture & Home',          '🪑', 16.00, ARRAY[]::TEXT[],         9),
  ('tools',          'Tools & Hardware',          '🔧', 11.00, ARRAY[]::TEXT[],        10);

-- ============================================================
-- 7. PRODUCTS
-- ============================================================
CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  seller_id UUID NOT NULL REFERENCES seller_profiles(id) ON DELETE CASCADE,
  category_id UUID NOT NULL REFERENCES categories(id),
  title TEXT NOT NULL,
  slug TEXT UNIQUE,
  description TEXT,
  specifications JSONB DEFAULT '{}', -- {key: value}
  images TEXT[], -- array of storage URLs
  video_url TEXT,
  base_price_usd DECIMAL(12,2) NOT NULL,
  buyer_price_usd DECIMAL(12,2), -- after margin markup
  min_order_qty INT NOT NULL DEFAULT 1,
  unit TEXT DEFAULT 'unit', -- piece, kg, ton, cbm
  supply_capacity TEXT,
  lead_time_days_min INT,
  lead_time_days_max INT,
  country_of_origin TEXT,
  certifications TEXT[],
  keywords TEXT[],
  status product_status NOT NULL DEFAULT 'pending_review',
  is_featured BOOLEAN DEFAULT FALSE,
  view_count INT DEFAULT 0,
  order_count INT DEFAULT 0,
  avg_rating DECIMAL(3,2) DEFAULT 0,
  review_count INT DEFAULT 0,
  rejection_reason rejection_reason,
  rejection_notes TEXT,
  reviewed_by UUID REFERENCES profiles(id),
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Full-text search index
CREATE INDEX products_fts_idx ON products USING GIN(to_tsvector('english', title || ' ' || COALESCE(description,'')));
CREATE INDEX products_category_idx ON products(category_id);
CREATE INDEX products_seller_idx ON products(seller_id);
CREATE INDEX products_status_idx ON products(status);

-- ============================================================
-- 8. PRODUCT PRICE TIERS
-- ============================================================
CREATE TABLE product_price_tiers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  min_qty INT NOT NULL,
  max_qty INT,
  price_usd DECIMAL(12,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 9. SELLER DOCUMENTS
-- ============================================================
CREATE TABLE seller_documents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  seller_id UUID NOT NULL REFERENCES seller_profiles(id) ON DELETE CASCADE,
  type document_type NOT NULL,
  name TEXT NOT NULL,
  file_url TEXT NOT NULL, -- Supabase Storage URL
  file_size_bytes INT,
  status document_status NOT NULL DEFAULT 'pending',
  expiry_date DATE,
  reviewer_notes TEXT,
  rejection_reason TEXT,
  reviewed_by UUID REFERENCES profiles(id),
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 10. ORDERS
-- ============================================================
CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_number TEXT UNIQUE NOT NULL, -- EB-XXXXXXXX
  buyer_id UUID NOT NULL REFERENCES profiles(id),
  seller_id UUID NOT NULL REFERENCES seller_profiles(id),
  status order_status NOT NULL DEFAULT 'pending',
  -- Line items snapshot
  items JSONB NOT NULL DEFAULT '[]', -- [{product_id, title, qty, unit_price, total}]
  -- Amounts
  subtotal_usd DECIMAL(14,2) NOT NULL,
  platform_fee_usd DECIMAL(14,2) NOT NULL, -- 5% commission
  shipping_cost_usd DECIMAL(14,2) DEFAULT 0,
  total_usd DECIMAL(14,2) NOT NULL,
  -- Shipping
  shipping_method shipping_method,
  shipping_address_id UUID REFERENCES addresses(id),
  tracking_number TEXT,
  carrier TEXT,
  vessel_name TEXT,
  bill_of_lading TEXT,
  shipped_at TIMESTAMPTZ,
  estimated_delivery_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  -- Payment
  payment_status payment_status DEFAULT 'pending',
  payment_method_id UUID REFERENCES payment_methods(id),
  escrow_released_at TIMESTAMPTZ,
  -- Notes
  buyer_notes TEXT,
  admin_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX orders_buyer_idx ON orders(buyer_id);
CREATE INDEX orders_seller_idx ON orders(seller_id);
CREATE INDEX orders_status_idx ON orders(status);
CREATE INDEX orders_number_idx ON orders(order_number);

-- ============================================================
-- 11. REVIEWS
-- ============================================================
CREATE TABLE reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID NOT NULL REFERENCES orders(id),
  product_id UUID NOT NULL REFERENCES products(id),
  buyer_id UUID NOT NULL REFERENCES profiles(id),
  seller_id UUID NOT NULL REFERENCES seller_profiles(id),
  overall_rating INT NOT NULL CHECK (overall_rating BETWEEN 1 AND 5),
  quality_rating INT CHECK (quality_rating BETWEEN 1 AND 5),
  shipping_rating INT CHECK (shipping_rating BETWEEN 1 AND 5),
  communication_rating INT CHECK (communication_rating BETWEEN 1 AND 5),
  as_described BOOLEAN,
  title TEXT,
  body TEXT,
  photos TEXT[],
  seller_reply TEXT,
  seller_replied_at TIMESTAMPTZ,
  is_verified_purchase BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(order_id, product_id)
);

CREATE INDEX reviews_product_idx ON reviews(product_id);
CREATE INDEX reviews_seller_idx ON reviews(seller_id);

-- ============================================================
-- 12. RFQs (Request for Quotation)
-- ============================================================
CREATE TABLE rfqs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  rfq_number TEXT UNIQUE NOT NULL, -- RQ-YYYY-XXXX
  buyer_id UUID NOT NULL REFERENCES profiles(id),
  category_id UUID REFERENCES categories(id),
  title TEXT NOT NULL,
  description TEXT,
  quantity INT,
  unit TEXT,
  budget_min_usd DECIMAL(12,2),
  budget_max_usd DECIMAL(12,2),
  required_certifications TEXT[],
  timeline_days INT,
  delivery_address_id UUID REFERENCES addresses(id),
  status rfq_status DEFAULT 'open',
  expires_at TIMESTAMPTZ,
  awarded_to UUID REFERENCES seller_profiles(id),
  quotes_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 13. RFQ QUOTES
-- ============================================================
CREATE TABLE rfq_quotes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  rfq_id UUID NOT NULL REFERENCES rfqs(id) ON DELETE CASCADE,
  seller_id UUID NOT NULL REFERENCES seller_profiles(id),
  unit_price_usd DECIMAL(12,2) NOT NULL,
  total_price_usd DECIMAL(12,2),
  lead_time_days INT,
  warranty_months INT,
  notes TEXT,
  is_trade_assured BOOLEAN DEFAULT TRUE,
  status TEXT DEFAULT 'pending', -- pending, accepted, rejected, countered
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(rfq_id, seller_id)
);

-- ============================================================
-- 14. DISPUTES
-- ============================================================
CREATE TABLE disputes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID NOT NULL REFERENCES orders(id),
  buyer_id UUID NOT NULL REFERENCES profiles(id),
  seller_id UUID NOT NULL REFERENCES seller_profiles(id),
  issue_type TEXT NOT NULL,
  description TEXT NOT NULL,
  requested_resolution TEXT,
  evidence_urls TEXT[],
  status dispute_status DEFAULT 'open',
  outcome dispute_outcome,
  refund_amount_usd DECIMAL(12,2),
  admin_decision TEXT,
  resolved_by UUID REFERENCES profiles(id),
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 15. WISHLIST
-- ============================================================
CREATE TABLE wishlists (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, product_id)
);

-- ============================================================
-- 16. SELLER PAYOUTS
-- ============================================================
CREATE TABLE seller_payouts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  seller_id UUID NOT NULL REFERENCES seller_profiles(id),
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  order_count INT DEFAULT 0,
  gross_revenue_usd DECIMAL(14,2) NOT NULL,
  platform_fee_usd DECIMAL(14,2) NOT NULL,
  net_payout_usd DECIMAL(14,2) NOT NULL,
  status payout_status DEFAULT 'pending',
  paid_at TIMESTAMPTZ,
  payment_reference TEXT,
  admin_notes TEXT,
  processed_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 17. SHIPPING RATES
-- ============================================================
CREATE TABLE shipping_rates (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  destination_country TEXT NOT NULL,
  destination_label TEXT NOT NULL,
  flag_emoji TEXT,
  air_per_kg DECIMAL(8,2),
  sea_fcl_flat DECIMAL(10,2),
  sea_lcl_per_cbm DECIMAL(8,2),
  door_to_door_per_kg DECIMAL(8,2),
  air_transit_days_min INT,
  air_transit_days_max INT,
  sea_transit_days_min INT,
  sea_transit_days_max INT,
  is_active BOOLEAN DEFAULT TRUE,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(destination_country)
);

-- Seed shipping rates
INSERT INTO shipping_rates (destination_country, destination_label, flag_emoji, air_per_kg, sea_fcl_flat, sea_lcl_per_cbm, door_to_door_per_kg, air_transit_days_min, air_transit_days_max, sea_transit_days_min, sea_transit_days_max) VALUES
  ('AE', 'UAE / Dubai',     '🇦🇪', 4.50, 1200, 95,  6.80, 3, 5,  18, 25),
  ('SA', 'Saudi Arabia',    '🇸🇦', 4.80, 1350, 105, 7.20, 3, 6,  20, 28),
  ('US', 'United States',   '🇺🇸', 5.20, 1800, 120, 8.50, 5, 7,  25, 35),
  ('GB', 'United Kingdom',  '🇬🇧', 5.60, 1600, 115, 8.00, 4, 6,  22, 30),
  ('DE', 'Germany',         '🇩🇪', 5.40, 1550, 112, 7.90, 4, 6,  22, 30),
  ('AU', 'Australia',       '🇦🇺', 6.20, 2100, 140, 9.80, 5, 8,  28, 35),
  ('IN', 'India',           '🇮🇳', 3.80, 900,  75,  5.20, 2, 4,  12, 18),
  ('NG', 'Nigeria',         '🇳🇬', 7.50, 2400, 165, 11.20, 5, 8, 30, 40);

-- ============================================================
-- 18. PLATFORM SETTINGS
-- ============================================================
CREATE TABLE platform_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  description TEXT,
  updated_by UUID REFERENCES profiles(id),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO platform_settings (key, value, description) VALUES
  ('commission_pct',        '5',     'Platform commission percentage on all transactions'),
  ('payment_processing_pct','2.5',   'Payment processor fee percentage'),
  ('min_order_usd',         '100',   'Minimum order value in USD'),
  ('max_trade_assurance',   '500000','Maximum Trade Assurance coverage per order in USD'),
  ('plan_free_max_products','10',    'Max products for free plan sellers'),
  ('plan_silver_price',     '49',    'Silver plan monthly price USD'),
  ('plan_gold_price',       '149',   'Gold plan monthly price USD'),
  ('plan_platinum_price',   '349',   'Platinum plan monthly price USD'),
  ('trade_assurance_active','true',  'Trade Assurance escrow feature enabled'),
  ('new_seller_reg_open',   'true',  'New seller registrations allowed'),
  ('buyer_reg_open',        'true',  'New buyer registrations allowed'),
  ('maintenance_mode',      'false', 'Platform in maintenance mode'),
  ('announcement_text',     'Welcome to Ebazario Trading — Global B2B Marketplace', 'Homepage announcement'),
  ('announcement_visible',  'true',  'Show announcement banner');

-- ============================================================
-- 19. NOTIFICATIONS
-- ============================================================
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type notification_type NOT NULL,
  title TEXT NOT NULL,
  body TEXT,
  action_url TEXT,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX notifs_user_idx ON notifications(user_id, is_read, created_at DESC);

-- ============================================================
-- 20. AUDIT LOG
-- ============================================================
CREATE TABLE audit_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id),
  user_email TEXT,
  role user_role,
  action TEXT NOT NULL,
  entity_type TEXT, -- 'product', 'order', 'seller', etc
  entity_id UUID,
  old_data JSONB,
  new_data JSONB,
  ip_address TEXT,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX audit_log_user_idx ON audit_log(user_id, created_at DESC);
CREATE INDEX audit_log_entity_idx ON audit_log(entity_type, entity_id);

-- ============================================================
-- 21. SUBSCRIPTIONS
-- ============================================================
CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  seller_id UUID NOT NULL REFERENCES seller_profiles(id),
  plan seller_plan NOT NULL,
  price_usd DECIMAL(8,2) NOT NULL,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  stripe_subscription_id TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE seller_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE rfqs ENABLE ROW LEVEL SECURITY;
ALTER TABLE rfq_quotes ENABLE ROW LEVEL SECURITY;
ALTER TABLE disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE wishlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE seller_payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE seller_documents ENABLE ROW LEVEL SECURITY;

-- PROFILES: users can read/update own profile; admins see all
CREATE POLICY "Users read own profile" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Admin read all profiles" ON profiles FOR SELECT USING (
  EXISTS (SELECT 1 FROM auth.users WHERE id = auth.uid() AND (raw_user_meta_data->>'role') = 'admin')
);
CREATE POLICY "Insert on signup" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- CUSTOMER PROFILES
CREATE POLICY "Customers manage own" ON customer_profiles FOR ALL USING (user_id = auth.uid());
CREATE POLICY "Admin access customer profiles" ON customer_profiles FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- SELLER PROFILES
CREATE POLICY "Sellers manage own" ON seller_profiles FOR ALL USING (user_id = auth.uid());
CREATE POLICY "Public read approved sellers" ON seller_profiles FOR SELECT USING (status = 'active');
CREATE POLICY "Admin full access sellers" ON seller_profiles FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- PRODUCTS: public can read approved; sellers manage own; admins manage all
CREATE POLICY "Public read approved products" ON products FOR SELECT USING (status = 'approved');
CREATE POLICY "Sellers manage own products" ON products FOR ALL USING (
  seller_id IN (SELECT id FROM seller_profiles WHERE user_id = auth.uid())
);
CREATE POLICY "Admin manage all products" ON products FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- ORDERS: buyers and sellers see their own orders; admins see all
CREATE POLICY "Buyers see own orders" ON orders FOR SELECT USING (buyer_id = auth.uid());
CREATE POLICY "Sellers see own orders" ON orders FOR SELECT USING (
  seller_id IN (SELECT id FROM seller_profiles WHERE user_id = auth.uid())
);
CREATE POLICY "Admin full access orders" ON orders FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- ADDRESSES: users manage their own
CREATE POLICY "Users manage own addresses" ON addresses FOR ALL USING (user_id = auth.uid());

-- PAYMENT METHODS: users manage their own
CREATE POLICY "Users manage own payments" ON payment_methods FOR ALL USING (user_id = auth.uid());

-- WISHLISTS
CREATE POLICY "Users manage own wishlist" ON wishlists FOR ALL USING (user_id = auth.uid());

-- NOTIFICATIONS
CREATE POLICY "Users read own notifications" ON notifications FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users update own notifications" ON notifications FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "Anyone can insert notifications" ON notifications FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- RFQs
CREATE POLICY "Buyers manage own rfqs" ON rfqs FOR ALL USING (buyer_id = auth.uid());
CREATE POLICY "Sellers read open rfqs" ON rfqs FOR SELECT USING (status = 'open');
CREATE POLICY "Admin full rfq access" ON rfqs FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- REVIEWS
CREATE POLICY "Public read reviews" ON reviews FOR SELECT USING (TRUE);
CREATE POLICY "Buyers write own reviews" ON reviews FOR INSERT WITH CHECK (buyer_id = auth.uid());
CREATE POLICY "Buyers update own reviews" ON reviews FOR UPDATE USING (buyer_id = auth.uid());

-- DISPUTES
CREATE POLICY "Buyers manage own disputes" ON disputes FOR ALL USING (buyer_id = auth.uid());
CREATE POLICY "Sellers see own disputes" ON disputes FOR SELECT USING (
  seller_id IN (SELECT id FROM seller_profiles WHERE user_id = auth.uid())
);
CREATE POLICY "Admin full dispute access" ON disputes FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- SELLER DOCUMENTS
CREATE POLICY "Sellers manage own docs" ON seller_documents FOR ALL USING (
  seller_id IN (SELECT id FROM seller_profiles WHERE user_id = auth.uid())
);
CREATE POLICY "Admin full doc access" ON seller_documents FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- SELLER PAYOUTS
CREATE POLICY "Sellers see own payouts" ON seller_payouts FOR SELECT USING (
  seller_id IN (SELECT id FROM seller_profiles WHERE user_id = auth.uid())
);
CREATE POLICY "Admin full payout access" ON seller_payouts FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- ============================================================
-- FUNCTIONS & TRIGGERS
-- ============================================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_profiles_updated BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_seller_profiles_updated BEFORE UPDATE ON seller_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_customer_profiles_updated BEFORE UPDATE ON customer_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_products_updated BEFORE UPDATE ON products FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_orders_updated BEFORE UPDATE ON orders FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_disputes_updated BEFORE UPDATE ON disputes FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Auto-create profile on user signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, email, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'customer')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Generate order number
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TRIGGER AS $$
BEGIN
  NEW.order_number = 'EB-' || TO_CHAR(NOW(), 'YYYY') || LPAD(NEXTVAL('order_seq')::TEXT, 5, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE SEQUENCE order_seq START 10001;
CREATE TRIGGER trg_order_number BEFORE INSERT ON orders FOR EACH ROW EXECUTE FUNCTION generate_order_number();

-- Generate RFQ number
CREATE OR REPLACE FUNCTION generate_rfq_number()
RETURNS TRIGGER AS $$
BEGIN
  NEW.rfq_number = 'RQ-' || TO_CHAR(NOW(), 'YYYY') || '-' || LPAD(NEXTVAL('rfq_seq')::TEXT, 4, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE SEQUENCE rfq_seq START 1001;
CREATE TRIGGER trg_rfq_number BEFORE INSERT ON rfqs FOR EACH ROW EXECUTE FUNCTION generate_rfq_number();

-- Update product avg rating when review added
CREATE OR REPLACE FUNCTION update_product_rating()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE products SET
    avg_rating = (SELECT AVG(overall_rating)::DECIMAL(3,2) FROM reviews WHERE product_id = NEW.product_id),
    review_count = (SELECT COUNT(*) FROM reviews WHERE product_id = NEW.product_id)
  WHERE id = NEW.product_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_product_rating AFTER INSERT OR UPDATE ON reviews FOR EACH ROW EXECUTE FUNCTION update_product_rating();

-- Update seller stats when order status changes
CREATE OR REPLACE FUNCTION update_seller_stats()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'delivered' AND OLD.status != 'delivered' THEN
    UPDATE seller_profiles SET
      total_orders = total_orders + 1,
      total_revenue_usd = total_revenue_usd + NEW.subtotal_usd
    WHERE id = NEW.seller_id;
    UPDATE customer_profiles SET
      total_orders = total_orders + 1,
      total_spent_usd = total_spent_usd + NEW.total_usd
    WHERE user_id = NEW.buyer_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_seller_stats AFTER UPDATE ON orders FOR EACH ROW EXECUTE FUNCTION update_seller_stats();

-- ============================================================
-- STORAGE BUCKETS (run in Supabase Dashboard → Storage)
-- ============================================================
-- These must be created via the Supabase Dashboard UI or API:
--   bucket: product-images  (public: true)
--   bucket: seller-documents (public: false)
--   bucket: avatars          (public: true)

-- ============================================================
-- REALTIME (enable in Supabase Dashboard → Database → Replication)
-- ============================================================
-- Enable realtime for: orders, notifications, disputes

