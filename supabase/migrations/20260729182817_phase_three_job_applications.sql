create table public.jobs (
  id uuid primary key default gen_random_uuid(),
  employer_name text not null,
  title text not null,
  location text not null,
  role_profile_id uuid references public.role_profiles(id),
  description text not null,
  status text not null check (status in ('draft', 'published', 'closed')) default 'draft',
  published_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.job_applications (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  candidate_id uuid not null references auth.users(id) on delete cascade,
  status text not null check (status in ('submitted', 'withdrawn', 'shortlisted', 'rejected')) default 'submitted',
  idempotency_key text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (job_id, candidate_id)
);

create index jobs_status_published_idx
  on public.jobs (status, published_at desc)
  where status = 'published';
create index job_applications_candidate_idx
  on public.job_applications (candidate_id, created_at desc);

alter table public.jobs enable row level security;
alter table public.job_applications enable row level security;

create policy "authenticated reads published jobs"
  on public.jobs for select to authenticated
  using (status = 'published');

create policy "candidate reads own applications"
  on public.job_applications for select to authenticated
  using ((select auth.uid()) = candidate_id);

-- Mutations (create, withdraw) go through the NestJS BFF using the service
-- role, which enforces the employer_sharing consent check and idempotency
-- key before writing -- see docs/03-api-specifications.md's
-- `POST /jobs/{id}/applications`. No client-side insert/update policy is
-- granted; RLS on this table is read-only from the candidate app.

grant select on public.jobs to authenticated;
grant select on public.job_applications to authenticated;

-- `role_profiles` is versioned (unique on code + version), so jobs bind to the
-- surrogate id of the published profile for each code.
insert into public.jobs
  (employer_name, title, location, role_profile_id, description, status, published_at)
select
  seed.employer_name, seed.title, seed.location, role.id, seed.description, 'published', now()
from (values
  ('Apex Consumer Products', 'Warehouse Operations Associate', 'Bhiwandi, Maharashtra', 'warehouse_associate', 'Receiving and put-away for a regional distribution centre. Entry-level, on-the-job training provided.'),
  ('Meridian Logistics', 'Inventory Executive', 'Gurugram, Haryana', 'inventory_executive', 'Cycle counts, discrepancy resolution and stock accuracy reporting across three warehouse zones.'),
  ('Northstar Freight', 'Dispatch Executive', 'Pune, Maharashtra', 'dispatch_executive', 'Prioritise outbound dispatch against SLA commitments and coordinate with the driver pool.')
) as seed (employer_name, title, location, role_profile_code, description)
join public.role_profiles role
  on role.code = seed.role_profile_code
 and role.status = 'published';
