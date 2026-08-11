import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../core/analytics/analytics_event.dart';
import '../domain/coach_message.dart';

const _welcomeMessage = CoachMessage(
  id: 'welcome',
  author: CoachMessageAuthor.coach,
  text:
      'Namaste! I am your AI career coach. Ask me how to prepare for a '
      'logistics role.',
);

class CoachState {
  const CoachState({required this.messages, required this.isSending});

  final List<CoachMessage> messages;

  /// True while a `send()` call is awaiting the coach's reply -- drives
  /// the typing indicator and disables the composer's send button so a
  /// candidate can't fire a second request before the first resolves.
  final bool isSending;

  CoachState copyWith({List<CoachMessage>? messages, bool? isSending}) {
    return CoachState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
    );
  }
}

final coachControllerProvider = NotifierProvider<CoachController, CoachState>(
  CoachController.new,
);

class CoachController extends Notifier<CoachState> {
  int _sequence = 0;

  @override
  CoachState build() =>
      const CoachState(messages: [_welcomeMessage], isSending: false);

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isSending) {
      return;
    }
    _sequence += 1;
    final historyBeforeThisMessage = state.messages;
    final candidateMessage = CoachMessage(
      id: 'candidate-$_sequence',
      author: CoachMessageAuthor.candidate,
      text: trimmed,
    );
    state = state.copyWith(
      messages: [...state.messages, candidateMessage],
      isSending: true,
    );
    unawaited(
      ref
          .read(analyticsTrackerProvider)
          .track(AnalyticsEvent.coachMessageSent()),
    );

    final result = await ref
        .read(coachRepositoryProvider)
        .sendMessage(message: trimmed, history: historyBeforeThisMessage);

    result.when(
      success: (reply) {
        state = state.copyWith(
          messages: [
            ...state.messages,
            CoachMessage(
              id: 'coach-$_sequence',
              author: CoachMessageAuthor.coach,
              text: reply.text,
            ),
          ],
          isSending: false,
        );
      },
      failure: (failure) {
        unawaited(
          ref
              .read(analyticsTrackerProvider)
              .track(AnalyticsEvent.coachReplyFailed()),
        );
        state = state.copyWith(
          messages: [
            ...state.messages,
            CoachMessage(
              id: 'coach-error-$_sequence',
              author: CoachMessageAuthor.coach,
              text: failure.message,
            ),
          ],
          isSending: false,
        );
      },
    );
  }

  void reset() {
    _sequence = 0;
    state = const CoachState(messages: [_welcomeMessage], isSending: false);
  }
}
