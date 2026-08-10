import 'dart:convert';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/storage/secure_key_value_store.dart';
import '../domain/saved_jobs_repository.dart';

class SecureSavedJobsRepository implements SavedJobsRepository {
  SecureSavedJobsRepository(this._store);

  static const _keyPrefix = 'jobs.saved_ids.v1.';

  final SecureKeyValueStore _store;

  @override
  Future<Result<Set<String>>> readSavedJobIds(String candidateId) async {
    try {
      return Success(await _readAll(candidateId));
    } catch (error, stackTrace) {
      return ResultFailure(
        StorageFailure(
          'Your saved jobs could not be loaded.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> setSaved(
    String candidateId,
    String jobId, {
    required bool saved,
  }) async {
    try {
      final current = await _readAll(candidateId);
      final next = saved
          ? {...current, jobId}
          : (current.toSet()..remove(jobId));
      await _store.write(_keyFor(candidateId), jsonEncode(next.toList()));
      return const Success(null);
    } catch (error, stackTrace) {
      return ResultFailure(
        StorageFailure(
          'This job could not be saved on this device.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<Set<String>> _readAll(String candidateId) async {
    final encoded = await _store.read(_keyFor(candidateId));
    if (encoded == null) return const {};
    final decoded = jsonDecode(encoded);
    if (decoded is! List) {
      throw const FormatException('Invalid saved-jobs list');
    }
    return decoded.whereType<String>().toSet();
  }

  String _keyFor(String candidateId) {
    final safeCandidateId = candidateId.replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '_',
    );
    return '$_keyPrefix$safeCandidateId';
  }
}
