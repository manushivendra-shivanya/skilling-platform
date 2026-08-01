-- Employer Evidence Review MVP: a minimal, narrowly-scoped employer identity
-- (a hashed API key per employer, issued out-of-band -- no employer login
-- flow, no employer portal) plus an append-only audit log of every
-- read-only evidence access, allowed or denied. Both tables are
-- service-role (BFF) only: no client (anon/authenticated) policy is
-- granted, since employers never talk to Supabase directly and candidates
-- have no reason to read either table in this slice.

create table public.employers (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  api_key_hash text not null unique,
  created_at timestamptz not null default now()
);

alter table public.jobs add column employer_id uuid references public.employers(id);
create index jobs_employer_idx on public.jobs (employer_id);

create table public.employer_evidence_access_log (
  id uuid primary key default gen_random_uuid(),
  employer_id uuid not null references public.employers(id),
  candidate_id uuid not null references auth.users(id) on delete cascade,
  job_id uuid references public.jobs(id),
  outcome text not null check (outcome in ('allowed', 'denied')),
  denial_reason text,
  accessed_at timestamptz not null default now()
);

create index employer_evidence_access_log_employer_idx
  on public.employer_evidence_access_log (employer_id, accessed_at desc);
create index employer_evidence_access_log_candidate_idx
  on public.employer_evidence_access_log (candidate_id, accessed_at desc);

alter table public.employers enable row level security;
alter table public.employer_evidence_access_log enable row level security;

-- Seed the three employers already seeded onto `jobs.employer_name` in
-- 20260729182817_phase_three_job_applications.sql, and backfill their jobs'
-- new employer_id. api_key_hash values below are sha256 hex digests of
-- development-only seed keys -- see
-- docs/generated/current-state.md's Employer Evidence Review MVP entry for
-- the raw keys used in local/manual testing. These are not production
-- credentials; issuing real employer keys is a follow-up, not part of this
-- slice.
insert into public.employers (name, api_key_hash) values
  ('Apex Consumer Products', '655ebf161b70101382da116559acfe41ae1abd4bbb8e265d9d466ce9c6f04eb4'),
  ('Meridian Logistics', '89cd1afecb6b6c74be908045184ffb2a42ed12be111396795add24582a502404'),
  ('Northstar Freight', 'a5063b18df3d39c51774ce6bf6c9c63eb3e1c55cbeb1f35a47ca876e1ae8db0d')
on conflict (name) do nothing;

update public.jobs
set employer_id = employers.id
from public.employers
where jobs.employer_name = employers.name
  and jobs.employer_id is null;
