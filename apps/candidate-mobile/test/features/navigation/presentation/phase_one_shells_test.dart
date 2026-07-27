import 'package:candidate_mobile/core/analytics/analytics_tracker.dart';
import 'package:candidate_mobile/core/errors/app_failure.dart';
import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/core/network/connectivity_status.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:candidate_mobile/features/home/data/mock_home_dashboard_repository.dart';
import 'package:candidate_mobile/features/jobs/data/local_mock_jobs_repository.dart';
import 'package:candidate_mobile/features/onboarding/data/secure_candidate_onboarding_repository.dart';
import 'package:candidate_mobile/features/onboarding/domain/candidate_onboarding_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  late InMemoryCandidateSessionRepository sessions;
  late InMemoryCandidateOnboardingRepository onboarding;

  setUp(() {
    sessions = InMemoryCandidateSessionRepository(
      session: const CandidateSession(
        candidateId: 'dev-candidate-3210',
        isAuthenticated: true,
      ),
    );
    onboarding = InMemoryCandidateOnboardingRepository(
      initialDraft: _completedDraft(),
    );
  });

  testWidgets('Home supports populated, empty, and recoverable error states', (
    tester,
  ) async {
    final repository = MockHomeDashboardRepository();
    await tester.pumpCandidateApp(
      candidateSessionRepository: sessions,
      candidateOnboardingRepository: onboarding,
      homeDashboardRepository: repository,
    );
    await tester.pumpAndSettle();
    expect(find.text('Practice readiness'), findsOneWidget);

    repository.setResponse(const Success(null));
    await tester.drag(find.text('Practice readiness'), const Offset(0, 500));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Your journey starts here'), findsOneWidget);

    repository.setResponse(
      const ResultFailure(NetworkFailure('Demo network failure.')),
    );
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Demo network failure.'), findsOneWidget);
  });

  testWidgets(
    'Coach sends local replies, exposes safe placeholders, and resets',
    (tester) async {
      final analytics = InMemoryAnalyticsTracker();
      await tester.pumpCandidateApp(
        candidateSessionRepository: sessions,
        candidateOnboardingRepository: onboarding,
        analyticsTracker: analytics,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('AI Coach'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'How should I report a mismatch?',
      );
      await tester.tap(find.byTooltip('Send message'));
      await tester.pump();
      expect(find.textContaining('break the task into steps'), findsOneWidget);
      expect(
        analytics.events.map((event) => event.name),
        contains('local_coach_message_sent'),
      );

      await tester.tap(find.byTooltip('Voice input unavailable'));
      await tester.pump();
      expect(find.textContaining('No microphone permission'), findsOneWidget);

      await tester.tap(find.byTooltip('Reset conversation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(find.text('How should I report a mismatch?'), findsNothing);
    },
  );

  testWidgets('Learning represents download, completion, and offline states', (
    tester,
  ) async {
    final connectivity = MockConnectivityRepository(
      initialStatus: ConnectivityStatus.offline,
    );
    addTearDown(connectivity.dispose);
    await tester.pumpCandidateApp(
      candidateSessionRepository: sessions,
      candidateOnboardingRepository: onboarding,
      connectivityRepository: connectivity,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('only lessons marked Downloaded'),
      findsOneWidget,
    );
    await tester.tap(find.text('Download').first);
    await tester.tap(find.text('Open lesson').first);
    await tester.pump();
    expect(find.text('Downloaded'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(
      find.textContaining('not an authoritative qualification'),
      findsOneWidget,
    );
  });

  testWidgets('Practice demonstration is interactive and explicitly unscored', (
    tester,
  ) async {
    await tester.pumpCandidateApp(
      candidateSessionRepository: sessions,
      candidateOnboardingRepository: onboarding,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Practise'));
    await tester.pumpAndSettle();

    expect(find.textContaining('not scored assessments'), findsOneWidget);
    await tester.tap(find.text('Start demonstration'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Recount, preserve records, and escalate the mismatch'),
    );
    await tester.pump();
    expect(find.textContaining('Good practice'), findsOneWidget);
    expect(
      find.textContaining('technical failure must not reduce'),
      findsOneWidget,
    );
  });

  testWidgets('Job application requires consent and persists locally', (
    tester,
  ) async {
    final repository = LocalMockJobsRepository(InMemorySecureKeyValueStore());
    await tester.pumpCandidateApp(
      candidateSessionRepository: sessions,
      candidateOnboardingRepository: onboarding,
      jobsRepository: repository,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jobs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Warehouse Operations Associate'));
    await tester.pumpAndSettle();

    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save demo application'),
    );
    expect(saveButton.onPressed, isNull);
    await tester.tap(find.text('Share this demo profile for this application'));
    await tester.pump();
    await tester.ensureVisible(find.text('Save demo application'));
    await tester.tap(find.text('Save demo application'));
    await tester.pumpAndSettle();

    final applied = (await repository.readAppliedJobIds(
      'dev-candidate-3210',
    )).when(success: (value) => value, failure: (failure) => throw failure);
    expect(applied, contains('warehouse-lucknow'));
    expect(find.text('Demo application saved'), findsOneWidget);
  });

  testWidgets('Profile edits persist and logout clears the session', (
    tester,
  ) async {
    await tester.pumpCandidateApp(
      candidateSessionRepository: sessions,
      candidateOnboardingRepository: onboarding,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Employer profile visibility'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Employer profile visibility'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Edit personal details'),
      -300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Edit personal details'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Full name'),
      'Asha Singh',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(onboarding.draft.fullName, 'Asha Singh');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Log out'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Choose your language'), findsOneWidget);
    expect(
      (await sessions.readSession()).when(
        success: (value) => value,
        failure: (_) => const CandidateSession(
          candidateId: 'failure',
          isAuthenticated: true,
        ),
      ),
      isNull,
    );
  });
}

CandidateOnboardingDraft _completedDraft() {
  final acceptedAt = DateTime.utc(2026, 7, 27);
  return CandidateOnboardingDraft(
    currentStep: 10,
    goal: CandidateGoal.findJob,
    fullName: 'Asha Kumari',
    city: 'Lucknow',
    state: 'Uttar Pradesh',
    pinCode: '226001',
    education: EducationLevel.twelfthPass,
    experience: ExperienceLevel.fresher,
    preferredRoles: const {LogisticsRole.warehouseAssociate},
    consents: {
      OnboardingConsentVersions.termsPurpose: ConsentAcceptance(
        purpose: OnboardingConsentVersions.termsPurpose,
        version: OnboardingConsentVersions.termsVersion,
        acceptedAt: acceptedAt,
      ),
      OnboardingConsentVersions.privacyPurpose: ConsentAcceptance(
        purpose: OnboardingConsentVersions.privacyPurpose,
        version: OnboardingConsentVersions.privacyVersion,
        acceptedAt: acceptedAt,
      ),
    },
    isCompleted: true,
  );
}
