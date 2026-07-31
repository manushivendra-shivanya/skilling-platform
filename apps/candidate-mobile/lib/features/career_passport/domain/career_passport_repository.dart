import '../../../core/errors/result.dart';
import '../../workplace_simulation/domain/simulation_runtime.dart';

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
}
