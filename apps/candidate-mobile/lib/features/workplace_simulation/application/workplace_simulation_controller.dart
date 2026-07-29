import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/services/action_evaluation_service.dart';
import '../domain/services/critical_error_service.dart';
import '../domain/services/mission_progress_service.dart';
import '../domain/services/mission_scoring_service.dart';
import '../domain/services/mission_state_service.dart';
import '../domain/services/scenario_generator.dart';
import '../domain/services/task_validation_service.dart';
import '../domain/services/workstation_progress_service.dart';
import '../domain/simulation_content.dart';
import '../domain/simulation_enums.dart';
import '../domain/simulation_runtime.dart';
import '../domain/workplace_task_drafts.dart' as drafts;
import 'workplace_simulation_state.dart';
import 'workplace_interaction_contracts.dart';

final workplaceSimulationControllerProvider =
    AsyncNotifierProvider<
      WorkplaceSimulationController,
      WorkplaceSimulationState
    >(WorkplaceSimulationController.new);

enum BeginShiftResult {
  success,
  acknowledgementRequired,
  alreadyStarting,
  alreadyStarted,
  invalidState,
  contentInvalid,
  scenarioUnavailable,
  persistenceFailure,
}

class WorkplaceSimulationController
    extends AsyncNotifier<WorkplaceSimulationState> {
  static const packId = 'logistics-foundation';
  static const workplaceId = 'central-distribution-centre';
  static const missionId = 'receive-incoming-shipment-01';

  final _stateService = const MissionStateService();
  final _scenarioGenerator = const ScenarioGenerator();
  final _taskValidation = const TaskValidationService();
  final _actionEvaluation = const ActionEvaluationService();
  final _criticalErrors = const CriticalErrorService();
  final _progress = const MissionProgressService();
  final _scoring = const MissionScoringService();
  final _workstations = const WorkstationProgressService();

  String? _candidateId;
  Future<void> _auditQueue = Future.value();
  bool _isStartingShift = false;

  @override
  Future<WorkplaceSimulationState> build() async {
    final sessionResult = await ref
        .read(candidateSessionRepositoryProvider)
        .readSession();
    final session = sessionResult.when(
      success: (value) => value,
      failure: (failure) => throw failure,
    );
    if (session == null || !session.isAuthenticated) {
      throw const AuthenticationFailure(
        'Sign in again to access workplace simulations.',
      );
    }
    _candidateId = session.candidateId;
    final content = ref.read(simulationContentRepositoryProvider);
    final pack = await content.getPack(packId);
    final workplace = await content.getWorkplace(workplaceId);
    final mission = await content.getMission(missionId);
    final competencies = await content.getCompetencies(
      mission.role.requiredCompetencies,
    );
    final remediation = await content.getRemediation();
    final attempt = await ref
        .read(simulationAttemptRepositoryProvider)
        .getActiveAttempt(session.candidateId, mission.id);
    final scenario = attempt == null
        ? null
        : _scenarioGenerator.generate(mission, attempt.scenarioSeed);
    final outcomes = attempt == null || scenario == null
        ? const <ActionOutcome>[]
        : _evaluateActions(mission, scenario, attempt.actions);
    final result =
        attempt?.state == MissionState.completed ||
            attempt?.state == MissionState.failed
        ? await ref
              .read(simulationAttemptRepositoryProvider)
              .getResult(session.candidateId, attempt!.id)
        : null;
    return WorkplaceSimulationState(
      pack: pack,
      workplace: workplace,
      mission: mission,
      competencies: competencies,
      remediation: remediation,
      attempt: attempt,
      scenario: scenario,
      outcomes: outcomes,
      result: result,
    );
  }

  Future<AppFailure?> startMission({int? scenarioSeed}) {
    return _guard(() async {
      final current = _requireState();
      final candidateId = _requireCandidate();
      final existing = current.attempt;
      if (existing != null &&
          existing.state != MissionState.completed &&
          existing.state != MissionState.failed) {
        return;
      }
      final attempt = await ref
          .read(simulationAttemptRepositoryProvider)
          .createAttempt(
            candidateId: candidateId,
            missionId: current.mission.id,
            missionVersion: current.mission.version,
            scenarioSeed:
                scenarioSeed ??
                DateTime.now().microsecondsSinceEpoch.remainder(0x7fffffff),
          );
      var briefing = _stateService.transition(attempt, MissionState.briefing);
      await ref.read(simulationAttemptRepositoryProvider).saveAttempt(briefing);
      briefing = await _appendAuditEvent(
        briefing,
        AttemptAuditEventType.missionSelected,
        screenId: 'simulation-entry',
      );
      briefing = await _appendAuditEvent(
        briefing,
        AttemptAuditEventType.attemptCreated,
        screenId: 'simulation-entry',
        payload: {
          'attemptNumber': briefing.attemptNumber,
          'scenarioSeed': briefing.scenarioSeed,
        },
      );
      briefing = await _appendAuditEvent(
        briefing,
        AttemptAuditEventType.simulationEntryOpened,
        screenId: 'simulation-entry',
      );
      state = AsyncData(
        current.copyWith(
          attempt: briefing,
          scenario: _scenarioGenerator.generate(
            current.mission,
            briefing.scenarioSeed,
          ),
          outcomes: const [],
          clearResult: true,
        ),
      );
    });
  }

  Future<AppFailure?> recordSimulationEntryOpened() => _recordAuditEvent(
    AttemptAuditEventType.simulationEntryOpened,
    screenId: 'simulation-entry',
  );

  Future<AppFailure?> recordBriefingOpened() => _recordAuditEvent(
    AttemptAuditEventType.briefingOpened,
    screenId: 'supervisor-briefing',
  );

  Future<AppFailure?> recordMissionDetailsOpened({required String screenId}) =>
      _recordAuditEvent(
        AttemptAuditEventType.missionDetailsOpened,
        screenId: screenId,
      );

  Future<AppFailure?> continueMission() {
    return _guard(() async {
      final current = _requireState();
      var attempt = _requireAttempt(current);
      if (attempt.state == MissionState.completed ||
          attempt.state == MissionState.failed ||
          attempt.state == MissionState.notStarted) {
        throw StateError('This attempt cannot be continued');
      }
      attempt = await _appendAuditEvent(
        attempt,
        AttemptAuditEventType.attemptResumeRequested,
        screenId: 'simulation-entry',
      );
      if (attempt.state == MissionState.paused) {
        attempt = await _resumeTimer(attempt, screenId: 'simulation-entry');
      }
      attempt = await _appendAuditEvent(
        attempt,
        AttemptAuditEventType.attemptResumed,
        screenId: 'simulation-entry',
      );
      state = AsyncData(current.copyWith(attempt: attempt));
    });
  }

  Future<AppFailure?> setBriefingAcknowledged(bool acknowledged) {
    return _guard(() async {
      final current = _requireState();
      final attempt = _requireAttempt(current);
      if (attempt.state != MissionState.briefing) {
        throw StateError('The briefing can be acknowledged only before work');
      }
      if (attempt.briefingAcknowledged == acknowledged) return;
      final updated = await _appendAuditEvent(
        attempt,
        acknowledged
            ? AttemptAuditEventType.briefingAcknowledged
            : AttemptAuditEventType.briefingAcknowledgementRemoved,
        screenId: 'supervisor-briefing',
        payload: {
          'acknowledged': acknowledged,
          'rulesVersion': current.mission.briefing.rulesVersion,
        },
      );
      final now = DateTime.now();
      final timestamped = updated.copyWith(
        briefingAcknowledgedAt: acknowledged ? now : null,
        clearBriefingAcknowledgedAt: !acknowledged,
      );
      await ref
          .read(simulationAttemptRepositoryProvider)
          .saveAttempt(timestamped);
      state = AsyncData(current.copyWith(attempt: timestamped));
    });
  }

  Future<BeginShiftResult> beginShift({DateTime? at}) async {
    if (_isStartingShift) return BeginShiftResult.alreadyStarting;
    final current = state.valueOrNull;
    final attempt = current?.attempt;
    if (current == null || attempt == null) {
      return BeginShiftResult.contentInvalid;
    }
    if (current.mission.briefing.responsibilities.isEmpty ||
        current.mission.briefing.workplaceRules.isEmpty ||
        current.mission.stages.isEmpty) {
      return _rejectShiftStart(
        current,
        attempt,
        BeginShiftResult.contentInvalid,
      );
    }
    if (attempt.shiftStartedAt != null) {
      return _rejectShiftStart(
        current,
        attempt,
        BeginShiftResult.alreadyStarted,
      );
    }
    if (attempt.state != MissionState.briefing) {
      return _rejectShiftStart(current, attempt, BeginShiftResult.invalidState);
    }
    if (!attempt.briefingAcknowledged) {
      return _rejectShiftStart(
        current,
        attempt,
        BeginShiftResult.acknowledgementRequired,
      );
    }
    if (current.scenario == null) {
      return _rejectShiftStart(
        current,
        attempt,
        BeginShiftResult.scenarioUnavailable,
      );
    }

    _isStartingShift = true;
    var working = attempt;
    try {
      final persisted = await ref
          .read(simulationAttemptRepositoryProvider)
          .getActiveAttempt(working.candidateId, working.missionId);
      if (persisted == null ||
          persisted.state != MissionState.briefing ||
          persisted.shiftStartedAt != null) {
        return BeginShiftResult.invalidState;
      }
      final shiftStart = at ?? DateTime.now();
      final started = _stateService
          .transition(persisted, MissionState.inProgress, at: shiftStart)
          .copyWith(
            shiftStartedAt: shiftStart,
            timerResumedAt: shiftStart,
            clearPausedAt: true,
            elapsedSimulationSeconds: 0,
            timerStatus: SimulationTimerStatus.running,
            currentStageId: 'document-verification',
          );
      final requestedEvent = _createAuditEvent(
        persisted,
        AttemptAuditEventType.shiftStartRequested,
        screenId: 'supervisor-briefing',
        sequenceNumber: persisted.auditEventCount + 1,
        occurredAt: shiftStart,
      );
      final startedEvent = _createAuditEvent(
        started,
        AttemptAuditEventType.shiftStarted,
        screenId: 'supervisor-briefing',
        sequenceNumber: persisted.auditEventCount + 2,
        occurredAt: shiftStart,
      );
      working = await ref
          .read(simulationAttemptRepositoryProvider)
          .startShift(
            startedAttempt: started,
            requestedEvent: requestedEvent,
            startedEvent: startedEvent,
          );
      state = AsyncData(current.copyWith(attempt: working));
      return BeginShiftResult.success;
    } catch (_) {
      try {
        working = await _appendAuditEvent(
          working,
          AttemptAuditEventType.shiftStartFailed,
          screenId: 'supervisor-briefing',
        );
        state = AsyncData(current.copyWith(attempt: working));
      } catch (_) {
        // The original persisted attempt remains authoritative.
      }
      return BeginShiftResult.persistenceFailure;
    } finally {
      _isStartingShift = false;
    }
  }

  Future<AppFailure?> pauseAttempt({DateTime? at}) {
    return _guard(() async {
      final current = _requireState();
      var attempt = _requireAttempt(current);
      if (attempt.state != MissionState.inProgress ||
          attempt.timerStatus != SimulationTimerStatus.running) {
        throw StateError('Only a running attempt can be paused');
      }
      attempt = _withAudit(
        attempt,
        AttemptAuditEventType.pauseRequested,
        screenId: 'workplace-overview',
      );
      final pausedAt = at ?? DateTime.now();
      final resumedAt = attempt.timerResumedAt ?? attempt.shiftStartedAt!;
      attempt = _stateService
          .transition(attempt, MissionState.paused, at: pausedAt)
          .copyWith(
            pausedAt: pausedAt,
            clearTimerResumedAt: true,
            elapsedSimulationSeconds:
                attempt.elapsedSimulationSeconds +
                pausedAt.difference(resumedAt).inSeconds,
            timerStatus: SimulationTimerStatus.paused,
          );
      attempt = _withAudit(
        attempt,
        AttemptAuditEventType.attemptPaused,
        screenId: 'workplace',
      );
      attempt = _withAudit(
        attempt,
        AttemptAuditEventType.shiftPaused,
        screenId: 'workplace-overview',
      );
      await _commit(current, attempt);
    });
  }

  Future<AppFailure?> resumeAttempt({DateTime? at}) {
    return _guard(() async {
      final current = _requireState();
      var attempt = _withAudit(
        _requireAttempt(current),
        AttemptAuditEventType.resumeRequested,
        screenId: 'workplace-overview',
      );
      final resumedAt = at ?? DateTime.now();
      attempt = _stateService
          .transition(attempt, MissionState.inProgress, at: resumedAt)
          .copyWith(
            clearPausedAt: true,
            timerResumedAt: resumedAt,
            timerStatus: SimulationTimerStatus.running,
          );
      attempt = _withAudit(
        attempt,
        AttemptAuditEventType.attemptResumedFromPause,
        screenId: 'workplace',
      );
      attempt = _withAudit(
        attempt,
        AttemptAuditEventType.shiftResumed,
        screenId: 'workplace-overview',
      );
      await _commit(current, attempt);
    });
  }

  @Deprecated('Use pauseAttempt')
  Future<AppFailure?> pause() => pauseAttempt();

  @Deprecated('Use resumeAttempt')
  Future<AppFailure?> resume() => resumeAttempt();

  Future<AppFailure?> recordAction({
    required String stageId,
    required String taskId,
    required ActionType actionType,
    String? targetId,
    JsonMap payload = const {},
    bool isTechnical = false,
    int? simulationTimeSeconds,
  }) {
    return _guard(() async {
      final current = _requireState();
      final attempt = _requireAttempt(current);
      final scenario = current.scenario;
      if (scenario == null) throw StateError('Scenario is not generated');
      final now = DateTime.now();
      final action = LearnerAction(
        id: '${attempt.id}-${attempt.actionCount + 1}',
        attemptId: attempt.id,
        missionId: attempt.missionId,
        stageId: stageId,
        taskId: taskId,
        actionType: actionType,
        targetId: targetId,
        payload: payload,
        sequenceNumber: attempt.actionCount + 1,
        simulationTimeSeconds:
            simulationTimeSeconds ?? currentElapsedSimulationSeconds(attempt),
        createdAt: now,
        isTechnical: isTechnical,
      );
      _taskValidation.validate(
        mission: current.mission,
        attempt: attempt,
        action: action,
      );
      final appended = await ref
          .read(simulationAttemptRepositoryProvider)
          .appendAction(action);
      final outcome = _actionEvaluation.evaluate(
        current.mission.task(taskId),
        action,
        scenario: scenario,
      );
      final progressed = _progress.applyOutcome(
        mission: current.mission,
        attempt: appended,
        action: action,
        outcome: outcome,
      );
      await ref
          .read(simulationAttemptRepositoryProvider)
          .saveAttempt(progressed);
      state = AsyncData(
        current.copyWith(
          attempt: progressed,
          outcomes: [...current.outcomes, outcome],
        ),
      );
    });
  }

  WorkstationStatus workstationStatus(String workstationId) {
    final current = _requireState();
    return _workstations.status(
      workstation: current.workplace.workstations.firstWhere(
        (item) => item.id == workstationId,
      ),
      mission: current.mission,
      attempt: _requireAttempt(current),
    );
  }

  String? get recommendedWorkstationId {
    final current = state.valueOrNull;
    final attempt = current?.attempt;
    if (current == null || attempt == null) return null;
    return _workstations
        .recommended(
          workplace: current.workplace,
          mission: current.mission,
          attempt: attempt,
        )
        ?.id;
  }

  String lockedWorkstationReason(String workstationId) {
    final current = _requireState();
    final workstation = current.workplace.workstations.firstWhere(
      (item) => item.id == workstationId,
    );
    return _workstations.lockedReason(workstation, current.mission);
  }

  Future<AppFailure?> recordWorkplaceEvent(
    AttemptAuditEventType type, {
    String screenId = 'workplace-overview',
    String? targetId,
    JsonMap payload = const {},
  }) {
    return _guard(() async {
      final current = _requireState();
      final updated = await _appendAuditEvent(
        _requireAttempt(current),
        type,
        screenId: screenId,
        targetId: targetId,
        payload: payload,
      );
      state = AsyncData(current.copyWith(attempt: updated));
    });
  }

  Future<WorkplaceCommandResult> submitDocumentFindings(
    List<LegacyDocumentFinding> findings,
  ) async {
    final noDiscrepancy = findings
        .where((item) => item.type == LegacyDocumentFindingType.noDiscrepancy)
        .length;
    if (findings.isEmpty ||
        noDiscrepancy > 1 ||
        (noDiscrepancy == 1 && findings.length != 1)) {
      return WorkplaceCommandResult.validationFailure;
    }
    try {
      final current = _requireState();
      var attempt = _requireAttempt(current);
      final scenario = current.scenario;
      if (attempt.state != MissionState.inProgress || scenario == null) {
        return WorkplaceCommandResult.invalidState;
      }
      attempt = _withAudit(
        attempt,
        AttemptAuditEventType.documentFindingsSaveRequested,
        screenId: 'document-desk',
        payload: {'findingCount': findings.length},
      );
      var outcomes = [...current.outcomes];
      for (final taskId in const [
        'open-purchase-order',
        'open-delivery-note',
      ]) {
        if (attempt.actions.any((action) => action.taskId == taskId)) continue;
        final task = current.mission.task(taskId);
        final action = _newAction(
          attempt,
          stageId: 'document-verification',
          taskId: taskId,
          actionType: ActionType.openResource,
          targetId: task.targetResourceIds.single,
        );
        (attempt, outcomes) = _applyAction(
          current,
          attempt,
          outcomes,
          action,
          scenario,
        );
      }
      for (final finding in findings) {
        final target = finding.type == LegacyDocumentFindingType.noDiscrepancy
            ? 'document-comparison-summary'
            : 'document-line-${finding.sku}';
        final action = _newAction(
          attempt,
          stageId: 'document-verification',
          taskId: 'record-document-finding',
          actionType: ActionType.classifyIssue,
          targetId: target,
          payload: {
            'findingType': finding.type.name,
            if (finding.note?.trim().isNotEmpty ?? false)
              'note': finding.note!.trim(),
          },
        );
        (attempt, outcomes) = _applyAction(
          current,
          attempt,
          outcomes,
          action,
          scenario,
        );
      }
      final completion = _newAction(
        attempt,
        stageId: 'document-verification',
        taskId: 'verify-documents',
        actionType: ActionType.completeForm,
        targetId: 'document-comparison-summary',
        payload: {'submitted': true},
      );
      (attempt, outcomes) = _applyAction(
        current,
        attempt,
        outcomes,
        completion,
        scenario,
      );
      attempt = _withAudit(
        attempt,
        AttemptAuditEventType.documentFindingsSaved,
        screenId: 'document-desk',
        payload: {'findingCount': findings.length},
      );
      await ref.read(simulationAttemptRepositoryProvider).saveAttempt(attempt);
      state = AsyncData(current.copyWith(attempt: attempt, outcomes: outcomes));
      return WorkplaceCommandResult.success;
    } catch (_) {
      await recordWorkplaceEvent(
        AttemptAuditEventType.documentFindingsSaveFailed,
        screenId: 'document-desk',
      );
      return WorkplaceCommandResult.persistenceFailure;
    }
  }

  Future<WorkplaceCommandResult> submitReceivingCounts({
    required DeliveryIdentityConclusion identityConclusion,
    required List<ReceivingCount> counts,
  }) async {
    try {
      final current = _requireState();
      var attempt = _requireAttempt(current);
      final scenario = current.scenario;
      final expectedCartons = current.mission
          .task('confirm-received-counts')
          .targetResourceIds;
      if (attempt.state != MissionState.inProgress || scenario == null) {
        return WorkplaceCommandResult.invalidState;
      }
      if (counts.length != expectedCartons.length ||
          counts.map((item) => item.cartonId).toSet().length !=
              expectedCartons.length ||
          !counts.every((item) => expectedCartons.contains(item.cartonId))) {
        return WorkplaceCommandResult.validationFailure;
      }
      for (final count in counts) {
        if (count.physicalQuantity < 0 || count.physicalQuantity > 500) {
          return WorkplaceCommandResult.validationFailure;
        }
        final expected = scenario.resource(count.cartonId).content['quantity'];
        if (count.physicalQuantity != expected &&
            !count.unusualCountConfirmed) {
          return WorkplaceCommandResult.validationFailure;
        }
      }
      attempt = _withAudit(
        attempt,
        AttemptAuditEventType.receivingCountSubmissionRequested,
        screenId: 'receiving-dock',
        payload: {'cartonCount': counts.length},
      );
      var outcomes = [...current.outcomes];
      final identity = _newAction(
        attempt,
        stageId: 'receiving-count',
        taskId: 'confirm-delivery-identity',
        actionType: ActionType.confirmAction,
        targetId: 'delivery-note-dn-2026-001',
        payload: {'conclusion': identityConclusion.name},
      );
      (attempt, outcomes) = _applyAction(
        current,
        attempt,
        outcomes,
        identity,
        scenario,
      );
      for (final count in counts) {
        final action = _newAction(
          attempt,
          stageId: 'receiving-count',
          taskId: 'confirm-received-counts',
          actionType: ActionType.countQuantity,
          targetId: count.cartonId,
          payload: {
            'physicalQuantity': count.physicalQuantity,
            'countMethod': count.method.name,
            'unusualCountConfirmed': count.unusualCountConfirmed,
          },
        );
        (attempt, outcomes) = _applyAction(
          current,
          attempt,
          outcomes,
          action,
          scenario,
        );
      }
      attempt = _withAudit(
        attempt,
        AttemptAuditEventType.receivingCountSaved,
        screenId: 'receiving-dock',
        payload: {'cartonCount': counts.length},
      );
      await ref.read(simulationAttemptRepositoryProvider).saveAttempt(attempt);
      state = AsyncData(current.copyWith(attempt: attempt, outcomes: outcomes));
      return WorkplaceCommandResult.success;
    } catch (_) {
      await recordWorkplaceEvent(
        AttemptAuditEventType.receivingCountSaveFailed,
        screenId: 'receiving-dock',
      );
      return WorkplaceCommandResult.persistenceFailure;
    }
  }

  WorkplaceOverviewViewModel get workplaceOverview {
    final current = _requireState();
    final attempt = _requireAttempt(current);
    final recommended = _workstations.recommended(
      workplace: current.workplace,
      mission: current.mission,
      attempt: attempt,
    );
    final completedStages = current.mission.stages
        .where(
          (stage) => stage.taskIds
              .map(current.mission.task)
              .where((task) => task.mandatory)
              .every((task) => attempt.completedTaskIds.contains(task.id)),
        )
        .length;
    return WorkplaceOverviewViewModel(
      attemptId: attempt.id,
      missionId: current.mission.id,
      missionTitle: current.mission.title,
      workplaceName: current.workplace.name,
      departmentName: current.workplace.departments
          .firstWhere((item) => item.id == current.mission.departmentId)
          .name,
      elapsedSimulationDuration: Duration(
        seconds: currentElapsedSimulationSeconds(attempt),
      ),
      timerStatus: attempt.timerStatus,
      missionProgress: _progress.progress(current.mission, attempt),
      completedStageCount: completedStages,
      totalStageCount: current.mission.stages.length,
      recommendedWorkstationId: recommended?.id,
      workstations: [
        for (final station in current.workplace.workstations)
          if (station.departmentId == current.mission.departmentId)
            _workstationViewModel(
              current,
              attempt,
              station.id,
              station.id == recommended?.id,
            ),
      ],
      canPause:
          attempt.state == MissionState.inProgress &&
          attempt.timerStatus == SimulationTimerStatus.running,
      canResume:
          attempt.state == MissionState.paused &&
          attempt.timerStatus == SimulationTimerStatus.paused,
      canSaveAndExit:
          attempt.state == MissionState.inProgress ||
          attempt.state == MissionState.paused,
    );
  }

  drafts.DocumentReviewDraft? get documentReviewDraft =>
      state.valueOrNull?.attempt?.documentReviewDraft;

  drafts.ReceivingCountDraft? get receivingCountDraft =>
      state.valueOrNull?.attempt?.receivingCountDraft;

  Future<OpenWorkstationResult> openWorkstation(String workstationId) async {
    try {
      final current = _requireState();
      var attempt = _requireAttempt(current);
      if (attempt.state != MissionState.inProgress) {
        return OpenWorkstationResult.invalidAttemptState;
      }
      Workstation? station;
      for (final item in current.workplace.workstations) {
        if (item.id == workstationId) station = item;
      }
      if (station == null) {
        return OpenWorkstationResult.routeUnavailable;
      }
      attempt = _withAudit(
        attempt,
        AttemptAuditEventType.workstationSelected,
        screenId: 'workplace-overview',
        targetId: workstationId,
      );
      final status = _workstations.status(
        workstation: station,
        mission: current.mission,
        attempt: attempt,
      );
      if (status == WorkstationStatus.locked) {
        attempt = _withAudit(
          attempt,
          AttemptAuditEventType.workstationOpenRejected,
          screenId: 'workplace-overview',
          targetId: workstationId,
          payload: {'reason': 'workstationLocked'},
        );
        await _commit(current, attempt);
        return OpenWorkstationResult.workstationLocked;
      }
      if (_workstationRoute(current.mission.id, station.id) == null) {
        return OpenWorkstationResult.routeUnavailable;
      }
      attempt = _withAudit(
        attempt,
        AttemptAuditEventType.workstationOpened,
        screenId: 'workplace-overview',
        targetId: workstationId,
      );
      await _commit(current, attempt);
      return OpenWorkstationResult.success;
    } catch (_) {
      return OpenWorkstationResult.persistenceFailure;
    }
  }

  Future<SaveAndExitResult> saveAndExit({DateTime? at}) async {
    final current = state.valueOrNull;
    var attempt = current?.attempt;
    if (current == null ||
        attempt == null ||
        (attempt.state != MissionState.inProgress &&
            attempt.state != MissionState.paused)) {
      return SaveAndExitResult.invalidAttemptState;
    }
    try {
      final exitedAt = at ?? DateTime.now();
      attempt = _withAudit(
        attempt,
        AttemptAuditEventType.saveAndExitRequested,
        screenId: 'workplace-overview',
      );
      if (attempt.state == MissionState.inProgress) {
        final resumedAt = attempt.timerResumedAt ?? attempt.shiftStartedAt!;
        attempt = _stateService
            .transition(attempt, MissionState.paused, at: exitedAt)
            .copyWith(
              pausedAt: exitedAt,
              clearTimerResumedAt: true,
              elapsedSimulationSeconds:
                  attempt.elapsedSimulationSeconds +
                  exitedAt.difference(resumedAt).inSeconds,
              timerStatus: SimulationTimerStatus.paused,
            );
        attempt = _withAudit(
          attempt,
          AttemptAuditEventType.attemptPaused,
          screenId: 'workplace-overview',
        );
        attempt = _withAudit(
          attempt,
          AttemptAuditEventType.shiftPaused,
          screenId: 'workplace-overview',
        );
      }
      attempt = _withAudit(
        attempt,
        AttemptAuditEventType.shiftExited,
        screenId: 'workplace-overview',
      );
      await _commit(current, attempt);
      return SaveAndExitResult.success;
    } catch (_) {
      return SaveAndExitResult.persistenceFailure;
    }
  }

  Future<AddDocumentFindingResult> addDocumentFinding(
    AddDocumentFindingCommand command,
  ) async {
    final current = state.valueOrNull;
    final attempt = current?.attempt;
    if (current == null ||
        attempt == null ||
        attempt.state != MissionState.inProgress) {
      return AddDocumentFindingResult.invalidAttemptState;
    }
    final draft = attempt.documentReviewDraft ?? _newDocumentDraft(attempt);
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return AddDocumentFindingResult.alreadySubmitted;
    }
    if (command.itemReference.trim().isEmpty) {
      return AddDocumentFindingResult.validationFailed;
    }
    if (draft.findings.any(
      (item) =>
          item.itemReference == command.itemReference &&
          item.findingType == command.findingType,
    )) {
      return AddDocumentFindingResult.duplicateFinding;
    }
    try {
      final now = DateTime.now();
      final finding = drafts.DocumentFinding(
        id: '${attempt.id}-finding-${draft.findings.length + 1}',
        sourceDocument: command.sourceDocument,
        itemReference: command.itemReference.trim(),
        findingType: command.findingType,
        learnerNotes: command.learnerNotes.trim(),
        createdAt: now,
        updatedAt: now,
        revisionNumber: 1,
      );
      var updated = attempt.copyWith(
        documentReviewDraft: draft.copyWith(
          findings: [...draft.findings, finding],
          updatedAt: now,
        ),
      );
      updated = _appendDraftAction(
        updated,
        stageId: 'document-verification',
        taskId: 'record-document-finding',
        actionType: ActionType.documentFindingAdded,
        targetId: _documentTarget(finding.itemReference),
        payload: {
          'findingId': finding.id,
          'sourceDocument': finding.sourceDocument.name,
          'findingType': finding.findingType.name,
          'learnerNotes': finding.learnerNotes,
          'revisionNumber': finding.revisionNumber,
        },
      );
      await _commit(current, updated);
      return AddDocumentFindingResult.success;
    } catch (_) {
      return AddDocumentFindingResult.persistenceFailure;
    }
  }

  Future<UpdateDocumentFindingResult> updateDocumentFinding(
    UpdateDocumentFindingCommand command,
  ) async {
    final current = state.valueOrNull;
    final attempt = current?.attempt;
    if (current == null ||
        attempt == null ||
        attempt.state != MissionState.inProgress) {
      return UpdateDocumentFindingResult.invalidAttemptState;
    }
    final draft = attempt.documentReviewDraft;
    if (draft == null) return UpdateDocumentFindingResult.findingNotFound;
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return UpdateDocumentFindingResult.alreadySubmitted;
    }
    final index = draft.findings.indexWhere(
      (item) => item.id == command.findingId,
    );
    if (index < 0) return UpdateDocumentFindingResult.findingNotFound;
    if (command.itemReference.trim().isEmpty) {
      return UpdateDocumentFindingResult.validationFailed;
    }
    try {
      final now = DateTime.now();
      final previous = draft.findings[index];
      final finding = previous.copyWith(
        sourceDocument: command.sourceDocument,
        itemReference: command.itemReference.trim(),
        findingType: command.findingType,
        learnerNotes: command.learnerNotes.trim(),
        updatedAt: now,
        revisionNumber: previous.revisionNumber + 1,
      );
      final findings = [...draft.findings]..[index] = finding;
      var updated = attempt.copyWith(
        documentReviewDraft: draft.copyWith(findings: findings, updatedAt: now),
      );
      updated = _appendDraftAction(
        updated,
        stageId: 'document-verification',
        taskId: 'record-document-finding',
        actionType: ActionType.documentFindingUpdated,
        targetId: _documentTarget(finding.itemReference),
        payload: {
          'findingId': finding.id,
          'sourceDocument': finding.sourceDocument.name,
          'findingType': finding.findingType.name,
          'learnerNotes': finding.learnerNotes,
          'revisionNumber': finding.revisionNumber,
        },
      );
      await _commit(current, updated);
      return UpdateDocumentFindingResult.success;
    } catch (_) {
      return UpdateDocumentFindingResult.persistenceFailure;
    }
  }

  Future<RemoveDocumentFindingResult> removeDocumentFinding(
    RemoveDocumentFindingCommand command,
  ) async {
    final current = state.valueOrNull;
    final attempt = current?.attempt;
    if (current == null ||
        attempt == null ||
        attempt.state != MissionState.inProgress) {
      return RemoveDocumentFindingResult.invalidAttemptState;
    }
    final draft = attempt.documentReviewDraft;
    if (draft == null) return RemoveDocumentFindingResult.findingNotFound;
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return RemoveDocumentFindingResult.alreadySubmitted;
    }
    drafts.DocumentFinding? finding;
    for (final item in draft.findings) {
      if (item.id == command.findingId) finding = item;
    }
    if (finding == null) return RemoveDocumentFindingResult.findingNotFound;
    try {
      final now = DateTime.now();
      var updated = attempt.copyWith(
        documentReviewDraft: draft.copyWith(
          findings: draft.findings
              .where((item) => item.id != command.findingId)
              .toList(growable: false),
          updatedAt: now,
        ),
      );
      updated = _appendDraftAction(
        updated,
        stageId: 'document-verification',
        taskId: 'record-document-finding',
        actionType: ActionType.documentFindingRemoved,
        targetId: _documentTarget(finding.itemReference),
        payload: {
          'findingId': finding.id,
          'revisionNumber': finding.revisionNumber + 1,
        },
      );
      await _commit(current, updated);
      return RemoveDocumentFindingResult.success;
    } catch (_) {
      return RemoveDocumentFindingResult.persistenceFailure;
    }
  }

  Future<SaveDocumentReviewDraftResult> saveDocumentReviewDraft(
    SaveDocumentReviewDraftCommand command,
  ) async {
    final current = state.valueOrNull;
    final attempt = current?.attempt;
    if (current == null ||
        attempt == null ||
        attempt.state != MissionState.inProgress) {
      return SaveDocumentReviewDraftResult.invalidAttemptState;
    }
    final draft = attempt.documentReviewDraft ?? _newDocumentDraft(attempt);
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return SaveDocumentReviewDraftResult.alreadySubmitted;
    }
    try {
      final updated = _withAudit(
        attempt.copyWith(documentReviewDraft: draft),
        AttemptAuditEventType.documentReviewDraftSaved,
        screenId: 'document-desk',
        payload: {'findingCount': draft.findings.length},
      );
      await _commit(current, updated);
      return SaveDocumentReviewDraftResult.success;
    } catch (_) {
      return SaveDocumentReviewDraftResult.persistenceFailure;
    }
  }

  Future<SubmitDocumentReviewResult> submitDocumentReview(
    SubmitDocumentReviewCommand command,
  ) async {
    final current = state.valueOrNull;
    var attempt = current?.attempt;
    final scenario = current?.scenario;
    if (current == null ||
        attempt == null ||
        scenario == null ||
        attempt.state != MissionState.inProgress) {
      return SubmitDocumentReviewResult.invalidAttemptState;
    }
    var working = attempt;
    final draft = working.documentReviewDraft;
    if (draft == null || draft.findings.isEmpty) {
      return SubmitDocumentReviewResult.noFindings;
    }
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return SubmitDocumentReviewResult.alreadySubmitted;
    }
    try {
      working = _withAudit(
        working,
        AttemptAuditEventType.documentFindingsSaveRequested,
        screenId: 'document-desk',
        payload: {'findingCount': draft.findings.length},
      );
      var outcomes = [...current.outcomes];
      for (final taskId in const [
        'open-purchase-order',
        'open-delivery-note',
      ]) {
        if (working.actions.any((action) => action.taskId == taskId)) continue;
        final task = current.mission.task(taskId);
        (working, outcomes) = _applyAction(
          current,
          working,
          outcomes,
          _newAction(
            working,
            stageId: 'document-verification',
            taskId: taskId,
            actionType: ActionType.openResource,
            targetId: task.targetResourceIds.single,
          ),
          scenario,
        );
      }
      for (final finding in draft.findings) {
        (working, outcomes) = _applyAction(
          current,
          working,
          outcomes,
          _newAction(
            working,
            stageId: 'document-verification',
            taskId: 'record-document-finding',
            actionType: ActionType.classifyIssue,
            targetId: _documentTarget(finding.itemReference),
            payload: {
              'findingId': finding.id,
              'findingType': finding.findingType.name,
              'learnerNotes': finding.learnerNotes,
              'revisionNumber': finding.revisionNumber,
              'submitted': true,
            },
          ),
          scenario,
        );
      }
      (working, outcomes) = _applyAction(
        current,
        working,
        outcomes,
        _newAction(
          working,
          stageId: 'document-verification',
          taskId: 'verify-documents',
          actionType: ActionType.completeForm,
          targetId: 'document-comparison-summary',
          payload: {'submitted': true},
        ),
        scenario,
      );
      final now = DateTime.now();
      working = working.copyWith(
        documentReviewDraft: draft.copyWith(
          status: drafts.OperationalDraftStatus.submitted,
          updatedAt: now,
          submittedAt: now,
        ),
      );
      working = _withAudit(
        working,
        AttemptAuditEventType.documentFindingsSaved,
        screenId: 'document-desk',
        payload: {'findingCount': draft.findings.length},
      );
      await _commit(current, working, outcomes: outcomes);
      return SubmitDocumentReviewResult.success;
    } catch (_) {
      await _recordWorkplaceEvent(
        AttemptAuditEventType.documentFindingsSaveFailed,
        screenId: 'document-desk',
      );
      return SubmitDocumentReviewResult.persistenceFailure;
    }
  }

  Future<ConfirmShipmentIdentityResult> confirmShipmentIdentity(
    ConfirmShipmentIdentityCommand command,
  ) async {
    final current = state.valueOrNull;
    final attempt = current?.attempt;
    if (current == null ||
        attempt == null ||
        attempt.state != MissionState.inProgress) {
      return ConfirmShipmentIdentityResult.invalidAttemptState;
    }
    final draft = attempt.receivingCountDraft ?? _newReceivingDraft(attempt);
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return ConfirmShipmentIdentityResult.alreadySubmitted;
    }
    try {
      final now = DateTime.now();
      var updated = attempt.copyWith(
        receivingCountDraft: draft.copyWith(
          shipmentConfirmed: command.confirmed,
          updatedAt: now,
        ),
      );
      final revision =
          updated.actions
              .where(
                (item) =>
                    item.actionType == ActionType.shipmentIdentityConfirmed,
              )
              .length +
          1;
      updated = _appendDraftAction(
        updated,
        stageId: 'receiving-count',
        taskId: 'confirm-delivery-identity',
        actionType: ActionType.shipmentIdentityConfirmed,
        targetId: 'delivery-note-dn-2026-001',
        payload: {'confirmed': command.confirmed, 'revisionNumber': revision},
      );
      await _commit(current, updated);
      return ConfirmShipmentIdentityResult.success;
    } catch (_) {
      return ConfirmShipmentIdentityResult.persistenceFailure;
    }
  }

  Future<RecordCartonCountResult> recordCartonCount(
    RecordCartonCountCommand command,
  ) async {
    final current = state.valueOrNull;
    final attempt = current?.attempt;
    if (current == null ||
        attempt == null ||
        attempt.state != MissionState.inProgress) {
      return RecordCartonCountResult.invalidAttemptState;
    }
    if (command.enteredQuantity < 0 || command.enteredQuantity > 500) {
      return RecordCartonCountResult.invalidQuantity;
    }
    final task = current.mission.task('confirm-received-counts');
    if (!task.targetResourceIds.contains(command.cartonId)) {
      return RecordCartonCountResult.cartonNotFound;
    }
    final draft = attempt.receivingCountDraft ?? _newReceivingDraft(attempt);
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return RecordCartonCountResult.alreadySubmitted;
    }
    if (draft.countEntries.any((item) => item.cartonId == command.cartonId)) {
      return RecordCartonCountResult.duplicateEntry;
    }
    try {
      final resource = current.scenario!.resource(command.cartonId);
      final now = DateTime.now();
      final entry = drafts.ReceivingCountEntry(
        id: '${attempt.id}-count-${draft.countEntries.length + 1}',
        cartonId: command.cartonId,
        sku: resource.content['sku']! as String,
        enteredQuantity: command.enteredQuantity,
        countMethod: command.countMethod,
        learnerNotes: command.learnerNotes.trim(),
        createdAt: now,
        updatedAt: now,
        revisionNumber: 1,
      );
      var updated = attempt.copyWith(
        receivingCountDraft: draft.copyWith(
          countEntries: [...draft.countEntries, entry],
          updatedAt: now,
        ),
      );
      updated = _appendDraftAction(
        updated,
        stageId: 'receiving-count',
        taskId: 'confirm-received-counts',
        actionType: ActionType.cartonCountRecorded,
        targetId: entry.cartonId,
        payload: _countPayload(entry),
      );
      await _commit(current, updated);
      return RecordCartonCountResult.success;
    } catch (_) {
      return RecordCartonCountResult.persistenceFailure;
    }
  }

  Future<UpdateCartonCountResult> updateCartonCount(
    UpdateCartonCountCommand command,
  ) async {
    final current = state.valueOrNull;
    final attempt = current?.attempt;
    if (current == null ||
        attempt == null ||
        attempt.state != MissionState.inProgress) {
      return UpdateCartonCountResult.invalidAttemptState;
    }
    if (command.enteredQuantity < 0 || command.enteredQuantity > 500) {
      return UpdateCartonCountResult.invalidQuantity;
    }
    final draft = attempt.receivingCountDraft;
    if (draft == null) return UpdateCartonCountResult.entryNotFound;
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return UpdateCartonCountResult.alreadySubmitted;
    }
    final index = draft.countEntries.indexWhere(
      (item) => item.id == command.entryId,
    );
    if (index < 0) return UpdateCartonCountResult.entryNotFound;
    try {
      final now = DateTime.now();
      final previous = draft.countEntries[index];
      final entry = previous.copyWith(
        enteredQuantity: command.enteredQuantity,
        countMethod: command.countMethod,
        learnerNotes: command.learnerNotes.trim(),
        updatedAt: now,
        revisionNumber: previous.revisionNumber + 1,
      );
      final entries = [...draft.countEntries]..[index] = entry;
      var updated = attempt.copyWith(
        receivingCountDraft: draft.copyWith(
          countEntries: entries,
          updatedAt: now,
        ),
      );
      updated = _appendDraftAction(
        updated,
        stageId: 'receiving-count',
        taskId: 'confirm-received-counts',
        actionType: ActionType.cartonCountUpdated,
        targetId: entry.cartonId,
        payload: _countPayload(entry),
      );
      await _commit(current, updated);
      return UpdateCartonCountResult.success;
    } catch (_) {
      return UpdateCartonCountResult.persistenceFailure;
    }
  }

  Future<RemoveCartonCountResult> removeCartonCount(
    RemoveCartonCountCommand command,
  ) async {
    final current = state.valueOrNull;
    final attempt = current?.attempt;
    if (current == null ||
        attempt == null ||
        attempt.state != MissionState.inProgress) {
      return RemoveCartonCountResult.invalidAttemptState;
    }
    final draft = attempt.receivingCountDraft;
    if (draft == null) return RemoveCartonCountResult.entryNotFound;
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return RemoveCartonCountResult.alreadySubmitted;
    }
    drafts.ReceivingCountEntry? entry;
    for (final item in draft.countEntries) {
      if (item.id == command.entryId) entry = item;
    }
    if (entry == null) return RemoveCartonCountResult.entryNotFound;
    try {
      final now = DateTime.now();
      var updated = attempt.copyWith(
        receivingCountDraft: draft.copyWith(
          countEntries: draft.countEntries
              .where((item) => item.id != command.entryId)
              .toList(growable: false),
          updatedAt: now,
        ),
      );
      updated = _appendDraftAction(
        updated,
        stageId: 'receiving-count',
        taskId: 'confirm-received-counts',
        actionType: ActionType.cartonCountRemoved,
        targetId: entry.cartonId,
        payload: {
          'entryId': entry.id,
          'revisionNumber': entry.revisionNumber + 1,
        },
      );
      await _commit(current, updated);
      return RemoveCartonCountResult.success;
    } catch (_) {
      return RemoveCartonCountResult.persistenceFailure;
    }
  }

  Future<SaveReceivingCountDraftResult> saveReceivingCountDraft(
    SaveReceivingCountDraftCommand command,
  ) async {
    final current = state.valueOrNull;
    final attempt = current?.attempt;
    if (current == null ||
        attempt == null ||
        attempt.state != MissionState.inProgress) {
      return SaveReceivingCountDraftResult.invalidAttemptState;
    }
    final draft = attempt.receivingCountDraft ?? _newReceivingDraft(attempt);
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return SaveReceivingCountDraftResult.alreadySubmitted;
    }
    try {
      final updated = _withAudit(
        attempt.copyWith(receivingCountDraft: draft),
        AttemptAuditEventType.receivingCountDraftSaved,
        screenId: 'receiving-dock',
        payload: {'entryCount': draft.countEntries.length},
      );
      await _commit(current, updated);
      return SaveReceivingCountDraftResult.success;
    } catch (_) {
      return SaveReceivingCountDraftResult.persistenceFailure;
    }
  }

  Future<SubmitReceivingCountResult> submitReceivingCount(
    SubmitReceivingCountCommand command,
  ) async {
    final current = state.valueOrNull;
    var attempt = current?.attempt;
    final scenario = current?.scenario;
    if (current == null ||
        attempt == null ||
        scenario == null ||
        attempt.state != MissionState.inProgress) {
      return SubmitReceivingCountResult.invalidAttemptState;
    }
    var working = attempt;
    final draft = working.receivingCountDraft;
    if (draft == null || !draft.shipmentConfirmed) {
      return SubmitReceivingCountResult.shipmentNotConfirmed;
    }
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return SubmitReceivingCountResult.alreadySubmitted;
    }
    final targets = current.mission
        .task('confirm-received-counts')
        .targetResourceIds;
    if (draft.countEntries.length != targets.length ||
        !targets.every(
          (id) => draft.countEntries.any((entry) => entry.cartonId == id),
        )) {
      return SubmitReceivingCountResult.incompleteCounts;
    }
    try {
      working = _withAudit(
        working,
        AttemptAuditEventType.receivingCountSubmissionRequested,
        screenId: 'receiving-dock',
        payload: {'entryCount': draft.countEntries.length},
      );
      var outcomes = [...current.outcomes];
      (working, outcomes) = _applyAction(
        current,
        working,
        outcomes,
        _newAction(
          working,
          stageId: 'receiving-count',
          taskId: 'confirm-delivery-identity',
          actionType: ActionType.confirmAction,
          targetId: 'delivery-note-dn-2026-001',
          payload: {'conclusion': 'matchesExpectedDelivery'},
        ),
        scenario,
      );
      for (final entry in draft.countEntries) {
        (working, outcomes) = _applyAction(
          current,
          working,
          outcomes,
          _newAction(
            working,
            stageId: 'receiving-count',
            taskId: 'confirm-received-counts',
            actionType: ActionType.countQuantity,
            targetId: entry.cartonId,
            payload: {
              'physicalQuantity': entry.enteredQuantity,
              'countMethod': entry.countMethod.name,
              'revisionNumber': entry.revisionNumber,
              'submitted': true,
            },
          ),
          scenario,
        );
      }
      final now = DateTime.now();
      working = working.copyWith(
        receivingCountDraft: draft.copyWith(
          status: drafts.OperationalDraftStatus.submitted,
          updatedAt: now,
          submittedAt: now,
        ),
      );
      working = _withAudit(
        working,
        AttemptAuditEventType.receivingCountSaved,
        screenId: 'receiving-dock',
        payload: {'entryCount': draft.countEntries.length},
      );
      await _commit(current, working, outcomes: outcomes);
      return SubmitReceivingCountResult.success;
    } catch (_) {
      await _recordWorkplaceEvent(
        AttemptAuditEventType.receivingCountSaveFailed,
        screenId: 'receiving-dock',
      );
      return SubmitReceivingCountResult.persistenceFailure;
    }
  }

  Future<AppFailure?> submit() {
    return _guard(() async {
      final current = _requireState();
      var attempt = _requireAttempt(current);
      final scenario = current.scenario;
      if (scenario == null) throw StateError('Scenario is not generated');
      final stoppedAt = DateTime.now();
      attempt = _stopTimer(attempt, stoppedAt);
      attempt = _stateService.transition(
        attempt,
        MissionState.submitted,
        at: stoppedAt,
      );
      await ref.read(simulationAttemptRepositoryProvider).saveAttempt(attempt);
      final inspectionComplete =
          attempt.completedTaskIds.contains('inspect-cartons') &&
          attempt.completedTaskIds.contains('scan-barcodes');
      final criticalErrors = _criticalErrors.detect(
        mission: current.mission,
        scenario: scenario,
        actions: attempt.actions,
        mandatoryInspectionCompleted: inspectionComplete,
      );
      final result = _scoring.score(
        mission: current.mission,
        attempt: attempt,
        outcomes: current.outcomes,
        criticalErrors: criticalErrors,
        remediation: current.remediation,
      );
      attempt = _stateService.transition(attempt, MissionState.evaluated);
      attempt = _stateService.transition(
        attempt,
        result.status == MissionStatus.passed
            ? MissionState.completed
            : MissionState.failed,
        at: result.completedAt,
      );
      await ref
          .read(simulationAttemptRepositoryProvider)
          .saveResult(_requireCandidate(), result);
      await ref.read(simulationAttemptRepositoryProvider).saveAttempt(attempt);
      state = AsyncData(current.copyWith(attempt: attempt, result: result));
    });
  }

  Future<AppFailure?> retry({int? scenarioSeed}) {
    return _guard(() async {
      final current = _requireState();
      final candidateId = _requireCandidate();
      final previous = current.attempt;
      if (previous != null) {
        final retryRequested = await _appendAuditEvent(
          previous,
          AttemptAuditEventType.retryRequested,
          screenId: 'simulation-entry',
        );
        state = AsyncData(current.copyWith(attempt: retryRequested));
      }
      await ref
          .read(simulationAttemptRepositoryProvider)
          .clearActiveAttempt(candidateId, current.mission.id);
      state = AsyncData(
        WorkplaceSimulationState(
          pack: current.pack,
          workplace: current.workplace,
          mission: current.mission,
          competencies: current.competencies,
          remediation: current.remediation,
        ),
      );
      final failure = await startMission(scenarioSeed: scenarioSeed);
      if (failure != null) throw failure;
      final retryState = _requireState();
      final retryAttempt = _requireAttempt(retryState);
      final updated = await _appendAuditEvent(
        retryAttempt,
        AttemptAuditEventType.retryAttemptCreated,
        screenId: 'simulation-entry',
      );
      state = AsyncData(retryState.copyWith(attempt: updated));
    });
  }

  double get progress {
    final current = state.valueOrNull;
    final attempt = current?.attempt;
    if (current == null || attempt == null) return 0;
    return _progress.progress(current.mission, attempt);
  }

  int currentElapsedSimulationSeconds(
    SimulationAttempt attempt, {
    DateTime? at,
  }) {
    if (attempt.timerStatus != SimulationTimerStatus.running) {
      return attempt.elapsedSimulationSeconds;
    }
    final resumedAt = attempt.timerResumedAt ?? attempt.shiftStartedAt;
    if (resumedAt == null) return attempt.elapsedSimulationSeconds;
    final additional = (at ?? DateTime.now()).difference(resumedAt).inSeconds;
    return attempt.elapsedSimulationSeconds + (additional < 0 ? 0 : additional);
  }

  Future<AppFailure?> _recordAuditEvent(
    AttemptAuditEventType type, {
    required String screenId,
    JsonMap payload = const {},
  }) {
    return _guard(() async {
      final current = _requireState();
      final updated = await _appendAuditEvent(
        _requireAttempt(current),
        type,
        screenId: screenId,
        payload: payload,
      );
      state = AsyncData(current.copyWith(attempt: updated));
    });
  }

  Future<SimulationAttempt> _appendAuditEvent(
    SimulationAttempt attempt,
    AttemptAuditEventType type, {
    required String screenId,
    String? targetId,
    JsonMap payload = const {},
  }) {
    final result = Completer<SimulationAttempt>();
    _auditQueue = _auditQueue.then((_) async {
      try {
        final repository = ref.read(simulationAttemptRepositoryProvider);
        final active =
            await repository.getActiveAttempt(
              attempt.candidateId,
              attempt.missionId,
            ) ??
            attempt;
        final eventNumber = active.auditEventCount + 1;
        final updated = await repository.appendAuditEvent(
          _createAuditEvent(
            active,
            type,
            screenId: screenId,
            targetId: targetId,
            sequenceNumber: eventNumber,
            payload: payload,
          ),
        );
        result.complete(updated);
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  AttemptAuditEvent _createAuditEvent(
    SimulationAttempt attempt,
    AttemptAuditEventType type, {
    required String screenId,
    required int sequenceNumber,
    String? targetId,
    JsonMap payload = const {},
    DateTime? occurredAt,
  }) => AttemptAuditEvent(
    id: '${attempt.id}-event-$sequenceNumber',
    attemptId: attempt.id,
    missionId: attempt.missionId,
    missionVersion: attempt.missionVersion,
    eventType: type,
    screenId: screenId,
    targetId: targetId,
    sequenceNumber: sequenceNumber,
    simulationElapsedSeconds: currentElapsedSimulationSeconds(
      attempt,
      at: occurredAt,
    ),
    occurredAt: occurredAt ?? DateTime.now(),
    payload: payload,
  );

  Future<BeginShiftResult> _rejectShiftStart(
    WorkplaceSimulationState current,
    SimulationAttempt attempt,
    BeginShiftResult result,
  ) async {
    try {
      final updated = await _appendAuditEvent(
        attempt,
        AttemptAuditEventType.shiftStartRejected,
        screenId: 'supervisor-briefing',
        payload: {'reason': result.name},
      );
      state = AsyncData(current.copyWith(attempt: updated));
    } catch (_) {
      return BeginShiftResult.persistenceFailure;
    }
    return result;
  }

  Future<SimulationAttempt> _resumeTimer(
    SimulationAttempt attempt, {
    DateTime? at,
    required String screenId,
  }) async {
    if (attempt.state != MissionState.paused ||
        attempt.timerStatus != SimulationTimerStatus.paused) {
      throw StateError('Only a paused attempt can be resumed');
    }
    final resumedAt = at ?? DateTime.now();
    var resumed = _stateService
        .transition(attempt, MissionState.inProgress, at: resumedAt)
        .copyWith(
          clearPausedAt: true,
          timerResumedAt: resumedAt,
          timerStatus: SimulationTimerStatus.running,
        );
    await ref.read(simulationAttemptRepositoryProvider).saveAttempt(resumed);
    resumed = await _appendAuditEvent(
      resumed,
      AttemptAuditEventType.attemptResumedFromPause,
      screenId: screenId,
    );
    return resumed;
  }

  SimulationAttempt _stopTimer(SimulationAttempt attempt, DateTime stoppedAt) {
    final elapsed = currentElapsedSimulationSeconds(attempt, at: stoppedAt);
    return attempt.copyWith(
      elapsedSimulationSeconds: elapsed,
      timerStatus: SimulationTimerStatus.stopped,
      clearPausedAt: true,
      clearTimerResumedAt: true,
    );
  }

  LearnerAction _newAction(
    SimulationAttempt attempt, {
    required String stageId,
    required String taskId,
    required ActionType actionType,
    String? targetId,
    JsonMap payload = const {},
  }) => LearnerAction(
    id: '${attempt.id}-${attempt.actionCount + 1}',
    attemptId: attempt.id,
    missionId: attempt.missionId,
    stageId: stageId,
    taskId: taskId,
    actionType: actionType,
    targetId: targetId,
    payload: payload,
    sequenceNumber: attempt.actionCount + 1,
    simulationTimeSeconds: currentElapsedSimulationSeconds(attempt),
    createdAt: DateTime.now(),
  );

  (SimulationAttempt, List<ActionOutcome>) _applyAction(
    WorkplaceSimulationState current,
    SimulationAttempt attempt,
    List<ActionOutcome> outcomes,
    LearnerAction action,
    GeneratedScenario scenario,
  ) {
    _taskValidation.validate(
      mission: current.mission,
      attempt: attempt,
      action: action,
    );
    final appended = attempt.copyWith(actions: [...attempt.actions, action]);
    final outcome = _actionEvaluation.evaluate(
      current.mission.task(action.taskId),
      action,
      scenario: scenario,
    );
    final progressed = _progress.applyOutcome(
      mission: current.mission,
      attempt: appended,
      action: action,
      outcome: outcome,
    );
    return (progressed, [...outcomes, outcome]);
  }

  SimulationAttempt _withAudit(
    SimulationAttempt attempt,
    AttemptAuditEventType type, {
    required String screenId,
    String? targetId,
    JsonMap payload = const {},
  }) => attempt.copyWith(
    auditEvents: [
      ...attempt.auditEvents,
      _createAuditEvent(
        attempt,
        type,
        screenId: screenId,
        targetId: targetId,
        sequenceNumber: attempt.auditEventCount + 1,
        payload: payload,
      ),
    ],
  );

  Future<AppFailure?> _recordWorkplaceEvent(
    AttemptAuditEventType type, {
    required String screenId,
    String? targetId,
    JsonMap payload = const {},
  }) => recordWorkplaceEvent(
    type,
    screenId: screenId,
    targetId: targetId,
    payload: payload,
  );

  Future<void> _commit(
    WorkplaceSimulationState current,
    SimulationAttempt attempt, {
    List<ActionOutcome>? outcomes,
  }) async {
    await ref
        .read(simulationAttemptRepositoryProvider)
        .commitOperationalUpdate(attempt);
    state = AsyncData(
      current.copyWith(
        attempt: attempt,
        outcomes: outcomes ?? current.outcomes,
      ),
    );
  }

  drafts.DocumentReviewDraft _newDocumentDraft(SimulationAttempt attempt) {
    final now = DateTime.now();
    return drafts.DocumentReviewDraft(
      attemptId: attempt.id,
      taskId: 'verify-documents',
      findings: const [],
      status: drafts.OperationalDraftStatus.draft,
      createdAt: now,
      updatedAt: now,
    );
  }

  drafts.ReceivingCountDraft _newReceivingDraft(SimulationAttempt attempt) {
    final now = DateTime.now();
    return drafts.ReceivingCountDraft(
      attemptId: attempt.id,
      taskId: 'confirm-received-counts',
      shipmentConfirmed: false,
      countEntries: const [],
      status: drafts.OperationalDraftStatus.draft,
      createdAt: now,
      updatedAt: now,
    );
  }

  SimulationAttempt _appendDraftAction(
    SimulationAttempt attempt, {
    required String stageId,
    required String taskId,
    required ActionType actionType,
    required String targetId,
    required JsonMap payload,
  }) {
    final action = _newAction(
      attempt,
      stageId: stageId,
      taskId: taskId,
      actionType: actionType,
      targetId: targetId,
      payload: payload,
    );
    return attempt.copyWith(actions: [...attempt.actions, action]);
  }

  String _documentTarget(String itemReference) =>
      'document-line-$itemReference';

  JsonMap _countPayload(drafts.ReceivingCountEntry entry) => {
    'entryId': entry.id,
    'sku': entry.sku,
    'enteredQuantity': entry.enteredQuantity,
    'countMethod': entry.countMethod.name,
    'learnerNotes': entry.learnerNotes,
    'revisionNumber': entry.revisionNumber,
  };

  WorkstationViewModel _workstationViewModel(
    WorkplaceSimulationState current,
    SimulationAttempt attempt,
    String workstationId,
    bool recommended,
  ) {
    final station = current.workplace.workstations.firstWhere(
      (item) => item.id == workstationId,
    );
    final status = _workstations.status(
      workstation: station,
      mission: current.mission,
      attempt: attempt,
    );
    final label = switch (status) {
      WorkstationStatus.locked => 'Locked',
      WorkstationStatus.available => 'Available',
      WorkstationStatus.inProgress => 'In progress',
      WorkstationStatus.completed => 'Completed',
      WorkstationStatus.attentionRequired => 'Attention required',
    };
    return WorkstationViewModel(
      workstationId: station.id,
      name: station.name,
      description: station.description,
      iconKey: station.icon,
      route: _workstationRoute(current.mission.id, station.id),
      status: status,
      isRecommended: recommended,
      progressLabel: label,
      supportingText: status == WorkstationStatus.locked
          ? _workstations.lockedReason(station, current.mission)
          : station.description,
    );
  }

  String? _workstationRoute(String missionId, String workstationId) =>
      switch (workstationId) {
        'document-desk' =>
          '/practise/workplace-simulation/$missionId/document-desk',
        'receiving-dock' =>
          '/practise/workplace-simulation/$missionId/receiving-dock',
        'inspection-zone' =>
          '/practise/workplace-simulation/$missionId/inspection-zone',
        _ => null,
      };

  List<ActionOutcome> _evaluateActions(
    MissionDefinition mission,
    GeneratedScenario scenario,
    List<LearnerAction> actions,
  ) => [
    for (final action in actions)
      _actionEvaluation.evaluate(
        mission.task(action.taskId),
        action,
        scenario: scenario,
      ),
  ];

  WorkplaceSimulationState _requireState() {
    final current = state.valueOrNull;
    if (current == null) {
      throw const StorageFailure(
        'Workplace simulation content is still loading.',
      );
    }
    return current;
  }

  SimulationAttempt _requireAttempt(WorkplaceSimulationState current) {
    final attempt = current.attempt;
    if (attempt == null) throw StateError('Start a mission first');
    return attempt;
  }

  String _requireCandidate() {
    final candidateId = _candidateId;
    if (candidateId == null) {
      throw const AuthenticationFailure('Sign in again to save the mission.');
    }
    return candidateId;
  }

  Future<AppFailure?> _guard(Future<void> Function() action) async {
    try {
      await action();
      return null;
    } on AppFailure catch (failure) {
      return failure;
    } on FormatException catch (error, stackTrace) {
      return StorageFailure(
        'Simulation content or action data is invalid.',
        cause: error,
        stackTrace: stackTrace,
      );
    } on StateError catch (error, stackTrace) {
      return StorageFailure(
        error.message,
        cause: error,
        stackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      return StorageFailure(
        'The workplace simulation could not save this action. Please retry.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}
