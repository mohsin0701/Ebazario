const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL  = 'https://pzhrijavhyojgwagcfyf.supabase.co';
const SUPABASE_ANON = 'sb_publishable_AByi7Xlb02WCISNiVG5LIQ_13ydobW5';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON);

async function setupTestUsers() {
  const usersToCreate = [
    { email: 'admin@ebazario.local', password: 'AdminPassword123!', role: 'admin', firstName: 'Super', lastName: 'Admin' },
    { email: 'seller@ebazario.local', password: 'SellerPassword123!', role: 'seller', firstName: 'Demo', lastName: 'Seller' },
    { email: 'buyer@ebazario.local', password: 'BuyerPassword123!', role: 'customer', firstName: 'James', lastName: 'Buyer' }
  ];

  for (const u of usersToCreate) {
    console.log(`Setting up ${u.email}...`);
    // Attempt sign up. If they already exist, this typically fails silently or returns an existing user error, which is fine.
    const { data: authData, error: authError } = await supabase.auth.signUp({
      email: u.email,
      password: u.password,
      options: {
        data: {
          first_name: u.firstName,
          last_name: u.lastName,
          role: u.role
        }
      }
    });

    if (authError) {
      console.log(`Note for ${u.email}: ${authError.message}`);
    } else {
      console.log(`Created ${u.email}. User ID: ${authData?.user?.id}`);
    }

    // Force update the profile role directly to ensure it has the correct permissions.
    // The DB trigger may have already set it based on metadata, but just to be sure...
    const login = await supabase.auth.signInWithPassword({ email: u.email, password: u.password });
    if (login.data && login.data.user) {
        const { error: profileError } = await supabase
            .from('profiles')
            .update({ role: u.role })
            .eq('id', login.data.user.id);
        
        if(profileError) console.log("Profile update error:", profileError.message);
        else console.log(`Role '${u.role}' confirmed in profile for ${u.email}`);
    }
  }

  // List all users to confirm
  console.log('\n--- Current Roles ---');
  const { data: profiles } = await supabase.from('profiles').select('email, role, first_name');
  if (profiles) {
    profiles.forEach(p => console.log(`Email: ${p.email} | Role: ${p.role}`));
  }
}

setupTestUsers();
