import 'package:candidate_mobile/app/app.dart';
import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/app/theme/app_theme.dart';
import 'package:candidate_mobile/core/analytics/analytics_tracker.dart';
import 'package:candidate_mobile/core/config/app_environment.dart';
import 'package:candidate_mobile/core/network/connectivity_status.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:candidate_mobile/features/authentication/domain/development_auth_repository.dart';
import 'package:candidate_mobile/features/home/domain/home_dashboard_repository.dart';
import 'package:candidate_mobile/features/jobs/data/local_mock_jobs_repository.dart';
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
import 'package:candidate_mobile/features/splash/domain/app_startup_repository.dart';
import 'package:candidate_mobile/features/voice/data/record_voice_capture_repository.dart';
import 'package:candidate_mobile/features/voice/data/secure_voice_interview_repository.dart';
import 'package:candidate_mobile/features/voice/domain/voice_interview_repository.dart';
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
    JobsRepository? jobsRepository,
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
          jobsRepositoryProvider.overrideWithValue(
            jobsRepository ??
                LocalMockJobsRepository(InMemorySecureKeyValueStore()),
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
