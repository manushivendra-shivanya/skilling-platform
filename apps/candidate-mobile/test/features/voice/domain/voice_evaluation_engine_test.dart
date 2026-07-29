import 'package:candidate_mobile/features/voice/domain/voice_evaluation_engine.dart';
import 'package:candidate_mobile/features/voice/domain/voice_interview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('evaluation uses transcript evidence and requires human review', () {
    final answers = [
      VoiceAnswer(
        questionId: 'inventory-exception',
        transcript:
            'First I recount and verify the stock, then record both values and report the exception.',
        localAudioPath: '/tmp/one.m4a',
        durationSeconds: 12,
        recordedAt: DateTime.utc(2026, 7, 28),
      ),
      VoiceAnswer(
        questionId: 'dispatch-priority',
        transcript:
            'First I check the SLA and safety risk, then prioritise and inform the supervisor.',
        localAudioPath: '/tmp/two.m4a',
        durationSeconds: 11,
        recordedAt: DateTime.utc(2026, 7, 28),
      ),
      VoiceAnswer(
        questionId: 'supervisor-escalation',
        transcript:
            'I document the facts, explain the risk, and escalate clearly to my supervisor.',
        localAudioPath: '/tmp/three.m4a',
        durationSeconds: 10,
        recordedAt: DateTime.utc(2026, 7, 28),
      ),
    ];

    final result = const VoiceEvaluationEngine().evaluate(
      answers,
      now: DateTime.utc(2026, 7, 28),
    );

    expect(result.totalScore, greaterThan(70));
    expect(result.dimensions, hasLength(5));
    expect(result.requiresHumanReview, isTrue);
    expect(result.confidence, 0.55);
    expect(result.summary, contains('not an employer score'));
    expect(
      result.dimensions
          .firstWhere((item) => item.dimension == 'Clarity')
          .explanation,
      contains('Audio characteristics are excluded'),
    );
  });
}
