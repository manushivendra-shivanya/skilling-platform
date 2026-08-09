import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../core/errors/app_failure.dart';
import '../../career_passport/domain/career_passport.dart';
import '../../career_passport/presentation/career_passport_controller.dart';
import '../domain/shift_match.dart';
import '../domain/shifts_repository.dart';

class ShiftsState {
  const ShiftsState({
    required this.shifts,
    required this.myApplications,
    required this.matchByShiftId,
    required this.isLiveData,
  });

  final List<Shift> shifts;
  final List<ShiftApplication> myApplications;
  final Map<String, ShiftMatch> matchByShiftId;
  final bool isLiveData;

  ShiftMatch matchFor(String shiftId) =>
      matchByShiftId[shiftId] ??
      const ShiftMatch(matchPercent: 0, missingCompetencyIds: []);

  ShiftApplication? applicationFor(String shiftId) {
    for (final application in myApplications) {
      if (application.shiftId == shiftId) return application;
    }
    return null;
  }

  ShiftsState copyWith({List<ShiftApplication>? myApplications}) => ShiftsState(
    shifts: shifts,
    myApplications: myApplications ?? this.myApplications,
    matchByShiftId: matchByShiftId,
    isLiveData: isLiveData,
  );
}

final shiftsControllerProvider =
    AsyncNotifierProvider<ShiftsController, ShiftsState>(ShiftsController.new);

class ShiftsController extends AsyncNotifier<ShiftsState> {
  String? _candidateId;

  @override
  Future<ShiftsState> build() async {
    final session =
        (await ref.read(candidateSessionRepositoryProvider).readSession()).when(
          success: (value) => value,
          failure: (failure) => throw failure,
        );
    if (session == null || !session.isAuthenticated) {
      throw const AuthenticationFailure('Sign in again to view shifts.');
    }
    _candidateId = session.candidateId;
    final repository = ref.read(shiftsRepositoryProvider);
    final shifts = (await repository.loadPublishedShifts()).when(
      success: (value) => value,
      failure: (failure) => throw failure,
    );
    final myApplications = (await repository.loadMyApplications(
      session.candidateId,
    )).when(success: (value) => value, failure: (failure) => throw failure);

    // Career Passport may still be loading or unavailable -- match% simply
    // degrades to 0 rather than blocking the shift catalogue on it, since
    // browsing shifts shouldn't depend on Career Passport being ready.
    // `.future` (not a bare `ref.watch(...).valueOrNull` snapshot) properly
    // awaits the other controller's own build to finish rather than
    // reading whatever state it happened to be in at this exact instant --
    // reading a bare snapshot after this method's own earlier awaits left
    // this provider's build never settling in practice.
    final entries = await ref
        .watch(careerPassportControllerProvider.future)
        .then((state) => state.entries)
        .catchError((_) => const <CareerPassportEntry>[]);

    return ShiftsState(
      shifts: shifts,
      myApplications: myApplications,
      matchByShiftId: {
        for (final shift in shifts)
          shift.id: deriveShiftMatch(entries, shift.requiredCompetencyIds),
      },
      isLiveData: repository.isLiveData,
    );
  }

  Future<AppFailure?> acceptShift(String shiftId) async {
    final value = state.valueOrNull;
    final candidateId = _candidateId;
    if (value == null || candidateId == null) {
      return const StorageFailure('Shifts are still loading.');
    }
    final result = await ref
        .read(shiftsRepositoryProvider)
        .acceptShift(candidateId, shiftId);
    return result.when(
      success: (application) {
        state = AsyncData(
          value.copyWith(
            myApplications: [
              for (final existing in value.myApplications)
                if (existing.shiftId != shiftId) existing,
              application,
            ],
          ),
        );
        return null;
      },
      failure: (failure) => failure,
    );
  }

  Future<AppFailure?> checkIn(String applicationId, String code) async {
    final value = state.valueOrNull;
    if (value == null) return const StorageFailure('Shifts are still loading.');
    final result = await ref
        .read(shiftsRepositoryProvider)
        .checkIn(applicationId, code);
    return result.when(
      success: (application) {
        state = AsyncData(
          value.copyWith(myApplications: _replace(value, application)),
        );
        return null;
      },
      failure: (failure) => failure,
    );
  }

  Future<AppFailure?> checkOut(String applicationId) async {
    final value = state.valueOrNull;
    if (value == null) return const StorageFailure('Shifts are still loading.');
    final result = await ref
        .read(shiftsRepositoryProvider)
        .checkOut(applicationId);
    return result.when(
      success: (application) {
        state = AsyncData(
          value.copyWith(myApplications: _replace(value, application)),
        );
        return null;
      },
      failure: (failure) => failure,
    );
  }

  List<ShiftApplication> _replace(
    ShiftsState value,
    ShiftApplication updated,
  ) => [
    for (final existing in value.myApplications)
      if (existing.id == updated.id) updated else existing,
  ];

  void retry() => ref.invalidateSelf();
}
