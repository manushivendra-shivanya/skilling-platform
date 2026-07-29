import '../../application/workplace_interaction_contracts.dart';
import '../simulation_content.dart';
import '../simulation_runtime.dart';

class WorkstationProgressService {
  const WorkstationProgressService();

  WorkstationStatus status({
    required Workstation workstation,
    required MissionDefinition mission,
    required SimulationAttempt attempt,
  }) {
    if (!_isUnlocked(workstation, attempt)) return WorkstationStatus.locked;
    final tasks = mission.stages
        .where((stage) => stage.workstationId == workstation.id)
        .expand((stage) => stage.taskIds)
        .map(mission.task)
        .where((task) => task.mandatory)
        .toList(growable: false);
    if (tasks.isNotEmpty &&
        tasks.every((task) => attempt.completedTaskIds.contains(task.id))) {
      return WorkstationStatus.completed;
    }
    if (attempt.actions.any(
      (action) => tasks.any((task) => task.id == action.taskId),
    )) {
      return WorkstationStatus.inProgress;
    }
    return WorkstationStatus.available;
  }

  Workstation? recommended({
    required Workplace workplace,
    required MissionDefinition mission,
    required SimulationAttempt attempt,
  }) {
    final statuses = {
      for (final station in workplace.workstations)
        station: status(
          workstation: station,
          mission: mission,
          attempt: attempt,
        ),
    };
    for (final desired in const [
      WorkstationStatus.attentionRequired,
      WorkstationStatus.inProgress,
      WorkstationStatus.available,
    ]) {
      for (final stage in [
        ...mission.stages,
      ]..sort((left, right) => left.sequence.compareTo(right.sequence))) {
        Workstation? station;
        for (final item in workplace.workstations) {
          if (item.id == stage.workstationId) {
            station = item;
            break;
          }
        }
        if (station != null && statuses[station] == desired) return station;
      }
    }
    return null;
  }

  String lockedReason(Workstation workstation, MissionDefinition mission) {
    final requiredTasks = workstation.unlockRequirements
        .where((item) => item.type == 'task_completed')
        .map((item) => mission.task(item.referenceId).title)
        .toList(growable: false);
    return requiredTasks.isEmpty
        ? 'This workstation is not available yet.'
        : 'Complete ${requiredTasks.join(' and ')} first.';
  }

  bool _isUnlocked(Workstation workstation, SimulationAttempt attempt) =>
      workstation.unlockRequirements.every(
        (requirement) =>
            requirement.type == 'task_completed' &&
            attempt.completedTaskIds.contains(requirement.referenceId),
      );
}
