import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/career_passport.dart';
import '../domain/career_passport_repository.dart';

class CareerPassportState {
  const CareerPassportState({
    required this.entries,
    required this.shareLink,
    required this.canManageShareLink,
    required this.employerAccess,
    required this.canManageEmployerAccess,
  });

  final List<CareerPassportEntry> entries;
  final ShareLink? shareLink;
  final bool canManageShareLink;
  final List<EmployerAccessEntry> employerAccess;
  final bool canManageEmployerAccess;

  CareerPassportState copyWith({
    Object? shareLink = _unset,
    List<EmployerAccessEntry>? employerAccess,
  }) => CareerPassportState(
    entries: entries,
    shareLink: identical(shareLink, _unset)
        ? this.shareLink
        : shareLink as ShareLink?,
    canManageShareLink: canManageShareLink,
    employerAccess: employerAccess ?? this.employerAccess,
    canManageEmployerAccess: canManageEmployerAccess,
  );
}

const _unset = Object();

final careerPassportControllerProvider =
    AsyncNotifierProvider<CareerPassportController, CareerPassportState>(
      CareerPassportController.new,
    );

class CareerPassportController extends AsyncNotifier<CareerPassportState> {
  String? _candidateId;

  @override
  Future<CareerPassportState> build() async {
    final session =
        (await ref.read(candidateSessionRepositoryProvider).readSession()).when(
          success: (value) => value,
          failure: (failure) => throw failure,
        );
    if (session == null || !session.isAuthenticated) {
      throw const AuthenticationFailure(
        'Sign in again to view your Career Passport.',
      );
    }
    _candidateId = session.candidateId;
    final repository = ref.read(careerPassportRepositoryProvider);
    final evidence = (await repository.loadEvidence(
      session.candidateId,
    )).when(success: (value) => value, failure: (failure) => throw failure);
    final shareLink = repository.canManageShareLink
        ? (await repository.loadShareLink(session.candidateId)).when(
            success: (value) => value,
            failure: (failure) => throw failure,
          )
        : null;
    final employerAccess = repository.canManageEmployerAccess
        ? (await repository.loadEmployerAccess(session.candidateId)).when(
            success: (value) => value,
            failure: (failure) => throw failure,
          )
        : const <EmployerAccessEntry>[];
    return CareerPassportState(
      entries: deriveCareerPassportEntries(evidence, now: DateTime.now()),
      shareLink: shareLink,
      canManageShareLink: repository.canManageShareLink,
      employerAccess: employerAccess,
      canManageEmployerAccess: repository.canManageEmployerAccess,
    );
  }

  Future<AppFailure?> generateShareLink() async {
    final value = state.valueOrNull;
    final candidateId = _candidateId;
    if (value == null || candidateId == null || !value.canManageShareLink) {
      return const StorageFailure('Share links require an account connection.');
    }
    final result = await ref
        .read(careerPassportRepositoryProvider)
        .createShareLink(candidateId);
    return result.when(
      success: (link) {
        state = AsyncData(value.copyWith(shareLink: link));
        return null;
      },
      failure: (failure) => failure,
    );
  }

  Future<AppFailure?> revokeShareLink() async {
    final value = state.valueOrNull;
    final candidateId = _candidateId;
    if (value == null || candidateId == null || !value.canManageShareLink) {
      return const StorageFailure('Share links require an account connection.');
    }
    final result = await ref
        .read(careerPassportRepositoryProvider)
        .revokeShareLink(candidateId);
    return result.when(
      success: (_) {
        state = AsyncData(value.copyWith(shareLink: null));
        return null;
      },
      failure: (failure) => failure,
    );
  }

  Future<AppFailure?> toggleEmployerAccess(EmployerAccessEntry entry) async {
    final value = state.valueOrNull;
    final candidateId = _candidateId;
    if (value == null ||
        candidateId == null ||
        !value.canManageEmployerAccess) {
      return const StorageFailure(
        'Employer access requires an account connection.',
      );
    }
    final repository = ref.read(careerPassportRepositoryProvider);
    final result = entry.granted
        ? await repository.revokeEmployerAccess(candidateId, entry.employerId)
        : await repository.grantEmployerAccess(candidateId, entry.employerId);
    return result.when(
      success: (_) {
        state = AsyncData(
          value.copyWith(
            employerAccess: [
              for (final item in value.employerAccess)
                if (item.employerId == entry.employerId)
                  EmployerAccessEntry(
                    employerId: item.employerId,
                    employerName: item.employerName,
                    granted: !item.granted,
                  )
                else
                  item,
            ],
          ),
        );
        return null;
      },
      failure: (failure) => failure,
    );
  }

  void retry() => ref.invalidateSelf();
}
