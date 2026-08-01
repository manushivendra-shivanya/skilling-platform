enum MicroLessonDomain {
  receiving,
  inspection,
  putAway,
  supervisor,
  dispatch,
  inventory,
  safety,
}

enum MicroLessonMode { lesson, practice, assessment }

enum TemperatureZone { frozen, chilled, fnv, dairy, ambient, mixed }

class ClipAnswerOption {
  const ClipAnswerOption({
    required this.id,
    required this.label,
    required this.feedback,
  });

  final String id;
  final String label;
  final String feedback;

  factory ClipAnswerOption.fromJson(Map<String, Object?> json) {
    return ClipAnswerOption(
      id: json['id']! as String,
      label: json['label']! as String,
      feedback: json['feedback']! as String,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'feedback': feedback,
  };
}

class ClipScoringRules {
  const ClipScoringRules({
    required this.maxPoints,
    required this.correctAnswerPoints,
    required this.evidenceSource,
    required this.technicalFailuresScoreable,
  });

  final int maxPoints;
  final int correctAnswerPoints;
  final String evidenceSource;
  final bool technicalFailuresScoreable;

  factory ClipScoringRules.fromJson(Map<String, Object?> json) {
    return ClipScoringRules(
      maxPoints: json['maxPoints']! as int,
      correctAnswerPoints: json['correctAnswerPoints']! as int,
      evidenceSource: json['evidenceSource']! as String,
      technicalFailuresScoreable:
          json['technicalFailuresScoreable'] as bool? ?? false,
    );
  }

  Map<String, Object?> toJson() => {
    'maxPoints': maxPoints,
    'correctAnswerPoints': correctAnswerPoints,
    'evidenceSource': evidenceSource,
    'technicalFailuresScoreable': technicalFailuresScoreable,
  };
}

class ClipAuditEventDefinition {
  const ClipAuditEventDefinition({
    required this.eventType,
    required this.when,
    this.payload = const {},
  });

  final String eventType;
  final String when;
  final Map<String, Object?> payload;

  factory ClipAuditEventDefinition.fromJson(Map<String, Object?> json) {
    return ClipAuditEventDefinition(
      eventType: json['eventType']! as String,
      when: json['when']! as String,
      payload: (json['payload'] as Map<String, Object?>?) ?? const {},
    );
  }

  Map<String, Object?> toJson() => {
    'eventType': eventType,
    'when': when,
    'payload': payload,
  };
}

class MicroLessonClip {
  const MicroLessonClip({
    required this.id,
    required this.title,
    required this.domain,
    required this.role,
    required this.processArea,
    required this.temperatureZone,
    required this.durationSeconds,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.transcript,
    required this.description,
    required this.expectedObservation,
    required this.expectedDecision,
    required this.competencyTags,
    required this.lessonContent,
    required this.assessmentQuestion,
    required this.answerOptions,
    required this.correctAnswerId,
    required this.scoringRules,
    required this.auditEvents,
    this.modes = const {
      MicroLessonMode.lesson,
      MicroLessonMode.practice,
      MicroLessonMode.assessment,
    },
  });

  final String id;
  final String title;
  final MicroLessonDomain domain;
  final String role;
  final String processArea;
  final TemperatureZone temperatureZone;
  final int durationSeconds;
  final String? videoUrl;
  final String? thumbnailUrl;
  final String transcript;
  final String description;
  final String expectedObservation;
  final String expectedDecision;
  final List<String> competencyTags;
  final String lessonContent;
  final String assessmentQuestion;
  final List<ClipAnswerOption> answerOptions;
  final String correctAnswerId;
  final ClipScoringRules scoringRules;
  final List<ClipAuditEventDefinition> auditEvents;
  final Set<MicroLessonMode> modes;

  ClipAnswerOption get correctAnswer =>
      answerOptions.firstWhere((option) => option.id == correctAnswerId);

  bool get hasVideoAsset => videoUrl != null && videoUrl!.trim().isNotEmpty;

  factory MicroLessonClip.fromJson(Map<String, Object?> json) {
    return MicroLessonClip(
      id: json['id']! as String,
      title: json['title']! as String,
      domain: _domainFromJson(json['domain']! as String),
      role: json['role']! as String,
      processArea: json['processArea']! as String,
      temperatureZone: _temperatureZoneFromJson(
        json['temperatureZone']! as String,
      ),
      durationSeconds: json['durationSeconds']! as int,
      videoUrl: json['videoUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      transcript: json['transcript']! as String,
      description: json['description']! as String,
      expectedObservation: json['expectedObservation']! as String,
      expectedDecision: json['expectedDecision']! as String,
      competencyTags: (json['competencyTags'] as List<Object?>)
          .whereType<String>()
          .toList(growable: false),
      lessonContent: json['lessonContent']! as String,
      assessmentQuestion: json['assessmentQuestion']! as String,
      answerOptions: (json['answerOptions'] as List<Object?>)
          .map(
            (item) => ClipAnswerOption.fromJson(item as Map<String, Object?>),
          )
          .toList(growable: false),
      correctAnswerId: json['correctAnswer']! as String,
      scoringRules: ClipScoringRules.fromJson(
        json['scoringRules']! as Map<String, Object?>,
      ),
      auditEvents: (json['auditEvents'] as List<Object?>? ?? const [])
          .map(
            (item) =>
                ClipAuditEventDefinition.fromJson(item as Map<String, Object?>),
          )
          .toList(growable: false),
      modes:
          (json['modes'] as List<Object?>? ??
                  const ['lesson', 'practice', 'assessment'])
              .whereType<String>()
              .map(_modeFromJson)
              .toSet(),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'domain': domain.name,
    'role': role,
    'processArea': processArea,
    'temperatureZone': temperatureZone.name,
    'durationSeconds': durationSeconds,
    'videoUrl': videoUrl,
    'thumbnailUrl': thumbnailUrl,
    'transcript': transcript,
    'description': description,
    'expectedObservation': expectedObservation,
    'expectedDecision': expectedDecision,
    'competencyTags': competencyTags,
    'lessonContent': lessonContent,
    'assessmentQuestion': assessmentQuestion,
    'answerOptions': answerOptions.map((option) => option.toJson()).toList(),
    'correctAnswer': correctAnswerId,
    'scoringRules': scoringRules.toJson(),
    'auditEvents': auditEvents.map((event) => event.toJson()).toList(),
    'modes': modes.map((mode) => mode.name).toList(),
  };
}

MicroLessonDomain _domainFromJson(String value) {
  return switch (value) {
    'receiving' => MicroLessonDomain.receiving,
    'inspection' => MicroLessonDomain.inspection,
    'put-away' || 'putAway' => MicroLessonDomain.putAway,
    'supervisor' => MicroLessonDomain.supervisor,
    'dispatch' => MicroLessonDomain.dispatch,
    'inventory' => MicroLessonDomain.inventory,
    'safety' => MicroLessonDomain.safety,
    _ => throw FormatException('Unknown micro-lesson domain: $value'),
  };
}

TemperatureZone _temperatureZoneFromJson(String value) {
  return switch (value) {
    'frozen' => TemperatureZone.frozen,
    'chilled' => TemperatureZone.chilled,
    'fnv' => TemperatureZone.fnv,
    'dairy' => TemperatureZone.dairy,
    'ambient' => TemperatureZone.ambient,
    'mixed' => TemperatureZone.mixed,
    _ => throw FormatException('Unknown temperature zone: $value'),
  };
}

MicroLessonMode _modeFromJson(String value) {
  return switch (value) {
    'lesson' => MicroLessonMode.lesson,
    'practice' => MicroLessonMode.practice,
    'assessment' => MicroLessonMode.assessment,
    _ => throw FormatException('Unknown micro-lesson mode: $value'),
  };
}
