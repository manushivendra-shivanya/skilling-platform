import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/repositories/candidate_session_repository.dart';

final candidateSessionControllerProvider =
    AsyncNotifierProvider<CandidateSessionController, CandidateSession?>(
      CandidateSessionController.new,
    );

class CandidateSessionController extends AsyncNotifier<CandidateSession?> {
  @override
  Future<CandidateSession?> build() async {
    final result = await ref
        .read(candidateSessionRepositoryProvider)
        .readSession();
    return result.when(
      success: (session) => session,
      failure: (failure) => throw failure,
    );
  }

  Future<AppFailure?> save(CandidateSession session) async {
    state = const AsyncLoading();
    final result = await ref
        .read(candidateSessionRepositoryProvider)
        .saveSession(session);
    return result.when(
      success: (_) {
        state = AsyncData(session);
        return null;
      },
      failure: (failure) {
        state = AsyncError(failure, failure.stackTrace ?? StackTrace.current);
        return failure;
      },
    );
  }

  Future<AppFailure?> logout() async {
    state = const AsyncLoading();
    final result = await ref
        .read(candidateSessionRepositoryProvider)
        .clearSession();
    return result.when(
      success: (_) {
        state = const AsyncData(null);
        return null;
      },
      failure: (failure) {
        state = AsyncError(failure, failure.stackTrace ?? StackTrace.current);
        return failure;
      },
    );
  }
}
