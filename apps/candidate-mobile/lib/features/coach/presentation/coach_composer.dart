import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../l10n/generated/app_localizations.dart';

/// The Coach message composer -- a text field plus a send control, shared
/// across `CoachThreadsScreen` (starting a new thread), `CoachThreadScreen`
/// (replying within one), and `AskCoachAffordance`'s quick-ask sheet. Those
/// three previously each hand-rolled a near-identical raw `TextField` +
/// `IconButton` `Row`; this widget is the one shared implementation,
/// wrapping [AppTextField] rather than composing `TextField` directly so
/// this chrome tracks the same design-system field every other screen uses.
///
/// This widget owns only the composer bar itself -- the field and its send
/// control. Each caller keeps its own outer `Padding`/keyboard-inset
/// handling, because that part is genuinely *not* identical: the two full-
/// screen callers sit inside a `Scaffold` that already resizes for the
/// keyboard (so they must deliberately *not* add `viewInsets.bottom`
/// again), while the quick-ask sheet has no `Scaffold` of its own and must
/// add it manually. Folding that into this widget would force one of the
/// two behaviours onto a caller that needs the other.
class CoachComposer extends StatelessWidget {
  const CoachComposer({
    required this.controller,
    required this.onSend,
    required this.hint,
    this.label,
    this.isSending = false,
    this.autofocus = false,
    this.sendButton,
    super.key,
  });

  final TextEditingController controller;
  final String hint;

  /// Optional floating label -- see [AppTextField.label]. Left null by
  /// callers (like the quick-ask sheet) that only want the [hint].
  final String? label;

  /// Called when the candidate submits via the keyboard's send action or
  /// taps the send control. Sending itself (haptics, clearing the
  /// controller, calling the repository) stays owned by each caller's own
  /// `_send` method, unchanged -- this widget only wires the trigger.
  final VoidCallback onSend;

  /// Disables the field and (for the default send control) the send
  /// button while a message is in flight -- matches each caller's own
  /// `_isStarting`/`_isSending`/`sendingThreadIds.contains(...)` state.
  final bool isSending;

  /// See [AppTextField.autofocus] -- used by the quick-ask sheet, which
  /// should be ready to type into as soon as it opens.
  final bool autofocus;

  /// Overrides the default plain send [IconButton]. `CoachThreadScreen`
  /// passes its own approved `_SendSparkButton` here -- that animation is
  /// deliberate, already-approved work (see that file's doc comment) and
  /// this widget must not replace it with the shared default.
  final Widget? sendButton;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppTextField(
            label: label,
            hint: hint,
            controller: controller,
            enabled: !isSending,
            autofocus: autofocus,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSend(),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        sendButton ??
            IconButton(
              tooltip: AppLocalizations.of(context).coachSendTooltip,
              onPressed: isSending ? null : onSend,
              icon: const Icon(Icons.send),
            ),
      ],
    );
  }
}
