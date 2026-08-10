import '../../../core/errors/result.dart';

/// On-device only, unlike [JobsRepository] -- there is no `saved_jobs`
/// table and no cross-device sync need for a bookmark list. Mirrors how
/// micro-lesson/certification-exam attempts are stored: a
/// [SecureKeyValueStore]-backed set scoped to the signed-in candidate.
abstract interface class SavedJobsRepository {
  Future<Result<Set<String>>> readSavedJobIds(String candidateId);

  /// Toggles a single job in or out of the saved set -- callers don't need
  /// to read-modify-write the whole set themselves.
  Future<Result<void>> setSaved(
    String candidateId,
    String jobId, {
    required bool saved,
  });
}
