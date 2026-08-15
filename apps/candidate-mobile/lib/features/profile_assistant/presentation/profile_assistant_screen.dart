import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/app_locale.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure_localization.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_sticky_footer.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/profile_assistant_repository.dart';
import 'profile_assistant_controller.dart';
import 'profile_gap_labels.dart';

/// The conversation that fills in whatever a resume couldn't.
///
/// Text-first by design *today*: the app records audio (see
/// `RecordVoiceCaptureRepository`) but has no speech-to-text, so offering
/// a microphone that silently did nothing would be worse than saying so.
/// The composer carries an explicit "voice is coming" affordance instead,
/// and the conversation contract is already shaped for it -- a
/// transcribed utterance enters through exactly the same `answer()` call
/// a typed one does.
class ProfileAssistantScreen extends ConsumerStatefulWidget {
  const ProfileAssistantScreen({required this.onDone, super.key});

  final VoidCallback onDone;

  @override
  ConsumerState<ProfileAssistantScreen> createState() =>
      _ProfileAssistantScreenState();
}

class _ProfileAssistantScreenState
    extends ConsumerState<ProfileAssistantScreen> {
  final _composer = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // The opening turn is the assistant's -- it greets and asks the first
    // question, so the candidate never faces an empty box wondering what
    // to type. Deferred past the first frame because it reads providers.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(profileAssistantControllerProvider.notifier)
          .start(languageTag: _languageTag());
    });
  }

  @override
  void dispose() {
    _composer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// `en`, `hi`, or `hi_Latn` -- derived from the locale the candidate
  /// already chose, so the assistant answers in their language without
  /// asking them to pick one a second time.
  String _languageTag() {
    final locale = ref.read(appLocaleProvider);
    return locale.scriptCode == null
        ? locale.languageCode
        : '${locale.languageCode}_${locale.scriptCode}';
  }

  void _send() {
    final text = _composer.text;
    if (text.trim().isEmpty) return;
    _composer.clear();
    ref
        .read(profileAssistantControllerProvider.notifier)
        .answer(text, languageTag: _languageTag());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(profileAssistantControllerProvider);

    // Keep the newest turn in view as the conversation grows.
    ref.listen(profileAssistantControllerProvider, (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      });
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileAssistantScreenTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Text(
                    l10n.profileAssistantIntro,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  for (final message in state.messages)
                    _MessageBubble(message: message),
                  if (state.isThinking)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        l10n.profileAssistantThinking,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ),
                  if (state.failure != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          state.failure!.localizedMessage(l10n),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.error),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            AppStickyFooter(
              child: state.isComplete
                  ? AppButton(
                      key: const ValueKey('profile-assistant-done-button'),
                      label: l10n.profileAssistantDoneButton,
                      onPressed: widget.onDone,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                key: const ValueKey(
                                  'profile-assistant-composer',
                                ),
                                controller: _composer,
                                hint: l10n.profileAssistantComposerHint,
                                enabled: !state.isThinking,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _send(),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            IconButton.filled(
                              key: const ValueKey('profile-assistant-send'),
                              onPressed: state.isThinking ? null : _send,
                              tooltip: l10n.profileAssistantSendSemantic,
                              icon: const Icon(Icons.send_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          l10n.profileAssistantVoiceComingSoon,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppColors.inkMuted),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final AssistantMessage message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAssistant = message.role == AssistantRole.assistant;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: isAssistant
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: isAssistant ? AppColors.surface : AppColors.brandSoft,
              border: Border.all(
                color: isAssistant
                    ? AppColors.surfaceMuted
                    : Colors.transparent,
              ),
              borderRadius: AppRadius.largeBorder,
            ),
            child: Text(
              message.text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isAssistant ? AppColors.ink : AppColors.brandDark,
              ),
            ),
          ),
          if (message.savedFields.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Wrap(
                spacing: AppSpacing.xxs,
                children: [
                  for (final field in message.savedFields)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: AppColors.success,
                      ),
                      label: Text(
                        '${profileGapLabel(field, l10n)} · '
                        '${l10n.profileAssistantSavedTag}',
                      ),
                      labelStyle: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: AppColors.success),
                      backgroundColor: AppColors.successSoft,
                      side: BorderSide.none,
                    ),
                ],
              ),
            ),
          if (message.saveFailed)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Text(
                l10n.profileAssistantSaveFailed,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppColors.error),
              ),
            ),
        ],
      ),
    );
  }
}
