enum VoiceInterviewStatus {
  consent,
  microphoneCheck,
  microphoneReady,
  recording,
  transcriptReview,
  completed,
}

class VoiceConsent {
  const VoiceConsent({
    required this.recording,
    required this.transcription,
    required this.evaluation,
    required this.employerSharing,
    required this.policyVersion,
    required this.acceptedAt,
  });

  final bool recording;
  final bool transcription;
  final bool evaluation;
  final bool employerSharing;
  final String policyVersion;
  final DateTime acceptedAt;

  bool get permitsInterview => recording && transcription && evaluation;

  Map<String, Object?> toJson() => {
    'recording': recording,
    'transcription': transcription,
    'evaluation': evaluation,
    'employer_sharing': employerSharing,
    'policy_version': policyVersion,
    'accepted_at': acceptedAt.toUtc().toIso8601String(),
  };

  factory VoiceConsent.fromJson(Map<String, Object?> json) => VoiceConsent(
    recording: json['recording'] as bool,
    transcription: json['transcription'] as bool,
    evaluation: json['evaluation'] as bool,
    employerSharing: json['employer_sharing'] as bool? ?? false,
    policyVersion: json['policy_version'] as String,
    acceptedAt: DateTime.parse(json['accepted_at'] as String),
  );
}

class VoiceInterviewQuestion {
  const VoiceInterviewQuestion({
    required this.id,
    required this.text,
    required this.competency,
    required this.category,
    this.guidance,
  });

  final String id;
  final String text;
  final String competency;

  /// Section this question belongs to, shown above the question so the
  /// candidate knows what kind of answer is being asked for -- an
  /// introduction and a scenario call for very different things.
  final String category;

  /// What a good answer covers. Shown with the question rather than withheld:
  /// a candidate practising alone has no interviewer to read the room from,
  /// and the point is to build the skill, not to catch them out.
  final String? guidance;
}

class VoiceAnswer {
  const VoiceAnswer({
    required this.questionId,
    required this.transcript,
    required this.localAudioPath,
    required this.durationSeconds,
    required this.recordedAt,
  });

  final String questionId;
  final String transcript;
  final String localAudioPath;
  final int durationSeconds;
  final DateTime recordedAt;

  VoiceAnswer copyWith({String? transcript}) => VoiceAnswer(
    questionId: questionId,
    transcript: transcript ?? this.transcript,
    localAudioPath: localAudioPath,
    durationSeconds: durationSeconds,
    recordedAt: recordedAt,
  );

  Map<String, Object?> toJson() => {
    'question_id': questionId,
    'transcript': transcript,
    'local_audio_path': localAudioPath,
    'duration_seconds': durationSeconds,
    'recorded_at': recordedAt.toUtc().toIso8601String(),
  };

  factory VoiceAnswer.fromJson(Map<String, Object?> json) => VoiceAnswer(
    questionId: json['question_id'] as String,
    transcript: json['transcript'] as String,
    localAudioPath: json['local_audio_path'] as String,
    durationSeconds: json['duration_seconds'] as int,
    recordedAt: DateTime.parse(json['recorded_at'] as String),
  );
}

class VoiceDimensionFeedback {
  const VoiceDimensionFeedback({
    required this.dimension,
    required this.score,
    required this.explanation,
  });

  final String dimension;
  final int score;
  final String explanation;

  Map<String, Object?> toJson() => {
    'dimension': dimension,
    'score': score,
    'explanation': explanation,
  };

  factory VoiceDimensionFeedback.fromJson(Map<String, Object?> json) =>
      VoiceDimensionFeedback(
        dimension: json['dimension'] as String,
        score: json['score'] as int,
        explanation: json['explanation'] as String,
      );
}

class VoiceEvaluation {
  const VoiceEvaluation({
    required this.totalScore,
    required this.dimensions,
    required this.confidence,
    required this.summary,
    required this.improvement,
    required this.promptVersion,
    required this.rubricVersion,
    required this.requiresHumanReview,
    required this.createdAt,
  });

  final int totalScore;
  final List<VoiceDimensionFeedback> dimensions;
  final double confidence;
  final String summary;
  final String improvement;
  final String promptVersion;
  final String rubricVersion;
  final bool requiresHumanReview;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'total_score': totalScore,
    'dimensions': dimensions.map((item) => item.toJson()).toList(),
    'confidence': confidence,
    'summary': summary,
    'improvement': improvement,
    'prompt_version': promptVersion,
    'rubric_version': rubricVersion,
    'requires_human_review': requiresHumanReview,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  factory VoiceEvaluation.fromJson(Map<String, Object?> json) =>
      VoiceEvaluation(
        totalScore: json['total_score'] as int,
        dimensions: (json['dimensions'] as List<Object?>)
            .map(
              (item) =>
                  VoiceDimensionFeedback.fromJson(item as Map<String, Object?>),
            )
            .toList(),
        confidence: (json['confidence'] as num).toDouble(),
        summary: json['summary'] as String,
        improvement: json['improvement'] as String,
        promptVersion: json['prompt_version'] as String,
        rubricVersion: json['rubric_version'] as String,
        requiresHumanReview: json['requires_human_review'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class VoiceInterviewState {
  const VoiceInterviewState({
    this.sessionId,
    this.status = VoiceInterviewStatus.consent,
    this.consent,
    this.microphonePermissionGranted = false,
    this.currentQuestionIndex = 0,
    this.answers = const [],
    this.evaluation,
    this.pendingUploadCount = 0,
    this.humanReviewRequested = false,
    this.technicalNotice,
  });

  final String? sessionId;
  final VoiceInterviewStatus status;
  final VoiceConsent? consent;
  final bool microphonePermissionGranted;
  final int currentQuestionIndex;
  final List<VoiceAnswer> answers;
  final VoiceEvaluation? evaluation;
  final int pendingUploadCount;
  final bool humanReviewRequested;
  final String? technicalNotice;

  VoiceInterviewState copyWith({
    String? sessionId,
    VoiceInterviewStatus? status,
    VoiceConsent? consent,
    bool? microphonePermissionGranted,
    int? currentQuestionIndex,
    List<VoiceAnswer>? answers,
    VoiceEvaluation? evaluation,
    int? pendingUploadCount,
    bool? humanReviewRequested,
    String? technicalNotice,
    bool clearTechnicalNotice = false,
  }) => VoiceInterviewState(
    sessionId: sessionId ?? this.sessionId,
    status: status ?? this.status,
    consent: consent ?? this.consent,
    microphonePermissionGranted:
        microphonePermissionGranted ?? this.microphonePermissionGranted,
    currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
    answers: answers ?? this.answers,
    evaluation: evaluation ?? this.evaluation,
    pendingUploadCount: pendingUploadCount ?? this.pendingUploadCount,
    humanReviewRequested: humanReviewRequested ?? this.humanReviewRequested,
    technicalNotice: clearTechnicalNotice
        ? null
        : technicalNotice ?? this.technicalNotice,
  );

  Map<String, Object?> toJson() => {
    'session_id': sessionId,
    'status': status.name,
    'consent': consent?.toJson(),
    'microphone_permission_granted': microphonePermissionGranted,
    'current_question_index': currentQuestionIndex,
    'answers': answers.map((item) => item.toJson()).toList(),
    'evaluation': evaluation?.toJson(),
    'pending_upload_count': pendingUploadCount,
    'human_review_requested': humanReviewRequested,
    'technical_notice': technicalNotice,
  };

  factory VoiceInterviewState.fromJson(Map<String, Object?> json) {
    final restoredStatus = VoiceInterviewStatus.values.byName(
      json['status'] as String,
    );
    return VoiceInterviewState(
      sessionId: json['session_id'] as String?,
      status: restoredStatus == VoiceInterviewStatus.recording
          ? VoiceInterviewStatus.microphoneReady
          : restoredStatus,
      consent: json['consent'] == null
          ? null
          : VoiceConsent.fromJson(json['consent'] as Map<String, Object?>),
      microphonePermissionGranted:
          json['microphone_permission_granted'] as bool? ?? false,
      currentQuestionIndex: json['current_question_index'] as int? ?? 0,
      answers: (json['answers'] as List<Object?>? ?? const [])
          .map((item) => VoiceAnswer.fromJson(item as Map<String, Object?>))
          .toList(),
      evaluation: json['evaluation'] == null
          ? null
          : VoiceEvaluation.fromJson(
              json['evaluation'] as Map<String, Object?>,
            ),
      pendingUploadCount: json['pending_upload_count'] as int? ?? 0,
      humanReviewRequested: json['human_review_requested'] as bool? ?? false,
      technicalNotice: restoredStatus == VoiceInterviewStatus.recording
          ? 'The previous recording was interrupted and was not scored.'
          : json['technical_notice'] as String?,
    );
  }
}

/// Ordered as a real interview runs: the introduction first, because it is
/// what every interview opens with and the one answer a candidate can prepare
/// word for word. Scenario questions follow.
const voiceInterviewQuestions = [
  VoiceInterviewQuestion(
    id: 'self-introduction',
    category: 'सामान्य प्रश्न और परिचय',
    text: 'अपना परिचय दीजिए।',
    guidance: 'अपने नाम, पढ़ाई और अनुभवों को 1-2 मिनट में साफ बोलें।',
    competency: 'communication_clarity',
  ),
  VoiceInterviewQuestion(
    id: 'inventory-exception',
    category: 'काम से जुड़े सवाल',
    text: 'You count 21 units but the system shows 24. What would you do next?',
    competency: 'inventory_accuracy',
  ),
  VoiceInterviewQuestion(
    id: 'dispatch-priority',
    category: 'काम से जुड़े सवाल',
    text:
        'Two dispatches are delayed and one has a strict SLA. How would you prioritise?',
    competency: 'sla_discipline',
  ),
  VoiceInterviewQuestion(
    id: 'supervisor-escalation',
    category: 'काम से जुड़े सवाल',
    text:
        'How would you clearly escalate a safety or stock exception to your supervisor?',
    competency: 'safe_escalation',
  ),
];
