import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_feedback.dart';
import '../domain/coach_message.dart';
import 'coach_controller.dart';

class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  final _composer = TextEditingController();

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(coachControllerProvider);
    final isLiveData = ref.watch(coachRepositoryProvider).isLiveData;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Career Coach'),
        actions: [
          IconButton(
            tooltip: 'Reset conversation',
            onPressed: _confirmReset,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: AppColors.infoSoft,
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Text(
                isLiveData
                    ? 'AI-generated guidance • Verify anything important with your training officer.'
                    : 'Local demo only • No production AI is connected. Do not share sensitive information.',
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: state.messages.length + (state.isSending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == state.messages.length) {
                    return const _TypingIndicatorBubble();
                  }
                  return _MessageBubble(message: state.messages[index]);
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.sm,
                MediaQuery.viewInsetsOf(context).bottom + AppSpacing.sm,
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Attachment options',
                    onPressed: _showAttachmentOptions,
                    icon: const Icon(Icons.attach_file),
                  ),
                  IconButton(
                    tooltip: 'Voice input unavailable',
                    onPressed: _showVoicePlaceholder,
                    icon: const Icon(Icons.mic_none_outlined),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _composer,
                      enabled: !state.isSending,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask about skills or interviews',
                        labelText: 'Message',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Send message',
                    onPressed: state.isSending ? null : _send,
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
    unawaited(ref.read(coachControllerProvider.notifier).send(text));
    _composer.clear();
  }

  void _showVoicePlaceholder() {
    showAppSnackBar(
      context: context,
      message:
          'Voice input is not active. No microphone permission was requested.',
      tone: AppMessageTone.neutral,
    );
  }

  Future<void> _showAttachmentOptions() {
    return showAppBottomSheet<void>(
      context: context,
      title: 'Attachment options',
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.image_outlined),
              title: Text('Photo'),
              subtitle: Text('Planned • no photo access requested'),
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          AppCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.description_outlined),
              title: Text('Document'),
              subtitle: Text('Planned • no file access requested'),
            ),
          ),
          SizedBox(height: AppSpacing.md),
          AppBottomSheetCloseButton(),
        ],
      ),
    );
  }

  Future<void> _confirmReset() async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'Reset this demo conversation?',
      message: 'Messages in this local session will be cleared.',
      confirmLabel: 'Reset',
    );
    if (confirmed) {
      ref.read(coachControllerProvider.notifier).reset();
    }
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
