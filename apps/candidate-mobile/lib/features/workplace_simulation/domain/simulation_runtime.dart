import 'simulation_content.dart';
import 'simulation_enums.dart';

class GeneratedScenario {
  const GeneratedScenario({
    required this.missionId,
    required this.missionVersion,
    required this.seed,
    required this.resources,
  });

  final String missionId;
  final String missionVersion;
  final int seed;
  final List<SimulationResource> resources;

  SimulationResource resource(String id) =>
      resources.firstWhere((item) => item.id == id);

  JsonMap toJson() => {
    'missionId': missionId,
    'missionVersion': missionVersion,
    'seed': seed,
    'resources': [
      for (final resource in resources)
        {
          'id': resource.id,
          'missionId': resource.missionId,
          'resourceType': resource.resourceType.wireName,
          'title': resource.title,
          'content': resource.content,
          'issues': resource.issues.map((item) => item.toJson()).toList(),
        },
    ],
  };

  factory GeneratedScenario.fromJson(JsonMap json) => GeneratedScenario(
    missionId: json.string('missionId'),
    missionVersion: json.string('missionVersion'),
    seed: json.integer('seed'),
    resources: json
        .mapList('resources')
        .map(SimulationResource.fromJson)
        .toList(growable: false),
  );
}

class SimulationAttempt {
  const SimulationAttempt({
    required this.id,
    required this.candidateId,
    required this.missionId,
    required this.missionVersion,
    required this.attemptNumber,
    required this.scenarioSeed,
    required this.state,
    required this.startedAt,
    required this.elapsedSeconds,
    required this.currentStageId,
    required this.completedTaskIds,
    required this.actions,
    this.submittedAt,
    this.completedAt,
  });

  final String id;
  final String candidateId;
  final String missionId;
  final String missionVersion;
  final int attemptNumber;
  final int scenarioSeed;
  final MissionState state;
  final DateTime startedAt;
  final DateTime? submittedAt;
  final DateTime? completedAt;
  final int elapsedSeconds;
  final String? currentStageId;
  final Set<String> completedTaskIds;
  final List<LearnerAction> actions;

  int get actionCount => actions.length;

  SimulationAttempt copyWith({
    MissionState? state,
    DateTime? submittedAt,
    DateTime? completedAt,
    int? elapsedSeconds,
    String? currentStageId,
    bool clearCurrentStage = false,
    Set<String>? completedTaskIds,
    List<LearnerAction>? actions,
  }) => SimulationAttempt(
    id: id,
    candidateId: candidateId,
    missionId: missionId,
    missionVersion: missionVersion,
    attemptNumber: attemptNumber,
    scenarioSeed: scenarioSeed,
    state: state ?? this.state,
    startedAt: startedAt,
    submittedAt: submittedAt ?? this.submittedAt,
    completedAt: completedAt ?? this.completedAt,
    elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    currentStageId: clearCurrentStage
        ? null
        : currentStageId ?? this.currentStageId,
    completedTaskIds: completedTaskIds ?? this.completedTaskIds,
    actions: actions ?? this.actions,
  );

  JsonMap toJson() => {
    'id': id,
    'candidateId': candidateId,
    'missionId': missionId,
    'missionVersion': missionVersion,
    'attemptNumber': attemptNumber,
    'scenarioSeed': scenarioSeed,
    'state': state.wireName,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'submittedAt': submittedAt?.toUtc().toIso8601String(),
    'completedAt': completedAt?.toUtc().toIso8601String(),
    'elapsedSeconds': elapsedSeconds,
    'currentStageId': currentStageId,
    'completedTaskIds': completedTaskIds.toList(),
    'actions': actions.map((item) => item.toJson()).toList(),
  };

  factory SimulationAttempt.fromJson(JsonMap json) => SimulationAttempt(
    id: json.string('id'),
    candidateId: json.string('candidateId'),
    missionId: json.string('missionId'),
    missionVersion: json.string('missionVersion'),
    attemptNumber: json.integer('attemptNumber'),
    scenarioSeed: json.integer('scenarioSeed'),
    state: MissionState.fromWireName(json.string('state')),
    startedAt: DateTime.parse(json.string('startedAt')),
    submittedAt: _optionalDate(json.optionalString('submittedAt')),
    completedAt: _optionalDate(json.optionalString('completedAt')),
    elapsedSeconds: json.integer('elapsedSeconds'),
    currentStageId: json.optionalString('currentStageId'),
    completedTaskIds: json.stringList('completedTaskIds').toSet(),
    actions: json
        .mapList('actions')
        .map(LearnerAction.fromJson)
        .toList(growable: false),
  );
}

class LearnerAction {
  const LearnerAction({
    required this.id,
    required this.attemptId,
    required this.missionId,
    required this.stageId,
    required this.taskId,
    required this.actionType,
    required this.targetId,
    required this.payload,
    required this.sequenceNumber,
    required this.simulationTimeSeconds,
    required this.createdAt,
    this.isTechnical = false,
  });

  final String id;
  final String attemptId;
  final String missionId;
  final String stageId;
  final String taskId;
  final ActionType actionType;
  final String? targetId;
  final JsonMap payload;
  final int sequenceNumber;
  final int simulationTimeSeconds;
  final DateTime createdAt;
  final bool isTechnical;

  JsonMap toJson() => {
    'id': id,
    'attemptId': attemptId,
    'missionId': missionId,
    'stageId': stageId,
    'taskId': taskId,
    'actionType': actionType.wireName,
    'targetId': targetId,
    'payload': payload,
    'sequenceNumber': sequenceNumber,
    'simulationTimeSeconds': simulationTimeSeconds,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'isTechnical': isTechnical,
  };

  factory LearnerAction.fromJson(JsonMap json) => LearnerAction(
    id: json.string('id'),
    attemptId: json.string('attemptId'),
    missionId: json.string('missionId'),
    stageId: json.string('stageId'),
    taskId: json.string('taskId'),
    actionType: ActionType.fromWireName(json.string('actionType')),
    targetId: json.optionalString('targetId'),
    payload: json.object('payload'),
    sequenceNumber: json.integer('sequenceNumber'),
    simulationTimeSeconds: json.integer('simulationTimeSeconds'),
    createdAt: DateTime.parse(json.string('createdAt')),
    isTechnical: json.boolean('isTechnical'),
  );
}

class ActionOutcome {
  const ActionOutcome({
    required this.actionId,
    required this.taskId,
    required this.categoryId,
    required this.outcomeType,
    required this.pointsAwarded,
    required this.maximumPoints,
    required this.feedbackCode,
    required this.competencyImpacts,
    this.criticalErrorTriggered = false,
  });

  final String actionId;
  final String taskId;
  final String categoryId;
  final OutcomeType outcomeType;
  final int pointsAwarded;
  final int maximumPoints;
  final String feedbackCode;
  final List<CompetencyImpact> competencyImpacts;
  final bool criticalErrorTriggered;
}

class CompetencyImpact {
  const CompetencyImpact({
    required this.competencyId,
    required this.scoreDelta,
    required this.maximumScore,
  });

  final String competencyId;
  final double scoreDelta;
  final double maximumScore;
}

class TriggeredCriticalError {
  const TriggeredCriticalError({
    required this.ruleId,
    required this.title,
    required this.feedback,
    required this.severity,
    required this.scorePenalty,
    required this.preventsPassing,
  });

  final String ruleId;
  final String title;
  final String feedback;
  final CriticalErrorSeverity severity;
  final int scorePenalty;
  final bool preventsPassing;
}

class CompetencyScore {
  const CompetencyScore({required this.competencyId, required this.score});

  final String competencyId;
  final int score;
}

class SimulationResult {
  const SimulationResult({
    required this.attemptId,
    required this.missionId,
    required this.missionVersion,
    required this.scenarioSeed,
    required this.status,
    required this.overallScore,
    required this.categoryScores,
    required this.competencyScores,
    required this.mandatoryTasksCompleted,
    required this.criticalErrors,
    required this.correctActions,
    required this.missedIssues,
    required this.evidence,
    required this.recommendedRemediationIds,
    required this.completedAt,
  });

  final String attemptId;
  final String missionId;
  final String missionVersion;
  final int scenarioSeed;
  final MissionStatus status;
  final double overallScore;
  final Map<String, double> categoryScores;
  final List<CompetencyScore> competencyScores;
  final bool mandatoryTasksCompleted;
  final List<TriggeredCriticalError> criticalErrors;
  final List<String> correctActions;
  final List<String> missedIssues;
  final List<EvidenceRecord> evidence;
  final List<String> recommendedRemediationIds;
  final DateTime completedAt;

  JsonMap toJson() => {
    'attemptId': attemptId,
    'missionId': missionId,
    'missionVersion': missionVersion,
    'scenarioSeed': scenarioSeed,
    'status': status.wireName,
    'overallScore': overallScore,
    'categoryScores': categoryScores,
    'competencyScores': [
      for (final item in competencyScores)
        {'competencyId': item.competencyId, 'score': item.score},
    ],
    'mandatoryTasksCompleted': mandatoryTasksCompleted,
    'criticalErrors': [
      for (final item in criticalErrors)
        {
          'ruleId': item.ruleId,
          'title': item.title,
          'feedback': item.feedback,
          'severity': item.severity.name,
          'scorePenalty': item.scorePenalty,
          'preventsPassing': item.preventsPassing,
        },
    ],
    'correctActions': correctActions,
    'missedIssues': missedIssues,
    'evidence': evidence.map((item) => item.toJson()).toList(),
    'recommendedRemediationIds': recommendedRemediationIds,
    'completedAt': completedAt.toUtc().toIso8601String(),
  };

  factory SimulationResult.fromJson(JsonMap json) => SimulationResult(
    attemptId: json.string('attemptId'),
    missionId: json.string('missionId'),
    missionVersion: json.string('missionVersion'),
    scenarioSeed: json.integer('scenarioSeed'),
    status: MissionStatus.fromWireName(json.string('status')),
    overallScore: json.number('overallScore').toDouble(),
    categoryScores: json
        .object('categoryScores')
        .map((key, value) => MapEntry(key, (value as num).toDouble())),
    competencyScores: json
        .mapList('competencyScores')
        .map(
          (item) => CompetencyScore(
            competencyId: item.string('competencyId'),
            score: item.integer('score'),
          ),
        )
        .toList(),
    mandatoryTasksCompleted: json.boolean('mandatoryTasksCompleted'),
    criticalErrors: json
        .mapList('criticalErrors')
        .map(
          (item) => TriggeredCriticalError(
            ruleId: item.string('ruleId'),
            title: item.string('title'),
            feedback: item.string('feedback'),
            severity: CriticalErrorSeverity.values.byName(
              item.string('severity'),
            ),
            scorePenalty: item.integer('scorePenalty'),
            preventsPassing: item.boolean('preventsPassing'),
          ),
        )
        .toList(),
    correctActions: json.stringList('correctActions'),
    missedIssues: json.stringList('missedIssues'),
    evidence: json.mapList('evidence').map(EvidenceRecord.fromJson).toList(),
    recommendedRemediationIds: json.stringList('recommendedRemediationIds'),
    completedAt: DateTime.parse(json.string('completedAt')),
  );
}

class EvidenceRecord {
  const EvidenceRecord({
    required this.id,
    required this.candidateId,
    required this.attemptId,
    required this.missionId,
    required this.missionVersion,
    required this.scenarioSeed,
    required this.competencyId,
    required this.score,
    required this.evidenceType,
    required this.title,
    required this.description,
    required this.issuedAt,
    required this.verificationStatus,
  });

  final String id;
  final String candidateId;
  final String attemptId;
  final String missionId;
  final String missionVersion;
  final int scenarioSeed;
  final String competencyId;
  final int score;
  final EvidenceType evidenceType;
  final String title;
  final String description;
  final DateTime issuedAt;
  final String verificationStatus;

  JsonMap toJson() => {
    'id': id,
    'candidateId': candidateId,
    'attemptId': attemptId,
    'missionId': missionId,
    'missionVersion': missionVersion,
    'scenarioSeed': scenarioSeed,
    'competencyId': competencyId,
    'score': score,
    'evidenceType': evidenceType.wireName,
    'title': title,
    'description': description,
    'issuedAt': issuedAt.toUtc().toIso8601String(),
    'verificationStatus': verificationStatus,
  };

  factory EvidenceRecord.fromJson(JsonMap json) => EvidenceRecord(
    id: json.string('id'),
    candidateId: json.string('candidateId'),
    attemptId: json.string('attemptId'),
    missionId: json.string('missionId'),
    missionVersion: json.string('missionVersion'),
    scenarioSeed: json.integer('scenarioSeed'),
    competencyId: json.string('competencyId'),
    score: json.integer('score'),
    evidenceType: EvidenceType.values.firstWhere(
      (item) => item.wireName == json.string('evidenceType'),
    ),
    title: json.string('title'),
    description: json.string('description'),
    issuedAt: DateTime.parse(json.string('issuedAt')),
    verificationStatus: json.string('verificationStatus'),
  );
}

DateTime? _optionalDate(String? value) =>
    value == null ? null : DateTime.parse(value);
