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
import '../features/authentication/data/supabase_email_auth_repository.dart';
import '../features/certification_exam/data/asset_certification_exam_repository.dart';
import '../features/certification_exam/data/secure_certification_exam_attempt_repository.dart';
import '../features/certification_exam/domain/certification_exam_repository.dart';
import '../features/authentication/domain/development_auth_repository.dart';
import '../features/career_passport/data/wms_career_passport_repository.dart';
import '../features/career_passport/domain/career_passport_repository.dart';
import '../features/coach/data/api_coach_repository.dart';
import '../features/coach/data/local_demo_coach_repository.dart';
import '../features/coach/data/secure_coach_thread_repository.dart';
import '../features/coach/domain/coach_repository.dart';
import '../features/coach/domain/coach_thread_repository.dart';
import '../features/home/data/mock_home_dashboard_repository.dart';
import '../features/home/domain/home_dashboard_repository.dart';
import '../features/intelligence/data/offline_first_candidate_intelligence_repository.dart';
import '../features/intelligence/data/secure_candidate_intelligence_repository.dart';
import '../features/intelligence/domain/candidate_intelligence_repository.dart';
import '../features/jobs/data/api_jobs_repository.dart';
import '../features/jobs/data/local_mock_jobs_repository.dart';
import '../features/jobs/data/secure_saved_jobs_repository.dart';
import '../features/jobs/domain/jobs_repository.dart';
import '../features/jobs/domain/saved_jobs_repository.dart';
import '../features/learning/data/mock_learning_repository.dart';
import '../features/learning/domain/learning_repository.dart';
import '../features/micro_lessons/data/asset_micro_lesson_clip_repository.dart';
import '../features/micro_lessons/data/secure_micro_lesson_assessment_repository.dart';
import '../features/micro_lessons/data/secure_viewed_clips_repository.dart';
import '../features/micro_lessons/domain/micro_lesson_assessment_repository.dart';
import '../features/micro_lessons/domain/micro_lesson_clip_repository.dart';
import '../features/micro_lessons/domain/viewed_clips_repository.dart';
import '../features/networking/data/api_networking_repository.dart';
import '../features/networking/data/unavailable_networking_repository.dart';
import '../features/networking/domain/networking_repository.dart';
import '../features/onboarding/data/local_onboarding_entry_repository.dart';
import '../features/onboarding/data/secure_candidate_onboarding_repository.dart';
import '../features/onboarding/data/supabase_candidate_onboarding_repository.dart';
import '../features/onboarding/domain/candidate_onboarding_repository.dart';
import '../features/onboarding/domain/onboarding_entry_repository.dart';
import '../features/profile_details/data/in_memory_detailed_profile_repository.dart';
import '../features/profile_details/data/supabase_detailed_profile_repository.dart';
import '../features/profile_details/domain/detailed_profile_repository.dart';
import '../features/resume/data/api_resume_parsing_repository.dart';
import '../features/profile_assistant/data/api_profile_assistant_repository.dart';
import '../features/profile_assistant/data/unavailable_profile_assistant_repository.dart';
import '../features/profile_assistant/domain/profile_assistant_repository.dart';
import '../features/resume/data/platform_resume_file_picker.dart';
import '../features/resume/data/unavailable_resume_parsing_repository.dart';
import '../features/resume/domain/resume_file_picker.dart';
import '../features/resume/domain/resume_parsing_repository.dart';
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
    return SupabaseEmailAuthRepository(Supabase.instance.client);
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

/// Whether the app can actually reach live data right now.
///
/// Configuration alone is not enough: every Supabase-backed repository sends
/// the signed-in user's access token, and without one they fail before making
/// a request -- `Sign in again to view jobs`, and the same for shifts and the
/// career passport. A configured build with no session therefore shows empty
/// screens everywhere, which is what the dev skip-to-home produces and what
/// makes a review build unreviewable.
///
/// In a non-production build that resolves to the local mock repositories:
/// no identity means live data is impossible, so show something reviewable
/// instead of an error. Production keeps the live repository and its honest
/// "sign in again" failure -- a real user whose session expired must never be
/// quietly handed sample data.
///
/// Re-resolves on sign-in and sign-out rather than caching the decision made
/// at startup.
final canUseLiveBackendProvider = Provider<bool>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.hasSupabaseConfiguration) return false;
  if (config.isProduction) return true;

  final auth = Supabase.instance.client.auth;
  final subscription = auth.onAuthStateChange.listen(
    (_) => ref.invalidateSelf(),
  );
  ref.onDispose(subscription.cancel);
  return auth.currentSession != null;
});

final candidateOnboardingRepositoryProvider =
    Provider<CandidateOnboardingRepository>((ref) {
      if (ref.watch(appConfigProvider).hasSupabaseConfiguration &&
          ref.watch(canUseLiveBackendProvider)) {
        return SupabaseCandidateOnboardingRepository(Supabase.instance.client);
      }
      return SecureCandidateOnboardingRepository(
        ref.watch(secureKeyValueStoreProvider),
      );
    });

// Direct Supabase reads/writes under RLS, the same convention
// candidateOnboardingRepositoryProvider above already uses -- no apps/api
// involvement, since every field this repository touches is a simple
// owned-row read (see SupabaseDetailedProfileRepository's own doc comment).
final detailedProfileRepositoryProvider = Provider<DetailedProfileRepository>((
  ref,
) {
  if (ref.watch(appConfigProvider).hasSupabaseConfiguration &&
      ref.watch(canUseLiveBackendProvider)) {
    return SupabaseDetailedProfileRepository(Supabase.instance.client);
  }
  return InMemoryDetailedProfileRepository();
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

final viewedClipsRepositoryProvider = Provider<ViewedClipsRepository>(
  (ref) => SecureViewedClipsRepository(ref.watch(secureKeyValueStoreProvider)),
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

final coachRepositoryProvider = Provider<CoachRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.hasSupabaseConfiguration &&
      config.hasApiConfiguration &&
      ref.watch(canUseLiveBackendProvider)) {
    return ApiCoachRepository(
      dio: Dio(),
      supabaseClient: Supabase.instance.client,
      apiBaseUrl: config.apiBaseUrl,
    );
  }
  return const LocalDemoCoachRepository();
});

// On-device only, always -- Coach threads are local browsing history (see
// CoachThread's doc comment), not gated by live-backend availability the
// way ApiCoachRepository is.
final coachThreadRepositoryProvider = Provider<CoachThreadRepository>(
  (ref) => SecureCoachThreadRepository(ref.watch(secureKeyValueStoreProvider)),
);

final resumeParsingRepositoryProvider = Provider<ResumeParsingRepository>((
  ref,
) {
  final config = ref.watch(appConfigProvider);
  if (config.hasSupabaseConfiguration &&
      config.hasApiConfiguration &&
      ref.watch(canUseLiveBackendProvider)) {
    return ApiResumeParsingRepository(
      dio: Dio(),
      supabaseClient: Supabase.instance.client,
      apiBaseUrl: config.apiBaseUrl,
    );
  }
  return const UnavailableResumeParsingRepository();
});

/// Not config-gated the way `resumeParsingRepositoryProvider` is: picking
/// a file is a purely local, always-available capability. Whether the
/// chosen file can then be *parsed* is the repository's business, and
/// letting the picker open regardless keeps the failure honest -- the
/// candidate is told parsing is unavailable, rather than the upload
/// button being mysteriously absent.
final resumeFilePickerProvider = Provider<ResumeFilePicker>(
  (ref) => const PlatformResumeFilePicker(),
);

final profileAssistantRepositoryProvider = Provider<ProfileAssistantRepository>(
  (ref) {
    final config = ref.watch(appConfigProvider);
    if (config.hasSupabaseConfiguration &&
        config.hasApiConfiguration &&
        ref.watch(canUseLiveBackendProvider)) {
      return ApiProfileAssistantRepository(
        dio: Dio(),
        supabaseClient: Supabase.instance.client,
        apiBaseUrl: config.apiBaseUrl,
      );
    }
    return const UnavailableProfileAssistantRepository();
  },
);

final networkingRepositoryProvider = Provider<NetworkingRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.hasSupabaseConfiguration &&
      config.hasApiConfiguration &&
      ref.watch(canUseLiveBackendProvider)) {
    return ApiNetworkingRepository(
      dio: Dio(),
      supabaseClient: Supabase.instance.client,
      apiBaseUrl: config.apiBaseUrl,
    );
  }
  return const UnavailableNetworkingRepository();
});

final jobsRepositoryProvider = Provider<JobsRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.hasSupabaseConfiguration &&
      config.hasApiConfiguration &&
      ref.watch(canUseLiveBackendProvider)) {
    return ApiJobsRepository(
      dio: Dio(),
      supabaseClient: Supabase.instance.client,
      apiBaseUrl: config.apiBaseUrl,
    );
  }
  return LocalMockJobsRepository(ref.watch(secureKeyValueStoreProvider));
});

// On-device only regardless of backend configuration -- there is no
// `saved_jobs` table, this is a bookmark list scoped to this device, same
// posture as micro-lesson/certification-exam attempt storage.
final savedJobsRepositoryProvider = Provider<SavedJobsRepository>(
  (ref) => SecureSavedJobsRepository(ref.watch(secureKeyValueStoreProvider)),
);

final shiftsRepositoryProvider = Provider<ShiftsRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.hasSupabaseConfiguration &&
      config.hasApiConfiguration &&
      ref.watch(canUseLiveBackendProvider)) {
    return ApiShiftsRepository(
      dio: Dio(),
      supabaseClient: Supabase.instance.client,
      apiBaseUrl: config.apiBaseUrl,
    );
  }
  return LocalMockShiftsRepository(ref.watch(secureKeyValueStoreProvider));
});

// Direct-to-Supabase -- no BFF involved for these three, so hasApiConfiguration
// is irrelevant, but they still read as the signed-in user and so still need a
// session (see canUseLiveBackendProvider).
final shiftAvailabilityRepositoryProvider =
    Provider<ShiftAvailabilityRepository>((ref) {
      if (ref.watch(canUseLiveBackendProvider)) {
        return SupabaseShiftAvailabilityRepository(Supabase.instance.client);
      }
      return _UnavailableShiftAvailabilityRepository();
    });

final shiftPayoutRepositoryProvider = Provider<ShiftPayoutRepository>((ref) {
  if (ref.watch(canUseLiveBackendProvider)) {
    return SupabaseShiftPayoutRepository(Supabase.instance.client);
  }
  return _UnavailableShiftPayoutRepository();
});

final shiftGrievanceRepositoryProvider = Provider<ShiftGrievanceRepository>((
  ref,
) {
  if (ref.watch(canUseLiveBackendProvider)) {
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
    // Null unless the backend is genuinely usable: the passport's share flow
    // sends the access token, so without a session it can only fail.
    supabaseClient: ref.watch(canUseLiveBackendProvider)
        ? Supabase.instance.client
        : null,
    apiBaseUrl:
        config.hasApiConfiguration && ref.watch(canUseLiveBackendProvider)
        ? config.apiBaseUrl
        : null,
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
