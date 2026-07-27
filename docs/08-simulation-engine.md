# 08 — Simulation Engine

## Objective
Create reusable, versioned, auditable workplace simulations that capture process, judgement, timing, accuracy, and escalation—not only final answers.

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
