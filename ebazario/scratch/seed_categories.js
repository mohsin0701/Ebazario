const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL  = 'https://pzhrijavhyojgwagcfyf.supabase.co';
const SUPABASE_ANON = 'sb_publishable_AByi7Xlb02WCISNiVG5LIQ_13ydobW5';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON);

const categories = [
  { slug: 'electronics',  name: 'Electronics & Electrical', icon: '🔌', platform_margin_pct: 12.00, required_certifications: ['CE','FCC','RoHS'],      sort_order: 1 },
  { slug: 'machinery',    name: 'Machinery & Equipment',    icon: '⚙️', platform_margin_pct: 10.00, required_certifications: ['CE','ISO 9001'],         2: 2 },
  { slug: 'apparel',      name: 'Apparel & Textiles',       icon: '👗', platform_margin_pct: 18.00, required_certifications: ['OEKO-TEX'],              3: 3 },
  { slug: 'food-agri',    name: 'Food & Agriculture',       icon: '🌿',  platform_margin_pct: 8.00, required_certifications: ['HACCP'],                 4: 4 },
  { slug: 'chemicals',    name: 'Chemicals & Plastics',     icon: '⚗️',  platform_margin_pct: 9.00, required_certifications: ['REACH','SDS'],           5: 5 },
  { slug: 'construction', name: 'Construction',             icon: '🏗️', platform_margin_pct: 10.00, required_certifications: ['CE'],                    6: 6 },
  { slug: 'auto-parts',   name: 'Auto Parts',               icon: '🚗', platform_margin_pct: 14.00, required_certifications: ['ISO/TS 16949'],          7: 7 },
  { slug: 'healthcare',   name: 'Health & Medical',         icon: '🏥', platform_margin_pct: 15.00, required_certifications: ['FDA','CE','ISO 13485'],  8: 8 },
  { slug: 'furniture',    name: 'Furniture & Home',         icon: '🪑', platform_margin_pct: 16.00, required_certifications: [],                9: 9 },
  { slug: 'tools',        name: 'Tools & Hardware',         icon: '🔧', platform_margin_pct: 11.00, required_certifications: [],               10: 10 }
];

// Clean up the object (the 2:2 thing was a typo in my mapping)
const cleanCategories = categories.map((c, i) => {
    const obj = {
        slug: c.slug,
        name: c.name,
        icon: c.icon,
        platform_margin_pct: c.platform_margin_pct,
        required_certifications: c.required_certifications,
        sort_order: i + 1
    };
    return obj;
});

async function seedCategories() {
  console.log('Signing in as admin...');
  const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
    email: 'admin@ebazario.local',
    password: 'AdminPassword123!'
  });

  if (authError) {
    console.error('Auth failed:', authError.message);
    return;
  }

  console.log('Seeding categories...');
  const { data, error } = await supabase.from('categories').upsert(cleanCategories, { onConflict: 'slug' });
  if (error) {
    console.error('Error seeding categories:', error.message);
    if (error.message.includes('permission denied')) {
        console.log('RLS might be blocking inserts. Trying as Admin...');
    }
  } else {
    console.log('Categories seeded successfully!');
  }
}

seedCategories();
