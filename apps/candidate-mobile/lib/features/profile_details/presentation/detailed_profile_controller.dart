import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/detailed_candidate_profile.dart';

final detailedProfileControllerProvider =
    AsyncNotifierProvider<DetailedProfileController, DetailedCandidateProfile>(
      DetailedProfileController.new,
    );

/// Every mutation method reloads from the repository afterward rather than
/// hand-splicing the change into local state -- simpler, and correct by
/// construction for entries whose id is server-assigned on first insert
/// (a hand-spliced "add" would show the entry with no real id until the
/// next reload anyway).
class DetailedProfileController
    extends AsyncNotifier<DetailedCandidateProfile> {
  String? _candidateId;

  @override
  Future<DetailedCandidateProfile> build() async {
    final sessionResult = await ref
        .read(candidateSessionRepositoryProvider)
        .readSession();
    final session = sessionResult.when(
      success: (value) => value,
      failure: (failure) => throw failure,
    );
    if (session == null || !session.isAuthenticated) {
      throw const AuthenticationFailure('Sign in again to view your profile.');
    }
    _candidateId = session.candidateId;

    // watch, not read: see candidateOnboardingControllerProvider's own
    // comment on why -- detailedProfileRepositoryProvider switches from
    // in-memory to Supabase the same way once live backend becomes
    // available.
    final result = await ref
        .watch(detailedProfileRepositoryProvider)
        .load(session.candidateId);
    return result.when(
      success: (profile) => profile,
      failure: (failure) => throw failure,
    );
  }

  Future<AppFailure?> _mutate(
    Future<Result<void>> Function(String candidateId) action,
  ) async {
    final candidateId = _candidateId;
    if (candidateId == null) {
      return const AuthenticationFailure('Sign in again to view your profile.');
    }
    final result = await action(candidateId);
    final failure = result.when(
      success: (_) => null,
      failure: (failure) => failure,
    );
    if (failure != null) return failure;

    final reload = await ref
        .read(detailedProfileRepositoryProvider)
        .load(candidateId);
    reload.when(
      success: (profile) => state = AsyncData(profile),
      // The write above already succeeded -- a reload failure shouldn't
      // discard that success and show an error for something that worked.
      failure: (_) {},
    );
    return null;
  }

  Future<AppFailure?> saveContactAndSkills({
    required String phone,
    required String email,
    required List<String> skills,
  }) => _mutate(
    (candidateId) => ref
        .read(detailedProfileRepositoryProvider)
        .saveContactAndSkills(
          candidateId,
          phone: phone,
          email: email,
          skills: skills,
        ),
  );

  Future<AppFailure?> saveProfileBasics({
    required String headline,
    required String summary,
    required String totalExperience,
  }) => _mutate(
    (candidateId) => ref
        .read(detailedProfileRepositoryProvider)
        .saveProfileBasics(
          candidateId,
          headline: headline,
          summary: summary,
          totalExperience: totalExperience,
        ),
  );

  Future<AppFailure?> saveCareerPreferences(CareerPreferences preferences) =>
      _mutate(
        (candidateId) => ref
            .read(detailedProfileRepositoryProvider)
            .saveCareerPreferences(candidateId, preferences),
      );

  Future<AppFailure?> saveLanguage(LanguageEntry entry) => _mutate(
    (candidateId) => ref
        .read(detailedProfileRepositoryProvider)
        .upsertLanguage(candidateId, entry),
  );

  Future<AppFailure?> deleteLanguage(String id) => _mutate(
    (candidateId) => ref
        .read(detailedProfileRepositoryProvider)
        .deleteLanguage(candidateId, id),
  );

  Future<AppFailure?> saveWorkExperience(WorkExperienceEntry entry) => _mutate(
    (candidateId) => ref
        .read(detailedProfileRepositoryProvider)
        .upsertWorkExperience(candidateId, entry),
  );

  Future<AppFailure?> deleteWorkExperience(String id) => _mutate(
    (candidateId) => ref
        .read(detailedProfileRepositoryProvider)
        .deleteWorkExperience(candidateId, id),
  );

  Future<AppFailure?> saveEducation(EducationEntry entry) => _mutate(
    (candidateId) => ref
        .read(detailedProfileRepositoryProvider)
        .upsertEducation(candidateId, entry),
  );

  Future<AppFailure?> deleteEducation(String id) => _mutate(
    (candidateId) => ref
        .read(detailedProfileRepositoryProvider)
        .deleteEducation(candidateId, id),
  );

  Future<AppFailure?> saveCertification(ExternalCertificationEntry entry) =>
      _mutate(
        (candidateId) => ref
            .read(detailedProfileRepositoryProvider)
            .upsertCertification(candidateId, entry),
      );

  Future<AppFailure?> deleteCertification(String id) => _mutate(
    (candidateId) => ref
        .read(detailedProfileRepositoryProvider)
        .deleteCertification(candidateId, id),
  );

  Future<AppFailure?> saveProject(ProjectEntry entry) => _mutate(
    (candidateId) => ref
        .read(detailedProfileRepositoryProvider)
        .upsertProject(candidateId, entry),
  );

  Future<AppFailure?> deleteProject(String id) => _mutate(
    (candidateId) => ref
        .read(detailedProfileRepositoryProvider)
        .deleteProject(candidateId, id),
  );

  void retry() => ref.invalidateSelf();
}
