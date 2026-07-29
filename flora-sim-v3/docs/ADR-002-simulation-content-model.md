# ADR-002 — Career-OS Simulation Content & Assessment Model

**Status:** Accepted
**Date:** 2026-07-28
**Decision owner:** Claude (technical architecture)
**Supersedes nothing; extends** ADR-001 (rendering technology).

---

## 1. Context

Flora is a **Career Operating System**, not a game: a learner performs an *entire
job*, department by department, and every action generates competency evidence.
Receiving is the first department; the same runtime must reuse for Put Away,
Picking, Packing, Dispatch, Inventory, Returns, Safety, Supervisor Ops.

The founder's design principles are binding:
- represent authentic workplace processes,
- prioritise learning over visual realism,
- **separate simulation logic from rendering**,
- reusable systems, not hardcoded missions,
- one runtime across industries,
- integrate with Flora's competency + assessment engine,
- **renderer-agnostic (2D, browser 3D, Unity, XR).**

## 2. Decision — a three-layer architecture

```
  ┌─────────────────────────────────────────────────────────┐
  │ 1. CONTENT LAYER  (pure data — no code, no rendering)    │
  │    Pack → Domain → Workplace → Department                │
  │    Areas · Object library · People library · Equipment   │
  │    Interaction verbs · Flow (state machine) · Scenarios  │
  │    Competency map · e.g. receiving.department.json        │
  └─────────────────────────────────────────────────────────┘
                     │ consumed by
  ┌─────────────────────────────────────────────────────────┐
  │ 2. SIMULATION RUNTIME  (renderer-agnostic engine)        │
  │    - loads content, runs the flow state machine          │
  │    - resolves interactions (verb × object → effect)      │
  │    - applies scenario config (injections/overrides)      │
  │    - emits append-only LearnerAction events              │
  │    - scores completion AND correctness (separate)        │
  │    Exposes a thin RendererAdapter interface only.        │
  └─────────────────────────────────────────────────────────┘
             │ RendererAdapter (spawn/move/highlight/prompt)
  ┌───────────────┬───────────────┬───────────────┬──────────┐
  │ 3a. 2D adapter│ 3b. R3F/3D    │ 3c. Unity     │ 3d. XR   │
  │  (accessible, │  (PRIMARY —   │  (future,     │ (future) │
  │  low-end)     │  ADR-001)     │  outsourced)  │          │
  └───────────────┴───────────────┴───────────────┴──────────┘
                     │ emits
  ┌─────────────────────────────────────────────────────────┐
  │ 4. EVIDENCE / ASSESSMENT  (Flora CareerOS)               │
  │    append-only LearnerAction stream → Postgres           │
  │    competency evidence · sequence · timing · corrections │
  └─────────────────────────────────────────────────────────┘
```

**The content layer and the runtime are the product. Renderers are swappable
adapters.** React Three Fiber (ADR-001) is the first and primary adapter; a 2D
adapter and, later, Unity/XR adapters can consume the *same* content and runtime
without changes to either.

> ### Deployment boundary (2026-07-28) — where each layer actually runs
> In Flora's deployment the split is client/server, not all-client:
> - **Flora Backend is authoritative** for the content layer, the simulation runtime
>   (flow state machine, interaction resolution, scenario config), and the
>   assessment/evidence/competency engines. It is the single source of truth.
> - **Clients are presentation only** — the **Flutter app** today and the **future
>   WebGL viewer**. They render backend-driven state and emit **append-only
>   `LearnerAction`** events back to the Backend; they hold no authoritative logic.
> - This matches the repo as built: `/practise` routes, atomic operational
>   persistence, append-only learner actions and audit events already live
>   server-side. The layer-2 "runtime" in the diagram is therefore a **backend
>   service**, and each renderer adapter is a thin client of it.

## 3. Key modelling choices

- **Departments are data, not code.** A department is one content document
  (`receiving.department.json`); adding Put Away or Picking means authoring another
  of the same shape. No new engine work per department.
- **Reusable entity libraries.** Objects, People, and Equipment are defined once
  with generic **interaction verbs** (walk, look, pickUp, place, open, close, read,
  scan, inspect, count, compare, measure, wearPPE, operate, speak, reportIssue,
  submitDecision). A `carton` exposes `scan/count/inspect/place` everywhere it
  appears; industries reuse the same verb set.
- **Flow = a state machine** over `areas`. Each step names its area, the verbs it
  needs, the objects/people it uses, the competencies it evidences, and the event
  it emits. The learner physically walks the areas; the flow gates progress.
- **Scenarios = configuration, not branches of code.** Each scenario is a small
  `config` object (injections/overrides: missing cartons, wrong SKU, unreadable
  barcode, temperature deviation…) plus an `expectedDecision`. The runtime applies
  the config to the same flow. Twelve Receiving scenarios today; add more as data.
- **Competencies are renderer-independent** and grouped Technical / Behavioural /
  Digital / Safety. Every interaction maps to competency ids.
- **Assessment is evidence, not a quiz.** The runtime emits an **append-only
  `LearnerAction`** stream (learnerId, sessionId, monotonic seq, ts, action, area,
  target, flowStep, scenarioId, result ∈ ok|error|corrected, competencies[], meta).
  **Completion ≠ correctness:** the learner can finish the shift while scoring low
  on competency; the two are reported separately. This matches Flora's existing
  append-only `LearnerAction` model — the sim is just another producer into it.

## 4. Consequences

- One runtime serves every department and every industry; content scales without
  engine changes.
- Rendering is decoupled: ship the accessible 2D adapter to the lowest-end phones
  and the R3F 3D adapter where the device allows, from the *same* content.
- The evidence stream is the integration surface with Flora — no renderer lock-in
  on assessment data.
- Cost of realism is deferred: greybox first (learning over visuals), assets filled
  later via procedural / bought / AI-generated glTF.

## 5. Build order

1. **Content layer for Receiving** — `receiving.department.json` (done).
2. **Runtime skeleton** — flow state machine + interaction resolver + LearnerAction
   emitter, headless and unit-testable (no renderer).
3. **R3F adapter** — walk the areas, interact with objects/people, render prompts.
   (Greybox walkthrough prototype proves the shape.)
4. **Wire evidence** to Flora's `LearnerAction` table.
5. **Second department (Put Away)** authored as data — validates reuse with zero
   engine changes. That test is the real proof the architecture holds.

## 6. Decision

Adopt the three-layer, renderer-agnostic model above. Content and runtime are
canonical; renderers are adapters (R3F primary per ADR-001, 2D for reach, Unity/XR
optional later). Assessment is the append-only LearnerAction evidence stream, with
completion and correctness scored separately.
