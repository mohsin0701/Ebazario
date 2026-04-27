const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL  = 'https://swygjpilcddqosjbzzfm.supabase.co';
const SUPABASE_ANON = 'sb_publishable_HnAYWFUXsQ5xtOSsQNrJrQ_yHxNay-5';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON);

async function testOldProject() {
  const credentials = [
    { name: 'Super Admin', email: 'admin@ebazario.local', password: 'AdminPassword123!', role: 'admin' },
  ];

  console.log('--- Testing OLD project (from js/supabase.js) ---');
  
  for (const cred of credentials) {
    const { data, error } = await supabase.auth.signInWithPassword({
      email: cred.email,
      password: cred.password
    });

    if (error) {
      console.error(`❌ ${cred.name} (${cred.email}) FAILED: ${error.message}`);
    } else {
      console.log(`✅ ${cred.name} (${cred.email}) WORKING!`);
      await supabase.auth.signOut();
    }
  }
}

testOldProject();
