const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL  = 'https://swygjpilcddqosjbzzfm.supabase.co';
const SUPABASE_ANON = 'sb_publishable_HnAYWFUXsQ5xtOSsQNrJrQ_yHxNay-5';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON);

async function testSimpleSignup() {
  console.log('Trying simple signup (no metadata)...');
  const { data, error } = await supabase.auth.signUp({
    email: 'test' + Math.random() + '@example.com',
    password: 'TestPassword123!'
  });

  if (error) {
    console.error('Error:', error.message);
  } else {
    console.log('Success! User ID:', data.user.id);
  }
}

testSimpleSignup();
