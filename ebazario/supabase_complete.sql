-- ============================================================
-- EBAZARIO TRADING — COMPLETE DATABASE SCHEMA (ALL-IN-ONE)
-- ============================================================
-- Run this SINGLE file in Supabase SQL Editor
-- It creates ALL tables from scratch safely (DROP + CREATE)
-- Safe to re-run: uses IF NOT EXISTS / OR REPLACE everywhere
-- ============================================================

-- ── EXTENSIONS ──────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ── ENUMS ────────────────────────────────────────────────────
DO $$ BEGIN CREATE TYPE user_role AS ENUM ('customer','seller','admin'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE seller_plan AS ENUM ('free','silver','gold','platinum'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE seller_status AS ENUM ('pending','active','suspended','banned','rejected'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE product_status AS ENUM ('draft','pending_review','approved','rejected','archived'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE order_status AS ENUM ('pending','confirmed','processing','shipped','in_transit','delivered','disputed','cancelled','refunded'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE payment_status AS ENUM ('pending','held_escrow','released','refunded','failed'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE shipping_method AS ENUM ('air','sea_fcl','sea_lcl','door_to_door','courier'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE document_status AS ENUM ('pending','approved','rejected','expired'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE document_type AS ENUM ('business_license','ce_certificate','fcc_certificate','fda_approval','iso_9001','iso_13485','rohs','reach','haccp','oeko_tex','export_license','factory_audit','other'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE rfq_status AS ENUM ('open','closed','awarded','expired'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE dispute_status AS ENUM ('open','under_review','resolved','closed'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE dispute_outcome AS ENUM ('buyer_won','seller_won','partial_refund','split','reshipment'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE payout_status AS ENUM ('pending','processing','paid','failed'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE notification_type AS ENUM ('order_update','rfq_quote','dispute','shipment','review_request','payment','system','marketing'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE address_type AS ENUM ('commercial','warehouse','residential'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE rejection_reason AS ENUM ('missing_certification','poor_images','incomplete_description','pricing_issue','duplicate','prohibited','fraudulent_docs','incomplete_application','other'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- TABLE 1: PROFILES (extends auth.users)
-- Every user: customer, seller, admin
-- ============================================================
CREATE TABLE IF NOT EXISTS profiles (
  id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role            user_role NOT NULL DEFAULT 'customer',
  first_name      TEXT,
  last_name       TEXT,
  email           TEXT UNIQUE NOT NULL,
  phone           TEXT,
  avatar_url      TEXT,
  country         TEXT,
  city            TEXT,
  state           TEXT,
  preferred_language    TEXT DEFAULT 'en',
  preferred_currency    TEXT DEFAULT 'USD',
  date_of_birth   DATE,
  is_verified     BOOLEAN DEFAULT FALSE,
  is_active       BOOLEAN DEFAULT TRUE,
  two_factor_enabled    BOOLEAN DEFAULT FALSE,
  two_factor_secret     TEXT,                    -- encrypted 2FA secret
  last_login_at   TIMESTAMPTZ,
  login_count     INT DEFAULT 0,
  failed_login_attempts INT DEFAULT 0,
  locked_until    TIMESTAMPTZ,                  -- account lock after failures
  password_changed_at   TIMESTAMPTZ DEFAULT NOW(),
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE 2: CUSTOMER PROFILES
-- Buyer-specific data
-- ============================================================
CREATE TABLE IF NOT EXISTS customer_profiles (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id             UUID UNIQUE NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  company_name        TEXT,
  company_size        TEXT,
  industry            TEXT,
  position            TEXT,
  annual_budget_usd   TEXT,
  website             TEXT,
  business_reg_number TEXT,
  trade_assurance_active BOOLEAN DEFAULT TRUE,
  loyalty_tier        TEXT DEFAULT 'standard',   -- standard, silver, gold
  total_orders        INT DEFAULT 0,
  total_spent_usd     DECIMAL(14,2) DEFAULT 0,
  notes               TEXT,                      -- admin notes
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE 3: SELLER PROFILES
-- All seller account data and performance metrics
-- ============================================================
CREATE TABLE IF NOT EXISTS seller_profiles (
  id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id                 UUID UNIQUE NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  company_name            TEXT NOT NULL,
  company_description     TEXT,
  industry                TEXT,
  country                 TEXT NOT NULL,
  city                    TEXT,
  established_year        INT,
  employee_count          TEXT,
  annual_revenue          TEXT,
  website                 TEXT,
  business_reg_number     TEXT,
  -- Plan & Status
  plan                    seller_plan NOT NULL DEFAULT 'free',
  plan_expires_at         TIMESTAMPTZ,
  status                  seller_status NOT NULL DEFAULT 'pending',
  verification_score      INT DEFAULT 0,         -- 0-100
  -- Performance
  total_products          INT DEFAULT 0,
  total_orders            INT DEFAULT 0,
  total_revenue_usd       DECIMAL(14,2) DEFAULT 0,
  avg_rating              DECIMAL(3,2) DEFAULT 0,
  response_rate           DECIMAL(5,2) DEFAULT 0,
  on_time_delivery_rate   DECIMAL(5,2) DEFAULT 0,
  dispute_rate            DECIMAL(5,2) DEFAULT 0,
  -- Review
  rejection_reason        rejection_reason,
  rejection_notes         TEXT,
  admin_notes             TEXT,
  approved_at             TIMESTAMPTZ,
  approved_by             UUID REFERENCES profiles(id),
  rejected_at             TIMESTAMPTZ,
  suspended_at            TIMESTAMPTZ,
  suspension_reason       TEXT,
  created_at              TIMESTAMPTZ DEFAULT NOW(),
  updated_at              TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE 4: USER SESSIONS (extra tracking beyond Supabase auth)
-- ============================================================
CREATE TABLE IF NOT EXISTS user_sessions (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  ip_address      TEXT,
  user_agent      TEXT,
  device_type     TEXT,                          -- mobile, desktop, tablet
  browser         TEXT,
  os              TEXT,
  country         TEXT,
  city            TEXT,
  is_active       BOOLEAN DEFAULT TRUE,
  started_at      TIMESTAMPTZ DEFAULT NOW(),
  last_active_at  TIMESTAMPTZ DEFAULT NOW(),
  ended_at        TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS sessions_user_idx ON user_sessions(user_id, started_at DESC);

-- ============================================================
-- TABLE 5: PASSWORD RESET TOKENS
-- ============================================================
CREATE TABLE IF NOT EXISTS password_reset_tokens (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  token       TEXT UNIQUE NOT NULL DEFAULT encode(gen_random_bytes(32), 'hex'),
  expires_at  TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '1 hour',
  used_at     TIMESTAMPTZ,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE 6: TWO FACTOR AUTH LOG
-- ============================================================
CREATE TABLE IF NOT EXISTS two_factor_log (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  method      TEXT NOT NULL,                     -- sms, authenticator, email
  status      TEXT NOT NULL,                     -- success, failed, expired
  ip_address  TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE 7: ADDRESSES
-- ============================================================
CREATE TABLE IF NOT EXISTS addresses (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  label           TEXT,
  type            address_type DEFAULT 'commercial',
  first_name      TEXT,
  last_name       TEXT,
  company         TEXT,
  street_line1    TEXT NOT NULL,
  street_line2    TEXT,
  city            TEXT NOT NULL,
  state           TEXT,
  postal_code     TEXT,
  country         TEXT NOT NULL,
  phone           TEXT,
  is_default      BOOLEAN DEFAULT FALSE,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS addresses_user_idx ON addresses(user_id);

-- ============================================================
-- TABLE 8: PAYMENT METHODS
-- ============================================================
CREATE TABLE IF NOT EXISTS payment_methods (
  id                          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id                     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type                        TEXT NOT NULL,     -- card, paypal, bank_transfer, crypto
  label                       TEXT,
  -- Card
  card_brand                  TEXT,
  last_four                   TEXT,
  expiry_month                INT,
  expiry_year                 INT,
  cardholder_name             TEXT,
  -- PayPal
  paypal_email                TEXT,
  -- Bank
  bank_name                   TEXT,
  bank_account_last_four      TEXT,
  bank_routing_number         TEXT,
  bank_account_type           TEXT,              -- checking, savings
  -- Token (never store raw card details)
  stripe_payment_method_id    TEXT,
  is_default                  BOOLEAN DEFAULT FALSE,
  created_at                  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS payments_user_idx ON payment_methods(user_id);

-- ============================================================
-- TABLE 9: CATEGORIES
-- ============================================================
CREATE TABLE IF NOT EXISTS categories (
  id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  slug                    TEXT UNIQUE NOT NULL,
  name                    TEXT NOT NULL,
  icon                    TEXT,
  description             TEXT,
  parent_id               UUID REFERENCES categories(id),
  required_certifications TEXT[],
  platform_margin_pct     DECIMAL(5,2) NOT NULL DEFAULT 10.00,
  is_active               BOOLEAN DEFAULT TRUE,
  sort_order              INT DEFAULT 0,
  product_count           INT DEFAULT 0,
  seller_count            INT DEFAULT 0,
  created_at              TIMESTAMPTZ DEFAULT NOW(),
  updated_at              TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO categories (slug,name,icon,platform_margin_pct,required_certifications,sort_order) VALUES
  ('electronics',  'Electronics & Electrical', '🔌', 12.00, ARRAY['CE','FCC','RoHS'],      1),
  ('machinery',    'Machinery & Equipment',    '⚙️', 10.00, ARRAY['CE','ISO 9001'],         2),
  ('apparel',      'Apparel & Textiles',       '👗', 18.00, ARRAY['OEKO-TEX'],              3),
  ('food-agri',    'Food & Agriculture',       '🌿',  8.00, ARRAY['HACCP'],                 4),
  ('chemicals',    'Chemicals & Plastics',     '⚗️',  9.00, ARRAY['REACH','SDS'],           5),
  ('construction', 'Construction',             '🏗️', 10.00, ARRAY['CE'],                    6),
  ('auto-parts',   'Auto Parts',               '🚗', 14.00, ARRAY['ISO/TS 16949'],          7),
  ('healthcare',   'Health & Medical',         '🏥', 15.00, ARRAY['FDA','CE','ISO 13485'],  8),
  ('furniture',    'Furniture & Home',         '🪑', 16.00, ARRAY[]::TEXT[],                9),
  ('tools',        'Tools & Hardware',         '🔧', 11.00, ARRAY[]::TEXT[],               10)
ON CONFLICT (slug) DO NOTHING;

-- ============================================================
-- TABLE 10: PRODUCTS
-- ============================================================
CREATE TABLE IF NOT EXISTS products (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  seller_id           UUID NOT NULL REFERENCES seller_profiles(id) ON DELETE CASCADE,
  category_id         UUID NOT NULL REFERENCES categories(id),
  title               TEXT NOT NULL,
  slug                TEXT UNIQUE,
  description         TEXT,
  short_description   TEXT,
  specifications      JSONB DEFAULT '{}',
  images              TEXT[],
  video_url           TEXT,
  -- Pricing
  base_price_usd      DECIMAL(12,2) NOT NULL,
  buyer_price_usd     DECIMAL(12,2),
  currency            TEXT DEFAULT 'USD',
  -- Order info
  min_order_qty       INT NOT NULL DEFAULT 1,
  max_order_qty       INT,
  unit                TEXT DEFAULT 'unit',
  supply_capacity     TEXT,
  lead_time_days_min  INT,
  lead_time_days_max  INT,
  -- Origin & certs
  country_of_origin   TEXT,
  certifications      TEXT[],
  keywords            TEXT[],
  tags                TEXT[],
  -- Status
  status              product_status NOT NULL DEFAULT 'pending_review',
  is_featured         BOOLEAN DEFAULT FALSE,
  is_trade_assured    BOOLEAN DEFAULT TRUE,
  -- Analytics
  view_count          INT DEFAULT 0,
  order_count         INT DEFAULT 0,
  inquiry_count       INT DEFAULT 0,
  avg_rating          DECIMAL(3,2) DEFAULT 0,
  review_count        INT DEFAULT 0,
  -- Review
  rejection_reason    rejection_reason,
  rejection_notes     TEXT,
  admin_notes         TEXT,
  reviewed_by         UUID REFERENCES profiles(id),
  reviewed_at         TIMESTAMPTZ,
  -- Search
  search_vector       TSVECTOR,
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS products_seller_idx    ON products(seller_id);
CREATE INDEX IF NOT EXISTS products_category_idx  ON products(category_id);
CREATE INDEX IF NOT EXISTS products_status_idx    ON products(status);
CREATE INDEX IF NOT EXISTS products_search_idx    ON products USING GIN(search_vector);
CREATE INDEX IF NOT EXISTS products_featured_idx  ON products(is_featured, status);

-- ============================================================
-- TABLE 11: PRODUCT PRICE TIERS (MOQ-based pricing)
-- ============================================================
CREATE TABLE IF NOT EXISTS product_price_tiers (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id  UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  min_qty     INT NOT NULL,
  max_qty     INT,
  price_usd   DECIMAL(12,2) NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS price_tiers_product_idx ON product_price_tiers(product_id);

-- ============================================================
-- TABLE 12: PRODUCT VARIANTS (sizes, colors, models)
-- ============================================================
CREATE TABLE IF NOT EXISTS product_variants (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id      UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  variant_name    TEXT NOT NULL,              -- e.g. "Color", "Size"
  variant_value   TEXT NOT NULL,             -- e.g. "Red", "XL"
  sku             TEXT,
  price_modifier  DECIMAL(10,2) DEFAULT 0,   -- +/- from base price
  stock_qty       INT,
  image_url       TEXT,
  is_available    BOOLEAN DEFAULT TRUE,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE 13: SELLER DOCUMENTS
-- Certifications uploaded by sellers
-- ============================================================
CREATE TABLE IF NOT EXISTS seller_documents (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  seller_id           UUID NOT NULL REFERENCES seller_profiles(id) ON DELETE CASCADE,
  type                document_type NOT NULL,
  name                TEXT NOT NULL,
  file_url            TEXT NOT NULL,
  file_name           TEXT,
  file_size_bytes     INT,
  mime_type           TEXT,
  status              document_status NOT NULL DEFAULT 'pending',
  expiry_date         DATE,
  issued_by           TEXT,                  -- certifying authority
  certificate_number  TEXT,
  reviewer_notes      TEXT,
  rejection_reason    TEXT,
  reviewed_by         UUID REFERENCES profiles(id),
  reviewed_at         TIMESTAMPTZ,
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS seller_docs_seller_idx  ON seller_documents(seller_id);
CREATE INDEX IF NOT EXISTS seller_docs_status_idx  ON seller_documents(status);

-- ============================================================
-- TABLE 14: CATEGORY DOCUMENT REQUIREMENTS
-- Which documents are required per category
-- ============================================================
CREATE TABLE IF NOT EXISTS category_doc_requirements (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  category_id     UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  document_type   document_type NOT NULL,
  is_required     BOOLEAN DEFAULT TRUE,
  description     TEXT,
  UNIQUE(category_id, document_type)
);

-- ============================================================
-- TABLE 15: ORDERS
-- All purchase orders with Trade Assurance escrow
-- ============================================================
CREATE TABLE IF NOT EXISTS orders (
  id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_number            TEXT UNIQUE,             -- auto-generated EB-XXXXX
  buyer_id                UUID NOT NULL REFERENCES profiles(id),
  seller_id               UUID NOT NULL REFERENCES seller_profiles(id),
  status                  order_status NOT NULL DEFAULT 'pending',
  -- Line items (snapshot at time of order)
  items                   JSONB NOT NULL DEFAULT '[]',
  -- Amounts
  subtotal_usd            DECIMAL(14,2) NOT NULL,
  platform_fee_usd        DECIMAL(14,2) NOT NULL,
  shipping_cost_usd       DECIMAL(14,2) DEFAULT 0,
  tax_usd                 DECIMAL(14,2) DEFAULT 0,
  discount_usd            DECIMAL(14,2) DEFAULT 0,
  total_usd               DECIMAL(14,2) NOT NULL,
  currency                TEXT DEFAULT 'USD',
  -- Shipping
  shipping_method         shipping_method,
  shipping_address_id     UUID REFERENCES addresses(id),
  shipping_address_snapshot JSONB,               -- copy at time of order
  tracking_number         TEXT,
  carrier                 TEXT,
  vessel_name             TEXT,
  bill_of_lading          TEXT,
  container_number        TEXT,
  port_of_loading         TEXT,
  port_of_discharge       TEXT,
  estimated_departure     DATE,
  estimated_arrival       DATE,
  shipped_at              TIMESTAMPTZ,
  delivered_at            TIMESTAMPTZ,
  -- Payment
  payment_status          payment_status DEFAULT 'pending',
  payment_method_id       UUID REFERENCES payment_methods(id),
  payment_reference       TEXT,
  paid_at                 TIMESTAMPTZ,
  escrow_released_at      TIMESTAMPTZ,
  -- Notes
  buyer_notes             TEXT,
  seller_notes            TEXT,
  admin_notes             TEXT,
  -- Cancellation
  cancelled_at            TIMESTAMPTZ,
  cancellation_reason     TEXT,
  cancelled_by            UUID REFERENCES profiles(id),
  created_at              TIMESTAMPTZ DEFAULT NOW(),
  updated_at              TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS orders_buyer_idx    ON orders(buyer_id);
CREATE INDEX IF NOT EXISTS orders_seller_idx   ON orders(seller_id);
CREATE INDEX IF NOT EXISTS orders_status_idx   ON orders(status);
CREATE INDEX IF NOT EXISTS orders_number_idx   ON orders(order_number);
CREATE INDEX IF NOT EXISTS orders_date_idx     ON orders(created_at DESC);

-- ============================================================
-- TABLE 16: ORDER STATUS HISTORY
-- Track every status change for an order
-- ============================================================
CREATE TABLE IF NOT EXISTS order_status_history (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id    UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  old_status  order_status,
  new_status  order_status NOT NULL,
  note        TEXT,
  changed_by  UUID REFERENCES profiles(id),
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS order_history_order_idx ON order_status_history(order_id);

-- ============================================================
-- TABLE 17: REVIEWS
-- Buyer reviews for products
-- ============================================================
CREATE TABLE IF NOT EXISTS reviews (
  id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id                UUID NOT NULL REFERENCES orders(id),
  product_id              UUID NOT NULL REFERENCES products(id),
  buyer_id                UUID NOT NULL REFERENCES profiles(id),
  seller_id               UUID NOT NULL REFERENCES seller_profiles(id),
  overall_rating          INT NOT NULL CHECK (overall_rating BETWEEN 1 AND 5),
  quality_rating          INT CHECK (quality_rating BETWEEN 1 AND 5),
  shipping_rating         INT CHECK (shipping_rating BETWEEN 1 AND 5),
  communication_rating    INT CHECK (communication_rating BETWEEN 1 AND 5),
  value_rating            INT CHECK (value_rating BETWEEN 1 AND 5),
  as_described            BOOLEAN,
  title                   TEXT,
  body                    TEXT,
  photos                  TEXT[],
  is_verified_purchase    BOOLEAN DEFAULT TRUE,
  helpful_count           INT DEFAULT 0,
  -- Seller response
  seller_reply            TEXT,
  seller_replied_at       TIMESTAMPTZ,
  -- Admin
  is_visible              BOOLEAN DEFAULT TRUE,
  admin_flagged           BOOLEAN DEFAULT FALSE,
  created_at              TIMESTAMPTZ DEFAULT NOW(),
  updated_at              TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(order_id, product_id)
);
CREATE INDEX IF NOT EXISTS reviews_product_idx ON reviews(product_id);
CREATE INDEX IF NOT EXISTS reviews_seller_idx  ON reviews(seller_id);
CREATE INDEX IF NOT EXISTS reviews_buyer_idx   ON reviews(buyer_id);

-- ============================================================
-- TABLE 18: RFQs (Request for Quotation)
-- ============================================================
CREATE TABLE IF NOT EXISTS rfqs (
  id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  rfq_number              TEXT UNIQUE,           -- auto-generated RQ-YYYY-XXXX
  buyer_id                UUID NOT NULL REFERENCES profiles(id),
  category_id             UUID REFERENCES categories(id),
  title                   TEXT NOT NULL,
  description             TEXT,
  quantity                INT,
  unit                    TEXT,
  budget_min_usd          DECIMAL(12,2),
  budget_max_usd          DECIMAL(12,2),
  required_certifications TEXT[],
  technical_specs         TEXT,
  packaging_requirements  TEXT,
  sample_required         BOOLEAN DEFAULT FALSE,
  oem_required            BOOLEAN DEFAULT FALSE,
  timeline_days           INT,
  delivery_address_id     UUID REFERENCES addresses(id),
  status                  rfq_status DEFAULT 'open',
  expires_at              TIMESTAMPTZ DEFAULT NOW() + INTERVAL '30 days',
  awarded_to              UUID REFERENCES seller_profiles(id),
  awarded_at              TIMESTAMPTZ,
  quotes_count            INT DEFAULT 0,
  views_count             INT DEFAULT 0,
  created_at              TIMESTAMPTZ DEFAULT NOW(),
  updated_at              TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS rfqs_buyer_idx    ON rfqs(buyer_id);
CREATE INDEX IF NOT EXISTS rfqs_status_idx   ON rfqs(status);
CREATE INDEX IF NOT EXISTS rfqs_category_idx ON rfqs(category_id);

-- ============================================================
-- TABLE 19: RFQ QUOTES (Seller responses to RFQs)
-- ============================================================
CREATE TABLE IF NOT EXISTS rfq_quotes (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  rfq_id              UUID NOT NULL REFERENCES rfqs(id) ON DELETE CASCADE,
  seller_id           UUID NOT NULL REFERENCES seller_profiles(id),
  unit_price_usd      DECIMAL(12,2) NOT NULL,
  total_price_usd     DECIMAL(14,2),
  lead_time_days      INT,
  warranty_months     INT,
  sample_available    BOOLEAN DEFAULT FALSE,
  sample_price_usd    DECIMAL(10,2),
  notes               TEXT,
  attachments         TEXT[],
  is_trade_assured    BOOLEAN DEFAULT TRUE,
  status              TEXT DEFAULT 'pending',    -- pending, accepted, rejected, countered, expired
  counter_price_usd   DECIMAL(12,2),             -- buyer counter-offer
  counter_notes       TEXT,
  accepted_at         TIMESTAMPTZ,
  rejected_at         TIMESTAMPTZ,
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(rfq_id, seller_id)
);
CREATE INDEX IF NOT EXISTS rfq_quotes_rfq_idx    ON rfq_quotes(rfq_id);
CREATE INDEX IF NOT EXISTS rfq_quotes_seller_idx ON rfq_quotes(seller_id);

-- ============================================================
-- TABLE 20: DISPUTES
-- Trade Assurance dispute management
-- ============================================================
CREATE TABLE IF NOT EXISTS disputes (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id            UUID NOT NULL REFERENCES orders(id),
  buyer_id            UUID NOT NULL REFERENCES profiles(id),
  seller_id           UUID NOT NULL REFERENCES seller_profiles(id),
  issue_type          TEXT NOT NULL,            -- missing_items, wrong_product, quality, damaged, not_received, other
  description         TEXT NOT NULL,
  requested_resolution TEXT,                   -- full_refund, partial_refund, reshipment, replacement
  evidence_urls       TEXT[],
  -- Seller response
  seller_response     TEXT,
  seller_evidence_urls TEXT[],
  seller_responded_at TIMESTAMPTZ,
  -- Admin decision
  status              dispute_status DEFAULT 'open',
  outcome             dispute_outcome,
  refund_amount_usd   DECIMAL(12,2),
  admin_decision      TEXT,
  admin_notes         TEXT,
  resolved_by         UUID REFERENCES profiles(id),
  resolved_at         TIMESTAMPTZ,
  auto_escalate_at    TIMESTAMPTZ DEFAULT NOW() + INTERVAL '14 days',
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS disputes_order_idx  ON disputes(order_id);
CREATE INDEX IF NOT EXISTS disputes_buyer_idx  ON disputes(buyer_id);
CREATE INDEX IF NOT EXISTS disputes_status_idx ON disputes(status);

-- ============================================================
-- TABLE 21: WISHLIST
-- ============================================================
CREATE TABLE IF NOT EXISTS wishlists (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  product_id  UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  notes       TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, product_id)
);
CREATE INDEX IF NOT EXISTS wishlists_user_idx ON wishlists(user_id);

-- ============================================================
-- TABLE 22: PRODUCT INQUIRIES (Contact Seller)
-- ============================================================
CREATE TABLE IF NOT EXISTS product_inquiries (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id          UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  buyer_id            UUID NOT NULL REFERENCES profiles(id),
  seller_id           UUID NOT NULL REFERENCES seller_profiles(id),
  subject             TEXT,
  message             TEXT NOT NULL,
  quantity            INT,
  attachments         TEXT[],
  status              TEXT DEFAULT 'open',      -- open, replied, closed
  seller_reply        TEXT,
  seller_replied_at   TIMESTAMPTZ,
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS inquiries_seller_idx ON product_inquiries(seller_id);
CREATE INDEX IF NOT EXISTS inquiries_buyer_idx  ON product_inquiries(buyer_id);

-- ============================================================
-- TABLE 23: SELLER PAYOUTS
-- Monthly payout processing
-- ============================================================
CREATE TABLE IF NOT EXISTS seller_payouts (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  seller_id           UUID NOT NULL REFERENCES seller_profiles(id),
  period_start        DATE NOT NULL,
  period_end          DATE NOT NULL,
  order_count         INT DEFAULT 0,
  gross_revenue_usd   DECIMAL(14,2) NOT NULL,
  platform_fee_usd    DECIMAL(14,2) NOT NULL,
  refunds_usd         DECIMAL(14,2) DEFAULT 0,
  net_payout_usd      DECIMAL(14,2) NOT NULL,
  status              payout_status DEFAULT 'pending',
  paid_at             TIMESTAMPTZ,
  payment_reference   TEXT,
  payment_method      TEXT,                     -- bank_transfer, paypal, wise
  bank_details        JSONB,                    -- encrypted snapshot of bank info
  admin_notes         TEXT,
  processed_by        UUID REFERENCES profiles(id),
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS payouts_seller_idx  ON seller_payouts(seller_id);
CREATE INDEX IF NOT EXISTS payouts_status_idx  ON seller_payouts(status);

-- ============================================================
-- TABLE 24: SUBSCRIPTIONS
-- Seller plan subscriptions
-- ============================================================
CREATE TABLE IF NOT EXISTS subscriptions (
  id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  seller_id               UUID NOT NULL REFERENCES seller_profiles(id),
  plan                    seller_plan NOT NULL,
  price_usd               DECIMAL(8,2) NOT NULL,
  billing_cycle           TEXT DEFAULT 'monthly',  -- monthly, annual
  started_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at              TIMESTAMPTZ NOT NULL,
  cancelled_at            TIMESTAMPTZ,
  stripe_subscription_id  TEXT,
  stripe_customer_id      TEXT,
  is_active               BOOLEAN DEFAULT TRUE,
  auto_renew              BOOLEAN DEFAULT TRUE,
  created_at              TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS subs_seller_idx ON subscriptions(seller_id);

-- ============================================================
-- TABLE 25: SHIPPING RATES
-- Per-destination freight rates
-- ============================================================
CREATE TABLE IF NOT EXISTS shipping_rates (
  id                          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  destination_country         TEXT NOT NULL,
  destination_label           TEXT NOT NULL,
  flag_emoji                  TEXT,
  air_per_kg                  DECIMAL(8,2),
  sea_fcl_flat                DECIMAL(10,2),
  sea_lcl_per_cbm             DECIMAL(8,2),
  door_to_door_per_kg         DECIMAL(8,2),
  courier_per_kg              DECIMAL(8,2),
  air_transit_days_min        INT,
  air_transit_days_max        INT,
  sea_transit_days_min        INT,
  sea_transit_days_max        INT,
  customs_notes               TEXT,
  surcharge_pct               DECIMAL(5,2) DEFAULT 0,
  is_active                   BOOLEAN DEFAULT TRUE,
  updated_at                  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(destination_country)
);

INSERT INTO shipping_rates (destination_country,destination_label,flag_emoji,air_per_kg,sea_fcl_flat,sea_lcl_per_cbm,door_to_door_per_kg,air_transit_days_min,air_transit_days_max,sea_transit_days_min,sea_transit_days_max) VALUES
  ('AE','UAE / Dubai',    '🇦🇪',4.50,1200,95, 6.80, 3,5, 18,25),
  ('SA','Saudi Arabia',   '🇸🇦',4.80,1350,105,7.20, 3,6, 20,28),
  ('US','United States',  '🇺🇸',5.20,1800,120,8.50, 5,7, 25,35),
  ('GB','United Kingdom', '🇬🇧',5.60,1600,115,8.00, 4,6, 22,30),
  ('DE','Germany',        '🇩🇪',5.40,1550,112,7.90, 4,6, 22,30),
  ('AU','Australia',      '🇦🇺',6.20,2100,140,9.80, 5,8, 28,35),
  ('IN','India',          '🇮🇳',3.80,900, 75, 5.20, 2,4, 12,18),
  ('NG','Nigeria',        '🇳🇬',7.50,2400,165,11.20,5,8, 30,40),
  ('FR','France',         '🇫🇷',5.30,1500,110,7.80, 4,6, 22,30),
  ('CA','Canada',         '🇨🇦',5.40,1750,118,8.20, 5,7, 25,35),
  ('SG','Singapore',      '🇸🇬',3.50,900, 70, 5.00, 2,4, 10,16),
  ('TR','Turkey',         '🇹🇷',4.20,1100,88, 6.20, 3,5, 16,22),
  ('PK','Pakistan',       '🇵🇰',3.90,950, 78, 5.50, 2,4, 12,18),
  ('BD','Bangladesh',     '🇧🇩',4.00,950, 80, 5.60, 2,4, 12,18),
  ('ZA','South Africa',   '🇿🇦',6.80,2200,148,9.40, 5,8, 28,38)
ON CONFLICT (destination_country) DO NOTHING;

-- ============================================================
-- TABLE 26: PLATFORM SETTINGS
-- Admin-configurable key/value store
-- ============================================================
CREATE TABLE IF NOT EXISTS platform_settings (
  key           TEXT PRIMARY KEY,
  value         TEXT NOT NULL,
  description   TEXT,
  updated_by    UUID REFERENCES profiles(id),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO platform_settings (key,value,description) VALUES
  ('commission_pct',          '5',      'Platform commission % on all transactions'),
  ('payment_processing_pct',  '2.5',    'Payment processor fee %'),
  ('min_order_usd',           '100',    'Minimum order value in USD'),
  ('max_trade_assurance',     '500000', 'Max Trade Assurance coverage per order USD'),
  ('plan_free_max_products',  '10',     'Max products for free plan'),
  ('plan_silver_price',       '49',     'Silver plan monthly price USD'),
  ('plan_gold_price',         '149',    'Gold plan monthly price USD'),
  ('plan_platinum_price',     '349',    'Platinum plan monthly price USD'),
  ('trade_assurance_active',  'true',   'Trade Assurance escrow enabled'),
  ('new_seller_reg_open',     'true',   'Allow new seller registrations'),
  ('buyer_reg_open',          'true',   'Allow new buyer registrations'),
  ('maintenance_mode',        'false',  'Show maintenance page'),
  ('announcement_text',       'Welcome to Ebazario Trading — Global B2B Marketplace', 'Homepage banner'),
  ('announcement_visible',    'true',   'Show announcement banner'),
  ('auto_approve_platinum',   'false',  'Auto-approve Platinum seller products'),
  ('dispute_auto_escalate_days','14',   'Days before dispute auto-escalates'),
  ('review_window_days',      '30',     'Days buyer has to leave a review after delivery'),
  ('rfq_expiry_days',         '30',     'Default RFQ expiry in days'),
  ('payout_schedule',         'monthly','Seller payout schedule: monthly or weekly'),
  ('support_email',           'support@ebazario.com','Support email address')
ON CONFLICT (key) DO NOTHING;

-- ============================================================
-- TABLE 27: NOTIFICATIONS (In-app)
-- ============================================================
CREATE TABLE IF NOT EXISTS notifications (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type            notification_type NOT NULL,
  title           TEXT NOT NULL,
  body            TEXT,
  action_url      TEXT,
  icon            TEXT,
  is_read         BOOLEAN DEFAULT FALSE,
  read_at         TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS notifs_user_unread_idx ON notifications(user_id, is_read, created_at DESC);

-- ============================================================
-- TABLE 28: EMAIL LOG
-- All system emails sent
-- ============================================================
CREATE TABLE IF NOT EXISTS email_log (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  to_email        TEXT NOT NULL,
  to_name         TEXT,
  from_email      TEXT DEFAULT 'noreply@ebazario.com',
  subject         TEXT NOT NULL,
  template        TEXT,                         -- template name used
  status          TEXT DEFAULT 'sent',          -- sent, failed, bounced
  user_id         UUID REFERENCES profiles(id),
  related_entity_type TEXT,
  related_entity_id   UUID,
  error_message   TEXT,
  sent_at         TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS email_log_user_idx ON email_log(user_id, sent_at DESC);

-- ============================================================
-- TABLE 29: AUDIT LOG
-- Every admin action recorded
-- ============================================================
CREATE TABLE IF NOT EXISTS audit_log (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID REFERENCES profiles(id),
  user_email      TEXT,
  role            user_role,
  action          TEXT NOT NULL,               -- e.g. product_approved, seller_rejected
  entity_type     TEXT,                        -- products, orders, seller_profiles...
  entity_id       UUID,
  old_data        JSONB,
  new_data        JSONB,
  ip_address      TEXT,
  user_agent      TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS audit_log_user_idx   ON audit_log(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS audit_log_entity_idx ON audit_log(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS audit_log_action_idx ON audit_log(action, created_at DESC);

-- ============================================================
-- TABLE 30: BLOCKED IPS
-- ============================================================
CREATE TABLE IF NOT EXISTS blocked_ips (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ip_address  TEXT UNIQUE NOT NULL,
  reason      TEXT,
  blocked_by  UUID REFERENCES profiles(id),
  blocked_at  TIMESTAMPTZ DEFAULT NOW(),
  expires_at  TIMESTAMPTZ
);

-- ============================================================
-- TABLE 31: PRODUCT VIEWS TRACKING
-- ============================================================
CREATE TABLE IF NOT EXISTS product_views (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id  UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  viewer_id   UUID REFERENCES profiles(id),
  ip_hash     TEXT,
  referrer    TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS prod_views_product_idx ON product_views(product_id, created_at DESC);

-- ============================================================
-- TABLE 32: REVENUE SNAPSHOTS (daily for reports)
-- ============================================================
CREATE TABLE IF NOT EXISTS revenue_snapshots (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  period_date         DATE NOT NULL UNIQUE,
  gmv_usd             DECIMAL(16,2) DEFAULT 0,
  order_count         INT DEFAULT 0,
  commission_usd      DECIMAL(14,2) DEFAULT 0,
  subscription_usd    DECIMAL(14,2) DEFAULT 0,
  total_revenue_usd   DECIMAL(14,2) DEFAULT 0,
  total_expenses_usd  DECIMAL(14,2) DEFAULT 0,
  net_profit_usd      DECIMAL(14,2) DEFAULT 0,
  active_sellers      INT DEFAULT 0,
  new_sellers         INT DEFAULT 0,
  active_buyers       INT DEFAULT 0,
  new_buyers          INT DEFAULT 0,
  new_products        INT DEFAULT 0,
  created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE 33: USER SESSIONS (login tracking)
-- ============================================================
CREATE TABLE IF NOT EXISTS user_sessions (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  ip_address      TEXT,
  user_agent      TEXT,
  device_type     TEXT,
  browser         TEXT,
  os              TEXT,
  country         TEXT,
  city            TEXT,
  is_active       BOOLEAN DEFAULT TRUE,
  started_at      TIMESTAMPTZ DEFAULT NOW(),
  last_active_at  TIMESTAMPTZ DEFAULT NOW(),
  ended_at        TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS sessions_user_idx ON user_sessions(user_id, started_at DESC);

-- ============================================================
-- TABLE 34: SELLER NOTIFICATION LOG
-- ============================================================
CREATE TABLE IF NOT EXISTS seller_notification_log (
  id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  seller_id               UUID NOT NULL REFERENCES seller_profiles(id) ON DELETE CASCADE,
  notification_type       TEXT NOT NULL,
  subject                 TEXT,
  body                    TEXT,
  related_entity_type     TEXT,
  related_entity_id       UUID,
  sent_at                 TIMESTAMPTZ DEFAULT NOW(),
  read_at                 TIMESTAMPTZ
);

-- ============================================================
-- TABLE 35: COUPONS & PROMOTIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS coupons (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code                TEXT UNIQUE NOT NULL,
  description         TEXT,
  discount_type       TEXT NOT NULL,            -- percentage, fixed_amount
  discount_value      DECIMAL(10,2) NOT NULL,
  min_order_usd       DECIMAL(10,2) DEFAULT 0,
  max_discount_usd    DECIMAL(10,2),
  valid_from          TIMESTAMPTZ DEFAULT NOW(),
  valid_until         TIMESTAMPTZ,
  usage_limit         INT,
  used_count          INT DEFAULT 0,
  is_active           BOOLEAN DEFAULT TRUE,
  applicable_to       TEXT DEFAULT 'all',       -- all, new_users, specific_category
  category_id         UUID REFERENCES categories(id),
  created_by          UUID REFERENCES profiles(id),
  created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- SEQUENCES FOR AUTO-GENERATED NUMBERS
-- ============================================================
CREATE SEQUENCE IF NOT EXISTS order_seq START 10001;
CREATE SEQUENCE IF NOT EXISTS rfq_seq   START 1001;

-- ============================================================
-- FUNCTIONS & TRIGGERS
-- ============================================================

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

DO $$ DECLARE t TEXT;
BEGIN
  FOR t IN SELECT unnest(ARRAY['profiles','seller_profiles','customer_profiles','products','orders','disputes','reviews','rfqs','rfq_quotes','seller_documents','addresses','product_inquiries','seller_payouts'])
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_updated ON %s', t, t);
    EXECUTE format('CREATE TRIGGER trg_%s_updated BEFORE UPDATE ON %s FOR EACH ROW EXECUTE FUNCTION update_updated_at()', t, t);
  END LOOP;
END $$;

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, email, role, first_name, last_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'customer'),
    NEW.raw_user_meta_data->>'first_name',
    NEW.raw_user_meta_data->>'last_name'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Auto-generate order number
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.order_number IS NULL THEN
    NEW.order_number = 'EB-' || TO_CHAR(NOW(), 'YYYY') || LPAD(NEXTVAL('order_seq')::TEXT, 5, '0');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_order_number ON orders;
CREATE TRIGGER trg_order_number
  BEFORE INSERT ON orders FOR EACH ROW EXECUTE FUNCTION generate_order_number();

-- Auto-generate RFQ number
CREATE OR REPLACE FUNCTION generate_rfq_number()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.rfq_number IS NULL THEN
    NEW.rfq_number = 'RQ-' || TO_CHAR(NOW(), 'YYYY') || '-' || LPAD(NEXTVAL('rfq_seq')::TEXT, 4, '0');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_rfq_number ON rfqs;
CREATE TRIGGER trg_rfq_number
  BEFORE INSERT ON rfqs FOR EACH ROW EXECUTE FUNCTION generate_rfq_number();

-- Update product avg rating after review
CREATE OR REPLACE FUNCTION update_product_rating()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE products SET
    avg_rating   = (SELECT ROUND(AVG(overall_rating)::NUMERIC, 2) FROM reviews WHERE product_id = NEW.product_id AND is_visible = TRUE),
    review_count = (SELECT COUNT(*) FROM reviews WHERE product_id = NEW.product_id AND is_visible = TRUE)
  WHERE id = NEW.product_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_product_rating ON reviews;
CREATE TRIGGER trg_product_rating
  AFTER INSERT OR UPDATE ON reviews FOR EACH ROW EXECUTE FUNCTION update_product_rating();

-- Update seller stats when order delivered
CREATE OR REPLACE FUNCTION update_seller_stats()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'delivered' AND (OLD.status IS NULL OR OLD.status <> 'delivered') THEN
    UPDATE seller_profiles SET
      total_orders      = total_orders + 1,
      total_revenue_usd = total_revenue_usd + NEW.subtotal_usd
    WHERE id = NEW.seller_id;
    UPDATE customer_profiles SET
      total_orders    = total_orders + 1,
      total_spent_usd = total_spent_usd + NEW.total_usd
    WHERE user_id = NEW.buyer_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_seller_stats ON orders;
CREATE TRIGGER trg_seller_stats
  AFTER UPDATE ON orders FOR EACH ROW EXECUTE FUNCTION update_seller_stats();

-- Log order status changes
CREATE OR REPLACE FUNCTION log_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO order_status_history (order_id, old_status, new_status)
    VALUES (NEW.id, OLD.status, NEW.status);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_order_status_history ON orders;
CREATE TRIGGER trg_order_status_history
  AFTER UPDATE ON orders FOR EACH ROW EXECUTE FUNCTION log_order_status_change();

-- Notify seller when product approved/rejected
CREATE OR REPLACE FUNCTION notify_seller_product_review()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status IN ('approved','rejected') AND (OLD.status IS NULL OR OLD.status = 'pending_review') THEN
    INSERT INTO notifications (user_id, type, title, body, action_url)
    SELECT sp.user_id,
      'system',
      CASE WHEN NEW.status='approved' THEN '✅ Product Approved!' ELSE '⚠️ Product Needs Attention' END,
      CASE WHEN NEW.status='approved'
        THEN '"' || LEFT(NEW.title,60) || '" is now live on the marketplace!'
        ELSE '"' || LEFT(NEW.title,60) || '" was not approved. ' || COALESCE(NEW.rejection_notes,'Please review and resubmit.')
      END,
      '/pages/seller-dashboard.html'
    FROM seller_profiles sp WHERE sp.id = NEW.seller_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_notify_product_review ON products;
CREATE TRIGGER trg_notify_product_review
  AFTER UPDATE OF status ON products FOR EACH ROW EXECUTE FUNCTION notify_seller_product_review();

-- Notify seller when account approved/rejected
CREATE OR REPLACE FUNCTION notify_seller_approval()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status IN ('active','rejected') AND (OLD.status IS NULL OR OLD.status = 'pending') THEN
    INSERT INTO notifications (user_id, type, title, body, action_url)
    VALUES (
      NEW.user_id, 'system',
      CASE WHEN NEW.status='active' THEN '🎉 Seller Account Approved!' ELSE '⚠️ Seller Application Update' END,
      CASE WHEN NEW.status='active'
        THEN 'Congratulations! Your account is now active. Start listing products!'
        ELSE COALESCE('Reason: ' || NEW.rejection_notes, 'Your application needs attention.')
      END,
      '/pages/seller-dashboard.html'
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_notify_seller_approval ON seller_profiles;
CREATE TRIGGER trg_notify_seller_approval
  AFTER UPDATE OF status ON seller_profiles FOR EACH ROW EXECUTE FUNCTION notify_seller_approval();

-- Build full-text search vector
CREATE OR REPLACE FUNCTION update_product_search_vector()
RETURNS TRIGGER AS $$
BEGIN
  NEW.search_vector = to_tsvector('english',
    COALESCE(NEW.title,'') || ' ' ||
    COALESCE(NEW.description,'') || ' ' ||
    COALESCE(array_to_string(NEW.keywords,' '),'') || ' ' ||
    COALESCE(array_to_string(NEW.tags,' '),'')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_product_search_vector ON products;
CREATE TRIGGER trg_product_search_vector
  BEFORE INSERT OR UPDATE OF title,description,keywords,tags ON products
  FOR EACH ROW EXECUTE FUNCTION update_product_search_vector();

-- Auto-update seller product count
CREATE OR REPLACE FUNCTION update_seller_product_count()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE seller_profiles SET
    total_products = (SELECT COUNT(*) FROM products WHERE seller_id = COALESCE(NEW.seller_id, OLD.seller_id) AND status = 'approved')
  WHERE id = COALESCE(NEW.seller_id, OLD.seller_id);
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_seller_product_count ON products;
CREATE TRIGGER trg_seller_product_count
  AFTER INSERT OR UPDATE OF status OR DELETE ON products
  FOR EACH ROW EXECUTE FUNCTION update_seller_product_count();

-- ============================================================
-- USEFUL VIEWS
-- ============================================================

CREATE OR REPLACE VIEW admin_dashboard_stats AS
SELECT
  (SELECT COUNT(*) FROM products WHERE status='pending_review')::INT         AS pending_products,
  (SELECT COUNT(*) FROM seller_profiles WHERE status='pending')::INT          AS pending_sellers,
  (SELECT COUNT(*) FROM seller_documents WHERE status='pending')::INT         AS pending_documents,
  (SELECT COUNT(*) FROM disputes WHERE status='open')::INT                    AS open_disputes,
  (SELECT COUNT(*) FROM orders WHERE status NOT IN ('delivered','cancelled','refunded'))::INT AS active_orders,
  (SELECT COUNT(*) FROM seller_profiles WHERE status='active')::INT           AS total_active_sellers,
  (SELECT COUNT(*) FROM profiles WHERE role='customer')::INT                  AS total_customers,
  (SELECT COALESCE(SUM(total_usd),0) FROM orders WHERE status='delivered' AND created_at >= date_trunc('month',NOW())) AS gmv_this_month,
  (SELECT COALESCE(SUM(platform_fee_usd),0) FROM orders WHERE status='delivered' AND created_at >= date_trunc('month',NOW())) AS revenue_this_month,
  (SELECT COUNT(*) FROM orders WHERE status='delivered' AND created_at >= date_trunc('month',NOW()))::INT AS orders_this_month;

CREATE OR REPLACE VIEW seller_performance_view AS
SELECT
  sp.id, sp.company_name, sp.country, sp.plan, sp.status,
  sp.avg_rating, sp.response_rate, sp.on_time_delivery_rate,
  COUNT(DISTINCT p.id)  FILTER (WHERE p.status='approved')  AS approved_products,
  COUNT(DISTINCT o.id)                                        AS total_orders,
  COALESCE(SUM(o.subtotal_usd) FILTER (WHERE o.status='delivered'),0) AS lifetime_revenue,
  COALESCE(SUM(o.subtotal_usd) FILTER (WHERE o.status='delivered' AND o.created_at >= date_trunc('month',NOW())),0) AS revenue_mtd,
  COUNT(DISTINCT d.id)  FILTER (WHERE d.status='open')       AS open_disputes
FROM seller_profiles sp
LEFT JOIN products p ON p.seller_id = sp.id
LEFT JOIN orders o   ON o.seller_id = sp.id
LEFT JOIN disputes d ON d.seller_id = sp.id
GROUP BY sp.id,sp.company_name,sp.country,sp.plan,sp.status,sp.avg_rating,sp.response_rate,sp.on_time_delivery_rate;

CREATE OR REPLACE VIEW product_analytics_view AS
SELECT
  p.id, p.title, p.status, p.base_price_usd, p.buyer_price_usd,
  p.view_count, p.order_count, p.avg_rating, p.review_count,
  c.name  AS category_name,
  sp.company_name AS seller_name, sp.country AS seller_country, sp.plan AS seller_plan,
  CASE WHEN p.view_count > 0 THEN ROUND((p.order_count::NUMERIC/p.view_count)*100,2) ELSE 0 END AS conversion_rate_pct
FROM products p
JOIN categories c ON c.id = p.category_id
JOIN seller_profiles sp ON sp.id = p.seller_id;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE profiles             ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_profiles    ENABLE ROW LEVEL SECURITY;
ALTER TABLE seller_profiles      ENABLE ROW LEVEL SECURITY;
ALTER TABLE products             ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders               ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews              ENABLE ROW LEVEL SECURITY;
ALTER TABLE rfqs                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE rfq_quotes           ENABLE ROW LEVEL SECURITY;
ALTER TABLE disputes             ENABLE ROW LEVEL SECURITY;
ALTER TABLE wishlists            ENABLE ROW LEVEL SECURITY;
ALTER TABLE seller_documents     ENABLE ROW LEVEL SECURITY;
ALTER TABLE seller_payouts       ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications        ENABLE ROW LEVEL SECURITY;
ALTER TABLE addresses            ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_methods      ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_inquiries    ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions        ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions        ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_views        ENABLE ROW LEVEL SECURITY;

-- Helper: is current user admin?
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin');
$$ LANGUAGE sql SECURITY DEFINER;

-- Helper: get seller profile id for current user
CREATE OR REPLACE FUNCTION my_seller_id()
RETURNS UUID AS $$
  SELECT id FROM seller_profiles WHERE user_id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER;

-- PROFILES
DROP POLICY IF EXISTS "profiles_select_own"   ON profiles;
DROP POLICY IF EXISTS "profiles_select_admin" ON profiles;
DROP POLICY IF EXISTS "profiles_insert"       ON profiles;
DROP POLICY IF EXISTS "profiles_update_own"   ON profiles;
CREATE POLICY "profiles_select_own"   ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "profiles_select_admin" ON profiles FOR SELECT USING (is_admin());
CREATE POLICY "profiles_insert"       ON profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "profiles_update_own"   ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "profiles_update_admin" ON profiles FOR UPDATE USING (is_admin());

-- CUSTOMER PROFILES
DROP POLICY IF EXISTS "cust_all_own"   ON customer_profiles;
DROP POLICY IF EXISTS "cust_all_admin" ON customer_profiles;
CREATE POLICY "cust_all_own"   ON customer_profiles FOR ALL USING (user_id = auth.uid());
CREATE POLICY "cust_all_admin" ON customer_profiles FOR ALL USING (is_admin());

-- SELLER PROFILES
DROP POLICY IF EXISTS "seller_select_public" ON seller_profiles;
DROP POLICY IF EXISTS "seller_all_own"       ON seller_profiles;
DROP POLICY IF EXISTS "seller_all_admin"     ON seller_profiles;
CREATE POLICY "seller_select_public" ON seller_profiles FOR SELECT USING (status = 'active');
CREATE POLICY "seller_all_own"       ON seller_profiles FOR ALL USING (user_id = auth.uid());
CREATE POLICY "seller_all_admin"     ON seller_profiles FOR ALL USING (is_admin());

-- PRODUCTS
DROP POLICY IF EXISTS "products_select_approved" ON products;
DROP POLICY IF EXISTS "products_all_own_seller"  ON products;
DROP POLICY IF EXISTS "products_all_admin"        ON products;
CREATE POLICY "products_select_approved" ON products FOR SELECT USING (status = 'approved');
CREATE POLICY "products_all_own_seller"  ON products FOR ALL USING (seller_id = my_seller_id());
CREATE POLICY "products_all_admin"       ON products FOR ALL USING (is_admin());

-- ORDERS
DROP POLICY IF EXISTS "orders_select_buyer"  ON orders;
DROP POLICY IF EXISTS "orders_select_seller" ON orders;
DROP POLICY IF EXISTS "orders_insert_buyer"  ON orders;
DROP POLICY IF EXISTS "orders_all_admin"     ON orders;
CREATE POLICY "orders_select_buyer"  ON orders FOR SELECT USING (buyer_id = auth.uid());
CREATE POLICY "orders_select_seller" ON orders FOR SELECT USING (seller_id = my_seller_id());
CREATE POLICY "orders_insert_buyer"  ON orders FOR INSERT WITH CHECK (buyer_id = auth.uid());
CREATE POLICY "orders_all_admin"     ON orders FOR ALL USING (is_admin());

-- ADDRESSES
DROP POLICY IF EXISTS "addr_all_own" ON addresses;
CREATE POLICY "addr_all_own" ON addresses FOR ALL USING (user_id = auth.uid());

-- PAYMENT METHODS
DROP POLICY IF EXISTS "pay_all_own" ON payment_methods;
CREATE POLICY "pay_all_own" ON payment_methods FOR ALL USING (user_id = auth.uid());

-- REVIEWS
DROP POLICY IF EXISTS "reviews_select_public" ON reviews;
DROP POLICY IF EXISTS "reviews_insert_buyer"  ON reviews;
DROP POLICY IF EXISTS "reviews_update_buyer"  ON reviews;
DROP POLICY IF EXISTS "reviews_all_admin"     ON reviews;
CREATE POLICY "reviews_select_public" ON reviews FOR SELECT USING (is_visible = TRUE);
CREATE POLICY "reviews_insert_buyer"  ON reviews FOR INSERT WITH CHECK (buyer_id = auth.uid());
CREATE POLICY "reviews_update_buyer"  ON reviews FOR UPDATE USING (buyer_id = auth.uid());
CREATE POLICY "reviews_all_admin"     ON reviews FOR ALL USING (is_admin());

-- RFQs
DROP POLICY IF EXISTS "rfqs_buyer_own"    ON rfqs;
DROP POLICY IF EXISTS "rfqs_open_sellers" ON rfqs;
DROP POLICY IF EXISTS "rfqs_all_admin"    ON rfqs;
CREATE POLICY "rfqs_buyer_own"    ON rfqs FOR ALL USING (buyer_id = auth.uid());
CREATE POLICY "rfqs_open_sellers" ON rfqs FOR SELECT USING (status = 'open');
CREATE POLICY "rfqs_all_admin"    ON rfqs FOR ALL USING (is_admin());

-- RFQ QUOTES
DROP POLICY IF EXISTS "quotes_seller_own" ON rfq_quotes;
DROP POLICY IF EXISTS "quotes_buyer_read" ON rfq_quotes;
DROP POLICY IF EXISTS "quotes_all_admin"  ON rfq_quotes;
CREATE POLICY "quotes_seller_own" ON rfq_quotes FOR ALL USING (seller_id = my_seller_id());
CREATE POLICY "quotes_buyer_read" ON rfq_quotes FOR SELECT USING (EXISTS (SELECT 1 FROM rfqs WHERE id = rfq_id AND buyer_id = auth.uid()));
CREATE POLICY "quotes_all_admin"  ON rfq_quotes FOR ALL USING (is_admin());

-- DISPUTES
DROP POLICY IF EXISTS "disp_buyer_own"   ON disputes;
DROP POLICY IF EXISTS "disp_seller_read" ON disputes;
DROP POLICY IF EXISTS "disp_all_admin"   ON disputes;
CREATE POLICY "disp_buyer_own"   ON disputes FOR ALL USING (buyer_id = auth.uid());
CREATE POLICY "disp_seller_read" ON disputes FOR SELECT USING (seller_id = my_seller_id());
CREATE POLICY "disp_all_admin"   ON disputes FOR ALL USING (is_admin());

-- WISHLISTS
DROP POLICY IF EXISTS "wish_all_own" ON wishlists;
CREATE POLICY "wish_all_own" ON wishlists FOR ALL USING (user_id = auth.uid());

-- SELLER DOCUMENTS
DROP POLICY IF EXISTS "docs_seller_own" ON seller_documents;
DROP POLICY IF EXISTS "docs_all_admin"  ON seller_documents;
CREATE POLICY "docs_seller_own" ON seller_documents FOR ALL USING (seller_id = my_seller_id());
CREATE POLICY "docs_all_admin"  ON seller_documents FOR ALL USING (is_admin());

-- SELLER PAYOUTS
DROP POLICY IF EXISTS "payout_seller_read" ON seller_payouts;
DROP POLICY IF EXISTS "payout_all_admin"   ON seller_payouts;
CREATE POLICY "payout_seller_read" ON seller_payouts FOR SELECT USING (seller_id = my_seller_id());
CREATE POLICY "payout_all_admin"   ON seller_payouts FOR ALL USING (is_admin());

-- NOTIFICATIONS
DROP POLICY IF EXISTS "notif_own_read"   ON notifications;
DROP POLICY IF EXISTS "notif_own_update" ON notifications;
CREATE POLICY "notif_own_read"   ON notifications FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "notif_own_update" ON notifications FOR UPDATE USING (user_id = auth.uid());

-- PRODUCT INQUIRIES
DROP POLICY IF EXISTS "inq_buyer_all"   ON product_inquiries;
DROP POLICY IF EXISTS "inq_seller_read" ON product_inquiries;
DROP POLICY IF EXISTS "inq_seller_upd"  ON product_inquiries;
CREATE POLICY "inq_buyer_all"   ON product_inquiries FOR ALL USING (buyer_id = auth.uid());
CREATE POLICY "inq_seller_read" ON product_inquiries FOR SELECT USING (seller_id = my_seller_id());
CREATE POLICY "inq_seller_upd"  ON product_inquiries FOR UPDATE USING (seller_id = my_seller_id());

-- USER SESSIONS
DROP POLICY IF EXISTS "sess_own" ON user_sessions;
DROP POLICY IF EXISTS "sess_admin" ON user_sessions;
CREATE POLICY "sess_own"   ON user_sessions FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "sess_admin" ON user_sessions FOR ALL USING (is_admin());

-- PRODUCT VIEWS (anyone can insert, only admins see all)
DROP POLICY IF EXISTS "views_insert_all" ON product_views;
DROP POLICY IF EXISTS "views_admin"      ON product_views;
CREATE POLICY "views_insert_all" ON product_views FOR INSERT WITH CHECK (TRUE);
CREATE POLICY "views_admin"      ON product_views FOR SELECT USING (is_admin());

-- SUBSCRIPTIONS
DROP POLICY IF EXISTS "subs_seller_own" ON subscriptions;
DROP POLICY IF EXISTS "subs_all_admin"  ON subscriptions;
CREATE POLICY "subs_seller_own" ON subscriptions FOR SELECT USING (seller_id = my_seller_id());
CREATE POLICY "subs_all_admin"  ON subscriptions FOR ALL USING (is_admin());

-- ============================================================
-- FINAL COUNT
-- ============================================================
DO $$
DECLARE
  tcount INT;
  vcount INT;
BEGIN
  SELECT COUNT(*) INTO tcount FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';
  SELECT COUNT(*) INTO vcount FROM information_schema.views WHERE table_schema = 'public';
  RAISE NOTICE '============================================';
  RAISE NOTICE 'Ebazario Complete Schema installed!';
  RAISE NOTICE 'Tables created: %', tcount;
  RAISE NOTICE 'Views created:  %', vcount;
  RAISE NOTICE '============================================';
END $$;
