import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../profile_details/domain/detailed_candidate_profile.dart';
import '../domain/profile_assistant_repository.dart';
import '../domain/profile_gap.dart';

/// Calls the real NestJS BFF (`POST /v1/profile-assistant/turn`, see
/// `apps/api/src/profile-assistant`). Same shape as
/// `ApiResumeParsingRepository`: the model call always happens
/// server-side, this repository only ever talks to Flora's own API.
///
/// Parses defensively -- a wrong-typed field drops that one update rather
/// than throwing away the whole turn, matching the backend's own posture
/// and for the same reason: one bad field should never cost the candidate
/// the question they just answered.
class ApiProfileAssistantRepository implements ProfileAssistantRepository {
  ApiProfileAssistantRepository({
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
  Future<Result<AssistantReply>> continueConversation(
    AssistantTurnRequest request,
  ) async {
    final accessToken = _supabaseClient.auth.currentSession?.accessToken;
    if (accessToken == null) {
      return const ResultFailure(
        AuthenticationFailure('Sign in again to continue.'),
      );
    }
    try {
      final response = await _dio.post<Object?>(
        '$_apiBaseUrl/profile-assistant/turn',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        data: {
          'knownProfileDigest': request.knownProfileDigest,
          'remainingFields': request.remainingFields
              .map((field) => field.name)
              .toList(),
          'history': request.history
              .map(
                (turn) => {
                  'role': turn.role == AssistantRole.assistant
                      ? 'assistant'
                      : 'candidate',
                  'text': turn.text,
                },
              )
              .toList(),
          'languageTag': request.languageTag,
        },
      );

      final body = response.data;
      if (body is! Map) {
        throw const FormatException('Unexpected assistant response shape');
      }
      final text = body['text'];
      if (text is! String || text.trim().isEmpty) {
        throw const FormatException('Unexpected assistant response shape');
      }

      return Success(
        AssistantReply(
          text: text.trim(),
          updates: _updates(body['updates']),
          isComplete: body['isComplete'] == true,
        ),
      );
    } on DioException catch (error, stackTrace) {
      return ResultFailure(_mapError(error, stackTrace));
    } catch (error, stackTrace) {
      return ResultFailure(
        UnexpectedFailure(
          'The assistant could not reply. Try again in a moment.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  String _str(Object? value) => value is String ? value.trim() : '';

  List<String> _strList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  List<AssistantFieldUpdate> _updates(Object? value) {
    if (value is! List) return const [];
    final updates = <AssistantFieldUpdate>[];

    for (final raw in value) {
      if (raw is! Map) continue;
      final field = ProfileGapId.values
          .where((id) => id.name == _str(raw['field']))
          .firstOrNull;
      if (field == null) continue;
      final confirmation = _str(raw['confirmation']);

      switch (field) {
        case ProfileGapId.expectedCtc:
          final amount = raw['amount'];
          final parsed = amount is num
              ? amount.toDouble()
              : double.tryParse(_str(amount));
          if (parsed == null || parsed <= 0) continue;
          updates.add(
            AssistantFieldUpdate(
              field: field,
              confirmation: confirmation,
              amount: parsed,
            ),
          );
        case ProfileGapId.noticePeriod:
          final period = NoticePeriod.fromId(_str(raw['id']));
          if (period == null) continue;
          updates.add(
            AssistantFieldUpdate(
              field: field,
              confirmation: confirmation,
              noticePeriod: period,
            ),
          );
        case ProfileGapId.languages:
          final languages = _languages(raw['languages']);
          if (languages.isEmpty) continue;
          updates.add(
            AssistantFieldUpdate(
              field: field,
              confirmation: confirmation,
              languages: languages,
            ),
          );
        case ProfileGapId.skills:
        case ProfileGapId.preferredLocations:
          final items = _strList(raw['items']);
          if (items.isEmpty) continue;
          updates.add(
            AssistantFieldUpdate(
              field: field,
              confirmation: confirmation,
              items: items,
            ),
          );
        default:
          final text = _str(raw['text']);
          if (text.isEmpty) continue;
          updates.add(
            AssistantFieldUpdate(
              field: field,
              confirmation: confirmation,
              text: text,
            ),
          );
      }
    }

    return updates;
  }

  List<LanguageEntry> _languages(Object? value) {
    if (value is! List) return const [];
    final entries = <LanguageEntry>[];
    for (final raw in value) {
      if (raw is! Map) continue;
      final language = _str(raw['language']);
      if (language.isEmpty) continue;
      entries.add(
        LanguageEntry(
          // Empty id -- a brand new entry the repository will insert, the
          // same convention resume import already uses.
          id: '',
          language: language,
          proficiency:
              LanguageProficiency.fromId(_str(raw['proficiency'])) ??
              LanguageProficiency.elementary,
        ),
      );
    }
    return entries;
  }

  AppFailure _mapError(DioException error, StackTrace stackTrace) {
    final status = error.response?.statusCode;
    final body = error.response?.data;
    final serverError = body is Map ? body['error'] : null;
    final serverMessage = serverError is Map ? serverError['message'] : null;
    final message = serverMessage is String
        ? serverMessage
        : 'The assistant could not reply. Try again in a moment.';

    if (status == 401) {
      return AuthenticationFailure(
        message,
        cause: error,
        stackTrace: stackTrace,
      );
    }
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
    // ProfileAssistantService wraps any provider failure in a 503 -- see
    // ApiResumeParsingRepository._mapError for why that needs its own
    // branch rather than falling through to UnexpectedFailure.
    if (status != null && status >= 500 && status < 600) {
      return ServiceUnavailableFailure(
        message,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    return UnexpectedFailure(message, cause: error, stackTrace: stackTrace);
  }
}
