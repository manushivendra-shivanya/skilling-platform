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
import '../domain/simulation_content.dart';
import '../domain/simulation_enums.dart';
import '../domain/simulation_runtime.dart';
import 'workplace_simulation_state.dart';

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
      await ref.read(simulationAttemptRepositoryProvider).saveAttempt(attempt);
      attempt = await _appendAuditEvent(
        attempt,
        AttemptAuditEventType.attemptPaused,
        screenId: 'workplace',
      );
      state = AsyncData(current.copyWith(attempt: attempt));
    });
  }

  Future<AppFailure?> resumeAttempt({DateTime? at}) {
    return _guard(() async {
      final current = _requireState();
      final resumed = await _resumeTimer(
        _requireAttempt(current),
        at: at,
        screenId: 'workplace',
      );
      state = AsyncData(current.copyWith(attempt: resumed));
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
