enum CandidateGoal {
  findJob('find_job', 'Find a new job'),
  buildSkills('build_skills', 'Build job-ready skills'),
  growCareer('grow_career', 'Grow in my current career');

  const CandidateGoal(this.id, this.label);

  final String id;
  final String label;

  static CandidateGoal? fromId(Object? id) {
    for (final value in values) {
      if (value.id == id) {
        return value;
      }
    }
    return null;
  }
}

enum EducationLevel {
  belowTenth('below_tenth', 'Below Class 10'),
  tenthPass('tenth_pass', 'Class 10 pass'),
  twelfthPass('twelfth_pass', 'Class 12 pass'),
  itiDiploma('iti_diploma', 'ITI or diploma'),
  graduate('graduate', 'Graduate or above');

  const EducationLevel(this.id, this.label);

  final String id;
  final String label;

  static EducationLevel? fromId(Object? id) {
    for (final value in values) {
      if (value.id == id) {
        return value;
      }
    }
    return null;
  }
}

enum ExperienceLevel {
  fresher('fresher', 'Fresher'),
  underOneYear('under_one_year', 'Less than 1 year'),
  oneToThreeYears('one_to_three_years', '1–3 years'),
  overThreeYears('over_three_years', 'More than 3 years');

  const ExperienceLevel(this.id, this.label);

  final String id;
  final String label;

  static ExperienceLevel? fromId(Object? id) {
    for (final value in values) {
      if (value.id == id) {
        return value;
      }
    }
    return null;
  }
}

/// Entry-role seniority tier. Only two tiers exist today (the front-line
/// "Associate"/"Executive" titles vs. the "Supervisor" titles) -- more
/// levels (L2, L3, ...) get added here as the role taxonomy grows, without
/// touching the [LogisticsRole] ids or labels candidates already see.
enum RoleLevel {
  l1('L1'),
  supervisor('Supervisor');

  const RoleLevel(this.label);

  final String label;
}

enum LogisticsRole {
  warehouseAssociate(
    'warehouse_associate',
    'Warehouse Operations Associate',
    RoleLevel.l1,
  ),
  inventoryExecutive(
    'inventory_executive',
    'Inventory Executive',
    RoleLevel.l1,
  ),
  dispatchExecutive('dispatch_executive', 'Dispatch Executive', RoleLevel.l1),
  hubSupervisor('hub_supervisor', 'Hub Supervisor', RoleLevel.supervisor),
  shiftSupervisor('shift_supervisor', 'Shift Supervisor', RoleLevel.supervisor);

  const LogisticsRole(this.id, this.label, this.level);

  final String id;
  final String label;
  final RoleLevel level;

  static LogisticsRole? fromId(Object? id) {
    for (final value in values) {
      if (value.id == id) {
        return value;
      }
    }
    return null;
  }
}

class ConsentAcceptance {
  const ConsentAcceptance({
    required this.purpose,
    required this.version,
    required this.acceptedAt,
  });

  final String purpose;
  final String version;
  final DateTime acceptedAt;

  Map<String, Object?> toJson() => {
    'purpose': purpose,
    'version': version,
    'accepted_at': acceptedAt.toUtc().toIso8601String(),
  };

  factory ConsentAcceptance.fromJson(Map<String, Object?> json) {
    final purpose = json['purpose'];
    final version = json['version'];
    final acceptedAt = json['accepted_at'];
    if (purpose is! String || version is! String || acceptedAt is! String) {
      throw const FormatException('Invalid consent acceptance');
    }
    return ConsentAcceptance(
      purpose: purpose,
      version: version,
      acceptedAt: DateTime.parse(acceptedAt),
    );
  }
}

abstract final class OnboardingConsentVersions {
  static const termsPurpose = 'platform_terms';
  static const termsVersion = '2026-07-v1';
  static const privacyPurpose = 'privacy_notice';
  static const privacyVersion = '2026-07-v1';
}

class CandidateOnboardingDraft {
  const CandidateOnboardingDraft({
    this.schemaVersion = 1,
    this.currentStep = 0,
    this.goal,
    this.fullName = '',
    this.city = '',
    this.state = '',
    this.pinCode = '',
    this.education,
    this.experience,
    this.preferredRoles = const {},
    this.consents = const {},
    this.isCompleted = false,
  });

  final int schemaVersion;
  final int currentStep;
  final CandidateGoal? goal;
  final String fullName;
  final String city;
  final String state;
  final String pinCode;
  final EducationLevel? education;
  final ExperienceLevel? experience;
  final Set<LogisticsRole> preferredRoles;
  final Map<String, ConsentAcceptance> consents;
  final bool isCompleted;

  bool get hasCurrentRequiredConsents {
    return consents[OnboardingConsentVersions.termsPurpose]?.version ==
            OnboardingConsentVersions.termsVersion &&
        consents[OnboardingConsentVersions.privacyPurpose]?.version ==
            OnboardingConsentVersions.privacyVersion;
  }

  CandidateOnboardingDraft copyWith({
    int? currentStep,
    CandidateGoal? goal,
    String? fullName,
    String? city,
    String? state,
    String? pinCode,
    EducationLevel? education,
    ExperienceLevel? experience,
    Set<LogisticsRole>? preferredRoles,
    Map<String, ConsentAcceptance>? consents,
    bool? isCompleted,
  }) {
    return CandidateOnboardingDraft(
      schemaVersion: schemaVersion,
      currentStep: currentStep ?? this.currentStep,
      goal: goal ?? this.goal,
      fullName: fullName ?? this.fullName,
      city: city ?? this.city,
      state: state ?? this.state,
      pinCode: pinCode ?? this.pinCode,
      education: education ?? this.education,
      experience: experience ?? this.experience,
      preferredRoles: preferredRoles ?? this.preferredRoles,
      consents: consents ?? this.consents,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, Object?> toJson() => {
    'schema_version': schemaVersion,
    'current_step': currentStep,
    'goal': goal?.id,
    'full_name': fullName,
    'city': city,
    'state': state,
    'pin_code': pinCode,
    'education': education?.id,
    'experience': experience?.id,
    'preferred_roles': preferredRoles.map((role) => role.id).toList(),
    'consents': consents.map(
      (purpose, acceptance) => MapEntry(purpose, acceptance.toJson()),
    ),
    'is_completed': isCompleted,
  };

  factory CandidateOnboardingDraft.fromJson(Map<String, Object?> json) {
    final schemaVersion = json['schema_version'];
    final currentStep = json['current_step'];
    final preferredRoles = json['preferred_roles'];
    final consents = json['consents'];
    final isCompleted = json['is_completed'];
    if (schemaVersion != 1 ||
        currentStep is! int ||
        preferredRoles is! List<Object?> ||
        consents is! Map<String, Object?> ||
        isCompleted is! bool) {
      throw const FormatException('Invalid candidate onboarding draft');
    }

    return CandidateOnboardingDraft(
      schemaVersion: schemaVersion as int,
      currentStep: currentStep.clamp(0, 10),
      goal: CandidateGoal.fromId(json['goal']),
      fullName: json['full_name'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      pinCode: json['pin_code'] as String? ?? '',
      education: EducationLevel.fromId(json['education']),
      experience: ExperienceLevel.fromId(json['experience']),
      preferredRoles: preferredRoles
          .map(LogisticsRole.fromId)
          .whereType<LogisticsRole>()
          .toSet(),
      consents: consents.map(
        (purpose, value) => MapEntry(
          purpose,
          ConsentAcceptance.fromJson(value as Map<String, Object?>),
        ),
      ),
      isCompleted: isCompleted,
    );
  }
}
