import '../../../core/errors/result.dart';

class LearningUnit {
  const LearningUnit({
    required this.id,
    required this.title,
    required this.durationMinutes,
    required this.isDailyMission,
    required this.version,
    required this.content,
  });

  final String id;
  final String title;
  final int durationMinutes;
  final bool isDailyMission;
  final String version;
  final String content;
}

abstract interface class LearningRepository {
  Future<Result<List<LearningUnit>>> loadPathway();
}
