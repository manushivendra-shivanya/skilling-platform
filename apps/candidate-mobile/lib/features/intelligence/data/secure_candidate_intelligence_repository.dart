import 'dart:convert';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/storage/secure_key_value_store.dart';
import '../domain/candidate_intelligence.dart';
import '../domain/candidate_intelligence_repository.dart';

class SecureCandidateIntelligenceRepository
    implements CandidateIntelligenceRepository {
  SecureCandidateIntelligenceRepository(this._store);

  final SecureKeyValueStore _store;

  @override
  Future<Result<CandidateIntelligenceState>> load(String candidateId) async {
    try {
      final encoded = await _store.read(_key(candidateId));
      if (encoded == null) {
        return const Success(CandidateIntelligenceState());
      }
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('Invalid candidate intelligence state');
      }
      return Success(CandidateIntelligenceState.fromJson(decoded));
    } catch (error, stackTrace) {
      return ResultFailure(
        StorageFailure(
          'Your saved pathway could not be restored. Please retry.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<CandidateIntelligenceState>> save(
    String candidateId,
    CandidateIntelligenceState state,
  ) async {
    try {
      await _store.write(_key(candidateId), jsonEncode(state.toJson()));
      return Success(state);
    } catch (error, stackTrace) {
      return ResultFailure(
        StorageFailure(
          'Your progress could not be saved securely. Please retry.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  String _key(String candidateId) {
    final safeId = candidateId.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
    return 'candidate.intelligence.v1.$safeId';
  }
}

class InMemoryCandidateIntelligenceRepository
    implements CandidateIntelligenceRepository {
  InMemoryCandidateIntelligenceRepository({
    this.state = const CandidateIntelligenceState(),
  });

  CandidateIntelligenceState state;

  @override
  Future<Result<CandidateIntelligenceState>> load(String candidateId) async =>
      Success(state);

  @override
  Future<Result<CandidateIntelligenceState>> save(
    String candidateId,
    CandidateIntelligenceState state,
  ) async {
    this.state = state;
    return Success(state);
  }
}
