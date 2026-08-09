import 'package:candidate_mobile/app/router/app_router.dart';
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
}
