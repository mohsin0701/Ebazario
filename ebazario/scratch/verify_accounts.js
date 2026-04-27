const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL  = 'https://pzhrijavhyojgwagcfyf.supabase.co';
const SUPABASE_ANON = 'sb_publishable_AByi7Xlb02WCISNiVG5LIQ_13ydobW5';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON);

async function verifyCredentials() {
  const credentials = [
    { name: 'Super Admin', email: 'admin@ebazario.local', password: 'AdminPassword123!', role: 'admin' },
    { name: 'Seller Account', email: 'seller@ebazario.local', password: 'SellerPassword123!', role: 'seller' },
    { name: 'User Account (Buyer)', email: 'buyer@ebazario.local', password: 'BuyerPassword123!', role: 'customer' }
  ];

  console.log('--- Verifying Credentials ---');
  
  for (const cred of credentials) {
    const { data, error } = await supabase.auth.signInWithPassword({
      email: cred.email,
      password: cred.password
    });

    if (error) {
      console.error(`❌ ${cred.name} (${cred.email}) FAILED: ${error.message}`);
    } else {
      // Check role in profile to be double sure
      const { data: profile } = await supabase
        .from('profiles')
        .select('role')
        .eq('id', data.user.id)
        .single();
      
      console.log(`✅ ${cred.name} (${cred.email}) WORKING! Role: ${profile?.role || 'unknown'}`);
      await supabase.auth.signOut();
    }
  }
}

verifyCredentials();
