import 'package:candidate_mobile/core/widgets/app_loading_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the label and an animating progress value', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppLoadingProgressBar(label: 'Finding jobs for you…'),
        ),
      ),
    );

    expect(find.text('Finding jobs for you…'), findsOneWidget);
    final initial = tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .value;
    expect(initial, 0);

    // A few ticks in: value should have eased upward, never past the
    // widget's own ceiling (it never claims to be done -- only the
    // caller's real state change replaces this widget on completion).
    await tester.pump(const Duration(milliseconds: 600));
    final afterTicks = tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .value;
    expect(afterTicks, greaterThan(0));
    expect(afterTicks, lessThan(0.92));
  });

  testWidgets(
    'swaps to the slow-connection label after the threshold, not before',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppLoadingProgressBar(
              label: 'Finding jobs for you…',
              slowConnectionLabel: 'Still finding jobs for you…',
              slowConnectionThreshold: Duration(seconds: 2),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Finding jobs for you…'), findsOneWidget);
      expect(find.text('Still finding jobs for you…'), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Still finding jobs for you…'), findsOneWidget);
      expect(find.text('Finding jobs for you…'), findsNothing);
    },
  );

  testWidgets('no slow-connection label means no swap ever happens', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppLoadingProgressBar(label: 'Finding jobs for you…'),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 10));
    expect(find.text('Finding jobs for you…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing mid-animation cancels its timers cleanly', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppLoadingProgressBar(
            label: 'Finding jobs for you…',
            slowConnectionLabel: 'Still finding jobs for you…',
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    // If either Timer weren't cancelled in dispose(), a later tick firing
    // against an unmounted State would throw during the next pump.
    await tester.pump(const Duration(seconds: 10));
    expect(tester.takeException(), isNull);
  });
}
