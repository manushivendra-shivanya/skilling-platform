import 'package:candidate_mobile/features/navigation/presentation/widgets/coach_attention_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A separate file (its own isolate under `flutter test`) rather than a
// second `testWidgets` in `coach_attention_popup_test.dart`: this needs to
// be the very first mount of the widget in its process, before the
// session-wide "already shown" static trips, so it actually exercises the
// entrance-delay `Timer` this test is regression-covering.
void main() {
  testWidgets(
    'disposing mid-entrance-delay cancels its pending timer cleanly',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CoachAttentionPopup(
              onTap: () {},
              child: const FloatingActionButton(
                onPressed: null,
                child: Icon(Icons.forum_outlined),
              ),
            ),
          ),
        ),
      );

      // Well short of the 700ms entrance delay -- the popup's Timer is
      // still armed at this point.
      await tester.pump(const Duration(milliseconds: 100));

      // Unmount before that Timer fires. Before the fix, this Timer was a
      // bare `Future.delayed` that `dispose()` had no handle to cancel, so
      // `flutter_test`'s end-of-test `!timersPending` check failed here --
      // this test's only assertion is that the run completes without that
      // assertion firing.
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
