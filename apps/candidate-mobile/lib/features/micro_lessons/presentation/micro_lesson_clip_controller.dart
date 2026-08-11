import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../domain/micro_lesson_clip.dart';

class MicroLessonClipState {
  const MicroLessonClipState({
    required this.clips,
    this.viewedClipIds = const {},
  });

  final List<MicroLessonClip> clips;

  /// On-device only -- see `ViewedClipsRepository`'s doc comment for why
  /// this doesn't sync across devices or become employer-visible evidence.
  final Set<String> viewedClipIds;

  MicroLessonClipState copyWith({Set<String>? viewedClipIds}) =>
      MicroLessonClipState(
        clips: clips,
        viewedClipIds: viewedClipIds ?? this.viewedClipIds,
      );

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
  String? _candidateId;

  @override
  Future<MicroLessonClipState> build() async {
    final result = await ref
        .read(microLessonClipRepositoryProvider)
        .loadClips();

    // Viewed state is genuinely optional context, same posture as Jobs'
    // treatment of Career Passport/Shift availability: no session (or a
    // read failure) means an empty viewed set rather than blocking the
    // clip catalogue from loading at all.
    final session =
        (await ref.read(candidateSessionRepositoryProvider).readSession()).when(
          success: (value) => value,
          failure: (_) => null,
        );
    _candidateId = session?.isAuthenticated == true
        ? session!.candidateId
        : null;
    final viewedClipIds = _candidateId == null
        ? const <String>{}
        : (await ref
                  .read(viewedClipsRepositoryProvider)
                  .readViewedClipIds(_candidateId!))
              .when<Set<String>>(
                success: (value) => value,
                failure: (_) => const {},
              );

    return result.when(
      success: (clips) {
        final orderedClips = clips.toList()
          ..sort(_compareClipsByOperationalSequence);
        return MicroLessonClipState(
          clips: List.unmodifiable(orderedClips),
          viewedClipIds: viewedClipIds,
        );
      },
      failure: (failure) => throw failure,
    );
  }

  /// Idempotent and silent on failure -- called from the player every time
  /// playback crosses the near-end threshold, not just once, and a device
  /// storage hiccup here shouldn't interrupt watching the clip.
  Future<void> markViewed(String clipId) async {
    final value = state.valueOrNull;
    final candidateId = _candidateId;
    if (value == null || candidateId == null) return;
    if (value.viewedClipIds.contains(clipId)) return;
    state = AsyncData(
      value.copyWith(viewedClipIds: {...value.viewedClipIds, clipId}),
    );
    await ref
        .read(viewedClipsRepositoryProvider)
        .markViewed(candidateId, clipId);
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
