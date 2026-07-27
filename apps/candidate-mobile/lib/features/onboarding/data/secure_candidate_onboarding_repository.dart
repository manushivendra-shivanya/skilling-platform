import 'dart:convert';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/storage/secure_key_value_store.dart';
import '../domain/candidate_onboarding_draft.dart';
import '../domain/candidate_onboarding_repository.dart';

class SecureCandidateOnboardingRepository
    implements CandidateOnboardingRepository {
  SecureCandidateOnboardingRepository(this._store);

  static const _keyPrefix = 'candidate.onboarding_draft.v1.';

  final SecureKeyValueStore _store;

  @override
  Future<Result<CandidateOnboardingDraft>> readDraft(String candidateId) async {
    try {
      final encodedDraft = await _store.read(_keyFor(candidateId));
      if (encodedDraft == null) {
        return const Success(CandidateOnboardingDraft());
      }
      final decodedDraft = jsonDecode(encodedDraft);
      if (decodedDraft is! Map<String, Object?>) {
        throw const FormatException('Invalid candidate onboarding draft');
      }
      return Success(CandidateOnboardingDraft.fromJson(decodedDraft));
    } catch (error, stackTrace) {
      return ResultFailure(
        StorageFailure(
          'We could not restore your saved profile. Please try again.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> saveDraft(
    String candidateId,
    CandidateOnboardingDraft draft,
  ) async {
    try {
      await _store.write(_keyFor(candidateId), jsonEncode(draft.toJson()));
      return const Success(null);
    } catch (error, stackTrace) {
      return ResultFailure(
        StorageFailure(
          'We could not save your profile on this device. Please try again.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  String _keyFor(String candidateId) {
    final safeCandidateId = candidateId.replaceAll(
      RegExp('[^a-zA-Z0-9_-]'),
      '_',
    );
    return '$_keyPrefix$safeCandidateId';
  }
}

class InMemoryCandidateOnboardingRepository
    implements CandidateOnboardingRepository {
  InMemoryCandidateOnboardingRepository({
    CandidateOnboardingDraft? initialDraft,
  }) : _draft = initialDraft ?? const CandidateOnboardingDraft();

  CandidateOnboardingDraft _draft;

  CandidateOnboardingDraft get draft => _draft;

  @override
  Future<Result<CandidateOnboardingDraft>> readDraft(String candidateId) async {
    return Success(_draft);
  }

  @override
  Future<Result<void>> saveDraft(
    String candidateId,
    CandidateOnboardingDraft draft,
  ) async {
    _draft = draft;
    return const Success(null);
  }
}
