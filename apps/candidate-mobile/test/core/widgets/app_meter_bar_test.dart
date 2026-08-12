import 'package:candidate_mobile/core/widgets/app_meter_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('fills the given fraction of the bar', (tester) async {
    await tester.pumpThemedWidget(
      const AppMeterBar(
        value: 0.4,
        trackColor: Colors.grey,
        fillColor: Colors.blue,
      ),
    );

    final fill = tester.widget<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(fill.widthFactor, 0.4);
  });

  testWidgets('clamps an out-of-range value instead of throwing', (
    tester,
  ) async {
    await tester.pumpThemedWidget(const AppMeterBar(value: 1.4));
    final fill = tester.widget<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(fill.widthFactor, 1.0);
    expect(tester.takeException(), isNull);

    await tester.pumpThemedWidget(const AppMeterBar(value: -0.2));
    final fillLow = tester.widget<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(fillLow.widthFactor, 0.0);
    expect(tester.takeException(), isNull);
  });
}
