# 09 — Candidate Mobile App

## Technology Direction
React Native with Expo and TypeScript. Android is the first operational priority; iOS remains supported from the same codebase. Native modules may be introduced for audio, security, or performance where justified.

## Navigation
Bottom tabs:
- Home
- Learn
- Practise
- Jobs
- Me

## Core Modules
- OTP authentication
- profile and consent
- diagnostic
- personalised pathway
- learning player
- simulation runtime
- voice coach
- readiness and evidence
- jobs and applications
- notifications
- post-placement journey
- support and appeal

## Offline Strategy
- Cache pathway metadata and downloaded learning units.
- Queue simulation events locally with sequence IDs.
- Encrypt sensitive local storage.
- Resume media uploads.
- Clearly show pending sync.
- Do not calculate authoritative scores only on-device.

## Performance Budgets
- Fast start on low-end Android.
- Avoid heavy animation on critical task screens.
- Compressed images/audio.
- Progressive download.
- Monitor crashes, ANRs, memory, and battery.

## Candidate Evidence Profile
Shows:
- competency score and level,
- source evidence,
- date and recency,
- verified physical badges,
- employer SOP completions,
- reliability band and explanation,
- visibility controls.

## Notifications
- daily mission
- incomplete upload
- interview reminder
- job match
- SOP deadline
- joining checklist
- post-placement milestone

Notification frequency is user-controlled and avoids manipulative streak pressure.
