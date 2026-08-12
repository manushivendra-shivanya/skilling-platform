import 'dart:convert';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/storage/secure_key_value_store.dart';
import '../domain/coach_thread.dart';
import '../domain/coach_thread_repository.dart';

class SecureCoachThreadRepository implements CoachThreadRepository {
  SecureCoachThreadRepository(this._store);

  static const _keyPrefix = 'coach.threads.v1.';

  final SecureKeyValueStore _store;

  @override
  Future<Result<List<CoachThread>>> listThreads(String candidateId) async {
    try {
      return Success(await _readAll(candidateId));
    } catch (error, stackTrace) {
      return ResultFailure(
        StorageFailure(
          'Your past coach conversations could not be loaded.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> saveThread(
    String candidateId,
    CoachThread thread,
  ) async {
    try {
      final existing = await _readAll(candidateId);
      final next = [
        for (final other in existing)
          if (other.id != thread.id) other,
        thread,
      ];
      await _store.write(
        _keyFor(candidateId),
        jsonEncode(next.map((t) => t.toJson()).toList()),
      );
      return const Success(null);
    } catch (error, stackTrace) {
      return ResultFailure(
        StorageFailure(
          'This conversation could not be saved on this device.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<List<CoachThread>> _readAll(String candidateId) async {
    final encoded = await _store.read(_keyFor(candidateId));
    if (encoded == null) return const [];
    final decoded = jsonDecode(encoded);
    if (decoded is! List) {
      throw const FormatException('Invalid coach thread history');
    }
    return decoded
        .map((item) => CoachThread.fromJson(item as Map<String, Object?>))
        .toList();
  }

  String _keyFor(String candidateId) {
    final safeCandidateId = candidateId.replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '_',
    );
    return '$_keyPrefix$safeCandidateId';
  }
}
