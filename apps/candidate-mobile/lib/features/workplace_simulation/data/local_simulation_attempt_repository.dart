import 'dart:convert';

import '../../../core/storage/secure_key_value_store.dart';
import '../domain/simulation_content.dart';
import '../domain/simulation_enums.dart';
import '../domain/simulation_repositories.dart';
import '../domain/simulation_runtime.dart';

class LocalSimulationAttemptRepository implements SimulationAttemptRepository {
  LocalSimulationAttemptRepository(this._store, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final SecureKeyValueStore _store;
  final DateTime Function() _clock;

  @override
  Future<SimulationAttempt> createAttempt({
    required String candidateId,
    required String missionId,
    required String missionVersion,
    required int scenarioSeed,
    String? scenarioId,
    GeneratedScenario? generatedScenario,
  }) async {
    final counterKey = _counterKey(candidateId, missionId);
    final attemptNumber =
        int.tryParse(await _store.read(counterKey) ?? '') ?? 0;
    final nextNumber = attemptNumber + 1;
    final now = _clock();
    final attempt = SimulationAttempt(
      id: '$missionId-${now.microsecondsSinceEpoch}-$nextNumber',
      candidateId: candidateId,
      missionId: missionId,
      missionVersion: missionVersion,
      attemptNumber: nextNumber,
      scenarioSeed: scenarioSeed,
      scenarioId: scenarioId,
      state: MissionState.notStarted,
      createdAt: now,
      shiftStartedAt: null,
      briefingAcknowledgedAt: null,
      pausedAt: null,
      timerResumedAt: null,
      elapsedSimulationSeconds: 0,
      timerStatus: SimulationTimerStatus.notStarted,
      currentStageId: null,
      completedTaskIds: const {},
      actions: const [],
      auditEvents: const [],
    );
    await _store.write(counterKey, '$nextNumber');
    await _writeAttempt(attempt);
    return attempt;
  }

  @override
  Future<SimulationAttempt?> getActiveAttempt(
    String candidateId,
    String missionId,
  ) async {
    final encoded = await _store.read(_activeKey(candidateId, missionId));
    if (encoded == null) return null;
    final decoded = jsonDecode(encoded);
    if (decoded is! JsonMap) {
      throw const FormatException('Invalid local simulation attempt');
    }
    final attempt = SimulationAttempt.fromJson(decoded);
    if (attempt.candidateId != candidateId || attempt.missionId != missionId) {
      throw StateError('Local simulation attempt ownership mismatch');
    }
    _activeCache[attempt.id] = attempt;
    return attempt;
  }

  @override
  Future<void> saveAttempt(SimulationAttempt attempt) async {
    final existing = await getActiveAttempt(
      attempt.candidateId,
      attempt.missionId,
    );
    if (existing != null) {
      if (existing.id != attempt.id ||
          attempt.actions.length < existing.actions.length) {
        throw StateError('An active attempt cannot be replaced');
      }
      for (var index = 0; index < existing.actions.length; index++) {
        if (jsonEncode(existing.actions[index].toJson()) !=
            jsonEncode(attempt.actions[index].toJson())) {
          throw StateError('Learner actions are append-only');
        }
      }
      if (existing.shiftStartedAt != null &&
          (attempt.shiftStartedAt == null ||
              !attempt.shiftStartedAt!.isAtSameMomentAs(
                existing.shiftStartedAt!,
              ))) {
        throw StateError('The shift start time cannot be overwritten');
      }
      if (attempt.auditEvents.length < existing.auditEvents.length) {
        throw StateError('Attempt audit events are append-only');
      }
      for (var index = 0; index < existing.auditEvents.length; index++) {
        if (jsonEncode(existing.auditEvents[index].toJson()) !=
            jsonEncode(attempt.auditEvents[index].toJson())) {
          throw StateError('Attempt audit events are append-only');
        }
      }
    }
    await _writeAttempt(attempt);
  }

  @override
  Future<void> commitOperationalUpdate(SimulationAttempt attempt) =>
      saveAttempt(attempt);

  @override
  Future<SimulationAttempt> appendAction(LearnerAction action) async {
    final active = await getActiveAttemptForAction(action);
    if (action.sequenceNumber != active.actions.length + 1) {
      throw const FormatException(
        'Learner actions must use continuous sequence numbers',
      );
    }
    if (active.actions.any((item) => item.id == action.id)) {
      throw StateError('Learner action IDs must be unique');
    }
    final updated = active.copyWith(actions: [...active.actions, action]);
    await _writeAttempt(updated);
    return updated;
  }

  @override
  Future<SimulationAttempt> appendAuditEvent(AttemptAuditEvent event) async {
    final active = _activeCache[event.attemptId];
    if (active == null) {
      throw StateError('No active attempt exists for this audit event');
    }
    if (event.sequenceNumber != active.auditEvents.length + 1) {
      throw const FormatException(
        'Audit events must use continuous sequence numbers',
      );
    }
    if (active.auditEvents.any((item) => item.id == event.id)) {
      throw StateError('Audit event IDs must be unique');
    }
    final updated = active.copyWith(
      auditEvents: [...active.auditEvents, event],
    );
    await _writeAttempt(updated);
    return updated;
  }

  @override
  Future<SimulationAttempt> startShift({
    required SimulationAttempt startedAttempt,
    required AttemptAuditEvent requestedEvent,
    required AttemptAuditEvent startedEvent,
  }) async {
    final active = await getActiveAttempt(
      startedAttempt.candidateId,
      startedAttempt.missionId,
    );
    if (active == null || active.id != startedAttempt.id) {
      throw StateError('The active attempt changed before shift start');
    }
    if (active.state != MissionState.briefing ||
        active.shiftStartedAt != null ||
        active.timerStatus != SimulationTimerStatus.notStarted) {
      throw StateError('The active attempt is not ready to start');
    }
    final nextSequence = active.auditEventCount + 1;
    if (requestedEvent.attemptId != active.id ||
        startedEvent.attemptId != active.id ||
        requestedEvent.sequenceNumber != nextSequence ||
        startedEvent.sequenceNumber != nextSequence + 1 ||
        requestedEvent.eventType != AttemptAuditEventType.shiftStartRequested ||
        startedEvent.eventType != AttemptAuditEventType.shiftStarted) {
      throw const FormatException('Invalid atomic shift-start audit events');
    }
    final persisted = startedAttempt.copyWith(
      auditEvents: [...active.auditEvents, requestedEvent, startedEvent],
    );
    await _writeAttempt(persisted);
    return persisted;
  }

  Future<SimulationAttempt> getActiveAttemptForAction(
    LearnerAction action,
  ) async {
    // Candidate identity is deliberately absent from action payloads. The
    // controller restores the candidate-owned active attempt before appending.
    final cached = _activeCache[action.attemptId];
    if (cached == null) {
      throw StateError('No active attempt exists for this action');
    }
    return cached;
  }

  final Map<String, SimulationAttempt> _activeCache = {};

  @override
  Future<void> saveResult(String candidateId, SimulationResult result) async {
    await _store.write(
      _resultKey(candidateId, result.attemptId),
      jsonEncode(result.toJson()),
    );
  }

  @override
  Future<SimulationResult?> getResult(
    String candidateId,
    String attemptId,
  ) async {
    final encoded = await _store.read(_resultKey(candidateId, attemptId));
    if (encoded == null) return null;
    final decoded = jsonDecode(encoded);
    if (decoded is! JsonMap) {
      throw const FormatException('Invalid local simulation result');
    }
    return SimulationResult.fromJson(decoded);
  }

  @override
  Future<void> clearActiveAttempt(String candidateId, String missionId) async {
    final attempt = await getActiveAttempt(candidateId, missionId);
    if (attempt != null) _activeCache.remove(attempt.id);
    await _store.remove(_activeKey(candidateId, missionId));
  }

  @override
  Future<int> pendingSyncCount(String candidateId) async => 0;

  @override
  Future<void> flushPendingSyncs(String candidateId) async {}

  Future<void> _writeAttempt(SimulationAttempt attempt) async {
    await _store.write(
      _activeKey(attempt.candidateId, attempt.missionId),
      jsonEncode(attempt.toJson()),
    );
    _activeCache[attempt.id] = attempt;
  }

  String _activeKey(String candidateId, String missionId) =>
      'candidate.wms.active.v1.${_safe(candidateId)}.${_safe(missionId)}';

  String _counterKey(String candidateId, String missionId) =>
      'candidate.wms.counter.v1.${_safe(candidateId)}.${_safe(missionId)}';

  String _resultKey(String candidateId, String attemptId) =>
      'candidate.wms.result.v1.${_safe(candidateId)}.${_safe(attemptId)}';

  String _safe(String value) => value.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
}

class InMemorySimulationAttemptRepository
    implements SimulationAttemptRepository {
  InMemorySimulationAttemptRepository({DateTime Function()? clock})
    : _delegate = LocalSimulationAttemptRepository(
        InMemorySecureKeyValueStore(),
        clock: clock,
      );

  final LocalSimulationAttemptRepository _delegate;

  @override
  Future<SimulationAttempt> appendAction(LearnerAction action) =>
      _delegate.appendAction(action);

  @override
  Future<SimulationAttempt> appendAuditEvent(AttemptAuditEvent event) =>
      _delegate.appendAuditEvent(event);

  @override
  Future<void> commitOperationalUpdate(SimulationAttempt attempt) =>
      _delegate.commitOperationalUpdate(attempt);

  @override
  Future<SimulationAttempt> startShift({
    required SimulationAttempt startedAttempt,
    required AttemptAuditEvent requestedEvent,
    required AttemptAuditEvent startedEvent,
  }) => _delegate.startShift(
    startedAttempt: startedAttempt,
    requestedEvent: requestedEvent,
    startedEvent: startedEvent,
  );

  @override
  Future<void> clearActiveAttempt(String candidateId, String missionId) =>
      _delegate.clearActiveAttempt(candidateId, missionId);

  @override
  Future<SimulationAttempt> createAttempt({
    required String candidateId,
    required String missionId,
    required String missionVersion,
    required int scenarioSeed,
    String? scenarioId,
    GeneratedScenario? generatedScenario,
  }) => _delegate.createAttempt(
    candidateId: candidateId,
    missionId: missionId,
    missionVersion: missionVersion,
    scenarioSeed: scenarioSeed,
    scenarioId: scenarioId,
    generatedScenario: generatedScenario,
  );

  @override
  Future<SimulationAttempt?> getActiveAttempt(
    String candidateId,
    String missionId,
  ) => _delegate.getActiveAttempt(candidateId, missionId);

  @override
  Future<SimulationResult?> getResult(String candidateId, String attemptId) =>
      _delegate.getResult(candidateId, attemptId);

  @override
  Future<void> saveAttempt(SimulationAttempt attempt) =>
      _delegate.saveAttempt(attempt);

  @override
  Future<void> saveResult(String candidateId, SimulationResult result) =>
      _delegate.saveResult(candidateId, result);

  @override
  Future<int> pendingSyncCount(String candidateId) =>
      _delegate.pendingSyncCount(candidateId);

  @override
  Future<void> flushPendingSyncs(String candidateId) =>
      _delegate.flushPendingSyncs(candidateId);
}
