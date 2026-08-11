import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:candidate_mobile/features/micro_lessons/data/secure_viewed_clips_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SecureViewedClipsRepository repository;

  setUp(() {
    repository = SecureViewedClipsRepository(InMemorySecureKeyValueStore());
  });

  test('a candidate with nothing watched yet reads an empty set', () async {
    final result = await repository.readViewedClipIds('candidate-1');

    expect(result, isA<Success<Set<String>>>());
    expect((result as Success<Set<String>>).value, isEmpty);
  });

  test(
    'marking a clip viewed persists it, and it survives across reads',
    () async {
      await repository.markViewed('candidate-1', 'clip-1');

      final result = await repository.readViewedClipIds('candidate-1');

      expect((result as Success<Set<String>>).value, {'clip-1'});
    },
  );

  test('marking an already-viewed clip is a no-op, not a duplicate', () async {
    await repository.markViewed('candidate-1', 'clip-1');
    await repository.markViewed('candidate-1', 'clip-1');

    final result = await repository.readViewedClipIds('candidate-1');
    expect((result as Success<Set<String>>).value, {'clip-1'});
  });

  test(
    'watching a second clip adds to the set rather than replacing it',
    () async {
      await repository.markViewed('candidate-1', 'clip-1');
      await repository.markViewed('candidate-1', 'clip-2');

      final result = await repository.readViewedClipIds('candidate-1');
      expect((result as Success<Set<String>>).value, {'clip-1', 'clip-2'});
    },
  );

  test('viewed clips are scoped per candidate', () async {
    await repository.markViewed('candidate-1', 'clip-1');

    final other = await repository.readViewedClipIds('candidate-2');

    expect((other as Success<Set<String>>).value, isEmpty);
  });
}
