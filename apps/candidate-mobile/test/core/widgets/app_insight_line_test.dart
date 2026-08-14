import 'package:candidate_mobile/core/widgets/app_insight_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the given text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppInsightLine(text: '8 lessons left to finish Receiving'),
        ),
      ),
    );

    expect(find.text('8 lessons left to finish Receiving'), findsOneWidget);
  });
}
