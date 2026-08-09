import 'package:dio/dio.dart';

/// Pings the BFF's unauthenticated `/health` route to wake a cold instance
/// as early as possible -- specifically for a Render Free-tier deployment,
/// which spins the whole container down after a period of inactivity and
/// can take up to roughly a minute to come back on the next request.
/// Fire-and-forget by design: the physical container wakes up whether or
/// not anything is still listening for the response, so failures/timeouts
/// here are swallowed rather than surfaced as a user-facing error.
class BackendWarmupService {
  const BackendWarmupService();

  /// Generous timeout -- long enough to actually observe a cold Render
  /// Free instance finish booting, not just to observe a fast local/warm
  /// response.
  static const _timeout = Duration(seconds: 75);

  Future<bool> ping({required Dio dio, required String apiBaseUrl}) async {
    try {
      final response = await dio.get<Object?>(
        '$apiBaseUrl/health',
        options: Options(
          sendTimeout: _timeout,
          receiveTimeout: _timeout,
          validateStatus: (_) => true,
        ),
      );
      return response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300;
    } catch (_) {
      return false;
    }
  }
}
