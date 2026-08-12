import 'package:candidate_mobile/core/widgets/app_icon_plate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('renders the given icon at the given size and color', (
    tester,
  ) async {
    await tester.pumpThemedWidget(
      const AppIconPlate(
        icon: Icons.route_outlined,
        background: Colors.green,
        foreground: Colors.white,
        size: 44,
      ),
    );

    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, Icons.route_outlined);
    expect(icon.color, Colors.white);

    final container = tester.widget<Container>(find.byType(Container));
    expect(container.constraints?.maxWidth, 44);
    expect(container.constraints?.maxHeight, 44);

    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, Colors.green);
  });

  testWidgets('AppIconPlateButton exposes a button semantics node and label', (
    tester,
  ) async {
    var tapped = false;
    final semantics = tester.ensureSemantics();

    await tester.pumpThemedWidget(
      AppIconPlateButton(
        icon: Icons.schedule_outlined,
        label: 'Availability',
        background: Colors.green,
        foreground: Colors.white,
        onTap: () => tapped = true,
      ),
    );

    expect(find.bySemanticsLabel('Availability'), findsOneWidget);
    expect(find.text('Availability'), findsOneWidget);

    await tester.tap(find.byType(AppIconPlateButton));
    expect(tapped, isTrue);
    semantics.dispose();
  });
}
