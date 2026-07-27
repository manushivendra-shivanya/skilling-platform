import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/analytics/analytics_tracker.dart';
import '../core/config/app_environment.dart';
import '../core/logging/app_logger.dart';
import '../core/network/connectivity_status.dart';
import '../core/repositories/candidate_session_repository.dart';
import '../core/storage/local_key_value_store.dart';
import '../features/onboarding/data/local_onboarding_entry_repository.dart';
import '../features/onboarding/domain/onboarding_entry_repository.dart';
import '../features/splash/data/mock_app_startup_repository.dart';
import '../features/splash/domain/app_startup_repository.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => const AppConfig.development(),
);

final appLoggerProvider = Provider<AppLogger>(
  (ref) => DebugAppLogger(enabled: ref.watch(appConfigProvider).enableLogging),
);

final analyticsTrackerProvider = Provider<AnalyticsTracker>(
  (ref) => InMemoryAnalyticsTracker(),
);

final localKeyValueStoreProvider = Provider<LocalKeyValueStore>(
  (ref) => InMemoryLocalKeyValueStore(),
);

final connectivityRepositoryProvider = Provider<ConnectivityRepository>((ref) {
  final repository = MockConnectivityRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

final candidateSessionRepositoryProvider = Provider<CandidateSessionRepository>(
  (ref) => MockCandidateSessionRepository(),
);

final appStartupRepositoryProvider = Provider<AppStartupRepository>(
  (ref) => MockAppStartupRepository(),
);

final onboardingEntryRepositoryProvider = Provider<OnboardingEntryRepository>(
  (ref) =>
      LocalOnboardingEntryRepository(ref.watch(localKeyValueStoreProvider)),
);
