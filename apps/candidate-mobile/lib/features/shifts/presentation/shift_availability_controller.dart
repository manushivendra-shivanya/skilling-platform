import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/shift_availability.dart';

final shiftAvailabilityControllerProvider =
    AsyncNotifierProvider<ShiftAvailabilityController, ShiftAvailability>(
      ShiftAvailabilityController.new,
    );

class ShiftAvailabilityController extends AsyncNotifier<ShiftAvailability> {
  String? _candidateId;

  @override
  Future<ShiftAvailability> build() async {
    final session =
        (await ref.read(candidateSessionRepositoryProvider).readSession()).when(
          success: (value) => value,
          failure: (failure) => throw failure,
        );
    if (session == null || !session.isAuthenticated) {
      throw const AuthenticationFailure('Sign in again to view availability.');
    }
    _candidateId = session.candidateId;
    return (await ref
            .read(shiftAvailabilityRepositoryProvider)
            .readAvailability(session.candidateId))
        .when(success: (value) => value, failure: (failure) => throw failure);
  }

  Future<AppFailure?> save(ShiftAvailability availability) async {
    final candidateId = _candidateId;
    if (candidateId == null) {
      return const StorageFailure('Availability is still loading.');
    }
    final result = await ref
        .read(shiftAvailabilityRepositoryProvider)
        .saveAvailability(candidateId, availability);
    return result.when(
      success: (_) {
        state = AsyncData(availability);
        return null;
      },
      failure: (failure) => failure,
    );
  }
}
