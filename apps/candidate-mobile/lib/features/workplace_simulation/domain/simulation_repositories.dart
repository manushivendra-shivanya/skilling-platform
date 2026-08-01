import 'simulation_content.dart';
import 'simulation_runtime.dart';

abstract interface class SimulationContentRepository {
  Future<SimulationPack> getPack(String packId);

  Future<Workplace> getWorkplace(String workplaceId);

  Future<MissionDefinition> getMission(String missionId);

  Future<List<CompetencyDefinition>> getCompetencies(
    List<String> competencyIds,
  );

  Future<List<RemediationRecommendation>> getRemediation();
}

abstract interface class SimulationAttemptRepository {
  /// [generatedScenario] is the attempt's deterministic scenario snapshot
  /// (from `mission` + [scenarioSeed] + [scenarioId]), optional because only
  /// a remote-syncing implementation needs the raw generated JSON -- local
  /// storage can always regenerate it deterministically from the seed.
  Future<SimulationAttempt> createAttempt({
    required String candidateId,
    required String missionId,
    required String missionVersion,
    required int scenarioSeed,
    String? scenarioId,
    GeneratedScenario? generatedScenario,
  });

  Future<SimulationAttempt?> getActiveAttempt(
    String candidateId,
    String missionId,
  );

  Future<void> saveAttempt(SimulationAttempt attempt);

  /// Atomically persists an operational draft/submission together with its
  /// append-only actions, audit events and derived attempt progress.
  Future<void> commitOperationalUpdate(SimulationAttempt attempt);

  Future<SimulationAttempt> appendAction(LearnerAction action);

  Future<SimulationAttempt> appendAuditEvent(AttemptAuditEvent event);

  Future<SimulationAttempt> startShift({
    required SimulationAttempt startedAttempt,
    required AttemptAuditEvent requestedEvent,
    required AttemptAuditEvent startedEvent,
  });

  Future<void> saveResult(String candidateId, SimulationResult result);

  Future<SimulationResult?> getResult(String candidateId, String attemptId);

  /// Every result ever saved for this candidate on this mission, newest
  /// first -- the full local attempt history, not just the current attempt.
  /// A retake's result is appended, never replaces an earlier one.
  Future<List<SimulationResult>> listResults(
    String candidateId,
    String missionId,
  );

  Future<void> clearActiveAttempt(String candidateId, String missionId);

  /// Number of writes for this candidate still queued for remote sync.
  /// Always 0 for a local-only implementation -- there is no remote to be
  /// behind.
  Future<int> pendingSyncCount(String candidateId);

  /// Retries every queued write for this candidate. A no-op for a
  /// local-only implementation.
  Future<void> flushPendingSyncs(String candidateId);
}
