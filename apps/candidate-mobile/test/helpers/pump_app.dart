import 'package:candidate_mobile/app/app.dart';
import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/app/theme/app_theme.dart';
import 'package:candidate_mobile/core/analytics/analytics_tracker.dart';
import 'package:candidate_mobile/core/config/app_environment.dart';
import 'package:candidate_mobile/features/onboarding/domain/onboarding_entry_repository.dart';
import 'package:candidate_mobile/features/splash/domain/app_startup_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

extension CandidateAppPump on WidgetTester {
  Future<void> pumpCandidateApp({
    AppStartupRepository? startupRepository,
    OnboardingEntryRepository? onboardingEntryRepository,
    AnalyticsTracker? analyticsTracker,
    AppConfig config = const AppConfig.development(),
  }) {
    return pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          if (startupRepository != null)
            appStartupRepositoryProvider.overrideWithValue(startupRepository),
          if (onboardingEntryRepository != null)
            onboardingEntryRepositoryProvider.overrideWithValue(
              onboardingEntryRepository,
            ),
          if (analyticsTracker != null)
            analyticsTrackerProvider.overrideWithValue(analyticsTracker),
        ],
        child: const SkillingApp(),
      ),
    );
  }

  Future<void> pumpThemedWidget(
    Widget child, {
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    return pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery(
          data: MediaQueryData(textScaler: textScaler),
          child: Scaffold(body: child),
        ),
      ),
    );
  }
}
