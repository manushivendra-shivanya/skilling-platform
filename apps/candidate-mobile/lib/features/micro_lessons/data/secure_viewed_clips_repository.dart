import 'dart:convert';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/storage/secure_key_value_store.dart';
import '../domain/viewed_clips_repository.dart';

class SecureViewedClipsRepository implements ViewedClipsRepository {
  SecureViewedClipsRepository(this._store);

  static const _keyPrefix = 'micro_lessons.viewed_clip_ids.v1.';

  final SecureKeyValueStore _store;

  @override
  Future<Result<Set<String>>> readViewedClipIds(String candidateId) async {
    try {
      return Success(await _readAll(candidateId));
    } catch (error, stackTrace) {
      return ResultFailure(
        StorageFailure(
          'Your watched clips could not be loaded.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> markViewed(String candidateId, String clipId) async {
    try {
      final current = await _readAll(candidateId);
      if (current.contains(clipId)) return const Success(null);
      final next = {...current, clipId};
      await _store.write(_keyFor(candidateId), jsonEncode(next.toList()));
      return const Success(null);
    } catch (error, stackTrace) {
      return ResultFailure(
        StorageFailure(
          'This clip could not be marked as watched on this device.',
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
      throw const FormatException('Invalid viewed-clips list');
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
