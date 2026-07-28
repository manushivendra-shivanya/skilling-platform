# 22 — Simulation Content Schema

## Principles

Workplace simulations use typed Dart models backed by JSON-compatible,
immutable content. Industry-specific facts remain content; state transitions,
audit, scoring and evidence remain reusable engine behaviour.

Published behavioural or scoring changes require a new mission version.

## Content documents

The initial logistics pack contains:

- `pack.json` — pack identity, version, industry, locale and engine support;
- `workplace.json` — workplace, departments, workstations, capabilities,
  normalized positions, operational rules and unlock requirements;
- `competencies.json` — observable competency definitions and proficiency;
- `remediation.json` — issue-triggered micro-learning recommendations;
- `receive_shipment_mission.json` — role, briefing, scenario, resources,
  stages, tasks, evaluation, scoring and critical errors.

## Mission identity and metadata

Required fields:

```text
id
version
packId
workplaceId
departmentId
processId
role
title
difficulty
estimatedDurationMinutes
missionType
objectives
startingWorkstationId
```

`role` contains an industry-neutral role identifier, title, level, department
references and competency references.

## Briefing contract

The approved entry and briefing screens consume:

```text
supervisorTitle
message
shiftName
supplier
purchaseOrderNumber
deliveryReference
deliveryType
responsibilities[]
workplaceRules[]
rulesVersion
```

Required briefing text, responsibilities and rules are validated before the
mission can start. The briefing schema contains no hidden issue placement,
correct decision or scoring answer.

## Runtime content

`stageDefinitions` order workplace stages and reference task identifiers.
Each stage declares a workstation, instruction and completion mode.

`taskDefinitions` declare:

- type and stage;
- mandatory and repeatable behaviour;
- permitted action types and target resources;
- competency mapping;
- maximum points and scoring category;
- deterministic evaluation rules.

`resources` represent documents, cartons, equipment, forms, policies and
messages as typed metadata with JSON-compatible content.

`scenario` declares a default seed, resource templates and equivalent
variation rules. The engine combines the mission version and attempt seed so
the same inputs reproduce the same scenario.

## Scoring and critical errors

`scoringRule` requires:

```text
minimumScore
allMandatoryTasksRequired
criticalErrorsAllowed
scoreCategories[]
```

Category weights must total one. The initial mission uses process accuracy,
document verification, inventory accuracy, quality inspection, safety and
compliance, and decision quality.

`criticalErrorRules` separately identify unsafe or non-compliant actions,
penalties, pass prevention and feedback.

## Attempt and audit schema

An attempt records:

```text
id
candidateId
missionId
missionVersion
attemptNumber
scenarioSeed
state
startedAt
shiftStartedAt
elapsedSeconds
currentStageId
completedTaskIds[]
actions[]
auditEvents[]
```

`startedAt` is attempt creation time. `shiftStartedAt` remains null while the
learner reads Screen 01 or Screen 02 and is set only after a valid Begin Shift
transition.

Scored learner actions and unscored audit events are separate append-only,
continuously sequenced streams. Briefing acknowledgement, entry/resume and
shift-start events do not affect competency scores.

## Future remote compatibility

A later Supabase/BFF adapter must preserve:

- candidate ownership;
- immutable mission-version and seed provenance;
- ordered idempotent action and audit streams;
- technical-event separation;
- equivalent content validation;
- RLS and consequential-operation boundaries.
