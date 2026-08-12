import 'coach_message.dart';

/// One focused conversation with the coach -- "Topic threads" (design
/// option B in docs/27-ai-coach-plan.md), chosen over one endless scroll
/// because that's how this coach is actually asked things: short,
/// specific questions revisited later ("what did coach say about
/// interviews?"), not one marathon chat.
///
/// Kept entirely on-device (see [CoachThreadRepository]) -- this is local
/// app state for browsing past conversations, not the "coach data at
/// rest on the server" the ephemeral-history decision in docs/27 rules
/// out. The backend still sees only a stateless message + history on
/// every call; a thread's [messages] list *is* that history.
class CoachThread {
  const CoachThread({
    required this.id,
    required this.topicLabel,
    required this.messages,
    required this.lastActivityAt,
    this.contextRef,
  });

  final String id;

  /// Shown in the thread list. Starts as a truncation of the candidate's
  /// first message and never changes after that -- see
  /// `CoachThreadsController.startThread`.
  final String topicLabel;

  final List<CoachMessage> messages;
  final DateTime lastActivityAt;

  /// Set when a thread starts from the contextual "Ask" affordance on
  /// another screen (e.g. `micro_lesson:clip_putaway_dairy_002`) --
  /// carried for future use (a "reopen where you were" jump), not read by
  /// anything today. Never sent to the backend; it's a client-side
  /// bookkeeping value, not part of the coach's own system-prompt context
  /// (see docs/27's system-prompt-scope decision).
  final String? contextRef;

  CoachThread copyWith({
    String? topicLabel,
    List<CoachMessage>? messages,
    DateTime? lastActivityAt,
  }) {
    return CoachThread(
      id: id,
      topicLabel: topicLabel ?? this.topicLabel,
      messages: messages ?? this.messages,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      contextRef: contextRef,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'topicLabel': topicLabel,
    'messages': messages.map((message) => message.toJson()).toList(),
    'lastActivityAt': lastActivityAt.toUtc().toIso8601String(),
    'contextRef': contextRef,
  };

  factory CoachThread.fromJson(Map<String, Object?> json) {
    return CoachThread(
      id: json['id']! as String,
      topicLabel: json['topicLabel']! as String,
      messages: (json['messages'] as List<Object?>)
          .map((item) => CoachMessage.fromJson(item as Map<String, Object?>))
          .toList(),
      lastActivityAt: DateTime.parse(json['lastActivityAt']! as String),
      contextRef: json['contextRef'] as String?,
    );
  }
}

/// Derives a thread's [CoachThread.topicLabel] from a candidate's opening
/// message -- trimmed to a short, list-friendly length. Shared by the
/// controller (real threads) and tests.
String deriveTopicLabel(String openingMessage) {
  final trimmed = openingMessage.trim();
  const maxLength = 60;
  if (trimmed.length <= maxLength) return trimmed;
  return '${trimmed.substring(0, maxLength).trimRight()}…';
}
