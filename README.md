# Skilling Platform — AI Employment Operating System for India

## Mission
Build an AI-native employability platform for India's grey-collar and operational workforce. The platform enables candidates to discover suitable roles, diagnose skill gaps, practise real work, improve through vernacular voice AI, prove practical readiness, get hired, and succeed during the first 90 days of employment.

This repository is the single source of truth for product, architecture, engineering, AI, design, delivery, governance, and implementation context. Every engineer, product manager, designer, contractor, and AI coding agent must read this README and the linked documentation before making changes.

## Initial Pilot
**Supply Chain & Logistics Operations**

Initial roles:
- Warehouse Operations Associate
- Inventory Executive
- Dispatch Executive
- Hub Supervisor
- Shift Supervisor

## Core Product Pillars
1. **Simulated Work Sandbox** — candidates practise realistic workflows rather than only consuming lessons.
2. **Vernacular Voice-AI Coach** — interview, communication, and workplace practice in Hindi, Hinglish, and later regional languages.
3. **Demand-led Employer Pipeline** — employer SOPs, role-specific readiness thresholds, and evidence-based hiring.

## Strategic Moats
- Workplace Reliability Graph
- Phygital hardware verification
- Earn-while-you-learn micro-gigs
- ATS and HRMS integrations
- Career Passport, benefits, and retention layer

## Product Surfaces
- Marketing website: acquisition, SEO, trust, partnerships, and app download.
- Candidate mobile app: the primary candidate product.
- Employer web portal: requisitions, candidate evidence, hiring, onboarding, and retention.
- Admin web portal: content, AI quality, operations, disputes, compliance, and analytics.
- Backend/AI platform: identity, data, scoring, simulations, voice, recommendations, integrations, and auditability.

## Non-Negotiable Principles
- Mobile-first and low-bandwidth candidate experience.
- Hindi/Hinglish first; regional languages follow.
- Practical evidence over passive completion.
- No accent discrimination or opaque personality scoring.
- Explainable scores, uncertainty indicators, and appeal mechanisms.
- Explicit consent for voice, assessments, employer sharing, and post-placement monitoring.
- Human review for consequential or disputed AI decisions.
- Reliability Score must measure platform-observed behaviours, not infer personal morality or guarantee retention.
- Financial products must be delivered only through appropriately regulated partners.
- Aadhaar, Skill India, CSC, ATS, and employer integrations require official access and contractual approval.
- Infrastructure, data, secrets, and accounts must remain separate from ZHealth and all other businesses.

## Documentation Index
1. [Master Plan](docs/00-master-plan.md)
2. [System Architecture](docs/01-system-architecture.md)
3. [Database Design](docs/02-database-design.md)
4. [API Specifications](docs/03-api-specifications.md)
5. [UI/UX Design System](docs/04-ui-ux-specification.md)
6. [AI Architecture](docs/05-ai-architecture.md)
7. [Voice Architecture](docs/06-voice-architecture.md)
8. [Prompt Library](docs/07-prompt-library.md)
9. [Simulation Engine](docs/08-simulation-engine.md)
10. [Candidate Mobile App](docs/09-candidate-mobile-app.md)
11. [Employer Portal](docs/10-employer-portal.md) — target design; the real portal is two API routes and a dev-only QC page today, see doc 03's own disclaimer.
12. [Admin Portal](docs/11-admin-portal.md) — target design; unbuilt.
13. [Engineering Handbook](docs/12-engineering-handbook.md)
14. [Security, Privacy and Compliance](docs/13-security-privacy-compliance.md)
15. [Analytics and Reliability Graph](docs/14-analytics-reliability-graph.md)
16. [Integrations and Phygital Network](docs/15-integrations-phygital-fintech.md)
17. [Sprint Plan](docs/16-sprint-plan.md) — superseded by the phase-execution plan (18); kept for history.
18. [Codex Phase Execution Plan](docs/20-codex-phase-execution.md) — the plan actually followed.
19. [Claude Code Implementation Prompts](docs/17-claude-code-prompts.md)
20. [Architecture Decision Records](docs/18-architecture-decisions.md) and [docs/adr/](docs/adr/) — six accepted ADRs (0013–0018) covering the decisions actually made since Phase 1.
21. [Layered Simulation Strategy](docs/21-layered-simulation-strategy.md) and [Workplace Management Simulation](docs/21-workplace-management-simulation.md) — share the number 21 pending a merge; the latter is the fuller, current spec.
22. [Simulation Content Schema](docs/22-simulation-content-schema.md)
23. [AI Employability Infrastructure Platform](docs/23-ai-employability-infrastructure-platform.md) — target-state proposal; no implementation authorised per the doc itself.
24. [Receiving Department Content Specification](docs/24-receiving-department-content-specification.md)
25. [Job Sourcing, Voice AI and Career Progression Plan](docs/25-job-sourcing-voice-ai-career-progression-plan.md) — Phase H (job sourcing) shipped; Phases I/J have not.
26. [Current Repository State](docs/generated/current-state.md) and [Block Diagram](docs/generated/block-diagram.md) — the machine-facing ground truth, updated every session per `AGENTS.md`.

## Actual Monorepo
```text
skilling-platform/
├── apps/
│   ├── candidate-mobile/    # Flutter / Dart — the real, shipping candidate product
│   └── api/                 # NestJS BFF — auth, jobs, shifts, career-passport, workplace-simulation
├── docs/                    # This documentation set, including docs/adr/ and docs/generated/
├── supabase/                 # Migrations and edge functions
├── ops/
└── flora-sim-v3/             # A separate, earlier simulation prototype -- not part of the shipping
                               # app; see docs/24 for why it's kept alongside rather than merged
```

Marketing/employer/admin web surfaces and the `packages/`-level shared-code split described in
earlier planning docs (00, 01, 09, 19) have not been built. `docs/10-employer-portal.md` and
`docs/11-admin-portal.md` describe target design, not shipped product.

## Phase Gate
No sector expansion occurs until the first logistics pathway demonstrates:
- completed diagnostic,
- at least three production-quality simulations,
- a voice interview assessment,
- explainable skill evidence,
- employer review and interview outcomes,
- measured joining and 30/60/90-day retention.

## Current Status
Phase 1 (candidate mobile shell) and Phase 2 (candidate intelligence) are built and shipping, with
Google Sign-In, email OTP, a Career Passport, a Shift Marketplace, and job sourcing from real
external sources (Adzuna/Jooble/Careerjet) all live. See
[docs/generated/current-state.md](docs/generated/current-state.md) for the authoritative,
continuously-updated build log — that file, not this line, is the source of truth for exactly
what's shipped versus still planned.
