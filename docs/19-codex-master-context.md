# Codex Master Context

## 1. Vision

Build India's trusted AI employment operating system for operational and grey-collar careers.

The platform should help candidates:

1. Discover suitable roles
2. Create a career profile
3. Diagnose skill gaps
4. Receive a personalised pathway
5. Complete daily learning missions
6. Practise realistic work simulations
7. Improve communication through voice AI
8. Build explainable evidence of readiness
9. Apply for jobs
10. Prepare for employer interviews
11. Track offers and joining
12. Receive support during the first 30, 60 and 90 days
13. Build a portable Career Passport

## 2. Initial pilot

Supply Chain and Logistics Operations.

Initial roles:
- Warehouse Operations Associate
- Inventory Executive
- Dispatch Executive
- Hub Supervisor
- Shift Supervisor

## 3. Candidate journey

Acquisition
 app installation
 splash and welcome
 language selection
 OTP login
 consent
 profile creation
 resume upload or guided profile
 voice introduction
 career diagnostic
 recommended role pathway
 home dashboard
 daily missions
 learning units
 practical simulations
 voice interview practice
 readiness and evidence profile
 job discovery
 job details
 consented application
 interview preparation
 offer and joining
 30/60/90-day coaching
 Career Passport and progression

## 4. Main product surfaces

### Candidate mobile app
Primary candidate experience.

### Marketing website
Acquisition, SEO, trust, partnerships and app download.

### Employer portal
Requisitions, candidate evidence, shortlisting, interview scheduling, offers, joining and retention.

### Admin portal
Content, simulations, AI review, candidate support, disputes, compliance and analytics.

### Backend and AI platform
Identity, consent, scoring, voice, simulations, recommendations, integrations and auditability.

## 5. Candidate mobile navigation

Bottom tabs:
- Home
- Learn
- Practise
- Jobs
- Me

Primary global action:
- AI Career Coach
- Voice interaction should be prominent but should not block normal text interaction.

## 6. Mobile capabilities

### Authentication and onboarding
- Phone OTP
- Development authentication adapter
- Google login later
- Language selection
- Location
- Education
- Work experience
- Job preferences
- Versioned consent
- Resume upload
- Voice introduction
- Profile review

### Home
- Candidate greeting
- Career readiness summary
- Daily mission
- Recommended next action
- Application updates
- Learning progress
- AI Coach entry
- Low-data mode indicator
- Pending sync indicator

### AI Career Coach
- Text conversation
- Voice recording
- Audio upload
- Photo and document upload
- Career guidance
- Role recommendations
- Interview preparation
- Learning guidance
- Application guidance
- Clear boundaries and escalation to support

### Diagnostic
- Role preference
- Experience
- Knowledge questions
- Situation judgement
- Communication readiness
- Practical reasoning
- Explainable competency gaps
- Recommended role pathway

### Learning
- Personalised pathway
- Daily mission
- Short lessons
- Checkpoints
- Download for offline use
- Progress
- Resume from last position

### Simulations
Initial simulations should include:
- Inventory discrepancy
- Cycle count
- Dispatch prioritisation
- Damaged goods escalation
- SLA and exception handling

Simulations must:
- Use immutable versions
- Record ordered events
- Work with offline batching
- Score deterministically where possible
- Produce explainable evidence
- Exclude technical failures from reliability scoring

### Voice AI
- Explicit recording consent
- Microphone check
- Recorded-turn interview
- Hindi and Hinglish
- Code-switching support
- Resumeable upload
- Transcription
- Transcript review
- Structured feedback
- Never score accent or emotion
- Allow deletion requests

### Jobs
- Job feed
- Search and filters
- Job details
- Match explanation
- Eligibility
- Employer information
- Consent before sharing evidence
- Apply
- Application tracker
- Interview reminders
- Offer and joining tracker

### Profile and Career Passport
- Personal information
- Skills
- Experience
- Education
- Evidence
- Assessments
- Voice practice
- Simulation results
- Employer SOP completions
- Reliability explanation
- Visibility controls
- Downloadable resume later
- Support and appeal

## 7. Employer journey

Organisation onboarding
 team and roles
 requisition creation
 competency requirements
 optional reliability dimensions
 company SOP module
 matched candidates
 consent-aware evidence review
 shortlist
 interview schedule
 offer
 joining
 30/60/90-day outcomes

## 8. Admin journey

Secure login
 dashboard
 role taxonomy
 competencies
 diagnostics
 simulation versions
 learning content
 AI prompt versions
 AI review queue
 candidate support timeline
 employer support
 disputes and appeals
 audit logs
 privacy and deletion requests
 analytics and fairness monitoring

## 9. AI architecture

Required AI components:
- Career Coach
- Role recommendation
- Diagnostic assistance
- Learning recommendation
- Voice transcription
- Voice interview evaluator
- Resume extraction
- Job matching
- Employer SOP draft assistance
- Candidate support summarisation
- Human review queue

AI platform rules:
- Prompt registry
- Immutable prompt versions
- Structured outputs
- Model routing abstraction
- Retry and fallback
- Cost and latency metrics
- PII redaction
- Audit record for every material AI run
- Human review for consequential or disputed decisions
- AI score must never be the sole basis for rejection

## 10. Technology architecture

### Candidate mobile
- Flutter
- Dart
- Riverpod
- GoRouter
- Material 3
- Feature-first architecture
- Secure local storage
- Offline drafts and queued events
- Android first
- iOS from the same codebase

### Web
- Next.js
- Shared design tokens
- Employer portal
- Admin portal
- Marketing website

### Backend
- NestJS API
- Supabase PostgreSQL
- Supabase Auth where appropriate
- Supabase Storage or abstracted object storage
- Redis for cache, queues and ephemeral workflows
- Python services for AI, speech and media processing

### Deployment
- Vercel for Next.js surfaces
- GitHub Actions for CI and Android APK
- Environment separation for development, staging and production
- Secrets managed outside the repository

## 11. Current repository state

Repository:
manushivendra-shivanya/skilling-platform

Active branch:
feature/flutter-foundation

Current Flutter app:
apps/candidate-mobile

Verified foundation:
- GitHub repository created
- Flutter project created
- Android SDK configuration corrected
- GitHub Actions APK workflow created
- APK builds successfully
- APK installs on Samsung S24 Ultra
- App launches without crashing
- Current app still shows the default Flutter counter page

Important build decisions:
- compileSdk = 36
- targetSdk = 36
- Java 17
- Gradle 9.1.0
- Android Gradle Plugin 9.0.1
- Kotlin 2.3.20
- Removed unused jni dependency because it caused Android plugin build failures
- Preserve .github/workflows/build-apk.yml

## 12. Development environments

### Android/mobile development environment
- Samsung S24 Ultra
- Termux
- Ubuntu 24.04 PRoot
- Flutter CLI
- Git
- GitHub

Limitation:
Android SDK host binaries are not reliable inside ARM64 PRoot.

Therefore:
- Code can be edited and committed from mobile
- Flutter dependency operations can be run where supported
- GitHub Actions is the authoritative APK compiler

### macOS development environment
Use macOS for:
- Flutter development
- Android emulator
- iOS Simulator
- Xcode
- iOS signing
- Android Studio
- Local debugging
- Release builds

The repository must remain usable from both environments.

## 13. Design direction

The app should feel:
- Premium
- Human
- Warm
- Trustworthy
- Modern
- Minimal
- Voice-friendly
- Indian-first
- Simple enough for first-time digital users

Design requirements:
- Large touch targets
- Clear hierarchy
- Low cognitive load
- Single primary action per screen
- Excellent empty and error states
- Accessible typography
- Hindi and English text expansion support
- Avoid heavy animation on operational screens
- Use animation for progress, guidance and emotional reassurance
- Support low-end Android devices
- Support low bandwidth

## 14. Privacy and safety

- Versioned consent
- Data minimisation
- PII masking
- Encryption in transit and at rest
- Tenant isolation
- Audit logs
- Deletion workflow
- Voice retention metadata
- Employer evidence sharing controls
- Appeal and correction mechanisms
- No hidden personality scoring
- No accent discrimination
- No technical failure penalties
- No financial product without regulated partner
- No Aadhaar, government or employer integration without official access and contracts

## 15. Phases

### Phase 1
Production mobile shell, design system, onboarding, navigation, mock data, home, AI Coach shell, jobs shell, learning shell and profile shell.

### Phase 2
Authentication integration, profile persistence, diagnostic, learning pathway, progress, simulations and offline foundations.

### Phase 3
Voice interview, AI evaluation, job applications, employer portal, admin portal and operational analytics.

### Later phases
Reliability dimensions, employer SOP academy, offers, joining, retention, phygital assessment, micro-gigs, ATS integrations and Career Passport.

## 16. Documentation discipline

After every Codex session update:
- docs/generated/current-state.md
- docs/generated/block-diagram.md
- Relevant API and architecture documents
- Tests and manual verification record

Never claim a feature is verified unless automated checks or explicit manual evidence exists.
