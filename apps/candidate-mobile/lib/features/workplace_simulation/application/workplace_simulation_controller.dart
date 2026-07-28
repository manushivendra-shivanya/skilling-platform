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
            scenarioSeed: scenarioSeed ?? current.mission.scenario.defaultSeed,
          );
      final briefing = _stateService.transition(attempt, MissionState.briefing);
      await ref.read(simulationAttemptRepositoryProvider).saveAttempt(briefing);
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

  Future<AppFailure?> beginShift() => _transition(
    MissionState.inProgress,
    currentStageId: 'document-verification',
  );

  Future<AppFailure?> pause() => _transition(MissionState.paused);

  Future<AppFailure?> resume() => _transition(MissionState.inProgress);

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
        simulationTimeSeconds: simulationTimeSeconds ?? attempt.elapsedSeconds,
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
      attempt = _stateService.transition(attempt, MissionState.submitted);
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
    });
  }

  double get progress {
    final current = state.valueOrNull;
    final attempt = current?.attempt;
    if (current == null || attempt == null) return 0;
    return _progress.progress(current.mission, attempt);
  }

  Future<AppFailure?> _transition(MissionState next, {String? currentStageId}) {
    return _guard(() async {
      final current = _requireState();
      final attempt = _stateService
          .transition(_requireAttempt(current), next)
          .copyWith(currentStageId: currentStageId);
      await ref.read(simulationAttemptRepositoryProvider).saveAttempt(attempt);
      state = AsyncData(current.copyWith(attempt: attempt));
    });
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
