import '../../../core/errors/result.dart';
import 'coach_message.dart';

class CoachReply {
  const CoachReply({
    required this.text,
    required this.modelId,
    required this.provider,
  });

  final String text;

  /// Recorded for auditability, not shown to the candidate -- mirrors
  /// apps/api's coach service, which returns it on every reply.
  final String modelId;
  final String provider;
}

/// Implemented by `ApiCoachRepository` (real backend, see
/// `apps/api/src/coach`) and `LocalDemoCoachRepository` (config-gated
/// fallback when no live backend is configured, same posture as
/// `LocalMockJobsRepository`).
///
/// Deliberately stateless on this side too: the coach has no server-side
/// memory (see docs/27-ai-coach-plan.md's ephemeral-history decision), so
/// every call sends the full `history` the candidate has seen so far.
abstract interface class CoachRepository {
  bool get isLiveData;

  Future<Result<CoachReply>> sendMessage({
    required String message,
    required List<CoachMessage> history,
  });
}
