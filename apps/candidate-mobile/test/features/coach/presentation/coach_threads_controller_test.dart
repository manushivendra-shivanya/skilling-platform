import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/core/errors/app_failure.dart';
import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:candidate_mobile/features/coach/data/secure_coach_thread_repository.dart';
import 'package:candidate_mobile/features/coach/domain/coach_message.dart';
import 'package:candidate_mobile/features/coach/domain/coach_repository.dart';
import 'package:candidate_mobile/features/coach/domain/coach_thread_repository.dart';
import 'package:candidate_mobile/features/coach/presentation/coach_threads_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startThread creates a thread, sends the opening message, and '
      'persists it', () async {
    final coach = _FakeCoachRepository();
    final threadStore = SecureCoachThreadRepository(
      InMemorySecureKeyValueStore(),
    );
    final container = _buildContainer(
      coachRepository: coach,
      coachThreadRepository: threadStore,
    );
    addTearDown(container.dispose);
    await container.read(coachThreadsControllerProvider.future);

    final threadId = await container
        .read(coachThreadsControllerProvider.notifier)
        .startThread(openingMessage: 'How do I prepare for an interview?');

    expect(threadId, isNotNull);
    final state = container.read(coachThreadsControllerProvider).requireValue;
    final thread = state.threadById(threadId!);
    expect(thread, isNotNull);
    expect(thread!.topicLabel, 'How do I prepare for an interview?');
    expect(thread.messages, hasLength(2));
    expect(thread.messages[0].author, CoachMessageAuthor.candidate);
    expect(thread.messages[1].author, CoachMessageAuthor.coach);
    expect(thread.messages[1].text, 'Fake reply');
    expect(state.sendingThreadIds, isEmpty);

    // Persisted -- a fresh read from the same store sees it too.
    final persisted = await threadStore.listThreads('candidate-1');
    persisted.when(
      success: (threads) => expect(threads.map((t) => t.id), [threadId]),
      failure: (failure) => fail('expected success, got $failure'),
    );
  });

  test(
    'sendMessage appends to an existing thread using its prior history',
    () async {
      final coach = _FakeCoachRepository();
      final container = _buildContainer(coachRepository: coach);
      addTearDown(container.dispose);
      await container.read(coachThreadsControllerProvider.future);
      final notifier = container.read(coachThreadsControllerProvider.notifier);

      final threadId = await notifier.startThread(
        openingMessage: 'First question',
      );
      await notifier.sendMessage(threadId!, 'Second question');

      final thread = container
          .read(coachThreadsControllerProvider)
          .requireValue
          .threadById(threadId)!;
      expect(thread.messages, hasLength(4));
      expect(thread.messages[2].text, 'Second question');
      // The second call's history included everything before it.
      expect(coach.historiesSeen[1], hasLength(2));
    },
  );

  test(
    'a provider failure lands as a coach-authored message, not a crash',
    () async {
      final coach = _FakeCoachRepository()
        ..nextResult = const ResultFailure(
          NetworkFailure('Could not reach the AI coach.'),
        );
      final container = _buildContainer(coachRepository: coach);
      addTearDown(container.dispose);
      await container.read(coachThreadsControllerProvider.future);

      final threadId = await container
          .read(coachThreadsControllerProvider.notifier)
          .startThread(openingMessage: 'Hello?');

      final thread = container
          .read(coachThreadsControllerProvider)
          .requireValue
          .threadById(threadId!)!;
      expect(thread.messages.last.author, CoachMessageAuthor.coach);
      expect(thread.messages.last.text, 'Could not reach the AI coach.');
    },
  );

  test(
    'an empty message does not start a thread or call the repository',
    () async {
      final coach = _FakeCoachRepository();
      final container = _buildContainer(coachRepository: coach);
      addTearDown(container.dispose);
      await container.read(coachThreadsControllerProvider.future);

      final threadId = await container
          .read(coachThreadsControllerProvider.notifier)
          .startThread(openingMessage: '   ');

      expect(threadId, isNull);
      expect(coach.historiesSeen, isEmpty);
      expect(
        container.read(coachThreadsControllerProvider).requireValue.threads,
        isEmpty,
      );
    },
  );
}

class _FakeCoachRepository implements CoachRepository {
  final List<List<CoachMessage>> historiesSeen = [];
  Result<CoachReply> nextResult = const Success(
    CoachReply(text: 'Fake reply', modelId: 'fake-model', provider: 'fake'),
  );

  @override
  bool get isLiveData => true;

  @override
  Future<Result<CoachReply>> sendMessage({
    required String message,
    required List<CoachMessage> history,
  }) async {
    historiesSeen.add(history);
    return nextResult;
  }
}

ProviderContainer _buildContainer({
  required CoachRepository coachRepository,
  CoachThreadRepository? coachThreadRepository,
}) => ProviderContainer(
  overrides: [
    candidateSessionRepositoryProvider.overrideWithValue(
      InMemoryCandidateSessionRepository(
        session: const CandidateSession(
          candidateId: 'candidate-1',
          isAuthenticated: true,
        ),
      ),
    ),
    coachRepositoryProvider.overrideWithValue(coachRepository),
    coachThreadRepositoryProvider.overrideWithValue(
      coachThreadRepository ??
          SecureCoachThreadRepository(InMemorySecureKeyValueStore()),
    ),
  ],
);
