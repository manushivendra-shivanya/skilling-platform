import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/core/network/connectivity_status.dart';
import 'package:candidate_mobile/core/widgets/app_chip.dart';
import 'package:candidate_mobile/core/widgets/app_icon_plate.dart';
import 'package:candidate_mobile/features/onboarding/data/secure_candidate_onboarding_repository.dart';
import 'package:candidate_mobile/features/onboarding/domain/candidate_onboarding_draft.dart';
import 'package:candidate_mobile/features/resume/domain/resume_parsing_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  late InMemoryCandidateSessionRepository sessions;

  setUp(() {
    sessions = InMemoryCandidateSessionRepository(
      session: const CandidateSession(
        candidateId: 'dev-candidate-3210',
        isAuthenticated: true,
      ),
    );
  });

  testWidgets('required onboarding fields block progress', (tester) async {
    await tester.pumpCandidateApp(
      candidateSessionRepository: sessions,
      candidateOnboardingRepository: InMemoryCandidateOnboardingRepository(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to profile setup'));
    await tester.pumpAndSettle();

    expect(find.text('What would you like to achieve?'), findsOneWidget);
    await tester.tap(find.text('Save and continue'));
    await tester.pump();

    expect(find.text('Choose one goal to continue.'), findsOneWidget);
  });

  testWidgets('saved onboarding draft resumes at its last step', (
    tester,
  ) async {
    final repository = InMemoryCandidateOnboardingRepository(
      initialDraft: const CandidateOnboardingDraft(
        currentStep: 5,
        goal: CandidateGoal.findJob,
        fullName: 'Asha Kumari',
        city: 'Lucknow',
        state: 'Uttar Pradesh',
        pinCode: '226001',
        education: EducationLevel.twelfthPass,
        experience: ExperienceLevel.fresher,
      ),
    );

    await tester.pumpCandidateApp(
      candidateSessionRepository: sessions,
      candidateOnboardingRepository: repository,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to profile setup'));
    await tester.pumpAndSettle();

    expect(find.text('Which roles interest you?'), findsOneWidget);
    expect(find.text('Step 6 of 10'), findsOneWidget);
  });

  testWidgets('offline state explains that the draft remains on device', (
    tester,
  ) async {
    final connectivity = MockConnectivityRepository(
      initialStatus: ConnectivityStatus.offline,
    );
    addTearDown(connectivity.dispose);

    await tester.pumpCandidateApp(
      candidateSessionRepository: sessions,
      candidateOnboardingRepository: InMemoryCandidateOnboardingRepository(),
      connectivityRepository: connectivity,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to profile setup'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'You are offline. Your profile steps are saved securely on this device.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('candidate can complete onboarding with versioned consent', (
    tester,
  ) async {
    final repository = InMemoryCandidateOnboardingRepository();
    await tester.pumpCandidateApp(
      candidateSessionRepository: sessions,
      candidateOnboardingRepository: repository,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to profile setup'));
    await tester.pumpAndSettle();

    await _selectAndContinue(tester, 'Find a new job');
    await tester.enterText(
      find.byKey(const ValueKey('full-name-field')),
      'Asha Kumari',
    );
    await _continue(tester);
    await tester.enterText(find.byKey(const ValueKey('city-field')), 'Lucknow');
    await tester.enterText(
      find.byKey(const ValueKey('state-field')),
      'Uttar Pradesh',
    );
    await tester.enterText(
      find.byKey(const ValueKey('pin-code-field')),
      '226001',
    );
    await _continue(tester);
    await _selectAndContinue(tester, 'Class 12 pass');
    await _selectAndContinue(tester, 'Fresher');
    await _selectAndContinue(tester, 'Warehouse Operations Associate');
    await _continue(tester);
    await _continue(tester);

    expect(find.text('Consent centre'), findsOneWidget);
    await tester.tap(find.text('Platform terms'));
    await tester.tap(find.text('Privacy notice'));
    await _continue(tester);
    expect(find.text('Review your profile'), findsOneWidget);
    expect(find.text('Asha Kumari'), findsOneWidget);
    await tester.tap(find.text('Complete profile'));
    await tester.pumpAndSettle();

    expect(find.text('Your profile is ready'), findsOneWidget);
    expect(repository.draft.isCompleted, isTrue);
    expect(repository.draft.hasCurrentRequiredConsents, isTrue);
    await tester.tap(find.text('Go to home'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Hello'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets(
    'each step shows an icon matching its content, and consent/review '
    'status render as status chips reflecting the real booleans',
    (tester) async {
      final repository = InMemoryCandidateOnboardingRepository();
      await tester.pumpCandidateApp(
        candidateSessionRepository: sessions,
        candidateOnboardingRepository: repository,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue to profile setup'));
      await tester.pumpAndSettle();

      // Step 0: goal -- a choice step.
      expect(_stepHeadingIcon(tester), Icons.checklist_rounded);
      await _selectAndContinue(tester, 'Find a new job');

      // Step 1: name -- a text-entry step.
      expect(_stepHeadingIcon(tester), Icons.person_outline);
      await tester.enterText(
        find.byKey(const ValueKey('full-name-field')),
        'Asha Kumari',
      );
      await _continue(tester);

      // Step 2: location -- also text-entry, but its own icon (distinct
      // content, same step type as step 1).
      expect(_stepHeadingIcon(tester), Icons.edit_outlined);
      await tester.enterText(
        find.byKey(const ValueKey('city-field')),
        'Lucknow',
      );
      await tester.enterText(
        find.byKey(const ValueKey('state-field')),
        'Uttar Pradesh',
      );
      await tester.enterText(
        find.byKey(const ValueKey('pin-code-field')),
        '226001',
      );
      await _continue(tester);

      // Steps 3-5: education, experience, roles -- all choice steps.
      expect(_stepHeadingIcon(tester), Icons.checklist_rounded);
      await _selectAndContinue(tester, 'Class 12 pass');
      expect(_stepHeadingIcon(tester), Icons.checklist_rounded);
      await _selectAndContinue(tester, 'Fresher');
      expect(_stepHeadingIcon(tester), Icons.checklist_rounded);
      await _selectAndContinue(tester, 'Warehouse Operations Associate');

      // Step 6: resume upload.
      expect(_stepHeadingIcon(tester), Icons.upload_file_outlined);
      await _continue(tester);

      // Step 7: coming-soon voice step.
      expect(_stepHeadingIcon(tester), Icons.mic_none_outlined);
      await _continue(tester);

      // Step 8: consent -- both checkboxes start unaccepted, each carrying
      // its own status chip reflecting that same boolean.
      expect(_stepHeadingIcon(tester), Icons.lock_outline);
      expect(
        tester
            .widgetList<AppStatusChip>(find.byType(AppStatusChip))
            .map((chip) => chip.label),
        ['Not yet accepted', 'Not yet accepted'],
      );
      await tester.tap(find.text('Platform terms'));
      await tester.pump();
      expect(
        tester
            .widgetList<AppStatusChip>(find.byType(AppStatusChip))
            .map((chip) => chip.tone),
        [AppChipTone.success, AppChipTone.warning],
      );
      await tester.tap(find.text('Privacy notice'));
      await tester.pump();
      expect(
        tester
            .widgetList<AppStatusChip>(find.byType(AppStatusChip))
            .every((chip) => chip.tone == AppChipTone.success),
        isTrue,
      );
      await _continue(tester);

      // Step 9: review -- the same `hasCurrentRequiredConsents` boolean
      // the plain-text row used to show, now also carried by a chip.
      expect(_stepHeadingIcon(tester), Icons.description_outlined);
      final reviewChip = tester.widget<AppStatusChip>(
        find.byType(AppStatusChip),
      );
      expect(reviewChip.label, 'Accepted with current versions');
      expect(reviewChip.tone, AppChipTone.success);
    },
  );

  group('resume upload step', () {
    // Tall viewport for this whole group: the resume step's content plus
    // the fixed Back/Save-and-continue bar doesn't fit an 800x600 test
    // surface, and scrolling the "Extract details" button into view with
    // ensureVisible/Scrollable.ensureVisible proved to land it right under
    // that fixed bar in some but not all tap sequences (same bug class as
    // practice_screen_restyle_test.dart's floating FAB, but flakier here
    // depending on prior scroll state). A tall surface sidesteps scrolling
    // -- and the hit-test mismatch -- entirely.
    setUp(() {
      final tester = TestWidgetsFlutterBinding.ensureInitialized();
      tester.platformDispatcher.views.first.physicalSize = const Size(
        900,
        2600,
      );
      tester.platformDispatcher.views.first.devicePixelRatio = 1;
    });

    tearDown(() {
      final tester = TestWidgetsFlutterBinding.ensureInitialized();
      tester.platformDispatcher.views.first.resetPhysicalSize();
      tester.platformDispatcher.views.first.resetDevicePixelRatio();
    });

    testWidgets(
      'extracting details fills in the name field and shows a preview',
      (tester) async {
        final parser = _FakeResumeParsingRepository();
        await tester.pumpCandidateApp(
          candidateSessionRepository: sessions,
          candidateOnboardingRepository:
              InMemoryCandidateOnboardingRepository(),
          resumeParsingRepository: parser,
        );
        await _navigateToResumeStep(tester);

        expect(find.text('Add your resume'), findsOneWidget);
        final extractButton = find.widgetWithText(
          FilledButton,
          'Extract details',
        );
        await tester.ensureVisible(extractButton);
        expect(tester.widget<FilledButton>(extractButton).onPressed, isNull);

        await tester.ensureVisible(
          find.byKey(const ValueKey('resume-text-field')),
        );
        await tester.enterText(
          find.byKey(const ValueKey('resume-text-field')),
          'Asha Kumari, Warehouse Associate at ABC Logistics, 2 years experience.',
        );
        await tester.pump();
        expect(tester.widget<FilledButton>(extractButton).onPressed, isNull);

        await tester.ensureVisible(find.text('Use AI to read this text'));
        await tester.tap(find.text('Use AI to read this text'));
        await tester.pump();
        expect(tester.widget<FilledButton>(extractButton).onPressed, isNotNull);

        // Not tester.ensureVisible: that scrolls the *minimum* distance,
        // which parks this button flush against the bottom of the
        // viewport -- exactly where the fixed Back/Save-and-continue bar
        // sits, so the tap lands on that bar instead (same class of bug
        // documented in practice_screen_restyle_test.dart). Centering the
        // scroll keeps this button clear of that fixed footprint.
        await Scrollable.ensureVisible(
          tester.element(extractButton),
          alignment: 0.5,
        );
        await tester.pumpAndSettle();
        await tester.tap(extractButton);
        await tester.pumpAndSettle();

        expect(parser.calls, hasLength(1));
        expect(parser.calls.single.consentVersion, isNotEmpty);
        expect(find.text('What we found'), findsOneWidget);
        expect(find.text('Asha Kumari'), findsOneWidget);
        expect(find.text('Warehouse Associate'), findsOneWidget);
        expect(
          find.textContaining('has been filled in for step 1'),
          findsOneWidget,
        );

        // The name really did land on step 1's own field, not just the
        // preview -- confirmed by carrying it all the way to Review,
        // which reads straight from that field's controller (see
        // _draftWithTextFields). "Back" isn't used here: it steps back
        // one screen at a time (6 -> 5, not 6 -> 1).
        await _continue(tester); // step 6 -> 7 (voice, skip)
        await _continue(tester); // step 7 -> 8 (consent)
        await tester.tap(find.text('Platform terms'));
        await tester.tap(find.text('Privacy notice'));
        await _continue(tester); // step 8 -> 9 (review)
        expect(find.text('Review your profile'), findsOneWidget);
        expect(find.text('Asha Kumari'), findsOneWidget);
      },
    );

    testWidgets('does not overwrite a name the candidate already typed', (
      tester,
    ) async {
      final parser = _FakeResumeParsingRepository();
      await tester.pumpCandidateApp(
        candidateSessionRepository: sessions,
        candidateOnboardingRepository: InMemoryCandidateOnboardingRepository(),
        resumeParsingRepository: parser,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue to profile setup'));
      await tester.pumpAndSettle();
      await _selectAndContinue(tester, 'Find a new job');
      await tester.enterText(
        find.byKey(const ValueKey('full-name-field')),
        'Ravi Singh',
      );
      await _continue(tester);
      await tester.enterText(find.byKey(const ValueKey('city-field')), 'Pune');
      await tester.enterText(
        find.byKey(const ValueKey('state-field')),
        'Maharashtra',
      );
      await tester.enterText(
        find.byKey(const ValueKey('pin-code-field')),
        '411001',
      );
      await _continue(tester);
      await _selectAndContinue(tester, 'Class 12 pass');
      await _selectAndContinue(tester, 'Fresher');
      await _selectAndContinue(tester, 'Warehouse Operations Associate');

      await tester.ensureVisible(
        find.byKey(const ValueKey('resume-text-field')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('resume-text-field')),
        'Asha Kumari, Warehouse Associate at ABC Logistics, 2 years experience.',
      );
      await tester.ensureVisible(find.text('Use AI to read this text'));
      await tester.tap(find.text('Use AI to read this text'));
      await tester.pump();
      final extractButton = find.widgetWithText(
        FilledButton,
        'Extract details',
      );
      await Scrollable.ensureVisible(
        tester.element(extractButton),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(extractButton);
      await tester.pumpAndSettle();

      expect(find.text('Asha Kumari'), findsOneWidget);

      // Ravi's own typed name survives all the way to Review, not
      // overwritten by the extracted "Asha Kumari".
      await _continue(tester); // step 6 -> 7 (voice, skip)
      await _continue(tester); // step 7 -> 8 (consent)
      await tester.tap(find.text('Platform terms'));
      await tester.tap(find.text('Privacy notice'));
      await _continue(tester); // step 8 -> 9 (review)
      expect(find.text('Review your profile'), findsOneWidget);
      expect(find.text('Ravi Singh'), findsOneWidget);
      expect(find.text('Asha Kumari'), findsNothing);
    });

    testWidgets('shows a failure message and still lets the candidate continue', (
      tester,
    ) async {
      // No resumeParsingRepository passed -- pumpCandidateApp's own
      // default (UnavailableResumeParsingRepository) applies, same as
      // this app's real behaviour with no live backend configured.
      await tester.pumpCandidateApp(
        candidateSessionRepository: sessions,
        candidateOnboardingRepository: InMemoryCandidateOnboardingRepository(),
      );
      await _navigateToResumeStep(tester);

      await tester.ensureVisible(
        find.byKey(const ValueKey('resume-text-field')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('resume-text-field')),
        'Asha Kumari, Warehouse Associate at ABC Logistics, 2 years experience.',
      );
      await tester.ensureVisible(find.text('Use AI to read this text'));
      await tester.tap(find.text('Use AI to read this text'));
      await tester.pump();
      final extractButton = find.widgetWithText(
        FilledButton,
        'Extract details',
      );
      await Scrollable.ensureVisible(
        tester.element(extractButton),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(extractButton);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Resume parsing needs a configured backend and is not '
          'available in this build.',
        ),
        findsOneWidget,
      );
      expect(find.text('What we found'), findsNothing);

      // The step is genuinely optional -- a failed extraction never
      // blocks moving on.
      await tester.tap(find.text('Save and continue'));
      await tester.pumpAndSettle();
      expect(find.text('Voice introduction'), findsOneWidget);
    });
  });

  testWidgets('onboarding remains usable with scaled text on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpCandidateApp(
      candidateSessionRepository: sessions,
      candidateOnboardingRepository: InMemoryCandidateOnboardingRepository(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to profile setup'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Save and continue'), findsOneWidget);
  });
}

Future<void> _selectAndContinue(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await _continue(tester);
}

Future<void> _continue(WidgetTester tester) async {
  await tester.tap(find.text('Save and continue'));
  await tester.pump();
  await tester.pumpAndSettle();
}

/// The current step's `_StepHeading` icon -- one `AppIconPlate` is on
/// screen per step, so this is unambiguous.
IconData _stepHeadingIcon(WidgetTester tester) {
  return tester.widget<AppIconPlate>(find.byType(AppIconPlate)).icon;
}

/// Walks a fresh draft through steps 0-5 (goal, name, location, education,
/// experience, roles) up to step 6 (resume upload), the same path
/// `candidate can complete onboarding with versioned consent` walks
/// further -- shared here since several resume-step tests all need to
/// start from the same place.
Future<void> _navigateToResumeStep(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue to profile setup'));
  await tester.pumpAndSettle();
  await _selectAndContinue(tester, 'Find a new job');
  await tester.enterText(
    find.byKey(const ValueKey('full-name-field')),
    'Asha Kumari',
  );
  await _continue(tester);
  await tester.enterText(find.byKey(const ValueKey('city-field')), 'Lucknow');
  await tester.enterText(
    find.byKey(const ValueKey('state-field')),
    'Uttar Pradesh',
  );
  await tester.enterText(
    find.byKey(const ValueKey('pin-code-field')),
    '226001',
  );
  await _continue(tester);
  await _selectAndContinue(tester, 'Class 12 pass');
  await _selectAndContinue(tester, 'Fresher');
  await _selectAndContinue(tester, 'Warehouse Operations Associate');
}

class _FakeResumeParsingRepository implements ResumeParsingRepository {
  final calls = <ResumeParseRequest>[];

  @override
  Future<Result<ResumeParseResult>> parse(ResumeParseRequest request) async {
    calls.add(request);
    return const Success(
      ResumeParseResult(
        adapter: 'fake',
        requiresCandidateReview: false,
        fields: {
          'fullName': 'Asha Kumari',
          'phone': '',
          'email': '',
          'city': '',
          'headline': 'Warehouse Associate',
          'yearsOfExperience': '2 years',
          'education': '',
          'workHistory': '',
          'skills': '',
        },
      ),
    );
  }
}
