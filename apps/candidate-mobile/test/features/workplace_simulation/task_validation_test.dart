import 'package:candidate_mobile/features/workplace_simulation/data/asset_simulation_content_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/services/action_evaluation_service.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/services/scenario_generator.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/services/task_validation_service.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_enums.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'rejects unavailable actions, invalid targets and missing reasons',
    () async {
      final repository = AssetSimulationContentRepository();
      final mission = await repository.getMission(
        'receive-incoming-shipment-01',
      );
      const validator = TaskValidationService();
      final attempt = _attempt(mission.id, mission.version);

      expect(
        () => validator.validate(
          mission: mission,
          attempt: attempt,
          action: _action(
            attempt,
            taskId: 'open-purchase-order',
            stageId: 'document-verification',
            actionType: ActionType.makeDecision,
            targetId: 'purchase-order-po-2026-001',
          ),
        ),
        throwsStateError,
      );
      expect(
        () => validator.validate(
          mission: mission,
          attempt: attempt,
          action: _action(
            attempt,
            taskId: 'open-purchase-order',
            stageId: 'document-verification',
            actionType: ActionType.openResource,
            targetId: 'carton-001',
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => validator.validate(
          mission: mission,
          attempt: attempt,
          action: _action(
            attempt,
            taskId: 'assign-dispositions',
            stageId: 'exception-handling',
            actionType: ActionType.selectDisposition,
            targetId: 'carton-001',
            payload: const {'disposition': 'quarantine'},
          ),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'evaluation checks seeded target condition instead of widget state',
    () async {
      final repository = AssetSimulationContentRepository();
      final mission = await repository.getMission(
        'receive-incoming-shipment-01',
      );
      final scenario = const ScenarioGenerator().generate(mission, 48127);
      final damaged = scenario.resources.firstWhere(
        (item) =>
            item.issues.any((issue) => issue.issueType == 'packaging_damage'),
      );
      final compliant = scenario.resources.firstWhere(
        (item) =>
            item.resourceType == ResourceType.carton && item.issues.isEmpty,
      );
      final attempt = _attempt(mission.id, mission.version);
      final task = mission.task('inspect-cartons');
      const evaluator = ActionEvaluationService();

      final correct = evaluator.evaluate(
        task,
        _action(
          attempt,
          taskId: task.id,
          stageId: task.stageId,
          actionType: ActionType.recordIssue,
          targetId: damaged.id,
          payload: const {'issueType': 'packaging_damage'},
        ),
        scenario: scenario,
      );
      final falseClaim = evaluator.evaluate(
        task,
        _action(
          attempt,
          taskId: task.id,
          stageId: task.stageId,
          actionType: ActionType.recordIssue,
          targetId: compliant.id,
          payload: const {'issueType': 'packaging_damage'},
        ),
        scenario: scenario,
      );

      expect(correct.outcomeType, OutcomeType.correct);
      expect(falseClaim.outcomeType, OutcomeType.incorrect);
    },
  );
}

SimulationAttempt _attempt(String missionId, String missionVersion) =>
    SimulationAttempt(
      id: 'attempt-1',
      candidateId: 'candidate-1',
      missionId: missionId,
      missionVersion: missionVersion,
      attemptNumber: 1,
      scenarioSeed: 48127,
      state: MissionState.inProgress,
      startedAt: DateTime.utc(2026, 7, 28),
      elapsedSeconds: 0,
      currentStageId: 'document-verification',
      completedTaskIds: const {},
      actions: const [],
    );

LearnerAction _action(
  SimulationAttempt attempt, {
  required String taskId,
  required String stageId,
  required ActionType actionType,
  String? targetId,
  Map<String, Object?> payload = const {},
}) => LearnerAction(
  id: 'action-${attempt.actionCount + 1}',
  attemptId: attempt.id,
  missionId: attempt.missionId,
  stageId: stageId,
  taskId: taskId,
  actionType: actionType,
  targetId: targetId,
  payload: payload,
  sequenceNumber: attempt.actionCount + 1,
  simulationTimeSeconds: 0,
  createdAt: DateTime.utc(2026, 7, 28),
);
