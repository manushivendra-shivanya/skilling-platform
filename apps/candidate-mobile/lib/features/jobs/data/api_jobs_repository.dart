import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/jobs_repository.dart';
import 'local_mock_jobs_repository.dart';

/// Applies to a job through the real `POST /v1/jobs/:id/applications`
/// endpoint on the NestJS BFF (`apps/api`). Job listing and the locally
/// tracked "applied" set stay on [LocalMockJobsRepository] until the Jobs
/// feature has a real job catalogue to list against -- mock job ids will not
/// match a real job in the target database, so an apply call against a mock
/// listing is expected to fail there until that catalogue is wired too.
class ApiJobsRepository implements JobsRepository {
  ApiJobsRepository({
    required LocalMockJobsRepository local,
    required Dio dio,
    required SupabaseClient supabaseClient,
    required String apiBaseUrl,
  }) : _local = local,
       _dio = dio,
       _supabaseClient = supabaseClient,
       _apiBaseUrl = apiBaseUrl;

  final LocalMockJobsRepository _local;
  final Dio _dio;
  final SupabaseClient _supabaseClient;
  final String _apiBaseUrl;

  @override
  Future<Result<List<JobOpportunity>>> loadJobs() => _local.loadJobs();

  @override
  Future<Result<Set<String>>> readAppliedJobIds(String candidateId) =>
      _local.readAppliedJobIds(candidateId);

  @override
  Future<Result<void>> saveApplication(String candidateId, String jobId) async {
    final accessToken = _supabaseClient.auth.currentSession?.accessToken;
    if (accessToken == null) {
      return const ResultFailure(
        AuthenticationFailure('Sign in again to apply for this job.'),
      );
    }
    try {
      await _dio.post<Object?>(
        '$_apiBaseUrl/jobs/$jobId/applications',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            // Deterministic per candidate/job so a retry of the same tap
            // reuses the same key; the server's unique (job_id, candidate_id)
            // constraint is what actually guarantees no duplicate is created.
            'Idempotency-Key': 'jobs-apply.$candidateId.$jobId',
          },
        ),
      );
    } on DioException catch (error, stackTrace) {
      return ResultFailure(_mapError(error, stackTrace));
    } catch (error, stackTrace) {
      return ResultFailure(
        UnexpectedFailure(
          'Your application could not be submitted.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
    return _local.saveApplication(candidateId, jobId);
  }

  AppFailure _mapError(DioException error, StackTrace stackTrace) {
    final status = error.response?.statusCode;
    final body = error.response?.data;
    final serverError = body is Map ? body['error'] : null;
    final serverMessage = serverError is Map ? serverError['message'] : null;
    final message = serverMessage is String
        ? serverMessage
        : 'Your application could not be submitted.';

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
        'Could not reach the jobs service. Check your connection and try again.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    return UnexpectedFailure(message, cause: error, stackTrace: stackTrace);
  }
}
