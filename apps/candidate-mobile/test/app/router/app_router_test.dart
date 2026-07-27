import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('opens the candidate application startup route', (tester) async {
    await tester.pumpCandidateApp();
    await tester.pumpAndSettle();

    expect(find.text('Your skilling journey starts here'), findsOneWidget);
    expect(find.text('Flutter Demo'), findsNothing);
    expect(find.text('0'), findsNothing);
  });
}
