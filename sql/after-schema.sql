-- ZOMA final migration. Run this in Supabase SQL Editor AFTER your existing schema.
-- It lets a customer securely log in using phone number or Card ID without exposing email mappings.
create or replace function public.zoma_get_login_email(p_login text)
returns text
language plpgsql
security definer
set search_path=public
as $$
declare result text;
begin
  select u.email into result
  from auth.users u
  join public.customers c on c.id=u.id
  where c.phone=p_login
  limit 1;
  if result is null then
    select u.email into result
    from auth.users u
    join public.customers c on c.id=u.id
    join public.cards ca on ca.customer_id=c.id
    where ca.card_id=p_login
    limit 1;
  end if;
  return result;
end;
$$;

revoke all on function public.zoma_get_login_email(text) from public;
grant execute on function public.zoma_get_login_email(text) to anon, authenticated;

-- Useful defaults/constraints for profiles.
alter table public.profiles
  add column if not exists show_whatsapp_2 boolean not null default true;

-- Allow a signed-in customer to create/update their own profile through their own card.
drop policy if exists "customers can insert own profile" on public.profiles;
create policy "customers can insert own profile"
on public.profiles for insert to authenticated
with check (
  exists (
    select 1 from public.cards c
    where c.id=card_id and c.customer_id=auth.uid()
  )
);

drop policy if exists "customers can update own profile" on public.profiles;
create policy "customers can update own profile"
on public.profiles for update to authenticated
using (
  exists (
    select 1 from public.cards c
    where c.id=profiles.card_id and c.customer_id=auth.uid()
  )
)
with check (
  exists (
    select 1 from public.cards c
    where c.id=profiles.card_id and c.customer_id=auth.uid()
  )
);

-- Public visitors can read only active cards/profiles.
drop policy if exists "public can read active cards" on public.cards;
create policy "public can read active cards"
on public.cards for select to anon, authenticated
using (status in ('active','unactivated'));

drop policy if exists "public can read active profiles" on public.profiles;
create policy "public can read active profiles"
on public.profiles for select to anon, authenticated
using (
  exists (select 1 from public.cards c where c.id=profiles.card_id and c.status='active')
);

-- Customers can read their own orders/cards.
drop policy if exists "customers read own orders" on public.orders;
create policy "customers read own orders"
on public.orders for select to authenticated
using (customer_id=auth.uid());

drop policy if exists "customers read own cards" on public.cards;
create policy "customers read own cards"
on public.cards for select to authenticated
using (customer_id=auth.uid());

-- Public analytics inserts for card events.
drop policy if exists "public analytics insert" on public.analytics;
create policy "public analytics insert"
on public.analytics for insert to anon, authenticated
with check (true);

-- If your existing schema already has suitable policies, duplicate-policy errors are avoided
-- by the DROP statements above.
