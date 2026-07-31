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

Production promotion requires security/performance advisor review and a
staging smoke test.
