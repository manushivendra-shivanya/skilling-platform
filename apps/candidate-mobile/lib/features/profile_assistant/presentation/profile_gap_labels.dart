import '../../../l10n/generated/app_localizations.dart';
import '../domain/profile_gap.dart';

/// Localized display label for each [ProfileGapId] -- same reasoning and
/// pattern as `candidate_onboarding_labels.dart`: the enum is
/// domain-layer and has no `BuildContext` to localize with.
///
/// Phrased as what the candidate is being asked for ("How soon you can
/// join"), not as the database column ("Notice period") -- this list is
/// read by someone deciding whether to answer, not by an engineer.
String profileGapLabel(ProfileGapId id, AppLocalizations l10n) => switch (id) {
  ProfileGapId.headline => l10n.profileGapHeadline,
  ProfileGapId.summary => l10n.profileGapSummary,
  ProfileGapId.totalExperience => l10n.profileGapTotalExperience,
  ProfileGapId.phone => l10n.profileGapPhone,
  ProfileGapId.email => l10n.profileGapEmail,
  ProfileGapId.skills => l10n.profileGapSkills,
  ProfileGapId.languages => l10n.profileGapLanguages,
  ProfileGapId.noticePeriod => l10n.profileGapNoticePeriod,
  ProfileGapId.expectedCtc => l10n.profileGapExpectedCtc,
  ProfileGapId.preferredLocations => l10n.profileGapPreferredLocations,
  ProfileGapId.workExperience => l10n.profileGapWorkExperience,
  ProfileGapId.education => l10n.profileGapEducation,
};
