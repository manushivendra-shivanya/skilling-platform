import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/analytics/analytics_tracker.dart';
import '../core/config/app_environment.dart';
import '../core/logging/app_logger.dart';
import '../core/network/connectivity_status.dart';
import '../core/repositories/candidate_session_repository.dart';
import '../core/storage/local_key_value_store.dart';
import '../core/storage/secure_key_value_store.dart';
import '../features/authentication/data/mock_development_auth_repository.dart';
import '../features/authentication/domain/development_auth_repository.dart';
import '../features/home/data/mock_home_dashboard_repository.dart';
import '../features/home/domain/home_dashboard_repository.dart';
import '../features/jobs/data/local_mock_jobs_repository.dart';
import '../features/jobs/domain/jobs_repository.dart';
import '../features/learning/data/mock_learning_repository.dart';
import '../features/learning/domain/learning_repository.dart';
import '../features/onboarding/data/local_onboarding_entry_repository.dart';
import '../features/onboarding/data/secure_candidate_onboarding_repository.dart';
import '../features/onboarding/domain/candidate_onboarding_repository.dart';
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
  (ref) =>
      SecureCandidateSessionRepository(ref.watch(secureKeyValueStoreProvider)),
);

final secureKeyValueStoreProvider = Provider<SecureKeyValueStore>(
  (ref) => FlutterSecureKeyValueStore(),
);

final developmentAuthRepositoryProvider = Provider<DevelopmentAuthRepository>(
  (ref) =>
      MockDevelopmentAuthRepository(!ref.watch(appConfigProvider).isProduction),
);

final appStartupRepositoryProvider = Provider<AppStartupRepository>(
  (ref) => MockAppStartupRepository(),
);

final onboardingEntryRepositoryProvider = Provider<OnboardingEntryRepository>(
  (ref) =>
      LocalOnboardingEntryRepository(ref.watch(localKeyValueStoreProvider)),
);

final candidateOnboardingRepositoryProvider =
    Provider<CandidateOnboardingRepository>(
      (ref) => SecureCandidateOnboardingRepository(
        ref.watch(secureKeyValueStoreProvider),
      ),
    );

final homeDashboardRepositoryProvider = Provider<HomeDashboardRepository>(
  (ref) => MockHomeDashboardRepository(),
);

final learningRepositoryProvider = Provider<LearningRepository>(
  (ref) => MockLearningRepository(),
);

final jobsRepositoryProvider = Provider<JobsRepository>(
  (ref) => LocalMockJobsRepository(ref.watch(secureKeyValueStoreProvider)),
);
