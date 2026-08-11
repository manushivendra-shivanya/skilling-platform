# 04 — UI/UX Design System

This is the single, authoritative source for how Flora looks, feels, and is
built — screen inventory and design philosophy in one place, so there is one
door to walk through, not several documents to reconcile. It replaces the
former split between a screen-inventory spec and a separately-tracked design
system document; both are folded in below.

**Treat Part 2 as a checklist for every new or redesigned screen, not
inspiration.** A screen that doesn't hold up against every item in it is not
done, the same way a screen with a failing test is not done. `AGENTS.md`
lists this file as mandatory reading before touching any candidate-facing
screen — that is the mechanism that keeps this binding across every session,
not just the one that wrote it.

---

## Part 1 — Screen Inventory

### Design Principles
- Candidate flows are mobile-first, thumb-friendly, voice-friendly, and resilient to interrupted connectivity.
- Every task shows purpose, expected time, progress, and completion state.
- Complex scores show evidence and next actions, not only a number.
- Hindi/Hinglish copy is conversational, respectful, and occupation-specific.
- Accessibility: scalable type, captions/transcripts, colour-independent status, screen-reader labels, minimum tap targets.

### How the app should feel
Premium, human, warm, trustworthy, modern, minimal, voice-friendly, Indian-first,
and simple enough for a first-time digital user. In practice that means: large
touch targets, clear hierarchy, low cognitive load, a single primary action
per screen (see Part 2, principle 1), excellent empty and error states,
accessible typography with Hindi/English text-expansion room, animation
reserved for progress/guidance/reassurance rather than operational screens,
and support for low-end Android devices on low bandwidth.

### Candidate Screen Inventory
#### Acquisition and access
1. App splash and language selection
2. Mobile number entry
3. OTP verification
4. Consent summary
5. Permissions education

#### Onboarding
6. Name and location
7. Education and work experience
8. Availability and travel radius
9. Role interest selection
10. Device/audio readiness check
11. Onboarding completion

#### Diagnostic
12. Diagnostic introduction
13. Section progress
14. Scenario question
15. Audio response question
16. Break/resume screen
17. Diagnostic result
18. Recommended pathways

#### Home and learning
19. Candidate home
20. Daily mission
21. Pathway overview
22. Lesson/player
23. Knowledge check
24. Mission completion
25. Streak and weekly progress

#### Simulation
26. Simulation briefing
27. Mock workstation/home
28. Task inbox
29. Scanner/POS/WMS interaction
30. Exception modal
31. Supervisor escalation
32. Submit review
33. Result and evidence
34. Retry plan

#### Voice coach
35. Coach home
36. Session selection
37. Microphone check
38. Call-like voice session
39. Transcript review
40. Feedback dimensions
41. Suggested answer structure
42. Practice replay

#### Career and jobs
43. Readiness profile
44. Career passport
45. Job feed
46. Job details
47. Employer sharing consent
48. Application confirmation
49. Application tracker
50. Interview details
51. Offer details

#### Post-placement
52. Joining checklist
53. Day-one guide
54. Daily onboarding mission
55. Manager expectation check
56. 30/60/90-day milestones
57. Support/grievance entry

#### Profile and support
58. Profile
59. Documents
60. Language and accessibility
61. Privacy and consent centre
62. Notification settings
63. Help centre
64. Score appeal
65. Account deletion

### Employer Portal Screen Inventory
1. Sign-in and organisation setup
2. Dashboard
3. Requisition list
4. Create requisition wizard
5. Competency threshold builder
6. Location and shift requirements
7. Candidate match list
8. Candidate evidence profile
9. Reliability evidence explanation
10. Shortlist workspace
11. Interview scheduler
12. Interview scorecard
13. Offer tracker
14. Joining tracker
15. 30/60/90-day retention dashboard
16. SOP programme list
17. SOP authoring/import
18. SOP assignment
19. Integration settings
20. Team and permissions
21. Billing and usage
22. Audit log

### Admin Portal Screen Inventory
1. Global operations dashboard
2. Candidate search and support timeline
3. Employer/tenant management
4. Role and competency taxonomy
5. Pathway authoring
6. Content authoring and publishing
7. Simulation builder
8. Simulation version comparison
9. Rubric builder
10. Prompt registry
11. AI run explorer
12. Human review queue
13. Score appeal queue
14. Voice session quality dashboard
15. Phygital centre management
16. Assessor management
17. Micro-gig operations
18. Wallet reconciliation
19. Notification templates
20. Feature flags
21. Consent and policy versions
22. Security and audit logs
23. Analytics definitions
24. Integration health

### Candidate Home Layout
- Greeting and current goal
- Today card with one primary CTA
- Readiness summary with evidence count
- Continue pathway
- Upcoming interview/job action
- Voice practice shortcut
- Bottom navigation: Home, Learn, Practise, Jobs, Me

### Key UX Rules
- Never show a candidate a retention probability as a fact.
- Reliability explanations list observed behaviours and data windows.
- Employer sees score bands and evidence with confidence and recency.
- Candidate sees what is shared before consent.
- Destructive actions require clear confirmation and recovery where possible.
- Offline mode identifies which modules are downloaded and which submissions are pending.

---

## Part 2 — Best-in-Class Design System

### Why this part exists

The Home and Voice Interview Practice redesigns (see the `2782334`-lineage
commits and the interview-practice redesign commit on `main`) came out of a
`/deep-research` pass on what makes mobile product design genuinely
best-in-class, not just "clean Material Design." That research first lived
only in a downloaded document and scattered code comments, then briefly as
a separate document before being folded in here — one UI door, not several
documents to keep in sync. That's exactly how Lessons, Practise, and
Certification ended up visually out of sync with Home: built to an earlier,
generic standard and never
retrofitted.

### The principles, grounded in what's already shipped

#### 1. One primary action per screen, everything else demoted
`TodayMissionCard` owns Home's only `FilledButton`; every other destination
is a row or an outlined action. Five equal buttons is not a design, it's an
unmade decision. Before shipping a screen, count the filled/primary buttons
on it — if it's more than one, that's a finding, not a style choice.

#### 2. Evidence and cost before commitment, not after
`TodayMissionCard` shows duration and format *before* the action button —
a candidate on a prepaid data plan decides whether to start based on what
a task will cost them, not after they've already tapped in. Anywhere a
candidate commits to something (time, data, an attempt), the cost is
visible before the commitment, not revealed after.

#### 3. Recency, not just a lifetime total
`HomeHeader`'s evidence count always carries its window ("7 proof items ·
last 30 days"), because a bare lifetime number reads as static and
recency is what an employer actually weighs. Any count that matters to a
decision (evidence, attempts, streaks) needs its time window stated next
to it, not implied.

#### 4. Real data, not decorative motion
`AnswerPacingTrack` is deliberately **not** a waveform: the capture layer
exposes no amplitude, so a moving waveform would be animation pretending to
be data. Every piece of motion or visual richness on screen has to represent
something real and known — if the honest answer is "we don't have that
signal," the honest UI is simpler, not faked.

#### 5. Colour is never the only channel
`AnswerPacingTrack`'s pace band is drawn, its figure is written in digits,
and its label states the same fact in words — three channels for one piece
of information, so colourblindness or a washed-out outdoor screen never
loses the point. Anywhere status is colour-coded (readiness bands, pace,
pass/fail), it also needs a label and/or an icon carrying the same meaning.

#### 6. Cards read as lifted, not stacked
Home's mission card is a scroll-list sibling `Transform.translate`d to
overlap the header gradient — a real elevation relationship — rather than
another flat card in a flat list. Flat, evenly-spaced cards of equal visual
weight is the generic-Material default this system explicitly rejects; there
should always be one thing the eye lands on first.

#### 7. Real icons, not bare Material defaults with no branding
The Home rebuild replaced bare `Icon(Icons.foo)` glyphs with a branded
header, layered shadows, and icon plates with intentional background tints
(`AppColors.brandSoft`/`infoSoft`/etc. behind each icon) — see
`_IconPlate` in `home_dashboard_screen.dart`. An icon floating on bare
background with no plate, tint, or shadow is the "thought is good, design is
poor" failure mode this system was built to stop.

#### 8. Digits that tick must not reflow
`AnswerPacingTrack`'s clock uses `FontFeature.tabularFigures()` specifically
so the seconds counting up doesn't jiggle the layout next to it. Any live-
updating number (timers, counters, scores) needs tabular figures.

#### 9. Hinglish is the default voice, not a translation pass
Copy throughout Home and the voice interview redesign ("Aaj koi mission
nahi", "Bilkul sahi lambai", "Ab samet lijiye") is written directly in
Hinglish, matched to the candidate's actual register — not English copy
translated afterward. This reinforces this file's own Part 1 principle
("Hindi/Hinglish copy is conversational, respectful, and occupation-specific")
for anything visual, not just microcopy.

#### 10. State something true, or say nothing
The voice interview screen states the no-accent-scoring promise on the
recording screen itself, not buried in a policy page, because that's the
moment the promise is actually in doubt. Reassurance, disclaimers, and
status copy belong at the point of doubt, not in a settings page nobody
reads before they need it.

### Checklist for any new or redesigned screen

- [ ] Exactly one filled/primary action, everything else demoted
- [ ] Cost/time/format shown before the commit action, not after
- [ ] Any count that matters to a decision carries its time window
- [ ] No animation or visual richness represents data the app doesn't have
- [ ] Every colour-coded status also has a label or icon carrying the same meaning
- [ ] The primary content reads as elevated (real shadow/overlap), not one more flat card
- [ ] Every icon sits in a tinted plate with intentional colour, not bare on background
- [ ] Live-updating numbers use tabular figures
- [ ] Copy is written in Hinglish directly, not translated after the fact
- [ ] Reassurance/disclaimer copy sits at the point of doubt, not a policy page

### Known screens still below this bar

As of this writing: **Lessons, Practise, and Certification** (the merged
Learn/Practise tab) were flagged as not in sync with this design language —
generic Material list tiles, no branded header, no evidence-first framing.
Mocks for their redesign are the next piece of work; check them against
every item above, not just against how Home looks.

---

## Part 3 — Where This Is Heading

This is deliberately not a frozen spec. The ambition behind this document is
genuine, top-tier product quality that stands up against the best consumer
apps built anywhere — not an internal figure of speech — and that only holds
up if the standard keeps moving as the product does. A few things worth
naming so future work has somewhere to aim rather than just a floor to
clear:

- **Motion with meaning, not motion for polish.** Principle 4 forbids fake
  data; it doesn't forbid real transitions. As more genuine signals become
  available (live readiness deltas, real-time shift status, streak
  momentum), motion that visualizes an actual state change is in scope —
  motion that exists only to look alive is not.
- **The design language should get *harder* to violate over time, not
  easier to work around.** If a future screen needs an exception to the
  checklist, that's a signal to either fix the screen or amend this
  document with the same grounding discipline used above (cite the file,
  cite the reasoning) — not to quietly ship the exception.
- **Every redesign is a candidate for extending Part 2, not just following
  it.** A pattern proven out once (like the mission card's overlap, or the
  pacing track's three-channel status) belongs here the moment it's
  shipped, with the same citation style, so the next screen inherits it
  instead of reinventing it.

### Keeping this current

This file is not a one-time snapshot. Treat it as living:
- When a redesign establishes a new pattern worth reusing, add it to Part 2
  with the same grounding style — cite the file and the reasoning, not just
  the rule.
- If a genuinely new design-research pass happens (another `/deep-research`
  round, a fresh review against the best consumer product design out there),
  fold its conclusions into this file rather than leaving them in a
  downloaded document or a chat transcript — that's the only form that
  survives a session switch.
- Keep this as the *only* UI guideline document. If a new one seems worth
  starting, that's usually a sign this file needs a new section instead —
  ask before splitting it again.
