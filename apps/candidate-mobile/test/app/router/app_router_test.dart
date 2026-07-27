import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
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
