-- ============================================================
-- BOMA — admin/ops backend. Run in your Polaris Supabase (SQL editor).
-- Lets a passphrase-holder see pending payments, confirm → list a maker,
-- renew, reject, and monitor Polaris + Viwanda — with NO SQL editor.
-- Security: these run as the owner but self-check a secret you set, so
-- the public anon key alone can't touch them. Keep the passphrase private.
-- ============================================================

-- 1) the shared admin passphrase (anon can NEVER read this table) -----
create table if not exists app_secrets (k text primary key, v text);
alter table app_secrets enable row level security;  -- no policies = no anon access
-- SET YOUR PASSPHRASE (change the value to something long & random):
insert into app_secrets(k,v) values ('admin','CHANGE-ME-to-a-long-random-passphrase')
  on conflict (k) do update set v = excluded.v;

create or replace function _is_admin(secret text) returns boolean
language sql security definer stable set search_path=public as $$
  select exists(select 1 from app_secrets where k='admin' and v=secret);
$$;

-- 2) inquiries (shops/makers can write; admin resolves) ---------------
create table if not exists inquiries (
  id bigint generated always as identity primary key,
  from_phone text, subject text, body text,
  status text default 'open', created_at timestamptz default now()
);
alter table inquiries enable row level security;
drop policy if exists "anon submit inquiry" on inquiries;
create policy "anon submit inquiry" on inquiries for insert with check (status='open');

-- 3) OVERVIEW — Polaris + Viwanda at a glance ------------------------
create or replace function admin_overview(secret text)
returns table(shops int, live_makers int, pending int, lapsed int, open_inquiries int, mrr int)
language plpgsql security definer set search_path=public as $$
begin
  if not _is_admin(secret) then raise exception 'unauthorized'; end if;
  return query select
    (select count(*) from shops)::int,
    (select count(*) from listings where active and paid_through>now())::int,
    (select count(*) from payments where status='pending')::int,
    (select count(*) from listings where paid_through is not null and paid_through<=now())::int,
    (select count(*) from inquiries where status='open')::int,
    ((select count(*) from listings where active and paid_through>now())*1500)::int;
end;$$;
grant execute on function admin_overview(text) to anon;

-- 4) PENDING queue ---------------------------------------------------
create or replace function admin_pending(secret text)
returns setof payments language plpgsql security definer set search_path=public as $$
begin
  if not _is_admin(secret) then raise exception 'unauthorized'; end if;
  return query select * from payments where status='pending' order by created_at;
end;$$;
grant execute on function admin_pending(text) to anon;

-- Confirm → list the maker (renews if the phone already has a listing)
create or replace function admin_confirm(secret text, p_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare pr payments;
begin
  if not _is_admin(secret) then raise exception 'unauthorized'; end if;
  select * into pr from payments where id=p_id and status='pending';
  if pr.id is null then raise exception 'no pending payment %', p_id; end if;
  update payments set status='confirmed' where id=p_id;
  if pr.phone is not null and pr.phone<>'' and exists(select 1 from listings where phone=pr.phone) then
    update listings set paid_through = greatest(coalesce(paid_through,now()),now()) + interval '30 days',
                        active = true where phone=pr.phone;
  else
    insert into listings(name,category,products,price_from,unit,coverage,website,instagram,
                         facebook,tiktok,whatsapp,phone,active,paid_through)
    values(pr.brand_name,pr.category,pr.products,pr.price_from,pr.unit,pr.coverage,pr.website,
           pr.instagram,pr.facebook,pr.tiktok,pr.whatsapp,pr.phone,true,now()+interval '30 days');
  end if;
end;$$;
grant execute on function admin_confirm(text,uuid) to anon;

create or replace function admin_reject(secret text, p_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not _is_admin(secret) then raise exception 'unauthorized'; end if;
  update payments set status='rejected' where id=p_id and status='pending';
end;$$;
grant execute on function admin_reject(text,uuid) to anon;

-- 5) LISTINGS (live / expiring / lapsed) + renew ---------------------
create or replace function admin_listings(secret text)
returns table(id uuid, name text, category text, phone text, paid_through timestamptz, days_left int, state text)
language plpgsql security definer set search_path=public as $$
begin
  if not _is_admin(secret) then raise exception 'unauthorized'; end if;
  return query select l.id,l.name,l.category,l.phone,l.paid_through,
    greatest(0,ceil(extract(epoch from l.paid_through-now())/86400))::int,
    case when l.active and l.paid_through>now() then 'live'
         when l.paid_through is not null and l.paid_through<=now() then 'lapsed'
         else 'inactive' end
  from listings l order by l.paid_through desc nulls last;
end;$$;
grant execute on function admin_listings(text) to anon;

create or replace function admin_renew(secret text, l_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not _is_admin(secret) then raise exception 'unauthorized'; end if;
  update listings set paid_through = greatest(coalesce(paid_through,now()),now()) + interval '30 days',
                      active=true where id=l_id;
end;$$;
grant execute on function admin_renew(text,uuid) to anon;

-- 6) INQUIRIES ------------------------------------------------------
create or replace function admin_inquiries(secret text)
returns setof inquiries language plpgsql security definer set search_path=public as $$
begin
  if not _is_admin(secret) then raise exception 'unauthorized'; end if;
  return query select * from inquiries where status='open' order by created_at;
end;$$;
grant execute on function admin_inquiries(text) to anon;

create or replace function admin_resolve(secret text, i_id bigint)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not _is_admin(secret) then raise exception 'unauthorized'; end if;
  update inquiries set status='resolved' where id=i_id;
end;$$;
grant execute on function admin_resolve(text,bigint) to anon;
