import 'package:candidate_mobile/app/app.dart';
import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/core/analytics/analytics_tracker.dart';
import 'package:candidate_mobile/core/config/app_environment.dart';
import 'package:candidate_mobile/features/splash/domain/app_startup_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

extension CandidateAppPump on WidgetTester {
  Future<void> pumpCandidateApp({
    AppStartupRepository? startupRepository,
    AnalyticsTracker? analyticsTracker,
  }) {
    return pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(const AppConfig.development()),
          if (startupRepository != null)
            appStartupRepositoryProvider.overrideWithValue(startupRepository),
          if (analyticsTracker != null)
            analyticsTrackerProvider.overrideWithValue(analyticsTracker),
        ],
        child: const SkillingApp(),
      ),
    );
  }
}
