import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../core/analytics/analytics_event.dart';
import '../../intelligence/presentation/candidate_intelligence_controller.dart';
import '../domain/learning_repository.dart';

class LearningState {
  const LearningState({
    required this.units,
    this.downloadedIds = const {},
    this.completedIds = const {},
  });

  final List<LearningUnit> units;
  final Set<String> downloadedIds;
  final Set<String> completedIds;

  double get progress => units.isEmpty ? 0 : completedIds.length / units.length;

  LearningState copyWith({
    Set<String>? downloadedIds,
    Set<String>? completedIds,
  }) {
    return LearningState(
      units: units,
      downloadedIds: downloadedIds ?? this.downloadedIds,
      completedIds: completedIds ?? this.completedIds,
    );
  }
}

final learningControllerProvider =
    AsyncNotifierProvider<LearningController, LearningState>(
      LearningController.new,
    );

class LearningController extends AsyncNotifier<LearningState> {
  @override
  Future<LearningState> build() async {
    final result = await ref.read(learningRepositoryProvider).loadPathway();
    final intelligence = await ref.watch(
      candidateIntelligenceControllerProvider.future,
    );
    return result.when(
      success: (units) => LearningState(
        units: units,
        downloadedIds: intelligence.learningProgress.downloadedUnitIds,
        completedIds: intelligence.learningProgress.completedUnitIds,
      ),
      failure: (failure) => throw failure,
    );
  }

  Future<void> toggleDownload(String id) async {
    final value = state.valueOrNull;
    if (value == null) return;
    final ids = {...value.downloadedIds};
    if (!ids.add(id)) ids.remove(id);
    state = AsyncData(value.copyWith(downloadedIds: ids));
    await ref
        .read(candidateIntelligenceControllerProvider.notifier)
        .updateLearning(
          downloadedUnitIds: ids,
          completedUnitIds: value.completedIds,
        );
  }

  Future<void> toggleComplete(String id) async {
    final value = state.valueOrNull;
    if (value == null) return;
    final ids = {...value.completedIds};
    if (!ids.add(id)) ids.remove(id);
    state = AsyncData(value.copyWith(completedIds: ids));
    await ref
        .read(candidateIntelligenceControllerProvider.notifier)
        .updateLearning(
          downloadedUnitIds: value.downloadedIds,
          completedUnitIds: ids,
        );
    await ref
        .read(analyticsTrackerProvider)
        .track(AnalyticsEvent.learningProgressSaved(id));
  }

  void retry() => ref.invalidateSelf();
}
