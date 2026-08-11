import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/repositories/candidate_session_repository.dart';

/// Signs a candidate in with a real Google account and exchanges the
/// resulting ID token for a real Supabase Auth session. This is what
/// replaces the fake local "skip to home" session -- the returned
/// [CandidateSession.candidateId] is a real `auth.users` UUID, so it
/// satisfies the RLS policies that every Supabase-backed repository relies
/// on (see supabase_candidate_onboarding_repository.dart).
class GoogleAuthRepository {
  GoogleAuthRepository(this._client, {required String webClientId})
    : _webClientId = webClientId;

  final SupabaseClient _client;
  final String _webClientId;
  bool _initialized = false;

  // Same real-device failure class as FlutterSecureKeyValueStore's
  // _callTimeout (see that file's doc comment): none of the three async
  // calls below had any ceiling, so a stall on a slow/flaky connection --
  // exactly the conditions this app explicitly targets -- hung the whole
  // sign-in flow forever with no recovery path. Network calls get a
  // tighter bound; authenticate() gets a generous one since it drives a
  // native account-picker UI a real person is interacting with, not pure
  // network latency.
  static const _networkCallTimeout = Duration(seconds: 20);
  static const _interactiveCallTimeout = Duration(seconds: 90);

  Future<Result<CandidateSession>> signIn() async {
    try {
      if (!_initialized) {
        await GoogleSignIn.instance
            .initialize(serverClientId: _webClientId)
            .timeout(_networkCallTimeout);
        _initialized = true;
      }
      final account = await GoogleSignIn.instance.authenticate().timeout(
        _interactiveCallTimeout,
      );
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        return const ResultFailure(
          AuthenticationFailure(
            'Google did not return a sign-in token. Please try again.',
          ),
        );
      }

      final response = await _client.auth
          .signInWithIdToken(provider: OAuthProvider.google, idToken: idToken)
          .timeout(_networkCallTimeout);
      final user = response.user;
      if (user == null || response.session == null) {
        return const ResultFailure(
          AuthenticationFailure('Google sign-in did not create a session.'),
        );
      }
      return Success(
        CandidateSession(candidateId: user.id, isAuthenticated: true),
      );
    } on GoogleSignInException catch (error, stackTrace) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return const ResultFailure(
          AuthenticationFailure('Sign-in was cancelled.'),
        );
      }
      return ResultFailure(
        AuthenticationFailure(
          'Google sign-in failed. Please try again.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } on AuthException catch (error, stackTrace) {
      return ResultFailure(
        AuthenticationFailure(
          'That Google account could not be verified. Please try again.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
