import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/resume_parsing_repository.dart';

/// Calls the real NestJS BFF (`POST /v1/resume/parse`, see
/// `apps/api/src/resume`). Same shape as `ApiCoachRepository`: the AI
/// provider call always happens server-side, this repository only ever
/// talks to Flora's own API, never to Gemini directly.
class ApiResumeParsingRepository implements ResumeParsingRepository {
  ApiResumeParsingRepository({
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
  Future<Result<ResumeParseResult>> parse(ResumeParseRequest request) async {
    final accessToken = _supabaseClient.auth.currentSession?.accessToken;
    if (accessToken == null) {
      return const ResultFailure(
        AuthenticationFailure('Sign in again to parse your resume.'),
      );
    }
    try {
      final response = await _dio.post<Object?>(
        '$_apiBaseUrl/resume/parse',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        data: {
          'resumeText': request.resumeText,
          'consentVersion': request.consentVersion,
        },
      );
      final body = response.data;
      if (body is! Map) {
        throw const FormatException('Unexpected resume-parse response shape');
      }
      final rawFields = body['fields'];
      final requiresCandidateReview = body['requiresCandidateReview'];
      final provider = body['provider'];
      if (rawFields is! Map ||
          requiresCandidateReview is! bool ||
          provider is! String) {
        throw const FormatException('Unexpected resume-parse response shape');
      }
      final fields = <String, String>{
        for (final entry in rawFields.entries)
          if (entry.key is String && entry.value is String)
            entry.key as String: entry.value as String,
      };
      return Success(
        ResumeParseResult(
          adapter: provider,
          fields: fields,
          requiresCandidateReview: requiresCandidateReview,
        ),
      );
    } on DioException catch (error, stackTrace) {
      return ResultFailure(_mapError(error, stackTrace));
    } catch (error, stackTrace) {
      return ResultFailure(
        UnexpectedFailure(
          'Your resume could not be parsed. Try again in a moment.',
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
        : 'Your resume could not be parsed. Try again in a moment.';

    if (status == 401) {
      return AuthenticationFailure(
        message,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    // 403 covers both the required-consent case and rate-limiting -- same
    // posture as ApiCoachRepository: PermissionFailure surfaces `.message`
    // verbatim, so the server's own wording carries through untouched.
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
        'Could not reach the server. Check your connection and try again.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    return UnexpectedFailure(message, cause: error, stackTrace: stackTrace);
  }
}
