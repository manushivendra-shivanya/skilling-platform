import '../../../core/errors/result.dart';
import '../domain/detailed_candidate_profile.dart';
import '../domain/detailed_profile_repository.dart';

/// Dev/test fallback when no live Supabase backend is configured --
/// same role `InMemoryCandidateOnboardingRepository` plays for onboarding.
/// Holds one profile per session, not persisted across app restarts: the
/// live `SupabaseDetailedProfileRepository` is this feature's primary
/// path (there is no "offline-first, syncs later" requirement here the
/// way onboarding's secure-storage fallback has), so this only needs to
/// make the screen fully usable in dev/tests, not survive a restart.
class InMemoryDetailedProfileRepository implements DetailedProfileRepository {
  InMemoryDetailedProfileRepository({DetailedCandidateProfile? initialProfile})
    : _profile = initialProfile ?? DetailedCandidateProfile.empty;

  DetailedCandidateProfile _profile;

  DetailedCandidateProfile get profile => _profile;

  @override
  Future<Result<DetailedCandidateProfile>> load(String candidateId) async =>
      Success(_profile);

  @override
  Future<Result<void>> saveContactAndSkills(
    String candidateId, {
    required String phone,
    required String email,
    required List<String> skills,
  }) async {
    _profile = DetailedCandidateProfile(
      phone: phone,
      email: email,
      skills: skills,
      workExperience: _profile.workExperience,
      education: _profile.education,
      certifications: _profile.certifications,
      projects: _profile.projects,
    );
    return const Success(null);
  }

  @override
  Future<Result<void>> upsertWorkExperience(
    String candidateId,
    WorkExperienceEntry entry,
  ) async {
    _profile = DetailedCandidateProfile(
      phone: _profile.phone,
      email: _profile.email,
      skills: _profile.skills,
      workExperience: _upsertInList(
        _profile.workExperience,
        entry,
        (e) => e.id,
        (id) => entry.copyWith(id: id),
      ),
      education: _profile.education,
      certifications: _profile.certifications,
      projects: _profile.projects,
    );
    return const Success(null);
  }

  @override
  Future<Result<void>> deleteWorkExperience(
    String candidateId,
    String id,
  ) async {
    _profile = DetailedCandidateProfile(
      phone: _profile.phone,
      email: _profile.email,
      skills: _profile.skills,
      workExperience: _profile.workExperience.where((e) => e.id != id).toList(),
      education: _profile.education,
      certifications: _profile.certifications,
      projects: _profile.projects,
    );
    return const Success(null);
  }

  @override
  Future<Result<void>> upsertEducation(
    String candidateId,
    EducationEntry entry,
  ) async {
    _profile = DetailedCandidateProfile(
      phone: _profile.phone,
      email: _profile.email,
      skills: _profile.skills,
      workExperience: _profile.workExperience,
      education: _upsertInList(
        _profile.education,
        entry,
        (e) => e.id,
        (id) => entry.copyWith(id: id),
      ),
      certifications: _profile.certifications,
      projects: _profile.projects,
    );
    return const Success(null);
  }

  @override
  Future<Result<void>> deleteEducation(String candidateId, String id) async {
    _profile = DetailedCandidateProfile(
      phone: _profile.phone,
      email: _profile.email,
      skills: _profile.skills,
      workExperience: _profile.workExperience,
      education: _profile.education.where((e) => e.id != id).toList(),
      certifications: _profile.certifications,
      projects: _profile.projects,
    );
    return const Success(null);
  }

  @override
  Future<Result<void>> upsertCertification(
    String candidateId,
    ExternalCertificationEntry entry,
  ) async {
    _profile = DetailedCandidateProfile(
      phone: _profile.phone,
      email: _profile.email,
      skills: _profile.skills,
      workExperience: _profile.workExperience,
      education: _profile.education,
      certifications: _upsertInList(
        _profile.certifications,
        entry,
        (e) => e.id,
        (id) => entry.copyWith(id: id),
      ),
      projects: _profile.projects,
    );
    return const Success(null);
  }

  @override
  Future<Result<void>> deleteCertification(
    String candidateId,
    String id,
  ) async {
    _profile = DetailedCandidateProfile(
      phone: _profile.phone,
      email: _profile.email,
      skills: _profile.skills,
      workExperience: _profile.workExperience,
      education: _profile.education,
      certifications: _profile.certifications.where((e) => e.id != id).toList(),
      projects: _profile.projects,
    );
    return const Success(null);
  }

  @override
  Future<Result<void>> upsertProject(
    String candidateId,
    ProjectEntry entry,
  ) async {
    _profile = DetailedCandidateProfile(
      phone: _profile.phone,
      email: _profile.email,
      skills: _profile.skills,
      workExperience: _profile.workExperience,
      education: _profile.education,
      certifications: _profile.certifications,
      projects: _upsertInList(
        _profile.projects,
        entry,
        (e) => e.id,
        (id) => entry.copyWith(id: id),
      ),
    );
    return const Success(null);
  }

  @override
  Future<Result<void>> deleteProject(String candidateId, String id) async {
    _profile = DetailedCandidateProfile(
      phone: _profile.phone,
      email: _profile.email,
      skills: _profile.skills,
      workExperience: _profile.workExperience,
      education: _profile.education,
      certifications: _profile.certifications,
      projects: _profile.projects.where((e) => e.id != id).toList(),
    );
    return const Success(null);
  }

  /// Inserts (assigning a fake incrementing id when [entry] arrives with
  /// an empty one, mirroring the real repository's server-assigned id) or
  /// replaces by id -- the same insert-vs-update rule
  /// `SupabaseDetailedProfileRepository._upsert` uses.
  List<T> _upsertInList<T>(
    List<T> current,
    T entry,
    String Function(T) idOf,
    T Function(String id) withGeneratedId,
  ) {
    final id = idOf(entry);
    if (id.isEmpty) {
      final generatedId = 'local-${DateTime.now().microsecondsSinceEpoch}';
      return [...current, withGeneratedId(generatedId)];
    }
    final index = current.indexWhere((e) => idOf(e) == id);
    if (index == -1) return [...current, entry];
    final updated = [...current];
    updated[index] = entry;
    return updated;
  }
}
