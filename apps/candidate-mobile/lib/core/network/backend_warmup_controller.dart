import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/dependencies.dart';
import 'backend_warmup_service.dart';

/// Fires once per app session, as soon as something watches it -- wired up
/// from [BackendWarmupBanner] on the sign-in screen, so the ping goes out
/// the moment a candidate starts signing in rather than waiting for the
/// first real, auth-guarded request later on. `true` means the BFF
/// answered; `false` means it didn't within the generous timeout (treated
/// as "give up waiting on this indicator", not a user-facing error --
/// whatever screen actually needs the backend next will surface its own
/// error if the backend is still unreachable).
final backendWarmupControllerProvider =
    AsyncNotifierProvider<BackendWarmupController, bool>(
      BackendWarmupController.new,
    );

class BackendWarmupController extends AsyncNotifier<bool> {
  static const _service = BackendWarmupService();

  @override
  Future<bool> build() async {
    final config = ref.read(appConfigProvider);
    if (!config.hasApiConfiguration) {
      // Local-mock mode: no real backend to wake up.
      return true;
    }
    return _service.ping(dio: Dio(), apiBaseUrl: config.apiBaseUrl);
  }
}
