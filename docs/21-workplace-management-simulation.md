# 21 — Workplace Management Simulation

This file absorbs `docs/21-layered-simulation-strategy.md` (deleted): the
two shared the number 21, and the layered-strategy file's content was
almost entirely reproduced here already. Its one genuinely unique section
("Current boundary") is folded in below as "Current boundary," corrected
to match what has actually shipped since — the receiving and put-away
missions are complete end to end now, not just Screens 01–02.

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

Version 0.2 originally excluded production screens. That boundary has since
moved substantially — see "Current boundary" below for what's actually
built. What's still excluded, unchanged since v0.2:

- AI providers, NPCs, voice, Redis or BFF changes beyond the sync boundary
  described under "Persistence and future synchronization."
- Changes to the existing Phase 2 simulation.
- A second industry pack (the engine is industry-neutral; logistics
  remains the only authored content).

## Current boundary

The Receiving mission is complete end to end — Document Desk, Receiving
Dock, Inspection Zone, Barcode Station, Quarantine Zone, Receiving Office,
and Performance Feedback all built and connected, per
`docs/generated/current-state.md`'s WMS milestone entries. The Put Away
mission is also complete end to end (Staging Area through Performance
Feedback). Both are merged to `main`.

Remote persistence is **not** deferred: WMS has a live Supabase persistence
schema, a BFF sync endpoint (`WMS Attempt Sync API`), and a Flutter
offline-first sync adapter that's API-gated (activates only in builds
configured with both Supabase and `API_BASE_URL`; otherwise attempts stay
local-only, which is a config state, not a missing feature).

No WMS screen is withheld pending approval. The WebGL/3D spatial
interaction layer (Layer 4+ territory below) remains deliberately deferred
for production use, per direct discussion with the product owner rather
than a specific ADR — though a dev-tools-only proof of concept exists
(`workplace_simulation_3d/presentation/workplace_3d_preview_screen.dart`),
proving the render path works and nothing more.

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

The attempt repository is offline-first, not local-only: encrypted local
key-value storage through the existing secure-storage abstraction remains
authoritative, and — as described under "Current boundary" above — a
Supabase/BFF sync adapter now exists and activates whenever a build is
configured with both Supabase and `API_BASE_URL`. Candidate ownership,
immutable action prefixes, continuous sequence numbers and fresh retries
are enforced both locally and by the sync adapter, which preserves the
same contracts, ordered idempotent actions, and version provenance without
weakening RLS or the consequential-operation boundary.
