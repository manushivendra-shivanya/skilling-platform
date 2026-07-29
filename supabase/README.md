# Supabase Phase 2 foundation

This directory contains the reviewed database migration for the separate
`JobSkills` Supabase project.

The Flutter client accepts only:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

Pass them with `--dart-define` per environment. Never place secret or
`service_role` keys in the mobile application or repository.

All exposed tables enable row-level security. Candidate-owned policies bind
rows to `auth.uid()`; reference taxonomies expose published versions only.
Production promotion requires security/performance advisor review and a
staging smoke test.
