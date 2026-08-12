import 'package:candidate_mobile/core/widgets/app_initials_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('derives up to 2 initials from the first letter of each word', (
    tester,
  ) async {
    await tester.pumpThemedWidget(
      const AppInitialsAvatar(name: 'Ravi Kumar Singh'),
    );

    expect(find.text('RK'), findsOneWidget);
  });

  testWidgets('uses a single initial for a one-word name', (tester) async {
    await tester.pumpThemedWidget(const AppInitialsAvatar(name: 'Cher'));

    expect(find.text('C'), findsOneWidget);
  });

  testWidgets('ignores extra whitespace between and around words', (
    tester,
  ) async {
    await tester.pumpThemedWidget(
      const AppInitialsAvatar(name: '  ravi   kumar  '),
    );

    expect(find.text('RK'), findsOneWidget);
  });

  testWidgets('renders a circle by default', (tester) async {
    await tester.pumpThemedWidget(const AppInitialsAvatar(name: 'Ravi Kumar'));

    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.borderRadius, isNull);
  });

  testWidgets('renders a rounded square when circular is false', (
    tester,
  ) async {
    await tester.pumpThemedWidget(
      const AppInitialsAvatar(name: 'Ravi Kumar', circular: false),
    );

    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.shape, BoxShape.rectangle);
    expect(decoration.borderRadius, isNotNull);
  });

  testWidgets('sizes the avatar and exposes the full name as a semantic '
      'label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpThemedWidget(
      const AppInitialsAvatar(name: 'Ravi Kumar', size: 48),
    );

    final container = tester.widget<Container>(find.byType(Container));
    expect(container.constraints?.maxWidth, 48);
    expect(container.constraints?.maxHeight, 48);
    expect(find.bySemanticsLabel('Ravi Kumar'), findsOneWidget);

    semantics.dispose();
  });

  testWidgets('uses the given background and foreground colors', (
    tester,
  ) async {
    await tester.pumpThemedWidget(
      const AppInitialsAvatar(
        name: 'Ravi Kumar',
        background: Colors.green,
        foreground: Colors.white,
      ),
    );

    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, Colors.green);

    final text = tester.widget<Text>(find.text('RK'));
    expect(text.style?.color, Colors.white);
  });
}
