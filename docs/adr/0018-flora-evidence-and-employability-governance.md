# ADR-0018: Flora Evidence, Competency and Employability Governance

- Status: Accepted
- Date: 2026-07-30
- Owners: Product

## Context

`docs/23-ai-employability-infrastructure-platform.md` section 18 names nine
architecture decision gates that must be approved before any target-state
Employability Infrastructure code (Career taxonomy, Evidence ledger,
Competency Passport, Employer Portal, Partner integrations) is built. Two of
the nine — mobile architecture conformance (ADR-0016) and route conformance
(ADR-0017) — were already satisfied by existing practice. This ADR records
the approved decision for the remaining seven: product boundary, canonical
taxonomy, evidence semantics, readiness policy, sharing model, employer
decision boundary, and partner authority matrix.

These decisions govern what Flora is permitted to claim, store, share and
automate once evidence and readiness features are built on top of Workplace
Management Simulation (WMS). They do not authorise building those features;
they constrain how they must be built when work on them begins. WMS itself is
unaffected — it continues to operate behind stable interfaces per doc 23
section 19, with no Career, Employment, Partner or Government dependency.

## Decision

### 1. Product boundary

Flora is an evidence and decision-support provider, not a certification
authority.

Flora may state:

- "Completed a Flora workplace simulation."
- "Demonstrated these behaviours under simulation conditions."
- "Achieved 82% against Flora rubric version 1.2."
- "Current evidence meets Flora's simulation benchmark for this role."

Flora must not state:

- "Certified Receiving Supervisor."
- "Government-certified."
- "NSQF qualified."
- "Guaranteed job-ready."
- "Approved by NCVET/SSC," unless a formal agreement explicitly authorises
  it.

Every result screen, PDF and API response carrying Flora evidence must
display: *"This is Flora-generated simulation evidence. It is not a
regulated qualification, licence, or certification."* Formal certificates
must be displayed separately, with the recognised awarding body named as
issuer (NCVET recognises and regulates Awarding Bodies and Assessment
Agencies under its Awarding Body framework; an Awarding Body issues
certification for approved qualifications — Flora is not one).

### 2. Canonical taxonomy

Flora owns an internal, versioned taxonomy as its primary identifier system:

```text
Flora Role
  └── Flora Competency
        └── Observable Behaviour
              └── Mission/Rubric Indicator
```

External standards (QP/NOS/NSQF, employer competencies, training-partner
competencies) are **mappings**, not Flora's primary identifiers:

```text
Flora Competency
  ↔ QP/NOS/NSQF mapping
  ↔ Employer competency
  ↔ Training-partner competency
```

Each mapping record requires: Flora competency and version; external
authority; QP/NOS/standard code and version; mapping strength (`exact`,
`partial`, `related`, or `unmapped`); effective and retirement dates;
evidence supporting the mapping; review status; and reviewer/approval
provenance.

Mapping status values: `proposed`, `floraReviewed`, `externallyValidated`,
`deprecated`, `superseded`. Only `externallyValidated` mappings may be shown
as validated by an SSC or recognised body. A named Flora Standards Steward
owns scheduled reviews and must reassess mappings when the external standard
changes.

Flora's taxonomy is canonical internally; NCVET/SSC standards remain
externally authoritative for anything they govern.

### 3. Evidence semantics

Evidence is append-only, provenance-labelled and freshness-aware. Retakes
accumulate; corrections supersede.

Verification classification (describes provenance, never implies
certification): `systemObserved` (generated from Flora's deterministic
simulation), `issuerVerified` (received from an authenticated authoritative
issuer), `partnerAttested` (asserted by an identified partner),
`candidateReported` (entered by the candidate), `unverified` (provenance or
integrity could not be established).

Every evidence record is immutable and must include: candidate, competency
and evidence IDs; source and issuer; observation and rubric versions;
attempt ID; score and critical-error results; verification classification;
limitations; issued, effective and freshness dates; integrity digest;
supersession link; and visibility/sharing restrictions.

Retake handling:

- All attempts remain in the audit history.
- A corrected record supersedes the erroneous record.
- A retake is a **new** evidence record, not a correction of the old one.
- The current projection uses the latest eligible evidence under a
  published policy; older evidence remains visible in the timeline.
- Expiry makes evidence stale; it does not delete it. Expiry periods are
  competency-specific and policy-versioned.

### 4. Readiness policy

Readiness is a time-bound, explainable projection against a Flora
benchmark — not a permanent candidate attribute or a success prediction.

Four outcomes only: `demonstrated` (current evidence meets the versioned
Flora benchmark), `developing` (sufficient evidence exists and identifies
material gaps), `insufficientEvidence` (coverage is too low to reach a
conclusion), `staleEvidence` (required evidence exists but is no longer
current). "Unknown" must never silently become "not ready."

A role-readiness policy must specify: role requirement version; required
competencies; critical vs. non-critical competencies; minimum evidence
coverage; allowed evidence sources; freshness rules; critical-error
overrides; scoring thresholds; and explanation requirements.

For the first WMS pilot, the safest candidate-facing label is *"Simulation
benchmark demonstrated"* — never *"job ready."*

Flora must never imply: guaranteed employment; predicted workplace success;
formal qualification; medical, safety or legal fitness; or automatic
eligibility for a vacancy.

### 5. Sharing model

Sharing is candidate-controlled, evidence-selective, purpose-bound,
time-limited, revocable and audited.

Every evidence share is a separate, purpose-specific grant containing:
candidate; recipient organisation; named purpose; selected evidence;
allowed fields; grant and expiry times; access channel; download
permission; revocation state; and consent-policy version.

Default grant: 30-day access, no onward sharing, no access to unrelated
evidence, candidate can revoke at any time, every view and download is
audited.

Revocation stops future access; it cannot technically retrieve a PDF
already downloaded, and the consent screen must say this clearly. Retained
employer records require their own documented legal purpose and retention
policy. This aligns with India's DPDP framework, which requires consent to
be specific, informed and limited to necessary data, and provides for
withdrawal with comparable ease (Digital Personal Data Protection Act,
2023; DPDP Rules, 2025).

### 6. Employer decision boundary

Flora presents evidence; the employer owns every consequential hiring
decision. Automated candidate ranking is **prohibited in the MVP**.

For the initial Employer Portal, Flora may: show candidate-authorised
evidence; explain satisfied requirements, gaps and unknowns; filter by
objective, job-relevant evidence fields; identify incomplete or stale
evidence; support human-authored shortlist decisions; and record employer
decision reasons.

Flora must not: automatically reject candidates; hide candidates based on a
readiness score; rank using protected or proxy attributes; infer sensitive
characteristics; treat missing evidence as failure; or present an AI
recommendation as an employer decision.

MVP search/comparison must be deterministic and transparent, not a ranking
model. Any future ranking capability requires a separate policy approval,
fairness testing, auditability and human override — it is out of scope
until that approval exists.

### 7. Partner authority matrix

Authority is defined per fact, not per integrated system.

| Fact | Authoritative owner |
|---|---|
| Flora simulation attempt/actions | Flora Simulation context |
| Flora evidence projection | Flora Competency context |
| Formal result/certificate | Issuing recognised body |
| QP/NOS/NSQF definition | NCVET/appropriate standards authority |
| Candidate sharing preference | Candidate/Consent context |
| NCS vacancy/application state | NCS |
| Employer vacancy and hiring decision | Employer |
| Training attendance/completion | Training provider |
| Apprenticeship contract/status | Authoritative government/partner platform |

When sources disagree: never overwrite the earlier assertion silently;
store both assertions with source, version and timestamps; use the
authority matrix to select the operational value; open a reconciliation
case; mark the disputed field in APIs and UI; preserve the resolution and
audit history. Integrations exchange provenance-bearing assertions —
conflicts trigger reconciliation, not last-write-wins.

## Alternatives Considered

- Let each feature (Competency Passport, Employer Portal, partner
  integrations) define its own evidence/sharing/authority rules ad hoc as
  it's built: rejected — produces inconsistent claims across surfaces and
  makes a compliance review impossible to scope.
- Adopt NSQF/NOS codes as Flora's primary identifiers instead of an
  internal taxonomy: rejected — couples Flora's competency model to
  external revision cycles Flora doesn't control, and blocks Flora from
  representing competencies no NOS code covers yet.
- Allow automated candidate ranking in the MVP Employer Portal: rejected —
  no fairness testing, auditability or human-override mechanism exists yet;
  revisit only behind its own future policy approval.
- Treat retakes as overwriting prior evidence: rejected — destroys audit
  history and makes evidence non-defensible if a result is later disputed.

## Consequences

- Every future evidence/readiness/employer-facing surface must be built
  against these decisions, not against convenience defaults.
- The Competency Passport and Employer Portal (doc 23 section 3, layers
  "Employability intelligence" and "Evidence") cannot ship without: the
  disclaimer string on every evidence surface, immutable append-only
  evidence storage, purpose-bound sharing grants, and a ranking-free
  employer search.
- A named Flora Standards Steward role must exist before any taxonomy
  mapping is marked `externallyValidated`.
- Partner integrations must be built with reconciliation-on-conflict from
  day one; retrofitting it later is materially harder once data has been
  silently overwritten.
- WMS's existing controller, action, audit, timing and scoring boundaries
  are unaffected — this ADR governs layers that don't exist yet.

## Security/Privacy Impact

This ADR is privacy-load-bearing. It commits Flora to: DPDP-aligned
purpose-bound, time-limited, revocable consent grants with full audit;
immutable evidence records (supporting dispute resolution and audit, not
silent correction); explicit non-retrievability disclosure for already-
downloaded shares; and a hard prohibition on inferring or ranking by
protected/proxy attributes. Any future design for evidence storage,
sharing-grant management, or employer search must be reviewed against this
ADR before implementation, not after.

## Migration/Rollback

No existing code implements evidence, readiness, sharing or employer
matching yet, so there is nothing to migrate. This ADR is the baseline any
future implementation is built against. Rollback or amendment of any of the
seven decisions requires a superseding ADR, not a silent implementation
deviation.

## References

- `docs/23-ai-employability-infrastructure-platform.md` (section 18,
  architecture decision gates 1–7; section 3, platform layers)
- NCVET Awarding Body framework
- Digital Personal Data Protection Act, 2023; DPDP Rules, 2025
- `docs/adr/0016-flutter-candidate-mobile-boundary.md`
- `docs/adr/0017-practise-workplace-route-hierarchy.md`
