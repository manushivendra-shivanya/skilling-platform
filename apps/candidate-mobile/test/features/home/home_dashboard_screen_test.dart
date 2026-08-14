import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/core/widgets/app_card.dart';
import 'package:candidate_mobile/features/home/data/mock_home_dashboard_repository.dart';
import 'package:candidate_mobile/features/home/domain/home_dashboard_repository.dart';
import 'package:candidate_mobile/features/home/presentation/home_dashboard_screen.dart';
import 'package:candidate_mobile/features/home/presentation/home_header.dart';
import 'package:candidate_mobile/features/home/presentation/journey_timeline_card.dart';
import 'package:candidate_mobile/features/home/presentation/today_mission_card.dart';
import 'package:candidate_mobile/l10n/generated/app_localizations.dart';
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: HomeDashboardScreen(
            onOpenDiagnostic: () {},
            onOpenVoiceInterview: () {},
            onOpenPathway: () {},
            onOpenNotifications: () {},
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
    expect(find.text('Start'), findsOneWidget);
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
          certificationStatus: sample.certificationStatus,
          applicationsSentThisMonth: sample.applicationsSentThisMonth,
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
          certificationStatus: sample.certificationStatus,
          applicationsSentThisMonth: sample.applicationsSentThisMonth,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No mission today'), findsOneWidget);
    // No mission means no primary button at all, rather than a disabled one.
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('keeps Home to two rows and never repeats a nav tab', (
    tester,
  ) async {
    // Sample dashboard has no upcoming interview here, so the interview
    // practice shortcut is the row under test -- see the next two tests for
    // what happens to it once an interview *is* present.
    final sample = MockHomeDashboardRepository.sampleDashboard();
    await tester.pumpWidget(
      wrap(
        HomeDashboard(
          candidateFirstName: sample.candidateFirstName,
          goalRoleName: sample.goalRoleName,
          readinessProgress: sample.readinessProgress,
          evidence: sample.evidence,
          learningProgress: sample.learningProgress,
          pendingSyncCount: sample.pendingSyncCount,
          certificationStatus: sample.certificationStatus,
          applicationsSentThisMonth: sample.applicationsSentThisMonth,
          todayMission: sample.todayMission,
          pathway: sample.pathway,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Home is a next step, not a menu. Jobs, the Coach, the Career Passport
    // and the diagnostic are all reachable from the shell; a row here would
    // just duplicate a destination already on screen.
    expect(find.text('Verified naukriyan'), findsNothing);
    expect(find.text('Career Coach se poochein'), findsNothing);
    expect(find.text('Aapke proof'), findsNothing);
    expect(find.text('Career diagnostic'), findsNothing);
    expect(find.text('Interview practice'), findsOneWidget);
  });

  testWidgets(
    'hides the interview-practice shortcut when the interview card already '
    'offers the same CTA',
    (tester) async {
      // sampleDashboard carries a nextInterview, so UpcomingInterviewCard's
      // own "Prepare" button is already on screen -- the shortcut row below
      // would just be a second way to say the same thing.
      await tester.pumpWidget(
        wrap(MockHomeDashboardRepository.sampleDashboard()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Interview practice'), findsNothing);
      expect(find.text('Prepare'), findsOneWidget);
    },
  );

  testWidgets(
    'shows the interview-practice shortcut again once there is no interview '
    'card to duplicate',
    (tester) async {
      final sample = MockHomeDashboardRepository.sampleDashboard();
      await tester.pumpWidget(
        wrap(
          HomeDashboard(
            candidateFirstName: sample.candidateFirstName,
            goalRoleName: sample.goalRoleName,
            readinessProgress: sample.readinessProgress,
            evidence: sample.evidence,
            learningProgress: sample.learningProgress,
            pendingSyncCount: sample.pendingSyncCount,
            certificationStatus: sample.certificationStatus,
            applicationsSentThisMonth: sample.applicationsSentThisMonth,
            todayMission: sample.todayMission,
            pathway: sample.pathway,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Interview practice'), findsOneWidget);
      expect(find.text('Prepare'), findsNothing);
    },
  );

  testWidgets('lifts the mission card into the header gradient', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(MockHomeDashboardRepository.sampleDashboard()),
    );
    await tester.pumpAndSettle();

    // The overlap is the point: the card has to start above where the
    // gradient block ends, or it reads as one more item in a list.
    final headerBottom = tester.getRect(find.byType(HomeHeader)).bottom;
    final cardTop = tester.getRect(find.byType(TodayMissionCard)).top;
    expect(cardTop, lessThan(headerBottom));
  });

  testWidgets('surfaces queued work waiting for a network', (tester) async {
    await tester.pumpWidget(
      wrap(MockHomeDashboardRepository.sampleDashboard()),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('2 items waiting to sync'), findsOneWidget);
  });

  testWidgets("shows the Journey card's four checkpoints for the sample "
      'dashboard', (tester) async {
    await tester.pumpWidget(
      wrap(MockHomeDashboardRepository.sampleDashboard()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Training'), findsOneWidget);
    expect(find.text('Certification'), findsOneWidget);
    expect(find.text('Applications'), findsOneWidget);
    expect(find.text('Interview'), findsOneWidget);

    // All four checkpoints sit inside one JourneyTimelineCard's AppCard,
    // not four separate cards -- the whole card is a single tap target.
    expect(find.byType(JourneyTimelineCard), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(JourneyTimelineCard),
        matching: find.byType(AppCard),
      ),
      findsOneWidget,
    );
  });

  testWidgets("surfaces each Journey checkpoint's plain-language status, "
      'not a bare number or enum name', (tester) async {
    await tester.pumpWidget(
      wrap(MockHomeDashboardRepository.sampleDashboard()),
    );
    await tester.pumpAndSettle();

    // sampleDashboard: pathway 4/12 lessons, certificationStatus.notStarted,
    // 2 applications sent this month, and a scheduled interview with
    // Delhivery Hub in Ghaziabad.
    expect(find.text('4 / 12 lessons'), findsOneWidget);
    expect(find.text('Not started yet'), findsOneWidget);
    expect(find.text('2 applications sent this month'), findsOneWidget);

    // Scoped to the Journey card, not a bare findsOneWidget: sampleDashboard
    // also has an UpcomingInterviewCard above it that repeats the same
    // location text, so the unscoped text legitimately appears twice.
    expect(
      find.descendant(
        of: find.byType(JourneyTimelineCard),
        matching: find.textContaining('Ghaziabad'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('omits the readiness-band note once already job ready -- nothing '
      'further to point toward', (tester) async {
    final sample = MockHomeDashboardRepository.sampleDashboard();
    await tester.pumpWidget(
      wrap(
        HomeDashboard(
          candidateFirstName: sample.candidateFirstName,
          goalRoleName: sample.goalRoleName,
          readinessProgress: 0.9,
          evidence: sample.evidence,
          learningProgress: sample.learningProgress,
          pendingSyncCount: sample.pendingSyncCount,
          certificationStatus: sample.certificationStatus,
          applicationsSentThisMonth: sample.applicationsSentThisMonth,
          todayMission: sample.todayMission,
          pathway: sample.pathway,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Job ready'), findsOneWidget);
    expect(find.textContaining('% to'), findsNothing);
  });
}
