import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
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
    return result.when(
      success: (units) => LearningState(units: units),
      failure: (failure) => throw failure,
    );
  }

  void toggleDownload(String id) {
    final value = state.valueOrNull;
    if (value == null) return;
    final ids = {...value.downloadedIds};
    if (!ids.add(id)) ids.remove(id);
    state = AsyncData(value.copyWith(downloadedIds: ids));
  }

  void toggleComplete(String id) {
    final value = state.valueOrNull;
    if (value == null) return;
    final ids = {...value.completedIds};
    if (!ids.add(id)) ids.remove(id);
    state = AsyncData(value.copyWith(completedIds: ids));
  }

  void retry() => ref.invalidateSelf();
}
