/// A candidate's answer to one [CertificationExamQuestion] within a
/// [CertificationExamAttempt]. Snapshots the question's competency and
/// correct option at submission time -- same "record what the candidate
/// actually saw and answered" rationale as
/// `MicroLessonAssessmentAttempt`/`RecordedAuditEvent`.
class QuestionResponse {
  const QuestionResponse({
    required this.questionId,
    required this.competencyId,
    required this.selectedOptionId,
    required this.correctOptionId,
  });

  final String questionId;
  final String competencyId;
  final String selectedOptionId;
  final String correctOptionId;

  bool get isCorrect => selectedOptionId == correctOptionId;

  Map<String, Object?> toJson() => {
    'questionId': questionId,
    'competencyId': competencyId,
    'selectedOptionId': selectedOptionId,
    'correctOptionId': correctOptionId,
  };

  factory QuestionResponse.fromJson(Map<String, Object?> json) {
    return QuestionResponse(
      questionId: json['questionId']! as String,
      competencyId: json['competencyId']! as String,
      selectedOptionId: json['selectedOptionId']! as String,
      correctOptionId: json['correctOptionId']! as String,
    );
  }
}

/// A single full sitting of a [CertificationExam] -- one response per
/// question, scored as a whole rather than question-by-question. Unlike
/// `MicroLessonAssessmentAttempt` (binary 0/100 for one question), scoring
/// here is the percentage of questions answered correctly across the whole
/// attempt, checked against the exam's `passThresholdPercent` to decide
/// pass/fail.
class CertificationExamAttempt {
  const CertificationExamAttempt({
    required this.id,
    required this.candidateId,
    required this.examId,
    required this.examVersion,
    required this.responses,
    required this.startedAt,
    required this.submittedAt,
  });

  final String id;
  final String candidateId;
  final String examId;
  final String examVersion;
  final List<QuestionResponse> responses;
  final DateTime startedAt;
  final DateTime submittedAt;

  Duration get timeTaken => submittedAt.difference(startedAt);

  int get correctCount => responses.where((r) => r.isCorrect).length;

  /// 0-100. Rounds to the nearest whole percent; `responses` is never empty
  /// for a real recorded attempt (enforced by the repository).
  int get scorePercent =>
      responses.isEmpty ? 0 : (correctCount / responses.length * 100).round();

  bool passed(int passThresholdPercent) => scorePercent >= passThresholdPercent;

  Map<String, Object?> toJson() => {
    'id': id,
    'candidateId': candidateId,
    'examId': examId,
    'examVersion': examVersion,
    'responses': responses.map((response) => response.toJson()).toList(),
    'startedAt': startedAt.toUtc().toIso8601String(),
    'submittedAt': submittedAt.toUtc().toIso8601String(),
  };

  factory CertificationExamAttempt.fromJson(Map<String, Object?> json) {
    return CertificationExamAttempt(
      id: json['id']! as String,
      candidateId: json['candidateId']! as String,
      examId: json['examId']! as String,
      examVersion: json['examVersion']! as String,
      responses: (json['responses'] as List<Object?>)
          .map(
            (item) => QuestionResponse.fromJson(item as Map<String, Object?>),
          )
          .toList(growable: false),
      startedAt: DateTime.parse(json['startedAt']! as String),
      submittedAt: DateTime.parse(json['submittedAt']! as String),
    );
  }
}
