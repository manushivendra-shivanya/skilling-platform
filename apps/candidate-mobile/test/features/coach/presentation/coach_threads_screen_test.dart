import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:candidate_mobile/features/coach/data/secure_coach_thread_repository.dart';
import 'package:candidate_mobile/features/coach/domain/coach_message.dart';
import 'package:candidate_mobile/features/coach/domain/coach_repository.dart';
import 'package:candidate_mobile/features/coach/presentation/coach_threads_screen.dart';
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
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CoachThreadsScreen(onOpenThread: (_) {}),
          ),
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

  testWidgets(
    'starting a new thread from the composer triggers a light haptic',
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
            coachRepositoryProvider.overrideWithValue(_FakeCoachRepository()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CoachThreadsScreen(onOpenThread: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(hapticCalls, isEmpty);

      await tester.enterText(find.byType(TextField), 'How should I prepare?');
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();

      expect(
        hapticCalls,
        isNotEmpty,
        reason: 'HapticFeedback.lightImpact() should fire on send',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
