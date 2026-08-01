import '../../../core/errors/result.dart';
import 'micro_lesson_clip.dart';

abstract interface class MicroLessonClipRepository {
  Future<Result<List<MicroLessonClip>>> loadClips();
}
