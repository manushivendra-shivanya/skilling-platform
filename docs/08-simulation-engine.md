# 08 — Simulation Engine

## Objective
Create reusable, versioned, auditable workplace simulations that capture process, judgement, timing, accuracy, and escalation—not only final answers.

## Current Implementations
- The Phase 2 inventory-discrepancy flow remains the production Practice
  experience and is not replaced.
- The additive Workplace Management Simulation v0.2 backbone lives under
  `features/workplace_simulation`. It is content-driven and industry-neutral
  at the engine boundary.
- The first local content pack models a logistics receiving mission so the
  generic runtime can be validated before the final interaction contract is
  applied.
- The Receiving mission is complete end to end (Document Desk through
  Performance Feedback) and the Put Away mission is complete end to end
  (Staging Area through Performance Feedback) -- see
  `docs/generated/current-state.md`'s WMS milestone entries for the full
  build history from the original Screen 01/02 handoff to today.
- See `docs/21-workplace-management-simulation.md` (includes the layered
  simulation strategy), `docs/22-simulation-content-schema.md` and
  ADR-0015.

## Authoring Model
A simulation version contains:
- metadata and target role,
- learning objectives,
- competency mappings,
- scenario state,
- screens/widgets,
- tasks and dependencies,
- rules and timers,
- allowed actions,
- injected events,
- completion conditions,
- scoring rubric,
- accessibility and language content.

The runtime must not infer presentation from this content. Screens translate
the approved interaction contract into domain commands; domain services remain
independent of Flutter widgets and navigation.

## Runtime State Machine
```text
CREATED → BRIEFED → ACTIVE → PAUSED → SUBMITTED → SCORING → SCORED
                                            ↘ INVALID/ABANDONED
```

## Event Types
- screen opened
- task accepted
- item scanned
- quantity entered
- record compared
- decision selected
- escalation sent
- timer expired
- hint used
- answer revised
- network offline/online
- app backgrounded

Technical failures are separated from candidate behaviour.

## Scoring
### Deterministic dimensions
- accuracy
- completion
- sequence compliance
- SLA adherence
- unsafe action avoidance

### Rubric dimensions
- prioritisation
- escalation quality
- communication
- risk recognition

### Score output
- total score
- dimension scores
- evidence events
- confidence
- invalidation flags
- improvement actions

## Initial Logistics Simulation Catalogue
1. Inventory discrepancy and cycle count
2. GRN and invoice reconciliation
3. Dispatch priority under SLA pressure
4. Pick-pack exception handling
5. Shift and workforce allocation
6. Temperature excursion escalation
7. Customer complaint and proof-of-delivery review
8. Supervisor handover

## Anti-Cheating and Integrity
- Randomised but equivalent scenario parameters.
- Attempt-level signed version.
- Server validation of event sequence.
- Device anomaly monitoring with privacy limits.
- No intrusive camera proctoring by default.
- Human review before consequential fraud flags.

## Authoring Workflow
Draft → domain review → scoring calibration → accessibility review → pilot → publish → monitor → revise as new immutable version.

## Phygital Bridge
Physical assessments use a compatible evidence schema but remain separately labelled. Assessor identity, centre, equipment, checklist, and media evidence are recorded with consent.
