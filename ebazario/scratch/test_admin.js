const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL  = 'https://pzhrijavhyojgwagcfyf.supabase.co';
const SUPABASE_ANON = 'sb_publishable_AByi7Xlb02WCISNiVG5LIQ_13ydobW5';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON);

async function testAdmin() {
  console.log('Signing in as admin...');
  const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
    email: 'admin@ebazario.local',
    password: 'AdminPassword123!'
  });

  if (authError) {
    console.error('Auth failed:', authError.message);
    return;
  }

  console.log('Admin ID:', authData.user.id);

  // Check profile
  const { data: profile, error: pError } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', authData.user.id)
    .single();
  
  if (pError) console.error('Profile error:', pError.message);
  else console.log('Profile role:', profile.role);

  // Try to create a category
  console.log('Trying to insert category...');
  const { error: cError } = await supabase.from('categories').insert({
    slug: 'electronics',
    name: 'Electronics'
  });
  if (cError) console.error('Category insert error:', cError.message);
  else console.log('Category insert success!');
}

testAdmin();
