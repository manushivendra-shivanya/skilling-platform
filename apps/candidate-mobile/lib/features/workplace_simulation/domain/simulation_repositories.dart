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
  Future<SimulationAttempt> createAttempt({
    required String candidateId,
    required String missionId,
    required String missionVersion,
    required int scenarioSeed,
  });

  Future<SimulationAttempt?> getActiveAttempt(
    String candidateId,
    String missionId,
  );

  Future<void> saveAttempt(SimulationAttempt attempt);

  Future<SimulationAttempt> appendAction(LearnerAction action);

  Future<SimulationAttempt> appendAuditEvent(AttemptAuditEvent event);

  Future<SimulationAttempt> startShift({
    required SimulationAttempt startedAttempt,
    required AttemptAuditEvent requestedEvent,
    required AttemptAuditEvent startedEvent,
  });

  Future<void> saveResult(String candidateId, SimulationResult result);

  Future<SimulationResult?> getResult(String candidateId, String attemptId);

  Future<void> clearActiveAttempt(String candidateId, String missionId);
}
