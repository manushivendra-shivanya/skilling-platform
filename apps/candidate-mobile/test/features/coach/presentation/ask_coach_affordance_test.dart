import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:candidate_mobile/features/coach/data/secure_coach_thread_repository.dart';
import 'package:candidate_mobile/features/coach/domain/coach_message.dart';
import 'package:candidate_mobile/features/coach/domain/coach_repository.dart';
import 'package:candidate_mobile/features/coach/presentation/ask_coach_affordance.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'opening, asking, and continuing to Coach carries the context and the '
    "conversation forward -- and the mic control degrades honestly, and "
    'sending triggers a light haptic',
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

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Stack(
                children: [
                  const Center(child: Text('Storing dairy crates')),
                  const Positioned(
                    right: 16,
                    bottom: 16,
                    child: AskCoachAffordance(
                      contextLabel: 'Storing dairy crates in cold storage',
                      contextRef: 'micro_lesson:clip_putaway_dairy_002',
                    ),
                  ),
                ],
              ),
            ),
          ),
          GoRoute(
            path: '/coach/:threadId',
            builder: (context, state) => Scaffold(
              body: Text('THREAD ${state.pathParameters['threadId']}'),
            ),
          ),
        ],
      );

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
            coachRepositoryProvider.overrideWithValue(_FakeCoachRepository()),
            coachThreadRepositoryProvider.overrideWithValue(
              SecureCoachThreadRepository(InMemorySecureKeyValueStore()),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ask'));
      await tester.pumpAndSettle();

      expect(
        find.text('Asking about: Storing dairy crates in cold storage'),
        findsOneWidget,
      );

      // The mic control never claims to work -- honest degradation, same
      // as the standalone Coach screens used to show before the redesign.
      await tester.tap(find.byTooltip('Voice input unavailable'));
      await tester.pump();
      expect(find.textContaining('No microphone permission'), findsOneWidget);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'What if the reading does not match?',
      );
      expect(hapticCalls, isEmpty);
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();

      expect(
        hapticCalls,
        isNotEmpty,
        reason: 'HapticFeedback.lightImpact() should fire on send',
      );
      expect(find.text('Fake reply'), findsOneWidget);
      expect(find.text('Continue in Coach'), findsOneWidget);

      await tester.tap(find.text('Continue in Coach'));
      await tester.pumpAndSettle();

      expect(find.textContaining('THREAD thread-'), findsOneWidget);
    },
  );
}

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
