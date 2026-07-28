# Current System Block Diagram

```mermaid
flowchart TD
    U[Candidate] --> APP[Flutter Candidate App]

    APP --> BOOT[Application Bootstrap]
    BOOT --> CONFIG[Build-time Environment]
    CONFIG --> LOCALMODE[Secure Local Development Mode]
    CONFIG -->|URL and publishable key| SUPAINIT[Supabase Initialization]
    BOOT --> LOG[Safe Debug Logger]
    BOOT --> ERR[Framework Error Boundary]

    APP --> ROUTER[GoRouter and Protected Navigation]
    ROUTER --> ENTRY[Welcome, Language and Sign-in]
    ROUTER --> ONBOARD[Candidate Onboarding]
    ROUTER --> SHELL[Persistent Five-tab Shell]
    ROUTER --> DIAG[Career Diagnostic]

    ENTRY --> AUTHCTRL[Authentication Controller]
    AUTHCTRL --> LOCALOTP[Development OTP Adapter]
    AUTHCTRL --> SUPAAUTH[Supabase Phone Auth Adapter]
    ONBOARD --> PROFILECTRL[Candidate Profile and Consent Controller]
    PROFILECTRL --> LOCALPROFILE[Secure Local Profile Adapter]
    PROFILECTRL --> SUPAPROFILE[Supabase Profile Adapter]

    SHELL --> HOME[Home]
    SHELL --> LEARN[Learning]
    SHELL --> PRACTISE[Practice]
    SHELL --> JOBS[Jobs]
    SHELL --> ME[Profile and Evidence]
    SHELL --> COACH[Local Scripted Coach]

    DIAG --> INTELCTRL[Candidate Intelligence Controller]
    LEARN --> INTELCTRL
    PRACTISE --> INTELCTRL
    ME --> INTELCTRL
    INTELCTRL --> LOCALINTEL[Encrypted Local State and Pending Sync]
    INTELCTRL --> OFFLINE[Offline-first Supabase Repository]

    DIAG --> DIAGENGINE[Versioned Deterministic Diagnostic Engine]
    DIAGENGINE --> PATHWAY[Explainable Role Gaps and Pathway]
    LEARN --> CONTENT[Versioned Content, Download and Progress]
    PRACTISE --> SIMEVENTS[Ordered Simulation Event Batch]
    SIMEVENTS --> SCORE[Deterministic Scoring]
    SCORE --> EVIDENCE[Competency Evidence]

    SUPAAUTH --> JOBSKILLS[(JobSkills Supabase)]
    SUPAPROFILE --> JOBSKILLS
    OFFLINE --> JOBSKILLS
    JOBSKILLS --> RLS[Candidate Ownership RLS]
    JOBSKILLS --> CATALOG[Read-only Published Taxonomy and Content]

    APP --> THEME[Material 3 Design System]
    THEME --> ACCESS[Accessible Shared Components]
    ACCESS --> STATES[Loading, Empty, Error, Offline and Pending Sync]
    APP --> ANALYTICS[Local Non-PII Analytics]

    GH[GitHub Repository] --> ACTIONS[GitHub Actions APK Build]
    ACTIONS --> APK[Signed Android Debug APK]
    APK --> DEVICE[Samsung S24 Ultra]

    API[NestJS BFF - PLANNED]
    REDIS[Redis - PLANNED]
    AI[Python AI Services - PLANNED]
    WEB[Next.js Web Apps - PLANNED]

    APP -. Consequential and privileged operations .-> API
    API -. Future .-> JOBSKILLS
    API -. Future .-> REDIS
    API -. Future .-> AI
    WEB -. Future .-> API
```
