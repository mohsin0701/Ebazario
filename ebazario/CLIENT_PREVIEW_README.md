# Ebazario Trading Platform - Client Preview

This repository contains the Ebazario B2B Marketplace front-end, fully integrated with Supabase.

## Platform Access

The project has been prepared with full dashboards for all roles. You can access them via the following links and credentials once the platform is hosted.

### 1. Super Admin Dashboard
**Link:** `/pages/admin-dashboard.html` or `/pages/login-admin.html`
- **Email:** `admin@ebazario.local` (or your configured admin email in Supabase)
- **Password:** `AdminPassword123!` 
*(Note: To create an admin, sign up normally then change the role to 'admin' in the Supabase `profiles` table).*

### 2. Seller Dashboard
**Link:** `/pages/seller-dashboard.html` or `/pages/login-seller.html`
- **Email:** `seller@ebazario.local`
- **Password:** `SellerPassword123!`

### 3. Customer (Buyer) Dashboard
**Link:** `/pages/customer-dashboard.html` or `/pages/login-customer.html`
- **Email:** `buyer@ebazario.local`
- **Password:** `BuyerPassword123!`

---

## Deployment Instructions

To share this immediately with your client, you can deploy it for free using **Netlify Drop** or **Surge**.

### Option A: Quick Share via Surge (Command Line)
If you have Node.js installed, simply open your terminal in the project folder and run:
```bash
npx surge . ebazario-test-2026.surge.sh
```
(It will ask you to set an email and password the first time you use it). 
Your client can then visit: `https://ebazario-test-2026.surge.sh`

### Option B: Quick Share via Netlify Drop (Browser)
1. Go to [https://app.netlify.com/drop](https://app.netlify.com/drop)
2. Drag and drop the `ebazario` folder directly into the browser.
3. Netlify will generate a live public URL instantly that you can send to you client.

---

## Notes for the Client
- **Dynamic Content:** Products on the Homepage and the Electronics Category page are dynamically loaded from the Supabase backend.
- **Authentication:** Sign-up, Sign-in, and Role-Based Access Control (Admin vs Seller vs Customer) are enforced using Supabase Auth + Row Level Security (RLS). Ensure your Supabase keys in `js/supabase.js` are pointing to the live project with the initialized `supabase_complete.sql` schema.
