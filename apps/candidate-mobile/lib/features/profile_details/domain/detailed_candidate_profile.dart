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

/// How soon the candidate could join a new role. Stored as an id string on
/// `candidate_profiles.notice_period` -- same convention as this table's
/// existing `goal`/`education_level`/`experience_level` columns, not a
/// Postgres enum.
enum NoticePeriod {
  immediate('immediate'),
  fifteenDays('fifteen_days'),
  oneMonth('one_month'),
  twoMonths('two_months'),
  threeMonths('three_months'),
  servingNotice('serving_notice');

  const NoticePeriod(this.id);

  final String id;

  static NoticePeriod? fromId(Object? id) {
    for (final value in values) {
      if (value.id == id) return value;
    }
    return null;
  }
}

enum EmploymentType {
  fullTime('full_time'),
  partTime('part_time'),
  contract('contract'),
  internship('internship'),
  temporary('temporary');

  const EmploymentType(this.id);

  final String id;

  static EmploymentType? fromId(Object? id) {
    for (final value in values) {
      if (value.id == id) return value;
    }
    return null;
  }
}

/// A single overall level per language, not separate speak/read/write
/// scores -- three scores per language is more questions than a quick
/// voice-driven completion flow should ask, and this candidate base cares
/// whether they can hold a conversation in a language, not a granular
/// literacy breakdown.
enum LanguageProficiency {
  native('native'),
  fluent('fluent'),
  professionalWorking('professional_working'),
  elementary('elementary');

  const LanguageProficiency(this.id);

  final String id;

  static LanguageProficiency? fromId(Object? id) {
    for (final value in values) {
      if (value.id == id) return value;
    }
    return null;
  }
}

/// One row on `candidate_languages` -- same shape/insert-vs-update rule as
/// `WorkExperienceEntry` and its siblings (empty [id] means "insert").
class LanguageEntry {
  const LanguageEntry({
    required this.id,
    required this.language,
    required this.proficiency,
    this.sequence = 0,
  });

  final String id;
  final String language;
  final LanguageProficiency proficiency;
  final int sequence;

  LanguageEntry copyWith({
    String? id,
    String? language,
    LanguageProficiency? proficiency,
    int? sequence,
  }) {
    return LanguageEntry(
      id: id ?? this.id,
      language: language ?? this.language,
      proficiency: proficiency ?? this.proficiency,
      sequence: sequence ?? this.sequence,
    );
  }
}

/// Naukri-style recruiter filters -- CTC, notice period, employment type,
/// locations -- deliberately a resume can't reliably supply most of
/// these, so this is exactly the shape a voice-driven completion flow
/// will ask about once that exists. Saved as one aggregate (not per-field
/// upserts like the list sections) because these fields live as plain
/// columns on `candidate_profiles`, the same row `saveContactAndSkills`
/// already writes to.
class CareerPreferences {
  const CareerPreferences({
    this.currentCtcAmount,
    this.currentCtcUndisclosed = false,
    this.expectedCtcAmount,
    this.expectedCtcNegotiable = false,
    this.noticePeriod,
    this.employmentTypes = const {},
    this.preferredLocations = const [],
    this.willingToRelocate = false,
    this.industry = '',
    this.functionalArea = '',
  });

  static const empty = CareerPreferences();

  /// Annual, in the candidate's local currency -- no currency field yet
  /// since this candidate base is India-only today; add one before this
  /// screen is ever shown outside India.
  final double? currentCtcAmount;
  final bool currentCtcUndisclosed;
  final double? expectedCtcAmount;
  final bool expectedCtcNegotiable;
  final NoticePeriod? noticePeriod;
  final Set<EmploymentType> employmentTypes;
  final List<String> preferredLocations;
  final bool willingToRelocate;
  final String industry;
  final String functionalArea;

  bool get isEmpty =>
      currentCtcAmount == null &&
      expectedCtcAmount == null &&
      noticePeriod == null &&
      employmentTypes.isEmpty &&
      preferredLocations.isEmpty &&
      !willingToRelocate &&
      industry.isEmpty &&
      functionalArea.isEmpty;

  CareerPreferences copyWith({
    double? currentCtcAmount,
    bool clearCurrentCtcAmount = false,
    bool? currentCtcUndisclosed,
    double? expectedCtcAmount,
    bool clearExpectedCtcAmount = false,
    bool? expectedCtcNegotiable,
    NoticePeriod? noticePeriod,
    bool clearNoticePeriod = false,
    Set<EmploymentType>? employmentTypes,
    List<String>? preferredLocations,
    bool? willingToRelocate,
    String? industry,
    String? functionalArea,
  }) {
    return CareerPreferences(
      currentCtcAmount: clearCurrentCtcAmount
          ? null
          : (currentCtcAmount ?? this.currentCtcAmount),
      currentCtcUndisclosed:
          currentCtcUndisclosed ?? this.currentCtcUndisclosed,
      expectedCtcAmount: clearExpectedCtcAmount
          ? null
          : (expectedCtcAmount ?? this.expectedCtcAmount),
      expectedCtcNegotiable:
          expectedCtcNegotiable ?? this.expectedCtcNegotiable,
      noticePeriod: clearNoticePeriod
          ? null
          : (noticePeriod ?? this.noticePeriod),
      employmentTypes: employmentTypes ?? this.employmentTypes,
      preferredLocations: preferredLocations ?? this.preferredLocations,
      willingToRelocate: willingToRelocate ?? this.willingToRelocate,
      industry: industry ?? this.industry,
      functionalArea: functionalArea ?? this.functionalArea,
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
    this.headline = '',
    this.summary = '',
    this.totalExperience = '',
    this.languages = const [],
    this.careerPreferences = CareerPreferences.empty,
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

  DetailedCandidateProfile copyWith({
    String? phone,
    String? email,
    List<String>? skills,
    List<WorkExperienceEntry>? workExperience,
    List<EducationEntry>? education,
    List<ExternalCertificationEntry>? certifications,
    List<ProjectEntry>? projects,
    String? headline,
    String? summary,
    String? totalExperience,
    List<LanguageEntry>? languages,
    CareerPreferences? careerPreferences,
  }) {
    return DetailedCandidateProfile(
      phone: phone ?? this.phone,
      email: email ?? this.email,
      skills: skills ?? this.skills,
      workExperience: workExperience ?? this.workExperience,
      education: education ?? this.education,
      certifications: certifications ?? this.certifications,
      projects: projects ?? this.projects,
      headline: headline ?? this.headline,
      summary: summary ?? this.summary,
      totalExperience: totalExperience ?? this.totalExperience,
      languages: languages ?? this.languages,
      careerPreferences: careerPreferences ?? this.careerPreferences,
    );
  }

  final String phone;
  final String email;
  final List<String> skills;
  final List<WorkExperienceEntry> workExperience;
  final List<EducationEntry> education;
  final List<ExternalCertificationEntry> certifications;
  final List<ProjectEntry> projects;

  /// A short "current/most recent role" line. Also lives on the
  /// on-device onboarding draft (feeds the Professional Persona card) --
  /// the two are not yet unified into one source of truth; see
  /// `ResumeImportScreen._confirm`'s doc comment for how resume import
  /// writes to both today.
  final String headline;

  /// Free-text professional narrative, ~2,000 characters. Not extracted
  /// from resumes today -- a resume's own summary paragraph is unreliable
  /// enough to parse that this is left to manual entry or the future
  /// voice-driven completion flow.
  final String summary;

  /// Free text ("3 yrs 4 mos"), matching `ResumeAiParseResult
  /// .yearsOfExperience`'s own convention -- see that field's doc comment
  /// for why this is a string, not a number.
  final String totalExperience;
  final List<LanguageEntry> languages;
  final CareerPreferences careerPreferences;

  /// Whole-number percent (0-100) of the profile's sections that have at
  /// least one real value -- powers Home's completion banner. Five equally-
  /// weighted sections (contact info, skills, experience, education,
  /// certifications-or-projects) rather than counting every individual
  /// field, so one filled-in work-experience entry counts the same as one
  /// filled-in education entry instead of a candidate with a long resume
  /// scoring higher than one with a short, honest one.
  ///
  /// Deliberately NOT re-weighted to include headline/summary/languages/
  /// career preferences yet -- Home's completion banner (see
  /// `ProfileCompletionBanner`) already has shipped copy and thresholds
  /// tuned to five sections; folding in the new ones is its own follow-up
  /// once they're not brand new.
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
