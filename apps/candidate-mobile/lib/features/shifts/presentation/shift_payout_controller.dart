import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/shift_payout.dart';

final shiftPayoutControllerProvider =
    AsyncNotifierProvider<ShiftPayoutController, List<ShiftPayout>>(
      ShiftPayoutController.new,
    );

class ShiftPayoutController extends AsyncNotifier<List<ShiftPayout>> {
  @override
  Future<List<ShiftPayout>> build() async {
    final session =
        (await ref.read(candidateSessionRepositoryProvider).readSession()).when(
          success: (value) => value,
          failure: (failure) => throw failure,
        );
    if (session == null || !session.isAuthenticated) {
      throw const AuthenticationFailure('Sign in again to view payouts.');
    }
    // watch, not read: shiftPayoutRepositoryProvider switches from an
    // unavailable stub to Supabase once canUseLiveBackendProvider flips true
    // right after sign-in -- a `read` would leave this controller stuck.
    return (await ref
            .watch(shiftPayoutRepositoryProvider)
            .loadPayouts(session.candidateId))
        .when(success: (value) => value, failure: (failure) => throw failure);
  }

  void retry() => ref.invalidateSelf();
}
