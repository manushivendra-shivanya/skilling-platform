# Flora AI Employability Infrastructure Platform

Status: target-state architecture proposal; no implementation is authorised by
this document.

## 1. Product vision

Flora is India's trusted AI employability infrastructure for operational and
grey-collar careers.

It helps a person move from career uncertainty to sustained employment by
connecting career discovery, skill diagnosis, targeted preparation, realistic
workplace simulations, portable competency evidence, readiness decisions and
employment opportunities.

Flora is not a learning management system, training provider, assessment
agency, job board or government portal. It is the consent-aware intelligence
and evidence layer between those systems.

The product promise is:

> Turn observable candidate behaviour into explainable, portable and
> consent-controlled employability evidence, then use that evidence to
> recommend the next best career action.

Workplace Management Simulation remains Flora's core differentiator. It becomes
the Simulation Engine within a wider employability platform, not the organising
boundary of the entire product.

## 2. Product strategy

### 2.1 Strategic position

Flora should own:

- the candidate's continuous career journey;
- explainable career and readiness recommendations;
- simulation-derived and partner-supplied competency evidence;
- candidate-controlled evidence sharing;
- role-readiness and skill-gap intelligence;
- employer requirement translation and explainable matching;
- placement workflow enablement;
- longitudinal outcome feedback that improves recommendations.

Flora should integrate with, but not own:

- formal course delivery and attendance administration;
- regulated assessment or qualification issuance;
- occupational-standard governance;
- government scheme registration and statutory workflows;
- apprenticeship contracts and claims;
- employer recruitment decisions;
- training-centre operations.

### 2.2 Initial wedge

The initial wedge remains Supply Chain and Logistics Operations:

1. finish the current WMS receiving mission and validate candidate engagement;
2. convert simulation outcomes into stable competency evidence;
3. expose a candidate-facing Competency Passport;
4. validate employer comprehension and trust in that evidence;
5. close the loop with interview, joining and early-retention outcomes.

The platform should expand to another sector only after the evidence model,
employer value and candidate outcome loop are validated in logistics.

### 2.3 Product flywheel

```text
Career intent + diagnostic
        ↓
Recommended preparation
        ↓
Learning and simulations
        ↓
Versioned competency evidence
        ↓
Readiness and gap explanation
        ↓
Consented employer matching
        ↓
Interview, placement and employment outcomes
        ↓
Better role models, recommendations and progression paths
```

The outcome loop must never turn into opaque automated rejection. Employer
decisions remain human-owned and auditable.

## 3. Product architecture

### 3.1 Architectural style

Preserve the approved modular-monolith-first strategy:

- Flutter remains the candidate mobile platform.
- Independently deployable web applications serve organisational users.
- A NestJS BFF/API is the authoritative boundary for consequential operations.
- Supabase PostgreSQL is the initial system of record.
- Background workers handle event projection, evidence generation,
  recommendation jobs, notifications and integrations.
- Transactional outbox and idempotency protect cross-context workflows.
- Contexts may be extracted only for demonstrated scale, security, ownership or
  availability reasons.

No microservice decomposition is required for the MVP.

### 3.2 Platform layers

```text
Experience layer
  Candidate App | Employer Portal | Partner Portals | Government/Analytics
  Dashboards | Counsellor Portal | Admin Portal | Simulation Studio

Journey orchestration layer
  Next-best action | Career journey | Case/placement workflow | Notifications

Employability intelligence layer
  Discovery | Diagnosis | Recommendations | Readiness | Matching | Skill gaps

Evidence layer
  Evidence ledger | Competency graph | Passport | Sharing grants | Provenance

Capability engines
  Simulation | Micro-learning | Interview practice | Portfolio/Resume | AI Coach

Ecosystem integration layer
  Skill India Digital Hub | NCS | Apprenticeship India | SSC/NSDC/NCVET
  Training and assessment partners | Employer ATS/HRMS

Trust and platform layer
  Identity | Consent | Tenant access | Audit | Policy | Safety | Observability
```

### 3.3 Authority boundaries

| Concern | Authoritative owner |
|---|---|
| Candidate profile, goals and sharing choices | Candidate context |
| Career and occupation taxonomy | Career context, with versioned external mappings |
| Diagnostic attempt and recommendation inputs | Discovery context |
| Course catalogue and enrolment | Source training provider; Flora stores references and progress where authorised |
| WMS attempt transitions and learner actions | Simulation context |
| Formal assessment result and certificate | Recognised assessment/awarding body |
| Flora competency evidence and readiness projection | Competency context |
| Job vacancy and employer requirements | Employment context or integrated source |
| Hiring decision | Employer |
| Placement case workflow | Placement context |
| Government registration, scheme and apprenticeship contract | Relevant government platform |

## 4. Domain-driven design

### 4.1 Core domain

The core domain is **Employability Evidence and Decision Support**.

Its unique value is the defensible conversion of observable behaviour into
versioned evidence, readiness explanations and recommended next actions.

The Simulation context supplies high-quality behavioural observations. It does
not directly own the candidate's overall readiness, career journey or
employment outcome.

### 4.2 Supporting domains

- Career modelling
- Candidate journey
- Discovery and diagnosis
- Micro-learning orchestration
- Employment opportunity and matching
- Placement workflow
- Partner operations
- Integration orchestration
- Portfolio and resume
- Coaching and communication readiness

### 4.3 Generic domains

- Identity and access
- Consent and privacy
- Notifications
- File/media storage
- Payments, if introduced later
- Audit and observability
- Feature configuration
- Localisation

### 4.4 Context interaction rules

- No context reads another context's private tables.
- Cross-context state changes use application services and domain events.
- Synchronous APIs are used for user-blocking validation and commands.
- Asynchronous events are used for projections, analytics and external sync.
- Every externally sourced fact carries source, source identifier, observed
  time, effective time and verification status.
- AI output is a versioned recommendation or extraction, never an unlabelled
  authoritative fact.

## 5. Bounded contexts

### 5.1 Candidate context

Purpose: own candidate identity-linked career state and preferences.

Core aggregates:

- Candidate
- CareerGoal
- CandidateJourney
- CandidatePreference
- EducationRecord
- ExperienceRecord
- EmploymentHistory
- CandidateConsent
- SharingGrant

Publishes:

- `CandidateProfileUpdated`
- `CareerGoalChanged`
- `EvidenceSharingGranted`
- `EvidenceSharingRevoked`
- `EmploymentMilestoneRecorded`

### 5.2 Career context

Purpose: maintain a versioned model of work and progression.

Core aggregates:

- Industry
- Occupation
- Role
- CareerPath
- SkillProfile
- RoleCompetencyRequirement
- ExternalTaxonomyMapping

Rules:

- roles and requirements are versioned;
- mappings to NOS, QP, NSQF or employer taxonomies are explicit;
- Flora does not redefine regulated occupational standards.

### 5.3 Discovery context

Purpose: help a candidate identify viable career directions.

Core aggregates:

- DiscoverySession
- InterestProfile
- AptitudeObservation
- WorkPreferenceProfile
- CareerRecommendation
- RecommendationExplanation

AI may rank options, but the context must preserve inputs, model/prompt version,
confidence, exclusions and candidate feedback.

### 5.4 Learning context

Purpose: recommend and track small, employability-linked preparation units.

Core aggregates:

- LearningModule
- ContentPack
- LearningPathway
- EnrolmentReference
- LearningProgress
- CheckpointAttempt

Flora may host micro-learning content, but it should federate full courses from
training partners rather than grow into an LMS.

### 5.5 Simulation context

Purpose: run deterministic workplace experiences and emit evidence candidates.

Core aggregates:

- SimulationDefinition
- MissionVersion
- Scenario
- SimulationAttempt
- LearnerAction
- AttemptAuditEvent
- ActionOutcome
- SimulationResult

Preserved invariants:

- controller owns authoritative state transitions;
- learner actions are the only scoreable behavioural stream;
- audit events are unscored and append-only;
- attempt timing is operational lifecycle state;
- mission/content versions are immutable after publication;
- technical failures never reduce candidate scores;
- scoring remains deterministic where possible.

Published event:

- `SimulationEvidenceGenerated`

The event contains evidence candidates and provenance, not a global readiness
score.

### 5.6 Competency context

Purpose: accept evidence from multiple sources and build explainable readiness.

Core aggregates:

- Competency
- EvidenceRecord
- EvidenceClaim
- EvidenceProvenance
- CompetencyProfile
- ReadinessProjection
- SkillGap
- SkillPassport
- EvidenceSharingView

Evidence source types:

- Flora simulation;
- diagnostic;
- learning checkpoint;
- interview practice;
- employer observation;
- training-provider completion;
- recognised assessment result;
- verified employment outcome;
- candidate-supplied portfolio artifact.

Evidence is append-only. Corrections supersede records rather than rewriting
history.

Readiness is a projection for a versioned role requirement, not a permanent
attribute of a person.

### 5.7 Employment context

Purpose: represent demand and make explainable candidate-opportunity matches.

Core aggregates:

- Employer
- OrganisationTenant
- Job
- ApprenticeshipOpportunity
- RequirementProfile
- Match
- Application
- Interview
- Offer
- Joining
- RetentionOutcome

Rules:

- a match explains satisfied requirements, gaps and unknowns;
- sharing requires an active candidate grant;
- AI cannot autonomously reject a candidate;
- protected attributes are excluded from ranking;
- employer-specific observations do not silently alter portable evidence.

### 5.8 Placement context

Purpose: enable human placement teams without replacing employer systems.

Core aggregates:

- PlacementCase
- CandidateCohort
- EmployerLead
- VacancyAssignment
- CaseActivity
- InterviewSchedule
- PlacementMilestone
- FollowUp
- Escalation

This context provides CRM workflow, SLA and outcome capture. It does not become
the authoritative job exchange.

### 5.9 Partner context

Purpose: manage organisations, agreements and data-sharing boundaries.

Core aggregates:

- Partner
- PartnerType
- PartnerAgreement
- Programme
- Cohort
- PartnerUser
- DataExchangePolicy
- ServiceCapability

Partner types:

- training partner;
- placement organisation;
- employer;
- Sector Skill Council;
- assessment agency;
- State Skill Mission;
- government platform;
- career-counselling organisation.

Employer tenant data remains in the Employment context; Partner owns the
relationship and integration agreement.

### 5.10 Integration context

Purpose: isolate external schemas, credentials and reconciliation.

Core aggregates:

- ExternalConnection
- ExternalIdentityLink
- MappingSet
- SyncJob
- SyncCursor
- DeliveryReceipt
- ReconciliationCase

Every integration uses an anti-corruption layer. Government or partner payloads
must not become Flora's internal domain model.

### 5.11 Trust context

Purpose: enforce consent, policy, audit and review across the platform.

Core aggregates:

- ConsentReceipt
- PurposeGrant
- PolicyVersion
- AuditRecord
- AutomatedDecisionRecord
- Appeal
- DataSubjectRequest
- SafetyCase

This context owns policy enforcement; product contexts own their domain facts.

## 6. Module architecture

### Candidate App

- career discovery and goals;
- AI Career Advisor;
- roadmap and next-best action;
- micro-learning;
- simulations;
- competency passport and evidence wallet;
- readiness and skill gaps;
- interview and apprenticeship readiness;
- jobs and local opportunities;
- application and placement tracking;
- digital resume, portfolio and sharing controls;
- employment check-ins and progression.

### Employer Portal

- organisation and team management;
- requirement-profile builder;
- vacancies and apprenticeships;
- explainable candidate matches;
- consent-aware evidence views;
- shortlist, interview, offer and joining workflows;
- outcome feedback;
- aggregate skill-gap insights with privacy thresholds.

### Training Partner Portal

- programme and cohort references;
- candidate readiness and gap views with consent;
- learning recommendation intake;
- completion/evidence submission;
- placement outcome handoff;
- cohort analytics;
- no Flora-issued formal certification.

### Placement Organisation Portal

- candidate cases and cohorts;
- employer pipeline and vacancy assignments;
- interview calendar and tasks;
- placement SLAs, escalations and follow-ups;
- joining and retention outcomes;
- NCS or other exchange handoff where authorised.

### Government Dashboard

- programme-level aggregate outcomes;
- geography, sector and cohort skill-gap analysis;
- simulation participation and readiness movement;
- placement and retention funnel;
- privacy thresholds, suppression and export audit;
- no individual surveillance or opaque ranking.

### Career Counsellor Portal

- candidate-approved career profile;
- discovery-session facilitation;
- recommendation explanation;
- action plan;
- referrals to training, simulation or placement;
- notes with explicit visibility boundaries.

### Admin Portal

- taxonomy and policy administration;
- partner and tenant management;
- content publication;
- evidence disputes and appeals;
- safety and consent operations;
- integration monitoring;
- audit and support tools.

### Simulation Studio

- workplace, mission and resource authoring;
- validation and deterministic preview;
- competency and standard mapping;
- scoring/rubric versioning;
- accessibility and localisation review;
- staged publication and rollback.

### Analytics Portal

- product and operational metrics;
- evidence quality and model monitoring;
- fairness and language/device parity;
- funnel and cohort analysis;
- partner outcome reporting;
- governed exports.

## 7. User personas

1. **First-time job seeker** — needs discovery, confidence, basic evidence and
   nearby entry-level opportunities.
2. **Working candidate seeking progression** — needs gap diagnosis, targeted
   proof and a credible next-role roadmap.
3. **Career switcher** — needs transferable-skill mapping and low-risk role
   exploration.
4. **Career counsellor** — needs explainable options and a practical action
   plan, not a black-box recommendation.
5. **Employer recruiter** — needs job-relevant evidence and transparent gaps.
6. **Operations hiring manager** — needs proof of workplace judgement and safe
   behaviour.
7. **Training partner manager** — needs cohort gaps, referrals and outcome
   visibility.
8. **Placement officer** — needs case workflow, employer demand and follow-up.
9. **Assessment agency operator** — needs clean candidate/attempt handoffs and
   return of authoritative assessment results.
10. **SSC/standards steward** — needs traceable mapping to current occupational
    standards without Flora claiming standards authority.
11. **Government programme manager** — needs aggregate programme outcomes and
    accountable data provenance.
12. **Flora trust/support operator** — needs auditable decisions, consent,
    appeals and correction workflows.

## 8. User journey

### Candidate lifecycle

```text
Discover
  → establish interests, constraints and goals
Diagnose
  → collect aptitude, knowledge and work-preference observations
Choose
  → compare explainable role recommendations
Prepare
  → complete micro-learning and workplace simulations
Prove
  → accumulate provenance-backed competency evidence
Understand
  → view role-specific readiness, gaps and next-best action
Connect
  → share selected evidence with training or employment partners
Apply
  → prepare, interview and track placement
Join
  → record employment with candidate consent
Progress
  → receive 30/60/90-day support and next-role recommendations
```

### Employer lifecycle

```text
Define role demand
  → map requirements to versioned competencies
Receive explainable matches
  → inspect candidate-authorised evidence
Human review
  → interview, offer and join
Return outcomes
  → improve requirement quality and candidate preparation
```

### Partner lifecycle

```text
Create agreement and cohort
  → receive consented candidate gaps/referrals
Deliver owned service
  → return completion, assessment or placement outcomes
Reconcile
  → resolve identity/data conflicts without overwriting provenance
```

## 9. Capability map

| Capability group | Capabilities |
|---|---|
| Career discovery | interests, aptitude, work preferences, role exploration, counsellor support |
| Career intelligence | AI advisor, career recommendations, roadmaps, next-best action |
| Preparation | micro-learning, content packs, offline progress, training referral |
| Workplace practice | simulation marketplace, WMS runtime, scenario generation, scoring, remediation |
| Competency intelligence | evidence ledger, evidence graph, readiness, skill gaps, passport |
| Candidate representation | portfolio, digital resume, evidence wallet, sharing controls |
| Communication readiness | interview practice, voice feedback, transcript review |
| Employment | local matching, jobs, apprenticeships, applications, interview, offer, joining |
| Placement enablement | CRM, cohorts, employer pipeline, scheduling, SLA, retention follow-up |
| Partner operations | agreements, programmes, referrals, data exchange, reconciliation |
| Public-sector intelligence | aggregate dashboards, programme reporting, governed export |
| Trust | identity, consent, provenance, audit, appeal, privacy, fairness |
| Platform | API gateway, events, notifications, offline sync, observability, localisation |

## 10. Feature sets

### Career Discovery and AI Career Advisor

- guided interest, aptitude and constraint discovery;
- vernacular text and voice input;
- explainable role shortlist;
- salary/location data clearly labelled by source and date;
- counsellor handoff;
- candidate feedback and recommendation correction;
- no personality-based exclusion.

### Career Roadmaps and Career Readiness

- versioned target-role requirements;
- milestones for knowledge, behaviour, communication and evidence;
- current/target gap;
- next-best action;
- alternate routes through training, simulation or work experience;
- readiness confidence and evidence freshness;
- explicit unknown state instead of treating missing evidence as failure.

### Simulation Marketplace

- sector, role, difficulty and language discovery;
- publisher and version provenance;
- practice versus scored/verified labels;
- prerequisites and accessibility metadata;
- offline-capable downloads;
- employer or partner private catalogues;
- publication review and withdrawal without rewriting attempts.

### Competency Passport and Evidence Wallet

- competency profile with source-separated evidence;
- evidence timeline and provenance;
- role-specific readiness views;
- candidate-controlled sharing packages;
- expiry/freshness;
- correction, dispute and revocation;
- machine-verifiable export only after trust model approval.

### Employer Dashboard

- requirement templates;
- vacancy/apprenticeship management;
- explainable matches and unknowns;
- consent-aware passport view;
- human decision notes;
- interview, offer, joining and retention funnel;
- no automated final rejection.

### Placement CRM

- cohorts and candidate cases;
- employer accounts and demand;
- tasks, scheduling and reminders;
- interview preparation;
- milestone and document checklist;
- joining and 30/60/90-day follow-up;
- exception and grievance routing.

### Training Partner Dashboard

- cohort import and identity reconciliation;
- aggregate gap analysis;
- consented learner action plans;
- course referral intake;
- completion and attendance references;
- outcome exports;
- clear separation between partner certification and Flora evidence.

### Government Reporting and Skill Gap Analytics

- programme/cohort/geography/sector filters;
- participation, readiness movement and placement funnels;
- standards-aligned aggregate gaps;
- minimum-cell privacy suppression;
- data-quality and provenance indicators;
- scheduled, signed and audited exports.

### Local Employment and Apprenticeship Readiness

- distance/commute, shift, wage, language and eligibility preferences;
- verified employer and source labels;
- apprenticeship eligibility checklist;
- document and interview readiness;
- handoff to the authoritative government or employer workflow;
- no duplicate apprenticeship contract management.

### Interview Readiness, Portfolio and Digital Resume

- role-specific practice;
- transcript review and structured feedback;
- candidate-selected portfolio artifacts;
- evidence-backed resume statements;
- multiple resume versions;
- expiring share links and purpose-specific exports;
- no fabricated achievements.

### AI Coach

- lifecycle-aware next action;
- grounded responses from candidate-approved data;
- voice/text and low-bandwidth modes;
- escalation to counsellor or support;
- action execution requires confirmation;
- prompt/model/version audit;
- safety boundaries for high-impact employment guidance.

## 11. Future integrations and government alignment

Integration is conditional on official partnership, documented API availability,
purpose limitation and security review. Screen scraping and credential sharing
are prohibited.

### Skill India Digital Hub

SIDH describes discovery, recommendation, skilling, assessment, apprenticeship,
jobs and an API-based trusted credential layer. Flora should:

- deep-link or refer candidates to authoritative courses, centres and schemes;
- consume approved taxonomy or credential interfaces when available;
- publish candidate-authorised Flora evidence only under an approved trust
  framework;
- avoid duplicating SIDH's LMS, payment, programme registration or credential
  authority.

Official reference:
[Skill India Digital Hub — About](https://www.skillindiadigital.gov.in/about-us).

### National Career Service

NCS provides jobseeker registration, career information, counselling,
assessment access, job discovery and employer/placement workflows. Flora
should:

- enrich readiness before handoff;
- exchange jobs or applications only through an authorised interface;
- preserve NCS as the source of NCS vacancy/application status;
- never charge candidates for NCS access or imply government affiliation;
- avoid recreating a national employment exchange.

Official references:
[NCS home](https://www.ncs.gov.in/Pages/default.aspx/default.aspx) and
[NCS jobseeker terms](https://www.ncs.gov.in/pages/jobseeker-tnc.aspx).

### Apprenticeship India / NAPS

The official apprenticeship workflow covers establishment and candidate
registration, vacancies, offers, contracts, monitoring, returns and claims.
Flora should:

- calculate readiness and eligibility checklists;
- recommend relevant opportunities;
- prepare candidates and employers;
- hand off registration, offers, contracts and claims to the authoritative
  portal;
- reconcile status only through approved exchange.

Official reference:
[MSDE NAPS implementation guidelines](https://www.msde.gov.in/static/uploads/2024/04/Guidelines-for-NAPS.pdf).

### NSDC, SSCs and occupational standards

SSCs identify skills, define competency standards and qualifications and align
them to NSQF. Flora should:

- version mappings from Flora competencies and simulations to published NOS/QP;
- give SSCs validation and analytics workflows;
- treat SSC/NCVET standards as external authority;
- never claim that a Flora readiness score is an NSQF qualification.

Official references:
[NSDC Sector Skill Councils](https://nsdcindia.org/node/306) and
[NSDC standards and frameworks](https://stag-api.nsdcindia.org/standards-frameworks).

### Assessment agencies and NCVET

NCVET regulates recognised Awarding Bodies and Assessment Agencies. Flora
should:

- provide assessment-readiness preparation and consented evidence packages;
- schedule or hand off formal assessments;
- ingest authoritative results with issuer provenance;
- display formal certification separately from Flora evidence;
- never issue or imply regulated certification unless separately recognised.

Official reference:
[NCVET](https://ncvet.gov.in/).

### Training partners and State Skill Missions

Flora should provide gap insights, candidate referrals, simulation services and
outcome reporting. Training delivery, attendance, scheme eligibility and
certification remain with the authorised partner or mission.

## 12. API strategy

### 12.1 API principles

- Contract-first OpenAPI for synchronous commands and queries.
- AsyncAPI/event catalogue for domain events.
- `/v1` external APIs with additive evolution and sunset policy.
- Idempotency key on every consequential mutation.
- Cursor pagination and deterministic ordering.
- Explicit tenant, purpose and candidate-sharing authorization.
- No client access to service-role credentials.
- Webhooks are signed, replay-protected, retryable and observable.
- Bulk partner exchange uses encrypted, checksummed manifests when APIs are not
  available.

### 12.2 API surfaces

- Candidate API
- Employer tenant API
- Partner API
- Counsellor/placement API
- Admin/trust API
- Simulation content and attempt API
- Evidence and passport API
- Integration adapter API
- Aggregate reporting API

### 12.3 Example contract boundaries

```text
POST /v1/discovery-sessions
POST /v1/simulation-attempts/{id}/actions
POST /v1/evidence-sharing-grants
GET  /v1/readiness-projections?roleVersionId=...
POST /v1/jobs/{id}/applications
POST /v1/partner-referrals
POST /v1/integrations/{connectionId}/sync-jobs
```

These are architectural examples, not authorised implementation endpoints.

### 12.4 Event backbone

Initial domain events:

- `DiscoveryCompleted`
- `CareerRecommendationAccepted`
- `LearningCheckpointCompleted`
- `SimulationEvidenceGenerated`
- `ExternalAssessmentRecorded`
- `CompetencyProfileChanged`
- `ReadinessProjectionChanged`
- `EvidenceSharingGranted`
- `ApplicationSubmitted`
- `InterviewCompleted`
- `CandidateJoined`
- `RetentionMilestoneRecorded`

Events use globally unique IDs, aggregate version, actor, occurred time,
correlation/causation IDs, schema version and classification. PII is referenced,
not broadly copied into events.

## 13. Data architecture

### 13.1 Operational data

Use PostgreSQL schemas or clearly owned table groups per bounded context inside
the initial modular monolith.

Key stores:

- PostgreSQL: authoritative transactional state;
- object storage: resumes, portfolio artifacts and consented media;
- encrypted mobile storage: offline attempts and pending commands;
- queue/outbox: reliable asynchronous delivery;
- analytics warehouse: de-identified/controlled analytical projections;
- search index, introduced only when job/content discovery volume requires it.

### 13.2 Evidence model

An `EvidenceRecord` should minimally include:

- evidence ID and candidate ID;
- competency/version;
- source type and source record ID;
- issuer and verification status;
- observed behaviour or outcome;
- rubric/standard mapping;
- confidence and limitations;
- valid/effective/freshness dates;
- created time and supersession link;
- visibility classification;
- cryptographic digest for export verification where justified.

Do not collapse evidence into a single mutable candidate skill score.

### 13.3 Evidence graph

The first implementation should use relational adjacency tables and materialised
projections, not a graph database.

Nodes:

- candidate;
- evidence;
- competency;
- role requirement;
- learning unit;
- simulation mission;
- qualification/NOS mapping;
- job requirement;
- employment outcome.

Edges are typed, versioned and provenance-bearing. Introduce specialised graph
infrastructure only after measured query limitations.

### 13.4 Readiness projection

A readiness projection is keyed by:

- candidate;
- target role requirement version;
- projection policy version;
- evidence cutoff time.

It contains:

- satisfied requirements;
- partial requirements;
- gaps;
- unknowns;
- evidence freshness;
- confidence/coverage;
- next recommended actions;
- explanation.

### 13.5 Privacy and governance

- purpose-specific consent, not blanket consent;
- candidate visibility controls and revocation;
- tenant isolation and row-level security;
- data minimisation in partner integrations;
- retention and deletion schedules by record class;
- immutable audit for evidence access and consequential decisions;
- fairness monitoring across language, geography, gender and device class;
- aggregate-report privacy thresholds;
- data residency and government-contract requirements assessed per integration.

## 14. Recommended MVP

The recommended MVP is narrower than the complete platform:

### Candidate outcome

A logistics candidate can:

1. choose a target role;
2. complete a lightweight discovery/diagnostic;
3. receive an explainable role roadmap;
4. complete focused learning and WMS missions;
5. see a role-specific Competency Passport and readiness gaps;
6. create a consented evidence share;
7. view matched pilot opportunities;
8. prepare for and track an employer interview.

### Employer outcome

A pilot employer can:

1. publish a versioned requirement profile;
2. receive candidate-authorised, explainable matches;
3. inspect evidence provenance;
4. record shortlist/interview/offer/joining outcomes.

### Partner outcome

A pilot training or placement partner can:

1. manage a cohort reference;
2. see aggregate gaps;
3. receive consented referrals;
4. return completion or placement outcomes.

### Explicit MVP exclusions

- national course marketplace;
- formal certification;
- automated hiring decisions;
- government production integrations without agreement;
- custom microservices;
- graph database;
- full LMS;
- apprenticeship contract/claim processing;
- cross-sector expansion before logistics validation.

## 15. Three-year roadmap

### Year 1 — Prove evidence-to-employment value

**Phase 1: WMS MVP**

- finish the current logistics WMS experience;
- validate deterministic attempts, evidence generation and candidate usability;
- retain the existing Flutter/Android pipeline.

**Phase 2: Career Discovery**

- role taxonomy, candidate goals, lightweight diagnostic;
- explainable career recommendation and roadmap;
- logistics-only initial scope.

**Phase 3: Competency Passport**

- multi-source evidence ledger;
- role-specific readiness projection;
- candidate evidence wallet and sharing grants.

Success gate:

- candidates understand and act on readiness guidance;
- employers understand the evidence;
- simulation evidence predicts useful interview observations without unfair
  subgroup degradation.

### Year 2 — Build the demand and placement network

**Phase 4: Employer Portal**

- requirement profiles, matching, evidence review and hiring outcomes.

**Phase 5: Placement Organisation and Training Partner**

- cohorts, referrals, placement CRM, training completion references;
- 30/60/90-day outcome loop.

**Phase 6: Controlled ecosystem integrations**

- one authorised integration each for jobs, training/credentials or
  apprenticeship handoff;
- governed programme reporting.

Success gate:

- measurable improvement in shortlist-to-interview, offer-to-joining or
  retention for pilot cohorts;
- sustainable employer/partner willingness to pay;
- reliable consent and reconciliation operations.

### Year 3 — National employability intelligence

**Phase 7: AI Career Infrastructure**

- lifecycle-aware AI advisor;
- cross-role career progression;
- local labour-market and skill-gap intelligence;
- scalable standards and partner mappings;
- governed government dashboards and APIs;
- additional sectors selected by evidence and partner demand.

Success gate:

- independently audited trust, fairness and security;
- repeatable cross-sector onboarding;
- high-quality longitudinal outcomes;
- no dependence on opaque model-only decisions.

## 16. Risks and controls

| Risk | Control |
|---|---|
| Product expands into an LMS/job portal | Maintain explicit authority matrix and integration-first reviews |
| Readiness treated as formal certification | Separate Flora evidence from regulated assessment and use precise labels |
| AI recommendations become opaque gatekeeping | Explanation, versioning, human review, appeal and no auto-rejection |
| Weak evidence validity | Provenance, rubric versioning, employer outcome studies and freshness |
| Government integration assumed before agreement | Partnership/API gate; no scraping or credential sharing |
| Candidate loses control of data | Purpose grants, revocation, access log and minimal sharing packages |
| Employer bias enters requirement profiles | Requirement review, protected-field exclusion and fairness monitoring |
| Taxonomy drift | Versioned external mappings and scheduled SSC/NOS review |
| Partner data conflicts | Anti-corruption layer, source authority and reconciliation cases |
| Premature microservices/graph infrastructure | Modular monolith and measured extraction triggers |
| Low-bandwidth/device exclusion | Flutter offline-first design, small artifacts and accessible fallbacks |
| Mobile architecture documentation drifts | ADR-0016 makes Flutter authoritative; CI checks and documentation review preserve alignment |

## 17. Recommended implementation order

1. Complete and validate the current WMS milestone already in progress.
2. Stabilise `SimulationEvidenceGenerated` as a domain contract.
3. Define the versioned Career/Role/Competency taxonomy and external mappings.
4. Implement the evidence ledger before building a broad passport UI.
5. Build one role-specific readiness projection with gaps and unknowns.
6. Add candidate evidence wallet and purpose-specific sharing grants.
7. Add lightweight discovery and roadmap against the same role model.
8. Run an employer evidence-comprehension prototype before building the full
   Employer Portal.
9. Implement employer requirement profiles and human-owned match review.
10. Capture interview, offer, joining and retention outcomes.
11. Add placement/training partner workflow only for an active pilot.
12. Start a government integration only after a signed partnership, interface
    specification, data-protection review and operational owner exist.
13. Expand the AI advisor after the underlying facts, actions and explanations
    are reliable.
14. Expand sectors only after the logistics outcome loop passes its success
    gate.

## 18. Architecture decision gates

No implementation for the target architecture should begin until these are
approved:

1. **Product boundary:** Flora evidence/readiness versus regulated assessment.
   Approved — see ADR-0018.
2. **Canonical taxonomy:** internal role/competency model and SSC/NOS mappings.
   Approved — see ADR-0018.
3. **Evidence semantics:** source types, verification, freshness and
   supersession. Approved — see ADR-0018.
4. **Readiness policy:** coverage, unknowns, explanation and prohibited uses.
   Approved — see ADR-0018.
5. **Sharing model:** purpose, recipient, duration, revocation and audit.
   Approved — see ADR-0018.
6. **Employer decision boundary:** permitted matching and prohibited automated
   decisions. Approved — see ADR-0018.
7. **Partner authority matrix:** source-of-truth rules per integration.
   Approved — see ADR-0018.
8. **Mobile architecture conformance:** preserve ADR-0016, Flutter and the
   Android build pipeline across every product module. Satisfied.
9. **Route conformance:** preserve ADR-0017 and the canonical `/practise`
   Workplace Simulation hierarchy without `/practice` aliases. Satisfied.

All nine gates are resolved. This does not itself authorise building the
target-architecture layers named in section 3 — see section 19: WMS
continues unaffected, and the next architecture-only milestone is still the
Career taxonomy and Evidence contract design named there.

## 19. Immediate development-flow impact

This proposal does not replace approved WMS architecture or authorise new
platform code.

The current WMS work should continue behind stable interfaces:

- Simulation remains feature-first inside the Flutter app.
- Existing mission state, scoring, evidence and audit boundaries stay intact.
- UI sends intents and renders controller state.
- WMS publishes evidence through a future application/domain contract rather
  than directly mutating a global candidate score.
- No Career, Employment, Partner or Government dependency is added to WMS.
- Screen-by-screen WMS milestones keep their current validation, documentation,
  commit, GitHub Actions, APK publication and device-QC workflow.

After the current WMS milestone, the next architecture-only milestone should
define the Career taxonomy and Evidence contract. The next implementation
milestone should be selected only after those contracts are approved.
