import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:candidate_mobile/features/coach/data/secure_coach_thread_repository.dart';
import 'package:candidate_mobile/features/coach/domain/coach_message.dart';
import 'package:candidate_mobile/features/coach/domain/coach_repository.dart';
import 'package:candidate_mobile/features/coach/domain/coach_thread.dart';
import 'package:candidate_mobile/features/coach/presentation/coach_thread_screen.dart';
import 'package:candidate_mobile/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCoachRepository implements CoachRepository {
  @override
  bool get isLiveData => true;

  @override
  Future<Result<CoachReply>> sendMessage({
    required String message,
    required List<CoachMessage> history,
  }) async {
    return const Success(
      CoachReply(text: 'Fake reply', modelId: 'fake-model', provider: 'fake'),
    );
  }
}

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
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const CoachThreadScreen(threadId: 'thread-1'),
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

  testWidgets(
    'sending a message triggers a light haptic and the reply fades/slides '
    'in rather than appearing instantly',
    (tester) async {
      final threadRepository = SecureCoachThreadRepository(
        InMemorySecureKeyValueStore(),
      );
      final thread = CoachThread(
        id: 'thread-1',
        topicLabel: 'Practice interview answers',
        messages: const [],
        lastActivityAt: DateTime.utc(2026, 8, 12),
      );
      await threadRepository.saveThread('candidate-1', thread);

      // Intercepts the platform channel HapticFeedback.lightImpact()
      // ultimately calls (HapticFeedback methods all funnel through
      // SystemChannels.platform's 'HapticFeedback.vibrate' method) --
      // there's no public Flutter API to assert "a haptic fired" other
      // than watching for this platform call.
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
            coachRepositoryProvider.overrideWithValue(_FakeCoachRepository()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const CoachThreadScreen(threadId: 'thread-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(hapticCalls, isEmpty);

      await tester.enterText(find.byType(TextField), 'How am I doing?');
      await tester.tap(find.byTooltip('Send message'));
      await tester.pump();

      expect(
        hapticCalls,
        isNotEmpty,
        reason: 'HapticFeedback.lightImpact() should fire on send',
      );

      // The just-sent bubble is mid entrance animation, not fully opaque
      // yet -- the whole point of _MessageEntrance is that it doesn't
      // appear instantly.
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.text('How am I doing?'),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(
        fade.opacity.value,
        lessThan(1.0),
        reason: 'message bubble should still be fading in on the first pump',
      );

      await tester.pumpAndSettle();
      final settledFade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.text('How am I doing?'),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(settledFade.opacity.value, 1.0);
      // Not find.text('Fake reply'): coach replies now reveal word-by-word
      // via _InkRevealText (each word is its own Text widget), so the full
      // sentence never exists as a single Text.data string. The complete
      // sentence is still exposed as one Semantics label for screen
      // readers -- see _InkRevealText's doc comment.
      expect(find.bySemanticsLabel('Fake reply'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the message entrance animation is skipped when the OS reduces motion',
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
            text: 'Already here before reduce-motion was checked',
          ),
        ],
        lastActivityAt: DateTime.utc(2026, 8, 12),
      );
      await threadRepository.saveThread('candidate-1', thread);

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
          child: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const CoachThreadScreen(threadId: 'thread-1'),
            ),
          ),
        ),
      );
      // A single pump, not pumpAndSettle -- if the animation weren't
      // skipped this would still be mid-fade on the very first frame.
      await tester.pump();

      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.text('Already here before reduce-motion was checked'),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, 1.0);
      expect(tester.takeException(), isNull);
    },
  );
}
