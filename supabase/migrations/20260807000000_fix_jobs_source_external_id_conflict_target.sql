-- Fixes a bug found via live testing: the partial unique index created in
-- 20260806090000_phase_h_job_sourcing.sql (`where external_id is not null`)
-- cannot be used as an ON CONFLICT target by PostgREST's upsert, which
-- generates a plain `ON CONFLICT (source, external_id)` clause with no
-- WHERE predicate -- Postgres requires the arbiter index's predicate to
-- match exactly, so every upsert failed with "there is no unique or
-- exclusion constraint matching the ON CONFLICT specification".
--
-- The partial predicate was unnecessary in the first place: Postgres
-- already treats NULL as distinct from NULL in a plain unique index (no
-- NULLS NOT DISTINCT), so multiple Flora-native jobs (external_id always
-- null) never collide under a plain unique index either -- the same
-- desired behaviour, without the ON CONFLICT incompatibility.

drop index if exists public.jobs_source_external_id_key;

create unique index jobs_source_external_id_key
  on public.jobs (source, external_id);
