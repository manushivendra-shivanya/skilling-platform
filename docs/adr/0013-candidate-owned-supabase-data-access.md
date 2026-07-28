# ADR-0013: Candidate-Owned Supabase Data Access

- Status: Accepted
- Date: 2026-07-28
- Owners: Engineering

## Context

Phase 2 requires phone authentication, candidate profile and consent
persistence, diagnostic results, learning progress, simulation events, scores,
and evidence. The approved architecture retains a NestJS backend-for-frontend
(BFF) for consequential workflows, cross-tenant operations, privileged
business logic, and service integrations. The candidate mobile application
also needs an offline-capable Phase 2 vertical slice before that BFF is
available.

## Decision

The Flutter candidate application may use the Supabase Flutter SDK directly
for the narrowly scoped, candidate-owned Phase 2 records protected by
PostgreSQL row-level security. This adapter is enabled only when a Supabase URL
and publishable key are supplied through build-time environment configuration.
Without that configuration, the app continues to use its secure local
development adapters.

Published role, competency, diagnostic, pathway, learning, and simulation
definitions are read-only to the mobile role. Candidate records are restricted
to `auth.uid()` ownership. Deterministic diagnostic and simulation calculations
run from immutable versioned definitions, while their inputs and outputs are
persisted for auditability.

This decision does not replace the NestJS BFF. Employer, administrator,
cross-candidate, privileged, AI-provider, resume-processing, job-application,
and other consequential operations remain behind the planned API boundary.

## Alternatives Considered

- Wait for the complete NestJS BFF before implementing Phase 2. Rejected
  because it prevents a testable candidate-owned vertical slice and offline
  workflow.
- Put all application operations directly behind Supabase. Rejected because it
  weakens the approved service boundary for privileged and consequential
  workflows.
- Store Phase 2 only on the device. Rejected because cross-device persistence,
  auditable consent, and authoritative evidence require server-side records.

## Consequences

- Candidate-owned Phase 2 data can synchronize without blocking on the BFF.
- The Flutter code retains repository interfaces, so the remote adapter can be
  moved behind the BFF without changing presentation or domain code.
- Production builds require environment configuration; no secret or service
  role key is embedded in the client.
- Future operations must be reviewed before direct Data API access is added.

## Security/Privacy Impact

- All exposed candidate tables use row-level security and least-privilege
  grants.
- Only the Supabase publishable key may be included in a client build.
- Service-role and secret keys are prohibited from Flutter configuration.
- Technical simulation events are retained for reliability analysis but are
  excluded from candidate scores.

## Migration/Rollback

Disable the Supabase build configuration to return the app to secure local
adapters. Repository interfaces allow a future NestJS adapter to replace the
direct adapter. Database migrations are additive and versioned under
`supabase/migrations`.

## References

- `docs/01-system-architecture.md`
- `docs/03-api-specifications.md`
- `docs/08-simulation-engine.md`
- `docs/13-security-privacy-compliance.md`
- `docs/20-codex-phase-execution.md`
