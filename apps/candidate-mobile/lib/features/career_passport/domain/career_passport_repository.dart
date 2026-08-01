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

/// Reads a candidate's governed evidence and manages whether it is
/// shareable with employers. Never ranks, scores or certifies -- it only
/// surfaces evidence Flora already generated and records a human-owned
/// visibility choice.
abstract interface class CareerPassportRepository {
  Future<Result<List<EvidenceRecord>>> loadEvidence(String candidateId);

  /// False (private) when no consent has been granted, or when this
  /// candidate has no account connection to grant one at all.
  Future<Result<bool>> isShareable(String candidateId);

  /// Whether [setShareable] can ever succeed for this candidate. False for
  /// a local-only (unconfigured) build, where there is nowhere to record a
  /// sharing grant.
  bool get canManageSharing;

  Future<Result<void>> setShareable(String candidateId, bool shareable);

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
}
