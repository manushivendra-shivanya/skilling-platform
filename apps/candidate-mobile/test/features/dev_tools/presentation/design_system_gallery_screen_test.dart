import 'package:candidate_mobile/core/config/app_environment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  testWidgets('development gallery exposes the design system components', (
    tester,
  ) async {
    await tester.pumpCandidateApp();
    await tester.pumpAndSettle();

    await tester.tap(find.text('View design system'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Component gallery'), findsOneWidget);
    expect(find.text('Saksham design system'), findsOneWidget);
    expect(find.text('Colour tokens'), findsOneWidget);

    final scrollable = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.text('Bottom sheet, dialog, and snackbar'),
      600,
      scrollable: scrollable,
    );

    expect(find.text('Bottom sheet, dialog, and snackbar'), findsOneWidget);
    expect(find.text('Show success message'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('production configuration hides development tools', (
    tester,
  ) async {
    await tester.pumpCandidateApp(
      config: const AppConfig(
        environment: AppEnvironment.production,
        enableLogging: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('View design system'), findsNothing);
  });
}
