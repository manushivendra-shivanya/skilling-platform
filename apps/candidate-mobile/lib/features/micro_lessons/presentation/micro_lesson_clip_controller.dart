import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../domain/micro_lesson_clip.dart';

class MicroLessonClipState {
  const MicroLessonClipState({required this.clips});

  final List<MicroLessonClip> clips;

  List<MicroLessonClip> clipsForDomain(MicroLessonDomain domain) {
    return clips.where((clip) => clip.domain == domain).toList(growable: false);
  }

  List<MicroLessonClip> clipsForModule(MicroLessonModule module) {
    final moduleClips = clips.where((clip) => clip.module == module).toList();
    moduleClips.sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));
    return List.unmodifiable(moduleClips);
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
      success: (clips) {
        final orderedClips = clips.toList()
          ..sort(_compareClipsByOperationalSequence);
        return MicroLessonClipState(clips: List.unmodifiable(orderedClips));
      },
      failure: (failure) => throw failure,
    );
  }

  void retry() => ref.invalidateSelf();
}

int _compareClipsByOperationalSequence(MicroLessonClip a, MicroLessonClip b) {
  final moduleComparison = _moduleSortOrder(
    a.module,
  ).compareTo(_moduleSortOrder(b.module));
  if (moduleComparison != 0) {
    return moduleComparison;
  }
  return a.sequenceNumber.compareTo(b.sequenceNumber);
}

int _moduleSortOrder(MicroLessonModule module) {
  return switch (module) {
    MicroLessonModule.inward => 0,
    MicroLessonModule.processing => 1,
    MicroLessonModule.dispatch => 2,
  };
}
