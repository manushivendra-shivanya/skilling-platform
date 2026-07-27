# 14 — Analytics and Workplace Reliability Graph

## Purpose
Provide evidence about observed consistency and task reliability, not a moral judgement, creditworthiness measure, or guaranteed prediction of employment retention.

## Candidate-Facing Name
Use a less punitive product label such as **Work Readiness Consistency** while retaining `reliability_score` as an internal technical concept if needed.

## Inputs
Eligible inputs:
- completion relative to self-selected or assigned deadlines,
- scheduled mock-shift attendance,
- simulation SLA response,
- consistency across repeated attempts,
- verified micro-gig acceptance and completion,
- employer-confirmed post-placement milestones with candidate visibility.

Excluded inputs:
- caste, religion, gender, disability, health, family status,
- accent or voice emotion,
- phone price or device model as a negative signal,
- raw GPS surveillance,
- social media,
- unrelated credit/financial data.

## Score
A 300–900 display range may be used only after validation. Initial product should show dimensions and bands before presenting a single composite score.

Example dimensions:
- Punctuality evidence
- Completion consistency
- SLA discipline
- Communication follow-through
- Verified assignment reliability

## Statistical Validation
- Define target outcomes.
- Separate training, validation, and temporal holdout datasets.
- Evaluate calibration and subgroup parity.
- Publish internal model cards.
- Never pitch a “90% probability of staying” without validated, current, employer-specific evidence and uncertainty bounds.

## Candidate Controls
- View contributing events.
- Correct inaccurate records.
- Appeal score.
- Understand expiration/recency.
- Choose whether employers can view the score.
