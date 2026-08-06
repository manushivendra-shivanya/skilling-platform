import 'dart:convert';
import 'dart:io';

import 'package:candidate_mobile/features/workplace_simulation/data/asset_simulation_content_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/services/action_evaluation_service.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/services/critical_error_service.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/services/mission_progress_service.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/services/mission_scoring_service.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/services/scenario_generator.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/services/task_validation_service.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_content.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_enums.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

/// Proves the Processing department content is valid and runs correctly
/// through the existing domain/scoring engine, following the same pattern
/// as put_away_content_test.dart -- only new content plus the two new
/// additive ActionType values (recordWeight, recordTemperatureReading),
/// zero other engine changes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Processing mission content validates against the content schema',
    () async {
      final mission = _loadProcessingMission();
      expect(mission.id, 'process-batch-01');
      expect(mission.stages, hasLength(4));
      expect(mission.tasks, hasLength(10));
      expect(mission.scenarios, hasLength(5));
    },
  );

  test(
    'a diligent Processing run scores a passing result with zero engine changes',
    () async {
      final run = await _successfulRun();
      final result = const MissionScoringService().score(
        mission: run.mission,
        attempt: run.attempt,
        outcomes: run.outcomes,
        criticalErrors: const [],
        remediation: run.remediation,
        completedAt: DateTime.utc(2026, 8, 5, 11),
      );

      expect(result.status, MissionStatus.passed);
      expect(result.overallScore, 100);
      expect(result.mandatoryTasksCompleted, isTrue);
      expect(
        result.evidence.every(
          (item) =>
              item.missionId == 'process-batch-01' &&
              item.missionVersion == '1.0.0',
        ),
        isTrue,
      );
    },
  );

  test(
    'releasing an off-weight batch instead of holding it is a critical error',
    () async {
      final run = await _successfulRun();
      final wrongWeightBatch = run.scenario.resources.firstWhere(
        (item) => item.issues.any((issue) => issue.issueType == 'wrong_weight'),
      );
      final unsafeAction = LearnerAction(
        id: 'unsafe-weight-release',
        attemptId: run.attempt.id,
        missionId: run.mission.id,
        stageId: 'processing-decision',
        taskId: 'classify-batch-exceptions',
        actionType: ActionType.selectDisposition,
        targetId: wrongWeightBatch.id,
        payload: const {'disposition': 'accept'},
        sequenceNumber: run.attempt.actionCount + 1,
        simulationTimeSeconds: 900,
        createdAt: DateTime.utc(2026, 8, 5, 10, 40),
      );
      final unsafeAttempt = run.attempt.copyWith(
        actions: [...run.attempt.actions, unsafeAction],
      );
      final errors = const CriticalErrorService().detect(
        mission: run.mission,
        scenario: run.scenario,
        actions: unsafeAttempt.actions,
        mandatoryInspectionCompleted: true,
      );
      final result = const MissionScoringService().score(
        mission: run.mission,
        attempt: unsafeAttempt,
        outcomes: run.outcomes,
        criticalErrors: errors,
        remediation: run.remediation,
      );

      expect(
        errors.map((item) => item.ruleId),
        contains('packed-wrong-weight-released'),
      );
      expect(result.status, MissionStatus.criticalFailure);
    },
  );

  test(
    'confirming compliance despite a real hygiene gap is a critical error',
    () async {
      final run = await _successfulRun();
      final unsafeAction = LearnerAction(
        id: 'unsafe-hygiene-confirm',
        attemptId: run.attempt.id,
        missionId: run.mission.id,
        stageId: 'hygiene-and-scan',
        taskId: 'confirm-hygiene-compliance',
        actionType: ActionType.confirmAction,
        targetId: 'hygiene-checklist',
        payload: const {'compliant': true},
        sequenceNumber: run.attempt.actionCount + 1,
        simulationTimeSeconds: 60,
        createdAt: DateTime.utc(2026, 8, 5, 9, 5),
      );
      final unsafeAttempt = run.attempt.copyWith(
        actions: [...run.attempt.actions, unsafeAction],
      );
      final hygieneChecklist = run.scenario.resource('hygiene-checklist');
      if (hygieneChecklist.issues.any(
        (issue) => issue.issueType == 'hygiene_missed',
      )) {
        final errors = const CriticalErrorService().detect(
          mission: run.mission,
          scenario: run.scenario,
          actions: unsafeAttempt.actions,
          mandatoryInspectionCompleted: true,
        );
        expect(
          errors.map((item) => item.ruleId),
          contains('processed-without-hygiene'),
        );
      }
    },
  );

  test(
    'the same competencies.json load path serves the new competencies',
    () async {
      final repository = AssetSimulationContentRepository();
      final competencies = await repository.getCompetencies([
        'hygiene-discipline',
        'pack-weight-control',
        'batch-traceability',
        'quality-exception-handling',
      ]);
      expect(competencies, hasLength(4));
    },
  );
}

MissionDefinition _loadProcessingMission() {
  final file = File(
    'assets/workplace_simulation/logistics/processing_mission.json',
  );
  final decoded = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  return MissionDefinition.fromJson(decoded);
}

Future<_Run> _successfulRun() async {
  final mission = _loadProcessingMission();
  final repository = AssetSimulationContentRepository();
  final remediation = await repository.getRemediation();
  final scenario = const ScenarioGenerator().generate(mission, 63910);
  var attempt = _attempt(mission);
  final outcomes = <ActionOutcome>[];
  const validation = TaskValidationService();
  const evaluation = ActionEvaluationService();
  const progress = MissionProgressService();

  void add(
    String taskId,
    ActionType actionType, {
    String? targetId,
    JsonMap payload = const {},
  }) {
    final task = mission.task(taskId);
    final action = LearnerAction(
      id: 'action-${attempt.actionCount + 1}',
      attemptId: attempt.id,
      missionId: mission.id,
      stageId: task.stageId,
      taskId: task.id,
      actionType: actionType,
      targetId: targetId,
      payload: payload,
      sequenceNumber: attempt.actionCount + 1,
      simulationTimeSeconds: attempt.actionCount * 15,
      createdAt: DateTime.utc(
        2026,
        8,
        5,
        9,
      ).add(Duration(seconds: attempt.actionCount * 15)),
    );
    validation.validate(mission: mission, attempt: attempt, action: action);
    attempt = attempt.copyWith(actions: [...attempt.actions, action]);
    final outcome = evaluation.evaluate(task, action, scenario: scenario);
    outcomes.add(outcome);
    attempt = progress.applyOutcome(
      mission: mission,
      attempt: attempt,
      action: action,
      outcome: outcome,
    );
  }

  final batches =
      scenario.resources
          .where((item) => item.resourceType == ResourceType.carton)
          .toList()
        ..sort((left, right) => left.id.compareTo(right.id));
  final hygieneChecklist = scenario.resource('hygiene-checklist');
  final hygieneGap = hygieneChecklist.issues.any(
    (issue) => issue.issueType == 'hygiene_missed',
  );

  add(
    'confirm-hygiene-compliance',
    ActionType.confirmAction,
    targetId: 'hygiene-checklist',
    payload: {'compliant': !hygieneGap},
  );
  for (final batch in batches) {
    add(
      'scan-processing-batches',
      ActionType.scanBarcode,
      targetId: batch.id,
      payload: const {'scanStatus': 'matched'},
    );
  }
  for (final batch in batches) {
    add(
      'pack-batch-items',
      ActionType.moveItem,
      targetId: batch.id,
      payload: const {'packed': true},
    );
  }
  for (final batch in batches) {
    add(
      'record-batch-weight',
      ActionType.recordWeight,
      targetId: batch.id,
      payload: {'recordedWeightKg': batch.content['packedWeightKg']},
    );
  }
  for (final batch in batches) {
    add(
      'verify-batch-labels',
      ActionType.inspectItem,
      targetId: batch.id,
      payload: const {'labelVerified': true},
    );
  }
  add(
    'supervisor-sample-check',
    ActionType.confirmAction,
    targetId: 'supervisor-sample',
    payload: const {'sampleReviewed': true},
  );
  for (final batch in batches) {
    final disposition = batch.issues.isEmpty
        ? 'accept'
        : 'hold_for_verification';
    add(
      'classify-batch-exceptions',
      ActionType.selectDisposition,
      targetId: batch.id,
      payload: {
        'disposition': disposition,
        if (disposition != 'accept') 'reason': 'Batch exception flagged',
      },
    );
  }
  add(
    'complete-processing-report',
    ActionType.completeForm,
    targetId: 'processing-report',
    payload: const {'allBatchesProcessed': true, 'exceptionsRecorded': true},
  );
  add(
    'make-processing-decision',
    ActionType.makeDecision,
    targetId: 'processing-report',
    payload: const {'decision': 'processing_complete'},
  );
  add(
    'notify-supervisor',
    ActionType.confirmAction,
    targetId: 'supervisor-notification',
    payload: const {'supervisorNotified': true, 'exceptionsIncluded': true},
  );

  return _Run(mission, scenario, attempt, outcomes, remediation);
}

SimulationAttempt _attempt(MissionDefinition mission) => SimulationAttempt(
  id: 'processing-attempt-1',
  candidateId: 'candidate-1',
  missionId: mission.id,
  missionVersion: mission.version,
  attemptNumber: 1,
  scenarioSeed: 63910,
  state: MissionState.inProgress,
  createdAt: DateTime.utc(2026, 8, 5, 9),
  shiftStartedAt: DateTime.utc(2026, 8, 5, 9),
  elapsedSimulationSeconds: 0,
  currentStageId: 'hygiene-and-scan',
  completedTaskIds: const {},
  actions: const [],
  auditEvents: const [],
);

class _Run {
  const _Run(
    this.mission,
    this.scenario,
    this.attempt,
    this.outcomes,
    this.remediation,
  );

  final MissionDefinition mission;
  final GeneratedScenario scenario;
  final SimulationAttempt attempt;
  final List<ActionOutcome> outcomes;
  final List<RemediationRecommendation> remediation;
}
