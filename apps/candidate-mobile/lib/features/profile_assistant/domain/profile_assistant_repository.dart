import '../../../core/errors/result.dart';
import '../../profile_details/domain/detailed_candidate_profile.dart';
import 'profile_gap.dart';

enum AssistantRole { assistant, candidate }

class AssistantTurn {
  const AssistantTurn({required this.role, required this.text});

  final AssistantRole role;
  final String text;
}

/// One field the assistant heard an answer for.
///
/// Only the slot matching [field] is ever populated -- see the backend's
/// `AssistantFieldUpdate` for why this is one shape rather than a union.
/// [confirmation] is the model's own short acknowledgement, already
/// written in the candidate's language ("15 days set kar diya"); it is
/// shown back to them and never stored.
class AssistantFieldUpdate {
  const AssistantFieldUpdate({
    required this.field,
    required this.confirmation,
    this.text = '',
    this.amount,
    this.items = const [],
    this.languages = const [],
    this.noticePeriod,
  });

  final ProfileGapId field;
  final String confirmation;
  final String text;
  final double? amount;
  final List<String> items;
  final List<LanguageEntry> languages;
  final NoticePeriod? noticePeriod;
}

class AssistantReply {
  const AssistantReply({
    required this.text,
    required this.updates,
    required this.isComplete,
  });

  final String text;
  final List<AssistantFieldUpdate> updates;

  /// True when nothing in the gap list is worth asking about anymore.
  final bool isComplete;
}

class AssistantTurnRequest {
  const AssistantTurnRequest({
    required this.knownProfileDigest,
    required this.remainingFields,
    required this.history,
    required this.languageTag,
  });

  /// A compact human-readable digest of what's already known -- never the
  /// raw profile. Built by `buildProfileDigest`.
  final String knownProfileDigest;
  final List<ProfileGapId> remainingFields;
  final List<AssistantTurn> history;

  /// `en`, `hi`, or `hi_Latn` -- taken from the app's own locale so the
  /// assistant answers in the language the candidate already chose.
  final String languageTag;
}

abstract interface class ProfileAssistantRepository {
  Future<Result<AssistantReply>> continueConversation(
    AssistantTurnRequest request,
  );
}

/// A short, human-readable summary of what the profile already holds, for
/// the assistant's prompt.
///
/// Deliberately lossy: the assistant only needs enough not to re-ask
/// something already answered. Sending the whole profile would cost
/// tokens on every turn and put more of the candidate's data through the
/// model than the task requires.
String buildProfileDigest(DetailedCandidateProfile profile) {
  final lines = <String>[
    if (profile.headline.isNotEmpty) 'Current role: ${profile.headline}',
    if (profile.totalExperience.isNotEmpty)
      'Total experience: ${profile.totalExperience}',
    if (profile.skills.isNotEmpty) 'Skills: ${profile.skills.join(', ')}',
    if (profile.workExperience.isNotEmpty)
      'Most recent job: ${profile.workExperience.first.title} at '
          '${profile.workExperience.first.company}',
    if (profile.education.isNotEmpty)
      'Education: ${profile.education.first.institution}',
    if (profile.languages.isNotEmpty)
      'Languages: ${profile.languages.map((l) => l.language).join(', ')}',
    if (profile.careerPreferences.noticePeriod != null)
      'Notice period: ${profile.careerPreferences.noticePeriod!.id}',
    if (profile.careerPreferences.expectedCtcAmount != null)
      'Expected salary: ${profile.careerPreferences.expectedCtcAmount!.round()} per year',
    if (profile.careerPreferences.preferredLocations.isNotEmpty)
      'Preferred locations: '
          '${profile.careerPreferences.preferredLocations.join(', ')}',
  ];
  return lines.join('\n');
}
