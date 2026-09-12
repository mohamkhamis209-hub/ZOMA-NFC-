-- ZOMA database verification. Run AFTER sql/schema.sql.
-- These checks are read-only.

select table_name
from information_schema.tables
where table_schema='public'
  and table_name in ('admins','customers','designs','orders','cards','profiles','nfc_writes','analytics','notifications','messages','audit_logs','admin_permissions')
order by table_name;

select routine_name, routine_type
from information_schema.routines
where routine_schema='public'
  and routine_name like 'zoma_%'
order by routine_name;

select tablename, policyname, cmd, roles
from pg_policies
where schemaname='public'
  and tablename in ('admins','customers','designs','orders','cards','profiles','nfc_writes','analytics','notifications','messages','audit_logs','admin_permissions')
order by tablename, policyname;

select c.card_id, c.status, c.customer_id, o.order_number, o.status as order_status
from public.cards c
left join public.orders o on o.id=c.order_id
order by c.created_at desc
limit 20;

-- Find potentially problematic legacy orders that should not be editable by customers.
select count(*) as orders_count from public.orders;
select count(*) as customers_count from public.customers;
select count(*) as cards_count from public.cards;
select count(*) as profiles_count from public.profiles;

-- Check duplicate phone normalization collisions.
select regexp_replace(phone,'[^0-9]','','g') as normalized_phone, count(*)
from public.customers
where phone is not null
  and phone <> ''
group by 1
having count(*) > 1;
