# 21 — Workplace Management Simulation

## Purpose

The Workplace Management Simulation (WMS) is an additive, content-driven
simulation capability for practising observable workplace decisions. It does
not replace the existing Phase 2 Practice simulation.

The engine boundary is industry-neutral. Logistics is the first authored
content pack, not an architectural constraint.

## Layered product strategy

1. Layer 1 — focused 2D interactive tasks.
2. Layer 2 — linked stories and deterministic operational events.
3. Layer 3 — AI-assisted NPC and voice roleplay behind reviewed safety and
   consequential-decision boundaries.
4. Layer 4 — full workplace-day and operational-system simulations.
5. Layer 5 — supervised multiplayer workplaces.

Version 0.2 implements only the technical backbone required for Layers 1 and
2. Later layers require separate product, safety, privacy, infrastructure and
interaction decisions.

## Version 0.2 scope

- Typed, versioned pack, workplace, role, competency, mission, task, resource,
  scoring, critical-error and remediation content.
- A deterministic seeded scenario generator.
- An explicit mission state machine.
- Candidate-action validation separated from technical events.
- Content-driven action evaluation.
- Deterministic weighted scoring and critical-error handling.
- Competency evidence and remediation generation.
- Candidate-isolated local attempt and result persistence.
- A UI-neutral Riverpod application controller.
- Local logistics content for the first receiving mission.

Version 0.2 originally excluded production screens. Approved Screens 01–05 are
now connected as subsequent presentation slices, and Screen 06 is a controlled
Inspection Zone placeholder.

Still excluded:

- Screen 06 inspection behaviour and later workstation workflows.
- Assumptions about Barcode, Quarantine, Office or result behaviour.
- Supabase schema or synchronization.
- AI providers, NPCs, voice, Redis or BFF changes.
- Changes to the existing Phase 2 simulation.

## Content and versioning

The local repository loads five JSON documents from
`assets/workplace_simulation/logistics/`:

- `pack.json`
- `workplace.json`
- `competencies.json`
- `remediation.json`
- `receive_shipment_mission.json`

References are cross-validated when content loads. Mission validation checks
stage, task, resource and competency references and requires both competency
weights and score-category weights to total one. Attempt records retain the
mission version and scenario seed so a result can be reconstructed.

Published content must remain immutable. A content change that affects
behaviour or scoring requires a new mission version.

## Runtime

The state machine allows only declared transitions:

```text
created → briefed → active ⇄ paused → submitted → scoring → completed
                                                    ↘ failed
```

A retry always creates a fresh attempt identifier and seed. Actions are
append-only, candidate-owned and continuously sequenced. Technical events use
the same audit stream but are explicitly excluded from scoring.

The scenario generator uses a stable local algorithm plus mission-version
input. The same mission version and seed produce exactly the same scenario.
Different seeds vary issue placement while preserving mission constraints.

## Evaluation, scoring and evidence

Task validation checks mission state, task ownership, action type, target,
repeat rules, sequence and required exception reasons. Evaluation rules are
authored in mission content and may inspect deterministic scenario properties.

Scoring is reproducible from the action outcomes:

- category earned and available points are calculated independently;
- category weights produce the overall score;
- authored penalties are applied;
- mandatory-task completeness is explicit;
- critical-error failure takes priority over incomplete or retry outcomes;
- technical failures never reduce a candidate score.

Results include score categories, outcome, labels, missed issues, triggered
critical errors, remediation and competency evidence. Evidence records retain
attempt, mission, mission version and seed provenance.

## Application boundary

`WorkplaceSimulationController` coordinates content, attempts, scenarios,
validation, evaluation, progress, scoring and retry through stable repository
interfaces. It exposes state and commands but does not navigate or render.

The future production presentation layer must consume these interfaces only
after the approved screen-by-screen interaction specification defines screen
states, actions, validation display, navigation, failure handling,
accessibility and exact results.

The approved Simulation Entry, Supervisor Briefing, Workplace Overview,
Document Desk and Receiving Dock presentations call this controller. Attempt
mutation remains outside Flutter widgets.

Document Review and Receiving Count are persisted aggregates. Their current
drafts may be revised, while each meaningful learner action remains append-only.
Structurally valid submission completes and unlocks the next process stage even
when its evidence is incorrect; the unchanged scoring engine evaluates quality
separately.

Operational submission uses a repository `commitOperationalUpdate` boundary so
draft state, actions, audits and derived progress are saved together. The local
encrypted repository can provide this atomicity because an attempt is one
stored value. A future database adapter must implement a real transaction.

## Persistence and future synchronization

The current attempt repository uses encrypted local key-value storage through
the existing secure-storage abstraction. Candidate ownership, immutable action
prefixes, continuous sequence numbers and fresh retries are enforced locally.

Remote persistence remains deferred. Any later Supabase/BFF adapter must
preserve the same contracts, ordered idempotent actions, version provenance
and candidate ownership without weakening RLS or the planned consequential
operation boundary.
