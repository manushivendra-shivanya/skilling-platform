import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../core/analytics/analytics_event.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/development_auth_repository.dart';
import 'candidate_session_controller.dart';

class DevelopmentAuthState {
  const DevelopmentAuthState({
    this.challenge,
    this.failure,
    this.isRequesting = false,
    this.isVerifying = false,
  });

  final OtpChallenge? challenge;
  final AppFailure? failure;
  final bool isRequesting;
  final bool isVerifying;

  DevelopmentAuthState copyWith({
    OtpChallenge? challenge,
    AppFailure? failure,
    bool clearFailure = false,
    bool? isRequesting,
    bool? isVerifying,
  }) {
    return DevelopmentAuthState(
      challenge: challenge ?? this.challenge,
      failure: clearFailure ? null : failure ?? this.failure,
      isRequesting: isRequesting ?? this.isRequesting,
      isVerifying: isVerifying ?? this.isVerifying,
    );
  }
}

final developmentAuthControllerProvider =
    NotifierProvider<DevelopmentAuthController, DevelopmentAuthState>(
      DevelopmentAuthController.new,
    );

class DevelopmentAuthController extends Notifier<DevelopmentAuthState> {
  @override
  DevelopmentAuthState build() => const DevelopmentAuthState();

  Future<bool> requestOtp(String phoneNumber) async {
    state = state.copyWith(isRequesting: true, clearFailure: true);
    final result = await ref
        .read(developmentAuthRepositoryProvider)
        .requestOtp(phoneNumber);
    return result.when(
      success: (challenge) {
        state = DevelopmentAuthState(challenge: challenge);
        unawaited(
          ref
              .read(analyticsTrackerProvider)
              .track(AnalyticsEvent.otpRequested()),
        );
        return true;
      },
      failure: (failure) {
        state = state.copyWith(
          failure: failure,
          isRequesting: false,
          isVerifying: false,
        );
        return false;
      },
    );
  }

  Future<bool> verifyOtp(String otp) async {
    final challenge = state.challenge;
    if (challenge == null) {
      state = state.copyWith(
        failure: const AuthenticationFailure(
          'Request a new OTP before continuing.',
        ),
      );
      return false;
    }

    state = state.copyWith(isVerifying: true, clearFailure: true);
    final result = await ref
        .read(developmentAuthRepositoryProvider)
        .verifyOtp(challenge: challenge, otp: otp);
    return result.when<Future<bool>>(
      success: (session) async {
        final saveResult = await ref
            .read(candidateSessionRepositoryProvider)
            .saveSession(session);
        return saveResult.when(
          success: (_) {
            ref.invalidate(candidateSessionControllerProvider);
            state = state.copyWith(isVerifying: false, clearFailure: true);
            unawaited(
              ref
                  .read(analyticsTrackerProvider)
                  .track(AnalyticsEvent.developmentLoginCompleted()),
            );
            return true;
          },
          failure: (failure) {
            state = state.copyWith(failure: failure, isVerifying: false);
            return false;
          },
        );
      },
      failure: (failure) {
        state = state.copyWith(failure: failure, isVerifying: false);
        return Future.value(false);
      },
    );
  }

  Future<bool> signInWithGoogle() async {
    final repository = ref.read(googleAuthRepositoryProvider);
    if (repository == null) {
      state = state.copyWith(
        failure: const AuthenticationFailure(
          'Google sign-in is not configured for this build.',
        ),
      );
      return false;
    }

    state = state.copyWith(isVerifying: true, clearFailure: true);
    final result = await repository.signIn();
    return result.when<Future<bool>>(
      success: (session) async {
        final saveResult = await ref
            .read(candidateSessionRepositoryProvider)
            .saveSession(session);
        return saveResult.when(
          success: (_) {
            ref.invalidate(candidateSessionControllerProvider);
            state = state.copyWith(isVerifying: false, clearFailure: true);
            unawaited(
              ref
                  .read(analyticsTrackerProvider)
                  .track(AnalyticsEvent.developmentLoginCompleted()),
            );
            return true;
          },
          failure: (failure) {
            state = state.copyWith(failure: failure, isVerifying: false);
            return false;
          },
        );
      },
      failure: (failure) {
        state = state.copyWith(failure: failure, isVerifying: false);
        return Future.value(false);
      },
    );
  }

  Future<bool> resendOtp() {
    final phoneNumber = state.challenge?.phoneNumber;
    if (phoneNumber == null) {
      state = state.copyWith(
        failure: const AuthenticationFailure(
          'Enter your phone number again to request an OTP.',
        ),
      );
      return Future.value(false);
    }
    return requestOtp(phoneNumber);
  }

  void clear() {
    state = const DevelopmentAuthState();
  }
}
