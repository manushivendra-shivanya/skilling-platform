import 'micro_lesson_clip.dart';

class MicroLessonClipValidationError {
  const MicroLessonClipValidationError(this.clipId, this.message);

  final String clipId;
  final String message;

  @override
  String toString() => '$clipId: $message';
}

List<MicroLessonClipValidationError> validateMicroLessonClip(
  MicroLessonClip clip,
) {
  final errors = <MicroLessonClipValidationError>[];
  void add(String message) {
    errors.add(MicroLessonClipValidationError(clip.id, message));
  }

  if (clip.id.trim().isEmpty) {
    add('id is required');
  }
  if (clip.title.trim().isEmpty) {
    add('title is required');
  }
  if (clip.sequenceNumber <= 0) {
    add('sequenceNumber must be positive');
  }
  if (clip.durationSeconds != 10) {
    add('durationSeconds must be exactly 10 for this micro-clip format');
  }
  if (clip.description.trim().isEmpty) {
    add('description is required');
  }
  if (clip.expectedObservation.trim().isEmpty) {
    add('expectedObservation is required');
  }
  if (clip.expectedDecision.trim().isEmpty) {
    add('expectedDecision is required');
  }
  if (clip.competencyTags.isEmpty) {
    add('at least one competencyTag is required');
  }
  if (clip.answerOptions.length < 2) {
    add('at least two answerOptions required');
  }
  if (!clip.answerOptions.any((option) => option.id == clip.correctAnswerId)) {
    add('correctAnswer must match an answer option id');
  }
  if (clip.scoringRules.technicalFailuresScoreable) {
    add('technical failures must not be scoreable');
  }
  if (clip.scoringRules.correctAnswerPoints > clip.scoringRules.maxPoints) {
    add('correctAnswerPoints cannot exceed maxPoints');
  }
  if (clip.modes.contains(MicroLessonMode.assessment) &&
      clip.auditEvents.isEmpty) {
    add('assessment clips must define auditEvents');
  }

  return errors;
}

List<MicroLessonClipValidationError> validateMicroLessonClipCatalogue(
  List<MicroLessonClip> clips,
) {
  final errors = <MicroLessonClipValidationError>[];
  final ids = <String>{};
  final sequenceKeys = <String>{};
  for (final clip in clips) {
    if (!ids.add(clip.id)) {
      errors.add(MicroLessonClipValidationError(clip.id, 'duplicate clip id'));
    }
    final sequenceKey = '${clip.module.name}:${clip.sequenceNumber}';
    if (!sequenceKeys.add(sequenceKey)) {
      errors.add(
        MicroLessonClipValidationError(
          clip.id,
          'duplicate sequenceNumber within ${clip.module.name}',
        ),
      );
    }
    errors.addAll(validateMicroLessonClip(clip));
  }
  return errors;
}
