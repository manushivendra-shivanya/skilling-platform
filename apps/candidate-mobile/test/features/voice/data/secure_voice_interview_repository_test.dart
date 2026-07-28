import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:candidate_mobile/features/voice/data/secure_voice_interview_repository.dart';
import 'package:candidate_mobile/features/voice/domain/voice_interview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'secure repository restores an interrupted recording without penalty',
    () async {
      final repository = SecureVoiceInterviewRepository(
        InMemorySecureKeyValueStore(),
      );
      final saved = VoiceInterviewState(
        sessionId: 'voice-test',
        status: VoiceInterviewStatus.recording,
        consent: VoiceConsent(
          recording: true,
          transcription: true,
          evaluation: true,
          employerSharing: false,
          policyVersion: 'voice-practice-consent-v1',
          acceptedAt: DateTime.utc(2026, 7, 28),
        ),
        microphonePermissionGranted: true,
      );

      await repository.save('candidate-1', saved);
      final restored = (await repository.load(
        'candidate-1',
      )).when(success: (value) => value, failure: (failure) => throw failure);

      expect(restored.status, VoiceInterviewStatus.microphoneReady);
      expect(restored.technicalNotice, contains('interrupted'));
      expect(restored.answers, isEmpty);
    },
  );

  test('delete removes candidate-isolated voice state', () async {
    final repository = SecureVoiceInterviewRepository(
      InMemorySecureKeyValueStore(),
    );
    await repository.save(
      'candidate-1',
      const VoiceInterviewState(sessionId: 'voice-test'),
    );

    await repository.delete('candidate-1');

    final restored = (await repository.load(
      'candidate-1',
    )).when(success: (value) => value, failure: (failure) => throw failure);
    expect(restored.sessionId, isNull);
  });
}
