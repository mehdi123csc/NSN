-- NSN WORLD - initial Supabase schema (review before production deployment)
-- Run in Supabase SQL Editor in a NEW NSN project, not in any other store project.
-- This schema intentionally uses server-side order pricing and restrictive RLS.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  role text not null default 'customer' check (role in ('customer','admin')),
  created_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name_ar text not null,
  name_fr text,
  description_ar text not null default '',
  description_fr text not null default '',
  category text not null,
  price numeric(12,2) not null check (price >= 0),
  currency text not null default 'DZD' check (currency ~ '^[A-Z]{3}$'),
  images jsonb not null default '[]'::jsonb check (jsonb_typeof(images) = 'array' and jsonb_array_length(images) <= 8),
  sizes jsonb not null default '[]'::jsonb check (jsonb_typeof(sizes) = 'array'),
  colors jsonb not null default '[]'::jsonb check (jsonb_typeof(colors) = 'array'),
  stock_quantity integer not null default 0 check (stock_quantity >= 0),
  active boolean not null default false,
  featured boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.coupons (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  discount_type text not null check (discount_type in ('percent','fixed')),
  discount_value numeric(12,2) not null check (discount_value > 0),
  min_order numeric(12,2) not null default 0 check (min_order >= 0),
  max_uses integer check (max_uses is null or max_uses > 0),
  used_count integer not null default 0 check (used_count >= 0),
  active boolean not null default true,
  starts_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  check (discount_type <> 'percent' or discount_value <= 100)
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_code text unique not null,
  tracking_token text not null,
  customer_name text not null check (char_length(customer_name) between 2 and 100),
  phone text not null check (char_length(phone) between 8 and 24),
  wilaya text not null,
  municipality text not null,
  address text not null,
  notes text not null default '',
  status text not null default 'new' check (status in ('new','confirmed','processing','shipped','delivered','cancelled')),
  payment_method text not null default 'cash_on_delivery' check (payment_method in ('cash_on_delivery')),
  currency text not null default 'DZD' check (currency ~ '^[A-Z]{3}$'),
  subtotal numeric(12,2) not null check (subtotal >= 0),
  discount numeric(12,2) not null default 0 check (discount >= 0),
  shipping_cost numeric(12,2) not null default 0 check (shipping_cost >= 0),
  total numeric(12,2) not null check (total >= 0),
  coupon_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  product_name text not null,
  unit_price numeric(12,2) not null check (unit_price >= 0),
  quantity integer not null check (quantity between 1 and 99),
  line_total numeric(12,2) not null check (line_total >= 0),
  selected_size text,
  selected_color text,
  created_at timestamptz not null default now()
);

create index if not exists products_active_category_idx on public.products(active, category);
create index if not exists products_created_at_idx on public.products(created_at desc);
create index if not exists orders_created_at_idx on public.orders(created_at desc);
create index if not exists orders_status_idx on public.orders(status);
create index if not exists order_items_order_id_idx on public.order_items(order_id);

create or replace function public.nsn_is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'admin'
  );
$$;
revoke all on function public.nsn_is_admin() from public;
grant execute on function public.nsn_is_admin() to anon, authenticated;

alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.coupons enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

-- Automatically create a least-privilege customer profile when Auth users sign up.
create or replace function public.nsn_handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(id, display_name, role)
  values (new.id, left(coalesce(new.raw_user_meta_data->>'display_name',''),100), 'customer')
  on conflict (id) do nothing;
  return new;
end;
$$;
drop trigger if exists nsn_on_auth_user_created on auth.users;
create trigger nsn_on_auth_user_created after insert on auth.users
for each row execute function public.nsn_handle_new_user();

-- Public can only read active product listings; only admins can mutate catalog.
drop policy if exists "Public reads active NSN products" on public.products;
create policy "Public reads active NSN products" on public.products for select to anon, authenticated using (active = true or public.nsn_is_admin());
drop policy if exists "Admins manage NSN products" on public.products;
create policy "Admins manage NSN products" on public.products for all to authenticated using (public.nsn_is_admin()) with check (public.nsn_is_admin());

-- Profiles are private; role is not writable by customers. The signup trigger creates customer profiles.
drop policy if exists "Users read own profile or admin" on public.profiles;
create policy "Users read own profile or admin" on public.profiles for select to authenticated using (id = (select auth.uid()) or public.nsn_is_admin());
drop policy if exists "Admins manage profiles" on public.profiles;
create policy "Admins manage profiles" on public.profiles for all to authenticated using (public.nsn_is_admin()) with check (public.nsn_is_admin());

-- Never expose raw order records or order items to anonymous visitors.
drop policy if exists "Admins manage NSN coupons" on public.coupons;
create policy "Admins manage NSN coupons" on public.coupons for all to authenticated using (public.nsn_is_admin()) with check (public.nsn_is_admin());
drop policy if exists "Admins read NSN orders" on public.orders;
create policy "Admins read NSN orders" on public.orders for select to authenticated using (public.nsn_is_admin());
drop policy if exists "Admins update NSN orders" on public.orders;
create policy "Admins update NSN orders" on public.orders for update to authenticated using (public.nsn_is_admin()) with check (public.nsn_is_admin());
drop policy if exists "Admins read NSN order items" on public.order_items;
create policy "Admins read NSN order items" on public.order_items for select to authenticated using (public.nsn_is_admin());
drop policy if exists "Admins manage NSN order items" on public.order_items;
create policy "Admins manage NSN order items" on public.order_items for all to authenticated using (public.nsn_is_admin()) with check (public.nsn_is_admin());

-- Coupon validation and order placement happen in a SECURITY DEFINER function.
-- Anonymous clients cannot insert/edit orders directly or choose their own prices.
create or replace function public.nsn_place_order(
  p_customer jsonb,
  p_items jsonb,
  p_coupon_code text default null
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_order_id uuid;
  v_order_code text;
  v_tracking_token text;
  v_name text;
  v_phone text;
  v_wilaya text;
  v_municipality text;
  v_address text;
  v_notes text;
  v_subtotal numeric(12,2) := 0;
  v_discount numeric(12,2) := 0;
  v_total numeric(12,2) := 0;
  v_coupon public.coupons%rowtype;
  v_item jsonb;
  v_product public.products%rowtype;
  v_qty integer;
  v_line numeric(12,2);
  v_count integer := 0;
begin
  if jsonb_typeof(p_customer) <> 'object' or jsonb_typeof(p_items) <> 'array' then
    raise exception 'Invalid order payload';
  end if;
  if jsonb_array_length(p_items) < 1 or jsonb_array_length(p_items) > 30 then
    raise exception 'Cart must contain between 1 and 30 line items';
  end if;
  v_name := btrim(coalesce(p_customer->>'customer_name',''));
  v_phone := btrim(coalesce(p_customer->>'phone',''));
  v_wilaya := btrim(coalesce(p_customer->>'wilaya',''));
  v_municipality := btrim(coalesce(p_customer->>'municipality',''));
  v_address := btrim(coalesce(p_customer->>'address',''));
  v_notes := left(coalesce(p_customer->>'notes',''),500);
  if char_length(v_name) not between 2 and 100 or char_length(v_phone) not between 8 and 24
     or v_wilaya = '' or v_municipality = '' or char_length(v_address) not between 4 and 250 then
    raise exception 'Please provide valid customer and delivery details';
  end if;

  -- Lock product rows to avoid two simultaneous checkouts overselling the same stock.
  for v_item in select value from jsonb_array_elements(p_items) loop
    v_count := v_count + 1;
    if coalesce(v_item->>'product_id','') = '' then
      raise exception 'Every item must contain a product_id';
    end if;
    if coalesce(v_item->>'quantity','') !~ '^[0-9]+$' then
      raise exception 'Invalid quantity';
    end if;
    v_qty := (v_item->>'quantity')::integer;
    if v_qty < 1 or v_qty > 99 then raise exception 'Quantity must be between 1 and 99'; end if;
    select * into v_product from public.products where id = (v_item->>'product_id')::uuid and active = true for update;
    if not found then raise exception 'A product is unavailable'; end if;
    if v_product.stock_quantity < v_qty then raise exception 'Insufficient stock for %', v_product.name_ar; end if;
    v_line := v_product.price * v_qty;
    v_subtotal := v_subtotal + v_line;
  end loop;

  if p_coupon_code is not null and btrim(p_coupon_code) <> '' then
    select * into v_coupon from public.coupons
      where upper(code) = upper(btrim(p_coupon_code)) and active = true
        and (starts_at is null or starts_at <= now()) and (expires_at is null or expires_at >= now())
        and (max_uses is null or used_count < max_uses)
      for update;
    if found and v_subtotal >= v_coupon.min_order then
      if v_coupon.discount_type = 'percent' then v_discount := round(v_subtotal * v_coupon.discount_value / 100, 2);
      else v_discount := least(v_subtotal, v_coupon.discount_value); end if;
    else
      raise exception 'Coupon is invalid, expired, or does not meet the minimum order';
    end if;
  end if;
  v_total := greatest(0, v_subtotal - v_discount);
  v_order_code := 'NSN-' || upper(substr(encode(gen_random_bytes(6),'hex'),1,10));
  v_tracking_token := encode(gen_random_bytes(24),'hex');
  insert into public.orders(order_code,tracking_token,customer_name,phone,wilaya,municipality,address,notes,subtotal,discount,total,coupon_code)
  values(v_order_code,v_tracking_token,v_name,v_phone,v_wilaya,v_municipality,v_address,v_notes,v_subtotal,v_discount,v_total,nullif(upper(btrim(coalesce(p_coupon_code,''))),''))
  returning id into v_order_id;

  for v_item in select value from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'quantity')::integer;
    select * into v_product from public.products where id = (v_item->>'product_id')::uuid and active = true for update;
    v_line := v_product.price * v_qty;
    insert into public.order_items(order_id,product_id,product_name,unit_price,quantity,line_total,selected_size,selected_color)
    values(v_order_id,v_product.id,v_product.name_ar,v_product.price,v_qty,v_line,left(coalesce(v_item->>'size',''),20),left(coalesce(v_item->>'color',''),40));
    update public.products set stock_quantity = stock_quantity - v_qty, updated_at = now() where id = v_product.id;
  end loop;
  if p_coupon_code is not null and btrim(p_coupon_code) <> '' then
    update public.coupons set used_count = used_count + 1 where id = v_coupon.id;
  end if;
  return jsonb_build_object('order_code',v_order_code,'tracking_token',v_tracking_token,'total',v_total,'currency','DZD','status','new');
end;
$$;

create or replace function public.nsn_track_order(p_order_code text, p_phone text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_order public.orders%rowtype; v_lines jsonb;
begin
  select * into v_order from public.orders
    where upper(order_code) = upper(btrim(p_order_code)) and regexp_replace(phone,'[^0-9+]','','g') = regexp_replace(btrim(p_phone),'[^0-9+]','','g');
  if not found then raise exception 'Order not found. Check the order code and phone number.'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('name',product_name,'quantity',quantity,'line_total',line_total)),'[]'::jsonb)
    into v_lines from public.order_items where order_id = v_order.id;
  return jsonb_build_object('order_code',v_order.order_code,'status',v_order.status,'created_at',v_order.created_at,'total',v_order.total,'currency',v_order.currency,'items',v_lines);
end;
$$;

revoke all on function public.nsn_place_order(jsonb,jsonb,text) from public;
revoke all on function public.nsn_track_order(text,text) from public;
grant execute on function public.nsn_place_order(jsonb,jsonb,text) to anon, authenticated;
grant execute on function public.nsn_track_order(text,text) to anon, authenticated;

-- No direct client inserts/updates/deletes on order tables. RPC owns checkout.
revoke all on public.orders from anon, authenticated;
revoke all on public.order_items from anon, authenticated;
grant select, update on public.orders to authenticated;
grant select on public.order_items to authenticated;
-- Products need public select and admin writes; table-level privileges are further constrained by RLS.
grant select on public.products to anon, authenticated;
grant insert, update, delete on public.products to authenticated;
grant select on public.coupons to authenticated;
grant all on public.coupons to authenticated;
grant select on public.profiles to authenticated;
grant update (display_name) on public.profiles to authenticated;

-- Create an admin safely after signing up that user through Supabase Auth:
-- update public.profiles set role = 'admin' where id = 'AUTH_USER_UUID';
-- Only run that statement from the SQL Editor as project owner, never expose admin role editing to clients.
