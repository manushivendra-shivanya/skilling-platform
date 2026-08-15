-- Phase-1 slice of the full candidate-profile schema (see the "Saksham
-- Career Passport" design mock): the fields a resume genuinely can't
-- supply and a voice-driven completion flow will fill in, plus two real
-- bugs this closes:
--
-- 1. `yearsOfExperience` is already extracted by the resume parser (see
--    `apps/api/src/resume/resume-ai-provider.ts`) and shown to the
--    candidate in the extraction summary, but the mobile confirm step has
--    had nowhere to save it -- it was read once and discarded.
-- 2. `headline` has existed on the on-device onboarding draft since the
--    Professional Persona feature, and gets published to
--    `networking_profiles` *only* if the candidate opts into networking
--    discoverability -- there has never been a column for it on
--    `candidate_profiles` itself, so the LinkedIn-style detailed profile
--    page (`candidate_detailed_profile` migration) has had no headline to
--    show at all.
--
-- `notice_period` is stored as text (an id string, same convention as
-- this table's existing `goal`/`education_level`/`experience_level`
-- columns), not a Postgres enum -- decoded via `NoticePeriod.fromId` on
-- the mobile side, same pattern those columns already use.
--
-- Deliberately out of scope here (see the design mock's Schedule A):
-- honors/awards, publications, patents, volunteer experience, featured
-- links, career-break explanation. Lower priority for this candidate
-- base -- added later, on demand, as their own migration.
alter table public.candidate_profiles
  add column headline text not null default '',
  add column summary text not null default '',
  -- Free text ("3 yrs 4 mos"), not a numeric year count -- matches the
  -- resume parser's own `yearsOfExperience` convention
  -- (ResumeAiParseResult), which is itself free text because a resume
  -- rarely states a clean number and inventing precision it doesn't
  -- support would be worse than an honest string.
  add column total_experience text not null default '',
  add column current_ctc_amount numeric,
  add column current_ctc_undisclosed boolean not null default false,
  add column expected_ctc_amount numeric,
  add column expected_ctc_negotiable boolean not null default false,
  add column notice_period text,
  add column employment_types text[] not null default '{}',
  add column preferred_locations text[] not null default '{}',
  add column willing_to_relocate boolean not null default false,
  add column industry text not null default '',
  add column functional_area text not null default '';

-- One row per language the candidate reports, own table (not a single
-- jsonb/array column) for the same reason `candidate_work_experience`
-- etc. are their own tables -- each entry needs an independently
-- upsert/delete-able id, same insert-vs-update rule as those.
create table public.candidate_languages (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references auth.users(id) on delete cascade,
  language text not null,
  -- Single overall level (native / fluent / professional_working /
  -- elementary), not separate speak/read/write scores -- three scores per
  -- language is too many questions for a quick voice-driven flow to ask,
  -- and this candidate base cares whether they can hold a conversation in
  -- a language, not a granular literacy breakdown.
  proficiency text not null,
  sequence integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (candidate_id, language)
);

create index candidate_languages_candidate_sequence_idx
  on public.candidate_languages (candidate_id, sequence);

alter table public.candidate_languages enable row level security;

create policy "candidate reads own languages"
  on public.candidate_languages for select to authenticated
  using ((select auth.uid()) = candidate_id);
create policy "candidate inserts own languages"
  on public.candidate_languages for insert to authenticated
  with check ((select auth.uid()) = candidate_id);
create policy "candidate updates own languages"
  on public.candidate_languages for update to authenticated
  using ((select auth.uid()) = candidate_id)
  with check ((select auth.uid()) = candidate_id);
create policy "candidate deletes own languages"
  on public.candidate_languages for delete to authenticated
  using ((select auth.uid()) = candidate_id);

grant select, insert, update, delete on public.candidate_languages to authenticated;
