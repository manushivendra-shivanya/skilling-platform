# 21 — Layered Simulation Strategy

## Objective

Build a professional workplace-simulation platform in controlled layers,
starting with accessible mobile 2D interactions and preserving domain,
content, evidence and safety boundaries as fidelity increases.

## Layer 1 — 2D interactive tasks

Standard Flutter widgets, gestures and restrained animation represent
documents, workstations, stock, forms and decisions. The current logistics
mission belongs to this layer.

Layer 1 requirements:

- immutable versioned content;
- deterministic seeded scenarios;
- explicit mission state and audit events;
- accessible tap targets and text scaling;
- local-first attempt preservation;
- deterministic scoring and explainable evidence;
- technical failures excluded from candidate scoring.

## Layer 2 — Story missions and dynamic events

Multiple Layer 1 tasks form an operational story with workstation unlocking,
time-aware events, supervisor messages and changing workplace conditions.
Dynamic events remain authored, deterministic and reproducible for assessment.

## Layer 3 — AI NPC and voice role-play

AI-supported conversations may later add supervisor, colleague or customer
role-play. They require versioned prompts, reviewed structured output,
candidate transcript controls, safety testing and human review. Accent,
emotion, personality and protected attributes remain excluded.

## Layer 4 — Full workplace-day simulation

Connected processes model a complete shift across departments, queues,
handover, SLAs and operational systems. This layer requires performance,
authoring, calibration and evidence-governance work beyond the current mobile
mission.

## Layer 5 — Collaborative and multiplayer simulation

Supervised multi-learner workplaces may model coordination and handover.
Identity, moderation, abuse prevention, scheduling, synchronization and fair
individual evidence require separate architecture and product approval.

## Current boundary

The app implements the reusable Layer 1 technical foundation and approved
Screen 01 (Simulation Entry) and Screen 02 (Supervisor Briefing) for one
logistics receiving mission. The existing Phase 2 Practice simulation remains
unchanged.

Screen 03 has not yet been implemented. After the shift begins, the app shows
an explicit specification handoff rather than inventing workstation layout or
operational interactions.

No 3D engine, multiplayer, backend persistence, voice AI or second industry is
included.
