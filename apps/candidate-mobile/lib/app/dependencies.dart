import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/analytics/analytics_tracker.dart';
import '../core/config/app_environment.dart';
import '../core/errors/app_failure.dart';
import '../core/errors/result.dart';
import '../core/logging/app_logger.dart';
import '../core/network/connectivity_status.dart';
import '../core/repositories/candidate_session_repository.dart';
import '../core/storage/local_key_value_store.dart';
import '../core/storage/secure_key_value_store.dart';
import '../features/authentication/data/google_auth_repository.dart';
import '../features/authentication/data/mock_development_auth_repository.dart';
import '../features/certification_exam/data/asset_certification_exam_repository.dart';
import '../features/certification_exam/data/secure_certification_exam_attempt_repository.dart';
import '../features/certification_exam/domain/certification_exam_repository.dart';
import '../features/authentication/data/supabase_phone_auth_repository.dart';
import '../features/authentication/domain/development_auth_repository.dart';
import '../features/career_passport/data/wms_career_passport_repository.dart';
import '../features/career_passport/domain/career_passport_repository.dart';
import '../features/home/data/mock_home_dashboard_repository.dart';
import '../features/home/domain/home_dashboard_repository.dart';
import '../features/intelligence/data/offline_first_candidate_intelligence_repository.dart';
import '../features/intelligence/data/secure_candidate_intelligence_repository.dart';
import '../features/intelligence/domain/candidate_intelligence_repository.dart';
import '../features/jobs/data/api_jobs_repository.dart';
import '../features/jobs/data/local_mock_jobs_repository.dart';
import '../features/jobs/domain/jobs_repository.dart';
import '../features/learning/data/mock_learning_repository.dart';
import '../features/learning/domain/learning_repository.dart';
import '../features/micro_lessons/data/asset_micro_lesson_clip_repository.dart';
import '../features/micro_lessons/data/secure_micro_lesson_assessment_repository.dart';
import '../features/micro_lessons/domain/micro_lesson_assessment_repository.dart';
import '../features/micro_lessons/domain/micro_lesson_clip_repository.dart';
import '../features/onboarding/data/local_onboarding_entry_repository.dart';
import '../features/onboarding/data/secure_candidate_onboarding_repository.dart';
import '../features/onboarding/data/supabase_candidate_onboarding_repository.dart';
import '../features/onboarding/domain/candidate_onboarding_repository.dart';
import '../features/onboarding/domain/onboarding_entry_repository.dart';
import '../features/shifts/data/api_shifts_repository.dart';
import '../features/shifts/data/local_mock_shifts_repository.dart';
import '../features/shifts/data/supabase_shift_availability_repository.dart';
import '../features/shifts/data/supabase_shift_grievance_repository.dart';
import '../features/shifts/data/supabase_shift_payout_repository.dart';
import '../features/shifts/domain/shift_availability.dart';
import '../features/shifts/domain/shift_grievance.dart';
import '../features/shifts/domain/shift_payout.dart';
import '../features/shifts/domain/shifts_repository.dart';
import '../features/splash/data/mock_app_startup_repository.dart';
import '../features/splash/domain/app_startup_repository.dart';
import '../features/voice/data/record_voice_capture_repository.dart';
import '../features/voice/data/secure_voice_interview_repository.dart';
import '../features/voice/domain/voice_interview_repository.dart';
import '../features/workplace_simulation/data/asset_simulation_content_repository.dart';
import '../features/workplace_simulation/data/local_simulation_attempt_repository.dart';
import '../features/workplace_simulation/data/offline_first_simulation_attempt_repository.dart';
import '../features/workplace_simulation/data/wms_remote_sync_client.dart';
import '../features/workplace_simulation/domain/simulation_repositories.dart';

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

final developmentAuthRepositoryProvider = Provider<DevelopmentAuthRepository>((
  ref,
) {
  final config = ref.watch(appConfigProvider);
  if (config.hasSupabaseConfiguration) {
    return SupabasePhoneAuthRepository(Supabase.instance.client);
  }
  return MockDevelopmentAuthRepository(!config.isProduction);
});

/// Null when Google Sign-In isn't configured for this build (no Supabase
/// backend, or no GOOGLE_WEB_CLIENT_ID dart-define) -- callers treat that as
/// "option unavailable" rather than attempting a doomed sign-in.
final googleAuthRepositoryProvider = Provider<GoogleAuthRepository?>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.hasGoogleSignInConfiguration) {
    return null;
  }
  return GoogleAuthRepository(
    Supabase.instance.client,
    webClientId: config.googleWebClientId,
  );
});

final appStartupRepositoryProvider = Provider<AppStartupRepository>(
  (ref) => MockAppStartupRepository(),
);

final onboardingEntryRepositoryProvider = Provider<OnboardingEntryRepository>(
  (ref) =>
      LocalOnboardingEntryRepository(ref.watch(localKeyValueStoreProvider)),
);

final candidateOnboardingRepositoryProvider =
    Provider<CandidateOnboardingRepository>((ref) {
      if (ref.watch(appConfigProvider).hasSupabaseConfiguration) {
        return SupabaseCandidateOnboardingRepository(Supabase.instance.client);
      }
      return SecureCandidateOnboardingRepository(
        ref.watch(secureKeyValueStoreProvider),
      );
    });

final homeDashboardRepositoryProvider = Provider<HomeDashboardRepository>(
  (ref) => MockHomeDashboardRepository(),
);

final learningRepositoryProvider = Provider<LearningRepository>(
  (ref) => MockLearningRepository(),
);

final microLessonClipRepositoryProvider = Provider<MicroLessonClipRepository>(
  (ref) => AssetMicroLessonClipRepository(
    cdnBaseUrl: ref.watch(appConfigProvider).microLessonCdnBaseUrl,
  ),
);

final microLessonAssessmentRepositoryProvider =
    Provider<MicroLessonAssessmentRepository>(
      (ref) => SecureMicroLessonAssessmentRepository(
        ref.watch(secureKeyValueStoreProvider),
      ),
    );

final certificationExamRepositoryProvider =
    Provider<CertificationExamRepository>(
      (ref) => const AssetCertificationExamRepository(),
    );

final certificationExamAttemptRepositoryProvider =
    Provider<CertificationExamAttemptRepository>(
      (ref) => SecureCertificationExamAttemptRepository(
        ref.watch(secureKeyValueStoreProvider),
      ),
    );

final jobsRepositoryProvider = Provider<JobsRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.hasSupabaseConfiguration && config.hasApiConfiguration) {
    return ApiJobsRepository(
      dio: Dio(),
      supabaseClient: Supabase.instance.client,
      apiBaseUrl: config.apiBaseUrl,
    );
  }
  return LocalMockJobsRepository(ref.watch(secureKeyValueStoreProvider));
});

final shiftsRepositoryProvider = Provider<ShiftsRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.hasSupabaseConfiguration && config.hasApiConfiguration) {
    return ApiShiftsRepository(
      dio: Dio(),
      supabaseClient: Supabase.instance.client,
      apiBaseUrl: config.apiBaseUrl,
    );
  }
  return LocalMockShiftsRepository(ref.watch(secureKeyValueStoreProvider));
});

// Direct-to-Supabase, matching candidateOnboardingRepositoryProvider's
// simpler branching -- no BFF involved for these three, so only
// hasSupabaseConfiguration matters, not hasApiConfiguration.
final shiftAvailabilityRepositoryProvider =
    Provider<ShiftAvailabilityRepository>((ref) {
      if (ref.watch(appConfigProvider).hasSupabaseConfiguration) {
        return SupabaseShiftAvailabilityRepository(Supabase.instance.client);
      }
      return _UnavailableShiftAvailabilityRepository();
    });

final shiftPayoutRepositoryProvider = Provider<ShiftPayoutRepository>((ref) {
  if (ref.watch(appConfigProvider).hasSupabaseConfiguration) {
    return SupabaseShiftPayoutRepository(Supabase.instance.client);
  }
  return _UnavailableShiftPayoutRepository();
});

final shiftGrievanceRepositoryProvider = Provider<ShiftGrievanceRepository>((
  ref,
) {
  if (ref.watch(appConfigProvider).hasSupabaseConfiguration) {
    return SupabaseShiftGrievanceRepository(Supabase.instance.client);
  }
  return _UnavailableShiftGrievanceRepository();
});

final candidateIntelligenceRepositoryProvider =
    Provider<CandidateIntelligenceRepository>((ref) {
      final local = SecureCandidateIntelligenceRepository(
        ref.watch(secureKeyValueStoreProvider),
      );
      if (ref.watch(appConfigProvider).hasSupabaseConfiguration) {
        return OfflineFirstCandidateIntelligenceRepository(
          local,
          Supabase.instance.client,
        );
      }
      return local;
    });

final voiceInterviewRepositoryProvider = Provider<VoiceInterviewRepository>(
  (ref) =>
      SecureVoiceInterviewRepository(ref.watch(secureKeyValueStoreProvider)),
);

final voiceCaptureRepositoryProvider = Provider<VoiceCaptureRepository>((ref) {
  final repository = RecordVoiceCaptureRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

final resumableMediaUploadRepositoryProvider =
    Provider<ResumableMediaUploadRepository>(
      (ref) => const LocalQueuedMediaUploadRepository(),
    );

final simulationContentRepositoryProvider =
    Provider<SimulationContentRepository>(
      (ref) => AssetSimulationContentRepository(),
    );

final simulationAttemptRepositoryProvider =
    Provider<SimulationAttemptRepository>((ref) {
      final store = ref.watch(secureKeyValueStoreProvider);
      final local = LocalSimulationAttemptRepository(store);
      final config = ref.watch(appConfigProvider);
      if (config.hasSupabaseConfiguration && config.hasApiConfiguration) {
        return OfflineFirstSimulationAttemptRepository(
          local: local,
          store: store,
          remote: WmsRemoteSyncClient(
            dio: Dio(),
            supabaseClient: Supabase.instance.client,
            apiBaseUrl: config.apiBaseUrl,
          ),
        );
      }
      return local;
    });

final careerPassportRepositoryProvider = Provider<CareerPassportRepository>((
  ref,
) {
  final config = ref.watch(appConfigProvider);
  return WmsCareerPassportRepository(
    attemptRepository: ref.watch(simulationAttemptRepositoryProvider),
    microLessonAssessmentRepository: ref.watch(
      microLessonAssessmentRepositoryProvider,
    ),
    certificationExamRepository: ref.watch(certificationExamRepositoryProvider),
    certificationExamAttemptRepository: ref.watch(
      certificationExamAttemptRepositoryProvider,
    ),
    shiftsRepository: ref.watch(shiftsRepositoryProvider),
    supabaseClient: config.hasSupabaseConfiguration
        ? Supabase.instance.client
        : null,
    apiBaseUrl: config.hasApiConfiguration ? config.apiBaseUrl : null,
    dio: Dio(),
  );
});

// Fallback stubs for the three direct-to-Supabase shift repositories when
// Supabase isn't configured at all (a pure local/mock build) -- there is
// no meaningful local-mock equivalent for account-scoped availability,
// payouts, or grievances, so these simply report unavailable rather than
// silently pretending to work.
const _shiftFeatureUnavailable = StorageFailure(
  'This requires an account connection.',
);

class _UnavailableShiftAvailabilityRepository
    implements ShiftAvailabilityRepository {
  @override
  Future<Result<ShiftAvailability>> readAvailability(
    String candidateId,
  ) async => const Success(ShiftAvailability());

  @override
  Future<Result<void>> saveAvailability(
    String candidateId,
    ShiftAvailability availability,
  ) async => const ResultFailure(_shiftFeatureUnavailable);
}

class _UnavailableShiftPayoutRepository implements ShiftPayoutRepository {
  @override
  Future<Result<List<ShiftPayout>>> loadPayouts(String candidateId) async =>
      const Success([]);
}

class _UnavailableShiftGrievanceRepository implements ShiftGrievanceRepository {
  @override
  Future<Result<List<ShiftGrievance>>> loadGrievances(
    String candidateId,
  ) async => const Success([]);

  @override
  Future<Result<void>> submitGrievance(
    String candidateId, {
    required ShiftGrievanceCategory category,
    required String description,
    String? shiftApplicationId,
  }) async => const ResultFailure(_shiftFeatureUnavailable);
}
