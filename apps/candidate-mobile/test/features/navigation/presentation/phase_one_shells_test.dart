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
    // The "Today's services" rail + journey/readiness cards push "Open
    // career diagnostic" out of ListView's default build extent at the
    // default 800x600 test surface -- it's not just off-screen, it's
    // genuinely unbuilt, so find.text finds nothing rather than something
    // untappable. A taller surface keeps it (and everything after it)
    // built without needing to scroll first.
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = MockHomeDashboardRepository();
    await tester.pumpCandidateApp(
      candidateSessionRepository: sessions,
      candidateOnboardingRepository: onboarding,
      homeDashboardRepository: repository,
    );
    await tester.pumpAndSettle();
    expect(find.text('Career diagnostic'), findsOneWidget);

    repository.setResponse(const Success(null));
    // Drag from the greeting in the header: it is the one element present
    // for every dashboard shape, so it cannot be pushed below the fold by
    // an optional card above it.
    await tester.drag(find.text('नमस्ते'), const Offset(0, 500));
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
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Open lesson').first);
    await tester.tap(find.text('Open lesson').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Close'));
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Downloaded'), findsOneWidget);
    expect(find.text('Mark incomplete'), findsOneWidget);
    expect(
      find.textContaining('not an employer qualification'),
      findsOneWidget,
    );
  });

  testWidgets('Practice demonstration is interactive and explicitly unscored', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpCandidateApp(
      candidateSessionRepository: sessions,
      candidateOnboardingRepository: onboarding,
    );
    await tester.pumpAndSettle();
    // Practise now lives as a sub-tab inside Learn rather than its own
    // bottom-nav destination.
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Practise'));
    await tester.pumpAndSettle();

    expect(find.textContaining('not scored assessments'), findsOneWidget);
    // scrollUntilVisible stops as soon as the finder matches a *built*
    // element -- which can happen while it's still in the sliver cache
    // extent, just outside the actual viewport, before it's truly
    // paintable/tappable.
    await tester.scrollUntilVisible(
      find.text('Start demonstration'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // WidgetController.ensureVisible scrolls the *minimum* distance needed,
    // which for an item just below the fold parks it flush against the
    // bottom of the viewport -- exactly where the floating "AI Coach"
    // button sits. That's a real overlap a real user scrolling to this
    // point would hit too, not just a test artifact: verified by comparing
    // the button's tap center against the FAB's rect directly, which
    // landed inside it. Centering the scroll instead keeps tappable
    // content clear of the FAB's fixed footprint.
    await Scrollable.ensureVisible(
      tester.element(find.text('Start demonstration')),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start demonstration'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Recount, preserve records, and escalate the mismatch'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(
        find.text('Recount, preserve records, and escalate the mismatch'),
      ),
      alignment: 0.5,
    );
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
    await tester.tap(find.text('My Profile'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Employer sharing'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Employer sharing'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Edit personal details'),
      -300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.text('Edit personal details'));
    await tester.pumpAndSettle();
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
    await tester.ensureVisible(find.text('Log out'));
    await tester.pumpAndSettle();
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
