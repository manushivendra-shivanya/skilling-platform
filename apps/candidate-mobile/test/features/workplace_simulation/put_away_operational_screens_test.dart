import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/app/theme/app_theme.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/application/workplace_simulation_controller.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/asset_simulation_content_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/local_simulation_attempt_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/presentation/location_planning_screen.dart';
import 'package:candidate_mobile/features/workplace_simulation/presentation/putaway_office_screen.dart';
import 'package:candidate_mobile/features/workplace_simulation/presentation/staging_area_screen.dart';
import 'package:candidate_mobile/features/workplace_simulation/presentation/transport_placement_screen.dart';
import 'package:candidate_mobile/features/workplace_simulation/presentation/workplace_overview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Put Away workstation screens render, lock correctly and open the '
    'putaway list',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final missionId = WorkplaceSimulationController.putAwayMissionId;
      final container = await _activePutAwayContainer(missionId);
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
        'Staging Area',
        'Location Planning',
        'Transport and Placement',
        'Putaway Office',
      ]) {
        expect(find.text(station), findsOneWidget);
      }

      await tester.tap(find.text('Staging Area'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(opened, isTrue);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: LocationPlanningScreen(
              missionId: missionId,
              onBack: () {},
              onOpenTransportPlacement: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Location Planning is locked'), findsOneWidget);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: TransportPlacementScreen(
              missionId: missionId,
              onBack: () {},
              onOpenPutawayOffice: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Transport and Placement is locked'), findsOneWidget);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: PutawayOfficeScreen(
              missionId: missionId,
              onBack: () {},
              onMissionComplete: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Putaway Office is locked'), findsOneWidget);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: StagingAreaScreen(
              missionId: missionId,
              onBack: () {},
              onOpenLocationPlanning: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Putaway Task List PUTAWAY-2026-004'), findsOneWidget);
      expect(find.text('Mark reviewed'), findsOneWidget);

      await tester.tap(find.text('Mark reviewed'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final attempt = container
          .read(workplaceSimulationControllerProvider(missionId))
          .requireValue
          .attempt!;
      expect(attempt.completedTaskIds, contains('open-putaway-list'));

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}

Future<ProviderContainer> _activePutAwayContainer(String missionId) async {
  final container = ProviderContainer(
    overrides: [
      candidateSessionRepositoryProvider.overrideWithValue(
        InMemoryCandidateSessionRepository(
          session: const CandidateSession(
            candidateId: 'put-away-screen-candidate',
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
  await controller.startMission(scenarioSeed: 71204);
  await controller.setBriefingAcknowledged(true);
  final result = await controller.beginShift();
  if (result != BeginShiftResult.success) {
    container.dispose();
    throw StateError('Could not prepare active Put Away test attempt: $result');
  }
  return container;
}
