# 12 — Engineering Handbook

## Repository Rules
- TypeScript strict mode.
- Monorepo with clear package boundaries.
- Shared schemas, not duplicated request types.
- Server components by default in Next.js; client components only for interaction.
- Lazy initialisation of external clients.
- No secrets in repository or client bundles.

## Branching and Reviews
- Protected `main`.
- Feature branches and pull requests.
- At least one reviewer; two for security, scoring, payments, or migrations.
- ADR required for material architecture changes.

## Definition of Done
- Acceptance criteria met.
- Unit/integration tests.
- Accessibility considered.
- Analytics events defined.
- Error/loading/empty/offline states.
- Security and privacy review where applicable.
- Documentation updated.
- Feature flag and rollback plan for risky changes.

## Testing Pyramid
- Unit tests for business rules.
- Contract tests for APIs.
- Integration tests with database and queues.
- Component tests.
- Mobile and web end-to-end critical journeys.
- Load tests for voice/session creation and event ingestion.
- AI evaluation regression tests.

## CI/CD
- Formatting, lint, typecheck, tests, dependency/security scan.
- Migration validation.
- Preview deployments.
- Staging smoke tests.
- Production approval gates.
- Post-deployment monitoring and rollback.

## Environments
Local, preview, staging, production. Production data is never copied into lower environments without approved anonymisation.

## Observability
- Correlation/request IDs.
- Structured logs without unnecessary PII.
- Metrics by endpoint and domain action.
- Distributed tracing for voice and AI flows.
- SLOs and alert ownership.

## Coding Agent Rules
AI coding agents must:
1. Read README and relevant docs.
2. State affected domains.
3. Preserve architecture boundaries.
4. Add tests and docs.
5. Never invent external integration credentials or claim unavailable APIs.
6. Avoid broad refactors unrelated to the requested task.
