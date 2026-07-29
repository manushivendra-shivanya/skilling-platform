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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'complete audited mission produces weighted result and evidence',
    () async {
      final run = await _successfulRun();
      final result = const MissionScoringService().score(
        mission: run.mission,
        attempt: run.attempt,
        outcomes: run.outcomes,
        criticalErrors: const [],
        remediation: run.remediation,
        completedAt: DateTime.utc(2026, 7, 28, 11),
      );

      expect(result.status, MissionStatus.passed);
      expect(result.overallScore, 100);
      expect(result.categoryScores.values, everyElement(100));
      expect(result.mandatoryTasksCompleted, isTrue);
      expect(result.evidence, hasLength(5));
      expect(
        result.evidence.every(
          (item) =>
              item.missionVersion == '1.0.0' &&
              item.scenarioSeed == 48127 &&
              item.attemptId == run.attempt.id,
        ),
        isTrue,
      );
      expect(result.correctActions, contains('Selected partial acceptance'));
    },
  );

  test('technical failure has no score or competency penalty', () async {
    final run = await _successfulRun();
    final task = run.mission.task('open-purchase-order');
    final technicalAction = LearnerAction(
      id: 'technical',
      attemptId: run.attempt.id,
      missionId: run.mission.id,
      stageId: task.stageId,
      taskId: task.id,
      actionType: ActionType.technicalFailure,
      targetId: null,
      payload: const {'code': 'network_interrupted'},
      sequenceNumber: run.attempt.actionCount + 1,
      simulationTimeSeconds: 20,
      createdAt: DateTime.utc(2026, 7, 28, 10, 30),
      isTechnical: true,
    );
    final technicalOutcome = const ActionEvaluationService().evaluate(
      task,
      technicalAction,
      scenario: run.scenario,
    );

    final withoutFailure = const MissionScoringService().score(
      mission: run.mission,
      attempt: run.attempt,
      outcomes: run.outcomes,
      criticalErrors: const [],
      remediation: run.remediation,
    );
    final withFailure = const MissionScoringService().score(
      mission: run.mission,
      attempt: run.attempt.copyWith(
        actions: [...run.attempt.actions, technicalAction],
      ),
      outcomes: [...run.outcomes, technicalOutcome],
      criticalErrors: const [],
      remediation: run.remediation,
    );

    expect(technicalOutcome.outcomeType, OutcomeType.notApplicable);
    expect(withFailure.overallScore, withoutFailure.overallScore);
    expect(
      withFailure.competencyScores.length,
      withoutFailure.competencyScores.length,
    );
  });

  test('missing mandatory tasks produces incomplete result', () async {
    final repository = AssetSimulationContentRepository();
    final mission = await repository.getMission('receive-incoming-shipment-01');
    final remediation = await repository.getRemediation();
    final attempt = _attempt(
      mission,
    ).copyWith(completedTaskIds: {'open-purchase-order'});

    final result = const MissionScoringService().score(
      mission: mission,
      attempt: attempt,
      outcomes: const [],
      criticalErrors: const [],
      remediation: remediation,
    );

    expect(result.status, MissionStatus.incomplete);
    expect(result.mandatoryTasksCompleted, isFalse);
    expect(result.evidence, isEmpty);
  });

  test(
    'category percentages produce the declared weighted overall score',
    () async {
      final run = await _successfulRun();
      final adjusted = [
        for (final outcome in run.outcomes)
          if (outcome.taskId == 'record-document-finding')
            ActionOutcome(
              actionId: outcome.actionId,
              taskId: outcome.taskId,
              categoryId: outcome.categoryId,
              outcomeType: OutcomeType.partiallyCorrect,
              pointsAwarded: 5,
              maximumPoints: outcome.maximumPoints,
              feedbackCode: outcome.feedbackCode,
              competencyImpacts: outcome.competencyImpacts,
            )
          else
            outcome,
      ];

      final result = const MissionScoringService().score(
        mission: run.mission,
        attempt: run.attempt,
        outcomes: adjusted,
        criticalErrors: const [],
        remediation: run.remediation,
      );

      expect(result.categoryScores['document-verification'], 50);
      expect(result.overallScore, 90);
    },
  );

  test(
    'completed mid-score attempt recommends retry and missed issue remediation',
    () async {
      final run = await _successfulRun();
      final sixtyPercent = [
        for (final task in run.mission.tasks)
          ActionOutcome(
            actionId: 'partial-${task.id}',
            taskId: task.id,
            categoryId: task.scoreCategoryId,
            outcomeType: OutcomeType.partiallyCorrect,
            pointsAwarded: (task.maximumPoints * 0.6).round(),
            maximumPoints: task.maximumPoints,
            feedbackCode: 'partial-${task.id}',
            competencyImpacts: const [],
          ),
      ];
      final result = const MissionScoringService().score(
        mission: run.mission,
        attempt: run.attempt,
        outcomes: sixtyPercent,
        criticalErrors: const [],
        remediation: run.remediation,
      );

      expect(result.status, MissionStatus.retryRecommended);
      expect(result.overallScore, inInclusiveRange(50, 69));
      expect(
        result.recommendedRemediationIds,
        contains('micro-lesson-expiry-policy'),
      );
    },
  );

  test('critical error overrides an otherwise passing numeric score', () async {
    final run = await _successfulRun();
    final incorrect = run.scenario.resources.firstWhere(
      (item) => item.issues.any((issue) => issue.issueType == 'incorrect_sku'),
    );
    final unsafeAction = LearnerAction(
      id: 'unsafe-accept',
      attemptId: run.attempt.id,
      missionId: run.mission.id,
      stageId: 'exception-handling',
      taskId: 'assign-dispositions',
      actionType: ActionType.selectDisposition,
      targetId: incorrect.id,
      payload: const {'disposition': 'accept'},
      sequenceNumber: run.attempt.actionCount + 1,
      simulationTimeSeconds: 600,
      createdAt: DateTime.utc(2026, 7, 28, 10, 40),
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

    expect(errors.map((item) => item.ruleId), contains('accept-incorrect-sku'));
    expect(result.status, MissionStatus.criticalFailure);
    expect(result.overallScore, 80);
  });
}

Future<_Run> _successfulRun() async {
  final repository = AssetSimulationContentRepository();
  final mission = await repository.getMission('receive-incoming-shipment-01');
  final remediation = await repository.getRemediation();
  final scenario = const ScenarioGenerator().generate(mission, 48127);
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
      simulationTimeSeconds: attempt.actionCount * 20,
      createdAt: DateTime.utc(
        2026,
        7,
        28,
        10,
      ).add(Duration(seconds: attempt.actionCount * 20)),
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

  add(
    'open-purchase-order',
    ActionType.openResource,
    targetId: 'purchase-order-po-2026-001',
  );
  add(
    'open-delivery-note',
    ActionType.openResource,
    targetId: 'delivery-note-dn-2026-001',
  );
  add(
    'record-document-finding',
    ActionType.classifyIssue,
    targetId: 'document-line-SKU-1002',
    payload: const {'findingType': 'quantityMismatch'},
  );
  add(
    'record-document-finding',
    ActionType.classifyIssue,
    targetId: 'document-line-SKU-1094',
    payload: const {'findingType': 'unexpectedItem'},
  );
  add(
    'verify-documents',
    ActionType.completeForm,
    targetId: 'document-comparison-summary',
    payload: const {'submitted': true},
  );
  add(
    'confirm-delivery-identity',
    ActionType.confirmAction,
    targetId: 'delivery-note-dn-2026-001',
    payload: const {'conclusion': 'matchesExpectedDelivery'},
  );
  for (final carton in _cartons(scenario)) {
    add(
      'confirm-received-counts',
      ActionType.countQuantity,
      targetId: carton.id,
      payload: {
        'physicalQuantity': carton.content['quantity'],
        'countMethod': 'individual',
      },
    );
  }
  for (final carton in _cartons(scenario)) {
    final issue = carton.issues.isEmpty ? null : carton.issues.single;
    add(
      'inspect-cartons',
      issue == null ? ActionType.inspectItem : ActionType.recordIssue,
      targetId: carton.id,
      payload: issue == null
          ? const {'finding': 'compliant'}
          : {'issueType': issue.issueType},
    );
  }
  for (final carton in _cartons(scenario)) {
    final unreadable = carton.issues.any(
      (item) => item.issueType == 'unreadable_barcode',
    );
    add(
      'scan-barcodes',
      ActionType.scanBarcode,
      targetId: carton.id,
      payload: {'barcodeStatus': unreadable ? 'unreadable' : 'readable'},
    );
  }
  for (final carton in _cartons(scenario)) {
    final issue = carton.issues.isEmpty ? null : carton.issues.single.issueType;
    final disposition = switch (issue) {
      'packaging_damage' => 'quarantine',
      'unreadable_barcode' => 'hold_for_verification',
      'incorrect_sku' => 'reject_return',
      'near_expiry' => 'escalate',
      'quantity_shortage' => 'hold_for_verification',
      _ => 'accept',
    };
    add(
      'assign-dispositions',
      ActionType.selectDisposition,
      targetId: carton.id,
      payload: {
        'disposition': disposition,
        if (disposition != 'accept') 'reason': 'Recorded issue: $issue',
      },
    );
  }
  add(
    'confirm-quarantine',
    ActionType.confirmAction,
    targetId: 'quarantine-record',
    payload: const {'allExceptionsSeparated': true},
  );
  add(
    'complete-discrepancy-report',
    ActionType.completeForm,
    targetId: 'receiving-discrepancy-report',
    payload: const {
      'poNumber': 'PO-2026-001',
      'shortageRecorded': true,
      'unauthorizedSkuRecorded': true,
      'damageRecorded': true,
      'barcodeIssueRecorded': true,
      'nearExpiryRecorded': true,
    },
  );
  add(
    'make-receiving-decision',
    ActionType.makeDecision,
    targetId: 'receiving-discrepancy-report',
    payload: const {'decision': 'partially_accept'},
  );
  add(
    'notify-supervisor',
    ActionType.confirmAction,
    targetId: 'supervisor-notification',
    payload: const {'supervisorNotified': true, 'auditTrailIncluded': true},
  );
  return _Run(mission, scenario, attempt, outcomes, remediation);
}

Iterable<SimulationResource> _cartons(GeneratedScenario scenario) => scenario
    .resources
    .where((item) => item.resourceType == ResourceType.carton);

SimulationAttempt _attempt(MissionDefinition mission) => SimulationAttempt(
  id: 'attempt-1',
  candidateId: 'candidate-1',
  missionId: mission.id,
  missionVersion: mission.version,
  attemptNumber: 1,
  scenarioSeed: 48127,
  state: MissionState.inProgress,
  createdAt: DateTime.utc(2026, 7, 28, 10),
  shiftStartedAt: DateTime.utc(2026, 7, 28, 10),
  elapsedSimulationSeconds: 0,
  currentStageId: 'document-verification',
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
