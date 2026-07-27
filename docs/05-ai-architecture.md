# 05 — AI Architecture

## AI Use Cases
- Diagnostic interpretation
- Learning pathway recommendation
- Voice interview facilitation
- Transcript and answer evaluation
- Coaching feedback generation
- Simulation free-text evaluation
- Employer SOP content transformation
- Candidate-job matching support
- Support assistant

## Architecture
```text
Product Service → AI Orchestrator → Policy/Prompt Registry
                               → Model Gateway/Providers
                               → Retrieval Layer
                               → Structured Output Validator
                               → Evaluation and Safety Layer
                               → Human Review Queue
```

## Rules
- Models do not directly write authoritative scores without rubric validation.
- Every AI run stores model, prompt version, rubric version, input hash, output, latency, and cost.
- Consequential outputs include confidence and explanation.
- AI assists shortlisting; it does not autonomously reject candidates.
- Sensitive attributes are excluded from scoring features unless legally required for fairness auditing and tightly controlled.
- No emotion recognition from face or voice.
- Accent, pitch, and perceived personality are not employability features.

## Model Routing
Use task-specific routing:
- Low-cost model for classification and formatting.
- High-reasoning model for complex rubric evaluation.
- Speech provider for transcription with language confidence.
- Text-to-speech provider for natural coach output.
- Deterministic rules for objective simulation events.

## Retrieval
Employer SOP retrieval is tenant-isolated. Documents are chunked, versioned, approved, and tagged with jurisdiction, role, location, and effective date. Generated answers cite internal source sections in the admin review interface.

## Evaluation Framework
### Offline
- Gold datasets reviewed by domain experts.
- Inter-rater agreement.
- Accuracy by language, region, gender, device quality, and experience level.
- Hallucination, safety, and rubric adherence tests.

### Online
- Human overturn rate.
- Candidate appeal rate.
- Employer disagreement rate.
- Score drift.
- Cost and latency.
- Downstream interview and retention correlation without claiming causality prematurely.

## Prompt Governance
- Draft → test → review → approved → deployed → retired.
- Production prompt versions are immutable.
- Prompt changes require evaluation results.
- Employer-specific prompts cannot leak across tenants.

## Safety
- Detect self-harm, harassment, discrimination, fraud, and coercion in relevant support contexts.
- Escalate employment discrimination or unsafe workplace complaints to human support.
- Never generate false credentials or coach deception.
- Avoid legal, financial, or medical advice beyond approved informational content.

## Explainability
Output evidence includes:
- rubric dimension,
- observed answer or action,
- score contribution,
- confidence,
- improvement recommendation,
- model and rubric version for audit.
