import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:candidate_mobile/features/jobs/data/secure_saved_jobs_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SecureSavedJobsRepository repository;

  setUp(() {
    repository = SecureSavedJobsRepository(InMemorySecureKeyValueStore());
  });

  test('a candidate with nothing saved yet reads an empty set', () async {
    final result = await repository.readSavedJobIds('candidate-1');

    expect(result, isA<Success<Set<String>>>());
    expect((result as Success<Set<String>>).value, isEmpty);
  });

  test('saving a job adds it, and it persists across reads', () async {
    await repository.setSaved('candidate-1', 'job-1', saved: true);

    final result = await repository.readSavedJobIds('candidate-1');

    expect((result as Success<Set<String>>).value, {'job-1'});
  });

  test('un-saving a job removes only that job', () async {
    await repository.setSaved('candidate-1', 'job-1', saved: true);
    await repository.setSaved('candidate-1', 'job-2', saved: true);

    await repository.setSaved('candidate-1', 'job-1', saved: false);

    final result = await repository.readSavedJobIds('candidate-1');
    expect((result as Success<Set<String>>).value, {'job-2'});
  });

  test('saved jobs are scoped per candidate', () async {
    await repository.setSaved('candidate-1', 'job-1', saved: true);

    final other = await repository.readSavedJobIds('candidate-2');

    expect((other as Success<Set<String>>).value, isEmpty);
  });
}
