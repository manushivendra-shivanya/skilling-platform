# JobSkills Supabase foundation

This directory contains the reviewed database migration for the separate
`JobSkills` Supabase project.

The Flutter client accepts only:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

Pass them with `--dart-define` per environment. Never place secret or
`service_role` keys in the mobile application or repository.

All exposed tables enable row-level security. Candidate-owned policies bind
rows to `auth.uid()`; reference taxonomies expose published versions only.

Workplace Management Simulation persistence is represented by the `wms_*`
tables. The schema preserves the approved WMS boundaries: attempt timing is
operational lifecycle state, `wms_learner_actions` is the only scoreable
behaviour stream, and `wms_attempt_audit_events` is unscored and append-only.
The Flutter runtime remains local-first until a future BFF/Supabase adapter is
wired to these tables.

`public.employers` and `public.employer_evidence_access_log` (plus the
nullable `jobs.employer_id` column) back the Employer Evidence Review MVP.
Both tables are BFF/service-role only -- no `anon`/`authenticated` grant is
issued to either, since employers never talk to Supabase directly, only
through `EmployerAuthGuard` in `apps/api`. Their `RLS Enabled No Policy`
advisor notice is expected for this reason, not a gap to close.

`public.career_passport_grants` and `public.career_passport_grant_access_log`
(`20260801120000_career_passport_grants.sql`) back the Career Passport
public share link. Unlike the employer tables, `career_passport_grants`
does grant `authenticated` policies -- a candidate can read/insert/update
only their own rows (`candidate_id = auth.uid()`), since minting and
revoking a link is a direct candidate write, not a BFF write. Anonymous
resolution of a link by token, and the access log, remain BFF/service-role
only. The same table is shaped to serve a later per-employer grant purpose
(`purpose = 'employer_review'`) without a second migration -- see the
migration's header comment.

Production promotion requires security/performance advisor review and a
staging smoke test.

## Migrations applied manually, outside this repo's normal review flow

The Supabase MCP connector available to the coding session that authored
`20260801100000_employer_evidence_review_mvp.sql` (and its follow-up
`..._advisor_remediation.sql`) only had access to an unrelated project
(`nutridiet`), not `JobSkills`. Both migrations were applied directly
against `JobSkills` by whoever had real access, then reported back to that
session rather than independently verified by it -- a different gap than
the Supabase CLI simply not being installed (the reason earlier `wms_*`
migrations were applied through a connector instead of `supabase migration
new` / `supabase db push`), but the same underlying lesson: confirm which
project a Supabase connector actually points at before assuming it can
apply anything here. If you're setting up a fresh `JobSkills`-equivalent
project from these migration files, this one and its dependents
(`employer_id` on `jobs`) require the `phase_three_job_applications`
migration to have run first.

`20260801120000_career_passport_grants.sql` has the same access gap and,
as of the commit that added it, has **not yet been applied anywhere** --
neither to `JobSkills` nor confirmed live. It depends on
`20260801100000_employer_evidence_review_mvp.sql` having already run
(`career_passport_grants.employer_id` references `public.employers`).
Until it's applied, the Career Passport share-link feature is present in
both `apps/api` and the Flutter app but will fail against a real deployment
with an undefined-table error -- see
`docs/generated/current-state.md`'s "Career Passport v0.2 -- revocable
public share link" entry.
