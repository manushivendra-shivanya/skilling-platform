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

/// Proves the Dispatch department content is valid and runs correctly
/// through the existing domain/scoring engine, following the same pattern
/// as put_away_content_test.dart -- only new content plus the two new
/// additive ActionType values (recordWeight, recordTemperatureReading),
/// zero other engine changes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Dispatch mission content validates against the content schema',
    () async {
      final mission = _loadDispatchMission();
      expect(mission.id, 'dispatch-orders-01');
      expect(mission.stages, hasLength(4));
      expect(mission.tasks, hasLength(10));
      expect(mission.scenarios, hasLength(6));
    },
  );

  test(
    'a diligent Dispatch run scores a passing result with zero engine changes',
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
              item.missionId == 'dispatch-orders-01' &&
              item.missionVersion == '1.0.0',
        ),
        isTrue,
      );
    },
  );

  test(
    'loading a wrong-route crate instead of holding it is a critical error',
    () async {
      final run = await _successfulRun();
      final wrongRouteCrate = run.scenario.resources.firstWhere(
        (item) => item.issues.any((issue) => issue.issueType == 'wrong_route'),
      );
      final unsafeAction = LearnerAction(
        id: 'unsafe-wrong-route-load',
        attemptId: run.attempt.id,
        missionId: run.mission.id,
        stageId: 'gate-and-exceptions',
        taskId: 'handle-dispatch-exceptions',
        actionType: ActionType.selectDisposition,
        targetId: wrongRouteCrate.id,
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
        contains('loaded-wrong-route-crate'),
      );
      expect(result.status, MissionStatus.criticalFailure);
    },
  );

  test('proceeding despite a vehicle temperature pre-check failure is a '
      'critical error', () async {
    final run = await _successfulRun();
    final vehicle = run.scenario.resource('dispatch-vehicle');
    if (!vehicle.issues.any(
      (issue) => issue.issueType == 'vehicle_temp_failure',
    )) {
      return;
    }
    final unsafeAction = LearnerAction(
      id: 'unsafe-temp-proceed',
      attemptId: run.attempt.id,
      missionId: run.mission.id,
      stageId: 'vehicle-verification',
      taskId: 'verify-vehicle-temperature',
      actionType: ActionType.recordTemperatureReading,
      targetId: 'dispatch-vehicle',
      payload: const {'heldForRecheck': false, 'proceededWithoutHold': true},
      sequenceNumber: run.attempt.actionCount + 1,
      simulationTimeSeconds: 300,
      createdAt: DateTime.utc(2026, 8, 5, 9, 30),
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
    expect(
      errors.map((item) => item.ruleId),
      contains('skipped-vehicle-temp-precheck'),
    );
  });

  test(
    'the same competencies.json load path serves the new competencies',
    () async {
      final repository = AssetSimulationContentRepository();
      final competencies = await repository.getCompetencies([
        'route-verification',
        'scan-discipline',
        'loading-sequence-control',
        'exception-escalation',
        'route-settlement-control',
      ]);
      expect(competencies, hasLength(5));
    },
  );
}

MissionDefinition _loadDispatchMission() {
  final file = File(
    'assets/workplace_simulation/logistics/dispatch_mission.json',
  );
  final decoded = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  return MissionDefinition.fromJson(decoded);
}

Future<_Run> _successfulRun() async {
  final mission = _loadDispatchMission();
  final repository = AssetSimulationContentRepository();
  final remediation = await repository.getRemediation();
  final scenario = const ScenarioGenerator().generate(mission, 82441);
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

  final crates =
      scenario.resources
          .where((item) => item.resourceType == ResourceType.carton)
          .toList()
        ..sort((left, right) => left.id.compareTo(right.id));
  final vehicle = scenario.resource('dispatch-vehicle');
  final vehicleTempFailure = vehicle.issues.any(
    (issue) => issue.issueType == 'vehicle_temp_failure',
  );
  final report = scenario.resource('dispatch-report');
  final routeCloseException = report.issues.any(
    (issue) => issue.issueType == 'route_close_exception',
  );

  for (final crate in crates) {
    final issue = crate.issues.isEmpty ? null : crate.issues.single.issueType;
    final payload = switch (issue) {
      'wrong_route' => const {'flagged': true},
      'failed_scan' => const {'rescanned': true},
      _ => const {'scanStatus': 'matched'},
    };
    add(
      'pick-order-items',
      ActionType.scanBarcode,
      targetId: crate.id,
      payload: payload,
    );
  }
  for (final crate in crates) {
    add(
      'consolidate-order-items',
      ActionType.moveItem,
      targetId: crate.id,
      payload: const {'consolidated': true},
    );
  }
  for (final crate in crates) {
    add(
      'stage-route-crates',
      ActionType.confirmAction,
      targetId: crate.id,
      payload: const {'staged': true},
    );
  }
  add(
    'verify-vehicle-temperature',
    ActionType.recordTemperatureReading,
    targetId: 'dispatch-vehicle',
    payload: {
      'heldForRecheck': vehicleTempFailure,
      'proceededWithoutHold': false,
    },
  );
  for (final crate in crates) {
    add(
      'confirm-load-sequence',
      ActionType.moveItem,
      targetId: crate.id,
      payload: const {'loadedInSequence': true},
    );
  }
  add(
    'final-gate-scan',
    ActionType.scanBarcode,
    targetId: 'dispatch-manifest',
    payload: const {'gateScanStatus': 'matched'},
  );
  for (final crate in crates) {
    final issue = crate.issues.isEmpty ? null : crate.issues.single.issueType;
    // A rescanned crate (handled correctly back at picking) is fine to
    // accept at the gate -- only a wrong-route or shortage-dispute crate
    // still needs to be held here.
    final disposition = (issue == 'wrong_route' || issue == 'partial_hold')
        ? 'hold_for_verification'
        : 'accept';
    add(
      'handle-dispatch-exceptions',
      ActionType.selectDisposition,
      targetId: crate.id,
      payload: {
        'disposition': disposition,
        if (disposition != 'accept') 'reason': 'Crate exception flagged',
      },
    );
  }
  add(
    'complete-dispatch-report',
    ActionType.completeForm,
    targetId: 'dispatch-report',
    payload: {
      'allCratesLoaded': true,
      'exceptionsRecorded': true,
      if (routeCloseException) 'mismatchResolved': true,
    },
  );
  add(
    'make-dispatch-decision',
    ActionType.makeDecision,
    targetId: 'dispatch-report',
    payload: const {'decision': 'dispatch_complete'},
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
  id: 'dispatch-attempt-1',
  candidateId: 'candidate-1',
  missionId: mission.id,
  missionVersion: mission.version,
  attemptNumber: 1,
  scenarioSeed: 82441,
  state: MissionState.inProgress,
  createdAt: DateTime.utc(2026, 8, 5, 9),
  shiftStartedAt: DateTime.utc(2026, 8, 5, 9),
  elapsedSimulationSeconds: 0,
  currentStageId: 'picking',
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
