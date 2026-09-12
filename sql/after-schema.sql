-- ZOMA compatibility migration. The main schema.sql is now the canonical setup.
-- Run schema.sql once. This file is intentionally idempotent for older deployments.
alter table public.designs add column if not exists design_type text not null default 'image';
alter table public.designs add column if not exists template_config jsonb not null default '{}'::jsonb;
create or replace function public.zoma_get_login_email(p_identity text) returns text language plpgsql security definer set search_path=public as $$
declare p text; result text; begin p:=trim(p_identity); if p like '%@%' then return lower(p); end if; select 'phone_'||regexp_replace(c.phone,'[^0-9]','','g')||'@zoma.local' into result from public.customers c where regexp_replace(c.phone,'[^0-9]','','g')=regexp_replace(p,'[^0-9]','','g') limit 1; if result is not null then return result; end if; select 'phone_'||regexp_replace(c.phone,'[^0-9]','','g')||'@zoma.local' into result from public.cards ca join public.customers c on c.id=ca.customer_id where ca.card_id=p and ca.status<>'suspended' limit 1; return result; end $$;
revoke all on function public.zoma_get_login_email(text) from public; grant execute on function public.zoma_get_login_email(text) to anon,authenticated;
