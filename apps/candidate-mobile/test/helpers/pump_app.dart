import 'package:candidate_mobile/app/app.dart';
import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/app/theme/app_theme.dart';
import 'package:candidate_mobile/core/analytics/analytics_tracker.dart';
import 'package:candidate_mobile/core/config/app_environment.dart';
import 'package:candidate_mobile/core/network/connectivity_status.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:candidate_mobile/features/authentication/domain/development_auth_repository.dart';
import 'package:candidate_mobile/core/errors/app_failure.dart';
import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/features/certification_exam/data/secure_certification_exam_attempt_repository.dart';
import 'package:candidate_mobile/features/certification_exam/domain/certification_exam.dart';
import 'package:candidate_mobile/features/certification_exam/domain/certification_exam_repository.dart';
import 'package:candidate_mobile/features/home/domain/home_dashboard_repository.dart';
import 'package:candidate_mobile/features/jobs/data/local_mock_jobs_repository.dart';
import 'package:candidate_mobile/features/jobs/data/secure_saved_jobs_repository.dart';
import 'package:candidate_mobile/features/jobs/domain/jobs_repository.dart';
import 'package:candidate_mobile/features/intelligence/data/secure_candidate_intelligence_repository.dart';
import 'package:candidate_mobile/features/intelligence/domain/candidate_intelligence_repository.dart';
import 'package:candidate_mobile/features/learning/domain/learning_repository.dart';
import 'package:candidate_mobile/features/micro_lessons/data/secure_micro_lesson_assessment_repository.dart';
import 'package:candidate_mobile/features/micro_lessons/domain/micro_lesson_assessment_repository.dart';
import 'package:candidate_mobile/features/micro_lessons/domain/micro_lesson_clip_repository.dart';
import 'package:candidate_mobile/features/onboarding/data/secure_candidate_onboarding_repository.dart';
import 'package:candidate_mobile/features/onboarding/domain/candidate_onboarding_repository.dart';
import 'package:candidate_mobile/features/onboarding/domain/onboarding_entry_repository.dart';
import 'package:candidate_mobile/features/shifts/data/local_mock_shifts_repository.dart';
import 'package:candidate_mobile/features/shifts/domain/shifts_repository.dart';
import 'package:candidate_mobile/features/splash/domain/app_startup_repository.dart';
import 'package:candidate_mobile/features/voice/data/record_voice_capture_repository.dart';
import 'package:candidate_mobile/features/voice/data/secure_voice_interview_repository.dart';
import 'package:candidate_mobile/features/voice/domain/voice_interview_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/local_simulation_attempt_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_repositories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

extension CandidateAppPump on WidgetTester {
  Future<void> pumpCandidateApp({
    AppStartupRepository? startupRepository,
    OnboardingEntryRepository? onboardingEntryRepository,
    CandidateSessionRepository? candidateSessionRepository,
    CandidateOnboardingRepository? candidateOnboardingRepository,
    DevelopmentAuthRepository? developmentAuthRepository,
    AnalyticsTracker? analyticsTracker,
    ConnectivityRepository? connectivityRepository,
    HomeDashboardRepository? homeDashboardRepository,
    LearningRepository? learningRepository,
    MicroLessonClipRepository? microLessonClipRepository,
    MicroLessonAssessmentRepository? microLessonAssessmentRepository,
    CertificationExamRepository? certificationExamRepository,
    CertificationExamAttemptRepository? certificationExamAttemptRepository,
    JobsRepository? jobsRepository,
    ShiftsRepository? shiftsRepository,
    SimulationAttemptRepository? simulationAttemptRepository,
    CandidateIntelligenceRepository? candidateIntelligenceRepository,
    VoiceInterviewRepository? voiceInterviewRepository,
    VoiceCaptureRepository? voiceCaptureRepository,
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
          candidateSessionRepositoryProvider.overrideWithValue(
            candidateSessionRepository ?? InMemoryCandidateSessionRepository(),
          ),
          candidateOnboardingRepositoryProvider.overrideWithValue(
            candidateOnboardingRepository ??
                InMemoryCandidateOnboardingRepository(),
          ),
          if (developmentAuthRepository != null)
            developmentAuthRepositoryProvider.overrideWithValue(
              developmentAuthRepository,
            ),
          if (analyticsTracker != null)
            analyticsTrackerProvider.overrideWithValue(analyticsTracker),
          if (connectivityRepository != null)
            connectivityRepositoryProvider.overrideWithValue(
              connectivityRepository,
            ),
          if (homeDashboardRepository != null)
            homeDashboardRepositoryProvider.overrideWithValue(
              homeDashboardRepository,
            ),
          if (learningRepository != null)
            learningRepositoryProvider.overrideWithValue(learningRepository),
          if (microLessonClipRepository != null)
            microLessonClipRepositoryProvider.overrideWithValue(
              microLessonClipRepository,
            ),
          // Always overridden (not just when explicitly passed) --
          // otherwise this falls through to the real secure-storage-backed
          // provider, which hangs on the platform channel in the widget
          // test sandbox (no mock registered) instead of failing fast.
          microLessonAssessmentRepositoryProvider.overrideWithValue(
            microLessonAssessmentRepository ??
                SecureMicroLessonAssessmentRepository(
                  InMemorySecureKeyValueStore(),
                ),
          ),
          // Always overridden (not just when explicitly passed). Unlike the
          // secure-storage providers above, this one doesn't hang on an
          // unmocked platform channel -- instead, `rootBundle.loadString`
          // (used by the default `AssetCertificationExamRepository`) was
          // observed to hang on its *second* call within one test process
          // (first `testWidgets` block resolves fine, a second one sharing
          // the same isolate never does), whenever nothing else in the
          // provider chain already forces an override. Reachable via the
          // same `careerPassportControllerProvider.future` chain as the two
          // repos above.
          certificationExamRepositoryProvider.overrideWithValue(
            certificationExamRepository ??
                const _NoExamCertificationExamRepository(),
          ),
          // Same rationale as microLessonAssessmentRepositoryProvider above:
          // always overridden so it never falls through to the real
          // secure-storage-backed provider in the widget test sandbox.
          certificationExamAttemptRepositoryProvider.overrideWithValue(
            certificationExamAttemptRepository ??
                SecureCertificationExamAttemptRepository(
                  InMemorySecureKeyValueStore(),
                ),
          ),
          jobsRepositoryProvider.overrideWithValue(
            jobsRepository ??
                LocalMockJobsRepository(InMemorySecureKeyValueStore()),
          ),
          // Same rationale as microLessonAssessmentRepositoryProvider above:
          // always overridden so it never falls through to the real
          // secure-storage-backed provider in the widget test sandbox.
          savedJobsRepositoryProvider.overrideWithValue(
            SecureSavedJobsRepository(InMemorySecureKeyValueStore()),
          ),
          // Same rationale as microLessonAssessmentRepositoryProvider above:
          // always overridden so it never falls through to the real
          // secure-storage-backed provider in the widget test sandbox.
          shiftsRepositoryProvider.overrideWithValue(
            shiftsRepository ??
                LocalMockShiftsRepository(InMemorySecureKeyValueStore()),
          ),
          // Same rationale as microLessonAssessmentRepositoryProvider above:
          // always overridden. This one is transitively pulled in by
          // careerPassportRepositoryProvider (attemptRepository), which was
          // harmless before nothing awaited Career Passport's resolution --
          // ShiftsController now does via `careerPassportControllerProvider
          // .future`, so an unmocked secure-storage read here hangs the
          // whole Shift tab forever instead of just this repo's own tests.
          simulationAttemptRepositoryProvider.overrideWithValue(
            simulationAttemptRepository ??
                LocalSimulationAttemptRepository(InMemorySecureKeyValueStore()),
          ),
          candidateIntelligenceRepositoryProvider.overrideWithValue(
            candidateIntelligenceRepository ??
                InMemoryCandidateIntelligenceRepository(),
          ),
          voiceInterviewRepositoryProvider.overrideWithValue(
            voiceInterviewRepository ?? InMemoryVoiceInterviewRepository(),
          ),
          voiceCaptureRepositoryProvider.overrideWithValue(
            voiceCaptureRepository ?? InMemoryVoiceCaptureRepository(),
          ),
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

/// Default test double for [certificationExamRepositoryProvider] -- see the
/// override's doc comment above for why this is unconditional. Always
/// fails, since no test relies on the real bundled exam content by default;
/// tests that need real exam content pass their own
/// `certificationExamRepository`.
class _NoExamCertificationExamRepository
    implements CertificationExamRepository {
  const _NoExamCertificationExamRepository();

  @override
  Future<Result<CertificationExam>> loadExam() async => const ResultFailure(
    StorageFailure('No certification exam configured for this test.'),
  );
}
