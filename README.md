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
5. [UI/UX Specification](docs/04-ui-ux-specification.md)
6. [AI Architecture](docs/05-ai-architecture.md)
7. [Voice Architecture](docs/06-voice-architecture.md)
8. [Prompt Library](docs/07-prompt-library.md)
9. [Simulation Engine](docs/08-simulation-engine.md)
10. [Candidate Mobile App](docs/09-candidate-mobile-app.md)
11. [Employer Portal](docs/10-employer-portal.md)
12. [Admin Portal](docs/11-admin-portal.md)
13. [Engineering Handbook](docs/12-engineering-handbook.md)
14. [Security, Privacy and Compliance](docs/13-security-privacy-compliance.md)
15. [Analytics and Reliability Graph](docs/14-analytics-reliability-graph.md)
16. [Integrations and Phygital Network](docs/15-integrations-phygital-fintech.md)
17. [Sprint Plan](docs/16-sprint-plan.md)
18. [Claude Code Implementation Prompts](docs/17-claude-code-prompts.md)
19. [Architecture Decision Records](docs/18-architecture-decisions.md)

## Proposed Monorepo
```text
skilling-platform/
├── apps/
│   ├── marketing-web/       # Next.js
│   ├── employer-web/        # Next.js
│   ├── admin-web/           # Next.js
│   ├── candidate-mobile/    # React Native / Expo
│   └── api/                 # API/BFF
├── packages/
│   ├── design-tokens/
│   ├── ui-web/
│   ├── ui-mobile/
│   ├── database/
│   ├── schemas/
│   ├── api-client/
│   ├── competency-engine/
│   ├── scoring-engine/
│   ├── simulation-engine/
│   ├── ai-evaluation/
│   ├── voice-core/
│   ├── analytics/
│   └── config/
├── services/
│   ├── realtime-voice/
│   ├── media-processing/
│   └── background-jobs/
├── infrastructure/
├── docs/
└── tests/
```

## Phase Gate
No sector expansion occurs until the first logistics pathway demonstrates:
- completed diagnostic,
- at least three production-quality simulations,
- a voice interview assessment,
- explainable skill evidence,
- employer review and interview outcomes,
- measured joining and 30/60/90-day retention.

## Current Status
Documentation foundation prepared. The next step is repository scaffolding and Sprint 0 implementation.
