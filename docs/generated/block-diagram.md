# Current System Block Diagram

```mermaid
flowchart TD
    U[Candidate] --> APP[Flutter Candidate App]
    APP --> MOCK[Mock Repositories]

    APP --> ONB[Onboarding - PLANNED]
    APP --> HOME[Home - PLANNED]
    APP --> COACH[AI Coach Shell - PLANNED]
    APP --> LEARN[Learning - PLANNED]
    APP --> PRACTICE[Practice - PLANNED]
    APP --> JOBS[Jobs - PLANNED]
    APP --> PROFILE[Profile - PLANNED]

    GH[GitHub Repository] --> ACTIONS[GitHub Actions APK Build]
    ACTIONS --> APK[Android Debug APK]
    APK --> DEVICE[Samsung S24 Ultra]

    API[NestJS API - PLANNED]
    DB[Supabase PostgreSQL - PLANNED]
    REDIS[Redis - PLANNED]
    AI[Python AI Services - PLANNED]
    WEB[Next.js Web Apps - PLANNED]

    APP -. Future .-> API
    API -. Future .-> DB
    API -. Future .-> REDIS
    API -. Future .-> AI
    WEB -. Future .-> API


## 2. Commit and push

Run:

```bash
cd /root/skilling-platform

git add AGENTS.md \
  docs/19-codex-master-context.md \
  docs/20-codex-phase-execution.md \
  docs/generated/current-state.md \
  docs/generated/block-diagram.md

cd /root/skilling-platform

git add AGENTS.md \
  docs/19-codex-master-context.md \
  docs/20-codex-phase-execution.md \
  docs/generated/current-state.md \
  docs/generated/block-diagram.md
