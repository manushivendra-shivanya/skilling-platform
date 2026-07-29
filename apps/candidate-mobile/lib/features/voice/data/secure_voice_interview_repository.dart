import 'dart:convert';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/storage/secure_key_value_store.dart';
import '../domain/voice_interview.dart';
import '../domain/voice_interview_repository.dart';

class SecureVoiceInterviewRepository implements VoiceInterviewRepository {
  SecureVoiceInterviewRepository(this._store);

  final SecureKeyValueStore _store;

  @override
  Future<Result<VoiceInterviewState>> load(String candidateId) async {
    try {
      final encoded = await _store.read(_key(candidateId));
      if (encoded == null) {
        return const Success(VoiceInterviewState());
      }
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('Invalid voice interview state');
      }
      return Success(VoiceInterviewState.fromJson(decoded));
    } catch (error, stackTrace) {
      return ResultFailure(
        StorageFailure(
          'Your saved voice interview could not be restored. Please retry.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<VoiceInterviewState>> save(
    String candidateId,
    VoiceInterviewState state,
  ) async {
    try {
      await _store.write(_key(candidateId), jsonEncode(state.toJson()));
      return Success(state);
    } catch (error, stackTrace) {
      return ResultFailure(
        StorageFailure(
          'Your voice interview could not be saved securely. Please retry.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> delete(String candidateId) async {
    try {
      await _store.remove(_key(candidateId));
      return const Success(null);
    } catch (error, stackTrace) {
      return ResultFailure(
        StorageFailure(
          'Your local voice interview could not be deleted. Please retry.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  String _key(String candidateId) {
    final safeId = candidateId.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
    return 'candidate.voice-interview.v1.$safeId';
  }
}

class InMemoryVoiceInterviewRepository implements VoiceInterviewRepository {
  InMemoryVoiceInterviewRepository({this.state = const VoiceInterviewState()});

  VoiceInterviewState state;

  @override
  Future<Result<VoiceInterviewState>> load(String candidateId) async =>
      Success(state);

  @override
  Future<Result<VoiceInterviewState>> save(
    String candidateId,
    VoiceInterviewState state,
  ) async {
    this.state = state;
    return Success(state);
  }

  @override
  Future<Result<void>> delete(String candidateId) async {
    state = const VoiceInterviewState();
    return const Success(null);
  }
}
