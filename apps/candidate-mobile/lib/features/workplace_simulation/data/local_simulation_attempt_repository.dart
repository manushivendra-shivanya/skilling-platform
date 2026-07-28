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
      state: MissionState.notStarted,
      startedAt: now,
      elapsedSeconds: 0,
      currentStageId: null,
      completedTaskIds: const {},
      actions: const [],
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
    }
    await _writeAttempt(attempt);
  }

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

  Future<void> _writeAttempt(SimulationAttempt attempt) async {
    _activeCache[attempt.id] = attempt;
    await _store.write(
      _activeKey(attempt.candidateId, attempt.missionId),
      jsonEncode(attempt.toJson()),
    );
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
  Future<void> clearActiveAttempt(String candidateId, String missionId) =>
      _delegate.clearActiveAttempt(candidateId, missionId);

  @override
  Future<SimulationAttempt> createAttempt({
    required String candidateId,
    required String missionId,
    required String missionVersion,
    required int scenarioSeed,
  }) => _delegate.createAttempt(
    candidateId: candidateId,
    missionId: missionId,
    missionVersion: missionVersion,
    scenarioSeed: scenarioSeed,
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
}
