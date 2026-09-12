-- ZOMA Smart Card - complete Supabase schema
-- Run this in a new Supabase project, or compare/merge with an existing ZOMA database.
create extension if not exists pgcrypto;

do $$ begin create type public.customer_status as enum ('active','suspended','deleted'); exception when duplicate_object then null; end $$;
do $$ begin create type public.card_status as enum ('unactivated','active','suspended'); exception when duplicate_object then null; end $$;
do $$ begin create type public.order_status as enum ('pending','confirmed','preparing','ready','shipped','delivered','rejected'); exception when duplicate_object then null; end $$;
do $$ begin create type public.admin_role as enum ('owner','manager','support'); exception when duplicate_object then null; end $$;

create table if not exists public.admins(id uuid primary key references auth.users(id) on delete cascade,username text unique not null,full_name text,role public.admin_role not null default 'support',created_at timestamptz not null default now());
create table if not exists public.customers(id uuid primary key references auth.users(id) on delete cascade,phone text unique not null,full_name text not null,status public.customer_status not null default 'active',created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table if not exists public.designs(id uuid primary key default gen_random_uuid(),design_code text unique not null,name text not null,preview_url text,price numeric(12,2) not null default 0,nfc_available boolean not null default true,qr_available boolean not null default false,is_available boolean not null default true,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
alter table public.designs add column if not exists design_type text not null default 'image';
alter table public.designs add column if not exists template_config jsonb not null default '{}'::jsonb;
alter table public.designs add column if not exists preview_url text;
create table if not exists public.orders(id uuid primary key default gen_random_uuid(),order_number text unique not null,customer_id uuid not null references public.customers(id) on delete cascade,design_id uuid references public.designs(id) on delete set null,total_price numeric(12,2) not null default 0,status public.order_status not null default 'pending',customer_name text,phone text,shipping_governorate text,shipping_city text,shipping_address text,customer_notes text,admin_notes text,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table if not exists public.cards(id uuid primary key default gen_random_uuid(),card_id text unique not null,customer_id uuid not null references public.customers(id) on delete cascade,order_id uuid references public.orders(id) on delete set null,public_url text unique not null,status public.card_status not null default 'unactivated',created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table if not exists public.profiles(id uuid primary key default gen_random_uuid(),card_id uuid unique not null references public.cards(id) on delete cascade,full_name text,photo_url text,facebook_url text,tiktok_url text,whatsapp_1 text,whatsapp_2 text,show_whatsapp_2 boolean not null default false,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table if not exists public.nfc_writes(id uuid primary key default gen_random_uuid(),card_id uuid references public.cards(id) on delete set null,order_id uuid references public.orders(id) on delete set null,admin_id uuid references public.admins(id) on delete set null,status text not null default 'success',written_url text,created_at timestamptz not null default now());
create table if not exists public.analytics(id uuid primary key default gen_random_uuid(),card_id uuid references public.cards(id) on delete cascade,event_type text not null,source text,metadata jsonb,created_at timestamptz not null default now());
create table if not exists public.notifications(id uuid primary key default gen_random_uuid(),customer_id uuid references public.customers(id) on delete cascade,title text,body text,is_read boolean not null default false,created_at timestamptz not null default now());
create table if not exists public.messages(id uuid primary key default gen_random_uuid(),customer_id uuid references public.customers(id) on delete cascade,subject text,body text,status text not null default 'open',admin_reply text,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table if not exists public.audit_logs(id uuid primary key default gen_random_uuid(),admin_id uuid references public.admins(id) on delete set null,action text not null,entity_type text,entity_id uuid,metadata jsonb,created_at timestamptz not null default now());
create table if not exists public.admin_permissions(id uuid primary key default gen_random_uuid(),admin_id uuid not null references public.admins(id) on delete cascade,section text not null,can_view boolean not null default true,can_edit boolean not null default false,unique(admin_id,section));

alter table public.customers add column if not exists phone text;
alter table public.customers add column if not exists full_name text;
alter table public.customers add column if not exists status public.customer_status not null default 'active';
alter table public.orders add column if not exists order_number text;
alter table public.orders add column if not exists customer_id uuid references public.customers(id) on delete cascade;
alter table public.orders add column if not exists design_id uuid references public.designs(id) on delete set null;
alter table public.orders add column if not exists total_price numeric(12,2) not null default 0;
alter table public.orders add column if not exists status public.order_status not null default 'pending';
alter table public.orders add column if not exists customer_name text;
alter table public.orders add column if not exists phone text;
alter table public.orders add column if not exists shipping_governorate text;
alter table public.orders add column if not exists shipping_city text;
alter table public.orders add column if not exists shipping_address text;
alter table public.orders add column if not exists customer_notes text;
alter table public.orders add column if not exists admin_notes text;
alter table public.cards add column if not exists card_id text;
alter table public.cards add column if not exists customer_id uuid references public.customers(id) on delete cascade;
alter table public.cards add column if not exists order_id uuid references public.orders(id) on delete set null;
alter table public.cards add column if not exists public_url text;
alter table public.cards add column if not exists status public.card_status not null default 'unactivated';

alter table public.profiles add column if not exists full_name text;alter table public.profiles add column if not exists photo_url text;alter table public.profiles add column if not exists facebook_url text;alter table public.profiles add column if not exists tiktok_url text;alter table public.profiles add column if not exists whatsapp_1 text;alter table public.profiles add column if not exists whatsapp_2 text;alter table public.profiles add column if not exists show_whatsapp_2 boolean not null default false;

create or replace function public.set_updated_at() returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end $$;

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
  if coalesce(new.raw_user_meta_data->>'phone','') <> '' then
    insert into public.customers(id,phone,full_name) values(new.id,new.raw_user_meta_data->>'phone',coalesce(new.raw_user_meta_data->>'full_name','ZOMA User')) on conflict(id) do update set phone=excluded.phone,full_name=excluded.full_name;
  end if;
  return new;
end $$;
drop trigger if exists on_auth_user_created_zoma on auth.users;
create trigger on_auth_user_created_zoma after insert on auth.users for each row execute function public.handle_new_user();
drop trigger if exists trg_customers_updated on public.customers;create trigger trg_customers_updated before update on public.customers for each row execute function public.set_updated_at();
drop trigger if exists trg_designs_updated on public.designs;create trigger trg_designs_updated before update on public.designs for each row execute function public.set_updated_at();
drop trigger if exists trg_orders_updated on public.orders;create trigger trg_orders_updated before update on public.orders for each row execute function public.set_updated_at();
drop trigger if exists trg_cards_updated on public.cards;create trigger trg_cards_updated before update on public.cards for each row execute function public.set_updated_at();
drop trigger if exists trg_profiles_updated on public.profiles;create trigger trg_profiles_updated before update on public.profiles for each row execute function public.set_updated_at();
drop trigger if exists trg_messages_updated on public.messages;create trigger trg_messages_updated before update on public.messages for each row execute function public.set_updated_at();

create index if not exists idx_orders_customer on public.orders(customer_id);create index if not exists idx_orders_status on public.orders(status);create index if not exists idx_cards_customer on public.cards(customer_id);create index if not exists idx_cards_card_id on public.cards(card_id);create index if not exists idx_analytics_card on public.analytics(card_id);create index if not exists idx_messages_customer on public.messages(customer_id);

insert into public.designs(design_code,name,price,nfc_available,qr_available,is_available,design_type,template_config) values
('DES-001','Black Luxury',350,true,true,true,'template','{"background":"#0b0b0d","accent":"#d4af37","text":"#ffffff","layout":"classic"}'::jsonb),
('DES-002','Gold Premium',450,true,true,true,'template','{"background":"#111111","accent":"#f0c75e","text":"#ffffff","layout":"center"}'::jsonb),
('DES-003','Business Blue',400,true,true,true,'template','{"background":"#07111f","accent":"#3b82f6","text":"#ffffff","layout":"business"}'::jsonb)
on conflict(design_code) do update set name=excluded.name,price=excluded.price,nfc_available=excluded.nfc_available,qr_available=excluded.qr_available,design_type=excluded.design_type,template_config=excluded.template_config;

create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.admins where id=auth.uid()); $$;
create or replace function public.admin_role_value() returns text language sql stable security definer set search_path=public as $$ select role::text from public.admins where id=auth.uid(); $$;

create or replace function public.zoma_get_login_email(p_identity text) returns text language plpgsql security definer set search_path=public as $$
declare p text; result text;
begin
 p:=trim(p_identity);
 if p like '%@%' then return lower(p); end if;
 select 'phone_'||regexp_replace(c.phone,'[^0-9]','','g')||'@zoma.local' into result from public.customers c where regexp_replace(c.phone,'[^0-9]','','g')=regexp_replace(p,'[^0-9]','','g') limit 1;
 if result is not null then return result; end if;
 select 'phone_'||regexp_replace(c.phone,'[^0-9]','','g')||'@zoma.local' into result from public.cards ca join public.customers c on c.id=ca.customer_id where ca.card_id=p and ca.status<>'suspended' limit 1;
 return result;
end $$;
grant execute on function public.zoma_get_login_email(text) to anon,authenticated;

drop function if exists public.zoma_get_public_card(text);
create function public.zoma_get_public_card(p_card_id text)
returns table(card_uuid uuid,card_id text,status public.card_status,full_name text,photo_url text,facebook_url text,tiktok_url text,whatsapp_1 text,whatsapp_2 text,show_whatsapp_2 boolean,design_name text,design_code text,design_type text,template_config jsonb)
language sql stable security definer set search_path=public as $$
 select c.id,c.card_id,c.status,p.full_name,p.photo_url,p.facebook_url,p.tiktok_url,p.whatsapp_1,p.whatsapp_2,p.show_whatsapp_2,d.name,d.design_code,d.design_type,d.template_config
 from public.cards as c
 left join public.profiles as p on p.card_id = c.id
 left join public.orders as o on o.id = c.order_id
 left join public.designs as d on d.id = o.design_id
 where c.card_id = p_card_id
   and c.status <> 'suspended'
 limit 1;
$$;
grant execute on function public.zoma_get_public_card(text) to anon,authenticated;

-- ZOMA order/card RPCs (idempotent and type-safe)
drop function if exists public.zoma_create_order(uuid,text,text,text,text,text,text);
create function public.zoma_create_order(
  p_design_id uuid,
  p_customer_name text,
  p_phone text,
  p_shipping_governorate text,
  p_shipping_city text,
  p_shipping_address text,
  p_customer_notes text
) returns public.orders
language plpgsql security definer set search_path=public as $$
declare
  v_customer_id uuid;
  v_price numeric(12,2);
  v_order public.orders;
  v_order_number text;
begin
  v_customer_id := auth.uid();
  if v_customer_id is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if not exists (select 1 from public.customers where id=v_customer_id) then
    raise exception 'حساب العميل غير موجود';
  end if;
  select price into v_price from public.designs where id=p_design_id and is_available=true;
  if v_price is null then raise exception 'التصميم غير متاح'; end if;
  v_order_number := 'ZM-' || to_char(now(),'YYYYMMDD-HH24MISS') || '-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,6));
  insert into public.orders(order_number,customer_id,design_id,total_price,status,customer_name,phone,shipping_governorate,shipping_city,shipping_address,customer_notes)
  values(v_order_number,v_customer_id,p_design_id,v_price,'pending',nullif(trim(p_customer_name),''),nullif(trim(p_phone),''),nullif(trim(p_shipping_governorate),''),nullif(trim(p_shipping_city),''),nullif(trim(p_shipping_address),''),nullif(trim(p_customer_notes),''))
  returning * into v_order;
  return v_order;
end $$;
grant execute on function public.zoma_create_order(uuid,text,text,text,text,text,text) to authenticated;

drop function if exists public.zoma_issue_card(uuid,text);
create function public.zoma_issue_card(p_order_id uuid,p_site_url text) returns public.cards
language plpgsql security definer set search_path=public as $$
declare
  v_order public.orders;
  v_card public.cards;
  v_profile public.profiles;
  v_card_id text;
  v_url text;
begin
  if not public.is_admin() then raise exception 'Admin only'; end if;
  select * into v_order from public.orders where id=p_order_id;
  if v_order.id is null then raise exception 'الطلب غير موجود'; end if;
  select * into v_card from public.cards where order_id=p_order_id limit 1;
  if v_card.id is not null then return v_card; end if;
  v_card_id := 'ZOMA-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,10));
  v_url := rtrim(coalesce(nullif(trim(p_site_url),''),'https://mohamkhamis209-hub.github.io/ZOMA-NFC/'),'/') || '/activation.html?id=' || v_card_id;
  insert into public.cards(card_id,customer_id,order_id,public_url,status) values(v_card_id,v_order.customer_id,v_order.id,v_url,'unactivated') returning * into v_card;
  insert into public.profiles(card_id,full_name) values(v_card.id,coalesce(v_order.customer_name,'')) on conflict(card_id) do update set full_name=excluded.full_name;
  return v_card;
end $$;
grant execute on function public.zoma_issue_card(uuid,text) to authenticated;

drop function if exists public.zoma_confirm_order(uuid,text);
create function public.zoma_confirm_order(p_order_id uuid,p_site_url text) returns public.orders
language plpgsql security definer set search_path=public as $$
declare v_order public.orders; v_card public.cards;
begin
  if not public.is_admin() then raise exception 'Admin only'; end if;
  update public.orders set status='confirmed' where id=p_order_id returning * into v_order;
  if v_order.id is null then raise exception 'الطلب غير موجود'; end if;
  select * into v_card from public.zoma_issue_card(p_order_id,p_site_url);
  return v_order;
end $$;
grant execute on function public.zoma_confirm_order(uuid,text) to authenticated;

create or replace function public.zoma_reset_year_data() returns void language plpgsql security definer set search_path=public as $$
begin
 if not exists(select 1 from public.admins where id=auth.uid() and role='owner') then raise exception 'Owner only'; end if;
 delete from public.audit_logs;delete from public.analytics;delete from public.nfc_writes;delete from public.notifications;delete from public.messages;delete from public.profiles;delete from public.cards;delete from public.orders;delete from public.customers;
end $$;
grant execute on function public.zoma_reset_year_data() to authenticated;

-- RLS
drop policy if exists admins_self on public.admins;
drop policy if exists admins_admin on public.admins;
drop policy if exists customers_self on public.customers;
drop policy if exists customers_insert on public.customers;
drop policy if exists customers_update on public.customers;
drop policy if exists customers_delete on public.customers;
drop policy if exists designs_public on public.designs;
drop policy if exists designs_admin on public.designs;
drop policy if exists orders_customer on public.orders;
drop policy if exists orders_insert on public.orders;
drop policy if exists orders_update on public.orders;
drop policy if exists orders_delete on public.orders;
drop policy if exists cards_customer on public.cards;
drop policy if exists cards_admin on public.cards;
drop policy if exists profiles_customer on public.profiles;
drop policy if exists profiles_customer_write on public.profiles;
drop policy if exists profiles_customer_update on public.profiles;
drop policy if exists profiles_admin on public.profiles;
drop policy if exists nfc_admin on public.nfc_writes;
drop policy if exists analytics_insert on public.analytics;
drop policy if exists analytics_admin on public.analytics;
drop policy if exists notif_customer on public.notifications;
drop policy if exists notif_update on public.notifications;
drop policy if exists notif_admin on public.notifications;
drop policy if exists messages_customer on public.messages;
drop policy if exists messages_insert on public.messages;
drop policy if exists messages_update on public.messages;
drop policy if exists messages_admin on public.messages;
drop policy if exists audit_admin on public.audit_logs;
drop policy if exists perm_admin on public.admin_permissions;
alter table public.admins enable row level security;alter table public.customers enable row level security;alter table public.designs enable row level security;alter table public.orders enable row level security;alter table public.cards enable row level security;alter table public.profiles enable row level security;alter table public.nfc_writes enable row level security;alter table public.analytics enable row level security;alter table public.notifications enable row level security;alter table public.messages enable row level security;alter table public.audit_logs enable row level security;alter table public.admin_permissions enable row level security;

drop policy if exists admins_self on public.admins;drop policy if exists admins_admin on public.admins;create policy admins_self on public.admins for select to authenticated using(id=auth.uid() or public.is_admin());create policy admins_admin on public.admins for all to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists customers_self on public.customers;drop policy if exists customers_admin on public.customers;create policy customers_self on public.customers for select to authenticated using(id=auth.uid() or public.is_admin());create policy customers_insert on public.customers for insert to authenticated with check(id=auth.uid() or public.is_admin());create policy customers_update on public.customers for update to authenticated using(id=auth.uid() or public.is_admin()) with check(id=auth.uid() or public.is_admin());create policy customers_delete on public.customers for delete to authenticated using(public.is_admin());
drop policy if exists designs_public on public.designs;drop policy if exists designs_admin on public.designs;create policy designs_public on public.designs for select to anon,authenticated using(is_available=true or public.is_admin());create policy designs_admin on public.designs for all to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists orders_customer on public.orders;drop policy if exists orders_admin on public.orders;create policy orders_customer on public.orders for select to authenticated using(customer_id=auth.uid() or public.is_admin());create policy orders_insert on public.orders for insert to authenticated with check(customer_id=auth.uid() or public.is_admin());create policy orders_update on public.orders for update to authenticated using(customer_id=auth.uid() or public.is_admin()) with check(customer_id=auth.uid() or public.is_admin());create policy orders_delete on public.orders for delete to authenticated using(public.is_admin());
drop policy if exists cards_customer on public.cards;drop policy if exists cards_admin on public.cards;create policy cards_customer on public.cards for select to authenticated using(customer_id=auth.uid() or public.is_admin());create policy cards_admin on public.cards for all to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists profiles_customer on public.profiles;drop policy if exists profiles_admin on public.profiles;create policy profiles_customer on public.profiles for select to authenticated using(exists(select 1 from public.cards as c where c.id = public.profiles.card_id and c.customer_id = auth.uid()));create policy profiles_customer_write on public.profiles for insert to authenticated with check(exists(select 1 from public.cards as c where c.id = public.profiles.card_id and c.customer_id = auth.uid()));create policy profiles_customer_update on public.profiles for update to authenticated using(exists(select 1 from public.cards as c where c.id = public.profiles.card_id and c.customer_id = auth.uid())) with check(exists(select 1 from public.cards as c where c.id = public.profiles.card_id and c.customer_id = auth.uid()));create policy profiles_admin on public.profiles for all to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists nfc_admin on public.nfc_writes;create policy nfc_admin on public.nfc_writes for all to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists analytics_insert on public.analytics;drop policy if exists analytics_admin on public.analytics;create policy analytics_insert on public.analytics for insert to anon,authenticated with check(true);create policy analytics_admin on public.analytics for select to authenticated using(public.is_admin());
drop policy if exists notif_customer on public.notifications;create policy notif_customer on public.notifications for select to authenticated using(customer_id=auth.uid() or public.is_admin());create policy notif_update on public.notifications for update to authenticated using(customer_id=auth.uid() or public.is_admin()) with check(customer_id=auth.uid() or public.is_admin());create policy notif_admin on public.notifications for all to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists messages_customer on public.messages;drop policy if exists messages_admin on public.messages;create policy messages_customer on public.messages for select to authenticated using(customer_id=auth.uid() or public.is_admin());create policy messages_insert on public.messages for insert to authenticated with check(customer_id=auth.uid() or public.is_admin());create policy messages_update on public.messages for update to authenticated using(customer_id=auth.uid() or public.is_admin()) with check(customer_id=auth.uid() or public.is_admin());create policy messages_admin on public.messages for all to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists audit_admin on public.audit_logs;create policy audit_admin on public.audit_logs for all to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists perm_admin on public.admin_permissions;create policy perm_admin on public.admin_permissions for all to authenticated using(public.is_admin()) with check(public.is_admin());

-- Profile photo bucket. The bucket is public for visitor display; writes are scoped to the user's own folder.
insert into storage.buckets(id,name,public) values('profile-photos','profile-photos',true) on conflict(id) do update set public=true;
drop policy if exists profile_photo_read on storage.objects;drop policy if exists profile_photo_insert on storage.objects;drop policy if exists profile_photo_update on storage.objects;drop policy if exists profile_photo_delete on storage.objects;
create policy profile_photo_read on storage.objects for select using(bucket_id='profile-photos');
create policy profile_photo_insert on storage.objects for insert to authenticated with check(bucket_id='profile-photos' and split_part(name,'/',1)=auth.uid()::text);
create policy profile_photo_update on storage.objects for update to authenticated using(bucket_id='profile-photos' and split_part(name,'/',1)=auth.uid()::text) with check(bucket_id='profile-photos' and split_part(name,'/',1)=auth.uid()::text);
create policy profile_photo_delete on storage.objects for delete to authenticated using(bucket_id='profile-photos' and split_part(name,'/',1)=auth.uid()::text);

insert into storage.buckets(id,name,public) values('design-assets','design-assets',true) on conflict(id) do update set public=true;
drop policy if exists design_asset_read on storage.objects;
drop policy if exists design_asset_insert on storage.objects;
drop policy if exists design_asset_update on storage.objects;
drop policy if exists design_asset_delete on storage.objects;
create policy design_asset_read on storage.objects for select using(bucket_id='design-assets');
create policy design_asset_insert on storage.objects for insert to authenticated with check(bucket_id='design-assets' and public.is_admin());
create policy design_asset_update on storage.objects for update to authenticated using(bucket_id='design-assets' and public.is_admin()) with check(bucket_id='design-assets' and public.is_admin());
create policy design_asset_delete on storage.objects for delete to authenticated using(bucket_id='design-assets' and public.is_admin());

-- Optional seeded permissions for an assistant if an admin is added manually.
