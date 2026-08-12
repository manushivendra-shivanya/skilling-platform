import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:candidate_mobile/features/coach/data/secure_coach_thread_repository.dart';
import 'package:candidate_mobile/features/coach/domain/coach_message.dart';
import 'package:candidate_mobile/features/coach/domain/coach_thread.dart';
import 'package:candidate_mobile/features/coach/presentation/coach_thread_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'the composer does not overflow when the on-screen keyboard opens '
    '(real-device report: "RenderFlex overflowed" banner over the send '
    'button once the message field gained focus)',
    (tester) async {
      final threadRepository = SecureCoachThreadRepository(
        InMemorySecureKeyValueStore(),
      );
      final thread = CoachThread(
        id: 'thread-1',
        topicLabel: 'Practice interview answers',
        messages: const [
          CoachMessage(
            id: 'candidate-1',
            author: CoachMessageAuthor.candidate,
            text: 'How should I answer a strengths question?',
          ),
          CoachMessage(
            id: 'coach-1',
            author: CoachMessageAuthor.coach,
            text: 'Pick one real example and describe the outcome.',
          ),
        ],
        lastActivityAt: DateTime.utc(2026, 8, 12),
      );
      await threadRepository.saveThread('candidate-1', thread);

      // A realistic portrait-phone viewport -- the default 800x600 test
      // surface is unusually short-and-wide (nothing like a real device in
      // portrait), which leaves the Column far more spare height than it
      // would ever have on-device and can hide a real overflow.
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            candidateSessionRepositoryProvider.overrideWithValue(
              InMemoryCandidateSessionRepository(
                session: const CandidateSession(
                  candidateId: 'candidate-1',
                  isAuthenticated: true,
                ),
              ),
            ),
            coachThreadRepositoryProvider.overrideWithValue(threadRepository),
          ],
          child: const MaterialApp(
            home: CoachThreadScreen(threadId: 'thread-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Practice interview answers'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Simulate the on-screen keyboard opening -- a Scaffold's default
      // resizeToAvoidBottomInset already shrinks the body for this; the
      // regression was the composer's own Padding adding this same inset
      // a second time on top of that. Stepping through the resize
      // animation frame-by-frame (not pumpAndSettle) matters here: the
      // real-device report showed the debug overflow banner mid-animation,
      // and pumpAndSettle would fast-forward straight past any transient
      // single-frame overflow to the final, already-settled state.
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.view.resetPadding);
      // Status bar + gesture/nav bar insets, same as a real device --
      // these eat into the same budget the composer needs.
      tester.view.padding = const FakeViewPadding(top: 72, bottom: 72);
      // 1200 physical / 3x density = 400 logical px -- a realistic-to-
      // generous Android keyboard-plus-predictive-text-strip height.
      tester.view.viewInsets = const FakeViewPadding(bottom: 1200);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          tester.takeException(),
          isNull,
          reason: 'overflow at frame $i of the keyboard-open animation',
        );
      }
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Send message'), findsOneWidget);
      expect(
        tester.getRect(find.byTooltip('Send message')).bottom,
        lessThanOrEqualTo(
          tester.view.physicalSize.height / tester.view.devicePixelRatio,
        ),
      );
    },
  );
}
