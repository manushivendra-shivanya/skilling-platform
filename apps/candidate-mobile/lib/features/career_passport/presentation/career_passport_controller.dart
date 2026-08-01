import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/career_passport.dart';
import '../domain/career_passport_repository.dart';

class CareerPassportState {
  const CareerPassportState({
    required this.entries,
    required this.isShareable,
    required this.canManageSharing,
    required this.shareLink,
    required this.canManageShareLink,
  });

  final List<CareerPassportEntry> entries;
  final bool isShareable;
  final bool canManageSharing;
  final ShareLink? shareLink;
  final bool canManageShareLink;

  CareerPassportState copyWith({
    bool? isShareable,
    Object? shareLink = _unset,
  }) => CareerPassportState(
    entries: entries,
    isShareable: isShareable ?? this.isShareable,
    canManageSharing: canManageSharing,
    shareLink: identical(shareLink, _unset)
        ? this.shareLink
        : shareLink as ShareLink?,
    canManageShareLink: canManageShareLink,
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
    final shareable = (await repository.isShareable(
      session.candidateId,
    )).when(success: (value) => value, failure: (failure) => throw failure);
    final shareLink = repository.canManageShareLink
        ? (await repository.loadShareLink(session.candidateId)).when(
            success: (value) => value,
            failure: (failure) => throw failure,
          )
        : null;
    return CareerPassportState(
      entries: deriveCareerPassportEntries(evidence, now: DateTime.now()),
      isShareable: shareable,
      canManageSharing: repository.canManageSharing,
      shareLink: shareLink,
      canManageShareLink: repository.canManageShareLink,
    );
  }

  Future<AppFailure?> toggleShareable() async {
    final value = state.valueOrNull;
    final candidateId = _candidateId;
    if (value == null || candidateId == null || !value.canManageSharing) {
      return const StorageFailure('Sharing requires an account connection.');
    }
    final next = !value.isShareable;
    final result = await ref
        .read(careerPassportRepositoryProvider)
        .setShareable(candidateId, next);
    return result.when(
      success: (_) {
        state = AsyncData(value.copyWith(isShareable: next));
        return null;
      },
      failure: (failure) => failure,
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

  void retry() => ref.invalidateSelf();
}
