import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/coach_mark.dart';
import '../../../core/widgets/app_feedback.dart';
import '../domain/coach_message.dart';
import 'coach_threads_controller.dart';

/// Must match `aiCoachRoutePath`/`aiCoachThreadRoutePath` in
/// `app/router/app_router.dart` -- kept as a plain literal here rather
/// than importing the router (feature code stays decoupled from it, the
/// same way every other screen only ever receives navigation as an
/// injected callback) since `MicroLessonPlayerScreen`, this affordance's
/// first host, is pushed via a raw `Navigator.push`, not a GoRoute, so
/// there is no router-supplied callback already threaded down to it.
String _coachThreadPath(String threadId) => '/coach/$threadId';

/// The contextual "Ask" affordance (see docs/27-ai-coach-plan.md's v4
/// design reference): a small floating control that opens a quick-ask
/// sheet pre-loaded with what the candidate is already looking at,
/// instead of sending them to a blank chat screen to re-explain it.
///
/// Text-first, not voice-first, unlike the design reference: this app has
/// no speech-to-text provider (see `voice_interview_screen.dart`'s own
/// "A transcription provider is not connected" state), so a live
/// waveform + partial transcript would be fabricated UI. The mic control
/// below degrades the same honest way the standalone Coach composer
/// already does.
class AskCoachAffordance extends StatelessWidget {
  const AskCoachAffordance({
    required this.contextLabel,
    this.contextRef,
    super.key,
  });

  /// What the candidate is looking at, shown back to them as the sheet's
  /// context chip (e.g. a micro-lesson clip's title).
  final String contextLabel;

  /// Recorded on the resulting `CoachThread` for future use -- see
  /// `CoachThread.contextRef`.
  final String? contextRef;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'ask-coach-affordance',
      backgroundColor: AppColors.brand,
      foregroundColor: Colors.white,
      icon: const CoachMark(color: Colors.white, size: 18),
      label: const Text('Ask'),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) =>
            _AskCoachSheet(contextLabel: contextLabel, contextRef: contextRef),
      ),
    );
  }
}

class _AskCoachSheet extends ConsumerStatefulWidget {
  const _AskCoachSheet({required this.contextLabel, this.contextRef});

  final String contextLabel;
  final String? contextRef;

  @override
  ConsumerState<_AskCoachSheet> createState() => _AskCoachSheetState();
}

class _AskCoachSheetState extends ConsumerState<_AskCoachSheet> {
  final _composer = TextEditingController();
  String? _threadId;
  bool _isSending = false;

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final threadId = _threadId;
    final thread = threadId == null
        ? null
        : ref
              .watch(coachThreadsControllerProvider)
              .valueOrNull
              ?.threadById(threadId);
    final lastMessage = (thread?.messages.isEmpty ?? true)
        ? null
        : thread!.messages.last;
    final hasReply =
        !_isSending &&
        lastMessage != null &&
        lastMessage.author == CoachMessageAuthor.coach;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              avatar: const CoachMark(size: 14, color: AppColors.brand),
              label: Text('Asking about: ${widget.contextLabel}'),
              backgroundColor: AppColors.brandSoft,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_isSending)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text('Coach is typing…'),
                ],
              ),
            ),
          if (hasReply) ...[
            Text(lastMessage.text),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => FocusScope.of(context).nextFocus(),
                    child: const Text('Ask something else'),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push(_coachThreadPath(threadId!));
                    },
                    child: const Text('Continue in Coach'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            children: [
              IconButton(
                tooltip: 'Voice input unavailable',
                onPressed: _showVoicePlaceholder,
                icon: const Icon(Icons.mic_none_outlined),
              ),
              Expanded(
                child: TextField(
                  controller: _composer,
                  enabled: !_isSending,
                  autofocus: true,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'Message your coach…',
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Send message',
                onPressed: _isSending ? null : _send,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _isSending) return;
    _composer.clear();
    setState(() => _isSending = true);

    final notifier = ref.read(coachThreadsControllerProvider.notifier);
    final existingThreadId = _threadId;
    String? resolvedId;
    if (existingThreadId == null) {
      resolvedId = await notifier.startThread(
        openingMessage: text,
        contextRef: widget.contextRef,
      );
    } else {
      await notifier.sendMessage(existingThreadId, text);
      resolvedId = existingThreadId;
    }

    if (!mounted) return;
    setState(() {
      _threadId = resolvedId;
      _isSending = false;
    });
  }

  void _showVoicePlaceholder() {
    showAppSnackBar(
      context: context,
      message:
          'Voice input is not active. No microphone permission was requested.',
      tone: AppMessageTone.neutral,
    );
  }
}
