# API (BFF)

The one place cross-tenant business logic, service-role database access, and
external integrations are allowed to live. The candidate app talks to
Supabase directly for its own RLS-scoped data; anything that needs to see
across parties, enforce authorization between them, or hold a credential no
client should have goes through here instead. See
`docs/01-system-architecture.md` and `docs/03-api-specifications.md`.

## Current scope

Phase 3.2 (job application operations) only, per
`docs/20-codex-phase-execution.md`:

- `GET /v1/jobs` — published jobs.
- `POST /v1/jobs/:id/applications` — consent-gated, idempotent job
  application. Requires an `Idempotency-Key` header; a repeated call for the
  same candidate and job returns the existing application rather than
  erroring or duplicating it.

Both routes require a `Authorization: Bearer <candidate JWT>` header, verified
against Supabase Auth (not decoded locally, so a revoked session is rejected
too).

## Setup

```bash
cd apps/api
npm install
cp .env.example .env   # fill in SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY
```

The service-role key is server-side only and bypasses row-level security —
never send it to a client, never commit `.env`.

Apply `supabase/migrations/20260729182817_phase_three_job_applications.sql`
to the target project before starting the service (via the Supabase CLI, the
SQL editor, or the Supabase MCP integration's `apply_migration`).

```bash
npm run start:dev   # http://localhost:3000/v1
npm test
```

## Why a repeated apply doesn't fail or duplicate

`job_applications` has a `unique (job_id, candidate_id)` constraint. The
service checks for an existing row before inserting, but the constraint --
not that check -- is what actually makes concurrent duplicate requests safe:
if two requests race, the loser's insert fails on the constraint and the
service reads back whichever row won, rather than erroring the request.
