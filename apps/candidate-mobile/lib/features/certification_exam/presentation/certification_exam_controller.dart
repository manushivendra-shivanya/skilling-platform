import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../domain/certification_exam.dart';
import '../domain/certification_exam_attempt.dart';

class CertificationExamState {
  const CertificationExamState({required this.exam, required this.attempts});

  final CertificationExam exam;
  final List<CertificationExamAttempt> attempts;

  /// Most recent attempt, if any -- drives the section card's "Passed" /
  /// "Failed, retake in Xh" / "Start exam" state.
  CertificationExamAttempt? get lastAttempt {
    if (attempts.isEmpty) return null;
    final sorted = attempts.toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return sorted.first;
  }

  bool get lastAttemptPassed =>
      lastAttempt?.passed(exam.passThresholdPercent) ?? false;
}

final certificationExamControllerProvider =
    AsyncNotifierProvider<CertificationExamController, CertificationExamState>(
      CertificationExamController.new,
    );

class CertificationExamController
    extends AsyncNotifier<CertificationExamState> {
  @override
  Future<CertificationExamState> build() async {
    final examResult = await ref
        .read(certificationExamRepositoryProvider)
        .loadExam();
    final exam = examResult.when(
      success: (value) => value,
      failure: (failure) => throw failure,
    );

    final candidateId = await _readCandidateId();
    if (candidateId == null) {
      return CertificationExamState(exam: exam, attempts: const []);
    }
    final attemptsResult = await ref
        .read(certificationExamAttemptRepositoryProvider)
        .listAttempts(candidateId, exam.id);
    final attempts = attemptsResult.when(
      success: (value) => value,
      failure: (_) => const <CertificationExamAttempt>[],
    );
    return CertificationExamState(exam: exam, attempts: attempts);
  }

  Future<String?> _readCandidateId() async {
    final result = await ref
        .read(candidateSessionRepositoryProvider)
        .readSession();
    final session = result.when(
      success: (value) => value,
      failure: (_) => null,
    );
    return session?.isAuthenticated == true ? session!.candidateId : null;
  }

  void retry() => ref.invalidateSelf();
}
