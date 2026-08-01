-- Career Passport grants: a single table backing both the candidate-
-- generated public share link (purpose = 'public_link', this slice) and,
-- in a follow-up slice, per-employer grants (purpose = 'employer_review',
-- employer_id set instead of token) -- see ADR-0018 section 5's grant
-- shape (candidate, recipient, purpose, grant/expiry times, revocation
-- state). Nothing here replaces the existing `consent_grants` /
-- `career_passport_sharing` purpose, which continues to gate the
-- (separate, broader) job-application-scoped employer review flow until
-- the follow-up slice migrates it onto per-employer grants.

create table public.career_passport_grants (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references auth.users(id) on delete cascade,
  purpose text not null check (purpose in ('public_link', 'employer_review')),
  employer_id uuid references public.employers(id) on delete cascade,
  token text unique,
  granted_at timestamptz not null default now(),
  expires_at timestamptz,
  revoked_at timestamptz,
  constraint career_passport_grants_shape check (
    (purpose = 'public_link' and token is not null and employer_id is null)
    or (purpose = 'employer_review' and employer_id is not null and token is null)
  )
);

-- At most one active public link per candidate -- the candidate-facing
-- flow is "generate or view the current link, revoke it," never a list of
-- concurrent links, so this is enforced at the data layer too, not just
-- in application code.
create unique index career_passport_grants_active_public_link_idx
  on public.career_passport_grants (candidate_id)
  where purpose = 'public_link' and revoked_at is null;

create index career_passport_grants_token_idx
  on public.career_passport_grants (token)
  where token is not null;

create index career_passport_grants_employer_idx
  on public.career_passport_grants (employer_id, candidate_id)
  where purpose = 'employer_review';

-- Append-only audit of every attempt to open a public share link,
-- mirroring `employer_evidence_access_log`'s allowed/denied shape --
-- ADR-0018 requires every evidence view be audited, not just employer
-- reads.
create table public.career_passport_grant_access_log (
  id uuid primary key default gen_random_uuid(),
  grant_id uuid references public.career_passport_grants(id) on delete set null,
  outcome text not null check (outcome in ('allowed', 'denied')),
  denial_reason text,
  accessed_at timestamptz not null default now()
);

create index career_passport_grant_access_log_grant_idx
  on public.career_passport_grant_access_log (grant_id, accessed_at desc);

alter table public.career_passport_grants enable row level security;
alter table public.career_passport_grant_access_log enable row level security;

create policy "candidate reads own grants"
  on public.career_passport_grants for select to authenticated
  using ((select auth.uid()) = candidate_id);
create policy "candidate inserts own grants"
  on public.career_passport_grants for insert to authenticated
  with check ((select auth.uid()) = candidate_id);
create policy "candidate updates own grants"
  on public.career_passport_grants for update to authenticated
  using ((select auth.uid()) = candidate_id)
  with check ((select auth.uid()) = candidate_id);

-- No client (anon/authenticated) policy on career_passport_grant_access_log
-- or on anonymous reads of career_passport_grants: the public share page is
-- served by the BFF's service-role client only, mirroring
-- employer_evidence_access_log -- an anonymous link recipient never talks
-- to Supabase directly.
