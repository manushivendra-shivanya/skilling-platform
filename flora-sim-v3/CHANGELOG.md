# Changelog — flora-sim

## v3.2.0 — 2026-07-28
### Added
- **Stage contracts** (backend-authoritative, configurable): Screen 06 Receiving Dock
  (shipment verification, scenarios A–F) and Screen 07 Goods Inspection (findings +
  quarantine, scenarios A–G, immutable Inspection Report → Screen 08).
- **tools/stage_runner.mjs** — headless reference runner that executes a stage contract
  and computes completion vs correctness + competency evidence (fast unit-test loop).

## v3.1.0 — 2026-07-28
### Added
- **ADR-003** client/server interaction boundary — "client owns the loop, backend
  owns the truth"; keeps Flora backend-authoritative without putting the server in
  the frame path (protects "real feel").
- **prototypes/boundary/boundary_demo.html** — runnable proof: latency slider +
  "server in the loop" toggle demonstrate the correct vs wrong boundary.

## v3.0.0 — 2026-07-28
First packaged module: **Logistics & Supply Chain → Distribution Warehouse → Receiving.**

### Added
- **ADR-001** rendering technology decision (React Three Fiber / Three.js), with a
  stack-correction revision: client is Flutter, 3D is a deferred WebGL viewer,
  Flora Backend is authoritative; Babylon.js noted as co-equal alternative.
- **ADR-002** renderer-agnostic three-layer content/runtime/evidence model, with a
  deployment-boundary note placing runtime + assessment in Flora Backend.
- **content/simulation.schema.json** — the department/scenario DSL.
- **content/.../receiving.department.json** — Receiving authored as data: 15 areas,
  reusable object/people/equipment libraries, 18-step flow, 12 configurable
  scenarios, Technical/Behavioural/Digital/Safety competencies, append-only
  LearnerAction assessment model.
- **prototypes/** — picking (+tuning), forklift (Rapier, LOCKED baseline), receiving
  walkthrough (walkable greybox). Raw Three.js proofs, not production.
- **assets/** — procedural low-poly glTF (warehouse aisle, rack, pallet, box, tote).

### Notes
- Renderer decision rationale updated for the Flutter reality (no Expo).
- WebGL implementation deferred; next milestone is the Screen 06 Inspection Zone
  contract (backend-authoritative).
