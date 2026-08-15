import '../../../l10n/generated/app_localizations.dart';
import '../domain/detailed_candidate_profile.dart';

/// Localized display labels for [DetailedCandidateProfile]'s domain enums
/// (`NoticePeriod`, `EmploymentType`, `LanguageProficiency`) -- same
/// reasoning and pattern as `candidate_onboarding_labels.dart`: those
/// enums are domain-layer and have no `BuildContext` to localize with.
String noticePeriodLabel(NoticePeriod period, AppLocalizations l10n) =>
    switch (period) {
      NoticePeriod.immediate => l10n.profileDetailsNoticePeriodImmediate,
      NoticePeriod.fifteenDays => l10n.profileDetailsNoticePeriodFifteenDays,
      NoticePeriod.oneMonth => l10n.profileDetailsNoticePeriodOneMonth,
      NoticePeriod.twoMonths => l10n.profileDetailsNoticePeriodTwoMonths,
      NoticePeriod.threeMonths => l10n.profileDetailsNoticePeriodThreeMonths,
      NoticePeriod.servingNotice =>
        l10n.profileDetailsNoticePeriodServingNotice,
    };

String employmentTypeLabel(EmploymentType type, AppLocalizations l10n) =>
    switch (type) {
      EmploymentType.fullTime => l10n.profileDetailsEmploymentTypeFullTime,
      EmploymentType.partTime => l10n.profileDetailsEmploymentTypePartTime,
      EmploymentType.contract => l10n.profileDetailsEmploymentTypeContract,
      EmploymentType.internship => l10n.profileDetailsEmploymentTypeInternship,
      EmploymentType.temporary => l10n.profileDetailsEmploymentTypeTemporary,
    };

String languageProficiencyLabel(
  LanguageProficiency proficiency,
  AppLocalizations l10n,
) => switch (proficiency) {
  LanguageProficiency.native => l10n.profileDetailsProficiencyNative,
  LanguageProficiency.fluent => l10n.profileDetailsProficiencyFluent,
  LanguageProficiency.professionalWorking =>
    l10n.profileDetailsProficiencyProfessionalWorking,
  LanguageProficiency.elementary => l10n.profileDetailsProficiencyElementary,
};
