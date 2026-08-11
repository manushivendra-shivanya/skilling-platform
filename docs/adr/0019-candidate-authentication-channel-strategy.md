# ADR-0019: Candidate Authentication Channel Strategy

- Status: Accepted
- Date: 2026-08-11
- Owners: Engineering

## Context

`docs/18-architecture-decisions.md` mandated an ADR for "Authentication and
OTP provider abstraction" from the start; none was ever written, even
though the channel choice changed twice with real, non-obvious reasoning
behind each change. This ADR is backfilled from that reasoning rather than
written ahead of the decision, which is why its date is later than the
work it describes — the goal is to give the decision a canonical, findable
record instead of leaving it scattered across code comments and session
history.

The candidate app needs a sign-in channel that (a) doesn't require the
candidate to have a Google account, (b) doesn't depend on a third-party
messaging vendor's account status or per-message cost, and (c) can
actually deliver in production without a regulatory approval this team
doesn't yet hold.

## Decision

Candidates sign in via **email OTP** (`SupabaseEmailAuthRepository`,
`supabase.auth.signInWithOtp(email:)` / `verifyOTP(type: OtpType.email)`)
or **native Google Sign-In** (`GoogleAuthRepository`, the `google_sign_in`
package's `GoogleSignIn.instance.initialize(serverClientId:)` →
`.authenticate()` → `supabase.auth.signInWithIdToken`). Phone OTP, the
original channel, was removed.

## Alternatives Considered

- **Phone OTP via SMS (original choice).** Rejected on delivery grounds,
  not design: sending transactional SMS to Indian mobile numbers requires
  DLT (Distributed Ledger Technology) registration — a TRAI-mandated
  process tied to the sending entity and message template, independent of
  which SMS gateway is used underneath. That registration was the actual
  cause of production sends 400ing at the Zavu gateway; no code change on
  either the app or the gateway integration would have fixed it.
- **Phone OTP via WhatsApp.** Evaluated as a substitute once SMS's
  regulatory gate was understood. Also rejected: Meta only grants access
  to its Authentication-category message template once a sending number
  clears one of Meta's Scaling Paths *and* sustains 2,000
  business-initiated conversations/day — a volume threshold a pre-launch
  app has no way to reach before it needs working OTP delivery, not after.
- **Aadhaar-based authentication.** Rejected as out of reach at this
  stage: direct Aadhaar e-KYC/authentication requires a UIDAI AUA/KUA
  license, and OTP-based Aadhaar authentication for a private entity
  additionally requires a Section 11A PMLA notification from the Central
  Government. Neither is realistic for a team at this stage.
- **DigiLocker / Meri Pehchaan sign-in.** Evaluated and shelved, not
  rejected outright — it's a real option but a materially bigger lift than
  a channel swap: it needs a Meri Pehchaan partner-approval process (an
  external, non-engineering timeline) and a browser-redirect OAuth flow
  this app has never built (no `signInWithOAuth` usage anywhere, no
  VIEW/BROWSABLE intent filter in `AndroidManifest.xml`). Worth
  revisiting later specifically as **Career Passport identity
  verification** — DigiLocker hands back a government-verified identity
  document, which fits that use case better than it fits a sign-in gate —
  not as the primary authentication path.
- **Direct-to-Supabase browser OAuth (`signInWithOAuth`) for Google.**
  Not used. Google Sign-In goes through the native `google_sign_in`
  package instead, which avoids a Custom Tab/browser hop entirely and
  requires the app's signing SHA-1 to be registered against an Android
  OAuth client in Google Cloud Console — see the CI keystore-stability
  work in `docs/generated/current-state.md`'s Phase OD-1 entry for why
  that registration has to survive across CI builds.

## Consequences

- Email OTP has no per-message regulatory gate equivalent to DLT, so it
  works today without waiting on external approval — at the cost of
  needing a configured email provider (Supabase's own sender, rate-limited
  by default, or a custom SMTP relay for real volume) rather than an SMS
  vendor.
- A candidate with neither an email address they check nor a Google
  account has no sign-in path today. Phone OTP could return once DLT
  registration is complete, as a third channel rather than a replacement.
- The Android OAuth client's registered SHA-1 must track whatever keystore
  actually signs each build channel (CI review builds, and eventually a
  real Play Store release keystore) — a mismatch here is a silent Google
  Sign-In failure with no useful on-device error, which is why the CI
  pipeline treats a stable signing keystore as load-bearing infrastructure,
  not a convenience.

## Security/Privacy Impact

- No SMS vendor holds candidate phone numbers or message content for this
  flow any more; email delivery goes through Supabase's own auth
  infrastructure.
- Google Sign-In's ID token is verified server-side by Supabase
  (`signInWithIdToken`); the client never handles a long-lived Google
  credential.
- Neither channel introduces a new PII category beyond what phone OTP
  already handled (a contact identifier used only for authentication).

## Migration/Rollback

`OtpChallenge.phoneNumber` became `OtpChallenge.contact` specifically so
the shape is channel-agnostic — re-adding phone (or another channel) later
means a new repository implementing `DevelopmentAuthRepository`, not a
domain-model change. No candidate data migration is required: this is a
sign-in-channel change, not a change to what identifies a candidate record
once authenticated.

## References

- `docs/09-candidate-mobile-app.md`
- `docs/13-security-privacy-compliance.md`
- `docs/generated/current-state.md` (Phase OD-1 entry)
- `apps/candidate-mobile/lib/features/authentication/`
