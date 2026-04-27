const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL  = 'https://pzhrijavhyojgwagcfyf.supabase.co';
const SUPABASE_ANON = 'sb_publishable_AByi7Xlb02WCISNiVG5LIQ_13ydobW5';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON);

async function testInsert() {
  const { data, error } = await supabase.from('categories').insert({
    slug: 'test-cat',
    name: 'Test Category',
    sort_order: 99
  });
  if (error) console.error('Insert error:', error.message);
  else console.log('Insert success:', data);
}

testInsert();
