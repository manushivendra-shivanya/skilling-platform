import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../domain/coach_message.dart';
import 'coach_threads_controller.dart';

/// One open conversation from `CoachThreadsScreen`'s list. Same message-
/// bubble UI the old single-conversation `CoachScreen` used, now scoped
/// to a single [CoachThread] instead of one global list.
class CoachThreadScreen extends ConsumerStatefulWidget {
  const CoachThreadScreen({required this.threadId, super.key});

  final String threadId;

  @override
  ConsumerState<CoachThreadScreen> createState() => _CoachThreadScreenState();
}

class _CoachThreadScreenState extends ConsumerState<CoachThreadScreen> {
  final _composer = TextEditingController();

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final threadsState = ref.watch(coachThreadsControllerProvider).valueOrNull;
    final thread = threadsState?.threadById(widget.threadId);
    final isSending =
        threadsState?.sendingThreadIds.contains(widget.threadId) ?? false;

    if (thread == null) {
      // Reached directly (e.g. a stale deep link) with no matching thread
      // -- rather than crash on a null lookup, show a plain not-found
      // state instead of a fabricated conversation.
      return Scaffold(
        appBar: AppBar(title: const Text('AI Career Coach')),
        body: const Center(child: Text('This conversation is not available.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(thread.topicLabel)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: thread.messages.length + (isSending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == thread.messages.length) {
                    return const _TypingIndicatorBubble();
                  }
                  return _MessageBubble(message: thread.messages[index]);
                },
              ),
            ),
            Padding(
              // Bottom inset is deliberately just AppSpacing.sm, not
              // MediaQuery.viewInsetsOf(context).bottom + AppSpacing.sm.
              // `context` here is this State's own build context, which
              // sits *above* the Scaffold this method returns -- Scaffold
              // only strips the keyboard inset from the MediaQuery its
              // body subtree sees, not from this outer context, so this
              // read the full, un-stripped keyboard height. Meanwhile the
              // Scaffold (default resizeToAvoidBottomInset: true) already
              // shrinks the body by that same height, so adding it again
              // here double-counted it -- confirmed via a widget test that
              // reproduces "RenderFlex overflowed" with this term present
              // and a realistic keyboard height, matching the real-device
              // report (see coach_thread_screen_test.dart, and
              // coach_threads_screen.dart's identical fix).
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _composer,
                      enabled: !isSending,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask about skills or interviews',
                        labelText: 'Message',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton(
                    tooltip: 'Send message',
                    onPressed: isSending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _send() {
    final text = _composer.text;
    if (text.trim().isEmpty) {
      return;
    }
    unawaited(
      ref
          .read(coachThreadsControllerProvider.notifier)
          .sendMessage(widget.threadId, text),
    );
    _composer.clear();
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final CoachMessage message;

  @override
  Widget build(BuildContext context) {
    final isCandidate = message.author == CoachMessageAuthor.candidate;
    return Align(
      alignment: isCandidate ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isCandidate ? AppColors.brand : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.text,
          style: TextStyle(color: isCandidate ? Colors.white : AppColors.ink),
        ),
      ),
    );
  }
}

class _TypingIndicatorBubble extends StatelessWidget {
  const _TypingIndicatorBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Semantics(
          liveRegion: true,
          label: 'Coach is typing a reply',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('Coach is typing…', style: TextStyle(color: AppColors.ink)),
            ],
          ),
        ),
      ),
    );
  }
}
