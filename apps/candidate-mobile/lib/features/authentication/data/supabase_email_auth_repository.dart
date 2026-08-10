import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/repositories/candidate_session_repository.dart';
import '../domain/development_auth_repository.dart';

/// Email delivers through Supabase's own mail sender (or a configured SMTP
/// relay) rather than a third-party SMS gateway. Phone OTP was dropped as
/// the primary channel because sending SMS to Indian numbers requires DLT
/// registration (a TRAI-mandated process, independent of any SMS vendor)
/// that stays outside this app's control; email and Google Sign-In need no
/// equivalent per-message gate.
class SupabaseEmailAuthRepository implements DevelopmentAuthRepository {
  SupabaseEmailAuthRepository(this._client, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final SupabaseClient _client;
  final DateTime Function() _clock;

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  Future<Result<OtpChallenge>> requestOtp(String email) async {
    final normalized = email.trim().toLowerCase();
    if (!_emailPattern.hasMatch(normalized)) {
      return const ResultFailure(
        ValidationFailure('Enter a valid email address.'),
      );
    }
    try {
      // shouldCreateUser: true -- this is sign-up-or-sign-in in one step,
      // matching how the phone flow always treated a new number as a new
      // candidate. There is no separate registration screen.
      await _client.auth.signInWithOtp(
        email: normalized,
        shouldCreateUser: true,
      );
      final now = _clock();
      return Success(
        OtpChallenge(
          id: 'supabase-email-otp',
          contact: normalized,
          expiresAt: now.add(const Duration(minutes: 5)),
          resendAvailableAt: now.add(const Duration(seconds: 60)),
        ),
      );
    } on AuthException catch (error, stackTrace) {
      return ResultFailure(
        AuthenticationFailure(
          'We could not send the code. Please wait and try again.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<CandidateSession>> verifyOtp({
    required OtpChallenge challenge,
    required String otp,
  }) async {
    if (!_clock().isBefore(challenge.expiresAt)) {
      return const ResultFailure(
        TimeoutFailure('This code has expired. Request a new one.'),
      );
    }
    try {
      final response = await _client.auth.verifyOTP(
        type: OtpType.email,
        token: otp,
        email: challenge.contact,
      );
      final user = response.user;
      if (user == null || response.session == null) {
        return const ResultFailure(
          AuthenticationFailure('Code verification did not create a session.'),
        );
      }
      return Success(
        CandidateSession(candidateId: user.id, isAuthenticated: true),
      );
    } on AuthException catch (error, stackTrace) {
      return ResultFailure(
        AuthenticationFailure(
          'That code could not be verified. Check it and try again.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
