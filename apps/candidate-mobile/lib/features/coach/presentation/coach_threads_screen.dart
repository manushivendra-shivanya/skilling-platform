import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/coach_mark.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/app_failure_localization.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_loading_progress.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/coach_thread.dart';
import 'coach_composer.dart';
import 'coach_threads_controller.dart';

/// Coach's own home: a list of past conversations ("Topic threads" --
/// design option B in docs/27-ai-coach-plan.md) plus a composer that
/// starts a new one. Tapping a thread opens `CoachThreadScreen`.
class CoachThreadsScreen extends ConsumerStatefulWidget {
  const CoachThreadsScreen({required this.onOpenThread, super.key});

  final void Function(String threadId) onOpenThread;

  @override
  ConsumerState<CoachThreadsScreen> createState() => _CoachThreadsScreenState();
}

class _CoachThreadsScreenState extends ConsumerState<CoachThreadsScreen> {
  final _composer = TextEditingController();
  bool _isStarting = false;

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final asyncState = ref.watch(coachThreadsControllerProvider);
    final isLiveData = ref.watch(coachRepositoryProvider).isLiveData;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.coachAppBarTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: AppColors.infoSoft,
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Text(
                isLiveData
                    ? l10n.coachLiveDataBanner
                    : l10n.coachDemoDataBanner,
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: asyncState.when(
                // Page-level "the thread list hasn't loaded yet" -- a
                // different state from "the coach is composing a reply"
                // (see CoachThinkingIndicator's doc comment), so this stays
                // the app's normal page-load affordance rather than
                // sharing that widget.
                loading: () => Center(
                  child: AppLoadingProgressBar(
                    label: l10n.coachLoadingConversations,
                  ),
                ),
                error: (error, _) => AppErrorState(
                  title: l10n.coachLoadErrorTitle,
                  message: error is AppFailure
                      ? error.localizedMessage(l10n)
                      : l10n.coachLoadErrorFallback,
                  onAction: () =>
                      ref.invalidate(coachThreadsControllerProvider),
                ),
                data: (state) => state.threads.isEmpty
                    ? _WelcomeView(onPromptTap: _startThread)
                    : _ThreadList(
                        threads: state.threads,
                        onTap: widget.onOpenThread,
                      ),
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
              // coach_thread_screen.dart's identical fix).
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: CoachComposer(
                controller: _composer,
                onSend: _send,
                hint: l10n.coachNewQuestionHint,
                label: l10n.coachMessageLabel,
                isSending: _isStarting,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _send() {
    final text = _composer.text;
    if (text.trim().isEmpty || _isStarting) {
      return;
    }
    unawaited(HapticFeedback.lightImpact());
    _composer.clear();
    unawaited(_startThread(text));
  }

  Future<void> _startThread(String message) async {
    setState(() => _isStarting = true);
    final threadId = await ref
        .read(coachThreadsControllerProvider.notifier)
        .startThread(openingMessage: message);
    if (!mounted) return;
    setState(() => _isStarting = false);
    if (threadId != null) {
      widget.onOpenThread(threadId);
    }
  }
}

class _WelcomeView extends StatelessWidget {
  const _WelcomeView({required this.onPromptTap});

  final ValueChanged<String> onPromptTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final starterPrompts = [
      l10n.coachPromptExplainTerm,
      l10n.coachPromptPracticeInterview,
      l10n.coachPromptExperience,
    ];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: AppColors.brandSoft,
                shape: BoxShape.circle,
              ),
              child: const CoachMark(size: 28, color: AppColors.brand),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.coachWelcomeGreeting,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.coachWelcomeDisclaimer,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final prompt in starterPrompts)
                  ActionChip(
                    label: Text(prompt),
                    onPressed: () => onPromptTap(prompt),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadList extends StatelessWidget {
  const _ThreadList({required this.threads, required this.onTap});

  final List<CoachThread> threads;
  final void Function(String threadId) onTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: threads.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final thread = threads[index];
        return _ThreadRow(thread: thread, onTap: () => onTap(thread.id));
      },
    );
  }
}

class _ThreadRow extends StatelessWidget {
  const _ThreadRow({required this.thread, required this.onTap});

  final CoachThread thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: AppColors.brandSoft,
              shape: BoxShape.circle,
            ),
            child: const CoachMark(size: 16, color: AppColors.brand),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  thread.topicLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '${l10n.coachMessageCount(thread.messages.length)} • '
                  '${_relativeTime(thread.lastActivityAt, l10n)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.inkMuted),
        ],
      ),
    );
  }
}

String _relativeTime(DateTime at, AppLocalizations l10n) {
  final diff = DateTime.now().difference(at);
  if (diff.inMinutes < 1) return l10n.coachTimeJustNow;
  if (diff.inMinutes < 60) return l10n.coachTimeMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l10n.coachTimeHoursAgo(diff.inHours);
  if (diff.inDays < 7) {
    return l10n.coachTimeDaysAgo(diff.inDays);
  }
  return '${at.day}/${at.month}/${at.year}';
}
