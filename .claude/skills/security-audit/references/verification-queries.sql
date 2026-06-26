-- ============================================================================
-- Live-database security verification pack
-- Figma -> Capacitor -> Supabase pipeline
-- ----------------------------------------------------------------------------
-- Run these in the Supabase SQL editor (Dashboard -> SQL Editor) against the
-- project the app actually ships against. Every query is READ-ONLY.
--
-- This is the "query the app to confirm all data is secure" step. The static
-- code audit only sees committed migrations; it cannot see RLS toggled off in
-- the dashboard, a bucket flipped to public, or grants changed by hand. These
-- queries inspect the LIVE catalog so you can prove the data is locked down.
--
-- Rule of thumb: for queries 1-6 and 8, ANY returned row is something to
-- investigate. Query 7 is informational context for query 1.
-- ============================================================================


-- 1. Tables in `public` with Row Level Security DISABLED. -------------------
--    In Supabase the `anon` role has table grants by default, so a public
--    table with RLS off is readable/writable by anyone with the anon key.
--    EXPECTED RESULT: zero rows. Any row = a wide-open table = BLOCKER.
select n.nspname  as schema,
       c.relname  as table,
       c.relrowsecurity   as rls_enabled,
       c.relforcerowsecurity as rls_forced
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where c.relkind = 'r'
  and n.nspname = 'public'
  and c.relrowsecurity = false
order by c.relname;


-- 2. Tables with RLS ENABLED but NO policies. -------------------------------
--    RLS with no policy denies all access — secure, but usually a wiring bug
--    (the feature silently returns nothing). EXPECTED: zero rows, or only
--    tables you intend to be access-free. Investigate each row.
select t.schemaname as schema,
       t.tablename  as table
from pg_tables t
left join pg_policies p
  on p.schemaname = t.schemaname and p.tablename = t.tablename
where t.schemaname = 'public'
group by t.schemaname, t.tablename
having count(p.policyname) = 0
order by t.tablename;


-- 3. World-open policies: USING (true) or WITH CHECK (true). ----------------
--    These grant access to EVERY row regardless of the caller — they defeat
--    RLS. EXPECTED RESULT: zero rows. Any row = BLOCKER unless the table is
--    deliberately public reference data.
select schemaname as schema,
       tablename  as table,
       policyname,
       cmd,
       roles,
       qual       as using_expr,
       with_check
from pg_policies
where schemaname in ('public', 'storage')
  and (qual = 'true' or with_check = 'true')
order by tablename, policyname;


-- 4. Policies that DON'T reference auth.uid(). ------------------------------
--    Owner-scoped policies in this pipeline check `auth.uid() = user_id`
--    (or `= id` for profiles). A policy with neither auth.uid() nor a clear
--    scoping clause is worth a look. EXPECTED: only intentionally-shared
--    tables appear here. Review each.
select schemaname as schema,
       tablename  as table,
       policyname,
       cmd,
       roles,
       coalesce(qual, with_check) as expr
from pg_policies
where schemaname = 'public'
  and coalesce(qual, '')       not ilike '%auth.uid()%'
  and coalesce(with_check, '') not ilike '%auth.uid()%'
order by tablename, policyname;


-- 5. Storage buckets that are PUBLIC. ---------------------------------------
--    A public bucket is readable by anyone with the object URL (no auth).
--    Acceptable for non-sensitive assets (e.g. public avatars); a leak for
--    anything user-private. EXPECTED: only buckets you intend to be public.
select id, name, public, created_at
from storage.buckets
where public = true
order by name;


-- 6. Storage object policies — review for owner scoping. --------------------
--    Storage access is governed by policies on storage.objects. Confirm each
--    scopes by `owner = auth.uid()` and/or a specific `bucket_id`, not blanket
--    access. EXPECTED: every row is owner/bucket scoped. Eyeball the exprs.
select policyname,
       cmd,
       roles,
       qual       as using_expr,
       with_check
from pg_policies
where schemaname = 'storage' and tablename = 'objects'
order by policyname;


-- 7. Table grants to anon / authenticated / public (CONTEXT for query 1). ---
--    Grants are NORMAL in Supabase — RLS, not grant revocation, is what
--    restricts rows. A grant is only dangerous when the SAME table appears in
--    query 1 (RLS disabled). Cross-reference: a table here AND in query 1 is
--    fully exposed.
select table_schema as schema,
       table_name   as table,
       grantee,
       string_agg(privilege_type, ', ' order by privilege_type) as privileges
from information_schema.role_table_grants
where table_schema = 'public'
  and grantee in ('anon', 'authenticated', 'public')
group by table_schema, table_name, grantee
order by table_name, grantee;


-- 8. SECURITY DEFINER functions without a pinned search_path. ---------------
--    A SECURITY DEFINER function runs with the owner's privileges; without a
--    fixed `search_path` it is vulnerable to search-path hijacking (an attacker
--    shadows a referenced object). EXPECTED RESULT: zero rows. Any row =
--    add `set search_path = ''` (or an explicit schema) to the function.
select n.nspname  as schema,
       p.proname  as function,
       p.proconfig as config
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prosecdef = true
  and (
    p.proconfig is null
    or not exists (
      select 1 from unnest(p.proconfig) as cfg where cfg ilike 'search_path=%'
    )
  )
order by p.proname;
