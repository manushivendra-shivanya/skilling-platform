import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/coach_message.dart';
import '../domain/coach_repository.dart';

/// Calls the real NestJS BFF (`POST /v1/coach/message`, see
/// `apps/api/src/coach`). The AI provider call itself always happens
/// server-side -- see docs/27-ai-coach-plan.md and docs/25's Phase J
/// precedent -- this repository only ever talks to Flora's own API, never
/// to Gemini or Anthropic directly.
class ApiCoachRepository implements CoachRepository {
  ApiCoachRepository({
    required Dio dio,
    required SupabaseClient supabaseClient,
    required String apiBaseUrl,
  }) : _dio = dio,
       _supabaseClient = supabaseClient,
       _apiBaseUrl = apiBaseUrl;

  final Dio _dio;
  final SupabaseClient _supabaseClient;
  final String _apiBaseUrl;

  @override
  bool get isLiveData => true;

  @override
  Future<Result<CoachReply>> sendMessage({
    required String message,
    required List<CoachMessage> history,
  }) async {
    final accessToken = _supabaseClient.auth.currentSession?.accessToken;
    if (accessToken == null) {
      return const ResultFailure(
        AuthenticationFailure('Sign in again to talk to your AI coach.'),
      );
    }
    try {
      final response = await _dio.post<Object?>(
        '$_apiBaseUrl/coach/message',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        data: {
          'message': message,
          'history': [
            for (final entry in history)
              {
                'role': entry.author == CoachMessageAuthor.candidate
                    ? 'candidate'
                    : 'coach',
                'text': entry.text,
              },
          ],
          // Only warehouseLogistics is wired into the shipped app today --
          // see sector_pack.dart. Sent explicitly rather than relying on
          // the server default so this keeps working once a second pack
          // goes live and the candidate's real active pack is threaded in.
          'sectorPackId': 'warehouseLogistics',
        },
      );
      final body = response.data;
      if (body is! Map) {
        throw const FormatException('Unexpected coach response shape');
      }
      final reply = body['reply'];
      final modelId = body['modelId'];
      final provider = body['provider'];
      if (reply is! String || modelId is! String || provider is! String) {
        throw const FormatException('Unexpected coach response shape');
      }
      return Success(
        CoachReply(text: reply, modelId: modelId, provider: provider),
      );
    } on DioException catch (error, stackTrace) {
      return ResultFailure(_mapError(error, stackTrace));
    } catch (error, stackTrace) {
      return ResultFailure(
        UnexpectedFailure(
          'The AI coach could not reply. Try again in a moment.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  AppFailure _mapError(DioException error, StackTrace stackTrace) {
    final status = error.response?.statusCode;
    final body = error.response?.data;
    final serverError = body is Map ? body['error'] : null;
    final serverMessage = serverError is Map ? serverError['message'] : null;
    final message = serverMessage is String
        ? serverMessage
        : 'The AI coach could not reply. Try again in a moment.';

    if (status == 401) {
      return AuthenticationFailure(
        message,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    // 403 (forbidden) and 429 (rate-limited) both land as "you can't do
    // this right now" -- PermissionFailure only ever surfaces `.message`
    // verbatim as a coach-authored message (see coach_thread_screen.dart
    // and ask_coach_affordance.dart), so the server's own wording (e.g.
    // "You've reached today's message limit...") carries through without
    // this repository needing a rate-limit-specific type.
    if (status == 403 || status == 429) {
      return PermissionFailure(message, cause: error, stackTrace: stackTrace);
    }
    if (status == 400 || status == 404) {
      return ValidationFailure(message, cause: error, stackTrace: stackTrace);
    }
    const networkErrorTypes = {
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
    };
    if (networkErrorTypes.contains(error.type)) {
      return NetworkFailure(
        'Could not reach the AI coach. Check your connection and try again.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    return UnexpectedFailure(message, cause: error, stackTrace: stackTrace);
  }
}
