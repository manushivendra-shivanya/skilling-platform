import 'package:candidate_mobile/features/coach/domain/coach_message.dart';
import 'package:candidate_mobile/features/coach/domain/coach_thread.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CoachThread JSON', () {
    test('round-trips through toJson/fromJson, including its messages', () {
      final thread = CoachThread(
        id: 'thread-1',
        topicLabel: 'How do I prepare for an interview?',
        messages: const [
          CoachMessage(
            id: 'candidate-1',
            author: CoachMessageAuthor.candidate,
            text: 'How do I prepare for an interview?',
          ),
          CoachMessage(
            id: 'coach-1',
            author: CoachMessageAuthor.coach,
            text: 'Practice out loud once before the interview.',
          ),
        ],
        lastActivityAt: DateTime.utc(2026, 8, 12, 9, 41),
        contextRef: 'micro_lesson:clip_putaway_dairy_002',
      );

      final restored = CoachThread.fromJson(thread.toJson());

      expect(restored.id, thread.id);
      expect(restored.topicLabel, thread.topicLabel);
      expect(restored.messages, hasLength(2));
      expect(restored.messages[0].author, CoachMessageAuthor.candidate);
      expect(restored.messages[1].text, thread.messages[1].text);
      expect(restored.lastActivityAt, thread.lastActivityAt);
      expect(restored.contextRef, thread.contextRef);
    });

    test('round-trips a null contextRef', () {
      final thread = CoachThread(
        id: 'thread-1',
        topicLabel: 'A question',
        messages: const [],
        lastActivityAt: DateTime.utc(2026, 8, 12),
      );

      final restored = CoachThread.fromJson(thread.toJson());

      expect(restored.contextRef, isNull);
    });
  });

  group('deriveTopicLabel', () {
    test('leaves a short message unchanged', () {
      expect(deriveTopicLabel('What does FIFO mean?'), 'What does FIFO mean?');
    });

    test('trims surrounding whitespace', () {
      expect(deriveTopicLabel('  Hello  '), 'Hello');
    });

    test('truncates a long message to 60 characters plus an ellipsis', () {
      final long =
          'How should I answer the interview question about my '
          'biggest weakness when I am nervous about it?';
      final label = deriveTopicLabel(long);

      expect(label.endsWith('…'), isTrue);
      // 60 characters of content, plus the ellipsis character.
      expect(label.length, lessThanOrEqualTo(61));
      expect(long.startsWith(label.substring(0, label.length - 1)), isTrue);
    });
  });
}
