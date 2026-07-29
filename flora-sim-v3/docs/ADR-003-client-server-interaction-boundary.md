# ADR-003 — Client/Server Interaction Boundary (Feel vs Authority)

**Status:** Accepted
**Date:** 2026-07-28
**Decision owner:** Claude (technical architecture)
**Relates to:** ADR-001 (renderer), ADR-002 (content/runtime/evidence model + the
"Flora Backend is authoritative" boundary).

---

## 1. Context

ADR-002 (revised) makes **Flora Backend authoritative** for mission, simulation,
assessment, evidence and competency; Flutter and the future WebGL viewer are
**presentation clients**. That is correct for *truth* — but it introduces a risk to
*feel*: if "authoritative" is misread as "in the interaction path," every action
(move, pick up, scan, inspect) would round-trip to the server before the client
responds. At Indian mobile-network latencies that means visible lag and jank — the
simulation would feel low-grade no matter how good the art or physics are.

The question this ADR settles: **how do we keep the backend authoritative without
putting it in the frame loop?**

## 2. Decision

**The client owns the loop. The backend owns the truth.**

- The presentation client (viewer / Flutter screen) runs the **real-time interaction
  loop locally at 60fps**: rendering, camera, input, animation, physics, and
  **optimistic immediate feedback** for every interaction. Nothing in this loop waits
  on the network.
- The backend is authoritative for **content, validation, scoring rules, the
  append-only `LearnerAction` evidence ledger, and competency** — reconciled
  **asynchronously**, outside the frame path.
- **Nothing authoritative sits in the input-to-render path.** The server is a source
  of truth and a recorder, never a per-action gatekeeper.

### Rules

1. **Optimistic local response.** Every interaction produces instant client feedback
   (highlight, pick-up, animation, provisional result) with zero network wait.
2. **Emit, don't await.** Each interaction is appended as a `LearnerAction` and
   streamed to the backend asynchronously (batch/queue friendly).
3. **Backend validates and records.** It scores against the scenario, appends to the
   evidence ledger (append-only — corrections are new entries, never mutations), and
   updates authoritative competency.
4. **Reconcile non-blockingly.** If backend truth differs from the client's optimistic
   result (e.g., learner accepted a damaged carton), the correction is applied as a
   *new* ledger entry and reflected in the authoritative panel — it does not stall or
   rewind the interaction loop.
5. **Single-player ⇒ autonomous client.** No adversary to defend against, so the
   client needs no per-action server gating; the backend's job is truth + evidence,
   not permission.
6. **Separate the two readouts.** *Immediate interaction feedback* (client, instant)
   and *authoritative score/competency* (backend, confirmed) are shown as distinct
   things. Completion is a client fact; correctness is a backend fact — consistent
   with ADR-002's "completion ≠ correctness."
7. **Degrade gracefully.** Offline or high-latency: queue `LearnerAction`s locally and
   sync when connectivity returns. Feel is unaffected; evidence is eventually consistent.

## 3. Anti-patterns (these lower the grade)

- Awaiting a server ACK before responding to a tap/move. ✗
- A server tick driving each rendered frame. ✗
- Blocking the UI while evidence is written. ✗
- Treating optimistic results as final (skipping backend reconciliation). ✗

## 4. Consequences

- Feel is bounded only by how well the viewer is built, not by network latency.
- The backend stays the single source of truth for assessment and evidence, matching
  the append-only actions + audit events already shipped server-side.
- The client can run fully offline for a session and sync evidence later.
- Slightly more client logic (optimistic state + reconciliation), which is the correct
  place for it.

## 5. Test (how to know it holds)

Crank simulated network latency to 1–2 seconds. **Interaction must stay instant**;
only the authoritative evidence/score panel is allowed to lag. If the interaction
itself lags, the boundary has been drawn wrong. (See the `boundary_demo` build — the
"Server in the loop" toggle demonstrates both the correct and the wrong side.)

## 6. Decision

Client owns the real-time loop with optimistic feedback; backend owns content,
validation, append-only evidence and competency, reconciled asynchronously; nothing
authoritative in the frame path. This is what lets Flora be backend-authoritative
*and* feel real.
