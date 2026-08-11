import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../core/analytics/analytics_event.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/candidate_onboarding_draft.dart';

final candidateOnboardingControllerProvider =
    AsyncNotifierProvider<
      CandidateOnboardingController,
      CandidateOnboardingDraft
    >(CandidateOnboardingController.new);

class CandidateOnboardingController
    extends AsyncNotifier<CandidateOnboardingDraft> {
  String? _candidateId;

  @override
  Future<CandidateOnboardingDraft> build() async {
    final sessionResult = await ref
        .read(candidateSessionRepositoryProvider)
        .readSession();
    final session = sessionResult.when(
      success: (value) => value,
      failure: (failure) => throw failure,
    );
    if (session == null || !session.isAuthenticated) {
      throw const AuthenticationFailure(
        'Sign in again to continue your profile.',
      );
    }
    _candidateId = session.candidateId;

    // watch, not read: candidateOnboardingRepositoryProvider switches from
    // secure-local to Supabase once canUseLiveBackendProvider flips true
    // (right after sign-in completes). A `read` here would freeze this
    // controller on whichever repository was live when it first built --
    // exactly the "signed in but nothing loads until the app is killed and
    // reopened" bug this fixes.
    final result = await ref
        .watch(candidateOnboardingRepositoryProvider)
        .readDraft(session.candidateId);
    return result.when(
      success: (draft) {
        if (draft.currentStep == 0 && !draft.isCompleted) {
          unawaited(
            ref
                .read(analyticsTrackerProvider)
                .track(AnalyticsEvent.onboardingStarted()),
          );
        }
        return draft;
      },
      failure: (failure) => throw failure,
    );
  }

  Future<AppFailure?> save(CandidateOnboardingDraft draft) async {
    final candidateId = _candidateId;
    if (candidateId == null) {
      return const AuthenticationFailure(
        'Sign in again to continue your profile.',
      );
    }

    final result = await ref
        .read(candidateOnboardingRepositoryProvider)
        .saveDraft(candidateId, draft);
    return result.when(
      success: (_) {
        state = AsyncData(draft);
        unawaited(
          ref
              .read(analyticsTrackerProvider)
              .track(
                draft.isCompleted
                    ? AnalyticsEvent.onboardingCompleted()
                    : AnalyticsEvent.onboardingStepSaved(draft.currentStep),
              ),
        );
        return null;
      },
      failure: (failure) => failure,
    );
  }

  void retry() {
    ref.invalidateSelf();
  }
}
