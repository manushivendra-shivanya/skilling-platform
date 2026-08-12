import '../../../core/errors/result.dart';
import '../domain/coach_message.dart';
import '../domain/coach_repository.dart';

/// Config-gated fallback when no live backend is configured -- same
/// posture as `LocalMockJobsRepository`. Keeps Coach usable in a pure
/// local/mock build, with a canned reply that makes no claim of being
/// AI-generated (see coach_threads_screen.dart's banner, which reads this
/// flag via `isLiveData`).
class LocalDemoCoachRepository implements CoachRepository {
  const LocalDemoCoachRepository();

  @override
  bool get isLiveData => false;

  @override
  Future<Result<CoachReply>> sendMessage({
    required String message,
    required List<CoachMessage> history,
  }) async {
    return const Success(
      CoachReply(
        text:
            'Demo guidance: break the task into steps, confirm safety and '
            'accuracy, then explain when you would escalate to a supervisor.',
        modelId: 'local-demo',
        provider: 'local-demo',
      ),
    );
  }
}
