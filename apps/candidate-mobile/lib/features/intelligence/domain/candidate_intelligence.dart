class CompetencyDefinition {
  const CompetencyDefinition({
    required this.code,
    required this.name,
    required this.description,
  });

  final String code;
  final String name;
  final String description;
}

class RoleDefinition {
  const RoleDefinition({
    required this.code,
    required this.name,
    required this.targetLevels,
  });

  final String code;
  final String name;
  final Map<String, int> targetLevels;
}

class DiagnosticOption {
  const DiagnosticOption({required this.label, required this.score});

  final String label;
  final int score;
}

class DiagnosticQuestion {
  const DiagnosticQuestion({
    required this.id,
    required this.competencyCode,
    required this.prompt,
    required this.options,
  });

  final String id;
  final String competencyCode;
  final String prompt;
  final List<DiagnosticOption> options;
}

class CompetencyResult {
  const CompetencyResult({
    required this.competencyCode,
    required this.level,
    required this.explanation,
    required this.improvement,
  });

  final String competencyCode;
  final int level;
  final String explanation;
  final String improvement;

  Map<String, Object?> toJson() => {
    'competency_code': competencyCode,
    'level': level,
    'explanation': explanation,
    'improvement': improvement,
  };

  factory CompetencyResult.fromJson(Map<String, Object?> json) {
    return CompetencyResult(
      competencyCode: json['competency_code'] as String,
      level: json['level'] as int,
      explanation: json['explanation'] as String,
      improvement: json['improvement'] as String,
    );
  }
}

class DiagnosticResult {
  const DiagnosticResult({
    required this.definitionVersion,
    required this.recommendedRoleCode,
    required this.competencies,
    required this.completedAt,
  });

  final String definitionVersion;
  final String recommendedRoleCode;
  final List<CompetencyResult> competencies;
  final DateTime completedAt;

  int get averageLevel => competencies.isEmpty
      ? 0
      : competencies.fold<int>(0, (sum, item) => sum + item.level) ~/
            competencies.length;

  Map<String, Object?> toJson() => {
    'definition_version': definitionVersion,
    'recommended_role_code': recommendedRoleCode,
    'competencies': competencies.map((item) => item.toJson()).toList(),
    'completed_at': completedAt.toUtc().toIso8601String(),
  };

  factory DiagnosticResult.fromJson(Map<String, Object?> json) {
    return DiagnosticResult(
      definitionVersion: json['definition_version'] as String,
      recommendedRoleCode: json['recommended_role_code'] as String,
      competencies: (json['competencies'] as List<Object?>)
          .map(
            (item) => CompetencyResult.fromJson(item as Map<String, Object?>),
          )
          .toList(),
      completedAt: DateTime.parse(json['completed_at'] as String),
    );
  }
}

class LearningProgressRecord {
  const LearningProgressRecord({
    this.downloadedUnitIds = const {},
    this.completedUnitIds = const {},
  });

  final Set<String> downloadedUnitIds;
  final Set<String> completedUnitIds;

  Map<String, Object?> toJson() => {
    'downloaded_unit_ids': downloadedUnitIds.toList(),
    'completed_unit_ids': completedUnitIds.toList(),
  };

  factory LearningProgressRecord.fromJson(Map<String, Object?> json) {
    return LearningProgressRecord(
      downloadedUnitIds: (json['downloaded_unit_ids'] as List<Object?>? ?? [])
          .whereType<String>()
          .toSet(),
      completedUnitIds: (json['completed_unit_ids'] as List<Object?>? ?? [])
          .whereType<String>()
          .toSet(),
    );
  }
}

class SimulationEvent {
  const SimulationEvent({
    required this.sequence,
    required this.type,
    required this.payload,
    required this.clientTime,
    this.isTechnical = false,
  });

  final int sequence;
  final String type;
  final Map<String, Object?> payload;
  final DateTime clientTime;
  final bool isTechnical;

  Map<String, Object?> toJson() => {
    'sequence': sequence,
    'type': type,
    'payload': payload,
    'client_time': clientTime.toUtc().toIso8601String(),
    'is_technical': isTechnical,
  };

  factory SimulationEvent.fromJson(Map<String, Object?> json) {
    return SimulationEvent(
      sequence: json['sequence'] as int,
      type: json['type'] as String,
      payload: json['payload'] as Map<String, Object?>,
      clientTime: DateTime.parse(json['client_time'] as String),
      isTechnical: json['is_technical'] as bool? ?? false,
    );
  }
}

class SimulationScore {
  const SimulationScore({
    required this.attemptId,
    required this.simulationVersion,
    required this.totalScore,
    required this.dimensionScores,
    required this.explanation,
    required this.improvement,
    required this.events,
    required this.completedAt,
  });

  final String attemptId;
  final String simulationVersion;
  final int totalScore;
  final Map<String, int> dimensionScores;
  final String explanation;
  final String improvement;
  final List<SimulationEvent> events;
  final DateTime completedAt;

  Map<String, Object?> toJson() => {
    'attempt_id': attemptId,
    'simulation_version': simulationVersion,
    'total_score': totalScore,
    'dimension_scores': dimensionScores,
    'explanation': explanation,
    'improvement': improvement,
    'events': events.map((event) => event.toJson()).toList(),
    'completed_at': completedAt.toUtc().toIso8601String(),
  };

  factory SimulationScore.fromJson(Map<String, Object?> json) {
    return SimulationScore(
      attemptId: json['attempt_id'] as String,
      simulationVersion: json['simulation_version'] as String,
      totalScore: json['total_score'] as int,
      dimensionScores: (json['dimension_scores'] as Map<String, Object?>).map(
        (key, value) => MapEntry(key, value as int),
      ),
      explanation: json['explanation'] as String,
      improvement: json['improvement'] as String,
      events: (json['events'] as List<Object?>)
          .map((item) => SimulationEvent.fromJson(item as Map<String, Object?>))
          .toList(),
      completedAt: DateTime.parse(json['completed_at'] as String),
    );
  }
}

class EvidenceRecord {
  const EvidenceRecord({
    required this.id,
    required this.competencyCode,
    required this.sourceType,
    required this.score,
    required this.explanation,
    required this.createdAt,
  });

  final String id;
  final String competencyCode;
  final String sourceType;
  final int score;
  final String explanation;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'competency_code': competencyCode,
    'source_type': sourceType,
    'score': score,
    'explanation': explanation,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  factory EvidenceRecord.fromJson(Map<String, Object?> json) {
    return EvidenceRecord(
      id: json['id'] as String,
      competencyCode: json['competency_code'] as String,
      sourceType: json['source_type'] as String,
      score: json['score'] as int,
      explanation: json['explanation'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class CandidateIntelligenceState {
  const CandidateIntelligenceState({
    this.diagnosticResult,
    this.learningProgress = const LearningProgressRecord(),
    this.simulationScores = const [],
    this.evidence = const [],
    this.pendingSyncCount = 0,
  });

  final DiagnosticResult? diagnosticResult;
  final LearningProgressRecord learningProgress;
  final List<SimulationScore> simulationScores;
  final List<EvidenceRecord> evidence;
  final int pendingSyncCount;

  CandidateIntelligenceState copyWith({
    DiagnosticResult? diagnosticResult,
    LearningProgressRecord? learningProgress,
    List<SimulationScore>? simulationScores,
    List<EvidenceRecord>? evidence,
    int? pendingSyncCount,
  }) {
    return CandidateIntelligenceState(
      diagnosticResult: diagnosticResult ?? this.diagnosticResult,
      learningProgress: learningProgress ?? this.learningProgress,
      simulationScores: simulationScores ?? this.simulationScores,
      evidence: evidence ?? this.evidence,
      pendingSyncCount: pendingSyncCount ?? this.pendingSyncCount,
    );
  }

  Map<String, Object?> toJson() => {
    'diagnostic_result': diagnosticResult?.toJson(),
    'learning_progress': learningProgress.toJson(),
    'simulation_scores': simulationScores.map((item) => item.toJson()).toList(),
    'evidence': evidence.map((item) => item.toJson()).toList(),
    'pending_sync_count': pendingSyncCount,
  };

  factory CandidateIntelligenceState.fromJson(Map<String, Object?> json) {
    final diagnostic = json['diagnostic_result'];
    return CandidateIntelligenceState(
      diagnosticResult: diagnostic is Map<String, Object?>
          ? DiagnosticResult.fromJson(diagnostic)
          : null,
      learningProgress: LearningProgressRecord.fromJson(
        json['learning_progress'] as Map<String, Object?>? ?? const {},
      ),
      simulationScores:
          (json['simulation_scores'] as List<Object?>? ?? const [])
              .map(
                (item) =>
                    SimulationScore.fromJson(item as Map<String, Object?>),
              )
              .toList(),
      evidence: (json['evidence'] as List<Object?>? ?? const [])
          .map((item) => EvidenceRecord.fromJson(item as Map<String, Object?>))
          .toList(),
      pendingSyncCount: json['pending_sync_count'] as int? ?? 0,
    );
  }
}

abstract final class LogisticsIntelligenceCatalog {
  static const diagnosticVersion = 'logistics-diagnostic-v1';
  static const simulationVersion = 'inventory-discrepancy-v1';

  static const competencies = [
    CompetencyDefinition(
      code: 'inventory_accuracy',
      name: 'Inventory accuracy',
      description: 'Counts, compares, and preserves accurate stock records.',
    ),
    CompetencyDefinition(
      code: 'safe_escalation',
      name: 'Safe escalation',
      description: 'Recognises exceptions and escalates with an audit trail.',
    ),
    CompetencyDefinition(
      code: 'sla_prioritisation',
      name: 'SLA prioritisation',
      description: 'Orders work by urgency without bypassing safety controls.',
    ),
    CompetencyDefinition(
      code: 'handover_communication',
      name: 'Handover communication',
      description: 'Shares clear facts, action taken, and outstanding risk.',
    ),
  ];

  static const roles = [
    RoleDefinition(
      code: 'warehouse_associate',
      name: 'Warehouse Operations Associate',
      targetLevels: {
        'inventory_accuracy': 2,
        'safe_escalation': 2,
        'sla_prioritisation': 1,
        'handover_communication': 1,
      },
    ),
    RoleDefinition(
      code: 'inventory_executive',
      name: 'Inventory Executive',
      targetLevels: {
        'inventory_accuracy': 3,
        'safe_escalation': 2,
        'sla_prioritisation': 2,
        'handover_communication': 2,
      },
    ),
    RoleDefinition(
      code: 'dispatch_executive',
      name: 'Dispatch Executive',
      targetLevels: {
        'inventory_accuracy': 2,
        'safe_escalation': 2,
        'sla_prioritisation': 3,
        'handover_communication': 2,
      },
    ),
  ];

  static const questions = [
    DiagnosticQuestion(
      id: 'inventory-count',
      competencyCode: 'inventory_accuracy',
      prompt:
          'The system shows 24 units, but the physical count is 21. What do you do first?',
      options: [
        DiagnosticOption(
          label: 'Change the system count immediately',
          score: 0,
        ),
        DiagnosticOption(label: 'Recount and preserve both records', score: 3),
        DiagnosticOption(label: 'Ignore it until tomorrow', score: 0),
      ],
    ),
    DiagnosticQuestion(
      id: 'damaged-carton',
      competencyCode: 'safe_escalation',
      prompt:
          'A sealed carton is damaged before dispatch. What is the safest response?',
      options: [
        DiagnosticOption(label: 'Dispatch it to avoid delay', score: 0),
        DiagnosticOption(
          label: 'Isolate, record, and escalate using the SOP',
          score: 3,
        ),
        DiagnosticOption(label: 'Hide the damage with tape', score: 0),
      ],
    ),
    DiagnosticQuestion(
      id: 'dispatch-priority',
      competencyCode: 'sla_prioritisation',
      prompt:
          'Two orders are ready; one is near its SLA while the other arrived first. What matters most?',
      options: [
        DiagnosticOption(
          label: 'Check SLA, safety, and approved priority rules',
          score: 3,
        ),
        DiagnosticOption(label: 'Always take the newest order', score: 0),
        DiagnosticOption(label: 'Choose whichever looks easiest', score: 1),
      ],
    ),
    DiagnosticQuestion(
      id: 'shift-handover',
      competencyCode: 'handover_communication',
      prompt: 'What makes an exception handover useful to the next shift?',
      options: [
        DiagnosticOption(label: 'Only say there was a problem', score: 1),
        DiagnosticOption(
          label: 'Share facts, actions, owner, and outstanding risk',
          score: 3,
        ),
        DiagnosticOption(label: 'Wait until someone asks', score: 0),
      ],
    ),
  ];

  static String competencyName(String code) =>
      competencies.firstWhere((item) => item.code == code).name;

  static String roleName(String code) =>
      roles.firstWhere((item) => item.code == code).name;
}
