import 'package:candidate_mobile/features/navigation/presentation/widgets/coach_attention_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Order matters in this file: `CoachAttentionPopup` shows itself at most
// once per app session via a module-level static (see the widget's own doc
// comment on `_shownThisSession`), and `flutter test` runs every
// `testWidgets` in a single file inside the same isolate -- so the first
// test below is the one that actually gets to exercise the bubble, and the
// second test asserts the suppression that leaves in place for every mount
// after it. Splitting these into separate files would just hide that
// coupling, not remove it.
void main() {
  testWidgets(
    'shows the bubble after the entrance delay, fires a haptic, opens the '
    'coach on tap, and auto-dismisses once not tapped',
    (tester) async {
      final hapticCalls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            hapticCalls.add(call.arguments as String);
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      var shownCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: CoachAttentionPopup(
                onTap: () {},
                onShown: () => shownCount++,
                child: const FloatingActionButton(
                  onPressed: null,
                  child: Icon(Icons.forum_outlined),
                ),
              ),
            ),
          ),
        ),
      );

      // The bubble is built from frame zero (so it can animate smoothly
      // in rather than popping into existence), just scaled/faded to
      // nothing until the entrance delay elapses -- so "not shown yet" is
      // asserted via its opacity, not via the text being absent from the
      // tree.
      FadeTransition fade() => tester.widget<FadeTransition>(
        find.byKey(const Key('coachAttentionPopupBubbleFade')),
      );

      expect(fade().opacity.value, 0);
      expect(hapticCalls, isEmpty);

      // Past the entrance delay (700ms) -- fires the entrance Timer and
      // starts the forward animation -- then `pumpAndSettle` (not a second
      // single `pump`: an `AnimationController`'s ticker only measures
      // elapsed time across multiple ticks, so one lump `pump(duration)`
      // covering both the delay and the animation would fire the Timer but
      // never actually advance the controller) drives its 220ms entrance
      // animation to completion.
      await tester.pump(const Duration(milliseconds: 750));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ask me anything'), findsOneWidget);
      expect(fade().opacity.value, 1);
      expect(
        hapticCalls,
        isNotEmpty,
        reason: 'HapticFeedback.lightImpact() should fire when it appears',
      );
      expect(shownCount, 1);

      // Auto-dismiss: past the 2s visible window, then let the 180ms
      // reverse animation settle.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(fade().opacity.value, 0);
    },
  );

  testWidgets(
    'a later mount in the same session never shows the bubble again',
    (tester) async {
      var shownCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CoachAttentionPopup(
              onTap: () {},
              onShown: () => shownCount++,
              child: const FloatingActionButton(
                onPressed: null,
                child: Icon(Icons.forum_outlined),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 5));

      expect(find.textContaining('Ask me anything'), findsNothing);
      expect(shownCount, 0);
    },
  );
}
