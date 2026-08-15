import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../core/errors/app_failure.dart';
import '../../profile_details/domain/detailed_candidate_profile.dart';
import '../../profile_details/presentation/detailed_profile_controller.dart';
import '../domain/profile_assistant_repository.dart';
import '../domain/profile_gap.dart';

/// One line in the conversation as the screen renders it.
///
/// [savedFields] is what the assistant successfully wrote as a result of
/// the *candidate's* message before it -- rendered as "Saved" tags under
/// the assistant's acknowledgement, so the candidate can see their answer
/// actually landed rather than trusting the model's word for it.
class AssistantMessage {
  const AssistantMessage({
    required this.role,
    required this.text,
    this.savedFields = const [],
    this.saveFailed = false,
  });

  final AssistantRole role;
  final String text;
  final List<ProfileGapId> savedFields;

  /// True when the assistant heard an answer but persisting it failed --
  /// surfaced honestly rather than letting the candidate believe a field
  /// was saved when it wasn't.
  final bool saveFailed;
}

class ProfileAssistantState {
  const ProfileAssistantState({
    this.messages = const [],
    this.isThinking = false,
    this.isComplete = false,
    this.failure,
  });

  final List<AssistantMessage> messages;
  final bool isThinking;
  final bool isComplete;
  final AppFailure? failure;

  ProfileAssistantState copyWith({
    List<AssistantMessage>? messages,
    bool? isThinking,
    bool? isComplete,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return ProfileAssistantState(
      messages: messages ?? this.messages,
      isThinking: isThinking ?? this.isThinking,
      isComplete: isComplete ?? this.isComplete,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

final profileAssistantControllerProvider =
    NotifierProvider<ProfileAssistantController, ProfileAssistantState>(
      ProfileAssistantController.new,
    );

/// Drives the completion conversation: sends a turn, applies whatever the
/// assistant extracted, and reloads the profile so the gap list shrinks.
///
/// The conversation itself is deliberately *not* persisted -- same
/// stateless posture as the backend (see `ProfileAssistantService`). What
/// persists is the profile fields the answers produced; the transcript is
/// scaffolding, and keeping it would mean storing a candidate's spoken
/// answers about salary indefinitely for no functional gain.
class ProfileAssistantController extends Notifier<ProfileAssistantState> {
  @override
  ProfileAssistantState build() => const ProfileAssistantState();

  /// Sends the opening turn. Safe to call again -- a conversation that
  /// already started is left alone rather than restarted under the
  /// candidate.
  Future<void> start({required String languageTag}) async {
    if (state.messages.isNotEmpty || state.isThinking) return;
    await _send(languageTag: languageTag);
  }

  Future<void> answer(String text, {required String languageTag}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isThinking) return;
    state = state.copyWith(
      messages: [
        ...state.messages,
        AssistantMessage(role: AssistantRole.candidate, text: trimmed),
      ],
      clearFailure: true,
    );
    await _send(languageTag: languageTag);
  }

  Future<void> _send({required String languageTag}) async {
    state = state.copyWith(isThinking: true, clearFailure: true);

    final profile = await ref.read(detailedProfileControllerProvider.future);
    final result = await ref
        .read(profileAssistantRepositoryProvider)
        .continueConversation(
          AssistantTurnRequest(
            knownProfileDigest: buildProfileDigest(profile),
            remainingFields: findProfileGaps(
              profile,
            ).map((gap) => gap.id).toList(),
            history: state.messages
                .map((m) => AssistantTurn(role: m.role, text: m.text))
                .toList(),
            languageTag: languageTag,
          ),
        );

    await result.when(
      success: (reply) async {
        final saved = <ProfileGapId>[];
        var saveFailed = false;
        for (final update in reply.updates) {
          final applied = await _apply(update, profile);
          if (applied) {
            saved.add(update.field);
          } else {
            saveFailed = true;
          }
        }
        if (saved.isNotEmpty) {
          // Reload so the next turn's gap list reflects what was just
          // written -- otherwise the assistant re-asks a field it already
          // has an answer for.
          ref.invalidate(detailedProfileControllerProvider);
        }
        state = state.copyWith(
          isThinking: false,
          isComplete: reply.isComplete,
          messages: [
            ...state.messages,
            AssistantMessage(
              role: AssistantRole.assistant,
              text: reply.text,
              savedFields: saved,
              saveFailed: saveFailed,
            ),
          ],
        );
      },
      failure: (failure) async {
        state = state.copyWith(isThinking: false, failure: failure);
      },
    );
  }

  /// Writes one extracted answer through the existing profile
  /// repositories. Returns false when the write failed, so the caller can
  /// tell the candidate rather than silently losing the answer.
  ///
  /// [current] is the profile as it was at the start of this turn --
  /// list-valued fields (skills, locations, languages) are merged into it
  /// rather than replacing it, so a candidate who names one more skill
  /// doesn't wipe the ones the resume already found.
  Future<bool> _apply(
    AssistantFieldUpdate update,
    DetailedCandidateProfile current,
  ) async {
    final controller = ref.read(detailedProfileControllerProvider.notifier);
    final preferences = current.careerPreferences;

    switch (update.field) {
      case ProfileGapId.headline:
        return null ==
            await controller.saveProfileBasics(
              headline: update.text,
              summary: current.summary,
              totalExperience: current.totalExperience,
            );
      case ProfileGapId.summary:
        return null ==
            await controller.saveProfileBasics(
              headline: current.headline,
              summary: update.text,
              totalExperience: current.totalExperience,
            );
      case ProfileGapId.totalExperience:
        return null ==
            await controller.saveProfileBasics(
              headline: current.headline,
              summary: current.summary,
              totalExperience: update.text,
            );
      case ProfileGapId.phone:
        return null ==
            await controller.saveContactAndSkills(
              phone: update.text,
              email: current.email,
              skills: current.skills,
            );
      case ProfileGapId.email:
        return null ==
            await controller.saveContactAndSkills(
              phone: current.phone,
              email: update.text,
              skills: current.skills,
            );
      case ProfileGapId.skills:
        return null ==
            await controller.saveContactAndSkills(
              phone: current.phone,
              email: current.email,
              skills: {...current.skills, ...update.items}.toList(),
            );
      case ProfileGapId.languages:
        for (final language in update.languages) {
          final failure = await controller.saveLanguage(language);
          if (failure != null) return false;
        }
        return true;
      case ProfileGapId.noticePeriod:
        return null ==
            await controller.saveCareerPreferences(
              preferences.copyWith(noticePeriod: update.noticePeriod),
            );
      case ProfileGapId.expectedCtc:
        return null ==
            await controller.saveCareerPreferences(
              preferences.copyWith(expectedCtcAmount: update.amount),
            );
      case ProfileGapId.preferredLocations:
        return null ==
            await controller.saveCareerPreferences(
              preferences.copyWith(
                preferredLocations: {
                  ...preferences.preferredLocations,
                  ...update.items,
                }.toList(),
              ),
            );
      case ProfileGapId.workExperience:
      case ProfileGapId.education:
        // Structured repeating entries the assistant deliberately never
        // transcribes -- see ASSISTANT_WRITABLE_FIELDS' doc comment. The
        // backend filters these out, so reaching here means a provider
        // ignored its contract; refuse rather than write a half-entry.
        return false;
    }
  }
}
