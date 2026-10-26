// Copy to config.js only when ready to connect Supabase.
// The anon/publishable key is intended for browser use when RLS is configured.
// NEVER put a service_role/secret key in this file or in GitHub Pages.
export const NSN_CONFIG = {
  SUPABASE_URL: 'https://YOUR_PROJECT_ID.supabase.co',
  SUPABASE_ANON_KEY: 'YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY',
  STORE_NAME: 'NSN WORLD',
  DEFAULT_CURRENCY: 'DZD',
  DEFAULT_LOCALE: 'ar-DZ'
};
