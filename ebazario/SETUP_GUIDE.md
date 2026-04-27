# Ebazario Trading — Supabase Setup Guide

## Step 1: Create Supabase Project
1. Go to https://supabase.com → Sign up / Log in
2. Click **"New Project"**
3. Set **Project Name**: `ebazario-trading`
4. Set a strong **Database Password** (save it!)
5. Select a **Region** closest to your users
6. Click **"Create new project"** — wait ~2 minutes

---

## Step 2: Run the Database Schema

1. In your Supabase project → **SQL Editor** (left sidebar)
2. Click **"New query"**
3. Copy the entire contents of `supabase_schema.sql`
4. Paste into the editor
5. Click **"Run"** (▶ button)
6. You should see: "Success. No rows returned."

This creates **21 tables**, all enums, RLS policies, triggers, and seeds categories + shipping rates.

---

## Step 3: Get Your API Keys

1. Supabase Dashboard → **Settings** (gear icon) → **API**
2. Copy:
   - **Project URL** (looks like: `https://abcdefghijkl.supabase.co`)
   - **anon / public key** (starts with `eyJ...`)

---

## Step 4: Configure the App

Open `js/supabase.js` and replace lines 7–8:

```javascript
const SUPABASE_URL  = 'https://YOUR-PROJECT-ID.supabase.co';
const SUPABASE_ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
```

---

## Step 5: Create Storage Buckets

1. Supabase Dashboard → **Storage** → **New bucket**

Create these 3 buckets:

| Bucket Name       | Public | Purpose                    |
|-------------------|--------|----------------------------|
| `product-images`  | ✅ Yes  | Product photos             |
| `seller-documents`| ❌ No   | CE, FDA, ISO certificates  |
| `avatars`         | ✅ Yes  | Profile photos             |

---

## Step 6: Enable Email Auth

1. Supabase → **Authentication** → **Providers**
2. **Email** should already be enabled
3. Optional: Enable **Google OAuth**:
   - Create Google OAuth app at console.cloud.google.com
   - Add Client ID + Secret in Supabase → Auth → Google

---

## Step 7: Enable Realtime

1. Supabase → **Database** → **Replication**
2. Enable for these tables:
   - `orders`
   - `notifications`  
   - `disputes`

---

## Step 8: Create the First Admin User

Run this in **SQL Editor** after your first user signs up:

```sql
-- Replace with the email that signed up
UPDATE profiles 
SET role = 'admin' 
WHERE email = 'admin@yourcompany.com';
```

Or use the Supabase Dashboard → **Table Editor** → `profiles` → edit the row.

---

## Step 9: Set Up Edge Functions (Optional, for production)

For email notifications, create a Supabase Edge Function:

```bash
supabase functions new send-notification
```

This handles sending emails when:
- Products are approved/rejected
- Orders are placed
- Disputes are filed

---

## Table Overview

| Table                | Purpose                          |
|----------------------|----------------------------------|
| `profiles`           | All users (extends auth.users)   |
| `customer_profiles`  | Buyer-specific data              |
| `seller_profiles`    | Seller accounts & status         |
| `products`           | All product listings             |
| `product_price_tiers`| MOQ-based pricing tiers          |
| `categories`         | 10 product categories            |
| `orders`             | All orders with escrow           |
| `seller_documents`   | CE/FDA/ISO uploaded certs        |
| `addresses`          | Shipping addresses               |
| `payment_methods`    | Saved cards / bank details       |
| `rfqs`               | Buyer RFQ submissions            |
| `rfq_quotes`         | Seller quotes on RFQs            |
| `reviews`            | Buyer product reviews            |
| `disputes`           | Trade disputes                   |
| `wishlists`          | Saved products                   |
| `seller_payouts`     | Monthly payout processing        |
| `shipping_rates`     | Per-destination freight rates    |
| `platform_settings`  | Admin-configurable platform vars |
| `notifications`      | In-app notifications             |
| `audit_log`          | Admin action audit trail         |
| `subscriptions`      | Seller plan subscriptions        |

---

## Development Tips

- Use `supabase start` locally with Supabase CLI for local dev
- All tables have RLS — test with different user roles
- The `audit_log` table records every admin action automatically
- `order_number` (EB-XXXXX) and `rfq_number` (RQ-YYYY-XXXX) are auto-generated via triggers

---

## Support

- Supabase Docs: https://supabase.com/docs
- JS Client Docs: https://supabase.com/docs/reference/javascript
