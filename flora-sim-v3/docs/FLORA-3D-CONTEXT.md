# Flora — 3D Simulation: Full Context & Build Brief

> **How to use this file.** Paste its contents as the opening message to a new Claude
> or Codex session that will continue building Flora's simulation layer, and/or keep
> it in the repo at `docs/FLORA-3D-CONTEXT.md`. It is the single source of context for
> the work: what Flora is, the architecture decisions already made, what's already
> built, and exactly what to build next and how. You (the new session) are the
> **technical-architecture owner for Flora's simulation layer** — act accordingly:
> contract-first, additive PRs, keep the backend authoritative.

---

## 1. What Flora is

Flora is an **AI-native Career Operating System** for India's grey-collar / operational
workforce. It is **not a game** — a learner performs an **entire job**, department by
department, in a simulated workplace, and **every action becomes observable evidence**.
First vertical: **Logistics & Supply Chain → Distribution Warehouse**, first department
**Receiving**. The same runtime must reuse for Put Away, Picking, Packing, Dispatch,
Inventory, Returns, Safety, Supervisor Ops.

**Design principles (binding):** authentic workplace processes; learning over visual
realism; **separate simulation logic from rendering**; reusable systems not hardcoded
missions; one runtime across industries; integrate with Flora's competency + assessment
engine; **renderer-agnostic (2D, browser 3D, Unity, XR)**.

## 2. The stack reality (important — do not assume)

- **Client:** **Flutter** (arm64 APK, CI-built, verified on Samsung S24 Ultra). NOT
  React Native/Expo.
- **3D layer:** a **future WebGL viewer** = a *web* presentation client, embedded in
  the Flutter app via a **WebView**. Currently **deferred** (see milestone below).
- **Backend:** **Flora Backend is authoritative** for mission, simulation, assessment,
  evidence and competency. Flutter and the WebGL viewer are **presentation clients only**.
- Already shipped: Screens 03–06 (03 Workplace Overview, 04 Document Desk, 05 shipment
  confirmation + revisioned carton counts, 06 Inspection Zone *placeholder*),
  `/practise` routes, atomic persistence, **append-only learner actions + audit events**.

## 3. Architecture decisions (already made — see ADRs in repo)

**ADR-001 — Rendering technology.** The 3D renderer is **Three.js, via React Three
Fiber (R3F)**, with **@react-three/rapier** for physics and **glTF/GLB** assets, packaged
as a **standalone WebGL viewer** embedded in Flutter via WebView. Chosen for declarative
maintainability, low-end browser reach, and solo-founder + AI-assisted velocity.
**Babylon.js is the co-equal fallback** (no React host is shared, so it's a real
alternative). Unity/Unreal rejected as the base layer (size, low-end, talent) — reserve
only as an outsourced per-deal module for certification-grade physics.

**ADR-002 — Renderer-agnostic content model.** Three layers:
1. **Content (pure data)** — Pack → Domain → Workplace → Department, with Areas, reusable
   Object/People/Equipment libraries, generic **interaction verbs**, a **Flow state
   machine**, **Scenarios as config**, and a **Competency map**. No rendering code.
2. **Simulation runtime** — loads content, runs the flow, resolves interactions, applies
   scenario config, emits evidence. Renderer-agnostic; exposes a thin RendererAdapter.
3. **Renderer adapters** — R3F/3D (primary), 2D (reach), Unity/XR (later).
   Then evidence → Flora Backend.
   **Content + runtime are the product; renderers are swappable.**

**ADR-003 — Client/server interaction boundary.** **Client owns the loop, backend owns
the truth.** The viewer runs the real-time interaction loop locally at 60fps with
optimistic feedback; the backend is authoritative for content, validation, scoring and
the **append-only LearnerAction** evidence — reconciled **asynchronously, never in the
frame path**. This is what keeps Flora backend-authoritative AND feeling real. Anti-pattern
to avoid: awaiting a server ACK before responding to any interaction.

## 4. Assessment model

Every interaction emits an **append-only `LearnerAction`**:
`{ learnerId, sessionId, seq (monotonic), ts, action (a verb), area, target, flowStep,
scenarioId, result: ok|error|corrected, competencies[], meta }`.
**Completion ≠ correctness** — a learner may complete the workflow while scoring low on
competency; the two are reported separately. This matches the append-only actions +
audit events already in the backend. Competencies are grouped Technical / Behavioural /
Digital / Safety and are renderer-independent.

## 5. What is already built (in the `flora-sim-v3` package)

- `docs/ADR-001/002/003` — the decisions above.
- `content/simulation.schema.json` — the department/scenario DSL.
- `content/…/receiving/receiving.department.json` — Receiving as data (areas, object/
  people/equipment libraries, 18-step flow, 12 scenarios, competencies, LearnerAction schema).
- `content/…/receiving/stages/screen06.receiving-dock.json` — **Screen 06 Receiving Dock**
  (shipment verification; scenarios A–F; verification checklist; correctness = right
  decision AND due-diligence checks done first).
- `content/…/receiving/stages/screen07.goods-inspection.json` — **Screen 07 Goods
  Inspection** (findings taxonomy, scenarios A–G via `groundTruth`; rubric = recall/
  precision/missed/false-positive/severity/quarantine; output = **immutable Inspection
  Report** consumed by Screen 08).
- `tools/stage_runner.mjs` — **headless reference runner**: executes a stage contract +
  scripted run, emits the LearnerAction stream, computes completion vs correctness +
  competency evidence. Run: `node tools/stage_runner.mjs`. This is the fast unit-test
  loop and the reference the backend mirrors.
- `prototypes/` — raw Three.js proofs (picking + tuning panel; forklift + Rapier LOCKED
  baseline; receiving walkthrough greybox; boundary demo for ADR-003). **Not production.**
- `assets/*.glb` — procedural low-poly glTF (aisle, rack, pallet, box, tote).

## 6. Current milestone & build order

**Next milestone (do this before any WebGL): complete the Screen 06 → 07 → 08 stage
contracts and wire them to the backend.** Renderer is the last layer.

Build order (ADR-002 §5):
1. **Contracts first** (06 done, 07 done) → next **Screen 08 Barcode Scanning** (consumes
   the immutable Inspection Report; verify each item digitally vs PO/inventory).
2. **Headless runtime skeleton** in the backend: flow state machine + interaction resolver
   + LearnerAction emitter, unit-testable (mirror `stage_runner.mjs`).
3. Wire evidence to the backend `LearnerAction` store (already exists) + competency engine.
4. Author the **next department (Put Away)** as data — proves reuse with zero engine
   changes. *This is the real test the architecture holds.*
5. **Only then** build the WebGL viewer (R3F).

## 7. How to build the 3D specifically (when its turn comes)

- **Stack:** React Three Fiber + Three.js + **@react-three/rapier** (physics) +
  **@react-three/drei**. Package as a standalone web app; embed in Flutter via WebView.
- **ADR-003 is law:** the viewer runs the interaction loop locally (optimistic, 60fps);
  it consumes backend-driven scenario state and emits LearnerActions asynchronously. Never
  block a tap on the server.
- **Assets without a 3D team:** stylized **low-poly**; source via **procedural geometry**
  (see the generator that made the `.glb`s), **bought packs** (Kenney/Poly Pizza free;
  Sketchfab), and **AI 3D generation** (Meshy/Tripo ~$0.15–0.50/model). No Maya, no
  in-house modelling.
- **Low-end Android is the target:** device-capability tiers (LOD, shadow toggle,
  `frameloop="demand"`, pixel-ratio clamp), Draco/meshopt compression, ~10–15MB scene
  budget, offline scenario bundles, evidence synced when online. Keep a **2D adapter** as
  the fallback for the weakest phones.
- **Feel is tuned by the founder:** expose feel constants (camera, animation, physics) in
  a tuning panel; the founder playtests on-device and the exported values become content
  defaults. (Prototypes already demonstrate this pattern.)

## 8. Working method (fast + merge-safe)

- **Contract-first:** freeze each stage's input/output shape as data before building the
  Flutter screen or viewer, so both build against a stable interface.
- **Small, single-purpose PRs**, one branch per screen/contract. **CI is the merge gate**
  (tests + APK build), not eyeballed conflict-absence.
- Content/docs/prototypes live in their own folders (`content/`, `docs/adr`, `tools/`,
  `prototypes/`, `assets/`) → **additive, near-zero conflict** → safe for Codex to auto-merge.
- **Headless unit tests** (like `stage_runner.mjs`) for logic → millisecond inner loop, no
  Flutter/3D needed. Flutter hot reload for UI. CI for the full suite.

## 9. Immediate task for the new session

> **Update 2026-07-29 — superseded.** Screens 08-13 are now authored (Barcode
> Verification, Discrepancy Resolution & Quarantine, Receiving Decision, Goods
> Receipt & Documentation, Shift Report & Reflection, Performance Feedback) — the
> full Receiving mission, dock verification through mission-level competency
> report. `stage_runner.mjs` has reference runners for 06-10; 11-13 still need
> runner coverage. **Next immediate task: wire Screens 06-13 to an actual backend
> runtime** (headless flow state machine + interaction resolver + LearnerAction
> emitter — the "Flora Backend" this whole pack assumes doesn't exist in this repo
> yet), or author the second department (Put Away) as data per §6 step 4. The
> original Screen 08 task description below is kept for history.

Pick up at **Screen 08 — Barcode Scanning** as a backend-authoritative contract in the
same shape as Screen 06/07: it consumes Screen 07's immutable Inspection Report, lets the
learner scan each item and verify SKU/qty/batch against the PO and inventory, records
mismatches as append-only LearnerActions, and outputs a verification result to Screen 09
(Quarantine Decision). Then extend `stage_runner.mjs` to execute it. Keep everything
additive; do not modify Flutter or backend app code without a frozen contract.

## 10. How this reaches the repo (git + unzip workflow)

The simulation work is delivered as a `flora-sim-v3` package (zip) with this layout:
`docs/` (ADRs + this file), `content/` (schema + department + stage contracts), `tools/`
(stage_runner), `prototypes/`, `assets/`. To land it:

```
# on a machine with git + GitHub network access (a cloud Cowork session CANNOT push —
# GitHub egress is blocked there; run this locally or in on-computer Cowork)
unzip -o flora-sim-v3.zip -d ./_flora
cd <your skilling-platform repo>
git checkout -b flora-sim-v3-content
mkdir -p docs/adr content tools prototypes/flora-sim assets/flora-sim
cp    ./_flora/flora-sim-v3/docs/*.md     docs/adr/
cp -r ./_flora/flora-sim-v3/content/*     content/
cp    ./_flora/flora-sim-v3/tools/*.mjs   tools/
cp -r ./_flora/flora-sim-v3/prototypes/*  prototypes/flora-sim/
cp    ./_flora/flora-sim-v3/assets/*.glb  assets/flora-sim/
git add docs/adr content tools prototypes/flora-sim assets/flora-sim
git commit -m "feat(sim): Flora V3 architecture + Receiving content"
git push -u origin flora-sim-v3-content
gh pr create --base main --title "Flora V3 — simulation architecture + Receiving content" \
  --body "Additive: ADRs, DSL, Receiving + stage contracts, runner, prototypes, assets. No Flutter/backend code touched."
```

Non-terminal alternative: GitHub web UI → **Add file → Upload files** → drag the unzipped
`flora-sim-v3` folder → "Create a new branch and start a pull request". Never upload the
raw `.zip` (GitHub won't extract it). Adjust destination folder names to match the repo.
