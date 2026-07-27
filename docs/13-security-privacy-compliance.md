# 13 — Security, Privacy and Compliance

## Baseline
Design for Indian privacy and employment context, while obtaining qualified legal advice before production. Maintain a data inventory, processing purposes, retention schedule, vendor register, incident plan, and data-subject request process.

## Controls
- Encryption in transit and at rest.
- Field encryption for high-risk PII.
- Key rotation.
- MFA for employer/admin users.
- RBAC/ABAC and tenant isolation.
- Secure upload scanning.
- Signed URLs with short expiry.
- Dependency and secret scanning.
- Audit logs and anomaly detection.
- Backup restoration tests.

## Candidate Rights and Transparency
- Layered consent notices in preferred language.
- Download and correction pathway.
- Consent withdrawal.
- Account deletion request.
- Score explanation and appeal.
- Clear distinction between verified, self-reported, inferred, and employer-provided information.

## Aadhaar and Government Integrations
Do not store Aadhaar data or implement e-KYC based on assumptions. Use only officially authorised flows, approved providers, purpose limitation, and minimal data retention. API Setu, Skill India, and CSC access must be validated through official documentation and agreements.

## Employment Fairness
- No autonomous rejection based solely on AI or reliability score.
- Protected characteristics excluded from operational scoring.
- Fairness monitoring and documented remediation.
- Employer misuse reporting.

## Financial Layer
Wallet ledger can track platform stipends, but regulated financial services require licensed partners, separate terms, explicit consent, and clear grievance routes. Employment access cannot be conditioned on accepting a financial product.
