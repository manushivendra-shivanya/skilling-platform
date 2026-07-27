import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../core/analytics/analytics_event.dart';
import '../domain/home_dashboard_repository.dart';

final homeDashboardControllerProvider =
    AsyncNotifierProvider<HomeDashboardController, HomeDashboard?>(
      HomeDashboardController.new,
    );

class HomeDashboardController extends AsyncNotifier<HomeDashboard?> {
  @override
  Future<HomeDashboard?> build() => _load();

  Future<HomeDashboard?> _load() async {
    final result = await ref
        .read(homeDashboardRepositoryProvider)
        .loadDashboard();
    return result.when(
      success: (dashboard) => dashboard,
      failure: (failure) => throw failure,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading<HomeDashboard?>().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
    if (!state.hasError) {
      unawaited(
        ref
            .read(analyticsTrackerProvider)
            .track(AnalyticsEvent.homeDashboardRefreshed()),
      );
    }
  }
}
