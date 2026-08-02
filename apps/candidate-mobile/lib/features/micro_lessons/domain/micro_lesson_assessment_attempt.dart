/// A single recorded assessment submission for a [MicroLessonClip]
/// (micro-lessons v0.2). Deliberately self-contained -- it snapshots the
/// clip's title and competency tags at submission time rather than
/// re-reading the live catalogue later, since evidence should reflect what
/// the candidate actually saw and answered, not whatever the content
/// happens to say if it's edited afterward.
class MicroLessonAssessmentAttempt {
  const MicroLessonAssessmentAttempt({
    required this.id,
    required this.candidateId,
    required this.clipId,
    required this.clipTitle,
    required this.competencyTags,
    required this.selectedAnswerId,
    required this.correctAnswerId,
    required this.submittedAt,
    required this.auditEvents,
  });

  final String id;
  final String candidateId;
  final String clipId;
  final String clipTitle;
  final List<String> competencyTags;
  final String selectedAnswerId;
  final String correctAnswerId;
  final DateTime submittedAt;
  final List<RecordedAuditEvent> auditEvents;

  bool get isCorrect => selectedAnswerId == correctAnswerId;

  /// 0-100, matching the scale [EvidenceRecord.score] already uses for
  /// workplace-simulation evidence. A single-question assessment is binary
  /// today (right or wrong); partial credit is a future extension, not a
  /// v0.2 concern.
  int get scorePercent => isCorrect ? 100 : 0;

  Map<String, Object?> toJson() => {
    'id': id,
    'candidateId': candidateId,
    'clipId': clipId,
    'clipTitle': clipTitle,
    'competencyTags': competencyTags,
    'selectedAnswerId': selectedAnswerId,
    'correctAnswerId': correctAnswerId,
    'submittedAt': submittedAt.toUtc().toIso8601String(),
    'auditEvents': auditEvents.map((event) => event.toJson()).toList(),
  };

  factory MicroLessonAssessmentAttempt.fromJson(Map<String, Object?> json) {
    return MicroLessonAssessmentAttempt(
      id: json['id']! as String,
      candidateId: json['candidateId']! as String,
      clipId: json['clipId']! as String,
      clipTitle: json['clipTitle']! as String,
      competencyTags: (json['competencyTags'] as List<Object?>)
          .whereType<String>()
          .toList(growable: false),
      selectedAnswerId: json['selectedAnswerId']! as String,
      correctAnswerId: json['correctAnswerId']! as String,
      submittedAt: DateTime.parse(json['submittedAt']! as String),
      auditEvents: (json['auditEvents'] as List<Object?>? ?? const [])
          .map(
            (item) => RecordedAuditEvent.fromJson(item as Map<String, Object?>),
          )
          .toList(growable: false),
    );
  }
}

/// An audit event actually recorded at submission time, distinct from
/// [ClipAuditEventDefinition] which is just the catalogue's declaration of
/// what *should* be recorded when a clip is answered.
class RecordedAuditEvent {
  const RecordedAuditEvent({
    required this.eventType,
    required this.occurredAt,
    this.payload = const {},
  });

  final String eventType;
  final DateTime occurredAt;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() => {
    'eventType': eventType,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'payload': payload,
  };

  factory RecordedAuditEvent.fromJson(Map<String, Object?> json) {
    return RecordedAuditEvent(
      eventType: json['eventType']! as String,
      occurredAt: DateTime.parse(json['occurredAt']! as String),
      payload: (json['payload'] as Map<String, Object?>?) ?? const {},
    );
  }
}
