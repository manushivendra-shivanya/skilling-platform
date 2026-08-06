-- Phase H: multi-source job sourcing. jobs.source distinguishes provenance
-- without changing what candidates see; external listings are read-only
-- mirrors made idempotent by (source, external_id). apply_url is null for
-- Flora-native/employer-posted jobs (internal one-click apply flow applies)
-- and set for every aggregator-sourced job (candidate is sent to the real
-- listing instead, since there is no real Flora employer behind those rows
-- to receive an internal application). job_sync_runs is an append-only
-- audit trail, mirroring employer_evidence_access_log's posture -- service
-- role (BFF) only, no client policy.

alter table public.jobs
  add column source text not null default 'flora'
    check (source in ('flora', 'adzuna', 'jooble', 'careerjet', 'greenhouse', 'lever')),
  add column external_id text,
  add column apply_url text;

-- Existing seed rows and all employer-posted jobs get source='flora' via
-- the column default; apply_url stays null for them (internal apply flow).

create unique index jobs_source_external_id_key
  on public.jobs (source, external_id)
  where external_id is not null;

create table public.job_sync_runs (
  id uuid primary key default gen_random_uuid(),
  source text not null,
  triggered_by text not null check (triggered_by in ('cron', 'manual')) default 'cron',
  started_at timestamptz not null,
  completed_at timestamptz not null default now(),
  jobs_seen integer not null default 0,
  jobs_upserted integer not null default 0,
  error text
);

create index job_sync_runs_source_idx
  on public.job_sync_runs (source, started_at desc);

alter table public.job_sync_runs enable row level security;
-- No policy, no grant to anon/authenticated: only the BFF's service-role
-- client ever reads or writes this table, same posture as
-- public.employers / public.employer_evidence_access_log.
