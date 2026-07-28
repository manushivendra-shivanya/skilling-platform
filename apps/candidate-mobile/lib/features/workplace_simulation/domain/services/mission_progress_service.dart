import '../simulation_content.dart';
import '../simulation_enums.dart';
import '../simulation_runtime.dart';

class MissionProgressService {
  const MissionProgressService();

  SimulationAttempt applyOutcome({
    required MissionDefinition mission,
    required SimulationAttempt attempt,
    required LearnerAction action,
    required ActionOutcome outcome,
  }) {
    if (outcome.outcomeType == OutcomeType.notApplicable) return attempt;
    final task = mission.task(action.taskId);
    final successful =
        outcome.outcomeType == OutcomeType.correct ||
        outcome.outcomeType == OutcomeType.partiallyCorrect ||
        task.completeOnValidAction;
    if (!successful) return attempt;

    final completed = {...attempt.completedTaskIds};
    if (!task.repeatable) {
      completed.add(task.id);
    } else {
      final targetCount = {
        for (final item in attempt.actions)
          if (item.taskId == task.id && item.targetId != null) item.targetId,
      }.length;
      if (targetCount >= task.targetResourceIds.length) completed.add(task.id);
    }

    final nextStage = mission.stages
        .where(
          (stage) => stage.taskIds.any((taskId) => !completed.contains(taskId)),
        )
        .cast<MissionStage?>()
        .firstWhere((item) => item != null, orElse: () => null);
    return attempt.copyWith(
      completedTaskIds: completed,
      currentStageId: nextStage?.id ?? attempt.currentStageId,
    );
  }

  double progress(MissionDefinition mission, SimulationAttempt attempt) {
    final mandatory = mission.tasks.where((item) => item.mandatory).toList();
    if (mandatory.isEmpty) return 1;
    final completed = mandatory
        .where((item) => attempt.completedTaskIds.contains(item.id))
        .length;
    return completed / mandatory.length;
  }

  bool allMandatoryTasksCompleted(
    MissionDefinition mission,
    SimulationAttempt attempt,
  ) => mission.tasks
      .where((item) => item.mandatory)
      .every((item) => attempt.completedTaskIds.contains(item.id));
}
