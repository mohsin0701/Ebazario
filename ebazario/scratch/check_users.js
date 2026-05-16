const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://swygjpilcddqosjbzzfm.supabase.co';
const SUPABASE_KEY = 'sb_publishable_HnAYWFUXsQ5xtOSsQNrJrQ_yHxNay-5'; // Note: This might be the anon key

const sb = createClient(SUPABASE_URL, SUPABASE_KEY);

async function checkUsers() {
  console.log('--- Checking Profiles ---');
  const { data, error } = await sb.from('profiles').select('*');
  if (error) {
    console.error('Error fetching profiles:', error);
  } else {
    console.log('Profiles found:', data.length);
    data.forEach(p => {
      console.log(`- ${p.email} | Role: ${p.role} | ID: ${p.id}`);
    });
  }
}

checkUsers();
