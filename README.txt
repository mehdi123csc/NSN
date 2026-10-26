NSN WORLD — 3D FASHION STORE STARTER (INDEPENDENT PROJECT)
==========================================================
This project is separate from every previous store/project. It is not connected to QMR.

WHAT IS INCLUDED
- index.html: responsive Arabic RTL storefront, cinematic entry, Three.js showroom, animated procedural avatar, male/female selection, clothing/color/size UI, product search/sort/categories, favorites, cart quantity controls, local persistence, demo checkout form, Algerian wilaya list, and local demo order history.
- supabase-schema.sql: starter schema for products, profiles, coupons, orders and order_items; restrictive RLS; server-side checkout RPC that reads authoritative prices and checks stock; order tracking RPC.
- supabase-client.js: optional Supabase JS v2 adapter for listing products, placing an order and tracking it.
- config.example.js: template for project URL and anon/publishable key.

IMPORTANT CURRENT LIMITS
- The current product catalog is sample data in index.html. Demo orders are saved only in this browser/device and are NOT sent to an admin.
- The 3D avatar is procedural geometry. It is not a realistic human model, a cloth simulation, body scanning, or accurate virtual fitting. Sizes are display choices only.
- No real payment gateway is connected. SQL currently models cash-on-delivery only; shipping is 0 until you define a shipping policy. Do not use this as a production store until reviewed and tested.
- Three.js and Supabase JS are loaded from public CDNs; an internet connection is required.

NEXT: CONNECT SUPABASE (WHEN YOU ARE READY)
1. Create a NEW Supabase project for NSN only. Do not paste these SQL commands into another store's project.
2. Open SQL Editor, review supabase-schema.sql, and run it in that new project.
3. Create an Auth user for the store owner. In SQL Editor, identify that user's auth.users.id and insert a profile, then grant admin role from the SQL Editor:
   insert into public.profiles (id, display_name, role) values ('AUTH_USER_UUID','NSN Admin','admin');
   (Replace AUTH_USER_UUID with the real Auth UUID. Never grant admin role through a public form.)
4. Copy config.example.js to config.js and replace SUPABASE_URL and SUPABASE_ANON_KEY with the project's Project URL and anon/publishable key.
5. Never use the service_role/secret key in browser JavaScript or GitHub Pages.
6. supabase-client.js is a connection adapter scaffold; index.html still uses demo catalog/checkout. The next integration step is to wire product loading and checkout UI to the adapter and then test all RLS/RPC policies.
7. Add real products with UUIDs, image URLs and stock in the products table. Ensure active=true only for products ready to sell.
8. Test: public product listing, admin login, create/update product, stock race conditions, valid/invalid coupons, order creation, order tracking, and that anonymous users cannot select customer/order data.
9. Before launch, get a security review of SQL/RLS, add rate limiting/abuse protection (e.g. Edge Function or gateway), privacy/terms, shipping rules, backup policy, monitoring, and proper payment integration if needed.

SECURITY NOTES
- Public/anon users should not be able to read order rows or customer personal details directly.
- Checkout prices are calculated server-side by nsn_place_order; never trust price/total sent by the browser.
- Do not expose the service_role key, admin credentials, or secrets in repository files.
- SQL is a starter implementation and should be reviewed and tested in a fresh project before production.

TEST THE FRONTEND
Open index.html via a local static server or deploy the folder to a NEW GitHub repository and enable GitHub Pages. The first page is a local demo until the Supabase integration is explicitly wired.
