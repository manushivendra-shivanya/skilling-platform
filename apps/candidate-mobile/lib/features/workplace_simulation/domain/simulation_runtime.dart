import 'simulation_content.dart';
import 'simulation_enums.dart';
import 'workplace_task_drafts.dart';

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
    this.scenarioId,
    required this.state,
    required this.createdAt,
    required this.shiftStartedAt,
    this.briefingAcknowledgedAt,
    this.pausedAt,
    this.timerResumedAt,
    this.elapsedSimulationSeconds = 0,
    this.timerStatus = SimulationTimerStatus.notStarted,
    required this.currentStageId,
    required this.completedTaskIds,
    required this.actions,
    required this.auditEvents,
    this.documentReviewDraft,
    this.receivingCountDraft,
    this.inspectionDraft,
    this.dispositionDraft,
    this.discrepancyReportDraft,
    this.submittedAt,
    this.completedAt,
  });

  final String id;
  final String candidateId;
  final String missionId;
  final String missionVersion;
  final int attemptNumber;
  final int scenarioSeed;

  /// Which entry of the mission's scenario catalog this attempt was seeded
  /// against, if any. Null means the mission's always-available default.
  final String? scenarioId;
  final MissionState state;
  final DateTime createdAt;
  final DateTime? briefingAcknowledgedAt;
  final DateTime? shiftStartedAt;
  final DateTime? pausedAt;
  final DateTime? timerResumedAt;
  final DateTime? submittedAt;
  final DateTime? completedAt;
  final int elapsedSimulationSeconds;
  final SimulationTimerStatus timerStatus;
  final String? currentStageId;
  final Set<String> completedTaskIds;
  final List<LearnerAction> actions;
  final List<AttemptAuditEvent> auditEvents;
  final DocumentReviewDraft? documentReviewDraft;
  final ReceivingCountDraft? receivingCountDraft;
  final InspectionDraft? inspectionDraft;
  final DispositionDraft? dispositionDraft;
  final DiscrepancyReportDraft? discrepancyReportDraft;

  @Deprecated('Use createdAt')
  DateTime get startedAt => createdAt;

  @Deprecated('Use elapsedSimulationSeconds')
  int get elapsedSeconds => elapsedSimulationSeconds;

  int get actionCount => actions.length;
  int get auditEventCount => auditEvents.length;

  bool get briefingAcknowledged {
    for (final event in auditEvents.reversed) {
      if (event.eventType == AttemptAuditEventType.briefingAcknowledged) {
        return true;
      }
      if (event.eventType ==
          AttemptAuditEventType.briefingAcknowledgementRemoved) {
        return false;
      }
    }
    return false;
  }

  SimulationAttempt copyWith({
    MissionState? state,
    DateTime? shiftStartedAt,
    bool clearShiftStartedAt = false,
    DateTime? briefingAcknowledgedAt,
    bool clearBriefingAcknowledgedAt = false,
    DateTime? pausedAt,
    bool clearPausedAt = false,
    DateTime? timerResumedAt,
    bool clearTimerResumedAt = false,
    DateTime? submittedAt,
    DateTime? completedAt,
    int? elapsedSimulationSeconds,
    SimulationTimerStatus? timerStatus,
    String? currentStageId,
    bool clearCurrentStage = false,
    Set<String>? completedTaskIds,
    List<LearnerAction>? actions,
    List<AttemptAuditEvent>? auditEvents,
    DocumentReviewDraft? documentReviewDraft,
    ReceivingCountDraft? receivingCountDraft,
    InspectionDraft? inspectionDraft,
    DispositionDraft? dispositionDraft,
    DiscrepancyReportDraft? discrepancyReportDraft,
  }) => SimulationAttempt(
    id: id,
    candidateId: candidateId,
    missionId: missionId,
    missionVersion: missionVersion,
    attemptNumber: attemptNumber,
    scenarioSeed: scenarioSeed,
    scenarioId: scenarioId,
    state: state ?? this.state,
    createdAt: createdAt,
    shiftStartedAt: clearShiftStartedAt
        ? null
        : shiftStartedAt ?? this.shiftStartedAt,
    briefingAcknowledgedAt: clearBriefingAcknowledgedAt
        ? null
        : briefingAcknowledgedAt ?? this.briefingAcknowledgedAt,
    pausedAt: clearPausedAt ? null : pausedAt ?? this.pausedAt,
    timerResumedAt: clearTimerResumedAt
        ? null
        : timerResumedAt ?? this.timerResumedAt,
    submittedAt: submittedAt ?? this.submittedAt,
    completedAt: completedAt ?? this.completedAt,
    elapsedSimulationSeconds:
        elapsedSimulationSeconds ?? this.elapsedSimulationSeconds,
    timerStatus: timerStatus ?? this.timerStatus,
    currentStageId: clearCurrentStage
        ? null
        : currentStageId ?? this.currentStageId,
    completedTaskIds: completedTaskIds ?? this.completedTaskIds,
    actions: actions ?? this.actions,
    auditEvents: auditEvents ?? this.auditEvents,
    documentReviewDraft: documentReviewDraft ?? this.documentReviewDraft,
    receivingCountDraft: receivingCountDraft ?? this.receivingCountDraft,
    inspectionDraft: inspectionDraft ?? this.inspectionDraft,
    dispositionDraft: dispositionDraft ?? this.dispositionDraft,
    discrepancyReportDraft:
        discrepancyReportDraft ?? this.discrepancyReportDraft,
  );

  JsonMap toJson() => {
    'id': id,
    'candidateId': candidateId,
    'missionId': missionId,
    'missionVersion': missionVersion,
    'attemptNumber': attemptNumber,
    'scenarioSeed': scenarioSeed,
    'scenarioId': scenarioId,
    'state': state.wireName,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'shiftStartedAt': shiftStartedAt?.toUtc().toIso8601String(),
    'briefingAcknowledgedAt': briefingAcknowledgedAt?.toUtc().toIso8601String(),
    'pausedAt': pausedAt?.toUtc().toIso8601String(),
    'timerResumedAt': timerResumedAt?.toUtc().toIso8601String(),
    'submittedAt': submittedAt?.toUtc().toIso8601String(),
    'completedAt': completedAt?.toUtc().toIso8601String(),
    'elapsedSimulationSeconds': elapsedSimulationSeconds,
    'timerStatus': timerStatus.wireName,
    'currentStageId': currentStageId,
    'completedTaskIds': completedTaskIds.toList(),
    'actions': actions.map((item) => item.toJson()).toList(),
    'auditEvents': auditEvents.map((item) => item.toJson()).toList(),
    'documentReviewDraft': documentReviewDraft?.toJson(),
    'receivingCountDraft': receivingCountDraft?.toJson(),
    'inspectionDraft': inspectionDraft?.toJson(),
    'dispositionDraft': dispositionDraft?.toJson(),
    'discrepancyReportDraft': discrepancyReportDraft?.toJson(),
  };

  factory SimulationAttempt.fromJson(JsonMap json) => SimulationAttempt(
    id: json.string('id'),
    candidateId: json.string('candidateId'),
    missionId: json.string('missionId'),
    missionVersion: json.string('missionVersion'),
    attemptNumber: json.integer('attemptNumber'),
    scenarioSeed: json.integer('scenarioSeed'),
    scenarioId: json.optionalString('scenarioId'),
    state: MissionState.fromWireName(json.string('state')),
    createdAt: DateTime.parse(
      json.optionalString('createdAt') ?? json.string('startedAt'),
    ),
    shiftStartedAt: _optionalDate(json.optionalString('shiftStartedAt')),
    briefingAcknowledgedAt: _optionalDate(
      json.optionalString('briefingAcknowledgedAt'),
    ),
    pausedAt: _optionalDate(json.optionalString('pausedAt')),
    timerResumedAt: _optionalDate(json.optionalString('timerResumedAt')),
    submittedAt: _optionalDate(json.optionalString('submittedAt')),
    completedAt: _optionalDate(json.optionalString('completedAt')),
    elapsedSimulationSeconds: json['elapsedSimulationSeconds'] is int
        ? json.integer('elapsedSimulationSeconds')
        : json.integer('elapsedSeconds'),
    timerStatus: json['timerStatus'] is String
        ? SimulationTimerStatus.fromWireName(json.string('timerStatus'))
        : _legacyTimerStatus(json),
    currentStageId: json.optionalString('currentStageId'),
    completedTaskIds: json.stringList('completedTaskIds').toSet(),
    actions: json
        .mapList('actions')
        .map(LearnerAction.fromJson)
        .toList(growable: false),
    auditEvents: json['auditEvents'] is List
        ? json
              .mapList('auditEvents')
              .map(AttemptAuditEvent.fromJson)
              .toList(growable: false)
        : const [],
    documentReviewDraft: json['documentReviewDraft'] is JsonMap
        ? DocumentReviewDraft.fromJson(json.object('documentReviewDraft'))
        : null,
    receivingCountDraft: json['receivingCountDraft'] is JsonMap
        ? ReceivingCountDraft.fromJson(json.object('receivingCountDraft'))
        : null,
    inspectionDraft: json['inspectionDraft'] is JsonMap
        ? InspectionDraft.fromJson(json.object('inspectionDraft'))
        : null,
    dispositionDraft: json['dispositionDraft'] is JsonMap
        ? DispositionDraft.fromJson(json.object('dispositionDraft'))
        : null,
    discrepancyReportDraft: json['discrepancyReportDraft'] is JsonMap
        ? DiscrepancyReportDraft.fromJson(json.object('discrepancyReportDraft'))
        : null,
  );
}

class AttemptAuditEvent {
  const AttemptAuditEvent({
    required this.id,
    required this.attemptId,
    required this.missionId,
    required this.missionVersion,
    required this.eventType,
    required this.screenId,
    required this.sequenceNumber,
    required this.simulationElapsedSeconds,
    required this.occurredAt,
    this.targetId,
    this.payload = const {},
  });

  final String id;
  final String attemptId;
  final String missionId;
  final String missionVersion;
  final AttemptAuditEventType eventType;
  final String screenId;
  final String? targetId;
  final int sequenceNumber;
  final int simulationElapsedSeconds;
  final DateTime occurredAt;
  final JsonMap payload;

  String get type => eventType.name;
  DateTime get timestamp => occurredAt;

  JsonMap toJson() => {
    'id': id,
    'attemptId': attemptId,
    'missionId': missionId,
    'missionVersion': missionVersion,
    'eventType': eventType.name,
    'screenId': screenId,
    'targetId': targetId,
    'sequenceNumber': sequenceNumber,
    'simulationElapsedSeconds': simulationElapsedSeconds,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'payload': payload,
  };

  factory AttemptAuditEvent.fromJson(JsonMap json) => AttemptAuditEvent(
    id: json.string('id'),
    attemptId: json.string('attemptId'),
    missionId: json.optionalString('missionId') ?? '',
    missionVersion: json.optionalString('missionVersion') ?? '',
    eventType: AttemptAuditEventType.fromWireName(
      json.optionalString('eventType') ?? json.string('type'),
    ),
    screenId: json.optionalString('screenId') ?? 'unknown',
    targetId: json.optionalString('targetId'),
    sequenceNumber: json.integer('sequenceNumber'),
    simulationElapsedSeconds: json['simulationElapsedSeconds'] is int
        ? json.integer('simulationElapsedSeconds')
        : 0,
    occurredAt: DateTime.parse(
      json.optionalString('occurredAt') ?? json.string('timestamp'),
    ),
    payload: json.object('payload'),
  );
}

SimulationTimerStatus _legacyTimerStatus(JsonMap json) {
  final state = MissionState.fromWireName(json.string('state'));
  if (json.optionalString('shiftStartedAt') == null) {
    return SimulationTimerStatus.notStarted;
  }
  if (state == MissionState.paused) return SimulationTimerStatus.paused;
  if (state == MissionState.completed || state == MissionState.failed) {
    return SimulationTimerStatus.stopped;
  }
  return SimulationTimerStatus.running;
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
