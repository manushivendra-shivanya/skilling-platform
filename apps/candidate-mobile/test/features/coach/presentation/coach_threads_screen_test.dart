import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:candidate_mobile/features/coach/data/secure_coach_thread_repository.dart';
import 'package:candidate_mobile/features/coach/presentation/coach_threads_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'the new-thread composer does not overflow when the on-screen keyboard '
    'opens (same double-counted keyboard inset bug as '
    'coach_thread_screen_test.dart -- this screen has its own copy of the '
    'same composer Padding)',
    (tester) async {
      // A realistic portrait-phone viewport, same reasoning as
      // coach_thread_screen_test.dart.
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      tester.view.padding = const FakeViewPadding(top: 72, bottom: 72);

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
            coachThreadRepositoryProvider.overrideWithValue(
              SecureCoachThreadRepository(InMemorySecureKeyValueStore()),
            ),
          ],
          child: MaterialApp(home: CoachThreadsScreen(onOpenThread: (_) {})),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      addTearDown(tester.view.resetViewInsets);
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
    },
  );
}
