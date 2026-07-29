import 'package:candidate_mobile/core/widgets/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('bottom sheet, confirmation dialog, and snackbar are usable', (
    tester,
  ) async {
    await tester.pumpThemedWidget(
      Builder(
        builder: (context) => Column(
          children: [
            TextButton(
              onPressed: () => showAppBottomSheet<void>(
                context: context,
                title: 'Mission details',
                child: const AppBottomSheetCloseButton(),
              ),
              child: const Text('Open sheet'),
            ),
            TextButton(
              onPressed: () => showAppConfirmationDialog(
                context: context,
                title: 'Discard draft?',
                message: 'Only this draft will be removed.',
              ),
              child: const Text('Open dialog'),
            ),
            TextButton(
              onPressed: () => showAppSnackBar(
                context: context,
                message: 'Progress saved',
                tone: AppMessageTone.success,
              ),
              child: const Text('Show message'),
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
    expect(find.text('Mission details'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    expect(find.text('Discard draft?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Show message'));
    await tester.pump();
    expect(find.text('Progress saved'), findsOneWidget);
  });
}
