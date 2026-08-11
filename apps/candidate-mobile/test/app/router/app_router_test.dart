import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/app/router/app_router.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/onboarding/data/secure_candidate_onboarding_repository.dart';
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
