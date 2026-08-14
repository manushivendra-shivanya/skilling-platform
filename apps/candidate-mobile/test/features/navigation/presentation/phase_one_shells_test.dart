import 'package:candidate_mobile/core/analytics/analytics_tracker.dart';
import 'package:candidate_mobile/core/errors/app_failure.dart';
import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/core/network/connectivity_status.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:candidate_mobile/features/home/data/mock_home_dashboard_repository.dart';
import 'package:candidate_mobile/features/jobs/data/local_mock_jobs_repository.dart';
import 'package:candidate_mobile/features/networking/domain/networking_repository.dart';
import 'package:candidate_mobile/features/onboarding/data/secure_candidate_onboarding_repository.dart';
import 'package:candidate_mobile/features/onboarding/domain/candidate_onboarding_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    // Home is short enough to build in one pass now, but the empty and
    // error states below still need room for the drag.
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = MockHomeDashboardRepository();
    await tester.pumpCandidateApp(
      candidateSessionRepository: sessions,
      candidateOnboardingRepository: onboarding,
      homeDashboardRepository: repository,
    );
    await tester.pumpAndSettle();
    // The default sample dashboard carries an upcoming interview, so
    // UpcomingInterviewCard's own CTA is on screen -- the interview-practice
    // shortcut row is deliberately hidden rather than duplicating it (see
    // home_dashboard_screen_test.dart).
    expect(find.text('Prepare'), findsOneWidget);

    repository.setResponse(const Success(null));
    // Drag from the greeting in the header: it is the one element present
    // for every dashboard shape, so it cannot be pushed below the fold by
    // an optional card above it.
    await tester.drag(find.text('Hello'), const Offset(0, 500));
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
    'Coach starts a topic thread from the empty state, replies locally, '
    'and lists it back on the threads screen',
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

      // Empty state: welcome copy plus starter prompts, no threads yet.
      expect(find.textContaining('Namaste!'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField),
        'How should I report a mismatch?',
      );
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();

      // Sending from the empty state opens the new thread automatically.
      // The question text appears twice on this screen -- once as the
      // candidate's message bubble, once as the AppBar title (the thread's
      // topic label, derived from this same opening question).
      //
      // Not find.textContaining: coach replies reveal word-by-word via
      // _InkRevealText (each word is its own Text widget), so no single
      // Text.data contains this whole phrase. The complete sentence is
      // still exposed as one Semantics label for screen readers -- see
      // _InkRevealText's doc comment in coach_thread_screen.dart.
      expect(
        find.bySemanticsLabel(RegExp('break the task into steps')),
        findsOneWidget,
      );
      expect(find.text('How should I report a mismatch?'), findsNWidgets(2));
      expect(
        analytics.events.map((event) => event.name),
        contains('coach_message_sent'),
      );

      await tester.pageBack();
      await tester.pumpAndSettle();

      // Back on the threads list: the new thread is there, topic-labelled
      // from the opening question.
      expect(find.text('How should I report a mismatch?'), findsOneWidget);
      expect(find.textContaining('2 messages'), findsOneWidget);
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
    await tester.tap(find.text('Train'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('only lessons marked Downloaded'),
      findsOneWidget,
    );
    // The row itself is the tap target now (no separate "Open lesson"
    // button -- see sector_index_row.dart); the download toggle is a
    // small icon-only utility button identified by its Tooltip, not a
    // labeled "Download" button.
    await tester.tap(find.byTooltip('Download for offline').first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Downloaded'), findsOneWidget);

    await tester.ensureVisible(find.text('Inventory accuracy basics'));
    await tester.tap(find.text('Inventory accuracy basics'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Close'));
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    // Downloaded state persists independently of completion; completion
    // now reads from the row's own status line, not a separate button.
    expect(find.byTooltip('Downloaded'), findsOneWidget);
    expect(
      find.textContaining('Completed — tap to mark incomplete'),
      findsOneWidget,
    );
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
    await tester.tap(find.text('Train'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Practise'));
    await tester.pumpAndSettle();

    expect(find.textContaining('not scored assessments'), findsOneWidget);
    // scrollUntilVisible stops as soon as the finder matches a *built*
    // element -- which can happen while it's still in the sliver cache
    // extent, just outside the actual viewport, before it's truly
    // paintable/tappable.
    //
    // "Recommended practice" is now a real SectorTaskCard (the whole card
    // is the tap target, same as the 4 mission tickets above it) rather
    // than a separate "Start demonstration" AppButton -- tap its title.
    await tester.scrollUntilVisible(
      find.text('Inventory discrepancy'),
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
      tester.element(find.text('Inventory discrepancy')),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inventory discrepancy'));
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

  testWidgets(
    'the Professional Persona card does not appear without a headline',
    (tester) async {
      // No headline in the seeded draft -- the persona card is real-content
      // gated (see ProfessionalPersonaCard's doc comment), so it shouldn't
      // render at all here.
      await tester.pumpCandidateApp(
        candidateSessionRepository: sessions,
        candidateOnboardingRepository: onboarding,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Professional persona'), findsNothing);
    },
  );

  testWidgets(
    'a Professional Persona card with a headline renders its details and '
    'copies a summary to the clipboard',
    (tester) async {
      // Tall surface: the Profile screen's whole scrollable content
      // (career profile, persona card, career passport, privacy section,
      // ...) doesn't fit an 800x600 test surface, and scrollUntilVisible's
      // delta-based scrolling proved to land "Copy persona summary" just
      // past the viewport edge. A tall surface sidesteps scrolling
      // entirely, same fix as the resume-upload onboarding step tests.
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Intercepts the platform channel Clipboard.setData ultimately calls,
      // same mechanism the coach haptic test uses for HapticFeedback.
      final clipboardCalls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final arguments = call.arguments as Map<Object?, Object?>;
            clipboardCalls.add(arguments['text'] as String);
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      final withPersona = InMemoryCandidateOnboardingRepository(
        initialDraft: _completedDraft().copyWith(
          headline: 'Warehouse Associate at ABC Logistics',
        ),
      );
      await tester.pumpCandidateApp(
        candidateSessionRepository: sessions,
        candidateOnboardingRepository: withPersona,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Profile'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Professional persona'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Professional persona'), findsOneWidget);
      expect(find.text('Warehouse Associate at ABC Logistics'), findsOneWidget);
      // Not findsOneWidget: the same "city, state" string also appears
      // unconditionally in the screen's own header, above and outside the
      // persona card -- two genuine, separate occurrences.
      expect(find.text('Lucknow, Uttar Pradesh'), findsNWidgets(2));

      await tester.scrollUntilVisible(
        find.text('Copy persona summary'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Copy persona summary'));
      await tester.pumpAndSettle();

      expect(clipboardCalls, hasLength(1));
      expect(clipboardCalls.single, contains('Asha Kumari'));
      expect(
        clipboardCalls.single,
        contains('Warehouse Associate at ABC Logistics'),
      );
      expect(find.text('Persona summary copied.'), findsOneWidget);
    },
  );

  testWidgets(
    'turning on discoverability publishes the persona card fields, and '
    'both networking screens are reachable',
    (tester) async {
      final networking = _FakeNetworkingRepository();
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpCandidateApp(
        candidateSessionRepository: sessions,
        candidateOnboardingRepository: InMemoryCandidateOnboardingRepository(
          initialDraft: _completedDraft().copyWith(
            headline: 'Warehouse Associate at ABC Logistics',
          ),
        ),
        networkingRepository: networking,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Profile'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Find other candidates'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Find other candidates'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Make my profile discoverable'),
      );
      await tester.pumpAndSettle();

      expect(networking.publishedProfiles, hasLength(1));
      final published = networking.publishedProfiles.single;
      expect(published.fullName, 'Asha Kumari');
      expect(published.headline, 'Warehouse Associate at ABC Logistics');
      expect(published.discoverable, isTrue);

      await tester.tap(find.text('Discover candidates'));
      await tester.pumpAndSettle();
      expect(find.text('Discover candidates'), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('My connections'));
      await tester.pumpAndSettle();
      expect(find.text('No connections yet'), findsOneWidget);
    },
  );
}

class _FakeNetworkingRepository implements NetworkingRepository {
  final publishedProfiles = <NetworkingProfile>[];

  @override
  Future<Result<NetworkingProfile>> getMyProfile() async => const Success(
    NetworkingProfile(
      discoverable: false,
      fullName: '',
      headline: '',
      city: '',
      state: '',
      preferredRoles: [],
    ),
  );

  @override
  Future<Result<NetworkingProfile>> publishProfile({
    required String fullName,
    required String headline,
    required String city,
    required String state,
    required List<String> preferredRoles,
    required bool discoverable,
  }) async {
    final profile = NetworkingProfile(
      discoverable: discoverable,
      fullName: fullName,
      headline: headline,
      city: city,
      state: state,
      preferredRoles: preferredRoles,
    );
    publishedProfiles.add(profile);
    return Success(profile);
  }

  @override
  Future<Result<List<DiscoveredCandidate>>> discover() async =>
      const Success([]);

  @override
  Future<Result<void>> sendConnectionRequest(
    String recipientCandidateId,
  ) async => const Success(null);

  @override
  Future<Result<ConnectionsOverview>> listConnections() async =>
      const Success(ConnectionsOverview.empty());

  @override
  Future<Result<void>> respondToConnection(
    String connectionId,
    bool accept,
  ) async => const Success(null);

  @override
  Future<Result<void>> withdrawConnection(String connectionId) async =>
      const Success(null);

  @override
  Future<Result<void>> blockCandidate(String candidateId) async =>
      const Success(null);

  @override
  Future<Result<void>> unblockCandidate(String candidateId) async =>
      const Success(null);
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
