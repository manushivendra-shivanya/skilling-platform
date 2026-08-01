import '../../../core/errors/result.dart';
import '../../workplace_simulation/domain/simulation_runtime.dart';

/// A candidate-owned, revocable public share link -- a
/// `career_passport_grants` row with purpose `public_link`. Opening [url]
/// requires no Flora account; it is served read-only by the BFF and
/// reflects [revoke] immediately.
class ShareLink {
  const ShareLink({
    required this.token,
    required this.url,
    required this.expiresAt,
  });

  final String token;
  final String url;
  final DateTime expiresAt;
}

/// One employer the candidate has applied to, and whether they currently
/// have an active, employer-specific grant to review this candidate's
/// Career Passport evidence -- the per-employer replacement for the old
/// single global "shared with employers" toggle.
class EmployerAccessEntry {
  const EmployerAccessEntry({
    required this.employerId,
    required this.employerName,
    required this.granted,
  });

  final String employerId;
  final String employerName;
  final bool granted;
}

/// Reads a candidate's governed evidence and manages who can see it. Never
/// ranks, scores or certifies -- it only surfaces evidence Flora already
/// generated and records human-owned visibility choices.
abstract interface class CareerPassportRepository {
  Future<Result<List<EvidenceRecord>>> loadEvidence(String candidateId);

  /// Whether [createShareLink]/[revokeShareLink] can ever succeed. False
  /// for a local-only build (no account) or one with no configured API
  /// base URL (nowhere to point the link).
  bool get canManageShareLink;

  /// The candidate's current active share link, or null if none has been
  /// generated (or it was revoked/expired).
  Future<Result<ShareLink?>> loadShareLink(String candidateId);

  /// Returns the existing active link if one exists; otherwise generates
  /// and returns a new one. Idempotent by design -- a candidate has at
  /// most one active public link at a time.
  Future<Result<ShareLink>> createShareLink(String candidateId);

  Future<Result<void>> revokeShareLink(String candidateId);

  /// Whether employer-access grants can ever be managed for this
  /// candidate. False for a local-only build or one with no configured API
  /// base URL (listing applied-to employers requires the BFF).
  bool get canManageEmployerAccess;

  /// Every employer behind a non-withdrawn application, each labelled with
  /// whether they currently have an active review grant.
  Future<Result<List<EmployerAccessEntry>>> loadEmployerAccess(
    String candidateId,
  );

  Future<Result<void>> grantEmployerAccess(
    String candidateId,
    String employerId,
  );

  Future<Result<void>> revokeEmployerAccess(
    String candidateId,
    String employerId,
  );
}
