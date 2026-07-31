# API (BFF)

The one place cross-tenant business logic, service-role database access, and
external integrations are allowed to live. The candidate app talks to
Supabase directly for its own RLS-scoped data; anything that needs to see
across parties, enforce authorization between them, or hold a credential no
client should have goes through here instead. See
`docs/01-system-architecture.md` and `docs/03-api-specifications.md`.

## Current scope

Candidate-owned BFF operations currently implemented:

- `GET /v1/jobs` — published jobs.
- `POST /v1/jobs/:id/applications` — consent-gated, idempotent job
  application. Requires an `Idempotency-Key` header; a repeated call for the
  same candidate and job returns the existing application rather than
  erroring or duplicating it.
- `POST /v1/workplace-simulation/attempts/:attemptId/sync` — idempotent WMS
  sync boundary for the already-local attempt aggregate, generated scenario,
  scoreable learner actions, unscored audit events, deterministic result and
  generated evidence. Requires an `Idempotency-Key` header.

All routes require a `Authorization: Bearer <candidate JWT>` header, verified
against Supabase Auth (not decoded locally, so a revoked session is rejected
too). The service-role key stays server-side; every route derives the candidate
id from the verified session and never trusts a client-supplied candidate id.

## Setup

```bash
cd apps/api
npm install
cp .env.example .env   # fill in SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY
```

The service-role key is server-side only and bypasses row-level security —
never send it to a client, never commit `.env`.

Apply the relevant migrations to the target project before starting the
service (via the Supabase CLI, the SQL editor, or the Supabase MCP
integration):

- `supabase/migrations/20260729182817_phase_three_job_applications.sql`
- `supabase/migrations/20260729182917_phase_three_job_applications_advisor_remediation.sql`
- `supabase/migrations/20260731042608_wms_remote_persistence_foundation.sql`
- `supabase/migrations/20260731155145_wms_remote_persistence_grant_remediation.sql`

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

## WMS sync boundary

The WMS endpoint is deliberately a synchronization boundary, not a scoring
endpoint and not a UI contract. The Flutter controller remains the
authoritative state-transition owner; the BFF persists what that controller
already produced.

The endpoint preserves the approved streams:

- `wms_attempts` stores operational lifecycle/timer/draft/scenario state.
- `wms_learner_actions` stores only scoreable learner behaviour. Requests with
  `isTechnical: true` in learner actions are rejected.
- `wms_attempt_audit_events` stores unscored lifecycle and analytics events.
- `wms_attempt_results` stores deterministic scoring output.
- `wms_competency_evidence` stores generated evidence and must not be displayed
  as regulated certification.

Writes are ordered by dependency and idempotent for repeated client retries.
The current implementation is application-level ordered persistence rather than
a single Postgres transaction; the transaction wrapper remains future work once
a database RPC/transaction support decision is made.
