import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../core/analytics/analytics_event.dart';
import '../domain/app_startup_state.dart';

final appStartupControllerProvider =
    AsyncNotifierProvider<AppStartupController, AppStartupState>(
      AppStartupController.new,
    );

class AppStartupController extends AsyncNotifier<AppStartupState> {
  @override
  Future<AppStartupState> build() async {
    unawaited(
      ref.read(analyticsTrackerProvider).track(AnalyticsEvent.appOpened()),
    );

    final result = await ref.read(appStartupRepositoryProvider).initialize();
    return result.when(
      success: (state) => state,
      failure: (failure) => throw failure,
    );
  }

  void retry() {
    ref.invalidateSelf();
  }
}
