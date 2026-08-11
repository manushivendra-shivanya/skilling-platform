# 15 — Integrations, Phygital Network, Micro-Gigs and Benefits

## ATS/HRMS Integration Framework
Use provider adapters with canonical objects:
- organisation
- requisition
- candidate
- application
- interview
- offer
- outcome

Capabilities:
- OAuth/API-key connection vault
- field mapping
- incremental sync
- webhook ingestion
- replay and idempotency
- reconciliation dashboard
- tenant-scoped logs

Initial candidates for research: Darwinbox, Keka, Zoho Recruit, Kredily and employer-specific APIs. Implementation depends on official partner access and current API documentation.

## Phygital Network
### Centre requirements
- verified partner and location,
- approved equipment inventory,
- trained assessor,
- candidate identity and consent process,
- safety checklist,
- evidence capture standard,
- grievance and incident process.

### Sandbox Saturday flow
Booking → reminder → centre check-in → equipment briefing → assessment → assessor sign-off → quality audit → physical verification badge.

Do not claim a CSC partnership until an agreement exists. Design the partner-centre system to support CSCs and private centres.

## Micro-Gigs

**A real, shipped implementation of this concept exists under the name
"Shift Marketplace" (Phase OD-1) — see
`docs/generated/current-state.md`'s "Phase OD-1" entry.** It predates this
section being reconciled against it, so treat the two as describing the
same thing rather than separate features: this section's design intent
(clear scope/stipend/acceptance criteria, no disguised unpaid work,
employer verification, dispute handling) is what the shipped feature
should be held to, not a different, still-unbuilt idea.

Shipped schema (`supabase/migrations/20260808000000_phase_od1_shift_marketplace.sql`):
`shift_requests`, `shift_applications`, `shift_payouts`,
`shift_grievances`, `candidate_shift_availability` — table names differ
from the `micro_gigs`/`micro_gig_assignments`/`wallet_ledger` names
`docs/02-database-design.md` proposes; that doc's tables were never built
under those names and should be read as superseded by the schema above,
not as an additional, still-pending set of tables.

Design intent, held against what's shipped:
- Clear scope, duration, stipend, expenses, ownership, safety, and acceptance criteria.
- No unpaid productive work disguised as assessment.
- Candidate acceptance and withdrawal.
- Employer verification and dispute window.
- Append-only payment ledger.

## Benefits Layer
Possible regulated-partner offerings:
- earned wage access,
- accident/health cover,
- savings,
- emergency assistance.

Rules:
- optional and separate from hiring,
- no dark patterns,
- licensed provider responsibility clearly shown,
- data minimisation and separate consent,
- transparent fees and grievance contacts.
