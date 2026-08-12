import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/app/router/app_router.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/onboarding/data/secure_candidate_onboarding_repository.dart';
import 'package:candidate_mobile/features/authentication/presentation/authenticated_placeholder_screen.dart';
import 'package:candidate_mobile/features/onboarding/presentation/sign_in_choice_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  test('workplace simulation routes stay under the Practice hierarchy', () {
    expect(workplaceSimulationHubRoutePath, startsWith('/practise/'));
    expect(
      workplaceSimulationRoutePath,
      startsWith('$workplaceSimulationHubRoutePath/'),
    );
    expect(
      workplaceBriefingRoutePath,
      startsWith('$workplaceSimulationRoutePath/'),
    );
    expect(
      workplaceOverviewRoutePath,
      startsWith('$workplaceSimulationRoutePath/'),
    );
    for (final path in [
      workplaceDocumentDeskRoutePath,
      workplaceReceivingDockRoutePath,
      workplaceInspectionZoneRoutePath,
    ]) {
      expect(path, startsWith('$workplaceSimulationRoutePath/'));
      expect(path, isNot(startsWith('/practice/')));
    }
    expect(workplaceSimulationRoutePattern, contains(':missionId'));
    expect(workplaceDocumentDeskRoutePattern, contains(':missionId'));
    expect(workplaceReceivingDockRoutePattern, contains(':missionId'));
    expect(workplaceInspectionZoneRoutePattern, contains(':missionId'));
    expect(
      workplaceDocumentDeskPath('mission-2'),
      '/practise/workplace-simulation/mission-2/document-desk',
    );
  });

  testWidgets('opens the candidate welcome route after splash', (tester) async {
    await tester.pumpCandidateApp();
    await tester.pumpAndSettle();

    expect(
      find.text('Build skills. Prove your readiness. Find better work.'),
      findsOneWidget,
    );
    expect(find.text('Choose your language'), findsOneWidget);
    expect(find.text('Flutter Demo'), findsNothing);
    expect(find.text('0'), findsNothing);
  });

  testWidgets(
    'Google sign-in from Sign-in choice goes straight to Authenticated, '
    'skipping Email/OTP entirely -- confirmed from the router\'s own wiring, '
    'not assumed (see createAppRouter\'s signInChoiceRoutePath route: '
    'onGoogleAuthenticated is context.go(authenticatedRoutePath) directly, '
    'with no Email/OTP route in between, unlike onContinueWithEmail which '
    'pushes emailEntryRoutePath). A real Google sign-in needs a live '
    'Supabase client this test sandbox does not have, so this drives the '
    'same callback the router hands the screen -- proving the *navigation* '
    'the router performs, not the OAuth call itself.',
    (tester) async {
      final sessions = InMemoryCandidateSessionRepository();
      await tester.pumpCandidateApp(candidateSessionRepository: sessions);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose your language'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.byType(SignInChoiceScreen), findsOneWidget);
      // The real `_signInWithGoogle` saves the session before invoking this
      // callback; replicated here since this test bypasses that method
      // (see the reasoning above) to isolate the router's own navigation
      // from the OAuth call. The router's own redirect rule (not this
      // test) is what then requires an authenticated session to reach
      // `authenticatedRoutePath` at all -- without this, `context.go`
      // would bounce straight back to Welcome.
      await sessions.saveSession(
        const CandidateSession(
          candidateId: 'google-candidate',
          isAuthenticated: true,
        ),
      );
      tester
          .widget<SignInChoiceScreen>(find.byType(SignInChoiceScreen))
          .onGoogleAuthenticated();
      await tester.pumpAndSettle();

      // Landed on Authenticated, having visited neither Email nor OTP.
      expect(find.byType(SignInChoiceScreen), findsNothing);
      expect(find.text('Enter your email address'), findsNothing);
      expect(find.text('Enter the 6-digit code'), findsNothing);
      expect(find.byType(AuthenticatedPlaceholderScreen), findsOneWidget);
    },
  );

  testWidgets(
    'the email path visits both Email and OTP before Authenticated -- the '
    'real 4-screen path the Google shortcut above does not take',
    (tester) async {
      await tester.pumpCandidateApp();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose your language'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue with email'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your email address'), findsOneWidget);

      await tester.enterText(
        find.bySemanticsLabel('Email address'),
        'candidate@example.com',
      );
      await tester.ensureVisible(find.text('Send development code'));
      await tester.tap(find.text('Send development code'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Enter the 6-digit code'), findsOneWidget);

      await tester.enterText(
        find.bySemanticsLabel('Six digit one time password'),
        '123456',
      );
      await tester.tap(find.text('Verify and continue'));
      await tester.pumpAndSettle();

      expect(find.text('Development sign-in complete'), findsOneWidget);
    },
  );

  test(
    'appRouterProvider keeps the same GoRouter instance when the onboarding '
    'repository swaps backend mid-session '
    '(real-device report: the app snapped back to the branded startup '
    'splash, sometimes hanging there, right after Google sign-in completed '
    '-- traced to canUseLiveBackendProvider invalidating itself on every '
    'Supabase auth event, which swapped candidateOnboardingRepositoryProvider '
    'from its secure-storage backend to its Supabase one, which rebuilt '
    'appRouterProvider because it used to `ref.watch` that provider, which '
    'constructs a brand new GoRouter with no initialLocation -- i.e. back '
    'at "/". A GoRouter identity change is a full navigation reset; it must '
    'never be a side effect of which repository backend happens to be live.)',
    () {
      final sessionRepository = InMemoryCandidateSessionRepository();
      final secureBackedOnboarding = InMemoryCandidateOnboardingRepository();
      final supabaseBackedOnboarding = InMemoryCandidateOnboardingRepository();

      final overrides = [
        candidateSessionRepositoryProvider.overrideWithValue(sessionRepository),
        candidateOnboardingRepositoryProvider.overrideWithValue(
          secureBackedOnboarding,
        ),
      ];
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      final routerBeforeSignIn = container.read(appRouterProvider);

      // Simulate exactly what canUseLiveBackendProvider does after Google
      // sign-in: candidateOnboardingRepositoryProvider re-resolving to a
      // different repository *instance* while the app is mid-session, with
      // nothing else about the app having changed.
      container.updateOverrides([
        candidateSessionRepositoryProvider.overrideWithValue(sessionRepository),
        candidateOnboardingRepositoryProvider.overrideWithValue(
          supabaseBackedOnboarding,
        ),
      ]);

      final routerAfterSignIn = container.read(appRouterProvider);

      expect(
        identical(routerBeforeSignIn, routerAfterSignIn),
        isTrue,
        reason:
            'appRouterProvider must not rebuild -- and therefore must not '
            'reset navigation back to "/" -- just because the onboarding '
            'repository backend changed underneath it.',
      );
    },
  );
}
