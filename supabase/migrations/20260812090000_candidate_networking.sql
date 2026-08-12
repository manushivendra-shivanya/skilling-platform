-- Candidate-to-candidate networking/discovery (Professional Persona v2):
-- mutual opt-in connect requests between candidates, view-only for v1 (no
-- in-app messaging -- see apps/api/src/networking/networking.service.ts
-- for why). All real access to these tables goes through the BFF's
-- service-role client, same as career_passport_grants' cross-candidate
-- reads -- RLS below is defense-in-depth (own-row visibility only), not
-- the actual authorization boundary; the service enforces matching,
-- blocking, and rate limits in code.
--
-- `networking_profiles` is a *published snapshot* the candidate explicitly
-- pushes when they opt in, not a live read of their onboarding draft --
-- that draft is on-device secure storage only (SecureCandidateOnboarding
-- Repository) and has never left the device before now. Publishing here
-- is the one deliberate exception, and only the fields already shown on
-- the candidate's own Professional Persona card leave the device.

create table public.networking_profiles (
  candidate_id uuid primary key references auth.users(id) on delete cascade,
  discoverable boolean not null default false,
  full_name text not null,
  headline text not null default '',
  city text not null default '',
  state text not null default '',
  preferred_roles text[] not null default '{}',
  updated_at timestamptz not null default now()
);

create index networking_profiles_discoverable_idx
  on public.networking_profiles (discoverable)
  where discoverable = true;

-- One active (pending or accepted) relationship per unordered pair,
-- regardless of who requested whom -- pair_key normalizes the two ids so
-- (A requests B) and (B requests A) collide at the database layer too,
-- not just in application code.
create table public.networking_connections (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  status text not null check (status in ('pending', 'accepted', 'declined', 'withdrawn')),
  pair_key text generated always as (
    least(requester_id::text, recipient_id::text) || ':' ||
    greatest(requester_id::text, recipient_id::text)
  ) stored,
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  constraint networking_connections_no_self_request check (requester_id <> recipient_id)
);

create unique index networking_connections_active_pair_idx
  on public.networking_connections (pair_key)
  where status in ('pending', 'accepted');

create index networking_connections_requester_idx
  on public.networking_connections (requester_id, status);
create index networking_connections_recipient_idx
  on public.networking_connections (recipient_id, status);

-- One-directional: A blocking B does not require B's cooperation and
-- does not imply B has blocked A. The service checks both directions
-- before allowing a new connection request or showing someone in
-- discovery results.
create table public.networking_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint networking_blocks_no_self_block check (blocker_id <> blocked_id)
);

alter table public.networking_profiles enable row level security;
alter table public.networking_connections enable row level security;
alter table public.networking_blocks enable row level security;

create policy "candidate reads own networking profile"
  on public.networking_profiles for select to authenticated
  using ((select auth.uid()) = candidate_id);
create policy "candidate upserts own networking profile"
  on public.networking_profiles for insert to authenticated
  with check ((select auth.uid()) = candidate_id);
create policy "candidate updates own networking profile"
  on public.networking_profiles for update to authenticated
  using ((select auth.uid()) = candidate_id)
  with check ((select auth.uid()) = candidate_id);

create policy "candidate reads own connections"
  on public.networking_connections for select to authenticated
  using ((select auth.uid()) in (requester_id, recipient_id));
create policy "candidate creates own connection requests"
  on public.networking_connections for insert to authenticated
  with check ((select auth.uid()) = requester_id);
create policy "candidate updates own connections"
  on public.networking_connections for update to authenticated
  using ((select auth.uid()) in (requester_id, recipient_id))
  with check ((select auth.uid()) in (requester_id, recipient_id));

create policy "candidate reads own blocks"
  on public.networking_blocks for select to authenticated
  using ((select auth.uid()) = blocker_id);
create policy "candidate creates own blocks"
  on public.networking_blocks for insert to authenticated
  with check ((select auth.uid()) = blocker_id);
create policy "candidate deletes own blocks"
  on public.networking_blocks for delete to authenticated
  using ((select auth.uid()) = blocker_id);

-- No client policy allows reading another candidate's
-- networking_profiles row, nor any other candidate's blocks -- discovery
-- (which necessarily reads *other* candidates' rows) is BFF-only,
-- mirroring career_passport's "applied-employers" precedent for reads
-- that can't be safely expressed as a client-facing RLS policy.
