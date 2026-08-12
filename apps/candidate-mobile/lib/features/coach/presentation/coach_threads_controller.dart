import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../core/analytics/analytics_event.dart';
import '../domain/coach_message.dart';
import '../domain/coach_thread.dart';

class CoachThreadsState {
  const CoachThreadsState({
    required this.threads,
    this.sendingThreadIds = const {},
  });

  final List<CoachThread> threads;

  /// Threads currently awaiting a reply -- drives the typing indicator and
  /// composer-disabled state per thread, independent of every other
  /// thread (unlike the old single-conversation `CoachState.isSending`).
  final Set<String> sendingThreadIds;

  CoachThread? threadById(String id) {
    for (final thread in threads) {
      if (thread.id == id) return thread;
    }
    return null;
  }

  CoachThreadsState copyWith({
    List<CoachThread>? threads,
    Set<String>? sendingThreadIds,
  }) {
    return CoachThreadsState(
      threads: threads ?? this.threads,
      sendingThreadIds: sendingThreadIds ?? this.sendingThreadIds,
    );
  }
}

final coachThreadsControllerProvider =
    AsyncNotifierProvider<CoachThreadsController, CoachThreadsState>(
      CoachThreadsController.new,
    );

/// Replaces the old single-conversation `CoachController` with "Topic
/// threads" (design option B in docs/27-ai-coach-plan.md): a list of
/// focused conversations instead of one endless scroll, matching how this
/// coach is actually used -- short, specific questions, revisited later.
///
/// The network side is unchanged: `CoachRepository.sendMessage` is still a
/// single stateless call per message, given the full history explicitly.
/// A thread's own `messages` list *is* that history -- threading is a
/// client-side bookkeeping concept the stateless backend never sees.
class CoachThreadsController extends AsyncNotifier<CoachThreadsState> {
  String? _candidateId;

  @override
  Future<CoachThreadsState> build() async {
    final sessionResult = await ref
        .read(candidateSessionRepositoryProvider)
        .readSession();
    final session = sessionResult.when(
      success: (value) => value,
      failure: (_) => null,
    );
    if (session == null || !session.isAuthenticated) {
      _candidateId = null;
      return const CoachThreadsState(threads: []);
    }
    _candidateId = session.candidateId;

    final result = await ref
        .read(coachThreadRepositoryProvider)
        .listThreads(session.candidateId);
    final threads = result.when(
      success: (value) => value,
      // A local-storage read failure degrades to "no history yet" rather
      // than blocking the whole screen -- starting a fresh thread still
      // works even if past ones couldn't be read back.
      failure: (_) => const <CoachThread>[],
    );
    final sorted = [...threads]
      ..sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));
    return CoachThreadsState(threads: sorted);
  }

  /// Starts a new thread from an opening message, sends it immediately,
  /// and returns the new thread's id (or null if there's no signed-in
  /// candidate or the message was empty). [contextRef] records where the
  /// thread started (e.g. a micro-lesson clip id) for future use -- see
  /// `CoachThread.contextRef`.
  Future<String?> startThread({
    required String openingMessage,
    String? contextRef,
  }) async {
    final trimmed = openingMessage.trim();
    if (trimmed.isEmpty) return null;
    // Waits for `build()` to resolve rather than checking `state.valueOrNull`
    // and bailing -- this can legitimately be the very first thing that
    // reads this provider (the contextual "Ask" affordance never watches
    // it until a thread exists), so `build()`'s two on-device reads may
    // still be in flight the instant a candidate finishes typing and hits
    // send. Bailing there would silently drop their message.
    final current = await future;
    final candidateId = _candidateId;
    if (candidateId == null) return null;

    final threadId =
        'thread-${DateTime.now().microsecondsSinceEpoch}-${current.threads.length}';
    final thread = CoachThread(
      id: threadId,
      topicLabel: deriveTopicLabel(trimmed),
      messages: const [],
      lastActivityAt: DateTime.now(),
      contextRef: contextRef,
    );
    state = AsyncData(current.copyWith(threads: [thread, ...current.threads]));
    await _sendWithinThread(candidateId, threadId, trimmed);
    return threadId;
  }

  Future<void> sendMessage(String threadId, String text) async {
    await future;
    final candidateId = _candidateId;
    if (candidateId == null) return;
    await _sendWithinThread(candidateId, threadId, text);
  }

  Future<void> _sendWithinThread(
    String candidateId,
    String threadId,
    String text,
  ) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final current = state.valueOrNull;
    final thread = current?.threadById(threadId);
    if (current == null || thread == null) return;
    if (current.sendingThreadIds.contains(threadId)) return;

    final historyBeforeThisMessage = thread.messages;
    final candidateMessage = CoachMessage(
      id: 'candidate-${DateTime.now().microsecondsSinceEpoch}',
      author: CoachMessageAuthor.candidate,
      text: trimmed,
    );
    var updatedThread = thread.copyWith(
      messages: [...thread.messages, candidateMessage],
      lastActivityAt: DateTime.now(),
    );
    state = AsyncData(
      _replaceThread(
        current,
        updatedThread,
      ).copyWith(sendingThreadIds: {...current.sendingThreadIds, threadId}),
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
        updatedThread = updatedThread.copyWith(
          messages: [
            ...updatedThread.messages,
            CoachMessage(
              id: 'coach-${DateTime.now().microsecondsSinceEpoch}',
              author: CoachMessageAuthor.coach,
              text: reply.text,
            ),
          ],
          lastActivityAt: DateTime.now(),
        );
      },
      failure: (failure) {
        unawaited(
          ref
              .read(analyticsTrackerProvider)
              .track(AnalyticsEvent.coachReplyFailed()),
        );
        updatedThread = updatedThread.copyWith(
          messages: [
            ...updatedThread.messages,
            CoachMessage(
              id: 'coach-error-${DateTime.now().microsecondsSinceEpoch}',
              author: CoachMessageAuthor.coach,
              text: failure.message,
            ),
          ],
          lastActivityAt: DateTime.now(),
        );
      },
    );

    final latest = state.valueOrNull;
    if (latest == null) return;
    final nextSending = {...latest.sendingThreadIds}..remove(threadId);
    state = AsyncData(
      _replaceThread(
        latest,
        updatedThread,
      ).copyWith(sendingThreadIds: nextSending),
    );
    // Awaited, not fire-and-forget: this is on-device storage (fast, no
    // network round trip), and awaiting it means the conversation the
    // candidate just saw is actually saved before this call returns --
    // not merely "probably saved before the app happens to be killed".
    // A failure here loses this conversation's future browsability, not
    // the reply the candidate already sees, so it's swallowed rather than
    // surfaced as an error state.
    await ref
        .read(coachThreadRepositoryProvider)
        .saveThread(candidateId, updatedThread);
  }

  CoachThreadsState _replaceThread(
    CoachThreadsState current,
    CoachThread updated,
  ) {
    return current.copyWith(
      threads: [
        for (final existing in current.threads)
          if (existing.id == updated.id) updated else existing,
      ],
    );
  }
}
