import 'package:candidate_mobile/core/widgets/app_accent_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('renders the given icon and label', (tester) async {
    await tester.pumpThemedWidget(
      const AppAccentPill(
        icon: Icons.bolt_rounded,
        label: 'Starts in 45m',
        background: Colors.orange,
        foreground: Colors.white,
      ),
    );

    expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
    expect(find.text('Starts in 45m'), findsOneWidget);
  });

  testWidgets('carries an accessible label when semanticLabel is set', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpThemedWidget(
      const AppAccentPill(
        icon: Icons.star_rounded,
        label: 'Top match for you',
        background: Colors.green,
        foreground: Colors.white,
        semanticLabel: 'Top match for you',
      ),
    );

    final node = tester.getSemantics(find.byType(AppAccentPill));
    expect(node.label, contains('Top match for you'));
    semantics.dispose();
  });
}
