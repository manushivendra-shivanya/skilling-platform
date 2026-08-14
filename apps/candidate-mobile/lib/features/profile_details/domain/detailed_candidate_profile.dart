/// A month-of-year value, 1-12. Stored as a plain `int?` throughout this
/// feature rather than a `DateTime` -- a resume or a candidate's own memory
/// rarely supplies a day, and a `DateTime` would force one to be
/// invented. Year alone (`startYear`/`endYear` with a null month) is a
/// valid, common case, e.g. an older resume that lists "2019 - 2023" for
/// a degree without months.
library;

/// One entry in the candidate's Experience section.
///
/// Mirrors `candidate_work_experience` (see
/// `supabase/migrations/20260814140000_candidate_detailed_profile.sql`).
class WorkExperienceEntry {
  const WorkExperienceEntry({
    required this.id,
    required this.title,
    required this.company,
    this.location = '',
    this.startMonth,
    this.startYear,
    this.endMonth,
    this.endYear,
    this.isCurrent = false,
    this.description = '',
    this.sequence = 0,
  });

  /// Empty for an entry not yet saved -- the repository assigns a real id
  /// on first insert.
  final String id;
  final String title;
  final String company;
  final String location;
  final int? startMonth;
  final int? startYear;
  final int? endMonth;
  final int? endYear;

  /// True hides the end date entirely in the UI ("Present"), and the
  /// repository writes end_month/end_year as null regardless of what they
  /// hold locally -- a stale end date under a current role should never
  /// round-trip back from the server.
  final bool isCurrent;
  final String description;

  /// Candidate-controlled display order, not a timestamp-derived sort --
  /// see the migration's own comment on why.
  final int sequence;

  WorkExperienceEntry copyWith({
    String? id,
    String? title,
    String? company,
    String? location,
    int? startMonth,
    int? startYear,
    int? endMonth,
    int? endYear,
    bool? isCurrent,
    String? description,
    int? sequence,
  }) {
    return WorkExperienceEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      company: company ?? this.company,
      location: location ?? this.location,
      startMonth: startMonth ?? this.startMonth,
      startYear: startYear ?? this.startYear,
      endMonth: endMonth ?? this.endMonth,
      endYear: endYear ?? this.endYear,
      isCurrent: isCurrent ?? this.isCurrent,
      description: description ?? this.description,
      sequence: sequence ?? this.sequence,
    );
  }
}

/// One entry in the candidate's Education section.
///
/// [degree] and [fieldOfStudy] are deliberately separate fields, not one
/// free-text string -- this is what lets an abbreviation like "BTech CS"
/// be interpreted into `degree: "Bachelor of Technology"` /
/// `fieldOfStudy: "Computer Science"` and displayed/searched as two
/// structured values, rather than kept as opaque verbatim text. See the
/// migration's own comment for the same reasoning.
class EducationEntry {
  const EducationEntry({
    required this.id,
    required this.institution,
    this.degree = '',
    this.fieldOfStudy = '',
    this.startYear,
    this.endYear,
    this.grade = '',
    this.description = '',
    this.sequence = 0,
  });

  final String id;
  final String institution;
  final String degree;
  final String fieldOfStudy;
  final int? startYear;
  final int? endYear;
  final String grade;
  final String description;
  final int sequence;

  EducationEntry copyWith({
    String? id,
    String? institution,
    String? degree,
    String? fieldOfStudy,
    int? startYear,
    int? endYear,
    String? grade,
    String? description,
    int? sequence,
  }) {
    return EducationEntry(
      id: id ?? this.id,
      institution: institution ?? this.institution,
      degree: degree ?? this.degree,
      fieldOfStudy: fieldOfStudy ?? this.fieldOfStudy,
      startYear: startYear ?? this.startYear,
      endYear: endYear ?? this.endYear,
      grade: grade ?? this.grade,
      description: description ?? this.description,
      sequence: sequence ?? this.sequence,
    );
  }
}

/// A certification the candidate already held before joining this
/// platform -- reported via resume or manual entry.
///
/// Deliberately distinct from `CertificationExamAttempt` (this platform's
/// own in-app skill exams, e.g. WMS certification): different meaning,
/// different table (`candidate_external_certifications`, not
/// `certification_exam_attempts`). Never conflate the two -- a candidate's
/// "Google IT Support Certificate" from their resume and a passed WMS
/// exam attempt are not the same kind of fact.
class ExternalCertificationEntry {
  const ExternalCertificationEntry({
    required this.id,
    required this.name,
    this.issuingOrganization = '',
    this.issueMonth,
    this.issueYear,
    this.expiryMonth,
    this.expiryYear,
    this.credentialId = '',
    this.credentialUrl = '',
    this.sequence = 0,
  });

  final String id;
  final String name;
  final String issuingOrganization;
  final int? issueMonth;
  final int? issueYear;
  final int? expiryMonth;
  final int? expiryYear;
  final String credentialId;
  final String credentialUrl;
  final int sequence;

  ExternalCertificationEntry copyWith({
    String? id,
    String? name,
    String? issuingOrganization,
    int? issueMonth,
    int? issueYear,
    int? expiryMonth,
    int? expiryYear,
    String? credentialId,
    String? credentialUrl,
    int? sequence,
  }) {
    return ExternalCertificationEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      issuingOrganization: issuingOrganization ?? this.issuingOrganization,
      issueMonth: issueMonth ?? this.issueMonth,
      issueYear: issueYear ?? this.issueYear,
      expiryMonth: expiryMonth ?? this.expiryMonth,
      expiryYear: expiryYear ?? this.expiryYear,
      credentialId: credentialId ?? this.credentialId,
      credentialUrl: credentialUrl ?? this.credentialUrl,
      sequence: sequence ?? this.sequence,
    );
  }
}

/// One entry in the candidate's Projects section.
class ProjectEntry {
  const ProjectEntry({
    required this.id,
    required this.title,
    this.role = '',
    this.description = '',
    this.startMonth,
    this.startYear,
    this.endMonth,
    this.endYear,
    this.isOngoing = false,
    this.url = '',
    this.skillsUsed = const [],
    this.sequence = 0,
  });

  final String id;
  final String title;
  final String role;
  final String description;
  final int? startMonth;
  final int? startYear;
  final int? endMonth;
  final int? endYear;
  final bool isOngoing;
  final String url;
  final List<String> skillsUsed;
  final int sequence;

  ProjectEntry copyWith({
    String? id,
    String? title,
    String? role,
    String? description,
    int? startMonth,
    int? startYear,
    int? endMonth,
    int? endYear,
    bool? isOngoing,
    String? url,
    List<String>? skillsUsed,
    int? sequence,
  }) {
    return ProjectEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      role: role ?? this.role,
      description: description ?? this.description,
      startMonth: startMonth ?? this.startMonth,
      startYear: startYear ?? this.startYear,
      endMonth: endMonth ?? this.endMonth,
      endYear: endYear ?? this.endYear,
      isOngoing: isOngoing ?? this.isOngoing,
      url: url ?? this.url,
      skillsUsed: skillsUsed ?? this.skillsUsed,
      sequence: sequence ?? this.sequence,
    );
  }
}

/// Everything on the LinkedIn-style detailed profile page, as one
/// aggregate -- the same "one load, not six" shape `HomeDashboard` already
/// uses, for the same reason: this screen renders all of it at once.
///
/// Unlike `HomeDashboard`, every field here is real, `candidate_profiles`/
/// `candidate_work_experience`/etc.-backed data (see
/// `SupabaseDetailedProfileRepository`) -- there is no mock-only
/// convention to document here.
class DetailedCandidateProfile {
  const DetailedCandidateProfile({
    required this.phone,
    required this.email,
    required this.skills,
    required this.workExperience,
    required this.education,
    required this.certifications,
    required this.projects,
  });

  static const empty = DetailedCandidateProfile(
    phone: '',
    email: '',
    skills: [],
    workExperience: [],
    education: [],
    certifications: [],
    projects: [],
  );

  final String phone;
  final String email;
  final List<String> skills;
  final List<WorkExperienceEntry> workExperience;
  final List<EducationEntry> education;
  final List<ExternalCertificationEntry> certifications;
  final List<ProjectEntry> projects;

  /// Whole-number percent (0-100) of the profile's sections that have at
  /// least one real value -- powers Home's completion banner. Five equally-
  /// weighted sections (contact info, skills, experience, education,
  /// certifications-or-projects) rather than counting every individual
  /// field, so one filled-in work-experience entry counts the same as one
  /// filled-in education entry instead of a candidate with a long resume
  /// scoring higher than one with a short, honest one.
  int get completionPercent {
    final sections = [
      phone.isNotEmpty || email.isNotEmpty,
      skills.isNotEmpty,
      workExperience.isNotEmpty,
      education.isNotEmpty,
      certifications.isNotEmpty || projects.isNotEmpty,
    ];
    final complete = sections.where((done) => done).length;
    return ((complete / sections.length) * 100).round();
  }

  bool get isComplete => completionPercent >= 100;
}
