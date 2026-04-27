const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL  = 'https://swygjpilcddqosjbzzfm.supabase.co';
const SUPABASE_ANON = 'sb_publishable_HnAYWFUXsQ5xtOSsQNrJrQ_yHxNay-5';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON);

async function createAccounts() {
  const users = [
    { email: 'admin@ebazario.local', password: 'AdminPassword123!', role: 'admin', meta: { first_name: 'Super', last_name: 'Admin' } },
    { email: 'seller@ebazario.local', password: 'SellerPassword123!', role: 'seller', meta: { company_name: 'Global Exports Ltd', country: 'Dubai, UAE' } },
    { email: 'buyer@ebazario.local', password: 'BuyerPassword123!', role: 'customer', meta: { first_name: 'John', last_name: 'Buyer' } }
  ];

  for (const u of users) {
    console.log(`Creating ${u.role}: ${u.email}...`);
    const { data, error } = await supabase.auth.signUp({
      email: u.email,
      password: u.password,
      options: { data: { role: u.role, ...u.meta } }
    });

    if (error) {
      if (error.message.includes('already registered')) {
        console.log(`- ${u.email} already exists.`);
      } else {
        console.error(`- Error: ${error.message}`);
      }
    } else {
      console.log(`- Success! Created ${u.email}`);
    }
  }
}

createAccounts();
