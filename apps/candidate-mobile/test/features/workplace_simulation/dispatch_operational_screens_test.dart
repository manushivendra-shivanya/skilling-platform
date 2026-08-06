import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/app/theme/app_theme.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/application/workplace_simulation_controller.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/asset_simulation_content_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/local_simulation_attempt_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/presentation/consolidation_bay_screen.dart';
import 'package:candidate_mobile/features/workplace_simulation/presentation/dispatch_gate_screen.dart';
import 'package:candidate_mobile/features/workplace_simulation/presentation/picking_station_screen.dart';
import 'package:candidate_mobile/features/workplace_simulation/presentation/vehicle_check_screen.dart';
import 'package:candidate_mobile/features/workplace_simulation/presentation/workplace_overview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Dispatch workstation screens render, lock correctly and scan a crate',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final missionId = WorkplaceSimulationController.dispatchMissionId;
      final container = await _activeDispatchContainer(missionId);
      addTearDown(container.dispose);
      var opened = false;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: WorkplaceOverviewScreen(
              missionId: missionId,
              onOpenWorkstation: (_) => opened = true,
              onReturnToPractice: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      for (final station in const [
        'Picking Station',
        'Consolidation Bay',
        'Vehicle Check',
        'Dispatch Gate',
      ]) {
        expect(find.text(station), findsOneWidget);
      }

      await tester.tap(find.text('Picking Station'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(opened, isTrue);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: ConsolidationBayScreen(
              missionId: missionId,
              onBack: () {},
              onOpenVehicleCheck: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Consolidation Bay is locked'), findsOneWidget);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: VehicleCheckScreen(
              missionId: missionId,
              onBack: () {},
              onOpenDispatchGate: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Vehicle Check is locked'), findsOneWidget);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: DispatchGateScreen(
              missionId: missionId,
              onBack: () {},
              onMissionComplete: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Dispatch Gate is locked'), findsOneWidget);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: PickingStationScreen(
              missionId: missionId,
              onBack: () {},
              onOpenConsolidationBay: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Scan every crate for its route'), findsOneWidget);
      expect(find.text('Scan (matched)'), findsWidgets);

      await tester.tap(find.text('Scan (matched)').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final attempt = container
          .read(workplaceSimulationControllerProvider(missionId))
          .requireValue
          .attempt!;
      expect(
        attempt.actions.any((action) => action.taskId == 'pick-order-items'),
        isTrue,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}

Future<ProviderContainer> _activeDispatchContainer(String missionId) async {
  final container = ProviderContainer(
    overrides: [
      candidateSessionRepositoryProvider.overrideWithValue(
        InMemoryCandidateSessionRepository(
          session: const CandidateSession(
            candidateId: 'dispatch-screen-candidate',
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
  await container.read(workplaceSimulationControllerProvider(missionId).future);
  final controller = container.read(
    workplaceSimulationControllerProvider(missionId).notifier,
  );
  await controller.startMission(scenarioSeed: 82441);
  await controller.setBriefingAcknowledged(true);
  final result = await controller.beginShift();
  if (result != BeginShiftResult.success) {
    container.dispose();
    throw StateError('Could not prepare active Dispatch test attempt: $result');
  }
  return container;
}
