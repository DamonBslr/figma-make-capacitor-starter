# Schema + RLS mapping rules (with worked example)

## Mapping rules
- Each persisted domain type → one table. TS `string` → `text`, `number` → `int`
  or `numeric`, `boolean` → `boolean`, nested object → `jsonb` (or a child table
  if it needs its own queries), arrays of scalars → `text[]` or `jsonb`.
- Every user-owned table gets `user_id uuid not null references auth.users(id)
  on delete cascade`.
- `id`: use `uuid primary key default gen_random_uuid()` unless the app already
  assigns ids (the stub uses string ids like "1" — switch to uuid in the real DB
  and let the client use the returned id).
- Timestamps: add `created_at timestamptz default now()` and `updated_at` where useful.
- The `User` type → `profiles` keyed by `id uuid primary key references auth.users(id)`.

## RLS pattern (every table)
```sql
alter table public.<t> enable row level security;

create policy "<t>_select_own" on public.<t>
  for select using (auth.uid() = user_id);
create policy "<t>_insert_own" on public.<t>
  for insert with check (auth.uid() = user_id);
create policy "<t>_update_own" on public.<t>
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "<t>_delete_own" on public.<t>
  for delete using (auth.uid() = user_id);
```
For `profiles`, replace `user_id` with `id`.

## Worked example (Muse types → schema)
```sql
-- profiles (maps the User domain type)
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default '',
  email text,
  bio text default '',
  avatar_url text,
  stats jsonb not null default '{"stories":0,"active":0,"words":0}',
  current_story jsonb,
  created_at timestamptz default now()
);
alter table public.profiles enable row level security;
create policy "profiles_select_own" on public.profiles for select using (auth.uid() = id);
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);

-- create a profile row automatically on signup
create function public.handle_new_user() returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, email, name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name',''));
  return new;
end; $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- characters (maps CharacterData)
create table public.characters (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  aussehen text, alter text, charakter text, sprechart text, backstory text,
  image text,
  starred boolean not null default false,
  created_at timestamptz default now()
);
alter table public.characters enable row level security;
create policy "characters_select_own" on public.characters for select using (auth.uid() = user_id);
create policy "characters_insert_own" on public.characters for insert with check (auth.uid() = user_id);
create policy "characters_update_own" on public.characters for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "characters_delete_own" on public.characters for delete using (auth.uid() = user_id);

-- library_items, stories: same shape; add per the LibraryItem / StoryConfig types.
```

## Storage (character/cover images)
Character and cover images currently point at Unsplash stubs. For real uploads,
create a Supabase Storage bucket (e.g. `character-images`) with an owner-scoped
policy, and store the returned public/signed URL in the row's `image` column.
Bucket creation is done via the dashboard or `supabase` CLI — a human/AI-guided
step, since it touches the live project.
