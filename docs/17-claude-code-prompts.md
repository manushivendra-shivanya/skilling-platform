# 17 — Claude Code Implementation Prompts

## Mandatory Session Bootstrap
```text
You are working in the skilling-platform repository. Before changing code:
1. Read README.md.
2. Read docs/00-master-plan.md, docs/01-system-architecture.md, docs/12-engineering-handbook.md, and the domain-specific document for this task.
3. Inspect the existing repository and do not assume files or packages exist.
4. Summarise the current architecture and the exact scope you will change.
5. Preserve tenant isolation, consent, explainable scoring, low-bandwidth mobile support, and immutable rubric/prompt/simulation versions.
6. Do not introduce a new dependency unless justified.
7. Implement tests, loading/error/empty states, analytics events, and documentation updates.
8. Run formatting, lint, typecheck, tests, and build before concluding.
9. Report changed files, validation results, risks, and follow-up items.
```

## Prompt 1 — Scaffold Monorepo
```text
Implement Sprint 0 from docs/16-sprint-plan.md. Create a TypeScript monorepo with apps for marketing-web, employer-web, admin-web, candidate-mobile, and api, plus the packages listed in README.md. Use the latest stable compatible versions after checking official documentation. Add shared lint, TypeScript, environment validation, CI, and a minimal health endpoint. Do not add business features. Create ADRs for the monorepo tool, ORM, auth provider abstraction, queue, and object storage abstraction.
```

## Prompt 2 — Database Foundation
```text
Using docs/02-database-design.md, implement the first migration for identity, candidate profile, consent, roles, competencies, role profiles, audit logs, and outbox events. Add constraints, indexes, seed data, repository functions, and integration tests. Keep PII access behind a dedicated module. Do not create every future table in the first migration.
```

## Prompt 3 — Candidate Onboarding
```text
Implement Sprint 1 end to end in candidate-mobile and api. Build OTP provider abstraction with a development adapter, onboarding screens, profile persistence, language selection, and versioned consent. Add offline-safe form drafts, accessibility labels, analytics, API contracts, tests, and error states. Do not expose provider secrets to the client.
```

## Prompt 4 — Diagnostic Engine
```text
Implement a versioned diagnostic engine for the logistics pilot. Use docs/03-api-specifications.md and docs/04-ui-ux-specification.md. Support question sections, resume, response persistence, submission, deterministic scoring, competency evidence, and a pathway recommendation. Provide seed content for Warehouse Operations Associate. Add an admin-readable JSON authoring format but not a full visual authoring tool yet.
```

## Prompt 5 — Simulation Runtime
```text
Implement the simulation runtime described in docs/08-simulation-engine.md. Start with Inventory Discrepancy and Cycle Count. Use immutable simulation versions, ordered client events, offline batching, server validation, deterministic rubric scoring, evidence output, and attempt replay for administrators. Technical network/app failures must not count as candidate reliability failures.
```

## Prompt 6 — Voice Recorded-Turn MVP
```text
Implement a recorded-turn voice interview MVP following docs/06-voice-architecture.md. Include explicit recording consent, microphone check, local capture, resumeable upload, transcription-provider abstraction, transcript review, and structured feedback placeholder behind an AI evaluator interface. Preserve code-switching and never score accent or emotion. Add retention metadata and deletion workflow hooks.
```

## Prompt 7 — AI Evaluation Service
```text
Implement the AI orchestration layer in docs/05-ai-architecture.md. Add prompt registry, immutable prompt versions, structured output validation, AI run audit records, model routing abstraction, retries, cost/latency metrics, redaction, and a human review queue. Implement P-VOICE-EVALUATOR-001 with a test fixture dataset. Do not allow an AI score to be the sole basis for candidate rejection.
```

## Prompt 8 — Employer Portal
```text
Implement Employer Portal v1 from docs/10-employer-portal.md: tenant setup, team roles, requisition creation, candidate match list, consent-aware evidence profile, shortlist, and interview scheduling. Enforce tenant isolation in database tests and API integration tests. Reliability dimensions must be explainable and optional in filtering.
```

## Prompt 9 — Admin Portal
```text
Implement the first Admin Portal modules: role taxonomy, diagnostic content, simulation version list, AI review queue, candidate support timeline, and audit log viewer. Use least privilege and mask PII by default. Sensitive actions require a reason and produce audit records.
```

## Prompt 10 — Reliability Dimensions
```text
Implement reliability dimensions from docs/14-analytics-reliability-graph.md using transparent rule-based aggregation first. Do not implement a predictive retention probability. Show candidate-visible contributing events, recency, exclusions, appeal flow, and employer sharing consent. Add fairness monitoring queries and tests proving technical failures are excluded.
```

## Prompt 11 — Architecture Block Diagram
```text
Generate or update docs/generated/block-diagram.md and Mermaid diagrams for the current implemented system. Derive the diagram from the repository rather than the aspirational plan. Mark modules as PLANNED, IN PROGRESS, BUILT, VERIFIED, or DEPRECATED. Link each module to its code path, owner, tests, APIs, database tables, and related documentation. The keyword “block diagram” in future tasks means this document must be refreshed.
```

## Prompt 12 — End-of-Session Repository Context
```text
Before ending this coding session, update docs/generated/current-state.md with: implemented features, current architecture, routes, schemas, migrations, environment variables, integrations, known gaps, test status, and next recommended task. Do not claim a feature is verified unless automated checks passed and manual verification evidence is recorded.
```
