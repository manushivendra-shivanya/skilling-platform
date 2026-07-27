# 01 — Complete System Architecture

## Architecture Style
Start as a modular monolith with independently deployable web/mobile clients and background workers. Preserve clear domain boundaries so high-volume voice, simulation, and integration workloads can later be extracted.

## Logical Components
1. Identity and access
2. Candidate profile and consent
3. Learning/pathway service
4. Assessment and competency service
5. Simulation runtime and authoring
6. Voice session and media service
7. AI orchestration and evaluation
8. Reliability and analytics service
9. Job, requisition, matching, and hiring service
10. Employer tenant and SOP service
11. Partner/phygital service
12. Payments/micro-gig ledger
13. Notification service
14. Admin and support service
15. Audit, policy, and compliance service

## High-Level Flow
```text
Mobile/Web Clients
      │
API Gateway / BFF
      │
Domain Modules ───── Event Outbox ───── Background Workers
      │                                     │
PostgreSQL                           AI/Voice/Media Providers
      │                                     │
Object Storage ← signed uploads → Media Processing
      │
Analytics Warehouse / BI
```

## Recommended Initial Stack
- Web: Next.js App Router, TypeScript
- Candidate: React Native with Expo and TypeScript
- API: TypeScript service using a structured framework or Next.js route handlers initially
- Database: PostgreSQL
- ORM/query layer: Drizzle or Prisma, selected by ADR
- Queue: managed durable queue
- Object storage: S3-compatible storage
- Cache/rate limiting: managed Redis-compatible service
- Auth: OTP-based provider with RBAC/tenant claims
- Observability: structured logs, traces, error tracking, product analytics
- Deployment: Vercel for web; managed runtime for workers and real-time voice where required

## Tenant Model
Employer and partner records carry `tenant_id`. Candidate identity is global, while candidate-to-employer sharing is controlled by explicit grant records. Internal administrators use scoped roles and audited impersonation.

## Critical Data Flows
### Voice interview
1. Client requests session.
2. Server checks consent, entitlement, language, and rubric version.
3. Client receives short-lived media credentials.
4. Audio streams or uploads in chunks.
5. Transcription produces timestamped segments.
6. Evaluation creates structured, versioned evidence.
7. Candidate receives coaching feedback.
8. Employer sees only authorised evidence.

### Simulation attempt
1. Client loads immutable simulation version.
2. Client records typed events with sequence IDs.
3. Server validates event ordering and scenario rules.
4. Scoring engine generates competency evidence and explanation.
5. Attempt is finalised, signed, and added to career passport when eligible.

## Resilience
- Idempotency keys on mutations.
- Transactional outbox for events.
- Retry with dead-letter queue.
- Offline-capable mobile attempt buffering.
- Resumeable uploads.
- Immutable assessment and prompt versions.
- Graceful AI-provider fallback without silently changing rubric semantics.

## Security Boundaries
- Public API
- Authenticated candidate API
- Employer tenant API
- Internal admin API
- Media upload boundary
- AI provider boundary
- Regulated partner boundary

## Scale Triggers for Service Extraction
Extract a module only when one of these is true:
- materially different scaling profile,
- independent security/compliance boundary,
- deployment cadence conflict,
- sustained operational ownership need,
- database contention or availability isolation requirement.
