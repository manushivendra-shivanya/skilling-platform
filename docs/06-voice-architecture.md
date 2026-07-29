# 06 — Voice Architecture

## Goals
- Natural Hindi/Hinglish interview and coaching.
- Works on low-cost Android devices and variable networks.
- Supports both real-time and store-and-forward modes.
- Provides transparent recording consent and deletion controls.

## Session Modes
1. Real-time conversational session using WebRTC/WebSocket.
2. Turn-based recorded answer with upload and delayed feedback.
3. Offline capture with resumeable background upload.

Phase 3.1 implements mode 2 with local queueing toward mode 3. Real-time mode,
production transcription, and signed media credentials remain behind the
planned NestJS BFF.

## Pipeline
```text
Mic → device audio processing → encrypted stream/upload
→ speech activity detection → transcription → dialogue manager
→ rubric-aware response generation → TTS → playback
→ structured evaluation → feedback and evidence
```

## Mobile Audio Requirements
- Echo cancellation
- Noise suppression
- Automatic gain control where appropriate
- Bluetooth and wired headset support
- Incoming-call interruption handling
- Visible recording state
- Upload retry and checksum

## Language Handling
- User chooses preferred language.
- Code-switching is expected and preserved.
- Transcript stores original text and optional normalised form.
- Evaluation judges job content and communication clarity, not accent imitation.
- Low transcription confidence triggers replay, clarification, or human review.

## Latency Targets
- First response audio under 2.5 seconds in real-time mode where network allows.
- Partial transcript under 1 second after speech segment.
- Recorded-answer feedback can be asynchronous but status must be visible.

## Consent and Retention
Separate consent for:
- recording,
- transcription,
- AI evaluation,
- employer sharing,
- model improvement use.

Audio retention is shorter than derived evidence by default. Candidates can request deletion subject to legitimate legal/audit requirements.

## Failure Handling
- Fallback from streaming to recorded turns.
- Preserve session state on app termination.
- Never fabricate a transcript when speech is unintelligible.
- Mark incomplete sessions without penalising reliability when failure is technical.

## Phase 3.1 Safety Boundary
- Microphone access follows explicit permission education and consent.
- The candidate reviews or corrects every transcript before evaluation.
- Development evaluation uses transcript content only.
- Accent, vocal emotion, personality and protected traits are not inferred.
- Technical failures are excluded from feedback and evidence.
- Every evaluation requires human review and cannot reject or shortlist.
- Audio uses a private bucket; short-lived upload/download credentials are
  authorised by the BFF.

## Voice Session Types
- Baseline introduction
- Behavioural interview
- Role knowledge interview
- Situational judgement
- Supervisor escalation
- Customer communication
- Spoken workplace practice

## Voice Evaluation Dimensions
- Answer relevance
- Operational correctness
- Structure
- Clarity
- Listening comprehension
- Appropriate escalation
- Improvement over prior attempts
