const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL  = 'https://swygjpilcddqosjbzzfm.supabase.co';
const SUPABASE_ANON = 'sb_publishable_HnAYWFUXsQ5xtOSsQNrJrQ_yHxNay-5';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON);

async function checkProject() {
  console.log('Checking connection to:', SUPABASE_URL);
  
  // 1. Check if we can reach the profiles table
  const { count: profilesCount, error: pError } = await supabase
    .from('profiles')
    .select('*', { count: 'exact', head: true });
  
  if (pError) {
    console.error('Error fetching profiles:', pError.message);
    console.log('This might be due to missing table or invalid keys.');
  } else {
    console.log('Profiles table exists. Count:', profilesCount);
  }

  // 3. Check if products exist
  const { count: productsCount, error: prError } = await supabase
    .from('products')
    .select('*', { count: 'exact', head: true });
  
  if (prError) {
    console.error('Error fetching products:', prError.message);
  } else {
    console.log('Products found:', productsCount);
  }
}

checkProject();
