# ADR-0015: Add a UI-neutral, content-driven workplace simulation engine

## Status

Accepted

## Context

The product needs a deeper Workplace Management Simulation while the complete
screen-by-screen interaction contract is still being prepared. The app already
contains a working Phase 2 inventory-discrepancy simulation. Building final
screens now would either replace working functionality or embed assumptions
that constrain the later contract.

## Decision

Add a separate `features/workplace_simulation` feature with:

- industry-neutral typed domain models and repository interfaces;
- versioned local JSON content;
- deterministic scenario, state, validation, evaluation, scoring,
  critical-error and evidence services;
- candidate-isolated local persistence; and
- a UI-neutral application controller.

Do not add a route, production screen, Supabase migration or replacement for
the Phase 2 simulation in this milestone.

## Consequences

- The engine can be tested and evolved without coupling it to temporary UI.
- The first logistics mission validates a generic engine without making
  logistics part of the engine contract.
- Attempts remain reconstructable through mission-version and seed provenance.
- The final interaction specification can be applied as a presentation layer
  without rewriting domain rules.
- The APK has no new visible WMS experience until a later approved milestone.
