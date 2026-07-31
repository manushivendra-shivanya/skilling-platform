import '../domain/simulation_content.dart';
import '../domain/simulation_enums.dart';
import '../domain/simulation_runtime.dart';

class WorkplaceSimulationState {
  const WorkplaceSimulationState({
    required this.pack,
    required this.workplace,
    required this.mission,
    required this.competencies,
    required this.remediation,
    this.attempt,
    this.scenario,
    this.outcomes = const [],
    this.result,
    this.pendingSyncCount = 0,
  });

  final SimulationPack pack;
  final Workplace workplace;
  final MissionDefinition mission;
  final List<CompetencyDefinition> competencies;
  final List<RemediationRecommendation> remediation;
  final SimulationAttempt? attempt;
  final GeneratedScenario? scenario;
  final List<ActionOutcome> outcomes;
  final SimulationResult? result;

  /// Number of this candidate's WMS writes still queued for remote sync.
  /// Always 0 when the app isn't configured for remote sync, or once every
  /// queued write has been flushed.
  final int pendingSyncCount;

  bool get canContinue =>
      attempt != null &&
      result == null &&
      attempt!.state != MissionState.completed &&
      attempt!.state != MissionState.failed;

  WorkplaceSimulationState copyWith({
    SimulationAttempt? attempt,
    GeneratedScenario? scenario,
    List<ActionOutcome>? outcomes,
    SimulationResult? result,
    bool clearResult = false,
    int? pendingSyncCount,
  }) => WorkplaceSimulationState(
    pack: pack,
    workplace: workplace,
    mission: mission,
    competencies: competencies,
    remediation: remediation,
    attempt: attempt ?? this.attempt,
    scenario: scenario ?? this.scenario,
    outcomes: outcomes ?? this.outcomes,
    result: clearResult ? null : result ?? this.result,
    pendingSyncCount: pendingSyncCount ?? this.pendingSyncCount,
  );
}
