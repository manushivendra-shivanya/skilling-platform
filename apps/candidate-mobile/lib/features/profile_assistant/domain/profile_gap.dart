import '../../profile_details/domain/detailed_candidate_profile.dart';

/// One thing still missing from a candidate's profile.
///
/// Deliberately a closed enum rather than free-text: every gap needs a
/// localized label, a localized question the assistant asks about it, and
/// (once the assistant can write) a known field to save the answer into.
/// A string id would make all three lookups stringly-typed.
enum ProfileGapId {
  headline,
  summary,
  totalExperience,
  phone,
  email,
  skills,
  languages,
  noticePeriod,
  expectedCtc,
  preferredLocations,
  workExperience,
  education,
}

/// How much a missing field actually costs the candidate.
///
/// [recruiterFilter] is not a severity judgement -- it's a factual claim
/// about how recruiters search: notice period and expected salary are the
/// two fields recruiters filter on most, so a profile missing them is
/// invisible to those searches no matter how complete the rest is. That
/// distinction is what the completion screen surfaces as "Top filter",
/// and it's why gaps are ordered by priority rather than by section.
enum ProfileGapPriority { recruiterFilter, important, optional }

class ProfileGap {
  const ProfileGap(this.id, this.priority);

  final ProfileGapId id;
  final ProfileGapPriority priority;
}

/// Everything still missing from [profile], most-costly first.
///
/// A pure function of the profile -- no network, no AI, no session. The
/// assistant conversation uses this to decide what to ask about, and the
/// completion screen uses the same list to show the candidate what's left,
/// so the two can never disagree about what "incomplete" means.
///
/// Only genuinely-blank fields count. A candidate who deliberately ticked
/// "prefer not to disclose" on current CTC has answered that question, so
/// current CTC is not a gap at all and never appears here (which is also
/// why it has no [ProfileGapId]). Expected CTC has no such opt-out and is
/// a real recruiter filter, so its absence is always a gap.
List<ProfileGap> findProfileGaps(DetailedCandidateProfile profile) {
  final preferences = profile.careerPreferences;
  final gaps = <ProfileGap>[
    if (preferences.noticePeriod == null)
      const ProfileGap(
        ProfileGapId.noticePeriod,
        ProfileGapPriority.recruiterFilter,
      ),
    if (preferences.expectedCtcAmount == null)
      const ProfileGap(
        ProfileGapId.expectedCtc,
        ProfileGapPriority.recruiterFilter,
      ),
    if (profile.headline.trim().isEmpty)
      const ProfileGap(ProfileGapId.headline, ProfileGapPriority.important),
    if (profile.totalExperience.trim().isEmpty)
      const ProfileGap(
        ProfileGapId.totalExperience,
        ProfileGapPriority.important,
      ),
    if (profile.skills.isEmpty)
      const ProfileGap(ProfileGapId.skills, ProfileGapPriority.important),
    if (profile.workExperience.isEmpty)
      const ProfileGap(
        ProfileGapId.workExperience,
        ProfileGapPriority.important,
      ),
    if (profile.education.isEmpty)
      const ProfileGap(ProfileGapId.education, ProfileGapPriority.important),
    if (profile.phone.trim().isEmpty)
      const ProfileGap(ProfileGapId.phone, ProfileGapPriority.important),
    if (profile.languages.isEmpty)
      const ProfileGap(ProfileGapId.languages, ProfileGapPriority.optional),
    if (profile.summary.trim().isEmpty)
      const ProfileGap(ProfileGapId.summary, ProfileGapPriority.optional),
    if (profile.email.trim().isEmpty)
      const ProfileGap(ProfileGapId.email, ProfileGapPriority.optional),
    if (preferences.preferredLocations.isEmpty)
      const ProfileGap(
        ProfileGapId.preferredLocations,
        ProfileGapPriority.optional,
      ),
  ];

  // Stable ordering by cost, preserving the declaration order within each
  // band -- a List.sort would not be stable and would shuffle equally
  // -weighted gaps between rebuilds of the same screen.
  return [
    ...gaps.where((g) => g.priority == ProfileGapPriority.recruiterFilter),
    ...gaps.where((g) => g.priority == ProfileGapPriority.important),
    ...gaps.where((g) => g.priority == ProfileGapPriority.optional),
  ];
}

/// Whole-number percent (0-100) of the tracked fields that are filled.
///
/// Deliberately a *different* number from
/// `DetailedCandidateProfile.completionPercent`, which weighs five broad
/// sections equally to drive Home's banner. This one counts individual
/// fields, because the assistant's pitch is "4 specific things are
/// missing" -- a section-level score can't name four things. Both are
/// honest; they answer different questions.
int profileFieldCompletionPercent(DetailedCandidateProfile profile) {
  final trackedFieldCount = ProfileGapId.values.length;
  final filled = trackedFieldCount - findProfileGaps(profile).length;
  return ((filled / trackedFieldCount) * 100).round();
}
