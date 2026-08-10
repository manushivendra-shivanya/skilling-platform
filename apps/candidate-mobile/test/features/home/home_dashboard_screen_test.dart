import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/features/home/data/mock_home_dashboard_repository.dart';
import 'package:candidate_mobile/features/home/domain/home_dashboard_repository.dart';
import 'package:candidate_mobile/features/home/presentation/home_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(HomeDashboard? dashboard) {
    return ProviderScope(
      overrides: [
        homeDashboardRepositoryProvider.overrideWithValue(
          MockHomeDashboardRepository(response: Success(dashboard)),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: HomeDashboardScreen(
            onOpenCoach: () {},
            onOpenDiagnostic: () {},
            onOpenVoiceInterview: () {},
            onOpenCareerPassport: () {},
            onOpenJobs: () {},
            onOpenPathway: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('shows the candidate, their goal and evidence-backed readiness', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(MockHomeDashboardRepository.sampleDashboard()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rahul'), findsOneWidget);
    expect(find.text('Warehouse Operations Associate'), findsOneWidget);
    expect(find.text('62%'), findsOneWidget);
    expect(find.text('Building'), findsOneWidget);
    // The spec requires the readiness summary to carry an evidence count,
    // and the count to carry its recency window.
    expect(find.textContaining('7 proof items'), findsOneWidget);
    expect(find.textContaining('last 30 days'), findsOneWidget);
  });

  testWidgets('offers exactly one filled primary action', (tester) async {
    await tester.pumpWidget(
      wrap(MockHomeDashboardRepository.sampleDashboard()),
    );
    await tester.pumpAndSettle();

    // The spec asks for a today card with one primary CTA. Any second
    // FilledButton means the hierarchy has regressed.
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.textContaining('शुरू करें'), findsOneWidget);
  });

  testWidgets('every control on Home is enabled', (tester) async {
    await tester.pumpWidget(
      wrap(MockHomeDashboardRepository.sampleDashboard()),
    );
    await tester.pumpAndSettle();

    // Guards the regression this redesign removed: a disabled "Mission
    // arrives in Learning" button, and rail tiles wired to no callback.
    final buttons = tester.widgetList<ButtonStyleButton>(
      find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
    expect(buttons, isNotEmpty);
    for (final button in buttons) {
      expect(button.onPressed, isNotNull, reason: 'found a dead control');
    }
  });

  testWidgets('renders without the interview the backend cannot yet supply', (
    tester,
  ) async {
    final sample = MockHomeDashboardRepository.sampleDashboard();
    await tester.pumpWidget(
      wrap(
        HomeDashboard(
          candidateFirstName: sample.candidateFirstName,
          goalRoleName: sample.goalRoleName,
          readinessProgress: sample.readinessProgress,
          evidence: sample.evidence,
          learningProgress: sample.learningProgress,
          pendingSyncCount: 0,
          todayMission: sample.todayMission,
          pathway: sample.pathway,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Interview ·'), findsNothing);
    expect(find.text('Rahul'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explains itself when there is no mission to start', (
    tester,
  ) async {
    final sample = MockHomeDashboardRepository.sampleDashboard();
    await tester.pumpWidget(
      wrap(
        HomeDashboard(
          candidateFirstName: sample.candidateFirstName,
          goalRoleName: sample.goalRoleName,
          readinessProgress: sample.readinessProgress,
          evidence: sample.evidence,
          learningProgress: sample.learningProgress,
          pendingSyncCount: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aaj koi mission nahi'), findsOneWidget);
    // No mission means no primary button at all, rather than a disabled one.
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('surfaces queued work waiting for a network', (tester) async {
    await tester.pumpWidget(
      wrap(MockHomeDashboardRepository.sampleDashboard()),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('2 items waiting to sync'), findsOneWidget);
  });
}
