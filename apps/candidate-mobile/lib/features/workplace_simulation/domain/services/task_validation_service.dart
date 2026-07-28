import '../simulation_content.dart';
import '../simulation_enums.dart';
import '../simulation_runtime.dart';

class TaskValidationService {
  const TaskValidationService();

  void validate({
    required MissionDefinition mission,
    required SimulationAttempt attempt,
    required LearnerAction action,
  }) {
    if (attempt.state != MissionState.inProgress) {
      throw StateError('Actions require an in-progress mission');
    }
    if (action.attemptId != attempt.id ||
        action.missionId != attempt.missionId) {
      throw const FormatException('Action ownership does not match attempt');
    }
    if (action.sequenceNumber != attempt.actionCount + 1) {
      throw const FormatException(
        'Learner actions must use continuous sequence numbers',
      );
    }
    final task = mission.task(action.taskId);
    if (task.stageId != action.stageId) {
      throw const FormatException('Action stage does not match its task');
    }
    if (action.isTechnical) return;
    if (!task.availableActions.contains(action.actionType) &&
        !action.isTechnical) {
      throw StateError('Action is not available for task ${task.id}');
    }
    if (action.targetId != null &&
        !task.targetResourceIds.contains(action.targetId)) {
      throw const FormatException('Action target is outside its task');
    }
    if (!task.repeatable &&
        attempt.actions.any(
          (item) => item.taskId == task.id && !item.isTechnical,
        )) {
      throw StateError('Task ${task.id} is not repeatable');
    }
    if (action.actionType == ActionType.selectDisposition) {
      final disposition = action.payload['disposition'];
      final reason = action.payload['reason'];
      if (disposition is! String ||
          DispositionType.values.every(
            (item) => item.wireName != disposition,
          )) {
        throw const FormatException('A valid disposition is required');
      }
      if (disposition != DispositionType.accept.wireName &&
          (reason is! String || reason.trim().isEmpty)) {
        throw const FormatException('Exception dispositions require a reason');
      }
    }
  }
}
