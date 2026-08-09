-- Phase OD-1: On-demand shift marketplace (MVP). Candidates browse
-- published hourly/shift work, accept a slot, check in/out with a
-- supervisor-issued code (no GPS/QR/selfie -- no location or camera
-- package exists in this app yet, and biometric check-in needs legal
-- review first), track payout *status* only, and raise grievance tickets.
--
-- IMPORTANT: shift_payouts is a status ledger, not a wallet. It never
-- moves real money -- that needs a payment partner and compliance/tax
-- review that is explicitly out of scope for this migration and this
-- phase. Every payout row here only ever reflects what a human (site/ops)
-- has approved, the same way `job_applications.status` reflects a human
-- decision rather than an automated one.
--
-- Table-by-table posture, mirroring existing precedent exactly:
--   shift_requests       -- mirrors `jobs`: candidates SELECT where
--                            published; all writes via the BFF service role.
--   shift_applications    -- mirrors `job_applications`: candidates SELECT
--                            own only; all writes via the BFF service role
--                            (idempotency-key enforced there, same as
--                            job applications).
--   shift_payouts         -- candidates SELECT own only; all writes via
--                            the BFF service role (an ops/employer approval
--                            action, never candidate-initiated).
--   shift_grievances       -- mirrors `candidate_profiles`: candidates
--                            SELECT + INSERT own directly (no BFF --
--                            there's no idempotency/race concern in
--                            filing a ticket, unlike accepting a
--                            limited-headcount shift).
--   candidate_shift_availability -- mirrors `candidate_profiles`: candidates
--                            SELECT + INSERT + UPDATE own directly.

create table public.shift_requests (
  id uuid primary key default gen_random_uuid(),
  employer_id uuid not null references public.employers(id),
  role_title text not null,
  site_name text not null,
  site_address text not null,
  city text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  reporting_time timestamptz,
  headcount integer not null check (headcount > 0),
  pay_amount numeric(10, 2) not null check (pay_amount >= 0),
  pay_currency text not null default 'INR',
  required_competency_ids text[] not null default '{}',
  description text,
  supervisor_name text,
  supervisor_contact text,
  cancellation_policy text,
  check_in_code text not null,
  status text not null
    check (status in ('draft', 'published', 'filled', 'completed', 'cancelled'))
    default 'draft',
  created_at timestamptz not null default now()
);

create table public.shift_applications (
  id uuid primary key default gen_random_uuid(),
  shift_id uuid not null references public.shift_requests(id) on delete cascade,
  candidate_id uuid not null references auth.users(id) on delete cascade,
  status text not null
    check (status in (
      'accepted', 'confirmed', 'checked_in', 'completed',
      'no_show', 'cancelled', 'disputed'
    ))
    default 'accepted',
  idempotency_key text not null,
  checked_in_at timestamptz,
  checked_out_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (shift_id, candidate_id)
);

create table public.shift_payouts (
  id uuid primary key default gen_random_uuid(),
  shift_application_id uuid not null unique
    references public.shift_applications(id) on delete cascade,
  candidate_id uuid not null references auth.users(id) on delete cascade,
  base_pay numeric(10, 2) not null,
  bonus numeric(10, 2) not null default 0,
  deductions numeric(10, 2) not null default 0,
  total numeric(10, 2) not null,
  status text not null
    check (status in (
      'pending_approval', 'approved', 'processing', 'paid', 'failed', 'disputed'
    ))
    default 'pending_approval',
  expected_payout_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.shift_grievances (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references auth.users(id) on delete cascade,
  shift_application_id uuid references public.shift_applications(id) on delete set null,
  category text not null
    check (category in (
      'attendance_mismatch', 'payout_mismatch', 'unsafe_work',
      'supervisor_issue', 'unpaid_overtime', 'cancellation_issue',
      'harassment_safety', 'other'
    )),
  description text not null,
  status text not null
    check (status in ('open', 'in_review', 'resolved', 'closed'))
    default 'open',
  resolution_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.candidate_shift_availability (
  candidate_id uuid primary key references auth.users(id) on delete cascade,
  available_today boolean not null default false,
  available_from time,
  available_until time,
  preferred_city text,
  max_travel_km integer,
  min_pay numeric(10, 2),
  updated_at timestamptz not null default now()
);

create index shift_requests_status_starts_idx
  on public.shift_requests (status, starts_at)
  where status = 'published';
create index shift_requests_employer_idx on public.shift_requests (employer_id);
create index shift_applications_candidate_idx
  on public.shift_applications (candidate_id, created_at desc);
create index shift_grievances_candidate_idx
  on public.shift_grievances (candidate_id, created_at desc);

alter table public.shift_requests enable row level security;
alter table public.shift_applications enable row level security;
alter table public.shift_payouts enable row level security;
alter table public.shift_grievances enable row level security;
alter table public.candidate_shift_availability enable row level security;

create policy "authenticated reads published shifts"
  on public.shift_requests for select to authenticated
  using (status = 'published');

create policy "candidate reads own shift applications"
  on public.shift_applications for select to authenticated
  using ((select auth.uid()) = candidate_id);
-- Mutations (accept, check-in, check-out) go through the NestJS BFF using
-- the service role, which enforces the idempotency key and the
-- check-in-code match -- same posture as job_applications. No client-side
-- insert/update policy is granted.

create policy "candidate reads own payouts"
  on public.shift_payouts for select to authenticated
  using ((select auth.uid()) = candidate_id);
-- Payout status changes are an ops/employer approval action, never
-- candidate-initiated -- BFF service role only, no client write policy.

create policy "candidate reads own grievances"
  on public.shift_grievances for select to authenticated
  using ((select auth.uid()) = candidate_id);
create policy "candidate files own grievance"
  on public.shift_grievances for insert to authenticated
  with check ((select auth.uid()) = candidate_id);

create policy "candidate reads own shift availability"
  on public.candidate_shift_availability for select to authenticated
  using ((select auth.uid()) = candidate_id);
create policy "candidate inserts own shift availability"
  on public.candidate_shift_availability for insert to authenticated
  with check ((select auth.uid()) = candidate_id);
create policy "candidate updates own shift availability"
  on public.candidate_shift_availability for update to authenticated
  using ((select auth.uid()) = candidate_id)
  with check ((select auth.uid()) = candidate_id);

grant select on public.shift_requests to authenticated;
grant select on public.shift_applications to authenticated;
grant select on public.shift_payouts to authenticated;
grant select, insert on public.shift_grievances to authenticated;
grant select, insert, update on public.candidate_shift_availability to authenticated;
