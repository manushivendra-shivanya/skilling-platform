import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/shift_grievance.dart';

final shiftGrievanceControllerProvider =
    AsyncNotifierProvider<ShiftGrievanceController, List<ShiftGrievance>>(
      ShiftGrievanceController.new,
    );

class ShiftGrievanceController extends AsyncNotifier<List<ShiftGrievance>> {
  String? _candidateId;

  @override
  Future<List<ShiftGrievance>> build() async {
    final session =
        (await ref.read(candidateSessionRepositoryProvider).readSession()).when(
          success: (value) => value,
          failure: (failure) => throw failure,
        );
    if (session == null || !session.isAuthenticated) {
      throw const AuthenticationFailure('Sign in again to view grievances.');
    }
    _candidateId = session.candidateId;
    // watch, not read: shiftGrievanceRepositoryProvider switches from an
    // unavailable stub to Supabase once canUseLiveBackendProvider flips true
    // right after sign-in -- a `read` would leave this controller stuck.
    return (await ref
            .watch(shiftGrievanceRepositoryProvider)
            .loadGrievances(session.candidateId))
        .when(success: (value) => value, failure: (failure) => throw failure);
  }

  Future<AppFailure?> submit({
    required ShiftGrievanceCategory category,
    required String description,
    String? shiftApplicationId,
  }) async {
    final candidateId = _candidateId;
    if (candidateId == null) {
      return const StorageFailure('Grievances are still loading.');
    }
    final result = await ref
        .read(shiftGrievanceRepositoryProvider)
        .submitGrievance(
          candidateId,
          category: category,
          description: description,
          shiftApplicationId: shiftApplicationId,
        );
    return result.when(
      success: (_) {
        ref.invalidateSelf();
        return null;
      },
      failure: (failure) => failure,
    );
  }
}
