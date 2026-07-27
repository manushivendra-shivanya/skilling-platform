import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/core/network/connectivity_status.dart';
import 'package:candidate_mobile/features/onboarding/data/secure_candidate_onboarding_repository.dart';
import 'package:candidate_mobile/features/onboarding/domain/candidate_onboarding_draft.dart';
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
