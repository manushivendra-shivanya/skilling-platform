import 'package:candidate_mobile/app/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  test('workplace simulation routes stay under the Practice hierarchy', () {
    expect(workplaceSimulationHubRoutePath, startsWith('$practiseRoutePath/'));
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
