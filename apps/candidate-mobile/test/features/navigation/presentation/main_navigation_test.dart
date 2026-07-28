import 'package:candidate_mobile/app/router/app_router.dart';
import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/app/theme/app_theme.dart';
import 'package:candidate_mobile/core/analytics/analytics_tracker.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:candidate_mobile/features/jobs/data/local_mock_jobs_repository.dart';
import 'package:candidate_mobile/features/onboarding/data/secure_candidate_onboarding_repository.dart';
import 'package:candidate_mobile/features/onboarding/domain/candidate_onboarding_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      initialDraft: const CandidateOnboardingDraft(
        currentStep: 10,
        isCompleted: true,
      ),
    );
  });

  testWidgets('completed candidate enters all five persistent destinations', (
    tester,
  ) async {
    final analytics = InMemoryAnalyticsTracker();
    await tester.pumpCandidateApp(
      candidateSessionRepository: sessions,
      candidateOnboardingRepository: onboarding,
      analyticsTracker: analytics,
    );
    await tester.pumpAndSettle();

    expect(find.text('Today’s mission'), findsOneWidget);
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    expect(find.text('Your logistics pathway'), findsOneWidget);

    await tester.tap(find.text('Open lesson').first);
    await tester.pumpAndSettle();
    expect(find.text('Inventory accuracy basics'), findsWidgets);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Completed'), findsOneWidget);

    await tester.tap(find.text('Jobs'));
    await tester.pumpAndSettle();
    expect(
      find.text('Demo opportunities • No live employer connection'),
      findsOneWidget,
    );

    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    expect(find.text('Completed'), findsOneWidget);

    await tester.tap(find.text('Practise'));
    await tester.pumpAndSettle();
    expect(find.text('Recommended practice'), findsOneWidget);

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Privacy and consent'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Privacy and consent'), findsOneWidget);
    expect(
      analytics.events.map((event) => event.name),
      contains('main_tab_selected'),
    );
  });

  testWidgets('Android back returns a non-home root tab to Home', (
    tester,
  ) async {
    await tester.pumpCandidateApp(
      candidateSessionRepository: sessions,
      candidateOnboardingRepository: onboarding,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jobs'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Today’s mission'), findsOneWidget);
  });

  testWidgets('global Coach and notifications routes return to selected tab', (
    tester,
  ) async {
    await tester.pumpCandidateApp(
      candidateSessionRepository: sessions,
      candidateOnboardingRepository: onboarding,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jobs'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('AI Coach'));
    await tester.pumpAndSettle();
    expect(find.text('AI Career Coach'), findsWidgets);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.text('Demo opportunities • No live employer connection'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('No notifications yet'), findsWidgets);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.text('Demo opportunities • No live employer connection'),
      findsOneWidget,
    );
  });

  testWidgets('completed candidate can open a tab route directly', (
    tester,
  ) async {
    final router = createAppRouter(
      analyticsTracker: InMemoryAnalyticsTracker(),
      candidateSessionRepository: sessions,
      candidateOnboardingRepository: onboarding,
      showDevelopmentTools: false,
      initialLocation: jobsRoutePath,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          candidateSessionRepositoryProvider.overrideWithValue(sessions),
          candidateOnboardingRepositoryProvider.overrideWithValue(onboarding),
          jobsRepositoryProvider.overrideWithValue(
            LocalMockJobsRepository(InMemorySecureKeyValueStore()),
          ),
        ],
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Demo opportunities • No live employer connection'),
      findsOneWidget,
    );
    expect(find.text('Jobs'), findsWidgets);
  });

  testWidgets('protected direct route sends signed-out candidate to welcome', (
    tester,
  ) async {
    final router = createAppRouter(
      analyticsTracker: InMemoryAnalyticsTracker(),
      candidateSessionRepository: InMemoryCandidateSessionRepository(),
      candidateOnboardingRepository: InMemoryCandidateOnboardingRepository(),
      showDevelopmentTools: false,
      initialLocation: jobsRoutePath,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose your language'), findsOneWidget);
    expect(
      find.text('Demo opportunities • No live employer connection'),
      findsNothing,
    );
  });

  testWidgets('five-tab shell supports narrow scaled layouts', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpCandidateApp(
      candidateSessionRepository: sessions,
      candidateOnboardingRepository: onboarding,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Practise'), findsOneWidget);
    expect(find.text('AI Coach'), findsOneWidget);
  });
}
