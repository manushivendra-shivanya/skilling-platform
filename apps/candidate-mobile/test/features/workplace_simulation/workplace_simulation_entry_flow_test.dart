import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/app/theme/app_theme.dart';
import 'package:candidate_mobile/core/analytics/analytics_tracker.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/application/workplace_simulation_controller.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/asset_simulation_content_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/local_simulation_attempt_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_enums.dart';
import 'package:candidate_mobile/features/workplace_simulation/presentation/simulation_entry_screen.dart';
import 'package:candidate_mobile/features/workplace_simulation/presentation/supervisor_briefing_screen.dart';
import 'package:candidate_mobile/features/workplace_simulation/presentation/workplace_overview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'candidate enters a shift, acknowledges the briefing and starts timed work',
    (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final attempts = InMemorySimulationAttemptRepository();
      final analytics = InMemoryAnalyticsTracker();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            candidateSessionRepositoryProvider.overrideWithValue(
              InMemoryCandidateSessionRepository(
                session: const CandidateSession(
                  candidateId: 'screen-candidate',
                  isAuthenticated: true,
                ),
              ),
            ),
            simulationContentRepositoryProvider.overrideWithValue(
              AssetSimulationContentRepository(),
            ),
            simulationAttemptRepositoryProvider.overrideWithValue(attempts),
            analyticsTrackerProvider.overrideWithValue(analytics),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Builder(
              builder: (entryContext) => SimulationEntryScreen(
                missionId: WorkplaceSimulationController.missionId,
                onOpenBriefing: () => Navigator.of(entryContext).push(
                  MaterialPageRoute<void>(
                    builder: (briefingContext) => SupervisorBriefingScreen(
                      missionId: WorkplaceSimulationController.missionId,
                      onBackToEntry: () => Navigator.of(briefingContext).pop(),
                      onOpenWorkplace: () =>
                          Navigator.of(briefingContext).pushReplacement(
                            MaterialPageRoute<void>(
                              builder: (_) => WorkplaceOverviewScreen(
                                missionId:
                                    WorkplaceSimulationController.missionId,
                                onOpenWorkstation: (_) {},
                                onReturnToPractice: () {},
                              ),
                            ),
                          ),
                    ),
                  ),
                ),
                onContinueWorkplace: () {},
                onExit: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Central Distribution Centre'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('Start Shift'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Start Shift'));
      await tester.pumpAndSettle();

      expect(find.text('Shift Briefing'), findsOneWidget);
      expect(find.text('Apex Consumer Products'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('Begin Shift'),
        500,
        scrollable: find.byType(Scrollable).last,
      );
      final disabledButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Begin Shift'),
      );
      expect(disabledButton.onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('briefing-acknowledgement')));
      await tester.pumpAndSettle();
      final acknowledged = await attempts.getActiveAttempt(
        'screen-candidate',
        WorkplaceSimulationController.missionId,
      );
      expect(acknowledged!.briefingAcknowledged, isTrue);
      expect(acknowledged.shiftStartedAt, isNull);

      await tester.ensureVisible(find.text('Begin Shift'));
      await tester.tap(find.text('Begin Shift'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Workplace Overview'), findsOneWidget);
      expect(find.text('Document Desk'), findsOneWidget);
      expect(find.textContaining('Recommended'), findsOneWidget);
      final active = await attempts.getActiveAttempt(
        'screen-candidate',
        WorkplaceSimulationController.missionId,
      );
      expect(active!.state, MissionState.inProgress);
      expect(active.shiftStartedAt, isNotNull);
      expect(active.elapsedSimulationSeconds, 0);
      expect(active.timerStatus, SimulationTimerStatus.running);
      expect(active.currentStageId, 'document-verification');
      expect(
        active.auditEvents.map((event) => event.type),
        containsAllInOrder([
          'attemptCreated',
          'briefingOpened',
          'briefingAcknowledged',
          'shiftStartRequested',
          'shiftStarted',
        ]),
      );
      expect(active.actions, isEmpty);
      expect(analytics.events, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
