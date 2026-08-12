import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:candidate_mobile/features/coach/data/secure_coach_thread_repository.dart';
import 'package:candidate_mobile/features/coach/domain/coach_message.dart';
import 'package:candidate_mobile/features/coach/domain/coach_thread.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const candidateId = 'candidate-1';

  CoachThread thread({required String id, DateTime? at}) => CoachThread(
    id: id,
    topicLabel: 'Topic $id',
    messages: const [],
    lastActivityAt: at ?? DateTime.utc(2026, 8, 12),
  );

  test('listThreads returns nothing before anything has been saved', () async {
    final repository = SecureCoachThreadRepository(
      InMemorySecureKeyValueStore(),
    );

    final result = await repository.listThreads(candidateId);

    result.when(
      success: (threads) => expect(threads, isEmpty),
      failure: (failure) => fail('expected success, got $failure'),
    );
  });

  test(
    'saveThread persists a new thread, then listThreads returns it',
    () async {
      final repository = SecureCoachThreadRepository(
        InMemorySecureKeyValueStore(),
      );

      await repository.saveThread(candidateId, thread(id: 'thread-1'));
      final result = await repository.listThreads(candidateId);

      result.when(
        success: (threads) {
          expect(threads, hasLength(1));
          expect(threads.single.id, 'thread-1');
        },
        failure: (failure) => fail('expected success, got $failure'),
      );
    },
  );

  test('saveThread upserts by id rather than duplicating', () async {
    final repository = SecureCoachThreadRepository(
      InMemorySecureKeyValueStore(),
    );

    await repository.saveThread(candidateId, thread(id: 'thread-1'));
    await repository.saveThread(
      candidateId,
      CoachThread(
        id: 'thread-1',
        topicLabel: 'Updated topic',
        messages: const [
          CoachMessage(
            id: 'm1',
            author: CoachMessageAuthor.candidate,
            text: 'Hello',
          ),
        ],
        lastActivityAt: DateTime.utc(2026, 8, 12, 10),
      ),
    );

    final result = await repository.listThreads(candidateId);

    result.when(
      success: (threads) {
        expect(threads, hasLength(1));
        expect(threads.single.topicLabel, 'Updated topic');
        expect(threads.single.messages, hasLength(1));
      },
      failure: (failure) => fail('expected success, got $failure'),
    );
  });

  test('threads are scoped independently per candidate', () async {
    final repository = SecureCoachThreadRepository(
      InMemorySecureKeyValueStore(),
    );

    await repository.saveThread('candidate-a', thread(id: 'thread-a'));
    await repository.saveThread('candidate-b', thread(id: 'thread-b'));

    final resultA = await repository.listThreads('candidate-a');
    final resultB = await repository.listThreads('candidate-b');

    resultA.when(
      success: (threads) => expect(threads.map((t) => t.id), ['thread-a']),
      failure: (failure) => fail('expected success, got $failure'),
    );
    resultB.when(
      success: (threads) => expect(threads.map((t) => t.id), ['thread-b']),
      failure: (failure) => fail('expected success, got $failure'),
    );
  });
}
