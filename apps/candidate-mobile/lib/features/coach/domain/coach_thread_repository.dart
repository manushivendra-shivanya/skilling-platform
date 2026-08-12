import '../../../core/errors/result.dart';
import 'coach_thread.dart';

/// On-device storage for [CoachThread]s -- see that class's doc comment
/// for why this is local, not a server-side "coach data at rest" concern.
abstract interface class CoachThreadRepository {
  Future<Result<List<CoachThread>>> listThreads(String candidateId);

  /// Upsert by [CoachThread.id].
  Future<Result<void>> saveThread(String candidateId, CoachThread thread);
}
