import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../domain/micro_lesson_clip.dart';

class MicroLessonClipState {
  const MicroLessonClipState({required this.clips});

  final List<MicroLessonClip> clips;

  List<MicroLessonClip> clipsForDomain(MicroLessonDomain domain) {
    return clips.where((clip) => clip.domain == domain).toList(growable: false);
  }

  List<MicroLessonClip> clipsForCompetency(String competencyTag) {
    return clips
        .where((clip) => clip.competencyTags.contains(competencyTag))
        .toList(growable: false);
  }
}

final microLessonClipControllerProvider =
    AsyncNotifierProvider<MicroLessonClipController, MicroLessonClipState>(
      MicroLessonClipController.new,
    );

class MicroLessonClipController extends AsyncNotifier<MicroLessonClipState> {
  @override
  Future<MicroLessonClipState> build() async {
    final result = await ref
        .read(microLessonClipRepositoryProvider)
        .loadClips();
    return result.when(
      success: (clips) => MicroLessonClipState(clips: clips),
      failure: (failure) => throw failure,
    );
  }

  void retry() => ref.invalidateSelf();
}
