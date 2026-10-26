/*
 * NSN Supabase adapter scaffold.
 * This file deliberately does not connect until config.js exists and contains real values.
 * Include from a page with: <script type="module" src="supabase-client.js"></script>
 * Keep all security enforcement in Postgres RLS/RPC; browser checks are not security controls.
 */
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

let client = null;
export async function getSupabase() {
  if (client) return client;
  let cfg;
  try { ({ NSN_CONFIG: cfg } = await import('./config.js')); }
  catch { throw new Error('Supabase is not configured yet. Copy config.example.js to config.js and add your project URL and anon/publishable key.'); }
  if (!cfg?.SUPABASE_URL || !cfg?.SUPABASE_ANON_KEY || cfg.SUPABASE_URL.includes('YOUR_PROJECT_ID') || cfg.SUPABASE_ANON_KEY.includes('YOUR_')) {
    throw new Error('Please fill in SUPABASE_URL and SUPABASE_ANON_KEY in config.js.');
  }
  client = createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON_KEY, {
    auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
  });
  return client;
}

export async function getActiveProducts({ category = null, search = '', limit = 60 } = {}) {
  const supabase = await getSupabase();
  let query = supabase.from('products').select('id,slug,name_ar,name_fr,description_ar,description_fr,price,currency,category,images,stock_quantity,active').eq('active', true).order('created_at', { ascending: false }).limit(Math.min(Math.max(limit, 1), 100));
  if (category) query = query.eq('category', category);
  if (search.trim()) query = query.or(`name_ar.ilike.%${search.trim()}%,name_fr.ilike.%${search.trim()}%`);
  const { data, error } = await query;
  if (error) throw error;
  return data ?? [];
}

/** items must be [{product_id: UUID, quantity: integer}]. Prices are re-read and calculated server-side. */
export async function placeOrder({ customer, items, couponCode = null }) {
  const supabase = await getSupabase();
  const { data, error } = await supabase.rpc('nsn_place_order', {
    p_customer: customer,
    p_items: items,
    p_coupon_code: couponCode
  });
  if (error) throw error;
  return data;
}

/** The SQL RPC should return only minimal tracking data after checking order code + phone. */
export async function trackOrder(orderCode, phone) {
  const supabase = await getSupabase();
  const { data, error } = await supabase.rpc('nsn_track_order', {
    p_order_code: orderCode,
    p_phone: phone
  });
  if (error) throw error;
  return data;
}
