import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../core/analytics/analytics_event.dart';
import '../domain/coach_message.dart';

final coachControllerProvider =
    NotifierProvider<CoachController, List<CoachMessage>>(CoachController.new);

class CoachController extends Notifier<List<CoachMessage>> {
  int _sequence = 0;

  @override
  List<CoachMessage> build() => const [
    CoachMessage(
      id: 'welcome',
      author: CoachMessageAuthor.coach,
      text:
          'Namaste! I am a local demo coach. Ask me how to prepare for a logistics role.',
    ),
  ];

  void send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _sequence += 1;
    state = [
      ...state,
      CoachMessage(
        id: 'candidate-$_sequence',
        author: CoachMessageAuthor.candidate,
        text: trimmed,
      ),
      CoachMessage(
        id: 'coach-$_sequence',
        author: CoachMessageAuthor.coach,
        text:
            'Demo guidance: break the task into steps, confirm safety and accuracy, then explain when you would escalate to a supervisor.',
      ),
    ];
    unawaited(
      ref
          .read(analyticsTrackerProvider)
          .track(AnalyticsEvent.coachMessageSent()),
    );
  }

  void reset() {
    _sequence = 0;
    state = const [
      CoachMessage(
        id: 'welcome',
        author: CoachMessageAuthor.coach,
        text:
            'Namaste! I am a local demo coach. Ask me how to prepare for a logistics role.',
      ),
    ];
  }
}
