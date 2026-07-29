import 'package:candidate_mobile/core/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('button exposes semantics and invokes its action', (
    tester,
  ) async {
    var pressed = false;
    final semantics = tester.ensureSemantics();

    await tester.pumpThemedWidget(
      Center(
        child: AppButton(
          label: 'Continue',
          expand: false,
          onPressed: () => pressed = true,
        ),
      ),
    );

    expect(find.bySemanticsLabel('Continue'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    expect(pressed, isTrue);
    semantics.dispose();
  });

  testWidgets('loading button is visibly busy and cannot be pressed', (
    tester,
  ) async {
    var pressCount = 0;

    await tester.pumpThemedWidget(
      AppButton(
        label: 'Saving progress',
        isLoading: true,
        onPressed: () => pressCount++,
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    expect(pressCount, 0);
  });

  testWidgets('long Hindi labels expand without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const label =
        'आज का कौशल अभ्यास पूरा करके अपनी अगली नौकरी की तैयारी जारी रखें';
    await tester.pumpThemedWidget(
      AppButton(label: label, onPressed: () {}),
      textScaler: TextScaler.linear(1.6),
    );

    expect(find.text(label), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
