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
    AsyncNotifierProvider.family<
      WorkplaceSimulationController,
      WorkplaceSimulationState,
      String
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
    extends FamilyAsyncNotifier<WorkplaceSimulationState, String> {
  static const packId = 'logistics-foundation';
  static const workplaceId = 'central-distribution-centre';
  static const missionId = 'receive-incoming-shipment-01';
  static const putAwayMissionId = 'put-away-incoming-stock-01';

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
  Future<WorkplaceSimulationState> build(String missionId) async {
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
        : _scenarioGenerator.generate(
            mission,
            attempt.scenarioSeed,
            scenarioId: attempt.scenarioId,
          );
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
    final pendingSyncCount = await ref
        .read(simulationAttemptRepositoryProvider)
        .pendingSyncCount(session.candidateId);
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
      pendingSyncCount: pendingSyncCount,
    );
  }

  /// Re-reads how many of this candidate's WMS writes are still queued for
  /// remote sync. Cheap and safe to call opportunistically -- e.g. when a
  /// screen that shows sync status becomes visible.
  Future<void> refreshPendingSyncStatus() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final candidateId = _candidateId;
    if (candidateId == null) return;
    final count = await ref
        .read(simulationAttemptRepositoryProvider)
        .pendingSyncCount(candidateId);
    final latest = state.valueOrNull;
    if (latest == null) return;
    state = AsyncData(latest.copyWith(pendingSyncCount: count));
  }

  /// Retries every queued write for this candidate, then refreshes the
  /// pending count. A no-op when the app isn't configured for remote sync.
  Future<void> retryPendingSyncs() async {
    final candidateId = _candidateId;
    if (candidateId == null) return;
    await ref
        .read(simulationAttemptRepositoryProvider)
        .flushPendingSyncs(candidateId);
    await refreshPendingSyncStatus();
  }

  Future<AppFailure?> startMission({int? scenarioSeed, String? scenarioId}) {
    return _guard(() async {
      final current = _requireState();
      final candidateId = _requireCandidate();
      final existing = current.attempt;
      if (existing != null &&
          existing.state != MissionState.completed &&
          existing.state != MissionState.failed) {
        return;
      }
      if (scenarioId != null) {
        // Validates the id and throws early with a clear error rather than
        // creating an attempt against an unknown scenario.
        current.mission.scenarioFor(scenarioId);
      }
      final resolvedSeed =
          scenarioSeed ??
          DateTime.now().microsecondsSinceEpoch.remainder(0x7fffffff);
      final generatedScenario = _scenarioGenerator.generate(
        current.mission,
        resolvedSeed,
        scenarioId: scenarioId,
      );
      final attempt = await ref
          .read(simulationAttemptRepositoryProvider)
          .createAttempt(
            candidateId: candidateId,
            missionId: current.mission.id,
            missionVersion: current.mission.version,
            scenarioSeed: resolvedSeed,
            scenarioId: scenarioId,
            generatedScenario: generatedScenario,
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
          scenario: generatedScenario,
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

  drafts.InspectionDraft? get inspectionDraft =>
      state.valueOrNull?.attempt?.inspectionDraft;

  drafts.BarcodeScanDraft? get barcodeScanDraft =>
      state.valueOrNull?.attempt?.barcodeScanDraft;

  drafts.DispositionDraft? get dispositionDraft =>
      state.valueOrNull?.attempt?.dispositionDraft;

  drafts.QuarantineReleaseDraft? get quarantineReleaseDraft =>
      state.valueOrNull?.attempt?.quarantineReleaseDraft;

  drafts.DiscrepancyReportDraft? get discrepancyReportDraft =>
      state.valueOrNull?.attempt?.discrepancyReportDraft;

  LearnerAction? _lastAction(String taskId) {
    final attempt = state.valueOrNull?.attempt;
    if (attempt == null) return null;
    for (final action in attempt.actions.reversed) {
      if (action.taskId == taskId) return action;
    }
    return null;
  }

  ReceivingDecisionOutcome? get selectedReceivingDecision {
    final action = _lastAction('make-receiving-decision');
    final decision = action?.payload['decision'];
    return decision is String
        ? ReceivingDecisionOutcome.fromWireName(decision)
        : null;
  }

  bool get supervisorNotified =>
      state.valueOrNull?.attempt?.completedTaskIds.contains(
        'notify-supervisor',
      ) ??
      false;

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
    final active = _activeAttempt();
    if (active == null) return AddDocumentFindingResult.invalidAttemptState;
    final (current, attempt) = active;
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
    return _tryPersist(
      () async {
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
      },
      onSuccess: () => AddDocumentFindingResult.success,
      onFailure: () => AddDocumentFindingResult.persistenceFailure,
    );
  }

  Future<UpdateDocumentFindingResult> updateDocumentFinding(
    UpdateDocumentFindingCommand command,
  ) async {
    final active = _activeAttempt();
    if (active == null) return UpdateDocumentFindingResult.invalidAttemptState;
    final (current, attempt) = active;
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
    return _tryPersist(
      () async {
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
          documentReviewDraft: draft.copyWith(
            findings: findings,
            updatedAt: now,
          ),
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
      },
      onSuccess: () => UpdateDocumentFindingResult.success,
      onFailure: () => UpdateDocumentFindingResult.persistenceFailure,
    );
  }

  Future<RemoveDocumentFindingResult> removeDocumentFinding(
    RemoveDocumentFindingCommand command,
  ) async {
    final active = _activeAttempt();
    if (active == null) return RemoveDocumentFindingResult.invalidAttemptState;
    final (current, attempt) = active;
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
    return _tryPersist(
      () async {
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
          targetId: _documentTarget(finding!.itemReference),
          payload: {
            'findingId': finding.id,
            'revisionNumber': finding.revisionNumber + 1,
          },
        );
        await _commit(current, updated);
      },
      onSuccess: () => RemoveDocumentFindingResult.success,
      onFailure: () => RemoveDocumentFindingResult.persistenceFailure,
    );
  }

  Future<SaveDocumentReviewDraftResult> saveDocumentReviewDraft(
    SaveDocumentReviewDraftCommand command,
  ) async {
    final active = _activeAttempt();
    if (active == null) {
      return SaveDocumentReviewDraftResult.invalidAttemptState;
    }
    final (current, attempt) = active;
    final draft = attempt.documentReviewDraft ?? _newDocumentDraft(attempt);
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return SaveDocumentReviewDraftResult.alreadySubmitted;
    }
    return _tryPersist(
      () async {
        final updated = _withAudit(
          attempt.copyWith(documentReviewDraft: draft),
          AttemptAuditEventType.documentReviewDraftSaved,
          screenId: 'document-desk',
          payload: {'findingCount': draft.findings.length},
        );
        await _commit(current, updated);
      },
      onSuccess: () => SaveDocumentReviewDraftResult.success,
      onFailure: () => SaveDocumentReviewDraftResult.persistenceFailure,
    );
  }

  Future<SubmitDocumentReviewResult> submitDocumentReview(
    SubmitDocumentReviewCommand command,
  ) async {
    final active = _activeAttemptWithScenario();
    if (active == null) return SubmitDocumentReviewResult.invalidAttemptState;
    final (current, attempt, scenario) = active;
    final draft = attempt.documentReviewDraft;
    if (draft == null || draft.findings.isEmpty) {
      return SubmitDocumentReviewResult.noFindings;
    }
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return SubmitDocumentReviewResult.alreadySubmitted;
    }
    return _tryPersist(
      () async {
        var working = _withAudit(
          attempt,
          AttemptAuditEventType.documentFindingsSaveRequested,
          screenId: 'document-desk',
          payload: {'findingCount': draft.findings.length},
        );
        var outcomes = [...current.outcomes];
        for (final taskId in const [
          'open-purchase-order',
          'open-delivery-note',
        ]) {
          if (working.actions.any((action) => action.taskId == taskId)) {
            continue;
          }
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
      },
      onSuccess: () => SubmitDocumentReviewResult.success,
      onFailure: () => SubmitDocumentReviewResult.persistenceFailure,
      onCaught: () => _recordWorkplaceEvent(
        AttemptAuditEventType.documentFindingsSaveFailed,
        screenId: 'document-desk',
      ),
    );
  }

  Future<ConfirmShipmentIdentityResult> confirmShipmentIdentity(
    ConfirmShipmentIdentityCommand command,
  ) async {
    final active = _activeAttempt();
    if (active == null) {
      return ConfirmShipmentIdentityResult.invalidAttemptState;
    }
    final (current, attempt) = active;
    final draft = attempt.receivingCountDraft ?? _newReceivingDraft(attempt);
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return ConfirmShipmentIdentityResult.alreadySubmitted;
    }
    return _tryPersist(
      () async {
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
      },
      onSuccess: () => ConfirmShipmentIdentityResult.success,
      onFailure: () => ConfirmShipmentIdentityResult.persistenceFailure,
    );
  }

  /// Ends the mission immediately after the candidate has recorded (via
  /// [confirmShipmentIdentity]) that the shipment does not match the
  /// expected delivery. Records the real scored confirm-delivery-identity
  /// outcome, then submits -- correctly stopping before counting or
  /// inspection effort is spent on stock that should never have been
  /// accepted onto the dock is itself the successful outcome for a
  /// wrong-supplier scenario; scoring for that is content-authored via
  /// `MissionDefinition.earlyCompletionRules`, not special-cased here.
  Future<RejectShipmentIdentityResult> rejectShipmentIdentity() async {
    final active = _activeAttemptWithScenario();
    if (active == null) return RejectShipmentIdentityResult.invalidAttemptState;
    final (current, attempt, scenario) = active;
    final draft = attempt.receivingCountDraft;
    if (draft == null || draft.shipmentConfirmed != false) {
      return RejectShipmentIdentityResult.notYetRejected;
    }
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return RejectShipmentIdentityResult.alreadySubmitted;
    }
    final recorded = await _tryPersist(
      () async {
        var working = attempt;
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
            payload: {'conclusion': 'wrong_supplier_or_reference'},
          ),
          scenario,
        );
        final now = DateTime.now();
        working = working.copyWith(
          receivingCountDraft: draft.copyWith(
            status: drafts.OperationalDraftStatus.submitted,
            updatedAt: now,
            submittedAt: now,
          ),
        );
        await _commit(current, working, outcomes: outcomes);
      },
      onSuccess: () => true,
      onFailure: () => false,
    );
    if (!recorded) return RejectShipmentIdentityResult.persistenceFailure;
    final completion = await completeMission(screenId: 'receiving-dock');
    return completion == CompleteMissionResult.success
        ? RejectShipmentIdentityResult.success
        : RejectShipmentIdentityResult.persistenceFailure;
  }

  Future<RecordCartonCountResult> recordCartonCount(
    RecordCartonCountCommand command,
  ) async {
    final active = _activeAttempt();
    if (active == null) return RecordCartonCountResult.invalidAttemptState;
    final (current, attempt) = active;
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
    return _tryPersist(
      () async {
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
      },
      onSuccess: () => RecordCartonCountResult.success,
      onFailure: () => RecordCartonCountResult.persistenceFailure,
    );
  }

  Future<UpdateCartonCountResult> updateCartonCount(
    UpdateCartonCountCommand command,
  ) async {
    final active = _activeAttempt();
    if (active == null) return UpdateCartonCountResult.invalidAttemptState;
    final (current, attempt) = active;
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
    return _tryPersist(
      () async {
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
      },
      onSuccess: () => UpdateCartonCountResult.success,
      onFailure: () => UpdateCartonCountResult.persistenceFailure,
    );
  }

  Future<RemoveCartonCountResult> removeCartonCount(
    RemoveCartonCountCommand command,
  ) async {
    final active = _activeAttempt();
    if (active == null) return RemoveCartonCountResult.invalidAttemptState;
    final (current, attempt) = active;
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
    return _tryPersist(
      () async {
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
          targetId: entry!.cartonId,
          payload: {
            'entryId': entry.id,
            'revisionNumber': entry.revisionNumber + 1,
          },
        );
        await _commit(current, updated);
      },
      onSuccess: () => RemoveCartonCountResult.success,
      onFailure: () => RemoveCartonCountResult.persistenceFailure,
    );
  }

  Future<SaveReceivingCountDraftResult> saveReceivingCountDraft(
    SaveReceivingCountDraftCommand command,
  ) async {
    final active = _activeAttempt();
    if (active == null) {
      return SaveReceivingCountDraftResult.invalidAttemptState;
    }
    final (current, attempt) = active;
    final draft = attempt.receivingCountDraft ?? _newReceivingDraft(attempt);
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return SaveReceivingCountDraftResult.alreadySubmitted;
    }
    return _tryPersist(
      () async {
        final updated = _withAudit(
          attempt.copyWith(receivingCountDraft: draft),
          AttemptAuditEventType.receivingCountDraftSaved,
          screenId: 'receiving-dock',
          payload: {'entryCount': draft.countEntries.length},
        );
        await _commit(current, updated);
      },
      onSuccess: () => SaveReceivingCountDraftResult.success,
      onFailure: () => SaveReceivingCountDraftResult.persistenceFailure,
    );
  }

  Future<SubmitReceivingCountResult> submitReceivingCount(
    SubmitReceivingCountCommand command,
  ) async {
    final active = _activeAttemptWithScenario();
    if (active == null) return SubmitReceivingCountResult.invalidAttemptState;
    final (current, attempt, scenario) = active;
    final draft = attempt.receivingCountDraft;
    if (draft == null || draft.shipmentConfirmed != true) {
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
    return _tryPersist(
      () async {
        var working = _withAudit(
          attempt,
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
            payload: {'conclusion': 'matches_expected_delivery'},
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
      },
      onSuccess: () => SubmitReceivingCountResult.success,
      onFailure: () => SubmitReceivingCountResult.persistenceFailure,
      onCaught: () => _recordWorkplaceEvent(
        AttemptAuditEventType.receivingCountSaveFailed,
        screenId: 'receiving-dock',
      ),
    );
  }

  Future<RecordCartonInspectionResult> recordCartonInspection(
    RecordCartonInspectionCommand command,
  ) async {
    final active = _activeAttempt();
    if (active == null) return RecordCartonInspectionResult.invalidAttemptState;
    final (current, attempt) = active;
    final task = current.mission.task('inspect-cartons');
    if (!task.targetResourceIds.contains(command.cartonId)) {
      return RecordCartonInspectionResult.cartonNotFound;
    }
    if (!_validFindings(command.findings)) {
      return RecordCartonInspectionResult.invalidFindings;
    }
    final draft = attempt.inspectionDraft ?? _newInspectionDraft(attempt);
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return RecordCartonInspectionResult.alreadySubmitted;
    }
    if (draft.cartonInspections.any(
      (item) => item.cartonId == command.cartonId,
    )) {
      return RecordCartonInspectionResult.duplicateEntry;
    }
    return _tryPersist(
      () async {
        final now = DateTime.now();
        final entry = drafts.CartonInspectionEntry(
          id: '${attempt.id}-inspect-${draft.cartonInspections.length + 1}',
          cartonId: command.cartonId,
          findings: command.findings,
          learnerNotes: command.learnerNotes.trim(),
          createdAt: now,
          updatedAt: now,
          revisionNumber: 1,
        );
        var updated = attempt.copyWith(
          inspectionDraft: draft.copyWith(
            cartonInspections: [...draft.cartonInspections, entry],
            updatedAt: now,
          ),
        );
        updated = _appendDraftAction(
          updated,
          stageId: 'physical-inspection',
          taskId: 'inspect-cartons',
          actionType: ActionType.cartonInspectionRecorded,
          targetId: entry.cartonId,
          payload: _inspectionPayload(entry),
        );
        await _commit(current, updated);
      },
      onSuccess: () => RecordCartonInspectionResult.success,
      onFailure: () => RecordCartonInspectionResult.persistenceFailure,
    );
  }

  Future<UpdateCartonInspectionResult> updateCartonInspection(
    UpdateCartonInspectionCommand command,
  ) async {
    final active = _activeAttempt();
    if (active == null) return UpdateCartonInspectionResult.invalidAttemptState;
    final (current, attempt) = active;
    if (!_validFindings(command.findings)) {
      return UpdateCartonInspectionResult.invalidFindings;
    }
    final draft = attempt.inspectionDraft;
    if (draft == null) return UpdateCartonInspectionResult.entryNotFound;
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return UpdateCartonInspectionResult.alreadySubmitted;
    }
    final index = draft.cartonInspections.indexWhere(
      (item) => item.id == command.entryId,
    );
    if (index < 0) return UpdateCartonInspectionResult.entryNotFound;
    return _tryPersist(
      () async {
        final now = DateTime.now();
        final previous = draft.cartonInspections[index];
        final entry = previous.copyWith(
          findings: command.findings,
          learnerNotes: command.learnerNotes.trim(),
          updatedAt: now,
          revisionNumber: previous.revisionNumber + 1,
        );
        final entries = [...draft.cartonInspections]..[index] = entry;
        var updated = attempt.copyWith(
          inspectionDraft: draft.copyWith(
            cartonInspections: entries,
            updatedAt: now,
          ),
        );
        updated = _appendDraftAction(
          updated,
          stageId: 'physical-inspection',
          taskId: 'inspect-cartons',
          actionType: ActionType.cartonInspectionUpdated,
          targetId: entry.cartonId,
          payload: _inspectionPayload(entry),
        );
        await _commit(current, updated);
      },
      onSuccess: () => UpdateCartonInspectionResult.success,
      onFailure: () => UpdateCartonInspectionResult.persistenceFailure,
    );
  }

  Future<RemoveCartonInspectionResult> removeCartonInspection(
    RemoveCartonInspectionCommand command,
  ) async {
    final active = _activeAttempt();
    if (active == null) return RemoveCartonInspectionResult.invalidAttemptState;
    final (current, attempt) = active;
    final draft = attempt.inspectionDraft;
    if (draft == null) return RemoveCartonInspectionResult.entryNotFound;
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return RemoveCartonInspectionResult.alreadySubmitted;
    }
    drafts.CartonInspectionEntry? entry;
    for (final item in draft.cartonInspections) {
      if (item.id == command.entryId) entry = item;
    }
    if (entry == null) return RemoveCartonInspectionResult.entryNotFound;
    return _tryPersist(
      () async {
        final now = DateTime.now();
        var updated = attempt.copyWith(
          inspectionDraft: draft.copyWith(
            cartonInspections: draft.cartonInspections
                .where((item) => item.id != command.entryId)
                .toList(growable: false),
            updatedAt: now,
          ),
        );
        updated = _appendDraftAction(
          updated,
          stageId: 'physical-inspection',
          taskId: 'inspect-cartons',
          actionType: ActionType.cartonInspectionRemoved,
          targetId: entry!.cartonId,
          payload: {
            'entryId': entry.id,
            'revisionNumber': entry.revisionNumber + 1,
          },
        );
        await _commit(current, updated);
      },
      onSuccess: () => RemoveCartonInspectionResult.success,
      onFailure: () => RemoveCartonInspectionResult.persistenceFailure,
    );
  }

  Future<RecordBarcodeScanResult> recordBarcodeScan(
    RecordBarcodeScanCommand command,
  ) async {
    final active = _activeAttempt();
    if (active == null) return RecordBarcodeScanResult.invalidAttemptState;
    final (current, attempt) = active;
    final task = current.mission.task('scan-barcodes');
    if (!task.targetResourceIds.contains(command.cartonId)) {
      return RecordBarcodeScanResult.cartonNotFound;
    }
    final draft = attempt.barcodeScanDraft ?? _newBarcodeScanDraft(attempt);
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return RecordBarcodeScanResult.alreadySubmitted;
    }
    if (draft.entries.any((item) => item.cartonId == command.cartonId)) {
      return RecordBarcodeScanResult.duplicateEntry;
    }
    return _tryPersist(
      () async {
        final now = DateTime.now();
        final entry = drafts.BarcodeScanEntry(
          id: '${attempt.id}-scan-${draft.entries.length + 1}',
          cartonId: command.cartonId,
          status: command.status,
          createdAt: now,
          updatedAt: now,
          revisionNumber: 1,
          resolutionMethod: command.resolutionMethod,
          manualCode: command.manualCode,
        );
        var updated = attempt.copyWith(
          barcodeScanDraft: draft.copyWith(
            entries: [...draft.entries, entry],
            updatedAt: now,
          ),
        );
        updated = _appendDraftAction(
          updated,
          stageId: 'barcode-scan',
          taskId: 'scan-barcodes',
          actionType: ActionType.barcodeScanRecorded,
          targetId: entry.cartonId,
          payload: _scanPayload(entry),
        );
        await _commit(current, updated);
      },
      onSuccess: () => RecordBarcodeScanResult.success,
      onFailure: () => RecordBarcodeScanResult.persistenceFailure,
    );
  }

  Future<UpdateBarcodeScanResult> updateBarcodeScan(
    UpdateBarcodeScanCommand command,
  ) async {
    final active = _activeAttempt();
    if (active == null) return UpdateBarcodeScanResult.invalidAttemptState;
    final (current, attempt) = active;
    final draft = attempt.barcodeScanDraft;
    if (draft == null) return UpdateBarcodeScanResult.entryNotFound;
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return UpdateBarcodeScanResult.alreadySubmitted;
    }
    final index = draft.entries.indexWhere(
      (item) => item.id == command.entryId,
    );
    if (index < 0) return UpdateBarcodeScanResult.entryNotFound;
    return _tryPersist(
      () async {
        final now = DateTime.now();
        final previous = draft.entries[index];
        final entry = previous.copyWith(
          status: command.status,
          updatedAt: now,
          revisionNumber: previous.revisionNumber + 1,
          scanAttempts: command.scanAttempts ?? previous.scanAttempts,
          resolutionMethod: command.resolutionMethod,
          manualCode: command.manualCode,
        );
        final entries = [...draft.entries]..[index] = entry;
        var updated = attempt.copyWith(
          barcodeScanDraft: draft.copyWith(entries: entries, updatedAt: now),
        );
        updated = _appendDraftAction(
          updated,
          stageId: 'barcode-scan',
          taskId: 'scan-barcodes',
          actionType: ActionType.barcodeScanUpdated,
          targetId: entry.cartonId,
          payload: _scanPayload(entry),
        );
        await _commit(current, updated);
      },
      onSuccess: () => UpdateBarcodeScanResult.success,
      onFailure: () => UpdateBarcodeScanResult.persistenceFailure,
    );
  }

  Future<RemoveBarcodeScanResult> removeBarcodeScan(
    RemoveBarcodeScanCommand command,
  ) async {
    final active = _activeAttempt();
    if (active == null) return RemoveBarcodeScanResult.invalidAttemptState;
    final (current, attempt) = active;
    final draft = attempt.barcodeScanDraft;
    if (draft == null) return RemoveBarcodeScanResult.entryNotFound;
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return RemoveBarcodeScanResult.alreadySubmitted;
    }
    drafts.BarcodeScanEntry? entry;
    for (final item in draft.entries) {
      if (item.id == command.entryId) entry = item;
    }
    if (entry == null) return RemoveBarcodeScanResult.entryNotFound;
    return _tryPersist(
      () async {
        final now = DateTime.now();
        var updated = attempt.copyWith(
          barcodeScanDraft: draft.copyWith(
            entries: draft.entries
                .where((item) => item.id != command.entryId)
                .toList(growable: false),
            updatedAt: now,
          ),
        );
        updated = _appendDraftAction(
          updated,
          stageId: 'barcode-scan',
          taskId: 'scan-barcodes',
          actionType: ActionType.barcodeScanRemoved,
          targetId: entry!.cartonId,
          payload: {
            'entryId': entry.id,
            'revisionNumber': entry.revisionNumber + 1,
          },
        );
        await _commit(current, updated);
      },
      onSuccess: () => RemoveBarcodeScanResult.success,
      onFailure: () => RemoveBarcodeScanResult.persistenceFailure,
    );
  }

  Future<SaveBarcodeScanDraftResult> saveBarcodeScanDraft(
    SaveBarcodeScanDraftCommand command,
  ) async {
    final active = _activeAttempt();
    if (active == null) return SaveBarcodeScanDraftResult.invalidAttemptState;
    final (current, attempt) = active;
    final draft = attempt.barcodeScanDraft ?? _newBarcodeScanDraft(attempt);
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return SaveBarcodeScanDraftResult.alreadySubmitted;
    }
    return _tryPersist(
      () async {
        final updated = _withAudit(
          attempt.copyWith(barcodeScanDraft: draft),
          AttemptAuditEventType.barcodeScanDraftSaved,
          screenId: 'barcode-station',
          payload: {'scanCount': draft.entries.length},
        );
        await _commit(current, updated);
      },
      onSuccess: () => SaveBarcodeScanDraftResult.success,
      onFailure: () => SaveBarcodeScanDraftResult.persistenceFailure,
    );
  }

  Future<SubmitBarcodeScanResult> submitBarcodeScan(
    SubmitBarcodeScanCommand command,
  ) async {
    final active = _activeAttemptWithScenario();
    if (active == null) return SubmitBarcodeScanResult.invalidAttemptState;
    final (current, attempt, scenario) = active;
    final draft = attempt.barcodeScanDraft;
    if (draft == null) return SubmitBarcodeScanResult.incompleteScans;
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return SubmitBarcodeScanResult.alreadySubmitted;
    }
    final scanTargets = current.mission.task('scan-barcodes').targetResourceIds;
    if (draft.entries.length != scanTargets.length ||
        !scanTargets.every(
          (id) => draft.entries.any((entry) => entry.cartonId == id),
        )) {
      return SubmitBarcodeScanResult.incompleteScans;
    }
    return _tryPersist(
      () async {
        var working = _withAudit(
          attempt,
          AttemptAuditEventType.barcodeScanSubmissionRequested,
          screenId: 'barcode-station',
          payload: {'scanCount': draft.entries.length},
        );
        var outcomes = [...current.outcomes];
        for (final entry in draft.entries) {
          (working, outcomes) = _applyAction(
            current,
            working,
            outcomes,
            _newAction(
              working,
              stageId: 'barcode-scan',
              taskId: 'scan-barcodes',
              actionType: ActionType.scanBarcode,
              targetId: entry.cartonId,
              payload: {'barcodeStatus': entry.status.name},
            ),
            scenario,
          );
        }
        final now = DateTime.now();
        working = working.copyWith(
          barcodeScanDraft: draft.copyWith(
            status: drafts.OperationalDraftStatus.submitted,
            updatedAt: now,
            submittedAt: now,
          ),
        );
        working = _withAudit(
          working,
          AttemptAuditEventType.barcodeScansSaved,
          screenId: 'barcode-station',
          payload: {'scanCount': draft.entries.length},
        );
        await _commit(current, working, outcomes: outcomes);
      },
      onSuccess: () => SubmitBarcodeScanResult.success,
      onFailure: () => SubmitBarcodeScanResult.persistenceFailure,
    );
  }

  Future<SaveInspectionDraftResult> saveInspectionDraft(
    SaveInspectionDraftCommand command,
  ) async {
    final active = _activeAttempt();
    if (active == null) return SaveInspectionDraftResult.invalidAttemptState;
    final (current, attempt) = active;
    final draft = attempt.inspectionDraft ?? _newInspectionDraft(attempt);
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return SaveInspectionDraftResult.alreadySubmitted;
    }
    return _tryPersist(
      () async {
        final updated = _withAudit(
          attempt.copyWith(inspectionDraft: draft),
          AttemptAuditEventType.inspectionDraftSaved,
          screenId: 'inspection-zone',
          payload: {'inspectionCount': draft.cartonInspections.length},
        );
        await _commit(current, updated);
      },
      onSuccess: () => SaveInspectionDraftResult.success,
      onFailure: () => SaveInspectionDraftResult.persistenceFailure,
    );
  }

  Future<SubmitInspectionResult> submitInspection(
    SubmitInspectionCommand command,
  ) async {
    final active = _activeAttemptWithScenario();
    if (active == null) return SubmitInspectionResult.invalidAttemptState;
    final (current, attempt, scenario) = active;
    final draft = attempt.inspectionDraft;
    if (draft == null) return SubmitInspectionResult.incompleteInspection;
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return SubmitInspectionResult.alreadySubmitted;
    }
    final inspectionTargets = current.mission
        .task('inspect-cartons')
        .targetResourceIds;
    if (draft.cartonInspections.length != inspectionTargets.length ||
        !inspectionTargets.every(
          (id) => draft.cartonInspections.any((entry) => entry.cartonId == id),
        )) {
      return SubmitInspectionResult.incompleteInspection;
    }
    return _tryPersist(
      () async {
        var working = _withAudit(
          attempt,
          AttemptAuditEventType.inspectionSubmissionRequested,
          screenId: 'inspection-zone',
          payload: {'inspectionCount': draft.cartonInspections.length},
        );
        var outcomes = [...current.outcomes];
        for (final entry in draft.cartonInspections) {
          // A carton may carry more than one simultaneous finding (a
          // multi-exception shipment); each is scored as its own action so
          // catching two issues on one carton earns credit for both.
          for (final finding in entry.findings) {
            final compliant = finding == drafts.CartonFinding.compliant;
            (working, outcomes) = _applyAction(
              current,
              working,
              outcomes,
              _newAction(
                working,
                stageId: 'physical-inspection',
                taskId: 'inspect-cartons',
                actionType: compliant
                    ? ActionType.inspectItem
                    : ActionType.recordIssue,
                targetId: entry.cartonId,
                payload: compliant
                    ? const {'finding': 'compliant'}
                    : {'issueType': finding.wireName},
              ),
              scenario,
            );
          }
        }
        final now = DateTime.now();
        working = working.copyWith(
          inspectionDraft: draft.copyWith(
            status: drafts.OperationalDraftStatus.submitted,
            updatedAt: now,
            submittedAt: now,
          ),
        );
        working = _withAudit(
          working,
          AttemptAuditEventType.inspectionSaved,
          screenId: 'inspection-zone',
          payload: {'inspectionCount': draft.cartonInspections.length},
        );
        await _commit(current, working, outcomes: outcomes);
      },
      onSuccess: () => SubmitInspectionResult.success,
      onFailure: () => SubmitInspectionResult.persistenceFailure,
      onCaught: () => _recordWorkplaceEvent(
        AttemptAuditEventType.inspectionSaveFailed,
        screenId: 'inspection-zone',
      ),
    );
  }

  Future<RecordDispositionResult> recordDisposition(
    RecordDispositionCommand command,
  ) async {
    final active = _activeAttempt();
    if (active == null) return RecordDispositionResult.invalidAttemptState;
    final (current, attempt) = active;
    final task = current.mission.task('assign-dispositions');
    if (!task.targetResourceIds.contains(command.cartonId)) {
      return RecordDispositionResult.cartonNotFound;
    }
    if (command.disposition != DispositionType.accept &&
        command.reason.trim().isEmpty) {
      return RecordDispositionResult.reasonRequired;
    }
    final draft = attempt.dispositionDraft ?? _newDispositionDraft(attempt);
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return RecordDispositionResult.alreadySubmitted;
    }
    if (draft.entries.any((item) => item.cartonId == command.cartonId)) {
      return RecordDispositionResult.duplicateEntry;
    }
    return _tryPersist(
      () async {
        final now = DateTime.now();
        final entry = drafts.DispositionEntry(
          id: '${attempt.id}-disposition-${draft.entries.length + 1}',
          cartonId: command.cartonId,
          disposition: command.disposition,
          reason: command.reason.trim(),
          createdAt: now,
          updatedAt: now,
          revisionNumber: 1,
        );
        var updated = attempt.copyWith(
          dispositionDraft: draft.copyWith(
            entries: [...draft.entries, entry],
            updatedAt: now,
          ),
        );
        updated = _appendDraftAction(
          updated,
          stageId: 'exception-handling',
          taskId: 'assign-dispositions',
          actionType: ActionType.dispositionRecorded,
          targetId: entry.cartonId,
          payload: _dispositionPayload(entry),
        );
        await _commit(current, updated);
      },
      onSuccess: () => RecordDispositionResult.success,
      onFailure: () => RecordDispositionResult.persistenceFailure,
    );
  }

  Future<UpdateDispositionResult> updateDisposition(
    UpdateDispositionCommand command,
  ) async {
    final active = _activeAttempt();
    if (active == null) return UpdateDispositionResult.invalidAttemptState;
    final (current, attempt) = active;
    if (command.disposition != DispositionType.accept &&
        command.reason.trim().isEmpty) {
      return UpdateDispositionResult.reasonRequired;
    }
    final draft = attempt.dispositionDraft;
    if (draft == null) return UpdateDispositionResult.entryNotFound;
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return UpdateDispositionResult.alreadySubmitted;
    }
    final index = draft.entries.indexWhere(
      (item) => item.id == command.entryId,
    );
    if (index < 0) return UpdateDispositionResult.entryNotFound;
    return _tryPersist(
      () async {
        final now = DateTime.now();
        final previous = draft.entries[index];
        final entry = previous.copyWith(
          disposition: command.disposition,
          reason: command.reason.trim(),
          updatedAt: now,
          revisionNumber: previous.revisionNumber + 1,
        );
        final entries = [...draft.entries]..[index] = entry;
        var updated = attempt.copyWith(
          dispositionDraft: draft.copyWith(entries: entries, updatedAt: now),
        );
        updated = _appendDraftAction(
          updated,
          stageId: 'exception-handling',
          taskId: 'assign-dispositions',
          actionType: ActionType.dispositionUpdated,
          targetId: entry.cartonId,
          payload: _dispositionPayload(entry),
        );
        await _commit(current, updated);
      },
      onSuccess: () => UpdateDispositionResult.success,
      onFailure: () => UpdateDispositionResult.persistenceFailure,
    );
  }

  Future<RemoveDispositionResult> removeDisposition(
    RemoveDispositionCommand command,
  ) async {
    final active = _activeAttempt();
    if (active == null) return RemoveDispositionResult.invalidAttemptState;
    final (current, attempt) = active;
    final draft = attempt.dispositionDraft;
    if (draft == null) return RemoveDispositionResult.entryNotFound;
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return RemoveDispositionResult.alreadySubmitted;
    }
    drafts.DispositionEntry? entry;
    for (final item in draft.entries) {
      if (item.id == command.entryId) entry = item;
    }
    if (entry == null) return RemoveDispositionResult.entryNotFound;
    return _tryPersist(
      () async {
        final now = DateTime.now();
        var updated = attempt.copyWith(
          dispositionDraft: draft.copyWith(
            entries: draft.entries
                .where((item) => item.id != command.entryId)
                .toList(growable: false),
            updatedAt: now,
          ),
        );
        updated = _appendDraftAction(
          updated,
          stageId: 'exception-handling',
          taskId: 'assign-dispositions',
          actionType: ActionType.dispositionRemoved,
          targetId: entry!.cartonId,
          payload: {
            'entryId': entry.id,
            'revisionNumber': entry.revisionNumber + 1,
          },
        );
        await _commit(current, updated);
      },
      onSuccess: () => RemoveDispositionResult.success,
      onFailure: () => RemoveDispositionResult.persistenceFailure,
    );
  }

  Future<SaveDispositionDraftResult> saveDispositionDraft(
    SaveDispositionDraftCommand command,
  ) async {
    final active = _activeAttempt();
    if (active == null) return SaveDispositionDraftResult.invalidAttemptState;
    final (current, attempt) = active;
    final draft = attempt.dispositionDraft ?? _newDispositionDraft(attempt);
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return SaveDispositionDraftResult.alreadySubmitted;
    }
    return _tryPersist(
      () async {
        final updated = _withAudit(
          attempt.copyWith(dispositionDraft: draft),
          AttemptAuditEventType.dispositionsDraftSaved,
          screenId: 'quarantine-zone',
          payload: {'entryCount': draft.entries.length},
        );
        await _commit(current, updated);
      },
      onSuccess: () => SaveDispositionDraftResult.success,
      onFailure: () => SaveDispositionDraftResult.persistenceFailure,
    );
  }

  Future<SubmitDispositionsResult> submitDispositions(
    SubmitDispositionsCommand command,
  ) async {
    final active = _activeAttemptWithScenario();
    if (active == null) return SubmitDispositionsResult.invalidAttemptState;
    final (current, attempt, scenario) = active;
    final draft = attempt.dispositionDraft;
    if (draft == null) return SubmitDispositionsResult.incompleteDispositions;
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return SubmitDispositionsResult.alreadySubmitted;
    }
    final targets = current.mission
        .task('assign-dispositions')
        .targetResourceIds;
    if (draft.entries.length != targets.length ||
        !targets.every(
          (id) => draft.entries.any((entry) => entry.cartonId == id),
        )) {
      return SubmitDispositionsResult.incompleteDispositions;
    }
    return _tryPersist(
      () async {
        var working = _withAudit(
          attempt,
          AttemptAuditEventType.dispositionsSubmissionRequested,
          screenId: 'quarantine-zone',
          payload: {'entryCount': draft.entries.length},
        );
        var outcomes = [...current.outcomes];
        for (final entry in draft.entries) {
          (working, outcomes) = _applyAction(
            current,
            working,
            outcomes,
            _newAction(
              working,
              stageId: 'exception-handling',
              taskId: 'assign-dispositions',
              actionType: ActionType.selectDisposition,
              targetId: entry.cartonId,
              payload: {
                'disposition': entry.disposition.wireName,
                'reason': entry.reason,
              },
            ),
            scenario,
          );
        }
        final now = DateTime.now();
        working = working.copyWith(
          dispositionDraft: draft.copyWith(
            status: drafts.OperationalDraftStatus.submitted,
            updatedAt: now,
            submittedAt: now,
          ),
        );
        working = _withAudit(
          working,
          AttemptAuditEventType.dispositionsSaved,
          screenId: 'quarantine-zone',
          payload: {'entryCount': draft.entries.length},
        );
        await _commit(current, working, outcomes: outcomes);
      },
      onSuccess: () => SubmitDispositionsResult.success,
      onFailure: () => SubmitDispositionsResult.persistenceFailure,
      onCaught: () => _recordWorkplaceEvent(
        AttemptAuditEventType.dispositionsSaveFailed,
        screenId: 'quarantine-zone',
      ),
    );
  }

  Future<ConfirmQuarantineResult> confirmQuarantine(
    ConfirmQuarantineCommand command,
  ) async {
    final active = _activeAttemptWithScenario();
    if (active == null) return ConfirmQuarantineResult.invalidAttemptState;
    final (current, attempt, scenario) = active;
    if (attempt.dispositionDraft?.status !=
        drafts.OperationalDraftStatus.submitted) {
      return ConfirmQuarantineResult.dispositionsNotSubmitted;
    }
    if (attempt.completedTaskIds.contains('confirm-quarantine')) {
      return ConfirmQuarantineResult.alreadyConfirmed;
    }
    return _tryPersist(
      () async {
        var working = attempt;
        var outcomes = [...current.outcomes];
        (working, outcomes) = _applyAction(
          current,
          working,
          outcomes,
          _newAction(
            working,
            stageId: 'exception-handling',
            taskId: 'confirm-quarantine',
            actionType: ActionType.confirmAction,
            targetId: 'quarantine-record',
            payload: {'allExceptionsSeparated': true},
          ),
          scenario,
        );
        working = _withAudit(
          working,
          AttemptAuditEventType.quarantineConfirmed,
          screenId: 'quarantine-zone',
        );
        await _commit(current, working, outcomes: outcomes);
      },
      onSuccess: () => ConfirmQuarantineResult.success,
      onFailure: () => ConfirmQuarantineResult.persistenceFailure,
      onCaught: () => _recordWorkplaceEvent(
        AttemptAuditEventType.quarantineConfirmationFailed,
        screenId: 'quarantine-zone',
      ),
    );
  }

  /// Cartons whose disposition is `quarantine` or `holdForVerification` --
  /// the only ones a release decision can be requested for. Unlike other
  /// tasks, `request-quarantine-release`'s real target set is this dynamic,
  /// scenario-dependent subset, not the task's static `targetResourceIds`
  /// (which lists every carton purely so content validation can confirm
  /// they're real resources).
  Set<String> _heldCartonIds(SimulationAttempt attempt) =>
      attempt.dispositionDraft?.entries
          .where(
            (entry) =>
                entry.disposition == DispositionType.quarantine ||
                entry.disposition == DispositionType.holdForVerification,
          )
          .map((entry) => entry.cartonId)
          .toSet() ??
      const {};

  Future<RecordReleaseDecisionResult> recordReleaseDecision(
    RecordReleaseDecisionCommand command,
  ) async {
    final active = _activeAttempt();
    if (active == null) return RecordReleaseDecisionResult.invalidAttemptState;
    final (current, attempt) = active;
    if (!_heldCartonIds(attempt).contains(command.cartonId)) {
      return RecordReleaseDecisionResult.cartonNotHeld;
    }
    if (command.justification.trim().isEmpty) {
      return RecordReleaseDecisionResult.justificationRequired;
    }
    final draft =
        attempt.quarantineReleaseDraft ?? _newQuarantineReleaseDraft(attempt);
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return RecordReleaseDecisionResult.alreadySubmitted;
    }
    if (draft.entries.any((item) => item.cartonId == command.cartonId)) {
      return RecordReleaseDecisionResult.duplicateEntry;
    }
    return _tryPersist(
      () async {
        final now = DateTime.now();
        final entry = drafts.QuarantineReleaseEntry(
          id: '${attempt.id}-release-${draft.entries.length + 1}',
          cartonId: command.cartonId,
          decision: command.decision,
          justification: command.justification.trim(),
          createdAt: now,
          updatedAt: now,
          revisionNumber: 1,
        );
        var updated = attempt.copyWith(
          quarantineReleaseDraft: draft.copyWith(
            entries: [...draft.entries, entry],
            updatedAt: now,
          ),
        );
        updated = _appendDraftAction(
          updated,
          stageId: 'exception-handling',
          taskId: 'request-quarantine-release',
          actionType: ActionType.releaseDecisionRecorded,
          targetId: entry.cartonId,
          payload: _releaseDecisionPayload(entry),
        );
        await _commit(current, updated);
      },
      onSuccess: () => RecordReleaseDecisionResult.success,
      onFailure: () => RecordReleaseDecisionResult.persistenceFailure,
    );
  }

  Future<UpdateReleaseDecisionResult> updateReleaseDecision(
    UpdateReleaseDecisionCommand command,
  ) async {
    final active = _activeAttempt();
    if (active == null) return UpdateReleaseDecisionResult.invalidAttemptState;
    final (current, attempt) = active;
    if (command.justification.trim().isEmpty) {
      return UpdateReleaseDecisionResult.justificationRequired;
    }
    final draft = attempt.quarantineReleaseDraft;
    if (draft == null) return UpdateReleaseDecisionResult.entryNotFound;
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return UpdateReleaseDecisionResult.alreadySubmitted;
    }
    final index = draft.entries.indexWhere(
      (item) => item.id == command.entryId,
    );
    if (index < 0) return UpdateReleaseDecisionResult.entryNotFound;
    return _tryPersist(
      () async {
        final now = DateTime.now();
        final previous = draft.entries[index];
        final entry = previous.copyWith(
          decision: command.decision,
          justification: command.justification.trim(),
          updatedAt: now,
          revisionNumber: previous.revisionNumber + 1,
        );
        final entries = [...draft.entries]..[index] = entry;
        var updated = attempt.copyWith(
          quarantineReleaseDraft: draft.copyWith(
            entries: entries,
            updatedAt: now,
          ),
        );
        updated = _appendDraftAction(
          updated,
          stageId: 'exception-handling',
          taskId: 'request-quarantine-release',
          actionType: ActionType.releaseDecisionUpdated,
          targetId: entry.cartonId,
          payload: _releaseDecisionPayload(entry),
        );
        await _commit(current, updated);
      },
      onSuccess: () => UpdateReleaseDecisionResult.success,
      onFailure: () => UpdateReleaseDecisionResult.persistenceFailure,
    );
  }

  Future<RemoveReleaseDecisionResult> removeReleaseDecision(
    RemoveReleaseDecisionCommand command,
  ) async {
    final active = _activeAttempt();
    if (active == null) return RemoveReleaseDecisionResult.invalidAttemptState;
    final (current, attempt) = active;
    final draft = attempt.quarantineReleaseDraft;
    if (draft == null) return RemoveReleaseDecisionResult.entryNotFound;
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return RemoveReleaseDecisionResult.alreadySubmitted;
    }
    drafts.QuarantineReleaseEntry? entry;
    for (final item in draft.entries) {
      if (item.id == command.entryId) entry = item;
    }
    if (entry == null) return RemoveReleaseDecisionResult.entryNotFound;
    return _tryPersist(
      () async {
        final now = DateTime.now();
        var updated = attempt.copyWith(
          quarantineReleaseDraft: draft.copyWith(
            entries: draft.entries
                .where((item) => item.id != command.entryId)
                .toList(growable: false),
            updatedAt: now,
          ),
        );
        updated = _appendDraftAction(
          updated,
          stageId: 'exception-handling',
          taskId: 'request-quarantine-release',
          actionType: ActionType.releaseDecisionRemoved,
          targetId: entry!.cartonId,
          payload: {
            'entryId': entry.id,
            'revisionNumber': entry.revisionNumber + 1,
          },
        );
        await _commit(current, updated);
      },
      onSuccess: () => RemoveReleaseDecisionResult.success,
      onFailure: () => RemoveReleaseDecisionResult.persistenceFailure,
    );
  }

  Future<SaveQuarantineReleaseDraftResult> saveQuarantineReleaseDraft(
    SaveQuarantineReleaseDraftCommand command,
  ) async {
    final active = _activeAttempt();
    if (active == null) {
      return SaveQuarantineReleaseDraftResult.invalidAttemptState;
    }
    final (current, attempt) = active;
    final draft =
        attempt.quarantineReleaseDraft ?? _newQuarantineReleaseDraft(attempt);
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return SaveQuarantineReleaseDraftResult.alreadySubmitted;
    }
    return _tryPersist(
      () async {
        final updated = _withAudit(
          attempt.copyWith(quarantineReleaseDraft: draft),
          AttemptAuditEventType.releaseDecisionsDraftSaved,
          screenId: 'quarantine-zone',
          payload: {'entryCount': draft.entries.length},
        );
        await _commit(current, updated);
      },
      onSuccess: () => SaveQuarantineReleaseDraftResult.success,
      onFailure: () => SaveQuarantineReleaseDraftResult.persistenceFailure,
    );
  }

  Future<SubmitQuarantineReleaseResult> submitQuarantineRelease(
    SubmitQuarantineReleaseCommand command,
  ) async {
    final active = _activeAttemptWithScenario();
    if (active == null) {
      return SubmitQuarantineReleaseResult.invalidAttemptState;
    }
    final (current, attempt, scenario) = active;
    if (!attempt.completedTaskIds.contains('confirm-quarantine')) {
      return SubmitQuarantineReleaseResult.quarantineNotConfirmed;
    }
    // No new draft is forced into existence when nothing is held -- an
    // attempt with zero quarantined/held cartons has nothing to recommend,
    // and the completeness check below is trivially satisfied (0 == 0).
    final draft =
        attempt.quarantineReleaseDraft ?? _newQuarantineReleaseDraft(attempt);
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return SubmitQuarantineReleaseResult.alreadySubmitted;
    }
    final heldCartonIds = _heldCartonIds(attempt);
    if (draft.entries.length != heldCartonIds.length ||
        !heldCartonIds.every(
          (id) => draft.entries.any((entry) => entry.cartonId == id),
        )) {
      return SubmitQuarantineReleaseResult.incompleteReleaseDecisions;
    }
    return _tryPersist(
      () async {
        var working = _withAudit(
          attempt,
          AttemptAuditEventType.releaseDecisionsSubmissionRequested,
          screenId: 'quarantine-zone',
          payload: {'entryCount': draft.entries.length},
        );
        var outcomes = [...current.outcomes];
        for (final entry in draft.entries) {
          (working, outcomes) = _applyAction(
            current,
            working,
            outcomes,
            _newAction(
              working,
              stageId: 'exception-handling',
              taskId: 'request-quarantine-release',
              actionType: ActionType.selectReleaseDecision,
              targetId: entry.cartonId,
              payload: {
                'releaseDecision': entry.decision.wireName,
                'justification': entry.justification,
              },
            ),
            scenario,
          );
        }
        // Cartons that were never quarantined or held still need a scored
        // action recorded against every task.targetResourceIds entry --
        // MissionProgressService's repeatable-task completion check counts
        // distinct actioned targets against the task's full static target
        // list, not the dynamic held subset the candidate actually chose
        // from. Recorded automatically, never surfaced to or editable by
        // the candidate; see ReleaseDecision.notApplicable's doc comment.
        final allTargets = current.mission
            .task('request-quarantine-release')
            .targetResourceIds;
        for (final cartonId in allTargets) {
          if (heldCartonIds.contains(cartonId)) continue;
          (working, outcomes) = _applyAction(
            current,
            working,
            outcomes,
            _newAction(
              working,
              stageId: 'exception-handling',
              taskId: 'request-quarantine-release',
              actionType: ActionType.selectReleaseDecision,
              targetId: cartonId,
              payload: {
                'releaseDecision': ReleaseDecision.notApplicable.wireName,
                'justification':
                    'Not quarantined or held -- no release decision needed.',
              },
            ),
            scenario,
          );
        }
        final now = DateTime.now();
        working = working.copyWith(
          quarantineReleaseDraft: draft.copyWith(
            status: drafts.OperationalDraftStatus.submitted,
            updatedAt: now,
            submittedAt: now,
          ),
        );
        working = _withAudit(
          working,
          AttemptAuditEventType.releaseDecisionsSaved,
          screenId: 'quarantine-zone',
          payload: {'entryCount': draft.entries.length},
        );
        await _commit(current, working, outcomes: outcomes);
      },
      onSuccess: () => SubmitQuarantineReleaseResult.success,
      onFailure: () => SubmitQuarantineReleaseResult.persistenceFailure,
      onCaught: () => _recordWorkplaceEvent(
        AttemptAuditEventType.releaseDecisionsSaveFailed,
        screenId: 'quarantine-zone',
      ),
    );
  }

  Future<SetDiscrepancyReportFlagsResult> setDiscrepancyReportFlags(
    SetDiscrepancyReportFlagsCommand command,
  ) async {
    final current = state.valueOrNull;
    final attempt = current?.attempt;
    if (current == null ||
        attempt == null ||
        attempt.state != MissionState.inProgress) {
      return SetDiscrepancyReportFlagsResult.invalidAttemptState;
    }
    final draft =
        attempt.discrepancyReportDraft ?? _newDiscrepancyReportDraft(attempt);
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return SetDiscrepancyReportFlagsResult.alreadySubmitted;
    }
    try {
      final now = DateTime.now();
      final updatedDraft = draft.copyWith(
        shortageRecorded: command.shortageRecorded,
        unauthorizedSkuRecorded: command.unauthorizedSkuRecorded,
        damageRecorded: command.damageRecorded,
        barcodeIssueRecorded: command.barcodeIssueRecorded,
        nearExpiryRecorded: command.nearExpiryRecorded,
        updatedAt: now,
      );
      // complete-discrepancy-report is non-repeatable: unlike the
      // repeatable per-carton drafts (inspection, dispositions), draft
      // edits here must NOT append a LearnerAction against this taskId --
      // task_validation_service forbids a second action on a non-repeatable
      // task regardless of whether the first was a draft edit, which would
      // permanently block the real complete_form submission below. An
      // audit event (not a LearnerAction) is sufficient for a save-draft
      // trail here.
      final updated = _withAudit(
        attempt.copyWith(discrepancyReportDraft: updatedDraft),
        AttemptAuditEventType.discrepancyReportFlagsSaved,
        screenId: 'receiving-office',
        payload: {
          'shortageRecorded': updatedDraft.shortageRecorded,
          'unauthorizedSkuRecorded': updatedDraft.unauthorizedSkuRecorded,
          'damageRecorded': updatedDraft.damageRecorded,
          'barcodeIssueRecorded': updatedDraft.barcodeIssueRecorded,
          'nearExpiryRecorded': updatedDraft.nearExpiryRecorded,
        },
      );
      await _commit(current, updated);
      return SetDiscrepancyReportFlagsResult.success;
    } catch (_) {
      return SetDiscrepancyReportFlagsResult.persistenceFailure;
    }
  }

  Future<SubmitDiscrepancyReportResult> submitDiscrepancyReport(
    SubmitDiscrepancyReportCommand command,
  ) async {
    final current = state.valueOrNull;
    var attempt = current?.attempt;
    final scenario = current?.scenario;
    if (current == null ||
        attempt == null ||
        scenario == null ||
        attempt.state != MissionState.inProgress) {
      return SubmitDiscrepancyReportResult.invalidAttemptState;
    }
    var working = attempt;
    final draft =
        working.discrepancyReportDraft ?? _newDiscrepancyReportDraft(working);
    if (draft.status == drafts.OperationalDraftStatus.submitted) {
      return SubmitDiscrepancyReportResult.alreadySubmitted;
    }
    try {
      working = _withAudit(
        working,
        AttemptAuditEventType.discrepancyReportSubmissionRequested,
        screenId: 'receiving-office',
      );
      var outcomes = [...current.outcomes];
      (working, outcomes) = _applyAction(
        current,
        working,
        outcomes,
        _newAction(
          working,
          stageId: 'receiving-decision',
          taskId: 'complete-discrepancy-report',
          actionType: ActionType.completeForm,
          targetId: 'receiving-discrepancy-report',
          payload: {
            'poNumber': current.mission.briefing.purchaseOrderNumber,
            'shortageRecorded': draft.shortageRecorded,
            'unauthorizedSkuRecorded': draft.unauthorizedSkuRecorded,
            'damageRecorded': draft.damageRecorded,
            'barcodeIssueRecorded': draft.barcodeIssueRecorded,
            'nearExpiryRecorded': draft.nearExpiryRecorded,
          },
        ),
        scenario,
      );
      final now = DateTime.now();
      working = working.copyWith(
        discrepancyReportDraft: draft.copyWith(
          status: drafts.OperationalDraftStatus.submitted,
          updatedAt: now,
          submittedAt: now,
        ),
      );
      working = _withAudit(
        working,
        AttemptAuditEventType.discrepancyReportSaved,
        screenId: 'receiving-office',
      );
      await _commit(current, working, outcomes: outcomes);
      return SubmitDiscrepancyReportResult.success;
    } catch (_) {
      await _recordWorkplaceEvent(
        AttemptAuditEventType.discrepancyReportSaveFailed,
        screenId: 'receiving-office',
      );
      return SubmitDiscrepancyReportResult.persistenceFailure;
    }
  }

  Future<SelectReceivingDecisionResult> selectReceivingDecision(
    SelectReceivingDecisionCommand command,
  ) async {
    final current = state.valueOrNull;
    var attempt = current?.attempt;
    final scenario = current?.scenario;
    if (current == null ||
        attempt == null ||
        scenario == null ||
        attempt.state != MissionState.inProgress) {
      return SelectReceivingDecisionResult.invalidAttemptState;
    }
    if (attempt.discrepancyReportDraft?.status !=
        drafts.OperationalDraftStatus.submitted) {
      return SelectReceivingDecisionResult.discrepancyReportNotSubmitted;
    }
    if (attempt.completedTaskIds.contains('make-receiving-decision')) {
      return SelectReceivingDecisionResult.alreadyDecided;
    }
    try {
      var working = attempt;
      var outcomes = [...current.outcomes];
      (working, outcomes) = _applyAction(
        current,
        working,
        outcomes,
        _newAction(
          working,
          stageId: 'receiving-decision',
          taskId: 'make-receiving-decision',
          actionType: ActionType.makeDecision,
          targetId: 'receiving-discrepancy-report',
          payload: {'decision': command.decision.wireName},
        ),
        scenario,
      );
      working = _withAudit(
        working,
        AttemptAuditEventType.receivingDecisionSelected,
        screenId: 'receiving-office',
        payload: {'decision': command.decision.wireName},
      );
      await _commit(current, working, outcomes: outcomes);
      return SelectReceivingDecisionResult.success;
    } catch (_) {
      await _recordWorkplaceEvent(
        AttemptAuditEventType.receivingDecisionFailed,
        screenId: 'receiving-office',
      );
      return SelectReceivingDecisionResult.persistenceFailure;
    }
  }

  Future<NotifySupervisorResult> notifySupervisor(
    NotifySupervisorCommand command,
  ) async {
    final current = state.valueOrNull;
    var attempt = current?.attempt;
    final scenario = current?.scenario;
    if (current == null ||
        attempt == null ||
        scenario == null ||
        attempt.state != MissionState.inProgress) {
      return NotifySupervisorResult.invalidAttemptState;
    }
    if (!attempt.actions.any(
      (action) => action.taskId == 'make-receiving-decision',
    )) {
      // A decision must have been attempted, but need not have scored
      // correct: the learner must always be able to finish the shift and
      // see feedback, even after a wrong call. Scoring reflects the
      // incorrect decision separately via mandatoryTasksCompleted/status.
      return NotifySupervisorResult.decisionNotMade;
    }
    if (attempt.completedTaskIds.contains('notify-supervisor')) {
      return NotifySupervisorResult.alreadyNotified;
    }
    try {
      var working = attempt;
      var outcomes = [...current.outcomes];
      working = _withAudit(
        working,
        AttemptAuditEventType.supervisorNotificationRequested,
        screenId: 'receiving-office',
      );
      (working, outcomes) = _applyAction(
        current,
        working,
        outcomes,
        _newAction(
          working,
          stageId: 'shift-report',
          taskId: 'notify-supervisor',
          actionType: ActionType.confirmAction,
          targetId: 'supervisor-notification',
          payload: {'supervisorNotified': true, 'auditTrailIncluded': true},
        ),
        scenario,
      );
      working = _withAudit(
        working,
        AttemptAuditEventType.supervisorNotified,
        screenId: 'receiving-office',
      );
      await _commit(current, working, outcomes: outcomes);
      return NotifySupervisorResult.success;
    } catch (_) {
      await _recordWorkplaceEvent(
        AttemptAuditEventType.supervisorNotificationFailed,
        screenId: 'receiving-office',
      );
      return NotifySupervisorResult.persistenceFailure;
    }
  }

  Future<CompleteMissionResult> completeMission({
    String screenId = 'receiving-office',
  }) async {
    final current = state.valueOrNull;
    final attempt = current?.attempt;
    if (current == null ||
        attempt == null ||
        attempt.state != MissionState.inProgress) {
      return CompleteMissionResult.invalidAttemptState;
    }
    final failure = await submit();
    if (failure != null) return CompleteMissionResult.persistenceFailure;
    await _recordWorkplaceEvent(
      AttemptAuditEventType.missionSubmitted,
      screenId: screenId,
    );
    return CompleteMissionResult.success;
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
      shipmentConfirmed: null,
      countEntries: const [],
      status: drafts.OperationalDraftStatus.draft,
      createdAt: now,
      updatedAt: now,
    );
  }

  drafts.InspectionDraft _newInspectionDraft(SimulationAttempt attempt) {
    final now = DateTime.now();
    return drafts.InspectionDraft(
      attemptId: attempt.id,
      cartonInspections: const [],
      status: drafts.OperationalDraftStatus.draft,
      createdAt: now,
      updatedAt: now,
    );
  }

  drafts.BarcodeScanDraft _newBarcodeScanDraft(SimulationAttempt attempt) {
    final now = DateTime.now();
    return drafts.BarcodeScanDraft(
      attemptId: attempt.id,
      entries: const [],
      status: drafts.OperationalDraftStatus.draft,
      createdAt: now,
      updatedAt: now,
    );
  }

  drafts.DispositionDraft _newDispositionDraft(SimulationAttempt attempt) {
    final now = DateTime.now();
    return drafts.DispositionDraft(
      attemptId: attempt.id,
      entries: const [],
      status: drafts.OperationalDraftStatus.draft,
      createdAt: now,
      updatedAt: now,
    );
  }

  drafts.QuarantineReleaseDraft _newQuarantineReleaseDraft(
    SimulationAttempt attempt,
  ) {
    final now = DateTime.now();
    return drafts.QuarantineReleaseDraft(
      attemptId: attempt.id,
      entries: const [],
      status: drafts.OperationalDraftStatus.draft,
      createdAt: now,
      updatedAt: now,
    );
  }

  drafts.DiscrepancyReportDraft _newDiscrepancyReportDraft(
    SimulationAttempt attempt,
  ) {
    final now = DateTime.now();
    return drafts.DiscrepancyReportDraft(
      attemptId: attempt.id,
      status: drafts.OperationalDraftStatus.draft,
      createdAt: now,
      updatedAt: now,
    );
  }

  JsonMap _dispositionPayload(drafts.DispositionEntry entry) => {
    'entryId': entry.id,
    'disposition': entry.disposition.wireName,
    'reason': entry.reason,
    'revisionNumber': entry.revisionNumber,
  };

  JsonMap _releaseDecisionPayload(drafts.QuarantineReleaseEntry entry) => {
    'entryId': entry.id,
    'decision': entry.decision.wireName,
    'justification': entry.justification,
    'revisionNumber': entry.revisionNumber,
  };

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

  JsonMap _inspectionPayload(drafts.CartonInspectionEntry entry) => {
    'entryId': entry.id,
    'findings': entry.findings.map((item) => item.wireName).toList(),
    'learnerNotes': entry.learnerNotes,
    'revisionNumber': entry.revisionNumber,
  };

  /// Findings must be non-empty, contain no duplicates, and never mix
  /// [drafts.CartonFinding.compliant] with another finding on the same
  /// carton.
  bool _validFindings(List<drafts.CartonFinding> findings) {
    if (findings.isEmpty) return false;
    final unique = findings.toSet();
    if (unique.length != findings.length) return false;
    if (unique.contains(drafts.CartonFinding.compliant) && unique.length > 1) {
      return false;
    }
    return true;
  }

  JsonMap _scanPayload(drafts.BarcodeScanEntry entry) => {
    'entryId': entry.id,
    'status': entry.status.name,
    'revisionNumber': entry.revisionNumber,
    'scanAttempts': entry.scanAttempts,
    'resolutionMethod': entry.resolutionMethod.name,
    if (entry.manualCode != null) 'manualCode': entry.manualCode,
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
      status: status,
      isRecommended: recommended,
      progressLabel: label,
      supportingText: status == WorkstationStatus.locked
          ? _workstations.lockedReason(station, current.mission)
          : station.description,
    );
  }

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

  /// The (state, in-progress attempt) pair every draft record/update/remove/
  /// save-draft command requires, or null if there isn't one. Replaces the
  /// same four-line guard repeated at the top of every one of those methods.
  (WorkplaceSimulationState, SimulationAttempt)? _activeAttempt() {
    final current = state.valueOrNull;
    final attempt = current?.attempt;
    if (current == null ||
        attempt == null ||
        attempt.state != MissionState.inProgress) {
      return null;
    }
    return (current, attempt);
  }

  /// As [_activeAttempt], for the submit-time methods that also need the
  /// generated scenario to evaluate actions against.
  (WorkplaceSimulationState, SimulationAttempt, GeneratedScenario)?
  _activeAttemptWithScenario() {
    final current = state.valueOrNull;
    final attempt = current?.attempt;
    final scenario = current?.scenario;
    if (current == null ||
        attempt == null ||
        scenario == null ||
        attempt.state != MissionState.inProgress) {
      return null;
    }
    return (current, attempt, scenario);
  }

  /// Runs a draft/submit mutation, mapping any thrown exception to
  /// [onFailure] instead of letting it propagate -- replaces the identical
  /// try/catch/persistenceFailure block at the end of every draft command.
  /// [onCaught] runs additional side effects (e.g. a failure audit event)
  /// before [onFailure] is returned, for the submit methods that need one.
  Future<TResult> _tryPersist<TResult>(
    Future<void> Function() action, {
    required TResult Function() onSuccess,
    required TResult Function() onFailure,
    Future<void> Function()? onCaught,
  }) async {
    try {
      await action();
      return onSuccess();
    } catch (_) {
      if (onCaught != null) await onCaught();
      return onFailure();
    }
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
