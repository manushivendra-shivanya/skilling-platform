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

/// Proves the Put Away department content is valid and runs correctly
/// through the existing domain/scoring engine with ZERO changes to that
/// engine -- only new content (put_away_mission.json, plus additive
/// entries in workplace.json/competencies.json/remediation.json).
///
/// This loads the mission JSON directly (MissionDefinition.fromJson) rather
/// than through AssetSimulationContentRepository.getMission(), because that
/// repository method currently hardcodes 'receive_shipment_mission.json' --
/// a real gap for actually playing a second mission through the app, but
/// orthogonal to whether the CONTENT SCHEMA and DOMAIN SERVICES generalise,
/// which is what this test demonstrates. See docs/24 and current-state.md
/// for the follow-up this implies for the runtime/controller side.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Put Away mission content validates against the content schema',
    () async {
      final mission = _loadPutAwayMission();
      expect(mission.id, 'put-away-incoming-stock-01');
      expect(mission.stages, hasLength(4));
      expect(mission.tasks, hasLength(9));
      // validateReferences() runs inside MissionDefinition.fromJson and would
      // have already thrown if any stage/task/resource/weight reference were
      // invalid; reaching this line is itself part of the proof.
    },
  );

  test(
    'a diligent Put Away run scores a passing result with zero engine changes',
    () async {
      final run = await _successfulRun();
      final result = const MissionScoringService().score(
        mission: run.mission,
        attempt: run.attempt,
        outcomes: run.outcomes,
        criticalErrors: const [],
        remediation: run.remediation,
        completedAt: DateTime.utc(2026, 7, 29, 11),
      );

      expect(result.status, MissionStatus.passed);
      expect(result.overallScore, 100);
      expect(result.mandatoryTasksCompleted, isTrue);
      expect(
        result.evidence.every(
          (item) =>
              item.missionId == 'put-away-incoming-stock-01' &&
              item.missionVersion == '1.0.0',
        ),
        isTrue,
      );
    },
  );

  test(
    'placing a hazmat item outside the hazmat locker is a critical error',
    () async {
      final run = await _successfulRun();
      final hazmatItem = run.scenario.resources.firstWhere(
        (item) => item.issues.any((issue) => issue.issueType == 'hazmat_item'),
      );
      final unsafeAction = LearnerAction(
        id: 'unsafe-hazmat-placement',
        attemptId: run.attempt.id,
        missionId: run.mission.id,
        stageId: 'plan-locations',
        taskId: 'assign-storage-zone',
        actionType: ActionType.classifyIssue,
        targetId: hazmatItem.id,
        payload: const {'selectedZone': 'standard-shelving'},
        sequenceNumber: run.attempt.actionCount + 1,
        simulationTimeSeconds: 600,
        createdAt: DateTime.utc(2026, 7, 29, 10, 40),
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
        contains('hazmat-in-standard-zone'),
      );
      expect(result.status, MissionStatus.criticalFailure);
    },
  );

  test(
    'the same competencies.json load path serves both departments',
    () async {
      final repository = AssetSimulationContentRepository();
      final receivingCompetencies = await repository.getCompetencies([
        'document-verification',
        'inventory-accuracy',
      ]);
      final putAwayCompetencies = await repository.getCompetencies([
        'storage-location-accuracy',
        'safe-material-handling',
        'putaway-decisions',
      ]);
      expect(receivingCompetencies, hasLength(2));
      expect(putAwayCompetencies, hasLength(3));
    },
  );
}

MissionDefinition _loadPutAwayMission() {
  final file = File(
    'assets/workplace_simulation/logistics/put_away_mission.json',
  );
  final decoded = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  return MissionDefinition.fromJson(decoded);
}

Future<_Run> _successfulRun() async {
  final mission = _loadPutAwayMission();
  final repository = AssetSimulationContentRepository();
  final remediation = await repository.getRemediation();
  final scenario = const ScenarioGenerator().generate(mission, 71204);
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
        7,
        29,
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

  final items =
      scenario.resources
          .where((item) => item.resourceType == ResourceType.carton)
          .toList()
        ..sort((left, right) => left.id.compareTo(right.id));

  add(
    'open-putaway-list',
    ActionType.openResource,
    targetId: 'putaway-task-list',
  );

  String zoneFor(String? issue) => switch (issue) {
    'hazmat_item' => 'hazmat-locker',
    'cold_chain_item' => 'cold-storage-unit',
    'high_value_item' => 'secure-cage',
    'zone_at_capacity' => 'overflow-storage',
    _ => 'standard-shelving',
  };

  for (final item in items) {
    final issue = item.issues.isEmpty ? null : item.issues.single.issueType;
    add(
      'assign-storage-zone',
      ActionType.classifyIssue,
      targetId: item.id,
      payload: {'selectedZone': zoneFor(issue)},
    );
    if (issue == 'zone_at_capacity') {
      add(
        'record-location-exception',
        ActionType.classifyIssue,
        targetId: item.id,
        payload: const {'exceptionType': 'zone_at_capacity'},
      );
    }
  }
  for (final item in items) {
    add(
      'transport-and-place-items',
      ActionType.moveItem,
      targetId: item.id,
      payload: const {'placed': true, 'safeHandlingConfirmed': true},
    );
  }
  for (final item in items) {
    add(
      'scan-items-to-bins',
      ActionType.scanBarcode,
      targetId: item.id,
      payload: const {'scanStatus': 'matched'},
    );
  }
  for (final item in items) {
    add(
      'confirm-quantities-placed',
      ActionType.countQuantity,
      targetId: item.id,
      payload: {'placedQuantity': item.content['quantity']},
    );
  }
  add(
    'complete-putaway-report',
    ActionType.completeForm,
    targetId: 'putaway-report',
    payload: const {'allItemsPlaced': true, 'exceptionsRecorded': true},
  );
  add(
    'make-putaway-decision',
    ActionType.makeDecision,
    targetId: 'putaway-report',
    payload: const {'decision': 'putaway_complete'},
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
  id: 'putaway-attempt-1',
  candidateId: 'candidate-1',
  missionId: mission.id,
  missionVersion: mission.version,
  attemptNumber: 1,
  scenarioSeed: 71204,
  state: MissionState.inProgress,
  createdAt: DateTime.utc(2026, 7, 29, 9),
  shiftStartedAt: DateTime.utc(2026, 7, 29, 9),
  elapsedSimulationSeconds: 0,
  currentStageId: 'review-putaway-list',
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
