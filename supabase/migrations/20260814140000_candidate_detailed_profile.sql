-- Schema for the "LinkedIn-style" detailed candidate profile: structured
-- work experience, education, external certifications, and projects, plus
-- phone/email/skills directly on candidate_profiles.
--
-- Before this migration, a resume upload could only ever extract these
-- fields for the candidate's own on-screen reference (see
-- `_ResumeExtractionSummary` in candidate_onboarding_screen.dart) --
-- `candidate_profiles` had no column to persist phone, email, skills,
-- work history, or a free-text qualification into, so everything beyond
-- fullName/headline was discarded after the candidate closed the screen.
-- This migration is what makes that data have somewhere real to live.
--
-- `candidate_education` deliberately splits `degree` from `field_of_study`
-- (rather than one free-text "education" string) so an abbreviation like
-- "BTech CS" can be interpreted into "Bachelor of Technology" /
-- "Computer Science" and stored as two structured, independently
-- queryable/displayable values -- not just kept verbatim.
--
-- All four new tables are owner-only (candidate_id = auth.uid()), same RLS
-- shape as `candidate_networking`'s tables: select/insert/update/delete on
-- your own rows, nothing cross-candidate. `sequence` on each is
-- candidate-controlled display order (most recent first, by convention),
-- not a timestamp-derived sort -- resume import and manual entry both need
-- to be able to reorder without faking `created_at`.

alter table public.candidate_profiles
  add column phone text not null default '',
  add column email text not null default '',
  add column skills text[] not null default '{}';

create table public.candidate_work_experience (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  company text not null,
  location text not null default '',
  start_month smallint check (start_month between 1 and 12),
  start_year smallint,
  end_month smallint check (end_month between 1 and 12),
  end_year smallint,
  is_current boolean not null default false,
  description text not null default '',
  sequence integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.candidate_education (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references auth.users(id) on delete cascade,
  institution text not null,
  -- Structured, not free text -- see the file-level comment on why this is
  -- split from field_of_study rather than one "education" string.
  degree text not null default '',
  field_of_study text not null default '',
  start_year smallint,
  end_year smallint,
  grade text not null default '',
  description text not null default '',
  sequence integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Deliberately named _external_ (not `candidate_certifications`) --
-- `certification_exam_attempts` (this platform's own in-app skill exams,
-- e.g. WMS certification) is a separate table with a separate meaning.
-- This one is for certifications a candidate already held before joining,
-- reported via resume or manual entry, never issued by this platform.
create table public.candidate_external_certifications (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  issuing_organization text not null default '',
  issue_month smallint check (issue_month between 1 and 12),
  issue_year smallint,
  expiry_month smallint check (expiry_month between 1 and 12),
  expiry_year smallint,
  credential_id text not null default '',
  credential_url text not null default '',
  sequence integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.candidate_projects (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  role text not null default '',
  description text not null default '',
  start_month smallint check (start_month between 1 and 12),
  start_year smallint,
  end_month smallint check (end_month between 1 and 12),
  end_year smallint,
  is_ongoing boolean not null default false,
  url text not null default '',
  skills_used text[] not null default '{}',
  sequence integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index candidate_work_experience_candidate_sequence_idx
  on public.candidate_work_experience (candidate_id, sequence);
create index candidate_education_candidate_sequence_idx
  on public.candidate_education (candidate_id, sequence);
create index candidate_external_certifications_candidate_sequence_idx
  on public.candidate_external_certifications (candidate_id, sequence);
create index candidate_projects_candidate_sequence_idx
  on public.candidate_projects (candidate_id, sequence);

alter table public.candidate_work_experience enable row level security;
alter table public.candidate_education enable row level security;
alter table public.candidate_external_certifications enable row level security;
alter table public.candidate_projects enable row level security;

create policy "candidate reads own work experience"
  on public.candidate_work_experience for select to authenticated
  using ((select auth.uid()) = candidate_id);
create policy "candidate inserts own work experience"
  on public.candidate_work_experience for insert to authenticated
  with check ((select auth.uid()) = candidate_id);
create policy "candidate updates own work experience"
  on public.candidate_work_experience for update to authenticated
  using ((select auth.uid()) = candidate_id)
  with check ((select auth.uid()) = candidate_id);
create policy "candidate deletes own work experience"
  on public.candidate_work_experience for delete to authenticated
  using ((select auth.uid()) = candidate_id);

create policy "candidate reads own education"
  on public.candidate_education for select to authenticated
  using ((select auth.uid()) = candidate_id);
create policy "candidate inserts own education"
  on public.candidate_education for insert to authenticated
  with check ((select auth.uid()) = candidate_id);
create policy "candidate updates own education"
  on public.candidate_education for update to authenticated
  using ((select auth.uid()) = candidate_id)
  with check ((select auth.uid()) = candidate_id);
create policy "candidate deletes own education"
  on public.candidate_education for delete to authenticated
  using ((select auth.uid()) = candidate_id);

create policy "candidate reads own external certifications"
  on public.candidate_external_certifications for select to authenticated
  using ((select auth.uid()) = candidate_id);
create policy "candidate inserts own external certifications"
  on public.candidate_external_certifications for insert to authenticated
  with check ((select auth.uid()) = candidate_id);
create policy "candidate updates own external certifications"
  on public.candidate_external_certifications for update to authenticated
  using ((select auth.uid()) = candidate_id)
  with check ((select auth.uid()) = candidate_id);
create policy "candidate deletes own external certifications"
  on public.candidate_external_certifications for delete to authenticated
  using ((select auth.uid()) = candidate_id);

create policy "candidate reads own projects"
  on public.candidate_projects for select to authenticated
  using ((select auth.uid()) = candidate_id);
create policy "candidate inserts own projects"
  on public.candidate_projects for insert to authenticated
  with check ((select auth.uid()) = candidate_id);
create policy "candidate updates own projects"
  on public.candidate_projects for update to authenticated
  using ((select auth.uid()) = candidate_id)
  with check ((select auth.uid()) = candidate_id);
create policy "candidate deletes own projects"
  on public.candidate_projects for delete to authenticated
  using ((select auth.uid()) = candidate_id);

grant select, insert, update, delete on public.candidate_work_experience,
  public.candidate_education, public.candidate_external_certifications,
  public.candidate_projects to authenticated;
