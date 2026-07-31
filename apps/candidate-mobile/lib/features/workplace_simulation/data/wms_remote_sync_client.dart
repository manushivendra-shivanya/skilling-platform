import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/simulation_runtime.dart';

class WmsRemoteSyncClient {
  factory WmsRemoteSyncClient({
    required Dio dio,
    required SupabaseClient supabaseClient,
    required String apiBaseUrl,
  }) => WmsRemoteSyncClient._(dio, supabaseClient, apiBaseUrl);

  WmsRemoteSyncClient._(this._dio, this._supabaseClient, this._apiBaseUrl);

  final Dio _dio;
  final SupabaseClient _supabaseClient;
  final String _apiBaseUrl;

  Future<void> sync({
    required SimulationAttempt attempt,
    SimulationResult? result,
    GeneratedScenario? generatedScenario,
  }) async {
    final accessToken = _supabaseClient.auth.currentSession?.accessToken;
    if (accessToken == null) {
      throw const AuthenticationFailure(
        'Sign in again to sync your workplace simulation.',
      );
    }

    try {
      await _dio.post<Object?>(
        '$_apiBaseUrl/workplace-simulation/attempts/${attempt.id}/sync',
        data: {
          'attempt': attempt.toJson(),
          'result': result?.toJson(),
          'generatedScenario': generatedScenario?.toJson(),
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Idempotency-Key': _idempotencyKey(attempt, result),
          },
        ),
      );
    } on DioException catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  String _idempotencyKey(SimulationAttempt attempt, SimulationResult? result) =>
      [
        'wms-sync',
        attempt.candidateId,
        attempt.id,
        attempt.actionCount,
        attempt.auditEventCount,
        attempt.timerStatus.wireName,
        attempt.state.wireName,
        result == null
            ? 'no-result'
            : 'result-${result.completedAt.toUtc().toIso8601String()}',
      ].join('.');

  AppFailure _mapError(DioException error, StackTrace stackTrace) {
    final status = error.response?.statusCode;
    final body = error.response?.data;
    final serverError = body is Map ? body['error'] : null;
    final serverMessage = serverError is Map ? serverError['message'] : null;
    final message = serverMessage is String
        ? serverMessage
        : 'Your workplace simulation could not be synced.';

    if (status == 401) {
      return AuthenticationFailure(
        message,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (status == 403) {
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
        'Could not reach the workplace sync service. Your attempt remains saved on this device.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    return UnexpectedFailure(message, cause: error, stackTrace: stackTrace);
  }
}
