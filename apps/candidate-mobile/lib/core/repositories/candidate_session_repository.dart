import 'dart:convert';

import '../errors/app_failure.dart';
import '../errors/result.dart';
import '../storage/secure_key_value_store.dart';

class CandidateSession {
  const CandidateSession({
    required this.candidateId,
    required this.isAuthenticated,
  });

  final String candidateId;
  final bool isAuthenticated;

  Map<String, Object?> toJson() => {
    'candidate_id': candidateId,
    'is_authenticated': isAuthenticated,
  };

  factory CandidateSession.fromJson(Map<String, Object?> json) {
    final candidateId = json['candidate_id'];
    final isAuthenticated = json['is_authenticated'];
    if (candidateId is! String || isAuthenticated is! bool) {
      throw const FormatException('Invalid candidate session');
    }
    return CandidateSession(
      candidateId: candidateId,
      isAuthenticated: isAuthenticated,
    );
  }
}

abstract interface class CandidateSessionRepository {
  Future<Result<CandidateSession?>> readSession();

  Future<Result<void>> saveSession(CandidateSession session);

  Future<Result<void>> clearSession();
}

class SecureCandidateSessionRepository implements CandidateSessionRepository {
  SecureCandidateSessionRepository(this._store);

  static const sessionKey = 'candidate.authenticated_session.v1';

  final SecureKeyValueStore _store;

  @override
  Future<Result<void>> clearSession() async {
    try {
      await _store.remove(sessionKey);
      return const Success(null);
    } catch (error, stackTrace) {
      return ResultFailure(
        StorageFailure(
          'We could not clear your session. Please try again.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<CandidateSession?>> readSession() async {
    try {
      final encodedSession = await _store.read(sessionKey);
      if (encodedSession == null) {
        return const Success(null);
      }
      final decodedSession = jsonDecode(encodedSession);
      if (decodedSession is! Map<String, Object?>) {
        throw const FormatException('Invalid candidate session');
      }
      return Success(CandidateSession.fromJson(decodedSession));
    } catch (error, stackTrace) {
      return ResultFailure(
        StorageFailure(
          'We could not restore your session. Please sign in again.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> saveSession(CandidateSession session) async {
    try {
      await _store.write(sessionKey, jsonEncode(session.toJson()));
      return const Success(null);
    } catch (error, stackTrace) {
      return ResultFailure(
        StorageFailure(
          'We could not securely save your session. Please try again.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}

class InMemoryCandidateSessionRepository implements CandidateSessionRepository {
  InMemoryCandidateSessionRepository({this._session});

  CandidateSession? _session;

  @override
  Future<Result<void>> clearSession() async {
    _session = null;
    return const Success(null);
  }

  @override
  Future<Result<CandidateSession?>> readSession() async => Success(_session);

  @override
  Future<Result<void>> saveSession(CandidateSession session) async {
    _session = session;
    return const Success(null);
  }
}
