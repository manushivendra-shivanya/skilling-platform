import 'package:candidate_mobile/core/widgets/app_sticky_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('renders its child inside the sticky chrome', (tester) async {
    await tester.pumpThemedWidget(
      const AppStickyFooter(child: Text('Accept shift')),
    );

    expect(find.text('Accept shift'), findsOneWidget);
    expect(find.byType(SafeArea), findsOneWidget);

    final decoratedBox = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
    final decoration = decoratedBox.decoration as BoxDecoration;
    expect(decoration.boxShadow, isNotEmpty);
  });
}
