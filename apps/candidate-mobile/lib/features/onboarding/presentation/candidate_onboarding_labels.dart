import '../../../l10n/generated/app_localizations.dart';
import '../domain/candidate_onboarding_draft.dart';

/// Localized display labels for [CandidateOnboardingDraft]'s domain enums
/// (`CandidateGoal`, `EducationLevel`, `ExperienceLevel`, `LogisticsRole`).
/// Kept here in onboarding's own presentation layer rather than as a
/// `label` getter on each enum -- those enums are domain-layer and have no
/// `BuildContext`/`AppLocalizations` to localize with (same reasoning as
/// `ShiftGrievanceCategory`'s own domain doc comment). Shared across three
/// consumers of these enums: the onboarding wizard's own picker steps
/// (`candidate_onboarding_screen.dart`), Profile's detail rows
/// (`profile_screen.dart`), and the Persona networking card
/// (`professional_persona_card.dart`) -- previously each of those either
/// hardcoded English (Profile, Persona card) or read a `.label` field that
/// never localized regardless of the app's language setting.
String candidateGoalLabel(CandidateGoal goal, AppLocalizations l10n) =>
    switch (goal) {
      CandidateGoal.findJob => l10n.goalFindJob,
      CandidateGoal.buildSkills => l10n.goalBuildSkills,
      CandidateGoal.growCareer => l10n.goalGrowCareer,
      CandidateGoal.buildPersona => l10n.goalBuildPersona,
    };

String educationLevelLabel(EducationLevel level, AppLocalizations l10n) =>
    switch (level) {
      EducationLevel.belowTenth => l10n.educationBelowTenth,
      EducationLevel.tenthPass => l10n.educationTenthPass,
      EducationLevel.twelfthPass => l10n.educationTwelfthPass,
      EducationLevel.itiDiploma => l10n.educationItiDiploma,
      EducationLevel.graduate => l10n.educationGraduate,
    };

String experienceLevelLabel(ExperienceLevel level, AppLocalizations l10n) =>
    switch (level) {
      ExperienceLevel.fresher => l10n.experienceFresher,
      ExperienceLevel.underOneYear => l10n.experienceUnderOneYear,
      ExperienceLevel.oneToThreeYears => l10n.experienceOneToThreeYears,
      ExperienceLevel.overThreeYears => l10n.experienceOverThreeYears,
    };

String logisticsRoleLabel(LogisticsRole role, AppLocalizations l10n) =>
    switch (role) {
      LogisticsRole.warehouseAssociate => l10n.roleWarehouseAssociate,
      LogisticsRole.inventoryExecutive => l10n.roleInventoryExecutive,
      LogisticsRole.dispatchExecutive => l10n.roleDispatchExecutive,
      LogisticsRole.hubSupervisor => l10n.roleHubSupervisor,
      LogisticsRole.shiftSupervisor => l10n.roleShiftSupervisor,
    };
