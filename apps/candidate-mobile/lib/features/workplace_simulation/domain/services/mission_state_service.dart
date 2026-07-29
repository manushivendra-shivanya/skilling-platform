import '../simulation_enums.dart';
import '../simulation_runtime.dart';

class MissionStateService {
  const MissionStateService();

  static const _allowedTransitions = <MissionState, Set<MissionState>>{
    MissionState.notStarted: {MissionState.briefing},
    MissionState.briefing: {MissionState.inProgress},
    MissionState.inProgress: {MissionState.paused, MissionState.submitted},
    MissionState.paused: {MissionState.inProgress},
    MissionState.submitted: {MissionState.evaluated},
    MissionState.evaluated: {MissionState.completed, MissionState.failed},
  };

  bool canTransition(MissionState from, MissionState to) =>
      _allowedTransitions[from]?.contains(to) ?? false;

  SimulationAttempt transition(
    SimulationAttempt attempt,
    MissionState next, {
    DateTime? at,
  }) {
    if (!canTransition(attempt.state, next)) {
      throw StateError(
        'Invalid mission transition: '
        '${attempt.state.wireName} → ${next.wireName}',
      );
    }
    final now = at ?? DateTime.now();
    return attempt.copyWith(
      state: next,
      submittedAt: next == MissionState.submitted ? now : null,
      completedAt: next == MissionState.completed || next == MissionState.failed
          ? now
          : null,
    );
  }
}
