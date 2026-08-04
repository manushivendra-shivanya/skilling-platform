/// A single multiple-choice answer option for a [CertificationExamQuestion].
/// Deliberately the same shape as `ClipAnswerOption` (id/label/feedback) so
/// the result screen can show right/wrong feedback the same way the
/// micro-lesson practice question does.
class ExamAnswerOption {
  const ExamAnswerOption({
    required this.id,
    required this.label,
    required this.feedback,
  });

  final String id;
  final String label;
  final String feedback;

  factory ExamAnswerOption.fromJson(Map<String, Object?> json) {
    return ExamAnswerOption(
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

/// One question in a [CertificationExam]. Unlike `MicroLessonClip` (which
/// carries a list of `competencyTags`, since one clip's question can speak
/// to several competencies at once), a certification question tests exactly
/// one [competencyId] -- a formal exam needs each question's contribution to
/// the overall certification to be unambiguous.
class CertificationExamQuestion {
  const CertificationExamQuestion({
    required this.id,
    required this.competencyId,
    required this.prompt,
    this.context,
    required this.options,
    required this.correctOptionId,
  });

  final String id;
  final String competencyId;
  final String prompt;

  /// Optional short situational paragraph shown above the prompt -- this
  /// content is text-only (no video), so a couple of sentences of scene-
  /// setting stand in for what a clip's transcript/description would do.
  final String? context;
  final List<ExamAnswerOption> options;
  final String correctOptionId;

  ExamAnswerOption get correctOption =>
      options.firstWhere((option) => option.id == correctOptionId);

  factory CertificationExamQuestion.fromJson(Map<String, Object?> json) {
    return CertificationExamQuestion(
      id: json['id']! as String,
      competencyId: json['competencyId']! as String,
      prompt: json['prompt']! as String,
      context: json['context'] as String?,
      options: (json['options'] as List<Object?>)
          .map(
            (item) => ExamAnswerOption.fromJson(item as Map<String, Object?>),
          )
          .toList(growable: false),
      correctOptionId: json['correctOptionId']! as String,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'competencyId': competencyId,
    'prompt': prompt,
    'context': context,
    'options': options.map((option) => option.toJson()).toList(),
    'correctOptionId': correctOptionId,
  };
}

/// A formal, timed certification exam: a fixed, hand-authored set of
/// questions with a time limit and a pass threshold, distinct from the
/// casual, unlimited-practice feel of micro-lesson clips. Loaded once from a
/// static JSON asset (v1 -- no admin authoring tooling exists yet).
class CertificationExam {
  const CertificationExam({
    required this.id,
    required this.title,
    required this.version,
    required this.description,
    required this.timeLimit,
    required this.passThresholdPercent,
    required this.questions,
  });

  final String id;
  final String title;
  final String version;
  final String description;
  final Duration timeLimit;
  final int passThresholdPercent;
  final List<CertificationExamQuestion> questions;

  factory CertificationExam.fromJson(Map<String, Object?> json) {
    return CertificationExam(
      id: json['id']! as String,
      title: json['title']! as String,
      version: json['version']! as String,
      description: json['description']! as String,
      timeLimit: Duration(seconds: json['timeLimitSeconds']! as int),
      passThresholdPercent: json['passThresholdPercent']! as int,
      questions: (json['questions'] as List<Object?>)
          .map(
            (item) => CertificationExamQuestion.fromJson(
              item as Map<String, Object?>,
            ),
          )
          .toList(growable: false),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'version': version,
    'description': description,
    'timeLimitSeconds': timeLimit.inSeconds,
    'passThresholdPercent': passThresholdPercent,
    'questions': questions.map((question) => question.toJson()).toList(),
  };
}
