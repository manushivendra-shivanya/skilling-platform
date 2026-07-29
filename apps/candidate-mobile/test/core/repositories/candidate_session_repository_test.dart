import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'secure session survives repository reconstruction and clears',
    () async {
      final store = InMemorySecureKeyValueStore();
      final firstRepository = SecureCandidateSessionRepository(store);
      const session = CandidateSession(
        candidateId: 'dev-candidate-3210',
        isAuthenticated: true,
      );

      final saveResult = await firstRepository.saveSession(session);
      expect(
        saveResult.when(success: (_) => true, failure: (_) => false),
        isTrue,
      );

      final restoredRepository = SecureCandidateSessionRepository(store);
      final readResult = await restoredRepository.readSession();
      expect(
        readResult.when(
          success: (value) => value?.candidateId,
          failure: (_) => null,
        ),
        session.candidateId,
      );

      await restoredRepository.clearSession();
      final clearedResult = await restoredRepository.readSession();
      expect(
        clearedResult.when(success: (value) => value, failure: (_) => session),
        isNull,
      );
    },
  );

  test('malformed secure session returns a storage failure', () async {
    final store = InMemorySecureKeyValueStore({
      SecureCandidateSessionRepository.sessionKey: 'not-json',
    });

    final result = await SecureCandidateSessionRepository(store).readSession();

    expect(
      result.when(success: (_) => null, failure: (failure) => failure.message),
      contains('restore your session'),
    );
  });
}
