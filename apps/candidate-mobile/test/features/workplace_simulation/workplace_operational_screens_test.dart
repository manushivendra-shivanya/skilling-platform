import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/app/theme/app_theme.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/application/workplace_simulation_controller.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/asset_simulation_content_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/local_simulation_attempt_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/presentation/inspection_zone_handoff_screen.dart';
import 'package:candidate_mobile/features/workplace_simulation/presentation/workplace_overview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Screen 03 renders controller-derived station states at large text',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1200);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final container = await _activeContainer();
      addTearDown(container.dispose);
      var receivingOpened = false;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: WorkplaceOverviewScreen(
              missionId: WorkplaceSimulationController.missionId,
              onOpenDocumentDesk: () {},
              onOpenReceivingDock: () => receivingOpened = true,
              onOpenInspectionZone: () {},
              onReturnToPractice: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      for (final station in const [
        'Document Desk',
        'Receiving Dock',
        'Inspection Zone',
        'Barcode Station',
        'Quarantine Zone',
        'Receiving Office',
      ]) {
        expect(find.text(station), findsOneWidget);
      }
      expect(find.textContaining('Recommended'), findsOneWidget);

      await tester.tap(find.text('Receiving Dock'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(receivingOpened, isFalse);
      expect(find.textContaining('Complete'), findsWidgets);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: InspectionZoneHandoffScreen(
              missionId: WorkplaceSimulationController.missionId,
              onBack: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Inspection Zone is locked'), findsOneWidget);
      expect(find.text('Inspection workflow coming next.'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}

Future<ProviderContainer> _activeContainer() async {
  final container = ProviderContainer(
    overrides: [
      candidateSessionRepositoryProvider.overrideWithValue(
        InMemoryCandidateSessionRepository(
          session: const CandidateSession(
            candidateId: 'screen-operations-candidate',
            isAuthenticated: true,
          ),
        ),
      ),
      simulationContentRepositoryProvider.overrideWithValue(
        AssetSimulationContentRepository(),
      ),
      simulationAttemptRepositoryProvider.overrideWithValue(
        InMemorySimulationAttemptRepository(),
      ),
    ],
  );
  await container.read(workplaceSimulationControllerProvider.future);
  final controller = container.read(
    workplaceSimulationControllerProvider.notifier,
  );
  await controller.startMission(scenarioSeed: 48127);
  await controller.setBriefingAcknowledged(true);
  final result = await controller.beginShift();
  if (result != BeginShiftResult.success) {
    container.dispose();
    throw StateError('Could not prepare active WMS test attempt: $result');
  }
  return container;
}
