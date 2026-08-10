import 'voice_interview.dart';

class VoiceEvaluationEngine {
  const VoiceEvaluationEngine();

  VoiceEvaluation evaluate(List<VoiceAnswer> answers, {DateTime? now}) {
    final transcript = answers
        .map((answer) => answer.transcript.toLowerCase())
        .join(' ');
    final answered = answers.where(
      (answer) => answer.transcript.trim().isNotEmpty,
    );
    final relevance = ((answered.length / voiceInterviewQuestions.length) * 100)
        .round();
    final correctness = _keywordScore(transcript, const [
      'recount',
      'record',
      'check',
      'verify',
      'sla',
      'safety',
    ]);
    final structure = _keywordScore(transcript, const [
      'first',
      'then',
      'next',
      'finally',
      'because',
    ]);
    final clarity = _clarityScore(answers);
    final escalation = _keywordScore(transcript, const [
      'escalate',
      'supervisor',
      'inform',
      'report',
      'document',
    ]);
    final dimensions = [
      VoiceDimensionFeedback(
        dimension: 'Answer relevance',
        score: relevance,
        explanation:
            '${answered.length} of ${voiceInterviewQuestions.length} questions include reviewable transcript evidence.',
      ),
      VoiceDimensionFeedback(
        dimension: 'Operational correctness',
        score: correctness,
        explanation:
            'Looks only for job-process evidence such as verification, records, SLA and safety.',
      ),
      VoiceDimensionFeedback(
        dimension: 'Answer structure',
        score: structure,
        explanation:
            'Looks for an understandable sequence of actions, not vocabulary or accent.',
      ),
      VoiceDimensionFeedback(
        dimension: 'Clarity',
        score: clarity,
        explanation:
            'Uses transcript completeness and concise answer length. Audio characteristics are excluded.',
      ),
      VoiceDimensionFeedback(
        dimension: 'Appropriate escalation',
        score: escalation,
        explanation:
            'Looks for documented reporting or supervisor escalation when an exception needs support.',
      ),
    ];
    final total =
        dimensions.fold<int>(0, (sum, item) => sum + item.score) ~/
        dimensions.length;
    return VoiceEvaluation(
      totalScore: total,
      dimensions: dimensions,
      confidence: 0.55,
      summary:
          'Development coaching estimate from candidate-reviewed transcript text. It is not an employer score or hiring decision.',
      improvement:
          'Use a simple sequence: verify the facts, preserve the record, explain the risk, and escalate to the correct person.',
      promptVersion: 'P-VOICE-EVALUATOR-001@1.0.0',
      rubricVersion: 'voice-logistics-v1',
      requiresHumanReview: true,
      createdAt: now ?? DateTime.now().toUtc(),
    );
  }

  int _keywordScore(String transcript, List<String> terms) {
    final matches = terms.where(transcript.contains).length;
    return (35 + matches * 13).clamp(35, 100);
  }

  int _clarityScore(List<VoiceAnswer> answers) {
    if (answers.isEmpty) return 0;
    final suitable = answers.where((answer) {
      final wordCount = answer.transcript
          .trim()
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .length;
      return wordCount >= 8 && wordCount <= 120;
    }).length;
    return (40 + suitable * 20).clamp(40, 100);
  }
}
