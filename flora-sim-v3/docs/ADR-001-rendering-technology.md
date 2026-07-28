# ADR-001 — Rendering Technology for the 3D Simulation Layer

**Status:** Accepted (owner: technical architecture)
**Date:** 2026-07-28
**Decision owner:** Claude (delegated technical-architecture authority)
**Applies to:** Flora / skilling-platform — the 3D training-simulation subsystem

---

> ### Revision 2026-07-28 — stack correction (authoritative)
> A prior repo read misidentified the client. The **actual stack** is:
> - **Client:** Flutter (arm64 APK, ~83 MB, CI-built) — **not** React Native/Expo.
> - **3D layer:** a **future WebGL viewer** = a *web* presentation client, embedded
>   in the Flutter app via a WebView, not a native engine.
> - **Authority:** **Flora Backend** owns mission, simulation, assessment, evidence
>   and competency. Flutter and the WebGL viewer are **presentation clients only.**
>
> **The engine choice is unchanged — Three.js, via React Three Fiber, packaged as a
> standalone WebGL viewer** — but the *rationale* changes: the "shared with Expo via
> `expo-gl`" argument below no longer applies (there is no Expo). R3F is chosen for
> declarative maintainability, ecosystem depth, and solo-founder + AI-assisted build
> velocity as a **self-contained viewer embedded via WebView**. Because no React host
> is shared any more, **Babylon.js is now a co-equal alternative** — pick R3F if you
> want React inside the viewer, Babylon if you want a self-contained non-React viewer.
> Everything in §3 about low-end browser delivery and glTF still holds.
>
> **Sequencing:** WebGL implementation is **deferred**. Current milestone is the
> Screen 06 Inspection Zone *contract* (backend-authoritative), before any viewer.
> Read §1–§5 below as the original evaluation; this box supersedes any Expo framing.

---

## 1. Context

Flora is an AI-native employability platform for India's grey-collar / operational
workforce. The 3D simulation layer must deliver interactive training scenarios
(order picking, forklift operation, inventory, dispatch, supervisory decisions),
score them, and emit competency evidence.

Hard constraints from the product and the existing codebase:

- **Existing stack:** Next.js (web), React Native / Expo (candidate mobile app),
  Node.js BFF, PostgreSQL. TypeScript/React throughout.
- **Primary user device:** low-end Android phones on patchy data. This is the
  dominant performance and reach constraint.
- **Team:** effectively a solo founder with a React/JS background and **no
  game-engine or 3D-art talent** in-house.
- **Delivery:** must run in the browser (web app) *and* inside the Expo app;
  employer/admin review happens on the web.
- **Physics:** already chosen — Rapier (WASM) — sufficient for "credible" (not
  certification-grade) physics such as load toppling.
- **Authoring:** scenarios are defined as data via a scenario DSL
  (`scenarios.schema.json`); the runtime is engine-bound, the content is not.

Optimisation targets (in the founder's words): **maintainability, browser
deployment, integration with the existing codebase, solo-founder workflow.**

---

## 2. Decision

Adopt **React Three Fiber (R3F)** — a React renderer for **Three.js** — as the
single rendering technology, with:

- **Three.js** as the underlying WebGL engine (WebGPU-ready later),
- **@react-three/rapier** for physics (the R3F binding over the already-chosen Rapier),
- **@react-three/drei** for batteries (loaders, controls, instancing, helpers),
- **glTF/GLB** as the asset format (Draco / meshopt compressed),
- delivery as a **shared `packages/sim` module** consumed by both the Next.js web
  app (DOM canvas) and the Expo app (via `expo-gl` / `@react-three/fiber/native`),
- scenarios authored as **DSL JSON**, served by the Node BFF; evidence posted back
  to Postgres.

The rendering technology is R3F. This is the base layer for **all** scenarios.

---

## 3. Options considered

Scored against the four optimisation targets (5 = best).

| Option | Maintainability | Browser deploy (low-end) | Integration w/ React+Expo | Solo-founder fit | Verdict |
|---|---|---|---|---|---|
| **React Three Fiber** | 5 | 4 | 5 | 5 | **Selected** |
| Babylon.js | 4 | 4 | 3 | 3 | Strong runner-up |
| Three.js (raw) | 3 | 4 | 3 | 3 | Use *via* R3F |
| Unity (WebGL / UaaL) | 2 | 1 | 1 | 1 | Rejected for base layer |
| PlayCanvas / other | 3 | 4 | 2 | 3 | Rejected |

### React Three Fiber — selected
- **Maintainability:** the scene graph *is* a React component tree; lifecycles,
  disposal, and state sync are handled by React's reconciler. Least boilerplate of
  any option, most testable, most composable. drei removes the common glue.
- **Browser deployment:** it *is* Three.js underneath — the same universal WebGL
  reach, runs on low-end Android browsers, supports Draco/meshopt, LOD, instancing,
  and on-demand (frameloop="demand") rendering to save battery.
- **Integration — the decisive factor:** it is the *same* React paradigm as the
  Next.js web app **and** runs inside Expo/React Native through `expo-gl`. A single
  3D package can be authored once and reused across web and mobile. No other option
  on the list can be authored once and run natively in both Flora surfaces.
- **Solo-founder fit:** the founder already writes React; 3D becomes "more React,"
  not a second discipline. Largest community and strongest AI-assisted-coding
  support, which maximises how much of this an AI pair-builder can carry.

### Babylon.js — strong runner-up
Excellent, TypeScript-native engine with built-in physics/PBR/GUI and great docs.
Rejected only because it owns its own scene/loop paradigm imperatively alongside
React (two mental models), the React binding (`react-babylonjs`) is smaller, and it
does not give the same author-once web+Expo reuse. If R3F's Expo path ever proves
untenable on target devices, Babylon is the fallback engine.

### Three.js (raw) — foundation, not the interface
The prototypes to date are raw Three.js (r128); that was the right cheap way to
validate the approach. For a product, raw Three.js means hand-managing the scene
graph, disposal, and React state sync — avoidable footguns for a solo dev. Keep
Three.js as the engine, consume it through R3F.

### Unity (WebGL export / Unity-as-a-Library) — rejected for the base layer
Separate C# codebase and editor-centric toolchain; WebGL builds are tens of MB and
load slowly on low-end mobile browsers (the exact target user); embedding into RN
via UaaL is fiddly and the web export is an opaque canvas, not composable React.
Highest fidelity ceiling, worst fit for maintainability, low-end browser delivery,
integration, and a solo React founder. **Retain only as a future, outsourced,
per-deal module** for certification-grade physics (e.g. a licensed forklift/crane
assessment), never as the foundation.

### PlayCanvas / Needle / Godot-web — rejected
Capable browser engines, but each is a separate paradigm with weaker React/Expo
integration than R3F; no advantage here that offsets the integration cost.

---

## 4. Consequences

**Positive**
- One language, one paradigm, one 3D package across web and mobile.
- Physics (Rapier) has a first-class R3F binding — no extra integration work.
- The scenario DSL stays engine-agnostic; R3F is simply its runtime.
- Evidence pipeline is plain Node/Postgres — no engine lock-in on data.
- An AI pair-builder is maximally effective in this ecosystem.

**Costs / trade-offs**
- Fidelity ceiling below Unity/Unreal — accepted; not needed for operational
  scenarios, and premium physics can be an outsourced module later.
- R3F on Expo uses the `expo-gl` native GL path, which is less battle-tested than
  R3F on the web (see risks).

**Migration path**
1. Port the locked raw-Three.js prototypes (picking v3, `forklift_sim_LOCKED_v1`)
   into R3F components, unchanged in behaviour.
2. Stand up `packages/sim` (renderer, DSL loader, scoring, evidence emitter).
3. Wire the Node BFF to serve scenario JSON and ingest the evidence payload.
4. Validate the Expo/`expo-gl` path on real low-end Android **before** committing
   heavily to the mobile runtime.

---

## 5. Risks & mitigations

- **`expo-gl` performance on low-end Android** (primary risk). *Mitigation:* build
  a device-capability tier (LOD, shadow toggle, on-demand frameloop, pixel-ratio
  clamp) from day one; benchmark early on target hardware; if the native path
  underperforms, fall back to rendering the same R3F bundle inside a
  `react-native-webview` (WebGL in a web view) — same code, different host.
- **Asset production without 3D talent.** *Mitigation:* procedural geometry, bought
  low-poly packs, and AI-generated glTF — no in-house modelling (see cost note).
- **Physics "feel."** *Mitigation:* founder playtests on device; a live tuning panel
  exports feel constants that get baked into the scenario config.

---

## 6. Decision

**React Three Fiber (Three.js + Rapier), shared across the Next.js and Expo apps,
DSL-driven, evidence to Postgres.** Revisit only if on-device benchmarking of the
Expo path fails its performance budget, in which case the fallback order is:
R3F-in-WebView → Babylon.js.
