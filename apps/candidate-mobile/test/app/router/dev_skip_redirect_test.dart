import 'package:candidate_mobile/app/router/app_router.dart';
import 'package:candidate_mobile/core/errors/app_failure.dart';
import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/onboarding/domain/candidate_onboarding_draft.dart';
import 'package:candidate_mobile/features/onboarding/domain/candidate_onboarding_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the Supabase-backed onboarding repository in a review build:
/// every read fails, because the dev candidate id has no `auth.users` row and
/// RLS rejects the query. This is the exact condition that sent the skip
/// straight back to the profile form.
class _RejectingOnboardingRepository implements CandidateOnboardingRepository {
  int readCount = 0;

  @override
  Future<Result<CandidateOnboardingDraft>> readDraft(String candidateId) async {
    readCount += 1;
    return const ResultFailure(
      UnexpectedFailure('row-level security policy denied the read'),
    );
  }

  @override
  Future<Result<void>> saveDraft(
    String candidateId,
    CandidateOnboardingDraft draft,
  ) async => const ResultFailure(
    UnexpectedFailure('row-level security policy denied the write'),
  );
}

class _StubSessionRepository implements CandidateSessionRepository {
  _StubSessionRepository(this._session);

  final CandidateSession? _session;

  @override
  Future<Result<CandidateSession?>> readSession() async => Success(_session);

  @override
  Future<Result<void>> saveSession(CandidateSession session) async =>
      const Success(null);

  @override
  Future<Result<void>> clearSession() async => const Success(null);
}

void main() {
  test(
    'dev skip reaches Home even when the backend rejects every read',
    () async {
      final onboarding = _RejectingOnboardingRepository();

      final redirect = await redirectForCandidateStateForTest(
        location: authenticatedRoutePath,
        candidateSessionRepository: _StubSessionRepository(
          const CandidateSession(
            candidateId: devSkipCandidateId,
            isAuthenticated: true,
          ),
        ),
        candidateOnboardingRepository: onboarding,
        allowDevSkipToHome: true,
      );

      expect(redirect, homeRoutePath);
      // The point of the short-circuit: the failing backend is never consulted
      // for the dev session, so its failure cannot bounce us to onboarding.
      expect(onboarding.readCount, 0);
    },
  );

  test('a real candidate is still gated on onboarding', () async {
    final redirect = await redirectForCandidateStateForTest(
      location: authenticatedRoutePath,
      candidateSessionRepository: _StubSessionRepository(
        const CandidateSession(
          candidateId: '11111111-1111-4111-8111-111111111111',
          isAuthenticated: true,
        ),
      ),
      candidateOnboardingRepository: _RejectingOnboardingRepository(),
      allowDevSkipToHome: true,
    );

    // No draft readable means onboarding is not complete, so the candidate
    // stays on the authenticated entry route rather than reaching Home.
    expect(redirect, isNull);
  });

  test('the dev id gets no special treatment in a production build', () async {
    final redirect = await redirectForCandidateStateForTest(
      location: authenticatedRoutePath,
      candidateSessionRepository: _StubSessionRepository(
        const CandidateSession(
          candidateId: devSkipCandidateId,
          isAuthenticated: true,
        ),
      ),
      candidateOnboardingRepository: _RejectingOnboardingRepository(),
      allowDevSkipToHome: false,
    );

    expect(redirect, isNot(homeRoutePath));
  });
}
