# Flora Simulation — V3

**Module:** Logistics & Supply Chain → Distribution Warehouse → **Receiving** (first department)
**Status:** Architecture accepted; content authored; prototypes validate the model.
**Owner:** Technical architecture (rendering decision delegated & recorded in ADR-001).

Flora is a **Career Operating System**: a learner performs an *entire job*, department
by department, and every action generates competency evidence. V3 delivers the
architecture plus the first fully-authored department (Receiving) on a runtime that
every future department reuses.

---

## What's in this package

```
flora-sim-v3/
├── README.md                  ← you are here
├── MANIFEST.json              ← machine-readable contents + versions
├── CHANGELOG.md
├── docs/
│   ├── ADR-001-rendering-technology.md      ← renderer = React Three Fiber (+ why)
│   └── ADR-002-simulation-content-model.md  ← renderer-agnostic 3-layer model
├── content/                   ← PURE DATA (no rendering code)
│   ├── simulation.schema.json               ← the scenario/department DSL
│   └── packs/logistics/distribution-warehouse/receiving/
│       └── receiving.department.json        ← Receiving authored as data
├── prototypes/                ← throwaway proofs, NOT production code
│   ├── picking/warehouse_picking_v3_tuning.html
│   ├── forklift/forklift_sim_LOCKED_v1.html
│   └── receiving/receiving_walkthrough.html
└── assets/                    ← procedural low-poly glTF (drop into r3f useGLTF)
    ├── warehouse_aisle.glb  pallet.glb  shelf_rack.glb
    └── cardboard_box.glb    tote.glb
```

## The architecture in one screen (see ADR-002)

```
CONTENT (data)  →  RUNTIME (renderer-agnostic engine)  →  RENDERER ADAPTERS  →  EVIDENCE
receiving.json     flow state machine + interaction        R3F (primary), 2D,     append-only
                   resolver + scenario config +            Unity/XR (later)        LearnerAction
                   LearnerAction emitter                                           → Postgres
```

Content and runtime are the product. Renderers are swappable. Assessment is the
append-only evidence stream; **completion and correctness are scored separately.**

## How to use it

- **Read first:** `docs/ADR-002` (the model), then `content/receiving.department.json`
  (the model applied). The prototypes are illustrations, not the codebase.
- **Open a prototype:** any file in `prototypes/` runs in a browser (mobile-friendly).
  They load Three.js / Rapier from CDN, so they need a network connection on first open.
- **Assets:** `assets/*.glb` are ready for `@react-three/drei`'s `useGLTF`.

## Current repo state (2026-07-28)

- **Client is Flutter** (arm64 APK ~83 MB, CI-built, verified on Samsung S24 Ultra).
  The 3D layer is a **future WebGL viewer** embedded via WebView — a presentation
  client, deferred for now.
- **Flora Backend is authoritative** for mission, simulation, assessment, evidence
  and competency. Clients render state and emit append-only `LearnerAction`s.
- Shipped: Screens 03–06 (Workplace Overview, Document Desk, shipment confirmation +
  revisioned carton counts, Inspection Zone placeholder), `/practise` routes, atomic
  persistence, append-only learner actions + audit events.
- **Screens 06-13 are now all authored as stage contracts** — the full Receiving
  mission, dock verification through mission-level performance feedback. Renderer
  is still deferred: this is architecturally correct, the renderer is the last
  layer (ADR-002). See `docs/FLORA-3D-CONTEXT.md` for the full context brief.

## Status & caveats

- Prototypes are **raw Three.js** (r128) — the cheap way to validate. Production is a
  port to **React Three Fiber** per ADR-001 (or Babylon.js — see ADR-001 revision).
  Do not ship prototype code as-is.
- Prototypes were authored in an environment without CDN access, so they are
  syntax-verified but not render-tested here; validate on-device.
- Physics "feel" (forklift) and interaction "feel" are tuned via the in-prototype
  tuning panels → export values → bake into content defaults.

## Next steps

0. **Now:** wire the Screen 06-13 stage contracts to the backend (headless runtime
   skeleton: flow state machine + interaction resolver + LearnerAction emitter,
   unit-testable, mirroring `tools/stage_runner.mjs`). WebGL viewer stays deferred
   until the contracts are stable end to end.
1. Build runner coverage for Screens 11-13 in `tools/stage_runner.mjs` (currently
   06-10 only).
2. Author a **second department (Put Away)** as data — proves reuse with zero engine
   changes. *That* is the real test the architecture holds.
3. When ready for 3D: build the **WebGL viewer** (R3F or Babylon per ADR-001), embed
   in Flutter via WebView, consume backend state, emit `LearnerAction`s. Port the
   walkthrough prototype as the starting point.
```
