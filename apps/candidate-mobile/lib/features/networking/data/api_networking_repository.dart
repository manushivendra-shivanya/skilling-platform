import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/networking_repository.dart';

/// Calls the real NestJS BFF (`/v1/networking/*`, see
/// `apps/api/src/networking`). Same shape as `ApiCoachRepository` /
/// `ApiResumeParsingRepository`: this repository only ever talks to
/// Flora's own API, never directly to another candidate's data --
/// discovery, matching, and blocking are all enforced server-side.
class ApiNetworkingRepository implements NetworkingRepository {
  ApiNetworkingRepository({
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
  Future<Result<NetworkingProfile>> getMyProfile() {
    return _call(
      'Could not load your networking settings. Try again in a moment.',
      (token) async {
        final response = await _dio.get<Object?>(
          '$_apiBaseUrl/networking/profile',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        final body = response.data;
        if (body is! Map) {
          throw const FormatException(
            'Unexpected networking-profile response shape',
          );
        }
        return _profileFromJson(body);
      },
    );
  }

  @override
  Future<Result<NetworkingProfile>> publishProfile({
    required String fullName,
    required String headline,
    required String city,
    required String state,
    required List<String> preferredRoles,
    required bool discoverable,
  }) {
    return _call(
      'Your networking profile could not be saved. Try again in a moment.',
      (token) async {
        final response = await _dio.put<Object?>(
          '$_apiBaseUrl/networking/profile',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
          data: {
            'fullName': fullName,
            'headline': headline,
            'city': city,
            'state': state,
            'preferredRoles': preferredRoles,
            'discoverable': discoverable,
          },
        );
        final body = response.data;
        if (body is! Map) {
          throw const FormatException(
            'Unexpected networking-profile response shape',
          );
        }
        return _profileFromJson(body);
      },
    );
  }

  @override
  Future<Result<List<DiscoveredCandidate>>> discover() {
    return _call(
      'Could not load candidates right now. Try again in a moment.',
      (token) async {
        final response = await _dio.get<Object?>(
          '$_apiBaseUrl/networking/discover',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        final body = response.data;
        final candidates = body is Map ? body['candidates'] : null;
        if (candidates is! List) {
          throw const FormatException('Unexpected discover response shape');
        }
        return [
          for (final entry in candidates)
            if (entry is Map) _discoveredFromJson(entry),
        ];
      },
    );
  }

  @override
  Future<Result<void>> sendConnectionRequest(String recipientCandidateId) {
    return _call(
      'Could not send the connection request. Try again in a moment.',
      (token) async {
        await _dio.post<Object?>(
          '$_apiBaseUrl/networking/connections',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
          data: {'recipientCandidateId': recipientCandidateId},
        );
      },
    );
  }

  @override
  Future<Result<ConnectionsOverview>> listConnections() {
    return _call('Could not load your connections. Try again in a moment.', (
      token,
    ) async {
      final response = await _dio.get<Object?>(
        '$_apiBaseUrl/networking/connections',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final body = response.data;
      if (body is! Map) {
        throw const FormatException('Unexpected connections response shape');
      }
      return ConnectionsOverview(
        accepted: _summaryListFromJson(body['accepted']),
        incomingPending: _summaryListFromJson(body['incomingPending']),
        outgoingPending: _summaryListFromJson(body['outgoingPending']),
      );
    });
  }

  @override
  Future<Result<void>> respondToConnection(String connectionId, bool accept) {
    return _call('Could not update this connection. Try again in a moment.', (
      token,
    ) async {
      await _dio.post<Object?>(
        '$_apiBaseUrl/networking/connections/$connectionId/respond',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
        data: {'accept': accept},
      );
    });
  }

  @override
  Future<Result<void>> withdrawConnection(String connectionId) {
    return _call('Could not update this connection. Try again in a moment.', (
      token,
    ) async {
      await _dio.post<Object?>(
        '$_apiBaseUrl/networking/connections/$connectionId/withdraw',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    });
  }

  @override
  Future<Result<void>> blockCandidate(String candidateId) {
    return _call('Could not block this candidate. Try again in a moment.', (
      token,
    ) async {
      await _dio.post<Object?>(
        '$_apiBaseUrl/networking/blocks',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
        data: {'candidateId': candidateId},
      );
    });
  }

  @override
  Future<Result<void>> unblockCandidate(String candidateId) {
    return _call('Could not unblock this candidate. Try again in a moment.', (
      token,
    ) async {
      await _dio.delete<Object?>(
        '$_apiBaseUrl/networking/blocks/$candidateId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    });
  }

  /// Shared request scaffolding every method above uses: check for a
  /// session, run the call, map any failure the same way
  /// `ApiResumeParsingRepository._mapError` does. Kept as one place so
  /// all seven endpoints fail the same honest way instead of seven
  /// slightly-different copies.
  Future<Result<T>> _call<T>(
    String fallbackMessage,
    Future<T> Function(String accessToken) run,
  ) async {
    final accessToken = _supabaseClient.auth.currentSession?.accessToken;
    if (accessToken == null) {
      return const ResultFailure(
        AuthenticationFailure('Sign in again to continue.'),
      );
    }
    try {
      return Success(await run(accessToken));
    } on DioException catch (error, stackTrace) {
      return ResultFailure(_mapError(error, stackTrace, fallbackMessage));
    } catch (error, stackTrace) {
      return ResultFailure(
        UnexpectedFailure(
          fallbackMessage,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  NetworkingProfile _profileFromJson(Map<Object?, Object?> json) {
    return NetworkingProfile(
      discoverable: json['discoverable'] == true,
      fullName: json['fullName'] as String? ?? '',
      headline: json['headline'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      preferredRoles: _stringList(json['preferredRoles']),
    );
  }

  DiscoveredCandidate _discoveredFromJson(Map<Object?, Object?> json) {
    return DiscoveredCandidate(
      candidateId: json['candidateId'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      headline: json['headline'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      sharedRoles: _stringList(json['sharedRoles']),
    );
  }

  List<ConnectionSummary> _summaryListFromJson(Object? value) {
    if (value is! List) return const [];
    return [
      for (final entry in value)
        if (entry is Map) _summaryFromJson(entry),
    ];
  }

  ConnectionSummary _summaryFromJson(Map<Object?, Object?> json) {
    final otherCandidate = json['otherCandidate'];
    final createdAt =
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now();
    return ConnectionSummary(
      id: json['id'] as String? ?? '',
      status: json['status'] == 'accepted'
          ? ConnectionStatus.accepted
          : ConnectionStatus.pending,
      direction: json['direction'] == 'outgoing'
          ? ConnectionDirection.outgoing
          : ConnectionDirection.incoming,
      otherCandidateId: json['otherCandidateId'] as String? ?? '',
      otherCandidate: otherCandidate is Map
          ? OtherCandidateSummary(
              fullName: otherCandidate['fullName'] as String? ?? '',
              headline: otherCandidate['headline'] as String? ?? '',
              city: otherCandidate['city'] as String? ?? '',
              state: otherCandidate['state'] as String? ?? '',
            )
          : null,
      createdAt: createdAt,
    );
  }

  List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return [
      for (final entry in value)
        if (entry is String) entry,
    ];
  }

  AppFailure _mapError(
    DioException error,
    StackTrace stackTrace,
    String fallbackMessage,
  ) {
    final status = error.response?.statusCode;
    final body = error.response?.data;
    final serverError = body is Map ? body['error'] : null;
    final serverMessage = serverError is Map ? serverError['message'] : null;
    final message = serverMessage is String ? serverMessage : fallbackMessage;

    if (status == 401) {
      return AuthenticationFailure(
        message,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    // 403 covers both "not discoverable"/"blocked" business rules and
    // rate-limiting -- same posture as ApiCoachRepository/
    // ApiResumeParsingRepository: PermissionFailure surfaces `.message`
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
