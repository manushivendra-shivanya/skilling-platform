import '../../../core/errors/result.dart';

/// On-device only, same posture as `SavedJobsRepository` -- there is no
/// `viewed_clips` table and no cross-device sync need for "did I watch
/// this yet". Mirrors how micro-lesson/certification-exam attempts are
/// stored: a secure-storage-backed set scoped to the signed-in candidate.
abstract interface class ViewedClipsRepository {
  Future<Result<Set<String>>> readViewedClipIds(String candidateId);

  /// Idempotent -- marking an already-viewed clip viewed again is a no-op,
  /// not an error, since the player calls this every time playback crosses
  /// the near-end threshold, not just the first time.
  Future<Result<void>> markViewed(String candidateId, String clipId);
}
