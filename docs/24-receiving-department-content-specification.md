# 24 — Receiving Department Content Specification

## 0. Purpose and division of labour

This document is the content layer for the Receiving department: warehouse
layout, department definitions, SOPs, scenario library, NPC roles and
dialogue, competency framework, assessment criteria and learning outcomes.

Division of labour on this codebase: the simulation platform and runtime
(state machine, scoring engine, screens, Flutter code) are built elsewhere.
This document — and the workplace content it describes — is the other half:
what the runtime executes, not how it executes it. Every claim below is
checked against the actual shipped content
(`apps/candidate-mobile/assets/workplace_simulation/logistics/*.json`) and the
actual runtime code as of the `feature/flutter-foundation` branch at the time
of writing, not against the separately delivered `flora-sim-v3` package
(merged into `main` via PRs #3/#4), whose screen numbering and content model
do not match this app's actual mission content — see
`docs/generated/current-state.md` for that cross-check.

Sections 1–4 describe content that exists today and propose concrete,
additive enrichments within the current schema (`docs/22-simulation-content-schema.md`).
Section 5 (NPC dialogue) proposes a schema extension the runtime does not yet
support — clearly marked as a request for the runtime team, not something
implemented here.

## 1. Warehouse and department layout

### 1.1 What exists today

`workplace.json` defines one workplace (Central Distribution Centre, a
regional warehouse receiving, storing and dispatching consumer products) with
one department (Receiving) and six workstations, each with a normalized
`position` (x, y in [0,1]), a `workstationType`, terse one-line `description`,
`capabilities`, and `unlockRequirements` keyed to task completion:

| Workstation | Position | Unlocks on |
|---|---|---|
| Document Desk | (0.12, 0.74) | mission start |
| Receiving Dock | (0.12, 0.22) | `verify-documents` complete |
| Inspection Zone | (0.48, 0.22) | `confirm-delivery-identity` + `confirm-received-counts` |
| Barcode Station | (0.48, 0.74) | `inspect-cartons` complete |
| Quarantine Zone | (0.84, 0.22) | `scan-barcodes` complete |
| Receiving Office | (0.84, 0.74) | `assign-dispositions` complete |

Reading the position grid: Document Desk and Receiving Dock sit on the left
(x≈0.12), Inspection Zone and Barcode Station in the middle (x≈0.48),
Quarantine Zone and Receiving Office on the right (x≈0.84) — a left-to-right
process flow, with each column alternating between the y≈0.22 "front of
house" row (Receiving Dock, Inspection Zone, Quarantine Zone) and the y≈0.74
"desk work" row (Document Desk, Barcode Station, Receiving Office). This
reads as: physical dock work up top, paperwork/decision work below, moving
left (arrival) to right (resolution).

**Note on Screen 06 (implemented separately):** the Inspection Zone screen
build discovered that `inspect-cartons` and `scan-barcodes` are both part of
the single `physical-inspection` stage and are presented together on one
screen, even though Barcode Station is modelled as its own workstation here.
Content and runtime should stay reconciled on this point — either Barcode
Station becomes its own screen later (unlocking after `inspect-cartons`
alone, matching its `unlockRequirements` above), or the workstation
definition should be merged into Inspection Zone. Flagging for the runtime
team rather than resolving unilaterally, since it's a screen-boundary
decision.

### 1.2 Proposed enrichment — richer `description` fields

The following are additive replacements for the existing one-line
`description` strings in `workplace.json`. They are safe: purely string
content, no schema change, immediately renderable by whatever screen already
displays `WorkstationViewModel.description`/`supportingText`.

```json
{
  "receiving-dock": "Roll-up dock door 3, one bay. A pallet truck and a wrapped delivery wait just inside; the driver is parked at the yellow line until the shipment is confirmed against paperwork.",
  "document-desk": "A single desk just inside the dock office, purchase orders and delivery notes filed by supplier. This is where every shipment starts — nothing moves to the dock until the paperwork has been compared.",
  "inspection-zone": "A stainless steel table under bright task lighting, positioned so cartons come straight off the dock trolley. Damage tags, a tape measure and a digital scale sit within reach; nothing inspected here re-enters the flow without a recorded finding.",
  "barcode-station": "A fixed-mount scanner and a small screen bolted beside the inspection table. Every carton passes under the scanner exactly once before it can move on.",
  "quarantine-zone": "A caged, clearly marked holding area beside the dock, separated from the general aisle by a painted red line. Nothing in this cage counts as available stock until a disposition is confirmed and logged.",
  "receiving-office": "A small glass-walled office overlooking the dock. This is where the shift's paper trail becomes a decision — the discrepancy report, the accept/reject call, and the note to the supervisor all happen at this one desk."
}
```

### 1.3 Proposed enrichment — department-level detail

`departmentDefinitions[0]` currently has one `description` line and one
`processes` entry. Proposed additive fields (all new keys, nothing renamed or
removed):

```json
{
  "shiftPattern": "Two shifts per day (06:00–14:00, 14:00–22:00), one Receiving Supervisor and 2–4 Warehouse Associates per shift depending on scheduled deliveries.",
  "escalationPath": "Warehouse Associate -> Receiving Supervisor -> Warehouse Manager. Associates escalate any exception they cannot resolve against the SOP (Section 3) without waiting for supervisor approval to quarantine or hold stock.",
  "keyPerformanceIndicators": [
    "Dock-to-stock time (minutes from truck arrival to receiving decision)",
    "Discrepancy detection rate (documented discrepancies / actual discrepancies present)",
    "Non-compliant stock leakage (compliant-marked items later found damaged or wrong-SKU in inventory)"
  ]
}
```

## 2. SOPs

No SOP exists today as readable content — `operationalRules` (4 bullets in
`workplace.json`) and `workplaceRules` (5 bullets in the mission briefing) are
the closest equivalent, and both are terse rule lists rather than a procedure
a learner can open and follow. `policy` is already a supported
`ResourceType`, and `open_resource`/`read_document`-style interactions
already exist (see `open-purchase-order`), so an SOP is addable as a resource
without any schema change. Whether/when a task requires reading it is a
runtime decision; the content is ready either way.

### 2.1 SOP-RCV-001 — Incoming Shipment Receiving Procedure

**Purpose.** Ensure every incoming shipment is verified against its
paperwork, physically inspected, and that no damaged, unauthorised or
unverified stock enters available inventory before a documented receiving
decision is made.

**Scope.** All scheduled and unscheduled supplier deliveries to the Central
Distribution Centre Receiving department.

**Procedure.**
1. **Document verification (Document Desk).** Before the dock door opens,
   compare the Purchase Order against the Delivery Note. Record every SKU,
   quantity or supplier mismatch. Do not proceed to physical receiving until
   the comparison is submitted.
2. **Delivery confirmation and counting (Receiving Dock).** Confirm the
   physical delivery matches the expected supplier and references. Count
   every carton individually where feasible; sealed-carton label counts are
   acceptable only when the seal is intact and unbroken.
3. **Physical inspection (Inspection Zone).** Inspect every carton for
   packaging damage, expiry/near-expiry, SKU correctness against the
   delivery note, and quantity. Record every finding — a carton with no
   finding is an explicit "compliant" confirmation, not a skipped step.
4. **Barcode verification (Barcode Station).** Scan every carton. An
   unreadable barcode is itself a finding requiring a hold or escalation
   disposition — it must never be recorded as "readable" to move the process
   along.
5. **Exception handling (Quarantine Zone).** Every carton with a finding
   receives a disposition:
   - **Packaging damage → Quarantine.** Damaged stock never enters available
     inventory (workplace rule, non-negotiable).
   - **Unreadable barcode → Hold for verification.** Do not accept or reject
     until the identity is confirmed by an alternate method.
   - **Incorrect/unauthorised SKU → Reject / return.** Stock not on the
     purchase order is not received into this facility.
   - **Near-expiry → Escalate.** Shelf-life acceptance is a supervisor
     decision, not an associate decision — see SOP-RCV-002.
   - **Quantity shortage → Hold for reconciliation.** Record the shortage;
     do not adjust the purchase order or invent a matching count.
   - **No finding → Accept.** Confirmed-compliant stock proceeds normally.
6. **Discrepancy report and receiving decision (Receiving Office).** Every
   discrepancy identified in steps 1–5 must appear in the discrepancy report
   before a receiving decision is made. The decision (accept / partially
   accept / reject) must be consistent with the dispositions already
   assigned — a shipment with any quarantined or rejected item cannot be
   marked a full, unqualified accept.
7. **Shift report.** Notify the Receiving Supervisor with the facts, the
   actions taken and any outstanding risk (e.g. stock on hold pending
   reconciliation). The notification must include the audit trail, not a
   verbal summary alone.

**Non-negotiable rules (from `workplace.json.operationalRules` and the
mission briefing's `workplaceRules` — do not weaken these when authoring
scenarios or scoring):**
- All incoming shipments require document verification before physical
  receiving begins.
- Damaged goods cannot enter available inventory under any circumstance.
- Items not listed on the purchase order must not be accepted.
- Unreadable barcodes require hold or escalation, never silent acceptance.
- Quantity discrepancies must be recorded, never adjusted to match the count.
- Required inspections cannot be skipped, even for a visually intact carton.

### 2.2 SOP-RCV-002 — Near-Expiry and Shelf-Life Exception

**Purpose.** Prevent shelf-life decisions from being made ad hoc by an
associate under delivery-time pressure.

**Procedure.** Any item flagged `near_expiry` during inspection must be
escalated, not independently accepted or rejected by the associate. The
Receiving Supervisor applies the facility's shelf-life policy (minimum
remaining shelf life at receipt, category-specific where applicable) and
records the resulting disposition. The associate's job is complete once the
escalation is logged with the expiry date and the affected SKU/quantity —
this is exactly what `assign-dispositions`' `escalate` outcome for
`near_expiry` already scores for.

### 2.3 SOP-RCV-003 — Quarantine Movement and Release

**Purpose.** Keep quarantined stock physically and systemically separated
from available inventory until a documented release decision.

**Procedure.** Every carton moved to the Quarantine Zone requires a reason
(`quarantine-record` resource already enforces `requiresReason: true`).
Quarantined stock is not released, moved or counted as available inventory by
a Warehouse Associate — release requires a supervisor-approved disposition
change, out of scope for the trainee mission modelled today.

## 3. Scenario library

### 3.1 How the current engine actually generates a scenario

`scenario_generator.dart` reads the mission's `scenario.variationRules` (one
fixed rule set today, not a catalog of alternative rule sets) and a seed. For
each rule, in order, it removes already-assigned targets from
`eligibleTargets`, shuffles the remainder with a seeded PRNG, and assigns the
issue to the first `count` targets. Today's rule set:

| Issue | Eligible targets | Count | Forced or varies by seed |
|---|---|---|---|
| `quantity_shortage` | `carton-002` only | 1 | **Always carton-002** — it's the only eligible target |
| `packaging_damage` | 001, 003, 004, 005, 006 | 1 | Varies |
| `unreadable_barcode` | all 6 | 1 | Varies |
| `incorrect_sku` | all 6 | 1 | Varies |
| `near_expiry` | all 6 | 1 | Varies |

Because there are 6 cartons and 5 forced-or-varying single-target
assignments, **every seed produces the same structure**: `carton-002` always
gets `quantity_shortage`; exactly 4 of the remaining 5 cartons each get
exactly one of the other four issue types; exactly 1 carton is always fully
compliant. Only *which* of the 5 remaining cartons gets which issue (and
which one is compliant) varies by seed. This is a genuine current limitation
worth naming plainly: today's system can reshuffle issue placement, not issue
*presence, absence, count, or type* — there is no way, without a runtime
change, to generate a zero-issue "perfect delivery," a shipment with two
instances of the same issue, or an issue type outside this fixed set of five.

`quantity_shortage` being pinned to `carton-002` is not arbitrary — it's the
only carton whose static `content.quantity` is deliberately designed to
match the pre-authored delivery-note-level shortage (SKU-1002: PO ordered 20,
delivery note shows 18 — see `document-line-SKU-1002` in
`receive_shipment_mission.json`). If a future scenario needs the shortage on
a different carton, the delivery note's static content must move with it, or
the paperwork-level and physical-level findings will contradict each other.

### 3.2 Reference scenario — default seed 48127

Computed by replaying the exact algorithm (`_stableHash` FNV-1a-style hash of
`"receive-incoming-shipment-01@1.0.0"` XORed with the seed, then the same LCG
+ Fisher-Yates the runtime uses) against the current content, so this table
is what a learner starting the mission today actually sees, not a guess:

| Carton | SKU / product | Issue assigned |
|---|---|---|
| carton-001 | SKU-1001, LED Bulb 12W | `unreadable_barcode` |
| carton-002 | SKU-1002, Extension Board | `quantity_shortage` (matches the 20→18 delivery-note shortfall) |
| carton-003 | SKU-1003, AA Battery Pack (batch expiring 2028-03-18) | `incorrect_sku` (relabelled to SKU-1094 "Unauthorized Multi Plug" — matches the pre-authored `document-line-SKU-1094` unexpected-item finding) |
| carton-004 | SKU-1004, Emergency Light | **compliant — no issue** |
| carton-005 | SKU-1001, LED Bulb 12W | `near_expiry` (expiry forced to 2026-09-15) |
| carton-006 | SKU-1003, AA Battery Pack (batch expiring 2028-04-02) | `packaging_damage` |

Expected correct outcome for this run, cross-checked against every task's
`evaluationRules`:
- **Document Desk**: two findings — `quantityMismatch` on SKU-1002,
  `unexpectedItem` on SKU-1094.
- **Receiving Dock**: identity confirmed (`matchesExpectedDelivery`); all 6
  cartons counted, carton-002 correctly counted at 18 (not the PO's 20).
- **Inspection Zone**: 5 findings (one per affected carton, matching the
  table above) + 1 compliant confirmation (carton-004).
- **Barcode Station**: 1 `unreadable` scan (carton-001), 5 `readable` scans.
- **Quarantine Zone**: dispositions — carton-001 `hold_for_verification`,
  carton-002 `hold_for_verification`, carton-003 `reject_return`, carton-004
  `accept`, carton-005 `escalate`, carton-006 `quarantine`.
- **Receiving Office**: discrepancy report with all five issue flags set;
  decision `partially_accept` (the only scored-correct decision today,
  reflecting that carton-004 is clean while five others need holds,
  escalation, quarantine or rejection).

### 3.3 Proposed scenario catalog (needs a runtime capability that doesn't exist yet)

Today's engine can only reshuffle *placement* of the same five issues across
six cartons — it cannot express a genuinely different scenario shape (a
clean delivery, a multi-instance issue, a new issue type, a wrong-supplier
delivery). Below is a proposed content shape for when the runtime supports a
scenario *catalog* (multiple named `variationRules` sets selectable at
attempt start, not just seeds against one fixed set) — this is a request to
the runtime team, written in enough detail to implement directly, not
something added to `receive_shipment_mission.json` in this pass.

```json
{
  "scenarios": [
    {
      "id": "perfect-delivery",
      "name": "Perfect delivery",
      "variationRules": [],
      "expectedDecision": "accept",
      "pedagogicalIntent": "Tests whether the learner still performs full document verification, counting and inspection when nothing is visibly wrong — the most common real failure mode is skipping steps on an apparently-clean shipment."
    },
    {
      "id": "multi-exception-shipment",
      "name": "Multiple exceptions, one carton",
      "variationRules": [
        {"type": "assign_issue", "issue": "packaging_damage", "eligibleTargets": ["carton-003"], "count": 1},
        {"type": "assign_issue", "issue": "unreadable_barcode", "eligibleTargets": ["carton-003"], "count": 1}
      ],
      "expectedDecision": "partially_accept",
      "pedagogicalIntent": "Tests whether the learner records every finding on a carton rather than stopping at the first one — a common shortcut is to log the first issue found and move on."
    },
    {
      "id": "wrong-supplier-delivery",
      "name": "Wrong supplier at the dock",
      "requiresNewIssueType": "wrong_supplier",
      "expectedDecision": "reject",
      "pedagogicalIntent": "Tests the earliest possible catch point — this should be caught at delivery confirmation (Receiving Dock), before any counting or inspection effort is spent on stock that should never have been accepted onto the dock."
    },
    {
      "id": "clerical-only-discrepancy",
      "name": "Paperwork mismatch, physically correct",
      "pedagogicalIntent": "PO/delivery-note quantities disagree with each other but the physical count matches the delivery note exactly — tests whether the learner distinguishes a clerical discrepancy (still must be recorded) from a physical receiving problem (nothing to quarantine or reject)."
    }
  ]
}
```

### 3.4 Shipped extension — new issue types beyond the original five

The scenario catalog proposed in 3.3 has since shipped for real (see
`receive_shipment_mission.json`'s `scenarios` array), which removed the
"engine can only reshuffle placement" limitation named in 3.1 — a named
scenario now supplies its own independent `variationRules` set. Two new
issue types were added on top of the original five (`packaging_damage`,
`unreadable_barcode`, `incorrect_sku`, `near_expiry`, `quantity_shortage`),
each with its own dedicated single-issue scenario rather than folded into
the default seed-48127 rule set:

| Issue | Scenario id | Correct disposition | Correct release decision |
|---|---|---|---|
| `temperature_breach` | `cold-chain-breach-shipment` | `quarantine` (looks fine, but the temperature log doesn't) | `continue_hold`, pending lab verification |
| `tamper_evidence` | `tampered-packaging-shipment` | `reject_return` (authenticity/safety unverifiable) | `not_applicable` — rejected stock needs no release decision |

Both are wired through every stage that scores an issue type end to end:
`inspect-cartons` (recording the finding), `assign-dispositions` (routing
it correctly), `request-quarantine-release` (the supervisor-approval step),
and a dedicated `criticalErrorRules` entry each
(`accept-temperature-breach`, `accept-tampered-goods`) for accepting it
into inventory outright. `micro-lesson-temperature-breach` and
`micro-lesson-tamper-evidence` were added to `remediation.json` so a missed
finding recommends the matching micro-lesson, same as the original five.

## 4. NPC roles and dialogue

### 4.1 Current state — this is a real gap, not just thin content

Neither `workplace.json` nor `receive_shipment_mission.json` defines any
people/NPCs. The mission briefing narratively references a "Receiving
Supervisor" (`supervisorTitle`, `message`) and the SOP above references a
truck driver and quality inspector, but none of these exist as addressable
content. Checked against the runtime enums: `ResourceType` has no `person` (or
similar) variant, and `ActionType` has no `speak`/dialogue-adjacent action —
so this is not an authoring gap alone, it needs a small runtime addition
before any of the dialogue below can be wired into a screen. Flagging as a
request, and providing the content ready to slot in once it exists.

### 4.2 Proposed schema extension (for the runtime team)

```
ResourceType.person   // wire name "person"
ActionType.speak      // wire name "speak" — targetId = person resource id

// A person resource:
{
  "id": "receiving-supervisor",
  "resourceType": "person",
  "title": "Receiving Supervisor",
  "content": {
    "role": "supervisor",
    "guidanceOnly": true,       // never reveals the correct answer
    "dialogue": [
      {
        "id": "greeting",
        "trigger": "mission_start",
        "lines": ["Good morning. Apex Consumer Products is on PO-2026-001. Inspect it carefully — I want every discrepancy recorded, not guessed at."]
      },
      {
        "id": "near_expiry_question",
        "trigger": "learner_asks",
        "topic": "near_expiry_policy",
        "lines": ["If it's near expiry, don't decide that yourself — flag it to me and I'll apply the shelf-life policy."]
      }
    ]
  }
}
```

### 4.3 Roles and example dialogue

**Receiving Supervisor** (guidance only — never reveals findings or the
correct disposition/decision).
- Mission start: *"Good morning. Apex Consumer Products is on PO-2026-001.
  Inspect it carefully — I want every discrepancy recorded, not guessed at."*
- If asked about a near-expiry item: *"Don't decide that yourself — flag it
  to me and I'll apply the shelf-life policy."*
- If the learner tries to skip inspection: *"Every carton gets inspected,
  even the ones that look fine. 'Looks fine' isn't a finding."*
- On shift-report notification received: *"Good — I've got the audit trail.
  I'll follow up on the held stock myself."*

**Truck Driver** (states claimed values; the learner must still verify
against documents — never simply trusted).
- On arrival: *"Full load off PO-2026-001, Apex Consumer Products. Six
  cartons, all present as far as I know."*
- If asked about a specific carton's condition: *"Looked fine when it left
  our warehouse — can't speak for the ride over."* (Deliberately unhelpful
  for damage verification — this line exists so the learner can't outsource
  the inspection to the driver's word.)

**Quality Inspector** (optional colleague, present at Inspection Zone;
observational, never gives the answer).
- *"What have you found on this one?"* — prompts the learner to state a
  finding aloud (content hook for a future "explain your finding" task type,
  not required by any current task).
- If the learner records "compliant" on a carton with a real issue (once
  dialogue can react to state, post-runtime-extension): *"Take another look
  before you sign off on that."*

**Security Guard** (identity/entry only — outside the Receiving process
proper; present for whenever a fuller shift-entry flow is authored).
- *"ID badge, please. You're on the Receiving Dock roster for this shift —
  go ahead."*

## 5. Competency framework

### 5.1 What exists and why these five competencies

`competencies.json` defines five competencies, each with a category,
observable behaviours and five proficiency levels (Aware/Developing/
Competent/Proficient/Advanced at 0/50/70/85/95 minimum score). Rationale for
each, tied to what the mission actually measures:

| Competency | Category | Why it's a distinct competency |
|---|---|---|
| `document-verification` | operational | Paperwork accuracy is the first control point — a learner can be excellent at physical inspection and still fail the process by never catching a PO/DN mismatch. Kept separate from `inventory-accuracy` because it's about *comparing records*, not *counting stock*. |
| `inventory-accuracy` | operational | Physical counting discipline — distinct from document verification because a learner can correctly compare documents yet still miscount cartons at the dock. |
| `goods-inspection` | operational | Observational skill (damage, expiry, barcode, SKU) — distinct from counting because it's about *condition and identity*, not *quantity*. |
| `warehouse-compliance` | safety | Whether non-conforming stock is kept out of available inventory. This is scored separately from inspection because a learner can correctly *identify* damage yet still fail to *act* on it (e.g. accepting a carton they themselves flagged as damaged) — the critical-error rules in Section 6 exist precisely to catch this gap between detection and action. |
| `receiving-decisions` | judgement | The synthesis competency — can the learner turn five separate findings into one coherent, documented, correctly-communicated decision. This is deliberately the highest-weighted competency in `make-receiving-decision` and `notify-supervisor`, because it's the capstone skill the whole mission builds toward. |

### 5.2 Relationship to score categories

`scoringRule.scoreCategories` (process-accuracy 0.25, document-verification
0.20, inventory-accuracy 0.20, quality-inspection 0.15, safety-compliance
0.10, decision-quality 0.10) are *scoring* categories, not identical to the
five *competencies* above — a single task can score into one category while
contributing evidence to a different-but-related competency (e.g.
`assign-dispositions` scores into `safety-compliance` but maps 60% to the
`warehouse-compliance` competency and 40% to `receiving-decisions`). This is
intentional and should stay intentional: score categories answer "how well
did this task go," competencies answer "what does this tell us about the
learner," and they don't have to be the same taxonomy. Future departments
should follow the same pattern rather than collapsing the two.

## 6. Assessment criteria

### 6.1 What "passing" means

`scoringRule`: minimum score 70%, all mandatory tasks required, **zero**
critical errors allowed. In plain terms: a learner cannot pass by being
mostly right — any single critical error (Section 6.2) fails the attempt
regardless of the numeric score, and every mandatory task must be attempted,
not just enough to clear 70%. This matches the department's real-world
stakes: a warehouse associate who gets 9 of 10 things right but accepts one
piece of damaged stock has not "mostly succeeded" — they've created a safety
and compliance failure that the 70% threshold alone would hide.

### 6.2 Critical errors, and what each one protects against

| Rule | Protects against |
|---|---|
| `accept-incorrect-sku` | Unauthorised stock entering inventory — a supply-chain integrity failure (could be counterfeit, could be a different regulatory category). |
| `accept-damaged-stock` | Damaged goods reaching a customer or another department — the most direct safety/quality failure the role exists to prevent. |
| `accept-unreadable-barcode` | Unverifiable stock entering inventory with no reliable way to trace it later — a traceability failure that compounds every downstream process (picking, dispatch, recalls). |
| `record-false-quantity` | Deliberate falsification of counts — an integrity failure distinct from an honest counting mistake (which costs points via `inventory-accuracy` but is not itself a critical error). |
| `approve-without-inspection` | Process-skipping under time pressure — the single most realistic failure mode for a rushed trainee, and the reason `physical-inspection` exists as a mandatory gate before `receiving-decision` can be reached. |
| `omit-discrepancy-report` | Under-reporting to make a shift look cleaner than it was — an honesty/documentation-integrity failure, not a competency gap. |

Each rule carries a 20–25 point penalty *and* `preventsPassing: true` — the
penalty and the hard block are both present so that even in a hypothetical
future scoring change, a critical error stays visibly costly, not just
pass-blocking.

### 6.3 Category weighting rationale

`process-accuracy` (0.25) and `document-verification` (0.20) together make up
45% of the score — reflecting that this mission is entry-level and weighted
toward *process discipline* (did you follow the steps, in order, completely)
over *judgement under ambiguity*. `decision-quality` is intentionally the
lowest weight (0.10) at this trainee level: the mission is testing whether
the learner can execute a known procedure correctly, not yet testing novel
judgement calls. This should shift for more senior role missions later (e.g.
a Shift Supervisor mission should weight decision-quality and
safety-compliance far higher than process-accuracy).

## 7. Learning outcomes

Expanding `objectives` (currently six short imperative phrases) into full
outcome statements, each tied to the competency it evidences:

1. **Verify shipment documents.** *On completing this mission, the learner
   can compare a purchase order against a delivery note and correctly
   identify quantity, SKU and supplier discrepancies without prompting.*
   (`document-verification`)
2. **Inspect received stock.** *The learner can physically inspect a carton
   for packaging condition, expiry status and barcode readability, and
   correctly distinguish a genuine finding from a compliant item — including
   explicitly confirming compliance rather than skipping inspection when
   nothing looks wrong.* (`goods-inspection`)
3. **Identify discrepancies.** *The learner can hold conflicting information
   from three sources (purchase order, delivery note, physical stock) and
   correctly identify which source disagrees with which.* (`document-verification`,
   `inventory-accuracy`)
4. **Separate problematic stock.** *The learner can select the disposition
   that matches each finding type (quarantine, hold, reject, escalate,
   accept) and physically confirm the separation, keeping non-conforming
   stock out of available inventory in every case, not just the obvious
   ones.* (`warehouse-compliance`)
5. **Make the correct receiving decision.** *The learner can synthesise every
   finding and disposition from the shift into a single, consistent
   shipment-level decision (accept / partially accept / reject) that does
   not contradict any individual disposition already recorded.*
   (`receiving-decisions`)
6. **Complete a discrepancy report.** *The learner can produce a complete,
   accurate written record of every discrepancy found during the shift,
   suitable for a supervisor to act on without needing to re-verify the
   shipment themselves.* (`document-verification`, `receiving-decisions`)

## 8. Content backlog

Tracked here so the next content session (Claude or otherwise) doesn't
re-derive this from scratch:

- [ ] Runtime request: `person` resource type + `speak` action type, so
  Section 4's NPC dialogue can be wired to a screen.
- [ ] Runtime request: scenario *catalog* support (multiple named
  `variationRules` sets, not just seed-varied placement of one fixed set),
  so Section 3.3's proposed scenarios become buildable.
- [ ] Once the above land: populate `receive_shipment_mission.json` with the
  Section 4 person resources and Section 3.3 scenario catalog for real.
- [ ] Second department content (Put Away) — deferred per this session's
  scoping decision to deepen Receiving first.
- [ ] Confirm and reconcile the Barcode Station workstation-vs-screen
  question noted in Section 1.1 with whoever owns Screen 06/07 next.
